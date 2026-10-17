part of 'bus.dart';

// Adapted from docs/auto-run/experiments/topology-dsl-fixtures/
// packages/live_standin: the live interpretation of a TopologyPlan, here
// reading the bus's RxDart subjects and publishing through the bus.

/// A shared stage: one output for every consumer, its upstream
/// subscriptions kept for cancellation.
final class _Hub<T> {
  final StreamController<PipelineValue<T>> _out =
      StreamController<PipelineValue<T>>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> subscriptions =
      <StreamSubscription<Object?>>[];
  void Function() connect = () {};
  void Function() extraCancel = () {};

  Stream<PipelineValue<T>> get stream => _out.stream;
  void add(PipelineValue<T> v) => _out.add(v);
  void addError(Object e, StackTrace st) => _out.addError(e, st);

  void listenTo<S>(Stream<S> s, void Function(S v) onData) =>
      subscriptions.add(s.listen(onData, onError: addError));

  void forward(Stream<PipelineValue<T>> s) => listenTo(s, add);

  void cancel() {
    for (final s in subscriptions) {
      s.cancel(); // never awaited (ADR-003 item 3)
    }
    extraCancel();
  }
}

/// The lineage a pipeline error carries (topology-dsl@v1 G25).
final class _Raised {
  _Raised(this.error, this.lineage);
  final Object error;
  final Lineage lineage;
  @override
  String toString() => 'Raised($error)';
}

final class _Activation implements StageVisitor<_Hub<Object?>> {
  _Activation(this._bus, this._plan) : definition = _plan.definition {
    handle = TopologyHandle._(this);
  }

  final Bus _bus;
  final TopologyPlan _plan;
  final TopologyDefinition definition;
  late final TopologyHandle handle;
  bool active = true;
  final Map<TopicStream<Object?>, _Hub<Object?>> _hubs =
      HashMap<TopicStream<Object?>, _Hub<Object?>>.identity();
  final List<StreamSubscription<Object?>> _sinkSubscriptions =
      <StreamSubscription<Object?>>[];

  String get topologyId => definition.topologyId;

  void wire() {
    for (final s in _plan.stages) {
      _hubs[s] = visitStage(s, this);
    }
    for (final k in _plan.sinks) {
      visitSink(k, _SinkWiring(this));
    }
    for (final s in _plan.stages) {
      _hubs[s]!.connect();
    }
  }

  _Hub<T> hub<T>(TopicStream<T> s) => _hubs[s]! as _Hub<T>;

  void deactivate() {
    if (!active) return;
    active = false;
    _bus._zone.run(() {
      for (final s in _sinkSubscriptions) {
        s.cancel();
      }
      for (final h in _hubs.values) {
        h.cancel();
      }
    });
    _bus._active.remove(topologyId);
    _bus._discard(this);
  }

  void _publish<T>(Topic<T> topic, T value, Lineage lineage) {
    if (!active) return;
    _bus._publish(topic, value,
        lineage: lineage, source: TopologySource(topologyId), owner: this);
  }

  void _terminated(Topic<Object?> sink, Object error, StackTrace st) {
    _bus._report(PipelineTerminated(
        topologyId: topologyId,
        sink: sink.ref,
        error: _unwrap(error),
        stackTrace: st));
  }

  Lineage _lineageOf(Object error) =>
      error is _Raised ? error.lineage : const Lineage.root();

  Object _unwrap(Object error) => error is _Raised ? error.error : error;

  void _guard<R>(_Hub<R> out, Lineage lineage, R Function() f) {
    final R r;
    try {
      r = f();
    } catch (e, st) {
      out.addError(_Raised(e, lineage), st);
      return;
    }
    out.add((payload: r, lineage: lineage));
  }

  @override
  _Hub<T> read<T>(ReadStage<T> stage) {
    final out = _Hub<T>();
    final topic = stage.topic;
    _bus._cell(topic);
    final dedup =
        topic is StateTopic<T> ? (stage.dedup ?? topic.dedup) : Dedup.none;
    out.connect = () {
      out.subscriptions.add(_bus._cell(topic).stream(dedup).listen((d) {
        final env = d.envelope;
        out.add((
          payload: d.payload,
          lineage: env == null || topic.tracing == Tracing.disabled
              ? const Lineage.root()
              : Lineage.causedBy(env),
        ));
      }, onError: out.addError));
    };
    return out;
  }

