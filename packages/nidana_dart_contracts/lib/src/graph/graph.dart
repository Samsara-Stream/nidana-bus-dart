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
  // The factory constructs through this once nidana.model.11 lands it.
  // ignore: unused_element
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
  }) => throw UnimplementedError();

  // by topologyId, distinct ids; unmodifiable
  final List<TopologyDefinition> topologies;
  // canonical order, equal claims kept; unmodifiable
  final List<ShellClaim> claims;
  // every topic read or written, canonical order; unmodifiable
  final List<TopicRef> topics;

  /// renderer.render(this).
  String render(GraphRenderer renderer) => throw UnimplementedError();
}

extension TopologyDefinitionGraph on TopologyDefinition {
  /// Spec §6.5's ir.toGraph(): TopologyGraph(topologies: [this]).
  TopologyGraph toGraph() => throw UnimplementedError();
}

/// Renders a graph as text (Spec §6.5, Appendix A.4 "other graph
/// formats"). Applications may implement it.
abstract interface class GraphRenderer {
  String render(TopologyGraph graph);
}
