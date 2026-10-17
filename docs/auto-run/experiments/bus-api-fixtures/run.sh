#!/usr/bin/env bash
# bus-api-fixtures: replays the bus-api@v1 fixtures, as written under the
# repository's hsdd/contract/, against
#   - a stand-in of nidana_dart_contracts (packages/nidana_dart_contracts,
#     copied from ../topology-ir-fixtures/) carrying the topic-model@v1
#     amendment bus-api@v1 needs: a sealed MultiWriterTopic<T> above
#     EventTopic<T> and ReplayTopic<T>;
#   - a stand-in of nidana_dart_runtime (packages/nidana_dart_runtime) that
#     implements bus-api@v1's Interface on RxDart 0.28 sync subjects, with
#     the live interpreter adapted from ../topology-dsl-fixtures/, and a
#     stand-in testing.dart holding the bus-testing@v1 names the bindings
#     forward-reference (TestBus, VirtualScheduler, the recorder).
# Both bindings run unchanged from the repository: the bus-api suite and
# topology-dsl@v1's live suite.
#
# The repository has no pub workspace yet, so the fixtures and the contract
# are copied into this experiment's own workspace at the same relative paths.
# The replay tool's structure and reject sets are the prototypes of
# ../topology-ir-fixtures/ (packages/nidana_contract_check/bin).
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
B=$F/bus-api
step() { echo; echo "### $*"; }

