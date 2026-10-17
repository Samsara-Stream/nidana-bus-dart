// virtual-scheduler: settles the runtime facts ADR-003 rests on, on the pinned
// SDK (Flutter 3.47.7, Dart 3.13.5) with rxdart 0.28.0 and clock 1.1.x.
//
//   Q1 every RxDart time operator a topology uses, listened inside the
//      provider zone and fed from outside it: is it driven only by virtual
//      time, and does cancelling the subscription leave no timer behind?
//   Q2 bus.observe as a stream whose listen re-enters the provider zone: does
//      a consumer listening from its own zone get the replayed first value
//      under triggerActions, where do its callbacks run, and which operators
//      it chains are virtual?
//   Q3 can the bus put a deferral or a timer into its zone from a call that
//      arrives in another zone?
//   Q4 drain semantics: order of microtasks and timers, periodic timers,
//      advanceTimeTo, argument checks, reentrancy, the runaway bound, errors.
//   Q5 package:clock inside and outside the virtual zone.
//   Q6 the production provider under fakeAsync and withClock.
//   Q7 a stub completed from the test's zone: triggerActions against settle().
//   Q8 cost of a pass-through fork against the captured zone.
//   Q9 RxDart 0.28's switchMap under plain fakeAsync, against a switchMap
//      that does not wait on the previous inner's cancel future.
//
// Run: fvm dart run bin/main.dart > output.txt 2>&1
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:rxdart/rxdart.dart';
import 'package:virtual_scheduler/scheduler.dart';

void p(String s) => print(s);
Duration d(int n) => Duration(milliseconds: n);

String t(VirtualScheduler vs) =>
    '${vs.now().difference(DateTime.utc(2000)).inMilliseconds}ms';

/// Runs [build] inside a fresh scheduler's zone over a sync PublishSubject
/// created outside it, then lets [script] drive it. Afterwards waits real time
/// to show nothing fires outside virtual time, cancels, and counts timers.
Future<void> op<T>(
  String name,
  Stream<Object?> Function(PublishSubject<T> s) build,
  void Function(PublishSubject<T> s, VirtualScheduler vs, List<String> out)
      script,
) async {
  final vs = VirtualScheduler();
  final s = PublishSubject<T>(sync: true);
  final out = <String>[];
  late StreamSubscription<Object?> sub;
  vs.zone.run(() {
    sub = build(s).listen((v) => out.add('$v@${t(vs)}'),
        onError: (Object e) => out.add('error:$e@${t(vs)}'));
  });
  script(s, vs, out);
  final before = out.length;
  await Future<void>.delayed(const Duration(milliseconds: 400));
  final realExtra = out.length - before;
  final pendingBefore = vs.pendingTimerCount;
  await sub.cancel();
  p('  $name: $out | real-time extra emissions: $realExtra | '
      'timers pending before cancel: $pendingBefore, after cancel: ${vs.pendingTimerCount}');
}

Future<void> opAsync<T>(
  String name,
  Stream<Object?> Function(PublishSubject<T> s) build,
  Future<void> Function(PublishSubject<T> s, VirtualScheduler vs, List<String> out) script,
) async {
  final vs = VirtualScheduler();
  final s = PublishSubject<T>(sync: true);
  final out = <String>[];
  late StreamSubscription<Object?> sub;
  vs.zone.run(() {
    sub = build(s).listen((v) => out.add('$v@${t(vs)}'));
  });
  await script(s, vs, out);
  await sub.cancel();
  p('  $name: $out | timers after cancel: ${vs.pendingTimerCount}');
}

