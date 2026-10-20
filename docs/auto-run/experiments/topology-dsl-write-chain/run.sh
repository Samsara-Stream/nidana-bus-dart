#!/usr/bin/env bash
# topology-dsl-write-chain: S59 (hsdd-contract, H2 of the v0.15.1 intake)
# classifies topology-dsl's changes for Specification v0.15.1 by replay:
#
# - L3, the write chain (Spec §10.2 principles 2, 4 and 5, Appendix A.4): an
#   error that reaches a sink ends that sink's write chain; the chain's
#   subscription and every stage, inner subscription, pending retry and timer
#   that feeds no other live chain are cancelled at once, without waiting for
#   a cancel future; the error reaches no topic; a reduceInto is one chain.
#   G26 is restated and the live suite gains six G26 cases.
# - L1, connection at start() (Spec §3.13), and Spec §7.2's scope timing:
#   the live suite's topologies that LiveTopologyHarness.start activates
#   before the start become APPLICATION-scoped; three cases that activate
#   only after the start use a MODULE topology; G19, G24 and Live
#   interpretation item 3 are worded for "when the activation connects".
#
# Runtimes, each swapped into packages/nidana_dart_runtime/lib/src/:
#   v1          before/bus.dart, before/interpreter.dart: the stand-in of
#               ../runtime-reconcile-amends/ unchanged, whose sink stops
#               publishing after an error while its upstream keeps running;
#   write-chain patch/*.write_chain.dart: v1 plus the write-chain rule,
#               marked "topology-dsl-write-chain patch";
#   barrier     patch/*.barrier.dart: write-chain plus a minimal v0.15.1
#               startup barrier: a MODULE or PAGE activation before start()
#               throws StateError, and a bootstrap activation is wired at
#               activate but connected by start(), writers before readers,
#               before the queue is delivered. It does not settle a writer's
#               first emission before its readers connect; that, and the
#               error bus-api names, are H3's.
# packages/ holds the write-chain runtime at rest; run.sh swaps the others in
# and restores it. The other stand-in packages are
# ../runtime-reconcile-amends/packages/ copied unchanged (setup shows it).
# For T6 the adapters take the patches the later replays of their own
# contracts used, copied here: the resolver with named stages
# (patch/navigation.named.dart, ../navigation-stage-names/, which
# navigation-api@v1's G13 case needs) and the Flutter adapter as amended in
# S35 (patch/*.amended.dart, ../flutter-reconcile-amends/, which
# flutter-binding@v1's G5, G6, G7 and G17 cases need).
#
# Fixture trees, each copied to hsdd/ in turn at the repository's relative
# paths: hsdd-before/ is hsdd/contract at HEAD (git archive), the tree this
# step starts from; "after" is the repository's hsdd/contract as it stands.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
A=$F/bus-api
B=$F/bus-testing
N=$F/navigation-api
FB=$F/flutter-binding
LIVE=$A/behavior/bus_activation_test.dart
REC=$F/topology-dsl/behavior/topology_builder_test.dart
RT=packages/nidana_dart_runtime/lib/src
step() { echo; echo "### $*"; }

# use {tree}: copies the contracts and the fixtures of {tree} to hsdd/.
use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$A "$1"/$B "$1"/$N "$1"/$FB "$1"/$F/topology-dsl $F/
}

# runtime {v1|write-chain|barrier}: swaps that runtime in.
runtime() {
  case "$1" in
    v1) cp before/bus.dart before/interpreter.dart $RT/ ;;
    write-chain) cp patch/bus.write_chain.dart $RT/bus.dart; cp patch/interpreter.write_chain.dart $RT/interpreter.dart ;;
    barrier) cp patch/bus.barrier.dart $RT/bus.dart; cp patch/interpreter.barrier.dart $RT/interpreter.dart ;;
  esac
}

