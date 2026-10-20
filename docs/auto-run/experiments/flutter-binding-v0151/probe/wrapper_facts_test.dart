// Probes N1 to N6 for NidanaModule (Spec §7.3's Flutter row, Appendix A.8):
// when a widget placed in a page, or around a nested Navigator that hosts a
// route subtree, is mounted and unmounted as Flutter's own Navigator pushes,
// covers, replaces and pops routes. A wrapper that acquires a module scope
// reference at mount and releases it at unmount holds exactly while the
// Holder below is mounted. Flutter only, no bus. Each probe prints one line
// `N{n} ...` with what it saw, and asserts it, so run.sh captures both.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every mount and unmount of every Holder, in order.
final List<String> log = <String>[];

/// Logs its mount and its unmount, as a wrapper would acquire and release.
final class Holder extends StatefulWidget {
  const Holder(this.name, {super.key, this.child = const SizedBox()});
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

/// The Holders mounted now: mounts minus unmounts.
int held() =>
    log.where((String e) => e.startsWith('mount ')).length -
    log.where((String e) => e.startsWith('unmount ')).length;

/// A page route with the default 300 ms transitions; [name] null gives
/// settings with no name. [hold] puts a Holder named [hold] in the page.
Route<void> page(String? name, {String? hold, bool maintainState = true, Widget? child}) =>
    PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      maintainState: maintainState,
      pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) {
        final Widget content = child ?? Text(name ?? '-', textDirection: TextDirection.ltr);
        return hold == null ? content : Holder(hold, child: content);
      },
    );

Widget app(GlobalKey<NavigatorState> key, List<Route<void>> initial) => WidgetsApp(
      navigatorKey: key,
      color: const Color(0xFF000000),
      onGenerateInitialRoutes: (String _) => initial,
      onGenerateRoute: (RouteSettings _) => null,
    );

/// What the log gained since [mark], as text.
String since(int mark) => log.sublist(mark).join(', ');