Future<void> q1() async {
  p('== Q1 time operators listened inside the provider zone, fed from outside');
  await op<int>('debounceTime(300ms)', (s) => s.debounceTime(d(300)), (s, vs, out) {
    s..add(1)..add(2);
    vs.advanceTimeBy(d(299));
    out.add('|299');
    vs.advanceTimeBy(d(1));
    s.add(3);
  });
  await op<int>('throttleTime(300ms)', (s) => s.throttleTime(d(300)), (s, vs, out) {
    s.add(1);
    vs.advanceTimeBy(d(100));
    s.add(2);
    vs.advanceTimeBy(d(200));
    s.add(3);
  });
  await op<int>('delay(100ms)', (s) => s.delay(d(100)), (s, vs, out) {
    s..add(1)..add(2);
    vs.advanceTimeBy(d(99));
    out.add('|99');
    vs.advanceTimeBy(d(1));
  });
  await op<int>('sampleTime(300ms) (Stream.periodic)', (s) => s.sampleTime(d(300)), (s, vs, out) {
    s.add(1);
    vs.advanceTimeBy(d(100));
    s.add(2);
    vs.advanceTimeBy(d(200));
    s.add(3);
    vs.advanceTimeBy(d(600));
  });
  await op<int>('bufferTime(300ms) (Stream.periodic)', (s) => s.bufferTime(d(300)), (s, vs, out) {
    s..add(1)..add(2);
    vs.advanceTimeBy(d(300));
    vs.advanceTimeBy(d(300));
  });
  await op<int>('Stream.timeout(500ms) (dart:async)',
      (s) => s.timeout(d(500), onTimeout: (sink) => sink.add(-1)), (s, vs, out) {
    vs.advanceTimeBy(d(499));
    out.add('|499');
    vs.advanceTimeBy(d(1));
  });
  await op<int>('interval(100ms) (Future.delayed)', (s) => s.interval(d(100)), (s, vs, out) {
    s..add(1)..add(2);
    vs.advanceTimeBy(d(100));
    vs.advanceTimeBy(d(100));
  });
  await op<int>('RxDart switchMap(Rx.timer 200ms), no await',
      (s) => s.switchMap((v) => Rx.timer(v, d(200))), (s, vs, out) {
    s.add(1);
    vs.advanceTimeBy(d(100));
    s.add(2);
    out.add('|after add(2): virtual timers ${vs.pendingTimerCount}, microtasks ${vs.pendingMicrotaskCount}');
    vs.advanceTimeBy(d(300));
    out.add('|after advance to 400ms');
  });
  await opAsync<int>('RxDart switchMap(Rx.timer 200ms), await one real turn after add(2)',
      (s) => s.switchMap((v) => Rx.timer(v, d(200))), (s, vs, out) async {
    s.add(1);
    vs.advanceTimeBy(d(100));
    s.add(2);
    await Future<void>.delayed(Duration.zero);
    out.add('|after a real turn: virtual timers ${vs.pendingTimerCount}');
    vs.advanceTimeBy(d(300));
  });
  await op<int>('debounceTime(300ms) then RxDart switchMap(Rx.timer 200ms), no await',
      (s) => s.debounceTime(d(300)).switchMap((v) => Rx.timer(v, d(200))), (s, vs, out) {
    s.add(1);
    vs.advanceTimeBy(d(600));
    s.add(2);
    vs.advanceTimeBy(d(1000));
    out.add('|after advance to 1600ms');
  });
  await op<int>('switchMapNoWait(Rx.timer 200ms), no await',
      (s) => s.switchMapNoWait((v) => Rx.timer(v, d(200))), (s, vs, out) {
    s.add(1);
    vs.advanceTimeBy(d(100));
    s.add(2);
    vs.advanceTimeBy(d(300));
  });
  await op<int>('debounceTime(300ms) then switchMapNoWait(Rx.timer 200ms), no await',
      (s) => s.debounceTime(d(300)).switchMapNoWait((v) => Rx.timer(v, d(200))), (s, vs, out) {
    s.add(1);
    vs.advanceTimeBy(d(600));
    s.add(2);
    vs.advanceTimeBy(d(1000));
  });
  var attempts = 0;
  await op<int>('Rx.retryWhen(retry after Rx.timer 1s)',
      (s) => s.switchMap((_) => Rx.retryWhen<String>(
          () => Rx.defer(() => ++attempts == 1
              ? Stream<String>.error('boom')
              : Stream<String>.value('ok#$attempts')),
          (e, st) => Rx.timer<void>(null, const Duration(seconds: 1)))),
      (s, vs, out) {
    s.add(0);
    vs.triggerActions();
    vs.advanceTimeBy(d(999));
    out.add('|999');
    vs.advanceTimeBy(d(1));
  });
  await op<String>('switchMap(Stream.periodic 100ms made in the mapper)',
      (s) => s.switchMap((_) => Stream<int>.periodic(d(100), (i) => i)), (s, vs, out) {
    s.add('go');
    vs.advanceTimeBy(d(350));
  });
  final svc = BehaviorSubject<String>.seeded('svc-0', sync: true);
  await op<String>('switchMap(service BehaviorSubject created outside the zone)',
      (s) => s.switchMap((_) => svc.stream), (s, vs, out) {
    s.add('go');
    out.add('|listened:${List.of(out)}');
    vs.triggerActions();
    svc.add('svc-1');
  });
  final feed = StreamController<int>.broadcast(sync: true);
  var n = 0;
  final svcTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => feed.add(n++));
  await op<String>('switchMap(service stream fed by a Timer the service made outside)',
      (s) => s.switchMap((_) => feed.stream), (s, vs, out) {
    s.add('go');
    vs.advanceTimeBy(const Duration(seconds: 1));
    out.add('|after virtual 1s');
  });
  svcTimer.cancel();
}

