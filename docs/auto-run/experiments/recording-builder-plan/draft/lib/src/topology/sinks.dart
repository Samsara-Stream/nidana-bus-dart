part of 'topology.dart';

/// A write or a reduceInto. Sealed; no public constructor.
sealed class PlanSink {
  PlanSink._();

  Topic<Object?> get topic;

  // Calls the visitor method of this sink's class with this sink, binding
  // its type arguments (G16).
  V _accept<V>(SinkVisitor<V> visitor);
}

final class WriteSink<T> extends PlanSink {
  WriteSink._(this.topic, this.input) : super._();

  @override
  final Topic<T> topic;
  final TopicStream<T> input;

  @override
  V _accept<V>(SinkVisitor<V> visitor) => visitor.write<T>(this);
}

final class ReduceIntoSink<S, E> extends PlanSink {
  ReduceIntoSink._(this.topic, this.events, this.reducer) : super._();

  @override
  final StateTopic<S> topic;
  final TopicStream<E> events;
  final S Function(S state, E event) reducer;

  @override
  V _accept<V>(SinkVisitor<V> visitor) => visitor.reduceInto<S, E>(this);
}
