// constraint-lower-bounds: settles ADR-002 item 4's rule for the lower bound
// of a third-party caret constraint (step S38). It starts from
// ../lint-reconcile-amends/constraints.sh (K1 to K6), which showed that the
// accepted rule, "the version the committed lockfile resolves when the
// dependency is added", writes `test: ^1.33.0` at nidana.model.1, and that
// `test: ^1.33.0` does not resolve once a Flutter member joins.
//
// Stand-in members, one per row of ADR-002 item 3, each with that row's real
// third-party dependencies (stand-in names, lb_*, for the nidana packages):
//   cc  nidana_contract_check        created by nidana.model.1
//   ct  nidana_dart_contracts        nidana.model.3
//   rt  nidana_dart_runtime          nidana.runtime's member-creating phase
//   nv  nidana_dart_navigation       nidana.navigation.1
//   fl  nidana_dart_runtime_flutter  nidana.flutter.1
//   li  nidana_dart_lint             nidana.tooling.lint.1
//   cg  nidana_dart_codegen          nidana.tooling.codegen's member phase
//   in  nidana_integration           nidana.integration's member phase
// The plans' edges between those phases: cc first (nidana.model.1 creates
// the root); ct before rt and cg (both depend on the contracts package); rt
// before nv; nv before fl; fl and cg before in; li after cc and otherwise
// free (nidana.tooling.lint.1 depends on nidana.model.1 and .7 only).
//
//   P0 the full planned resolution: every member, open constraints except
//      root D9's `rxdart: ^0.28.0` and item 7's exact pins. Its versions are
//      the candidate lower-bound table T.
//   P1 what holds each direct package of P0 below its newest version: the
//      full set with a caret at the newest version, and pub's explanation.
//   P2 the accepted rule, simulated along the planned order and along the
//      tooling-first order, with the lockfile kept between stages as the
//      phases keep it: where it first fails. P2c: the rule's other
//      constraint from nidana.model.1, package_config ^3.0.0, on its own.
//   P3 the accepted rule with a Flutter anchor (`flutter_test`) in the root
//      from nidana.model.1, the alternative that keeps the rule and puts
//      Flutter's pins first.
//   P4 the proposed rule (every lower bound from T) on every member set any
//      build order reaches, each resolved from no lockfile; per set, the
//      direct packages whose resolved version differs from T.
//   P5 the proposed rule along the same two orders with the lockfile kept
//      between stages, then `pub get --enforce-lockfile` as every gate runs
//      it; the lockfile changes each stage makes to direct packages.
//      P5c: item 7's pins read literally ("the exact version the committed
//      lockfile resolves") when the plugin lands before the Flutter member.
//   P6 P5's final lockfiles against P0's, every package compared.
//
// Each workspace lives in a temporary directory with a copy of .fvmrc and
// resolves with `fvm dart pub get` at its root, online against pub.dev.
// Run from anywhere: node run.mjs > output.txt 2>&1
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../../..');
const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'clb-'));
const scrub = (s) => s.split(tmpRoot).join('{tmp}').split(os.homedir()).join('{home}');
const log = (...a) => console.log(scrub(a.join(' ')));
const step = (t) => { console.log(); console.log(`### ${t}`); };

// The members. `sib` are sibling members (hosted ^0.1.0), `deps` and `dev`
// third-party packages, `sdk` and `sdkDev` Flutter SDK packages.
const M = {
  cc: { name: 'lb_contract_check', publish: false, sib: [], deps: ['args', 'json_schema', 'matcher', 'package_config', 'path'], dev: ['test'] },
  ct: { name: 'lb_contracts', publish: true, sib: [], deps: ['meta'], dev: ['test'] },
  rt: { name: 'lb_runtime', publish: true, sib: ['ct'], deps: ['rxdart', 'clock', 'meta'], dev: ['test'] },
  nv: { name: 'lb_navigation', publish: true, sib: ['ct', 'rt'], deps: ['meta'], dev: ['test'] },
  fl: { name: 'lb_runtime_flutter', publish: true, sib: ['ct', 'rt', 'nv'], deps: ['meta'], dev: [], sdk: ['flutter'], sdkDev: ['flutter_test'] },
  li: { name: 'lb_lint', publish: true, sib: [], deps: ['analysis_server_plugin', 'analyzer'], dev: ['analyzer_testing', 'test'], pins: true },
  cg: { name: 'lb_codegen', publish: true, sib: ['ct'], deps: ['build', 'source_gen', 'analyzer', 'dart_style', 'yaml', 'path'], dev: ['build_test', 'test'] },
  in: { name: 'lb_integration', publish: false, sib: ['ct', 'rt', 'nv', 'fl'], deps: [], dev: ['build_runner'], sibDev: ['cg'], sdk: ['flutter'], sdkDev: ['flutter_test'] },
};
const KEYS = Object.keys(M);
const PRE = { ct: ['cc'], rt: ['ct', 'cc'], nv: ['rt', 'cc'], fl: ['nv', 'cc'], cg: ['ct', 'cc'], in: ['fl', 'cg', 'cc'], li: ['cc'], cc: [] };
const PLANNED = ['cc', 'ct', 'rt', 'nv', 'fl', 'li', 'cg', 'in'];
const TOOLING_FIRST = ['cc', 'li', 'ct', 'cg', 'rt', 'nv', 'fl', 'in'];
const PINS = { analysis_server_plugin: '0.3.18', analyzer: '13.3.0' }; // item 7, in li only
const DIRECT = [...new Set(KEYS.flatMap((k) => [...M[k].deps, ...M[k].dev]))].sort();
const WATCH = ['test', 'test_api', 'test_core', 'analyzer', 'matcher', 'meta', 'package_config', 'path', 'clock', 'build', 'source_gen'];

