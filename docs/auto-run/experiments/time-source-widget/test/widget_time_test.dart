// time-source-widget: what the production provider does under testWidgets.
//
//   W1 a provider that captures Zone.current inside the test body: does
//      tester.pump drive RxDart time operators?
//   W2 package:clock and DateTime.now() under testWidgets.
//   W3 a provider captured in setUp, outside the test body's fake zone.
//   W4 RxDart 0.28's switchMap under testWidgets: when does it listen to the
//      next inner after a switch, against a switchMap that does not wait?
//   W5 a timer cancelled in the dispose of an ancestor that owns it, after a
//      descendant's dispose started it (BusProvider shutting the bus down
//      after a module binding released its last scope reference).
//   W6 a pending RxDart debounce timer whose subscription is cancelled in
//      dispose.
// pending_timer_test.dart holds the case that must fail: a timer still pending
// when the test body ends.
//
// Run: fvm flutter test test/widget_time_test.dart; fvm flutter test test/pending_timer_test.dart
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:time_source_widget/scheduler.dart';

Duration d(int n) => Duration(milliseconds: n);

/// Stand-in for a bus that owns timers and cancels them at shutdown.
class FakeBus {
  FakeBus() : provider = RealTimeProvider();
  final RealTimeProvider provider;
  final _timers = <Timer>{};
  void startGrace(Duration grace, void Function() expire) {
    late Timer t;
    t = provider.zone.run(() => Timer(grace, () {
          _timers.remove(t);
          expire();
        }));
    _timers.add(t);
  }

  void shutdown() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}

class Owner extends StatefulWidget {
  const Owner({super.key, required this.bus, required this.child});
  final FakeBus bus;
  final Widget child;
  @override
  State<Owner> createState() => _OwnerState();
}

class _OwnerState extends State<Owner> {
  @override
  void dispose() {
    debugPrint('W5 owner dispose: shutdown');
    widget.bus.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ModuleBinding extends StatefulWidget {
  const ModuleBinding({super.key, required this.bus});
  final FakeBus bus;
  @override
  State<ModuleBinding> createState() => _ModuleBindingState();
}

class _ModuleBindingState extends State<ModuleBinding> {
  @override
  void dispose() {
    debugPrint('W5 module binding dispose: last release starts the grace timer');
    widget.bus.startGrace(d(100), () => debugPrint('W5 grace expired'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class Debounced extends StatefulWidget {
  const Debounced({super.key, required this.source, required this.provider});
  final Stream<int> source;
  final RealTimeProvider provider;
  @override
  State<Debounced> createState() => _DebouncedState();
}

class _DebouncedState extends State<Debounced> {
  late final StreamSubscription<int> sub;
  @override
  void initState() {
    super.initState();
    sub = widget.provider.zone.run(() => widget.source.debounceTime(d(300)).listen((_) {}));
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  late RealTimeProvider fromSetUp;
  setUp(() => fromSetUp = RealTimeProvider());

  testWidgets('W1 captured zone: tester.pump drives debounceTime', (tester) async {
    final prov = RealTimeProvider();
    final s = PublishSubject<int>(sync: true);
    final out = <int>[];
    prov.zone.run(() => s.debounceTime(d(300)).listen(out.add));
    s..add(1)..add(2);
    await tester.pump(d(299));
    final at299 = List.of(out);
    await tester.pump(d(1));
    debugPrint('W1 captured zone: at 299ms $at299, at 300ms $out');
  });

  testWidgets('W2 clock under testWidgets', (tester) async {
    final prov = RealTimeProvider();
    final c0 = prov.clock.now();
    final d0 = DateTime.now();
    await tester.pump(const Duration(seconds: 1));
    debugPrint('W2 provider clock starts ${c0.toIso8601String()}, '
        'advanced ${prov.clock.now().difference(c0).inMilliseconds}ms over pump(1s); '
        'DateTime.now advanced ${DateTime.now().difference(d0).inMilliseconds}ms; '
        'clock.now() inside the body equals the captured clock: ${clock.now() == prov.clock.now()}');
  });

  testWidgets('W3 provider captured in setUp: tester.pump does not drive it', (tester) async {
    final s = PublishSubject<int>(sync: true);
    final out = <int>[];
    fromSetUp.zone.run(() => s.debounceTime(d(300)).listen(out.add));
    s..add(1)..add(2);
    await tester.pump(const Duration(seconds: 1));
    debugPrint('W3 setUp zone: after pump(1s) $out; same zone as the body: '
        '${identical(fromSetUp.zone, Zone.current)}');
  });

  testWidgets('W4 RxDart switchMap after a switch under testWidgets', (tester) async {
    final prov = RealTimeProvider();
    final s = PublishSubject<int>(sync: true);
    final out = <String>[];
    final start = clock.now();
    String at() => '${clock.now().difference(start).inMilliseconds}ms';
    prov.zone.run(() => s.switchMap((v) => Rx.timer(v, d(200))).listen((v) => out.add('$v@${at()}')));
    s.add(1);
    await tester.pump(d(100));
    s.add(2);
    await tester.pump(d(300));
    final afterPump = List.of(out);
    await tester.pump(d(300));
    debugPrint('W4 RxDart switchMap: after pump to 400ms $afterPump; after pump to 700ms $out');
  });

  testWidgets('W4b switchMapNoWait under testWidgets', (tester) async {
    final prov = RealTimeProvider();
    final s = PublishSubject<int>(sync: true);
    final out = <String>[];
    final start = clock.now();
    String at() => '${clock.now().difference(start).inMilliseconds}ms';
    prov.zone.run(() => s.switchMapNoWait((v) => Rx.timer(v, d(200))).listen((v) => out.add('$v@${at()}')));
    s.add(1);
    await tester.pump(d(100));
    s.add(2);
    await tester.pump(d(300));
    debugPrint('W4b switchMapNoWait: after pump to 400ms $out');
  });

  testWidgets('W5 an ancestor shutdown cancels the grace timer a descendant started', (tester) async {
    final bus = FakeBus();
    await tester.pumpWidget(Owner(bus: bus, child: ModuleBinding(bus: bus)));
    debugPrint('W5 tree mounted; the test body ends and the binding unmounts the tree');
  });

  testWidgets('W6 a debounce subscription cancelled in dispose leaves no timer', (tester) async {
    final prov = RealTimeProvider();
    final s = PublishSubject<int>(sync: true);
    await tester.pumpWidget(Debounced(source: s, provider: prov));
    s.add(1);
    debugPrint('W6 debounce timer pending as the body ends');
  });
}
