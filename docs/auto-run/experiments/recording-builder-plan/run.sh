#!/usr/bin/env bash
# recording-builder-plan: runtime facts the nidana.model.9 plan depends on
# (S127). It replays the plan's task sequence in a temporary copy of the
# committed tree (git archive HEAD), with the files drafted under draft/, and
# records what each task's failing step and passing step print:
#   F: facts/facts.dart: which references are identical, what a
#      ZoneSpecification counts, how a visitor binds type arguments, and
#      what combineAll's apply must hand its combiner.
#   S: the committed tree: the package tests, and the replays the gate runs
#      (topology-dsl restricted as the gate restricts it and unrestricted,
#      topic-model, topology-ir's four sets).
#   N: dart test's name filters on the recording binding, to run G9's two
#      recording cases by name.
#   B: every diagnostic the analyzer reports in the Dart libraries of every
#      slug's surface/, reject/ and behavior/, before any body lands.
#   T1 to T4: each task's failing step (its new test file, and the replay of
#      its guarantees restricted with --guarantee) and its passing step (the
#      formatter, the package tests, the root analyzer, the same replay).
#      The library states between tasks are draft/lib/src/topology/*.tN.dart,
#      which gen_variants.py derives from the final draft and HEAD.
#   G: the phase gate as the phase context writes it, then the same gate with
#      G10 dropped from the topology-dsl restriction (the fix S127 proposes).
#   C: the last task's checklist.
#   A: every fixture diagnostic again, compared with B.
#   D: seeded defects, each restored after, and which check catches each.
#   X: every test file the plan writes out, compared with draft/test/.
# draft/ is evidence, not code to copy; the plan states what each task does.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
DRAFT=$HERE/draft
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/rbp.XXXXXX")
P=$WS/packages/nidana_dart_contracts
TOP=$P/lib/src/topology
BINDING=hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart
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
  grep -E '\[E\]$|All tests passed|Some tests failed|No tests ran|No tests match|^exit:' "$WS/tests.out" | sed 's/^[0-9:]* //' | sort -u | clip | head -n 40
  grep -E '^  (UnimplementedError|Bad state|Invalid argument|Expected|Actual|Which|Error)' "$WS/tests.out" | sort | uniq -c | clip | head -n 12
}
analyze() { (cd "$WS" && fvm dart analyze --fatal-infos 2>&1 | tail -n 6 | clip; echo "analyze exit: ${PIPESTATUS[0]}"); }
fmt() { (cd "$WS" && fvm dart format packages/nidana_dart_contracts 2>&1 | tail -n 1 | clip); }
put_test() { cp "$DRAFT/test/$1" "$P/test/$1"; }
lib_state() { # builder handle stages plan sinks(head|final)
  cp "$DRAFT/lib/src/topology/topology.dart" "$TOP/topology.dart"
  cp "$DRAFT/lib/src/topology/$1" "$TOP/builder.dart"
  cp "$DRAFT/lib/src/topology/$2" "$TOP/handle.dart"
  cp "$DRAFT/lib/src/topology/$3" "$TOP/stages.dart"
  cp "$DRAFT/lib/src/topology/$4" "$TOP/plan.dart"
  if [ "$5" = head ]; then git -C "$REPO" show HEAD:packages/nidana_dart_contracts/lib/src/topology/sinks.dart > "$TOP/sinks.dart"; else cp "$DRAFT/lib/src/topology/sinks.dart" "$TOP/sinks.dart"; fi
}
g9() {
  (cd "$WS" && fvm dart test "$BINDING" --name '^G9 (planOf runs|the builder form)' -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE '^\+[0-9]+: loading|^  package:|^  hsdd/|^$' | clip | head -n 12; echo "exit: ${PIPESTATUS[0]}")
}
fixture_diagnostics() { # every (file, line, code) the analyzer reports in the fixtures' Dart sets
  (cd "$WS" && fvm dart analyze --format=json $(ls -d hsdd/contract/fixture/*/surface hsdd/contract/fixture/*/reject hsdd/contract/fixture/*/behavior 2>/dev/null) 2>/dev/null) \
    | sed -n 's/^.*\({"version".*\)$/\1/p' \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const r=j.diagnostics.map(d=>d.location.file.split("/hsdd/contract/fixture/")[1]+":"+d.location.range.start.line+" "+d.code);r.sort();console.log(r.join("\n"))})'
}
GATE='fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl --guarantee G10,G11,G13,G14,G15,G16,G17,G30 && fvm dart run nidana_contract_check topology-ir --set structure,surface,reject,schema'
gate() { # gate <command>
  (cd "$WS" && bash -c "$1" > "$WS/gate.out" 2>&1; echo "gate exit: $?")
  grep -E 'Got dependencies|No issues found|fixtures:|All tests passed|Some tests failed|^FAIL|^PENDING|^PASS behavior' "$WS/gate.out" | sed 's/^[0-9][0-9]:[0-9][0-9] //' | sed 's/; failed-case (/\n    failed-case (/g' | clip
}

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)
python3 -I "$HERE/gen_variants.py"

step "F facts/facts.dart"
(cd "$HERE/facts" && fvm dart run facts.dart 2>&1)

step "S1 the committed tree"
tests packages/nidana_dart_contracts
replay topology-dsl --guarantee G10,G11,G13,G14,G15,G16,G17,G30
replay topology-dsl --set behavior
replay topic-model --set behavior
replay topology-ir --set structure,surface,reject,schema

step "N name filters on the recording binding (committed tree: the bodies throw, so selected cases fail)"
for args in "--plain-name;G9 planOf runs declare once" "--name;^G9 (planOf runs|the builder form)" "--plain-name;G9 planOf;--plain-name;G9 the builder form"; do
  IFS=';' read -r -a a <<< "$args"
  (cd "$WS" && fvm dart test "$BINDING" "${a[@]}" > "$WS/n.out" 2>&1; echo "exit: $?" >> "$WS/n.out")
  echo "-- dart test $BINDING ${a[*]}"
  grep -E 'Some tests failed|All tests passed|No tests ran|No tests match|^exit:' "$WS/n.out" | sed 's/^[0-9:]* //' | sort -u | clip
  echo "   cases run: $(grep -oE '^[0-9:]+ \+[0-9]+ -[0-9]+: G9[^[]*' "$WS/n.out" | sed 's/^[0-9:]* +[0-9]* -[0-9]*: //' | sort -u | tr '\n' ';')"
done

step "B every fixture diagnostic before any body lands (surface, reject and behavior of every slug)"
fixture_diagnostics > "$WS/fixtures.before"
echo "diagnostics: $(wc -l < "$WS/fixtures.before" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.before" | sort -u | wc -l | tr -d ' ') libraries"
echo "const-collection codes: $(grep -cE 'const_set_element_not_primitive_equality|const_map_key_not_primitive_equality' "$WS/fixtures.before")"

step "T1.2 Task 1's failing step: test/recording_test.dart, the G13, G15, G17 and G30 cases, G9's two by name"
put_test recording_test.dart
tests packages/nidana_dart_contracts/test/recording_test.dart
replay topology-dsl --set behavior --guarantee G13,G15,G17,G30
g9

step "T1.4 Task 1's library: planOf, the builder form, read, write, TopologyRef equality"
lib_state builder.t1.dart handle.t1.dart stages.t1.dart plan.t1.dart head
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-dsl --set behavior --guarantee G13,G15,G17,G30
g9
replay topology-dsl --set behavior --guarantee G11

step "T2.2 Task 2's failing step: test/handle_stages_test.dart and the G14 and G15 cases"
put_test handle_stages_test.dart
tests packages/nidana_dart_contracts/test/handle_stages_test.dart
replay topology-dsl --set behavior --guarantee G14,G15

step "T2.4 Task 2's library: the single-input handle calls"
lib_state builder.t1.dart handle.t2.dart stages.t1.dart plan.t1.dart head
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-dsl --set behavior --guarantee G14,G15

step "T3.2 Task 3's failing step: test/combining_stages_test.dart and the G10, G11, G13, G14 and G15 cases"
put_test combining_stages_test.dart
tests packages/nidana_dart_contracts/test/combining_stages_test.dart
replay topology-dsl --set behavior --guarantee G10,G11,G13,G14,G15

step "T3.4 Task 3's library: the multi-input calls, reduceInto and apply"
lib_state builder.dart handle.t3.dart stages.t3.dart plan.t1.dart head
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-dsl --set behavior --guarantee G10,G11,G13,G14,G15

step "T4.2 Task 4's failing step: test/plan_visitors_test.dart and the G11 and G16 cases"
put_test plan_visitors_test.dart
tests packages/nidana_dart_contracts/test/plan_visitors_test.dart
replay topology-dsl --set behavior --guarantee G11,G16

step "T4.4 Task 4's library: visitStage and visitSink"
lib_state builder.dart handle.dart stages.dart plan.dart final
fmt
tests packages/nidana_dart_contracts
analyze
replay topology-dsl --set behavior --guarantee G11,G16
replay topology-dsl --guarantee G10,G11,G13,G14,G15,G16,G17,G30
replay topology-dsl --set behavior
echo "-- why the G10 cases fail:"
(cd "$WS" && fvm dart test "$BINDING" --name '^G10' 2>&1 | grep -E '^  (UnimplementedError|package:nidana_dart_contracts/src/topology/[a-z]+\.dart [0-9]+:[0-9]+ +[A-Za-z.]+|hsdd/.*recording_conformance\.dart [0-9]+:[0-9]+)' | sort | uniq -c | clip)

step "G the phase gate, from the workspace root"
echo "-- as the phase context writes it:"
gate "$GATE"
echo "-- with G10 dropped from the topology-dsl restriction:"
gate "${GATE/--guarantee G10,G11,/--guarantee G11,}"

step "C the last task's checklist"
g9
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/combining_stages_test.dart --name '^G10' -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE 'loading' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && fvm dart test packages/nidana_dart_contracts/test/recording_test.dart packages/nidana_dart_contracts/test/handle_stages_test.dart packages/nidana_dart_contracts/test/combining_stages_test.dart --name '^G1[45] ' -j 1 -r expanded 2>&1 | sed 's/^[0-9][0-9]:[0-9][0-9] //' | grep -vE 'loading' | clip; echo "exit: ${PIPESTATUS[0]}")
(cd "$WS" && grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?")
(cd "$WS" && grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?")
(cmp -s "$WS/pubspec.lock" "$REPO/pubspec.lock" && echo "pubspec.lock unchanged")
(cd "$WS" && for f in packages/nidana_dart_contracts/lib/src/topology/*.dart; do git -C "$REPO" show "HEAD:${f}" 2>/dev/null | diff - "$f" | grep -c '^[<>]' | sed "s#^#changed lines in ${f#packages/nidana_dart_contracts/}: #"; done)
(cd "$WS" && wc -l packages/nidana_dart_contracts/lib/src/topology/*.dart packages/nidana_dart_contracts/test/recording_test.dart packages/nidana_dart_contracts/test/handle_stages_test.dart packages/nidana_dart_contracts/test/combining_stages_test.dart packages/nidana_dart_contracts/test/plan_visitors_test.dart | clip)
echo "-- const set or map literals with elements in the new tests:"
(cd "$WS" && grep -nE "const\s*(<[^>]*>)?\s*\{\s*[^} ]" packages/nidana_dart_contracts/test/recording_test.dart packages/nidana_dart_contracts/test/handle_stages_test.dart packages/nidana_dart_contracts/test/combining_stages_test.dart packages/nidana_dart_contracts/test/plan_visitors_test.dart; echo "exit: $?")
echo "-- D6 tokens in lib/src/topology (purity_test.dart scans these):"
(cd "$WS" && grep -nE 'DateTime\.now\(|Stopwatch\(|Timer\(|Timer\.periodic\(|scheduleMicrotask\(|Future\.delayed\(|Future\.microtask\(|Random\(|Zone\.' packages/nidana_dart_contracts/lib/src/topology/*.dart; echo "exit: $?")

step "A every fixture diagnostic again"
fixture_diagnostics > "$WS/fixtures.after"
echo "diagnostics: $(wc -l < "$WS/fixtures.after" | tr -d ' ') in $(cut -d: -f1 "$WS/fixtures.after" | sort -u | wc -l | tr -d ' ') libraries"
echo "const-collection codes: $(grep -cE 'const_set_element_not_primitive_equality|const_map_key_not_primitive_equality' "$WS/fixtures.after")"
echo "-- diff before/after (none expected):"
diff "$WS/fixtures.before" "$WS/fixtures.after" && echo "  identical"

step "D seeded defects, each restored after"
seed() { # seed <label> <file> <old> <new>
  cp "$2" "$WS/seed.bak"
  python3 -I - "$2" "$3" "$4" <<'PY'
import sys, pathlib
f, a, b = pathlib.Path(sys.argv[1]), sys.argv[2].encode().decode('unicode_escape'), sys.argv[3].encode().decode('unicode_escape')
t = f.read_text(); assert t.count(a) == 1, a; f.write_text(t.replace(a, b))
PY
  echo "-- $1"
}
restore() { cp "$WS/seed.bak" "$1"; }
seed "D1 MapStage visits at Object? instead of its own type arguments" "$TOP/stages.dart" "visitor.map<T, R>(this)" "visitor.map<Object?, Object?>(this)"
tests packages/nidana_dart_contracts/test/plan_visitors_test.dart
replay topology-dsl --set behavior --guarantee G11,G16
restore "$TOP/stages.dart"
seed "D2 combineAll hands its combiner a modifiable cast view" "$TOP/builder.dart" "combiner(List<T>.unmodifiable(values.cast<T>()))" "combiner(values.cast<T>())"
tests packages/nidana_dart_contracts/test/combining_stages_test.dart
replay topology-dsl --set behavior --guarantee G11
restore "$TOP/builder.dart"
seed "D3 merge checks for an empty list after recording its stage" "$TOP/builder.dart" "    _checkNotEmpty(inputs);\n    final List<TopicStream<T>> made = _checkMade(inputs);\n    return _addStage(MergeStage<T>._(this, made), made);" "    final List<TopicStream<T>> made = _checkMade(inputs);\n    final TopicStream<T> stage = _addStage(MergeStage<T>._(this, made), made);\n    _checkNotEmpty(inputs);\n    return stage;"
tests packages/nidana_dart_contracts/test/combining_stages_test.dart
replay topology-dsl --set behavior --guarantee G14
restore "$TOP/builder.dart"
seed "D4 the one-sink check compares state topics by identity" "$TOP/builder.dart" "final Set<StateTopic<Object?>> _written = <StateTopic<Object?>>{};" "final Set<StateTopic<Object?>> _written = Set<StateTopic<Object?>>.identity();"
tests packages/nidana_dart_contracts/test/recording_test.dart
replay topology-dsl --set behavior --guarantee G14
restore "$TOP/builder.dart"
seed "D5 planOf closes the builder only when declare returns normally" "$TOP/plan.dart" "  try {\n    topology.declare(builder);\n  } finally {\n    builder._open = false;\n  }" "  topology.declare(builder);\n  builder._open = false;"
tests packages/nidana_dart_contracts/test/recording_test.dart
replay topology-dsl --set behavior --guarantee G15
restore "$TOP/plan.dart"
seed "D6 a foreign handle is told apart by its closed builder, not by identity" "$TOP/builder.dart" "if (!identical(handle._builder, this)) {" "if (!handle._builder._open) {"
tests packages/nidana_dart_contracts/test/recording_test.dart
replay topology-dsl --set behavior --guarantee G14
restore "$TOP/builder.dart"
seed "D7 merge keeps the caller's list" "$TOP/builder.dart" "    _checkNotEmpty(inputs);\n    final List<TopicStream<T>> made = _checkMade(inputs);\n    return _addStage(MergeStage<T>._(this, made), made);" "    _checkNotEmpty(inputs);\n    _checkMade(inputs);\n    return _addStage(MergeStage<T>._(this, inputs), inputs);"
tests packages/nidana_dart_contracts/test/combining_stages_test.dart
replay topology-dsl --set behavior --guarantee G11
restore "$TOP/builder.dart"
seed "D8 a negative duration recorded before it is checked" "$TOP/handle.dart" "    return _derive(\n      DebounceStage<T>._(_builder, this, _checkNotNegative(duration)),\n    );" "    final TopicStream<T> stage = _derive(DebounceStage<T>._(_builder, this, duration));\n    _checkNotNegative(duration);\n    return stage;"
tests packages/nidana_dart_contracts/test/handle_stages_test.dart
replay topology-dsl --set behavior --guarantee G14
restore "$TOP/handle.dart"
seed "D9 a closed builder checks the duration before it reports the closed builder" "$TOP/handle.dart" "  TopicStream<T> debounce(Duration duration) {\n    _builder._checkOpen();\n    return _derive(\n      DebounceStage<T>._(_builder, this, _checkNotNegative(duration)),\n    );" "  TopicStream<T> debounce(Duration duration) {\n    final Duration checked = _checkNotNegative(duration);\n    _builder._checkOpen();\n    return _derive(DebounceStage<T>._(_builder, this, checked));"
tests packages/nidana_dart_contracts/test/handle_stages_test.dart
replay topology-dsl --set behavior --guarantee G15
restore "$TOP/handle.dart"
seed "D10 withLatestFrom's apply without its length check" "$TOP/stages.dart" "    if (latest.length != this.latest.length) {" "    if (false) {"
tests packages/nidana_dart_contracts/test/combining_stages_test.dart
restore "$TOP/stages.dart"
echo "-- restored: the package tests"
tests packages/nidana_dart_contracts

step "X every test file the plan writes out, against draft/test/"
PLAN=$REPO/docs/superpowers/plans/nidana.model.9.md
if [ -f "$PLAN" ]; then
  python3 -I - "$PLAN" "$DRAFT/test" <<'PY'
import sys, re, pathlib
plan = pathlib.Path(sys.argv[1]).read_text()
draft = pathlib.Path(sys.argv[2])
blocks = re.findall(r"Create `packages/nidana_dart_contracts/test/([a-z_]+_test\.dart)`[^\n]*:\n\n```dart\n(.*?)```\n", plan, re.S)
print(f"test files in the plan: {len(blocks)}")
for name, body in blocks:
    same = (draft / name).read_text() == body
    print(f"  {name}: {'identical to draft' if same else 'DIFFERS from draft'}")
lib = draft.parent / 'lib' / 'src' / 'topology'
sources = {f.name: f.read_text() for f in sorted(lib.glob('*.dart'))}
whole = {b for _, b in blocks}
excerpts = [b for b in re.findall(r"```dart\n(.*?)```\n", plan, re.S) if b not in whole]
print(f"library excerpts in the plan: {len(excerpts)}")
for b in excerpts:
    hits = [n for n, s in sources.items() if b in s]
    print(f"  {b.splitlines()[0].strip()[:60]}: {'in ' + ', '.join(hits) if hits else 'NOT FOUND in any draft'}")
PY
else
  echo "no plan at $PLAN yet"
fi

case "$WS" in "${T%/}"/rbp.*) rm -rf "$WS" ;; esac
echo
echo "done"
