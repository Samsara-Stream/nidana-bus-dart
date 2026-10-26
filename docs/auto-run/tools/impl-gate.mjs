#!/usr/bin/env node
// impl-gate.mjs: the orchestrator's mechanical gate for the implementation
// segment (from S96). Zero dependencies. Run from the repository root.
//
// Usage:
//   node docs/auto-run/tools/impl-gate.mjs config <phase-id>
//       after an hsdd-config switch, before its artifact commit: the write set
//       (uncommitted changes), the stamp, hsdd-config's equality check, no
//       unfilled braces, the verification template, ids named without a section
//   node docs/auto-run/tools/impl-gate.mjs code-plan <phase-id>
//       after superpowers:writing-plans, before its artifact commit: the write
//       set and the derivative's Plan check
//   node docs/auto-run/tools/impl-gate.mjs implement <phase-id> <base> [--no-run] [--log <file>]
//       after execution: every file changed in <base>..HEAD and in the working
//       tree against the implement write set, the verification doc's sections,
//       prose rules on added lines, clean registries, a clean tree, and (unless
//       --no-run) the phase gate read from hsdd-context/<phase-id>.md
//
// Exit 0 when no error; warnings never fail the gate.

import { readFileSync, existsSync, writeFileSync } from "node:fs";
import { execFileSync, spawnSync } from "node:child_process";
import { join } from "node:path";

const ROOT = process.cwd();
const [kind, phase, ...rest] = process.argv.slice(2);
const flag = (k) => rest.includes(k);
const opt = (k) => { const i = rest.indexOf(k); return i >= 0 ? rest[i + 1] : undefined; };

const errors = [];
const warnings = [];
const err = (m) => errors.push(m);
const warn = (m) => warnings.push(m);
const read = (p) => readFileSync(join(ROOT, p), "utf8");
const git = (...a) => execFileSync("git", a, { encoding: "utf8", maxBuffer: 1 << 28 });
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

if (!["config", "code-plan", "implement"].includes(kind) || !/^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)*\.[0-9]+$/.test(phase || "")) {
  console.error("usage: impl-gate.mjs config|code-plan|implement <phase-id> [<base>] [--no-run] [--log <file>]");
  process.exit(64);
}

const CTX = `hsdd-context/${phase}.md`;
const DER = `hsdd-context/superpowers/${phase}.md`;
const PLAN = `docs/superpowers/plans/${phase}.md`;
const VERIFY = `hsdd/verify/${phase}.verification.md`;
const TEMPLATE = "hsdd/templates/verification.md";
const SKILL_TEMPLATE = ".agents/skills/hsdd-config/templates/verification.md";

// ---------- write sets ----------
const NEVER = [/^ref\//, /^\.agents\//, /^\.claude\//, /^skills-lock\.json$/, /^\.fvmrc$/, /^hsdd\/judgement\//,
  /^docs\/auto-run\/(?!steps\/|experiments\/)/];
