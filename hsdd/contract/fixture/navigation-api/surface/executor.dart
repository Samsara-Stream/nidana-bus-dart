// Surface fixture for navigation-api@v1 (ADR-001 item 4): the executor
// protocol, used with the types the Interface states. It implements
// NavigationRouter in full, so a member added to the port fails this set,
// and switches exhaustively over RouterCall, NavigationPlan and
// NavigationRefusal. It uses the in-memory router of testing.dart.
import 'dart:async';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_navigation/testing.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const NavRoute<void> home = NavRoute<void>('app/home');

final class LoggingRouter implements NavigationRouter {
  final List<NavigationEntry> _stack = <NavigationEntry>[NavigationEntry(RouteState(route: home))];
  final StreamController<RouteConfirmation> _confirmations =
      StreamController<RouteConfirmation>.broadcast(sync: true);

  @override
  List<NavigationEntry> get stack => List<NavigationEntry>.unmodifiable(_stack);

  @override
  bool get supportsPopUntil => false;

  @override
  void perform(List<RouterCall> calls, ResolvedNavIntent intent) {
    for (final RouterCall call in calls) {
      print(call);
    }
    _confirmations.add(RouteConfirmation(stack: _stack, intent: intent));
  }

  @override
  Stream<RouteConfirmation> get confirmations => _confirmations.stream;
}

String call(RouterCall c) => switch (c) {
      PushRoute(:final NavigationEntry entry) => 'push $entry',
      ReplaceRoute(:final NavigationEntry entry) => 'replace $entry',
      PopRoute() => 'pop',
      PopUntilRoute(:final NavRoute<Object?> route) => 'pop until $route',
    };

String plan(NavigationPlan p) => switch (p) {
      PerformCalls(:final List<RouterCall> calls) => 'perform $calls',
      RefuseIntent(:final NavigationRefusal reason) => 'refuse ${refusal(reason)}',
    };

String refusal(NavigationRefusal r) => switch (r) {
      NavigationRefusal.backAtRoot => 'back at root',
      NavigationRefusal.targetNotOnStack => 'target not on stack',
      NavigationRefusal.noModalToDismiss => 'no modal to dismiss',
    };

String diagnostic(ShellDiagnostic d) => switch (d) {
      NavigationRefused(:final String origin, :final NavigationRefusal reason, :final NavRoute<Object?>? route) =>
        '$origin $reason $route',
      LateExecutorConstruction(:final String origin) => origin,
      _ => d.origin,
    };

void protocol(Bus bus) {
  final NavigationEntry entry = NavigationEntry(RouteState(route: home), modal: true);
  final RouteState state = entry.state;
  final bool modal = entry.modal;
  final List<RouterCall> calls = <RouterCall>[
    PushRoute(entry),
    ReplaceRoute(entry),
    const PopRoute(),
    const PopUntilRoute(home),
  ];
  final RouteConfirmation c = RouteConfirmation(stack: <NavigationEntry>[entry], intent: const Back());
  final List<NavigationEntry> confirmed = c.stack;
  final ResolvedNavIntent cause = c.intent;
  final NavigationPlan p = planNavigation(<NavigationEntry>[entry], home.go(), supportsPopUntil: true);
  final PerformCalls perform = PerformCalls(calls);
  final List<RouterCall> planned = perform.calls;
  const RefuseIntent refuse = RefuseIntent(NavigationRefusal.backAtRoot);
  final NavigationRefusal reason = refuse.reason;
  const NavigationRefused refused =
      NavigationRefused(origin: 'executor:app', reason: NavigationRefusal.targetNotOnStack, route: home);
  const LateExecutorConstruction late = LateExecutorConstruction(origin: 'executor:app');
  final ShellDiagnostic shell = refused;
  final BusDiagnostic any = late;
  final NavigationExecutor executor = NavigationExecutor(bus, LoggingRouter(), name: 'app');
  final NavigationRouter router = executor.router;
  final ExecutorSource source = executor.source;
  final bool disposed = executor.isDisposed;
  executor.dispose();
  final InMemoryRouter memory = InMemoryRouter(RouteState(route: home), supportsPopUntil: false);
  final NavigationRouter port = memory;
  final List<List<RouterCall>> performed = memory.performed;
  memory.platformBack();
  final NavigationExecutor defaulted = NavigationExecutor(bus, InMemoryRouter(state));
  print(<Object?>[
    modal, confirmed, cause, p, planned, reason, shell, any, router, source,
    disposed, port, performed, defaulted, call(calls.first), plan(p),
    diagnostic(refused),
  ]);
}
