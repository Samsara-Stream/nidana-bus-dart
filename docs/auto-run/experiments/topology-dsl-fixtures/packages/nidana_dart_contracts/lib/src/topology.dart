/// Stand-in for the topology-dsl@v1 part of `nidana_dart_contracts`.
///
/// Throwaway experiment code: it implements the Interface of
/// hsdd/contract/topology-dsl.md as directly as possible so that the
/// contract's surface, reject and behavior fixtures can be replayed before the
/// real package exists. It is not the real package.
///
/// One library on purpose: TopicStream is sealed, so every stage class lives
/// here; the package's two public libraries export disjoint parts of it.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'topic_model.dart';
import 'topology_ir.dart';

// ------------------------------------------------------------ values

/// A value inside a live pipeline: its payload and the lineage its next
/// published envelope will carry (Spec §3.5; topic-model@v1 Lineage).
typedef PipelineValue<T> = ({T payload, Lineage lineage});

/// switchMap's retry policy: the delay before toStream is called again after
/// the inner stream's [attempt]-th error (1-based), or null to let it through.
typedef RetryPolicy = Duration? Function(Object error, int attempt);

/// The raw-engine escape hatch's operator (Spec §3.5 "Escape Hatch").
typedef RawOperator<T, R> = Stream<PipelineValue<R>> Function(
  Stream<PipelineValue<T>> values,
  String Function() freshCorrelationId,
);

/// A typed, module-local topology identifier (Spec §4.6).
@immutable
final class TopologyRef {
  const TopologyRef(this.id);
  final String id;

  @override
  bool operator ==(Object other) => other is TopologyRef && other.id == id;

  @override
  int get hashCode => Object.hash(TopologyRef, id);

  @override
  String toString() => 'TopologyRef($id)';
}

// ------------------------------------------------------------ topology

/// A topology in class form (Spec §6.1, Guide §6.3).
@immutable
abstract base class Topology {
  const Topology();

  String get topologyId;
  Scope get scope;

  /// Pure wiring (Spec §6.1).
  void declare(TopologyBuilder b);

  /// The IR of this topology (Spec §6.5): `planOf(this).definition`.
  @nonVirtual
  TopologyDefinition buildDefinition() => planOf(this).definition;
}

/// The builder shorthand (Spec §6.1).
Topology topology(
  String topologyId,
  Scope scope,
  void Function(TopologyBuilder b) declare,
) {
  if (topologyId.isEmpty) {
    throw ArgumentError.value(topologyId, 'topologyId', 'must not be empty');
  }
  return _FunctionTopology(topologyId, scope, declare);
}

final class _FunctionTopology extends Topology {
  const _FunctionTopology(this.topologyId, this.scope, this._declare);

  @override
  final String topologyId;

  @override
  final Scope scope;

  final void Function(TopologyBuilder b) _declare;

  @override
  void declare(TopologyBuilder b) => _declare(b);
}

// ------------------------------------------------------------ builder

/// The only builder: it records the declaration as a plan (Spec §6.5).
final class TopologyBuilder {
  TopologyBuilder._();

  final List<TopicStream<Object?>> _stages = <TopicStream<Object?>>[];
  final List<PlanSink> _sinks = <PlanSink>[];
  final Set<Topic<Object?>> _stateSinks = <Topic<Object?>>{};
  bool _open = true;

  void _checkOpen() {
    if (!_open) {
      throw StateError('the declaration has returned; a builder and its '
          'handles record only while declare runs');
    }
  }

  void _own(TopicStream<Object?> stream, String name) {
    if (!identical(stream._builder, this)) {
      throw ArgumentError.value(
          stream, name, 'is a handle made by another declaration');
    }
  }

  void _ownAll(List<TopicStream<Object?>> streams, String name) {
    for (final s in streams) {
      _own(s, name);
    }
  }

  S _add<S extends TopicStream<Object?>>(S stage) {
    _stages.add(stage);
    return stage;
  }

  void _claim(Topic<Object?> topic) {
    if (topic is StateTopic<Object?> && !_stateSinks.add(topic)) {
      throw ArgumentError.value(topic, 'topic',
          'already has a sink in this declaration (write or reduceInto)');
    }
  }

  TopicStream<T> read<T>(Topic<T> topic, {Dedup? dedup}) {
    _checkOpen();
    if (dedup != null && topic is! StateTopic<Object?>) {
      throw ArgumentError.value(
          dedup, 'dedup', 'applies to a StateTopic read only');
    }
    return _add(ReadStage<T>._(this, topic, dedup));
  }

