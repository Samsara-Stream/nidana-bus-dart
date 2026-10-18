// codegen-plan-facts, part A: ADR-002 item 4's resolution probe for a package
// outside its table. nidana_dart_codegen formats the registry with
// dart_style 3.1.14, whose DartFormatter takes a pub_semver Version
// (languageVersion is required), so the member imports
// package:pub_semver/pub_semver.dart and must declare it.
//
// A1 one resolution of every row of ADR-002 item 3 (stand-in members with the
//    rows' real third-party packages, as ../constraint-lower-bounds/run.mjs
//    builds them), item 7's exact pins, root D9's rxdart, with the codegen
//    stand-in also declaring pub_semver (open) and json_schema (its dev
//    dependency, at item 4's caret): the version pub_semver resolves to, and
//    every direct package compared with item 4's table.
// A2 the codegen stand-in with pub_semver at the caret of A1's version, from
//    no lockfile, on the member sets where it lands first ({cc, ct, cg}),
//    beside the plugin ({cc, ct, cg, li}), and the full set.
// A3 the API fact: a program constructing DartFormatter(languageVersion:
//    Version(3, 13, 0)) and formatting one line, compiled and run in A2's
//    full workspace.
// Run from anywhere: node probe.mjs > probe-output.txt 2>&1
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../../..');
const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'cpf-'));
const scrub = (s) => s.split(tmpRoot).join('{tmp}').split(os.homedir()).join('{home}');
const log = (...a) => console.log(scrub(a.join(' ')));
const step = (t) => { console.log(); console.log(`### ${t}`); };

// ADR-002 item 4's table (amended S38).
const TABLE = {
  analysis_server_plugin: '0.3.18', analyzer: '^13.3.0', analyzer_testing: '^0.3.2', args: '^2.7.0',
  build: '^4.0.11', build_runner: '^2.16.1', build_test: '^3.5.20', clock: '^1.1.3', dart_style: '^3.1.14',
  json_schema: '^5.2.2', matcher: '^0.12.20', meta: '^1.19.0', package_config: '^2.2.0', path: '^1.9.1',
  rxdart: '^0.28.0', source_gen: '^4.2.4', test: '^1.31.1', yaml: '^3.1.4',
};
const M = {
  cc: { name: 'cp_contract_check', publish: false, sib: [], deps: ['args', 'json_schema', 'matcher', 'package_config', 'path'], dev: ['test'] },
  ct: { name: 'cp_contracts', publish: true, sib: [], deps: ['meta'], dev: ['test'] },
  rt: { name: 'cp_runtime', publish: true, sib: ['ct'], deps: ['rxdart', 'clock', 'meta'], dev: ['test'] },
  nv: { name: 'cp_navigation', publish: true, sib: ['ct', 'rt'], deps: ['meta'], dev: ['test'] },
  fl: { name: 'cp_runtime_flutter', publish: true, sib: ['ct', 'rt', 'nv'], deps: ['meta'], dev: [], sdk: ['flutter'], sdkDev: ['flutter_test'] },
  li: { name: 'cp_lint', publish: true, sib: [], deps: ['analysis_server_plugin', 'analyzer'], dev: ['analyzer_testing', 'test'], pins: true },
  cg: { name: 'cp_codegen', publish: true, sib: ['ct'], deps: ['build', 'source_gen', 'analyzer', 'dart_style', 'yaml', 'path', 'pub_semver'], dev: ['build_test', 'test', 'json_schema'] },
  in: { name: 'cp_integration', publish: false, sib: ['ct', 'rt', 'nv', 'fl'], deps: [], dev: ['build_runner'], sibDev: ['cg'], sdk: ['flutter'], sdkDev: ['flutter_test'] },
};
const KEYS = Object.keys(M);
const q = (c) => (c === 'any' ? 'any' : `'${c}'`);

