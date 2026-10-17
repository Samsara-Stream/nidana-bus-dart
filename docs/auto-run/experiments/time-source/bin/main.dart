// Question: on the pinned SDK, what controls time for RxDart's time operators,
// and what does that imply for Spec §3.6 (SchedulerProvider, VirtualScheduler,
// TestBus) on Dart, where RxDart has no scheduler parameter?
import 'dart:async';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:rxdart/rxdart.dart';

void p(String s) => print(s);

void case1() {
  p('== 1: subscription created inside fakeAsync, debounceTime(300ms)');
  fakeAsync((fa) {
    final s = PublishSubject<int>(sync: true);
    final out = <int>[];
    s.debounceTime(const Duration(milliseconds: 300)).listen(out.add);
    s..add(1)..add(2);
    fa.elapse(const Duration(milliseconds: 299));
    p('  at 299ms: $out');
    fa.elapse(const Duration(milliseconds: 1));
    p('  at 300ms: $out');
    s.add(3);
    fa.elapse(const Duration(seconds: 1));
    p('  after 1s more: $out');
  });
}

Future<void> case2() async {
  p('== 2: subscription created OUTSIDE fakeAsync, events published inside it');
  final s = PublishSubject<int>(sync: true);
  final out = <int>[];
  s.debounceTime(const Duration(milliseconds: 300)).listen(out.add);
  fakeAsync((fa) {
    s..add(1)..add(2);
    fa.elapse(const Duration(seconds: 1));
    p('  inside fakeAsync after elapse(1s): $out (timer lives in the root zone)');
  });
  await Future<void>.delayed(const Duration(milliseconds: 350));
  p('  after 350ms of real time: $out');
}

void case3() {
  p('== 3: scheduleMicrotask normalization under fakeAsync');
  fakeAsync((fa) {
    final x = PublishSubject<String>(sync: true);
    final y = PublishSubject<String>(sync: true);
    final seen = <String>[];
    x.listen((v) { seen.add('x:$v'); scheduleMicrotask(() => y.add('y-from-$v')); });
    y.listen((v) => seen.add('y:$v'));
    x.add('a');
    p('  before flushMicrotasks: $seen');
    fa.flushMicrotasks();
    p('  after flushMicrotasks: $seen');
  });
}

void case4() {
  p('== 4: clock.now() and DateTime.now() under fakeAsync');
  final start = DateTime.utc(2026, 1, 1);
  fakeAsync((fa) {
    final c0 = clock.now();
    fa.elapse(const Duration(minutes: 5));
    final c1 = clock.now();
    p('  clock.now advanced by ${c1.difference(c0)}; initialTime given: $start');
  }, initialTime: start);
  fakeAsync((fa) {
    final d0 = DateTime.now();
    fa.elapse(const Duration(minutes: 5));
    final d1 = DateTime.now();
    p('  DateTime.now advanced by ${d1.difference(d0)} (not virtualized: real clock)');
  });
}

// A minimal zone-based scheduler, standing in for an injected SchedulerProvider:
// the bus would run activation inside this zone, so every Timer an RxDart
// operator creates in a subscription callback lands here.
class VirtualTimers {
  Duration now = Duration.zero;
  final _pending = <({Duration due, void Function() fire, int seq})>[];
  int _seq = 0;
  late final Zone zone = Zone.current.fork(specification: ZoneSpecification(
    createTimer: (self, parent, zone, d, f) {
      final entry = (due: now + d, fire: () => zone.run(f), seq: _seq++);
      _pending.add(entry);
      return _VTimer(() => _pending.remove(entry));
    },
  ));
  void advanceTimeBy(Duration d) {
    final target = now + d;
    while (true) {
      final due = _pending.where((e) => e.due <= target).toList()
        ..sort((a, b) => a.due.compareTo(b.due) != 0 ? a.due.compareTo(b.due) : a.seq.compareTo(b.seq));
      if (due.isEmpty) break;
      final e = due.first;
      _pending.remove(e);
      now = e.due;
      e.fire();
    }
    now = target;
  }
}

class _VTimer implements Timer {
  _VTimer(this._cancel);
  final void Function() _cancel;
  bool _active = true;
  @override
  void cancel() { if (_active) { _active = false; _cancel(); } }
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

Future<void> case5() async {
  p('== 5: own zone-based virtual scheduler controls RxDart debounceTime/throttleTime/delay');
  final vt = VirtualTimers();
  final s = PublishSubject<int>(sync: true);
  final deb = <int>[], thr = <int>[], del = <int>[];
  vt.zone.run(() {
    s.debounceTime(const Duration(milliseconds: 300)).listen(deb.add);
    s.throttleTime(const Duration(milliseconds: 300)).listen(thr.add);
    s.delay(const Duration(milliseconds: 100)).listen(del.add);
  });
  s..add(1)..add(2); // published from outside the zone
  await Future<void>.delayed(Duration.zero); // let the delay operator's internals run
  vt.advanceTimeBy(const Duration(milliseconds: 99));
  p('  t=99ms   debounce=$deb throttle=$thr delay=$del');
  vt.advanceTimeBy(const Duration(milliseconds: 1));
  p('  t=100ms  debounce=$deb throttle=$thr delay=$del');
  vt.advanceTimeBy(const Duration(milliseconds: 200));
  p('  t=300ms  debounce=$deb throttle=$thr delay=$del');
  await Future<void>.delayed(const Duration(milliseconds: 400));
  p('  after 400ms of real time, unchanged: debounce=$deb throttle=$thr delay=$del');
}

void case6() {
  p('== 6: nested fakeAsync (stand-in for a TestBus fakeAsync inside an outer fake zone)');
  fakeAsync((outer) {
    final out = <int>[];
    fakeAsync((inner) {
      final s = PublishSubject<int>(sync: true);
      s.debounceTime(const Duration(milliseconds: 300)).listen(out.add);
      s.add(1);
      outer.elapse(const Duration(seconds: 1));
      p('  after OUTER elapse(1s): $out');
      inner.elapse(const Duration(seconds: 1));
      p('  after INNER elapse(1s): $out');
    });
  });
}

Future<void> main() async {
  case1();
  await case2();
  case3();
  case4();
  await case5();
  case6();
}
