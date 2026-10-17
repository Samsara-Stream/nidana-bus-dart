// Probes for OQ-F1 (hsdd/spec/nidana.flutter.md): what Flutter's own
// Navigator does that a NavigationRouter over it, and a module-scope
// observer, rely on. Each probe prints one line `P{n} ...` with what it saw,
// and asserts it, so run.sh captures both.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every observer callback as text, in order.
final class Log extends NavigatorObserver {
  final List<String> events = <String>[];

  static String name(Route<dynamic>? r) => r?.settings.name ?? '-';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('push ${name(route)}');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('pop ${name(route)}');

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('remove ${name(route)}');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      events.add('replace ${name(oldRoute)} -> ${name(newRoute)}');
}

Route<void> page(String name, {bool canPop = true}) => PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) => PopScope(
        canPop: canPop,
        child: Text(name, textDirection: TextDirection.ltr),
      ),
    );

Widget host(GlobalKey<NavigatorState> key, Log log, List<String> initial,
        {RouteFactory? onGenerateRoute}) =>
    WidgetsApp(
      navigatorKey: key,
      navigatorObservers: <NavigatorObserver>[log],
      color: const Color(0xFF000000),
      onGenerateInitialRoutes: (String _) => <Route<dynamic>>[for (final String n in initial) page(n)],
      onGenerateRoute: onGenerateRoute ?? (RouteSettings s) => null,
    );

Future<void> platform(WidgetTester tester, String method, [Object? arguments]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(MethodCall(method, arguments)),
    (ByteData? _) {},
  );
}

/// Answers every pushed route information, so WidgetsApp never pushes it.
final class Capture with WidgetsBindingObserver {
  final List<Uri> uris = <Uri>[];

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    uris.add(routeInformation.uri);
    return SynchronousFuture<bool>(true);
  }
}

