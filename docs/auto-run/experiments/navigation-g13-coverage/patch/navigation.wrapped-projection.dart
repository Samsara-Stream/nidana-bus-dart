/// Stand-in implementation of the main library of navigation-api@v1
/// (experiment only). One library, so that NavRoute can reach the private
/// constructors of the intents it builds.
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

// ------------------------------------------------------------ helpers

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final MapEntry<K, V> e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

int _mapHash<K, V>(Map<K, V> m) => Object.hashAllUnordered(
    <int>[for (final MapEntry<K, V> e in m.entries) Object.hash(e.key, e.value)]);

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

// ------------------------------------------------------------ routes

@immutable
final class NavRoute<A> {
  const NavRoute(this.path) : assert(path != '', 'a route path is non-empty');
  const NavRoute._none() : path = '';

  static const NavRoute<void> none = NavRoute<void>._none();

  final String path;

  Type get argsType => A;

  GoTo go([A? args]) => GoTo._(this, args);
  Replace replace([A? args]) => Replace._(this, args);
  ShowModal showModal([A? args]) => ShowModal._(this, args);
  BackTo backTo() => BackTo(this);

  A? argsOf(RouteState state) => state.route == this ? state.args as A? : null;

  @override
  bool operator ==(Object other) =>
      other is NavRoute<Object?> &&
      other.path == path &&
      other.argsType == argsType;

  @override
  int get hashCode => Object.hash(path, argsType);

  @override
  String toString() => 'route:$path';
}

@immutable
final class RouteRegistry {
  RouteRegistry(Iterable<NavRoute<Object?>> routes) : routes = _distinct(routes);

  final List<NavRoute<Object?>> routes;

  NavRoute<Object?>? lookup(String path) {
    for (final NavRoute<Object?> r in routes) {
      if (r.path == path) return r;
    }
    return null;
  }

  RouteRegistry operator +(RouteRegistry other) =>
      RouteRegistry(<NavRoute<Object?>>[...routes, ...other.routes]);

  static List<NavRoute<Object?>> _distinct(Iterable<NavRoute<Object?>> routes) {
    final Map<String, NavRoute<Object?>> byPath = <String, NavRoute<Object?>>{};
    for (final NavRoute<Object?> r in routes) {
      if (r.path.isEmpty) {
        throw ArgumentError.value(r, 'routes', 'NavRoute.none is not registrable');
      }
      final NavRoute<Object?>? seen = byPath[r.path];
      if (seen == null) {
        byPath[r.path] = r;
      } else if (seen != r) {
        throw ArgumentError.value(
            r, 'routes', 'path ${r.path} is registered with another argument type');
      }
    }
    return List<NavRoute<Object?>>.unmodifiable(byPath.values);
  }

  @override
  bool operator ==(Object other) =>
      other is RouteRegistry && _listEquals(other.routes, routes);

  @override
  int get hashCode => Object.hashAll(routes);
}

// ------------------------------------------------------------ intents

@immutable
sealed class NavIntent {
  const NavIntent();
}

final class DeepLink extends NavIntent {
  const DeepLink(this.uri);

  final Uri uri;

  @override
  bool operator ==(Object other) => other is DeepLink && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'DeepLink($uri)';
}

sealed class ResolvedNavIntent extends NavIntent {
  const ResolvedNavIntent();

  NavRoute<Object?>? get targetRoute;
}

final class GoTo extends ResolvedNavIntent {
  const GoTo._(this.route, this.args);

  final NavRoute<Object?> route;
  final Object? args;

  @override
  NavRoute<Object?> get targetRoute => route;

  @override
  bool operator ==(Object other) =>
      other is GoTo && other.route == route && other.args == args;

  @override
  int get hashCode => Object.hash(GoTo, route, args);

  @override
  String toString() => 'GoTo($route, $args)';
}

final class Replace extends ResolvedNavIntent {
  const Replace._(this.route, this.args);

  final NavRoute<Object?> route;
  final Object? args;

  @override
  NavRoute<Object?> get targetRoute => route;

  @override
  bool operator ==(Object other) =>
      other is Replace && other.route == route && other.args == args;

  @override
  int get hashCode => Object.hash(Replace, route, args);

