// Surface fixture for topology-dsl@v2: the plan library, used the way a live
// implementation uses it. StageVisitor and SinkVisitor are implemented in
// full, so a stage or sink class added to the Interface fails this set, and
// every stage's members are read with the types the Interface states.
// Passes when `fvm dart analyze --fatal-infos` reports nothing on it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';

/// Describes every stage the way an interpreter reaches it: through the
/// visitor, which binds the stage's type arguments.
final class Describe implements StageVisitor<String> {
  const Describe();

  @override
  String read<T>(ReadStage<T> stage) {
    final Topic<T> topic = stage.topic;
    final Dedup? dedup = stage.dedup;
    return 'read ${topic.name} ${dedup?.name}';
  }

  @override
  String map<T, R>(MapStage<T, R> stage) {
    final TopicStream<T> input = stage.input;
    final R Function(T value) transform = stage.transform;
    return 'map $input $transform';
  }

  @override
  String filter<T>(FilterStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final bool Function(T value) test = stage.test;
    return 'filter $input $test';
  }

  @override
  String combine<R>(CombineStage<R> stage) {
    final List<TopicStream<Object?>> inputs = stage.inputs;
    final Function combiner = stage.combiner;
    final R Function(List<Object?> values) apply = stage.apply;
    return 'combine ${inputs.length} $combiner $apply';
  }

  @override
  String withLatestFrom<T, R>(WithLatestFromStage<T, R> stage) {
    final TopicStream<T> primary = stage.primary;
    final List<TopicStream<Object?>> latest = stage.latest;
    final Function combiner = stage.combiner;
    final R Function(T value, List<Object?> latest) apply = stage.apply;
    return 'withLatestFrom $primary ${latest.length} $combiner $apply';
  }

  @override
  String merge<T>(MergeStage<T> stage) {
    final List<TopicStream<T>> inputs = stage.inputs;
    return 'merge ${inputs.length}';
  }

  @override
  String switchMap<T, R>(SwitchMapStage<T, R> stage) {
    final TopicStream<T> input = stage.input;
    final Stream<R> Function(T value) toStream = stage.toStream;
    final RetryPolicy? retry = stage.retry;
    return 'switchMap $input $toStream $retry';
  }

  @override
  String scan<T, S>(ScanStage<T, S> stage) {
    final TopicStream<T> input = stage.input;
    final S initial = stage.initial;
    final S Function(S accumulated, T value) accumulator = stage.accumulator;
    return 'scan $input $initial $accumulator';
  }

  @override
  String pairwise<T>(PairwiseStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final TopicStream<({T previous, T current})> self = stage;
    return 'pairwise $input $self';
  }

  @override
  String distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage) {
    final TopicStream<T> input = stage.input;
    return 'distinctUntilChanged $input';
  }

  @override
  String debounce<T>(DebounceStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final Duration duration = stage.duration;
    return 'debounce $input $duration';
  }

  @override
  String throttle<T>(ThrottleStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final Duration duration = stage.duration;
    return 'throttle $input $duration';
  }

  @override
  String delay<T>(DelayStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final Duration duration = stage.duration;
    return 'delay $input $duration';
  }

  @override
  String sample<T>(SampleStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final Duration duration = stage.duration;
    return 'sample $input $duration';
  }

  @override
  String buffer<T>(BufferStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final Duration duration = stage.duration;
    final TopicStream<List<T>> self = stage;
    return 'buffer $input $duration $self';
  }

  @override
  String timeout<T>(TimeoutStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final Duration duration = stage.duration;
    return 'timeout $input $duration';
  }

  @override
  String catchError<T>(CatchErrorStage<T> stage) {
    final TopicStream<T> input = stage.input;
    final T Function(Object error, StackTrace stackTrace) recover =
        stage.recover;
    return 'catchError $input $recover';
  }

  @override
  String rawEngine<T, R>(RawEngineStage<T, R> stage) {
    final TopicStream<T> input = stage.input;
    final RawOperator<T, R> operator = stage.operator;
    return 'rawEngine $input $operator';
  }
}

final class DescribeSink implements SinkVisitor<String> {
  const DescribeSink();

  @override
  String write<T>(WriteSink<T> sink) {
    final Topic<T> topic = sink.topic;
    final TopicStream<T> input = sink.input;
    return 'write ${topic.name} $input';
  }

  @override
  String reduceInto<S, E>(ReduceIntoSink<S, E> sink) {
    final StateTopic<S> topic = sink.topic;
    final TopicStream<E> events = sink.events;
    final S Function(S state, E event) reducer = sink.reducer;
    return 'reduceInto ${topic.name} $events $reducer';
  }
}

/// What a live implementation does at activation: one plan, its definition
/// for the checks, then every stage and every sink in order.
List<String> describe(Topology topology) {
  final TopologyPlan plan = planOf(topology);
  final String id = plan.topologyId;
  final Scope scope = plan.scope;
  final TopologyDefinition definition = plan.definition;
  final List<TopicStream<Object?>> stages = plan.stages;
  final List<PlanSink> sinks = plan.sinks;
  return <String>[
    '$id ${scope.name} ${definition.topologyId}',
    for (final TopicStream<Object?> stage in stages)
      visitStage(stage, const Describe()),
    for (final PlanSink sink in sinks) ...<String>[
      sink.topic.name,
      visitSink(sink, const DescribeSink()),
    ],
  ];
}

/// The plan's sealed families, matched exhaustively.
String kindOf(PlanSink sink) => switch (sink) {
      WriteSink<Object?>() => 'write',
      ReduceIntoSink<Object?, Object?>() => 'reduceInto',
    };
