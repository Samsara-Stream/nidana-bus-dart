// Follow-up: when exactly does a sync BehaviorSubject deliver its replay, are
// later adds synchronous once the first delivery happened, and can a custom
// subject built on dart:async deliver the current value synchronously on listen?
import 'dart:async';
import 'package:rxdart/rxdart.dart';

void p(String s) => print(s);

Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<void> a() async {
  p('== a: replay timing relative to a microtask scheduled right after listen');
  final s = BehaviorSubject<int>.seeded(0, sync: true);
  s.listen((v) => p('  sub got $v'));
  scheduleMicrotask(() => p('  microtask scheduled after listen ran'));
  p('  after listen (sync)');
  await settle();
  p('  -- now add(1) after the first turn');
  s.add(1);
  p('  after add(1) (sync)');
  await settle();
  await s.close();
}

Future<void> b() async {
  p('== b: two subscribers, second subscribes while first is established');
  final s = BehaviorSubject<int>.seeded(0, sync: true);
  s.listen((v) => p('  s1 got $v'));
  await settle();
  s.listen((v) => p('  s2 got $v'));
  s.add(1);
  p('  after add(1) (sync): s1 delivered synchronously, s2 not yet established');
  await settle();
  p('  after turn');
  await s.close();
}

Future<void> c() async {
  p('== c: Stream.multi with addSync of the current value inside onListen');
  var current = 0;
  final listeners = <MultiStreamController<int>>{};
  final stream = Stream<int>.multi((ctl) {
    ctl.addSync(current);
    listeners.add(ctl);
    ctl.onCancel = () => listeners.remove(ctl);
  }, isBroadcast: true);
  void publish(int v) { current = v; for (final l in listeners.toList()) l.addSync(v); }
  stream.listen((v) => p('  sub got $v'));
  p('  after listen (sync)');
  publish(1);
  p('  after publish(1) (sync)');
  await settle();
  p('  after turn');
}

Future<void> d() async {
  p('== d: Stream.multi reentrant addSync to the same stream during delivery');
  final listeners = <MultiStreamController<int>>{};
  final stream = Stream<int>.multi((ctl) { listeners.add(ctl); }, isBroadcast: true);
  void publish(int v) { for (final l in listeners.toList()) l.addSync(v); }
  stream.listen((v) { p('  s1 got $v'); if (v == 1) { try { publish(2); p('  reentrant publish(2) returned'); } catch (e) { p('  threw $e'); } } });
  stream.listen((v) => p('  s2 got $v'));
  publish(1);
  p('  after publish(1)');
  await settle();
}

Future<void> e() async {
  p('== e: ValueStream (BehaviorSubject.stream) transformed by map, listen then add');
  final s = BehaviorSubject<int>.seeded(0, sync: true);
  s.stream.map((v) => v * 10).listen((v) => p('  mapped got $v'));
  p('  after listen');
  s.add(1);
  p('  after add(1)');
  await settle();
  await s.close();
}

Future<void> main() async {
  await a();
  await b();
  await c();
  await d();
  await e();
}
