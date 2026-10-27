#!/usr/bin/env bash
# sweep-topology-ir-text: evidence for S153, the end-of-nidana.model
# governance sweep of topology-ir@v1, part 1 (hsdd-contract, compatible
# touches within v1: the text, the Interface, the schema, invalid/ and the
# surface set). It works in a temporary copy of the committed tree
# (git archive HEAD), so packages/ is the shipped package, and records:
#   F: facts/facts.dart against the shipped package, run from the repository
#      root: FunctionRef.of over the extension forms, two state topics whose
#      value types render alike, graphs whose encoding the decoder rejects,
#      integers in the JSON form and what a schema bound would decide, the
#      three would-be invalid/ documents, and the order of scope violations.
#   X: ext/bin/main.dart, the extension and extension-type function forms
#      under every compiler the derivation table has a column for: JIT, AOT,
#      AOT with --obfuscate, dart2js at -O1 and -O4, dart2wasm.
#   J: how a JavaScript JSON parser reads 2^63 - 1 and 2^63.
#   B: the committed fixtures, topology-ir replayed unrestricted.
#   N: S153's working-tree contract text and surface/graphs.dart in the copy,
#      replayed unrestricted, and the tree's structure set.
#   C: a seeded defect, ScopeViolation's constructor not const, replayed on
#      the surface set with the committed graphs.dart and with S153's.
#   W: the three would-be invalid/ documents placed under the copy's
#      invalid/: the schema set, the G21 conformance cases, and the package's
#      json_reject_test.dart, which pins the exact list of invalid/ files.
#   M: the alternative not taken, a schema with `maximum` 2^63 - 1 on
#      durationMicros and edge: the schema set over valid/ and invalid/.
#   R: the copy's lib/ against HEAD's, and S153's fixtures once more.
# Run from anywhere: ./run.sh > output.txt 2>&1
set -u
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
T=${TMPDIR:-/tmp}
WS=$(mktemp -d "${T%/}/sweepir.XXXXXX")
P=$WS/packages/nidana_dart_contracts
IR=hsdd/contract/fixture/topology-ir
step() { echo; echo "### $*"; }
clip() { sed "s#$(cd "$WS" && pwd -P)#{ws}#g; s#$WS#{ws}#g" | cut -c1-400; } # the resolved path, the longer, first
replay() { # replay <grep pattern for the lines to show> <args...>
  local show=$1; shift
  (cd "$WS" && fvm dart run nidana_contract_check "$@" > "$WS/replay.out" 2>&1; echo "exit: $?" >> "$WS/replay.out")
  echo "-- nidana_contract_check $*"
  grep -E "$show|^FAIL|fixtures:|^exit:" "$WS/replay.out" | sed 's/; failed-case (/\n    failed-case (/g' | clip
}
seed() { # seed <label> <file under lib/src> <old> <new>; \n in old and new is a newline
  cp "$P/lib/src/$2" "$WS/seed.bak"
  python3 -I - "$P/lib/src/$2" "$3" "$4" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1])
a, b = sys.argv[2].replace('\\n', '\n'), sys.argv[3].replace('\\n', '\n')
t = f.read_text()
assert t.count(a) == 1, 'not found once: ' + a
f.write_text(t.replace(a, b))
PY
  echo; echo "-- $1"
  diff "$WS/seed.bak" "$P/lib/src/$2" | clip
}
unseed() { cp "$WS/seed.bak" "$P/lib/src/$1"; }

step "S0 setup: the committed tree, resolved offline"
git -C "$REPO" archive HEAD .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml packages hsdd | tar -x -C "$WS"
echo "tree from $(git -C "$REPO" log -1 --format='%h %s')"
fvm dart --version 2>&1
(cd "$WS" && fvm dart pub get --offline 2>&1 | tail -n 1)
echo "packages/ changes in the working tree: $(git -C "$REPO" status --porcelain packages | wc -l | tr -d ' ')"
echo "S153's working-tree changes under hsdd/:"
git -C "$REPO" status --porcelain hsdd | sed 's/^/  /'

step "F facts/facts.dart against the shipped package, from the repository root"
(cd "$REPO" && fvm dart run "$HERE/facts/facts.dart" 2>&1)

step "X the extension forms under each compiler (ext/, standalone)"
(cd "$HERE/ext" && rm -rf build && mkdir -p build && fvm dart pub get > /dev/null 2>&1
  echo "-- JIT (fvm dart run)"; fvm dart run bin/main.dart
  echo "-- AOT (fvm dart compile exe)"
  fvm dart compile exe bin/main.dart -o build/aot > /dev/null 2>&1 && ./build/aot
  echo "-- AOT obfuscated (--extra-gen-snapshot-options=--obfuscate)"
  fvm dart compile exe --extra-gen-snapshot-options=--obfuscate bin/main.dart -o build/aot_obf > /dev/null 2>&1 && ./build/aot_obf
  for o in O1 O4; do
    echo "-- dart2js -$o, run by node $(node --version)"
    fvm dart compile js -$o bin/main.dart -o build/main_$o.js > /dev/null 2>&1
    node -e "globalThis.self = globalThis; globalThis.dartPrint = (s) => console.log(s); require('./build/main_$o.js');"
  done
  echo "-- dart2wasm, run by node $(node --version)"
  fvm dart compile wasm bin/main.dart -o build/main.wasm > /dev/null 2>&1
  cp bin/run_wasm.mjs build/ && node build/run_wasm.mjs
  rm -rf build .dart_tool pubspec.lock)

