#!/usr/bin/env bash
# topology-dsl-fixtures: replays the topology-dsl@v1 fixtures, as written
# under the repository's hsdd/contract/, against
#   - a stand-in of nidana_dart_contracts that implements the contract's
#     Interface (packages/nidana_dart_contracts; its topic-model part is
#     copied from ../topic-model-fixtures/, its topology-ir part is a
#     placeholder with only what topology-dsl@v1 names), and
#   - a stand-in live implementation on RxDart 0.28 and a virtual scheduler
#     (packages/live_standin), bound to the live suite by a stand-in binding
#     (packages/live_standin/test/live_standin_test.dart, ADR-001 item 11).
#
# The repository has no pub workspace yet, so the fixtures and the contract
# are copied into this experiment's own workspace at the same relative paths.
# The replay tool's structure and reject sets are the prototypes of
# ../topic-model-fixtures/ (packages/nidana_contract_check/bin).
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
step() { echo; echo "### $*"; }

step "setup: copy the fixtures and the contract from the repository, resolve"
rm -rf hsdd && mkdir -p $F
cp $REPO/hsdd/contract/topology-dsl.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/topology-dsl $F/
find hsdd -type f | sort
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  (meta|matcher|test|rxdart|clock|lints):/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 workspace-wide analyze at the root skips hsdd/** (reject fixtures hold deliberate errors)"
fvm dart analyze --fatal-infos; echo "exit: $?"

step "T2 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check topology-dsl; echo "exit: $?"

step "T3 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $F/topology-dsl/surface; echo "exit: $?"

step "T4 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
fvm dart run nidana_contract_check:reject_check $F/topology-dsl/reject; echo "exit: $?"

step "T5 reject: the raw diagnostics behind T4, one line each (line severity code)"
for f in $F/topology-dsl/reject/*.dart; do
  echo "-- $(basename "$f")"
  fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      for (const d of JSON.parse(s).diagnostics)
        console.log(d.location.range.start.line, d.severity, d.code);
    });'
done

step "T6 behavior, recording: the binding under dart test, run from the root"
fvm dart test --reporter expanded $F/topology-dsl/behavior/topology_builder_test.dart 2>&1 | tail -n 30; echo "exit: ${PIPESTATUS[0]}"

step "T7 behavior, recording: a guarantee restriction by test-name prefix (--guarantee topology-dsl/G14)"
fvm dart test --reporter expanded --name '^G14 ' $F/topology-dsl/behavior/topology_builder_test.dart 2>&1 | tail -n 8; echo "exit: ${PIPESTATUS[0]}"

step "T8 behavior, live: the stand-in binding of the live suite"
fvm dart test --reporter expanded packages/live_standin/test/live_standin_test.dart 2>&1 | tail -n 50; echo "exit: ${PIPESTATUS[0]}"

step "T9 the conformance libraries and the binding analyze clean (warnings included)"
fvm dart analyze --fatal-infos $F/topology-dsl/behavior; echo "exit: $?"

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

DSL=packages/nidana_dart_contracts/lib/src/topology.dart
REC=$F/topology-dsl/behavior/topology_builder_test.dart
step "T10 the recording suite is not vacuous: each seeded defect in the stand-in recorder fails the cases of its guarantee"
mutate $DSL "dangling stages accepted (G15)" "if (!reached.contains(b._stages[i])) {" "if (false) {" $REC
mutate $DSL "dedup accepted on any read (G13)" "if (dedup != null && topic is! StateTopic<Object?>) {" "if (false) {" $REC
mutate $DSL "second sink on a state topic accepted (G14)" "if (topic is StateTopic<Object?> && !_stateSinks.add(topic)) {" "if (false) {" $REC
mutate $DSL "foreign handles accepted (G14)" "if (!identical(stream._builder, this)) {" "if (false) {" $REC
mutate $DSL "builder left open after declare (G15)" "    b._open = false;" "    b._open = true;" $REC
mutate $DSL "negative durations accepted (G14)" "  if (duration.isNegative) {" "  if (false) {" $REC
mutate $DSL "declare run twice per planOf (G9)" "    topology.declare(b);" "    topology.declare(TopologyBuilder._());
    topology.declare(b);" $REC
mutate $DSL "writes projected without reduceInto sinks (G12)" "writes: <TopicRef>{for (final k in plan.sinks) k.topic.ref}," "writes: <TopicRef>{for (final k in plan.sinks) if (k is WriteSink<Object?>) k.topic.ref}," $REC
mutate $DSL "stages recorded newest first (G11)" "    _stages.add(stage);" "    _stages.insert(0, stage);" $REC
mutate $DSL "combine4 passes its values out of order (G11)" "(v) => combiner(v[0] as A, v[1] as B, v[2] as C, v[3] as D));" "(v) => combiner(v[3] as A, v[2] as B, v[1] as C, v[0] as D));" $REC
mutate $DSL "a map stage keeps a wrapper, not the function passed (G11)" "_next(() => MapStage<T, R>._(_builder, this, transform));" "_next(() => MapStage<T, R>._(_builder, this, (T v) => transform(v)));" $REC
mutate $DSL "recording schedules a microtask (G10)" "  final b = TopologyBuilder._();" "  scheduleMicrotask(() {});
  final b = TopologyBuilder._();" $REC
mutate $DSL "recording calls a recover function (G10)" "_next(() => CatchErrorStage<T>._(_builder, this, recover));" "_next(() => CatchErrorStage<T>._(_builder, this, recover..call(StateError('probe'), StackTrace.empty)));" $REC
mutate $DSL "topology references equal whatever their ids (G17)" "bool operator ==(Object other) => other is TopologyRef && other.id == id;" "bool operator ==(Object other) => other is TopologyRef;" $REC
mutate $DSL "a map stage is visited as another stage (G16)" "V _accept<V>(StageVisitor<V> visitor) => visitor.map<T, R>(this);" "V _accept<V>(StageVisitor<V> visitor) =>
      visitor.distinctUntilChanged<R>(DistinctUntilChangedStage<R>._(_builder, this));" $REC

LIVE=packages/live_standin/lib/live_standin.dart
LT=packages/live_standin/test/live_standin_test.dart
step "T11 the live suite is not vacuous: each seeded defect in the stand-in live implementation fails the cases of its guarantee"
mutate $LIVE "switchMap waits for the previous inner cancel future (G22)" "      inner?.cancel(); // not awaited
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
      }" $LT
mutate $LIVE "switchMap listens to the next inner after a root-zone microtask, as RxDart 0.28 does (G22)" "      attempt = 0;
      start(v);" "      attempt = 0;
      Zone.root.scheduleMicrotask(() => _bus.zone.run(() => start(v)));" $LT
mutate $LIVE "activation records the definition with a second declare run (G18)" "      zone.run(() => Activation._(this, planOf(topology)));" "      zone.run(() { topology.buildDefinition(); return Activation._(this, planOf(topology)); });" $LT
mutate $LIVE "a read ignores its Dedup.none (G19)" "final dedup = topic is StateTopic<T> ? (stage.dedup ?? topic.dedup) : Dedup.none;" "final dedup = topic is StateTopic<T> ? topic.dedup : Dedup.none;" $LT
mutate $LIVE "a read does not replay the buffer of a replay topic (G19)" "      if (t is ReplayTopic<T>) List<_Delivery<T>>.of(_buffer).forEach(onData);" "" $LT
mutate $LIVE "scan emits its seed first (G20)" "    var acc = stage.initial;
    out.listenTo(" "    var acc = stage.initial;
    out.connect = () => out.add((payload: acc, lineage: const Lineage.root()));
    out.listenTo(" $LT
mutate $LIVE "withLatestFrom emits before every latest input has a value (G21)" "      if (lineages.any((l) => l == null)) return;
      final lineage = Lineage.withLatestFrom(" "      if (lineages.every((l) => l == null) && false) return;
      final lineage = Lineage.withLatestFrom(" $LT
mutate $LIVE "a retry does not wait for its delay (G22)" "        retryTimer = Timer(delay, () => start(v));" "        retryTimer = Timer(Duration.zero, () => start(v));" $LT
mutate $LIVE "throttle emits trailing values too (G23)" "stage.input).stream.throttleTime(stage.duration));" "stage.input).stream.throttleTime(stage.duration, trailing: true));" $LT
mutate $LIVE "buffer emits empty batches (G23)" "      if (batch.isEmpty) return; // RxDart emits empty windows" "" $LT
mutate $LIVE "reduceInto seeds from the declared initial value (G24)" "    var state = _a._bus._cell(sink.topic).current;" "    var state = sink.topic.createInitial();" $LT
mutate $LIVE "map starts a new flow instead of passing its input lineage (G25)" "(PipelineValue<T> v) => _guard(out, v.lineage, () => stage.transform(v.payload)));" "(PipelineValue<T> v) => _guard(out, const Lineage.root(), () => stage.transform(v.payload)));" $LT
mutate $LIVE "combine takes the first input as trigger (G25)" "            trigger: i, freshCorrelationId: _bus.freshCorrelationId);" "            trigger: 0, freshCorrelationId: _bus.freshCorrelationId);" $LT
mutate $LIVE "an untraced read keeps the envelope lineage (G25)" "lineage: env == null || topic.tracing == Tracing.disabled" "lineage: env == null" $LT
mutate $LIVE "a recovered value starts a new flow (G25)" "            _guard(out, _lineageOf(e), () => stage.recover(_unwrap(e), st))));" "            _guard(out, const Lineage.root(), () => stage.recover(_unwrap(e), st))));" $LT
mutate $LIVE "a sink goes on after an error (G26)" "      onError: (Object e, StackTrace st) {
        sub.cancel();" "      onError: (Object e, StackTrace st) {" $LT
mutate $LIVE "sinks are wired in reverse declaration order (G27)" "    for (final k in _plan.sinks) {" "    for (final k in _plan.sinks.reversed) {" $LT
mutate $LIVE "a map stage is interpreted once per consumer (G27)" "  Hub<T> hub<T>(TopicStream<T> s) => _hubs[s]! as Hub<T>;" "  Hub<T> hub<T>(TopicStream<T> s) =>
      (s is MapStage<Object?, Object?> ? visitStage(s, this) : _hubs[s]!) as Hub<T>;" $LT
mutate $LIVE "the raw operator is called twice per activation (G28)" "      ..forward(stage.operator(unwrapped, _bus.freshCorrelationId));" "      ..forward(stage.operator(unwrapped, _bus.freshCorrelationId))
      ..forward(stage.operator(unwrapped, _bus.freshCorrelationId).where((_) => false));" $LT
mutate $LIVE "deactivation leaves the switchMap inner subscription (G29)" "    out.extraCancel = () {
      inner?.cancel();" "    out.extraCancel = () {" $LT

step "T12 a stage class added to the Interface fails the surface set (StageVisitor implemented in full)"
cp $DSL "$DSL.orig"
perl -0pi -e 's/(abstract interface class StageVisitor<V> \{\n)/$1  V window<T>(DebounceStage<T> stage);\n/' $DSL
grep -c 'V window<T>' $DSL
fvm dart analyze --fatal-infos --format=machine $F/topology-dsl/surface | cut -d'|' -f3,4,5,6 ; echo "exit: ${PIPESTATUS[0]}"
mv "$DSL.orig" $DSL
echo "stand-in restored"

step "cleanup: remove the copied tree; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd; echo "removed"
