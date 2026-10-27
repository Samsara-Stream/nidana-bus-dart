import '../graph/graph.dart';
import '../ir/definition.dart';
import 'findings.dart';

List<TopologyCycle> findTopologyCycles(TopologyGraph graph) =>
    throw UnimplementedError();
List<SelfReference> findSelfReferences(TopologyDefinition definition) =>
    throw UnimplementedError();
List<WriterConflict> findWriterConflicts(TopologyGraph graph) =>
    throw UnimplementedError();
List<ScopeViolation> findScopeViolations(TopologyGraph graph) =>
    throw UnimplementedError();

/// Every finding: cycles, then the self-references of each topology in graph
/// order, then writer conflicts, then scope violations.
List<TopologyFinding> analyzeTopologyGraph(TopologyGraph graph) =>
    throw UnimplementedError();

List<TopicNameCollision> findTopicNameCollisions(
  Iterable<TopicDeclaration> declarations,
) => throw UnimplementedError();
