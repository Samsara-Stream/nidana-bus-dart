import 'package:meta/meta.dart';

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
  TopologyCycle({required this.topologyIds, required this.topics}) : super._();

  final List<String> topologyIds; // sorted
  final List<TopicRef> topics; // canonical order
}

/// Spec §3.8, intra-topology: [topic] is read and written by [topologyId]
/// through no state-bearing edge. [edges] are the indices of every edge on
/// such a path.
final class SelfReference extends TopologyFinding {
  SelfReference({
    required this.topologyId,
    required this.topic,
    required this.edges,
  }) : super._();

  final String topologyId;
  final TopicRef topic;
  final List<int> edges; // ascending
}

/// Spec §3.11: a state topic with more than one writer. A topology writes
/// as TopologySource(topologyId), a claim as its source.
final class WriterConflict extends TopologyFinding {
  WriterConflict({required this.topic, required this.writers}) : super._();

  final TopicRef topic;
  // canonical order, one per writer, equal sources repeated
  final List<MessageSource> writers;
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
}

/// A topic declaration a scan found, and where (a label the caller chooses,
/// such as a file and line).
@immutable
final class TopicDeclaration {
  const TopicDeclaration({required this.topic, required this.site});

  final TopicRef topic;
  final String site;
}

/// Spec §4.3: [name] declared more than once.
@immutable
final class TopicNameCollision {
  TopicNameCollision({required this.name, required this.declarations});

  final String name;
  // by site, then topic in canonical order
  final List<TopicDeclaration> declarations;
}
