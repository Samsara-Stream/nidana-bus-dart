part of 'topology.dart';

// The stage classes: each final, extending TopicStream, no public
// constructor. Every member holds the value the declaration passed,
// identical to it (G11).

final class ReadStage<T> extends TopicStream<T> {
  ReadStage._(super.builder, this.topic, this.dedup) : super._();

  final Topic<T> topic;
  final Dedup? dedup; // as given; null keeps the topic's

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.read<T>(this);
}

final class MapStage<T, R> extends TopicStream<R> {
  MapStage._(super.builder, this.input, this.transform) : super._();

  final TopicStream<T> input;
  final R Function(T value) transform;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.map<T, R>(this);
}

final class FilterStage<T> extends TopicStream<T> {
  FilterStage._(super.builder, this.input, this.test) : super._();

  final TopicStream<T> input;
  final bool Function(T value) test;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.filter<T>(this);
}

/// combine2, combine3, combine4 and combineAll.
final class CombineStage<R> extends TopicStream<R> {
  CombineStage._(super.builder, this.inputs, this.combiner, this._apply)
    : super._();

  final List<TopicStream<Object?>> inputs; // unmodifiable, in input order
  final Function combiner; // the function the declaration passed

  // combiner, called at the type arguments of the builder call that made
  // this stage.
  final R Function(List<Object?> values) _apply;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.combine<R>(this);

  /// Calls combiner with [values], the inputs' latest payloads in input order.
  R apply(List<Object?> values) {
    if (values.length != inputs.length) {
      throw ArgumentError.value(
        values,
        'values',
        'holds ${values.length} values for ${inputs.length} inputs',
      );
    }
    return _apply(values);
  }
}

/// withLatestFrom, withLatestFrom2 and withLatestFrom3.
final class WithLatestFromStage<T, R> extends TopicStream<R> {
  WithLatestFromStage._(
    super.builder,
    this.primary,
    this.latest,
    this.combiner,
    this._apply,
  ) : super._();

  final TopicStream<T> primary;
  final List<TopicStream<Object?>> latest; // unmodifiable, in argument order
  final Function combiner;

  // combiner, called at the type arguments of the handle call that made
  // this stage.
  final R Function(T value, List<Object?> latest) _apply;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.withLatestFrom<T, R>(this);

  R apply(T value, List<Object?> latest) {
    if (latest.length != this.latest.length) {
      throw ArgumentError.value(
        latest,
        'latest',
        'holds ${latest.length} values for ${this.latest.length} inputs',
      );
    }
    return _apply(value, latest);
  }
}

final class MergeStage<T> extends TopicStream<T> {
  MergeStage._(super.builder, this.inputs) : super._();

  final List<TopicStream<T>> inputs; // unmodifiable

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.merge<T>(this);
}

final class SwitchMapStage<T, R> extends TopicStream<R> {
  SwitchMapStage._(super.builder, this.input, this.toStream, this.retry)
    : super._();

  final TopicStream<T> input;
  final Stream<R> Function(T value) toStream;
  final RetryPolicy? retry;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.switchMap<T, R>(this);
}

final class ScanStage<T, S> extends TopicStream<S> {
  ScanStage._(super.builder, this.input, this.initial, this.accumulator)
    : super._();

  final TopicStream<T> input;
  final S initial;
  final S Function(S accumulated, T value) accumulator;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.scan<T, S>(this);
}

final class PairwiseStage<T> extends TopicStream<({T previous, T current})> {
  PairwiseStage._(super.builder, this.input) : super._();

  final TopicStream<T> input;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.pairwise<T>(this);
}

final class DistinctUntilChangedStage<T> extends TopicStream<T> {
  DistinctUntilChangedStage._(super.builder, this.input) : super._();

  final TopicStream<T> input;

  @override
  V _accept<V>(StageVisitor<V> visitor) =>
      visitor.distinctUntilChanged<T>(this);
}

final class DebounceStage<T> extends TopicStream<T> {
  DebounceStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.debounce<T>(this);
}

final class ThrottleStage<T> extends TopicStream<T> {
  ThrottleStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.throttle<T>(this);
}

final class DelayStage<T> extends TopicStream<T> {
  DelayStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.delay<T>(this);
}

final class SampleStage<T> extends TopicStream<T> {
  SampleStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.sample<T>(this);
}

final class BufferStage<T> extends TopicStream<List<T>> {
  BufferStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.buffer<T>(this);
}

final class TimeoutStage<T> extends TopicStream<T> {
  TimeoutStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.timeout<T>(this);
}

final class CatchErrorStage<T> extends TopicStream<T> {
  CatchErrorStage._(super.builder, this.input, this.recover) : super._();

  final TopicStream<T> input;
  final T Function(Object error, StackTrace stackTrace) recover;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.catchError<T>(this);
}

final class RawEngineStage<T, R> extends TopicStream<R> {
  RawEngineStage._(super.builder, this.input, this.operator) : super._();

  final TopicStream<T> input;
  final RawOperator<T, R> operator;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.rawEngine<T, R>(this);
}
