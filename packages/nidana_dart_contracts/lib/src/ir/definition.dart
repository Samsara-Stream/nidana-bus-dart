import 'package:meta/meta.dart';

import '../topic/scope.dart';
import '../topic/topic.dart';
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
}

/// The values the stage edge at index [edge] of the same definition's
/// transforms emits. [edge] is asserted non-negative.
final class StageInput extends EdgeInput {
  const StageInput(this.edge)
    : assert(edge >= 0, 'edge must not be negative'),
      super._();

  final int edge;
}

/// One element of a topology's wiring other than a read (Spec §6.5): a stage
/// edge, whose values only later edges consume, or a sink edge, whose values
/// are published to [output]. No public unnamed constructor.
@immutable
final class TransformEdge {
  // The three factories construct through this once nidana.model.10 lands
  // them.
  // ignore: unused_element
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
  }) => throw UnimplementedError();

  /// A write: [input]'s values published to [topic] unchanged.
  factory TransformEdge.write(TopicRef topic, EdgeInput input) =>
      throw UnimplementedError();

  /// A reduceInto folding [events] into [topic] with [reducer]. Throws
  /// ArgumentError unless [topic] is a state topic.
  factory TransformEdge.reduceInto(
    TopicRef topic,
    EdgeInput events,
    FunctionRef reducer,
  ) => throw UnimplementedError();

  final CombinatorKind? combinator; // null exactly for a write
  final List<EdgeInput> inputs; // unmodifiable copy, in input order
  final TopicRef? output; // a sink's topic; null for a stage
  final FunctionRef? transformer; // the edge's function, when it holds one
  final Duration? duration; // the six time stages only
  final FunctionRef? retry; // a switchMap with a retry policy only
  bool get isSink => throw UnimplementedError(); // output != null
  bool get isStateBearing =>
      throw UnimplementedError(); // Spec §3.8; the rule below
}

/// The IR of one topology (Spec §6.5, Appendix A.4).
@immutable
final class TopologyDefinition {
  // The factory constructs through this once nidana.model.10 lands it.
  // ignore: unused_element
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
  }) => throw UnimplementedError();

  final String topologyId;
  final Scope scope;
  // the topics of every TopicInput; canonical order; unmodifiable
  final Set<TopicRef> reads;
  // the outputs of the sink edges; canonical order; unmodifiable
  final Set<TopicRef> writes;
  final List<TransformEdge> transforms; // unmodifiable copy
}
