#!/usr/bin/env bash
# navigation-stage-names: S32 (phase plan of nidana.navigation) settles two
# runtime facts for its decisions, on the stand-in packages of
# ../navigation-api-touch/ (nidana_dart_contracts, nidana_contract_check,
# nidana_dart_runtime, nidana_dart_navigation, copied unchanged; the Flutter
# stand-in is left out because nothing here needs it).
#   S1 the FunctionRefs the recorded nav-resolver carries when its stage
#      functions are closures (the stand-in as written) and when they are
#      method tear-offs of private stage classes (patch/navigation.named.dart):
#      the names a graph or catalog of the resolver shows (topology-ir@v1 G9);
#   S2 whether navigation-api@v1's two bindings, from the repository's
#      fixtures, still pass with the named stage functions: the navigation
#      suite (G13 records the resolver; G14, G15 and G24 run it live) and the
#      executor suite on InMemoryRouter;
#   S3 what an error event on a synchronous broadcast stream does to a
#      listener that passes onData only (probe/confirmation_errors.dart), the
#      shape of the executor's subscription to a router's confirmations.
# The fixtures are copied from the repository's hsdd/contract/ to ./hsdd/ for
# the run and removed after it.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
N=$F/navigation-api
NAV=packages/nidana_dart_navigation/lib/src/navigation.dart
step() { echo; echo "### $*"; }

rm -rf hsdd && mkdir -p $F
cp $REPO/hsdd/contract/*.md hsdd/contract/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$N $F/
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version

step "T0 the stand-in navigation library is ../navigation-api-touch/'s, unchanged, and patch/navigation.closures.dart is a copy of it"
diff -q ../navigation-api-touch/$NAV $NAV && echo "navigation.dart: identical to navigation-api-touch"
diff -q patch/navigation.closures.dart $NAV && echo "patch/navigation.closures.dart: identical"

bindings() {
  for b in $N/behavior/nidana_dart_navigation_test.dart $N/behavior/in_memory_router_test.dart; do
    echo "-- $b"; fvm dart test "$b" 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
  done
}

step "S1a closures (as written): the recorded resolver's transformers"
cp patch/navigation.closures.dart $NAV
fvm dart run probe/stage_names.dart; echo "exit: $?"
step "S2a closures (as written): navigation-api@v1's bindings"
bindings

step "S1b method tear-offs (patch/navigation.named.dart): the recorded resolver's transformers"
cp patch/navigation.named.dart $NAV
fvm dart analyze --fatal-infos packages/nidana_dart_navigation; echo "analyze exit: $?"
fvm dart run probe/stage_names.dart; echo "exit: $?"
step "S2b method tear-offs: navigation-api@v1's bindings"
bindings

step "S3 an error event on a synchronous broadcast stream, listened with onData only inside a guarded zone"
fvm dart run probe/confirmation_errors.dart; echo "exit: $?"

step "cleanup: restore the stand-in as written, remove the copied fixtures"
cp patch/navigation.closures.dart $NAV
rm -rf hsdd; echo "removed"
