part of 'topology.dart';

/// Runs topology.declare once against a fresh builder and returns its plan.
/// Throws StateError when topologyId is empty or a stage reaches no sink;
/// an error declare throws, a builder's ArgumentError included, propagates.
TopologyPlan planOf(Topology topology) {
  final String topologyId = topology.topologyId;
  if (topologyId.isEmpty) {
    throw StateError(
      'planOf: ${topology.runtimeType} has an empty topologyId (Spec §4.6).',
    );
  }
  final TopologyBuilder builder = TopologyBuilder._();
  try {
    topology.declare(builder);
  } finally {
    builder._open = false;
  }
  return builder._plan(topologyId, topology.scope);
}

/// The executable form of one declaration (Spec §6.5).
@immutable
final class TopologyPlan {
  TopologyPlan._(this.topologyId, this.scope, this.stages, this.sinks);

  final String topologyId;
  final Scope scope;

  /// Every stage, in the order the declaration created them; unmodifiable.
  /// A stage's inputs precede it.
  final List<TopicStream<Object?>> stages;

  /// Every write and reduceInto, in declaration order; unmodifiable.
  final List<PlanSink> sinks;

  /// The IR projected from this plan (topology-ir@v1); equal to
  /// topology.buildDefinition() for a deterministic declaration.
  TopologyDefinition get definition => projectPlan(this);
}

/// Passes [stage] to the visitor method of its class, binding the stage's
/// type arguments; likewise visitSink.
V visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor) =>
    stage._accept(visitor);
V visitSink<V>(PlanSink sink, SinkVisitor<V> visitor) => sink._accept(visitor);

/// Implemented by a live implementation's interpreter, and by any reader
/// that needs a stage's type arguments.
abstract interface class StageVisitor<V> {
  V read<T>(ReadStage<T> stage);
  V map<T, R>(MapStage<T, R> stage);
  V filter<T>(FilterStage<T> stage);
  V combine<R>(CombineStage<R> stage);
  V withLatestFrom<T, R>(WithLatestFromStage<T, R> stage);
  V merge<T>(MergeStage<T> stage);
  V switchMap<T, R>(SwitchMapStage<T, R> stage);
  V scan<T, S>(ScanStage<T, S> stage);
  V pairwise<T>(PairwiseStage<T> stage);
  V distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage);
  V debounce<T>(DebounceStage<T> stage);
  V throttle<T>(ThrottleStage<T> stage);
  V delay<T>(DelayStage<T> stage);
  V sample<T>(SampleStage<T> stage);
  V buffer<T>(BufferStage<T> stage);
  V timeout<T>(TimeoutStage<T> stage);
  V catchError<T>(CatchErrorStage<T> stage);
  V rawEngine<T, R>(RawEngineStage<T, R> stage);
}

abstract interface class SinkVisitor<V> {
  V write<T>(WriteSink<T> sink);
  V reduceInto<S, E>(ReduceIntoSink<S, E> sink);
}
