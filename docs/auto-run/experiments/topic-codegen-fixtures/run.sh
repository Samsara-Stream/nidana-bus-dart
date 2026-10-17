#!/usr/bin/env bash
# topic-codegen-fixtures: replays the topic-codegen@v1 fixtures and schema,
# as written under the repository's hsdd/contract/, against a stand-in
# nidana_dart_codegen (packages/nidana_dart_codegen: the pure generator, the
# `generate` command and the build_runner builder) built on the stand-in
# nidana_dart_contracts of ../flutter-binding-fixtures/ (topic-model@v1 with
# MultiWriterTopic, and topology-ir@v1's decoder and renderers).
#
# packages/example_app is a stand-in app: its types are the ones the fixture's
# topics.yaml imports, so the generated library can be compiled and analyzed,
# and it applies the builder through build_runner. tool/ holds the schema-set
# prototype (package:json_schema 5.2.2) and the generator of invalid/;
# render-check/ cross-checks with Ajv, jsdom and Mermaid's parser from
# project-local npm packages. probe/ holds the runtime facts the contract
# cites (yaml_facts.out.txt, doc/output.txt, names/output.txt).
#
# The repository has no pub workspace yet, so the fixtures and the schema are
# copied into this experiment's own workspace at the same relative paths, and
# every command runs from this directory as the replay would from the
# workspace root. Third-party versions are pinned to ADR-002's resolution.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
ROOT=$(pwd)
REPO=../../../..
F=hsdd/contract/fixture/topic-codegen
IN=$F/input
EXP=$F/expected
SCHEMA=hsdd/contract/schema/topic-codegen.schema.json
TMP=$(mktemp -d)
GEN="fvm dart run nidana_dart_codegen:generate"
step() { echo; echo "### $*"; }
paths() { sed -e "s|$TMP|{tmp}|g" -e "s|$ROOT|{root}|g"; }

step "setup: copy the fixtures and schema from the repository, resolve"
rm -rf hsdd out && mkdir -p hsdd/contract/fixture hsdd/contract/schema
cp -R $REPO/$F hsdd/contract/fixture/
cp $REPO/$SCHEMA hsdd/contract/schema/
mkdir -p hsdd/contract/fixture/topology-ir && cp -R $REPO/hsdd/contract/fixture/topology-ir/render $REPO/hsdd/contract/fixture/topology-ir/invalid hsdd/contract/fixture/topology-ir/
find hsdd/contract/fixture/topic-codegen -type f | sed 's|/[^/]*$||' | sort | uniq -c
fvm dart pub get --offline > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  [a-z_]+:$/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock | grep -E ' (analyzer|build|build_runner|dart_style|yaml|json_schema|lints):'
(cd render-check && npm ci --no-audit --no-fund > /dev/null 2>&1; echo "npm ci exit: $?")
node -e "for (const p of ['ajv','jsdom','mermaid']) console.log('npm', p, require('./render-check/node_modules/'+p+'/package.json').version)"

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages/nidana_dart_codegen packages/nidana_dart_contracts; echo "exit: $?"

step "T1 file replay (ADR-001 item 6): the Validation command from the workspace root into an empty directory, fvm dart format on the Dart, then a byte comparison with expected/"
OUT=$TMP/replay && mkdir -p "$OUT"
$GEN --graph $IN/topology-graph.json $IN/topics.yaml "$OUT"; echo "generate exit: $?"
fvm dart format "$OUT" | paths
diff -r "$OUT" $EXP && echo "IDENTICAL: $(ls "$OUT" | tr '\n' ' ')"

step "T2 the generator's own output is already formatted: no fvm dart format, same bytes"
OUT=$TMP/raw && $GEN --graph $IN/topology-graph.json $IN/topics.yaml "$OUT" && diff -r "$OUT" $EXP && echo "IDENTICAL without formatting"

