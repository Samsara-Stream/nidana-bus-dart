#!/usr/bin/env bash
# flutter-phase-facts: runtime facts nidana.flutter's phase plan (S34) rests
# on, on the stand-in packages of ../runtime-reconcile-amends/ copied
# unchanged (a runtime that meets bus-api@v1 G41 and bus-testing@v1 G18 as
# amended in S31, and the flutter-binding@v1 stand-in of
# ../flutter-binding-fixtures/), in a pure-Dart workspace root as ADR-002
# lays out the repository's.
#
#   F1 the default gate's resolution commands at a workspace root with a
#      Flutter member: `fvm dart pub get --enforce-lockfile`;
#   F2 a Flutter member's package tests under `fvm flutter test --no-pub`, run
#      from the workspace root by path (the member directory and its test/
#      directory) and from inside the member;
#   F3 what such a test sees: its working directory, Isolate.resolvePackageUri,
#      and an ancestor search for the workspace root
#      (packages/nidana_dart_runtime_flutter/test/locate_test.dart);
#   F4 topic widgets and an off-type value published through a widened
#      reference: the stand-in's typed subscription against a widened one
#      (probe/off_type_test.dart);
#   F5 WidgetTestBus.stub for one topic at two type arguments (same file).
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
M=packages/nidana_dart_runtime_flutter
step() { echo; echo "### $*"; }
fvm flutter --version | head -n 1
fvm dart --version

step "F1 resolve once with flutter pub get, then the gate's dart pub get --enforce-lockfile at the root"
fvm flutter pub get > /dev/null 2>&1; echo "flutter pub get exit: $?"
fvm dart pub get --enforce-lockfile 2>&1 | tail -n 1; echo "dart pub get --enforce-lockfile exit: ${PIPESTATUS[0]}"

step "F2/F3 from the root, the member directory: fvm flutter test --no-pub $M"
fvm flutter test --no-pub $M 2>&1 | grep -E '^F3|All tests passed|Some tests failed|No tests|rror'; echo "exit: ${PIPESTATUS[0]}"
step "F2/F3 from the root, the member's test directory: fvm flutter test --no-pub $M/test"
fvm flutter test --no-pub $M/test 2>&1 | grep -E '^F3|All tests passed|Some tests failed|No tests|rror'; echo "exit: ${PIPESTATUS[0]}"
step "F2/F3 inside the member: fvm flutter test --no-pub"
(cd $M && fvm flutter test --no-pub 2>&1 | grep -E '^F3|All tests passed|Some tests failed|No tests|rror'; echo "exit: ${PIPESTATUS[0]}")

step "F4/F5 topic widgets and stub with off-type values (probe/off_type_test.dart, from the root)"
fvm flutter test --no-pub probe/off_type_test.dart 2>&1 | grep -E '^F[45]|All tests passed|Some tests failed'; echo "exit: ${PIPESTATUS[0]}"

step "cleanup: remove build output and the resolution"
rm -rf build .dart_tool packages/*/.dart_tool packages/*/build pubspec.lock
echo removed
