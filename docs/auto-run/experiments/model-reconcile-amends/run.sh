#!/usr/bin/env bash
# model-reconcile-amends: checks the two compatible amendments S29's
# hsdd-reconcile applied from nidana.model's phase plan:
#
# - topology-dsl@v1 G30: stages, sinks, builders and plans keep Object's ==
#   and hashCode (one new recording case);
# - topology-ir@v1 G23: the constructors of TopologyCycle, SelfReference,
#   WriterConflict and TopicNameCollision sort their lists into the orders the
#   Interface names (one new behavior case).
#
# The stand-in under packages/ is ../topology-ir-fixtures/packages/ copied
# unchanged, except that the four constructors in
# packages/nidana_dart_contracts/lib/src/topology_graph.dart now sort their
# lists (G23). The stand-in in ../topology-ir-fixtures/ keeps the order given;
# T8 and T9 restore that behavior as seeded defects.
#
# The repository has no pub workspace yet, so the contracts, fixtures and
# schema are copied from the repository's hsdd/contract/ into this
# experiment's own workspace at the same relative paths, and removed again.
# Run from anywhere: ./run.sh > output.txt 2>&1
cd "$(dirname "$0")" || exit 1
REPO=../../../..
F=hsdd/contract/fixture
DSL=$F/topology-dsl
IR=$F/topology-ir
REC=$DSL/behavior/topology_builder_test.dart
IRS=$IR/behavior/nidana_dart_contracts_test.dart
step() { echo; echo "### $*"; }
# Prints the failing case names of a dart test run, then its verdict.
verdicts() {
  sed -E 's/^[0-9:]+ \+[0-9]+( ~[0-9]+)?( -[0-9]+)?: //' \
    | grep -E '\[E\]$|Some tests failed|All tests passed' | sort -u
}

step "setup: copy the contracts, fixtures and schema from the repository, resolve"
rm -rf hsdd && mkdir -p $F hsdd/contract/schema
cp $REPO/hsdd/contract/topology-ir.md $REPO/hsdd/contract/topology-dsl.md hsdd/contract/
cp $REPO/hsdd/contract/schema/topology-ir.schema.json hsdd/contract/schema/
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/topology-ir $REPO/$F/topology-dsl $F/
echo "copied $(find hsdd -type f | wc -l | tr -d ' ') files"
grep -c "^- \*\*G30\*\*" hsdd/contract/topology-dsl.md
grep -c "^- \*\*G23\*\*" hsdd/contract/topology-ir.md
fvm dart pub get > /dev/null 2>&1; echo "pub get exit: $?"
fvm dart --version 2>&1

step "T0 the stand-in packages are clean under the root lint set and --fatal-infos"
fvm dart analyze --fatal-infos packages; echo "exit: $?"

step "T1 structure: guarantee coverage holds with G30 and G23 (prototype structure set)"
fvm dart run nidana_contract_check:structure_check topology-dsl | tail -n 2; echo "exit: ${PIPESTATUS[0]}"
fvm dart run nidana_contract_check:structure_check topology-ir | tail -n 2; echo "exit: ${PIPESTATUS[0]}"

step "T2 the two conformance libraries and their bindings analyze clean (warnings included)"
fvm dart analyze --fatal-infos $DSL/behavior/recording_conformance.dart $REC $IR/behavior; echo "exit: $?"

step "T3 topology-dsl@v1 recording suite, every case, against the stand-in"
fvm dart test $REC 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"

step "T4 the G30 case alone (--guarantee topology-dsl/G30)"
fvm dart test --reporter expanded --name '^G30 ' $REC 2>&1 | grep -v '^loading' | tail -n 2; echo "exit: ${PIPESTATUS[0]}"

step "T5 topology-ir@v1 suite, every case, against the sorting stand-in"
fvm dart test $IRS 2>&1 | tail -n 1; echo "exit: ${PIPESTATUS[0]}"

step "T6 the G23 case alone (--guarantee topology-ir/G23)"
fvm dart test --reporter expanded --name '^G23 ' $IRS 2>&1 | grep -v '^loading' | tail -n 2; echo "exit: ${PIPESTATUS[0]}"

