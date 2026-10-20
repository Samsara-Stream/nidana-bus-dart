#!/usr/bin/env bash
# bus-api-start-running: S80 (hsdd-reconcile, H12 of the v0.15.1 intake)
# drains nidana.runtime's re-plan (S79), whose pending section carries one
# amend of bus-api@v2, from the plan's D8: from the moment start() begins on
# a bootstrapping bus, the bus is running, so the work start() runs (a
# subscriber's or an observer's callback) sees BusLifecycle.running; an
# activation, an observed subscription or a module's first reference that it
# makes is one made after start() (G22, G17, G28, G42); a start() it calls
# does nothing (G34); a publish it makes is reentrant (G14) and a removeTopic
# it calls throws StateError (G9).
#
# The step classifies the amend against bus-api@v2's Breaking list by replay
# and pins it by extending two existing cases, so the case count stays 109:
#   'G34 start is idempotent, ...'      a bootstrap subscription's callback in
#                                        step 2 reads running and its
#                                        removeTopic throws; an observer called
#                                        in step 3 reads running, activates a
#                                        PAGE topology and subscribes as after
#                                        start, and calls start(), which does
#                                        nothing;
#   'G42 acquiring a module before ...' a bootstrap subscription's callback in
#                                        step 2 acquires a module.
#
# Runtimes, each swapped into packages/nidana_dart_runtime/lib/src/:
#   v2     ../bus-api-v2/runtime/v2/ (the bus-api@v2 stand-in, a wrapped
#          subject);
#   owned  ../runtime-topic-storage/runtime/owned/ (topic storage and fan-out
#          owned by the bus, nidana.runtime D3).
# Both set BusLifecycle.running before step 1 of start(). Two seeded defects
# in the owned runtime stand for the readings the amend excludes:
#   late-running  the bus reads bootstrapping, holds activations and
#                 subscriptions and rejects MODULE and PAGE activations and a
#                 module's first reference until start() returns (the option
#                 nidana.runtime D8 rejected);
#   step2-remove  a removeTopic called from a callback that step 2 runs is
#                 not rejected, as G9's "during a delivery" alone would allow.
#
# The stand-in packages are ../flutter-binding-v0151/packages/ as they rest
# there (the v2 runtime, navigation-api-v0151's navigation stand-in, the
# Flutter adapter with NidanaModule), copied at setup and removed at cleanup.
# Fixture trees, each copied to hsdd/ in turn: hsdd-before/ is hsdd/contract
# at HEAD (git archive), the tree this step starts from; "after" is the
# repository's hsdd/contract as it stands.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
V2=../bus-api-v2
OWNED=../runtime-topic-storage
BASE=../flutter-binding-v0151/packages
F=hsdd/contract/fixture
A=$F/bus-api
B=$F/bus-testing
N=$F/navigation-api
FB=$F/flutter-binding
API=$A/behavior/nidana_dart_runtime_test.dart
LIVE=$A/behavior/bus_activation_test.dart
RT=packages/nidana_dart_runtime/lib/src
G34='G34 start is idempotent'
G42='G42 acquiring a module before start'
step() { echo; echo "### $*"; }

use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$A "$1"/$B "$1"/$N "$1"/$FB "$1"/$F/topology-dsl $F/
}

runtime() {
  case "$1" in
    v2) cp $V2/runtime/v2/bus.dart $V2/runtime/v2/interpreter.dart $RT/ ;;
    owned) cp $OWNED/runtime/owned/bus.dart $OWNED/runtime/owned/interpreter.dart $RT/ ;;
  esac
}

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

# why {name prefix}: the first lines of that case's failure.
why() {
  echo "-- why: $1"
  fvm dart test --plain-name "$1" $API 2>&1 \
    | grep -E 'Expected|Actual|Which' | head -n 6
}

