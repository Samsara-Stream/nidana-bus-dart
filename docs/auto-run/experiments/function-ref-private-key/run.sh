#!/usr/bin/env bash
# function-ref-private-key: evidence for step S44, the hsdd-contract touch of
# topology-ir@v1 that adds private names to the Function references table.
# S33 saw (../navigation-g13-coverage/ T7) that the VM renders a private
# function as `_name@{key}` and that the key differs between JIT and AOT. This
# asks what the key depends on, what every compiler renders for private names,
# and whether one behavior case can cover the row without pinning a key.
#
# probe/ (standalone package): lib/fns.dart holds private and public names;
# lib/moved/fns.dart is the same text at another URL; lib/report.dart prints
# each function's toString() and the name G9's rule derives from it.
#   P1 program a (fns.dart and report.dart only) under every runner and
#      compiler: `dart run` twice, a2 (a's text, another file name), `dart
#      test`, the Flutter tester, AOT, AOT with --obfuscate, dart2js -O1 and
#      -O4, dart2wasm;
#   P2 load order: b imports six more libraries before fns.dart, c the same
#      six after it; b under AOT too;
#   P3 URL: fns.dart and moved/fns.dart in one process.
# suite/ (own pub workspace): the stand-in of ../model-reconcile-amends/,
# copied unchanged, with hsdd/contract copied in at the repository's relative
# paths and removed afterwards.
#   S0 the stand-in packages are ../model-reconcile-amends/'s, unchanged;
#   S1 what changed among topology-ir@v1's fixtures, before against after;
#   S2 structure for topology-ir (the stand-in's prototype), then amended
#      ADR-001's coverage and layout prototype over the nine contracts;
#   S3 the conformance library and its binding analyze clean;
#   S4 every case passes against the stand-in; the G9 cases alone;
#   S5 seeded defects in FunctionRef.of: stripping the key, and anonymous for
#      a private name, each fail the new case and nothing else;
#   S6 the fixtures from before the amendment pass against the stripping
#      defect: the gap the new case closes.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
step() { echo; echo "### $*"; }

step "setup"
fvm dart --version 2>&1
fvm flutter --version 2>&1 | head -n 1
echo "node $(node --version)"

cd "$HERE/probe" || exit 1
rm -rf build && mkdir -p build
fvm dart pub get > /dev/null 2>&1; echo "probe pub get exit: $?"

step "P1 program a under every runner and compiler"
echo "-- dart run (JIT), first"
fvm dart run bin/a.dart
echo "-- dart run (JIT), second: private top-level only"
fvm dart run bin/a.dart | head -n 1
echo "-- a2: a's text under another file name (JIT): private top-level only"
fvm dart run bin/a2.dart | head -n 1
echo "-- dart test (JIT)"
fvm dart test --reporter expanded test/a_test.dart 2>&1 | grep '^test |'
echo "-- flutter test --no-pub (the Flutter tester, JIT)"
fvm flutter test --no-pub test/a_test.dart 2>&1 | grep '^test |'
echo "-- AOT (dart compile exe)"
fvm dart compile exe bin/a.dart -o build/a > /dev/null 2>&1 && ./build/a
echo "-- AOT with --obfuscate"
fvm dart compile exe --extra-gen-snapshot-options=--obfuscate bin/a.dart -o build/a_obf > /dev/null 2>&1 && ./build/a_obf
for o in O1 O4; do
  echo "-- dart2js -$o, run by node"
  fvm dart compile js -$o bin/a.dart -o build/a_$o.js > /dev/null 2>&1
  node -e "globalThis.self = globalThis; globalThis.dartPrint = (s) => console.log(s); require('./build/a_$o.js');"
done
echo "-- dart2wasm, run by node"
fvm dart compile wasm bin/a.dart -o build/a.wasm > /dev/null 2>&1
cp bin/run_wasm.mjs build/ && node build/run_wasm.mjs

step "P2 load order: b (six libraries before fns.dart), c (the same six after it)"
echo "-- b, JIT"
fvm dart run bin/b.dart | head -n 2
echo "-- c, JIT"
fvm dart run bin/c.dart | head -n 2
echo "-- b, AOT"
fvm dart compile exe bin/b.dart -o build/b > /dev/null 2>&1 && ./build/b | head -n 2

