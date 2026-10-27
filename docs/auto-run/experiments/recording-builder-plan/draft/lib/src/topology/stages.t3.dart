part of 'topology.dart';

// The stage classes: each final, extending TopicStream, no public
// constructor. Every member holds the value the declaration passed,
// identical to it (G11).

final class ReadStage<T> extends TopicStream<T> {
  ReadStage._(super.builder, this.topic, this.dedup) : super._();

  final Topic<T> topic;
  final Dedup? dedup; // as given; null keeps the topic's
}

final class MapStage<T, R> extends TopicStream<R> {
  MapStage._(super.builder, this.input, this.transform) : super._();

  final TopicStream<T> input;
  final R Function(T value) transform;
}

final class FilterStage<T> extends TopicStream<T> {
  FilterStage._(super.builder, this.input, this.test) : super._();

  final TopicStream<T> input;
  final bool Function(T value) test;
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
}

final class SwitchMapStage<T, R> extends TopicStream<R> {
  SwitchMapStage._(super.builder, this.input, this.toStream, this.retry)
    : super._();

  final TopicStream<T> input;
  final Stream<R> Function(T value) toStream;
  final RetryPolicy? retry;
}

final class ScanStage<T, S> extends TopicStream<S> {
  ScanStage._(super.builder, this.input, this.initial, this.accumulator)
    : super._();

  final TopicStream<T> input;
  final S initial;
  final S Function(S accumulated, T value) accumulator;
}

final class PairwiseStage<T> extends TopicStream<({T previous, T current})> {
  PairwiseStage._(super.builder, this.input) : super._();

  final TopicStream<T> input;
}

final class DistinctUntilChangedStage<T> extends TopicStream<T> {
  DistinctUntilChangedStage._(super.builder, this.input) : super._();

  final TopicStream<T> input;
}

final class DebounceStage<T> extends TopicStream<T> {
  DebounceStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class ThrottleStage<T> extends TopicStream<T> {
  ThrottleStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class DelayStage<T> extends TopicStream<T> {
  DelayStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class SampleStage<T> extends TopicStream<T> {
  SampleStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class BufferStage<T> extends TopicStream<List<T>> {
  BufferStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class TimeoutStage<T> extends TopicStream<T> {
  TimeoutStage._(super.builder, this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class CatchErrorStage<T> extends TopicStream<T> {
  CatchErrorStage._(super.builder, this.input, this.recover) : super._();

  final TopicStream<T> input;
  final T Function(Object error, StackTrace stackTrace) recover;
}

final class RawEngineStage<T, R> extends TopicStream<R> {
  RawEngineStage._(super.builder, this.input, this.operator) : super._();

  final TopicStream<T> input;
  final RawOperator<T, R> operator;
}
