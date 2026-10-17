/// Stand-in live implementation of topology-dsl@v1 (experiment only).
///
/// A small bus on a virtual scheduler that interprets a TopologyPlan the way
/// the contract describes: every stage shared within an activation, read
/// stages connected after all consumers are wired, sink publishes deferred to
/// a provider-zone microtask, lineage applied per stage, errors carrying the
/// lineage of the value that raised them, a switchMap that never waits for a
/// cancel future, and RxDart's time operators inside the provider zone. Its
/// purpose is to show that the live conformance cases are satisfiable and not
/// vacuous; it is not the runtime's design.
library;

import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart' as c;
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:rxdart/rxdart.dart';

// ------------------------------------------------------------ scheduler

/// Trimmed from docs/auto-run/experiments/virtual-scheduler/lib/scheduler.dart.
final class VirtualScheduler {
  VirtualScheduler() : _epoch = DateTime.utc(2000) {
    clock = c.Clock(now);
    zone = c.withClock(
      clock,
      () => Zone.current.fork(
        specification: ZoneSpecification(
          scheduleMicrotask: (self, parent, zone, f) =>
              _microtasks.add(() => zone.runGuarded(f)),
          createTimer: (self, parent, zone, d, f) =>
              _add(d, null, () => zone.runGuarded(f)),
          createPeriodicTimer: (self, parent, zone, d, f) {
            late final _VTimer t;
            t = _add(d, d, () => zone.runUnaryGuarded(f, t));
            return t;
          },
        ),
      ),
    );
  }

  final DateTime _epoch;
  Duration _elapsed = Duration.zero;
  final Queue<void Function()> _microtasks = Queue<void Function()>();
  final List<_VTimer> _timers = <_VTimer>[];
  int _seq = 0;
  late final Zone zone;
  late final c.Clock clock;

  DateTime now() => _epoch.add(_elapsed);
  bool get isIdle => _microtasks.isEmpty && _nextDue(_elapsed) == null;

  _VTimer _add(Duration d, Duration? period, void Function() fire) {
    final t = _VTimer(
        this, _elapsed + (d.isNegative ? Duration.zero : d), _seq++, period, fire);
    _timers.add(t);
    return t;
  }

  _VTimer? _nextDue(Duration limit) {
    _VTimer? best;
    for (final t in _timers) {
      if (t.due > limit) continue;
      if (best == null ||
          t.due < best.due ||
          (t.due == best.due && t.seq < best.seq)) {
        best = t;
      }
    }
    return best;
  }

  void _drainNow() {
    var actions = 0;
    while (true) {
      if (++actions > 100000) throw StateError('runaway');
      if (_microtasks.isNotEmpty) {
        _microtasks.removeFirst()();
        continue;
      }
      final t = _nextDue(_elapsed);
      if (t == null) return;
      t._fire();
    }
  }

  void triggerActions() => _drainNow();

  void advanceTimeBy(Duration d) {
    final target = _elapsed + d;
    _drainNow();
    while (true) {
      final t = _nextDue(target);
      if (t == null) break;
      _elapsed = t.due;
      _drainNow();
    }
    _elapsed = target;
    _drainNow();
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      triggerActions();
      await Future<void>.delayed(Duration.zero);
      if (isIdle) return;
    }
    throw StateError('not settled');
  }
}

final class _VTimer implements Timer {
  _VTimer(this._s, this.due, this.seq, this.period, this._run);
  final VirtualScheduler _s;
  Duration due;
  int seq;
  final Duration? period;
  final void Function() _run;
  int _tick = 0;
  @override
  bool get isActive => _s._timers.contains(this);
  @override
  void cancel() => _s._timers.remove(this);
  @override
  int get tick => _tick;
  void _fire() {
    _tick++;
    final p = period;
    if (p == null) {
      _s._timers.remove(this);
    } else {
      due += p;
      seq = _s._seq++;
    }
    _run();
  }
}

// ------------------------------------------------------------ bus

