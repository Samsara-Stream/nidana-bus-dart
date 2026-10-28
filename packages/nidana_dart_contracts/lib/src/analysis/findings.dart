import 'package:meta/meta.dart';

import '../ir/canonical_order.dart';
import '../topic/list_equality.dart';
import '../topic/message_source.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

/// A finding of the analyses (Spec §3.8, §3.11, §7.2). Sealed.
@immutable
sealed class TopologyFinding {
  const TopologyFinding._();
}

/// Spec §3.8, inter-topology: a strongly connected set of two or more
/// topologies. [topics] are the topics one member writes and another reads.
final class TopologyCycle extends TopologyFinding {
  TopologyCycle({
    required List<String> topologyIds,
    required List<TopicRef> topics,
  }) : topologyIds = sortedCopy(topologyIds, compareTopologyIds),
       topics = sortedCopy(topics, compareTopicRefs),
       super._();

  final List<String> topologyIds; // sorted
  final List<TopicRef> topics; // canonical order

  // topologyIds and topics, element by element (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopologyCycle &&
      elementsEqual(other.topologyIds, topologyIds) &&
      elementsEqual(other.topics, topics);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(topologyIds), Object.hashAll(topics));
}

/// Spec §3.8, intra-topology: [topic] is read and written by [topologyId]
/// through no state-bearing edge. [edges] are the indices of every edge on
/// such a path.
final class SelfReference extends TopologyFinding {
  SelfReference({
    required this.topologyId,
    required this.topic,
    required List<int> edges,
  }) : edges = sortedCopy(edges, (int a, int b) => a.compareTo(b)),
       super._();

  final String topologyId;
  final TopicRef topic;
  final List<int> edges; // ascending

  // topologyId, topic and edges, element by element (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is SelfReference &&
      other.topologyId == topologyId &&
      other.topic == topic &&
      elementsEqual(other.edges, edges);

  @override
  int get hashCode => Object.hash(topologyId, topic, Object.hashAll(edges));
}

/// Spec §3.11: a state topic with more than one writer. A topology writes
/// as TopologySource(topologyId), a claim as its source.
final class WriterConflict extends TopologyFinding {
  WriterConflict({required this.topic, required List<MessageSource> writers})
    : writers = sortedCopy(writers, compareMessageSources),
      super._();

  final TopicRef topic;
  // canonical order, one per writer, equal sources repeated
  final List<MessageSource> writers;

  // topic and writers, element by element (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is WriterConflict &&
      other.topic == topic &&
      elementsEqual(other.writers, writers);

  @override
  int get hashCode => Object.hash(topic, Object.hashAll(writers));
}

/// Spec §7.2: [owner] of the state topic [topic] has a shorter scope than
/// the topology [readerId] that reads it.
final class ScopeViolation extends TopologyFinding {
  const ScopeViolation({
    required this.topic,
    required this.owner,
    required this.ownerScope,
    required this.readerId,
    required this.readerScope,
  }) : super._();

  final TopicRef topic;
  final MessageSource owner;
  final Scope ownerScope;
  final String readerId;
  final Scope readerScope;

  // all five fields (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is ScopeViolation &&
      other.topic == topic &&
      other.owner == owner &&
      other.ownerScope == ownerScope &&
      other.readerId == readerId &&
      other.readerScope == readerScope;

  @override
  int get hashCode =>
      Object.hash(topic, owner, ownerScope, readerId, readerScope);
}

/// A topic declaration a scan found, and where (a label the caller chooses,
/// such as a file and line).
@immutable
final class TopicDeclaration {
  const TopicDeclaration({required this.topic, required this.site});

  final TopicRef topic;
  final String site;

  // topic and site (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopicDeclaration && other.topic == topic && other.site == site;

  @override
  int get hashCode => Object.hash(topic, site);
}

/// Spec §4.3: [name] declared more than once.
@immutable
final class TopicNameCollision {
  TopicNameCollision({
    required this.name,
    required List<TopicDeclaration> declarations,
  }) : declarations = sortedCopy(declarations, _bySiteThenTopic);

  final String name;
  // by site, then topic in canonical order
  final List<TopicDeclaration> declarations;

  // name and declarations, element by element (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopicNameCollision &&
      other.name == name &&
      elementsEqual(other.declarations, declarations);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(declarations));
}

// The order of a collision's declarations: by site, then topic in canonical
// order (topology-ir@v1 G23).
int _bySiteThenTopic(TopicDeclaration a, TopicDeclaration b) {
  final int bySite = a.site.compareTo(b.site);
  return bySite != 0 ? bySite : compareTopicRefs(a.topic, b.topic);
}
