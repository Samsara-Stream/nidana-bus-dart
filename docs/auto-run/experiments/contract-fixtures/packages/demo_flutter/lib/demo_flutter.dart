/// A Flutter implementation of the Executor interface: the route changes only
/// after the framework pumps, so conformance needs the harness's settle().
library;

import 'package:demo_contracts/demo_contracts.dart';
import 'package:flutter/widgets.dart';

final class FlutterExecutor extends NavigatorObserver implements Executor {
  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  String _current = '/';

  @override
  String get current => _current;

  @override
  Future<void> go(String route) {
    key.currentState!.pushNamed<void>(route);
    return Future<void>.value();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _current = route.settings.name ?? _current;
  }

  Widget app() => WidgetsApp(
        navigatorKey: key,
        navigatorObservers: [this],
        color: const Color(0xFF000000),
        initialRoute: '/',
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, _, _) =>
              Text(settings.name ?? '', textDirection: TextDirection.ltr),
        ),
      );
}
