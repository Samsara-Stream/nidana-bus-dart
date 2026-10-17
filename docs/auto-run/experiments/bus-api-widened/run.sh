#!/usr/bin/env bash
# bus-api-widened: checks the second amendment of bus-api@v1 within v1:
#   (e) G41: one topic reached through a widened reference (Topic<Object?>,
#       StateTopic<Object?>, MultiWriterTopic<Object?>, as generic shell code
#       holds it) and at its value type is one subject, in either order; G20's
#       same writer handle is per type argument;
#   (f) For static analysis cites nidana-checks@v1 G5 (a statement only; it
#       changes no fixture).
#
# Stand-ins, copied from ../flutter-binding-fixtures/ (whose first four are
# those of ../bus-api-amendment/, unchanged):
#   - nidana_dart_contracts, nidana_contract_check (its structure and reject
#     prototypes), nidana_dart_navigation, nidana_dart_runtime_flutter,
#     unchanged;
#   - nidana_dart_runtime: the S13 stand-in of ../bus-api-amendment/ with this
#     experiment's patch, marked "bus-api-widened patch" in lib/src/bus.dart
#     and lib/src/interpreter.dart: a subject is keyed by the topic's name and
#     holds its values at Object? whatever the type argument of the access
#     that creates it, each access converts at its own type argument, and
#     writers are kept per topic and type argument.
# Kept beside the stand-in: s13_runtime/, lib/src/bus.dart and
# lib/src/interpreter.dart of ../bus-api-amendment/, the runtime before this
# patch, whose subject takes the type argument of its first access.
# tool/widened_observe.dart is S14's probe (../flutter-binding-fixtures/tool/),
# unchanged; tool/widened_envelopes.dart is this experiment's probe of the
# envelope a widened publish builds and of what Topic.valueType offers.
#
# The fixtures are the repository's hsdd/contract/ as amended, copied into
# this experiment's own workspace at the same relative paths. Every contract
# whose fixtures import nidana_dart_runtime is replayed: bus-api@v1 (with
# topology-dsl@v1's live suite through bus_activation_test.dart),
# bus-testing@v1, navigation-api@v1 (both suites) and flutter-binding@v1
# (both bindings, under fvm flutter test).
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
A=$F/bus-api
B=$F/bus-testing
N=$F/navigation-api
FB=$F/flutter-binding
RT=packages/nidana_dart_runtime/lib/src
step() { echo; echo "### $*"; }

# s13 {command...}: runs the command with the S13 runtime in place of the
# patched one, and restores the patched one.
s13() {
  cp $RT/bus.dart $RT/bus.dart.patched; cp $RT/interpreter.dart $RT/interpreter.dart.patched
  cp s13_runtime/bus.dart s13_runtime/interpreter.dart $RT/
  "$@"
  mv $RT/bus.dart.patched $RT/bus.dart; mv $RT/interpreter.dart.patched $RT/interpreter.dart
}

# report {command...}: runs the command and prints its failing case names.
report() {
  "$@" 2>&1 | grep -E '\[E\]$|Some tests failed|All tests passed' \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
}

# mutate {file} {label} {from} {to} {command...}: applies one textual defect
# to the patched stand-in, runs the command, and restores the file.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"; shift 4
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  report "$@"
  mv "$file.orig" "$file"
}

api() { fvm dart test $A/behavior/nidana_dart_runtime_test.dart; }

