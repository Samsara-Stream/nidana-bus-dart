#!/usr/bin/env bash
# sweep-topology-dsl: evidence for S152, the end-of-nidana.model governance
# sweep of topology-dsl@v2 and nidana-checks@v1 (hsdd-contract, compatible
# touches within the current versions). It works in a temporary copy of the
# committed tree (git archive HEAD), so packages/ is the shipped package, and
# records:
#   F: facts/facts.dart against the shipped package, run from the repository
#      root (a closed builder given a bad argument as well, apply given a list
#      of the wrong length, calls that throw and are caught, a state topic
#      built apart, a nested planOf, a declaration that throws, the input
#      lists a stage holds, the type arguments the visitors bind).
#   B: the committed fixtures, replayed unrestricted.
#   N: the fixtures with S152's seven recording cases (the working tree's
#      conformance library), replayed unrestricted.
#   D: seeded defects in the copy's package, each restored after, replayed
#      restricted to the behavior set and the guarantee they touch, with the
#      committed cases and with S152's. D1 to D9 are the defects S127's plan
#      experiment seeded (docs/auto-run/experiments/recording-builder-plan/,
#      D1 to D9) rewritten against the shipped code; D10 to D15 are further
#      seeds of the rules the new cases pin.
#   R: the copy's lib/ against HEAD's, and S152's cases once more.
#   P: nidana-checks@v1's scan cases: from a scan case's files/, `dart run`
#      of a {package}:{executable} command against the form the replay tool
#      runs (bin/{executable}.dart under the running dart with --packages),
#      on a fresh workspace, on one made stale by a newer member pubspec.yaml,
#      and after `dart pub get --enforce-lockfile`. nidana_dart_codegen does
#      not exist yet, so nidana_contract_check stands in as the executable;
#      what is shown is whether the program starts.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/sweepdsl.XXXXXX")
P=$WS/packages/nidana_dart_contracts
TOP=$P/lib/src/topology
CONF=hsdd/contract/fixture/topology-dsl/behavior/recording_conformance.dart
step() { echo; echo "### $*"; }
clip() { sed "s#$(cd "$WS" && pwd -P)#{ws}#g; s#$WS#{ws}#g" | cut -c1-300; } # the resolved path, the longer, first
replay() {
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "-- nidana_contract_check $*"
  grep -E '^(PASS|FAIL) behavior|fixtures:|^exit:' "$WS/replay.out" | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
seed() { # seed <label> <file under lib/src/topology> <old> <new>; \n in old and new is a newline
  cp "$TOP/$2" "$WS/seed.bak"
  python3 -I - "$TOP/$2" "$3" "$4" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1])
a, b = sys.argv[2].replace('\\n', '\n'), sys.argv[3].replace('\\n', '\n')
t = f.read_text()
assert t.count(a) == 1, 'not found once: ' + a
f.write_text(t.replace(a, b))
PY
  echo; echo "-- $1"
  diff "$WS/seed.bak" "$TOP/$2" | clip
}
unseed() { cp "$WS/seed.bak" "$TOP/$1"; }
both() { # both <guarantee>: the committed cases, then S152's, restricted
  echo "- committed cases:"; cp "$WS/conf.committed" "$WS/$CONF"; replay topology-dsl --set behavior --guarantee "$1"
  echo "- with S152's cases:"; cp "$REPO/$CONF" "$WS/$CONF"; replay topology-dsl --set behavior --guarantee "$1"
}
mtimes() {
  (cd "$WS" && for f in pubspec.yaml packages/nidana_dart_contracts/pubspec.yaml pubspec.lock .dart_tool/package_config.json; do
    printf '%s=%s ' "$f" "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")"
  done; echo)
}

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)

step "F facts/facts.dart against the shipped package (packages/ is unchanged in the working tree)"
echo "packages/ changes in the working tree: $(git -C "$REPO" status --porcelain packages | wc -l | tr -d ' ')"
(cd "$REPO" && fvm dart run "$HERE/facts/facts.dart" 2>&1)

