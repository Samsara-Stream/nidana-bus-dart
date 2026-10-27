#!/usr/bin/env bash
# renderers-plan: runtime facts the nidana.model.14 plan depends on (S149).
# It replays the plan's task sequence in a temporary copy of the committed
# tree (git archive HEAD), with the files drafted under draft/, and records
# what each task's failing step and passing step print:
#   S1: the committed tree: the package tests and the gate's last replay.
#   T1, T2: each task's failing step (its new test files, and the replay of
#      G22's cases) and its passing step (the formatter, the package tests,
#      the root analyzer, the same replay). Task 1's renderers.dart is
#      derived by variants.py from the final draft, which is Task 2's.
#   X: the new files against draft/ after the formatter, and each new test
#      file's count.
#   G: the phase gate exactly as the phase context writes it.
#   C: the last task's checklist.
#   D: seeded defects (defects.py), each restored after, and which check
#      catches each: the package tests or the gate's topology-ir replay
#      (its behavior set, unrestricted, as the gate runs it).
# draft/ is evidence, not code to copy; the plan states what each task does.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/rp.XXXXXX")
V=$(mktemp -d "${T%/}/rp-v.XXXXXX") # variants, outside the analyzed tree
P=$WS/packages/nidana_dart_contracts
R=$P/lib/src/render/renderers.dart
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-400; }
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "-- nidana_contract_check $*"
  echo "PASS structure lines: $(grep -c '^PASS structure' "$WS/replay.out"); PASS schema lines: $(grep -c '^PASS schema' "$WS/replay.out")"
  grep -E '^FAIL|^PENDING|^PASS behavior|fixtures:|^exit:' "$WS/replay.out" | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
tests() {
  (cd "$WS" && fvm dart test "$@" > "$WS/tests.out" 2>&1; echo "exit: $?" >> "$WS/tests.out")
  echo "-- dart test $*"
  grep -E '\[E\]$|All tests passed|Some tests failed|No tests ran|^exit:' "$WS/tests.out" | sed 's/^[0-9:]* //' | sort -u | clip | head -n 40
  grep -E "^  (UnimplementedError|Expected|Actual|Which|Error: )|Error: Couldn't resolve|Error: Method not found|Error: Undefined name" "$WS/tests.out" | sort | uniq -c | clip | head -n 12
}
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 12 | clip; echo "analyze exit: ${PIPESTATUS[0]}"); }
fmt() { (cd "$WS" && fvm dart format packages/nidana_dart_contracts 2>&1 | tail -n 1 | clip); }
put() { mkdir -p "$(dirname "$P/$1")"; cp "$DRAFT/$1" "$P/$1"; }
GATE="fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir"
gate() {
  (cd "$WS" && bash -c "$1" > "$WS/gate.out" 2>&1; echo "gate exit: $?")
  grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed|^FAIL|^PENDING|^ERROR|^PASS behavior' "$WS/gate.out" | sed 's/^[0-9][0-9]:[0-9][0-9] //' | sed 's/; failed-case (/\n    failed-case (/g' | clip
  echo "PASS schema lines in the gate: $(grep -c '^PASS schema' "$WS/gate.out")"
}
seed() { # seed <label> <defect>
  local label=$1 defect=$2
  cp "$R" "$WS/seed.bak"
  echo "-- $label"
  python3 -I "$HERE/defects.py" "$R" "$defect" || { echo "   SEED FAILED"; cp "$WS/seed.bak" "$R"; return; }
  (cd "$WS" && fvm dart test packages/nidana_dart_contracts > "$WS/d.out" 2>&1)
  echo "   package tests: $(grep -E 'All tests passed|Some tests failed|Failed to load' "$WS/d.out" | tail -n 1 | sed 's/^[0-9:]* //' | cut -c1-60)"
  grep -E '\[E\]$' "$WS/d.out" | sed 's/^[0-9:]* +[0-9]* -[0-9]*: //; s/ \[E\]$//; s#packages/nidana_dart_contracts/test/##' | sort -u | sed 's/^/   failing: /' | cut -c1-220
  (cd "$WS" && fvm dart run nidana_contract_check topology-ir --set behavior > "$WS/d.out" 2>&1)
  echo "   gate topology-ir replay: $(grep -E '^(PASS|FAIL) behavior' "$WS/d.out" | sed 's/^.*: cases/cases/; s/^.*: \([0-9]* passed\)/\1/; s/; failed-case (/ | /g' | cut -c1-400)"
  cp "$WS/seed.bak" "$R"
}

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)
python3 -I "$HERE/variants.py" "$DRAFT/lib/src/render/renderers.dart" "$V"
cp "$V/renderers.t1.dart" "$V/fmt.dart"; fvm dart format "$V/fmt.dart" > /dev/null 2>&1
cmp -s "$V/fmt.dart" "$V/renderers.t1.dart" && echo "renderers.t1.dart is formatter-stable" || echo "renderers.t1.dart CHANGES under the formatter"

