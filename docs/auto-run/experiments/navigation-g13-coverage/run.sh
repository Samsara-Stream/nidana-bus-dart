#!/usr/bin/env bash
# navigation-g13-coverage: S33 (hsdd-reconcile of nidana.navigation's plan)
# applies the plan's compatible amend of navigation-api@v1 G13: the resolver's
# transform edges record `resolveDeepLinks` (intent map),
# `FunctionRef.of(principalOf)` (auth map) and `applyAuthGuard`
# (withLatestFrom), in both forms, on the VM. ADR-001 item 3 needs the clause
# covered, so the navigation suite gains one G13 case. This checks:
#   T1 the fixture change is that one case and nothing else;
#   T2 structure still holds for navigation-api (27 guarantees, one case more);
#   T3 the conformance library and its bindings analyze clean;
#   T4 the new case fails against a resolver whose stages are closures (the
#      stand-in as ../navigation-stage-names/ found it) and against one that
#      wraps the app's projection in a closure (seeded defect), and every
#      other case passes against both;
#   T5 every case passes against the resolver with named stages
#      (../navigation-stage-names/patch/navigation.named.dart), and the four
#      G13 cases are what a `--guarantee G13` restriction selects;
#   T6 the fixtures from before the amend pass unchanged against the named
#      stand-in, so the amend breaks no case that existed;
#   T7 what FunctionRef.of yields for a private name (T4b shows the VM adds a
#      library key to `_principalOf`): JIT twice, then AOT.
# Stand-ins: nidana_dart_contracts, nidana_contract_check (structure and
# reject prototypes), nidana_dart_runtime, nidana_dart_navigation, copied
# unchanged from ../navigation-stage-names/ (T0 shows it).
# Fixture trees, each copied to hsdd/ in turn at the repository's relative
# paths: before/ is hsdd/contract at the commit this step starts from (git
# archive of HEAD); "after" is the repository's hsdd/contract as it stands.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
N=$F/navigation-api
NAV=packages/nidana_dart_navigation/lib/src/navigation.dart
step() { echo; echo "### $*"; }

use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$N $F/
}

# suite {binding}: the binding's result line and every failing case's name.
suite() {
  echo "-- $1"
  fvm dart test --reporter expanded "$1" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /'
  grep -E '^ *(Expected|Actual|Which|[a-z]+): ' .suite.log | sed -E 's/^ */  /'
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

step "setup: the before tree from git, resolve"
rm -rf before && mkdir -p before
git -C $REPO archive HEAD hsdd/contract | tar -x -C before
echo "before: hsdd/contract at $(git -C $REPO rev-parse --short HEAD)"
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version

step "T0 the stand-in packages and patches are ../navigation-stage-names/'s, unchanged"
for p in nidana_dart_contracts nidana_contract_check nidana_dart_runtime nidana_dart_navigation; do
  diff -rq -x .dart_tool ../navigation-stage-names/packages/$p packages/$p > /dev/null && echo "$p: identical" || echo "$p: DIFFERS"
done
for v in closures named; do
  diff -q ../navigation-stage-names/patch/navigation.$v.dart patch/navigation.$v.dart > /dev/null && echo "patch/navigation.$v.dart: identical" || echo "patch/navigation.$v.dart: DIFFERS"
done
echo "-- patch/navigation.wrapped-projection.dart against patch/navigation.named.dart"
diff patch/navigation.named.dart patch/navigation.wrapped-projection.dart

step "T1 what changed among navigation-api@v1's fixtures, before against after"
use before; mv hsdd hsdd-before
use $REPO
diff -ru hsdd-before/contract/fixture hsdd/contract/fixture; echo "fixture diff exit: $?"
rm -rf hsdd-before

step "T2 structure (after): headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check navigation-api | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check navigation-api | grep '^PASS G13'

step "T3 the conformance libraries and the bindings analyze clean under the fixture options (after)"
fvm dart analyze --fatal-infos $N/behavior; echo "exit: $?"

step "T4a after, closures stand-in (both stages anonymous)"
cp patch/navigation.closures.dart $NAV
suite $N/behavior/nidana_dart_navigation_test.dart
suite $N/behavior/in_memory_router_test.dart

step "T4b after, seeded defect: named stages, the auth map wraps the projection in a closure"
cp patch/navigation.wrapped-projection.dart $NAV
fvm dart analyze --fatal-infos packages/nidana_dart_navigation; echo "analyze exit: $?"
suite $N/behavior/nidana_dart_navigation_test.dart

step "T5 after, named stand-in (method tear-offs of private stage classes)"
cp patch/navigation.named.dart $NAV
suite $N/behavior/nidana_dart_navigation_test.dart
suite $N/behavior/in_memory_router_test.dart
echo "-- the cases a --guarantee G13 restriction selects (names beginning 'G13 ')"
fvm dart test --reporter expanded --plain-name 'G13 ' $N/behavior/nidana_dart_navigation_test.dart 2>&1 | sed -nE 's/^[0-9:]+ \+[0-9]+: (.*G13 .*)$/\1/p' | sed -E 's/^.*(G13 .*)$/\1/' | sort -u
fvm dart test --plain-name 'G13 ' $N/behavior/nidana_dart_navigation_test.dart 2>&1 | tail -n 1

step "T6 before, named stand-in: the fixtures from before the amend"
use before
suite $N/behavior/nidana_dart_navigation_test.dart
suite $N/behavior/in_memory_router_test.dart

step "T7 probe/private_names.dart: FunctionRef.of of private and public names, JIT twice, then AOT"
fvm dart run probe/private_names.dart; echo "exit: $?"
fvm dart run probe/private_names.dart; echo "exit: $?"
fvm dart compile exe probe/private_names.dart -o .private_names.exe > /dev/null 2>&1; echo "compile exe exit: $?"
./.private_names.exe; echo "exit: $?"
rm -f .private_names.exe

step "cleanup: restore the stand-in as copied, remove the copied fixtures and the before tree"
cp patch/navigation.closures.dart $NAV
rm -rf hsdd before; echo "removed"
