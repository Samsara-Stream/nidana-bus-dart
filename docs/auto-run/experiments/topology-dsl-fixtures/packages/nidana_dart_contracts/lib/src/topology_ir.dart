/// Minimal stand-in for the topology-ir@v1 declarations that topology-dsl@v1
/// names: `TopologyDefinition` with the Spec §6.5 fields, and a placeholder
/// `TransformEdge` and `CombinatorKind`. topology-ir@v1 (a later hsdd-contract
/// step) fixes the real shape; the topology-dsl@v1 fixtures use only
/// `topologyId`, `scope`, `reads`, `writes` and `==`.
///
/// Throwaway experiment code.
library;

import 'package:meta/meta.dart';

import 'topic_model.dart';

/// One value per stage class and per reduceInto sink of topology-dsl@v1.
enum CombinatorKind {
  map,
  filter,
  combine,
  withLatestFrom,
  merge,
  switchMap,
  scan,
  pairwise,
  distinctUntilChanged,
  debounce,
  throttle,
  delay,
  sample,
  buffer,
  timeout,
  catchError,
  rawEngine,
  reduceInto,
}

@immutable
final class TransformEdge {
  const TransformEdge(this.combinator);
  final CombinatorKind combinator;

  @override
  bool operator ==(Object other) =>
      other is TransformEdge && other.combinator == combinator;

  @override
  int get hashCode => combinator.hashCode;

  @override
  String toString() => 'TransformEdge(${combinator.name})';
}

@immutable
final class TopologyDefinition {
  TopologyDefinition({
    required this.topologyId,
    required this.scope,
    required Set<TopicRef> reads,
    required Set<TopicRef> writes,
    required List<TransformEdge> transforms,
  })  : reads = Set<TopicRef>.unmodifiable(reads),
        writes = Set<TopicRef>.unmodifiable(writes),
        transforms = List<TransformEdge>.unmodifiable(transforms);

  final String topologyId;
  final Scope scope;
  final Set<TopicRef> reads;
  final Set<TopicRef> writes;
  final List<TransformEdge> transforms;

  @override
  bool operator ==(Object other) {
    if (other is! TopologyDefinition) return false;
    if (other.topologyId != topologyId || other.scope != scope) return false;
    if (other.reads.length != reads.length || !other.reads.containsAll(reads)) {
      return false;
    }
    if (other.writes.length != writes.length ||
        !other.writes.containsAll(writes)) {
      return false;
    }
    if (other.transforms.length != transforms.length) return false;
    for (var i = 0; i < transforms.length; i++) {
      if (other.transforms[i] != transforms[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        topologyId,
        scope,
        Object.hashAllUnordered(reads),
        Object.hashAllUnordered(writes),
        Object.hashAll(transforms),
      );
}
