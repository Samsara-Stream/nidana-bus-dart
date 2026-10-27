#!/usr/bin/env bash
# topic-model-values-plan: runtime facts the nidana.model.8 plan depends on
# (S124). It replays the plan's task sequence in a temporary copy of the
# committed tree (git archive HEAD), with the files drafted under draft/, and
# records what each task's failing step and passing step print:
#   F: facts/facts.dart run twice, in two processes, and the lines that
#      differ between the runs (hash codes seeded per run).
#   S: the committed tree: the package tests and the unrestricted
#      topic-model replay (the 32 failing behavior cases, by name).
#   B: every diagnostic the analyzer reports in the Dart libraries of every
#      slug's surface/, reject/ and behavior/, before any body lands.
#   A0: probe/const_collections_probe.dart against the committed declarations.
#   T1 to T5: each task's failing step (its new test file, and the replay of
#      its guarantees restricted with --guarantee) and its passing step (the
#      formatter, the package tests, the root analyzer, the same replay).
#   G: the phase gate, as the phase context writes it.
#   C: the last task's checklist.
#   A: the probe against the drafted declarations, and every fixture
#      diagnostic again, compared with B; the two const-collection codes.
#   D: seeded defects, each restored after, and which check catches each.
#   X: every Dart block of the plan against draft/.
# draft/ is evidence, not code to copy; the plan states what each task does.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/tmvp.XXXXXX")
P=$WS/packages/nidana_dart_contracts
step() { echo; echo "### $*"; }
clip() { sed "s#$WS#{ws}#g; s#$(cd "$WS" && pwd -P)#{ws}#g" | cut -c1-400; }
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "-- nidana_contract_check $*"
  echo "PASS structure lines: $(grep -c '^PASS structure' "$WS/replay.out")"
  grep -vE '^PASS structure|^running ' "$WS/replay.out" | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