step "S1 the committed tree"
tests packages/nidana_dart_contracts
replay topic-model topology-dsl topology-ir
echo "stubs left under lib/src/render/: $(grep -c 'throw UnimplementedError()' "$R")"

step "T1.2 Task 1's failing step: test/src/render_support.dart, test/mermaid_renderer_test.dart and the G22 cases"
put test/src/render_support.dart
put test/mermaid_renderer_test.dart
tests packages/nidana_dart_contracts/test/mermaid_renderer_test.dart
replay topology-ir --set behavior --guarantee G22

step "T1.4 Task 1's library: MermaidRenderer and the shared label, duration and arrow helpers"
cp "$V/renderers.t1.dart" "$R"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G22
(cd "$WS" && fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G22 ' 2>&1 | grep -E '^  (UnimplementedError|package:nidana_dart_contracts/src/render)' | sort | uniq -c | clip)
echo "stubs left under lib/src/render/: $(grep -c 'throw UnimplementedError()' "$R")"

step "T2.2 Task 2's failing step: test/graphviz_renderer_test.dart and the G22 cases"
put test/graphviz_renderer_test.dart
tests packages/nidana_dart_contracts/test/graphviz_renderer_test.dart
replay topology-ir --set behavior --guarantee G22

step "T2.4 Task 2's library: GraphvizRenderer"
cp "$DRAFT/lib/src/render/renderers.dart" "$R"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G22
replay topic-model topology-dsl topology-ir
echo "stubs left under lib/src/render/: $(grep -c 'throw UnimplementedError()' "$R")"

step "X the new files against draft/ after the formatter, and each new test file's count"
for f in lib/src/render/renderers.dart test/src/render_support.dart test/mermaid_renderer_test.dart test/graphviz_renderer_test.dart; do
  cmp -s "$P/$f" "$DRAFT/$f" && echo "$f equals draft/$f" || echo "$f DIFFERS from draft/$f"
done
for f in mermaid_renderer_test.dart graphviz_renderer_test.dart; do
  (cd "$WS" && fvm dart test "packages/nidana_dart_contracts/test/$f" 2>&1 | grep -E 'All tests passed|Some tests failed' | tail -n 1 | sed "s/^[0-9:]* /$f: /")
done
(cd "$WS" && /usr/bin/time -p fvm dart test packages/nidana_dart_contracts 2>&1 | grep -E 'All tests passed|Some tests failed|^real' | sed 's/^[0-9:]* //' | clip)

step "G the phase gate, exactly as the phase context writes it"
gate "$GATE"

step "C the last task's checklist"
(cd "$WS" && fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G22 ' -r expanded 2>&1 | grep -E '^[0-9:]+ \+[0-9]+: (G|All)' | sed 's/^[0-9:]* //' | clip)
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/mermaid_renderer_test.dart packages/nidana_dart_contracts/test/graphviz_renderer_test.dart -j 1 -r expanded 2>&1 | grep -E '^[0-9:]+ \+[0-9]+: (packages|All)' | sed 's/^[0-9:]* //; s#packages/nidana_dart_contracts/test/##' | clip)
(cd "$WS" && grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/render; echo "exit: $?")
(cd "$WS" && grep -rnE "DateTime\.now\(|Stopwatch\(|Timer\(|Timer\.periodic\(|scheduleMicrotask\(|Future\.delayed\(|Future\.microtask\(|Random\(|Zone\." packages/nidana_dart_contracts/lib; echo "exit: $?")
(cd "$WS" && grep -rn "^import" packages/nidana_dart_contracts/lib/src/render/renderers.dart)
(cd "$WS" && wc -l packages/nidana_dart_contracts/lib/src/render/renderers.dart packages/nidana_dart_contracts/test/mermaid_renderer_test.dart packages/nidana_dart_contracts/test/graphviz_renderer_test.dart packages/nidana_dart_contracts/test/src/render_support.dart | clip)

step "D seeded defects: which check catches each"
seed "D1 Mermaid escapes # last, so it escapes its own escapes again" D1
seed "D2 Graphviz escapes the backslash last" D2
seed "D3 Mermaid escapes the joined label, its <br/> breaks included" D3
seed "D4 Mermaid also escapes &, which the rule leaves as it is" D4
seed "D5 Graphviz also escapes {, } and |, as for a record label" D5
seed "D6 an anonymous retry renders as 'retry null'" D6
seed "D7 a duration of a second or more renders in whole seconds" D7
seed "D8 a duration of a millisecond or more renders in whole milliseconds" D8
seed "D9 the duration goes on a line of its own" D9
seed "D10 the retry line comes before the transformer line" D10
seed "D11 a scope renders as Scope.page" D11
seed "D12 repeated arrows collapse into one" D12
seed "D13 topic ids keyed by name, so one name of two variants shares an id" D13
seed "D14 the sink output arrows come after every input arrow of the graph" D14
seed "D15 no newline after the last line" D15
seed "D16 Mermaid labels a dedup arrow with the enum's toString" D16

rm -rf "$WS" "$V"
