// Surface of bus-api@v1, activation, module scopes and the live graph.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const EventTopic<int> input = EventTopic<int>(name: 'surface.input');
const StateTopic<int> total = StateTopic<int>(name: 'surface.total', initial: 0);

int add(int state, int event) => state + event;

final Topology totals = topology('surface-totals', Scope.module,
    (TopologyBuilder b) => b.reduceInto(total, b.read(input), add));

void activation(Bus bus) {
  final TopologyHandle handle = bus.activate(totals);
  final String id = handle.topologyId;
  final Scope scope = handle.scope;
  final TopologyDefinition definition = handle.definition;
  final bool active = handle.isActive;
  handle.deactivate();
  final TopologyGraph graph = bus.toGraph();
  print(<Object?>[id, scope, definition, active, graph]);
}

void modules(Bus bus) {
  final ModuleScope checkout = bus.module('checkout', <Topology>[totals]);
  final ModuleScope slow = bus.module('slow', <Topology>[totals],
      gracePeriod: const Duration(milliseconds: 400));
  final String id = checkout.moduleId;
  final List<Topology> topologies = checkout.topologies;
  final Duration grace = checkout.gracePeriod;
  final int references = checkout.references;
  final bool active = checkout.isActive;
  final ModuleReference reference = checkout.acquire();
  final ModuleScope scope = reference.scope;
  final bool released = reference.isReleased;
  reference.release();
  print(<Object?>[slow, id, topologies, grace, references, active, scope, released]);
}
