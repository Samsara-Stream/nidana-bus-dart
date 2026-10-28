part of 'topology.dart';

/// The only builder (Spec §6.5): it records the declaration into a plan.
/// Final, no public constructor; planOf creates one per call.
final class TopologyBuilder {
  TopologyBuilder._();

  // What the declaration recorded so far, in call order.
  final List<TopicStream<Object?>> _stages = <TopicStream<Object?>>[];
  final List<PlanSink> _sinks = <PlanSink>[];

  // The stages a later stage or a sink takes as an input.
  final Set<TopicStream<Object?>> _consumed =
      Set<TopicStream<Object?>>.identity();

  // The state topics a sink already writes, compared by topic equality.
  final Set<StateTopic<Object?>> _written = <StateTopic<Object?>>{};

  // False once the declaration that made this builder has returned.
  bool _open = true;

  /// A read of [topic] (Spec §6.1). [dedup] overrides a StateTopic's own
  /// policy for this read only (Spec §3.12); null keeps it. A non-null
  /// [dedup] on an EventTopic or ReplayTopic read throws ArgumentError.
  TopicStream<T> read<T>(Topic<T> topic, {Dedup? dedup}) {
    _checkOpen();
    if (dedup != null && topic is MultiWriterTopic<T>) {
      throw ArgumentError.value(
        dedup,
        'dedup',
        'applies to a state topic read only, and ${topic.name} is an '
            '${topic.variant.name} topic',
      );
    }
    return _addStage(
      ReadStage<T>._(this, topic, dedup),
      const <TopicStream<Object?>>[],
    );
  }

  /// Writes every value of [stream] to [topic]: one write chain (Errors and
  /// lineage). The stream's value type is the topic's or a subtype of it (G3).
  void write<T, S extends T>(Topic<T> topic, TopicStream<S> stream) {
    _checkOpen();
    _checkMade(<TopicStream<Object?>>[stream]);
    _checkFirstSink(topic);
    _addSink(WriteSink<T>._(topic, stream), stream);
  }

  /// Folds [events] into [topic], which this topology then owns, seeded with
  /// the topic's current value when the activation connects (Spec §6.3,
  /// §7.2): one write chain (Errors and lineage).
  void reduceInto<S, E>(
    StateTopic<S> topic,
    TopicStream<E> events,
    S Function(S state, E event) reducer,
  ) {
    _checkOpen();
    _checkMade(<TopicStream<Object?>>[events]);
    _checkFirstSink(topic);
    _addSink(ReduceIntoSink<S, E>._(topic, events, reducer), events);
  }