  void write<T, S extends T>(Topic<T> topic, TopicStream<S> stream) {
    _checkOpen();
    _own(stream, 'stream');
    _claim(topic);
    _sinks.add(WriteSink<T>._(topic, stream));
  }

  void reduceInto<S, E>(
    StateTopic<S> topic,
    TopicStream<E> events,
    S Function(S state, E event) reducer,
  ) {
    _checkOpen();
    _own(events, 'events');
    _claim(topic);
    _sinks.add(ReduceIntoSink<S, E>._(topic, events, reducer));
  }

  TopicStream<R> combine2<A, B, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    R Function(A a, B b) combiner,
  ) =>
      _combine<R>(<TopicStream<Object?>>[a, b], combiner,
          (v) => combiner(v[0] as A, v[1] as B));

  TopicStream<R> combine3<A, B, C, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(A a, B b, C c) combiner,
  ) =>
      _combine<R>(<TopicStream<Object?>>[a, b, c], combiner,
          (v) => combiner(v[0] as A, v[1] as B, v[2] as C));

  TopicStream<R> combine4<A, B, C, D, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(A a, B b, C c, D d) combiner,
  ) =>
      _combine<R>(<TopicStream<Object?>>[a, b, c, d], combiner,
          (v) => combiner(v[0] as A, v[1] as B, v[2] as C, v[3] as D));

  TopicStream<R> combineAll<T, R>(
    List<TopicStream<T>> inputs,
    R Function(List<T> values) combiner,
  ) {
    _checkOpen();
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
    }
    return _combine<R>(inputs, combiner,
        (v) => combiner(List<T>.unmodifiable(v.cast<T>())));
  }

  TopicStream<R> _combine<R>(
    List<TopicStream<Object?>> inputs,
    Function combiner,
    R Function(List<Object?> values) apply,
  ) {
    _checkOpen();
    _ownAll(inputs, 'inputs');
    return _add(CombineStage<R>._(this, inputs, combiner, apply));
  }

  TopicStream<T> merge<T>(List<TopicStream<T>> inputs) {
    _checkOpen();
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
    }
    _ownAll(inputs, 'inputs');
    return _add(MergeStage<T>._(this, inputs));
  }
}

void _checkDuration(Duration duration) {
  if (duration.isNegative) {
    throw ArgumentError.value(duration, 'duration', 'must not be negative');
  }
}

// ------------------------------------------------------------ handle

/// The opaque stream handle (Spec §6.1). Every handle is a stage of the plan.
sealed class TopicStream<T> {
  TopicStream._(this._builder);

  final TopologyBuilder _builder;

  List<TopicStream<Object?>> get _inputs;

  V _accept<V>(StageVisitor<V> visitor);

  S _next<S extends TopicStream<Object?>>(S Function() make) {
    _builder._checkOpen();
    return _builder._add(make());
  }

  TopicStream<R> map<R>(R Function(T value) transform) =>
      _next(() => MapStage<T, R>._(_builder, this, transform));

  TopicStream<T> filter(bool Function(T value) test) =>
      _next(() => FilterStage<T>._(_builder, this, test));

  TopicStream<R> withLatestFrom<B, R>(
    TopicStream<B> latest,
    R Function(T value, B latest) combiner,
  ) =>
      _withLatest<R>(<TopicStream<Object?>>[latest], combiner,
          (t, v) => combiner(t, v[0] as B));

