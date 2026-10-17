#!/usr/bin/env node
// gate.mjs: the orchestrator's mechanical gate after each step of the
// automatic HSDD run. Zero dependencies. Run from the repository root, before
// the step's artifact commit, so `git status` shows exactly the step's changes.
//
// Usage:
//   node docs/auto-run/tools/gate.mjs --skill <hsdd-spec|hsdd-adr|hsdd-contract|hsdd-phase-plan|hsdd-reconcile>
//        [--node <node-id>]            phase-plan: the one spec file the step may write
//        [--pending-adr ADR-001,...]   ADR ids proposed but not yet materialized
//        [--contracts-pending]         contract ids named in specs may lack files (decomposition stages)
//        [--final]                     end-of-run checks (summary tables, drained sections, stable/final)
//   node docs/auto-run/tools/gate.mjs --final            (no --skill: tree-wide final check only)
//
// Exit 0 when no error; warnings never fail the gate.

import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";

const ROOT = process.cwd();
const H = join(ROOT, "hsdd");
const args = process.argv.slice(2);
const opt = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : undefined; };
const flag = (k) => args.includes(k);
const skill = opt("--skill");
const node = opt("--node");
const pendingAdr = new Set((opt("--pending-adr") || "").split(",").map((s) => s.trim()).filter(Boolean));
const contractsPending = flag("--contracts-pending");
const final = flag("--final");

const errors = [];
const warnings = [];
const err = (m) => errors.push(m);
const warn = (m) => warnings.push(m);

const read = (p) => readFileSync(p, "utf8");
const md = (dir) => (existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith(".md") && f !== "INDEX.md").sort() : []);

