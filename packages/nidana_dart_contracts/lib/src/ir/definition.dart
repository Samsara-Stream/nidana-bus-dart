import 'package:meta/meta.dart';

import '../topic/list_equality.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';
import 'canonical_order.dart';
import 'function_ref.dart';

/// The combinator of an edge (Spec §6.5, Appendix A.4): one value per stage
/// class of topology-dsl@v2 other than ReadStage, and one for reduceInto, in
/// topology-dsl@v2's combinator-table order.
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

/// What an edge consumes (Spec §6.5 `inputs`). Sealed.
@immutable
sealed class EdgeInput {
  const EdgeInput._();
}

/// The values one read of [topic] delivers: a ReadStage of the plan. [dedup]
/// is the read's argument, null when the read kept the topic's own policy
/// (topology-dsl@v2 G13).
final class TopicInput extends EdgeInput {
  const TopicInput(this.topic, {this.dedup}) : super._();

  final TopicRef topic;
  final Dedup? dedup;

  // topic and dedup (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopicInput && other.topic == topic && other.dedup == dedup;

  @override
  int get hashCode => Object.hash(topic, dedup);
}

/// The values the stage edge at index [edge] of the same definition's
/// transforms emits. [edge] is asserted non-negative.
final class StageInput extends EdgeInput {
  const StageInput(this.edge)
    : assert(edge >= 0, 'edge must not be negative'),
      super._();

  final int edge;

  // edge (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) => other is StageInput && other.edge == edge;

  @override
  int get hashCode => edge.hashCode;
}

/// One element of a topology's wiring other than a read (Spec §6.5): a stage
/// edge, whose values only later edges consume, or a sink edge, whose values
/// are published to [output]. No public unnamed constructor.
@immutable
final class TransformEdge {
  const TransformEdge._({
    required this.combinator,
    required this.inputs,
    required this.output,
    required this.transformer,
    required this.duration,
    required this.retry,
  });