/// A delivery on a topic: the payload and its envelope (null for a state
/// topic's declared initial value, which no message caused).
typedef _Delivery<T> = ({T payload, MessageEnvelope<T>? envelope});

final class _Cell<T> {
  _Cell(this.topic) {
    final t = topic;
    if (t is StateTopic<T>) _current = (payload: t.createInitial(), envelope: null);
  }

  final Topic<T> topic;
  _Delivery<T>? _current;
  final List<_Delivery<T>> _buffer = <_Delivery<T>>[];
  final StreamController<_Delivery<T>> _live =
      StreamController<_Delivery<T>>.broadcast(sync: true);

  T get current => _current!.payload;

  void publish(MessageEnvelope<T> envelope) {
    final d = (payload: envelope.payload, envelope: envelope);
    final t = topic;
    if (t is StateTopic<T>) _current = d;
    if (t is ReplayTopic<T>) {
      _buffer.add(d);
      if (_buffer.length > t.bufferSize) _buffer.removeAt(0);
    }
    _live.add(d);
  }

  /// Delivers the replay synchronously, then live deliveries.
  StreamSubscription<_Delivery<T>> listen(
    void Function(_Delivery<T> d) onData, {
    required bool replay,
  }) {
    if (replay) {
      final t = topic;
      if (t is StateTopic<T>) onData(_current!);
      if (t is ReplayTopic<T>) List<_Delivery<T>>.of(_buffer).forEach(onData);
    }
    return _live.stream.listen(onData);
  }
}

/// The lineage a pipeline error carries (contract G25).
final class _Raised {
  _Raised(this.error, this.lineage);
  final Object error;
  final Lineage lineage;
  @override
  String toString() => 'Raised($error)';
}

final class StandinBus {
  StandinBus(this.scheduler);

  final VirtualScheduler scheduler;
  final Map<Topic<Object?>, _Cell<Object?>> _cells = <Topic<Object?>, _Cell<Object?>>{};
  final List<String> diagnostics = <String>[];
  int _ids = 0;
  int _correlations = 0;

  Zone get zone => scheduler.zone;

  _Cell<T> _cell<T>(Topic<T> topic) =>
      _cells.putIfAbsent(topic, () => _Cell<T>(topic)) as _Cell<T>;

  String freshCorrelationId() => 'c-${++_correlations}';

  MessageEnvelope<T> _envelope<T>(
          Topic<T> topic, T payload, Lineage lineage, MessageSource source) =>
      MessageEnvelope<T>.publishedTo(
        topic,
        id: 'e-${++_ids}',
        payload: payload,
        lineage: lineage,
        freshCorrelationId: freshCorrelationId,
        timestamp: scheduler.now(),
        source: source,
      );

  void shellPublish<T>(Topic<T> topic, T value) => _cell(topic).publish(
      _envelope(topic, value, const Lineage.root(), const ServiceSource('test')));

  /// A topology publish: deferred to a provider-zone microtask (Spec §3.4).
  void topologyPublish<T>(Topic<T> topic, T value, Lineage lineage, String id) {
    final envelope = _envelope(topic, value, lineage, TopologySource(id));
    zone.scheduleMicrotask(() => _cell(topic).publish(envelope));
  }

  Activation activate(Topology topology) =>
      zone.run(() => Activation._(this, planOf(topology)));

  T current<T>(StateTopic<T> topic) => _cell(topic).current;

  /// A shell subscriber reading with the topic's own dedup policy; the replay
  /// at subscription is not delivered.
  void watch<T>(Topic<T> topic, void Function(MessageEnvelope<T> e) onEnvelope) =>
      zone.run(() {
        final c = _cell(topic);
        final t = topic;
        final dedup = t is StateTopic<T> ? t.dedup : Dedup.none;
        var has = t is StateTopic<T>;
        T? last = t is StateTopic<T> ? c.current : null;
        c.listen((d) {
          if (dedup == Dedup.equality && has && last == d.payload) return;
          has = true;
          last = d.payload;
          final env = d.envelope;
          if (env != null) onEnvelope(env);
        }, replay: false);
      });
}

