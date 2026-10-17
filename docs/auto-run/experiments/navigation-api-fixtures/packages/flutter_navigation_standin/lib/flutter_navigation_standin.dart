/// A minimal Flutter implementation of navigation-api@v1's NavigationRouter
/// (experiment only): Flutter's own Navigator, observed through a
/// NavigatorObserver. It shows that the executor suite binds under
/// testWidgets; flutter-binding@v1 decides the real router (OQ-F1).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

final class StandinFlutterRouter extends NavigatorObserver
    implements NavigationRouter {
  StandinFlutterRouter(RouteState initial)
      : _stack = <NavigationEntry>[NavigationEntry(initial)];

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final List<NavigationEntry> _stack;
  final StreamController<RouteConfirmation> _controller =
      StreamController<RouteConfirmation>.broadcast(sync: true);
  bool _performing = false;

  @override
  bool get supportsPopUntil => true;

  @override
  List<NavigationEntry> get stack => List<NavigationEntry>.unmodifiable(_stack);

  @override
  Stream<RouteConfirmation> get confirmations => _controller.stream;

  /// The widget that hosts the router's Navigator.
  Widget host() => WidgetsApp(
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[this],
        color: const Color(0xFF000000),
        onGenerateInitialRoutes: (String _) =>
            <Route<dynamic>>[_page(_stack.first)],
        onGenerateRoute: (RouteSettings s) =>
            _page(s.arguments! as NavigationEntry),
      );

  Route<void> _page(NavigationEntry e) => PageRouteBuilder<void>(
        settings: RouteSettings(name: e.state.route.path, arguments: e),
        fullscreenDialog: e.modal,
        pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
            Text(e.state.route.path, textDirection: TextDirection.ltr),
      );

  static bool _isOn(Route<dynamic> r, NavRoute<Object?> target) {
    final Object? a = r.settings.arguments;
    return a is NavigationEntry && a.state.route == target;
  }

  /// The stack [calls] would leave, or a StateError before anything is done.
  List<NavigationEntry> _simulate(List<RouterCall> calls) {
    if (calls.isEmpty) throw ArgumentError.value(calls, 'calls', 'is empty');
    final List<NavigationEntry> next = List<NavigationEntry>.of(_stack);
    for (final RouterCall call in calls) {
      switch (call) {
        case PushRoute(:final NavigationEntry entry):
          next.add(entry);
        case ReplaceRoute(:final NavigationEntry entry):
          next[next.length - 1] = entry;
        case PopRoute():
          if (next.length < 2) throw StateError('a pop would empty the stack');
          next.removeLast();
        case PopUntilRoute(:final NavRoute<Object?> route):
          if (!next.any((NavigationEntry e) => e.state.route == route)) {
            throw StateError('$route is not on the stack');
          }
          while (next.last.state.route != route) {
            next.removeLast();
          }
      }
    }
    return next;
  }

  @override
  void perform(List<RouterCall> calls, ResolvedNavIntent intent) {
    final List<NavigationEntry> next = _simulate(calls);
    final NavigatorState nav = navigatorKey.currentState!;
    _performing = true;
    try {
      for (final RouterCall call in calls) {
        switch (call) {
          case PushRoute(:final NavigationEntry entry):
            unawaited(nav.push(_page(entry)));
          case ReplaceRoute(:final NavigationEntry entry):
            unawaited(nav.pushReplacement(_page(entry)));
          case PopRoute():
            nav.pop();
          case PopUntilRoute(:final NavRoute<Object?> route):
            nav.popUntil((Route<dynamic> r) => _isOn(r, route));
        }
      }
    } finally {
      _performing = false;
    }
    _stack
      ..clear()
      ..addAll(next);
    _controller.add(RouteConfirmation(stack: _stack, intent: intent));
  }

  /// A pop the platform made itself, such as a system back.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_performing || _stack.length < 2) return;
    _stack.removeLast();
    _controller.add(RouteConfirmation(stack: _stack, intent: const Back()));
  }
}
