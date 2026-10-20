#!/usr/bin/env bash
# navigation-api-v0151: S62 (hsdd-contract, H5 of the v0.15.1 intake)
# classifies navigation-api's changes for Specification v0.15.1 by replay:
#
# - L1, the startup barrier (Spec §3.13; bus-api@v2 G34, G22, G14): G14 and
#   G24 hold unchanged when the resolver connects at start(), after the
#   topologies that write its inputs and before the queue; a topology-owned
#   nav.access-policy is settled before the resolver connects (probes P1 to
#   P4).
# - Re-activation (Spec §3.9; Guide §6.3; bus-api@v2 G23): navResolver
#   builds its stage functions once per call, so the value one call returns
#   re-activates to its handle and another call's conflicts (G13's new case,
#   probe P5).
# - L4, errors (Spec §10.2 principle 5; bus-api@v2 G18): where what the
#   executor leaves unhandled goes (probe P6), for nidana.navigation D6.
# - Spec §7.2 scope timing: the suites' bootstrap order (T1 lists every
#   activation).
#
# Runtimes, each swapped into packages/nidana_dart_runtime/lib/src/:
#   v1  runtime/v1/: ../bus-api-v2/runtime/v1/, a bus-api@v1 runtime with
#       topology-dsl@v2's write chains, which passes every v1 suite;
#   v2  runtime/v2/: ../bus-api-v2/runtime/v2/, the bus-api@v2 runtime.
# Navigation stand-ins, each swapped into
# packages/nidana_dart_navigation/lib/src/navigation.dart:
#   in-declare  navigation/in-declare.dart: ../bus-api-v2/patch/
#               navigation.named.dart, the stand-in of nidana.navigation D5,
#               which builds its stage objects inside the declaration body;
#   once        navigation/once.dart: the same, the stage objects built once
#               per navResolver call (at rest in packages/);
#   cached      navigation/cached.dart: the same, the stage objects
#               canonicalized per configuration in a static cache;
#   closures    navigation/closures.dart: the stand-in at rest in
#               ../bus-api-v2/packages/, whose stages are closures.
# The other stand-in packages are ../bus-testing-v0151/packages/ unchanged
# (setup shows it). For flutter-binding's executor binding the Flutter
# adapter takes the patches ../bus-api-v2/ used (patch/).
#
# Fixture trees, each copied to hsdd/ in turn: hsdd-before/ is hsdd/contract
# at HEAD (git archive), the tree this step starts from; "after" is the
# repository's hsdd/contract as it stands.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
N=$F/navigation-api
FB=$F/flutter-binding
NAVT=$N/behavior/nidana_dart_navigation_test.dart
EXT=$N/behavior/in_memory_router_test.dart
FEXT=$FB/behavior/flutter_navigation_executor_test.dart
RT=packages/nidana_dart_runtime/lib/src
NAV=packages/nidana_dart_navigation/lib/src/navigation.dart
FSRC=packages/nidana_dart_runtime_flutter/lib/src
BT=../bus-testing-v0151
V2=../bus-api-v2
step() { echo; echo "### $*"; }

use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$N "$1"/$FB "$1"/$F/bus-api "$1"/$F/bus-testing "$1"/$F/topology-dsl $F/
}

runtime() { cp runtime/"$1"/bus.dart runtime/"$1"/interpreter.dart $RT/; }
navigation() { cp navigation/"$1".dart $NAV; }

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
    | grep -E 'Expected|Actual|Bad state|Which|reason' | head -n 5
}

adapters() {
  if [ "$1" = on ]; then
    for f in page_scope topic_builders widget_test_bus; do
      cp $FSRC/$f.dart $FSRC/$f.dart.copied; cp patch/$f.amended.dart $FSRC/$f.dart
    done
  else
    for f in page_scope topic_builders widget_test_bus; do mv $FSRC/$f.dart.copied $FSRC/$f.dart; done
  fi
}

step "setup: the before tree from git HEAD, resolve, versions, the stand-ins' provenance"
rm -rf hsdd-before && mkdir hsdd-before
git -C $REPO archive HEAD hsdd/contract | tar -x -C hsdd-before
git -C $REPO rev-parse --short HEAD
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version
diff -r -q -x .dart_tool -x bus.dart -x interpreter.dart -x navigation.dart packages $BT/packages && echo "stand-in packages: same as $BT/packages but for the runtime and navigation sources swapped in"
for r in v1 v2; do
  for f in bus interpreter; do
    cmp -s runtime/$r/$f.dart $V2/runtime/$r/$f.dart && echo "runtime/$r/$f.dart: same as $V2/runtime/$r/$f.dart"
  done
