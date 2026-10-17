// Stand-in for the binding flutter-binding@v1 will carry (ADR-001 item 4):
// navigation-api@v1's executor suite on NavigationExecutor over a Flutter
// router, under testWidgets, on a production-provider bus built in the test
// body, so tester.pump drives the bus clock (ADR-003 item 7). run.sh copies
// it to hsdd/contract/fixture/flutter-binding/behavior/, where it imports the
// conformance library by relative path, as the real binding will.
import 'package:flutter/widgets.dart';
import 'package:flutter_navigation_standin/flutter_navigation_standin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

import '../../navigation-api/behavior/navigation_executor_conformance.dart';

final class _Harness implements NavigationExecutorHarness {
  _Harness(this.tester);

  final WidgetTester tester;
  final List<Bus> buses = <Bus>[];

  @override
  Bus bus([BusConfig config = const BusConfig()]) {
    final Bus bus = Bus(config); // production provider: this zone and clock
    buses.add(bus);
    return bus;
  }

  @override
  Future<NavigationRun> executor(Bus bus, RouteState initial,
      {String name = 'navigation'}) async {
    final StandinFlutterRouter router = StandinFlutterRouter(initial);
    await tester.pumpWidget(router.host());
    return (executor: NavigationExecutor(bus, router, name: name), router: router);
  }

  @override
  Future<void> platformBack(NavigationRouter router) async {
    await (router as StandinFlutterRouter).navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
  }

  @override
  Future<void> elapse(Duration duration) => tester.pump(duration);

  @override
  Future<void> settle() => tester.pumpAndSettle();
}

void main() {
  for (final c in navigationExecutorConformance) {
    testWidgets(c.name, (WidgetTester tester) async {
      final _Harness h = _Harness(tester);
      try {
        await c.body(h);
      } finally {
        // No bus timer may outlive the body (ADR-003 item 7).
        for (final Bus bus in h.buses) {
          bus.shutdown();
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    });
  }
}
