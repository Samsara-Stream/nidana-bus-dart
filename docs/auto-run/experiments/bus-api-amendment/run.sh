#!/usr/bin/env bash
# bus-api-amendment: checks the S13 amendment of bus-api@v1 within v1:
#   (a) an activation is connected when activate returns, so start() delivers
#       the queue to topologies already connected (G22, G34, the connection
#       rule), and the publishes a connection causes wait for a provider-zone
#       microtask;
#   (b) Bus.publish and Publisher.publish typed
#       publish<T extends Object?, V extends T>(MultiWriterTopic<T>, V) (G40);
#   (c) G38 excepts the settle operation's real turns;
#   (d) the delivery rule names the recorders attached to the bus.
# (c) and (d) are statements only and change no fixture.
#
# Stand-ins, copied from ../navigation-api-fixtures/:
#   - nidana_dart_contracts and nidana_contract_check, unchanged;
#   - nidana_dart_runtime with that experiment's patch for (a), marked
#     "navigation-api-fixtures patch" in lib/src/interpreter.dart and
#     lib/src/bus.dart (the connection reaches a read synchronously and the
#     publishes it causes wait for a provider-zone microtask), and this
#     experiment's two patches, marked "bus-api-amendment patch" in
#     lib/src/bus.dart and lib/src/interpreter.dart: the typed publish (b),
#     and topology reads served by a synchronous broadcast controller of the
#     cell instead of the RxDart subject, whose replay to a new listener
#     holds back every delivery made before its first microtask (T10 shows
#     what that does to a queued state publish);
#   - nidana_dart_navigation (navigation-api@v1) and
#     flutter_navigation_standin, unchanged.
# Variants kept beside the stand-in for T9 and T10:
#   - s11_runtime/: lib/src/bus.dart and lib/src/interpreter.dart of
#     ../bus-testing-fixtures/, the runtime before any patch;
#   - naf_runtime/: lib/src/interpreter.dart of ../navigation-api-fixtures/,
#     the read stage with that experiment's patch only.
#
# The fixtures are the repository's hsdd/contract/ as amended, copied into
# this experiment's own workspace at the same relative paths. Every contract
# whose fixtures import nidana_dart_runtime is replayed: bus-api@v1 (with
# topology-dsl@v1's live suite through bus_activation_test.dart),
# bus-testing@v1 and navigation-api@v1 (its executor suite also under
# testWidgets, through the stand-in binding of ../navigation-api-fixtures/).
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
A=$F/bus-api
B=$F/bus-testing
N=$F/navigation-api
W=$F/flutter-binding/behavior/flutter_navigation_standin_test.dart
RT=packages/nidana_dart_runtime/lib/src
step() { echo; echo "### $*"; }

step "setup: copy the contracts and the fixtures from the repository, resolve"
rm -rf hsdd && mkdir -p $F/flutter-binding/behavior
cp $REPO/hsdd/contract/*.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/bus-api $REPO/$F/bus-testing $REPO/$F/navigation-api $REPO/$F/topology-dsl $F/
cp standin_bindings/flutter_navigation_standin_test.dart $F/flutter-binding/behavior/
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version
echo "-- the patches in the stand-in runtime"
grep -n "navigation-api-fixtures patch\|bus-api-amendment patch" $RT/*.dart
grep -n "void publish<" $RT/bus.dart

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
for s in bus-api bus-testing navigation-api; do
  echo "-- $s"; fvm dart run nidana_contract_check:structure_check $s | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
done
echo "-- bus-api, every guarantee"
fvm dart run nidana_contract_check:structure_check bus-api | grep '^PASS G\|^FAIL G' | tr '\n' ' '; echo

step "T2 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $A/surface $B/surface $N/surface; echo "exit: $?"

step "T3 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
for s in bus-api bus-testing navigation-api; do
  echo "-- $s"; fvm dart run nidana_contract_check:reject_check $F/$s/reject; echo "exit: $?"
done

step "T4 reject: the raw diagnostics behind T3 for bus-api@v1's publish files (line severity code)"
for f in $A/reject/publish_value_matches_topic.dart $A/reject/no_publisherless_state_publish.dart $A/reject/publisher_reaches_state_through_writer.dart $N/reject/current_route_is_claimed_by_the_executor.dart; do
  echo "-- $(basename "$f")"
  fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      for (const d of JSON.parse(s).diagnostics)
        console.log(d.location.range.start.line, d.severity, d.code);
    });'
done

step "T5 probes: what the typed publish accepts and rejects (P1), and which signature form keeps a state topic at one diagnostic (P2)"
for f in probe/publish_typing.dart probe/signature_forms.dart; do
  echo "-- $f: (line severity code); a tagged line with no pair compiles"
  fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      const ds = JSON.parse(s).diagnostics.map(d => [d.location.range.start.line, d.severity, d.code]);
      ds.sort((a, b) => a[0] - b[0]);
      for (const d of ds) console.log(d.join(" "));
    });'
  grep -n '// [PL][0-9][0-9]' "$f"
done

step "T6 the conformance libraries and the bindings analyze clean (warnings included)"
fvm dart analyze --fatal-infos $A/behavior $B/behavior $N/behavior $F/flutter-binding/behavior; echo "exit: $?"

step "T7 behavior: every suite that touches bus-api@v1, on the amended stand-in"
for b in $A/behavior/nidana_dart_runtime_test.dart $A/behavior/bus_activation_test.dart $B/behavior/nidana_dart_runtime_test.dart $N/behavior/nidana_dart_navigation_test.dart $N/behavior/in_memory_router_test.dart; do
  echo "-- $b"; fvm dart test "$b" 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
done
echo "-- $W (fvm flutter test, testWidgets, production-provider bus)"
fvm flutter test --no-pub $W 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"

step "T8 behavior: the G22 and G34 cases of bus-api@v1, by name prefix (--guarantee bus-api/G22,G34)"
fvm dart test --reporter expanded --name '^G(22|34) ' $A/behavior/nidana_dart_runtime_test.dart 2>&1 \
  | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' | grep -v '^loading'; echo "exit: ${PIPESTATUS[0]}"

step "T9 the S11 runtime, before both patches: the new cases fail, and the typed-publish rejects fail"
cp $RT/interpreter.dart $RT/interpreter.dart.amended; cp $RT/bus.dart $RT/bus.dart.amended
cp s11_runtime/interpreter.dart s11_runtime/bus.dart $RT/
grep -n "void publish<" $RT/bus.dart
echo "-- bus-api suite"
fvm dart test $A/behavior/nidana_dart_runtime_test.dart 2>&1 | grep -E '\[E\]$|Some tests failed|All tests passed' \
  | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
echo "-- topology-dsl live suite through bus_activation_test.dart"
fvm dart test $A/behavior/bus_activation_test.dart 2>&1 | tail -n 1
echo "-- bus-api reject"
fvm dart run nidana_contract_check:reject_check $A/reject | grep -E 'FAIL|publish'
echo "-- bus-api surface"
fvm dart analyze --fatal-infos $A/surface 2>&1 | grep -E 'error|warning|info|No issues' | sed -E 's/ - Try .*//'
mv $RT/interpreter.dart.amended $RT/interpreter.dart; mv $RT/bus.dart.amended $RT/bus.dart
echo "restored the amended runtime"