step "B the committed fixtures, unrestricted"
replay topology-dsl

step "N S152's conformance library (seven new cases), unrestricted"
cp "$WS/$CONF" "$WS/conf.committed"
cp "$REPO/$CONF" "$WS/$CONF"
echo "-- cases added:"
diff "$WS/conf.committed" "$WS/$CONF" | grep -E "^> +name: " | sed 's/^> *//'
replay topology-dsl

step "D seeded defects, each restored after"

seed "D1 MapStage visits at Object? instead of its own type arguments" stages.dart \
  "visitor.map<T, R>(this)" \
  "visitor.map<Object?, Object?>(this)"
both G16; unseed stages.dart

seed "D2 combineAll hands its combiner a modifiable cast view" builder.dart \
  "combiner(List<T>.unmodifiable(values.cast<T>()))" \
  "combiner(values.cast<T>())"
both G11; unseed builder.dart

seed "D3 merge checks for an empty list after recording its stage" builder.dart \
  "    _checkNotEmpty(inputs);\n    final List<TopicStream<T>> made = _checkMade(\n      inputs,\n      _elementNames('inputs', inputs.length),\n    );\n    return _addStage(MergeStage<T>._(this, made), made);" \
  "    final List<TopicStream<T>> made = _checkMade(\n      inputs,\n      _elementNames('inputs', inputs.length),\n    );\n    final TopicStream<T> stage = _addStage(MergeStage<T>._(this, made), made);\n    _checkNotEmpty(inputs);\n    return stage;"
both G14; unseed builder.dart

seed "D4 the one-sink check compares state topics by identity" builder.dart \
  "final Set<StateTopic<Object?>> _written = <StateTopic<Object?>>{};" \
  "final Set<StateTopic<Object?>> _written = Set<StateTopic<Object?>>.identity();"
both G14; unseed builder.dart

seed "D5 planOf closes the builder only when declare returns normally" plan.dart \
  "  try {\n    topology.declare(builder);\n  } finally {\n    builder._open = false;\n  }" \
  "  topology.declare(builder);\n  builder._open = false;"
both G15; unseed plan.dart

seed "D6 a foreign handle is told apart by its closed builder, not by identity" builder.dart \
  "if (!identical(handles[i]._builder, this)) {" \
  "if (!handles[i]._builder._open) {"
both G14; unseed builder.dart

seed "D7 merge keeps the caller's list" builder.dart \
  "    return _addStage(MergeStage<T>._(this, made), made);" \
  "    return _addStage(MergeStage<T>._(this, inputs), inputs);"
both G11; unseed builder.dart

seed "D8 a negative debounce duration recorded before it is checked" handle.dart \
  "    return _derive(\n      DebounceStage<T>._(_builder, this, _checkNotNegative(duration)),\n    );" \
  "    final TopicStream<T> stage = _derive(\n      DebounceStage<T>._(_builder, this, duration),\n    );\n    _checkNotNegative(duration);\n    return stage;"
both G14; unseed handle.dart

seed "D9 a closed handle checks the debounce duration before it reports the closed builder" handle.dart \
  "  TopicStream<T> debounce(Duration duration) {\n    _builder._checkOpen();\n    return _derive(\n      DebounceStage<T>._(_builder, this, _checkNotNegative(duration)),\n    );" \
  "  TopicStream<T> debounce(Duration duration) {\n    final Duration checked = _checkNotNegative(duration);\n    _builder._checkOpen();\n    return _derive(\n      DebounceStage<T>._(_builder, this, checked),\n    );"
both G15; unseed handle.dart

seed "D10 a closed builder checks merge's empty list before it reports the closed builder" builder.dart \
  "  TopicStream<T> merge<T>(List<TopicStream<T>> inputs) {\n    _checkOpen();\n    _checkNotEmpty(inputs);" \
  "  TopicStream<T> merge<T>(List<TopicStream<T>> inputs) {\n    _checkNotEmpty(inputs);\n    _checkOpen();"
