#!/usr/bin/env node
// ledger.mjs: append to and validate the automatic run's judgement ledger.
// Zero dependencies. Validates against docs/auto-run/decision.schema.json by
// hand (required keys, enums, patterns), so the ledger never needs a JSON
// Schema library.
//
// Usage:
//   node docs/auto-run/tools/ledger.mjs decisions <step> <step_ref> <commit> <file.json>
//       <file.json> holds an array of decision objects without id/step/step_ref/commit,
//       or a step report (docs/auto-run/steps/*.json) whose `decisions` field is that array.
//       Each gets the next DEC id; `at` is kept when present, else stamped now.
//   node docs/auto-run/tools/ledger.mjs run <step_ref> <skill> <target> <started> <finished> <commit> [dispatches] [note]
//   node docs/auto-run/tools/ledger.mjs validate
//   node docs/auto-run/tools/ledger.mjs next-id

import { readFileSync, appendFileSync, existsSync, mkdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";

const ROOT = process.cwd();
const DIR = join(ROOT, "hsdd", "judgement");
const DECISIONS = join(DIR, "decisions.jsonl");
const RUN = join(DIR, "run.jsonl");

const STEPS = ["setup", "plan", "root-spec", "mid-level-spec", "adr", "contract", "phase-plan", "reconcile"];
const BLAST = ["node-local", "contract", "tree", "upstream"];
const CONF = ["high", "medium", "low"];
const STOP = ["axis", "shape", "upstream", "breaking-amend", "collision", "external", null];
const KEYS = ["id", "at", "step", "step_ref", "artifact", "question", "options", "chosen", "why", "evidence",
  "blast_radius", "confidence", "would_have_asked", "stop_class", "would_upstream", "commit"];
const REQUIRED = ["id", "at", "step", "question", "options", "chosen", "why", "evidence", "blast_radius",
  "confidence", "would_have_asked", "commit"];
const AT = /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(?::[0-9]{2})?(?:Z|[+-][0-9]{2}:[0-9]{2})$/;
const ART = /^(?!\/)(?!(?:.*\/)?\.\.(?:\/|$)).+$/;

const now = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

function lines(path) {
  if (!existsSync(path)) return [];
  return readFileSync(path, "utf8").split("\n").filter((l) => l.trim());
}

function commitExists(sha) {
  try {
    execFileSync("git", ["cat-file", "-e", `${sha}^{commit}`], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

export function check(d, where) {
  const errs = [];
  const e = (m) => errs.push(`${where}: ${m}`);
  for (const k of Object.keys(d)) if (!KEYS.includes(k)) e(`unknown key ${k}`);
  for (const k of REQUIRED) if (!(k in d)) e(`missing ${k}`);
  if (d.id !== undefined && !/^DEC-[0-9]{3,}$/.test(d.id)) e(`bad id ${d.id}`);
  if (d.at !== undefined && !AT.test(d.at)) e(`bad at ${d.at}`);
  if (d.step !== undefined && !STEPS.includes(d.step)) e(`bad step ${d.step}`);
  if ("step_ref" in d && typeof d.step_ref !== "string") e("step_ref not a string");
  if ("artifact" in d && d.artifact !== null && !(typeof d.artifact === "string" && ART.test(d.artifact)))
    e(`bad artifact ${d.artifact}`);
  for (const k of ["question", "chosen", "why"])
    if (k in d && !(typeof d[k] === "string" && d[k].length > 0)) e(`${k} empty`);
  if ("options" in d) {
    if (!Array.isArray(d.options) || d.options.length < 2) e("options needs >= 2 entries");
    else d.options.forEach((o, i) => {
      const ok = o && typeof o === "object" && Object.keys(o).every((k) => k === "label" || k === "consequence")
        && typeof o.label === "string" && o.label && typeof o.consequence === "string" && o.consequence;
      if (!ok) e(`option ${i} malformed`);
    });
    if (Array.isArray(d.options) && typeof d.chosen === "string" && !d.options.some((o) => o.label === d.chosen))
      e(`chosen "${d.chosen}" is not an option label`);
  }
  if ("evidence" in d && !(Array.isArray(d.evidence) && d.evidence.every((x) => typeof x === "string" && x)))
    e("evidence must be an array of non-empty strings");
  if ("blast_radius" in d && !BLAST.includes(d.blast_radius)) e(`bad blast_radius ${d.blast_radius}`);
  if ("confidence" in d && !CONF.includes(d.confidence)) e(`bad confidence ${d.confidence}`);
  if ("would_have_asked" in d && typeof d.would_have_asked !== "boolean") e("would_have_asked not boolean");
  if ("stop_class" in d && !STOP.includes(d.stop_class)) e(`bad stop_class ${d.stop_class}`);
  if (d.would_have_asked === true && !d.stop_class) e("would_have_asked true needs a stop_class");
  if ("would_upstream" in d && typeof d.would_upstream !== "boolean") e("would_upstream not boolean");
  if ("commit" in d && !/^[0-9a-f]{7,64}$/.test(d.commit)) e(`bad commit ${d.commit}`);
  return errs;
}

function nextId() {
  const ls = lines(DECISIONS);
  if (!ls.length) return 1;
  return Number(JSON.parse(ls[ls.length - 1]).id.slice(4)) + 1;
}

function validate() {
  const errs = [];
  const seen = new Set();
  let prev = 0;
  lines(DECISIONS).forEach((l, i) => {
    let d;
    try { d = JSON.parse(l); } catch { errs.push(`line ${i + 1}: not JSON`); return; }
    errs.push(...check(d, `line ${i + 1} ${d.id}`));
    const n = Number(String(d.id).slice(4));
    if (seen.has(d.id)) errs.push(`line ${i + 1}: duplicate ${d.id}`);
    if (n !== prev + 1) errs.push(`line ${i + 1}: ${d.id} out of order (prev DEC-${prev})`);
    seen.add(d.id);
    prev = n;
    if (d.commit && !commitExists(d.commit)) errs.push(`line ${i + 1}: commit ${d.commit} not in repo`);
  });
  lines(RUN).forEach((l, i) => {
    try {
      const r = JSON.parse(l);
      for (const k of ["step_ref", "skill", "target", "started", "finished", "commit"])
        if (!(k in r)) errs.push(`run line ${i + 1}: missing ${k}`);
      if (r.commit && !commitExists(r.commit)) errs.push(`run line ${i + 1}: commit ${r.commit} not in repo`);
    } catch { errs.push(`run line ${i + 1}: not JSON`); }
  });
  return errs;
}

const [cmd, ...a] = process.argv.slice(2);
if (cmd === "decisions") {
  const [step, stepRef, commit, file] = a;
  if (!commitExists(commit)) { console.error(`commit ${commit} not in repo`); process.exit(1); }
  const parsed = JSON.parse(readFileSync(file, "utf8"));
  const items = Array.isArray(parsed) ? parsed : parsed.decisions;
  if (!Array.isArray(items)) { console.error("file must hold an array or an object with a decisions array"); process.exit(1); }
  let n = nextId();
  const out = [];
  const errs = [];
  for (const [i, raw] of items.entries()) {
    const d = {
      id: `DEC-${String(n++).padStart(3, "0")}`,
      at: raw.at ?? now(),
      step,
      step_ref: stepRef,
      artifact: raw.artifact ?? null,
      question: raw.question,
      options: raw.options,
      chosen: raw.chosen,
      why: raw.why,
      evidence: raw.evidence ?? [],
      blast_radius: raw.blast_radius,
      confidence: raw.confidence,
      would_have_asked: raw.would_have_asked ?? false,
      stop_class: raw.would_have_asked ? (raw.stop_class ?? null) : null,
      would_upstream: raw.would_upstream ?? false,
      commit,
    };
    errs.push(...check(d, `item ${i}`));
    if (Date.parse(d.at) > Date.now() + 60_000) errs.push(`item ${i}: at ${d.at} is in the future`);
    out.push(d);
  }
  if (errs.length) { console.error(errs.join("\n")); process.exit(1); }
  mkdirSync(DIR, { recursive: true });
  appendFileSync(DECISIONS, out.map((d) => JSON.stringify(d)).join("\n") + "\n");
  console.log(`appended ${out.length}: ${out[0]?.id ?? "-"}..${out[out.length - 1]?.id ?? "-"}`);
} else if (cmd === "run") {
  const [stepRef, skill, target, started, finished, commit, dispatches, note] = a;
  if (!commitExists(commit)) { console.error(`commit ${commit} not in repo`); process.exit(1); }
  for (const t of [started, finished])
    if (!(Date.parse(t) <= Date.now() + 60_000)) { console.error(`time ${t} is invalid or in the future`); process.exit(1); }
  const r = { step_ref: stepRef, skill, target, started, finished, commit };
  if (dispatches) r.dispatches = Number(dispatches);
  if (note) r.note = note;
  mkdirSync(DIR, { recursive: true });
  appendFileSync(RUN, JSON.stringify(r) + "\n");
  console.log(`run: ${stepRef}`);
} else if (cmd === "validate") {
  const errs = validate();
  if (errs.length) { console.error(errs.join("\n")); process.exit(1); }
  console.log(`ledger ok: ${lines(DECISIONS).length} decisions, ${lines(RUN).length} run lines`);
} else if (cmd === "next-id") {
  console.log(`DEC-${String(nextId()).padStart(3, "0")}`);
} else {
  console.error("usage: ledger.mjs decisions|run|validate|next-id ...");
  process.exit(2);
}