  /// A non-read stage. Throws ArgumentError when [combinator] is reduceInto,
  /// or when the inputs, transformer, duration or retry do not fit the
  /// combinator (the table below), or for a negative [duration].
  factory TransformEdge.stage(
    CombinatorKind combinator,
    List<EdgeInput> inputs, {
    FunctionRef? transformer,
    Duration? duration,
    FunctionRef? retry,
  }) {
    final _StageRule rule = _ruleOf(combinator);
    if (inputs.length < rule.minInputs ||
        (rule.maxInputs != null && inputs.length > rule.maxInputs!)) {
      final String count = rule.maxInputs == null
          ? 'at least ${rule.minInputs}'
          : rule.minInputs == rule.maxInputs
          ? 'exactly ${rule.minInputs}'
          : '${rule.minInputs} to ${rule.maxInputs}';
      throw ArgumentError.value(
        inputs.length,
        'inputs',
        'a ${combinator.name} edge takes $count inputs',
      );
    }
    _checkPresence(transformer, 'transformer', combinator, rule.transformer);
    _checkPresence(duration, 'duration', combinator, rule.duration);
    if (duration != null && duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    if (retry != null && !rule.retry) {
      throw ArgumentError.value(
        retry,
        'retry',
        'a ${combinator.name} edge holds none',
      );
    }
    return TransformEdge._(
      combinator: combinator,
      inputs: List<EdgeInput>.unmodifiable(inputs),
      output: null,
      transformer: transformer,
      duration: duration,
      retry: retry,
    );
  }

  /// A write: [input]'s values published to [topic] unchanged.
  factory TransformEdge.write(TopicRef topic, EdgeInput input) =>
      TransformEdge._(
        combinator: null,
        inputs: List<EdgeInput>.unmodifiable(<EdgeInput>[input]),
        output: topic,
        transformer: null,
        duration: null,
        retry: null,
      );

  /// A reduceInto folding [events] into [topic] with [reducer]. Throws
  /// ArgumentError unless [topic] is a state topic.
  factory TransformEdge.reduceInto(
    TopicRef topic,
    EdgeInput events,
    FunctionRef reducer,
  ) {
    if (topic.variant != TopicVariant.state) {
      throw ArgumentError.value(
        topic.name,
        'topic',
        'is not a state topic, and a reduceInto writes one',
      );
    }
    return TransformEdge._(
      combinator: CombinatorKind.reduceInto,
      inputs: List<EdgeInput>.unmodifiable(<EdgeInput>[events]),
      output: topic,
      transformer: reducer,
      duration: null,
      retry: null,
    );
  }

  final CombinatorKind? combinator; // null exactly for a write
  final List<EdgeInput> inputs; // unmodifiable copy, in input order
  final TopicRef? output; // a sink's topic; null for a stage
  final FunctionRef? transformer; // the edge's function, when it holds one
  final Duration? duration; // the six time stages only
  final FunctionRef? retry; // a switchMap with a retry policy only
  bool get isSink => output != null; // output != null
  bool get isStateBearing => switch (combinator) {
    CombinatorKind.scan || CombinatorKind.reduceInto => true,
    CombinatorKind.debounce ||
    CombinatorKind.delay ||
    CombinatorKind.sample ||
    CombinatorKind.buffer => duration! > Duration.zero,
    _ => false,
  }; // Spec §3.8; the rule below

  // all six fields, inputs element by element (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TransformEdge &&
      other.combinator == combinator &&
      elementsEqual(other.inputs, inputs) &&
      other.output == output &&
      other.transformer == transformer &&
      other.duration == duration &&
      other.retry == retry;

  @override
  int get hashCode => Object.hash(
    combinator,
    Object.hashAll(inputs),
    output,
    transformer,
    duration,
    retry,
  );
}

// What a stage edge of one combinator holds (topology-ir@v1, What a stage
// edge holds): from minInputs to maxInputs inputs (null: no upper bound); a
// transformer and a duration exactly when required, else none; a retry
// allowed only where optional.
typedef _StageRule = ({
  int minInputs,
  int? maxInputs,
  bool transformer,
  bool duration,
  bool retry,
});

_StageRule _ruleOf(CombinatorKind combinator) => switch (combinator) {
  CombinatorKind.map ||
  CombinatorKind.filter ||
  CombinatorKind.scan ||
  CombinatorKind.catchError ||
  CombinatorKind.rawEngine => (
    minInputs: 1,
    maxInputs: 1,
    transformer: true,
    duration: false,
    retry: false,
  ),
  CombinatorKind.switchMap => (
    minInputs: 1,
    maxInputs: 1,
    transformer: true,
    duration: false,
    retry: true,
  ),
  CombinatorKind.combine => (
    minInputs: 1,
    maxInputs: null,
    transformer: true,
    duration: false,
    retry: false,
  ),
  CombinatorKind.withLatestFrom => (
    minInputs: 2,
    maxInputs: 4,
    transformer: true,
    duration: false,
    retry: false,
  ),
  CombinatorKind.merge => (
    minInputs: 1,
    maxInputs: null,
    transformer: false,
    duration: false,
    retry: false,
  ),
  CombinatorKind.pairwise || CombinatorKind.distinctUntilChanged => (
    minInputs: 1,
    maxInputs: 1,
    transformer: false,
    duration: false,
    retry: false,
  ),
  CombinatorKind.debounce ||
  CombinatorKind.throttle ||
  CombinatorKind.delay ||
  CombinatorKind.sample ||
  CombinatorKind.buffer ||
  CombinatorKind.timeout => (
    minInputs: 1,
    maxInputs: 1,
    transformer: false,
    duration: true,
    retry: false,
  ),
  CombinatorKind.reduceInto => throw ArgumentError.value(
    combinator,
    'combinator',
    'a reduceInto edge is made by TransformEdge.reduceInto',
  ),
};

// Throws ArgumentError when [value] is absent where [required], or present
// where not.
void _checkPresence(
  Object? value,
  String name,
  CombinatorKind combinator,
  bool required,
) {
  if (required && value == null) {
    throw ArgumentError.value(
      value,
      name,
      'a ${combinator.name} edge needs one',
    );
  }
  if (!required && value != null) {
    throw ArgumentError.value(
      value,
      name,
      'a ${combinator.name} edge holds none',
    );
  }
}

/// The IR of one topology (Spec §6.5, Appendix A.4).
@immutable
final class TopologyDefinition {
  const TopologyDefinition._({
    required this.topologyId,
    required this.scope,
    required this.reads,
    required this.writes,
    required this.transforms,
  });

