// Reject fixture for topology-ir@v1 G3: no field of a definition, an edge,
// an edge input, a function reference, a graph, a claim or a finding can be
// assigned (Spec §6.5: the IR is a value type).
// covers: G3
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

void misuse(
  TopologyDefinition definition,
  TransformEdge edge,
  TopicInput input,
  StageInput stage,
  FunctionRef ref,
  TopologyGraph graph,
  ShellClaim claim,
  SelfReference finding,
) {
  // expect-diagnostic: assignment_to_final
  definition.topologyId = 'other';
  // expect-diagnostic: assignment_to_final
  definition.transforms = <TransformEdge>[];
  // expect-diagnostic: assignment_to_final
  edge.combinator = CombinatorKind.map;
  // expect-diagnostic: assignment_to_final
  edge.inputs = <EdgeInput>[];
  // expect-diagnostic: assignment_to_final
  input.dedup = Dedup.none;
  // expect-diagnostic: assignment_to_final
  stage.edge = 0;
  // expect-diagnostic: assignment_to_final
  ref.name = 'other';
  // expect-diagnostic: assignment_to_final
  graph.topologies = <TopologyDefinition>[];
  // expect-diagnostic: assignment_to_final
  claim.scope = Scope.page;
  // expect-diagnostic: assignment_to_final
  finding.edges = <int>[];
}
