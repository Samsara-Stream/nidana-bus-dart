part of 'topology.dart';

/// The only builder (Spec §6.5): it records the declaration into a plan.
/// Final, no public constructor; planOf creates one per call.
final class TopologyBuilder {
  TopologyBuilder._();

  /// A read of [topic] (Spec §6.1). [dedup] overrides a StateTopic's own
  /// policy for this read only (Spec §3.12); null keeps it. A non-null
  /// [dedup] on an EventTopic or ReplayTopic read throws ArgumentError.
  TopicStream<T> read<T>(Topic<T> topic, {Dedup? dedup}) =>
      throw UnimplementedError();

  /// Writes every value of [stream] to [topic]: one write chain (Errors and
  /// lineage). The stream's value type is the topic's or a subtype of it (G3).
  void write<T, S extends T>(Topic<T> topic, TopicStream<S> stream) =>
      throw UnimplementedError();

  /// Folds [events] into [topic], which this topology then owns, seeded with
  /// the topic's current value when the activation connects (Spec §6.3,
  /// §7.2): one write chain (Errors and lineage).
  void reduceInto<S, E>(
    StateTopic<S> topic,
    TopicStream<E> events,
    S Function(S state, E event) reducer,
  ) => throw UnimplementedError();

  TopicStream<R> combine2<A, B, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    R Function(A a, B b) combiner,
  ) => throw UnimplementedError();
  TopicStream<R> combine3<A, B, C, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(A a, B b, C c) combiner,
  ) => throw UnimplementedError();
  TopicStream<R> combine4<A, B, C, D, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(A a, B b, C c, D d) combiner,
  ) => throw UnimplementedError();

  /// [combiner] receives an unmodifiable list of the inputs' latest values,
  /// in input order. Throws ArgumentError for an empty [inputs].
  TopicStream<R> combineAll<T, R>(
    List<TopicStream<T>> inputs,
    R Function(List<T> values) combiner,
  ) => throw UnimplementedError();

  /// Throws ArgumentError for an empty [inputs].
  TopicStream<T> merge<T>(List<TopicStream<T>> inputs) =>
      throw UnimplementedError();
}
