#!/usr/bin/env bash
# model-main-library-closure (S109, hsdd-phase-plan: nidana.model re-plan of
# nidana.model.4 and nidana.model.5).
#
# Questions:
#  Q1 Does nidana_dart_contracts analyze clean when its main library carries
#     topic-model@v1, topology-dsl@v2 and topology-ir@v1's The IR and Function
#     references, beside lib/topology_plan.dart and with no lib/topology_ir.dart
#     (the re-planned nidana.model.4)?
#  Q2 Does nidana.model.4's gate replay (topic-model topology-dsl, sets
#     structure, surface and reject) pass against it, with the replay tool as
#     committed?
#  Q3 Which topology-ir@v1 surface and reject fixtures pass at that point, and
#     could nidana.model.4's gate replay topology-ir@v1's surface or reject set?
#  Q4 Do the package's own tests (purity_test.dart, nidana.model D6) pass with
#     those files in lib/?
#  Q5 Control: does topology-ir@v1's TopologyDefinition alone, as the plan
#     before S109 scoped nidana.model.4, analyze?
#  Q6 With lib/topology_ir.dart added (the re-planned nidana.model.5), does
#     nidana.model.5's gate replay pass?
#
# The scratch workspace is built under ./work and removed at exit:
#  - packages/nidana_contract_check: the repository's replay tool as committed
#    (nidana.model.1 and nidana.model.2).
#  - packages/nidana_dart_contracts: the repository's package as committed
#    (nidana.model.3), plus the stand-in DSL and IR files of
#    ../topology-ir-fixtures/ (lib/src/topology.dart, lib/src/topology_ir.dart,
#    lib/topology_plan.dart; their bodies compute, which no question here
#    depends on), topic_model_shim.dart as lib/src/topic_model.dart, and
#    main_library_tail.dart appended to the main library. Q6 adds the stand-in's
#    lib/topology_ir.dart and lib/src/topology_graph.dart.
#  - hsdd/contract: topic-model, topology-dsl and topology-ir with their
#    fixtures, the fixture analysis options and the topology-ir schema, copied
#    from the repository.
#  - the repository's .fvmrc, root analysis_options.yaml and pubspec.lock.
# Run from anywhere: bash run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
REPO=$(cd ../../../.. && pwd)
SI=$REPO/docs/auto-run/experiments/topology-ir-fixtures/packages/nidana_dart_contracts/lib
W=$HERE/work
F=hsdd/contract/fixture
P=packages/nidana_dart_contracts
step() { echo; echo "### $*"; }
rm -rf "$W"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/packages" "$W/$F" "$W/hsdd/contract/schema"
cd "$W" || exit 1

step "setup: scratch workspace from the committed packages, contracts and fixtures (repository HEAD $(git -C "$REPO" rev-parse --short HEAD))"
cp "$REPO/.fvmrc" "$REPO/analysis_options.yaml" "$REPO/pubspec.lock" .
cat > pubspec.yaml <<'EOF'
name: mlc_root
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - packages/nidana_contract_check
  - packages/nidana_dart_contracts
dev_dependencies:
  lints: ^6.1.0
EOF
rsync -a --exclude .dart_tool "$REPO/packages/nidana_contract_check" "$REPO/packages/nidana_dart_contracts" packages/
cp "$SI/src/topology.dart" "$SI/src/topology_ir.dart" $P/lib/src/
cp "$SI/topology_plan.dart" $P/lib/
cp "$HERE/topic_model_shim.dart" $P/lib/src/topic_model.dart
cat "$HERE/main_library_tail.dart" >> $P/lib/nidana_dart_contracts.dart
for s in topic-model topology-dsl topology-ir; do
  cp "$REPO/hsdd/contract/$s.md" hsdd/contract/
  cp -R "$REPO/$F/$s" $F/
done
cp "$REPO/$F/analysis_options.yaml" $F/
cp "$REPO/hsdd/contract/schema/topology-ir.schema.json" hsdd/contract/schema/
fvm dart --version 2>&1
fvm dart pub get --offline > /dev/null 2>&1; echo "pub get exit: $?"
echo "package lib/:"; (cd $P && find lib -type f | sort)
echo "main library export lines:"; grep -c '^export' $P/lib/nidana_dart_contracts.dart

step "Q1 analyze at the scratch root with --fatal-infos (main library: topic-model, topology-dsl, IR and Function references; no lib/topology_ir.dart)"
fvm dart analyze --fatal-infos 2>&1 | tail -3; echo "exit: ${PIPESTATUS[0]}"

step "Q2 nidana.model.4's gate replay: topic-model topology-dsl --set structure,surface,reject"
fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject 2>&1; echo "exit: $?"

step "Q3a topology-ir --set surface,reject at the same point"
fvm dart run nidana_contract_check topology-ir --set surface,reject 2>&1; echo "exit: $?"

step "Q3b the raw diagnostics of the topology-ir fixtures that import topology_ir.dart (first 4 lines each)"
for f in $F/topology-ir/surface/graphs.dart $F/topology-ir/reject/ir_families_are_closed.dart $F/topology-ir/reject/ir_values_are_immutable.dart; do
  echo "-- $f"
  fvm dart analyze "$f" 2>&1 | grep -E 'error|warning|info' | head -4
done

step "Q3c topology-ir --set structure,schema at the same point (what is runnable without topology_ir.dart)"
fvm dart run nidana_contract_check topology-ir --set structure,schema 2>&1 | tail -4; echo "exit: ${PIPESTATUS[0]}"

step "Q4 the package's own tests (declarations_test.dart, purity_test.dart) with the DSL and IR files in lib/"
fvm dart test packages/nidana_dart_contracts 2>&1 | tail -3; echo "exit: ${PIPESTATUS[0]}"

step "Q5 control: TopologyDefinition alone, importing the topic declarations and no IR file"
cp "$HERE/definition_alone.dart" $P/lib/src/definition_alone.dart
fvm dart analyze --fatal-infos $P/lib/src/definition_alone.dart 2>&1 | grep -E 'error|warning|info|issue'; echo "exit: ${PIPESTATUS[0]}"
rm $P/lib/src/definition_alone.dart

step "Q6 with the stand-in's lib/topology_ir.dart and lib/src/topology_graph.dart added: analyze, then nidana.model.5's gate replay"
cp "$SI/topology_ir.dart" $P/lib/
cp "$SI/src/topology_graph.dart" $P/lib/src/
fvm dart analyze --fatal-infos 2>&1 | tail -2; echo "analyze exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set structure,surface,reject,schema 2>&1 | grep -v ' schema ' ; echo "exit: ${PIPESTATUS[0]}"
fvm dart test packages/nidana_dart_contracts 2>&1 | tail -1; echo "exit: ${PIPESTATUS[0]}"
