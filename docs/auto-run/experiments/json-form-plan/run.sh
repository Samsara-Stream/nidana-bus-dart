#!/usr/bin/env bash
# json-form-plan: runtime facts the nidana.model.13 plan depends on (S146).
# It replays the plan's task sequence in a temporary copy of the committed
# tree (git archive HEAD), with the files drafted under draft/, and records
# what each task's failing step and passing step print:
#   S1: the committed tree: the package tests and every replay the gate runs.
#   F1, F2: what dart:convert does with the codec's values on the pinned SDK
#      (facts/json_layout.dart): JsonEncoder.withIndent's layout, escapes and
#      key order; the numbers jsonDecode returns; double.toInt; enum lookups;
#      ArgumentError's and FormatException's text.
#   F3: what the replay tool's validator, package:json_schema 5.2.2, says of
#      documents the governance does not settle in words
#      (facts/schema_verdicts.dart).
#   T1 to T3: each task's failing step (its new test files, and the replay
#      of its guarantees) and its passing step (the formatter, the package
#      tests, the root analyzer, the same replay). Task 1's and Task 2's
#      codec.dart and Task 1's test/src/json_support.dart are derived by
#      variants.py from the final drafts.
#   I: the final draft against every valid/ and invalid/ file, one by one,
#      beside the schema's verdict (facts/fixtures_one_by_one.dart).
#   F4: what the property tests' generators reach, against the final draft
#      and against Task 2's codec (facts/property_counts_test.dart).
#   F5: how long the new test files take.
#   X: the new files against draft/ after the formatter.
#   G: the phase gate exactly as the phase context writes it.
#   U: the topology-ir behavior set unrestricted (what waits for
#      nidana.model.14).
#   C: the last task's searches.
#   D: seeded defects (defects.py), each restored after, and which check
#      catches each: the package tests or the gate's topology-ir replay.
# draft/ is evidence, not code to copy; the plan states what each task does.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/jfp.XXXXXX")
V=$(mktemp -d "${T%/}/jfp-v.XXXXXX") # variants, outside the analyzed tree
P=$WS/packages/nidana_dart_contracts
C=$P/lib/src/json/codec.dart
TOOL=$WS/packages/nidana_contract_check/tool
RESTRICTION=G2,G4,G5,G6,G8,G9,G10,G11,G12,G19,G20,G21
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
  grep -E '\[E\]$|All tests passed|Some tests failed|No tests ran|^exit:' "$WS/tests.out" | sed 's/^[0-9:]* //' | sort -u | clip | head -n 60
  grep -E "^  (UnimplementedError|Expected|Actual|Which|Error: |Bad state|Unsupported|Invalid argument|Failed assertion|FormatException)|Error: Couldn't resolve|Error: Method not found|Error: Undefined name|Error: The getter" "$WS/tests.out" | sort | uniq -c | clip | head -n 16
}
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 12 | clip; echo "analyze exit: ${PIPESTATUS[0]}"); }
fmt() { (cd "$WS" && fvm dart format packages/nidana_dart_contracts 2>&1 | tail -n 1 | clip); }
put() { mkdir -p "$(dirname "$P/$1")"; cp "$DRAFT/$1" "$P/$1"; }
tool() { # tool <facts file>: run it from the workspace root, then remove it
  mkdir -p "$TOOL"
  cp "$HERE/facts/$1" "$TOOL/$1"
  (cd "$WS" && fvm dart run "packages/nidana_contract_check/tool/$1" 2>&1 | clip)
  rm -rf "$TOOL"
}
counts() { # counts <label>: F4 against the codec.dart in place
  cp "$HERE/facts/property_counts_test.dart" "$P/test/facts_property_counts_test.dart"
  echo "-- $1"
  (cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/facts_property_counts_test.dart -r expanded 2>&1 | grep -E '^F4|tests passed|failed' | sed 's/^[0-9:]* //' | clip)
  rm -f "$P/test/facts_property_counts_test.dart"
}
GATE="fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee $RESTRICTION"
gate() {
  (cd "$WS" && bash -c "$1" > "$WS/gate.out" 2>&1; echo "gate exit: $?")
  grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed|^FAIL|^PENDING|^ERROR|^PASS behavior' "$WS/gate.out" | sed 's/^[0-9][0-9]:[0-9][0-9] //' | sed 's/; failed-case (/\n    failed-case (/g' | clip
  echo "PASS schema lines in the gate: $(grep -c '^PASS schema' "$WS/gate.out")"
}
seed() { # seed <label> <defect>
  local label=$1 defect=$2
  cp "$C" "$WS/seed.bak"
  echo "-- $label"
  python3 -I "$HERE/defects.py" "$C" "$defect" || { echo "   SEED FAILED"; cp "$WS/seed.bak" "$C"; return; }
  (cd "$WS" && fvm dart test packages/nidana_dart_contracts > "$WS/d.out" 2>&1)
  echo "   package tests: $(grep -E 'All tests passed|Some tests failed' "$WS/d.out" | tail -n 1 | sed 's/^[0-9:]* //' | cut -c1-60)"
  grep -E '\[E\]$' "$WS/d.out" | sed 's/^[0-9:]* +[0-9]* -[0-9]*: //; s/ \[E\]$//' | sort -u | sed 's/^/   failing: /' | cut -c1-220
  (cd "$WS" && fvm dart run nidana_contract_check topology-ir --guarantee $RESTRICTION > "$WS/d.out" 2>&1)
  echo "   gate topology-ir replay: $(grep -E '^(PASS|FAIL) behavior' "$WS/d.out" | sed 's/^.*: cases/cases/; s/^.*: \([0-9]* passed\)/\1/; s/; failed-case (/ | /g' | cut -c1-400)"
  cp "$WS/seed.bak" "$C"
}

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)
python3 -I "$HERE/variants.py" "$DRAFT/lib/src/json/codec.dart" "$DRAFT/test/src/json_support.dart" "$V"
for f in codec.t1.dart codec.t2.dart json_support.t1.dart; do
  cp "$V/$f" "$V/fmt.dart"; fvm dart format "$V/fmt.dart" > /dev/null 2>&1
  cmp -s "$V/fmt.dart" "$V/$f" && echo "$f is formatter-stable" || echo "$f CHANGES under the formatter"
