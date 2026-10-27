#!/usr/bin/env bash
# file-cli-sets-plan, staleness part 2: what makes a workspace whose mtimes
# read stale run `dart run {package}:{executable}` from files/ again, and the
# repository's own state (read only: the one command run in it is the replay
# tool from a fixture directory, which exits 64 on the unknown slug when it
# starts at all).
#   M1 stale (member pubspec.yaml newer than pubspec.lock): package_config.json
#      deleted, then dart pub get --enforce-lockfile
#   M2 stale again: pubspec.lock deleted and restored by dart pub get --offline,
#      then dart pub get --enforce-lockfile
#   M3 stale again: pubspec.lock touched, then package_config.json touched
#   M4 stale by package_config.json alone (older than pubspec.lock): what
#      dart run from the root does, and from files/ after it
#   M5 the repository: mtimes, oldest first, and `dart run nidana_contract_check`
#      from a recorded invocation's files/ (does it start)
# Run from anywhere: ./staleness2.sh > staleness2-output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}; T=${T%/}
TREAL=$(cd "$T" && pwd -P)
DART=$(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-cli-sets-plan/probe/paths.dart exe)
step() { echo; echo "### $*"; }
red() { sed -e "s#$TREAL#{T-real}#g" -e "s#$T#{T}#g" -e "s#$HOME#~#g" -e "s#$REPO#{repo}#g"; }
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
fromfiles() { (cd "$W/$C" && "$DART" run gen:generate in.txt "$W/out" > "$W/o" 2> "$W/e"; echo "dart run from files/: exit $?"); red < "$W/e" | head -1 | sed 's/^/  | /'; rm -rf "$W/out"; }
pg() { (cd "$W" && "$DART" pub get "$@" > "$W/o" 2> "$W/e"; echo "dart pub get $*: exit $?"); tail -1 "$W/o" | sed 's/^/  | /'; red < "$W/e" | head -2 | sed 's/^/  | /'; }
stale() { sleep 2; touch "$W/packages/gen/pubspec.yaml"; }

(cd "$W" && "$DART" pub get --offline > /dev/null 2>&1)

step "M1 stale, then package_config.json deleted, then dart pub get --enforce-lockfile"
stale; mt; fromfiles
rm "$W/.dart_tool/package_config.json"; sleep 2; pg --enforce-lockfile; mt; fromfiles

step "M2 stale, then pubspec.lock deleted and restored by dart pub get --offline, then --enforce-lockfile"
stale; mt; fromfiles
cp "$W/pubspec.lock" "$W/lock.orig"; rm "$W/pubspec.lock"; sleep 2; pg --offline; mt
cmp -s "$W/pubspec.lock" "$W/lock.orig" && echo "pubspec.lock: the same bytes"
sleep 2; pg --enforce-lockfile; mt; fromfiles

step "M3 stale, then pubspec.lock touched, then package_config.json touched"
stale; sleep 2; touch "$W/pubspec.lock"; sleep 2; touch "$W/.dart_tool/package_config.json"; mt; fromfiles

step "M4 package_config.json older than pubspec.lock alone: dart run from the root, then from files/"
sleep 2; touch "$W/pubspec.lock"; mt; fromfiles
(cd "$W" && "$DART" run gen:generate "$C/in.txt" "$W/out" > "$W/o" 2> "$W/e"; echo "dart run from the root: exit $?"); sed 's/^/  | /' "$W/o" | red | head -3; rm -rf "$W/out"; mt; fromfiles
rm -rf "$W"

step "M5 the repository, read only"
(cd "$REPO" && for f in pubspec.yaml packages/*/pubspec.yaml pubspec.lock .dart_tool/package_config.json; do
  printf '%s %s\n' "$(stat -f %m "$f")" "$f"; done | sort -n | awk '{print $2}' | tr '\n' ' '); echo "(oldest first)"
(cd "$REPO" && git log -1 --format='last commit touching pubspec.lock: %h %ci' -- pubspec.lock)
FILES="$REPO/hsdd/contract/fixture/nidana-checks/invocation/scan-clean/files"
(cd "$FILES" && "$DART" run nidana_contract_check nosuch > "$T"/m5.o 2> "$T"/m5.e; echo "dart run nidana_contract_check nosuch from scan-clean/files/: exit $?"); red < "$T"/m5.e | head -2 | sed 's/^/  | /'; rm -f "$T"/m5.o "$T"/m5.e
