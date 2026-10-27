// The projection of a recorded plan to its definition (topology-ir@v1, From
// a plan), behind TopologyPlan.definition and buildDefinition()
// (topology-dsl@v2 G9, G10 and G12; topology-ir@v1 G8). It reads a plan's
// handles, topics, functions and durations through one stage and sink
// visitor, and calls none of the functions: FunctionRef.of reads a
// function's rendering only.
import '../topic/topic.dart';
import '../topology/topology.dart';
import 'definition.dart';
import 'function_ref.dart';

/// The definition [plan] projects to by topology-ir@v1's five From a plan
/// rules: one stage edge per non-read stage, in stage order, then one sink
/// edge per sink, in sink order. Throws TopologyDefinition's ArgumentError
/// when the edges are not well formed, which a plan that planOf accepted
/// makes only with sinks on two state topics whose value types render alike.
TopologyDefinition projectPlan(TopologyPlan plan) {
  final _Projection projection = _Projection();
  for (final TopicStream<Object?> stage in plan.stages) {
    projection.addStage(stage);
  }
  for (final PlanSink sink in plan.sinks) {
    projection.addSink(sink);
  }
  return TopologyDefinition(
    topologyId: plan.topologyId,
    scope: plan.scope,
    transforms: projection.edges,
  );
}

// The edges of the stages and sinks it is given, in that order (rules 1 to
// 5). Each visitor method runs with the stage's or sink's own type
// arguments, so it reads a function-typed member at its declared type.
final class _Projection
    implements StageVisitor<TransformEdge?>, SinkVisitor<TransformEdge> {
  // The edges so far: the stage edges, then the sink edges.
  final List<TransformEdge> edges = <TransformEdge>[];

  // The index of each non-read stage's edge, keyed by identity: stages keep
  // Object's == (topology-dsl@v2 G30).
  final Map<TopicStream<Object?>, int> _edgeOf =
      Map<TopicStream<Object?>, int>.identity();

  // Rule 1: a non-read stage adds its edge; a read stage adds none.
  void addStage(TopicStream<Object?> stage) {
    if (visitStage(stage, this) case final TransformEdge edge) {
      _edgeOf[stage] = edges.length;
      edges.add(edge);
    }
  }

  // Rules 1 and 5: a sink adds its sink edge.
  void addSink(PlanSink sink) => edges.add(visitSink(sink, this));

  // Rule 2: a read handle is a topic input with the read's dedup argument;
  // any other handle is the index of its stage's edge, which a plan lists
  // before every stage or sink that takes the handle.
  EdgeInput _input(TopicStream<Object?> handle) => switch (handle) {
    ReadStage<Object?>(:final Topic<Object?> topic, :final Dedup? dedup) =>
      TopicInput(topic.ref, dedup: dedup),
    _ => StageInput(_edgeOf[handle]!),
  };

  // Rules 3 and 4 for a stage of one input: its kind, its input, and its
  // function or duration, when it holds one.
  TransformEdge _single(
    CombinatorKind combinator,
    TopicStream<Object?> input, {
    Function? function,
    Duration? duration,
  }) => TransformEdge.stage(
    combinator,
    <EdgeInput>[_input(input)],
    transformer: function == null ? null : FunctionRef.of(function),
    duration: duration,
  );

  @override
  TransformEdge? read<T>(ReadStage<T> stage) => null;

  @override
  TransformEdge map<T, R>(MapStage<T, R> stage) =>
      _single(CombinatorKind.map, stage.input, function: stage.transform);

  @override
  TransformEdge filter<T>(FilterStage<T> stage) =>
      _single(CombinatorKind.filter, stage.input, function: stage.test);

  // The declared combiner, never apply, which is a closure over it.
  @override
  TransformEdge combine<R>(CombineStage<R> stage) => TransformEdge.stage(
    CombinatorKind.combine,
    <EdgeInput>[for (final TopicStream<Object?> i in stage.inputs) _input(i)],
    transformer: FunctionRef.of(stage.combiner),
  );

  // The primary first, then the latest inputs in argument order.
  @override
  TransformEdge withLatestFrom<T, R>(WithLatestFromStage<T, R> stage) =>
      TransformEdge.stage(CombinatorKind.withLatestFrom, <EdgeInput>[
        _input(stage.primary),
        for (final TopicStream<Object?> i in stage.latest) _input(i),
      ], transformer: FunctionRef.of(stage.combiner));

  @override
  TransformEdge merge<T>(MergeStage<T> stage) => TransformEdge.stage(
    CombinatorKind.merge,
    <EdgeInput>[for (final TopicStream<Object?> i in stage.inputs) _input(i)],
  );

  @override
  TransformEdge switchMap<T, R>(SwitchMapStage<T, R> stage) =>
      TransformEdge.stage(
        CombinatorKind.switchMap,
        <EdgeInput>[_input(stage.input)],
        transformer: FunctionRef.of(stage.toStream),
        retry: switch (stage.retry) {
          final RetryPolicy retry => FunctionRef.of(retry),
          null => null,
        },
      );

  @override
  TransformEdge scan<T, S>(ScanStage<T, S> stage) =>
      _single(CombinatorKind.scan, stage.input, function: stage.accumulator);

  @override
  TransformEdge pairwise<T>(PairwiseStage<T> stage) =>
      _single(CombinatorKind.pairwise, stage.input);

  @override
  TransformEdge distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage) =>
      _single(CombinatorKind.distinctUntilChanged, stage.input);

  @override
  TransformEdge debounce<T>(DebounceStage<T> stage) =>
      _single(CombinatorKind.debounce, stage.input, duration: stage.duration);

  @override
  TransformEdge throttle<T>(ThrottleStage<T> stage) =>
      _single(CombinatorKind.throttle, stage.input, duration: stage.duration);

  @override
  TransformEdge delay<T>(DelayStage<T> stage) =>
      _single(CombinatorKind.delay, stage.input, duration: stage.duration);

  @override
  TransformEdge sample<T>(SampleStage<T> stage) =>
      _single(CombinatorKind.sample, stage.input, duration: stage.duration);

  @override
  TransformEdge buffer<T>(BufferStage<T> stage) =>
      _single(CombinatorKind.buffer, stage.input, duration: stage.duration);

  @override
  TransformEdge timeout<T>(TimeoutStage<T> stage) =>
      _single(CombinatorKind.timeout, stage.input, duration: stage.duration);

  @override
  TransformEdge catchError<T>(CatchErrorStage<T> stage) =>
      _single(CombinatorKind.catchError, stage.input, function: stage.recover);

  @override
  TransformEdge rawEngine<T, R>(RawEngineStage<T, R> stage) =>
      _single(CombinatorKind.rawEngine, stage.input, function: stage.operator);

  @override
  TransformEdge write<T>(WriteSink<T> sink) =>
      TransformEdge.write(sink.topic.ref, _input(sink.input));

  @override
  TransformEdge reduceInto<S, E>(ReduceIntoSink<S, E> sink) =>
      TransformEdge.reduceInto(
        sink.topic.ref,
        _input(sink.events),
        FunctionRef.of(sink.reducer),
      );
}
