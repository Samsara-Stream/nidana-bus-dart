#!/usr/bin/env bash
# integration-plan-facts: runtime facts behind nidana.integration's phase
# plan (hsdd/spec/nidana.integration.md, step S41). Its CI slice runs the
# codegen's commands and the v1 checks over the example member, and over
# seeded copies that ADR-002 Consequences keeps out of the member's analyzed
# code. This settles whether the member's own tests can drive those tools.
#
# Layout: work/ is a pub workspace rebuilt on every run from the stand-ins of
# ../nidana-checks-fixtures/packages/ (the plugin with its four rules, the
# scan, and the nidana packages it recognizes) plus src/nidana_integration, a
# Flutter member shaped like ADR-002 item 3's nidana_integration row. The root
# options are ADR-002 item 2's with item 7's plugin section.
#
#   I0 the root analyze with the Flutter member in the workspace;
#   I1 what a test of the member, run from the workspace root under
#      `fvm flutter test --no-pub packages/nidana_integration`, sees of the
#      toolchain: FLUTTER_ROOT, the root package configuration's flutterRoot,
#      the pinned dart derived from them;
#   I2 that test running a member's executable (`dart run
#      nidana_dart_codegen:scan`) from the workspace root;
#   I3 a seeded package in a temporary directory outside the workspace, with
#      a synthesized package configuration (the workspace's packages by
#      absolute root, plus itself) and options enabling the plugin by
#      absolute path: `dart analyze --format=machine .` inside it;
#   I4 the scan over the member and that seeded package together;
#   I5 a nested `flutter test` started from inside the outer one;
#   I6 which output directories the root analyze reads, for where a gate
#      may write what `catalog` and `generate` produce;
#   I7 build_runner 2.16.1 in a member whose generated output is committed:
#      a fresh checkout (no .dart_tool), the removed
#      --delete-conflicting-outputs flag, a stale committed output.
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
ROOT=$(pwd)
W=$ROOT/work
step() { echo; echo "### $*"; }
paths() { sed -e "s|$W|{root}|g" -e "s|$HOME|{home}|g"; }

rm -rf "$W" && mkdir -p "$W/packages"
cp -R ../nidana-checks-fixtures/packages/* "$W/packages/"
cp -R src/nidana_integration "$W/packages/"
cat > "$W/pubspec.yaml" <<'EOF'
name: ipf_root
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - packages/nidana_dart_codegen
  - packages/nidana_dart_contracts
  - packages/nidana_dart_lint
  - packages/nidana_dart_navigation
  - packages/nidana_dart_runtime
  - packages/nidana_dart_runtime_flutter
  - packages/nidana_integration
dev_dependencies:
  lints: ^6.1.0
EOF
cat > "$W/analysis_options.yaml" <<'EOF'
include: package:lints/recommended.yaml
analyzer:
  exclude:
    - ref/**
    - docs/**
    - hsdd/**
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
plugins:
  nidana_dart_lint:
    path: packages/nidana_dart_lint
EOF
cd "$W" || exit 1

step "setup: SDK, resolve with dart pub get (no lockfile), then --enforce-lockfile"
fvm flutter --version | head -n 1
fvm dart pub get > /dev/null 2>&1; echo "dart pub get exit: $?"
fvm dart pub get --enforce-lockfile > /dev/null 2>&1; echo "dart pub get --enforce-lockfile exit: $?"
grep -o '"flutterRoot": *"[^"]*"' .dart_tool/package_config.json | paths

step "I0 the root analyze with the Flutter member, the plugin enabled"
fvm dart analyze --fatal-infos 2>&1 | paths | tail -n 3; echo "exit: ${PIPESTATUS[0]}"

step "I1 to I5 the member's probe test, from the workspace root"
fvm flutter test --no-pub packages/nidana_integration 2>&1 | paths | grep -E '^I[0-9]:|All tests passed|Some tests failed|\[E\]'; echo "exit: ${PIPESTATUS[0]}"

step "I6 which output directories the root analyze reads: a library with an unused import written to build/, .dart_tool/ and the member's build/"
for d in build/ci .dart_tool/ci packages/nidana_integration/build/ci; do
  mkdir -p $d && printf "import 'dart:async';\n\nvoid f() {}\n" > $d/stray.dart
done
fvm dart analyze --fatal-infos --format=machine 2>&1 | paths | cut -d'|' -f1,3,4; echo "exit: ${PIPESTATUS[0]}"
rm -rf build/ci .dart_tool/ci packages/nidana_integration/build/ci

step "cleanup"
cd "$ROOT" && rm -rf "$W"
echo removed

# I7: src/build_probe is a second, smaller workspace: mini_gen, a builder with
# topic-codegen@v1's build.yaml shape (^lib/topics.yaml to lib/topics.g.dart,
# auto_apply dependents, build_to source), and app, which depends on it and
# on build_runner ^2.16.1 (ADR-002 item 4) as nidana_integration does.
B=$ROOT/build_work
rm -rf "$B" && cp -R src/build_probe "$B" && cd "$B" || exit 1
bpaths() { sed -e "s|$B|{root}|g" -e "s|$HOME|{home}|g"; }
step "I7 build_runner in a member whose generated output is committed"
fvm dart pub get > /dev/null 2>&1; echo "dart pub get exit: $?"
grep -A2 '^  build_runner:' pubspec.lock | grep version | sed 's|^ *|resolved build_runner |'
echo "-- I7a first build"
(cd packages/app && fvm dart run build_runner build 2>&1 | bpaths | grep -E '^ *(W|E|Built|Failed|Conflict)|wrote|conflict' ; echo "exit: ${PIPESTATUS[0]}")
cat packages/app/lib/topics.g.dart
echo "-- I7b a fresh checkout: the committed output kept, every .dart_tool removed, resolved again, built"
rm -rf .dart_tool packages/*/.dart_tool && fvm dart pub get > /dev/null 2>&1
(cd packages/app && fvm dart run build_runner build 2>&1 | bpaths | grep -E '^ *(W|E|Built|Failed|Conflict)|wrote|conflict' ; echo "exit: ${PIPESTATUS[0]}")
echo "-- I7c the same with --delete-conflicting-outputs"
rm -rf .dart_tool packages/*/.dart_tool && fvm dart pub get > /dev/null 2>&1
(cd packages/app && fvm dart run build_runner build --delete-conflicting-outputs 2>&1 | bpaths | grep -E '^ *(W|E|Built|Failed|Conflict)|wrote|conflict' ; echo "exit: ${PIPESTATUS[0]}")
echo "-- I7d a stale committed output in a fresh checkout: does the build rewrite it?"
printf '// stale\n' > packages/app/lib/topics.g.dart
rm -rf .dart_tool packages/*/.dart_tool && fvm dart pub get > /dev/null 2>&1
(cd packages/app && fvm dart run build_runner build 2>&1 | bpaths | grep -E '^ *(W|E|Built|Failed|Conflict)|wrote|conflict' ; echo "exit: ${PIPESTATUS[0]}")
cat packages/app/lib/topics.g.dart
step "cleanup I7"
cd "$ROOT" && rm -rf "$B"
echo removed
