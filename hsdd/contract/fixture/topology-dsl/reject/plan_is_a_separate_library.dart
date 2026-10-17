// Reject fixture for topology-dsl@v1 G2: the plan declarations are exported
// only from package:nidana_dart_contracts/topology_plan.dart. Code that
// imports the main library alone, as a topology module does, cannot name a
// stage or a plan, or obtain one.
// covers: G2
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

// expect-diagnostic: undefined_class
MapStage<int, int>? stage;

// expect-diagnostic: undefined_class
TopologyPlan? plan;

// expect-diagnostic: undefined_function
Object? planFor(Topology t) => planOf(t);