  @override
  _Hub<R> map<T, R>(MapStage<T, R> stage) {
    final out = _Hub<R>();
    out.listenTo(hub(stage.input).stream,
        (PipelineValue<T> v) => _guard(out, v.lineage, () => stage.transform(v.payload)));
    return out;
  }

  @override
  _Hub<T> filter<T>(FilterStage<T> stage) {
    final out = _Hub<T>();
    out.listenTo(hub(stage.input).stream, (PipelineValue<T> v) {
      final bool pass;
      try {
        pass = stage.test(v.payload);
      } catch (e, st) {
        out.addError(_Raised(e, v.lineage), st);
        return;
      }
      if (pass) out.add(v);
    });
    return out;
  }

  @override
  _Hub<R> combine<R>(CombineStage<R> stage) {
    final out = _Hub<R>();
    final n = stage.inputs.length;
    final values = List<Object?>.filled(n, null);
    final lineages = List<Lineage?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      out.listenTo(hub(stage.inputs[i]).stream, (PipelineValue<Object?> v) {
        values[i] = v.payload;
        lineages[i] = v.lineage;
        if (lineages.any((l) => l == null)) return;
        final lineage = Lineage.combine(lineages.cast<Lineage>(),
            trigger: i, freshCorrelationId: _bus._freshCorrelationId);
        _guard(out, lineage, () => stage.apply(List<Object?>.of(values)));
      });
    }
    return out;
  }

  @override
  _Hub<R> withLatestFrom<T, R>(WithLatestFromStage<T, R> stage) {
    final out = _Hub<R>();
    final n = stage.latest.length;
    final values = List<Object?>.filled(n, null);
    final lineages = List<Lineage?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      out.listenTo(hub(stage.latest[i]).stream, (PipelineValue<Object?> v) {
        values[i] = v.payload;
        lineages[i] = v.lineage;
      });
    }
    out.listenTo(hub(stage.primary).stream, (PipelineValue<T> v) {
      if (lineages.any((l) => l == null)) return;
      final lineage = Lineage.withLatestFrom(v.lineage, lineages.cast<Lineage>());
      _guard(out, lineage, () => stage.apply(v.payload, List<Object?>.of(values)));
    });
    return out;
  }

  @override
  _Hub<T> merge<T>(MergeStage<T> stage) {
    final out = _Hub<T>();
    for (final input in stage.inputs) {
      out.forward(hub(input).stream);
    }
    return out;
  }

  @override
  _Hub<R> switchMap<T, R>(SwitchMapStage<T, R> stage) {
    final out = _Hub<R>();
    StreamSubscription<R>? inner;
    Timer? retryTimer;
    var attempt = 0;
    void start(PipelineValue<T> v) {
      void failed(Object e, StackTrace st) {
        final policy = stage.retry;
        Duration? delay;
        if (policy != null) {
          try {
            delay = policy(e, ++attempt);
          } catch (e2, st2) {
            out.addError(_Raised(e2, v.lineage), st2);
            return;
          }
        }
        if (delay == null) {
          out.addError(_Raised(e, v.lineage), st);
          return;
        }
        inner?.cancel();
        inner = null;
        retryTimer = Timer(delay, () => start(v));
      }

      final Stream<R> s;
      try {
        s = stage.toStream(v.payload);
      } catch (e, st) {
        failed(e, st);
        return;
      }
      inner = s.listen((R r) => out.add((payload: r, lineage: v.lineage)),
          onError: failed);
    }

    out.listenTo(hub(stage.input).stream, (PipelineValue<T> v) {
      inner?.cancel(); // not awaited
      retryTimer?.cancel();
      inner = null;
      attempt = 0;
      start(v);
    });
    out.extraCancel = () {
      inner?.cancel();
      retryTimer?.cancel();
    };
    return out;
  }

  @override
  _Hub<S> scan<T, S>(ScanStage<T, S> stage) {
    final out = _Hub<S>();
    var acc = stage.initial;
    out.listenTo(hub(stage.input).stream, (PipelineValue<T> v) {
      _guard(out, v.lineage, () => acc = stage.accumulator(acc, v.payload));
    });
    return out;
  }

  @override
  _Hub<({T previous, T current})> pairwise<T>(PairwiseStage<T> stage) {
    final out = _Hub<({T previous, T current})>();
    var has = false;
    late T previous;
    out.listenTo(hub(stage.input).stream, (PipelineValue<T> v) {
      if (has) {
        out.add((payload: (previous: previous, current: v.payload), lineage: v.lineage));
      }
      has = true;
      previous = v.payload;
    });
    return out;
  }

  @override
  _Hub<T> distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage) {
    final out = _Hub<T>();
    var has = false;
    late T last;
    out.listenTo(hub(stage.input).stream, (PipelineValue<T> v) {
      if (has && last == v.payload) return;
      has = true;
      last = v.payload;
      out.add(v);
    });
    return out;
  }

  @override
  _Hub<T> debounce<T>(DebounceStage<T> stage) =>
      _Hub<T>()..forward(hub(stage.input).stream.debounceTime(stage.duration));

  @override
  _Hub<T> throttle<T>(ThrottleStage<T> stage) =>
      _Hub<T>()..forward(hub(stage.input).stream.throttleTime(stage.duration));

  @override
  _Hub<T> delay<T>(DelayStage<T> stage) =>
      _Hub<T>()..forward(hub(stage.input).stream.delay(stage.duration));

  @override
  _Hub<T> sample<T>(SampleStage<T> stage) =>
      _Hub<T>()..forward(hub(stage.input).stream.sampleTime(stage.duration));

  @override
  _Hub<List<T>> buffer<T>(BufferStage<T> stage) {
    final out = _Hub<List<T>>();
    out.listenTo(hub(stage.input).stream.bufferTime(stage.duration),
        (List<PipelineValue<T>> batch) {
      if (batch.isEmpty) return; // RxDart emits empty windows
      out.add((
        payload: List<T>.unmodifiable(batch.map((v) => v.payload)),
        lineage: batch.last.lineage,
      ));
    });
    return out;
  }

  @override
  _Hub<T> timeout<T>(TimeoutStage<T> stage) =>
      _Hub<T>()..forward(hub(stage.input).stream.timeout(stage.duration));

  @override
  _Hub<T> catchError<T>(CatchErrorStage<T> stage) {
    final out = _Hub<T>();
    out.subscriptions.add(hub(stage.input).stream.listen(out.add,
        onError: (Object e, StackTrace st) =>
            _guard(out, _lineageOf(e), () => stage.recover(_unwrap(e), st))));
    return out;
  }

  @override
  _Hub<R> rawEngine<T, R>(RawEngineStage<T, R> stage) {
    final unwrapped = hub(stage.input).stream.transform(
        StreamTransformer<PipelineValue<T>, PipelineValue<T>>.fromHandlers(
            handleError: (Object e, StackTrace st, EventSink<PipelineValue<T>> sink) =>
                sink.addError(_unwrap(e), st)));
    return _Hub<R>()..forward(stage.operator(unwrapped, _bus._freshCorrelationId));
  }
}

