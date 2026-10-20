// Stand-in for flutter-binding@v1's Flutter navigation executor (experiment
// only): navigation-api@v1's NavigationRouter over Flutter's own Navigator,
// and the NavigationExecutor wired to it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

/// Builds the Flutter route that presents [entry]; the route must carry
/// [settings].
typedef NavigationRouteBuilder = Route<dynamic> Function(
    NavigationEntry entry, RouteSettings settings);

/// navigation-api@v1's NavigationRouter over a Flutter Navigator.
final class FlutterNavigationRouter implements NavigationRouter {
  FlutterNavigationRouter(RouteState initial, {required this.routeBuilder})
      : _stack = <NavigationEntry>[NavigationEntry(initial)],
        _routes = <Route<dynamic>?>[null] {
    _observer = _RouterObserver(this);
  }

  final NavigationRouteBuilder routeBuilder;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final List<NavigationEntry> _stack;

  /// The route of each entry while a Navigator hosts the router.
  final List<Route<dynamic>?> _routes;
  late final _RouterObserver _observer;
  final StreamController<RouteConfirmation> _confirmations =
      StreamController<RouteConfirmation>.broadcast(sync: true);
  bool _performing = false;

  @override
  bool get supportsPopUntil => true;

  @override
  List<NavigationEntry> get stack => List<NavigationEntry>.unmodifiable(_stack);

  @override
  Stream<RouteConfirmation> get confirmations => _confirmations.stream;

  NavigatorObserver get observer => _observer;

  bool get isHosted => _observer.navigator != null;

  Route<dynamic> _build(NavigationEntry entry) {
    final RouteSettings settings =
        RouteSettings(name: '/${entry.state.route.path}', arguments: entry);
    final Route<dynamic> route = routeBuilder(entry, settings);
    if (!identical(route.settings, settings)) {
      throw ArgumentError.value(route, 'routeBuilder',
          'returned a route without the settings it was given');
    }
    return route;
  }

  /// For WidgetsApp.onGenerateInitialRoutes: one new route per entry.
  List<Route<dynamic>> initialRoutes(String initialRoute) {
    final List<Route<dynamic>> routes = <Route<dynamic>>[for (final NavigationEntry e in _stack) _build(e)];
    _routes
      ..clear()
      ..addAll(routes);
    return routes;
  }

  /// For WidgetsApp.onGenerateRoute: the router builds no route by name.
  Route<dynamic>? generateRoute(RouteSettings settings) => null;

  @override
  void perform(List<RouterCall> calls, ResolvedNavIntent intent) {
    if (calls.isEmpty) throw ArgumentError.value(calls, 'calls', 'is empty');
    // Validate every call and build every route before touching anything.
    final List<NavigationEntry> next = List<NavigationEntry>.of(_stack);
    final List<Route<dynamic>?> nextRoutes = List<Route<dynamic>?>.of(_routes);
    final bool hosted = isHosted;
    final List<(RouterCall, Route<dynamic>?)> plan = <(RouterCall, Route<dynamic>?)>[];
    for (final RouterCall call in calls) {
      switch (call) {
        case PushRoute(:final NavigationEntry entry):
          final Route<dynamic>? r = hosted ? _build(entry) : null;
          next.add(entry);
          nextRoutes.add(r);
          plan.add((call, r));
        case ReplaceRoute(:final NavigationEntry entry):
          final Route<dynamic>? r = hosted ? _build(entry) : null;
          next[next.length - 1] = entry;
          nextRoutes[nextRoutes.length - 1] = r;
          plan.add((call, r));
        case PopRoute():
          if (next.length < 2) throw StateError('a pop would empty the stack');
          next.removeLast();
          nextRoutes.removeLast();
          plan.add((call, null));
        case PopUntilRoute(:final NavRoute<Object?> route):
          final int target = next.lastIndexWhere((NavigationEntry e) => e.state.route == route);
          if (target < 0) throw StateError('$route is not on the stack');
          next.removeRange(target + 1, next.length);
          nextRoutes.removeRange(target + 1, nextRoutes.length);
          plan.add((call, nextRoutes[target]));
      }
    }
    if (hosted) {
      final NavigatorState nav = _observer.navigator!;
      _performing = true;
      try {
        final Route<dynamic>? top = _routes.last;
        nav.popUntil((Route<dynamic> r) => identical(r, top));
        for (final (RouterCall call, Route<dynamic>? r) in plan) {
          switch (call) {
            case PushRoute():
              unawaited(nav.push<Object?>(r!));
            case ReplaceRoute():
              unawaited(nav.pushReplacement<Object?, Object?>(r!));
            case PopRoute():
              nav.pop();
            case PopUntilRoute():
              nav.popUntil((Route<dynamic> x) => identical(x, r));
          }
        }
      } finally {
        _performing = false;
      }
    }
    _stack
      ..clear()
      ..addAll(next);
    _routes
      ..clear()
      ..addAll(nextRoutes);
    _confirmations.add(RouteConfirmation(stack: _stack, intent: intent));
  }

  void _platformPop(Route<dynamic> route) {
    if (_performing || _stack.length < 2 || !identical(route, _routes.last)) return;
    _stack.removeLast();
    _routes.removeLast();
    _confirmations.add(RouteConfirmation(stack: _stack, intent: const Back()));
  }
}

final class _RouterObserver extends NavigatorObserver {
  _RouterObserver(this.router);

  final FlutterNavigationRouter router;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => router._platformPop(route);
}

/// The Flutter navigation executor (Spec Appendix A.8; Guide §3.4).
final class FlutterNavigationExecutor {
  FlutterNavigationExecutor._(this.bus, this.router, this.executor);

  factory FlutterNavigationExecutor(
    Bus bus, {
    required RouteState initial,
    required NavigationRouteBuilder routeBuilder,
    String name = 'flutter-navigation',
    bool forwardPlatformRoutes = true,
  }) {
    final FlutterNavigationRouter router =
        FlutterNavigationRouter(initial, routeBuilder: routeBuilder);
    final NavigationExecutor executor = NavigationExecutor(bus, router, name: name);
    final FlutterNavigationExecutor self = FlutterNavigationExecutor._(bus, router, executor);
    if (forwardPlatformRoutes) {
      final Publisher platform = bus.publisher(ExecutorSource(name));
      final _PlatformRoutes forwarding = _PlatformRoutes(platform);
      self._platform = platform;
      self._forwarding = forwarding;
      final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
      final String initialRoute = binding.platformDispatcher.defaultRouteName;
      if (initialRoute != Navigator.defaultRouteName) {
        forwarding.forward(Uri.parse(initialRoute));
      }
      binding.addObserver(forwarding);
    }
    bus.onShutdown(self.dispose);
    return self;
  }

  final Bus bus;
  final FlutterNavigationRouter router;
  final NavigationExecutor executor;
  Publisher? _platform;
  _PlatformRoutes? _forwarding;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    executor.dispose();
    final _PlatformRoutes? forwarding = _forwarding;
    if (forwarding != null) WidgetsBinding.instance.removeObserver(forwarding);
    _platform?.dispose();
  }
}

final class _PlatformRoutes with WidgetsBindingObserver {
  _PlatformRoutes(this.publisher);

  final Publisher publisher;

  void forward(Uri uri) => publisher.publish(NavigationTopics.intent, DeepLink(uri));

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    forward(routeInformation.uri);
    return SynchronousFuture<bool>(true);
  }
}