Future<void> q2() async {
  p('== Q2 bus.observe re-entering the provider zone, consumer listening from its own zone');
  {
    final vs = VirtualScheduler();
    final state = BehaviorSubject<int>.seeded(0, sync: true);
    final raw = <int>[];
    state.stream.listen(raw.add);
    vs.triggerActions();
    p('  raw subject stream: after triggerActions $raw (needs a real turn)');
    await Future<void>.delayed(Duration.zero);
    p('  raw subject stream: after a real turn $raw');
  }
  {
    final vs = VirtualScheduler();
    final state = BehaviorSubject<int>.seeded(0, sync: true);
    final got = <String>[];
    ZonedStream(state.stream, vs.zone).listen((v) => got.add(
        '$v inZone=${identical(Zone.current, vs.zone)}'));
    p('  ZonedStream: right after listen $got, pending microtasks ${vs.pendingMicrotaskCount}');
    vs.triggerActions();
    p('  ZonedStream: after triggerActions $got');
    state.add(1);
    p('  ZonedStream: after add(1) from outside $got');
  }
  {
    final vs = VirtualScheduler();
    final ev = PublishSubject<int>(sync: true);
    final got = <String>[];
    ZonedStream(ev.stream, vs.zone).debounceTime(d(300)).listen((v) => got.add('$v@${t(vs)}'));
    p('  consumer-chained debounceTime: timers in the virtual queue after listen ${vs.pendingTimerCount}');
    ev.add(5);
    p('  consumer-chained debounceTime: timers in the virtual queue after add ${vs.pendingTimerCount}');
    vs.advanceTimeBy(d(300));
    p('  consumer-chained debounceTime: after advanceTimeBy(300ms) $got');
  }
  {
    final vs = VirtualScheduler();
    final ev = PublishSubject<int>(sync: true);
    final got = <String>[];
    final sub = ZonedStream(ev.stream, vs.zone)
        .timeout(d(200), onTimeout: (sink) => sink.add(-1))
        .listen((v) => got.add('$v'));
    p('  consumer-chained Stream.timeout(200ms): virtual timers after listen ${vs.pendingTimerCount}');
    vs.advanceTimeBy(const Duration(seconds: 1));
    p('  consumer-chained Stream.timeout: after virtual 1s $got');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    p('  consumer-chained Stream.timeout: after real 250ms $got');
    await sub.cancel();
  }
  {
    final vs = VirtualScheduler();
    final ev = PublishSubject<int>(sync: true);
    final got = <String>[];
    final sub = ZonedStream(ev.stream, vs.zone).sampleTime(d(100)).listen((v) => got.add('$v'));
    ev.add(7);
    p('  consumer-chained sampleTime(100ms): virtual timers after listen+add ${vs.pendingTimerCount}');
    vs.advanceTimeBy(const Duration(seconds: 1));
    p('  consumer-chained sampleTime: after virtual 1s $got');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    p('  consumer-chained sampleTime: after real 150ms $got');
    await sub.cancel();
  }
}