step "setup: copy the contract and the fixtures from the repository, resolve"
rm -rf hsdd && mkdir -p $F
cp $REPO/hsdd/contract/bus-api.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/bus-api $REPO/$F/topology-dsl $F/
find hsdd/contract/bus-api.md $B -type f | sort
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  (meta|matcher|test|rxdart|clock|lints):/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 workspace-wide analyze at the root skips hsdd/** (reject fixtures hold deliberate errors)"
fvm dart analyze --fatal-infos; echo "exit: $?"

step "T2 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check bus-api; echo "exit: $?"

step "T3 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $B/surface; echo "exit: $?"

step "T4 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
fvm dart run nidana_contract_check:reject_check $B/reject; echo "exit: $?"

step "T5 reject: the raw diagnostics behind T4, one line each (line severity code)"
for f in $B/reject/*.dart; do
  echo "-- $(basename "$f")"
  fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      for (const d of JSON.parse(s).diagnostics)
        console.log(d.location.range.start.line, d.severity, d.code);
    });'
done

step "T6 the conformance library and both bindings analyze clean (warnings included)"
fvm dart analyze --fatal-infos $B/behavior; echo "exit: $?"

step "T7 behavior: the bus-api suite on the stand-in TestBus, under dart test from the root"
fvm dart test --reporter expanded $B/behavior/nidana_dart_runtime_test.dart 2>&1 | tail -n 95; echo "exit: ${PIPESTATUS[0]}"

step "T8 behavior: a guarantee restriction by test-name prefix (--guarantee bus-api/G17)"
fvm dart test --reporter expanded --name '^G17 ' $B/behavior/nidana_dart_runtime_test.dart 2>&1 | tail -n 4; echo "exit: ${PIPESTATUS[0]}"

step "T9 behavior: topology-dsl@v1's live suite bound to Bus.activate on the stand-in TestBus"
fvm dart test --reporter expanded $B/behavior/bus_activation_test.dart 2>&1 | tail -n 50; echo "exit: ${PIPESTATUS[0]}"

# mutate {file} {label} {from} {to} {test file}: applies one textual defect,
# runs the suite, prints the failing cases, and restores the file.
mutate() {
  local file="$1" label="$2" from="$3" to="$4" suite="$5"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  fvm dart test "$suite" 2>&1 \
    | grep -E '\[E\]$|Some tests failed|All tests passed|Error:' \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
  mv "$file.orig" "$file"
}

BUS=packages/nidana_dart_runtime/lib/src/bus.dart
INT=packages/nidana_dart_runtime/lib/src/interpreter.dart
DIAG=packages/nidana_dart_runtime/lib/src/diagnostics.dart
T=$B/behavior/nidana_dart_runtime_test.dart
L=$B/behavior/bus_activation_test.dart
step "T10 the bus-api suite is not vacuous: each seeded defect in the stand-in fails the cases of its guarantee"
mutate $BUS "a limit below 1 accepted (G3)" "throw ArgumentError('a limit is below 1');" "print('limit ignored');" $T
mutate $BUS "diagnostics delivered outside dev mode (G4)" "    if (!devMode) return;
" "" $T
mutate $BUS "an observed stream subscribes in the listener's zone (G5)" "      _bus._zone.run(() {
        if (_bus._lifecycle == BusLifecycle.shutDown) {" "      Zone.current.run(() {
        if (_bus._lifecycle == BusLifecycle.shutDown) {" $T
mutate $BUS "a delivery runs in the publisher's zone (G5)" "    _zone.run(() => _run(p));" "    _run(p);" $T
mutate $BUS "a different sensitive flag shares the subject (G7)" "  if (a.sensitive != b.sensitive || a.tracing != b.tracing) return false;" "  if (a.tracing != b.tracing) return false;" $T
mutate $BUS "the buffer is handed out modifiable (G8)" "  List<T> get buffered => List<T>.unmodifiable(_buffer);" "  List<T> get buffered => _buffer;" $T
mutate $BUS "removal ignores live subscribers (G9)" "    if (c.subject.hasListener && !force) return false;" "    if (false) return false;" $T
mutate $BUS "the active topology limit is not checked (G10)" "    if (_active.length >= config.maxActiveTopologies) {" "    if (false) {" $T
mutate $BUS "a publisher-less publish is not reported (G11)" "    _report(PublisherlessPublish(topic: topic.ref));" "" $T
mutate $BUS "shell publishes share one correlation (G12)" "    _bus._publish(topic, value,
        lineage: const Lineage.root(), source: source, owner: this);" "    _bus._publish(topic, value,
        lineage: const Lineage.root(correlationId: 'shared'), source: source, owner: this);" $T
mutate $BUS "a reentrant publish is delivered at once, depth first (G14)" "    if (_delivering > 0) {
      p.chain" "    if (false) {
      p.chain" $T
mutate $BUS "reentrant publishes are delivered newest first (G14)" "      _deferred.add(p);" "      _deferred.addFirst(p);" $T
mutate $BUS "a deep reentrant chain is not reported (G15)" "      if (p.chain.length - 1 == config.maxReentrancyDepth + 1) {" "      if (false) {" $T
mutate $BUS "an observed subscription ignores dedup (G16)" "    if (dedup == Dedup.none || topic is! StateTopic<T>) return s;" "    return s;" $T
mutate $BUS "an equal publish is dropped before observers and Dedup.none reads (G16)" "    final cell = _cell(topic);
    _recorder?._record(topic.ref, envelope);" "    final cell = _cell(topic);
    if (topic is StateTopic<T> && topic.dedup == Dedup.equality && cell.current == envelope.payload) return;
    _recorder?._record(topic.ref, envelope);" $T
mutate $BUS "an observed subscription drops its first value (G17)" "        inner = cell.stream(dedup).listen(" "        inner = cell.stream(dedup).skip(1).listen(" $T
mutate $BUS "a topology or unknown source is accepted (G19)" "    if (source is TopologySource || source is UnknownSource) {" "    if (false) {" $T
mutate $BUS "a conflicting claim is accepted (G20)" "      if (findings.isNotEmpty) {
        throw ClaimRejected" "      if (false) {
        throw ClaimRejected" $T
mutate $BUS "dispose keeps the publisher's queued publishes (G21)" "    _bus._publishers.remove(this);
    _bus._discard(this);" "    _bus._publishers.remove(this);" $T
mutate $BUS "a late APPLICATION activation is not reported (G22)" "    if (definition.scope == Scope.application &&" "    if (false &&" $T
mutate $BUS "an equal definition is not recognized (G23)" "      if (existing.definition == definition) return existing.handle;
" "" $T
mutate $BUS "activation findings are ignored (G24)" "    if (findings.isNotEmpty) {
      throw ActivationRejected(" "    if (false) {
      throw ActivationRejected(" $T
mutate $BUS "a module accepts a page-scoped topology (G27)" "      if (t.scope != Scope.module) {" "      if (false) {" $T
mutate $BUS "the grace period is ignored (G28)" "    if (gracePeriod == Duration.zero) {" "    if (true) {" $T
mutate $BUS "a release below the last tears the module down (G28)" "    if (_references > 0) return;
" "" $T
mutate $BUS "subscribers are served before observers (G29)" "    if (topic.tracing == Tracing.enabled) {
      for (final o in List<BusObserver>.of(_observers)) {" "    cell.add(envelope);
    if (topic.tracing == Tracing.enabled) {
      for (final o in List<BusObserver>.of(_observers)) {" $T
mutate $BUS "observers see sensitive envelopes without the grant (G30)" "        if (!ObserverCapability.permits(o.capabilities,
            sensitive: envelope.sensitive)) {" "        if (false) {" $T
mutate $BUS "observers see untraced topics (G30)" "    if (topic.tracing == Tracing.enabled) {" "    if (true) {" $T
mutate $BUS "an observer exception is not reported (G31)" "          _report(ObserverThrew(
              observer: o, topic: topic.ref, error: e, stackTrace: st));" "" $T
mutate $BUS "activation observers are never told (G32)" "    for (final o in List<BusObserver>.of(_observers)) {
      if (o is! ActivationObserver) continue;" "    for (final o in const <BusObserver>[]) {
      if (o is! ActivationObserver) continue;" $T
mutate $BUS "telemetry spans are not linked to their cause (G33)" "          links: <String>[?causation]," "          links: const <String>[]," $T
mutate $BUS "publishes before start are delivered at once (G34)" "    if (_lifecycle == BusLifecycle.bootstrapping) {
      _startupQueue.add(p);" "    if (false) {
      _startupQueue.add(p);" $T
mutate $BUS "the startup window is never armed (G35)" "    if (!devMode || _windowTimer != null) return;" "    return;" $T
mutate $BUS "shutdown does not drain the pending reentrant publishes (G36)" "      if (_lifecycle == BusLifecycle.running) _drain();" "" $T
mutate $BUS "shutdown callbacks run in registration order (G36)" "      for (final cb in _shutdownCallbacks.reversed) {" "      for (final cb in _shutdownCallbacks) {" $T
mutate $BUS "the live graph leaves out the claims (G37)" "            if (p.writes.isNotEmpty)
              ShellClaim(" "            if (false)
              ShellClaim(" $T
mutate $INT "deactivation keeps the topology's queued publishes (G25)" "    _bus._active.remove(topologyId);
    _bus._discard(this);" "    _bus._active.remove(topologyId);" $T
mutate $INT "a terminated sink is not reported (G26)" "        sub.cancel();
        _a._terminated(sink.topic, e, st);" "        sub.cancel();" $T

step "T11 the live binding is not vacuous: seeded defects in the stand-in's interpreter and recorder fail the live cases"
mutate $INT "a read ignores its Dedup.none (live G19)" "        topic is StateTopic<T> ? (stage.dedup ?? topic.dedup) : Dedup.none;" "        topic is StateTopic<T> ? topic.dedup : Dedup.none;" $L
mutate $INT "reduceInto seeds from the declared initial value (live G24)" "    var state = _a._bus._cell(sink.topic).current;" "    var state = sink.topic.createInitial();" $L
mutate $INT "switchMap waits for the previous inner cancel future (live G22)" "      inner?.cancel(); // not awaited
      retryTimer?.cancel();
      inner = null;
      attempt = 0;
      start(v);" "      final pending = inner?.cancel();
      retryTimer?.cancel();
      inner = null;
      attempt = 0;
      if (pending == null) {
        start(v);
      } else {
        pending.then((_) => start(v));
      }" $L
mutate $BUS "the recorder leaves out untraced topics (live G25, a bus-testing@v1 requirement)" "    _recorder?._record(topic.ref, envelope);" "    if (topic.tracing == Tracing.enabled) _recorder?._record(topic.ref, envelope);" $L

step "T12 a diagnostic variant added to the Interface fails the surface set (exhaustive switch)"
cp "$DIAG" "$DIAG.orig"
printf '\nfinal class ProbeDiagnostic extends BusDiagnostic {\n  const ProbeDiagnostic();\n}\n' >> "$DIAG"
fvm dart analyze --fatal-infos --format=machine $B/surface | cut -d'|' -f3,4,5,6 ; echo "exit: ${PIPESTATUS[0]}"
mv "$DIAG.orig" "$DIAG"
echo "stand-in restored"

step "T13 close timing of RxDart sync subjects (tool/close_probe.dart, also in output-close.txt)"
fvm dart run tool/close_probe.dart

step "cleanup: remove the copied tree; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd; echo "removed"