# mutate {suite} {file} {label} {from} {to}: applies one textual defect to
# the stand-in, runs the suite, prints the failing cases, restores the file.
mutate() {
  local suite="$1" file="$2" label="$3" from="$4" to="$5"
  cp "$file" "$file.orig"
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
  if cmp -s "$file.orig" "$file"; then echo "-- $label: MUTATION DID NOT APPLY"; mv "$file.orig" "$file"; return; fi
  echo "-- $label"
  fvm dart test "$suite" 2>&1 | verdicts
  mv "$file.orig" "$file"
}

TOP=packages/nidana_dart_contracts/lib/src/topology.dart
GR=packages/nidana_dart_contracts/lib/src/topology_graph.dart

step "T7 G30 is not vacuous: value equality seeded into a stage, a sink, the builder or the plan fails G30 alone"
mutate $REC $TOP "a read stage equal by topic and dedup" \
"  final Dedup? dedup;
" \
"  final Dedup? dedup;
  @override
  bool operator ==(Object other) =>
      other is ReadStage<Object?> && other.topic == topic && other.dedup == dedup;
  @override
  int get hashCode => Object.hash(topic, dedup);
"
mutate $REC $TOP "a write sink equal by topic and input" \
"  V _accept<V>(SinkVisitor<V> visitor) => visitor.write<T>(this);
" \
"  V _accept<V>(SinkVisitor<V> visitor) => visitor.write<T>(this);
  @override
  bool operator ==(Object other) =>
      other is WriteSink<Object?> && other.topic == topic && identical(other.input, input);
  @override
  int get hashCode => Object.hash(topic, identityHashCode(input));
"
mutate $REC $TOP "builders all equal" \
"  TopologyBuilder._();
" \
"  TopologyBuilder._();
  @override
  bool operator ==(Object other) => other is TopologyBuilder;
  @override
  int get hashCode => 0;
"
mutate $REC $TOP "a plan equal by id, identity hash code kept" \
"  final List<PlanSink> sinks;

  /// The IR" \
"  final List<PlanSink> sinks;
  @override
  bool operator ==(Object other) => other is TopologyPlan && other.topologyId == topologyId;
  @override
  int get hashCode => super.hashCode;

  /// The IR"

step "T8 G23 is not vacuous: each constructor keeping the order given fails G23 alone"
mutate $IRS $GR "TopologyCycle keeps its ids and topics as given" \
"      : topologyIds = List<String>.unmodifiable(topologyIds.toList()..sort()),
        topics = List<TopicRef>.unmodifiable(topics.toList()..sort(compareTopicRefs)),"  \
"      : topologyIds = List<String>.unmodifiable(topologyIds),
        topics = List<TopicRef>.unmodifiable(topics),"
mutate $IRS $GR "SelfReference keeps its edges as given" \
"  })  : edges = List<int>.unmodifiable(edges.toList()..sort())," \
"  })  : edges = List<int>.unmodifiable(edges),"
mutate $IRS $GR "WriterConflict keeps its writers as given" \
"      : writers = List<MessageSource>.unmodifiable(writers.toList()
          ..sort((a, b) => a.toString().compareTo(b.toString()))),"  \
"      : writers = List<MessageSource>.unmodifiable(writers),"
mutate $IRS $GR "TopicNameCollision keeps its declarations as given" \
"  }) : declarations = List<TopicDeclaration>.unmodifiable(declarations.toList()
          ..sort((a, b) {
            final bySite = a.site.compareTo(b.site);
            return bySite != 0 ? bySite : compareTopicRefs(a.topic, b.topic);
          }));" \
"  }) : declarations = List<TopicDeclaration>.unmodifiable(declarations);"

step "T9 the stand-in of ../topology-ir-fixtures/ (no constructor sorts) fails G23 and nothing else"
cp $GR $GR.orig
cp ../topology-ir-fixtures/$GR $GR
fvm dart test $IRS 2>&1 | verdicts
fvm dart test $REC 2>&1 | tail -n 1
mv $GR.orig $GR
echo "stand-in restored"

step "T10 amended ADR-001's coverage and layout prototype over the repository's nine contracts as they stand"
(cd $REPO && fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart | tail -n 4; echo "exit: ${PIPESTATUS[0]}")

step "cleanup: remove the copied tree; the repository's hsdd/contract/ stays the only copy"
rm -rf hsdd; echo "removed"