function pubspecOf(key, constraint) {
  const m = M[key];
  const L = [`name: ${m.name}`];
  if (m.publish) L.push('version: 0.1.0', 'description: Stand-in for one ADR-002 item 3 row (experiment only).');
  else L.push('publish_to: none');
  L.push('environment:', '  sdk: ^3.13.0', 'resolution: workspace', 'dependencies:');
  for (const s of m.sdk || []) L.push(`  ${s}:`, '    sdk: flutter');
  for (const s of m.sib) L.push(`  ${M[s].name}: ^0.1.0`);
  for (const p of m.deps) L.push(`  ${p}: ${q(constraint(key, p))}`);
  if (!m.deps.length && !m.sib.length && !(m.sdk || []).length) L.push('  {}');
  const dev = [];
  for (const s of m.sdkDev || []) dev.push(`  ${s}:`, '    sdk: flutter');
  for (const s of m.sibDev || []) dev.push(`  ${M[s].name}: ^0.1.0`);
  for (const p of m.dev) dev.push(`  ${p}: ${q(constraint(key, p))}`);
  if (dev.length) L.push('dev_dependencies:', ...dev);
  return L.join('\n') + '\n';
}
function writeWorkspace(dir, keys, constraint) {
  fs.mkdirSync(dir, { recursive: true });
  fs.copyFileSync(path.join(repo, '.fvmrc'), path.join(dir, '.fvmrc'));
  const order = KEYS.filter((k) => keys.includes(k));
  fs.writeFileSync(path.join(dir, 'pubspec.yaml'), ['name: cp_root', 'publish_to: none', 'environment:', '  sdk: ^3.13.0', 'workspace:',
    ...order.map((k) => `  - packages/${M[k].name}`), 'dev_dependencies:', '  lints: ^6.1.0'].join('\n') + '\n');
  for (const k of order) {
    const d = path.join(dir, 'packages', M[k].name);
    fs.mkdirSync(path.join(d, 'lib'), { recursive: true });
    fs.writeFileSync(path.join(d, 'pubspec.yaml'), pubspecOf(k, constraint));
    fs.writeFileSync(path.join(d, 'lib', `${M[k].name}.dart`), 'int one() => 1;\n');
  }
}
const pub = (dir) => { const r = spawnSync('fvm', ['dart', 'pub', 'get'], { cwd: dir, encoding: 'utf8' }); return { code: r.status, out: (r.stdout || '') + (r.stderr || '') }; };
function lockVersions(dir) {
  const s = fs.readFileSync(path.join(dir, 'pubspec.lock'), 'utf8');
  const re = /^  ([a-z_0-9]+):\n(?:    .*\n)*?    version: "([^"]+)"/gm;
  const v = {}; let m;
  while ((m = re.exec(s))) v[m[1]] = m[2];
  return v;
}
const fresh = (label) => fs.mkdtempSync(path.join(tmpRoot, `${label}-`));
const pinOrTable = (key, p) => (M[key].pins && p === 'analyzer' ? '13.3.0' : TABLE[p]);

log(execFileSync('fvm', ['dart', '--version'], { cwd: repo, encoding: 'utf8' }).trim());

step('A1 the full planned resolution with pub_semver (open) and json_schema (dev, ^5.2.2) in the codegen stand-in');
const a1 = fresh('a1');
writeWorkspace(a1, KEYS, (k, p) => (p === 'pub_semver' ? 'any' : pinOrTable(k, p)));
let r = pub(a1);
log(`pub get exit: ${r.code}`);
const v1 = lockVersions(a1);
log(`  pub_semver resolves to ${v1.pub_semver}`);
const direct = [...new Set(KEYS.flatMap((k) => [...M[k].deps, ...M[k].dev]))].filter((p) => p !== 'pub_semver').sort();
const off = direct.filter((p) => TABLE[p] && TABLE[p].replace('^', '') !== v1[p]);
log(`  direct packages whose resolved version differs from item 4's table: ${off.length ? off.map((p) => `${p} ${v1[p]} (table ${TABLE[p]})`).join(', ') : 'none'}`);
log(`  packages in the lockfile: ${Object.keys(v1).length}`);

const caret = `^${v1.pub_semver}`;
step(`A2 pub_semver: ${caret} in the codegen stand-in, every other constraint from item 4's table, each set from no lockfile`);
let full;
for (const set of [['cc', 'ct', 'cg'], ['cc', 'ct', 'cg', 'li'], KEYS]) {
  const d = fresh('a2');
  writeWorkspace(d, set, (k, p) => (p === 'pub_semver' ? caret : pinOrTable(k, p)));
  r = pub(d);
  const v = lockVersions(d);
  log(`  {${set.join(', ')}}: pub get exit ${r.code}; pub_semver ${v.pub_semver}, analyzer ${v.analyzer}, dart_style ${v.dart_style}, test ${v.test}`);
  if (set === KEYS) full = d;
}

step('A3 DartFormatter(languageVersion: Version(3, 13, 0)) in the codegen stand-in of A2\'s full workspace');
const cg = path.join(full, 'packages', M.cg.name);
fs.mkdirSync(path.join(cg, 'bin'), { recursive: true });
fs.writeFileSync(path.join(cg, 'bin', 'fmt.dart'), [
  "import 'package:dart_style/dart_style.dart';",
  "import 'package:pub_semver/pub_semver.dart';",
  '',
  "void main() => print(DartFormatter(languageVersion: Version(3, 13, 0)).format('int  one( )=>1;'));",
  '',
].join('\n'));
const run = spawnSync('fvm', ['dart', 'run', `${M.cg.name}:fmt`], { cwd: full, encoding: 'utf8' });
log(`  exit ${run.status}; output: ${(run.stdout || '').trim()}`);
const an = spawnSync('fvm', ['dart', 'analyze', '--fatal-infos', `packages/${M.cg.name}/bin`], { cwd: full, encoding: 'utf8' });
log(`  dart analyze --fatal-infos of bin/fmt.dart: exit ${an.status}; ${(an.stdout || '').trim().split('\n').pop()}`);

fs.rmSync(tmpRoot, { recursive: true, force: true });
console.log();
console.log('run exit 0');
