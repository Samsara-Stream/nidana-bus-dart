#!/usr/bin/env bash
# codegen-reconcile-amends: checks the fixture changes hsdd-reconcile made
# when it drained nidana.tooling.codegen's plan (S40).
#
# Part A, topic-codegen@v1, the amendment that spells out the usage errors:
#   generate-usage-graph-without-value  a trailing --graph, exit 2
#   generate-usage-graph-twice          --graph given twice, exit 2
#   generate-graph-not-json             a graph that is not JSON, exit 1
#   catalog-usage-no-package            catalog with only <output>, exit 2
#   catalog-not-a-package               a <package> without pubspec.yaml, exit 2
# against the stand-in nidana_dart_codegen of ../topic-codegen-fixtures/ (its
# generate command, unchanged) plus catalog.dart here, a stand-in of
# catalog's argument handling only.
#
# Part B, nidana-checks@v1, the amendment on code that does not resolve:
#   scan-unresolved-claim gains lib/unresolved.dart (an unresolved prefixed
#   topic creation whose name collides with a declared topic, and publisher
#   invocations on a bus type from a package the configuration lacks and on a
#   misspelt one), its stdout unchanged
# against the stand-in scan of ../nidana-checks-fixtures/.
#
# Each part replays the fixtures as amended in the working tree and as
# committed at HEAD on the same stand-in, then on seeded stand-ins that each
# read one amended rule another way: each must fail the amended case of the
# rule it breaks and pass every committed case, which is the coverage the
# change adds. Replays use the cli-set prototypes (../file-invocations/
# replay.dart for Part A, ../nidana-checks-fixtures/tool/replay.dart for B).
#
#   A1 amended topic-codegen invocations on the stand-in
#   A2 committed topic-codegen invocations on the same stand-in
#   A3 seeded stand-ins (generate and catalog)
#   B1 amended nidana-checks invocations on the stand-in
#   B2 committed nidana-checks invocations on the same stand-in
#   B3 a seeded stand-in scan that takes an unresolved `publisher` for Bus's
#   C  the structure prototype (../file-invocations/structure_check.dart)
#      over the repository's contracts as amended
#
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
TCF=$REPO/docs/auto-run/experiments/topic-codegen-fixtures
NCF=$REPO/docs/auto-run/experiments/nidana-checks-fixtures
F=hsdd/contract/fixture
TMP=$(mktemp -d)
# Copies below $TMP find the SDK pin through this copy of the repository's .fvmrc.
cp "$REPO/.fvmrc" "$TMP/"
step() { echo; echo "### $*"; }
paths() { sed -e "s|$TMP|{tmp}|g" -e "s|$REPO|{repo}|g" -e "s|$HOME|{home}|g"; }
summary() { grep -E -o '^(PASS|FAIL) [a-z0-9-]+|^[0-9]+ of [0-9]+ invocations pass'; }
# fixtures $1 (workspace) $2 (slug) $3 (worktree | HEAD): replace the copy
fixtures() {
  rm -rf "$1/$F/$2" && mkdir -p "$1/$F"
  if [ "$3" = worktree ]; then
    cp -R "$REPO/$F/$2" "$1/$F/"
  else
    (cd "$REPO" && git archive HEAD "$F/$2") | tar -x -C "$1"
  fi
}
# sub $1 file, $2 old, $3 new: a python patch replacing one occurrence
sub() { echo "import sys; p='$1'; s=open(p).read(); a='''$2'''; b='''$3'''; assert s.count(a) == 1, 'patch target missing'; open(p,'w').write(s.replace(a,b))"; }

step "setup"
fvm dart --version
git -C "$REPO" status --short -- "$F/topic-codegen" "$F/nidana-checks" | paths

# ---------- Part A ----------
TI=$F/topic-codegen/invocation
WA=$TMP/tcf
tcf_workspace() { # $1 directory
  mkdir -p "$1/tool"
  cp "$TCF/pubspec.yaml" "$TCF/analysis_options.yaml" "$1/"
  rsync -a --exclude .dart_tool --exclude pubspec.lock "$TCF/packages" "$1/"
  cp "$HERE/catalog.dart" "$1/packages/nidana_dart_codegen/bin/catalog.dart"
  cp "$REPO/docs/auto-run/experiments/file-invocations/replay.dart" "$1/tool/replay.dart"
  (cd "$1" && fvm dart pub get --offline > /dev/null 2>&1; echo "pub get exit: $?")
}
tcf_workspace "$WA"

step "A1 the amended topic-codegen invocations, every case, on the stand-in"
fixtures "$WA" topic-codegen worktree
ls "$WA/$TI" | tr '\n' ' '; echo
(cd "$WA" && rm -rf .dart_tool/pub/bin && fvm dart run tool/replay.dart $TI | paths; echo "exit: ${PIPESTATUS[0]}")

step "A2 the committed topic-codegen invocations on the same stand-in"
fixtures "$WA" topic-codegen HEAD
(cd "$WA" && fvm dart run tool/replay.dart $TI | summary; echo "exit: ${PIPESTATUS[0]}")

