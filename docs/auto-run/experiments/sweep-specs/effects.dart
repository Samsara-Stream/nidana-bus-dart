// S156: what each call that nidana.model D6's token list misses does on the
// pinned SDK. Run from the repository root: fvm dart docs/auto-run/experiments/sweep-specs/effects.dart
import 'dart:async';
import 'dart:math';

/// Counts the timers, periodic timers and microtasks [body] creates, run in a
/// zone that intercepts them.
Future<String> counted(String label, void Function() body) async {
  int timers = 0;
  int periodic = 0;
  int microtasks = 0;
  final Completer<void> done = Completer<void>();
  runZoned(
    () {
      body();
      // Let the body's own work be created before the counts are read.
    },
    zoneSpecification: ZoneSpecification(
      createTimer: (Zone self, ZoneDelegate parent, Zone zone, Duration d,
          void Function() f) {
        timers++;
        return parent.createTimer(zone, d, f);
      },
      createPeriodicTimer: (Zone self, ZoneDelegate parent, Zone zone,
          Duration d, void Function(Timer) f) {
        periodic++;
        return parent.createPeriodicTimer(zone, d, f);
      },
      scheduleMicrotask:
          (Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
        microtasks++;
        parent.scheduleMicrotask(zone, f);
      },
    ),
  );
  Timer(const Duration(milliseconds: 20), done.complete);
  await done.future;
  return '$label: timers=$timers periodic=$periodic microtasks=$microtasks';
}

Future<void> main() async {
  final DateTime before = DateTime.now().toUtc();
  final DateTime stamp = DateTime.timestamp();
  final DateTime after = DateTime.now().toUtc();
  print('DateTime.timestamp(): isUtc=${stamp.isUtc}, '
      'within two DateTime.now() reads=${!stamp.isBefore(before) && !stamp.isAfter(after)}');

  final Random secure = Random.secure();
  final Set<int> draws = <int>{for (int i = 0; i < 8; i++) secure.nextInt(1 << 32)};
  print('Random.secure(): 8 draws, ${draws.length} distinct (an entropy source)');

  print(await counted('Timer.run(f)', () => Timer.run(() {})));
  print(await counted('Future(f)', () => Future<void>(() {})));
  print(await counted('Stream.periodic(d) not listened',
      () => Stream<int>.periodic(const Duration(milliseconds: 1), (int i) => i)));
  late StreamSubscription<int> sub;
  print(await counted('Stream.periodic(d).listen', () {
    sub = Stream<int>.periodic(const Duration(milliseconds: 1), (int i) => i).listen((_) {});
  }));
  await sub.cancel();

  final Zone outer = Zone.current;
  final Zone inner = runZoned(() => Zone.current);
  print('runZoned(f): runs f in a new zone=${!identical(outer, inner)}, '
      'its parent the caller\'s zone=${identical(inner.parent, outer)}');
}
