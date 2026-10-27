#!/usr/bin/env bash
# model-gate-reach (S137): can each unshipped nidana.model gate (.11 to .14)
# pass, case by case? A gate's replay restricted by --guarantee runs every
# case of each admitted guarantee (ADR-001 item 9), so a gate cannot pass
# when it admits a case that calls a body its phase's dependency closure has
# not delivered (D5: a gate replays what its closure has delivered).
#   A: scan.dart over the plan at HEAD (the Gates as S136 found them).
#   B: scan.dart over the plan in the working tree (after S137's amend).
#   V: validation of the static scan: the behavior sets of topic-model,
#      topology-dsl and topology-ir replayed unrestricted on today's code
#      (nidana.model.1 to .10 merged), and scan.dart --check, which compares
#      each case's static reach with whether it fails today. A case that
#      reaches no unimplemented body must pass today (a "MISS" otherwise).
# scan.dart's header states the method. Read-only: nothing tracked changes.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}
WORK=$(mktemp -d "${T%/}/mgr.XXXXXX")
cd "$REPO" || exit 1

echo "### A: the plan at HEAD ($(git rev-parse --short HEAD))"
git show HEAD:hsdd/spec/nidana.model.md > "$WORK/nidana.model.HEAD.md"
fvm dart "$HERE/scan.dart" "$WORK/nidana.model.HEAD.md" | sed "s#$WORK/#{tmp}/#g"

echo
echo "### B: the plan in the working tree (S137's amend)"
fvm dart "$HERE/scan.dart"

echo
echo "### V: the static scan against today's replay"
fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set behavior > "$WORK/replay.out" 2>&1
echo "replay exit: $?"
grep -E '^(PASS|FAIL) behavior' "$WORK/replay.out" | sed 's/; failed-case/\n  failed-case/g'
fvm dart "$HERE/scan.dart" --check "$WORK/replay.out"

rm -rf "$WORK"
echo
echo "done"
