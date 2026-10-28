#!/usr/bin/env node
// decide.mjs: append one decision to a step report's `decisions` array, stamped
// now (HARNESS.md, What went wrong, item 2). Zero dependencies.
//
// Usage:
//   node docs/auto-run/tools/decide.mjs <report.json> <decision.json | ->
//       The decision is an object without `at` (stamped here); `-` reads it from stdin.
//       The report is created as { step_ref, decisions: [] } when absent, with
//       step_ref taken from the file name.

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { basename } from "node:path";
import { check } from "./ledger.mjs";

const [reportPath, src] = process.argv.slice(2);
if (!reportPath || !src) {
  console.error("usage: decide.mjs <report.json> <decision.json | ->");
  process.exit(64);
}
const raw = JSON.parse(src === "-" ? readFileSync(0, "utf8") : readFileSync(src, "utf8"));
const at = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
const d = { at, ...raw, at };
const probe = { id: "DEC-000", step: "implement", commit: "0000000", would_have_asked: false, ...d };
const errs = check(probe, "decision").filter((e) => !/DEC-000|0000000/.test(e));
if (errs.length) { console.error(errs.join("\n")); process.exit(1); }
const report = existsSync(reportPath)
  ? JSON.parse(readFileSync(reportPath, "utf8"))
  : { step_ref: basename(reportPath).split(".")[0], decisions: [] };
report.decisions = [...(report.decisions || []), d];
writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n");
console.log(`${reportPath}: ${report.decisions.length} decisions (last at ${at})`);
