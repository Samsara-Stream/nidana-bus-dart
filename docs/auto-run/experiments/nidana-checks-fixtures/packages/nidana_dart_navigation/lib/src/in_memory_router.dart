/// Stand-in for the InMemoryRouter of navigation-api@v1's testing.dart
/// (experiment only).
library;

import 'dart:async';

import '../nidana_dart_navigation.dart';

final class InMemoryRouter implements NavigationRouter {
  InMemoryRouter(RouteState initial, {this.supportsPopUntil = true})
      : _stack = <NavigationEntry>[NavigationEntry(initial)];

  final List<NavigationEntry> _stack;
  final List<List<RouterCall>> _performed = <List<RouterCall>>[];
  final StreamController<RouteConfirmation> _confirmations =
      StreamController<RouteConfirmation>.broadcast(sync: true);

  @override
  final bool supportsPopUntil;

  @override
  List<NavigationEntry> get stack => List<NavigationEntry>.unmodifiable(_stack);

  List<List<RouterCall>> get performed =>
      List<List<RouterCall>>.unmodifiable(_performed);

  @override
  Stream<RouteConfirmation> get confirmations => _confirmations.stream;

  @override
  void perform(List<RouterCall> calls, ResolvedNavIntent intent) {
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
          if (!supportsPopUntil) throw StateError('this router does not pop until');
          if (!next.any((NavigationEntry e) => e.state.route == route)) {
            throw StateError('$route is not on the stack');
          }
          while (next.last.state.route != route) {
            next.removeLast();
          }
      }
    }
    _stack
      ..clear()
      ..addAll(next);
    _performed.add(List<RouterCall>.unmodifiable(calls));
    _confirmations.add(RouteConfirmation(stack: _stack, intent: intent));
  }

  void platformBack() {
    if (_stack.length < 2) return;
    _stack.removeLast();
    _confirmations.add(RouteConfirmation(stack: _stack, intent: const Back()));
  }
}