done

step "S1 the committed tree"
tests packages/nidana_dart_contracts
replay topic-model topology-dsl
replay topology-ir --guarantee $RESTRICTION
echo "stubs left under lib/src/json/: $(grep -c 'throw UnimplementedError()' "$C")"

step "F1 F2 dart:convert on the pinned SDK"
(cd "$HERE/facts" && fvm dart run json_layout.dart 2>&1 | clip)

step "F3 the replay tool's validator on documents the governance does not settle in words"
tool schema_verdicts.dart

step "T1.2 Task 1's failing step: test/src/json_support.dart (Task 1's part), test/json_encode_test.dart and the G19 cases"
cp "$V/json_support.t1.dart" "$P/test/src/json_support.dart"
put test/json_encode_test.dart
tests packages/nidana_dart_contracts/test/json_encode_test.dart
replay topology-ir --set behavior --guarantee G19

step "T1.4 Task 1's library: the encoder and JsonRenderer"
cp "$V/codec.t1.dart" "$C"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G19

step "T2.2 Task 2's failing step: test/src/json_support.dart (whole), test/json_decode_test.dart and the G4, G20 and G21 cases"
put test/src/json_support.dart
put test/json_decode_test.dart
tests packages/nidana_dart_contracts/test/json_decode_test.dart
replay topology-ir --set behavior --guarantee G4,G20,G21

step "T2.4 Task 2's library: the decoder reads every document of the right shape"
cp "$V/codec.t2.dart" "$C"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G4,G20,G21

step "T3.2 Task 3's failing step: test/json_reject_test.dart and the G21 cases"
put test/json_reject_test.dart
tests packages/nidana_dart_contracts/test/json_reject_test.dart
replay topology-ir --set behavior --guarantee G21
counts "F4 against Task 2's codec"

step "T3.4 Task 3's library: the decoder's rules"
cp "$DRAFT/lib/src/json/codec.dart" "$C"
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-ir --set behavior --guarantee G21
replay topology-ir --guarantee $RESTRICTION
echo "stubs left under lib/src/json/: $(grep -c 'throw UnimplementedError()' "$C")"

