// Surface fixture for flutter-binding@v2 (ADR-001 item 4): the Flutter router
// and executor, the module-scope observer, and the bootstrap of Guide §3.5
// wired into a WidgetsApp, used with the types the Interface states.
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

abstract final class AppRoutes {
  static const NavRoute<void> home = NavRoute<void>('home');
  static const NavRoute<int> order = NavRoute<int>('orders/detail');
  static const NavRoute<void> cart = NavRoute<void>('checkout/cart');
}

const EventTopic<int> checkoutTaps = EventTopic<int>(name: 'checkout.taps');
const StateTopic<int> checkoutState = StateTopic<int>(name: 'checkout.state', initial: 0);

final Topology checkoutFlow = topology('checkout-flow', Scope.module,
    (TopologyBuilder b) => b.write(checkoutState, b.read(checkoutTaps)));

/// The app's mapping from an entry to the Flutter route that presents it.
Route<dynamic> pages(NavigationEntry entry, RouteSettings settings) => PageRouteBuilder<void>(
      settings: settings,
      fullscreenDialog: entry.modal,
      pageBuilder: (BuildContext context, Animation<double> a, Animation<double> b) =>
          Text(entry.state.route.path),
    );

final NavigationRouteBuilder routeBuilder = pages;

/// Guide §3.5's bootstrap, then the app: the executor is constructed before
/// start(), and start() before anything mounts.
Widget bootstrap(Bus bus, Topology resolver) {
  bus.activate(resolver);
  final FlutterNavigationExecutor navigation = FlutterNavigationExecutor(
    bus,
    initial: RouteState(route: AppRoutes.home),
    routeBuilder: routeBuilder,
    name: 'flutter-navigation',
    forwardPlatformRoutes: true,
  );
  final ModuleScopeObserver modules = ModuleScopeObserver(bus, <ModuleRoutes>[
    ModuleRoutes(
      moduleId: 'checkout',
      prefix: 'checkout',
      topologies: <Topology>[checkoutFlow],
      gracePeriod: const Duration(milliseconds: 300),
    ),
  ]);
  bus.start();
  final FlutterNavigationRouter router = navigation.router;
  return BusProvider(
    bus: bus,
    child: WidgetsApp(
      navigatorKey: router.navigatorKey,
      navigatorObservers: <NavigatorObserver>[router.observer, modules],
      onGenerateInitialRoutes: router.initialRoutes,
      onGenerateRoute: router.generateRoute,
      color: const Color(0xFF000000),
    ),
  );
}

void executor(FlutterNavigationExecutor navigation) {
  final Bus bus = navigation.bus;
  final FlutterNavigationRouter router = navigation.router;
  final NavigationExecutor executor = navigation.executor;
  final bool disposed = navigation.isDisposed;
  navigation.dispose();
  print(<Object>[bus, router, executor, disposed]);
}

void router(FlutterNavigationRouter router) {
  final NavigationRouter port = router;
  final List<NavigationEntry> stack = router.stack;
  final bool popUntil = router.supportsPopUntil;
  final Stream<RouteConfirmation> confirmations = router.confirmations;
  router.perform(<RouterCall>[PushRoute(NavigationEntry(RouteState(route: AppRoutes.order, args: 7)))],
      AppRoutes.order.go(7));
  final NavigationRouteBuilder build = router.routeBuilder;
  final GlobalKey<NavigatorState> key = router.navigatorKey;
  final NavigatorObserver observer = router.observer;
  final bool hosted = router.isHosted;
  final List<Route<dynamic>> initial = router.initialRoutes('/');
  final Route<dynamic>? none = router.generateRoute(const RouteSettings(name: '/home'));
  final InitialRouteListFactory initialFactory = router.initialRoutes;
  final RouteFactory routeFactory = router.generateRoute;
  final FlutterNavigationRouter another =
      FlutterNavigationRouter(RouteState(route: AppRoutes.home), routeBuilder: pages);
  print(<Object?>[
    port, stack, popUntil, confirmations, build, key, observer, hosted, initial, none,
    initialFactory, routeFactory, another,
  ]);
}

void modules(ModuleScopeObserver observer, ModuleRoutes module, Route<dynamic> route) {
  final NavigatorObserver asObserver = observer;
  final Bus bus = observer.bus;
  final List<ModuleScope> scopes = observer.scopes;
  final bool disposed = observer.isDisposed;
  observer.dispose();
  final String? path = ModuleScopeObserver.pathOf(route);
  final String moduleId = module.moduleId;
  final String prefix = module.prefix;
  final List<Topology> topologies = module.topologies;
  final Duration? grace = module.gracePeriod;
  final bool matches = module.matches('checkout/cart');
  print(<Object?>[asObserver, bus, scopes, disposed, path, moduleId, prefix, topologies, grace, matches]);
}