# apply {file} {from} {to} [{from} {to}]...: textual defects in the owned
# runtime, the original kept as {file}.orig; restore puts it back.
apply() {
  local file="$1"; shift
  cp "$file" "$file.orig"
  while [ $# -ge 2 ]; do
    FROM="$1" TO="$2" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
    shift 2
  done
  if cmp -s "$file.orig" "$file"; then echo "-- MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return 1; fi
  diff "$file.orig" "$file" | grep -c '^[<>]' | sed 's/^/lines changed: /'
}
restore() { mv "$1.orig" "$1"; }

step "setup: the stand-in packages from $BASE, the before tree from git HEAD, resolve, versions"
rm -rf packages hsdd hsdd-before
mkdir packages && (cd $BASE && tar -cf - --exclude .dart_tool .) | (cd packages && tar -xf -)
mkdir hsdd-before
git -C $REPO archive HEAD hsdd/contract | tar -x -C hsdd-before
git -C $REPO rev-parse --short HEAD
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version
for f in bus interpreter; do
  cmp -s $RT/$f.dart $V2/runtime/v2/$f.dart && echo "copied package $f.dart: same as $V2/runtime/v2/$f.dart"
done
echo "-- where each runtime sets running in start(): the line after the idempotency check"
for r in v2 owned; do
  case $r in v2) src=$V2/runtime/v2/bus.dart ;; owned) src=$OWNED/runtime/owned/bus.dart ;; esac
  grep -n -A1 'if (_lifecycle == BusLifecycle.running) return;' $src | sed "s/^/$r: /"
done

step "T1 the fixture change: case names before and after, and the lines changed"
use $REPO
grep -cE "^    name: 'G" hsdd-before/$A/behavior/bus_api_conformance.dart | sed 's/^/cases before: /'
grep -cE "^    name: 'G" $A/behavior/bus_api_conformance.dart | sed 's/^/cases after: /'
diff <(grep -oE "^    name: '[^']*'" hsdd-before/$A/behavior/bus_api_conformance.dart) \
     <(grep -oE "^    name: '[^']*'" $A/behavior/bus_api_conformance.dart) | grep -E '^[<>]'
echo "-- lines changed per file of the fixture tree"
for f in $(cd $A && find . -name '*.dart' | sort); do
  n=$(diff hsdd-before/$A/$f $A/$f | grep -c '^[<>]')
  [ "$n" != 0 ] && echo "$f: $n"
done
echo "-- other contracts' fixture trees that differ (expect none)"
for d in bus-testing navigation-api flutter-binding topology-dsl; do
  diff -r -q hsdd-before/$F/$d $F/$d
done

step "T2 structure (prototype) for bus-api, S17's prototype over the repository's contracts, analysis"
runtime owned
fvm dart run nidana_contract_check:structure_check bus-api | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check bus-api | grep -c '^PASS G' | sed 's/^/guarantees covered: /'
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)
fvm dart analyze --fatal-infos $A/surface; echo "surface exit: $?"
fvm dart run nidana_contract_check:reject_check $A/reject; echo "reject exit: $?"
fvm dart analyze --fatal-infos $A/behavior; echo "behavior exit: $?"

step "T3 the bus-api suite before and after, on each runtime"
for r in v2 owned; do
  runtime $r
  echo "== runtime $r, before"; use hsdd-before; suite $API
  echo "== runtime $r, after"; use $REPO; suite $API
done

step "T4 topology-dsl@v2's live suite through bus_activation_test.dart, on each runtime"
for r in v2 owned; do runtime $r; echo "== runtime $r"; suite $LIVE; done

step "T5 every other suite that imports nidana_dart_runtime, on each runtime, against the fixtures as they stand"
for r in v2 owned; do
  runtime $r; echo "== runtime $r"
  suite $B/behavior/nidana_dart_runtime_test.dart
  suite $N/behavior/nidana_dart_navigation_test.dart
  suite $N/behavior/in_memory_router_test.dart
  fsuite $FB/behavior/nidana_dart_runtime_flutter_test.dart
  fsuite $FB/behavior/flutter_navigation_executor_test.dart
done