Future<void> q3() async {
  p('== Q3 scheduling into the provider zone from a call made in another zone');
  final vs = VirtualScheduler();
  final log = <String>[];
  vs.zone.scheduleMicrotask(() => log.add('zone.scheduleMicrotask'));
  scheduleMicrotask(() => log.add('global scheduleMicrotask from outside'));
  vs.zone.run(() => Timer(d(10), () => log.add('Timer inside zone.run')));
  vs.zone.createTimer(d(10), () => log.add('zone.createTimer'));
  p('  virtual queue: microtasks ${vs.pendingMicrotaskCount}, timers ${vs.pendingTimerCount}');
  vs.advanceTimeBy(d(10));
  p('  after advanceTimeBy(10ms), no await: $log');
  await Future<void>.delayed(Duration.zero);
  p('  after a real turn: $log');

  // Spec §3.4: a subscriber of x publishes to y reentrantly; the bus defers
  // the publish with zone.scheduleMicrotask, whatever zone the call is in.
  final x = PublishSubject<String>(sync: true);
  final y = PublishSubject<String>(sync: true);
  final seen = <String>[];
  ZonedStream(x.stream, vs.zone).listen((v) {
    seen.add('x1:$v');
    vs.zone.scheduleMicrotask(() => y.add('y<-$v'));
  });
  ZonedStream(x.stream, vs.zone).listen((v) => seen.add('x2:$v'));
  ZonedStream(y.stream, vs.zone).listen((v) => seen.add('y:$v'));
  x.add('a');
  p('  reentrant deferral: after x.add(a) $seen');
  vs.triggerActions();
  p('  reentrant deferral: after triggerActions $seen');
}