// constraint(rule, key, pkg): the constraint string member `key` writes.
const exactPin = (key, pkg) => (M[key].pins && PINS[pkg]) || null;
const ruleOpen = (key, pkg) => exactPin(key, pkg) || (pkg === 'rxdart' ? '^0.28.0' : 'any');

function pubspecOf(key, constraint) {
  const m = M[key];
  const L = [`name: ${m.name}`];
  if (m.publish) L.push('version: 0.1.0', `description: Stand-in for one ADR-002 item 3 row (experiment only).`);
  else L.push('publish_to: none');
  L.push('environment:', '  sdk: ^3.13.0', 'resolution: workspace', 'dependencies:');
  for (const s of m.sdk || []) L.push(`  ${s}:`, '    sdk: flutter');
  for (const s of m.sib) L.push(`  ${M[s].name}: ^0.1.0`);
  for (const p of m.deps) L.push(`  ${p}: ${q(constraint(key, p))}`);
  if (!m.deps.length && !m.sib.length && !(m.sdk || []).length) L.push('  {}');
  const devLines = [];
  for (const s of m.sdkDev || []) devLines.push(`  ${s}:`, '    sdk: flutter');
  for (const s of m.sibDev || []) devLines.push(`  ${M[s].name}: ^0.1.0`);
  for (const p of m.dev) devLines.push(`  ${p}: ${q(constraint(key, p))}`);
  if (devLines.length) L.push('dev_dependencies:', ...devLines);
  return L.join('\n') + '\n';
}
const q = (c) => (c === 'any' ? 'any' : `'${c}'`);

function writeWorkspace(dir, keys, constraint, { anchor = false } = {}) {
  fs.mkdirSync(dir, { recursive: true });
  fs.copyFileSync(path.join(repo, '.fvmrc'), path.join(dir, '.fvmrc'));
  const order = KEYS.filter((k) => keys.includes(k));
  const root = ['name: lb_root', 'publish_to: none', 'environment:', '  sdk: ^3.13.0', 'workspace:',
    ...order.map((k) => `  - packages/${M[k].name}`), 'dev_dependencies:', '  lints: ^6.1.0'];
  if (anchor) root.push('  flutter_test:', '    sdk: flutter');
  fs.writeFileSync(path.join(dir, 'pubspec.yaml'), root.join('\n') + '\n');
  for (const k of order) {
    const d = path.join(dir, 'packages', M[k].name);
    fs.mkdirSync(path.join(d, 'lib'), { recursive: true });
    fs.writeFileSync(path.join(d, 'pubspec.yaml'), pubspecOf(k, constraint));
    fs.writeFileSync(path.join(d, 'lib', `${M[k].name}.dart`), 'int one() => 1;\n');
  }
}

function pub(dir, args = []) {
  const r = spawnSync('fvm', ['dart', 'pub', 'get', ...args], { cwd: dir, encoding: 'utf8' });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}
const reasons = (out) => out.split('\n').filter((l) => /^(Because|So,|And because|Thus,)/.test(l)).slice(0, 5);
const changes = (out, pkgs) => out.split('\n').filter((l) => /^[<>+\-*] /.test(l) && pkgs.includes(l.slice(2).split(' ')[0]));

function lockVersions(dir) {
  const f = path.join(dir, 'pubspec.lock');
  if (!fs.existsSync(f)) return null;
  const s = fs.readFileSync(f, 'utf8');
  const re = /^  ([a-z_0-9]+):\n(?:    .*\n)*?    version: "([^"]+)"/gm;
  const v = {};
  let m;
  while ((m = re.exec(s))) v[m[1]] = m[2];
  return v;
}
const caret = (v) => `^${v}`;
const fresh = (label) => fs.mkdtempSync(path.join(tmpRoot, `${label}-`));