step "setup: copy the contracts and the fixtures from the repository, resolve"
rm -rf hsdd && mkdir -p $F
cp $REPO/hsdd/contract/*.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$A $REPO/$B $REPO/$N $REPO/$F/topology-dsl $REPO/$FB $F/
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version
echo "-- the patch in the stand-in runtime"
grep -n "bus-api-widened patch" $RT/*.dart
echo "-- the stand-in packages other than nidana_dart_runtime equal those of ../flutter-binding-fixtures/"
for p in nidana_dart_contracts nidana_contract_check nidana_dart_navigation nidana_dart_runtime_flutter; do
  diff -r -x .dart_tool packages/$p ../flutter-binding-fixtures/packages/$p > /dev/null && echo "$p: same" || echo "$p: DIFFERS"
done
echo "-- s13_runtime/ equals the runtime of ../bus-api-amendment/"
for f in bus.dart interpreter.dart; do
  cmp -s s13_runtime/$f ../bus-api-amendment/packages/nidana_dart_runtime/lib/src/$f && echo "$f: same" || echo "$f: DIFFERS"
done

step "P1 S14's probe: a topic reached through a Topic<Object?> reference and at its value type, on the S13 runtime and on the patched one"
echo "-- S13 runtime"
s13 fvm dart run tool/widened_observe.dart
echo "-- patched runtime"
fvm dart run tool/widened_observe.dart

step "P2, P3 on the patched runtime: the envelope of a widened publish and bus-testing@v1's recorder; what Topic.valueType offers generic code"
fvm dart run tool/widened_envelopes.dart

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
for s in bus-api bus-testing navigation-api flutter-binding; do
  echo "-- $s"; fvm dart run nidana_contract_check:structure_check $s | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
done
echo "-- bus-api, every guarantee"
fvm dart run nidana_contract_check:structure_check bus-api | grep '^PASS G\|^FAIL G' | tr '\n' ' '; echo

step "T1b structure under amended ADR-001 (items 3 and 9), S17's prototype, over the repository's nine contracts"
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)

step "T2 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $A/surface $B/surface $N/surface $FB/surface; echo "exit: $?"

step "T3 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
for s in bus-api bus-testing navigation-api flutter-binding; do
  echo "-- $s"; fvm dart run nidana_contract_check:reject_check $F/$s/reject; echo "exit: $?"
done

step "T4 the conformance libraries and the bindings analyze clean (warnings included)"
fvm dart analyze --fatal-infos $A/behavior $B/behavior $N/behavior $FB/behavior; echo "exit: $?"

step "T5 behavior: every suite that touches bus-api@v1, on the patched stand-in"
for b in $A/behavior/nidana_dart_runtime_test.dart $A/behavior/bus_activation_test.dart $B/behavior/nidana_dart_runtime_test.dart $N/behavior/nidana_dart_navigation_test.dart $N/behavior/in_memory_router_test.dart; do
  echo "-- $b"; fvm dart test "$b" 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
done
for b in $FB/behavior/nidana_dart_runtime_flutter_test.dart $FB/behavior/flutter_navigation_executor_test.dart; do
  echo "-- $b (fvm flutter test, testWidgets)"; fvm flutter test --no-pub "$b" 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
done

step "T6 behavior: the G41 cases of bus-api@v1, by name prefix (--guarantee bus-api/G41), on the patched stand-in"
fvm dart test --reporter expanded --name '^G41 ' $A/behavior/nidana_dart_runtime_test.dart 2>&1 \
  | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' | grep -v '^loading'; echo "exit: ${PIPESTATUS[0]}"

step "T7 the S13 runtime: the G41 cases fail, every other case of every suite passes"
echo "-- bus-api suite: the failing cases"
s13 report api
echo "-- what the G41 cases throw there (first line of each error)"
s13 bash -c "fvm dart test --name '^G41 ' $A/behavior/nidana_dart_runtime_test.dart 2>&1 | grep -E \"^  (type '|Expected|  Actual|TypeError)\" | sort | uniq -c"
for b in $A/behavior/bus_activation_test.dart $B/behavior/nidana_dart_runtime_test.dart $N/behavior/nidana_dart_navigation_test.dart $N/behavior/in_memory_router_test.dart; do
  echo "-- $b"; s13 bash -c "fvm dart test $b 2>&1 | tail -n 1"
done
for b in $FB/behavior/nidana_dart_runtime_flutter_test.dart $FB/behavior/flutter_navigation_executor_test.dart; do
  echo "-- $b (fvm flutter test)"; s13 bash -c "fvm flutter test --no-pub $b 2>&1 | tail -n 1"
done

step "T8 seeded defects in the patched stand-in fail the cases of the guarantee they break"
mutate $RT/bus.dart "writers kept per topic only, as before the patch (G20, G41)" \
  "_writers.putIfAbsent((topic, T)," "_writers.putIfAbsent((topic, Object), " api
mutate $RT/bus.dart "getBufferedValues returns a modifiable copy at the access's type argument (G8, G41)" \
  "    return List<T>.unmodifiable(_cell(topic)._buffer);" "    return List<T>.of(_cell(topic)._buffer.cast<T>());" api
mutate $RT/bus.dart "the collision check ignores the value type (G7, G41)" \
  "  if (a.variant != b.variant || a.valueType != b.valueType) return false;" \
  "  if (a.variant != b.variant) return false;" api
mutate $RT/bus.dart "an observed stream at a nullable type argument, Object? among them, applies no dedup (G16, G41)" \
  "        final dedup = t is StateTopic<T> ? t.dedup : Dedup.none;" \
  "        final dedup = t is StateTopic<T> && null is! T ? t.dedup : Dedup.none;" api

step "cleanup: remove the copied tree and the Flutter build output; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd build; echo "removed"