const SCRATCH = [/^docs\/auto-run\/steps\//, /^docs\/auto-run\/experiments\//];
// Orchestrator-owned run files, edited between steps and committed with judgement commits:
// ignored in the working tree, never allowed in a step's own commits.
const ORCH = [/^docs\/auto-run\/impl-execution-plan\.md$/, /^docs\/auto-run\/tools\//, /^docs\/auto-run\/REPORT-impl[^/]*\.md$/];
const ALLOW = {
  config: [new RegExp(`^${esc(CTX)}$`), new RegExp(`^${esc(DER)}$`), new RegExp(`^${esc(TEMPLATE)}$`)],
  "code-plan": [new RegExp(`^${esc(PLAN)}$`)],
  // implement: anything outside hsdd/, docs/auto-run/, hsdd-context/ and docs/superpowers/plans/,
  // plus this phase's verification doc
  implement: [new RegExp(`^${esc(VERIFY)}$`), /^(?!hsdd\/|hsdd-context\/|docs\/superpowers\/plans\/|docs\/auto-run\/)/],
};

function uncommitted() {
  return git("status", "--porcelain", "--untracked-files=all").split("\n").filter(Boolean)
    .map((l) => l.slice(3).replace(/^"|"$/g, "").split(" -> ").pop())
    .filter((f) => !ORCH.some((r) => r.test(f)));
}

function checkWriteSet(files, label) {
  for (const f of files) {
    if (NEVER.some((r) => r.test(f)) && !(kind !== "implement" && SCRATCH.some((r) => r.test(f)))) {
      err(`${label}: ${f} is outside every step's write set`);
      continue;
    }
    if (SCRATCH.some((r) => r.test(f))) continue;
    if (!ALLOW[kind].some((r) => r.test(f))) err(`${label}: ${f} is outside the ${kind} write set`);
  }
}

// ---------- prose rules ----------
function proseCheck(text, where) {
  text.split("\n").forEach((l, i) => {
    if (l.includes("—")) err(`${where}:${i + 1}: em-dash`);
    if (/load-bearing/i.test(l)) err(`${where}:${i + 1}: "load-bearing"`);
  });
}

// ---------- derivative parsing ----------
function derivativeConstraints(der) {
  const m = der.match(/## Global Constraints\n([\s\S]*?)\n## Plan check/);
  if (!m) return null;
  const items = [];
  let cur = null;
  for (const line of m[1].split("\n")) {
    const n = line.match(/^(\d+)\.\s+(.*)$/);
    if (n) { if (cur) items.push(cur); cur = { n: Number(n[1]), text: n[2] }; }
    else if (cur && line.trim()) cur.text += " " + line.trim();
    else if (cur && !line.trim()) { items.push(cur); cur = null; }
  }
  if (cur) items.push(cur);
  return items;
}
const norm = (s) => s.replace(/[`*_]/g, "").replace(/\s+/g, " ").trim();

// ---------- kinds ----------
if (kind === "config") {
  checkWriteSet(uncommitted(), "working tree");
  for (const p of [CTX, DER]) if (!existsSync(join(ROOT, p))) err(`missing ${p}`);
  if (!errors.length) {
    const ctx = read(CTX);
    const der = read(DER);
    const stamp = ctx.split("\n")[0];
    const sm = stamp.match(/^<!-- hsdd-phase-context (\{.*\}) -->$/);
    if (!sm) err(`${CTX}: first line is not the hsdd-phase-context stamp`);
    else {
      const s = JSON.parse(sm[1]);
      if (s.phase !== phase) err(`${CTX}: stamp names phase ${s.phase}`);
      if (/-dirty$/.test(s.spec)) warn(`${CTX}: spec sha is dirty (${s.spec})`);
    }
    if (!/^<!-- hsdd-derivative \{"method":"superpowers"/.test(der.split("\n")[0])) err(`${DER}: first line is not the superpowers derivative stamp`);
    // hsdd-config step 11, the equality check
    const body = ctx.split("\n").slice(1).join("\n");
    const mm = der.match(/<!-- hsdd-phase-context:begin -->\n([\s\S]*?)\n?<!-- hsdd-phase-context:end -->/);
    if (!mm) err(`${DER}: no hsdd-phase-context markers`);
    else if (mm[1].replace(/\n+$/, "") !== body.replace(/\n+$/, "")) err(`${DER}: text between the markers differs from the generic body (equality check)`);
    const pre = der.split("<!-- hsdd-phase-context:begin -->")[0];
    const brace = pre.match(/\{(N|gate command|review tier|tier line|last|phase-id|spec-sha|YYYY-MM-DD|language|skill)\}/);
    if (brace) err(`${DER}: unfilled ${brace[0]}`);
    const gc = derivativeConstraints(der);
    if (!gc || gc.length < 8) err(`${DER}: Global Constraints has ${gc ? gc.length : 0} numbered items, expected at least 8`);
    proseCheck(pre, DER);
    // ids named in template-filled lines without a section (rule 2); excerpts may name others
    const ids = new Set([...ctx.matchAll(/\b([a-z][a-z-]*@v\d+)\b/g)].map((x) => x[1]));
    const missing = [...ids].filter((id) => !ctx.includes(`### ${id} ·`));
    if (missing.length) warn(`${CTX}: contract ids named without a Contracts subsection (inside excerpts?): ${missing.join(", ")}`);
    const adrs = new Set([...ctx.matchAll(/\bADR-(\d{3})\b/g)].map((x) => x[0]));
    const madr = [...adrs].filter((id) => !ctx.includes(`### ${id}:`));
    if (madr.length) warn(`${CTX}: ADR ids named without a Decisions subsection (inside excerpts?): ${madr.join(", ")}`);
  }
  if (!existsSync(join(ROOT, TEMPLATE))) err(`missing ${TEMPLATE}`);
  else {
    const t = read(TEMPLATE);
    if (!t.includes("## Learnings")) err(`${TEMPLATE}: no ## Learnings`);
    if (t !== read(SKILL_TEMPLATE)) warn(`${TEMPLATE} differs from the skill's template`);
  }
}

if (kind === "code-plan") {
  checkWriteSet(uncommitted(), "working tree");
  if (!existsSync(join(ROOT, PLAN))) err(`missing ${PLAN}`);
  if (!existsSync(join(ROOT, DER))) err(`missing ${DER}`);
  if (!errors.length) {
    const plan = read(PLAN);
    const der = read(DER);
    const nplan = norm(plan);
    const gc = derivativeConstraints(der) || [];
    for (const c of gc) if (!nplan.includes(norm(c.text))) err(`plan check: Global Constraint ${c.n} is not in the plan verbatim`);
    const nmax = Number((der.match(/The plan has at most (\d+) tasks/) || [])[1]);
    // tasks outside fenced code blocks
    let fence = false;
    const tasks = [];
    for (const line of plan.split("\n")) {
      if (/^```/.test(line)) fence = !fence;
      if (fence) continue;
      const t = line.match(/^###\s+Task\s+(\d+):/);
      if (t) tasks.push({ n: Number(t[1]), lines: [] });
      else if (tasks.length && /^#{1,2}\s/.test(line)) tasks.push({ n: -1, lines: [] }); // an h1 or h2 ends the task
      else if (tasks.length) tasks[tasks.length - 1].lines.push(line);
    }
    const real = tasks.filter((t) => t.n > 0);
    if (!real.length) err("plan check: no ### Task N: headings");
    if (nmax && real.length > nmax) err(`plan check: ${real.length} tasks, at most ${nmax}`);
    real.forEach((t, i) => {
      if (t.n !== i + 1) err(`plan check: task headings out of sequence at Task ${t.n}`);
      const first = t.lines.find((l) => /^- \[ \] \*\*Step/.test(l)) || "";
      const last = i === real.length - 1;
      if (!last && !/failing[- ]test/i.test(first)) err(`plan check: Task ${t.n} does not start with a failing-test step (${first.slice(0, 80)})`);
      if (last && !t.lines.join("\n").includes(VERIFY)) err(`plan check: the last task does not write ${VERIFY}`);
      if (last && /failing[- ]test/i.test(first)) warn(`plan check: the last task starts with a failing-test step`);
    });
    if (!plan.includes(DER)) warn(`plan does not name its derivative ${DER}`);
    proseCheck(plan, PLAN);
  }
}

if (kind === "implement") {
  const base = rest.find((a) => !a.startsWith("--") && a !== opt("--log"));
  if (!base) { console.error("implement needs <base>"); process.exit(64); }
  const ranged = git("diff", "--name-only", `${base}..HEAD`).split("\n").filter(Boolean);
  checkWriteSet(ranged, `${base}..HEAD`);
  const dirty = uncommitted().filter((f) => !SCRATCH.some((r) => r.test(f)));
  if (dirty.length) err(`working tree not clean: ${dirty.slice(0, 10).join(", ")}${dirty.length > 10 ? " ..." : ""}`);
  if (!ranged.includes(VERIFY)) err(`${VERIFY} not written in ${base}..HEAD`);
  if (existsSync(join(ROOT, VERIFY))) {
    const v = read(VERIFY);
    for (const h of ["## Commands to run", "## Expected output", "## Observed", "## Outstanding", "## Learnings", "## Sign-off"])
      if (!v.includes(h)) err(`${VERIFY}: missing ${h}`);
    const lm = v.match(/## Learnings\n([\s\S]*?)\n## /);
    if (lm) {
      const entries = lm[1].split("\n").filter((l) => /^- /.test(l));
      if (!entries.length) err(`${VERIFY}: Learnings is empty`);
      const DISP = /(spec-updated|contract-bumped \([^)]+\)|adr-proposed \([^)]+\)|dropped \([^)]+\))\.?\s*$/;
      for (const e of entries) if (e.trim() !== "- none" && !DISP.test(e)) warn(`${VERIFY}: Learning without a trailing disposition: ${e.slice(0, 100)}`);
    }
    if (/^- Reviewer \/ date:\s*\S/m.test(v)) warn(`${VERIFY}: Sign-off is filled; the run leaves it to the owner`);
  }
  // prose rules on added lines of non-generated text
  const diff = git("diff", "-U0", `${base}..HEAD`, "--", ".", ":(exclude)pubspec.lock");
  let file = "";
  for (const l of diff.split("\n")) {
    const f = l.match(/^\+\+\+ b\/(.*)$/);
    if (f) { file = f[1]; continue; }
    if (l.startsWith("+") && !l.startsWith("+++")) {
      if (l.includes("—")) err(`${file}: added line with an em-dash: ${l.slice(1, 90)}`);
      if (/load-bearing/i.test(l)) err(`${file}: added line with "load-bearing"`);
    }
  }
  // registries regenerate clean
  execFileSync("node", ["hsdd/scripts/gen-registry.mjs"], { stdio: "ignore" });
  const reg = uncommitted().filter((f) => f.startsWith("hsdd/"));
  if (reg.length) err(`gen-registry changed ${reg.join(", ")}`);
  // the phase gate
  if (!flag("--no-run")) {
    const ctx = read(CTX);
    const g = ctx.match(/^- \*\*Gate:\*\* `([^`]+)`/m);
    if (!g) err(`${CTX}: no Gate line`);
    else {
      console.log(`running gate: ${g[1]}`);
      const t0 = Date.now();
      const r = spawnSync("bash", ["-c", g[1]], { cwd: ROOT, encoding: "utf8", maxBuffer: 1 << 28 });
      const out = (r.stdout || "") + (r.stderr || "");
      const log = opt("--log");
      if (log) writeFileSync(log, `$ ${g[1]}\n${out}\nexit ${r.status} after ${Math.round((Date.now() - t0) / 1000)}s\n`);
      console.log(out.split("\n").slice(-40).join("\n"));
      console.log(`gate exit ${r.status} after ${Math.round((Date.now() - t0) / 1000)}s`);
      if (r.status !== 0) err(`phase gate exited ${r.status}`);
      const after = uncommitted().filter((f) => !SCRATCH.some((r) => r.test(f)));
      if (after.length) err(`the gate left changes in the tree: ${after.slice(0, 10).join(", ")}`);
    }
  }
}

for (const w of warnings) console.log(`warning: ${w}`);
for (const e of errors) console.log(`ERROR: ${e}`);
console.log(`${kind} ${phase}: ${errors.length} error(s), ${warnings.length} warning(s)`);
process.exit(errors.length ? 1 : 0);