log(execFileSync('fvm', ['dart', '--version'], { cwd: repo, encoding: 'utf8' }).trim());

// ---------------------------------------------------------------- P0
step('P0 the full planned resolution, open constraints (rxdart ^0.28.0, item 7 pins in lb_lint)');
const p0 = fresh('p0');
writeWorkspace(p0, KEYS, ruleOpen);
let r = pub(p0);
log(`pub get exit: ${r.code}`);
const T = lockVersions(p0);
const outdated = JSON.parse(spawnSync('fvm', ['dart', 'pub', 'outdated', '--json', '--show-all'], { cwd: p0, encoding: 'utf8' }).stdout);
const latest = Object.fromEntries(outdated.packages.map((p) => [p.package, p.latest?.version]));
log('  package                  T (resolved)  newest');
for (const p of [...DIRECT, 'lints']) log(`  ${p.padEnd(24)} ${T[p].padEnd(13)} ${latest[p] ?? '-'}${latest[p] && latest[p] !== T[p] ? '   held' : ''}`);
log('  transitive, watched:');
for (const p of ['test_api', 'test_core']) log(`  ${p.padEnd(24)} ${T[p].padEnd(13)} ${latest[p] ?? '-'}`);
const ruleTable = (key, pkg) => exactPin(key, pkg) || caret(T[pkg]);

// ---------------------------------------------------------------- P1
step('P1 what holds a direct package below its newest version: the full set with a caret at the newest');
for (const p of DIRECT.filter((p) => latest[p] && latest[p] !== T[p] && !PINS[p])) {
  const d = fresh(`p1-${p}`);
  writeWorkspace(d, KEYS, (k, x) => (x === p ? caret(latest[p]) : ruleOpen(k, x)));
  r = pub(d);
  log(`-- ${p}: ^${latest[p]} in every member that declares it: pub get exit ${r.code}`);
  for (const l of reasons(r.out)) log(`   ${l}`);
}

// ---------------------------------------------------------------- P2, P3
// The accepted rule: a dependency already declared by an earlier member
// takes that member's constraint; a new one is added open, resolved, and
// written as the caret of the version the lockfile then holds. rxdart takes
// root D9's ^0.28.0 and lb_lint item 7's exact pins.
function simulateAccepted(order, label, opts = {}) {
  const dir = fresh(label);
  const declared = {};
  const present = [];
  for (const k of order) {
    present.push(k);
    const fresh_ = [...M[k].deps, ...M[k].dev].filter((p) => !(p in declared) && !exactPin(k, p) && p !== 'rxdart');
    const constraint = (key, p) => exactPin(key, p) || (p === 'rxdart' ? '^0.28.0' : declared[p] ?? 'any');
    writeWorkspace(dir, present, constraint, opts);
    r = pub(dir);
    if (r.code !== 0) {
      log(`  ${k.padEnd(3)} ${M[k].name}: pub get exit ${r.code}, before writing any new constraint`);
      for (const l of reasons(r.out)) log(`      ${l}`);
      return false;
    }
    const v = lockVersions(dir);
    for (const p of fresh_) declared[p] = caret(v[p]);
    writeWorkspace(dir, present, constraint, opts);
    r = pub(dir);
    const wrote = fresh_.map((p) => `${p}: ${declared[p]}`).join(', ') || 'no new constraint';
    log(`  ${k.padEnd(3)} ${M[k].name}: writes ${wrote}; pub get exit ${r.code}`);
    if (r.code !== 0) { for (const l of reasons(r.out)) log(`      ${l}`); return false; }
  }
  log('  every stage resolved');
  return true;
}
step('P2a the accepted rule along the planned order');
simulateAccepted(PLANNED, 'p2a');
step('P2b the accepted rule along the tooling-first order');
simulateAccepted(TOOLING_FIRST, 'p2b');
// P2c: P2a stops at test ^1.33.0. The accepted rule's package_config ^3.0.0,
// written by the same stage, on its own: the members through nidana.flutter.1
// with every other constraint from T.
step("P2c the accepted rule's package_config ^3.0.0 alone, members through nidana.flutter.1, T elsewhere");
{
  const d = fresh('p2c');
  writeWorkspace(d, ['cc', 'ct', 'rt', 'nv', 'fl'], (k, p) => (p === 'package_config' ? '^3.0.0' : exactPin(k, p) || caret(T[p])));
  r = pub(d);
  log(`  pub get exit ${r.code}`);
  for (const l of reasons(r.out)) log(`      ${l}`);
}
step('P3a the accepted rule, Flutter anchor in the root from nidana.model.1, planned order');
simulateAccepted(PLANNED, 'p3a', { anchor: true });
step('P3b the accepted rule, Flutter anchor in the root from nidana.model.1, tooling-first order');
simulateAccepted(TOOLING_FIRST, 'p3b', { anchor: true });