void q4() {
  p('== Q4 drain semantics');
  {
    final vs = VirtualScheduler();
    final order = <String>[];
    vs.zone.run(() {
      scheduleMicrotask(() {
        order.add('m1');
        scheduleMicrotask(() => order.add('m3'));
      });
      Timer(Duration.zero, () {
        order.add('t1');
        scheduleMicrotask(() => order.add('m2'));
        Timer(Duration.zero, () => order.add('t2'));
      });
      Timer(Duration.zero, () => order.add('t3'));
    });
    vs.triggerActions();
    p('  order under triggerActions: $order, idle=${vs.isIdle}');
  }
  {
    final vs = VirtualScheduler();
    final order = <String>[];
    vs.zone.run(() {
      Timer(d(100), () => order.add('a(100)'));
      Timer(d(50), () => order.add('b(50)'));
      Timer(d(100), () => order.add('c(100)'));
      Timer(d(100), () {
        order.add('d(100)');
        Timer(Duration.zero, () => order.add('e(d+0)'));
        Timer(d(1), () => order.add('f(d+1)'));
      });
    });
    vs.advanceTimeBy(d(100));
    p('  equal due times by creation; a timer made at 100 due at 100 runs in the same advance: $order, pending=${vs.pendingTimerCount}');
  }
  {
    final vs = VirtualScheduler();
    final ticks = <String>[];
    late Timer periodic;
    vs.zone.run(() => periodic = Timer.periodic(d(300), (tm) => ticks.add('tick${tm.tick}@${t(vs)}')));
    vs.advanceTimeBy(const Duration(seconds: 1));
    p('  periodic 300ms over advanceTimeBy(1s): $ticks, now=${t(vs)}, still active=${periodic.isActive}');
    periodic.cancel();
  }
  {
    final vs = VirtualScheduler();
    vs.advanceTimeTo(DateTime.utc(2000, 1, 1, 0, 0, 2));
    p('  advanceTimeTo(epoch+2s): now=${vs.now().toIso8601String()}');
    for (final f in <(String, void Function())>[
      ('advanceTimeTo(epoch+1s)', () => vs.advanceTimeTo(DateTime.utc(2000, 1, 1, 0, 0, 1))),
      ('advanceTimeBy(-1ms)', () => vs.advanceTimeBy(d(-1))),
    ]) {
      try {
        f.$2();
        p('  ${f.$1}: no error');
      } catch (e) {
        p('  ${f.$1}: ${e.runtimeType}');
      }
    }
  }
  {
    final errors = <String>[];
    final after = <String>[];
    runZonedGuarded(() {
      final vs = VirtualScheduler();
      vs.zone.run(() {
        Timer(Duration.zero, () => vs.triggerActions());
        Timer(Duration.zero, () => throw StateError('callback threw'));
        Timer(Duration.zero, () => after.add('later timer ran'));
      });
      vs.triggerActions();
    }, (e, st) => errors.add('$e'));
    p('  scheduler built inside runZonedGuarded: errors reached it: $errors; $after');
  }
  {
    final built = <String>[];
    final caller = <String>[];
    late VirtualScheduler vs;
    runZonedGuarded(() {
      vs = VirtualScheduler();
    }, (e, st) => built.add('$e'));
    runZonedGuarded(() {
      vs.zone.run(() => Timer(Duration.zero, () => throw StateError('thrown at fire time')));
      vs.triggerActions();
    }, (e, st) => caller.add('$e'));
    p('  built in zone A, driven from zone B: A got $built, B got $caller');
  }
  for (final (name, arm) in <(String, void Function(VirtualScheduler))>[
    ('self-rescheduling microtask', (vs) {
      void loop() => scheduleMicrotask(loop);
      vs.zone.run(loop);
    }),
    ('zero-period periodic timer', (vs) {
      vs.zone.run(() => Timer.periodic(Duration.zero, (_) {}));
    }),
  ]) {
    final vs = VirtualScheduler(maxActions: 1000);
    arm(vs);
    try {
      vs.triggerActions();
      p('  runaway ($name): returned');
    } catch (e) {
      p('  runaway ($name): ${e.runtimeType}: $e');
    }
  }
}

void q5() {
  p('== Q5 package:clock inside and outside the virtual zone');
  final vs = VirtualScheduler();
  final inside0 = vs.zone.run(() => clock.now());
  vs.advanceTimeBy(const Duration(minutes: 5));
  final inside1 = vs.zone.run(() => clock.now());
  p('  inside the zone: ${inside0.toIso8601String()} then ${inside1.toIso8601String()} (provider clock ${vs.clock.now().toIso8601String()})');
  p('  outside the zone: clock.now() is the system clock: ${clock.now().year >= 2026}');
}

Future<void> q6() async {
  p('== Q6 production provider (captures Zone.current and clock at construction)');
  fakeAsync((fa) {
    final prov = RealTimeProvider();
    final s = PublishSubject<int>(sync: true);
    final out = <int>[];
    prov.zone.run(() => s.debounceTime(d(300)).listen(out.add));
    final t0 = prov.clock.now();
    s..add(1)..add(2);
    fa.elapse(d(300));
    p('  built inside fakeAsync: debounce after elapse(300ms) $out; captured clock advanced ${prov.clock.now().difference(t0).inMilliseconds}ms');
  }, initialTime: DateTime.utc(2026));
  final outside = RealTimeProvider();
  fakeAsync((fa) {
    final s = PublishSubject<int>(sync: true);
    final out = <int>[];
    outside.zone.run(() => s.debounceTime(d(300)).listen(out.add));
    final t0 = outside.clock.now();
    s..add(1)..add(2);
    fa.elapse(d(300));
    p('  built outside fakeAsync, used inside: debounce after elapse(300ms) $out; captured clock advanced ${outside.clock.now().difference(t0).inMilliseconds}ms');
  });
  final fixed = DateTime.utc(2026, 10, 17, 9);
  final insideWithClock = withClock(Clock.fixed(fixed), () => RealTimeProvider());
  p('  built inside withClock(fixed), read outside it: ${insideWithClock.clock.now() == fixed}');
  final plain = RealTimeProvider();
  final readInside = withClock(Clock.fixed(fixed), () => plain.clock.now());
  p('  built outside, read inside withClock(fixed): equals the call-site clock? ${readInside == fixed}');
  await Future<void>.delayed(const Duration(milliseconds: 350));
}

