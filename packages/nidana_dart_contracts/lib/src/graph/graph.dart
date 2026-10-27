import 'package:meta/meta.dart';

import '../ir/canonical_order.dart';
import '../ir/definition.dart';
import '../topic/list_equality.dart';
import '../topic/message_source.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

/// A shell publisher's claim (Spec §2.4, §3.11, §7.2): its source, the scope
/// it is bound to (application when unbound), and the state topics it
/// claims. Throws ArgumentError when [source] is a TopologySource or
/// UnknownSource, or [writes] is empty or names a topic that is not a state
/// topic.
@immutable
final class ShellClaim {
  const ShellClaim._({
    required this.source,
    required this.scope,
    required this.writes,
  });

  factory ShellClaim({
    required MessageSource source,
    Scope scope = Scope.application,
    required Set<TopicRef> writes,
  }) {
    if (!_isShellSource(source)) {
      throw ArgumentError.value(
        source,
        'source',
        'is not a service, page or executor source',
      );
    }
    if (writes.isEmpty) {
      throw ArgumentError.value(writes, 'writes', 'must not be empty');
    }
    for (final TopicRef topic in writes) {
      if (topic.variant != TopicVariant.state) {
        throw ArgumentError.value(
          topic.name,
          'writes',
          'names a topic that is not a state topic',
        );
      }
    }
    return ShellClaim._(
      source: source,
      scope: scope,
      writes: Set<TopicRef>.unmodifiable(sortedCopy(writes, compareTopicRefs)),
    );
  }

  final MessageSource source;
  final Scope scope;
  final Set<TopicRef> writes; // canonical order; unmodifiable copy

  // The parts of this claim that the claim order compares.
  ClaimKey get _key => (source: source, scope: scope, writes: writes);

  // source, scope and writes, element by element in canonical order
  // (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is ShellClaim &&
      other.source == source &&
      other.scope == scope &&
      elementsEqual(other.writes.toList(), writes.toList());

  @override
  int get hashCode => Object.hash(source, scope, Object.hashAll(writes));
}

// Whether a shell publisher may claim with [source] (G12): a topology owns
// its topics through its definition, and an unknown source owns nothing.
bool _isShellSource(MessageSource source) => switch (source) {
  ServiceSource() || PageSource() || ExecutorSource() => true,
  TopologySource() || UnknownSource() => false,
};

/// Topologies and shell claims (Spec §6.5, Appendix A.4, A.9): the active
/// set behind bus.toGraph(), or the static set a catalog scans.
@immutable
final class TopologyGraph {
  const TopologyGraph._({
    required this.topologies,
    required this.claims,
    required this.topics,
  });

  /// Throws ArgumentError when two definitions share a topologyId and are
  /// not equal; equal ones count once (Spec §3.9).
  factory TopologyGraph({
    Iterable<TopologyDefinition> topologies = const <TopologyDefinition>[],
    Iterable<ShellClaim> claims = const <ShellClaim>[],
  }) {
    final List<TopologyDefinition> byId = _distinctById(topologies);
    final List<ShellClaim> sortedClaims = sortedCopy(
      claims,
      (ShellClaim a, ShellClaim b) => compareClaimKeys(a._key, b._key),
    );
    return TopologyGraph._(
      topologies: byId,
      claims: sortedClaims,
      topics: sortedCopy(<TopicRef>{
        for (final TopologyDefinition d in byId) ...d.reads,
        for (final TopologyDefinition d in byId) ...d.writes,
        for (final ShellClaim c in sortedClaims) ...c.writes,
      }, compareTopicRefs),
    );
  }

  // by topologyId, distinct ids; unmodifiable
  final List<TopologyDefinition> topologies;
  // canonical order, equal claims kept; unmodifiable
  final List<ShellClaim> claims;
  // every topic read or written, canonical order; unmodifiable
  final List<TopicRef> topics;

  /// renderer.render(this).
  String render(GraphRenderer renderer) => renderer.render(this);

  // topologies and claims, element by element in their canonical orders, so
  // the order the arguments came in takes no part (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopologyGraph &&
      elementsEqual(other.topologies, topologies) &&
      elementsEqual(other.claims, claims);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(topologies), Object.hashAll(claims));
}

// [topologies] by topologyId, one per id (G11): an equal definition counts
// once, and one unequal to the definition already kept for its id throws
// ArgumentError.
List<TopologyDefinition> _distinctById(
  Iterable<TopologyDefinition> topologies,
) {
  final List<TopologyDefinition> kept = <TopologyDefinition>[];
  for (final TopologyDefinition d in sortedCopy(
    topologies,
    (TopologyDefinition a, TopologyDefinition b) =>
        compareTopologyIds(a.topologyId, b.topologyId),
  )) {
    if (kept.isEmpty || kept.last.topologyId != d.topologyId) {
      kept.add(d);
    } else if (kept.last != d) {
      throw ArgumentError.value(
        d.topologyId,
        'topologies',
        'holds two definitions with this id that are not equal',
      );
    }
  }
  return List<TopologyDefinition>.unmodifiable(kept);
}

extension TopologyDefinitionGraph on TopologyDefinition {
  /// Spec §6.5's ir.toGraph(): TopologyGraph(topologies: [this]).
  TopologyGraph toGraph() =>
      TopologyGraph(topologies: <TopologyDefinition>[this]);
}

/// Renders a graph as text (Spec §6.5, Appendix A.4 "other graph
/// formats"). Applications may implement it.
abstract interface class GraphRenderer {
  String render(TopologyGraph graph);
}
