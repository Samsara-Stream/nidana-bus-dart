#!/usr/bin/env bash
# bus-testing-fixtures: replays the bus-testing@v1 fixtures, as written under
# the repository's hsdd/contract/, against
#   - the stand-in nidana_dart_contracts of ../bus-api-fixtures/ (it carries
#     topic-model@v1's MultiWriterTopic and RedactedPayload);
#   - a stand-in nidana_dart_runtime copied from ../bus-api-fixtures/, whose
#     part lib/src/testing.dart now implements bus-testing@v1's Interface
#     (VirtualScheduler, VirtualSchedulerProvider, TestBus with input, stub
#     and deterministic ids, EnvelopeRecorder with redaction, RecordedEnvelope,
#     OrderingProbe) and whose bus calls every attached recorder at delivery.
# It also runs bus-api@v1's two bindings unchanged against the same stand-in,
# to show that the names they forward-reference are the ones bus-testing@v1
# declares.
#
# The repository has no pub workspace yet, so the fixtures and the contracts
# are copied into this experiment's own workspace at the same relative paths.
# The replay tool's structure and reject sets are the prototypes of
# ../topology-ir-fixtures/ (packages/nidana_contract_check/bin).
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
B=$F/bus-testing
A=$F/bus-api
step() { echo; echo "### $*"; }

step "setup: copy the contracts and the fixtures from the repository, resolve"
rm -rf hsdd && mkdir -p $F
cp $REPO/hsdd/contract/bus-testing.md $REPO/hsdd/contract/bus-api.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/bus-testing $REPO/$F/bus-api $REPO/$F/topology-dsl $F/
find hsdd/contract/bus-testing.md $B -type f | sort
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  (meta|matcher|test|rxdart|clock|lints):/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check bus-testing; echo "exit: $?"
echo "-- bus-api, unchanged, against the same stand-in"
fvm dart run nidana_contract_check:structure_check bus-api | tail -n 2; echo "exit: ${PIPESTATUS[0]}"

step "T2 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $B/surface; echo "exit: $?"

step "T3 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
fvm dart run nidana_contract_check:reject_check $B/reject; echo "exit: $?"