step "T3 byte stability: absolute paths, another output directory"
$GEN --graph "$ROOT/$IN/topology-graph.json" "$ROOT/$IN/topics.yaml" "$TMP/elsewhere/deeper" && diff -r "$TMP/elsewhere/deeper" $EXP && echo "IDENTICAL from absolute paths"
grep -c -e "$TMP" -e "$ROOT" $EXP/* | sed 's|^|occurrences of a path: |'

step "T4 expected/topics.g.dart compiles against the stand-in nidana_dart_contracts and analyzes clean in the stand-in app (root lint set, strict modes, --fatal-infos)"
cp $EXP/topics.g.dart packages/example_app/lib/topics.g.dart
fvm dart analyze --fatal-infos packages/example_app; echo "exit: $?"

step "T5 build_runner (ADR-002 item 8): the builder nidana_dart_codegen:topics, applied by auto_apply dependents, maps lib/topics.yaml to lib/topics.g.dart with the command's bytes"
A=packages/example_app
rm -f $A/lib/topics.g.dart && cp $IN/topics.yaml $A/lib/topics.yaml
mkdir -p $A/lib/extra && cp $F/valid/minimal.json $A/lib/extra/topics.yaml
(cd $A && fvm dart run build_runner build 2>&1 | grep -E 'nidana_dart_codegen|wrote|Failed|SEVERE|error' ; echo "build_runner exit: ${PIPESTATUS[0]}")
find $A/lib -name 'topics.g.dart' | sort
cmp $A/lib/topics.g.dart $EXP/topics.g.dart && echo "builder output and command output are IDENTICAL"
echo "-- an invalid lib/topics.yaml fails the build"
cp $F/rejected/member-collision.yaml $A/lib/topics.yaml
(cd $A && fvm dart run build_runner build 2>&1 | grep -E 'SEVERE|topics.yaml:|Failed|wrote' | paths; echo "build_runner exit: ${PIPESTATUS[0]}")
ls $A/lib/topics.g.dart 2>&1 | paths
cp $IN/topics.yaml $A/lib/topics.yaml && rm -rf $A/lib/extra
(cd $A && fvm dart run build_runner build > /dev/null 2>&1; echo "restored, build_runner exit: $?")
cmp $A/lib/topics.g.dart $EXP/topics.g.dart && echo "restored output IDENTICAL"

step "T6 schema set (ADR-001 item 5) on package:json_schema 5.2.2: valid/ validates, invalid/ does not; input/topics.yaml and the parsable rejected/ documents validate"
fvm dart run tool/schema_check.dart $F $SCHEMA; echo "exit: $?"

step "T7 Ajv on the same cases; the HTML golden's diagram is topology-ir@v1's render/checkout.mmd, and Mermaid parses it"
node render-check/check.mjs $F $SCHEMA hsdd/contract/fixture/topology-ir/render; echo "exit: $?"

step "T8 the generator accepts every valid/ document (exit 0) and rejects every invalid/ document (exit 1, nothing written)"
for f in $F/valid/*.json; do o=$TMP/v/$(basename $f .json); $GEN $f $o > /dev/null 2>&1; echo "exit $? $(basename $f) wrote: $(ls $o 2>/dev/null | tr '\n' ' ')"; done
bad=0; for f in $F/invalid/*.json; do o=$TMP/i/$(basename $f .json); $GEN $f $o > /dev/null 2> $TMP/err.txt; c=$?; if [ $c -ne 1 ] || [ -e $o ]; then bad=$((bad+1)); echo "UNEXPECTED $(basename $f): exit $c, output $(ls $o 2>/dev/null)"; fi; done
echo "invalid/: $(ls $F/invalid | wc -l | tr -d ' ') documents, $bad not rejected with exit 1 and no output"

step "T9 the generator rejects every rejected/ document (exit 1, nothing written), with file:line:column diagnostics"
for f in $F/rejected/*.yaml; do o=$TMP/r/$(basename $f .yaml); $GEN $f $o 2>&1 >/dev/null | paths | sed "s|^|  |"; echo "exit ${PIPESTATUS[0]} $(basename $f) output: $(ls $o 2>/dev/null || echo none)"; done

step "T10 without a graph: same topics.g.dart, topics.md without readers and writers, no topology-graph.html"
OUT=$TMP/nograph && $GEN $IN/topics.yaml "$OUT"; echo "exit: $?; wrote: $(ls "$OUT" | tr '\n' ' ')"
cmp "$OUT/topics.g.dart" $EXP/topics.g.dart && echo "topics.g.dart IDENTICAL"
sed -n '1,6p' "$OUT/topics.md"
echo "rows 'Written by' or 'Read by': $(grep -c -E '^\| (Written|Read) by' "$OUT/topics.md"); graph sections: $(grep -c -E '^## (Topologies|Shell claims|Topics outside)' "$OUT/topics.md")"
diff <(grep -v -E '^\| (Written|Read) by' $EXP/topics.md | sed '/^## Topologies$/,$d' | sed '1,6d') <(sed '1,6d' "$OUT/topics.md") > /dev/null && echo "otherwise equal to expected/topics.md after its graph rows, sections and header lines are removed"

step "T11 exit codes: usage errors exit 2, an undecodable graph exits 1; nothing is written either way"
try() { label=$1; shift; $GEN "$@" > $TMP/try.txt 2>&1; c=$?; head -1 $TMP/try.txt | paths; echo "$label: exit $c"; }
try "no arguments"
try "one argument" $IN/topics.yaml
try "unknown option" --frobnicate $IN/topics.yaml $TMP/u1
try "missing topics.yaml" $IN/missing.yaml $TMP/u2
try "missing graph" --graph $IN/missing.json $IN/topics.yaml $TMP/u3
touch $TMP/afile; try "output is a file" $IN/topics.yaml $TMP/afile
try "undecodable graph (topology-ir invalid/format_v2.json)" --graph hsdd/contract/fixture/topology-ir/invalid/format_v2.json $IN/topics.yaml $TMP/u4
ls -d $TMP/u1 $TMP/u2 $TMP/u3 $TMP/u4 2>&1 | paths

step "T12 Spec §4.5's example (valid/spec-section-4-5.json) generates; its initial values are copied as Dart expressions"
$GEN $F/valid/spec-section-4-5.json $TMP/spec && sed -n '/abstract final class AuthTopics/,$p' $TMP/spec/topics.g.dart

step "T13 (P5) a library that imports Flutter loads under the Flutter tester and not under dart run (probe/flutter-vm, its own package)"
(cd probe/flutter-vm && fvm flutter pub get --offline > /dev/null 2>&1; echo "pub get exit: $?"
 fvm dart run bin/catalog.dart > $TMP/p5.txt 2>&1; c=$?; grep -E "dart:ui' is not available|^loaded" $TMP/p5.txt | head -1 | sed 's|.*/packages/flutter/|{flutter}/packages/flutter/|'; echo "fvm dart run bin/catalog.dart: exit $c"
 fvm flutter test --no-pub > $TMP/p5t.txt 2>&1; c=$?; tail -1 $TMP/p5t.txt; echo "fvm flutter test: exit $c")

rm -rf "$TMP"
# The copies and the stand-in app's inputs are run artifacts; the next run rewrites them.
rm -rf hsdd packages/example_app/lib/topics.yaml packages/example_app/lib/topics.g.dart
