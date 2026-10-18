#!/usr/bin/env bash
# plugin-rebuild: settles whether `fvm dart analyze` picks up an edit to a
# path-enabled analysis server plugin at the same path, on the pinned SDK,
# analyzer 13.3.0 and analysis_server_plugin 0.3.18. nidana.tooling.lint's
# gates edit packages/nidana_dart_lint and then run `dart analyze` (the root
# analyze and nidana-checks@v1's analyze-* recorded invocations) against the
# plugin at the same path; nidana-checks-fixtures' seeded defects (T5) ran
# from copies at other absolute paths, so they did not settle it.
#
#   R1 a cold analysis, after the synthetic plugin packages for this path are
#      removed; R2 the same analysis again, unchanged (timing);
#   R3 the rule's message edited in lib/src/rule.dart;
#   R4 the rule's reach edited in lib/src/rule.dart (one more name reported);
#   R5 lib/main.dart edited to register a second rule;
#   R6 lib/src/rule.dart made not to compile; R7 restored.
#
# cases/app is shaped like an analyze-* case's files/: a pubspec.yaml never
# resolved by pub, options enabling the plugin by relative path, and
# `dart analyze .` run inside it. Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
ROOT=$(pwd)
R=packages/pr_lint/lib/src/rule.dart
M=packages/pr_lint/lib/main.dart
step() { echo; echo "### $*"; }
paths() { sed -e "s|$ROOT|{root}|g" -e "s|$HOME|{home}|g"; }
synthetic() { grep -l "packages/pr_lint\$" "$HOME"/.dartServer/.plugin_manager/*/pubspec.yaml 2>/dev/null | wc -l | tr -d ' '; }
analyze() {
  local t0=$(date +%s)
  (cd cases/app && fvm dart analyze --format=machine . 2>&1 | paths | cut -d'|' -f1,3,8; echo "exit: ${PIPESTATUS[0]}")
  echo "seconds: $(( $(date +%s) - t0 ))"
}
cp $R $R.orig; cp $M $M.orig
trap 'mv $R.orig $R; mv $M.orig $M' EXIT

step "setup: resolve, SDK"
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version
# Remove earlier synthetic packages for this plugin path so R1 is cold.
for f in $(grep -l "packages/pr_lint\$" "$HOME"/.dartServer/.plugin_manager/*/pubspec.yaml 2>/dev/null); do rm -rf "$(dirname "$f")"; done
echo "synthetic packages for this path before R1: $(synthetic)"

step "R1 cold: the plugin built for the first time at this path"
analyze
echo "synthetic packages for this path after R1: $(synthetic)"

step "R2 warm: unchanged"
analyze

step "R3 lib/src edit: message v1 becomes v2"
perl -pi -e 's/message v1/message v2/' $R
analyze

step "R4 lib/src edit: the rule also reports alsoMe"
perl -pi -e "s/<String>\\{'flagMe'\\}/<String>{'flagMe', 'alsoMe'}/" $R
analyze

step "R5 lib/main.dart edit: a second rule registered"
perl -pi -e 's|// MAIN-EDIT|registry.registerWarningRule(FlagRule(otherCode));|' $M
analyze
echo "synthetic packages for this path after R5: $(synthetic)"

step "R6 lib/src no longer compiles"
cp $R $R.good
echo 'final int broken = ;' >> $R
analyze

step "R7 restored to R5's source"
mv $R.good $R
analyze
