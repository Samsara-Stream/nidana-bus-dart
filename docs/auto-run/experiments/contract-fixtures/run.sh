#!/usr/bin/env bash
# contract-fixtures: settles the runtime facts ADR-001 rests on.
#
# The experiment is its own pub workspace, laid out like the planned tree:
# a lint-enabled root whose analysis_options.yaml excludes hsdd/**, a pure
# producer (demo_contracts), a Flutter implementer (demo_flutter), a tool
# stand-in (demo_check), an analyzer plugin member (demo_lint), and a
# governance tree under hsdd/contract/ holding surface, reject, behavior,
# schema and recorded-invocation fixtures.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
F=hsdd/contract/fixture
step() { echo; echo "### $*"; }

step "setup: resolve the workspace"
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  (matcher|json_schema|test|test_api|lints|meta|analyzer):/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock

step "Q1 workspace-wide analyze at the root (root excludes hsdd/**; fixtures hold deliberate errors)"
fvm dart analyze; echo "exit: $?"

step "Q2 explicit path into the excluded tree is still analyzed; nested hsdd/contract/fixture/analysis_options.yaml replaces the root lint set"
fvm dart analyze --format=machine $F/demo-api/reject; echo "exit: $?"

step "Q3 json format: lowercase code and 1-based line per diagnostic"
fvm dart analyze --format=json $F/demo-api/reject/event_topic_has_no_value.dart; rc=$?; echo; echo "exit: $rc"

step "Q4 surface fixtures with --fatal-infos: clean set"
fvm dart analyze --fatal-infos --format=machine $F/demo-api/surface; echo "exit: $?"

step "Q5 surface fixtures with --fatal-infos: deprecated use (info) and raw types under strict modes (warning) both fail"
fvm dart analyze --fatal-infos --format=machine $F/demo-api-broken/surface; echo "exit: $?"

step "Q6 reject rule prototype: marker on its own line names the diagnostic on the next line; no other diagnostic of any severity"
fvm dart run packages/demo_check/bin/reject_check.dart $F/demo-api/reject; echo "exit: $?"

step "Q7 reject rule prototype on broken fixtures: wrong line, extra diagnostics, a code authored without running the analyzer"
fvm dart run packages/demo_check/bin/reject_check.dart $F/demo-api-broken/reject; echo "exit: $?"

step "Q8 behavior: pure binding under dart test, run from the root"
fvm dart test $F/demo-api/behavior/in_memory_executor_test.dart 2>&1 | tail -3; echo "exit: ${PIPESTATUS[0]}"

step "Q9 behavior: guarantee filter by test-name prefix"
fvm dart test --name '^G3 ' $F/demo-api/behavior/in_memory_executor_test.dart 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}"

step "Q10 behavior: the same conformance library bound under testWidgets, flutter test --no-pub from the root (root package is pure Dart)"
fvm flutter test --no-pub $F/demo-api/behavior/flutter_executor_test.dart 2>&1 | tail -3; echo "exit: ${PIPESTATUS[0]}"

step "Q11 behavior: flutter test from inside the Flutter member, fixture by relative path, with a guarantee filter"
(cd packages/demo_flutter && fvm flutter test --no-pub --name '^G3 ' ../../$F/demo-api/behavior/flutter_executor_test.dart 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}")

step "Q12 behavior: the Flutter binding under dart test fails to load (dart:ui), so the runner must be chosen per binding"
fvm dart test $F/demo-api/behavior/flutter_executor_test.dart 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}"

step "Q13 behavior: a binding whose implementing package does not exist yet fails to load"
fvm dart test $F/demo-api-pending/behavior/absent_impl_test.dart 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}"

step "Q14 binding selection prototype: runner from imports, PENDING from package_config"
fvm dart run packages/demo_check/bin/binding_plan.dart $F/demo-api/behavior $F/demo-api-pending/behavior; echo "exit: $?"

step "Q15 a consumer stand-in bound from a member's test directory by relative import of the conformance library"
(cd packages/demo_check && fvm dart test test/standin_test.dart 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}")

step "Q16 schema: draft 2020-12 (\$defs, prefixItems, items:false, unevaluatedProperties) through json_schema"
fvm dart run packages/demo_check/bin/schema_check.dart hsdd/contract/schema/demo-ir.schema.json $F/demo-ir; echo "exit: $?"

step "Q17 tool invocation: dart run <member> from the root, root not depending on the member"
fvm dart run demo_check slug --set surface; echo "exit: $?"

step "Q18 recorded cli invocation: an input tree whose own analysis_options enables an analyzer plugin by relative path (plugin outside the workspace)"
fvm dart analyze --format=json $F/demo-checks/global-bus/files; rc=$?; echo; echo "exit: $rc"

step "Q19 the same with the plugin as a workspace member (resolution: workspace)"
fvm dart analyze --format=json $F/demo-checks/global-bus-member/files; rc=$?; echo; echo "exit: $rc"