step "P3 URL: fns.dart and moved/fns.dart in one process (JIT): private top-level only"
fvm dart run bin/both.dart | grep '_hidden'
rm -rf build

cd "$HERE/suite" || exit 1
F=hsdd/contract/fixture
IR=$F/topology-ir
IRS=$IR/behavior/nidana_dart_contracts_test.dart
FR=packages/nidana_dart_contracts/lib/src/topology_ir.dart
verdicts() {
  sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' \
    | grep -E '\[E\]$|Some tests failed|All tests passed' | sort -u
}
# use {tree}: copies a tree's topology-ir contract, schema and fixtures here.
use() {
  rm -rf hsdd && mkdir -p $F hsdd/contract/schema
  cp "$1"/hsdd/contract/topology-ir.md hsdd/contract/
  cp "$1"/hsdd/contract/schema/topology-ir.schema.json hsdd/contract/schema/
  cp "$1"/$F/analysis_options.yaml $F/
  cp -R "$1"/$IR $F/
}
# mutate {label} {from} {to}: one textual defect in FunctionRef.of, the suite
# run, the failing cases printed, the file restored.
mutate() {
  local label="$1" from="$2" to="$3"
  cp $FR $FR.orig
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' $FR
  if cmp -s $FR.orig $FR; then echo "-- $label: MUTATION DID NOT APPLY"; mv $FR.orig $FR; return; fi
  echo "-- $label"
  fvm dart test $IRS 2>&1 | verdicts
  mv $FR.orig $FR
}
STRIP_FROM="        : FunctionRef.named(found);"
STRIP_TO="        : FunctionRef.named(found.replaceAll(RegExp(r'@\\d+'), ''));"
ANON_FROM="    return found == null || found.isEmpty"
ANON_TO="    return found == null || found.isEmpty || found.startsWith('_')"

step "S0 the stand-in packages are ../model-reconcile-amends/'s, unchanged"
diff -rq -x .dart_tool ../../model-reconcile-amends/packages packages > /dev/null && echo "identical" || echo "DIFFERS"
rm -rf before && mkdir -p before
git -C "$REPO" archive HEAD hsdd/contract | tar -x -C before
echo "before: hsdd/contract at $(git -C "$REPO" rev-parse --short HEAD)"
fvm dart pub get > /dev/null 2>&1; echo "suite pub get exit: $?"

step "S1 what changed among topology-ir@v1's fixtures and schema, before against after"
diff -ru before/$IR "$REPO"/$IR; echo "fixture diff exit: $?"
diff -u before/hsdd/contract/schema/topology-ir.schema.json "$REPO"/hsdd/contract/schema/topology-ir.schema.json; echo "schema diff exit: $?"

use "$REPO"
step "S2 structure: topology-ir with the stand-in's prototype, then the nine contracts with amended ADR-001's prototype"
fvm dart run nidana_contract_check:structure_check topology-ir | grep -v '^PASS G'; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check topology-ir | grep '^PASS G9'
(cd "$REPO" && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart | tail -n 11; echo "exit: ${PIPESTATUS[0]}")

step "S3 the conformance library and its binding analyze clean under the fixture options"
fvm dart analyze --fatal-infos $IR/behavior; echo "exit: $?"

step "S4 every case against the stand-in, then the G9 cases alone (--guarantee topology-ir/G9)"
fvm dart test $IRS 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
fvm dart test --reporter expanded --name '^G9 ' $IRS 2>&1 | sed -nE 's/^[0-9:]+ \+[0-9]+: (.*)(G9 .*)$/\2/p' | sort -u
fvm dart test --name '^G9 ' $IRS 2>&1 | tail -n 1

step "S5 seeded defects in FunctionRef.of fail the new case and nothing else"
mutate "the key stripped from a private name" "$STRIP_FROM" "$STRIP_TO"
mutate "a private name made anonymous" "$ANON_FROM" "$ANON_TO"

step "S6 before the amendment, the stripping defect passed every case"
use before
cp $FR $FR.orig
FROM="$STRIP_FROM" TO="$STRIP_TO" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' $FR
cmp -s $FR.orig $FR && echo "MUTATION DID NOT APPLY"
fvm dart test $IRS 2>&1 | verdicts
mv $FR.orig $FR

step "cleanup: remove the copied trees; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd before; echo "removed"
