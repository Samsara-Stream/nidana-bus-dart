part of 'topology.dart';

/// The opaque stream handle (Spec §6.1): a stage of the plan. Sealed; made
/// only by the builder and by its own methods. It has no synchronous value
/// accessor, is not a Stream and has no listen (G1).
sealed class TopicStream<T> {
  TopicStream._(this._builder);

  // The builder whose declaration made this handle, which records every
  // stage derived from it (G14, G15).
  final TopologyBuilder _builder;

  // Calls the visitor method of this stage's class with this stage, binding
  // its type arguments (G16).
  V _accept<V>(StageVisitor<V> visitor);

  TopicStream<R> map<R>(R Function(T value) transform) {
    _builder._checkOpen();
    return _derive(MapStage<T, R>._(_builder, this, transform));
  }

  TopicStream<T> filter(bool Function(T value) test) {
    _builder._checkOpen();
    return _derive(FilterStage<T>._(_builder, this, test));
  }

  TopicStream<R> withLatestFrom<B, R>(
    TopicStream<B> latest,
    R Function(T value, B latest) combiner,
  ) {
    _builder._checkOpen();
    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[latest],
    );
    return _builder._addStage(
      WithLatestFromStage<T, R>._(
        _builder,
        this,
        made,
        combiner,
        (T value, List<Object?> values) => combiner(value, values[0] as B),
      ),
      <TopicStream<Object?>>[this, ...made],
    );
  }

  TopicStream<R> withLatestFrom2<B, C, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(T value, B b, C c) combiner,
  ) {
    _builder._checkOpen();
    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[b, c],
    );
    return _builder._addStage(
      WithLatestFromStage<T, R>._(
        _builder,
        this,
        made,
        combiner,
        (T value, List<Object?> values) =>
            combiner(value, values[0] as B, values[1] as C),
      ),
      <TopicStream<Object?>>[this, ...made],
    );
  }

  TopicStream<R> withLatestFrom3<B, C, D, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(T value, B b, C c, D d) combiner,
  ) {
    _builder._checkOpen();
    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[b, c, d],
    );
    return _builder._addStage(
      WithLatestFromStage<T, R>._(
        _builder,
        this,
        made,
        combiner,
        (T value, List<Object?> values) =>
            combiner(value, values[0] as B, values[1] as C, values[2] as D),
      ),
      <TopicStream<Object?>>[this, ...made],
    );
  }

  /// [toStream] is the shell's stream factory (Spec §6.3); [retry] is the
  /// timed retry of its inner stream (ADR-003 item 4).
  TopicStream<R> switchMap<R>(
    Stream<R> Function(T value) toStream, {
    RetryPolicy? retry,
  }) {
    _builder._checkOpen();
    return _derive(SwitchMapStage<T, R>._(_builder, this, toStream, retry));
  }

  TopicStream<S> scan<S>(
    S initial,
    S Function(S accumulated, T value) accumulator,
  ) {
    _builder._checkOpen();
    return _derive(ScanStage<T, S>._(_builder, this, initial, accumulator));
  }

  TopicStream<({T previous, T current})> pairwise() {
    _builder._checkOpen();
    return _derive(PairwiseStage<T>._(_builder, this));
  }

  TopicStream<T> distinctUntilChanged() {
    _builder._checkOpen();
    return _derive(DistinctUntilChangedStage<T>._(_builder, this));
  }

  /// Time-dependent combinators (Spec §3.6, §6.3) take a Duration and no
  /// scheduler (ADR-003 item 4). A negative duration throws ArgumentError.
  TopicStream<T> debounce(Duration duration) {
    _builder._checkOpen();
    return _derive(
      DebounceStage<T>._(_builder, this, _checkNotNegative(duration)),
    );
  }

  TopicStream<T> throttle(Duration duration) {
    _builder._checkOpen();
    return _derive(
      ThrottleStage<T>._(_builder, this, _checkNotNegative(duration)),
    );
  }

  TopicStream<T> delay(Duration duration) {
    _builder._checkOpen();
    return _derive(
      DelayStage<T>._(_builder, this, _checkNotNegative(duration)),
    );
  }

  TopicStream<T> sample(Duration duration) {
    _builder._checkOpen();
    return _derive(
      SampleStage<T>._(_builder, this, _checkNotNegative(duration)),
    );
  }

  TopicStream<List<T>> buffer(Duration duration) {
    _builder._checkOpen();
    return _derive(
      BufferStage<T>._(_builder, this, _checkNotNegative(duration)),
    );
  }

  TopicStream<T> timeout(Duration duration) {
    _builder._checkOpen();
    return _derive(
      TimeoutStage<T>._(_builder, this, _checkNotNegative(duration)),
    );
  }

  /// Turns a shell-boundary failure into a value (Spec §6.3, §10.2).
  TopicStream<T> catchError(
    T Function(Object error, StackTrace stackTrace) recover,
  ) {
    _builder._checkOpen();
    return _derive(CatchErrorStage<T>._(_builder, this, recover));
  }

  /// The raw-engine escape hatch (Spec §3.5 "Escape Hatch").
  TopicStream<R> rawEngine<R>(RawOperator<T, R> operator) {
    _builder._checkOpen();
    return _derive(RawEngineStage<T, R>._(_builder, this, operator));
  }

  // Records [stage], whose one input is this handle.
  S _derive<S extends TopicStream<Object?>>(S stage) =>
      _builder._addStage(stage, <TopicStream<Object?>>[this]);
}

// Returns [duration], or throws ArgumentError when it is negative (G14); a
// zero duration is accepted.
Duration _checkNotNegative(Duration duration) {
  if (duration.isNegative) {
    throw ArgumentError.value(duration, 'duration', 'must not be negative');
  }
  return duration;
}
