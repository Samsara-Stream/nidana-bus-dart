// Surface of bus-testing@v1, the virtual scheduler: every declaration used
// with the types the Interface states. Passes when
// `fvm dart analyze --fatal-infos` reports nothing (ADR-001 item 4).
import 'dart:async';

import 'package:nidana_dart_runtime/testing.dart';

Future<void> drive() async {
  final VirtualScheduler defaults = VirtualScheduler();
  final VirtualScheduler scheduler = VirtualScheduler(
    initialTime: DateTime.utc(2026, 10, 17),
    maxActions: 1000,
    maxSettleTurns: 5,
  );
  final DateTime start = VirtualScheduler.defaultInitialTime;
  final DateTime now = scheduler.clock.now();
  final Stopwatch watch = scheduler.clock.stopwatch();
  final int maxActions = scheduler.maxActions;
  final int maxSettleTurns = scheduler.maxSettleTurns;
  final Timer timer =
      scheduler.run(() => Timer(const Duration(seconds: 1), () {}));
  final int answer = scheduler.run(() => 42);
  scheduler.triggerActions();
  scheduler.advanceTimeBy(const Duration(milliseconds: 300));
  scheduler.advanceTimeTo(DateTime.utc(2026, 10, 17, 0, 0, 2));
  final int microtasks = scheduler.pendingMicrotaskCount;
  final int timers = scheduler.pendingTimerCount;
  final DateTime? next = scheduler.nextTimerDue;
  final Future<void> settling = scheduler.settle();
  await settling;
  print(<Object?>[
    defaults, start, now, watch, maxActions, maxSettleTurns, timer, answer,
    microtasks, timers, next,
  ]);
}
