#!/usr/bin/env bash
# step-commit.sh: the second commit of a step in the implementation segment.
# Appends each report's decisions to hsdd/judgement/decisions.jsonl (skipping
# reports with none), appends the run line with `finished` stamped now,
# validates the ledger, and commits `judgement: <step_ref>` with the ledger and
# the named reports. Run from the repository root after the artifact commit.
#
# Usage:
#   step-commit.sh <step_ref> <ledger_step> <skill> <target> <started> <artifact_sha> <dispatches> \
#                  [--note <text>] [report.json ...]
set -euo pipefail

if [ $# -lt 7 ]; then
  sed -n '2,12p' "$0" >&2
  exit 64
fi
ref=$1 lstep=$2 skill=$3 target=$4 started=$5 sha=$6 disp=$7
shift 7
note=""
if [ "${1:-}" = "--note" ]; then note=$2; shift 2; fi

L=docs/auto-run/tools/ledger.mjs
for r in "$@"; do
  n=$(node -e 'const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const d=Array.isArray(p)?p:(p.decisions||[]);console.log(d.length)' "$r")
  if [ "$n" -gt 0 ]; then node "$L" decisions "$lstep" "$ref" "$sha" "$r"; fi
done
finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [ -n "$note" ]; then
  node "$L" run "$ref" "$skill" "$target" "$started" "$finished" "$sha" "$disp" "$note"
else
  node "$L" run "$ref" "$skill" "$target" "$started" "$finished" "$sha" "$disp"
fi
node "$L" validate
git add hsdd/judgement "$@"
git commit -q -F - <<EOF
judgement: $ref

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git log --oneline -1
