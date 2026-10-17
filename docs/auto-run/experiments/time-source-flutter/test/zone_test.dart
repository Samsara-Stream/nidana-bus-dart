// Question: under Flutter's testWidgets (whose body runs in the binding's
// FakeAsync zone), does a bus-owned pass-through zone let tester.pump drive
// RxDart time operators, and is a bus-owned virtual zone independent of pump?
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

class VirtualTimers {
  Duration now = Duration.zero;
  final _pending = <({Duration due, void Function() fire})>[];
  late final Zone zone = Zone.current.fork(specification: ZoneSpecification(
    createTimer: (self, parent, zone, d, f) {
      final e = (due: now + d, fire: () => zone.run(f));
      _pending.add(e);
      return parent.createTimer(zone, const Duration(days: 365), () {})..cancel();
    },
  ));
  void advanceTimeBy(Duration d) {
    final target = now + d;
    for (final e in _pending.where((e) => e.due <= target).toList()) { _pending.remove(e); now = e.due; e.fire(); }
    now = target;
  }
}

void main() {
  testWidgets('pass-through bus zone: tester.pump drives debounceTime', (tester) async {
    final busZone = Zone.current.fork(); // production provider: pass-through
    final s = PublishSubject<int>(sync: true);
    final out = <int>[];
    busZone.run(() => s.debounceTime(const Duration(milliseconds: 300)).listen(out.add));
    await tester.pumpWidget(const SizedBox());
    s..add(1)..add(2);
    await tester.pump(const Duration(milliseconds: 299));
    debugPrint('pass-through at 299ms: $out');
    await tester.pump(const Duration(milliseconds: 1));
    debugPrint('pass-through at 300ms: $out');
    expect(out, [2]);
  });

  testWidgets('virtual bus zone: independent of tester.pump', (tester) async {
    final vt = VirtualTimers();
    final s = PublishSubject<int>(sync: true);
    final out = <int>[];
    vt.zone.run(() => s.debounceTime(const Duration(milliseconds: 300)).listen(out.add));
    s..add(1)..add(2);
    await tester.pump(const Duration(seconds: 1));
    debugPrint('virtual after tester.pump(1s): $out');
    vt.advanceTimeBy(const Duration(milliseconds: 300));
    debugPrint('virtual after advanceTimeBy(300ms): $out');
    expect(out, [2]);
  });
}