# report {command...}: runs the command and prints its failing lines.
report() {
  "$@" 2>&1 | grep -E '\[E\]$|Some tests failed|All tests passed|^FAIL|^PASS current_route|^PASS no_publisherless|^PASS publish' \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
}

# mutate {file} {label} {from} {to} {command...}: applies one textual defect
# to the stand-in, runs the command, and restores the file.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"; shift 4
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  report "$@"
  mv "$file.orig" "$file"
}

# swap {file} {variant} {label} {command...}: replaces one stand-in file by a
# variant, runs the command, and restores the file.
swap() {
  local file="$1" variant="$2" label="$3"; shift 3
  cp "$file" "$file.orig"; cp "$variant" "$file"
  echo "-- $label"
  report "$@"
  mv "$file.orig" "$file"
}

step "T10 seeded defects in the amended stand-in fail the fixtures of the guarantee they break"
mutate $RT/bus.dart "the publishes a connection causes are made within activate (G22)" \
  "    if (_connecting > 0) {" "    if (false) {" \
  fvm dart test $A/behavior/nidana_dart_runtime_test.dart
swap $RT/interpreter.dart naf_runtime/interpreter.dart \
  "a read the connection reached receives the deliveries made before the first microtask only after it, the navigation-api-fixtures runtime (G22, G34)" \
  fvm dart test $A/behavior/nidana_dart_runtime_test.dart
cp $RT/interpreter.dart $RT/interpreter.dart.orig; cp naf_runtime/interpreter.dart $RT/interpreter.dart
echo "   what the G34 deep-link case receives there: the queued state publish reaches the gate after the event queued after it"
fvm dart test --name '^G34 start delivers' $A/behavior/nidana_dart_runtime_test.dart 2>&1 | grep -E '^ +(Expected|Actual):'
mv $RT/interpreter.dart.orig $RT/interpreter.dart
swap $RT/interpreter.dart s11_runtime/interpreter.dart \
  "the connection reaches the reads one microtask after activate, the S11 runtime's interpreter (G22, G34)" \
  fvm dart test $A/behavior/nidana_dart_runtime_test.dart
mutate $RT/bus.dart "Bus.publish leaves T unbounded, the form publish<T, V extends T>; Publisher.publish keeps the amended form (Refinement 3)" \
  "  void publish<T extends Object?, V extends T>(MultiWriterTopic<T> topic, V value) {
    _checkOpen();" \
  "  void publish<T, V extends T>(MultiWriterTopic<T> topic, V value) {
    _checkOpen();" \
  bash -c "fvm dart run nidana_contract_check:reject_check $A/reject; fvm dart run nidana_contract_check:reject_check $N/reject"
mutate $RT/bus.dart "Bus.publish infers T from the value too, the form before the amendment; Publisher.publish keeps the amended form (G40)" \
  "  void publish<T extends Object?, V extends T>(MultiWriterTopic<T> topic, V value) {
    _checkOpen();" \
  "  void publish<T>(MultiWriterTopic<T> topic, T value) {
    _checkOpen();" \
  fvm dart run nidana_contract_check:reject_check $A/reject

step "cleanup: remove the copied tree and the Flutter build output; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd build; echo "removed"
