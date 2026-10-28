#!/usr/bin/env bash
# suite_reach.sh: which of run.sh's seeded defects topology-ir@v1's
# conformance suite would catch once its restriction admits G3, G5, G6 and
# G7 (nidana.model.11's gate), on the final draft in a temporary copy of HEAD.
# D4 (a negative stage input accepted) is not probed: the binding runs under
# dart test with assertions enabled, so StageInput's own assertion fires
# before any definition sees the index.
# Run from anywhere: ./suite_reach.sh > suite_reach.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/ivr.XXXXXX")
P=$WS/packages/nidana_dart_contracts
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml LICENSE packages hsdd | tar -x -C "$WS"
(cd "$WS" && fvm dart pub get --offline > /dev/null 2>&1)
for f in ir/function_ref.dart ir/definition.dart ir/canonical_order.dart analysis/findings.dart; do cp "$HERE/draft/lib/src/$f" "$P/lib/src/$f"; done
run() {
  (cd "$WS" && fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G3,G5,G6,G7 2>&1) \
    | grep -E '^(PASS|FAIL) behavior' | sed 's/^.*: cases/cases/; s/^PASS behavior [^:]*: /cases /; s/; failed-case (/\n    failed-case (/g' | cut -c1-200
}
seed() { # seed <label> <file under lib/src> <old> <new>
  local file=$P/lib/src/$2
  cp "$file" "$WS/seed.bak"
  python3 -I -c 'import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
assert s.count(old) == 1
open(p, "w").write(s.replace(old, new))' "$file" "$3" "$4"
  echo "-- $1"; run
  cp "$WS/seed.bak" "$file"
}
echo "-- the final draft (the G3 cases and G7's second case build graphs, nidana.model.11's)"; run
seed "D2 an edge hashes its inputs list by identity" ir/definition.dart 'Object.hashAll(inputs),' 'inputs,'
seed "D5 combine takes a retry" ir/definition.dart "  CombinatorKind.combine => (
    minInputs: 1,
    maxInputs: null,
    transformer: true,
    duration: false,
    retry: false," "  CombinatorKind.combine => (
    minInputs: 1,
    maxInputs: null,
    transformer: true,
    duration: false,
    retry: true,"
seed "D7 a topic input ignores its dedup in equality" ir/definition.dart 'other is TopicInput && other.topic == topic && other.dedup == dedup;' 'other is TopicInput && other.topic == topic;'
seed "D8 an edge keeps the list it is given" ir/definition.dart 'inputs: List<EdgeInput>.unmodifiable(inputs),' 'inputs: inputs,'
seed "D11 a definition's equality ignores the order of its edges" ir/definition.dart 'elementsEqual(other.transforms, transforms);' 'other.transforms.toSet().containsAll(transforms) && other.transforms.length == transforms.length;'
rm -rf "$WS"
echo "done"