# suite {test file...}: the failing case names, then the verdict line.
suite() {
  echo "-- $*"
  fvm dart test --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

# fsuite {test file...}: suite under fvm flutter test.
fsuite() {
  echo "-- $* (fvm flutter test)"
  fvm flutter test --no-pub --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

# why {name prefix}: the first lines of the failure of the cases named so.
why() {
  echo "-- why: $1"
  fvm dart test --plain-name "$1" $LIVE 2>&1 \
    | grep -E 'Expected|Actual|Bad state' | head -n 4
}

# adapters {on|off}: puts the adapter patches in place, or restores the
# adapters as copied.
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

# mutate {file} {label} {from} {to}: applies one textual defect to the
# write-chain runtime, runs the live suite, and restores the file.
mutate() {
  local file="$1" label="$2" from="$3" to="$4"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "== seeded defect: $label"
  suite $LIVE
  mv "$file.orig" "$file"
}

step "setup: the before tree from git HEAD, resolve, versions"
rm -rf hsdd-before && mkdir hsdd-before
git -C $REPO archive HEAD hsdd/contract | tar -x -C hsdd-before
git -C $REPO rev-parse --short HEAD
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version
echo "-- before/ is the runtime of ../runtime-reconcile-amends/; every other stand-in file is the same"
for f in bus.dart interpreter.dart; do
  cmp -s before/$f ../runtime-reconcile-amends/$RT/$f && echo "before/$f: same" || echo "before/$f: DIFFERS"
done
diff -r -q -x .dart_tool -x bus.dart -x interpreter.dart packages ../runtime-reconcile-amends/packages && echo "other stand-in files: same"
echo "-- the adapter patches equal those of the experiments that wrote them"
cmp -s patch/navigation.named.dart ../navigation-stage-names/patch/navigation.named.dart && echo "navigation.named.dart: same"
for f in page_scope topic_builders widget_test_bus; do
  cmp -s patch/$f.amended.dart ../flutter-reconcile-amends/patch/$f.amended.dart && echo "$f.amended.dart: same"
done
echo "-- the write-chain patch against v1, and the barrier patch against the write-chain patch"
diff -u before/interpreter.dart patch/interpreter.write_chain.dart | grep -c '^[+-][^+-]' | sed 's/^/interpreter lines changed by write-chain: /'
cmp -s before/bus.dart patch/bus.write_chain.dart && echo "bus.dart unchanged by write-chain"
diff -u patch/bus.write_chain.dart patch/bus.barrier.dart | grep -c '^[+-][^+-]' | sed 's/^/bus lines changed by barrier: /'
diff -u patch/interpreter.write_chain.dart patch/interpreter.barrier.dart | grep -c '^[+-][^+-]' | sed 's/^/interpreter lines changed by barrier: /'

step "T1 the fixture change: the live suite, and a version line in every other file's header"
use $REPO
diff -r hsdd-before/$F/topology-dsl $F/topology-dsl | grep -E '^[<>] (// .*topology-dsl@|  \(|    name:)' | sort | uniq -c | sort -rn | head -n 20
echo "-- files that differ other than in their first line"
for f in $(cd $F/topology-dsl && find . -name '*.dart' | sort); do
  if ! diff <(tail -n +2 hsdd-before/$F/topology-dsl/$f) <(tail -n +2 $F/topology-dsl/$f) > /dev/null; then echo "$f"; fi
done
echo "-- case names in the live suite, before and after"
grep -cE "^    name: 'G" hsdd-before/$F/topology-dsl/behavior/live_conformance.dart
grep -cE "^    name: 'G" $F/topology-dsl/behavior/live_conformance.dart
echo "-- cases added or renamed"
diff <(grep -oE "^    name: '[^']*'" hsdd-before/$F/topology-dsl/behavior/live_conformance.dart) \
     <(grep -oE "^    name: '[^']*'" $F/topology-dsl/behavior/live_conformance.dart) | grep -E '^[<>]'

step "T2 structure (prototype): headers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check topology-dsl | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check topology-dsl | grep -c '^PASS G' | sed 's/^/guarantees covered: /'

step "T2b structure under amended ADR-001 (items 3 and 9), S17's prototype, over the repository's contracts"
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)

step "T3 surface, reject, and the conformance libraries with the bindings, analyzed"
fvm dart analyze --fatal-infos $F/topology-dsl/surface; echo "surface exit: $?"
fvm dart run nidana_contract_check:reject_check $F/topology-dsl/reject; echo "reject exit: $?"
fvm dart analyze --fatal-infos $F/topology-dsl/behavior $LIVE; echo "behavior exit: $?"
fvm dart analyze --fatal-infos packages tool; echo "stand-in and probe exit: $?"

step "T4 the recording suite, unchanged but for its header, against the stand-in recorder"
suite $REC

step "T5 runtime v1 (a sink stops, its upstream runs on): the live suite before and after"
runtime v1
use hsdd-before; suite $LIVE
use $REPO; suite $LIVE
why "G26 once an error ends a write chain"
why "G26 ending a chain cancels"
why "G26 a reduceInto is one write chain"

step "T6 runtime write-chain: the live suite before and after, and every other suite that imports nidana_dart_runtime, with the adapter patches"
runtime write-chain
use hsdd-before; suite $LIVE
use $REPO; suite $LIVE
adapters on
suite $A/behavior/nidana_dart_runtime_test.dart
suite $B/behavior/nidana_dart_runtime_test.dart
suite $N/behavior/nidana_dart_navigation_test.dart
suite $N/behavior/in_memory_router_test.dart
fsuite $FB/behavior/nidana_dart_runtime_flutter_test.dart
fsuite $FB/behavior/flutter_navigation_executor_test.dart
adapters off

step "T7 runtime barrier (connection at start(), MODULE before start() rejected): the live suite before and after"
runtime barrier
use hsdd-before; suite $LIVE
why "G19 a state topic read delivers the current value"
use $REPO; suite $LIVE

step "T8 probe: a chain ending with a debounce pending, a shared stage, a bootstrap activation (tool/chain_probe.dart)"
for r in v1 write-chain barrier; do
  runtime $r; echo "-- runtime $r"; fvm dart run tool/chain_probe.dart
done

step "T9 the cases a G26 restriction selects (--guarantee topology-dsl/G26, by name prefix), on runtime write-chain"
runtime write-chain
use $REPO
fvm dart test --reporter expanded --name '^G26 ' $LIVE 2>&1 \
  | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' | grep -E '^G26 |All tests passed|Some tests failed'

step "T10 seeded defects in the write-chain runtime fail the cases of what they break"
mutate $RT/interpreter.dart "an ended chain's stages are cancelled only after the sink subscription's cancel future completes (ADR-003 item 3)" \
  "      _ended.add(s);
      _hubs[s]!.cancel();" \
  "      _ended.add(s);
      final h = _hubs[s]!;
      _sinkOf[sink]!.cancel().then((_) => h.cancel());"
mutate $RT/interpreter.dart "a stage shared with a live chain is cancelled with the chain that ended" \
  "      if (_live.any((k) => _chains[k]!.contains(s))) continue;
" ""
mutate $RT/interpreter.dart "the sink passes the error on to its topic as an error signal" \
  "      onError: (Object e, StackTrace st) => _a._endChain(sink, e, st)," \
  "      onError: (Object e, StackTrace st) {
        _a._bus._cell(sink.topic).reads.addError(e, st);
        _a._endChain(sink, e, st);
      },"
mutate $RT/interpreter.dart "a reduceInto's error stops its sink alone, as v1 allowed" \
  "    void terminate(Object e, StackTrace st) => _a._endChain(sink, e, st);" \
  "    void terminate(Object e, StackTrace st) {
      sub.cancel();
      _a._terminated(sink.topic, e, st);
    }"

step "cleanup: restore the write-chain runtime, remove the copied trees and the Flutter build output"
runtime write-chain
rm -rf hsdd hsdd-before build; echo "removed"
