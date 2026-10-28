// topology-ir@v1's canonical orders (the Interface's Canonical orders), as
// comparators the IR, the graphs and the findings share (nidana.model D4).
// The claim order compares a claim's parts, so that this library never names
// ShellClaim, which lib/src/graph/ declares on top of lib/src/ir/.
import '../topic/message_source.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

/// Topic references: by `name` (`String.compareTo`), then `variant` (state,
/// event, replay), then `typeName`.
int compareTopicRefs(TopicRef a, TopicRef b) {
  final int byName = a.name.compareTo(b.name);
  if (byName != 0) {
    return byName;
  }
  final int byVariant = a.variant.index.compareTo(b.variant.index);
  if (byVariant != 0) {
    return byVariant;
  }
  return a.typeName.compareTo(b.typeName);
}

/// Topologies: by `topologyId`.
int compareTopologyIds(String a, String b) => a.compareTo(b);

/// Message sources: by `toString()`.
int compareMessageSources(MessageSource a, MessageSource b) =>
    a.toString().compareTo(b.toString());

/// The parts of a shell claim that the claim order compares.
typedef ClaimKey = ({
  MessageSource source,
  Scope scope,
  Iterable<TopicRef> writes,
});

/// Claims: by `source.toString()`, then `scope` (application, module, page),
/// then their `writes` element by element in canonical order, a shorter list
/// first when one is a prefix of the other.
int compareClaimKeys(ClaimKey a, ClaimKey b) {
  final int bySource = compareMessageSources(a.source, b.source);
  if (bySource != 0) {
    return bySource;
  }
  final int byScope = a.scope.index.compareTo(b.scope.index);
  if (byScope != 0) {
    return byScope;
  }
  final List<TopicRef> left = sortedCopy(a.writes, compareTopicRefs);
  final List<TopicRef> right = sortedCopy(b.writes, compareTopicRefs);
  for (int i = 0; i < left.length && i < right.length; i++) {
    final int byTopic = compareTopicRefs(left[i], right[i]);
    if (byTopic != 0) {
      return byTopic;
    }
  }
  return left.length.compareTo(right.length);
}

/// An unmodifiable list of [elements] sorted by [compare], repeated elements
/// kept.
List<T> sortedCopy<T>(Iterable<T> elements, Comparator<T> compare) =>
    List<T>.unmodifiable(elements.toList()..sort(compare));
