// Binding: runs navigation-api@v1's executor conformance suite against
// NavigationExecutor over the producer's InMemoryRouter (package:
// nidana_dart_navigation/testing.dart), each case on fresh TestBus instances
// (bus-testing@v2), under `dart test`. Every case runs twice: on a router
// that pops until natively, and on one that does not, so that BackTo is
// also synthesized from pops (Guide §3.2). Both registrations begin with the
// case's guarantee id, so a --guarantee restriction selects both.
//
// The package imports name the implementation, so the replay tool reports
// this binding as PENDING until nidana_dart_navigation exists (ADR-001
// item 9).
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_navigation/testing.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';
import 'package:test/test.dart';

import 'navigation_executor_conformance.dart';

final class _Harness implements NavigationExecutorHarness {
  _Harness({required this.popUntil});

  final bool popUntil;
  final List<TestBus> _buses = <TestBus>[];

  @override
  Bus bus([BusConfig config = const BusConfig()]) {
    final TestBus bus = TestBus(config);
    _buses.add(bus);
    return bus;
  }

  @override
  Future<NavigationRun> executor(Bus bus, RouteState initial,
      {String name = 'navigation'}) async {
    final InMemoryRouter router =
        InMemoryRouter(initial, supportsPopUntil: popUntil);
    return (executor: NavigationExecutor(bus, router, name: name), router: router);
  }

  @override
  Future<void> platformBack(NavigationRouter router) async {
    (router as InMemoryRouter).platformBack();
    await settle();
  }

  @override
  Future<void> elapse(Duration duration) async {
    for (final TestBus bus in _buses) {
      bus.scheduler.advanceTimeBy(duration);
    }
  }

  @override
  Future<void> settle() async {
    for (final TestBus bus in _buses) {
      await bus.scheduler.settle();
    }
  }
}

void main() {
  for (final c in navigationExecutorConformance) {
    test(c.name, () => c.body(_Harness(popUntil: true)));
    test('${c.name} (BackTo synthesized from pops)',
        () => c.body(_Harness(popUntil: false)));
  }
}
