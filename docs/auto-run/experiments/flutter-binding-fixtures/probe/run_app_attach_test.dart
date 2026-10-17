// Probe P1 for OQ-F1: on the production binding (not flutter_test's, which
// overrides scheduleAttachRootWidget to attach at once), runApp attaches the
// root widget from a Timer, so microtasks queued before or by runApp, which
// is where a production-provider bus delivers a start() queue's reentrant
// publishes, run before any Navigator exists.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' show expect, isNotNull, isNull, test;

void main() {
  test('P1 runApp mounts the Navigator only after a timer, so microtasks run before it exists', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
    final List<String> seen = <String>[];
    runApp(WidgetsApp(
      navigatorKey: key,
      color: const Color(0xFF000000),
      onGenerateRoute: (RouteSettings s) => PageRouteBuilder<void>(
        settings: s,
        pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
            const SizedBox(),
      ),
    ));
    seen.add('after runApp returns: navigator ${key.currentState == null ? 'absent' : 'present'}');
    scheduleMicrotask(() => seen.add('in a microtask queued after runApp: navigator ${key.currentState == null ? 'absent' : 'present'}'));
    await Future<void>.microtask(() {});
    final NavigatorState? afterMicrotasks = key.currentState;
    await Future<void>.delayed(Duration.zero);
    seen.add('after one timer turn: navigator ${key.currentState == null ? 'absent' : 'present'}');
    for (final String s in seen) {
      print('P1 $s');
    }
    expect(afterMicrotasks, isNull);
    expect(key.currentState, isNotNull);
  });
}
