// Probe: when does done reach a subscriber of a closed RxDart sync subject,
// and of a closed sync StreamController? Captured in ../output-close.txt.
// The BehaviorSubject line shows done arriving from a microtask, which a
// virtual scheduler's zone does not see (the bus-api@v1 G9 and G18 cases
// failed on a stand-in that relied on it).
import 'dart:async';
import 'package:rxdart/rxdart.dart';

Future<void> probe(String label, StreamController<int> c, Stream<int> s) async {
  final log = <String>[];
  s.listen((v) => log.add('v$v'),
      onError: (Object e) => log.add('err'), onDone: () => log.add('done'));
  await Future<void>.delayed(Duration.zero);
  c.addError(StateError('x'));
  unawaited(c.close());
  log.add('after close (sync)');
  scheduleMicrotask(() => log.add('microtask after close'));
  await Future<void>.delayed(Duration.zero);
  print('$label: $log');
}

Future<void> main() async {
  final b = BehaviorSubject<int>.seeded(1, sync: true);
  await probe('BehaviorSubject sync', b, b.stream);
  final p = PublishSubject<int>(sync: true);
  await probe('PublishSubject sync', p, p.stream);
  final r = ReplaySubject<int>(maxSize: 2, sync: true);
  await probe('ReplaySubject sync', r, r.stream);
  final c = StreamController<int>(sync: true);
  await probe('StreamController sync', c, c.stream);
  final bc = StreamController<int>.broadcast(sync: true);
  await probe('StreamController.broadcast sync', bc, bc.stream);
}