step "J a JavaScript JSON parser reads 2^63 - 1 and 2^63 as one number"
node -e "const a = JSON.parse('9223372036854775807'), b = JSON.parse('9223372036854775808');
console.log('JSON.parse(2^63 - 1) =', a, '; JSON.parse(2^63) =', b, '; equal:', a === b, '; equal to 2**63:', a === 2 ** 63);"

step "B the committed fixtures, topology-ir unrestricted"
replay '^PASS (surface|reject|behavior) ' topology-ir

step "N S153's contract text and surface/graphs.dart in the copy"
cp "$WS/$IR/surface/graphs.dart" "$WS/graphs.committed"
cp "$REPO/hsdd/contract/topology-ir.md" "$WS/hsdd/contract/topology-ir.md"
cp "$REPO/$IR/surface/graphs.dart" "$WS/$IR/surface/graphs.dart"
cp "$REPO/hsdd/contract/schema/topology-ir.schema.json" "$WS/hsdd/contract/schema/topology-ir.schema.json"
echo "-- surface/graphs.dart, committed against S153's:"
diff "$WS/graphs.committed" "$WS/$IR/surface/graphs.dart" | clip
echo "-- the schema, committed against S153's: $(git -C "$REPO" diff --quiet HEAD -- hsdd/contract/schema/topology-ir.schema.json && echo unchanged || echo changed)"
replay '^PASS (surface|reject|behavior) |^PASS structure hsdd/contract/topology-ir.md' topology-ir
replay '^FAIL' --all --set structure

step "C seeded: ScopeViolation's constructor not const"
seed "C1 ScopeViolation's constructor without const" analysis/findings.dart \
  "  const ScopeViolation({" \
  "  ScopeViolation({"
echo "- the committed graphs.dart:"; cp "$WS/graphs.committed" "$WS/$IR/surface/graphs.dart"
replay '^PASS surface ' topology-ir --set surface
echo "- S153's graphs.dart:"; cp "$REPO/$IR/surface/graphs.dart" "$WS/$IR/surface/graphs.dart"
replay '^PASS surface |const' topology-ir --set surface
unseed analysis/findings.dart

step "W the would-be invalid/ documents under the copy's invalid/"
for f in "$HERE"/would-be-invalid/*.json; do cp "$f" "$WS/$IR/invalid/"; done
echo "invalid/ now holds $(ls "$WS/$IR/invalid" | wc -l | tr -d ' ') documents"
replay '(claim_repeat_topic|dedup_on_replay_read|topic_ref_empty_type_name)' topology-ir --set schema
replay '^PASS behavior ' topology-ir --set behavior --guarantee G21
echo "-- fvm dart test packages/nidana_dart_contracts/test/json_reject_test.dart"
(cd "$WS" && fvm dart test --reporter expanded packages/nidana_dart_contracts/test/json_reject_test.dart > "$WS/test.out" 2>&1; echo "exit: $?" >> "$WS/test.out")
grep -E '\[E\]|Which:' "$WS/test.out" | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' | clip
grep -E 'Some tests failed|All tests passed' "$WS/test.out" | tail -n 1 | sed -E 's/^[0-9:]+ //' | clip
grep -E '^exit:' "$WS/test.out"
for f in "$HERE"/would-be-invalid/*.json; do rm "$WS/$IR/invalid/$(basename "$f")"; done
echo "invalid/ restored: $(ls "$WS/$IR/invalid" | wc -l | tr -d ' ') documents"

step "M the alternative not taken: maximum 2^63 - 1 on durationMicros and edge"
SCHEMA=$WS/hsdd/contract/schema/topology-ir.schema.json
cp "$SCHEMA" "$WS/schema.bak"
python3 -I - "$SCHEMA" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1])
t = f.read_text()
for old in ('"edge": { "type": "integer", "minimum": 0 }', '"durationMicros": { "type": "integer", "minimum": 0 }'):
    assert t.count(old) == 1, old
    t = t.replace(old, old[:-2] + ', "maximum": 9223372036854775807 }')
f.write_text(t)
PY
diff "$WS/schema.bak" "$SCHEMA" | clip
replay '^PASS schema hsdd/contract/schema' topology-ir --set schema
cp "$WS/schema.bak" "$SCHEMA"

step "R restored: the copy's lib/ and schema against HEAD's, S153's fixtures once more"
mkdir -p "$WS/head"
git -C "$REPO" archive HEAD packages/nidana_dart_contracts/lib | tar -x -C "$WS/head"
if diff -r "$WS/head/packages/nidana_dart_contracts/lib" "$P/lib" > /dev/null; then
  echo "the copy's lib/ equals HEAD's"
else
  echo "the copy's lib/ differs from HEAD's"
fi
replay '^PASS (surface|reject|behavior) ' topology-ir

rm -rf "$WS"
