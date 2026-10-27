part of 'topology.dart';

/// The opaque stream handle (Spec §6.1): a stage of the plan. Sealed; made
/// only by the builder and by its own methods. It has no synchronous value
/// accessor, is not a Stream and has no listen (G1).
sealed class TopicStream<T> {
  TopicStream._(this._builder);

  // The builder whose declaration made this handle, which records every
  // stage derived from it (G14, G15).
  final TopologyBuilder _builder;

  TopicStream<R> map<R>(R Function(T value) transform) =>
      throw UnimplementedError();
  TopicStream<T> filter(bool Function(T value) test) =>
      throw UnimplementedError();

  TopicStream<R> withLatestFrom<B, R>(
    TopicStream<B> latest,
    R Function(T value, B latest) combiner,
  ) => throw UnimplementedError();
  TopicStream<R> withLatestFrom2<B, C, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(T value, B b, C c) combiner,
  ) => throw UnimplementedError();
  TopicStream<R> withLatestFrom3<B, C, D, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(T value, B b, C c, D d) combiner,
  ) => throw UnimplementedError();

  /// [toStream] is the shell's stream factory (Spec §6.3); [retry] is the
  /// timed retry of its inner stream (ADR-003 item 4).
  TopicStream<R> switchMap<R>(
    Stream<R> Function(T value) toStream, {
    RetryPolicy? retry,
  }) => throw UnimplementedError();

  TopicStream<S> scan<S>(
    S initial,
    S Function(S accumulated, T value) accumulator,
  ) => throw UnimplementedError();
  TopicStream<({T previous, T current})> pairwise() =>
      throw UnimplementedError();
  TopicStream<T> distinctUntilChanged() => throw UnimplementedError();

  /// Time-dependent combinators (Spec §3.6, §6.3) take a Duration and no
  /// scheduler (ADR-003 item 4). A negative duration throws ArgumentError.
  TopicStream<T> debounce(Duration duration) => throw UnimplementedError();
  TopicStream<T> throttle(Duration duration) => throw UnimplementedError();
  TopicStream<T> delay(Duration duration) => throw UnimplementedError();
  TopicStream<T> sample(Duration duration) => throw UnimplementedError();
  TopicStream<List<T>> buffer(Duration duration) => throw UnimplementedError();
  TopicStream<T> timeout(Duration duration) => throw UnimplementedError();

  /// Turns a shell-boundary failure into a value (Spec §6.3, §10.2).
  TopicStream<T> catchError(
    T Function(Object error, StackTrace stackTrace) recover,
  ) => throw UnimplementedError();

  /// The raw-engine escape hatch (Spec §3.5 "Escape Hatch").
  TopicStream<R> rawEngine<R>(RawOperator<T, R> operator) =>
      throw UnimplementedError();
}