done
cmp -s navigation/in-declare.dart $V2/patch/navigation.named.dart && echo "navigation/in-declare.dart: same as $V2/patch/navigation.named.dart"
cmp -s navigation/closures.dart $V2/packages/nidana_dart_navigation/lib/src/navigation.dart && echo "navigation/closures.dart: same as $V2/packages/nidana_dart_navigation/lib/src/navigation.dart"
cmp -s navigation/once.dart $NAV && echo "packages/ holds navigation/once.dart"
for f in page_scope topic_builders widget_test_bus; do
  cmp -s patch/$f.amended.dart $V2/patch/$f.amended.dart && echo "patch/$f.amended.dart: same as $V2/patch/"
done
echo "-- once and cached against in-declare: the navResolver body only"
diff navigation/in-declare.dart navigation/once.dart | grep -c '^[<>]' | sed 's/^/once: changed lines /'
diff navigation/in-declare.dart navigation/cached.dart | grep -c '^[<>]' | sed 's/^/cached: changed lines /'

step "T1 the fixture change: case names and other lines before and after; every activation and its scope"
use $REPO
for s in navigation_conformance navigation_executor_conformance; do
  echo "-- $s"
  grep -cE "^    name: 'G" hsdd-before/$N/behavior/$s.dart | sed 's/^/cases before: /'
  grep -cE "^    name: 'G" $N/behavior/$s.dart | sed 's/^/cases after: /'
  diff <(grep -oE "^    name: '[^']*'" hsdd-before/$N/behavior/$s.dart) \
       <(grep -oE "^    name: '[^']*'" $N/behavior/$s.dart) | grep -E '^[<>]'
done
echo "-- every file of the fixture tree that differs, and how"
diff -r hsdd-before/$N $N | grep -E '^(diff|Only|[<>])' | grep -vE "^[<>] +(expect|final|for|\(|\]|\)|body|name|reason|'|<|  )"
echo "-- activations in both suites (Spec §7.2: MODULE or PAGE only after start())"
grep -nE "activate\(|bus\.start\(\)|Scope\.(application|module|page)" $N/behavior/navigation_conformance.dart $N/behavior/navigation_executor_conformance.dart | sed -E 's/^([^:]+):([0-9]+):\s*/\1:\2: /' | sed -E "s#$N/behavior/##"

step "T2 structure (prototype) for navigation-api, and S17's prototype over the repository's contracts"
runtime v2
navigation once
fvm dart run nidana_contract_check:structure_check navigation-api | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check navigation-api | grep -c '^PASS G' | sed 's/^/guarantees covered: /'
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)

step "T3 surface, reject and behavior libraries analyzed; the stand-ins and the probes"
fvm dart analyze --fatal-infos $N/surface; echo "surface exit: $?"
fvm dart run nidana_contract_check:reject_check $N/reject; echo "reject exit: $?"
fvm dart analyze --fatal-infos $N/behavior; echo "behavior exit: $?"
for n in once in-declare cached; do
  navigation $n
  fvm dart analyze --fatal-infos packages/nidana_dart_navigation > /dev/null 2>&1; echo "navigation stand-in $n exit: $?"
done
navigation once
fvm dart analyze --fatal-infos probe; echo "probes exit: $?"

step "T4 both suites after, on each runtime and each navigation stand-in"
for r in v2 v1; do
  runtime $r
  for n in once in-declare cached closures; do
    navigation $n
    echo "== runtime $r, navigation $n"
    suite $NAVT
    suite $EXT
  done
done
runtime v2
navigation in-declare
why $NAVT "G13 one nav-resolver holds the same stage functions"
navigation cached
why $NAVT "G13 one nav-resolver holds the same stage functions"
navigation closures
why $NAVT "G13 both nav-resolver forms name their stage functions"

step "T5 both suites before, on each runtime, with the stand-ins the suites passed against before (in-declare) and the once stand-in"
use hsdd-before
for r in v1 v2; do
  runtime $r
  for n in in-declare once; do
    navigation $n
    echo "== runtime $r, navigation $n"
    suite $NAVT
    suite $EXT
  done
done
use $REPO

step "T6 flutter-binding's binding of the executor suite, after, on the v2 runtime with the once stand-in"
runtime v2
navigation once
adapters on
fsuite $FEXT
adapters off

step "T7 probes P1 to P4: the nav-resolver and the executor at bootstrap, on each runtime"
navigation once
for r in v1 v2; do runtime $r; echo "-- runtime $r"; fvm dart run probe/bootstrap_probe.dart; done

step "T8 probe P5: re-activating a nav-resolver, on each runtime and each navigation stand-in"
for r in v1 v2; do
  runtime $r
  for n in in-declare once cached; do
    navigation $n
    echo "-- runtime $r, navigation $n"
    fvm dart run probe/reactivation_probe.dart
  done
done

step "T9 probe P6: where an error the executor leaves unhandled goes, on each runtime"
navigation once
for r in v1 v2; do runtime $r; echo "-- runtime $r"; fvm dart run probe/executor_error_probe.dart; done

step "cleanup: restore the v2 runtime and the once stand-in, remove the copied trees and the Flutter build output"
runtime v2
navigation once
rm -rf hsdd hsdd-before build; echo "removed"
