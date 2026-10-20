// Binding: runs navigation-api@v1's executor conformance suite against
// FlutterNavigationExecutor (flutter-binding@v2), whose router is a
// FlutterNavigationRouter over the Navigator of a WidgetsApp, under
// testWidgets (ADR-001 item 4). Each case builds production-provider buses
// in the test body, so tester.pump drives their clocks and timers, and shuts
// every bus down and unmounts the tree before the body ends (ADR-003
// item 7). The executor is constructed before its WidgetsApp is pumped, as
// an app's bootstrap constructs it before runApp mounts anything
// (flutter-binding@v2 G12); the platform's back is the navigation channel's
// popRoute message, which reaches the Navigator through WidgetsApp. The
// WidgetsApp is pumped when the suite asks for the executor, which most
// cases do before start(); its pages are text and mount no page or module
// scope, so scope timing (bus-api@v2 G42) rejects nothing, while an app
// mounts its WidgetsApp after start() (flutter-binding@v2 G16).
//
// The package imports name the implementation, so the replay tool reports
// this binding as PENDING until nidana_dart_runtime_flutter exists (ADR-001
// item 9).
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

import '../../navigation-api/behavior/navigation_executor_conformance.dart';

Route<dynamic> _page(NavigationEntry entry, RouteSettings settings) =>
    PageRouteBuilder<void>(
      settings: settings,
      fullscreenDialog: entry.modal,
      pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
          Text(entry.state.route.path, textDirection: TextDirection.ltr),
    );

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
    final FlutterNavigationExecutor navigation =
        FlutterNavigationExecutor(bus, initial: initial, routeBuilder: _page, name: name);
    final FlutterNavigationRouter router = navigation.router;
    await tester.pumpWidget(WidgetsApp(
      navigatorKey: router.navigatorKey,
      navigatorObservers: <NavigatorObserver>[router.observer],
      onGenerateInitialRoutes: router.initialRoutes,
      onGenerateRoute: router.generateRoute,
      color: const Color(0xFF000000),
    ));
    return (executor: navigation.executor, router: router);
  }

  @override
  Future<void> platformBack(NavigationRouter router) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(const MethodCall('popRoute')),
      (ByteData? _) {},
    );
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