step "T6 seeded defects in the owned runtime"
runtime owned
LATE=(
  "  BusLifecycle _lifecycle = BusLifecycle.bootstrapping;" \
  "  BusLifecycle _lifecycle = BusLifecycle.bootstrapping;
  bool _inStart = false;" \
  "  BusLifecycle get lifecycle => _lifecycle;" \
  "  BusLifecycle get lifecycle => _inStart ? BusLifecycle.bootstrapping : _lifecycle;" \
  "        _lifecycle == BusLifecycle.bootstrapping) {
      throw StateError(\"topology" \
  "        (_lifecycle == BusLifecycle.bootstrapping || _inStart)) {
      throw StateError(\"topology" \
  "    if (_lifecycle == BusLifecycle.bootstrapping) {
      // bus-api-v2 (G34): validated and claimed" \
  "    if (_lifecycle == BusLifecycle.bootstrapping || _inStart) {
      // bus-api-v2 (G34): validated and claimed" \
  "    if (_bus._lifecycle == BusLifecycle.bootstrapping) {
      // bus-api-v2 (G34): not connected until start()" \
  "    if (_bus._lifecycle == BusLifecycle.bootstrapping || _bus._inStart) {
      // bus-api-v2 (G34): not connected until start()" \
  "    if (_bus._lifecycle == BusLifecycle.bootstrapping) {
      throw StateError(\"module" \
  "    if (_bus._lifecycle == BusLifecycle.bootstrapping || _bus._inStart) {
      throw StateError(\"module" \
  "    _lifecycle = BusLifecycle.running;
    _windowTimer?.cancel();" \
  "    _lifecycle = BusLifecycle.running;
    _inStart = true;
    _windowTimer?.cancel();" \
  "      for (final p in queue) {
        _run(p);
      }
    });
  }" \
  "      for (final p in queue) {
        _run(p);
      }
    });
    _inStart = false;
  }"
)
STEP2=(
  "  BusLifecycle _lifecycle = BusLifecycle.bootstrapping;" \
  "  BusLifecycle _lifecycle = BusLifecycle.bootstrapping;
  bool _inStep2 = false;" \
  "    if (_delivering > 0) throw StateError('removeTopic during a delivery');" \
  "    if (_delivering > 0 && !_inStep2) throw StateError('removeTopic during a delivery');" \
  "      _delivering++;
      try {
        for (final s in subscriptions) {
          s.connect();
        }
      } finally {
        _delivering--;
      }" \
  "      _delivering++;
      _inStep2 = true;
      try {
        for (final s in subscriptions) {
          s.connect();
        }
      } finally {
        _inStep2 = false;
        _delivering--;
      }"
)
echo "== seeded defect: late-running: running, connection and scope timing only once start() returns"
if apply $RT/bus.dart "${LATE[@]}"; then
  suite $API; why "$G34"; why "$G42"
  echo "-- the other suites under late-running: a case that fails here relies on the amendment already"
  suite $B/behavior/nidana_dart_runtime_test.dart
  suite $N/behavior/nidana_dart_navigation_test.dart
  suite $N/behavior/in_memory_router_test.dart
  fsuite $FB/behavior/nidana_dart_runtime_flutter_test.dart
  fsuite $FB/behavior/flutter_navigation_executor_test.dart
  suite $LIVE
  restore $RT/bus.dart
fi
echo "== seeded defect: step2-remove: removeTopic from a callback step 2 runs not rejected"
if apply $RT/bus.dart "${STEP2[@]}"; then
  suite $API; why "$G34"
  restore $RT/bus.dart
fi

step "T7 the replay schedule of nidana.runtime's plan against the fixtures as they stand"
echo "-- the two extended cases, as ../runtime-replay-schedule-v2/schedule.dart places them"
(cd ../runtime-replay-schedule-v2 && fvm dart schedule.dart) | grep -E "^### |G34 start is idempotent|G42 acquiring a module|cases calling start|^    \.(12|14):"
echo "-- the plan's gates checked against the schedule"
(cd ../runtime-replay-schedule-v2 && fvm dart schedule.dart --check ../../../../hsdd/spec/nidana.runtime.md) | tail -n 1

step "cleanup: remove the copied packages, the fixture trees and the build output"
rm -rf packages hsdd hsdd-before build .suite.log; echo "removed"
