// Probes the runtime facts the settle cases rest on, against the stand-in
// VirtualScheduler: what reaches the virtual zone from a future the test
// completes in its own zone, with triggerActions alone and with settle; and
// whether work injected from a real periodic timer keeps settle from
// settling until its turn bound.
import 'dart:async';

import 'package:nidana_dart_runtime/testing.dart';

Future<void> main() async {
  // S1 a then-callback registered inside the virtual zone on a future the
  // test completes from its own zone.
  {
    final s = VirtualScheduler();
    final c = Completer<int>();
    final got = <String>[];
    s.run(() => c.future.then((v) => got.add('then $v in virtual: ${s.run(() => true)}')));
    c.complete(1);
    s.triggerActions();
    print('S1 after complete + triggerActions: $got (pending microtasks ${s.pendingMicrotaskCount})');
    await Future<void>.delayed(Duration.zero);
    print('S1 after one real turn: $got (pending microtasks ${s.pendingMicrotaskCount})');
    await s.settle();
    print('S1 after settle: $got (pending microtasks ${s.pendingMicrotaskCount})');
  }
  // S2 the same with Completer.sync.
  {
    final s = VirtualScheduler();
    final c = Completer<int>.sync();
    final got = <int>[];
    s.run(() => c.future.then(got.add));
    c.complete(2);
    print('S2 sync completer, right after complete: $got (pending microtasks ${s.pendingMicrotaskCount})');
    s.triggerActions();
    print('S2 after triggerActions: $got');
  }
  // S3 a then-callback inside the zone on a future completed later by a real
  // timer the test creates outside the zone.
  {
    final s = VirtualScheduler();
    final got = <int>[];
    final f = Future<int>.delayed(const Duration(milliseconds: 5), () => 3);
    s.run(() => f.then(got.add));
    s.triggerActions();
    print('S3 before the real timer: $got');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    print('S3 after the real timer fired: $got (pending microtasks ${s.pendingMicrotaskCount})');
    await s.settle();
    print('S3 after settle: $got');
  }
  // S4 work injected into the virtual zone by a real zero-period periodic
  // timer on every turn: settle runs out of turns.
  {
    final s = VirtualScheduler(maxSettleTurns: 3);
    var injected = 0;
    final t = Timer.periodic(Duration.zero, (_) {
      injected++;
      s.run(() => scheduleMicrotask(() {}));
    });
    try {
      await s.settle();
      print('S4 settled (unexpected), injected $injected');
    } on StateError catch (e) {
      print('S4 StateError after $injected injections: ${e.message}');
    }
    t.cancel();
    await s.settle();
    print('S4 after cancelling the injector, settle completes');
  }
  // S5 settle called inside the scheduler zone throws at the call.
  {
    final s = VirtualScheduler();
    try {
      s.run(() => s.settle());
      print('S5 no throw (unexpected)');
    } on StateError catch (e) {
      print('S5 StateError at the call: ${e.message}');
    }
  }
}
