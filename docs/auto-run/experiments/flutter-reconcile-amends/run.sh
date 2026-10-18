#!/usr/bin/env bash
# flutter-reconcile-amends: S35 (hsdd-reconcile of nidana.flutter's plan)
# applies the plan's four compatible amends of flutter-binding@v1: G5 and G6,
# a topic widget subscribes through a widened reference, so a value of
# another type fails the build with TypeError, reaches no provider-zone
# handler, and the next on-type delivery renders (D7); G7, a route named `/`
# alone gives the page route `/` (D11); G8, a PageScope keeps its binding
# when the provided bus changes (D10); G17, `stub` keeps one publisher per
# topic and returns its writer per type argument, ClaimRejected on a rejected
# claim (D8). ADR-001 item 3 needs each covered, so the suite gains one case
# for each of G5, G6, G7, G8 and G17. This checks:
#   T1 the fixture change is those five cases and one helper, nothing else;
#   T2 structure still holds for flutter-binding (19 guarantees, 57 cases);
#   T3 the conformance library and both bindings analyze clean;
#   T4 against the stand-in as copied (typed subscriptions, the empty route
#      for `/`, one cached writer per topic), the new G5, G6, G7 and G17
#      cases fail and every other case passes; the new G8 case passes,
#      because the stand-in already binds once;
#   T5 against the stand-in patched to meet the amendments (patch/*.amended
#      .dart), which analyzes clean, every case of both bindings passes;
#   T6 a seeded defect in the patched stand-in, a PageScope that rebinds when
#      the provided bus changes (patch/page_scope.rebinds.dart), fails the new
#      G8 case and no other;
#   T7 the fixtures from before the amendments pass against the patched
#      stand-in, so the amendments break no case that existed;
#   T8 the name-prefix restriction each consuming gate uses selects the new
#      cases: nidana.flutter.4's G3 to G6, .5's G7 and G8, .6's G17;
#   T9 for the conventions line the plan's note asks for: `fvm dart pub get`
#      resolves a workspace with a Flutter member from no lockfile, and the
#      default gate's `fvm dart pub get --enforce-lockfile` then passes.
# Stand-ins: the five packages of ../flutter-phase-facts/, copied unchanged
# (T0 shows it): a runtime that meets bus-api@v1 G41 and bus-testing@v1 G18
# as amended in S31, and the flutter-binding@v1 stand-in of
# ../flutter-binding-fixtures/.
# Fixture trees, each copied to hsdd/ in turn at the repository's relative
# paths: before/ is hsdd/contract at the commit this step starts from (git
# archive of HEAD); "after" is the repository's hsdd/contract as it stands.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
B=$F/flutter-binding
OWN=$B/behavior/nidana_dart_runtime_flutter_test.dart
NAV=$B/behavior/flutter_navigation_executor_test.dart
SRC=packages/nidana_dart_runtime_flutter/lib/src
step() { echo; echo "### $*"; }

