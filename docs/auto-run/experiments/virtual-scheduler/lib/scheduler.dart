// Prototype of the ADR-003 time source: a virtual scheduler that owns a zone
// (timers, periodic timers, microtasks) and a virtual clock, a production
// provider that captures the construction zone and clock, and the stream
// wrapper that bus.observe would return (listen re-enters the provider zone).
//
// Throwaway experiment code; not the runtime's implementation.
import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart' as c;

/// What a bus reads time and schedules work through.
abstract interface class Provider {
  Zone get zone;
  c.Clock get clock;
}

/// Production: captures Zone.current and package:clock's clock at construction.
final class RealTimeProvider implements Provider {
  RealTimeProvider()
      : zone = Zone.current,
        clock = c.clock;
  @override
  final Zone zone;
  @override
  final c.Clock clock;
}

/// Production variant the root proposed: a pass-through fork of Zone.current.
final class ForkedProvider implements Provider {
  ForkedProvider()
      : zone = Zone.current.fork(),
        clock = c.clock;
  @override
  final Zone zone;
  @override
  final c.Clock clock;
}

final class VirtualScheduler implements Provider {
  VirtualScheduler({DateTime? initialTime, this.maxActions = 100000})
      : _epoch = initialTime ?? DateTime.utc(2000) {
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
  final int maxActions;
  Duration _elapsed = Duration.zero;
  final _microtasks = Queue<void Function()>();
  final _timers = <_VTimer>[];
  int _seq = 0;
  bool _running = false;
  int _actions = 0;

  @override
  late final Zone zone;
  @override
  late final c.Clock clock;

  DateTime now() => _epoch.add(_elapsed);
  int get pendingTimerCount => _timers.length;
  int get pendingMicrotaskCount => _microtasks.length;
  bool get isIdle => _microtasks.isEmpty && _nextDue(_elapsed) == null;

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
      throw StateError('VirtualScheduler operation called from inside an '
          'action it is running');
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
      throw StateError('VirtualScheduler ran more than $maxActions actions in '
          'one operation (a microtask loop or a zero-period timer?)');
    }
  }

  // Runs every queued microtask and every timer due at the current instant,
  // draining microtasks before each timer, until neither remains.
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

  void advanceTimeBy(Duration d) {
    if (d.isNegative) {
      throw ArgumentError.value(d, 'duration', 'must not be negative');
    }
    _guard(() {
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
    });
  }

  void advanceTimeTo(DateTime timestamp) {
    final d = timestamp.difference(now());
    if (d.isNegative) {
      throw ArgumentError.value(
          timestamp, 'timestamp', 'is before the virtual time ${now()}');
    }
    advanceTimeBy(d);
  }

  /// Alternates triggerActions with real event-loop turns until the virtual
  /// queue stays idle across a turn. Must be awaited from outside [zone].
  Future<void> settle({int maxTurns = 20}) async {
    for (var i = 0; i < maxTurns; i++) {
      triggerActions();
      await Future<void>.delayed(Duration.zero);
      if (isIdle) return;
    }
    throw StateError('not settled after $maxTurns real turns');
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

/// What bus.observe(topic) returns: listen subscribes inside the provider zone.
final class ZonedStream<T> extends Stream<T> {
  ZonedStream(this._source, this._zone);
  final Stream<T> _source;
  final Zone _zone;
  @override
  bool get isBroadcast => _source.isBroadcast;
  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _zone.run(() => _source.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError));
}

/// A switchMap that cancels the previous inner subscription without waiting
/// for its cancel future and listens to the next inner at once (the RxJS and
/// RxJava behavior). RxDart 0.28's switchMap waits for that future instead.
extension SwitchMapNoWait<S> on Stream<S> {
  Stream<T> switchMapNoWait<T>(Stream<T> Function(S value) mapper) {
    late final StreamController<T> out;
    StreamSubscription<S>? outer;
    StreamSubscription<T>? inner;
    var outerDone = false;
    out = StreamController<T>(
      sync: true,
      onListen: () {
        outer = listen(
          (s) {
            inner?.cancel();
            inner = mapper(s).listen(out.add, onError: out.addError, onDone: () {
              inner = null;
              if (outerDone) out.close();
            });
          },
          onError: out.addError,
          onDone: () {
            outerDone = true;
            if (inner == null) out.close();
          },
        );
      },
      onCancel: () {
        inner?.cancel();
        outer?.cancel();
      },
    );
    return out.stream;
  }
}
