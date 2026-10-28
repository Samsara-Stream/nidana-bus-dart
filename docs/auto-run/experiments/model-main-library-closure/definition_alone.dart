// Control for the plan as written before S109: nidana.model.4 landing
// topology-ir@v1's TopologyDefinition "(its factory and five getters)" and
// nothing else of topology-ir@v1. Copied by run.sh into the scratch package's
// lib/src/ beside the topic files, importing them and no IR file. The
// declaration is hsdd/contract/topology-ir.md lines 120 to 135 with bodies
// that throw (nidana.model D3).
import 'topic_model.dart';

final class TopologyDefinition {
  factory TopologyDefinition({
    required String topologyId,
    required Scope scope,
    required List<TransformEdge> transforms,
  }) => throw UnimplementedError();

  String get topologyId => throw UnimplementedError();
  Scope get scope => throw UnimplementedError();
  Set<TopicRef> get reads => throw UnimplementedError();
  Set<TopicRef> get writes => throw UnimplementedError();
  List<TransformEdge> get transforms => throw UnimplementedError();
}
