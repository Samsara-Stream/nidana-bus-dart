#!/usr/bin/env bash
# nidana-checks-fixtures: replays the nidana-checks@v1 recorded invocations,
# as written under the repository's hsdd/contract/fixture/nidana-checks/,
# the way ADR-001 item 7 describes, against stand-ins:
#
#   packages/nidana_dart_lint     the four plugin rules, on the pinned
#                                 analyzer 13.3.0 and analysis_server_plugin
#                                 0.3.18, depending on no nidana package
#   packages/nidana_dart_codegen  the scan command, on analyzer 13.3.0 and the
#                                 stand-in nidana_dart_contracts' analyses
#
# over the stand-in nidana_dart_contracts, nidana_dart_runtime,
# nidana_dart_navigation and nidana_dart_runtime_flutter of
# ../flutter-binding-fixtures/, copied unchanged. The root options enable the
# plugin, as ADR-002 item 7 has the real root do.
#
# tool/replay.dart is the stand-in of the replay tool's `cli` set: per case,
# `args` (command, then one argument per line), `files/` as the working
# directory, exit_code, stdout and stderr compared exactly after the absolute
# paths of files/ and of the workspace root become {files} and {root}.
# tool/graphs.dart wrote the graph documents the scan cases read;
# tool/graph_check.dart validates them against topology-ir@v1's schema;
# tool/type_names.dart is probe P1 (static type names against the VM's).
#
# The repository has no pub workspace yet, so the fixtures are copied into
# this experiment's own workspace at the same relative paths (tool/sync.sh),
# and every command runs from this directory as the replay would from the
# workspace root. Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
ROOT=$(pwd)
I=hsdd/contract/fixture/nidana-checks/invocation
TMP=$(mktemp -d)
# Copies below $TMP find the SDK pin through this copy of the repository's
# .fvmrc, as the experiment itself finds the repository's.
cp ../../../../.fvmrc "$TMP/"
step() { echo; echo "### $*"; }
paths() { sed -e "s|$TMP|{tmp}|g" -e "s|$ROOT|{root}|g" -e "s|$HOME|{home}|g"; }

step "setup: copy the fixtures from the repository, resolve"
tool/sync.sh
find $I -maxdepth 1 -mindepth 1 -type d | sort | sed 's|.*/||' | tr '\n' ' '; echo
fvm flutter pub get > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  [a-z_]+:$/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock | grep -E ' (analyzer|analysis_server_plugin|json_schema|path|test):'
fvm dart --version

step "T0 the stand-in members, the plugin's own sources included, are clean under the root lint set, the strict modes and the plugin, with --fatal-infos"
fvm dart analyze --fatal-infos --format=machine packages | paths; echo "exit: ${PIPESTATUS[0]}"

step "T1 replay every recorded invocation from the workspace root (ADR-001 item 7)"
fvm dart run tool/replay.dart $I; echo "exit: $?"

step "T2 the graph documents: schema-valid and decodable, except the one the scan must reject"
fvm dart run tool/graph_check.dart $I ../../../../hsdd/contract/schema/topology-ir.schema.json

step "T3 without the replacement, a machine-format recording holds this machine's absolute path"
(cd $I/analyze-raw-string-topic/files && fvm dart analyze --format=machine . | grep -c "$ROOT/$I/analyze-raw-string-topic/files/lib/" | sed 's|^|lines naming the absolute files/ path: |')
grep -c '{files}/lib/' $I/analyze-raw-string-topic/stdout | sed 's|^|lines naming {files} in the recording: |'

step "T4 machine independence: the whole workspace moved to another absolute path replays unchanged"
MOVED=$TMP/elsewhere/deeper/ncf
mkdir -p "$(dirname "$MOVED")" && rsync -a --exclude probe "$ROOT/" "$MOVED/"
(cd "$MOVED" && fvm dart run tool/replay.dart $I | paths; echo "exit: ${PIPESTATUS[0]}")

seeded() { # $1 label, $2 python patch, $3... cases
  local label=$1 patch=$2; shift 2
  local copy=$TMP/defect-$label
  rsync -a --exclude probe "$ROOT/" "$copy/"
  (cd "$copy" && python3 -I -c "$patch" && fvm dart run tool/replay.dart $I "$@" | grep -E -o '^(PASS|FAIL) [a-z0-9-]+|^[0-9]+ of [0-9]+ invocations pass')
}
sub() { echo "import sys; p='$1'; s=open(p).read(); a='''$2'''; b='''$3'''; assert a in s, 'patch target missing'; open(p,'w').write(s.replace(a,b))"; }

step "T5 seeded defects in the stand-ins: each fails the invocations of the guarantee it breaks"
L=packages/nidana_dart_lint/lib/src/rules.dart
S=packages/nidana_dart_codegen/lib/src/scan.dart
K=packages/nidana_dart_codegen/lib/src/claims.dart
echo "-- D1 plugin rules also report in test directories (G3)"
seeded d1 "$(sub $L '    if (context.isInTestDirectory) return;' '')" analyze-clean analyze-human
echo "-- D2 unflagged_sensitive_topic reports at WARNING instead of INFO (G1)"
seeded d2 "$(sub $L "or to its entry in topics.yaml.\"," "or to its entry in topics.yaml.\", severity: DiagnosticSeverity.WARNING,")" analyze-unflagged-sensitive-topic analyze-sensitive-fatal-infos analyze-human analyze-clean
echo "-- D3 the scan also reads the graph document's claims (G9)"
seeded d3 "$(sub $S 'claims: <ShellClaim>[for (final FoundClaim f in walk.claims) f.claim],' 'claims: <ShellClaim>[for (final FoundClaim f in walk.claims) f.claim, if (graphPath != null) ...decodeTopologyGraph(jsonDecode(File(graphPath).readAsStringSync())).claims],')" scan-clean scan-writer-conflict
echo "-- D4 the scan also reads test directories (G9)"
seeded d4 "$(sub $S '      if (testDirectories.contains(first)) continue;' '')" scan-clean scan-topic-name-collision scan-cycles
echo "-- D5 the scan does not recognize PageScope claims (G11)"
seeded d5 "$(sub $K "    if (isNidana(cls, flutterPackage, 'PageScope') ||" '    if (')" scan-writer-conflict scan-scope-violation scan-unresolved-claim scan-cycles

step "P1 static type names against the VM's rendering (TopicRef.typeName, '\$T'), which the graph document holds"
fvm dart run tool/type_names.dart

step "P2 a plugin enabled in a package root's options reports when dart analyze runs on that root or on a file, and not when it runs on a directory below it"
for target in . lib lib/app.dart; do
  (cd $I/analyze-human/files && fvm dart analyze --format=machine $target | cut -d'|' -f1,3 | sed "s|^|dart analyze $target: |"; echo "dart analyze $target exit: ${PIPESTATUS[0]}")
done

# The copied fixtures are the repository's; the copy is not kept.
rm -rf "$TMP" hsdd
