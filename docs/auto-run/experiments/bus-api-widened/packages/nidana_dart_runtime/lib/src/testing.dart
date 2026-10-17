part of 'bus.dart';

// The bus-testing@v1 Interface (hsdd/contract/bus-testing.md), implemented as
// directly as possible. The scheduler grows out of
// docs/auto-run/experiments/virtual-scheduler/lib/scheduler.dart.

final class VirtualSchedulerProvider extends SchedulerProvider {
  VirtualSchedulerProvider(this.scheduler);
  final VirtualScheduler scheduler;
}

final class VirtualScheduler {
  VirtualScheduler({
    DateTime? initialTime,
    this.maxActions = 100000,
    this.maxSettleTurns = 20,
  }) : _epoch = initialTime ?? defaultInitialTime {
    if (maxActions < 1) {
      throw ArgumentError.value(maxActions, 'maxActions', 'must be at least 1');
    }
    if (maxSettleTurns < 1) {
      throw ArgumentError.value(
          maxSettleTurns, 'maxSettleTurns', 'must be at least 1');
    }
    clock = c.Clock(_now);
    _zone = c.withClock(
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

  static final DateTime defaultInitialTime = DateTime.utc(2000);

  final int maxActions;
  final int maxSettleTurns;
  late final c.Clock clock;
  late final Zone _zone;

  final DateTime _epoch;
  Duration _elapsed = Duration.zero;
  final Queue<void Function()> _microtasks = Queue<void Function()>();
  final List<_VTimer> _timers = <_VTimer>[];
  int _seq = 0;
  bool _running = false;
  int _actions = 0;

  DateTime _now() => _epoch.add(_elapsed);

  int get pendingMicrotaskCount => _microtasks.length;
  int get pendingTimerCount => _timers.length;

  DateTime? get nextTimerDue {
    Duration? best;
    for (final t in _timers) {
      if (best == null || t.due < best) best = t.due;
    }
    return best == null ? null : _epoch.add(best);
  }

  bool get _quiescent => _microtasks.isEmpty && _nextDue(_elapsed) == null;

  bool _inZone() {
    for (Zone? z = Zone.current; z != null; z = z.parent) {
      if (identical(z, _zone)) return true;
    }
    return false;
  }

  R run<R>(R Function() body) => _zone.run(body);

  _VTimer _add(Duration d, Duration? period, void Function() fire) {
    final t = _VTimer(this, _elapsed + (d.isNegative ? Duration.zero : d),
        _seq++, period, fire);
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

  void _guard(void Function() body) {
    if (_running) {
      throw StateError(
          'a VirtualScheduler operation was called from inside work it runs');
    }
    _running = true;
    _actions = 0;
    try {
      body();
    } finally {
      _running = false;
    }
  }

  void _count() {
    if (++_actions > maxActions) {
      throw StateError('the VirtualScheduler ran more than $maxActions '
          'actions in one operation');
    }
  }

  void _drainNow() {
    while (true) {
      if (_microtasks.isNotEmpty) {
        _count();
        _microtasks.removeFirst()();
        continue;
      }
      final t = _nextDue(_elapsed);
      if (t == null) return;
      _count();
      t._fire();
    }
  }

  void triggerActions() => _guard(_drainNow);

  void advanceTimeBy(Duration duration) {
    if (_running) {
      throw StateError(
          'a VirtualScheduler operation was called from inside work it runs');
    }
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    _guard(() {
      final target = _elapsed + duration;
      _drainNow();
      while (true) {
        final t = _nextDue(target);
        if (t == null) break;
        _elapsed = t.due;
        _drainNow();
      }
      _elapsed = target;
      _drainNow();
    });
  }

  void advanceTimeTo(DateTime timestamp) {
    if (_running) {
      throw StateError(
          'a VirtualScheduler operation was called from inside work it runs');
    }
    final d = timestamp.difference(_now());
    if (d.isNegative) {
      throw ArgumentError.value(
          timestamp, 'timestamp', 'is before the virtual time ${_now()}');
    }
    advanceTimeBy(d);
  }

  Future<void> settle() {
    if (_running) {
      throw StateError(
          'a VirtualScheduler operation was called from inside work it runs');
    }
    if (_inZone()) {
      throw StateError('settle was called inside the VirtualScheduler zone');
    }
    return _settle();
  }

  Future<void> _settle() async {
    for (var i = 0; i < maxSettleTurns; i++) {
      triggerActions();
      await Future<void>.delayed(Duration.zero);
      if (_quiescent) return;
    }
    throw StateError('the VirtualScheduler did not settle in '
        '$maxSettleTurns real turns');
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

@immutable
final class RecordedEnvelope {
  RecordedEnvelope._(this.topic, this.unredacted)
      : envelope = unredacted.redacted();

  final TopicRef topic;
  final MessageEnvelope<Object?> envelope;
  final MessageEnvelope<Object?> unredacted;

  @override
  bool operator ==(Object other) =>
      other is RecordedEnvelope &&
      other.topic == topic &&
      other.unredacted == unredacted;

  @override
  int get hashCode => Object.hash(topic, unredacted);

  @override
  String toString() => '${topic.name} $envelope';
}

final class EnvelopeRecorder {
  EnvelopeRecorder._();

  factory EnvelopeRecorder.attach(Bus bus) {
    bus._checkOpen();
    final r = EnvelopeRecorder._();
    bus._recorders.add(r);
    return r;
  }

  final List<RecordedEnvelope> _records = <RecordedEnvelope>[];

  List<RecordedEnvelope> get envelopes =>
      List<RecordedEnvelope>.unmodifiable(_records);

  List<MessageEnvelope<T>> envelopesOf<T>(Topic<T> topic,
      {bool unredacted = false}) {
    if (topic.sensitive && !unredacted) {
      throw ArgumentError.value(topic.name, 'topic',
          'is sensitive; pass unredacted: true to read its raw envelopes');
    }
    final ref = topic.ref;
    return List<MessageEnvelope<T>>.unmodifiable(<MessageEnvelope<T>>[
      for (final r in _records)
        if (r.topic == ref) r.unredacted as MessageEnvelope<T>,
    ]);
  }

  List<T> payloadsOf<T>(Topic<T> topic, {bool unredacted = false}) =>
      List<T>.unmodifiable(<T>[
        for (final e in envelopesOf(topic, unredacted: unredacted)) e.payload,
      ]);

  void _record(TopicRef topic, MessageEnvelope<Object?> envelope) =>
      _records.add(RecordedEnvelope._(topic, envelope));
}

final class OrderingProbe<T> {
  OrderingProbe._(this.topic);

  factory OrderingProbe.attach(Bus bus, Topic<T> topic,
      {int subscriptions = 3}) {
    if (subscriptions < 2) {
      throw ArgumentError.value(
          subscriptions, 'subscriptions', 'must be at least 2');
    }
    final p = OrderingProbe<T>._(topic);
    final stream = bus.observe(topic);
    for (var i = 0; i < subscriptions; i++) {
      final got = <T>[];
      p._received.add(got);
      p._subscriptions.add(stream.listen(got.add));
    }
    return p;
  }

  final Topic<T> topic;
  final List<List<T>> _received = <List<T>>[];
  final List<StreamSubscription<T>> _subscriptions = <StreamSubscription<T>>[];

  List<List<T>> get received => List<List<T>>.unmodifiable(<List<T>>[
        for (final r in _received) List<T>.unmodifiable(r),
      ]);

  bool get isConsistent {
    final first = _received.first;
    for (final r in _received.skip(1)) {
      if (r.length != first.length) return false;
      for (var i = 0; i < r.length; i++) {
        if (r[i] != first[i]) return false;
      }
    }
    return true;
  }

  void cancel() {
    for (final s in _subscriptions) {
      s.cancel(); // never awaited (ADR-003 item 3)
    }
    _subscriptions.clear();
  }
}

final class TestBus extends Bus {
  TestBus([BusConfig config = const BusConfig()])
      : this._(config, _virtualFor(config));

  // The provider is also kept as the scheduler.
  // ignore: use_super_parameters
  TestBus._(BusConfig config, VirtualSchedulerProvider provider)
      : scheduler = provider.scheduler,
        super._(config, provider) {
    recorder = EnvelopeRecorder.attach(this);
  }

  static VirtualSchedulerProvider _virtualFor(BusConfig config) =>
      switch (config.scheduler) {
        null => VirtualSchedulerProvider(VirtualScheduler()),
        final VirtualSchedulerProvider v => v,
        ProductionSchedulerProvider() => throw ArgumentError.value(
            config.scheduler, 'config', 'names the production provider'),
      };

  static const ServiceSource testSource = ServiceSource('test');

  final VirtualScheduler scheduler;
  late final EnvelopeRecorder recorder;
  final Map<StateTopic<Object?>, StateWriter<Object?>> _stubs =
      <StateTopic<Object?>, StateWriter<Object?>>{};
  int _testIds = 0;
  int _testCorrelations = 0;

  late final Publisher input = publisher(testSource);

  StateWriter<T> stub<T>(StateTopic<T> topic) {
    final existing = _stubs[topic];
    if (existing != null) return existing as StateWriter<T>;
    final w = publisher(testSource, writes: <StateTopic<Object?>>{topic})
        .writer(topic);
    _stubs[topic] = w;
    return w;
  }

  @override
  String _freshId() => 'e${++_testIds}';

  @override
  String _freshCorrelationId() => 'c${++_testCorrelations}';
}
