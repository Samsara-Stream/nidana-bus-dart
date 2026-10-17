#!/usr/bin/env bash
# topology-ir-fixtures: replays the topology-ir@v1 fixtures and schema, as
# written under the repository's hsdd/contract/, against a stand-in of
# nidana_dart_contracts that implements topology-ir@v1
# (packages/nidana_dart_contracts; its topic-model and topology-dsl parts are
# copied from ../topology-dsl-fixtures/, its recorder's plan projection
# rewritten to topology-ir@v1's rules), and replays topology-dsl@v1's
# fixtures again against the same stand-in.
#
# The replay tool's structure, reject and schema sets are prototypes
# (packages/nidana_contract_check/bin); its fixture library adds
# expectMatchesSchema on package:json_schema. render-check/ parses the
# Mermaid goldens with Mermaid's parser, lays out the DOT goldens with
# Graphviz compiled to wasm, and cross-checks the schema with Ajv, from
# project-local npm packages (package.json, package-lock.json).
#
# The repository has no pub workspace yet, so the fixtures and contracts are
# copied into this experiment's own workspace at the same relative paths.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
IR=$F/topology-ir
step() { echo; echo "### $*"; }

step "setup: copy the contracts, fixtures and schema from the repository, resolve"
rm -rf hsdd out && mkdir -p $F hsdd/contract/schema
cp $REPO/hsdd/contract/topology-ir.md $REPO/hsdd/contract/topology-dsl.md hsdd/contract/
cp $REPO/hsdd/contract/schema/topology-ir.schema.json hsdd/contract/schema/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/topology-ir $REPO/$F/topology-dsl $F/
find hsdd -type f | sort | sed -n '1,12p'; echo "... $(find hsdd -type f | wc -l | tr -d ' ') files"
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
awk '/^  (meta|matcher|test|json_schema|lints):/{p=$1} p && /version:/{print "resolved", p, $2; p=""}' pubspec.lock
(cd render-check && npm ci --no-audit --no-fund > /dev/null 2>&1; echo "npm ci exit: $?")
node -e "for (const p of ['mermaid','@hpcc-js/wasm-graphviz','ajv','jsdom']) console.log('npm', p, require('./render-check/node_modules/'+p+'/package.json').version)"

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 workspace-wide analyze at the root skips hsdd/** (reject fixtures hold deliberate errors) and the experiment scripts"
fvm dart analyze --fatal-infos; echo "exit: $?"

step "T2 structure: headers, markers, guarantee coverage, listed bindings, no src/ imports"
fvm dart run nidana_contract_check:structure_check topology-ir; echo "exit: $?"

step "T3 surface: every surface library analyzes with no diagnostic under --fatal-infos"
fvm dart analyze --fatal-infos $IR/surface; echo "exit: $?"

step "T4 reject: the (line, code) pairs reported in each file equal the pairs its markers name"
fvm dart run nidana_contract_check:reject_check $IR/reject; echo "exit: $?"

step "T5 reject: the raw diagnostics behind T4, one line each (line severity code)"
for f in $IR/reject/*.dart; do
  echo "-- $(basename "$f")"
  fvm dart analyze --format=json "$f" | sed -n 's/^.*\({"version".*\)$/\1/p' | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      for (const d of JSON.parse(s).diagnostics)
        console.log(d.location.range.start.line, d.severity, d.code);
    });'
done

step "T6 schema (package:json_schema 5.2.2, draft 2020-12): every valid/ file validates, no invalid/ file does"
fvm dart run nidana_contract_check:schema_check topology-ir; echo "exit: $?"

step "T7 schema cross-check (Ajv, draft 2020-12, strict): the same verdicts"
node render-check/schema.mjs hsdd/contract/schema/topology-ir.schema.json $IR | grep -c '^PASS'; node render-check/schema.mjs hsdd/contract/schema/topology-ir.schema.json $IR > /dev/null; echo "exit: $?"

step "T8 behavior: the binding under dart test, run from the root"
fvm dart test --reporter expanded $IR/behavior/nidana_dart_contracts_test.dart 2>&1 | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' | grep -v '^loading'; echo "exit: ${PIPESTATUS[0]}"

step "T9 behavior: a guarantee restriction by test-name prefix (--guarantee topology-ir/G14)"
fvm dart test --reporter expanded --name '^G14 ' $IR/behavior/nidana_dart_contracts_test.dart 2>&1 | tail -n 3; echo "exit: ${PIPESTATUS[0]}"

step "T10 behavior: the binding runs from a member's directory too (workspace root found by walking up)"
(cd packages/nidana_dart_contracts && fvm dart test ../../$IR/behavior/nidana_dart_contracts_test.dart 2>&1 | tail -n 1); echo "exit: $?"

step "T11 the conformance library and the binding analyze clean (warnings included)"
fvm dart analyze --fatal-infos $IR/behavior; echo "exit: $?"

step "T12 the render/ goldens parse: Mermaid's parser and Graphviz's layout"
node render-check/check.mjs $IR/render; echo "exit: $?"
echo "-- not vacuous: the escaping goldens with their escapes undone"
mkdir -p out/broken
sed 's/#quot;/"/g' $IR/render/escaping.mmd > out/broken/unescaped.mmd
sed 's/\\"/"/g' $IR/render/escaping.dot > out/broken/unescaped.dot
node render-check/check.mjs out/broken; echo "exit: $?"

step "T13 the Interface's example document validates and round-trips"
fvm dart run tool/check_example.dart; echo "exit: $?"

step "T14 the goldens are what the stand-in writes (valid/ and render/ regenerated and compared)"
fvm dart run tool/write_goldens.dart out/regen > /dev/null && diff -r out/regen/valid $IR/valid && diff -r out/regen/render $IR/render && echo "identical"
node tool/write_invalid.mjs $IR/valid out/regen/invalid > /dev/null && diff -r out/regen/invalid $IR/invalid && echo "invalid/ identical"

step "T15 topology-dsl@v1's fixtures against this stand-in's projection: structure, surface, reject, recording"
fvm dart run nidana_contract_check:structure_check topology-dsl | tail -n 1; echo "exit: ${PIPESTATUS[0]}"
fvm dart analyze --fatal-infos $F/topology-dsl/surface; echo "exit: $?"
fvm dart run nidana_contract_check:reject_check $F/topology-dsl/reject | cut -c1-60; echo "exit: ${PIPESTATUS[0]}"
fvm dart test $F/topology-dsl/behavior/topology_builder_test.dart 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"

# mutate {file} {label} {from} {to}: applies one textual defect to the
# stand-in, runs the suite, prints the failing cases, and restores the file.
SUITE=$IR/behavior/nidana_dart_contracts_test.dart
mutate() {
  local file="$1" label="$2" from="$3" to="$4"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  fvm dart test "$SUITE" 2>&1 \
    | grep -E '\[E\]$|Some tests failed|All tests passed|Error:' \
    | sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)? -[0-9]+: //' | sort -u
  mv "$file.orig" "$file"
}

IRV=packages/nidana_dart_contracts/lib/src/topology_ir.dart
GR=packages/nidana_dart_contracts/lib/src/topology_graph.dart
REC=packages/nidana_dart_contracts/lib/src/topology.dart
step "T16 the suite is not vacuous: each seeded defect in the stand-in fails the cases of its guarantee"
mutate $REC "withLatestFrom projects its latest inputs before the primary (G8)" "_all(<TopicStream<Object?>>[s.primary, ...s.latest])" "_all(<TopicStream<Object?>>[...s.latest, s.primary])"
mutate $REC "a read's dedup argument is dropped (G8)" "TopicInput(topic.ref, dedup: dedup)" "TopicInput(topic.ref)"
mutate $IRV "FunctionRef.of names a closure by its signature (G9)" "    final String? found = _vmName.firstMatch(function.toString())?.group(1);" "    final String? found = _vmName.firstMatch(function.toString())?.group(1) ??
        RegExp(r\"^Closure: ([^ ]*)\").firstMatch(function.toString())?.group(1);"
mutate $IRV "a zero-duration time stage bears state (G10, G14, G17)" "duration! > Duration.zero" "duration! >= Duration.zero"
mutate $IRV "a stage edge after a sink edge is accepted (G6, G21)" "      } else if (sinkSeen) {" "      } else if (sinkSeen && false) {"
mutate $IRV "edges ignore their duration in equality (G7)" "        other.duration != duration ||" ""
mutate $IRV "reads keep edge order instead of canonical order (G6, G19, G22)" "      _sorted(<TopicRef>[
        for (final e in transforms)
          for (final input in e.inputs)" "      Set<TopicRef>.unmodifiable(<TopicRef>[
        for (final e in transforms)
          for (final input in e.inputs)"
mutate $GR "a graph keeps the later of two definitions with one id (G11)" "      if (seen != null && seen != d) {" "      if (false) {"
mutate $GR "a graph exposes a modifiable topology list (G3)" "      List<TopologyDefinition>.unmodifiable(ordered)," "      ordered,"
mutate $GR "a claim accepts event topics (G12)" "      if (w.variant != TopicVariant.state) {
        throw ArgumentError.value(" "      if (false) {
        throw ArgumentError.value("
mutate $GR "a single topology counts as a cycle (G13)" "      if (c.length > 1)
        TopologyCycle(" "      if (c.isNotEmpty)
        TopologyCycle("
mutate $GR "self-reference search ignores state-bearing edges (G14)" "    for (var k = 0; k < edges.length; k++) {
      final e = edges[k];
      if (e.isStateBearing) continue;" "    for (var k = 0; k < edges.length; k++) {
      final e = edges[k];"
mutate $GR "event topics have owners (G15)" "      if (w.variant != TopicVariant.state) continue;" ""
mutate $GR "scope compatibility compares the wrong way round (G16)" "        if (!o.scope.isAtLeastAsLongAs(r.scope)) {" "        if (!r.scope.isAtLeastAsLongAs(o.scope)) {"
mutate $GR "analyzeTopologyGraph puts cycles last (G17)" "      ...findTopologyCycles(graph),
      for (final d in graph.topologies) ...findSelfReferences(d),
      ...findWriterConflicts(graph),
      ...findScopeViolations(graph)," "      for (final d in graph.topologies) ...findSelfReferences(d),
      ...findWriterConflicts(graph),
      ...findScopeViolations(graph),
      ...findTopologyCycles(graph),"
mutate $GR "name collisions require different types (G18)" "    (byName[d.topic.name] ??= <TopicDeclaration>{}).add(d);" "    (byName['\${d.topic.name} \${d.topic.typeName}'] ??= <TopicDeclaration>{}).add(d);"
mutate $GR "a write encodes combinator: null (G19, G20, G22)" "      if (e.combinator != null) 'combinator': e.combinator!.name," "      'combinator': e.combinator?.name,"
mutate $GR "the decoder skips the reads check (G21)" "  if (reads.toSet().length != reads.length ||
      reads.length != d.reads.length ||
      !d.reads.containsAll(reads)) {" "  if (false) {"
mutate $GR "the decoder casts instead of checking (G21)" "  int integer(Object? json) => json is int ? json : fail('expected an integer');" "  int integer(Object? json) => json! as int;"
mutate $GR "Mermaid does not escape quotes (G22)" "      .replaceAll('\"', '#quot;')" ""
mutate $GR "Graphviz does not escape backslashes (G22)" "      .replaceAll(r'\\', r'\\\\')" ""
mutate $GR "the JSON rendering has no final newline (G22)" "convert(encodeTopologyGraph(graph))}\\n';" "convert(encodeTopologyGraph(graph))}';"

step "T17 a CombinatorKind value added to the Interface fails the surface set (exhaustive switch)"
cp $IRV "$IRV.orig"
perl -0pi -e 's/  reduceInto,\n\}/  reduceInto,\n  window,\n}/' $IRV
grep -c '^  window,' $IRV
fvm dart analyze --fatal-infos --format=machine $IR/surface | cut -d'|' -f3,4,5,6 ; echo "exit: ${PIPESTATUS[0]}"
mv "$IRV.orig" $IRV
echo "stand-in restored"

step "cleanup: remove the copied tree and the scratch output; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd out render-check/node_modules; echo "removed"