  @override
  String toString() => 'Replace($route, $args)';
}

final class Back extends ResolvedNavIntent {
  const Back();

  @override
  NavRoute<Object?>? get targetRoute => null;

  @override
  bool operator ==(Object other) => other is Back;

  @override
  int get hashCode => (Back).hashCode;

  @override
  String toString() => 'Back()';
}

final class BackTo extends ResolvedNavIntent {
  const BackTo(this.route);

  final NavRoute<Object?> route;

  @override
  NavRoute<Object?> get targetRoute => route;

  @override
  bool operator ==(Object other) => other is BackTo && other.route == route;

  @override
  int get hashCode => Object.hash(BackTo, route);

  @override
  String toString() => 'BackTo($route)';
}

final class ShowModal extends ResolvedNavIntent {
  const ShowModal._(this.route, this.args);

  final NavRoute<Object?> route;
  final Object? args;

  @override
  NavRoute<Object?> get targetRoute => route;

  @override
  bool operator ==(Object other) =>
      other is ShowModal && other.route == route && other.args == args;

  @override
  int get hashCode => Object.hash(ShowModal, route, args);

  @override
  String toString() => 'ShowModal($route, $args)';
}

final class DismissModal extends ResolvedNavIntent {
  const DismissModal();

  @override
  NavRoute<Object?>? get targetRoute => null;

  @override
  bool operator ==(Object other) => other is DismissModal;

  @override
  int get hashCode => (DismissModal).hashCode;

  @override
  String toString() => 'DismissModal()';
}

// ------------------------------------------------------------ route state

@immutable
final class RouteState {
  RouteState({
    required this.route,
    this.args,
    Map<String, String> pathParams = const <String, String>{},
    Map<String, String> queryParams = const <String, String>{},
  })  : pathParams = Map<String, String>.unmodifiable(pathParams),
        queryParams = Map<String, String>.unmodifiable(queryParams);

  const RouteState._initial()
      : route = NavRoute.none,
        args = null,
        pathParams = const <String, String>{},
        queryParams = const <String, String>{};

  static const RouteState initial = RouteState._initial();

  final NavRoute<Object?> route;
  final Object? args;
  final Map<String, String> pathParams;
  final Map<String, String> queryParams;

  @override
  bool operator ==(Object other) =>
      other is RouteState &&
      other.route == route &&
      other.args == args &&
      _mapEquals(other.pathParams, pathParams) &&
      _mapEquals(other.queryParams, queryParams);

  @override
  int get hashCode =>
      Object.hash(route, args, _mapHash(pathParams), _mapHash(queryParams));

  @override
  String toString() => 'RouteState($route, $args, $pathParams, $queryParams)';
}

@immutable
final class RouteTransition {
  const RouteTransition({
    required this.from,
    required this.to,
    required this.intent,
    required this.timestamp,
  });

  final RouteState from;
  final RouteState to;
  final ResolvedNavIntent intent;
  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      other is RouteTransition &&
      other.from == from &&
      other.to == to &&
      other.intent == intent &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(from, to, intent, timestamp);

  @override
  String toString() => 'RouteTransition($from -> $to, $intent, $timestamp)';
}

// ------------------------------------------------------------ access

@immutable
sealed class RouteAccessRequirement {
  const RouteAccessRequirement();
}

final class PublicAccess extends RouteAccessRequirement {
  const PublicAccess();

  @override
  bool operator ==(Object other) => other is PublicAccess;

  @override
  int get hashCode => (PublicAccess).hashCode;
}

final class AuthenticatedAccess extends RouteAccessRequirement {
  const AuthenticatedAccess();

  @override
  bool operator ==(Object other) => other is AuthenticatedAccess;

  @override
  int get hashCode => (AuthenticatedAccess).hashCode;
}

final class RoleAccess extends RouteAccessRequirement {
  RoleAccess(Set<String> roles) : roles = Set<String>.unmodifiable(roles) {
    if (this.roles.isEmpty) {
      throw ArgumentError.value(roles, 'roles', 'is empty');
    }
  }

  final Set<String> roles;

  @override
  bool operator ==(Object other) =>
      other is RoleAccess && _setEquals(other.roles, roles);

  @override
  int get hashCode => Object.hashAllUnordered(roles);
}

