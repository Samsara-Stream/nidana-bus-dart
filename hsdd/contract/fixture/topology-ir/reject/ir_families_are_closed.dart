// Reject fixture for topology-ir@v1 G1: the IR's families are closed. No
// type outside the library extends or implements an edge input, an edge, a
// definition, a function reference, a graph, a claim or a finding, and a
// switch that omits an edge input form, a finding variant or a combinator
// kind does not compile.
// covers: G1
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedInput implements EdgeInput {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedTopicInput implements TopicInput {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedEdge implements TransformEdge {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedDefinition implements TopologyDefinition {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedRef implements FunctionRef {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedGraph implements TopologyGraph {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedClaim implements ShellClaim {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedFinding implements TopologyFinding {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedCycle implements TopologyCycle {}

// expect-diagnostic: non_exhaustive_switch_expression
String input(EdgeInput i) => switch (i) {
      TopicInput() => 'topic',
    };

// expect-diagnostic: non_exhaustive_switch_expression
String finding(TopologyFinding f) => switch (f) {
      TopologyCycle() => 'cycle',
      SelfReference() => 'self',
      WriterConflict() => 'writers',
    };

// expect-diagnostic: non_exhaustive_switch_expression
bool timed(CombinatorKind k) => switch (k) {
      CombinatorKind.debounce ||
      CombinatorKind.throttle ||
      CombinatorKind.delay ||
      CombinatorKind.sample ||
      CombinatorKind.buffer ||
      CombinatorKind.timeout =>
        true,
      CombinatorKind.map || CombinatorKind.filter || CombinatorKind.combine => false,
    };
