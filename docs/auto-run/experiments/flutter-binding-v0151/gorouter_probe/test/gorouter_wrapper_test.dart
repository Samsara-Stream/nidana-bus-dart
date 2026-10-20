// Probes R6 to R8 for NidanaModule against go_router 18.1.0 (Spec §7.3: the
// wrapper "needs no route names and works with any router"; Guide §3.4's
// router): when a widget placed in a ShellRoute's builder, or in each page of
// a subtree, is mounted and unmounted as GoRouter navigates, and which names
// the routes it puts on the Navigator carry, which is what a prefix-matching
// route observer would see. Each probe prints one line `R{n} ...` and
// asserts what it saw.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final List<String> log = <String>[];

final class Holder extends StatefulWidget {
  const Holder(this.name, {super.key, required this.child});
  final String name;
  final Widget child;
  @override
  State<Holder> createState() => _HolderState();
}

final class _HolderState extends State<Holder> {
  @override
  void initState() {
    super.initState();
    log.add('mount ${widget.name}');
  }

  @override
  void dispose() {
    log.add('unmount ${widget.name}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Records the settings name of every route the observed Navigator pushes.
final class Names extends NavigatorObserver {
  final List<String?> pushed = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route.settings.name);
}

Widget _text(GoRouterState s) => Text(s.matchedLocation, textDirection: TextDirection.ltr);

/// A 300 ms fade, as an app's own page transition would be.
Page<void> _fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (BuildContext _, Animation<double> a, Animation<double> _, Widget c) =>
          FadeTransition(opacity: a, child: c),
      child: child,
    );

Widget host(GoRouter r) => WidgetsApp.router(routerConfig: r, color: const Color(0xFF000000));

String since(int mark) => log.sublist(mark).join(', ');

void main() {
  setUp(log.clear);

  testWidgets('R6 a wrapper in a ShellRoute builder mounts when navigation enters the shell, stays mounted across go and push inside it, and unmounts when navigation leaves it', (WidgetTester tester) async {
    final Names names = Names();
    final GoRouter r = GoRouter(
      initialLocation: '/home',
      observers: <NavigatorObserver>[names],
      routes: <RouteBase>[
        GoRoute(path: '/home', builder: (BuildContext _, GoRouterState s) => _text(s)),
        ShellRoute(
          builder: (BuildContext _, GoRouterState _, Widget child) => Holder('shell', child: child),
          routes: <RouteBase>[
            GoRoute(path: '/checkout/cart', builder: (BuildContext _, GoRouterState s) => _text(s)),
            GoRoute(path: '/checkout/pay', builder: (BuildContext _, GoRouterState s) => _text(s)),
          ],
        ),
      ],
    );
    await tester.pumpWidget(host(r));
    r.go('/checkout/cart');
    await tester.pumpAndSettle();
    final String entered = since(0);
    final int mark = log.length;
    r.go('/checkout/pay');
    await tester.pumpAndSettle();
    unawaited(r.push<void>('/checkout/cart'));
    await tester.pumpAndSettle();
    r.pop();
    await tester.pumpAndSettle();
    r.go('/checkout/cart');
    await tester.pumpAndSettle();
    final String inside = since(mark);
    r.go('/home');
    await tester.pumpAndSettle();
    final String left = since(mark);
    print('R6 ShellRoute: entering /checkout/cart [$entered]; go pay, push cart, pop, go cart [$inside]; go /home [$left]; '
        'names the root Navigator saw pushed: ${names.pushed}');
    expect(entered, 'mount shell');
    expect(inside, isEmpty);
    expect(left, 'unmount shell');
    r.dispose();
  });

  testWidgets('R7 a wrapper in each page: go from one page of the subtree to another mounts the new page before the old one unmounts, with and without a transition', (WidgetTester tester) async {
    for (final bool fade in <bool>[false, true]) {
      log.clear();
      Page<void> pageOf(GoRouterState s, String hold) => fade
          ? _fade(s, Holder(hold, child: _text(s)))
          : NoTransitionPage<void>(key: s.pageKey, child: Holder(hold, child: _text(s)));
      final GoRouter r = GoRouter(
        initialLocation: '/home',
        routes: <RouteBase>[
          GoRoute(path: '/home', builder: (BuildContext _, GoRouterState s) => _text(s)),
          GoRoute(path: '/checkout/cart', pageBuilder: (BuildContext _, GoRouterState s) => pageOf(s, 'cart')),
          GoRoute(path: '/checkout/pay', pageBuilder: (BuildContext _, GoRouterState s) => pageOf(s, 'pay')),
        ],
      );
      await tester.pumpWidget(host(r));
      r.go('/checkout/cart');
      await tester.pumpAndSettle();
      final int mark = log.length;
      r.go('/checkout/pay');
      await tester.pump();
      final String afterFrame = since(mark);
      await tester.pumpAndSettle();
      final String settled = since(mark);
      print('R7 ${fade ? '300 ms fade' : 'no transition'}: go cart -> pay: after one frame [$afterFrame], settled [$settled]');
      expect(settled, 'mount pay, unmount cart');
      await tester.pumpWidget(const SizedBox());
      r.dispose();
    }
  });

  testWidgets('R8 the names of the routes GoRouter puts on the Navigator: a nested GoRoute names its route by its own path pattern, not by the location', (WidgetTester tester) async {
    final Names names = Names();
    final GoRouter r = GoRouter(
      initialLocation: '/home',
      observers: <NavigatorObserver>[names],
      routes: <RouteBase>[
        GoRoute(path: '/home', builder: (BuildContext _, GoRouterState s) => _text(s)),
        GoRoute(
          path: '/checkout',
          builder: (BuildContext _, GoRouterState s) => _text(s),
          routes: <RouteBase>[
            GoRoute(path: 'cart', builder: (BuildContext _, GoRouterState s) => _text(s)),
            GoRoute(path: 'item/:id', builder: (BuildContext _, GoRouterState s) => _text(s)),
          ],
        ),
      ],
    );
    await tester.pumpWidget(host(r));
    r.go('/checkout/cart');
    await tester.pumpAndSettle();
    unawaited(r.push<void>('/checkout/item/7'));
    await tester.pumpAndSettle();
    print('R8 route names pushed for /home, then go /checkout/cart, then push /checkout/item/7: ${names.pushed}');
    expect(names.pushed, isNot(contains('/checkout/cart')));
    r.dispose();
  });
}