G=packages/nidana_dart_codegen/bin/generate.dart
K=packages/nidana_dart_codegen/bin/catalog.dart
seeded_a() { # $1 label, $2 python patch
  local copy=$TMP/seed-a-$1
  rsync -a "$WA/" "$copy/"
  (cd "$copy" && python3 -I -c "$2" && rm -rf .dart_tool/pub/bin) || { echo "patch failed"; return; }
  fixtures "$copy" topic-codegen worktree
  echo "amended:"; (cd "$copy" && fvm dart run tool/replay.dart $TI | grep -E '^FAIL|invocations pass' | cut -c1-160)
  fixtures "$copy" topic-codegen HEAD
  echo "committed:"; (cd "$copy" && fvm dart run tool/replay.dart $TI | grep -E '^FAIL|invocations pass' | cut -c1-160)
}

step "A3 seeded stand-ins: each fails the amended case of the rule it breaks, and passes every committed case"
echo "-- AD1 generate: a second --graph replaces the first"
seeded_a ad1 "$(sub $G "if (i + 1 >= args.length || graphPath != null) return _usage('--graph takes one file');" "if (i + 1 >= args.length) return _usage('--graph takes one file');")"
echo "-- AD2 generate: a trailing --graph without a value is ignored"
seeded_a ad2 "$(sub $G "if (i + 1 >= args.length || graphPath != null) return _usage('--graph takes one file');" "if (i + 1 >= args.length) continue;
      if (graphPath != null) return _usage('--graph takes one file');")"
echo "-- AD3 generate: a graph that is not JSON is a usage error, as the scan treats one"
seeded_a ad3 "$(sub $G "  final result = generate(" "  if (graphPath != null) {
    try {
      jsonDecode(File(graphPath).readAsStringSync());
    } on FormatException {
      return _usage('\$graphPath is not JSON');
    }
  }
  final result = generate(")
$(sub $G "import 'dart:io';" "import 'dart:convert';
import 'dart:io';")"
echo "-- AD4 catalog: one argument is the output of an empty package list"
seeded_a ad4 "$(sub $K "if (positional.length < 2) return _usage" "if (positional.isEmpty) return _usage")"
echo "-- AD5 catalog: a directory without pubspec.yaml is a package that registers nothing"
seeded_a ad5 "$(sub $K "    if (!File(p.join(pkg, 'pubspec.yaml')).existsSync()) {
      return _usage('\$pkg is not a package root');
    }" "")"

# ---------- Part B ----------
NI=$F/nidana-checks/invocation
WB=$TMP/ncf
rsync -a --exclude probe --exclude hsdd --exclude output.txt "$NCF/" "$WB/"
mkdir -p "$WB/$F" && cp "$REPO/$F/analysis_options.yaml" "$WB/$F/"

step "B1 the amended nidana-checks invocations, every case, on the stand-in"
fixtures "$WB" nidana-checks worktree
(cd "$WB" && fvm dart run tool/replay.dart $NI | paths; echo "exit: ${PIPESTATUS[0]}")
echo "-- what the analyzer reports in the added library (the scan reports none of it)"
(cd "$WB/$NI/scan-unresolved-claim/files/app" && fvm dart analyze --format=machine lib/unresolved.dart | cut -d'|' -f1,3,5,6 | paths)

step "B2 the committed nidana-checks invocations on the same stand-in"
fixtures "$WB" nidana-checks HEAD
(cd "$WB" && fvm dart run tool/replay.dart $NI | summary; echo "exit: ${PIPESTATUS[0]}")

C=packages/nidana_dart_codegen/lib/src/claims.dart
seeded_b() { # $1 label, $2 python patch
  local copy=$TMP/seed-b-$1
  rsync -a "$WB/" "$copy/"
  (cd "$copy" && python3 -I -c "$2" && rm -rf .dart_tool/pub/bin) || { echo "patch failed"; return; }
  fixtures "$copy" nidana-checks worktree
  echo "amended:"; (cd "$copy" && fvm dart run tool/replay.dart $NI scan-clean scan-unresolved-claim scan-writer-conflict scan-topic-name-collision | grep -E '^(PASS|FAIL) [a-z0-9-]+|^warning|invocations pass' | cut -c1-160)
  fixtures "$copy" nidana-checks HEAD
  echo "committed:"; (cd "$copy" && fvm dart run tool/replay.dart $NI | grep -E '^FAIL|invocations pass' | cut -c1-160)
}

step "B3 a seeded stand-in: a publisher invocation whose element does not resolve is taken for Bus.publisher"
seeded_b bd1 "$(sub $C "      if (owner is InterfaceElement && isNidanaClassOrSubclass(owner, runtimePackage, 'Bus')) {" "      if (owner == null || (owner is InterfaceElement && isNidanaClassOrSubclass(owner, runtimePackage, 'Bus'))) {")"

# ---------- C ----------
step "C the structure prototype over the repository's contracts as amended"
(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart | paths; echo "exit: ${PIPESTATUS[0]}")

rm -rf "$TMP"