// ---------------------------------------------------------------- P4
step('P4 the proposed rule (lower bound from T) on every member set a build order reaches, from no lockfile');
log('  constraints written:');
for (const p of DIRECT) log(`    ${p.padEnd(24)} ${PINS[p] ? `${caret(T[p])} (exact ${PINS[p]} in lb_lint)` : caret(T[p])}`);
const others = KEYS.filter((k) => k !== 'cc');
const sets = [];
for (let mask = 0; mask < 1 << others.length; mask++) {
  const s = ['cc', ...others.filter((_, i) => mask & (1 << i))];
  if (s.every((k) => PRE[k].every((p) => s.includes(p)))) sets.push(s);
}
log(`  reachable member sets: ${sets.length}`);
let p4fail = 0;
for (const s of sets) {
  const d = fresh('p4');
  writeWorkspace(d, s, ruleTable);
  r = pub(d);
  const v = lockVersions(d) || {};
  const declaredHere = [...new Set(s.flatMap((k) => [...M[k].deps, ...M[k].dev]))];
  const differ = declaredHere.filter((p) => v[p] && v[p] !== T[p]).map((p) => `${p} ${v[p]}`);
  if (r.code !== 0) p4fail++;
  log(`  {${s.join(' ')}}: exit ${r.code}; differs from T: ${differ.join(', ') || 'none'}`);
  if (r.code !== 0) for (const l of reasons(r.out)) log(`      ${l}`);
}
log(`  sets that failed: ${p4fail}`);

// ---------------------------------------------------------------- P5, P6
function incremental(order, label) {
  const dir = fresh(label);
  const present = [];
  for (const k of order) {
    present.push(k);
    writeWorkspace(dir, present, ruleTable);
    r = pub(dir);
    const ch = changes(r.out, [...DIRECT, 'test_api', 'test_core']);
    const e = pub(dir, ['--enforce-lockfile']);
    log(`  + ${k.padEnd(3)} pub get exit ${r.code}, then --enforce-lockfile exit ${e.code}${ch.length ? '; lockfile changes:' : ''}`);
    for (const l of ch) log(`      ${l}`);
    if (r.code !== 0) for (const l of reasons(r.out)) log(`      ${l}`);
  }
  return lockVersions(dir);
}
step('P5a the proposed rule along the planned order, lockfile kept between stages');
const p5a = incremental(PLANNED, 'p5a');
step('P5b the proposed rule along the tooling-first order, lockfile kept between stages');
const p5b = incremental(TOOLING_FIRST, 'p5b');

// ---------------------------------------------------------------- P5c
// ADR-002 item 7 as accepted pins the plugin's two packages "to the exact
// version the committed lockfile resolves". Read literally while the plugin
// lands before the first Flutter member (nidana.tooling.lint.1 needs only
// nidana.model.1 and .7), with every other constraint from T.
step('P5c item 7 read literally (pins = what the lockfile resolves when lb_lint is added), tooling-first order, T elsewhere');
{
  const dir = fresh('p5c');
  const present = [];
  let pins = null; // null until lb_lint's two packages have been resolved open
  const constraint = (key, p) => {
    if (M[key].pins && PINS[p]) return pins ? pins[p] : 'any';
    return caret(T[p]);
  };
  for (const k of TOOLING_FIRST) {
    present.push(k);
    writeWorkspace(dir, present, constraint);
    r = pub(dir);
    if (k === 'li' && r.code === 0) {
      const v = lockVersions(dir);
      pins = { analysis_server_plugin: v.analysis_server_plugin, analyzer: v.analyzer };
      writeWorkspace(dir, present, constraint);
      r = pub(dir);
      log(`  + li  pins analysis_server_plugin: ${pins.analysis_server_plugin}, analyzer: ${pins.analyzer}; pub get exit ${r.code}`);
    } else {
      log(`  + ${k.padEnd(3)} pub get exit ${r.code}`);
    }
    if (r.code !== 0) { for (const l of reasons(r.out)) log(`      ${l}`); break; }
  }
}

step("P6 P5's final lockfiles against P0's, every package");
for (const [label, v] of [['P5a', p5a], ['P5b', p5b]]) {
  const all = [...new Set([...Object.keys(T), ...Object.keys(v)])].sort();
  const diff = all.filter((p) => T[p] !== v[p]).map((p) => `${p} ${T[p] ?? '-'} -> ${v[p] ?? '-'}`);
  log(`  ${label}: ${all.length} packages; differences from P0: ${diff.join(', ') || 'none'}`);
}

fs.rmSync(tmpRoot, { recursive: true, force: true });
