#!/usr/bin/env bash
# projection-graphs-plan: runtime facts the nidana.model.11 plan depends on
# (S140). It replays the plan's task sequence in a temporary copy of the
# committed tree (git archive HEAD), with the new files drafted under draft/
# and the edits to committed files in edits.py, and records what each task's
# failing step and passing step print:
#   S1: the committed tree: the package tests and every replay the gate runs.
#   B: every diagnostic the analyzer reports in the Dart libraries of every
#      slug's surface/, reject/ and behavior/, before any body lands.
#   T1 to T4: each task's failing step (its new test file, and the replay of
#      its guarantees) and its passing step (the formatter, the package
#      tests, the root analyzer, the same replay). Task 2's graph.dart is
#      derived from the final draft and HEAD (ShellClaim only).
#   X: the new files against draft/ after the formatter, and the diff of
#      every edited file against HEAD.
#   G: the phase gate exactly as the phase context writes it.
#   U: both contracts' behavior sets unrestricted, and the G3 case the
#      restriction leaves out that this phase reaches.
#   C: the last task's checklist.
#   A: every fixture diagnostic again, compared with B.
#   D: seeded defects, each restored after, and which check catches each.
# draft/ is evidence, not code to copy; the plan states what each task does.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/pgp.XXXXXX")
V=$(mktemp -d "${T%/}/pgp-v.XXXXXX") # variants, outside the analyzed tree
P=$WS/packages/nidana_dart_contracts
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-400; }
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "-- nidana_contract_check $*"
  echo "PASS structure lines: $(grep -c '^PASS structure' "$WS/replay.out")"
  grep -E '^FAIL|^PENDING|^PASS behavior|fixtures:|^exit:' "$WS/replay.out" | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
