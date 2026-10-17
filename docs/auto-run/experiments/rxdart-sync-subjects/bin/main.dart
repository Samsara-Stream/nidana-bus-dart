// Question: what do RxDart subjects constructed with sync: true actually do,
// on the pinned SDK, for the behaviors Spec §3.3, §3.4 and §3.10 rely on?
import 'dart:async';
import 'package:rxdart/rxdart.dart';

final log = <String>[];
void p(String s) { log.add(s); print(s); }

Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<void> case1BehaviorReplay() async {
  p('== case 1: BehaviorSubject.seeded(0, sync: true), listen then add(1)');
  final s = BehaviorSubject<int>.seeded(0, sync: true);
  s.listen((v) => p('  sub got $v'));
  p('  after listen (sync)');
  s.add(1);
  p('  after add(1) (sync)');
  await settle();
  p('  after event-loop turn');
  await s.close();
}

Future<void> case2PublishSync() async {
  p('== case 2: PublishSubject(sync: true), listen then add(1)');
  final s = PublishSubject<int>(sync: true);
  s.listen((v) => p('  sub got $v'));
  s.add(1);
  p('  after add(1) (sync)');
  await settle();
  await s.close();
}

Future<void> case3ReplaySync() async {
  p('== case 3: ReplaySubject(maxSize: 2, sync: true), add 1,2,3 then listen then add 4');
  final s = ReplaySubject<int>(maxSize: 2, sync: true);
  s..add(1)..add(2)..add(3);
  s.listen((v) => p('  sub got $v'));
  p('  after listen (sync)');
  s.add(4);
  p('  after add(4) (sync)');
  await settle();
  p('  after event-loop turn; values=${s.values}');
  await s.close();
}

Future<void> case4BehaviorDefault() async {
  p('== case 4: BehaviorSubject.seeded(0) default sync: false, listen then add(1)');
  final s = BehaviorSubject<int>.seeded(0);
  s.listen((v) => p('  sub got $v'));
  s.add(1);
  p('  after add(1) (sync)');
  await settle();
  p('  after event-loop turn');
  await s.close();
}

Future<void> case5ReentrantOtherTopic() async {
  p('== case 5: reentrant publish to another sync subject, no normalization');
  final x = PublishSubject<String>(sync: true);
  final y = PublishSubject<String>(sync: true);
  x.listen((v) { p('  x.sub1 got $v'); y.add('y-from-$v'); });
  x.listen((v) => p('  x.sub2 got $v'));
  y.listen((v) => p('  y.sub got $v'));
  x.add('a');
  p('  after x.add(a)');
  await settle();
  await x.close(); await y.close();
}

Future<void> case6ReentrantSameTopic() async {
  p('== case 6: reentrant add to the same sync subject during its own delivery');
  final x = PublishSubject<int>(sync: true);
  x.listen((v) {
    p('  sub got $v');
    if (v == 1) {
      try { x.add(2); p('  reentrant add(2) returned'); }
      catch (e) { p('  reentrant add(2) threw ${e.runtimeType}: $e'); }
    }
  });
  x.add(1);
  await settle();
  await x.close();
}

Future<void> case7Normalized() async {
  p('== case 7: reentrant publish deferred with scheduleMicrotask (Spec §3.4)');
  final x = PublishSubject<String>(sync: true);
  final y = PublishSubject<String>(sync: true);
  x.listen((v) { p('  x.sub1 got $v'); scheduleMicrotask(() => y.add('y-from-$v')); });
  x.listen((v) => p('  x.sub2 got $v'));
  y.listen((v) => p('  y.sub got $v'));
  x.add('a');
  p('  after x.add(a)');
  await settle();
  await x.close(); await y.close();
}

Future<void> case8BehaviorReplayRace() async {
  p('== case 8: BehaviorSubject sync: publish 1 right after listen, before replay');
  final s = BehaviorSubject<int>.seeded(0, sync: true);
  final got = <int>[];
  s.listen(got.add);
  s.add(1);
  s.add(1);
  s.add(2);
  await settle();
  p('  subscriber saw $got (no dedup in BehaviorSubject itself)');
  await s.close();
}

Future<void> case9ValueSync() async {
  p('== case 9: BehaviorSubject.value is synchronous');
  final s = BehaviorSubject<int>.seeded(0, sync: true);
  s.add(5);
  p('  value right after add(5) = ${s.value}');
  await s.close();
}

Future<void> case10PlainSyncController() async {
  p('== case 10: plain StreamController.broadcast(sync: true) reentrant add to itself');
  final c = StreamController<int>.broadcast(sync: true);
  c.stream.listen((v) {
    p('  sub got $v');
    if (v == 1) {
      try { c.add(2); p('  reentrant add(2) returned'); }
      catch (e) { p('  reentrant add(2) threw ${e.runtimeType}: $e'); }
    }
  });
  c.add(1);
  await settle();
  await c.close();
}

Future<void> main() async {
  await case1BehaviorReplay();
  await case2PublishSync();
  await case3ReplaySync();
  await case4BehaviorDefault();
  await case5ReentrantOtherTopic();
  await case6ReentrantSameTopic();
  await case7Normalized();
  await case8BehaviorReplayRace();
  await case9ValueSync();
  await case10PlainSyncController();
}