Future<void> q7() async {
  p('== Q7 a stub completed from the test zone');
  for (final mode in ['triggerActions only', 'await one microtask, then triggerActions', 'settle()']) {
    final vs = VirtualScheduler();
    final query = PublishSubject<String>(sync: true);
    final stub = Completer<String>();
    final out = <String>[];
    vs.zone.run(() => query.switchMap((q) => Stream.fromFuture(stub.future)).listen(out.add));
    query.add('q');
    stub.complete('result');
    switch (mode) {
      case 'triggerActions only':
        vs.triggerActions();
      case 'await one microtask, then triggerActions':
        await Future<void>.value();
        vs.triggerActions();
      default:
        await vs.settle();
    }
    p('  $mode: $out');
  }
}

void q8() {
  p('== Q8 delivery cost: 2,000,000 sync events, best of 5 runs');
  int run(Zone zone) {
    final s = PublishSubject<int>(sync: true);
    var sum = 0;
    zone.run(() => s.listen((v) => sum += v));
    final sw = Stopwatch()..start();
    for (var i = 0; i < 2000000; i++) {
      s.add(i);
    }
    sw.stop();
    if (sum < 0) p('unreachable');
    return sw.elapsedMicroseconds;
  }

  final captured = RealTimeProvider().zone;
  final forked = ForkedProvider().zone;
  for (var round = 0; round < 2; round++) {
    run(captured);
    run(forked);
  }
  final a = List.generate(5, (_) => run(captured))..sort();
  final b = List.generate(5, (_) => run(forked))..sort();
  p('  captured root zone: ${a.first ~/ 1000}ms; pass-through fork: ${b.first ~/ 1000}ms; '
      'ratio ${(b.first / a.first).toStringAsFixed(2)}');
}

void q9() {
  p('== Q9 the same root-zone hop under plain fakeAsync (production provider built inside it)');
  fakeAsync((fa) {
    final prov = RealTimeProvider();
    final s = PublishSubject<int>(sync: true);
    final out = <String>[];
    prov.zone.run(() => s.switchMap((v) => Rx.timer(v, d(200))).listen(
        (v) => out.add('$v@${fa.elapsed.inMilliseconds}ms')));
    s.add(1);
    fa.elapse(d(100));
    s.add(2);
    fa.flushMicrotasks();
    fa.elapse(d(300));
    p('  RxDart switchMap under fakeAsync after elapse to 400ms: $out, fake timers pending ${fa.pendingTimers.length}');
  });
  fakeAsync((fa) {
    final prov = RealTimeProvider();
    final s = PublishSubject<int>(sync: true);
    final out = <String>[];
    prov.zone.run(() => s.switchMapNoWait((v) => Rx.timer(v, d(200))).listen(
        (v) => out.add('$v@${fa.elapsed.inMilliseconds}ms')));
    s.add(1);
    fa.elapse(d(100));
    s.add(2);
    fa.elapse(d(300));
    p('  switchMapNoWait under fakeAsync after elapse to 400ms: $out');
  });
}

Future<void> main() async {
  await q1();
  await q2();
  await q3();
  q4();
  q5();
  await q6();
  await q7();
  q8();
  q9();
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