  TopicStream<R> withLatestFrom2<B, C, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(T value, B b, C c) combiner,
  ) =>
      _withLatest<R>(<TopicStream<Object?>>[b, c], combiner,
          (t, v) => combiner(t, v[0] as B, v[1] as C));

  TopicStream<R> withLatestFrom3<B, C, D, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(T value, B b, C c, D d) combiner,
  ) =>
      _withLatest<R>(<TopicStream<Object?>>[b, c, d], combiner,
          (t, v) => combiner(t, v[0] as B, v[1] as C, v[2] as D));

  TopicStream<R> _withLatest<R>(
    List<TopicStream<Object?>> latest,
    Function combiner,
    R Function(T value, List<Object?> latest) apply,
  ) {
    _builder._checkOpen();
    _builder._ownAll(latest, 'latest');
    return _builder._add(
        WithLatestFromStage<T, R>._(_builder, this, latest, combiner, apply));
  }

  TopicStream<R> switchMap<R>(
    Stream<R> Function(T value) toStream, {
    RetryPolicy? retry,
  }) =>
      _next(() => SwitchMapStage<T, R>._(_builder, this, toStream, retry));

  TopicStream<S> scan<S>(
    S initial,
    S Function(S accumulated, T value) accumulator,
  ) =>
      _next(() => ScanStage<T, S>._(_builder, this, initial, accumulator));

  TopicStream<({T previous, T current})> pairwise() =>
      _next(() => PairwiseStage<T>._(_builder, this));

  TopicStream<T> distinctUntilChanged() =>
      _next(() => DistinctUntilChangedStage<T>._(_builder, this));

  TopicStream<T> debounce(Duration duration) {
    _checkDuration(duration);
    return _next(() => DebounceStage<T>._(_builder, this, duration));
  }

  TopicStream<T> throttle(Duration duration) {
    _checkDuration(duration);
    return _next(() => ThrottleStage<T>._(_builder, this, duration));
  }

  TopicStream<T> delay(Duration duration) {
    _checkDuration(duration);
    return _next(() => DelayStage<T>._(_builder, this, duration));
  }

  TopicStream<T> sample(Duration duration) {
    _checkDuration(duration);
    return _next(() => SampleStage<T>._(_builder, this, duration));
  }

  TopicStream<List<T>> buffer(Duration duration) {
    _checkDuration(duration);
    return _next(() => BufferStage<T>._(_builder, this, duration));
  }

  TopicStream<T> timeout(Duration duration) {
    _checkDuration(duration);
    return _next(() => TimeoutStage<T>._(_builder, this, duration));
  }

  TopicStream<T> catchError(
    T Function(Object error, StackTrace stackTrace) recover,
  ) =>
      _next(() => CatchErrorStage<T>._(_builder, this, recover));

  TopicStream<R> rawEngine<R>(RawOperator<T, R> operator) =>
      _next(() => RawEngineStage<T, R>._(_builder, this, operator));
}

// ------------------------------------------------------------ stages

final class ReadStage<T> extends TopicStream<T> {
  ReadStage._(super._builder, this.topic, this.dedup) : super._();
  final Topic<T> topic;
  final Dedup? dedup;
  @override
  List<TopicStream<Object?>> get _inputs => const <TopicStream<Object?>>[];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.read<T>(this);
}

final class MapStage<T, R> extends TopicStream<R> {
  MapStage._(super._builder, this.input, this.transform) : super._();
  final TopicStream<T> input;
  final R Function(T value) transform;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.map<T, R>(this);
}

final class FilterStage<T> extends TopicStream<T> {
  FilterStage._(super._builder, this.input, this.test) : super._();
  final TopicStream<T> input;
  final bool Function(T value) test;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.filter<T>(this);
}

final class CombineStage<R> extends TopicStream<R> {
  CombineStage._(
    super._builder,
    List<TopicStream<Object?>> inputs,
    this.combiner,
    this._apply,
  )   : inputs = List<TopicStream<Object?>>.unmodifiable(inputs),
        super._();
  final List<TopicStream<Object?>> inputs;
  final Function combiner;
  final R Function(List<Object?> values) _apply;

  /// Calls [combiner] with [values], the inputs' latest payloads in input order.
  R apply(List<Object?> values) => _apply(values);

  @override
  List<TopicStream<Object?>> get _inputs => inputs;
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.combine<R>(this);
}

final class WithLatestFromStage<T, R> extends TopicStream<R> {
  WithLatestFromStage._(
    super._builder,
    this.primary,
    List<TopicStream<Object?>> latest,
    this.combiner,
    this._apply,
  )   : latest = List<TopicStream<Object?>>.unmodifiable(latest),
        super._();
  final TopicStream<T> primary;
  final List<TopicStream<Object?>> latest;
  final Function combiner;
  final R Function(T value, List<Object?> latest) _apply;

  /// Calls [combiner] with the primary's [value] and the latest inputs'
  /// payloads in order.
  R apply(T value, List<Object?> latest) => _apply(value, latest);

  @override
  List<TopicStream<Object?>> get _inputs =>
      <TopicStream<Object?>>[primary, ...latest];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.withLatestFrom<T, R>(this);
}

final class MergeStage<T> extends TopicStream<T> {
  MergeStage._(super._builder, List<TopicStream<T>> inputs)
      : inputs = List<TopicStream<T>>.unmodifiable(inputs),
        super._();
  final List<TopicStream<T>> inputs;
  @override
  List<TopicStream<Object?>> get _inputs => inputs;
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.merge<T>(this);
}