tests() {
  (cd "$WS" && fvm dart test "$@" > "$WS/tests.out" 2>&1; echo "exit: $?" >> "$WS/tests.out")
  echo "-- dart test $*"
  grep -E '\[E\]$|All tests passed|Some tests failed|No tests ran|^exit:' "$WS/tests.out" | sed 's/^[0-9:]* //' | sort -u | clip | head -n 40
  grep -E "^  (UnimplementedError|Expected|Actual|Which|Error: |Bad state)|Error: Couldn't resolve|Error: Method not found|Error: Undefined name|Error: The getter" "$WS/tests.out" | sort | uniq -c | clip | head -n 12
}
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 12 | clip; echo "analyze exit: ${PIPESTATUS[0]}"); }
fmt() { (cd "$WS" && fvm dart format packages/nidana_dart_contracts 2>&1 | tail -n 1 | clip); }
put() { mkdir -p "$(dirname "$P/$1")"; cp "$DRAFT/$1" "$P/$1"; }
edit() { python3 -I "$HERE/edits.py" "$P" "$1"; }
fixture_diagnostics() { # every (file, line, code) the analyzer reports in the fixtures' Dart sets
  (cd "$WS" && fvm dart analyze --format=json $(ls -d hsdd/contract/fixture/*/surface hsdd/contract/fixture/*/reject hsdd/contract/fixture/*/behavior 2>/dev/null) 2>/dev/null) \
    | sed -n 's/^.*\({"version".*\)$/\1/p' \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const r=j.diagnostics.map(d=>d.location.file.split("/hsdd/contract/fixture/")[1]+":"+d.location.range.start.line+" "+d.code);r.sort();console.log(r.join("\n"))})'
}
GATE='fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G8,G9,G10,G11,G12'
gate() {
  (cd "$WS" && bash -c "$1" > "$WS/gate.out" 2>&1; echo "gate exit: $?")
  grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed|^FAIL|^PENDING|^PASS behavior' "$WS/gate.out" | sed 's/^[0-9][0-9]:[0-9][0-9] //' | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
seed() { # seed <label> <edit set>
  local label=$1 set=$2
  (cd "$WS" && tar -cf "$WS/seed.tar" packages/nidana_dart_contracts/lib)
  echo "-- $label"
  edit "$set" > /dev/null || { echo "   SEED FAILED"; return; }
  (cd "$WS" && fvm dart test packages/nidana_dart_contracts > "$WS/d.out" 2>&1)
  echo "   package tests: $(grep -E 'All tests passed|Some tests failed' "$WS/d.out" | tail -n 1 | sed 's/^[0-9:]* //' | cut -c1-60)"
  grep -E '\[E\]$' "$WS/d.out" | sed 's/^[0-9:]* +[0-9]* -[0-9]*: //; s/ \[E\]$//' | sort -u | sed 's/^/   failing: /' | cut -c1-220
  (cd "$WS" && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G8,G9,G10,G11,G12 > "$WS/d.out" 2>&1)
  echo "   gate topology-ir replay: $(grep -E '^(PASS|FAIL) behavior' "$WS/d.out" | sed 's/^.*: cases/cases/; s/^.*: \([0-9]* passed\)/\1/; s/; failed-case (/ | /g' | cut -c1-300)"
  (cd "$WS" && fvm dart run nidana_contract_check topology-dsl --set behavior > "$WS/d.out" 2>&1)
  echo "   gate topology-dsl replay: $(grep -E '^(PASS|FAIL) behavior' "$WS/d.out" | sed 's/^.*: cases/cases/; s/^.*: \([0-9]* passed\)/\1/' | cut -c1-200)"
  (cd "$WS" && rm -rf packages/nidana_dart_contracts/lib && tar -xf "$WS/seed.tar")
}

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)
# Task 2's graph.dart: the final draft's ShellClaim (without the claim key,
# which Task 3 adds) above HEAD's TopologyGraph, extension and renderer.
python3 -I - "$DRAFT/lib/src/graph/graph.dart" "$P/lib/src/graph/graph.dart" "$V/graph.t2.dart" <<'PY'
import sys
final, head = (open(p).read() for p in sys.argv[1:3])
out = sys.argv[3]
mark = "/// Topologies and shell claims"
top = final[: final.index(mark)]
key = "  // The parts of this claim that the claim order compares.\n  ClaimKey get _key => (source: source, scope: scope, writes: writes);\n\n"
assert top.count(key) == 1
top = top.replace(key, "")
open(out, "w").write(top + head[head.index(mark):])
print("graph.t2.dart:", len((top + head[head.index(mark):]).splitlines()), "lines")
PY

step "S1 the committed tree"
tests packages/nidana_dart_contracts
replay topic-model topology-dsl
replay topology-ir --guarantee G2,G5,G6,G8,G9,G10,G11,G12

step "B every fixture diagnostic before any body lands (surface, reject and behavior of every slug)"
fixture_diagnostics > "$WS/fixtures.before"
echo "diagnostics: $(wc -l < "$WS/fixtures.before" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.before" | sort -u | wc -l | tr -d ' ') libraries"

step "T1.2 Task 1's failing step: test/projection_test.dart and the cases that call definition"
put test/projection_test.dart
tests packages/nidana_dart_contracts/test/projection_test.dart
replay topology-dsl --set behavior
replay topology-ir --set behavior --guarantee G8

step "T1.4 Task 1's library: the projection, the definition body, the recursive boundary test"
put lib/src/ir/projection.dart
edit t1
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-dsl --set behavior
replay topology-ir --set behavior --guarantee G8

step "T2.2 Task 2's failing step: test/shell_claim_test.dart and the G12 case"
put test/shell_claim_test.dart
tests packages/nidana_dart_contracts/test/shell_claim_test.dart
replay topology-ir --set behavior --guarantee G12

step "T2.4 Task 2's library: ShellClaim"
cp "$V/graph.t2.dart" "$P/lib/src/graph/graph.dart"
edit t2
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G12
echo "ignore lines in graph.dart: $(grep -c 'ignore:' "$P/lib/src/graph/graph.dart")"

step "T3.2 Task 3's failing step: test/topology_graph_test.dart and the G11 cases"
put test/topology_graph_test.dart
tests packages/nidana_dart_contracts/test/topology_graph_test.dart
replay topology-ir --set behavior --guarantee G11

step "T3.4 Task 3's library: TopologyGraph, toGraph and render"
put lib/src/graph/graph.dart
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G11
replay topology-ir --guarantee G2,G5,G6,G8,G9,G10,G11,G12
echo "ignore lines in graph.dart: $(grep -c 'ignore:' "$P/lib/src/graph/graph.dart")"

step "T4.2 Task 4's failing step: test/error_messages_test.dart"
put test/error_messages_test.dart
tests packages/nidana_dart_contracts/test/error_messages_test.dart

step "T4.4 Task 4's library: the messages"
edit t4
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-dsl --set behavior

step "X the new files against draft/ (formatter-stable), and the edited files against HEAD"
for f in lib/src/ir/projection.dart lib/src/graph/graph.dart test/projection_test.dart test/shell_claim_test.dart test/topology_graph_test.dart test/error_messages_test.dart; do
  cmp -s "$P/$f" "$DRAFT/$f" && echo "same: $f" || { echo "DIFFERS: $f"; diff "$DRAFT/$f" "$P/$f" | head -n 30; }
done
for f in lib/src/topology/topology.dart lib/src/topology/plan.dart lib/src/topology/builder.dart lib/src/topology/handle.dart lib/src/ir/definition.dart lib/src/topic/list_equality.dart test/canonical_order_test.dart; do
  echo "-- diff HEAD $f"
  git -C "$REPO" show "HEAD:packages/nidana_dart_contracts/$f" > "$V/head.dart"
  diff "$V/head.dart" "$P/$f"
done

step "G the phase gate, exactly as the phase context writes it"
gate "$GATE"

step "U both behavior sets unrestricted, and the G3 case this phase reaches"
replay topology-dsl --set behavior
replay topology-ir --set behavior
(cd "$WS" && fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --plain-name 'G3 the IR copies the lists it is given' 2>&1 | tail -n 1 | sed 's/^[0-9:]* //' | clip; echo "exit: ${PIPESTATUS[0]}")

step "C the last task's checklist"
(cd "$WS" && fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G(8|11|12) ' -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^$' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && fvm dart test hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart --name '^G(9|10|12) ' -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^$' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/projection_test.dart packages/nidana_dart_contracts/test/shell_claim_test.dart packages/nidana_dart_contracts/test/topology_graph_test.dart packages/nidana_dart_contracts/test/error_messages_test.dart -j 1 -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^$' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/graph packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?")
(cd "$WS" && grep -rn "ignore:" packages/nidana_dart_contracts/lib; echo "exit: $?")
(cd "$WS" && grep -rnE "^(import|export) .*graph/" packages/nidana_dart_contracts/lib/src/ir; echo "exit: $?")
(cd "$WS" && grep -rnE "is an '|'handle'|count inputs'" packages/nidana_dart_contracts/lib; echo "exit: $?")
echo "-- lines: library, then tests"
(cd "$WS" && for f in lib/src/ir/projection.dart lib/src/graph/graph.dart lib/src/topology/topology.dart lib/src/topology/plan.dart lib/src/topology/builder.dart lib/src/topology/handle.dart lib/src/ir/definition.dart; do echo "$f: $(git -C "$REPO" show HEAD:packages/nidana_dart_contracts/$f 2>/dev/null | wc -l | tr -d ' ') at HEAD, $(wc -l < packages/nidana_dart_contracts/$f | tr -d ' ') after"; done)
(cd "$WS" && wc -l packages/nidana_dart_contracts/test/projection_test.dart packages/nidana_dart_contracts/test/shell_claim_test.dart packages/nidana_dart_contracts/test/topology_graph_test.dart packages/nidana_dart_contracts/test/error_messages_test.dart)

step "A every fixture diagnostic after this phase's bodies, compared with B"
fixture_diagnostics > "$WS/fixtures.after"
echo "diagnostics: $(wc -l < "$WS/fixtures.after" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.after" | sort -u | wc -l | tr -d ' ') libraries"
diff "$WS/fixtures.before" "$WS/fixtures.after" > /dev/null && echo "same as B" || { echo "DIFFERS from B:"; diff "$WS/fixtures.before" "$WS/fixtures.after" | head -n 20; }
echo "const sets or maps in the new test files:"
(cd "$P/test" && grep -nE 'const <[^>]*>\{|const \{' projection_test.dart shell_claim_test.dart topology_graph_test.dart error_messages_test.dart; echo "grep exit: $?")

step "D seeded defects, each restored after"
seed "D1 the projection names a combine stage's apply, not its combiner" d1
seed "D2 a claim keeps a view of the caller's set, not a copy" d2
seed "D3 a claim hashes its writes by identity" d3
seed "D4 claims sort by source and scope only" d4
seed "D5 a graph's equality compares its topologies only" d5
seed "D6 a graph hashes its lists by identity" d6
seed "D7 a claim's writes keep the order they were given in" d7
seed "D8 a graph reads its topologies argument twice" d8

step "done"
rm -rf "$WS" "$V"
