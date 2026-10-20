#!/usr/bin/env bash
# bus-api-v2: S60 (hsdd-contract, H3 of the v0.15.1 intake) classifies
# bus-api's changes for Specification v0.15.1 by replay and pins them:
#
# - L1, the startup barrier (Spec §3.13, §2.1): a bootstrap activation or
#   subscription is not connected until start(); start() connects the
#   activations in topological order of their read/write graph, delivering
#   what each connection causes before the next connects, then the
#   bootstrap subscriptions, then the queue (G34, G22, G17, G6, G9, G25).
# - L2, scope timing (Spec §7.2): a MODULE or PAGE activation, or a module's
#   acquire, before start() throws StateError (G42); LateApplicationActivation
#   (G22).
# - L3, write chains (Spec §10.2): G26 per chain; claims kept.
# - L4, subscriber errors (Spec §10.2 principle 5): to the listen zone (G5,
#   G18); conversions as error events and read-stage errors (G41); the bus's
#   own delivery code (G13).
# - L5, the name check (Spec §4.3): G7.
# - L6, re-activation (Spec §3.9, Guide §6.3): G23 compares the plan's
#   functions and seeds.
#
# Runtimes, each swapped into packages/nidana_dart_runtime/lib/src/:
#   v1          runtime/v1/: ../topology-dsl-write-chain/'s write-chain
#               runtime, a bus-api@v1 runtime with topology-dsl@v2's write
#               chains, which passes every v1 suite;
#   barrier-min runtime/barrier-min/: ../topology-dsl-write-chain/'s minimal
#               barrier (connection at start(), MODULE before start()
#               rejected), which does not settle a writer before its readers;
#   v2          runtime/v2/: barrier-min extended to bus-api@v2, every change
#               marked "bus-api-v2".
# packages/ holds the v2 runtime at rest. The other stand-in packages are
# ../topology-dsl-write-chain/packages/ unchanged (setup shows it). For the
# other suites the adapters take the patches the later replays of their own
# contracts used (patch/, as in ../topology-dsl-write-chain/).
#
# Fixture trees, each copied to hsdd/ in turn: hsdd-before/ is hsdd/contract
# at HEAD (git archive), the tree this step starts from; "after" is the
# repository's hsdd/contract as it stands.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
A=$F/bus-api
B=$F/bus-testing
N=$F/navigation-api
FB=$F/flutter-binding
API=$A/behavior/nidana_dart_runtime_test.dart
LIVE=$A/behavior/bus_activation_test.dart
RT=packages/nidana_dart_runtime/lib/src
WC=../topology-dsl-write-chain
step() { echo; echo "### $*"; }

use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$A "$1"/$B "$1"/$N "$1"/$FB "$1"/$F/topology-dsl $F/
}

runtime() { cp runtime/"$1"/bus.dart runtime/"$1"/interpreter.dart $RT/; }

suite() {
  echo "-- $*"
  fvm dart test --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

fsuite() {
  echo "-- $* (fvm flutter test)"
  fvm flutter test --no-pub --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

# why {file} {name prefix}: the first lines of the failure of that case.
why() {
  echo "-- why: $2"
  fvm dart test --plain-name "$2" "$1" 2>&1 \
    | grep -E 'Expected|Actual|Bad state|Which' | head -n 4
}

NAV=packages/nidana_dart_navigation/lib/src/navigation.dart
FSRC=packages/nidana_dart_runtime_flutter/lib/src
adapters() {
  if [ "$1" = on ]; then
    cp $NAV $NAV.copied; cp patch/navigation.named.dart $NAV
    for f in page_scope topic_builders widget_test_bus; do
      cp $FSRC/$f.dart $FSRC/$f.dart.copied; cp patch/$f.amended.dart $FSRC/$f.dart
    done
  else
    mv $NAV.copied $NAV
    for f in page_scope topic_builders widget_test_bus; do mv $FSRC/$f.dart.copied $FSRC/$f.dart; done
  fi
}

# others: every other suite that imports nidana_dart_runtime.
others() {
  adapters on
  suite $B/behavior/nidana_dart_runtime_test.dart
  suite $N/behavior/nidana_dart_navigation_test.dart
  suite $N/behavior/in_memory_router_test.dart
  fsuite $FB/behavior/nidana_dart_runtime_flutter_test.dart
  fsuite $FB/behavior/flutter_navigation_executor_test.dart
  adapters off
}

# mutate {file} {label} {from} {to} {test file}: one textual defect in the
# v2 runtime, the bus-api suite run, the file restored.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "== seeded defect: $label"
  suite $API
  mv "$file.orig" "$file"
}

step "setup: the before tree from git HEAD, resolve, versions, the runtimes' provenance"
rm -rf hsdd-before && mkdir hsdd-before
git -C $REPO archive HEAD hsdd/contract | tar -x -C hsdd-before
git -C $REPO rev-parse --short HEAD
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version
for f in bus interpreter; do
  cmp -s runtime/v1/$f.dart $WC/patch/$f.write_chain.dart && echo "runtime/v1/$f.dart: same as $WC/patch/$f.write_chain.dart"
  cmp -s runtime/barrier-min/$f.dart $WC/patch/$f.barrier.dart && echo "runtime/barrier-min/$f.dart: same as $WC/patch/$f.barrier.dart"
done
diff -r -q -x .dart_tool -x bus.dart -x interpreter.dart packages $WC/packages && echo "other stand-in files: same as $WC/packages"
for f in navigation.named page_scope.amended topic_builders.amended widget_test_bus.amended; do
  cmp -s patch/$f.dart $WC/patch/$f.dart && echo "patch/$f.dart: same"
done
echo "-- lines the v2 runtime changes against barrier-min"
for f in bus interpreter; do
  diff -u runtime/barrier-min/$f.dart runtime/v2/$f.dart | grep -c '^[+-][^+-]' | sed "s/^/$f.dart: /"
done

step "T1 the fixture change: case names before and after"
use $REPO
grep -cE "^    name: 'G" hsdd-before/$A/behavior/bus_api_conformance.dart | sed 's/^/cases before: /'
grep -cE "^    name: 'G" $A/behavior/bus_api_conformance.dart | sed 's/^/cases after: /'
diff <(grep -oE "^    name: '[^']*'" hsdd-before/$A/behavior/bus_api_conformance.dart) \
     <(grep -oE "^    name: '[^']*'" $A/behavior/bus_api_conformance.dart) | grep -E '^[<>]'
echo "-- other files of the fixture tree that differ"
diff -r -q hsdd-before/$A $A | grep -v bus_api_conformance

step "T2 structure (prototype) for bus-api, and S17's prototype over the repository's contracts"
runtime v2
fvm dart run nidana_contract_check:structure_check bus-api | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check bus-api | grep -c '^PASS G' | sed 's/^/guarantees covered: /'
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)