final class CustomAccess extends RouteAccessRequirement {
  const CustomAccess(this.test);

  final bool Function(AccessPrincipal principal) test;

  @override
  bool operator ==(Object other) => other is CustomAccess && other.test == test;

  @override
  int get hashCode => test.hashCode;
}

@immutable
final class RouteAccessPolicy {
  RouteAccessPolicy(
    Map<NavRoute<Object?>, RouteAccessRequirement> requirements, {
    this.fallback = const PublicAccess(),
  }) : requirements =
            Map<NavRoute<Object?>, RouteAccessRequirement>.unmodifiable(requirements);

  const RouteAccessPolicy._empty()
      : requirements = const <NavRoute<Object?>, RouteAccessRequirement>{},
        fallback = const PublicAccess();

  static const RouteAccessPolicy empty = RouteAccessPolicy._empty();

  final Map<NavRoute<Object?>, RouteAccessRequirement> requirements;
  final RouteAccessRequirement fallback;

  RouteAccessRequirement requirementFor(NavRoute<Object?> route) =>
      requirements[route] ?? fallback;

  @override
  bool operator ==(Object other) =>
      other is RouteAccessPolicy &&
      other.fallback == fallback &&
      _mapEquals(other.requirements, requirements);

  @override
  int get hashCode => Object.hash(fallback, _mapHash(requirements));
}

@immutable
sealed class AccessPrincipal {
  const AccessPrincipal();
}

final class PendingPrincipal extends AccessPrincipal {
  const PendingPrincipal();

  @override
  bool operator ==(Object other) => other is PendingPrincipal;

  @override
  int get hashCode => (PendingPrincipal).hashCode;
}

final class AnonymousPrincipal extends AccessPrincipal {
  const AnonymousPrincipal();

  @override
  bool operator ==(Object other) => other is AnonymousPrincipal;

  @override
  int get hashCode => (AnonymousPrincipal).hashCode;
}

final class AuthenticatedPrincipal extends AccessPrincipal {
  AuthenticatedPrincipal({Set<String> roles = const <String>{}})
      : roles = Set<String>.unmodifiable(roles);

  final Set<String> roles;

  @override
  bool operator ==(Object other) =>
      other is AuthenticatedPrincipal && _setEquals(other.roles, roles);

  @override
  int get hashCode => Object.hash(AuthenticatedPrincipal, Object.hashAllUnordered(roles));
}

typedef AccessRedirect = ResolvedNavIntent Function(ResolvedNavIntent attempted);

@immutable
final class AccessRedirects {
  const AccessRedirects({
    required this.unauthenticated,
    required this.forbidden,
    AccessRedirect? pending,
  }) : pending = pending ?? unauthenticated;

  final AccessRedirect unauthenticated;
  final AccessRedirect forbidden;
  final AccessRedirect pending;
}

// ------------------------------------------------------------ pure functions

typedef DeepLinkResolver = ResolvedNavIntent Function(Uri uri);

ResolvedNavIntent resolveDeepLinks(NavIntent intent, DeepLinkResolver resolve) =>
    switch (intent) {
      DeepLink(:final Uri uri) => resolve(uri),
      ResolvedNavIntent() => intent,
    };

ResolvedNavIntent applyAuthGuard(
  ResolvedNavIntent intent,
  AccessPrincipal principal,
  RouteAccessPolicy policy,
  AccessRedirects redirects,
) {
  final NavRoute<Object?>? target = intent.targetRoute;
  if (target == null) return intent;
  final bool allowed = switch (policy.requirementFor(target)) {
    PublicAccess() => true,
    AuthenticatedAccess() => principal is AuthenticatedPrincipal,
    RoleAccess(:final Set<String> roles) =>
      principal is AuthenticatedPrincipal && principal.roles.any(roles.contains),
    CustomAccess(:final bool Function(AccessPrincipal) test) => test(principal),
  };
  if (allowed) return intent;
  return switch (principal) {
    PendingPrincipal() => redirects.pending(intent),
    AnonymousPrincipal() => redirects.unauthenticated(intent),
    AuthenticatedPrincipal() => redirects.forbidden(intent),
  };
}

// ------------------------------------------------------------ topics

