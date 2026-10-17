// Probes for OQ-F1 against go_router 18.1.0 (Guide §3.4's router): when a
// GoRouter call reaches the Navigator, what go does to the stack, what the
// router does with the platform's initial route, and whether it pops until.
// Each probe prints one line `R{n} ...` and asserts what it saw.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class Log extends NavigatorObserver {
  final List<String> events = <String>[];
  static String name(Route<dynamic>? r) => r?.settings.name ?? '-';
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => events.add('push ${name(route)}');
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => events.add('pop ${name(route)}');
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => events.add('remove ${name(route)}');
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      events.add('replace ${name(oldRoute)} -> ${name(newRoute)}');
}

Page<void> _page(GoRouterState s) => NoTransitionPage<void>(
      key: s.pageKey,
      name: s.matchedLocation,
      child: Text(s.matchedLocation, textDirection: TextDirection.ltr),
    );

GoRouter router(Log log) => GoRouter(
      observers: <NavigatorObserver>[log],
      routes: <RouteBase>[
        GoRoute(path: '/', pageBuilder: (BuildContext _, GoRouterState s) => _page(s), routes: <RouteBase>[
          GoRoute(path: 'a', pageBuilder: (BuildContext _, GoRouterState s) => _page(s)),
          GoRoute(path: 'b', pageBuilder: (BuildContext _, GoRouterState s) => _page(s)),
          GoRoute(path: 'detail/:id', pageBuilder: (BuildContext _, GoRouterState s) => _page(s)),
        ]),
      ],
    );

Widget host(GoRouter r) => WidgetsApp.router(routerConfig: r, color: const Color(0xFF000000));

void main() {
  testWidgets('R2 GoRouter.push reaches the Navigator only after a frame, not when push returns', (WidgetTester tester) async {
    final Log log = Log();
    final GoRouter r = router(log);
    await tester.pumpWidget(host(r));
    log.events.clear();
    unawaited(r.push<Object?>('/a'));
    final List<String> atReturn = List<String>.of(log.events);
    await tester.pump();
    final List<String> afterFrame = List<String>.of(log.events);
    print('R2 when push returns: $atReturn; after one pump: $afterFrame');
    expect(atReturn, isEmpty);
    expect(afterFrame, <String>['push /a']);
    r.pop();
    await tester.pumpAndSettle();
    r.dispose();
  });

  testWidgets('R4 GoRouter navigates to the platform\'s initial route itself, before any bus could guard it', (WidgetTester tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/detail/5';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    final Log log = Log();
    final GoRouter r = router(log);
    await tester.pumpWidget(host(r));
    await tester.pumpAndSettle();
    print('R4 initial location: ${r.state.uri}; navigator events: ${log.events}');
    expect(r.state.uri.path, '/detail/5');
    r.dispose();
  });

  testWidgets('R5 GoRouter.go replaces the pushed stack with the route tree\'s path to the location', (WidgetTester tester) async {
    final Log log = Log();
    final GoRouter r = router(log);
    await tester.pumpWidget(host(r));
    unawaited(r.push<Object?>('/a'));
    await tester.pumpAndSettle();
    final List<String> before = List<String>.of(log.events);
    r.go('/b');
    await tester.pumpAndSettle();
    print('R5 after push(/a): $before; then go(/b): ${log.events}; canPop: ${r.canPop()}; '
        'pages on the Navigator: ${<String>[for (final String t in <String>['/', '/a', '/b']) if (find.text(t, skipOffstage: false).evaluate().isNotEmpty) t]}');
    expect(find.text('/a', skipOffstage: false), findsNothing);
    expect(find.text('/', skipOffstage: false), findsOneWidget);
    expect(find.text('/b'), findsOneWidget);
    r.dispose();
  });
}
