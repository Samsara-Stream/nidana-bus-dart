// Reject fixture for topology-dsl@v2 G2: handles, builders, stages, sinks and
// plans are made only by the DSL. No type outside the library extends or
// implements them, and none has a public constructor.
// covers: G2
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedHandle implements TopicStream<int> {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedBuilder implements TopologyBuilder {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedStage implements MapStage<int, int> {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedSink implements PlanSink {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class ForgedPlan implements TopologyPlan {}

void construct() {
  // expect-diagnostic: new_with_undefined_constructor_default
  TopologyBuilder();
  // expect-diagnostic: new_with_undefined_constructor_default
  ReadStage<int>();
}
