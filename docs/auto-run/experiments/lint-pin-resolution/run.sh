#!/usr/bin/env bash
# lint-pin-resolution: before nidana.flutter.1 the workspace has no
# flutter_test, so nothing holds test at 1.31.1 and analyzer below 14
# (ADR-002 Context, Q1 and Q2). nidana.tooling.lint.1 adds a member pinned to
# analyzer 13.3.0 and analysis_server_plugin 0.3.18, with analyzer_testing.
#   L1 the workspace before the plugin: which analyzer and test resolve;
#   L2 the plugin's member added: does it resolve, and what moves;
#   L3 a member constrained to analyzer ^14.5.0 beside the plugin.
# Resolved offline from the pub cache. Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
step() { echo; echo "### $*"; }
members() { # $@ member directories
  { sed -n '1,/^workspace:/p' pubspec.yaml.base; for m in "$@"; do echo "  - packages/$m"; done; echo "dev_dependencies:"; echo "  lints: ^6.1.0"; } > pubspec.yaml
}
resolved() { awk '/^  [a-z_]+:$/{p=$1} p && /version:/{print "  resolved", p, $2; p=""}' pubspec.lock | grep -E ' (analyzer|analysis_server_plugin|analyzer_testing|test|test_core):'; }
cp pubspec.yaml pubspec.yaml.base
sed -i '' '/^workspace:/,$d' pubspec.yaml.base; echo "workspace:" >> pubspec.yaml.base
trap 'members lpr_pure; rm -f pubspec.yaml.base' EXIT
fvm dart --version
step "L1 pure members only"
rm -f pubspec.lock; members lpr_pure
fvm dart pub get --offline > /tmp/lpr.$$ 2>&1; echo "pub get exit: $?"; resolved
step "L2 the plugin's member added"
members lpr_pure lpr_lint
fvm dart pub get --offline > /tmp/lpr.$$ 2>&1; echo "pub get exit: $?"; grep -E '^[<>*] (analyzer|test|test_core) ' /tmp/lpr.$$; resolved
step "L3 a member constrained to analyzer ^14.5.0 beside the plugin"
members lpr_pure lpr_lint lpr_codegen
fvm dart pub get --offline > /tmp/lpr.$$ 2>&1; echo "pub get exit: $?"; grep -v '^Resolving' /tmp/lpr.$$ | head -8
rm -f /tmp/lpr.$$