abstract final class NavigationTopics {
  static const EventTopic<NavIntent> intent =
      EventTopic<NavIntent>(name: 'nav.intent');
  static const EventTopic<ResolvedNavIntent> resolvedIntent =
      EventTopic<ResolvedNavIntent>(name: 'nav.resolved-intent');
  static const StateTopic<RouteState> currentRoute = StateTopic<RouteState>(
      name: 'nav.current-route', initial: RouteState.initial);
  static const ReplayTopic<RouteTransition> history =
      ReplayTopic<RouteTransition>(name: 'nav.history', bufferSize: 20);
  static const StateTopic<RouteAccessPolicy> accessPolicy =
      StateTopic<RouteAccessPolicy>(
          name: 'nav.access-policy', initial: RouteAccessPolicy.empty);
}

// ------------------------------------------------------------ resolver template

const String _resolverId = 'nav-resolver';

Topology navResolver<S>({
  required StateTopic<S> authState,
  required AccessPrincipal Function(S state) principalOf,
  required AccessRedirects redirects,
  required DeepLinkResolver resolveDeepLink,
  RouteAccessPolicy? policy,
}) =>
    topology(_resolverId, Scope.application, (TopologyBuilder b) {
      final TopicStream<ResolvedNavIntent> resolved = b
          .read(NavigationTopics.intent)
          .map(_Resolution(resolveDeepLink).resolveDeepLinks);
      final TopicStream<AccessPrincipal> principal =
          b.read(authState).map((S state) => principalOf(state));
      final RouteAccessPolicy? fixed = policy;
      final TopicStream<ResolvedNavIntent> guarded = fixed == null
          ? resolved.withLatestFrom2(principal,
              b.read(NavigationTopics.accessPolicy), _ReactiveGuard(redirects).applyAuthGuard)
          : resolved.withLatestFrom(
              principal, _StaticGuard(fixed, redirects).applyAuthGuard);
      b.write(NavigationTopics.resolvedIntent, guarded);
    });

// Seeded defect: the auth map wraps the app's projection in a closure, so it
// records FunctionRef.anonymous() in place of FunctionRef.of(principalOf).
// Stage functions as method tear-offs, so the recorded IR names them
// (topology-ir@v1 G9: a method tear-off is named, a closure is anonymous).
final class _Resolution {
  const _Resolution(this._resolve);
  final DeepLinkResolver _resolve;
  ResolvedNavIntent resolveDeepLinks(NavIntent intent) =>
      _resolveTopLevel(intent, _resolve);
}

ResolvedNavIntent _resolveTopLevel(NavIntent intent, DeepLinkResolver resolve) =>
    resolveDeepLinks(intent, resolve);

final class _ReactiveGuard {
  const _ReactiveGuard(this._redirects);
  final AccessRedirects _redirects;
  ResolvedNavIntent applyAuthGuard(
          ResolvedNavIntent intent, AccessPrincipal principal, RouteAccessPolicy policy) =>
      _guardTopLevel(intent, principal, policy, _redirects);
}

final class _StaticGuard {
  const _StaticGuard(this._policy, this._redirects);
  final RouteAccessPolicy _policy;
  final AccessRedirects _redirects;
  ResolvedNavIntent applyAuthGuard(ResolvedNavIntent intent, AccessPrincipal principal) =>
      _guardTopLevel(intent, principal, _policy, _redirects);
}

ResolvedNavIntent _guardTopLevel(ResolvedNavIntent intent, AccessPrincipal principal,
        RouteAccessPolicy policy, AccessRedirects redirects) =>
    applyAuthGuard(intent, principal, policy, redirects);

// ------------------------------------------------------------ result handling

TopicStream<R> resultsFor<Q, R>(
  TopicStream<R> results,
  TopicStream<Q> requests,
  bool Function(Q request, R result) answers,
) =>
    results
        .withLatestFrom(requests,
            (R result, Q request) => (result: result, answers: answers(request, result)))
        .filter((({R result, bool answers}) p) => p.answers)
        .map((({R result, bool answers}) p) => p.result);

// ------------------------------------------------------------ executor protocol

@immutable
final class NavigationEntry {
  const NavigationEntry(this.state, {this.modal = false});