final class _SinkWiring implements SinkVisitor<void> {
  _SinkWiring(this._a);
  final _Activation _a;

  @override
  void write<T>(WriteSink<T> sink) {
    _a._bus._cell(sink.topic);
    late final StreamSubscription<PipelineValue<T>> sub;
    sub = _a.hub(sink.input).stream.listen(
      (PipelineValue<T> v) => _a._publish(sink.topic, v.payload, v.lineage),
      onError: (Object e, StackTrace st) {
        sub.cancel();
        _a._terminated(sink.topic, e, st);
      },
    );
    _a._sinkSubscriptions.add(sub);
  }

  @override
  void reduceInto<S, E>(ReduceIntoSink<S, E> sink) {
    var state = _a._bus._cell(sink.topic).current;
    late final StreamSubscription<PipelineValue<E>> sub;
    void terminate(Object e, StackTrace st) {
      sub.cancel();
      _a._terminated(sink.topic, e, st);
    }

    sub = _a.hub(sink.events).stream.listen(
      (PipelineValue<E> v) {
        final S next;
        try {
          next = sink.reducer(state, v.payload);
        } catch (e, st) {
          terminate(e, st);
          return;
        }
        state = next;
        _a._publish(sink.topic, next, v.lineage);
      },
      onError: terminate,
    );
    _a._sinkSubscriptions.add(sub);
  }
}
