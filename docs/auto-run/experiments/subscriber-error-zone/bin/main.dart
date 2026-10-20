// subscriber-error-zone: settles the runtime facts behind ADR-003's amendment
// for Specification v0.15.1 §10.2 principle 5 (S58), on the pinned SDK
// (Flutter 3.47.7, Dart 3.13.x) with rxdart 0.28.0 and clock 1.1.x.
//
// Spec §10.2 principle 5 sends an exception thrown by a bus.observe()
// subscriber's callback to the uncaught-error handler of the zone in which
// `listen` was called. ADR-003 item 2 runs the callbacks in the provider zone;
// item 6 has a TestBus deliver everything a bus.observe subscription schedules
// through the scheduler operations alone. lib/observe.dart implements three
// strategies (today, forward, bind); this program measures each, with the
// virtual scheduler of docs/auto-run/experiments/virtual-scheduler/ (copied
// unchanged into lib/scheduler.dart) as the provider:
//
//   C1  first value: delivered by triggerActions alone? in which zone does the
//       callback run, does it see the listener's zone value, which clock?
//   C2  a live publish from the test zone: delivered synchronously?
//   C3  a throwing subscriber: where does the error go, in what order with the
//       next subscriber, does the publish or triggerActions return normally,
//       does the throwing subscriber keep receiving?
//   C4  an error event the subscriber leaves unhandled, and an onError that throws
//   C5  an onDone that throws
//   C6  a handler set after listen with StreamSubscription.onData
//   C7  a Timer created inside a subscriber callback: virtual or real?
//   C8  debounceTime chained onto the observed stream, listened from the test zone
//   C9  map chained onto the observed stream, whose final callback throws
//   C10 a listener in a zone without its own handler, nested in the test zone
//   C11 a listener in the provider zone itself (listen zone == provider zone)
//   C12 Dart's own Stream.cast precedent: where a cast failure goes
//   C13 a listener in the root zone of an isolate with no guarded zone
//   C14 cost per delivery when the listener's zone is not the provider zone
import 'dart:async';
import 'dart:isolate';

import 'package:clock/clock.dart' as c;
import 'package:rxdart/rxdart.dart';
import 'package:subscriber_error_zone/observe.dart';
import 'package:subscriber_error_zone/scheduler.dart';

String _m(Object e) => e is StateError ? e.message : '${e.runtimeType}';

/// A scheduler built in zone S (its own error handler, standing for the zone a
/// test fixture or setUpAll built the TestBus in), a sync BehaviorSubject
/// created in the provider zone P, and a test zone U with its own handler and
/// a zone value.
final class World {
  World(this.strategy) {
    runZonedGuarded(() {
      vs = VirtualScheduler();
    }, (e, st) => log.add('S<-${_m(e)}'));
    subject = vs.zone.run(() => BehaviorSubject<int>.seeded(0, sync: true));
    observed = Observed<int>(subject.stream, vs.zone, strategy);
  }
  final Strategy strategy;
  final log = <String>[];
  late final VirtualScheduler vs;
  late final BehaviorSubject<int> subject;
  late final Observed<int> observed;