both G15; unseed builder.dart

seed "D11 WithLatestFromStage.apply without its length check" stages.dart \
  "    if (latest.length != this.latest.length) {" \
  "    if (latest.length < 0) {"
both G11; unseed stages.dart

seed "D12 CombineStage.apply without its length check" stages.dart \
  "    if (values.length != inputs.length) {" \
  "    if (values.length < 0) {"
both G11; unseed stages.dart

seed "D13 write marks its handle consumed before the second-sink check" builder.dart \
  "    _checkMade(<TopicStream<Object?>>[stream], const <String>['stream']);\n    _checkFirstSink(topic);" \
  "    _checkMade(<TopicStream<Object?>>[stream], const <String>['stream']);\n    _consumed.add(stream);\n    _checkFirstSink(topic);"
both G14; unseed builder.dart

seed "D14 reduceInto claims its state topic before the foreign-handle check" builder.dart \
  "    _checkMade(<TopicStream<Object?>>[events], const <String>['events']);\n    _checkFirstSink(topic);" \
  "    _checkFirstSink(topic);\n    _written.add(topic);\n    _checkMade(<TopicStream<Object?>>[events], const <String>['events']);"
both G14; unseed builder.dart

seed "D15 ReduceIntoSink visits at Object? instead of its own type arguments" sinks.dart \
  "visitor.reduceInto<S, E>(this)" \
  "visitor.reduceInto<Object?, Object?>(this)"
both G16; unseed sinks.dart

step "R restored: S152's cases against the shipped package once more"
mkdir -p "$WS/head"
git -C "$REPO" archive HEAD packages/nidana_dart_contracts/lib | tar -x -C "$WS/head"
if diff -r "$WS/head/packages/nidana_dart_contracts/lib" "$P/lib" > /dev/null; then
  echo "the copy's lib/ equals HEAD's"
else
  echo "the copy's lib/ differs from HEAD's"
fi
replay topology-dsl

step "P nidana-checks@v1's scan cases: a {package}:{executable} command run from files/"
FILES=$WS/hsdd/contract/fixture/nidana-checks/invocation/scan-clean/files
echo "files/ holds a pubspec.yaml: $([ -e "$FILES/pubspec.yaml" ] && echo yes || echo no)"
run_forms() {
  (cd "$FILES" && fvm dart run nidana_contract_check nosuch > "$WS/p.out" 2>&1; echo "exit $?" >> "$WS/p.out")
  echo "dart run nidana_contract_check nosuch: $(tail -n 1 "$WS/p.out")"; sed '$d' "$WS/p.out" | head -n 2 | sed 's/^/  | /' | clip
  (cd "$FILES" && fvm dart --packages="$WS/.dart_tool/package_config.json" "$WS/packages/nidana_contract_check/bin/nidana_contract_check.dart" nosuch > "$WS/p.out" 2>&1; echo "exit $?" >> "$WS/p.out")
  echo "dart --packages={ws}/.dart_tool/package_config.json bin/nidana_contract_check.dart nosuch: $(tail -n 1 "$WS/p.out")"; sed '$d' "$WS/p.out" | head -n 2 | sed 's/^/  | /' | clip
  echo "files/ after: $(cd "$FILES" && ls -A | tr '\n' ' ')"
}
echo "-- P1 fresh (seconds since the epoch, oldest rule first)"
mtimes
run_forms
echo "-- P2 stale: a member pubspec.yaml touched after pubspec.lock"
sleep 1; touch "$P/pubspec.yaml"
mtimes
run_forms
echo "-- P3 then dart pub get --enforce-lockfile (offline)"
(cd "$WS" && fvm dart pub get --enforce-lockfile --offline 2>&1 | tail -n 1 | sed 's/^/  | /')
mtimes
run_forms

rm -rf "$WS"
