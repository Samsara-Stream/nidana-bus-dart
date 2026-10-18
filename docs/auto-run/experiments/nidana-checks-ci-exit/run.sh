#!/usr/bin/env bash
# nidana-checks-ci-exit: what an app's CI sees from `fvm dart analyze` when
# the analysis server plugin its options enable does not load (step S45, for
# nidana-checks@v1 The plugin, Running it). plugin-compile-exit/ ran the
# shapes inside one pub workspace; this probe runs the app's shape: a
# standalone package in a temporary directory, outside any workspace, whose
# own analysis_options.yaml enables the plugin by absolute path, analyzed at
# its root with `dart analyze .`, the way nidana-checks@v1 In CI has an app
# run it. The plugin's source is outside the analyzed root, so its compile
# error is never one of the analyzed files' diagnostics.
#
# The plugin is plugin-rebuild/'s pr_lint (analyzer 13.3.0 and
# analysis_server_plugin 0.3.18 pinned, one WARNING rule flag_rule on a
# top-level variable named flagMe), copied out of any workspace. The app's
# options also enable the lint camel_case_types, so an INFO is available.
#   A0 plugin builds, app holds flagMe                      (the rule runs)
#   A1 plugin builds, app clean, --fatal-infos
#   then the plugin's source is broken:
#   A2 app clean
#   A3 app clean, --fatal-infos
#   A4 app holds an INFO only
#   A5 app holds an INFO only, --fatal-infos
#   A6 app holds an analyzer WARNING
#   A7 app holds an ERROR
#   A8 app holds flagMe only, --fatal-infos                 (the violation is missed)
#   A9 as A3 in the default (human) output format
#   then the plugin's source is restored and its pubspec gains a hosted
#   dependency that pub.dev does not have, so the plugin does not resolve:
#   A10 app clean, --fatal-infos
#   A11 app holds an INFO only
#   A12 app holds an analyzer WARNING
#   A13 plugin restored, app holds flagMe                   (the rule runs again)
# Each case records the analyzer's diagnostic lines, the stream that carries
# the plugin failure line, and the exit code.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=$(cd ../../../.. && pwd)
SRC=$(cd ../plugin-rebuild/packages/pr_lint && pwd)
TMP=$(mktemp -d)
P=$TMP/plugin/ce_lint
A=$TMP/app
step() { echo; echo "### $*"; }
paths() { sed -e "s|/private$TMP|{tmp}|g" -e "s|$TMP|{tmp}|g" -e "s|$HOME|{home}|g"; }
analyze() { # flags for dart analyze; the target is always .
  (cd "$A" && fvm dart analyze "$@" . > "$TMP/out" 2> "$TMP/err"; code=$?
   grep -E '^(INFO|WARNING|ERROR)\|' "$TMP/out" | cut -d'|' -f1,3 | paths
   grep -E '^ *(info|warning|error) - ' "$TMP/out" | sed -e 's/ - .* - / - /' | paths
   so=$(grep -c 'An error occurred while executing an analyzer plugin' "$TMP/out")
   se=$(grep -c 'An error occurred while executing an analyzer plugin' "$TMP/err")
   echo "plugin failure line: stdout $so, stderr $se"
   grep -m1 -A1 'An error occurred while executing an analyzer plugin' "$TMP/err" | tail -n +2 | cut -c1-100 | paths | sed 's/^/  stderr next line: /'
   echo "exit: $code")
}
mkdir -p "$P/lib/src" "$A/lib"
cp "$REPO/.fvmrc" "$TMP/"
sed -e 's/^name: pr_lint/name: ce_lint/' -e 's/^description: .*/description: Probe plugin (experiment only)./' -e '/^resolution: workspace/d' "$SRC/pubspec.yaml" > "$P/pubspec.yaml"
sed -e 's/pr_lint/ce_lint/' -e '/MAIN-EDIT/d' "$SRC/lib/main.dart" > "$P/lib/main.dart"
cp "$SRC/lib/src/rule.dart" "$P/lib/src/rule.dart"
printf 'name: ce_app\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\n' > "$A/pubspec.yaml"
printf 'plugins:\n  ce_lint:\n    path: %s\nlinter:\n  rules:\n    - camel_case_types\n' "$P" > "$A/analysis_options.yaml"
APP=$A/lib/app.dart
RULE=$P/lib/src/rule.dart

step "setup"
(cd "$A" && fvm dart pub get --offline > /dev/null 2>&1; echo "app pub get exit: $?")
fvm dart --version

step "A0 plugin builds, app holds flagMe"
printf 'int one() => 1;\nfinal int flagMe = 1;\n' > "$APP"
analyze --format=machine
step "A1 plugin builds, app clean, --fatal-infos"
echo 'int one() => 1;' > "$APP"
analyze --fatal-infos --format=machine

cp "$RULE" "$RULE.good"; echo 'final int broken = ;' >> "$RULE"
step "A2 plugin source broken, app clean"
analyze --format=machine
step "A3 plugin source broken, app clean, --fatal-infos"
analyze --fatal-infos --format=machine
step "A4 plugin source broken, app holds an INFO only"
printf 'int one() => 1;\nclass not_camel {}\n' > "$APP"
analyze --format=machine
step "A5 plugin source broken, app holds an INFO only, --fatal-infos"
analyze --fatal-infos --format=machine
step "A6 plugin source broken, app holds an analyzer WARNING"
printf 'int one() => 1;\nvoid f(int? x) { x!; x!; }\n' > "$APP"
analyze --format=machine
step "A7 plugin source broken, app holds an ERROR"
printf "int one() => 1;\nint two = 'two';\n" > "$APP"
analyze --format=machine
step "A8 plugin source broken, app holds flagMe only, --fatal-infos"
printf 'int one() => 1;\nfinal int flagMe = 1;\n' > "$APP"
analyze --fatal-infos --format=machine
step "A9 as A3, default output format"
echo 'int one() => 1;' > "$APP"
analyze --fatal-infos

cp "$RULE.good" "$RULE"
cp "$P/pubspec.yaml" "$P/pubspec.yaml.good"
printf '  nidana_ce_absent_package_s45: ^1.0.0\n' >> "$P/pubspec.yaml"
step "A10 plugin does not resolve, app clean, --fatal-infos"
analyze --fatal-infos --format=machine
step "A11 plugin does not resolve, app holds an INFO only"
printf 'int one() => 1;\nclass not_camel {}\n' > "$APP"
analyze --format=machine
step "A12 plugin does not resolve, app holds an analyzer WARNING"
printf 'int one() => 1;\nvoid f(int? x) { x!; x!; }\n' > "$APP"
analyze --format=machine
step "A13 plugin restored, app holds flagMe"
cp "$P/pubspec.yaml.good" "$P/pubspec.yaml"
printf 'int one() => 1;\nfinal int flagMe = 1;\n' > "$APP"
analyze --format=machine

# Remove the analysis server's synthetic packages for this temporary plugin path.
for f in $(grep -l "$TMP" "$HOME"/.dartServer/.plugin_manager/*/pubspec.yaml 2>/dev/null); do rm -rf "$(dirname "$f")"; done
rm -rf "$TMP"
