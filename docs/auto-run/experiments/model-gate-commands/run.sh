#!/usr/bin/env bash
# Run from this directory: bash run.sh > output.txt 2>&1
cd "$(dirname "$0")"
step() { echo; echo "### $1"; }
step "G0 pub get at the root, offline"
fvm dart pub get --offline 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}"
step "G1 dart test with a member directory, run from the root (root dev dependency: lints only)"
fvm dart test packages/mgc_pure 2>&1 | tail -4; echo "exit: ${PIPESTATUS[0]}"
step "G2 dart test with a member's test directory, run from the root"
fvm dart test packages/mgc_pure/test 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}"
step "G3 dart test inside the member"
(cd packages/mgc_pure && fvm dart test 2>&1 | tail -3; echo "exit: ${PIPESTATUS[0]}")
step "G4 dart run of a member's executable from the root, the root not depending on it"
fvm dart run mgc_tool a b 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}"
step "G5 dart test of a member directory that does not exist"
fvm dart test packages/absent 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}"
step "G6 pub get --enforce-lockfile with the committed lockfile in place"
fvm dart pub get --enforce-lockfile --offline 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}"
step "G7 pub get --enforce-lockfile after a member adds a dependency the lockfile lacks (json_schema)"
cp packages/mgc_tool/pubspec.yaml mgc_tool_pubspec.bak
printf 'dependencies:\n  json_schema: ^5.2.2\n' >> packages/mgc_tool/pubspec.yaml
fvm dart pub get --enforce-lockfile --offline 2>&1 | tail -3; echo "exit: ${PIPESTATUS[0]}"
mv mgc_tool_pubspec.bak packages/mgc_tool/pubspec.yaml; fvm dart pub get --offline > /dev/null 2>&1
step "G8 dart analyze --fatal-infos at the root"
fvm dart analyze --fatal-infos 2>&1 | tail -2; echo "exit: ${PIPESTATUS[0]}"