  final RouteState state;
  final bool modal;

  @override
  bool operator ==(Object other) =>
      other is NavigationEntry && other.state == state && other.modal == modal;

  @override
  int get hashCode => Object.hash(state, modal);

  @override
  String toString() => 'NavigationEntry($state${modal ? ', modal' : ''})';
}

@immutable
sealed class RouterCall {
  const RouterCall();
}

final class PushRoute extends RouterCall {
  const PushRoute(this.entry);

  final NavigationEntry entry;

  @override
  bool operator ==(Object other) => other is PushRoute && other.entry == entry;

  @override
  int get hashCode => Object.hash(PushRoute, entry);

  @override
  String toString() => 'PushRoute($entry)';
}

final class ReplaceRoute extends RouterCall {
  const ReplaceRoute(this.entry);

  final NavigationEntry entry;

  @override
  bool operator ==(Object other) => other is ReplaceRoute && other.entry == entry;

  @override
  int get hashCode => Object.hash(ReplaceRoute, entry);

  @override
  String toString() => 'ReplaceRoute($entry)';
}

final class PopRoute extends RouterCall {
  const PopRoute();

  @override
  bool operator ==(Object other) => other is PopRoute;

  @override
  int get hashCode => (PopRoute).hashCode;

  @override
  String toString() => 'PopRoute()';
}

final class PopUntilRoute extends RouterCall {
  const PopUntilRoute(this.route);

  final NavRoute<Object?> route;

  @override
  bool operator ==(Object other) => other is PopUntilRoute && other.route == route;

  @override
  int get hashCode => Object.hash(PopUntilRoute, route);

  @override
  String toString() => 'PopUntilRoute($route)';
}

@immutable
final class RouteConfirmation {
  RouteConfirmation({required List<NavigationEntry> stack, required this.intent})
      : stack = List<NavigationEntry>.unmodifiable(stack) {
    if (this.stack.isEmpty) {
      throw ArgumentError.value(stack, 'stack', 'is empty');
    }
  }

  final List<NavigationEntry> stack;
  final ResolvedNavIntent intent;

  @override
  bool operator ==(Object other) =>
      other is RouteConfirmation &&
      other.intent == intent &&
      _listEquals(other.stack, stack);

  @override
  int get hashCode => Object.hash(intent, Object.hashAll(stack));

  @override
  String toString() => 'RouteConfirmation($stack, $intent)';
}

enum NavigationRefusal { backAtRoot, targetNotOnStack, noModalToDismiss }

@immutable
sealed class NavigationPlan {
  const NavigationPlan();
}

final class PerformCalls extends NavigationPlan {
  PerformCalls(List<RouterCall> calls) : calls = List<RouterCall>.unmodifiable(calls);

  final List<RouterCall> calls;

  @override
  bool operator ==(Object other) =>
      other is PerformCalls && _listEquals(other.calls, calls);

  @override
  int get hashCode => Object.hashAll(calls);

  @override
  String toString() => 'PerformCalls($calls)';
}

final class RefuseIntent extends NavigationPlan {
  const RefuseIntent(this.reason);

  final NavigationRefusal reason;

  @override
  bool operator ==(Object other) => other is RefuseIntent && other.reason == reason;

  @override
  int get hashCode => Object.hash(RefuseIntent, reason);

  @override
  String toString() => 'RefuseIntent($reason)';
}

NavigationPlan planNavigation(
  List<NavigationEntry> stack,
  ResolvedNavIntent intent, {
  required bool supportsPopUntil,
}) {
  if (stack.isEmpty) throw ArgumentError.value(stack, 'stack', 'is empty');
  return switch (intent) {
    GoTo(:final NavRoute<Object?> route, :final Object? args) => PerformCalls(
        <RouterCall>[PushRoute(NavigationEntry(RouteState(route: route, args: args)))]),
    ShowModal(:final NavRoute<Object?> route, :final Object? args) =>
      PerformCalls(<RouterCall>[
        PushRoute(NavigationEntry(RouteState(route: route, args: args), modal: true)),
      ]),
    Replace(:final NavRoute<Object?> route, :final Object? args) => PerformCalls(
        <RouterCall>[ReplaceRoute(NavigationEntry(RouteState(route: route, args: args)))]),
    Back() => stack.length > 1
        ? PerformCalls(const <RouterCall>[PopRoute()])
        : const RefuseIntent(NavigationRefusal.backAtRoot),
    DismissModal() => !stack.last.modal
        ? const RefuseIntent(NavigationRefusal.noModalToDismiss)
        : stack.length > 1
            ? PerformCalls(const <RouterCall>[PopRoute()])
            : const RefuseIntent(NavigationRefusal.backAtRoot),
    BackTo(:final NavRoute<Object?> route) => _backTo(stack, route, supportsPopUntil),
  };
}

