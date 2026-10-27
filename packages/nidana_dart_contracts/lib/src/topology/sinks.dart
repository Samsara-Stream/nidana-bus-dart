part of 'topology.dart';

/// A write or a reduceInto. Sealed; no public constructor.
sealed class PlanSink {
  PlanSink._();

  Topic<Object?> get topic;
}

final class WriteSink<T> extends PlanSink {
  WriteSink._(this.topic, this.input) : super._();

  @override
  final Topic<T> topic;
  final TopicStream<T> input;
}

final class ReduceIntoSink<S, E> extends PlanSink {
  ReduceIntoSink._(this.topic, this.events, this.reducer) : super._();

  @override
  final StateTopic<S> topic;
  final TopicStream<E> events;
  final S Function(S state, E event) reducer;
}