  TopicStream<R> combine2<A, B, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    R Function(A a, B b) combiner,
  ) {
    _checkOpen();
    final List<TopicStream<Object?>> inputs = _checkMade(<TopicStream<Object?>>[
      a,
      b,
    ]);
    return _addStage(
      CombineStage<R>._(
        this,
        inputs,
        combiner,
        (List<Object?> values) => combiner(values[0] as A, values[1] as B),
      ),
      inputs,
    );
  }

  TopicStream<R> combine3<A, B, C, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(A a, B b, C c) combiner,
  ) {
    _checkOpen();
    final List<TopicStream<Object?>> inputs = _checkMade(<TopicStream<Object?>>[
      a,
      b,
      c,
    ]);
    return _addStage(
      CombineStage<R>._(
        this,
        inputs,
        combiner,
        (List<Object?> values) =>
            combiner(values[0] as A, values[1] as B, values[2] as C),
      ),
      inputs,
    );
  }

  TopicStream<R> combine4<A, B, C, D, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(A a, B b, C c, D d) combiner,
  ) {
    _checkOpen();
    final List<TopicStream<Object?>> inputs = _checkMade(<TopicStream<Object?>>[
      a,
      b,
      c,
      d,
    ]);
    return _addStage(
      CombineStage<R>._(
        this,
        inputs,
        combiner,
        (List<Object?> values) => combiner(
          values[0] as A,
          values[1] as B,
          values[2] as C,
          values[3] as D,
        ),
      ),
      inputs,
    );
  }

  /// [combiner] receives an unmodifiable list of the inputs' latest values,
  /// in input order. Throws ArgumentError for an empty [inputs].
  TopicStream<R> combineAll<T, R>(
    List<TopicStream<T>> inputs,
    R Function(List<T> values) combiner,
  ) {
    _checkOpen();
    _checkNotEmpty(inputs);
    final List<TopicStream<T>> made = _checkMade(inputs);
    return _addStage(
      CombineStage<R>._(
        this,
        made,
        combiner,
        (List<Object?> values) =>
            combiner(List<T>.unmodifiable(values.cast<T>())),
      ),
      made,
    );
  }

  /// Throws ArgumentError for an empty [inputs].
  TopicStream<T> merge<T>(List<TopicStream<T>> inputs) {
    _checkOpen();
    _checkNotEmpty(inputs);
    final List<TopicStream<T>> made = _checkMade(inputs);
    return _addStage(MergeStage<T>._(this, made), made);
  }

  // Throws StateError once the declaration that made this builder has
  // returned (G15).
  void _checkOpen() {
    if (!_open) {
      throw StateError(
        'The declaration that made this builder has returned: its builder '
        'and handles record nothing more.',
      );
    }
  }

  // Throws ArgumentError unless this builder made every one of [handles]
  // (G14); returns them as an unmodifiable copy.
  List<H> _checkMade<H extends TopicStream<Object?>>(List<H> handles) {
    for (final H handle in handles) {
      if (!identical(handle._builder, this)) {
        throw ArgumentError.value(
          handle,
          'handle',
          'was made by another builder: another declaration, or another '
              'planOf call of this one',
        );
      }
    }
    return List<H>.unmodifiable(handles);
  }

  // Throws ArgumentError for an empty input list (G14).
  void _checkNotEmpty(List<TopicStream<Object?>> inputs) {
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
    }
  }

  // Throws ArgumentError when a sink already writes [topic], a state topic
  // (G14); event and replay topics take any number of sinks.
  void _checkFirstSink(Topic<Object?> topic) {
    if (topic is StateTopic<Object?> && _written.contains(topic)) {
      throw ArgumentError.value(
        topic.name,
        'topic',
        'already has a sink in this topology; a state topic takes one',
      );
    }
  }

  // Appends [stage] and marks [inputs] consumed. Every check has passed.
  S _addStage<S extends TopicStream<Object?>>(
    S stage,
    List<TopicStream<Object?>> inputs,
  ) {
    _stages.add(stage);
    _consumed.addAll(inputs);
    return stage;
  }

  // Appends [sink], marks [input] consumed and claims a state topic. Every
  // check has passed.
  void _addSink(PlanSink sink, TopicStream<Object?> input) {
    _sinks.add(sink);
    _consumed.add(input);
    final Topic<Object?> topic = sink.topic;
    if (topic is StateTopic<Object?>) {
      _written.add(topic);
    }
  }

  // The plan of the declaration that has returned. Throws StateError when a
  // stage reaches no sink (G15): every stage reaches one exactly when each is
  // the input of a later stage or of a sink, because a stage's inputs precede
  // it.
  TopologyPlan _plan(String topologyId, Scope scope) {
    for (int i = 0; i < _stages.length; i++) {
      if (!_consumed.contains(_stages[i])) {
        throw StateError(
          'Topology $topologyId: stage ${i + 1} of ${_stages.length}, a '
          '${_stages[i].runtimeType}, reaches no sink. Write it, or remove '
          'it.',
        );
      }
    }
    return TopologyPlan._(
      topologyId,
      scope,
      List<TopicStream<Object?>>.unmodifiable(_stages),
      List<PlanSink>.unmodifiable(_sinks),
    );
  }
}