NavigationPlan _backTo(
    List<NavigationEntry> stack, NavRoute<Object?> route, bool supportsPopUntil) {
  final int at = stack.lastIndexWhere((NavigationEntry e) => e.state.route == route);
  if (at < 0) return const RefuseIntent(NavigationRefusal.targetNotOnStack);
  final int pops = stack.length - 1 - at;
  if (pops == 0) return PerformCalls(const <RouterCall>[]);
  return PerformCalls(supportsPopUntil
      ? <RouterCall>[PopUntilRoute(route)]
      : List<RouterCall>.filled(pops, const PopRoute()));
}

abstract interface class NavigationRouter {
  List<NavigationEntry> get stack;
  bool get supportsPopUntil;
  void perform(List<RouterCall> calls, ResolvedNavIntent intent);
  Stream<RouteConfirmation> get confirmations;
}

final class NavigationRefused extends ShellDiagnostic {
  const NavigationRefused({required this.origin, required this.reason, this.route});

  @override
  final String origin;
  final NavigationRefusal reason;
  final NavRoute<Object?>? route;

  @override
  String toString() =>
      'NavigationRefused(origin: $origin, reason: ${reason.name}, route: $route)';
}

final class LateExecutorConstruction extends ShellDiagnostic {
  const LateExecutorConstruction({required this.origin});

  @override
  final String origin;

  @override
  String toString() => 'LateExecutorConstruction(origin: $origin)';
}

final class NavigationExecutor {
  NavigationExecutor(Bus bus, this.router, {String name = 'navigation'})
      : source = ExecutorSource(name),
        _bus = bus {
    _publisher = bus.publisher(source,
        writes: <StateTopic<Object?>>{NavigationTopics.currentRoute});
    try {
      _writer = _publisher.writer(NavigationTopics.currentRoute);
      if (bus.lifecycle == BusLifecycle.running) {
        bus.reportDiagnostic(LateExecutorConstruction(origin: source.toString()));
      }
      _current = router.stack.last.state;
      _intents = bus.observe(NavigationTopics.resolvedIntent).listen(_execute);
      _confirmations = router.confirmations.listen(_confirm);
      _writer.publish(_current);
      bus.onShutdown(dispose);
    } catch (_) {
      _publisher.dispose();
      rethrow;
    }
  }

  final NavigationRouter router;
  final ExecutorSource source;
  final Bus _bus;
  late final Publisher _publisher;
  late final StateWriter<RouteState> _writer;
  late final StreamSubscription<ResolvedNavIntent> _intents;
  late final StreamSubscription<RouteConfirmation> _confirmations;
  late RouteState _current;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void _execute(ResolvedNavIntent intent) {
    if (_disposed) return;
    switch (planNavigation(router.stack, intent,
        supportsPopUntil: router.supportsPopUntil)) {
      case RefuseIntent(:final NavigationRefusal reason):
        _bus.reportDiagnostic(NavigationRefused(
            origin: source.toString(),
            reason: reason,
            route: intent is BackTo ? intent.route : null));
      case PerformCalls(:final List<RouterCall> calls):
        if (calls.isNotEmpty) router.perform(calls, intent);
    }
  }

  void _confirm(RouteConfirmation c) {
    if (_disposed) return;
    final RouteState from = _current;
    final RouteState to = c.stack.last.state;
    _current = to;
    _writer.publish(to);
    _publisher.publish(
        NavigationTopics.history,
        RouteTransition(
            from: from, to: to, intent: c.intent, timestamp: _bus.clock.now()));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_intents.cancel());
    unawaited(_confirmations.cancel());
    _publisher.dispose();
  }
}
