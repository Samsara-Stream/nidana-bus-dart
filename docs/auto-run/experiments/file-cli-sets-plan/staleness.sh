#!/usr/bin/env bash
# file-cli-sets-plan, staleness: when does `dart run {package}:{executable}`
# from a directory below the workspace root with no pubspec.yaml (a recorded
# invocation's files/) fail with exit 255, and which pub command makes it run
# again? Prints the mtimes of the root pubspec.yaml, the member's
# pubspec.yaml, pubspec.lock and .dart_tool/package_config.json (seconds since
# the workspace was made) after each step.
#   K1 a fresh offline resolution
#   K2 a member pubspec.yaml touched after it
#   K3 then dart pub get --enforce-lockfile
#   K4 then dart pub get (offline)
#   K5 the root pubspec.yaml touched, then dart run from the root, then from files/
#   K6 a member pubspec.yaml touched, then dart pub get --enforce-lockfile run twice
#   K7 a member pubspec.yaml touched, then the lockfile touched
#   K8 package_config.json older than pubspec.lock
#   (the repository's own state is staleness2.sh's M5)
# Run from anywhere: ./staleness.sh > staleness-output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}; T=${T%/}
TREAL=$(cd "$T" && pwd -P)
DART=$(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-cli-sets-plan/probe/paths.dart exe)
step() { echo; echo "### $*"; }
red() { sed -e "s#$TREAL#{T-real}#g" -e "s#$T#{T}#g" -e "s#$HOME#~#g"; }
W=$(mktemp -d "$T/fcs.XXXXXX")
C=hsdd/contract/fixture/sample/invocation/case/files
mkdir -p "$W/packages/gen/bin" "$W/$C"
printf 'name: stand_in_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - packages/gen\n' > "$W/pubspec.yaml"
printf 'name: gen\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\n' > "$W/packages/gen/pubspec.yaml"
cp probe/generate.dart "$W/packages/gen/bin/generate.dart"
printf 'hello\n' > "$W/$C/in.txt"
BASE=$(stat -f %m "$W/pubspec.yaml")
mt() {
  for f in pubspec.yaml packages/gen/pubspec.yaml pubspec.lock .dart_tool/package_config.json; do
    if [ -e "$W/$f" ]; then printf '%s=+%s ' "$f" $(( $(stat -f %m "$W/$f") - BASE )); else printf '%s=absent ' "$f"; fi
  done; echo
}
fromfiles() { (cd "$W/$C" && "$DART" run gen:generate in.txt "$W/out-$1" > "$W/o" 2> "$W/e"; echo "dart run from files/: exit $?"); red < "$W/e" | head -2 | sed 's/^/  | /'; rm -rf "$W/out-$1"; }
fromroot() { (cd "$W" && "$DART" run gen:generate "$C/in.txt" "$W/out-$1" > "$W/o" 2> "$W/e"; echo "dart run from the root: exit $?"); red < "$W/e" | head -2 | sed 's/^/  | /'; red < "$W/o" | head -3 | sed 's/^/  | /'; rm -rf "$W/out-$1"; }
pg() { (cd "$W" && "$DART" pub get "$@" > "$W/o" 2> "$W/e"; echo "dart pub get $*: exit $?"); tail -1 "$W/o" | sed 's/^/  | /'; red < "$W/e" | head -2 | sed 's/^/  | /'; }

step "K1 a fresh offline resolution"
sleep 2; pg --offline; mt; fromfiles k1

step "K2 a member pubspec.yaml touched after it"
sleep 2; touch "$W/packages/gen/pubspec.yaml"; mt; fromfiles k2

step "K3 then dart pub get --enforce-lockfile"
sleep 2; pg --enforce-lockfile; mt; fromfiles k3

step "K4 then dart pub get --offline"
sleep 2; pg --offline; mt; fromfiles k4

step "K5 the root pubspec.yaml touched; dart run from the root, then from files/"
sleep 2; touch "$W/pubspec.yaml"; mt; fromroot k5; mt; fromfiles k5b

step "K6 a member pubspec.yaml touched, then dart pub get --enforce-lockfile twice"
sleep 2; touch "$W/packages/gen/pubspec.yaml"; mt
sleep 2; pg --enforce-lockfile; mt
sleep 2; pg --enforce-lockfile; mt; fromfiles k6

step "K7 a member pubspec.yaml touched, then pubspec.lock touched"
sleep 2; touch "$W/packages/gen/pubspec.yaml"; sleep 2; touch "$W/pubspec.lock"; mt; fromfiles k7

step "K8 then package_config.json made older than pubspec.lock"
touch -t 200001010000 "$W/.dart_tool/package_config.json"; mt; fromfiles k8
sleep 2; pg --enforce-lockfile; mt; fromfiles k8b

rm -rf "$W"