step "I the final draft against every valid/ and invalid/ file, one by one"
tool fixtures_one_by_one.dart

step "F4 what the property tests' generators reach, against the final draft"
counts "F4 against the final codec"

step "F5 how long the new test files take"
(cd "$WS" && /usr/bin/time -p fvm dart test packages/nidana_dart_contracts/test/json_encode_test.dart packages/nidana_dart_contracts/test/json_decode_test.dart packages/nidana_dart_contracts/test/json_reject_test.dart 2>&1 | grep -E 'All tests passed|Some tests failed|^real' | sed 's/^[0-9:]* //' | clip)
(cd "$WS" && /usr/bin/time -p fvm dart test packages/nidana_dart_contracts 2>&1 | grep -E 'All tests passed|Some tests failed|^real' | sed 's/^[0-9:]* //' | clip)

step "X the new files against draft/ after the formatter"
for f in lib/src/json/codec.dart test/src/json_support.dart test/json_encode_test.dart test/json_decode_test.dart test/json_reject_test.dart; do
  cmp -s "$P/$f" "$DRAFT/$f" && echo "$f equals draft/$f" || echo "$f DIFFERS from draft/$f"
done
for f in json_encode_test.dart json_decode_test.dart json_reject_test.dart; do
  (cd "$WS" && fvm dart test "packages/nidana_dart_contracts/test/$f" 2>&1 | grep -E 'All tests passed|Some tests failed' | tail -n 1 | sed "s/^[0-9:]* /$f: /")
done

step "G the phase gate, exactly as the phase context writes it"
gate "$GATE"

step "U the topology-ir behavior set unrestricted"
replay topology-ir --set behavior

step "C the last task's checklist"
(cd "$WS" && fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G(4|19|20|21) ' -r expanded 2>&1 | grep -E '^[0-9:]+ \+[0-9]+: (G|All)' | sed 's/^[0-9:]* //' | clip)
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/json_encode_test.dart packages/nidana_dart_contracts/test/json_decode_test.dart packages/nidana_dart_contracts/test/json_reject_test.dart -j 1 -r expanded 2>&1 | grep -E 'All tests passed|Some tests failed' | sed 's/^[0-9:]* //' | clip)
(cd "$WS" && grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/json; echo "exit: $?")
(cd "$WS" && grep -rnE "DateTime\.now\(|Stopwatch\(|Timer\(|Timer\.periodic\(|scheduleMicrotask\(|Future\.delayed\(|Future\.microtask\(|Random\(|Zone\." packages/nidana_dart_contracts/lib; echo "exit: $?")
(cd "$WS" && grep -rn "^import" packages/nidana_dart_contracts/lib/src/json/codec.dart)
(cd "$WS" && grep -c "" packages/nidana_dart_contracts/lib/src/json/codec.dart | sed 's/^/codec.dart lines: /')
(cd "$WS" && wc -l packages/nidana_dart_contracts/test/json_*.dart packages/nidana_dart_contracts/test/src/json_support.dart | clip)

step "D seeded defects: which check catches each"
seed "D1 the encoder writes dedup as null when the read gave none" D1
seed "D2 the encoder writes an edge's transformer before its output" D2
seed "D3 JsonRenderer ends without a newline" D3
seed "D4 JsonRenderer indents by four spaces" D4
seed "D5 the encoder writes durations in milliseconds" D5
seed "D6 the decoder lets a repeated topology id collapse" D6
seed "D7 the decoder lets repeated topics collapse in reads, writes and claims" D7
seed "D8 the decoder lets a claim's repeated topics collapse" D8
seed "D9 the decoder does not compare reads with the edges" D9
seed "D10 the decoder accepts a dedup on a replay read" D10
seed "D11 the decoder accepts an empty typeName" D11
seed "D12 a negative index reaches StageInput's assert" D12
seed "D13 the decoder rejects a whole-number double" D13
seed "D14 the factories' ArgumentError leaks" D14
seed "D15 an unknown enum name throws ArgumentError (values.byName)" D15
seed "D16 a message renders the value with jsonEncode" D16
seed "D17 the decoder merges equal claims" D17

rm -rf "$WS" "$V"
