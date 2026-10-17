part of 'bus.dart';

// The bus-testing@v1 surface the bus-api@v1 bindings assume. Names and
// shapes are this experiment's guess at what bus-testing@v1 will declare
// (ADR-003 items 5 and 6); the scheduler is trimmed from
// docs/auto-run/experiments/virtual-scheduler/lib/scheduler.dart.

final class VirtualSchedulerProvider extends SchedulerProvider {
  VirtualSchedulerProvider([VirtualScheduler? scheduler])
      : scheduler = scheduler ?? VirtualScheduler();
  final VirtualScheduler scheduler;
}

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
  int get pendingTimerCount => _timers.length;
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

final class RecordedEnvelope {
  RecordedEnvelope._(this.topic, this.envelope);
  final TopicRef topic;
  final MessageEnvelope<Object?> envelope;
}

final class EnvelopeRecorder {
  EnvelopeRecorder._();
  final List<RecordedEnvelope> _envelopes = <RecordedEnvelope>[];

  /// Every envelope delivered on the bus, untraced topics included, in
  /// delivery order.
  List<RecordedEnvelope> get envelopes =>
      UnmodifiableListView<RecordedEnvelope>(_envelopes);

  void _record(TopicRef topic, MessageEnvelope<Object?> envelope) =>
      _envelopes.add(RecordedEnvelope._(topic, envelope));
}

final class TestBus extends Bus {
  TestBus([BusConfig config = const BusConfig()])
      : this._(config, _virtualFor(config));

  // The provider is also kept as the scheduler.
  // ignore: use_super_parameters
  TestBus._(BusConfig config, VirtualSchedulerProvider provider)
      : scheduler = provider.scheduler,
        super._(config, provider) {
    _recorder = recorder;
  }

  static VirtualSchedulerProvider _virtualFor(BusConfig config) =>
      switch (config.scheduler) {
        null => VirtualSchedulerProvider(),
        final VirtualSchedulerProvider v => v,
        ProductionSchedulerProvider() =>
          throw ArgumentError.value(config.scheduler, 'config', 'production provider'),
      };

  final VirtualScheduler scheduler;
  final EnvelopeRecorder recorder = EnvelopeRecorder._();
}