final class SwitchMapStage<T, R> extends TopicStream<R> {
  SwitchMapStage._(super._builder, this.input, this.toStream, this.retry)
      : super._();
  final TopicStream<T> input;
  final Stream<R> Function(T value) toStream;
  final RetryPolicy? retry;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.switchMap<T, R>(this);
}

final class ScanStage<T, S> extends TopicStream<S> {
  ScanStage._(super._builder, this.input, this.initial, this.accumulator)
      : super._();
  final TopicStream<T> input;
  final S initial;
  final S Function(S accumulated, T value) accumulator;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.scan<T, S>(this);
}

final class PairwiseStage<T> extends TopicStream<({T previous, T current})> {
  PairwiseStage._(super._builder, this.input) : super._();
  final TopicStream<T> input;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.pairwise<T>(this);
}

final class DistinctUntilChangedStage<T> extends TopicStream<T> {
  DistinctUntilChangedStage._(super._builder, this.input) : super._();
  final TopicStream<T> input;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) =>
      visitor.distinctUntilChanged<T>(this);
}

final class DebounceStage<T> extends TopicStream<T> {
  DebounceStage._(super._builder, this.input, this.duration) : super._();
  final TopicStream<T> input;
  final Duration duration;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.debounce<T>(this);
}

final class ThrottleStage<T> extends TopicStream<T> {
  ThrottleStage._(super._builder, this.input, this.duration) : super._();
  final TopicStream<T> input;
  final Duration duration;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.throttle<T>(this);
}

final class DelayStage<T> extends TopicStream<T> {
  DelayStage._(super._builder, this.input, this.duration) : super._();
  final TopicStream<T> input;
  final Duration duration;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.delay<T>(this);
}

final class SampleStage<T> extends TopicStream<T> {
  SampleStage._(super._builder, this.input, this.duration) : super._();
  final TopicStream<T> input;
  final Duration duration;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.sample<T>(this);
}

final class BufferStage<T> extends TopicStream<List<T>> {
  BufferStage._(super._builder, this.input, this.duration) : super._();
  final TopicStream<T> input;
  final Duration duration;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.buffer<T>(this);
}

final class TimeoutStage<T> extends TopicStream<T> {
  TimeoutStage._(super._builder, this.input, this.duration) : super._();
  final TopicStream<T> input;
  final Duration duration;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.timeout<T>(this);
}

final class CatchErrorStage<T> extends TopicStream<T> {
  CatchErrorStage._(super._builder, this.input, this.recover) : super._();
  final TopicStream<T> input;
  final T Function(Object error, StackTrace stackTrace) recover;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.catchError<T>(this);
}

final class RawEngineStage<T, R> extends TopicStream<R> {
  RawEngineStage._(super._builder, this.input, this.operator) : super._();
  final TopicStream<T> input;
  final RawOperator<T, R> operator;
  @override
  List<TopicStream<Object?>> get _inputs => <TopicStream<Object?>>[input];
  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.rawEngine<T, R>(this);
}

// ------------------------------------------------------------ sinks

sealed class PlanSink {
  const PlanSink._();
  Topic<Object?> get topic;
  TopicStream<Object?> get _input;
  V _accept<V>(SinkVisitor<V> visitor);
}

final class WriteSink<T> extends PlanSink {
  const WriteSink._(this.topic, this.input) : super._();
  @override
  final Topic<T> topic;
  final TopicStream<T> input;
  @override
  TopicStream<Object?> get _input => input;
  @override
  V _accept<V>(SinkVisitor<V> visitor) => visitor.write<T>(this);
}

final class ReduceIntoSink<S, E> extends PlanSink {
  const ReduceIntoSink._(this.topic, this.events, this.reducer) : super._();
  @override
  final StateTopic<S> topic;
  final TopicStream<E> events;
  final S Function(S state, E event) reducer;
  @override
  TopicStream<Object?> get _input => events;
  @override
  V _accept<V>(SinkVisitor<V> visitor) => visitor.reduceInto<S, E>(this);
}

// ------------------------------------------------------------ visitors

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

V visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor) =>
    stage._accept(visitor);

V visitSink<V>(PlanSink sink, SinkVisitor<V> visitor) => sink._accept(visitor);

// ------------------------------------------------------------ plan

