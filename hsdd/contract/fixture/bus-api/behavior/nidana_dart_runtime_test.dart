// Binding: runs the bus-api@v1 conformance suite against the producer's
// bus in package:nidana_dart_runtime, each case on fresh TestBus instances,
// under `dart test`.
//
// TestBus and its scheduler are bus-testing@v1's (package:
// nidana_dart_runtime/testing.dart). This binding forward-references the
// names this contract's ## Validation section lists; the replay tool
// reports it as PENDING until the package exists (ADR-001 item 9).
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';
import 'package:test/test.dart';

import 'bus_api_conformance.dart';

final class _Harness implements BusApiHarness {
  final List<TestBus> _buses = <TestBus>[];

  TestBus _of(Bus bus) => bus as TestBus;

  @override
  Bus bus([BusConfig config = const BusConfig()]) {
    final TestBus bus = TestBus(config);
    _buses.add(bus);
    return bus;
  }

  @override
  void flush(Bus bus) => _of(bus).scheduler.triggerActions();

  @override
  void advance(Bus bus, Duration duration) =>
      _of(bus).scheduler.advanceTimeBy(duration);

  @override
  int pendingTimers(Bus bus) => _of(bus).scheduler.pendingTimerCount;

  @override
  Future<void> settle() async {
    for (final TestBus bus in _buses) {
      await bus.scheduler.settle();
    }
  }
}

void main() {
  for (final c in busApiConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