  void inU(void Function() body) => runZonedGuarded(
      body, (e, st) => log.add('U<-${_m(e)}'),
      zoneValues: {#who: 'U'});

  String where() => identical(Zone.current, vs.zone)
      ? 'P'
      : (Zone.current[#who] as String?) ?? 'other';

  String clockKind() => c.clock.now().year == 2000 ? 'virtual' : 'wall';
}

Future<void> runStrategy(Strategy s) async {
  print('== ${s.name}');

  // C1, C2
  {
    final w = World(s);
    final got = <String>[];
    w.inU(() {
      w.observed.listen((v) => got.add(
          '$v in ${w.where()} zoneValue=${Zone.current[#who]} clock=${w.clockKind()}'));
      print('  C1 right after listen: $got, provider microtasks queued '
          '${w.vs.pendingMicrotaskCount}');
      w.vs.triggerActions();
      print('  C1 after triggerActions, no await: $got');
      w.subject.add(1);
      print('  C2 after add(1) from the test zone: $got');
    });
  }

  // C3
  {
    final w = World(s);
    w.inU(() {
      w.observed.listen((v) {
        w.log.add('X got $v');
        throw StateError('X threw on $v');
      });
      w.observed.listen((v) => w.log.add('Y got $v'));
      w.vs.triggerActions();
      w.log.add('triggerActions returned');
      try {
        w.subject.add(1);
        w.log.add('add(1) returned');
      } catch (e) {
        w.log.add('add(1) threw ${_m(e)}');
      }
      w.subject.add(2);
    });
    print('  C3 throwing subscriber X, then Y: ${w.log}');
  }

  // C4
  {
    final w = World(s);
    w.inU(() {
      w.observed.listen((_) {});
      w.observed.listen((_) {},
          onError: (Object e) => throw StateError('onError threw'));
      w.vs.triggerActions();
      w.subject.addError(StateError('error event'));
    });
    print('  C4 unhandled error event, and an onError that throws: ${w.log}');
  }

  // C5
  {
    final w = World(s);
    final ctl =
        w.vs.zone.run(() => StreamController<int>.broadcast(sync: true));
    final obs = Observed<int>(ctl.stream, w.vs.zone, s);
    w.inU(() {
      obs.listen((_) {}, onDone: () => throw StateError('onDone threw'));
      obs.listen((_) {}, onDone: () => w.log.add('second onDone ran'));
    });
    w.vs.zone.run(() => ctl.close());
    w.log.add('close returned');
    w.vs.triggerActions();
    await Future<void>.delayed(Duration.zero);
    print('  C5 onDone that throws (sync broadcast controller closed): ${w.log}');
  }

  // C6
  {
    final w = World(s);
    w.inU(() {
      final sub = w.observed.listen(null);
      sub.onData((v) => throw StateError('later onData threw on $v'));
      w.vs.triggerActions();
      w.subject.add(3);
    });
    print('  C6 handler set after listen: ${w.log}');
  }

  // C7
  {
    final w = World(s);
    w.inU(() {
      w.observed.listen((v) {
        if (v == 5) {
          Timer(const Duration(milliseconds: 100),
              () => w.log.add('timer fired in ${w.where()}'));
        }
      });
      w.vs.triggerActions();
      w.subject.add(5);
    });
    w.log.add('virtual timers pending ${w.vs.pendingTimerCount}');
    w.vs.advanceTimeBy(const Duration(milliseconds: 100));
    w.log.add('after advanceTimeBy(100ms)');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    w.log.add('after 150ms real');
    print('  C7 Timer created in a callback: ${w.log}');
  }

  // C8
  {
    final w = World(s);
    final got = <String>[];
    w.inU(() {
      w.observed
          .debounceTime(const Duration(milliseconds: 300))
          .listen((v) => got.add('$v in ${w.where()}'));
      w.vs.triggerActions();
      w.subject.add(7);
    });
    final pending = w.vs.pendingTimerCount;
    w.vs.advanceTimeBy(const Duration(milliseconds: 300));
    final afterVirtual = [...got];
    await Future<void>.delayed(const Duration(milliseconds: 350));
    print('  C8 chained debounceTime(300ms): virtual timers pending after add '
        '$pending; after advanceTimeBy(300ms) $afterVirtual; after 350ms real '
        '$got');
  }

  // C9
  {
    final w = World(s);
    w.inU(() {
      w.observed.map((v) => v * 10).listen((v) {
        w.log.add('mapped listener got $v in ${w.where()}');
        if (v == 40) throw StateError('mapped listener threw on $v');
      });
      w.vs.triggerActions();
      w.subject.add(4);
    });
    print('  C9 chained map, final callback throws: ${w.log}');
  }

  // C10
  {
    final w = World(s);
    w.inU(() {
      runZoned(() {
        w.observed.listen((v) {
          if (v == 6) throw StateError("U' listener threw in ${w.where()}");
        });
      }, zoneValues: {#who: "U'"});
      w.vs.triggerActions();
      w.subject.add(6);
    });
    print("  C10 listener in U' (no handler of its own) nested in U: ${w.log}");
  }

  // C11
  {
    final w = World(s);
    w.inU(() {
      w.vs.zone.run(() => w.observed.listen((v) {
            if (v == 8) throw StateError('P listener threw in ${w.where()}');
          }));
      w.vs.triggerActions();
      w.subject.add(8);
    });
    print('  C11 listener in the provider zone itself: ${w.log}');
  }

  // C12
  {
    final w = World(s);
    final any =
        w.vs.zone.run(() => BehaviorSubject<Object?>.seeded(0, sync: true));
    final obs = Observed<Object?>(any.stream, w.vs.zone, s);
    w.inU(() {
      obs.cast<int>().listen((v) => w.log.add('cast got $v'));
      obs.cast<int>().listen((v) => w.log.add('cast+onError got $v'),
          onError: (Object e) => w.log.add('onError got ${e.runtimeType}'));
      w.vs.triggerActions();
      any.add('x');
      any.add(9);
    });
    print('  C12 Stream.cast<int> over an off-type value: ${w.log}');
  }
}

// C13: everything in the root zone of a fresh isolate, no guarded zone.
void _rootIsolate((SendPort, int) args) {
  final (port, si) = args;
  final s = Strategy.values[si];
  final vs = VirtualScheduler();
  final subject = vs.zone.run(() => BehaviorSubject<int>.seeded(0, sync: true));
  final observed = Observed<int>(subject.stream, vs.zone, s);
  observed.listen((v) {
    if (v == 1) throw StateError('root listener threw');
  });
  observed.listen((v) => port.send('Y got $v'));
  vs.triggerActions();
  subject.add(1);
  port.send('add(1) returned');
  subject.add(2);
  Future<void>.delayed(const Duration(milliseconds: 20), () => port.send('done'));
}

Future<void> rootCase(Strategy s) async {
  final msgs = ReceivePort();
  final errs = ReceivePort();
  final log = <String>[];
  final done = Completer<void>();
  msgs.listen((m) {
    if (m == 'done') {
      done.complete();
    } else {
      log.add('$m');
    }
  });
  errs.listen((e) => log.add('isolate uncaught error: ${(e as List)[0]}'));
  await Isolate.spawn(_rootIsolate, (msgs.sendPort, s.index),
      onError: errs.sendPort, errorsAreFatal: false);
  await done.future;
  await Future<void>.delayed(const Duration(milliseconds: 20));
  msgs.close();
  errs.close();
  print('  C13 ${s.name}: $log');
}

// C14
void cost() {
  const n = 2000000;
  for (final s in Strategy.values) {
    var best = 1 << 30;
    for (var r = 0; r < 5; r++) {
      final w = World(s);
      var sum = 0;
      w.inU(() {
        w.observed.listen((v) => sum += v);
        w.vs.triggerActions();
      });
      final sw = Stopwatch()..start();
      for (var i = 0; i < n; i++) {
        w.subject.add(i);
      }
      sw.stop();
      if (sw.elapsedMilliseconds < best) best = sw.elapsedMilliseconds;
      if (sum == -1) print('');
    }
    print('  C14 ${s.name}: $n deliveries to one listener in the test zone, '
        'best of 5: ${best}ms');
  }
}

Future<void> main() async {
  for (final s in Strategy.values) {
    await runStrategy(s);
  }
  print('== C13 root zone of an isolate, no guarded zone');
  for (final s in Strategy.values) {
    await rootCase(s);
  }
  print('== C14 cost');
  cost();
}
