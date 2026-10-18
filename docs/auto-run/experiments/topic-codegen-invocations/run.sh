#!/usr/bin/env bash
# topic-codegen-invocations: step S21's check of the topic-codegen@v1 touch
# that adds recorded invocations of `generate` (amended ADR-001 item 7) under
# hsdd/contract/fixture/topic-codegen/invocation/. It replays, against the
# stand-in nidana_dart_codegen of ../topic-codegen-fixtures/:
#
#   E1 every recorded invocation, with ../file-invocations/replay.dart (the
#      cli-set prototype with `{output}`, `expected/` and the check that
#      nothing exists at `{output}` after a case without `expected/`);
#   E2 the existing file replay and schema cases, unchanged;
#   E3 G14's "same bytes" and the no-graph catalog, by comparison with the
#      file replay's expected/;
#   E4 the amended structure prototype (../file-invocations/structure_check.dart)
#      over the repository's nine contracts, then over a copy with two seeded
#      defects in topic-codegen@v1's new parts;
#   E5 seeded defects in the stand-in generator (seed.dart), each of which
#      must fail the cases of the guarantee it breaks and no other, then the
#      restored generator passing every case again;
#   E6 a recorded invocation that names a fixture file by its path from the
#      workspace root fails loudly when that file is missing.
#
# The repository has no pub workspace yet, so the stand-in workspace of
# ../topic-codegen-fixtures/ (pubspec.yaml, analysis_options.yaml, packages/)
# is copied into work/ here, inside the repository so that fvm finds .fvmrc,
# and the repository's fixtures and schema are copied into work/hsdd/ at the
# paths they have in the repository. Every replay runs from work/, as the
# replay tool would from the workspace root. work/ and work-structure/ are
# removed when the script ends.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
SRC=$HERE/../topic-codegen-fixtures
W=$HERE/work
F=hsdd/contract/fixture/topic-codegen
INV=$F/invocation
SCHEMA=hsdd/contract/schema/topic-codegen.schema.json
PKG=$W/packages/nidana_dart_codegen
TMP=$(mktemp -d)
step() { echo; echo "### $*"; }
replay() { (cd "$W" && rm -rf .dart_tool/pub/bin && fvm dart run tool/replay.dart "$@"); }
file_replay() {
  local out=$TMP/file-replay-$1
  rm -rf "$out"
  (cd "$W" && fvm dart run nidana_dart_codegen:generate --graph $F/input/topology-graph.json $F/input/topics.yaml "$out" > /dev/null 2>&1
   c=$?; fvm dart format "$out" > /dev/null 2>&1
   if [ $c -eq 0 ] && diff -r "$out" $F/expected > /dev/null; then echo "file replay: PASS"; else echo "file replay: FAIL (exit $c)"; fi)
}