// ---------- 1. changed files against the skill's write set ----------
function changed() {
  const out = execFileSync("git", ["status", "--porcelain", "--untracked-files=all"], { encoding: "utf8" });
  return out.split("\n").filter(Boolean).map((l) => l.slice(3).replace(/^"|"$/g, "").split(" -> ").pop());
}
const NEVER = [/^ref\//, /^hsdd\/judgement\//, /^\.agents\//, /^\.claude\//, /^skills-lock\.json$/, /^\.fvmrc$/];
const ALWAYS = [/^docs\/auto-run\/experiments\//, /^docs\/auto-run\/steps\//];
const ALLOW = {
  "hsdd-spec": [/^hsdd\/spec\/[^/]+\.md$/, /^hsdd\/conventions\.md$/],
  "hsdd-adr": [/^hsdd\/adr\/[^/]+\.md$/, /^hsdd\/spec\/[^/]+\.md$/, /^hsdd\/contract\/[^/]+\.md$/, /^hsdd\/scripts\/gen-registry\.mjs$/],
  "hsdd-contract": [/^hsdd\/contract\//, /^hsdd\/scripts\/gen-registry\.mjs$/, /^hsdd\/adr\/INDEX\.md$/],
  "hsdd-phase-plan": node ? [new RegExp(`^hsdd/spec/${node.replace(/\./g, "\\.")}\\.md$`)] : [],
  "hsdd-reconcile": [/^hsdd\/contract\//, /^hsdd\/spec\/[^/]+\.md$/, /^hsdd\/conventions\.md$/, /^hsdd\/adr\/INDEX\.md$/],
};
const files = changed();
if (skill) {
  if (!ALLOW[skill]) err(`unknown skill ${skill}`);
  if (skill === "hsdd-phase-plan" && !node) err("--node is required for hsdd-phase-plan");
  for (const f of files) {
    if (NEVER.some((r) => r.test(f))) { err(`forbidden path changed: ${f}`); continue; }
    if (ALWAYS.some((r) => r.test(f))) continue;
    if (!(ALLOW[skill] || []).some((r) => r.test(f))) err(`${skill} may not write ${f}`);
  }
  if (!files.length) warn("the step changed no file");
}

// ---------- 2. registry: verbatim generator, regenerates clean ----------
const GEN = join(H, "scripts", "gen-registry.mjs");
if (existsSync(GEN)) {
  const src = join(ROOT, ".agents", "skills", "hsdd-contract", "scripts", "gen-registry.mjs");
  if (read(GEN) !== read(src)) err("hsdd/scripts/gen-registry.mjs is not a verbatim copy of the skill's generator");
  const idx = [join(H, "contract", "INDEX.md"), join(H, "adr", "INDEX.md")];
  const before = idx.map((p) => (existsSync(p) ? read(p) : null));
  try {
    execFileSync("node", [GEN], { cwd: ROOT, stdio: "pipe" });
  } catch (e) {
    err(`gen-registry.mjs failed: ${e.message}`);
  }
  idx.forEach((p, i) => {
    const after = existsSync(p) ? read(p) : null;
    if (after !== before[i]) err(`${p.slice(ROOT.length + 1)} was stale; the generator rewrote it`);
  });
} else if (existsSync(join(H, "contract")) && md(join(H, "contract")).length) {
  err("contracts exist but hsdd/scripts/gen-registry.mjs does not");
}

// ---------- 3. the tree ----------
const specDir = join(H, "spec");
const specs = md(specDir).map((f) => ({ f, id: f.replace(/\.md$/, ""), text: read(join(specDir, f)) }));
const contracts = md(join(H, "contract")).map((f) => ({ f, text: read(join(H, "contract", f)) }));
const adrs = md(join(H, "adr")).map((f) => ({ f, text: read(join(H, "adr", f)) }));
const conventions = existsSync(join(H, "conventions.md")) ? read(join(H, "conventions.md")) : "";

function frontmatter(text) {
  if (!text.startsWith("---")) return null;
  const end = text.indexOf("\n---", 3);
  if (end < 0) return null;
  const d = {};
  let key = null;
  for (const raw of text.slice(3, end).split("\n")) {
    if (!raw.trim() || raw.trim().startsWith("#")) continue;
    const item = raw.match(/^\s*-\s+(.*)$/);
    if (item && Array.isArray(d[key])) { d[key].push(item[1].replace(/\s+#.*$/, "").trim()); continue; }
    const kv = raw.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!kv) continue;
    key = kv[1];
    const v = kv[2].replace(/\s+#.*$/, "").trim();
    d[key] = v === "" ? [] : v.startsWith("[") ? v.replace(/^\[|\]$/g, "").split(",").map((s) => s.trim()).filter(Boolean) : v;
  }
  return d;
}

const field = (text, name) => {
  const m = new RegExp(`^\\s*-\\s+\\*\\*${name}:\\*\\*\\s*(.*)$`, "m").exec(text);
  return m ? m[1].trim() : null;
};

// A spec's own Kind is the first Kind field in the file (its header block).
const kindOf = (s) => (field(s.text, "Kind") || "").toLowerCase();

const allText = [
  ...specs.map((s) => ({ where: `hsdd/spec/${s.f}`, text: s.text })),
  ...contracts.map((c) => ({ where: `hsdd/contract/${c.f}`, text: c.text })),
  ...adrs.map((a) => ({ where: `hsdd/adr/${a.f}`, text: a.text })),
  { where: "hsdd/conventions.md", text: conventions },
];

for (const s of specs) {
  const t = /^#\s+([^\s:]+)\s*:/m.exec(s.text);
  if (!t) err(`hsdd/spec/${s.f}: no "# {node-id}: {Name}" title`);
  else if (t[1] !== s.id) err(`hsdd/spec/${s.f}: title id ${t[1]} does not match the file name`);
  if (!kindOf(s)) err(`hsdd/spec/${s.f}: no Kind field`);
  const dec = field(s.text, "Decomposes into");
  if (dec && !/phases/i.test(dec)) {
    for (const child of dec.match(/[a-z0-9-]+(?:\.[a-z0-9-]+)+/g) || []) {
      if (!existsSync(join(specDir, `${child}.md`))) err(`hsdd/spec/${s.f}: child ${child} has no spec file`);
    }
  }
}

// ADR references
const adrIds = new Map();
for (const a of adrs) {
  const fm = frontmatter(a.text);
  if (!fm) { err(`hsdd/adr/${a.f}: no frontmatter`); continue; }
  for (const k of ["id", "status", "affects", "date"]) if (!(k in fm)) err(`hsdd/adr/${a.f}: frontmatter lacks ${k}`);
  adrIds.set(fm.id, { f: a.f, fm });
}
for (const { where, text } of allText) {
  for (const m of text.matchAll(/\bADR-(\d{3})\b/g)) {
    const id = `ADR-${m[1]}`;
    if (adrIds.has(id)) continue;
    if (pendingAdr.has(id)) warn(`${where}: ${id} pending materialization`);
    else err(`${where}: cites ${id}, which has no file under hsdd/adr/`);
  }
}
// affects <-> Governed by
for (const [id, { f, fm }] of adrIds) {
  for (const target of fm.affects || []) {
    const slug = target.split("@")[0];
    const spec = specs.find((s) => s.id === target);
    const con = contracts.find((c) => (frontmatter(c.text) || {}).id === slug);
    const host = target.includes("@") ? con : spec || specs.find((s) => new RegExp(`^###\\s+${target.replace(/\./g, "\\.")}:`, "m").test(s.text));
    if (!host) { warn(`hsdd/adr/${f}: affects ${target}, which has no file yet (forward reference)`); continue; }
    const gb = /\*\*Governed by:\*\*\s*(.*)$|^governed_by:\s*(.*)$/gm;
    const text = host.text;
    if (!new RegExp(`Governed by:?\\*?\\*?[^\\n]*\\b${id}\\b|governed_by:[^\\n]*\\b${id}\\b`).test(text))
      err(`hsdd/adr/${f}: affects ${target}, but ${host.f} carries no Governed by ${id}`);
    void gb;
  }
}

// Contract references
const conById = new Map();
for (const c of contracts) {
  const fm = frontmatter(c.text);
  if (!fm) { err(`hsdd/contract/${c.f}: no frontmatter`); continue; }
  for (const k of ["id", "version", "status", "kind", "owner", "compatibility", "produced_by", "consumers", "phase_ids"])
    if (!(k in fm)) err(`hsdd/contract/${c.f}: frontmatter lacks ${k}`);
  if (fm.id && `${fm.id}.md` !== c.f) err(`hsdd/contract/${c.f}: id ${fm.id} does not match the file name`);
  conById.set(fm.id, { c, fm });
  const val = /##\s+Validation\s*\n([\s\S]*?)(?:\n##\s|$)/.exec(c.text);
  if (!val) err(`hsdd/contract/${c.f}: no ## Validation section`);
  else {
    const paths = [...val[1].matchAll(/(hsdd\/contract\/(?:schema|fixture)\/[^\s`)]+)/g)].map((m) => m[1].replace(/[.,;]$/, ""));
    if (!paths.length) err(`hsdd/contract/${c.f}: Validation names no schema or fixture path`);
    for (const p of paths) if (!existsSync(join(ROOT, p))) err(`hsdd/contract/${c.f}: Validation path ${p} does not exist`);
    if (paths.length && paths.every((p) => existsSync(join(ROOT, p)) && statSync(join(ROOT, p)).isDirectory() && !readdirSync(join(ROOT, p)).length))
      err(`hsdd/contract/${c.f}: every Validation path is an empty directory`);
  }
  if (fm.status === "stable" && fm.phase_ids !== "final") err(`hsdd/contract/${c.f}: stable with phase_ids ${fm.phase_ids}`);
}
const named = new Set();
for (const { where, text } of allText) {
  for (const m of text.matchAll(/(?<![\w/.-])([a-z][a-z0-9-]*)@(v\d+)\b/g)) {
    const [ref, slug, ver] = [m[0], m[1], m[2]];
    if (where.startsWith("hsdd/spec/")) named.add(slug);
    const hit = conById.get(slug);
    if (!hit) {
      if (contractsPending) warn(`${where}: ${ref} has no contract file yet`);
      else err(`${where}: cites ${ref}, which has no file under hsdd/contract/`);
    } else if (hit.fm.version !== ver && !new RegExp(`\\b${ver}\\b`).test(hit.c.text.split("## Versioning")[1] || ""))
      err(`${where}: cites ${ref}, but the contract is at ${hit.fm.version}`);
  }
}

// OQ references: defined once as a heading in a spec
const oqDefs = new Map();
for (const s of specs) {
  for (const m of s.text.matchAll(/^###\s+(OQ-?[A-Z]*\d+)\b/gm)) {
    if (oqDefs.has(m[1])) err(`${m[1]} defined twice: ${oqDefs.get(m[1])} and hsdd/spec/${s.f}`);
    else oqDefs.set(m[1], `hsdd/spec/${s.f}`);
  }
}
for (const { where, text } of allText) {
  for (const m of text.matchAll(/\bOQ-?[A-Z]*\d+\b/g)) {
    if (/^OQ-?[A-Z]*\d+$/.test(m[0]) && !oqDefs.has(m[0]) && !/\{|prefix/.test(text.slice(Math.max(0, m.index - 3), m.index)))
      err(`${where}: cites ${m[0]}, which no spec defines`);
  }
}

// Phase ids named by contracts
const phaseHeads = new Set();
for (const s of specs) for (const m of s.text.matchAll(/^###\s+([a-z0-9-]+(?:\.[a-z0-9-]+)*\.\d+):/gm)) phaseHeads.add(m[1]);
for (const [slug, { c, fm }] of conById) {
  for (const k of ["produced_by", "consumers"]) {
    for (const id of fm[k] || []) {
      const isPhase = /\.\d+$/.test(id);
      const ok = isPhase ? phaseHeads.has(id) : specs.some((s) => s.id === id);
      if (!ok) (fm.phase_ids === "final" ? err : warn)(`hsdd/contract/${c.f}: ${k} names ${id}, which does not resolve`);
    }
  }
  void slug;
}

// ---------- 4. final checks ----------
if (final) {
  for (const s of specs) {
    if (kindOf(s).includes("leaf-parent")) {
      const pp = /##\s+Phase Plan\s*\n([\s\S]*?)(?:\n##\s|$)/.exec(s.text);
      if (!pp || !/^\|\s*Phase\s*\|/m.test(pp[1])) err(`hsdd/spec/${s.f}: leaf-parent without a phase summary table`);
    }
    const gov = /##\s+Governance updates \(pending reconcile\)\s*\n([\s\S]*?)(?:\n##\s|$)/.exec(s.text);
    if (gov && /^\s*-\s+(confirm|note|amend|request)\b/m.test(gov[1])) err(`hsdd/spec/${s.f}: undrained governance entries`);
  }
  for (const [slug, { c, fm }] of conById) {
    if (fm.status !== "stable") err(`hsdd/contract/${c.f}: status ${fm.status}`);
    if (fm.phase_ids !== "final") err(`hsdd/contract/${c.f}: phase_ids ${fm.phase_ids}`);
    void slug;
  }
  const index = existsSync(join(H, "contract", "INDEX.md")) ? read(join(H, "contract", "INDEX.md")) : "";
  for (const slug of named) if (!index.includes(`\`${slug}\``)) err(`hsdd/contract/INDEX.md does not list ${slug}`);
}

// ---------- 5. prose rules (owner's ban list), warnings ----------
for (const f of files) {
  if (!/\.(md|json|yaml|yml|dart)$/.test(f) || !existsSync(join(ROOT, f)) || statSync(join(ROOT, f)).isDirectory()) continue;
  const t = read(join(ROOT, f));
  const dash = (t.match(/—/g) || []).length;
  if (dash) warn(`${f}: ${dash} em-dash(es)`);
  if (/load-bearing/i.test(t)) warn(`${f}: uses a banned phrase`);
}

for (const w of warnings) console.log(`warn  ${w}`);
for (const e of errors) console.log(`ERROR ${e}`);
console.log(`gate: ${errors.length} error(s), ${warnings.length} warning(s), ${files.length} changed file(s)`);
process.exit(errors.length ? 1 : 0);