step "T4 reject: the raw diagnostics behind T3, one line each (line severity code)"
for f in $B/reject/*.dart; do
  echo "-- $(basename "$f")"
  fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      for (const d of JSON.parse(s).diagnostics)
        console.log(d.location.range.start.line, d.severity, d.code);
    });'
done

step "T5 the conformance library and the binding analyze clean (warnings included)"
fvm dart analyze --fatal-infos $B/behavior; echo "exit: $?"

step "T6 behavior: the bus-testing suite on the stand-in, under dart test from the root"
fvm dart test --reporter expanded $B/behavior/nidana_dart_runtime_test.dart 2>&1 | tail -n 48; echo "exit: ${PIPESTATUS[0]}"

step "T7 behavior: a guarantee restriction by test-name prefix (--guarantee bus-testing/G12)"
fvm dart test --reporter expanded --name '^G12 ' $B/behavior/nidana_dart_runtime_test.dart 2>&1 | tail -n 5; echo "exit: ${PIPESTATUS[0]}"

step "T8 bus-api@v1's surface, reject and binding files analyze clean against this testing.dart"
fvm dart analyze --fatal-infos $A/surface $A/behavior; echo "exit: $?"
fvm dart run nidana_contract_check:reject_check $A/reject | tail -n 8; echo "exit: ${PIPESTATUS[0]}"

step "T9 bus-api@v1's two bindings run unchanged on this TestBus (names adopted, deterministic ids)"
fvm dart test $A/behavior/nidana_dart_runtime_test.dart 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
fvm dart test $A/behavior/bus_activation_test.dart 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"

# mutate {file} {label} {from} {to} {test file}: applies one textual defect,
# runs the suite, prints the failing cases, and restores the file. A
# watchdog kills a run that has not finished after 120 s and says so.
mutate() {
  local file="$1" label="$2" from="$3" to="$4" suite="$5"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  fvm dart test "$suite" > mutate.log 2>&1 &
  local pid=$!
  ( trap 'kill "$s" 2>/dev/null; exit 0' TERM; sleep 120 & s=$!; wait "$s"
    if kill -0 "$pid" 2>/dev/null; then echo "TIMED OUT after 120 s" >> mutate.log; pkill -f "$suite"; fi ) &
  local dog=$!
  wait "$pid"
  kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null
  grep -E '\[E\]$|Some tests failed|All tests passed|Error:|TIMED OUT' mutate.log \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
  rm -f mutate.log
  mv "$file.orig" "$file"
}

TS=packages/nidana_dart_runtime/lib/src/testing.dart
BUS=packages/nidana_dart_runtime/lib/src/bus.dart
T=$B/behavior/nidana_dart_runtime_test.dart
step "T10 the bus-testing suite is not vacuous: each seeded defect in the stand-in fails the cases of its guarantee"
mutate $TS "a TestBus accepts the production provider (G3)" "ProductionSchedulerProvider() => throw ArgumentError.value(
            config.scheduler, 'config', 'names the production provider')," "ProductionSchedulerProvider() => VirtualSchedulerProvider(VirtualScheduler())," $T
mutate $TS "a fresh scheduler is built in the root zone, not the construction zone (G3)" "        null => VirtualSchedulerProvider(VirtualScheduler())," "        null => VirtualSchedulerProvider(Zone.root.run(VirtualScheduler.new))," $T
mutate $BUS "a bus ignores the virtual provider's zone (G4)" "        _zone = scheduler._zone;" "        _zone = Zone.current;" $T
mutate $TS "virtual time starts at the Unix epoch (G5)" "  static final DateTime defaultInitialTime = DateTime.utc(2000);" "  static final DateTime defaultInitialTime = DateTime.utc(1970);" $T
mutate $TS "the zone does not install the virtual clock (G5)" "    _zone = c.withClock(
      clock,
      () => Zone.current.fork(" "    _zone = ((Zone Function() f) => f())(
      () => Zone.current.fork(" $T
mutate $TS "microtasks are forwarded to the parent zone (G6)" "          scheduleMicrotask: (self, parent, zone, f) =>
              _microtasks.add(() => zone.runGuarded(f))," "          scheduleMicrotask: (self, parent, zone, f) =>
              parent.scheduleMicrotask(zone, f)," $T
mutate $TS "cancel leaves the timer pending (G6, G9)" "  void cancel() => _s._timers.remove(this);" "  void cancel() {}" $T
mutate $TS "run does not enter the zone (G6)" "  R run<R>(R Function() body) => _zone.run(body);" "  R run<R>(R Function() body) => body();" $T
mutate $TS "microtasks run newest first (G7)" "        _microtasks.removeFirst()();" "        _microtasks.removeLast()();" $T
mutate $TS "timers due at one instant fire newest first (G7)" "          (t.due == best.due && t.seq < best.seq)) {" "          (t.due == best.due && t.seq > best.seq)) {" $T
mutate $TS "an advance jumps straight to its target (G8)" "        _elapsed = t.due;" "        _elapsed = target;" $T
mutate $TS "a negative duration is accepted (G8)" "    if (duration.isNegative) {" "    if (false) {" $T
mutate $TS "nextTimerDue reports the latest timer (G9)" "      if (best == null || t.due < best) best = t.due;" "      if (best == null || t.due > best) best = t.due;" $T
mutate $TS "an operation inside running work is not refused (G10)" "    if (_running) {
      throw StateError(
          'a VirtualScheduler operation was called from inside work it runs');
    }
    _running = true;" "    _running = true;" $T
mutate $TS "the action bound drops the action it refuses (G10)" "        _count();
        _microtasks.removeFirst()();" "        final m = _microtasks.removeFirst();
        _count();
        m();" $T
mutate $TS "a bound below one is accepted (G10)" "    if (maxActions < 1) {" "    if (false) {" $T
# The SDK already binds scheduleMicrotask and Timer callbacks guarded
# (bindCallbackGuarded), so replacing runGuarded with run changes nothing; the
# defect that breaks G11 is a scheduler zone that handles errors itself.
mutate $TS "the scheduler zone swallows uncaught errors (G11)" "        specification: ZoneSpecification(
" "        specification: ZoneSpecification(
          handleUncaughtError: (self, parent, zone, e, st) {},
" $T
mutate $TS "settle returns before any real turn (G12)" "      await Future<void>.delayed(Duration.zero);
      if (_quiescent) return;" "      if (_quiescent) return;
      await Future<void>.delayed(Duration.zero);" $T
mutate $TS "settle completes when it runs out of turns (G12)" "    throw StateError('the VirtualScheduler did not settle in '
        '\$maxSettleTurns real turns');" "    return;" $T
mutate $TS "settle inside the zone is not refused (G12)" "    if (_inZone()) {" "    if (false) {" $T
mutate $TS "TestBus ids are random (G13)" "  String _freshId() => 'e\${++_testIds}';" "  String _freshId() => 'e\${Random().nextInt(1 << 30)}';" $T
mutate $BUS "the recorder leaves out untraced topics (G14)" "      r._record(topic.ref, envelope);
    }
    if (topic.tracing == Tracing.enabled) {" "      if (topic.tracing == Tracing.enabled) r._record(topic.ref, envelope);
    }
    if (topic.tracing == Tracing.enabled) {" $T
mutate $BUS "the recorder records after the delivery, in a microtask (G14)" "      r._record(topic.ref, envelope);
    }
    if (topic.tracing == Tracing.enabled) {" "      _zone.scheduleMicrotask(() => r._record(topic.ref, envelope));
    }
    if (topic.tracing == Tracing.enabled) {" $T
mutate $TS "the recorder does not redact (G15)" "      : envelope = unredacted.redacted();" "      : envelope = unredacted;" $T
mutate $TS "typed queries need no opt-in for a sensitive topic (G15)" "    if (topic.sensitive && !unredacted) {" "    if (false) {" $T
mutate $TS "envelopes is a live view, not a snapshot (G16)" "      List<RecordedEnvelope>.unmodifiable(_records);" "      UnmodifiableListView<RecordedEnvelope>(_records);" $T
mutate $TS "record equality ignores the topic (G16)" "      other.topic == topic &&" "" $T
mutate $TS "a recorder attaches to a shut-down bus (G17)" "    bus._checkOpen();
    final r = EnvelopeRecorder._();" "    final r = EnvelopeRecorder._();" $T
mutate $TS "a new recorder replaces the earlier ones (G17)" "    bus._recorders.add(r);" "    bus._recorders..clear()..add(r);" $T
mutate $TS "stub claims anew on every call (G18)" "    if (existing != null) return existing as StateWriter<T>;" "" $T
mutate $TS "input publishes with another source (G18)" "  late final Publisher input = publisher(testSource);" "  late final Publisher input = publisher(const ServiceSource('input'));" $T
mutate $TS "the probe's later subscriptions skip values (G19)" "      p._subscriptions.add(stream.listen(got.add));" "      p._subscriptions.add(stream.skip(i).listen(got.add));" $T
mutate $TS "cancel leaves the probe subscribed (G19)" "      s.cancel(); // never awaited (ADR-003 item 3)" "      // s.cancel();" $T
mutate $BUS "a bus whose later subscriptions miss a delivery fails the probe (G19)" "        inner = cell.stream(dedup).listen((d) => out.add(d.payload)," "        inner = cell.stream(dedup).skip(cell.observers.length > 1 ? 1 : 0).listen((d) => out.add(d.payload)," $T

step "T11 settle facts (tool/settle_probe.dart, also in output-settle.txt)"
fvm dart run tool/settle_probe.dart

step "cleanup: remove the copied tree; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd; echo "removed"
