#!/usr/bin/env bash
# file-cli-sets-plan, samples: the plan's own seeded samples (samples/, the
# strings its Tasks 6 and 7 seed: the stand-in generator package `gen` and the
# `gen` contract with its file replay and four recorded invocations) in a
# temporary workspace seeded as the plan's seedWorkspace(..., generator: true)
# seeds it.
#   Q1 the workspace resolves offline (samples/ holds a copy of the
#      repository's hsdd/contract/fixture/analysis_options.yaml, as seedWorkspace writes it)
#   Q2 the structure set of the tool as it stands passes the `gen` slug
#   Q3 the file replay by hand: dart run from the root, dart format, diff -r
#   Q4 each recorded invocation through probe/replay_case.dart, the plan's
#      cli set in prototype
#   Q5 the same on a stale workspace (gen's pubspec.yaml touched after the
#      resolution): the cases still pass; dart run from files/ would not
#   Q6 seeded defects: one changed byte, an extra and a missing file in the
#      file replay; a wrong exit code; output left at {output}
# Run from anywhere: ./samples.sh > samples-output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}; T=${T%/}
TREAL=$(cd "$T" && pwd -P)
DART=$(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-cli-sets-plan/probe/paths.dart exe)
step() { echo; echo "### $*"; }
red() { sed -e "s#$TREAL#{T-real}#g" -e "s#$T#{T}#g" -e "s#$HOME#~#g"; }
W=$(mktemp -d "$T/ncc_.XXXXXX")
F=hsdd/contract/fixture/gen
cp -R samples/hsdd samples/packages "$W/"
printf 'name: stand_in_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n  - packages/gen\n' > "$W/pubspec.yaml"
printf 'name: gen\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nresolution: workspace\n' > "$W/packages/gen/pubspec.yaml"
cases() { for c in analyze-lib generate-from-files generate-tree generate-usage; do (cd "$W" && "$DART" "$HERE/probe/replay_case.dart" "$W" gen "$c"); done; }
file_replay() {
  local out; out=$(mktemp -d "$T/ncc_file_.XXXXXX")
  (cd "$W" && "$DART" run gen:generate "$W/$F/input/word.txt" "$out" > /dev/null 2>&1; echo "generator exit: $?")
  "$DART" format "$out" > /dev/null 2>&1; echo "format exit: $?"
  if diff -r "$out" "$W/$F/expected" > "$W/diff.txt"; then echo "file replay: PASS"; else echo "file replay: FAIL"; red < "$W/diff.txt" | sed 's/^/  | /'; fi
  rm -rf "$out"
}

step "Q1 the workspace resolves offline"
(cd "$W" && "$DART" pub get --offline | tail -1; echo "exit: ${PIPESTATUS[0]}")

step "Q2 the structure set of the tool as it stands over the gen slug"
(cd "$W" && "$DART" "$REPO/packages/nidana_contract_check/bin/nidana_contract_check.dart" gen --set structure; echo "exit: $?")

step "Q3 the file replay by hand"
file_replay

step "Q4 each recorded invocation, the plan's cli set in prototype"
cases

step "Q5 a stale workspace: gen's pubspec.yaml touched after the resolution"
sleep 2; touch "$W/packages/gen/pubspec.yaml"
cases
file_replay
(cd "$W/$F/invocation/generate-from-files/files" && "$DART" run gen:generate word.txt "$W/x" > /dev/null 2>&1; echo "dart run gen:generate from generate-from-files/files/: exit $?")

step "Q6 seeded defects"
cp "$W/$F/expected/notes.txt" "$W/notes.orig"
printf 'from Hello\n' > "$W/$F/expected/notes.txt"; echo "-- one changed byte in expected/notes.txt"; file_replay
cp "$W/notes.orig" "$W/$F/expected/notes.txt"
printf 'more\n' > "$W/$F/expected/more.txt"; echo "-- expected/ holds a file the generator does not write"; file_replay
rm "$W/$F/expected/more.txt"
mv "$W/$F/expected/notes.txt" "$W/notes.moved"; echo "-- expected/ lacks a file the generator writes"; file_replay
mv "$W/notes.moved" "$W/$F/expected/notes.txt"
printf '0\n' > "$W/$F/invocation/generate-usage/exit_code"; echo "-- generate-usage records exit 0"
(cd "$W" && "$DART" "$HERE/probe/replay_case.dart" "$W" gen generate-usage)
printf '2\n' > "$W/$F/invocation/generate-usage/exit_code"
mkdir -p "$W/$F/invocation/generate-leaves-output"
printf 'gen:generate\n--write-then-fail\nhsdd/contract/fixture/gen/input/word.txt\n{output}\n' > "$W/$F/invocation/generate-leaves-output/args"
printf '1\n' > "$W/$F/invocation/generate-leaves-output/exit_code"
echo "-- generate-leaves-output: exit 1 recorded, no expected/"
(cd "$W" && "$DART" "$HERE/probe/replay_case.dart" "$W" gen generate-leaves-output)
rm -rf "$W"