  /// Throws ArgumentError for an empty [topologyId] or ill-formed
  /// [transforms] (the rules below).
  factory TopologyDefinition({
    required String topologyId,
    required Scope scope,
    required List<TransformEdge> transforms,
  }) {
    if (topologyId.isEmpty) {
      throw ArgumentError.value(topologyId, 'topologyId', 'must not be empty');
    }
    final List<TransformEdge> edges = List<TransformEdge>.unmodifiable(
      transforms,
    );
    _checkWellFormed(edges);
    final List<TopicRef> read = <TopicRef>[
      for (final TransformEdge edge in edges)
        for (final EdgeInput input in edge.inputs)
          if (input is TopicInput) input.topic,
    ];
    final List<TopicRef> written = <TopicRef>[
      for (final TransformEdge edge in edges)
        if (edge.output case final TopicRef topic) topic,
    ];
    return TopologyDefinition._(
      topologyId: topologyId,
      scope: scope,
      reads: Set<TopicRef>.unmodifiable(sortedCopy(read, compareTopicRefs)),
      writes: Set<TopicRef>.unmodifiable(sortedCopy(written, compareTopicRefs)),
      transforms: edges,
    );
  }

  final String topologyId;
  final Scope scope;
  // the topics of every TopicInput; canonical order; unmodifiable
  final Set<TopicRef> reads;
  // the outputs of the sink edges; canonical order; unmodifiable
  final Set<TopicRef> writes;
  final List<TransformEdge> transforms; // unmodifiable copy

  // topologyId, scope and transforms element by element (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopologyDefinition &&
      other.topologyId == topologyId &&
      other.scope == scope &&
      elementsEqual(other.transforms, transforms);

  @override
  int get hashCode =>
      Object.hash(topologyId, scope, Object.hashAll(transforms));
}

// Throws ArgumentError when [edges] break a rule of a well-formed definition
// (topology-ir@v1 G6): each stage input names an earlier stage edge, no stage
// edge follows a sink edge, every stage edge is consumed by a later edge, and
// no state topic has a second sink edge.
void _checkWellFormed(List<TransformEdge> edges) {
  final Set<int> consumed = <int>{};
  final Set<TopicRef> stateSinks = <TopicRef>{};
  bool sinkSeen = false;
  for (int i = 0; i < edges.length; i++) {
    final TransformEdge edge = edges[i];
    for (final EdgeInput input in edge.inputs) {
      if (input case StageInput(edge: final int stage)) {
        // A negative index is reachable only without assertions.
        if (stage < 0 || stage >= i) {
          throw ArgumentError.value(
            stage,
            'transforms',
            'edge $i takes the output of edge $stage, which is not an '
                'earlier edge',
          );
        }
        if (edges[stage].isSink) {
          throw ArgumentError.value(
            stage,
            'transforms',
            'edge $i takes the output of edge $stage, which is a sink edge',
          );
        }
        consumed.add(stage);
      }
    }
    if (edge.output case final TopicRef output) {
      sinkSeen = true;
      if (output.variant == TopicVariant.state && !stateSinks.add(output)) {
        throw ArgumentError.value(
          output.name,
          'transforms',
          'edge $i is a second sink edge on a state topic',
        );
      }
    } else if (sinkSeen) {
      throw ArgumentError.value(
        i,
        'transforms',
        'edge $i is a stage edge after a sink edge',
      );
    }
  }
  for (int i = 0; i < edges.length; i++) {
    if (!edges[i].isSink && !consumed.contains(i)) {
      throw ArgumentError.value(
        i,
        'transforms',
        'edge $i is a stage edge that no later edge consumes',
      );
    }
  }
}
