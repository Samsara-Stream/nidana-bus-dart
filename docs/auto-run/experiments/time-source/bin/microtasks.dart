// Follow-up for the time-source decision: if the virtual scheduler zone also
// intercepts scheduleMicrotask, does it capture (a) a sync BehaviorSubject's
// first delivery to a subscriber that listened inside the zone, and (b) the
// Spec §3.4 reentrancy deferral, so that a TestBus test needs no event-loop turn?
import 'dart:async';
import 'package:rxdart/rxdart.dart';

class VirtualScheduler {
  Duration now = Duration.zero;
  final _micro = <void Function()>[];
  final _timers = <({Duration due, void Function() fire, int seq})>[];
  int _seq = 0;
  late final Zone zone = Zone.current.fork(specification: ZoneSpecification(
    scheduleMicrotask: (self, parent, zone, f) => _micro.add(() => zone.run(f)),
    createTimer: (self, parent, zone, d, f) {
      final e = (due: now + d, fire: () => zone.run(f), seq: _seq++);
      _timers.add(e);
      return _T(() => _timers.remove(e));
    },
  ));
  void triggerActions() {
    while (true) {
      if (_micro.isNotEmpty) { _micro.removeAt(0)(); continue; }
      final due = _timers.where((e) => e.due <= now).toList()..sort((a, b) => a.seq.compareTo(b.seq));
      if (due.isEmpty) return;
      _timers.remove(due.first);
      due.first.fire();
    }
  }
  void advanceTimeBy(Duration d) {
    final target = now + d;
    while (true) {
      triggerActions();
      final next = _timers.where((e) => e.due <= target).toList()
        ..sort((a, b) => a.due != b.due ? a.due.compareTo(b.due) : a.seq.compareTo(b.seq));
      if (next.isEmpty) break;
      now = next.first.due;
    }
    now = target;
    triggerActions();
  }
}

class _T implements Timer {
  _T(this._c);
  final void Function() _c;
  bool _a = true;
  @override void cancel() { if (_a) { _a = false; _c(); } }
  @override bool get isActive => _a;
  @override int get tick => 0;
}

Future<void> main() async {
  final vs = VirtualScheduler();
  final state = BehaviorSubject<int>.seeded(0, sync: true);
  final events = PublishSubject<String>(sync: true);
  final seen = <String>[];

  // (a) a subscriber that listens inside the zone
  vs.zone.run(() => state.listen((v) => seen.add('state:$v')));
  print('after listen inside zone, before triggerActions: $seen');
  vs.triggerActions();
  print('after triggerActions: $seen');

  // (b) reentrant publish deferred with scheduleMicrotask from a callback that runs in the zone
  vs.zone.run(() => events.listen((v) {
    seen.add('event:$v');
    scheduleMicrotask(() => state.add(state.value + 1));
  }));
  events.add('tap'); // published from outside the zone; the callback runs in the zone
  print('after events.add, before triggerActions: $seen');
  vs.triggerActions();
  print('after triggerActions: $seen');

  // (c) debounce inside the zone driven only by advanceTimeBy
  final deb = <int>[];
  vs.zone.run(() => state.debounceTime(const Duration(milliseconds: 300)).listen(deb.add));
  vs.triggerActions();
  state.add(10);
  vs.advanceTimeBy(const Duration(milliseconds: 300));
  print('debounce after advanceTimeBy(300ms): $deb');

  // (d) a subscriber that listens OUTSIDE the zone needs a real event-loop turn
  final outside = <int>[];
  state.listen(outside.add);
  vs.triggerActions();
  print('outside listener after triggerActions only: $outside');
  await Future<void>.delayed(Duration.zero);
  print('outside listener after a real event-loop turn: $outside');
}
