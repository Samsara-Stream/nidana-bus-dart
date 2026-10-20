#!/usr/bin/env bash
# flutter-binding-v0151: S63 (hsdd-contract, H6 of the v0.15.1 intake)
# classifies flutter-binding's changes for Specification v0.15.1 by replay:
#
# - L7, the module wrapper widget (Spec §7.3's Flutter row, Appendix A.8):
#   NidanaModule (G20); probes N1 to N6 measure when a widget in a page, or
#   around a nested Navigator, mounts and unmounts as Flutter's Navigator
#   pushes, covers, replaces and pops routes; R6 to R8 do the same under
#   go_router 18.1.0 and record the route names it gives.
# - L2, scope timing (Spec §7.2; bus-api@v2 G42): a PageScope with a
#   topology, a NidanaModule and a route acquire before start() (G8, G10,
#   G20), and the two v1 G8 cases that mounted on a bus never started.
# - L1, the startup barrier (Spec §3.13; bus-api@v2 G17, G34): a topic
#   widget mounted during bootstrap (G5, G6), the bootstrap deep link (G16).
# - L4, subscriber errors (Spec §10.2 principle 5; bus-api@v2 G18): the G5
#   and G6 off-type cases on both runtimes.
# - L6, re-activation (Spec §3.9; Guide §6.3; bus-api@v2 G23): one route
#   pushed twice (G8).
#
# Runtimes, each swapped into packages/nidana_dart_runtime/lib/src/:
#   v1  runtime/v1/: ../bus-api-v2/runtime/v1/, a bus-api@v1 runtime with
#       topology-dsl@v2's write chains, which passes every v1 suite;
#   v2  runtime/v2/: ../bus-api-v2/runtime/v2/, the bus-api@v2 runtime.
# Flutter adapters, each copied to packages/nidana_dart_runtime_flutter/lib/:
#   v1  adapter/v1/: the stand-in of ../navigation-api-v0151/packages/ with
#       that experiment's patches (flutter-binding@v1 as amended);
#   v2  adapter/v2/: v1 plus NidanaModule (src/nidana_module.dart) and the
#       topic widgets' bootstrap first-value rule (src/topic_builders.dart).
# Seeded defects, each one file of adapter v2 replaced from defect/;
# first-skip, which puts back v1's topic widgets, is also adapter v1 plus
# NidanaModule alone.
# The other stand-in packages are ../navigation-api-v0151/packages/
# unchanged (setup shows it).
#
# Fixture trees, each copied to hsdd/ in turn: hsdd-before/ is hsdd/contract
# at HEAD (git archive), the tree this step starts from; "after" is the
# repository's hsdd/contract as it stands.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
FB=$F/flutter-binding
SUITE=$FB/behavior/nidana_dart_runtime_flutter_test.dart
EXEC=$FB/behavior/flutter_navigation_executor_test.dart
RT=packages/nidana_dart_runtime/lib/src
AD=packages/nidana_dart_runtime_flutter/lib
NV=../navigation-api-v0151
V2=../bus-api-v2
step() { echo; echo "### $*"; }

use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$FB "$1"/$F/navigation-api "$1"/$F/bus-api "$1"/$F/bus-testing "$1"/$F/topology-dsl $F/
}