tests() {
  (cd "$WS" && fvm dart test "$@" > "$WS/tests.out" 2>&1; echo "exit: $?" >> "$WS/tests.out")
  echo "-- dart test $*"
  grep -E '^\s*[0-9]+:[0-9]+ \+[0-9]+.*(\[E\]|All tests passed|Some tests failed)|Error:|Expected:|Actual:|Which:|UnimplementedError|^exit:' "$WS/tests.out" | sed 's/^[0-9:]* //' | sort -u | clip | head -n 40
}
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 6 | clip; echo "analyze exit: ${PIPESTATUS[0]}"); }
fmt() { (cd "$WS" && fvm dart format --output=none --set-exit-if-changed packages/nidana_dart_contracts 2>&1 | tail -n 3 | clip; echo "format exit: ${PIPESTATUS[0]}"); }
put() { mkdir -p "$(dirname "$P/$2")"; cp "$DRAFT/$1" "$P/$2"; }
fixture_diagnostics() { # every (file, line, code) the analyzer reports in the fixtures' Dart sets
  (cd "$WS" && fvm dart analyze --format=json $(ls -d hsdd/contract/fixture/*/surface hsdd/contract/fixture/*/reject hsdd/contract/fixture/*/behavior 2>/dev/null) 2>/dev/null) \
    | sed -n 's/^.*\({"version".*\)$/\1/p' \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const r=j.diagnostics.map(d=>d.location.file.split("/hsdd/contract/fixture/")[1]+":"+d.location.range.start.line+" "+d.code);r.sort();console.log(r.join("\n"))})'
}

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)

step "F facts/facts.dart, two runs; the lines that differ are run-dependent"
(cd "$HERE/facts" && fvm dart run facts.dart > "$WS/f1.txt" 2>&1; fvm dart run facts.dart > "$WS/f2.txt" 2>&1)
cat "$WS/f1.txt"
echo "-- lines that differ between the two runs (run 1 | run 2):"
paste -d '|' "$WS/f1.txt" "$WS/f2.txt" | awk -F'|' '$1 != $2 {print "  " $1 " | " $2}'

step "S1 the committed tree"
tests packages/nidana_dart_contracts
replay topic-model

step "B every fixture diagnostic before any body lands (surface, reject and behavior of every slug)"
fixture_diagnostics > "$WS/fixtures.before"
echo "diagnostics: $(wc -l < "$WS/fixtures.before" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.before" | sort -u | wc -l | tr -d ' ') libraries"
echo "const-collection codes: $(grep -cE 'const_set_element_not_primitive_equality|const_map_key_not_primitive_equality' "$WS/fixtures.before")"

step "A0 the probe against the committed declarations (Object's ==)"
cp "$HERE/probe/const_collections_probe.dart" "$P/test/const_collections_probe.dart"
(cd "$WS" && fvm dart analyze --fatal-infos packages/nidana_dart_contracts/test/const_collections_probe.dart 2>&1 | grep -E ' - |No issues' | clip)
rm "$P/test/const_collections_probe.dart"

step "T1.2 Task 1's failing step: test/topic_test.dart and the G7, G8, G9 and G11 cases"
put test/topic_test.dart test/topic_test.dart
tests packages/nidana_dart_contracts/test/topic_test.dart
replay topic-model --set behavior --guarantee G7,G8,G9,G11

step "T1.4 lib/src/topic/topic.dart"
put lib/src/topic/topic.dart lib/src/topic/topic.dart
fmt
tests packages/nidana_dart_contracts
analyze
replay topic-model --set behavior --guarantee G7,G8,G9,G11

step "T2.2 Task 2's failing step: the source and redaction tests and the G17, G21, G23 and G24 cases"
put test/message_source_test.dart test/message_source_test.dart
put test/redacted_payload_test.dart test/redacted_payload_test.dart
tests packages/nidana_dart_contracts/test/message_source_test.dart packages/nidana_dart_contracts/test/redacted_payload_test.dart
replay topic-model --set behavior --guarantee G17,G21,G23,G24

step "T2.4 message_source.dart, scope.dart, observer.dart, redacted_payload.dart"
for f in message_source scope observer redacted_payload; do put "lib/src/topic/$f.dart" "lib/src/topic/$f.dart"; done
fmt
tests packages/nidana_dart_contracts
analyze
replay topic-model --set behavior --guarantee G17,G21,G23,G24

step "T3.2 Task 3's failing step: test/lineage_test.dart and the G4, G18 and G20 cases"
put test/lineage_test.dart test/lineage_test.dart
tests packages/nidana_dart_contracts/test/lineage_test.dart
replay topic-model --set behavior --guarantee G4,G18,G20

step "T3.4 list_equality.dart, lineage.dart without combine, envelope.dart's copy"
put lib/src/topic/list_equality.dart lib/src/topic/list_equality.dart
put lib/src/topic/lineage.t3.dart lib/src/topic/lineage.dart
put lib/src/topic/envelope.t3.dart lib/src/topic/envelope.dart
fmt
tests packages/nidana_dart_contracts
analyze
replay topic-model --set behavior --guarantee G4,G18,G20

step "T4.2 Task 4's failing step: test/lineage_property_test.dart and the G4 and G19 cases"
put test/lineage_property_test.dart test/lineage_property_test.dart
tests packages/nidana_dart_contracts/test/lineage_property_test.dart
replay topic-model --set behavior --guarantee G4,G19

step "T4.4 Lineage.combine and the README"
put lib/src/topic/lineage.dart lib/src/topic/lineage.dart
put README.md README.md
fmt
tests packages/nidana_dart_contracts
analyze
replay topic-model --set behavior --guarantee G4,G19
echo "-- the property test's run time:"
(cd "$WS" && /usr/bin/time -p fvm dart test packages/nidana_dart_contracts/test/lineage_property_test.dart 2>&1 | grep -E 'All tests|^real' | sed 's/^[0-9:]* //')

step "T5.2 Task 5's failing step: test/envelope_test.dart and the G13, G14 and G15 cases"
put test/envelope_test.dart test/envelope_test.dart
tests packages/nidana_dart_contracts/test/envelope_test.dart
replay topic-model --set behavior --guarantee G13,G14,G15

step "T5.4 envelope.dart"
put lib/src/topic/envelope.dart lib/src/topic/envelope.dart
fmt
tests packages/nidana_dart_contracts
analyze
replay topic-model --set behavior --guarantee G13,G14,G15
replay topic-model

step "G the phase gate, from the workspace root"
(cd "$WS" && bash -c 'fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl topology-ir --set structure,surface,reject,schema' > "$WS/gate.out" 2>&1; echo "gate exit: $?")
grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed|^FAIL|^PENDING' "$WS/gate.out" | sed 's/^[0-9][0-9]:[0-9][0-9] //' | clip
grep -E ' - .* - [a-z_]+$' "$WS/gate.out" | clip

step "C the last task's checklist"
(cd "$WS" && fvm dart test hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart --name '^G19 a (same-correlation combine keeps|cross-correlation combine takes)' -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/envelope_test.dart --name 'G15' -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/topic; echo "exit: $?")
(cd "$WS" && grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/topic; echo "exit: $?")
(cd "$WS" && grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?")
(cd "$WS" && grep -rnE "Random\(|DateTime\.now\(" packages/nidana_dart_contracts/lib; echo "exit: $?")
(cmp -s "$WS/pubspec.lock" "$REPO/pubspec.lock" && echo "pubspec.lock unchanged")
(cd "$WS" && for f in packages/nidana_dart_contracts/lib/src/topic/*.dart packages/nidana_dart_contracts/README.md; do git -C "$REPO" show "HEAD:${f}" 2>/dev/null | diff - "$f" | grep -c '^[<>]' | sed "s#^#changed lines in ${f#packages/nidana_dart_contracts/}: #"; done)
(cd "$WS" && wc -l packages/nidana_dart_contracts/lib/src/topic/*.dart packages/nidana_dart_contracts/test/topic_test.dart packages/nidana_dart_contracts/test/message_source_test.dart packages/nidana_dart_contracts/test/redacted_payload_test.dart packages/nidana_dart_contracts/test/lineage_test.dart packages/nidana_dart_contracts/test/lineage_property_test.dart packages/nidana_dart_contracts/test/envelope_test.dart | clip)

step "A the probe against the drafted declarations; every fixture diagnostic again"
cp "$HERE/probe/const_collections_probe.dart" "$P/test/const_collections_probe.dart"
(cd "$WS" && fvm dart analyze --fatal-infos packages/nidana_dart_contracts/test/const_collections_probe.dart 2>&1 | grep -E ' - |No issues' | clip)
rm "$P/test/const_collections_probe.dart"
fixture_diagnostics > "$WS/fixtures.after"
echo "diagnostics: $(wc -l < "$WS/fixtures.after" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.after" | sort -u | wc -l | tr -d ' ') libraries"
echo "const-collection codes: $(grep -cE 'const_set_element_not_primitive_equality|const_map_key_not_primitive_equality' "$WS/fixtures.after")"
echo "-- diff before/after (none expected):"
diff "$WS/fixtures.before" "$WS/fixtures.after" && echo "  identical"
echo "-- const set or map literals with elements in the package and in every fixture Dart file (text search, implicit const contexts included by eye):"
(cd "$WS" && grep -rnE "const\s*(<[^>]*>)?\s*\{\s*[^} ]" packages/nidana_dart_contracts hsdd/contract/fixture --include='*.dart' | grep -vE "ObserverCapability|<String, (String|Object\?)>" > "$WS/consts.txt"; clip < "$WS/consts.txt"; echo "lines: $(wc -l < "$WS/consts.txt" | tr -d ' ')")

step "D seeded defects, each restored after"
seed() { # seed <label> <file> <old> <new>
  cp "$2" "$WS/seed.bak"
  python3 - "$2" "$3" "$4" <<'PY'
import sys, pathlib
f, a, b = pathlib.Path(sys.argv[1]), sys.argv[2].encode().decode('unicode_escape'), sys.argv[3].encode().decode('unicode_escape')
t = f.read_text(); assert t.count(a) == 1, a; f.write_text(t.replace(a, b))
PY
  echo "-- $1"
}
restore() { cp "$WS/seed.bak" "$1"; }
seed "D1 Topic without its hashCode override" "$P/lib/src/topic/topic.dart" "  @override\n  int get hashCode => Object.hash(variant, name, valueType);\n" ""
analyze
restore "$P/lib/src/topic/topic.dart"
seed "D2 createInitial as _constant ?? _factory!()" "$P/lib/src/topic/topic.dart" "    return factory == null ? _constant as T : factory();" "    return _constant ?? factory!();"
tests packages/nidana_dart_contracts/test/topic_test.dart
restore "$P/lib/src/topic/topic.dart"
seed "D3 a topic name matched by one multi-line pattern" "$P/lib/src/topic/topic.dart" "final RegExp _segment = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*\$');" "final RegExp _segment = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*\$', multiLine: true);"
tests packages/nidana_dart_contracts/test/topic_test.dart
replay topic-model --set behavior --guarantee G11
restore "$P/lib/src/topic/topic.dart"
seed "D4 envelope hashCode over the parents list itself" "$P/lib/src/topic/envelope.dart" "    Object.hashAll(parentCorrelationIds),\n    timestamp," "    parentCorrelationIds,\n    timestamp,"
tests packages/nidana_dart_contracts/test/envelope_test.dart
replay topic-model --set behavior --guarantee G13
restore "$P/lib/src/topic/envelope.dart"
seed "D5 combine takes a fresh id before it counts the correlations" "$P/lib/src/topic/lineage.dart" "    final String? causationId = inputs[trigger].causationId;\n" "    final String? causationId = inputs[trigger].causationId;\n    final String fresh = freshCorrelationId();\n"
(python3 - "$P/lib/src/topic/lineage.dart" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1]); t = f.read_text()
a = "        correlationId: freshCorrelationId(),\n"
assert t.count(a) == 1; f.write_text(t.replace(a, "        correlationId: fresh,\n"))
PY
)
tests packages/nidana_dart_contracts/test/lineage_property_test.dart
restore "$P/lib/src/topic/lineage.dart"
seed "D6 combine keeps repeated parents under a shared correlation" "$P/lib/src/topic/lineage.dart" "        parentCorrelationIds: List<String>.unmodifiable(<String>{\n          for (final Lineage input in inputs)\n            if (input.correlationId != null) ...input.parentCorrelationIds,\n        }),\n" "        parentCorrelationIds: List<String>.unmodifiable(<String>[\n          for (final Lineage input in inputs)\n            if (input.correlationId != null) ...input.parentCorrelationIds,\n        ]),\n"
tests packages/nidana_dart_contracts/test/lineage_property_test.dart
restore "$P/lib/src/topic/lineage.dart"
seed "D7 combine takes the causation of the last input" "$P/lib/src/topic/lineage.dart" "    final String? causationId = inputs[trigger].causationId;\n" "    final String? causationId = inputs.last.causationId;\n"
tests packages/nidana_dart_contracts/test/lineage_property_test.dart
restore "$P/lib/src/topic/lineage.dart"
seed "D8 a sensitive envelope rendered with its payload" "$P/lib/src/topic/envelope.dart" "\${sensitive ? RedactedPayload.of(payload) : payload}" "\$payload"
tests packages/nidana_dart_contracts/test/envelope_test.dart
restore "$P/lib/src/topic/envelope.dart"
tests packages/nidana_dart_contracts

step "X every Dart block of the plan is the text of a draft file or a contiguous part of one"
python3 - "$REPO/docs/superpowers/plans/nidana.model.8.md" "$DRAFT" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.exists():
    print('no plan yet'); sys.exit(0)
plan, draft = p.read_text(), pathlib.Path(sys.argv[2])
files = {str(f.relative_to(draft)): f.read_text() for f in draft.rglob('*.dart')}
blocks = re.findall(r'```dart\n(.*?)```', plan, re.S)
for i, b in enumerate(blocks, 1):
    whole = [n for n, t in sorted(files.items()) if t == b]
    part = [n for n, t in sorted(files.items()) if b in t]
    print(f'block {i}: {len(b.splitlines())} lines,', ('the whole of ' + whole[0]) if whole else ('part of ' + part[0]) if part else 'NOT IN ANY DRAFT FILE')
PY

step "cleanup"
rm -rf "$WS"; echo "removed the temporary workspace"
