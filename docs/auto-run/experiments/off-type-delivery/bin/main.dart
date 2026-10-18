// Experiment for nidana.runtime's decomposition (S22): where does the
// TypeError go when one subscription converts an Object?-held value at its
// own type argument and the value is off-type (bus-api@v1 G41 leaves the
// value outside its guarantee; G13 and G18 must still hold for the others)?
//
// Each case delivers through a sync subject or controller held at Object?,
// from inside a zone with its own uncaught-error handler (the provider zone),
// with three listeners: one at Object?, one converting `as int` in its
// onData, one at Object? registered after it. A String is published, then an
// int. The case prints what each listener received, what reached the zone
// handler, and whether the add() call threw.
import 'dart:async';

import 'package:rxdart/rxdart.dart';

void run(String name, void Function(Zone zone, List<String> log) body) {
  final log = <String>[];
  late Zone zone;
  runZonedGuarded(() {
    zone = Zone.current;
    body(zone, log);
  }, (e, st) => log.add('zone handler: ${e.runtimeType}'));
  // Let any microtask (BehaviorSubject replay) run.
  Future<void>.delayed(Duration.zero, () {
    print('--- $name');
    log.forEach(print);
  });
}

void listeners(Stream<Object?> s, List<String> log, {bool viaMap = false}) {
  s.listen((v) => log.add('A(Object?) got $v'));
  if (viaMap) {
    s.map((v) => v as int).listen((v) => log.add('B(int) got $v'),
        onError: (Object e) => log.add('B(int) onError ${e.runtimeType}'));
  } else {
    s.listen((v) {
      final int i = v as int;
      log.add('B(int) got $i');
    });
  }
  s.listen((v) => log.add('C(Object?) got $v'));
}

void publish(void Function(Object?) add, List<String> log, Object? v) {
  try {
    add(v);
    log.add('add($v) returned');
  } catch (e) {
    log.add('add($v) threw ${e.runtimeType}');
  }
}

void main() {
  run('1 sync broadcast controller, cast in onData', (zone, log) {
    final c = StreamController<Object?>.broadcast(sync: true);
    listeners(c.stream, log);
    publish(c.add, log, 'off-type');
    publish(c.add, log, 7);
  });
  run('2 sync broadcast controller, cast in map with onError', (zone, log) {
    final c = StreamController<Object?>.broadcast(sync: true);
    listeners(c.stream, log, viaMap: true);
    publish(c.add, log, 'off-type');
    publish(c.add, log, 7);
  });
  run('3 sync PublishSubject, cast in onData', (zone, log) {
    final s = PublishSubject<Object?>(sync: true);
    listeners(s.stream, log);
    publish(s.add, log, 'off-type');
    publish(s.add, log, 7);
  });
  run('4 sync BehaviorSubject seeded 0, cast in onData, after replay', (zone, log) {
    final s = BehaviorSubject<Object?>.seeded(0, sync: true);
    listeners(s.stream, log);
    // Publish after the replay microtask, so delivery is synchronous.
    scheduleMicrotask(() {
      publish(s.add, log, 'off-type');
      publish(s.add, log, 7);
    });
  });
  run('5 sync BehaviorSubject seeded off-type, cast in onData (replay)', (zone, log) {
    final s = BehaviorSubject<Object?>.seeded('off-type seed', sync: true);
    listeners(s.stream, log);
    scheduleMicrotask(() => publish(s.add, log, 7));
  });
  run('6 sync BehaviorSubject seeded 0, distinct then cast in onData', (zone, log) {
    final s = BehaviorSubject<Object?>.seeded(0, sync: true);
    listeners(s.stream.distinct(), log);
    scheduleMicrotask(() {
      publish(s.add, log, 'off-type');
      publish(s.add, log, 7);
    });
  });
}