/// The executable form of one declaration (Spec §6.5): what live activation
/// interprets, and what the IR is projected from.
@immutable
final class TopologyPlan {
  TopologyPlan._(
    this.topologyId,
    this.scope,
    List<TopicStream<Object?>> stages,
    List<PlanSink> sinks,
  )   : stages = List<TopicStream<Object?>>.unmodifiable(stages),
        sinks = List<PlanSink>.unmodifiable(sinks);

  final String topologyId;
  final Scope scope;
  final List<TopicStream<Object?>> stages;
  final List<PlanSink> sinks;

  /// The IR (topology-ir@v1), projected from this plan.
  late final TopologyDefinition definition = _project(this);
}

TopologyPlan planOf(Topology topology) {
  final id = topology.topologyId;
  if (id.isEmpty) throw StateError('topologyId must not be empty');
  final b = TopologyBuilder._();
  try {
    topology.declare(b);
  } finally {
    b._open = false;
  }
  final reached = Set<TopicStream<Object?>>.identity();
  void walk(TopicStream<Object?> s) {
    if (!reached.add(s)) return;
    s._inputs.forEach(walk);
  }

  for (final sink in b._sinks) {
    walk(sink._input);
  }
  for (var i = 0; i < b._stages.length; i++) {
    if (!reached.contains(b._stages[i])) {
      throw StateError('stage $i (${b._stages[i].runtimeType}) of topology '
          '"$id" reaches no sink');
    }
  }
  return TopologyPlan._(id, topology.scope, b._stages, b._sinks);
}

final class _Kind implements StageVisitor<CombinatorKind?> {
  const _Kind();
  @override
  CombinatorKind? read<T>(ReadStage<T> s) => null;
  @override
  CombinatorKind map<T, R>(MapStage<T, R> s) => CombinatorKind.map;
  @override
  CombinatorKind filter<T>(FilterStage<T> s) => CombinatorKind.filter;
  @override
  CombinatorKind combine<R>(CombineStage<R> s) => CombinatorKind.combine;
  @override
  CombinatorKind withLatestFrom<T, R>(WithLatestFromStage<T, R> s) =>
      CombinatorKind.withLatestFrom;
  @override
  CombinatorKind merge<T>(MergeStage<T> s) => CombinatorKind.merge;
  @override
  CombinatorKind switchMap<T, R>(SwitchMapStage<T, R> s) =>
      CombinatorKind.switchMap;
  @override
  CombinatorKind scan<T, S>(ScanStage<T, S> s) => CombinatorKind.scan;
  @override
  CombinatorKind pairwise<T>(PairwiseStage<T> s) => CombinatorKind.pairwise;
  @override
  CombinatorKind distinctUntilChanged<T>(DistinctUntilChangedStage<T> s) =>
      CombinatorKind.distinctUntilChanged;
  @override
  CombinatorKind debounce<T>(DebounceStage<T> s) => CombinatorKind.debounce;
  @override
  CombinatorKind throttle<T>(ThrottleStage<T> s) => CombinatorKind.throttle;
  @override
  CombinatorKind delay<T>(DelayStage<T> s) => CombinatorKind.delay;
  @override
  CombinatorKind sample<T>(SampleStage<T> s) => CombinatorKind.sample;
  @override
  CombinatorKind buffer<T>(BufferStage<T> s) => CombinatorKind.buffer;
  @override
  CombinatorKind timeout<T>(TimeoutStage<T> s) => CombinatorKind.timeout;
  @override
  CombinatorKind catchError<T>(CatchErrorStage<T> s) =>
      CombinatorKind.catchError;
  @override
  CombinatorKind rawEngine<T, R>(RawEngineStage<T, R> s) =>
      CombinatorKind.rawEngine;
}

TopologyDefinition _project(TopologyPlan plan) => TopologyDefinition(
      topologyId: plan.topologyId,
      scope: plan.scope,
      reads: <TopicRef>{
        for (final s in plan.stages)
          if (s is ReadStage<Object?>) s.topic.ref,
      },
      writes: <TopicRef>{for (final k in plan.sinks) k.topic.ref},
      transforms: <TransformEdge>[
        for (final s in plan.stages)
          if (visitStage(s, const _Kind()) case final CombinatorKind kind)
            TransformEdge(kind),
        for (final k in plan.sinks)
          if (k is ReduceIntoSink<Object?, Object?>)
            const TransformEdge(CombinatorKind.reduceInto),
      ],
    );
