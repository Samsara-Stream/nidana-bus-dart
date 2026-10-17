#!/usr/bin/env bash
# file-invocations: can a `file` contract carry recorded invocations (ADR-001
# item 7) whose output is a tree, so that topic-codegen@v1's G2 (rejected/
# half), G14 and G19 become executable? Step S17 asks whether to extend
# ADR-001 for that. This replays candidate invocation cases against the
# stand-in nidana_dart_codegen of ../topic-codegen-fixtures/ with replay.dart,
# the prototype of ../nidana-checks-fixtures/tool/replay.dart extended with an
# `{output}` argument and an `expected/` tree.
#
# The repository has no pub workspace yet, so the stand-in workspace of
# ../topic-codegen-fixtures/ (pubspec.yaml, analysis_options.yaml, packages/)
# is copied into work/ here, inside the repository so that fvm finds .fvmrc,
# and the fixtures are copied into work/hsdd/ at the paths they have in the
# repository. work/ is removed when the script ends.
#
# Cases: cases/ holds the hand-written ones (args, exit_code, the no-graph
# case's expected/topics.md); run.sh adds what they copy from the fixtures
# (topics.yaml, the undecodable graph, expected/topics.g.dart) and writes one
# case per rejected/ document, as a contract step would write them.
# Run from anywhere: ./run.sh > output.txt 2>&1   (./run.sh --record-no-graph
# records cases/generate-no-graph/expected/ once from the stand-in instead;
# it was recorded once and reviewed against expected/topics.md by reading)
#
# structure.sh (output in structure-output.txt) is the other half: it checks
# that the nine contracts as written meet the amended coverage and layout
# rules (items 3 and 9), with structure_check.dart, and that seeded defects
# are reported.
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=../../../..
SRC=../topic-codegen-fixtures
W=$HERE/work
F=hsdd/contract/fixture/topic-codegen
INV=$F/invocation
step() { echo; echo "### $*"; }

step "setup: copy the stand-in workspace and the fixtures, resolve"
rm -rf "$W" && mkdir -p "$W/tool" "$W/hsdd/contract/fixture/topology-ir"
cp $SRC/pubspec.yaml $SRC/analysis_options.yaml "$W/"
rsync -a --exclude .dart_tool --exclude pubspec.lock $SRC/packages "$W/"
cp replay.dart "$W/tool/replay.dart"
cp -R $REPO/$F "$W/hsdd/contract/fixture/"
cp -R $REPO/hsdd/contract/fixture/topology-ir/invalid "$W/hsdd/contract/fixture/topology-ir/"
(cd "$W" && fvm dart pub get --offline > /dev/null 2>&1; echo "pub get exit: $?")

mkdir -p "$W/$INV"
cp -R cases/. "$W/$INV/"
I="$W/$INV"
mkdir -p "$I/generate-graph-undecodable/files" "$I/generate-usage-output-is-a-file/files"
cp "$W/$F/input/topics.yaml" "$I/generate-graph-undecodable/files/topics.yaml"
cp "$W/hsdd/contract/fixture/topology-ir/invalid/format_v2.json" "$I/generate-graph-undecodable/files/topology-graph.json"
cp "$W/$F/input/topics.yaml" "$I/generate-usage-output-is-a-file/files/topics.yaml"
for f in "$W/$F"/rejected/*.yaml; do
  c="$I/generate-rejected-$(basename "$f" .yaml)"
  mkdir -p "$c/files" && cp "$f" "$c/files/topics.yaml"
  printf 'nidana_dart_codegen:generate\ntopics.yaml\n{output}\n' > "$c/args"
  printf '1\n' > "$c/exit_code"
done
if [ "$1" = "--record-no-graph" ]; then
  rm -rf "$I/generate-no-graph/expected"
  (cd "$W" && fvm dart run tool/replay.dart --record $INV generate-no-graph)
  rm -rf cases/generate-no-graph/expected && cp -R "$I/generate-no-graph/expected" cases/generate-no-graph/
  rm -f cases/generate-no-graph/expected/topics.g.dart
  rm -rf "$W"; exit 0
fi
cp "$W/$F/expected/topics.g.dart" "$I/generate-no-graph/expected/topics.g.dart"
find "$W/$INV" -mindepth 1 -maxdepth 1 -type d | sed "s|$W/||" | sort
echo "cases: $(find "$W/$INV" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"

step "E1 every candidate case passes against the stand-in generator; a case without files/ runs from the workspace root"
(cd "$W" && fvm dart run tool/replay.dart $INV; echo "replay exit: $?")

step "E2 G14's 'same bytes': the no-graph case's expected/topics.g.dart is the file replay's expected/topics.g.dart; its topics.md has no graph rows or sections"
cmp "$I/generate-no-graph/expected/topics.g.dart" "$W/$F/expected/topics.g.dart" && echo "topics.g.dart IDENTICAL to the file replay's"
echo "files in expected/: $(ls "$I/generate-no-graph/expected" | tr '\n' ' ')"
echo "rows 'Written by' or 'Read by': $(grep -c -E '^\| (Written|Read) by' "$I/generate-no-graph/expected/topics.md"); graph sections: $(grep -c -E '^## (Topologies|Shell claims|Topics outside)' "$I/generate-no-graph/expected/topics.md")"

step "E3 seeded defects fail the case they break"
D="$W/defects" && mkdir -p "$D"
cp -R "$I/generate-rejected-member-collision" "$D/accepts-a-rejected-document"
cp "$W/$F/valid/minimal.json" "$D/accepts-a-rejected-document/files/topics.yaml"
cp -R "$I/generate-no-graph" "$D/no-graph-catalog-changed"
printf '\n' >> "$D/no-graph-catalog-changed/expected/topics.md"
cp -R "$I/generate-no-graph" "$D/no-graph-writes-the-page"
printf 'nidana_dart_codegen:generate\n--graph\n%s\n%s\n{output}\n' "$F/input/topology-graph.json" "$F/input/topics.yaml" > "$D/no-graph-writes-the-page/args"
cp -R "$I/generate-usage-no-arguments" "$D/usage-exit-code-wrong"
printf '1\n' > "$D/usage-exit-code-wrong/exit_code"
(cd "$W" && fvm dart run tool/replay.dart defects 2>&1 | grep -E '^(PASS|FAIL|[0-9])' | cut -c1-240; echo "replay exit: ${PIPESTATUS[0]}")

rm -rf "$W"