use() {
  rm -rf hsdd && mkdir -p $F
  cp "$1"/hsdd/contract/*.md hsdd/contract/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$F/navigation-api "$1"/$F/flutter-binding $F/
}

# suite {binding...}: the result line and every failing case's name.
suite() {
  echo "-- $*"
  fvm flutter test --no-pub --reporter expanded "$@" > .suite.log 2>&1; local code=$?
  grep -E '\[E\]$' .suite.log | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: /FAILED: /' | sed -E 's/ \[E\]$//' | sort -u
  grep -E '^[0-9:]+ \+[0-9]+.*: (All tests passed!|Some tests failed\.)$' .suite.log | tail -n 1
  echo "exit: $code"
  rm -f .suite.log
}

# why {name prefix}: the first lines of the failure of the cases named so.
why() {
  echo "-- why: $1"
  fvm flutter test --no-pub --plain-name "$1" $OWN 2>&1 \
    | grep -E '^(Expected|  Actual|   Which|The following|LateInitializationError|.*TypeError)' | head -n 6
}

amended() {
  cp patch/topic_builders.amended.dart $SRC/topic_builders.dart
  cp patch/page_scope.amended.dart $SRC/page_scope.dart
  cp patch/widget_test_bus.amended.dart $SRC/widget_test_bus.dart
}

as_copied() {
  for f in topic_builders page_scope widget_test_bus; do
    cp ../flutter-phase-facts/$SRC/$f.dart $SRC/$f.dart
  done
}

step "setup: the before tree from git, resolve"
rm -rf before && mkdir -p before
git -C $REPO archive HEAD hsdd/contract | tar -x -C before
echo "before: hsdd/contract at $(git -C $REPO rev-parse --short HEAD)"
as_copied
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm flutter --version | head -n 1
fvm dart --version

step "T0 the stand-in packages are ../flutter-phase-facts/'s, unchanged"
for p in nidana_dart_contracts nidana_contract_check nidana_dart_runtime nidana_dart_navigation nidana_dart_runtime_flutter; do
  diff -rq -x .dart_tool -x build ../flutter-phase-facts/packages/$p packages/$p > /dev/null && echo "$p: identical" || echo "$p: DIFFERS"
done

step "T1 what changed among the flutter-binding@v1 and navigation-api@v1 fixtures, before against after"
use before; mv hsdd hsdd-before
use $REPO
diff -ru hsdd-before/contract/fixture hsdd/contract/fixture; echo "fixture diff exit: $?"
rm -rf hsdd-before

step "T2 structure (after): headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check flutter-binding; echo "exit: $?"

step "T3 the conformance library and both bindings analyze clean under the fixture options (after)"
fvm dart analyze --fatal-infos $B/behavior; echo "exit: $?"

step "T4 after, the stand-in as copied"
suite $OWN
why 'G5 a value of another type'
why 'G6 while the buffer holds'
why 'G7 a route named / alone'
why 'G17 stub keeps one publisher'
suite $NAV

step "T5 after, the stand-in patched to meet the amendments"
amended
for f in topic_builders page_scope widget_test_bus; do echo "-- patch/$f.amended.dart against the stand-in as copied"; diff ../flutter-phase-facts/$SRC/$f.dart $SRC/$f.dart; done
fvm dart analyze --fatal-infos packages/nidana_dart_runtime_flutter; echo "analyze exit: $?"
suite $OWN
suite $NAV

step "T6 after, seeded defect: a PageScope that rebinds when the provided bus changes"
cp patch/page_scope.rebinds.dart $SRC/page_scope.dart
fvm dart analyze --fatal-infos packages/nidana_dart_runtime_flutter; echo "analyze exit: $?"
suite $OWN
why 'G8 a PageScope stays bound'
amended

step "T7 before, the patched stand-in: the fixtures from before the amendments"
use before
suite $OWN
suite $NAV

step "T8 after, the patched stand-in: the cases each consuming gate's restriction selects, new ones marked"
use $REPO
for sel in '^(G3|G4|G5|G6) ' '^(G7|G8) ' '^G17 '; do
  echo "-- --name '$sel'"
  fvm flutter test --no-pub --reporter expanded --name "$sel" $OWN 2>&1 \
    | sed -nE 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: (G[0-9]+ .*)$/\3/p' | sort -u \
    | grep -E "^(G5 a value of another type|G6 while the buffer holds|G7 a route named / alone|G8 a PageScope stays bound|G17 stub keeps one publisher)" | sed 's/^/NEW: /'
  fvm flutter test --no-pub --name "$sel" $OWN 2>&1 | tail -n 1
done

step "T9 fvm dart pub get, not flutter pub get, resolves this workspace with a Flutter member from no lockfile, and --enforce-lockfile then passes"
rm -rf pubspec.lock .dart_tool packages/*/.dart_tool
fvm dart pub get > .pub.log 2>&1; echo "fvm dart pub get exit: $?"; tail -n 1 .pub.log
grep -c '^  flutter:' pubspec.lock | sed 's/^/lockfile entries named flutter: /'
grep -A3 '^  flutter:' pubspec.lock | grep -E 'source|version' | sed 's/^ */  /'
fvm dart pub get --enforce-lockfile > .pub.log 2>&1; echo "fvm dart pub get --enforce-lockfile exit: $?"
rm -f .pub.log

step "cleanup: restore the stand-in as copied, remove the copied fixtures, the before tree and the build output"
as_copied
rm -rf hsdd before build; echo "removed"