step "setup: copy the stand-in workspace, the fixtures and the schema, resolve"
rm -rf "$W" && mkdir -p "$W/tool" "$W/hsdd/contract/fixture" "$W/hsdd/contract/schema"
cp "$SRC/pubspec.yaml" "$SRC/analysis_options.yaml" "$W/"
rsync -a --exclude .dart_tool --exclude pubspec.lock "$SRC/packages" "$W/"
cp ../file-invocations/replay.dart "$W/tool/replay.dart"
cp "$SRC/tool/schema_check.dart" "$W/tool/schema_check.dart"
cp -R "$REPO/$F" "$W/hsdd/contract/fixture/"
cp "$REPO/$SCHEMA" "$W/hsdd/contract/schema/"
(cd "$W" && fvm dart pub get --offline > /dev/null 2>&1; echo "pub get exit: $?")
# -p keeps the package's mtimes: a pubspec.yaml newer than the resolution makes
# `dart run` resolve again, which fails from a case's files/ (no pubspec.yaml).
cp -Rp "$PKG" "$TMP/pristine-codegen"
echo "fixture tree: $(ls "$W/$F" | tr '\n' ' ')"
echo "invocation cases: $(ls "$W/$INV" | wc -l | tr -d ' ')"
for c in "$W/$INV"/*/; do
  n=$(basename "$c")
  echo "  $n: exit $(cat "$c/exit_code"), files/ $( [ -d "$c/files" ] && ls "$c/files" | tr '\n' ' ' || echo none), expected/ $( [ -d "$c/expected" ] && ls "$c/expected" | tr '\n' ' ' || echo none), args: $(tail -n +2 "$c/args" | tr '\n' ' ')"
done

step "E1 every recorded invocation passes as ADR-001 item 7 replays it; a case without files/ runs from the workspace root"
replay $INV; echo "replay exit: $?"

step "E2 the existing file replay (ADR-001 item 6) and the schema cases (item 5) still pass"
file_replay baseline
(cd "$W" && fvm dart run tool/schema_check.dart $F $SCHEMA > "$TMP/schema.txt" 2>&1; echo "schema check exit: $?")
echo "PASS lines: $(grep -c '^PASS' "$TMP/schema.txt"); FAIL lines: $(grep -c '^FAIL' "$TMP/schema.txt")"
grep -E '^(FAIL|SKIP|schema check)' "$TMP/schema.txt"

step "E3 G14: generate-no-graph's expected/topics.g.dart is the file replay's; its topics.md is expected/topics.md without the graph's rows, sections and header lines"
NG=$W/$INV/generate-no-graph/expected
cmp "$NG/topics.g.dart" "$W/$F/expected/topics.g.dart" && echo "topics.g.dart IDENTICAL to the file replay's expected/topics.g.dart"
echo "rows 'Written by' or 'Read by': $(grep -c -E '^\| (Written|Read) by' "$NG/topics.md"); graph sections: $(grep -c -E '^## (Topologies|Shell claims|Topics outside)' "$NG/topics.md")"
sed -n '1,2p;6p' "$NG/topics.md"
diff <(grep -v -E '^\| (Written|Read) by' "$W/$F/expected/topics.md" | sed '/^## Topologies$/,$d' | sed '1,6d' | sed -e '${/^$/d;}') <(sed '1,6d' "$NG/topics.md") > /dev/null && echo "otherwise EQUAL to expected/topics.md"

step "E4 the amended structure prototype over the repository's nine contracts, then over a copy with two seeded defects in topic-codegen@v1's new parts"
(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart; echo "exit: $?")
echo "-- seeded: a case directory with no table row; G2 dropped from every generate-rejected-* row while G2's part line stays"
WS=$HERE/work-structure && rm -rf "$WS" && mkdir -p "$WS/hsdd"
cp -R "$REPO/hsdd/contract" "$WS/hsdd/"
mkdir -p "$WS/$INV/generate-extra" && cp "$WS/$INV/generate-usage-no-arguments/args" "$WS/$INV/generate-extra/"
sed -i '' 's/^\(| `generate-rejected-[a-z-]*` |.*| 1 | \)G2, G19/\1G19/' "$WS/hsdd/contract/topic-codegen.md"
echo "rows still naming G2: $(grep -c -E '^\| `generate-rejected-.*\| G2, G19' "$WS/hsdd/contract/topic-codegen.md")"
(cd "$WS" && fvm dart run "$HERE/../file-invocations/structure_check.dart" | grep -E 'topic-codegen|contracts,'; echo "exit: ${PIPESTATUS[0]}")
rm -rf "$WS"

step "E5 seeded defects in the stand-in generator: each fails the cases of the guarantee it breaks; the file replay alone misses every one"
for d in $(cd "$W" && fvm dart run "$HERE/seed.dart" --list | grep -E '^[a-z0-9-]+: ' | cut -d: -f1); do
  echo "-- $d"
  rm -rf "$PKG" && cp -Rp "$TMP/pristine-codegen" "$PKG"
  (cd "$W" && fvm dart run "$HERE/seed.dart" "$PKG" "$d") || { echo "SEED FAILED"; continue; }
  replay $INV | grep -E '^(FAIL|[0-9]+ of)' | cut -c1-200
  file_replay "$d"
done
rm -rf "$PKG" && cp -Rp "$TMP/pristine-codegen" "$PKG"
echo "-- restored"
replay $INV | grep -E '^(FAIL|[0-9]+ of)'
file_replay restored

step "E6 a case naming a fixture by its path from the workspace root fails loudly when the file is missing"
mv "$W/$F/rejected/two-documents.yaml" "$TMP/two-documents.yaml"
replay $INV generate-rejected-two-documents | cut -c1-200
mv "$TMP/two-documents.yaml" "$W/$F/rejected/two-documents.yaml"

rm -rf "$W" "$TMP"
