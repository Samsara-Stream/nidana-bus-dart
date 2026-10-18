#!/usr/bin/env bash
# plugin-compile-exit: settles the exit code of `fvm dart analyze` when a
# root-enabled analysis server plugin does not compile (step S38, for
# ADR-002 Context Q11c). workspace-layout Q11c recorded exit 3 for the root
# analyze with the plugin's own source broken, filtering that source's
# diagnostics out of its output; plugin-rebuild R6 recorded exit 4 for an
# analysis of a directory outside the plugin. This probe runs both shapes on
# one workspace and separates the plugin failure from the analyzed files'
# own diagnostics.
#
# A pub workspace in a temporary directory: pce_lint, the plugin (analyzer
# 13.3.0 and analysis_server_plugin 0.3.18 pinned, one WARNING rule on a
# top-level variable named flagMe), enabled in the root analysis_options.yaml
# by relative path, and pce_app, a pure member.
#   E0 plugin builds, app clean: root analyze
#   E1 plugin source broken: root analyze, which also analyzes the plugin's source
#   E2 plugin source broken: analyze packages/pce_app only, app clean
#   E3 plugin source broken: analyze packages/pce_app only, app holds a WARNING
#   E4 plugin source broken: analyze packages/pce_app only, app holds an ERROR
#   E5 plugin source broken: packages/pce_app only, app holds an INFO (a lint)
#   E6 as E5, under --fatal-infos
#   E7 plugin restored, app holds an ERROR: analyze packages/pce_app
# The root options also enable the lint camel_case_types, which only E5 and
# E6's app code breaks.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=$(cd ../../../.. && pwd)
SRC=$(cd ../plugin-rebuild/packages/pr_lint && pwd)
TMP=$(mktemp -d)
W=$TMP/w
step() { echo; echo "### $*"; }
paths() { sed -e "s|/private$TMP|{tmp}|g" -e "s|$TMP|{tmp}|g" -e "s|$HOME|{home}|g"; }
analyze() { # $@ target relative to the workspace root, and flags
  (cd "$W" && fvm dart analyze --format=machine "$@" > "$TMP/out" 2>&1; code=$?
   grep -E '^(INFO|WARNING|ERROR)\|' "$TMP/out" | cut -d'|' -f1,3,4 | paths
   grep -m1 'An error occurred while executing an analyzer plugin' "$TMP/out" | cut -c1-120 | paths
   echo "exit: $code")
}
mkdir -p "$W/packages/pce_lint/lib/src" "$W/packages/pce_app/lib"
cp "$REPO/.fvmrc" "$W/"
printf 'name: pce_root\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - packages/pce_app\n  - packages/pce_lint\n' > "$W/pubspec.yaml"
printf 'plugins:\n  pce_lint:\n    path: packages/pce_lint\nlinter:\n  rules:\n    - camel_case_types\n' > "$W/analysis_options.yaml"
sed -e 's/^name: pr_lint/name: pce_lint/' -e 's/^description: .*/description: Probe plugin (experiment only)./' "$SRC/pubspec.yaml" > "$W/packages/pce_lint/pubspec.yaml"
sed -e 's/pr_lint/pce_lint/' -e '/MAIN-EDIT/d' "$SRC/lib/main.dart" > "$W/packages/pce_lint/lib/main.dart"
cp "$SRC/lib/src/rule.dart" "$W/packages/pce_lint/lib/src/rule.dart"
printf 'name: pce_app\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\n' > "$W/packages/pce_app/pubspec.yaml"
APP=$W/packages/pce_app/lib/app.dart
RULE=$W/packages/pce_lint/lib/src/rule.dart
echo 'int one() => 1;' > "$APP"

step "setup"
(cd "$W" && fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?")
fvm dart --version

step "E0 plugin builds, app clean: root analyze"
analyze
step "E1 plugin source broken: root analyze"
cp "$RULE" "$RULE.good"; echo 'final int broken = ;' >> "$RULE"
analyze
step "E2 plugin source broken: packages/pce_app only, app clean"
analyze packages/pce_app
step "E3 plugin source broken: packages/pce_app only, app holds a WARNING"
printf 'int one() => 1;\nvoid f(int? x) { x!; x!; }\nint g(int x) => x ?? 0;\n' > "$APP"
analyze packages/pce_app
step "E4 plugin source broken: packages/pce_app only, app holds an ERROR"
printf "int one() => 1;\nint two = 'two';\n" > "$APP"
analyze packages/pce_app
step "E5 plugin source broken: packages/pce_app only, app holds an INFO"
printf 'int one() => 1;\nclass not_camel {}\n' > "$APP"
analyze packages/pce_app
step "E6 as E5, under --fatal-infos"
analyze --fatal-infos packages/pce_app
step "E7 plugin restored, app holds an ERROR: packages/pce_app"
mv "$RULE.good" "$RULE"
printf "int one() => 1;\nint two = 'two';\n" > "$APP"
analyze packages/pce_app

# Remove the analysis server's synthetic packages for this temporary plugin path.
for f in $(grep -l "$TMP" "$HOME"/.dartServer/.plugin_manager/*/pubspec.yaml 2>/dev/null); do rm -rf "$(dirname "$f")"; done
rm -rf "$TMP"