runtime() { cp runtime/"$1"/bus.dart runtime/"$1"/interpreter.dart $RT/; }
adapter() { rm -rf $AD && cp -R adapter/"$1"/lib $AD; }
# defect {name}: adapter v2 with defect/{name}.{file}.dart in place of src/{file}.dart.
defect() {
  adapter v2
  local f; f=$(ls defect/"$1".*.dart); local target=${f#defect/$1.}
  cp "$f" $AD/src/"$target"
}

fsuite() {
  echo "-- $* (fvm flutter test)"
  fvm flutter test --no-pub --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  grep -E "Error: |error •" .suite.log | head -n 3
  echo "exit: $code"
  rm -f .suite.log
}

# why {file} {name}: the first lines of the failure of that case.
why() {
  echo "-- why: $2"
  fvm flutter test --no-pub --plain-name "$2" "$1" 2>&1 \
    | grep -E 'Expected|Actual|Which|Bad state' | head -n 4
}

step "setup: the before tree from git HEAD, resolve, versions, the stand-ins' provenance"
rm -rf hsdd-before && mkdir hsdd-before
git -C $REPO archive HEAD hsdd/contract | tar -x -C hsdd-before
git -C $REPO rev-parse --short HEAD
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version
fvm flutter --version | head -n 1
echo "-- stand-in packages against $NV/packages, the runtime sources excluded: every difference"
diff -r -q -x .dart_tool -x bus.dart -x interpreter.dart packages $NV/packages | sed -E "s#$NV/##"
for r in v1 v2; do
  for f in bus interpreter; do
    cmp -s runtime/$r/$f.dart $V2/runtime/$r/$f.dart && echo "runtime/$r/$f.dart: same as $V2/runtime/$r/$f.dart"
  done
done
for f in bus_provider module_scope navigation; do
  cmp -s adapter/v1/lib/src/$f.dart $NV/packages/nidana_dart_runtime_flutter/lib/src/$f.dart && echo "adapter/v1 $f.dart: same as $NV/packages/"
done
for f in page_scope topic_builders widget_test_bus; do
  cmp -s adapter/v1/lib/src/$f.dart $NV/patch/$f.amended.dart && echo "adapter/v1 $f.dart: same as $NV/patch/$f.amended.dart"
done
echo "-- adapter v2 against adapter v1"
diff -r adapter/v1/lib adapter/v2/lib | grep -E '^(diff|Only)'
diff adapter/v1/lib/src/topic_builders.dart adapter/v2/lib/src/topic_builders.dart | grep -c '^[<>]' | sed 's/^/topic_builders.dart: changed lines /'
echo "-- each seeded defect against adapter v2"
for d in defect/*.dart; do
  n=${d#defect/}; target=${n#*.}
  echo "$n: $(diff adapter/v2/lib/src/$target "$d" | grep -c '^[<>]') changed lines in src/$target"
done

step "T1 the fixture change: case names before and after; every scope binding a case mounts and every start()"
use $REPO
c=$FB/behavior/flutter_binding_conformance.dart
grep -cE "^    name: 'G" hsdd-before/$c | sed 's/^/cases before: /'
grep -cE "^    name: 'G" $c | sed 's/^/cases after: /'
diff <(grep -oE "^    name: '([^'\\\\]|\\\\.)*'" hsdd-before/$c) <(grep -oE "^    name: '([^'\\\\]|\\\\.)*'" $c) | grep -E '^[<>]'
echo "-- other files of the fixture tree that differ"
diff -r -q hsdd-before/$FB $FB | grep -v flutter_binding_conformance
echo "-- per case: the lines that start a bus, activate, or mount a PageScope with topologies or a NidanaModule (Spec §7.2)"
awk "/^    name: 'G/ { n=\$0; sub(/^    name: '/, \"\", n); sub(/'.*/, \"\", n); n=substr(n, 1, 60) }
     /\.start\(\);|\.activate\(|topologies: <Topology>\[_(page|namedPage|closurePage)|NidanaModule\(/ { gsub(/^ +/, \"\"); print n \" | \" substr(\$0, 1, 70) }" $c

step "T2 structure (prototype) for flutter-binding, and S17's prototype over the repository's contracts"
runtime v2
adapter v2
fvm dart run nidana_contract_check:structure_check flutter-binding | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check flutter-binding | grep -c '^PASS G' | sed 's/^/guarantees covered: /'
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart 2>&1 | tail -n 10)

step "T3 surface, reject and behavior libraries analyzed against adapter v2; the adapters, the defects and the probes"
fvm dart analyze --fatal-infos $FB/surface; echo "surface exit: $?"
fvm dart run nidana_contract_check:reject_check $FB/reject; echo "reject exit: $?"
fvm dart analyze --fatal-infos $FB/behavior; echo "behavior exit: $?"
fvm dart analyze --fatal-infos packages/nidana_dart_runtime_flutter > /dev/null 2>&1; echo "adapter v2 exit: $?"
adapter v1
fvm dart analyze --fatal-infos packages/nidana_dart_runtime_flutter > /dev/null 2>&1; echo "adapter v1 exit: $?"
echo "-- the after fixtures against adapter v1, which declares no NidanaModule"
fvm dart analyze $FB/behavior $FB/surface $FB/reject 2>&1 | grep -E "error - .*NidanaModule" | sed -E 's/^ *error - ([^:]+):[0-9:]+ - /error \1: /' | sed -E 's/ Try .*//' | sort | uniq -c
echo "-- errors there that do not name NidanaModule, outside the reject set (its errors are its expected codes)"
fvm dart analyze $FB/behavior $FB/surface 2>&1 | grep -E "error - " | grep -vc NidanaModule
for d in defect/*.dart; do
  n=${d#defect/}; n=${n%%.*}; defect "$n"
  fvm dart analyze packages/nidana_dart_runtime_flutter 2>&1 | grep -qE ' error ' && echo "defect $n: analysis errors" || echo "defect $n: compiles"
done
adapter v2
fvm dart analyze --fatal-infos probe; echo "probes exit: $?"

step "T4 both bindings after, on each runtime, adapter v2"
for r in v2 v1; do
  runtime $r
  adapter v2
  echo "== runtime $r, adapter v2"
  fsuite $SUITE
  fsuite $EXEC
done
runtime v1
why $SUITE "G5 a builder mounted before start() renders the initial value, then what start() delivers"
why $SUITE "G8 one route pushed twice holds one activation of a page topology equal to its next evaluation, and a page topology that passes a closure fails the second mount with TopologyConflict"

step "T5 both bindings before, on each runtime and each adapter"
use hsdd-before
for r in v1 v2; do
  runtime $r
  for a in v1 v2; do
    adapter $a
    echo "== runtime $r, adapter $a"
    fsuite $SUITE
    fsuite $EXEC
  done
done
runtime v1
defect first-skip
echo "== runtime v1, adapter v1 plus NidanaModule alone (defect/first-skip: adapter v2 with v1's topic widgets)"
fsuite $SUITE
runtime v2
adapter v2
why $SUITE "G8 a PageScope binds once, at mount: a rebuild with other arguments keeps that binding"
use $REPO

step "T6 seeded defects in adapter v2, on the v2 runtime, after"
runtime v2
for d in defect/*.dart; do
  n=${d#defect/}; n=${n%%.*}
  defect "$n"
  echo "== defect $n"
  fsuite $SUITE
done
adapter v2

step "T7 the name prefix 'G20 ' selects that guarantee's cases"
fvm flutter test --no-pub --reporter expanded --name '^G20 ' $SUITE 2>&1 | grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' | tail -n 1

step "T8 probes N1 to N6: a widget in a page or around a nested Navigator, on Flutter's Navigator"
fvm flutter test --no-pub probe/wrapper_facts_test.dart 2>&1 | grep -E '^N[0-9]|All tests passed|Some tests failed'

step "T9 probes R6 to R8: the same under go_router 18.1.0, in its own package"
(cd gorouter_probe && fvm flutter pub get --offline > /dev/null 2>&1; echo "pub get exit: $?"; fvm flutter pub deps --style=compact 2>&1 | grep -E '^- go_router ')
(cd gorouter_probe && fvm flutter test --no-pub test/gorouter_wrapper_test.dart 2>&1 | grep -E '^R[0-9]|All tests passed|Some tests failed')

step "cleanup: restore the v2 runtime and adapter v2, remove the copied trees and the Flutter build output"
runtime v2
adapter v2
rm -rf hsdd hsdd-before build gorouter_probe/build gorouter_probe/.dart_tool gorouter_probe/pubspec.lock .baseline.sh; echo "removed"