step "T3 surface, reject and behavior libraries analyzed; the stand-in and the probes"
fvm dart analyze --fatal-infos $A/surface; echo "surface exit: $?"
fvm dart run nidana_contract_check:reject_check $A/reject; echo "reject exit: $?"
fvm dart analyze --fatal-infos $A/behavior; echo "behavior exit: $?"
fvm dart analyze --fatal-infos packages probe; echo "stand-in and probes exit: $?"

step "T4 probe P1: which functions compare == across two evaluations of declare (G23)"
fvm dart run probe/function_equality.dart

step "T5 probe P2: a reader activated before its input's writer, on each runtime (G34)"
for r in v1 barrier-min v2; do runtime $r; echo "-- runtime $r"; fvm dart run probe/barrier_probe.dart; done

step "T6 the bus-api suite after, on each runtime"
for r in v2 v1 barrier-min; do runtime $r; echo "== runtime $r"; suite $API; done
runtime v1
why $API "G34 start connects a writer before every topology"
runtime barrier-min
why $API "G34 start connects a writer before every topology"

step "T7 the bus-api suite before, on runtime v2: the cases v2 reverses"
use hsdd-before
runtime v2
suite $API
use $REPO

step "T8 topology-dsl@v2's live suite through bus_activation_test.dart, on v2 and v1"
for r in v2 v1; do runtime $r; echo "== runtime $r"; suite $LIVE; done

step "T9 every other suite that imports nidana_dart_runtime, with the adapter patches, on v1 (baseline) and v2"
for r in v1 v2; do runtime $r; echo "== runtime $r"; others; done
runtime v2
adapters on
why $B/behavior/nidana_dart_runtime_test.dart "G3 a TestBus left without a provider"
why $B/behavior/nidana_dart_runtime_test.dart "G4 a bus on a virtual provider"
echo "-- why: flutter-binding G8 (fvm flutter test)"
fvm flutter test --no-pub --plain-name "G8 a PageScope binds once" $FB/behavior/nidana_dart_runtime_flutter_test.dart 2>&1 | grep -E 'Bad state' | head -n 2
adapters off

step "T10 seeded defects in the v2 runtime fail the cases of what they break"
runtime v2
mutate $RT/bus.dart "a bootstrap connection's publishes wait for a microtask, as in barrier-min" \
  "      if (_starting) {" "      if (false) {"
mutate $RT/bus.dart "ties in reverse activation order" \
  "      final next = left.firstWhere(" "      final next = left.lastWhere("
mutate $RT/bus.dart "bootstrap subscriptions connected before the topologies" \
  "      _starting = true;
      try {
        for (final a in order) {" "      for (final s in subscriptions) {
        s.connect();
      }
      subscriptions.clear();
      _starting = true;
      try {
        for (final a in order) {"
mutate $RT/bus.dart "a subscriber's error goes to the provider zone, as in v1" \
  "    final listenZone = Zone.current;" "    final listenZone = _bus._zone;"
mutate $RT/bus.dart "a subscription's failed conversion thrown in the provider zone rather than delivered as an error event" \
  "        out.addError(e, st);
        return;" "        _bus._zone.handleUncaughtError(e, st);
        return;"
mutate $RT/interpreter.dart "a read skips a value it cannot convert, as in v1" \
  "          out.addError(_Raised(e, lineage), st);
          return;" "          _bus._zone.handleUncaughtError(e, st);
          return;"
mutate $RT/bus.dart "re-activation compares definitions only, as in v1" \
  "existing.definition == definition && _samePlan(existing.plan, plan)" "existing.definition == definition"
mutate $RT/bus.dart "the scope check runs after declare" \
  "    if (topology.scope != Scope.application &&
        _lifecycle == BusLifecycle.bootstrapping) {" "    planOf(topology);
    if (topology.scope != Scope.application &&
        _lifecycle == BusLifecycle.bootstrapping) {"
mutate $RT/bus.dart "a module acquired before start" \
  "    if (_bus._lifecycle == BusLifecycle.bootstrapping) {
      throw StateError(\"module" "    if (false) {
      throw StateError(\"module"
mutate $RT/bus.dart "a forced removal during bootstrap leaves an unconnected read to reconnect" \
  "      if (!a.connected) a.removedBeforeConnect.add(topic.name);" ""
mutate $RT/bus.dart "an activation deactivated before start is still connected" \
  "        if (a.active) a," "        a,"

step "cleanup: restore the v2 runtime, remove the copied trees and the Flutter build output"
runtime v2
rm -rf hsdd hsdd-before build; echo "removed"
