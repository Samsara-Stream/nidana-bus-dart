#!/usr/bin/env bash
# bus-testing-v0151: S61 (hsdd-contract, H4 of the v0.15.1 intake) classifies
# bus-testing's changes for Specification v0.15.1 by replay and pins them:
#
# - L1, the startup barrier (Spec §3.13, §2.1): a recorder attached during
#   bootstrap records what start() delivers while it connects the bootstrap
#   topologies, in the connection order, before the queue (G14); an
#   OrderingProbe attached during bootstrap receives nothing before start()
#   and its first values within start() (G19).
# - L2, scope timing (Spec §7.2): a MODULE or PAGE activation before start()
#   throws (bus-api@v2 G42), so seven cases that activated a MODULE topology
#   before start() activate an APPLICATION one before it, or a MODULE one
#   after it ("How a test uses it").
# - L4, subscriber errors (Spec §10.2 principle 5): what a subscriber's
#   callback throws never reaches the scheduler, even when an operation runs
#   the delivery; it goes to the zone that listened (G3, G11). A timer the
#   callback creates is virtual (G4) and its error goes to the zone that
#   built the scheduler (G11).
#
# The stand-in packages and runtimes are ../bus-api-v2/'s, unchanged (setup
# shows it): runtime/v1/ is a bus-api@v1 runtime that passes every v1 suite,
# runtime/v2/ the bus-api@v2 runtime. packages/ holds the v2 runtime at rest.
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
BT=$B/behavior/nidana_dart_runtime_test.dart
API=$A/behavior/nidana_dart_runtime_test.dart
LIVE=$A/behavior/bus_activation_test.dart
RT=packages/nidana_dart_runtime/lib/src
V2=../bus-api-v2
step() { echo; echo "### $*"; }

use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$A "$1"/$B "$1"/$F/topology-dsl $F/
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

# why {file} {name prefix}: the first lines of the failure of that case.
why() {
  echo "-- why: $2"
  fvm dart test --plain-name "$2" "$1" 2>&1 \
    | grep -E 'Expected|Actual|Bad state|Which' | head -n 4
}

# mutate {file} {label} {from} {to}: one textual defect in the v2 runtime,
# this contract's suite run, the file restored.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "== seeded defect: $label"
  suite $BT
  mv "$file.orig" "$file"
}

step "setup: the before tree from git HEAD, resolve, versions, the stand-ins' provenance"
rm -rf hsdd-before && mkdir hsdd-before
git -C $REPO archive HEAD hsdd/contract | tar -x -C hsdd-before
git -C $REPO rev-parse --short HEAD
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version
diff -r -q -x .dart_tool -x bus.dart -x interpreter.dart packages $V2/packages && echo "stand-in packages: same as $V2/packages"
for r in v1 v2; do
  for f in bus interpreter; do
    cmp -s runtime/$r/$f.dart $V2/runtime/$r/$f.dart && echo "runtime/$r/$f.dart: same as $V2/runtime/$r/$f.dart"
  done
done

step "T1 the fixture change: case names before and after"
use $REPO
grep -cE "^    name: 'G" hsdd-before/$B/behavior/bus_testing_conformance.dart | sed 's/^/cases before: /'
grep -cE "^    name: 'G" $B/behavior/bus_testing_conformance.dart | sed 's/^/cases after: /'
diff <(grep -oE "^    name: '[^']*'" hsdd-before/$B/behavior/bus_testing_conformance.dart) \
     <(grep -oE "^    name: '[^']*'" $B/behavior/bus_testing_conformance.dart) | grep -E '^[<>]'
echo "-- activations before and after: the scope of each topology a case activates"
diff <(grep -oE "activate\(_[a-z]+\('[a-z-]+'" hsdd-before/$B/behavior/bus_testing_conformance.dart) \
     <(grep -oE "activate\(_[a-z]+\('[a-z-]+'" $B/behavior/bus_testing_conformance.dart)
echo "-- other files of the fixture tree that differ"
diff -r -q hsdd-before/$B $B | grep -v bus_testing_conformance

step "T2 structure (prototype) for bus-testing, and S17's prototype over the repository's contracts"
runtime v2
fvm dart run nidana_contract_check:structure_check bus-testing | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check bus-testing | grep -c '^PASS G' | sed 's/^/guarantees covered: /'
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)

step "T3 surface, reject and behavior libraries analyzed"
fvm dart analyze --fatal-infos $B/surface; echo "surface exit: $?"
fvm dart run nidana_contract_check:reject_check $B/reject; echo "reject exit: $?"
fvm dart analyze --fatal-infos $B/behavior; echo "behavior exit: $?"

step "T4 this suite after, on each runtime"
for r in v2 v1; do runtime $r; echo "== runtime $r"; suite $BT; done
runtime v1
why $BT "G3 a TestBus left without a provider"
why $BT "G14 a recorder attached during bootstrap"
why $BT "G19 a probe attached during bootstrap"

step "T5 this suite before, on each runtime: the cases v2 rewrote"
use hsdd-before
for r in v1 v2; do runtime $r; echo "== runtime $r"; suite $BT; done
runtime v2
why $BT "G3 a TestBus left without a provider"
why $BT "G4 a bus on a virtual provider"
use $REPO

step "T6 bus-api@v2's two bindings, which use this contract's declarations, on the v2 runtime"
runtime v2
suite $API
suite $LIVE

step "T7 seeded defects in the v2 runtime fail the cases of what they break"
runtime v2
mutate $RT/bus.dart "a subscriber's error goes to the provider zone, as in v1" \
  "    final listenZone = Zone.current;" "    final listenZone = _bus._zone;"
mutate $RT/bus.dart "a subscriber's callbacks bound to the zone that listened" \
  "(v) => _guard(() => handleData(v))" "(v) => _listenZone.runGuarded(() => handleData(v))"
mutate $RT/bus.dart "a bootstrap connection's publishes wait for a microtask, as in ../bus-api-v2/runtime/barrier-min" \
  "      if (_starting) {" "      if (false) {"
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
mutate $RT/bus.dart "a recorder skips what start delivers while it connects the bootstrap activations" \
  "    for (final r in _recorders) {" "    for (final r in _starting ? const <EnvelopeRecorder>[] : _recorders) {"

step "cleanup: restore the v2 runtime, remove the copied trees"
runtime v2
rm -rf hsdd hsdd-before; echo "removed"