void main() {
  setUp(log.clear);

  testWidgets('N1 a page covered by another route stays mounted; a popped page unmounts when its exit transition ends, not at the pop', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(key, <Route<void>>[page('/home')]));
    final NavigatorState nav = key.currentState!;
    unawaited(nav.push(page('/checkout/cart', hold: 'cart')));
    final String atPush = since(0);
    await tester.pump();
    final String afterFrame = since(0);
    await tester.pumpAndSettle();
    unawaited(nav.push(page('/checkout/pay', hold: 'pay')));
    await tester.pumpAndSettle();
    unawaited(nav.push(page('/profile')));
    await tester.pumpAndSettle();
    final int coveredBoth = held();
    nav.pop(); // /profile
    await tester.pumpAndSettle();
    final int mark = log.length;
    nav.pop(); // /checkout/pay
    final String atPop = since(mark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final String midTransition = since(mark);
    await tester.pumpAndSettle();
    final String settled = since(mark);
    print('N1 when push returns: [$atPush]; after one frame: [$afterFrame]; '
        'held with cart and pay covered by /profile: $coveredBoth; '
        'pop of pay: at the pop [$atPop], mid-transition [$midTransition], settled [$settled]');
    expect(atPush, isEmpty);
    expect(afterFrame, 'mount cart');
    expect(coveredBoth, 2);
    expect(atPop, isEmpty);
    expect(midTransition, isEmpty);
    expect(settled, 'unmount pay');
  });

  testWidgets('N2 pushReplacement mounts the new page in the next frame and unmounts the old one when the new one has finished entering', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(key, <Route<void>>[page('/home'), page('/checkout/cart', hold: 'cart')]));
    final int mark = log.length;
    unawaited(key.currentState!.pushReplacement<void, void>(page('/checkout/pay', hold: 'pay')));
    await tester.pump();
    final String afterFrame = since(mark);
    await tester.pump(const Duration(milliseconds: 150));
    final String midTransition = since(mark);
    await tester.pumpAndSettle();
    final String settled = since(mark);
    print('N2 pushReplacement cart -> pay: after one frame [$afterFrame], mid-transition [$midTransition], settled [$settled]');
    expect(afterFrame, 'mount pay');
    expect(midTransition, 'mount pay');
    expect(settled, 'mount pay, unmount cart');
  });

  testWidgets('N3 popUntil unmounts the covered pages it removes and the top page it pops when the transition ends', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(key, <Route<void>>[
      page('/home'),
      page('/checkout/cart', hold: 'cart'),
      page('/checkout/pay', hold: 'pay'),
    ]));
    final int mark = log.length;
    key.currentState!.popUntil((Route<dynamic> r) => r.settings.name == '/home');
    final String atCall = since(mark);
    await tester.pump();
    final String afterFrame = since(mark);
    await tester.pumpAndSettle();
    final String settled = since(mark);
    print('N3 popUntil /home over cart and pay: at the call [$atCall], after one frame [$afterFrame], settled [$settled]');
    expect(atCall, isEmpty);
    expect(settled.split(', ').toSet(), <String>{'unmount cart', 'unmount pay'});
  });

  testWidgets('N4 a page route with maintainState false unmounts its page while an opaque route covers it, and mounts it anew when uncovered', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(key, <Route<void>>[page('/home')]));
    final NavigatorState nav = key.currentState!;
    unawaited(nav.push(page('/checkout/cart', hold: 'cart', maintainState: false)));
    await tester.pumpAndSettle();
    final int mark = log.length;
    unawaited(nav.push(page('/profile')));
    await tester.pumpAndSettle();
    final String covered = since(mark);
    final int heldCovered = held();
    nav.pop();
    await tester.pumpAndSettle();
    final String uncovered = since(mark);
    print('N4 maintainState false: covered by /profile [$covered] (held $heldCovered); after /profile pops [$uncovered]');
    expect(covered, 'unmount cart');
    expect(heldCovered, 0);
    expect(uncovered, 'unmount cart, mount cart');
  });

  testWidgets('N5 a wrapper around a nested Navigator stays mounted while the nested routes come and go, named or not, and unmounts when its own route is popped and has left', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> root = GlobalKey<NavigatorState>();
    final GlobalKey<NavigatorState> nested = GlobalKey<NavigatorState>();
    final Widget shell = Holder('shell',
        child: Navigator(
          key: nested,
          onGenerateInitialRoutes: (NavigatorState _, String _) => <Route<void>>[page(null)],
          onGenerateRoute: (RouteSettings _) => null,
        ));
    await tester.pumpWidget(app(root, <Route<void>>[page('/home')]));
    unawaited(root.currentState!.push(page('/checkout', child: shell)));
    await tester.pumpAndSettle();
    final int mark = log.length;
    for (var i = 0; i < 3; i++) {
      unawaited(nested.currentState!.push(page(null)));
      await tester.pumpAndSettle();
    }
    unawaited(nested.currentState!.pushReplacement<void, void>(page(null)));
    await tester.pumpAndSettle();
    nested.currentState!.pop();
    nested.currentState!.pop();
    await tester.pumpAndSettle();
    final String inside = since(mark);
    root.currentState!.pop();
    final String atPop = since(mark);
    await tester.pumpAndSettle();
    final String settled = since(mark);
    print('N5 nested routes pushed, replaced and popped, all without names: [$inside]; '
        'the shell route popped: at the pop [$atPop], settled [$settled]');
    expect(inside, isEmpty);
    expect(atPop, isEmpty);
    expect(settled, 'unmount shell');
  });

  testWidgets('N6 a dialog over a page, and a page pushed and popped above it, never unmount it', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(key, <Route<void>>[page('/home'), page('/checkout/cart', hold: 'cart')]));
    final int mark = log.length;
    unawaited(showGeneralDialog<void>(
        context: key.currentContext!,
        pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
            const Text('dialog', textDirection: TextDirection.ltr)));
    await tester.pumpAndSettle();
    key.currentState!.pop();
    await tester.pumpAndSettle();
    unawaited(key.currentState!.push(page('/profile')));
    await tester.pumpAndSettle();
    key.currentState!.pop();
    await tester.pumpAndSettle();
    print('N6 dialog shown and dismissed, /profile pushed and popped over cart: [${since(mark)}]');
    expect(since(mark), isEmpty);
  });
}