void main() {
  testWidgets('P2 observer callbacks run synchronously inside push, pushReplacement, replace, pop and popUntil', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final Log log = Log();
    await tester.pumpWidget(host(key, log, <String>['/home']));
    log.events.clear();
    final NavigatorState nav = key.currentState!;
    unawaited(nav.push(page('/a')));
    final List<String> afterPush = List<String>.of(log.events);
    unawaited(nav.pushReplacement(page('/b')));
    final List<String> afterReplacement = List<String>.of(log.events);
    nav.replace(oldRoute: _top(nav)!, newRoute: page('/c'));
    final List<String> afterReplace = List<String>.of(log.events);
    unawaited(nav.push(page('/d')));
    nav.pop();
    final List<String> afterPop = List<String>.of(log.events);
    unawaited(nav.push(page('/e')));
    unawaited(nav.push(page('/f')));
    nav.popUntil((Route<dynamic> r) => r.settings.name == '/c');
    final List<String> afterPopUntil = List<String>.of(log.events);
    print('P2 after push: $afterPush');
    print('P2 after pushReplacement: $afterReplacement');
    print('P2 after replace: $afterReplace');
    print('P2 after push and pop: $afterPop');
    print('P2 after popUntil: $afterPopUntil');
    expect(afterPush, <String>['push /a']);
    expect(afterPopUntil.last, 'pop /e');
    await tester.pumpAndSettle();
  });

  testWidgets('P3 the initial routes are reported to observers as pushes, bottom first, during the first build', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final Log log = Log();
    await tester.pumpWidget(host(key, log, <String>['/home', '/a', '/b']));
    print('P3 initial routes: ${log.events}');
    print('P3 visible: ${find.text('/b').evaluate().length}, below kept mounted: ${find.text('/home', skipOffstage: false).evaluate().length}');
    expect(log.events.where((String e) => e.startsWith('push')), hasLength(3));
  });

  testWidgets('P4 a platform popRoute pops the top route through WidgetsApp, never the root, and PopScope can refuse it', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final Log log = Log();
    await tester.pumpWidget(host(key, log, <String>['/home']));
    log.events.clear();
    await platform(tester, 'popRoute');
    await tester.pumpAndSettle();
    final List<String> atRoot = List<String>.of(log.events);
    unawaited(key.currentState!.push(page('/a')));
    await tester.pumpAndSettle();
    log.events.clear();
    await platform(tester, 'popRoute');
    final List<String> beforePump = List<String>.of(log.events);
    await tester.pumpAndSettle();
    final List<String> aboveRoot = List<String>.of(log.events);
    unawaited(key.currentState!.push(page('/guarded', canPop: false)));
    await tester.pumpAndSettle();
    log.events.clear();
    await platform(tester, 'popRoute');
    await tester.pumpAndSettle();
    final List<String> refused = List<String>.of(log.events);
    print('P4 at root: $atRoot; above root, before any pump: $beforePump, after: $aboveRoot; under PopScope(canPop: false): $refused');
    expect(atRoot, isEmpty);
    expect(aboveRoot, <String>['pop /a']);
    expect(refused, isEmpty);
  });

  testWidgets('P5 a platform pushRouteInformation reaches the first binding observer that answers true; without one WidgetsApp pushes it by name', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final Log log = Log();
    final List<String> generated = <String>[];
    final Capture capture = Capture();
    tester.binding.addObserver(capture); // registered before WidgetsApp's
    await tester.pumpWidget(host(key, log, <String>['/home'], onGenerateRoute: (RouteSettings s) {
      generated.add(s.name!);
      return page(s.name!);
    }));
    log.events.clear();
    await platform(tester, 'pushRouteInformation', <String, Object?>{'location': '/detail/5?x=1', 'state': null});
    await tester.pumpAndSettle();
    final List<Uri> captured = List<Uri>.of(capture.uris);
    final List<String> pushedWithCapture = List<String>.of(log.events);
    tester.binding.removeObserver(capture);
    await platform(tester, 'pushRouteInformation', <String, Object?>{'location': '/detail/6', 'state': null});
    await tester.pumpAndSettle();
    print('P5 with an earlier observer: captured $captured, navigator events $pushedWithCapture; without it: onGenerateRoute $generated, navigator events ${log.events}');
    expect(captured, <Uri>[Uri.parse('/detail/5?x=1')]);
    expect(pushedWithCapture, isEmpty);
    expect(generated, <String>['/detail/6']);
  });

  testWidgets('P5b an observer registered after WidgetsApp mounted comes too late: WidgetsApp pushes the route first', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final Log log = Log();
    final List<String> generated = <String>[];
    await tester.pumpWidget(host(key, log, <String>['/home'], onGenerateRoute: (RouteSettings s) {
      generated.add(s.name!);
      return page(s.name!);
    }));
    final Capture capture = Capture();
    tester.binding.addObserver(capture);
    await platform(tester, 'pushRouteInformation', <String, Object?>{'location': '/detail/7', 'state': null});
    await tester.pumpAndSettle();
    tester.binding.removeObserver(capture);
    print('P5b late observer: captured ${capture.uris}, onGenerateRoute $generated');
    expect(capture.uris, isEmpty);
    expect(generated, <String>['/detail/7']);
  });

  testWidgets('P6 a Navigator that unmounts detaches its observers and reports no pop or removal of the routes it held', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final Log log = Log();
    await tester.pumpWidget(host(key, log, <String>['/home', '/a']));
    final bool attached = log.navigator != null;
    log.events.clear();
    await tester.pumpWidget(const SizedBox());
    print('P6 attached while mounted: $attached; after unmount: navigator ${log.navigator}, events ${log.events}');
    expect(log.navigator, isNull);
    expect(log.events, isEmpty);
  });

  testWidgets('P7 a dialog pushed over the routes is an observed push of a route the app did not name; popUntil on a route identity pops it', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final Log log = Log();
    await tester.pumpWidget(host(key, log, <String>['/home', '/a']));
    log.events.clear();
    final NavigatorState nav = key.currentState!;
    final Route<dynamic> a = _top(nav)!;
    unawaited(showGeneralDialog<void>(
      context: key.currentContext!,
      pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
          const Text('dialog', textDirection: TextDirection.ltr),
    ));
    await tester.pumpAndSettle();
    final List<String> shown = List<String>.of(log.events);
    nav.popUntil((Route<dynamic> r) => identical(r, a));
    await tester.pumpAndSettle();
    print('P7 dialog shown: $shown; after popUntil(identical /a): ${log.events}');
    expect(log.events.last, 'pop -');
  });

  testWidgets('P8 a page\'s own Navigator.maybePop, as a back button calls it, is an observed pop like a platform back', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final Log log = Log();
    await tester.pumpWidget(host(key, log, <String>['/home', '/a']));
    log.events.clear();
    final BuildContext pageContext = tester.element(find.text('/a'));
    final bool popped = await Navigator.maybePop(pageContext);
    await tester.pumpAndSettle();
    print('P8 maybePop from the page: $popped, events ${log.events}');
    expect(log.events, <String>['pop /a']);
  });
}

Route<dynamic>? _top(NavigatorState nav) {
  Route<dynamic>? top;
  nav.popUntil((Route<dynamic> r) {
    top = r;
    return true;
  });
  return top;
}
