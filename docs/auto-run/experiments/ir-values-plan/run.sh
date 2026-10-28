#!/usr/bin/env bash
# ir-values-plan: runtime facts the nidana.model.10 plan depends on (S134).
# It replays the plan's task sequence in a temporary copy of the committed
# tree (git archive HEAD), with the files drafted under draft/, and records
# what each task's failing step and passing step print:
#   F1, F2: facts/facts.dart, run twice: how Object.hash treats a list, which
#      hash codes change between runs, what Set.unmodifiable and
#      List.unmodifiable keep, and what FunctionRef.of's rule yields for the
#      forms the plan's tests use.
#   S1: the committed tree: the package tests and every replay the gate runs.
#   B: every diagnostic the analyzer reports in the Dart libraries of every
#      slug's surface/, reject/ and behavior/, before any body lands.
#   T1 to T5: each task's failing step (its new test file, and the replay of
#      its guarantees restricted with --guarantee) and its passing step (the
#      formatter, the package tests, the root analyzer, the same replay).
#      Task 2's definition.dart is draft/lib/src/ir/definition.t2.dart, which
#      gen_variants.py derives from the final draft and HEAD.
#   G: the phase gate exactly as the phase context writes it.
#   U: the topology-ir behavior set unrestricted (information: which cases
#      pass after this phase).
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
WS=$(mktemp -d "${T%/}/ivp.XXXXXX")
P=$WS/packages/nidana_dart_contracts
IR=$P/lib/src/ir
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-300; }
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
  grep -E "^  (UnimplementedError|Expected|Error: |Bad state)|Error: Couldn't resolve|Error: Method not found|Error: Undefined name" "$WS/tests.out" | sort | uniq -c | clip | head -n 8
}
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 4 | clip; echo "analyze exit: ${PIPESTATUS[0]}"); }
fmt() { (cd "$WS" && fvm dart format packages/nidana_dart_contracts 2>&1 | tail -n 1 | clip); }
put_test() { mkdir -p "$(dirname "$P/test/$1")"; cp "$DRAFT/test/$1" "$P/test/$1"; }
put_lib() { cp "$DRAFT/lib/src/$1" "$P/lib/src/$2"; }
fixture_diagnostics() { # every (file, line, code) the analyzer reports in the fixtures' Dart sets
  (cd "$WS" && fvm dart analyze --format=json $(ls -d hsdd/contract/fixture/*/surface hsdd/contract/fixture/*/reject hsdd/contract/fixture/*/behavior 2>/dev/null) 2>/dev/null) \
    | sed -n 's/^.*\({"version".*\)$/\1/p' \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const r=j.diagnostics.map(d=>d.location.file.split("/hsdd/contract/fixture/")[1]+":"+d.location.range.start.line+" "+d.code);r.sort();console.log(r.join("\n"))})'
}
GATE='fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl --set structure,surface,reject && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G9,G10'
gate() { # gate <command>
  (cd "$WS" && bash -c "$1" > "$WS/gate.out" 2>&1; echo "gate exit: $?")
  grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed|^FAIL|^PENDING|^PASS behavior' "$WS/gate.out" | sed 's/^[0-9][0-9]:[0-9][0-9] //' | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
seed() { # seed <label> <file under lib/src> <python old> <python new> <check>...
  local label=$1 file=$P/lib/src/$2 old=$3 new=$4; shift 4
  cp "$file" "$WS/seed.bak"
  python3 -I -c 'import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
assert s.count(old) == 1, "seed text not found once in " + p
open(p, "w").write(s.replace(old, new))' "$file" "$old" "$new" || { echo "$label: SEED FAILED"; return; }
  echo "-- $label"
  local check
  for check in "$@"; do
    case $check in
      pkg) (cd "$WS" && fvm dart test packages/nidana_dart_contracts > "$WS/d.out" 2>&1); echo "   package tests: $(grep -E 'All tests passed|Some tests failed' "$WS/d.out" | tail -n 1 | sed 's/^[0-9:]* //' | cut -c1-60); failing: $(grep -oE '\[E\]$|: [^:]*\[E\]' "$WS/d.out" | sed 's/: //; s/ \[E\]//' | sort -u | tr '\n' ';' | cut -c1-400)" ;;
      gate) (cd "$WS" && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G9,G10 > "$WS/d.out" 2>&1); echo "   gate replay: $(grep -E '^(PASS|FAIL) behavior' "$WS/d.out" | sed 's/^.*: cases/cases/; s/; failed-case (/ | /g' | cut -c1-300)" ;;
    esac
  done
  cp "$WS/seed.bak" "$file"
}

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)
python3 -I "$HERE/gen_variants.py" "$REPO"

step "F1 facts/facts.dart, first run"
(cd "$HERE/facts" && fvm dart run facts.dart 2>&1) | tee "$WS/f1.out"
step "F2 facts/facts.dart, second run: the lines that differ from F1"
(cd "$HERE/facts" && fvm dart run facts.dart 2>&1) > "$WS/f2.out"
diff "$WS/f1.out" "$WS/f2.out"; echo "diff exit: $?"

step "S1 the committed tree"
tests packages/nidana_dart_contracts
replay topology-ir --guarantee G2,G5,G6,G9,G10
replay topology-ir --set behavior
replay topic-model
replay topology-dsl --set structure,surface,reject

step "B every fixture diagnostic before any body lands (surface, reject and behavior of every slug)"
fixture_diagnostics > "$WS/fixtures.before"
echo "diagnostics: $(wc -l < "$WS/fixtures.before" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.before" | sort -u | wc -l | tr -d ' ') libraries"

step "T1.2 Task 1's failing step: test/function_ref_test.dart and the G9 cases"
put_test function_ref_test.dart
tests packages/nidana_dart_contracts/test/function_ref_test.dart
replay topology-ir --set behavior --guarantee G9

step "T1.4 Task 1's library: FunctionRef"
put_lib ir/function_ref.dart ir/function_ref.dart
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G9

step "T2.2 Task 2's failing step: test/transform_edge_test.dart and the G5 and G10 cases"
put_test transform_edge_test.dart
tests packages/nidana_dart_contracts/test/transform_edge_test.dart
replay topology-ir --set behavior --guarantee G5,G10

step "T2.4 Task 2's library: edge inputs and TransformEdge"
put_lib ir/definition.t2.dart ir/definition.dart
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G5,G10
echo "ignore lines under lib/src/ir: $(grep -c 'ignore:' "$IR/definition.dart")"

step "T3.2 Task 3's failing step: test/canonical_order_test.dart"
put_test canonical_order_test.dart
tests packages/nidana_dart_contracts/test/canonical_order_test.dart

step "T3.4 Task 3's library: the canonical orders"
put_lib ir/canonical_order.dart ir/canonical_order.dart
fmt
tests packages/nidana_dart_contracts
analyze

step "T4.2 Task 4's failing step: test/topology_definition_test.dart and the G6 cases"
put_test src/cart_elsewhere.dart
put_test topology_definition_test.dart
tests packages/nidana_dart_contracts/test/topology_definition_test.dart
replay topology-ir --set behavior --guarantee G6

step "T4.4 Task 4's library: TopologyDefinition"
put_lib ir/definition.dart ir/definition.dart
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G6

step "T5.2 Task 5's failing step: test/findings_test.dart"
put_test findings_test.dart
tests packages/nidana_dart_contracts/test/findings_test.dart

step "T5.4 Task 5's library: the findings' value semantics"
put_lib analysis/findings.dart analysis/findings.dart
fmt
tests packages/nidana_dart_contracts
analyze

step "X the workspace's library and test files against draft/ (formatter-stable)"
for f in lib/src/ir/function_ref.dart lib/src/ir/definition.dart lib/src/ir/canonical_order.dart lib/src/analysis/findings.dart test/function_ref_test.dart test/transform_edge_test.dart test/canonical_order_test.dart test/topology_definition_test.dart test/src/cart_elsewhere.dart test/findings_test.dart; do
  cmp -s "$P/$f" "$DRAFT/$f" && echo "same: $f" || echo "DIFFERS: $f"
done

step "G the phase gate, exactly as the phase context writes it"
gate "$GATE"

step "U the topology-ir behavior set, unrestricted"
replay topology-ir --set behavior

step "C the last task's checklist"
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/function_ref_test.dart -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^$' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G9 ' -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^$' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/transform_edge_test.dart packages/nidana_dart_contracts/test/topology_definition_test.dart --name '^G[56] ' -j 1 -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^$' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/analysis/findings.dart; echo "exit: $?")
(cd "$WS" && grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/analysis; echo "exit: $?")
(cd "$WS" && grep -rn "graph/" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/analysis/findings.dart | grep -E "^[^:]*:[0-9]+:(import|export)"; echo "exit: $?")
echo "-- lines: library, then tests"
(cd "$WS" && wc -l packages/nidana_dart_contracts/lib/src/ir/*.dart packages/nidana_dart_contracts/lib/src/analysis/findings.dart | tail -n 1)
(cd "$WS" && wc -l packages/nidana_dart_contracts/test/function_ref_test.dart packages/nidana_dart_contracts/test/transform_edge_test.dart packages/nidana_dart_contracts/test/canonical_order_test.dart packages/nidana_dart_contracts/test/topology_definition_test.dart packages/nidana_dart_contracts/test/src/cart_elsewhere.dart packages/nidana_dart_contracts/test/findings_test.dart | tail -n 1)
(cd "$WS" && for f in function_ref definition canonical_order; do echo "$f: $(git -C "$REPO" show HEAD:packages/nidana_dart_contracts/lib/src/ir/$f.dart 2>/dev/null | wc -l | tr -d ' ') at HEAD, $(wc -l < packages/nidana_dart_contracts/lib/src/ir/$f.dart | tr -d ' ') after"; done; echo "findings: $(git -C "$REPO" show HEAD:packages/nidana_dart_contracts/lib/src/analysis/findings.dart | wc -l | tr -d ' ') at HEAD, $(wc -l < packages/nidana_dart_contracts/lib/src/analysis/findings.dart | tr -d ' ') after")

step "A every fixture diagnostic after this phase's bodies, compared with B"
fixture_diagnostics > "$WS/fixtures.after"
echo "diagnostics: $(wc -l < "$WS/fixtures.after" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.after" | sort -u | wc -l | tr -d ' ') libraries"
diff "$WS/fixtures.before" "$WS/fixtures.after" > /dev/null && echo "same as B" || { echo "DIFFERS from B:"; diff "$WS/fixtures.before" "$WS/fixtures.after" | head -n 20; }
echo "const-collection codes: $(grep -cE 'const_set_element_not_primitive_equality|const_map_key_not_primitive_equality' "$WS/fixtures.after")"
echo "const sets or maps in the new test files:"
(cd "$P/test" && grep -nE 'const <[^>]*>\{|const \{' function_ref_test.dart transform_edge_test.dart canonical_order_test.dart topology_definition_test.dart findings_test.dart; echo "grep exit: $?")

step "D seeded defects, each restored after"
seed "D1 FunctionRef.of drops the library key" ir/function_ref.dart \
  'return FunctionRef.named(rendering.substring(start, end));' \
  'return FunctionRef.named(rendering.substring(start, end).split("@").first);' gate pkg
seed "D2 an edge hashes its inputs list by identity (Object.hash of the list)" ir/definition.dart \
  'Object.hashAll(inputs),' 'inputs,' gate pkg
seed "D3 topic references sort their variants by name (event, replay, state)" ir/canonical_order.dart \
  'a.variant.index.compareTo(b.variant.index)' 'a.variant.name.compareTo(b.variant.name)' gate pkg
seed "D4 a definition accepts a negative stage input when assertions are off" ir/definition.dart \
  'if (from < 0 || from >= i) {' 'if (from >= i) {' gate pkg
seed "D5 combine takes a retry" ir/definition.dart \
  "  CombinatorKind.combine => (
    minInputs: 1,
    maxInputs: null,
    transformer: true,
    duration: false,
    retry: false," "  CombinatorKind.combine => (
    minInputs: 1,
    maxInputs: null,
    transformer: true,
    duration: false,
    retry: true," gate pkg
seed "D6 a writer conflict keeps the order it is given" analysis/findings.dart \
  'writers = sortedCopy(writers, compareMessageSources),' 'writers = List<MessageSource>.unmodifiable(writers),' gate pkg
seed "D7 a topic input ignores its dedup in equality" ir/definition.dart \
  'other is TopicInput && other.topic == topic && other.dedup == dedup;' 'other is TopicInput && other.topic == topic;' gate pkg
seed "D8 an edge keeps the list it is given" ir/definition.dart \
  'inputs: List<EdgeInput>.unmodifiable(inputs),' 'inputs: inputs,' gate pkg
seed "D9 the claim order puts a longer list first" ir/canonical_order.dart \
  'return left.length.compareTo(right.length);' 'return right.length.compareTo(left.length);' gate pkg
seed "D10 the claim order compares writes in the order given" ir/canonical_order.dart \
  'final List<TopicRef> left = sortedCopy(a.writes, compareTopicRefs);' 'final List<TopicRef> left = a.writes.toList();' gate pkg
seed "D11 a definition's equality ignores the order of its edges" ir/definition.dart \
  'elementsEqual(other.transforms, transforms);' 'other.transforms.toSet().containsAll(transforms) && other.transforms.length == transforms.length;' gate pkg
seed "D12 a collision orders its declarations by site only" analysis/findings.dart \
  'return bySite != 0 ? bySite : compareTopicRefs(a.topic, b.topic);' 'return bySite;' gate pkg
seed "D13 FunctionRef.named accepts an empty name" ir/function_ref.dart \
  "FunctionRef.named(String name) : name = _nonEmpty(name);" "FunctionRef.named(String name) : name = name;" gate pkg

rm -rf "$WS"
echo
echo "done"