// ------------------------------------------------------------ interpreter

/// A shared stage: one output for every consumer, its upstream subscriptions
/// kept for cancellation.
final class Hub<T> {
  final StreamController<PipelineValue<T>> _out =
      StreamController<PipelineValue<T>>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> subscriptions =
      <StreamSubscription<Object?>>[];
  final List<Timer> timers = <Timer>[];
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
    for (final t in timers) {
      t.cancel();
    }
    extraCancel();
  }
}

final class Activation implements StageVisitor<Hub<Object?>> {
  Activation._(this._bus, this._plan) {
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

  final StandinBus _bus;
  final TopologyPlan _plan;
  final Map<TopicStream<Object?>, Hub<Object?>> _hubs =
      HashMap<TopicStream<Object?>, Hub<Object?>>.identity();
  final List<StreamSubscription<Object?>> _sinkSubscriptions =
      <StreamSubscription<Object?>>[];

  String get topologyId => _plan.topologyId;

  Hub<T> hub<T>(TopicStream<T> s) => _hubs[s]! as Hub<T>;

  void deactivate() => _bus.zone.run(() {
        for (final s in _sinkSubscriptions) {
          s.cancel();
        }
        for (final h in _hubs.values) {
          h.cancel();
        }
      });

  Lineage _lineageOf(Object error) =>
      error is _Raised ? error.lineage : const Lineage.root();

  Object _unwrap(Object error) => error is _Raised ? error.error : error;

  /// Applies [f]; a throw becomes an error carrying [lineage].
  void _guard<R>(Hub<R> out, Lineage lineage, R Function() f) {
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
  Hub<T> read<T>(ReadStage<T> stage) {
    final out = Hub<T>();
    final topic = stage.topic;
    final dedup = topic is StateTopic<T> ? (stage.dedup ?? topic.dedup) : Dedup.none;
    out.connect = () {
      var has = false;
      late T last;
      out.subscriptions.add(_bus._cell(topic).listen((d) {
        if (dedup == Dedup.equality && has && last == d.payload) return;
        has = true;
        last = d.payload;
        final env = d.envelope;
        out.add((
          payload: d.payload,
          lineage: env == null || topic.tracing == Tracing.disabled
              ? const Lineage.root()
              : Lineage.causedBy(env),
        ));
      }, replay: true));
    };
    return out;
  }

  @override
  Hub<R> map<T, R>(MapStage<T, R> stage) {
    final out = Hub<R>();
    out.listenTo(hub(stage.input).stream,
        (PipelineValue<T> v) => _guard(out, v.lineage, () => stage.transform(v.payload)));
    return out;
  }

  @override
  Hub<T> filter<T>(FilterStage<T> stage) {
    final out = Hub<T>();
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
  Hub<R> combine<R>(CombineStage<R> stage) {
    final out = Hub<R>();
    final n = stage.inputs.length;
    final values = List<Object?>.filled(n, null);
    final lineages = List<Lineage?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      out.listenTo(hub(stage.inputs[i]).stream, (PipelineValue<Object?> v) {
        values[i] = v.payload;
        lineages[i] = v.lineage;
        if (lineages.any((l) => l == null)) return;
        final lineage = Lineage.combine(lineages.cast<Lineage>(),
            trigger: i, freshCorrelationId: _bus.freshCorrelationId);
        _guard(out, lineage, () => stage.apply(List<Object?>.of(values)));
      });
    }
    return out;
  }

  @override
  Hub<R> withLatestFrom<T, R>(WithLatestFromStage<T, R> stage) {
    final out = Hub<R>();
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
  Hub<T> merge<T>(MergeStage<T> stage) {
    final out = Hub<T>();
    for (final input in stage.inputs) {
      out.forward(hub(input).stream);
    }
    return out;
  }

  @override
  Hub<R> switchMap<T, R>(SwitchMapStage<T, R> stage) {
    final out = Hub<R>();
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
  Hub<S> scan<T, S>(ScanStage<T, S> stage) {
    final out = Hub<S>();
    var acc = stage.initial;
    out.listenTo(hub(stage.input).stream, (PipelineValue<T> v) {
      _guard(out, v.lineage, () => acc = stage.accumulator(acc, v.payload));
    });
    return out;
  }

  @override
  Hub<({T previous, T current})> pairwise<T>(PairwiseStage<T> stage) {
    final out = Hub<({T previous, T current})>();
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
  Hub<T> distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage) {
    final out = Hub<T>();
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
  Hub<T> debounce<T>(DebounceStage<T> stage) =>
      Hub<T>()..forward(hub(stage.input).stream.debounceTime(stage.duration));

  @override
  Hub<T> throttle<T>(ThrottleStage<T> stage) =>
      Hub<T>()..forward(hub(stage.input).stream.throttleTime(stage.duration));

  @override
  Hub<T> delay<T>(DelayStage<T> stage) =>
      Hub<T>()..forward(hub(stage.input).stream.delay(stage.duration));

  @override
  Hub<T> sample<T>(SampleStage<T> stage) =>
      Hub<T>()..forward(hub(stage.input).stream.sampleTime(stage.duration));

  @override
  Hub<List<T>> buffer<T>(BufferStage<T> stage) {
    final out = Hub<List<T>>();
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
  Hub<T> timeout<T>(TimeoutStage<T> stage) =>
      Hub<T>()..forward(hub(stage.input).stream.timeout(stage.duration));

  @override
  Hub<T> catchError<T>(CatchErrorStage<T> stage) {
    final out = Hub<T>();
    out.subscriptions.add(hub(stage.input).stream.listen(out.add,
        onError: (Object e, StackTrace st) =>
            _guard(out, _lineageOf(e), () => stage.recover(_unwrap(e), st))));
    return out;
  }

  @override
  Hub<R> rawEngine<T, R>(RawEngineStage<T, R> stage) {
    // The operator sees the errors the stages raised, not this wrapper.
    final unwrapped = hub(stage.input).stream.transform(
        StreamTransformer<PipelineValue<T>, PipelineValue<T>>.fromHandlers(
            handleError: (Object e, StackTrace st, EventSink<PipelineValue<T>> sink) =>
                sink.addError(_unwrap(e), st)));
    return Hub<R>()
      ..forward(stage.operator(unwrapped, _bus.freshCorrelationId));
  }
}

final class _SinkWiring implements SinkVisitor<void> {
  _SinkWiring(this._a);
  final Activation _a;

  @override
  void write<T>(WriteSink<T> sink) {
    late final StreamSubscription<PipelineValue<T>> sub;
    sub = _a.hub(sink.input).stream.listen(
      (PipelineValue<T> v) => _a._bus
          .topologyPublish(sink.topic, v.payload, v.lineage, _a.topologyId),
      onError: (Object e, StackTrace st) {
        sub.cancel();
        _a._bus.diagnostics.add('terminated ${sink.topic.name}: $e');
      },
    );
    _a._sinkSubscriptions.add(sub);
  }

  @override
  void reduceInto<S, E>(ReduceIntoSink<S, E> sink) {
    var state = _a._bus._cell(sink.topic).current;
    late final StreamSubscription<PipelineValue<E>> sub;
    void terminate(Object e) {
      sub.cancel();
      _a._bus.diagnostics.add('terminated ${sink.topic.name}: $e');
    }

    sub = _a.hub(sink.events).stream.listen(
      (PipelineValue<E> v) {
        final S next;
        try {
          next = sink.reducer(state, v.payload);
        } catch (e) {
          terminate(e);
          return;
        }
        state = next;
        _a._bus.topologyPublish(sink.topic, next, v.lineage, _a.topologyId);
      },
      onError: (Object e, StackTrace st) => terminate(e),
    );
    _a._sinkSubscriptions.add(sub);
  }
}

