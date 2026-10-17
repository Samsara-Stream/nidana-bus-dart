---
id: navigation-api
version: v1
status: draft
kind: api
owner: nidana.navigation
compatibility: versioned
produced_by: [nidana.navigation]
consumers: [nidana.flutter, nidana.integration]
external_consumers: [app pages publishing intents, app route registries and access policies, app bootstrap code, app navigation tests]
phase_ids: provisional
---

# Contract: navigation-api

- **Governed by:** [ADR-001, ADR-002, ADR-003]

Navigation as a cross-cutting concern on the bus (Guide §3; Spec Appendix A.6): typed routes and the route registry, the intent vocabulary before and after deep-link resolution, the confirmed route state and transitions, the access policy and the principal it is checked against, the five navigation topics, the nav-resolver topology template with its pure deep-link resolution and auth guard, result matching on typed result topics, and the executor protocol: a platform-neutral `NavigationExecutor` that owns every bus-facing duty of Guide §3.4, driving a `NavigationRouter` port that each platform implements, with the pure planner that turns a resolved intent into router calls, `BackTo` synthesis included. Pages publish intents; the resolver guards and resolves them; the executor performs them through the platform's router and writes what the router confirms.

## Boundary

| Declaration group | Contract |
|-------------------|----------|
| `NavRoute`, `RouteRegistry`; `NavIntent`, `DeepLink`, `ResolvedNavIntent` and its six variants; `RouteState`, `RouteTransition`; `RouteAccessRequirement` and its four variants, `RouteAccessPolicy`, `AccessPrincipal` and its three variants, `AccessRedirect`, `AccessRedirects`; `DeepLinkResolver`, `resolveDeepLinks`, `applyAuthGuard`; `NavigationTopics`; `navResolver`; `resultsFor`; `NavigationEntry`, `RouterCall` and its four variants, `RouteConfirmation`, `NavigationRefusal`, `NavigationPlan` and its two variants, `planNavigation`, `NavigationRouter`, `NavigationExecutor`, `NavigationRefused`, `LateExecutorConstruction` | navigation-api@v1, main library |
| `InMemoryRouter` | navigation-api@v1, `testing.dart` |
| a Flutter `NavigationRouter` and `FlutterNavigationExecutor`, route observation, the binding of this contract's executor suite to them under `testWidgets`, module and page scope binding | flutter-binding@v1 |
| `Bus`, publishers, writers, `observe`, `bus.clock`, `onShutdown`, `reportDiagnostic`, `ShellDiagnostic`, activation, the startup barrier | bus-api@v1 |
| `TestBus`, the virtual scheduler, the envelope recorder | bus-testing@v1 |
| `Topic` and its variants, `MessageSource`, `ExecutorSource`, `Scope` | topic-model@v1 |
| `Topology`, `topology(...)`, `TopologyBuilder`, `TopicStream` and its combinators | topology-dsl@v1 |
| `TopologyDefinition`, `TopologyGraph`, `ShellClaim`, `analyzeTopologyGraph` | topology-ir@v1 |
| the app's auth state type, its routes, argument types, access policy, deep-link mapping and redirect targets | application code |

- **Refinement 1. Typed arguments (decides OQ-N2).** A route is `NavRoute<A>`, typed by its argument type, analogous to `Topic<T>`. An intent that carries arguments is built by its route (`order.go(OrderArgs(7))`), so the argument is checked against the route's type. A generic intent constructor would not check it: Dart infers its type argument from both arguments and widens it to their least upper bound, so `GoTo(order, 'seven')` would compile (`docs/auto-run/experiments/navigation-api-fixtures/probe/widening.dart`, W6; `docs/auto-run/experiments/topology-dsl-typing/`, A1). Untyped `Map` arguments, as Guide §3.2 sketches, are rejected for two Dart reasons beyond the lost checking: Dart maps have no value equality, so `RouteState` equality, which `nav.current-route`'s default dedup and every test compare by, would fail for equal arguments; and Guide §3.6's own result example passes a typed request as `args`. Arguments are optional at the call (`A?`), as the Guide's are, because a deep link or a platform route can arrive without them. Path and query parameters stay `Map<String, String>`, filled from what the platform confirms.
- **Refinement 2. The auth binding (decides OQ-N1).** The template is generic over the app's auth state type `S`: it takes the app's `StateTopic<S>` and a pure projection `AccessPrincipal Function(S)` to the library's principal, and `applyAuthGuard` decides over that principal. The app's auth type stays the app's, the resolver reads the app's auth topic directly as Guide §3.4 and Appendix A draw, and the guard is one pure function over library types. The principal has a pending variant, because a cold-start deep link (Guide §3.5) reaches the guard while the auth state may still be in its `Initializing` variant (Spec §7.6); the guard sends it to a `pending` redirect rather than treating it as signed out. Redirect targets are the app's: pure functions from the attempted intent to the intent to perform instead, so a login route can carry the attempted intent as its typed argument. An app whose guard needs more than a principal (onboarding, feature flags) projects those facts into roles or a `CustomAccess` test, or declares its own resolver topology from `resolveDeepLinks` and its own guard; the template is a convenience over public pure functions, not the only resolver.
- **Refinement 3. Resolve, then guard.** Guide §3.4's resolver guards first and resolves second. A deep link has no target route before resolution, so under that order it passes the guard and its resolved target is never checked: a deep link to a protected route would bypass the guard. The template resolves first and guards the resolved intent, so `applyAuthGuard` takes and returns `ResolvedNavIntent`.
- **Refinement 4. `ResolvedNavIntent` is a sealed subfamily of `NavIntent`.** Spec Appendix A.6 describes the resolved type as identical to `NavIntent` except that `DeepLink` is impossible. Here `NavIntent`'s variants are `DeepLink` and the sealed `ResolvedNavIntent`, whose six variants are the rest, as topic-model@v1 makes `MultiWriterTopic` a sealed subfamily of `Topic`. The six variants are declared once, `resolveDeepLinks` passes a resolved intent through unchanged, and a switch over `ResolvedNavIntent` that names the six is exhaustive.
- **Refinement 5. `NavRoute`, not `Route`.** The Specification and the Guide name the route type `Route`. `package:flutter/widgets.dart`, which every Flutter page imports, exports a `Route` class, and a page importing both libraries gets `ambiguous_import` on every use (`probe/flutter_names.dart` in the experiment). No other name declared here collides with `package:flutter/material.dart`.
- **Refinement 6. The executor split.** Guide §3.4 has each platform write a whole executor. Here the bus-facing duties (claiming `nav.current-route`, observing `nav.resolved-intent`, planning, `BackTo` synthesis, writing route state and history together, timestamps, diagnostics, disposal) are written once, in `NavigationExecutor`, and a platform implements only the `NavigationRouter` port: four stack calls, its stack, and its confirmations. The resolver is identical across platforms (Guide §3.4), and so is everything an executor does on the bus. flutter-binding@v1 provides `FlutterNavigationExecutor` as a Flutter `NavigationRouter` with its wiring, not as a subclass, and binds this contract's executor suite to it.
- **Refinement 7. Stack semantics.** The Specification fixes the intent vocabulary but not what each intent does to the stack, and Guide §3.4's executor maps `GoTo` to `go_router`'s location-based `go`, whose stack depends on that router's route tree. A portable conformance suite needs one meaning: `GoTo` pushes, `Replace` replaces the top entry, `Back` pops, `BackTo` pops to the topmost entry of its route, `ShowModal` pushes a modal entry and `DismissModal` pops one. Under this reading `BackTo` and `Replace` stay distinct and useful; a reset-the-stack intent is not in the vocabulary (Versioning). `BackTo` on a router without a native pop-until becomes one `PopRoute` per entry above the target (Guide §3.2), performed and confirmed as one transition, so the result is the same either way.
- **Refinement 8. What this contract reads in bus-api@v1.** The nav-resolver's `withLatestFrom` drops an intent that arrives before the auth read's first value, so G14 and G24 rest on two guarantees of bus-api@v1. Under its G22, the connection of an activation reaches its reads before `activate` returns, every later delivery of a read's topic reaches the read during that delivery, and the publishes the connection causes wait for a provider-zone microtask. Under its G34, every topology activated before `start()` is connected when `start()` delivers the queue, even when nothing runs between the activation and `start()`, so a deep link queued before the activation reaches the resolver's intent read after the auth read's first value, and the queue reaches the reads in its order. bus-api@v1's G22 connection case and G34 deep-link case pin both. The stand-in runtime of `docs/auto-run/experiments/bus-testing-fixtures/`, which passed every bus-api@v1 case before that contract's amendment within v1, delivers the connection one microtask after activation, so it drops a deep link queued before `start()` (`tool/connection_probe.dart` in `docs/auto-run/experiments/navigation-api-fixtures/`) and fails both cases (`docs/auto-run/experiments/bus-api-amendment/`, T9).
- **Refinement 9. Publish typing.** bus-api@v1 types `Bus.publish` and `Publisher.publish` as `publish<T extends Object?, V extends T>(MultiWriterTopic<T> topic, V value)` (its Refinement 3), so that, with the type arguments inferred, `T` comes from the topic alone and the call compiles only when the value's static type is `T` or a subtype of it (its G40). `pages.publish(NavigationTopics.resolvedIntent, DeepLink(uri))` therefore does not compile, reported as `could_not_infer`, and G1 states it. Under the signature this contract was first written against, `publish<T>(MultiWriterTopic<T> topic, T value)`, the same call inferred `T` as `NavIntent` from both arguments, compiled, and failed only at delivery, with a `TypeError` on the stand-in (`probe/widening.dart` W1 and `tool/publish_runtime_probe.dart` in `docs/auto-run/experiments/navigation-api-fixtures/`). Explicit type arguments, such as `publish<NavIntent, DeepLink>`, still widen the topic's type through Dart's covariant generics and compile; bus-api@v1 G40 leaves such a call outside its guarantee, and G1 does too (`docs/auto-run/experiments/navigation-api-touch/`, Q08).

Not here: route hierarchies and nested navigators; codegen of route registries and policies from `routes.yaml` and `policies.yaml` (Guide C.3), which root D1 does not schedule; linking a page's publishes to the navigation that opened it (Guide §10.2, root D1); a platform router of any kind other than the in-memory one.

## Interface

**Libraries:** `package:nidana_dart_navigation/nidana_dart_navigation.dart`, the main library of `nidana_dart_navigation` at `packages/nidana_dart_navigation/` (ADR-002 item 3), carries every declaration below except `InMemoryRouter`; `package:nidana_dart_navigation/testing.dart`, a second public library named by this contract, carries `InMemoryRouter` and nothing else. Neither re-exports `nidana_dart_contracts` or `nidana_dart_runtime`; app code imports those itself. Both import nothing beyond the SDK, `meta`, and the public libraries of `nidana_dart_contracts` and `nidana_dart_runtime` (G26). **Code owner:** nidana.navigation, whose first phase lands every declaration below (ordering policy `fp-progression`, root D10). **Validation artifacts:** `hsdd/contract/fixture/navigation-api/`, owned by hsdd-contract (ADR-001 item 8).

The declarations are the schema of this contract (ADR-001 item 4). Bodies are omitted; the comments, the terms and the guarantees state the semantics. Every class here other than the sealed bases, `NavigationRouter`, `NavigationExecutor` and `InMemoryRouter` is an immutable value (`@immutable`) that keeps its state in final fields, with value equality over the fields its getters name.

### Terms

- **A stack** is a non-empty list of `NavigationEntry`, bottom first; **the top** is its last entry. An entry is a confirmed `RouteState` and whether it is presented modally.
- **A router call** is one of the four stack operations of `RouterCall`. **A perform** is one `NavigationRouter.perform` call: a non-empty list of router calls applied as one platform transition, caused by one resolved intent.
- **A confirmation** is the router's report that a transition has completed: the stack it left and the intent that caused it. **A platform transition** is one the platform makes without a perform, such as a system back.
- **The principal** is what the guard knows of the user: pending, anonymous, or authenticated with a set of roles.

### Routes

```dart
/// A typed route reference (Guide §3.2; Spec Appendix A.6), analogous to
/// Topic<T>: [A] is the type of its arguments, void for a route that takes
/// none. Equal by path and argument type.
final class NavRoute<A> {
  /// [path] is non-empty, asserted ('checkout/cart').
  const NavRoute(String path);

  /// The route of RouteState.initial, before any route is confirmed. Its
  /// path is empty; no registry accepts it.
  static const NavRoute<void> none;

  String get path;
  Type get argsType;                          // A

  // ---- the intents a route builds (G2)
  GoTo go([A? args]);
  Replace replace([A? args]);
  ShowModal showModal([A? args]);
  BackTo backTo();                            // BackTo(this)

  /// state.args when state.route is this route, else null.
  A? argsOf(RouteState state);

  String toString();                          // 'route:{path}'
}

/// The routes of an application or feature (Spec Appendix A.6). Throws
/// ArgumentError for one path under two argument types or NavRoute.none.
final class RouteRegistry {
  RouteRegistry(Iterable<NavRoute<Object?>> routes);
  List<NavRoute<Object?>> get routes;         // first-given order, equal routes once; unmodifiable
  NavRoute<Object?>? lookup(String path);
  RouteRegistry operator +(RouteRegistry other);
}
```

An application declares its routes as `static const` members of an `abstract final class`, as it declares topics (Spec §4.2), and collects them in a `RouteRegistry` where it needs lookup by path, such as in its deep-link mapping or its platform router.

### Intents

```dart
/// The navigation vocabulary before resolution (Guide §3.2; Spec Appendix
/// A.6): a DeepLink or a resolved intent. Sealed.
sealed class NavIntent {
  const NavIntent();
}

/// An OS or web deep link, before resolution. Never reaches an executor.
final class DeepLink extends NavIntent {
  const DeepLink(Uri uri);
  Uri get uri;                                // equal by uri
}

/// The vocabulary after resolution: every NavIntent but DeepLink (G1).
sealed class ResolvedNavIntent extends NavIntent {
  const ResolvedNavIntent();
  /// The route the intent navigates to; null for Back and DismissModal.
  NavRoute<Object?>? get targetRoute;
}

/// Pushes its route (Refinement 7). Made only by NavRoute.go.
final class GoTo extends ResolvedNavIntent {
  NavRoute<Object?> get route;
  Object? get args;
}

/// Replaces the top entry. Made only by NavRoute.replace.
final class Replace extends ResolvedNavIntent {
  NavRoute<Object?> get route;
  Object? get args;
}

/// Pops the top entry.
final class Back extends ResolvedNavIntent {
  const Back();
}

/// Pops to the topmost entry of [route] (Guide §3.2).
final class BackTo extends ResolvedNavIntent {
  const BackTo(NavRoute<Object?> route);
  NavRoute<Object?> get route;
}

/// Pushes its route as a modal entry. Made only by NavRoute.showModal.
final class ShowModal extends ResolvedNavIntent {
  NavRoute<Object?> get route;
  Object? get args;
}

/// Pops the top entry when it is modal.
final class DismissModal extends ResolvedNavIntent {
  const DismissModal();
}
```

The navigation topics are not sensitive (G9), so arguments are visible to every observer with `observeAll`; a route whose arguments would carry sensitive data passes an identifier instead and lets the destination read the data from a sensitive topic (Spec §9.2).

### Route state

```dart
/// The confirmed current route (Guide §3.2; Spec Appendix A.6), as the
/// executor writes it to nav.current-route.
final class RouteState {
  RouteState({
    required NavRoute<Object?> route,
    Object? args,
    Map<String, String> pathParams = const <String, String>{},   // copied
    Map<String, String> queryParams = const <String, String>{},  // copied
  });

  /// nav.current-route before an executor writes it: NavRoute.none, no
  /// arguments, no parameters.
  static const RouteState initial;

  NavRoute<Object?> get route;
  Object? get args;
  Map<String, String> get pathParams;         // unmodifiable
  Map<String, String> get queryParams;        // unmodifiable
}

/// A confirmed transition (Guide §3.2; Spec Appendix A.6), written to
/// nav.history together with the RouteState it reached.
final class RouteTransition {
  const RouteTransition({
    required RouteState from,
    required RouteState to,
    required ResolvedNavIntent intent,        // from the router's confirmation
    required DateTime timestamp,              // the bus clock (G22)
  });
  RouteState get from;
  RouteState get to;
  ResolvedNavIntent get intent;
  DateTime get timestamp;
}
```

### Access

```dart
/// A route's access requirement (Spec Appendix A.6). Sealed.
sealed class RouteAccessRequirement {
  const RouteAccessRequirement();
}
final class PublicAccess extends RouteAccessRequirement { const PublicAccess(); }
final class AuthenticatedAccess extends RouteAccessRequirement { const AuthenticatedAccess(); }
/// Any of [roles]; ArgumentError for an empty set. Copied.
final class RoleAccess extends RouteAccessRequirement {
  RoleAccess(Set<String> roles);
  Set<String> get roles;                      // unmodifiable
}
final class CustomAccess extends RouteAccessRequirement {
  const CustomAccess(bool Function(AccessPrincipal principal) test);
  bool Function(AccessPrincipal principal) get test;
}

/// Route to requirement (Spec Appendix A.6): static, a value the template
/// is given, or reactive, the value of nav.access-policy.
final class RouteAccessPolicy {
  RouteAccessPolicy(
    Map<NavRoute<Object?>, RouteAccessRequirement> requirements,   // copied
    {RouteAccessRequirement fallback = const PublicAccess()},
  );
  /// No requirement listed, PublicAccess fallback: nav.access-policy's initial value.
  static const RouteAccessPolicy empty;

  Map<NavRoute<Object?>, RouteAccessRequirement> get requirements;  // unmodifiable
  RouteAccessRequirement get fallback;        // for every route not listed
  RouteAccessRequirement requirementFor(NavRoute<Object?> route);
}

/// What the guard knows of the user (Refinement 2). Sealed.
sealed class AccessPrincipal {
  const AccessPrincipal();
}
/// The auth state is not known yet (Spec §7.6).
final class PendingPrincipal extends AccessPrincipal { const PendingPrincipal(); }
final class AnonymousPrincipal extends AccessPrincipal { const AnonymousPrincipal(); }
final class AuthenticatedPrincipal extends AccessPrincipal {
  AuthenticatedPrincipal({Set<String> roles = const <String>{}});   // copied
  Set<String> get roles;                      // unmodifiable
}

/// The intent to perform instead of [attempted], which the guard refused.
typedef AccessRedirect = ResolvedNavIntent Function(ResolvedNavIntent attempted);

/// Where the guard sends a refused intent, by principal.
final class AccessRedirects {
  const AccessRedirects({
    required AccessRedirect unauthenticated,  // an AnonymousPrincipal
    required AccessRedirect forbidden,        // an AuthenticatedPrincipal
    AccessRedirect? pending,                  // a PendingPrincipal; unauthenticated when null
  });
  AccessRedirect get unauthenticated;
  AccessRedirect get forbidden;
  AccessRedirect get pending;
}
```

### Pure functions

```dart
/// The app's mapping of a deep link to a resolved intent; total: a link
/// the app does not know maps to a route it chooses, such as a not-found
/// page, so no intent is dropped silently.
typedef DeepLinkResolver = ResolvedNavIntent Function(Uri uri);

/// [resolve] of a DeepLink's uri; any resolved intent itself (G11).
ResolvedNavIntent resolveDeepLinks(NavIntent intent, DeepLinkResolver resolve);

/// [intent] when [principal] satisfies [policy]'s requirement for its
/// target route, else the redirect for [principal] (G12).
ResolvedNavIntent applyAuthGuard(
  ResolvedNavIntent intent,
  AccessPrincipal principal,
  RouteAccessPolicy policy,
  AccessRedirects redirects,
);

/// The router calls that perform [intent] on [stack], or why it cannot be
/// performed (G17). ArgumentError for an empty stack.
NavigationPlan planNavigation(
  List<NavigationEntry> stack,
  ResolvedNavIntent intent, {
  required bool supportsPopUntil,
});
```

`applyAuthGuard` keeps Guide §3.4's single shape for static and reactive policies: the policy is an argument either way.

### Topics

```dart
/// The navigation topics (Guide §3.3), published by this package for every
/// module (root D7).
abstract final class NavigationTopics {
  /// Pages publish intents here.
  static const EventTopic<NavIntent> intent;                    // 'nav.intent'
  /// The nav-resolver's output, the executor's input.
  static const EventTopic<ResolvedNavIntent> resolvedIntent;    // 'nav.resolved-intent'
  /// The confirmed current route; the executor's claim (Spec §3.11).
  static const StateTopic<RouteState> currentRoute;             // 'nav.current-route', initial RouteState.initial
  /// The confirmed transitions, written by the executor.
  static const ReplayTopic<RouteTransition> history;            // 'nav.history', buffer 20
  /// The reactive access policy, written by the app's owner of it.
  static const StateTopic<RouteAccessPolicy> accessPolicy;      // 'nav.access-policy', initial RouteAccessPolicy.empty
}
```

`nav.access-policy` has no writer in this package. An app that uses the reactive form owns it with a topology or a claimed publisher; until its first value is delivered the policy is `RouteAccessPolicy.empty`, which admits every route, so such an app publishes its first policy before `start()`, ahead of any intent its bootstrap publishes (Spec §3.13 delivers the queue in publication order).

### The resolver template

```dart
/// The nav-resolver (Guide §3.4): an APPLICATION topology with id
/// 'nav-resolver'. Reads nav.intent, [authState] and, when [policy] is
/// null, nav.access-policy; writes nav.resolved-intent. Its stages, in
/// order: a map of the intent read through resolveDeepLinks with
/// [resolveDeepLink]; a map of the [authState] read through [principalOf];
/// a withLatestFrom on the first, whose latest inputs are the second and,
/// when [policy] is null, the nav.access-policy read, combining through
/// applyAuthGuard with [redirects]; the write of that stage to
/// nav.resolved-intent.
Topology navResolver<S>({
  required StateTopic<S> authState,
  required AccessPrincipal Function(S state) principalOf,
  required AccessRedirects redirects,
  required DeepLinkResolver resolveDeepLink,
  RouteAccessPolicy? policy,                  // static when given (Guide §3.4)
});
```

The auth topic is a `StateTopic`, so the resolver's latest inputs always hold a value once its activation has connected (bus-api@v1 G22; Refinement 8), and no intent waits or is dropped for lack of one. Its owner's scope must be `APPLICATION`, which bus-api@v1 G24 checks at activation (Spec §7.2).

### Result handling

```dart
/// The values of [results] that answer the latest value of [requests]
/// (Guide §3.6): a withLatestFrom of [results] on [requests], a filter by
/// [answers], and a map back to the result. Matching is on payloads only.
TopicStream<R> resultsFor<Q, R>(
  TopicStream<R> results,
  TopicStream<Q> requests,
  bool Function(Q request, R result) answers,
);
```

A destination page publishes its result to an app result topic and then `Back`; the source page's `PAGE` topology reads the result topic and the requests it made, and keeps the answers to its latest request through `resultsFor`. No intent, route state or transition carries a result, and matching never reads envelope metadata, which transformers do not see (Spec §3.5).

### The executor protocol

```dart
/// One stack entry: a confirmed route state and its presentation.
final class NavigationEntry {
  const NavigationEntry(RouteState state, {bool modal = false});
  RouteState get state;
  bool get modal;
}

/// A stack operation a router performs (Refinement 7). Sealed.
sealed class RouterCall {
  const RouterCall();
}
final class PushRoute extends RouterCall {         // adds [entry] on top
  const PushRoute(NavigationEntry entry);
  NavigationEntry get entry;
}
final class ReplaceRoute extends RouterCall {      // replaces the top with [entry]
  const ReplaceRoute(NavigationEntry entry);
  NavigationEntry get entry;
}
final class PopRoute extends RouterCall {          // removes the top
  const PopRoute();
}
final class PopUntilRoute extends RouterCall {     // removes entries until the topmost entry of [route] is on top
  const PopUntilRoute(NavRoute<Object?> route);
  NavRoute<Object?> get route;
}

/// A router's report of a completed transition. ArgumentError for an
/// empty stack.
final class RouteConfirmation {
  RouteConfirmation({
    required List<NavigationEntry> stack,     // copied, bottom first
    required ResolvedNavIntent intent,
  });
  List<NavigationEntry> get stack;            // unmodifiable
  ResolvedNavIntent get intent;
}

enum NavigationRefusal { backAtRoot, targetNotOnStack, noModalToDismiss }

/// planNavigation's answer. Sealed.
sealed class NavigationPlan {
  const NavigationPlan();
}
final class PerformCalls extends NavigationPlan {  // possibly empty: nothing to do
  PerformCalls(List<RouterCall> calls);           // copied
  List<RouterCall> get calls;                     // unmodifiable
}
final class RefuseIntent extends NavigationPlan {
  const RefuseIntent(NavigationRefusal reason);
  NavigationRefusal get reason;
}

/// The platform half of an executor (Refinement 6): what a platform adapter
/// implements over its router. The one interface of this contract an
/// implementation outside the package implements (G18).
abstract interface class NavigationRouter {
  /// The stack now, bottom first; never empty; an unmodifiable snapshot that
  /// reflects every perform as soon as it returns.
  List<NavigationEntry> get stack;

  /// Whether perform accepts PopUntilRoute (Guide §3.2).
  bool get supportsPopUntil;

  /// Applies [calls] in order as one transition caused by [intent], then
  /// confirms it once. ArgumentError for no calls; StateError, changing and
  /// confirming nothing, for a call the stack does not admit.
  void perform(List<RouterCall> calls, ResolvedNavIntent intent);

  /// One confirmation per perform, once the platform has completed it, and
  /// one per platform transition.
  Stream<RouteConfirmation> get confirmations;
}

/// The executor (Guide §3.4; Spec Appendix A.6): one per coordination
/// domain, APPLICATION-scoped shell infrastructure over the platform's
/// router.
final class NavigationExecutor {
  /// Claims nav.current-route for ExecutorSource(name) through bus.publisher
  /// (ClaimRejected when it has an owner; StateError after shutdown), writes
  /// the router's top state to it, observes nav.resolved-intent, listens to
  /// the router's confirmations and registers dispose with bus.onShutdown.
  /// A construction that throws claims nothing.
  NavigationExecutor(Bus bus, NavigationRouter router, {String name = 'navigation'});

  NavigationRouter get router;
  ExecutorSource get source;                  // ExecutorSource(name)
  bool get isDisposed;
  void dispose();                             // idempotent (G23)
}

/// A resolved intent the stack does not admit (G20). Holds no payload.
final class NavigationRefused extends ShellDiagnostic {
  const NavigationRefused({
    required String origin,                   // 'executor:{name}'
    required NavigationRefusal reason,
    NavRoute<Object?>? route,                 // BackTo's target; null for the others
  });
  String get origin;
  NavigationRefusal get reason;
  NavRoute<Object?>? get route;
}

/// An executor constructed after start() (G19), which a deep link queued
/// before start() has already missed.
final class LateExecutorConstruction extends ShellDiagnostic {
  const LateExecutorConstruction({required String origin});
  String get origin;
}
```

The executor plans against `router.stack` when a resolved intent arrives and writes against what the router confirms, so a router that confirms after a frame (a declarative router) and one that confirms at once behave alike on the bus. A router reports platform transitions through the same stream; the executor writes them like any other (G21).

### The testing library

Library `package:nidana_dart_navigation/testing.dart`. It imports neither `package:test` nor `package:flutter_test` (G26).

```dart
/// A NavigationRouter with no platform (G25): its stack is a list in memory,
/// and it confirms synchronously, so a VM test on a TestBus drives
/// navigation through bus and scheduler operations alone (bus-testing@v1).
final class InMemoryRouter implements NavigationRouter {
  InMemoryRouter(RouteState initial, {bool supportsPopUntil = true});
  List<NavigationEntry> get stack;
  bool get supportsPopUntil;
  void perform(List<RouterCall> calls, ResolvedNavIntent intent);
  Stream<RouteConfirmation> get confirmations;   // broadcast, synchronous
  /// The calls of every perform carried out, in order; unmodifiable.
  List<List<RouterCall>> get performed;
  /// A platform back: pops the top entry and confirms with const Back();
  /// does nothing at the root.
  void platformBack();
}
```

### How an app uses it

```dart
abstract final class AppRoutes {
  static const NavRoute<void> home = NavRoute<void>('app/home');
  static const NavRoute<OrderArgs> order = NavRoute<OrderArgs>('orders/detail');
  static const NavRoute<ResolvedNavIntent> login = NavRoute<ResolvedNavIntent>('auth/login');
}

// Bootstrap (Guide §3.5): the resolver active and the executor constructed
// before start(); a deep link the OS delivered earlier is already queued.
final Bus bus = Bus();
bus.activate(navResolver<AuthState>(
  authState: AuthTopics.state,
  principalOf: principalOf,                   // the app's pure projection
  redirects: const AccessRedirects(unauthenticated: toLogin, forbidden: toDenied),
  resolveDeepLink: resolveAppLink,            // the app's total mapping
  policy: appAccessPolicy,                    // or none: nav.access-policy
));
final NavigationExecutor executor = NavigationExecutor(bus, platformRouter);
bus.start();

// A page navigates by intent, with typed arguments.
pages.publish(NavigationTopics.intent, AppRoutes.order.go(OrderArgs(id: 7)));
```

On Flutter, `platformRouter` and its wiring come from flutter-binding@v1's `FlutterNavigationExecutor`; in VM tests it is an `InMemoryRouter` on a `TestBus`.

## Guarantees / invariants

- **G1** The intent families are closed (Guide §3.2; Spec Appendix A.6): `NavIntent` is sealed, its subtypes are exactly `DeepLink` and the sealed `ResolvedNavIntent`, whose subtypes are exactly `GoTo`, `Replace`, `Back`, `BackTo`, `ShowModal` and `DismissModal`; every variant is final, no type outside the library extends or implements any of them, and a switch over either family that omits a variant does not compile. A `DeepLink` is not a `ResolvedNavIntent`, so no declaration of this contract that takes or yields a resolved intent accepts one: `resolveDeepLinks`'s and `applyAuthGuard`'s results, a `DeepLinkResolver`'s result, `RouteTransition.intent`, `RouteConfirmation.intent`, `NavigationRouter.perform`, `planNavigation` and a variable of type `ResolvedNavIntent`; and since `NavigationTopics.resolvedIntent` is an `EventTopic<ResolvedNavIntent>`, neither does a call of `Bus.publish` or `Publisher.publish` on it with its type arguments inferred (bus-api@v1 G40; Refinement 9). A deep link is impossible by construction after resolution.
- **G2** Arguments are typed by their route (decides OQ-N2): `GoTo`, `Replace` and `ShowModal` have no public constructor and are made by `NavRoute<A>.go`, `replace` and `showModal`, whose optional argument parameter is `A?`, so an argument of another type does not compile; `argsOf` returns `A?`.
- **G3** The other families are closed: `RouteAccessRequirement` is sealed with exactly `PublicAccess`, `AuthenticatedAccess`, `RoleAccess` and `CustomAccess`; `AccessPrincipal` with exactly `PendingPrincipal`, `AnonymousPrincipal` and `AuthenticatedPrincipal`; `RouterCall` with exactly `PushRoute`, `ReplaceRoute`, `PopRoute` and `PopUntilRoute`; `NavigationPlan` with exactly `PerformCalls` and `RefuseIntent`; `NavigationRefusal` has exactly the values `backAtRoot`, `targetNotOnStack` and `noModalToDismiss`. Every class of this contract other than the sealed bases and `NavigationRouter` is final, no type outside the package extends or implements one, and a switch that omits a variant does not compile. `NavigationRouter` is the one interface an implementation outside the package implements.
- **G4** Navigation values are immutable: no field of a route, registry, intent, route state, transition, requirement, policy, principal, redirect set, entry, router call, confirmation or plan can be assigned, and every list, map and set they expose is an unmodifiable copy that later changes to the argument do not reach.
- **G5** Routes (Guide §3.2): two routes are equal, with equal hash codes, exactly when their paths and argument types are equal; `argsType` is the type argument; `toString()` is `route:{path}`; a path is non-empty, asserted, except that of `NavRoute.none`, which is empty; `argsOf(state)` is `state.args` when `state.route` equals the route, and null otherwise.
- **G6** Intents: `go(args)`, `replace(args)` and `showModal(args)` carry the route and the argument, null when it is omitted; `backTo()` equals `BackTo(route)`; two intents are equal, with equal hash codes, exactly when their variants and fields are equal, so every `Back` equals every other `Back`, likewise `DismissModal`, and `DeepLink` is equal by its URI; `targetRoute` is the route of `GoTo`, `Replace`, `ShowModal` and `BackTo`, and null for `Back` and `DismissModal`.
- **G7** A route registry (Spec Appendix A.6) lists its routes once each in the order first given, an equal route counted once; it throws `ArgumentError` for two routes of one path with different argument types and for `NavRoute.none`; `lookup(path)` is the route of that path or null; `a + b` is the registry of `a`'s routes then `b`'s, under the same rules; two registries are equal when their route lists are.
- **G8** Route state and transitions (Spec Appendix A.6): a route state defaults to null arguments and empty parameter maps; `RouteState.initial` is `NavRoute.none` with no arguments and no parameters; route states are equal, with equal hash codes, exactly when route, arguments and both parameter maps are equal, maps compared by entries; transitions are equal exactly when `from`, `to`, `intent` and `timestamp` are.
- **G9** The navigation topics (Guide §3.3): `NavigationTopics` declares `intent`, an `EventTopic<NavIntent>` named `nav.intent`; `resolvedIntent`, an `EventTopic<ResolvedNavIntent>` named `nav.resolved-intent`; `currentRoute`, a `StateTopic<RouteState>` named `nav.current-route` with initial value `RouteState.initial`; `history`, a `ReplayTopic<RouteTransition>` named `nav.history` with a buffer of 20; and `accessPolicy`, a `StateTopic<RouteAccessPolicy>` named `nav.access-policy` with initial value `RouteAccessPolicy.empty`. Each is const, not sensitive, traced, with the default dedup, and has a well-formed name (Spec §4.4).
- **G10** Access values (Spec Appendix A.6): `requirementFor(route)` is the requirement listed for the route, else `fallback`, which is `PublicAccess` unless given; `RouteAccessPolicy.empty` lists nothing and falls back to `PublicAccess`; two policies are equal when their fallbacks and their listed entries are, whatever the listing order; `RoleAccess` throws `ArgumentError` for an empty set and is equal by its set; `CustomAccess` is equal by its function; principals are equal by variant and, for `AuthenticatedPrincipal`, by roles, which are empty unless given; `AccessRedirects.pending` is the `unauthenticated` redirect when none is given.
- **G11** `resolveDeepLinks(intent, resolve)` returns `resolve(uri)` for a `DeepLink`, calling `resolve` once, and returns a resolved intent itself without calling `resolve` (Guide §3.4).
- **G12** `applyAuthGuard(intent, principal, policy, redirects)` (Guide §3.4) returns `intent` itself when it has no target route or `principal` satisfies `policy.requirementFor(intent.targetRoute)`, and otherwise the redirect for `principal`, called with `intent`: `pending` for a `PendingPrincipal`, `unauthenticated` for an `AnonymousPrincipal`, `forbidden` for an `AuthenticatedPrincipal`. Every principal satisfies `PublicAccess`; an authenticated one satisfies `AuthenticatedAccess`, and `RoleAccess` when it holds any of its roles; any principal satisfies `CustomAccess` exactly when the test, called once with it, holds. A redirect's result is not guarded again.
- **G13** The recorded nav-resolver (Guide §3.4; Spec §6.5; decides OQ-N1 with Refinement 2): `navResolver` returns an `APPLICATION` topology with id `nav-resolver` whose definition reads `nav.intent`, the given auth topic and, when no static policy is given, `nav.access-policy`, and writes `nav.resolved-intent` only; its edges are, in order, a `map` of the intent read, a `map` of the auth read, a `withLatestFrom` whose primary is the first edge and whose latest inputs are the second edge and, in the reactive form, the policy read, and a write of the third edge; two nav-resolvers of one configuration record equal definitions.
- **G14** The live nav-resolver (Guide §3.4; Spec §3.5): once its activation has connected (bus-api@v1 G22), it publishes exactly one resolved intent for each intent delivered on `nav.intent`, in delivery order, equal to `applyAuthGuard(resolveDeepLinks(intent, resolveDeepLink), principalOf(auth), policy, redirects)` with the auth topic's latest value and the given static policy or the latest value of `nav.access-policy`, so a deep link is guarded after it is resolved; each is published with `TopologySource('nav-resolver')`, caused by the intent's envelope and carrying its correlation id.
- **G15** The resolver and the executor keep the graph acyclic (Guide §3.4; Spec §3.8): the nav-resolver reads none of `nav.resolved-intent`, `nav.current-route` and `nav.history`, and an executor writes only `nav.current-route`, through its claim, and `nav.history`; with the resolver active and an executor constructed, `analyzeTopologyGraph(bus.toGraph())` has no finding; a topology that writes `nav.intent` from `nav.resolved-intent` forms a `TopologyCycle` with the resolver and is not activated (bus-api@v1 G24).
- **G16** Result handling (Guide §3.6): `resultsFor(results, requests, answers)` records a `withLatestFrom` of `results` on `requests`, then a `filter` and a `map`, and emits exactly the results for which `answers(request, result)` holds of the latest request, compared on payloads; a result that arrives before any request is dropped.
- **G17** `planNavigation(stack, intent, supportsPopUntil:)` is a pure function of its arguments that throws `ArgumentError` for an empty stack (Guide §3.2, §3.4): `GoTo` plans one `PushRoute` of a non-modal entry of its route and arguments; `ShowModal` one `PushRoute` of a modal entry; `Replace` one `ReplaceRoute` of a non-modal entry; `Back` one `PopRoute`, refused `backAtRoot` on a stack of one entry; `DismissModal` one `PopRoute` when the top is modal, refused `noModalToDismiss` when it is not and `backAtRoot` when it is the only entry; `BackTo(route)` targets the topmost entry of `route`: no call when it is the top, one `PopUntilRoute(route)` when `supportsPopUntil`, else one `PopRoute` per entry above it, refused `targetNotOnStack` when no entry has the route.
- **G18** The router port (Guide §3.4): a `NavigationRouter`'s `stack` is never empty, starts as the router's initial entry, is an unmodifiable snapshot and reflects every perform as soon as it returns; `perform(calls, intent)` applies the calls in order (`PushRoute` adds its entry on top, `ReplaceRoute` replaces the top with its entry, `PopRoute` removes the top, `PopUntilRoute` removes entries until the topmost entry of its route is on top) and reports exactly one confirmation, once the platform has completed the calls, with the stack they leave and `intent`; a perform with no calls throws `ArgumentError`, and one with a call that would empty the stack, a `PopUntilRoute` whose route is not on the stack, or a `PopUntilRoute` on a router that does not support it, throws `StateError`, either changing and confirming nothing; a platform transition is reported as one confirmation, a platform back as a pop confirmed with `const Back()`, and a platform back at the root changes and confirms nothing.
- **G19** Executor construction (Spec §3.11, §3.13; Guide §3.4): `NavigationExecutor(bus, router, name:)` claims `nav.current-route` for `ExecutorSource(name)` through `bus.publisher` and writes the router's top state to it, delivered as any publish is (bus-api@v1 G34), and writes nothing to `nav.history`; while it holds the claim, another executor or publisher claiming the topic throws `ClaimRejected` and a topology writing it is rejected with `ActivationRejected` (bus-api@v1 G20, G24); the topic is a state topic, so no publisher-less or unclaimed publish reaches it, and the executor exposes neither its publisher nor its writer: only the executor's claim writes `nav.current-route`. In dev mode an executor constructed after `start()` is reported as `LateExecutorConstruction` with origin `executor:{name}`, and works. A construction that throws claims nothing.
- **G20** Executing intents (Guide §3.2, §3.4): the executor acts on `nav.resolved-intent` and on no other intent topic; for each resolved intent, in delivery order, it plans with `planNavigation` over the router's current stack and `supportsPopUntil`; a plan with calls is performed by one `perform` with the intent, and a plan with none does nothing; a refusal performs and writes nothing and, in dev mode, is reported as `NavigationRefused` with the reason, `BackTo`'s target route or null, and origin `executor:{name}`. So `BackTo` is one transition whether the router pops until natively or the plan synthesizes it from pops.
- **G21** Writing confirmed transitions (Guide §3.4; Spec Appendix A.6): for each confirmation of its router, a perform's or a platform transition's, the executor writes the top state of the confirmed stack to `nav.current-route` and then a `RouteTransition` to `nav.history` from the state it wrote last to that state, with the confirmation's intent; it makes the two publishes one after the other, so no delivery comes between them (bus-api@v1 G13, G14); each transition's `from` is the previous transition's `to`, and the last transition's `to` is the value of `nav.current-route`.
- **G22** A transition's timestamp is the bus clock, `bus.clock.now()`, read when the executor handles the confirmation (ADR-003 item 8), so it follows virtual time on a TestBus and `tester.pump` in a widget test.
- **G23** Disposal (Guide §3.4; Spec §11.2): `dispose` is idempotent; it cancels the executor's subscriptions without waiting on a cancel future (ADR-003 item 3) and disposes its publisher, releasing the claim, after which no resolved intent is performed and no confirmation is written; the constructor registers `dispose` with `bus.onShutdown`, so shutting the bus down disposes the executor.
- **G24** The deep-link bootstrap (Guide §3.5; Spec §3.13): when the bootstrap activates the nav-resolver and constructs the executor before `start()`, a `DeepLink` published to `nav.intent` before `start()`, even before the activation, is resolved, guarded and performed once `start()` delivers it, with nothing run between the activation and `start()`; this rests on bus-api@v1 G22 and G34 (Refinement 8).
- **G25** The in-memory router (`testing.dart`): `InMemoryRouter(initial, supportsPopUntil:)` meets G18 with no platform; its stack starts as `initial`, not modal; it supports `PopUntilRoute` unless `supportsPopUntil` is false; it reports each confirmation synchronously, before `perform` or `platformBack` returns; `performed` lists the calls of every perform it carried out, in order; `platformBack()` is its platform back.
- **G26** `nidana_dart_navigation` depends on `nidana_dart_contracts`, `nidana_dart_runtime` and `meta` only, has no Flutter dependency, and neither public library imports `package:test` or `package:flutter_test` (ADR-002 items 3 and 4).
- **G27** `nidana_dart_navigation` reads no wall clock, constructs no `Stopwatch` and creates no timer or microtask; the only time it reads is the bus clock of G22 (ADR-003 item 8).

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates.
- Breaking for this contract: removing, renaming or retyping any declaration; adding a variant to `NavIntent`, `ResolvedNavIntent`, `RouteAccessRequirement`, `AccessPrincipal`, `RouterCall`, `NavigationPlan` or `NavigationRefusal`, which consumers switch over exhaustively; adding a member to `NavigationRouter`, which platforms implement; changing what an intent does to the stack, the guard's decision table, the order of resolution and guarding, the resolver's id, scope, reads, writes or stages, a topic's name, variant, type, initial value or buffer, the order of the two writes, the timestamp source, the routes' or values' equality, or which operation throws what.
- Compatible: a new optional named parameter with a default that keeps current behavior; a new getter or method on a final class; a new top-level function; a new `ShellDiagnostic` the executor reports in dev mode; a new guarantee that existing fixtures still pass.
- Touched within v1 after bus-api@v1's amendment within v1 and the authoring of flutter-binding@v1, with no declaration changed, no guarantee removed or weakened and no id moved. G1 gains the clause that a publish to `nav.resolved-intent` with inferred type arguments accepts no `DeepLink`, and `reject/resolved_intent_is_never_a_deep_link.dart` gains its two lines. Refinement 8 cites bus-api@v1 G22 and G34, which now state the reading it held, in place of that reading and of the note that bus-api@v1's fixtures did not pin it; Refinement 9 cites bus-api@v1 G40 in place of the gap it recorded; G14 and G24 cite G22 and G34 directly. Validation names flutter-binding@v1's binding of the executor suite. The clause adds no rejection of its own: bus-api@v1 G40 already rejects the call, so no consumer code that compiled after that amendment stops compiling. It is a new guarantee clause that existing fixtures still pass, compatible under the list above: every fixture as it stood before the touch, and flutter-binding@v1's binding of the executor suite, passes unchanged against a stand-in that meets bus-api@v1 as amended (`docs/auto-run/experiments/navigation-api-touch/`).
- Not in v1, each a candidate for a later version: an intent that resets the stack to one route, and route hierarchies or nested navigators (Refinement 7); holding intents until the auth state is known, in place of the `pending` redirect; guarding `Back`; typed path and query parameters; codegen of route registries and policies (Guide C.3, root D1); linking a page's publishes to the navigation that opened it (Guide §10.2, root D1); a platform router in this package.

## Validation

- fixture: `hsdd/contract/fixture/navigation-api/`, under `hsdd/contract/fixture/analysis_options.yaml` (ADR-001 item 2); replayed with `fvm dart run nidana_contract_check navigation-api`.
- surface: `hsdd/contract/fixture/navigation-api/surface/` (`routes_and_intents.dart`, `access_and_resolver.dart`, `executor.dart`) uses every declaration with the types the Interface states, declares a route registry class, builds both resolver forms and a `PAGE` topology with `resultsFor`, implements `NavigationRouter` in full, and switches exhaustively over `NavIntent` (both ways), `ResolvedNavIntent`, `RouteAccessRequirement`, `AccessPrincipal`, `RouterCall`, `NavigationPlan` and `NavigationRefusal`, so a variant added to any of them, or a member added to `NavigationRouter`, fails the surface set.
- reject: `hsdd/contract/fixture/navigation-api/reject/`, one library per type-level guarantee: `intents_are_closed.dart` and `resolved_intent_is_never_a_deep_link.dart` (G1; the second also publishes a `DeepLink` to `nav.resolved-intent` through a publisher and publisher-less, each reported as `could_not_infer` through bus-api@v1 G40), `route_arguments_are_typed.dart` (G2), `navigation_types_are_closed.dart` (G3), `navigation_values_are_immutable.dart` (G4), `current_route_is_claimed_by_the_executor.dart` (G19).
- behavior, navigation: conformance library `hsdd/contract/fixture/navigation-api/behavior/navigation_conformance.dart`, harness `NavigationHarness`, cases `navigationConformance`, covering G1, G4 to G17 and G25. The declarations have one implementation, the producer's, so the cases construct them directly, run live topologies on bus-testing@v1's `TestBus` and assert on its recorder, and the harness supplies only `settle`. They let real time pass only through `VirtualScheduler.settle`, so the suite is bound under `dart test` only.
- binding: `hsdd/contract/fixture/navigation-api/behavior/nidana_dart_navigation_test.dart` binds the navigation suite to the producer's declarations in `nidana_dart_navigation`, under `dart test`. It must pass every case of `navigationConformance`.
- behavior, executor: conformance library `hsdd/contract/fixture/navigation-api/behavior/navigation_executor_conformance.dart`, harness `NavigationExecutorHarness` with `NavigationRun`, cases `navigationExecutorConformance`, covering G18 to G24. The harness names no bus-testing@v1 type: a binding supplies a bus (`bus`), the implementation under test on it (`executor`, a router whose stack is the initial entry and a `NavigationExecutor` over it), the platform's back action (`platformBack`), clock movement (`elapse`) and quiescence (`settle`). The cases assert timestamps against the bus clock read around each navigation, never as literals, so they hold on a virtual clock and on a production clock driven by `tester.pump`.
- binding: `hsdd/contract/fixture/navigation-api/behavior/in_memory_router_test.dart` binds the executor suite to `NavigationExecutor` over `InMemoryRouter` (`testing.dart`), each case on fresh `TestBus` instances, under `dart test`, twice: on a router that supports `PopUntilRoute` and on one that does not, the second registration's name suffixed so that both begin with the guarantee id. It must pass every case of `navigationExecutorConformance` both times.
- The Flutter router is declared by flutter-binding@v1, so its binding of the executor suite, `hsdd/contract/fixture/flutter-binding/behavior/flutter_navigation_executor_test.dart`, lives in that contract's fixture directory and is listed in that contract's `## Validation`. It imports `../../navigation-api/behavior/navigation_executor_conformance.dart` by relative path (ADR-001 item 4) and binds the suite to `FlutterNavigationExecutor` under `testWidgets`, on a production-provider bus built in the test body and shut down before it ends (ADR-003 item 7); its `settle` is `tester.pumpAndSettle()`, its `elapse` is `tester.pump(duration)`, and its `executor` constructs the executor before it pumps the `WidgetsApp` that hosts the router, as an app's bootstrap does (flutter-binding@v1 G12). nidana.flutter's gate runs it; nidana.navigation's does not.
- Both bindings here import packages that name the implementation, so the replay tool reports them as `PENDING` until `nidana_dart_navigation` exists (ADR-001 item 9). They run in nidana.navigation's gates; nidana.integration's gate runs them with `--all`.
- type-level guarantees G1 to G4 and the type-level half of G19 are checked by the reject and surface sets.
- not executable: G26, a property of the package's pubspec and imports; checked by nidana.navigation's gates
- not executable: G27, a property of the package's sources rather than of its declarations; checked by nidana.navigation's gates
- No schema: an `api` contract with no serialized form carries none (ADR-001 item 4).
- The fixtures are forward references, written before the package exists. In `docs/auto-run/experiments/navigation-api-fixtures/` (`run.sh`, `output.txt`) a stand-in `nidana_dart_navigation` implements this Interface on the stand-in runtime of `docs/auto-run/experiments/bus-testing-fixtures/`; the surface set analyzed clean; every reject code was confirmed against the stand-in; the navigation suite passed 40 of 40 cases, the executor suite 52 of 52 registrations on `InMemoryRouter`, and 26 of 26 cases under `fvm flutter test` and `testWidgets` against a minimal stand-in Flutter router over `Navigator` on a production-provider bus (`standin_bindings/flutter_navigation_standin_test.dart`, which flutter-binding@v1's binding `hsdd/contract/fixture/flutter-binding/behavior/flutter_navigation_executor_test.dart` replaces); and each of 33 seeded defects, in the stand-in package, the in-memory router and the stand-in Flutter router, failed the cases of the guarantee it breaks. The executor suite's G24 cases and one G14 case pass only against a runtime whose activation connection reaches its reads before later deliveries (Refinement 8); the experiment's copy of the runtime carries that change, under which bus-api@v1's two bindings and bus-testing@v1's binding still pass unchanged, and it records which cases fail without it. bus-api@v1 G22 and G34 now state that behavior, and `docs/auto-run/experiments/bus-api-amendment/` replays every fixture here against a runtime that meets them and bus-api@v1 G40 (bus-api@v1 Validation). The first replay against the real packages, once nidana.model's first phase lands the replay tool, is their first verification (ADR-001 Consequences).
- The touch within v1 (`## Versioning`) is checked in `docs/auto-run/experiments/navigation-api-touch/` (`run.sh`, `output.txt`), on the stand-in packages of `docs/auto-run/experiments/flutter-binding-fixtures/`, unchanged, whose runtime and navigation packages are those of `docs/auto-run/experiments/bus-api-amendment/`. The fixtures at the commit the touch started from and the fixtures as amended, which differ only in `reject/resolved_intent_is_never_a_deep_link.dart`, each passed: structure for this contract (27 guarantees, 66 cases, 2 bindings) and for flutter-binding@v1; the surface set; every reject code; the navigation suite 40 of 40 and the executor suite 52 of 52 on `InMemoryRouter`; and flutter-binding@v1's binding of the executor suite 26 of 26 under `fvm flutter test --no-pub`. Each new reject line reports `could_not_infer` alone (probe Q01, Q02). With both publish paths of the stand-in reverted to `publish<T>(MultiWriterTopic<T> topic, T value)`, the new lines compile and the reject set fails on their file alone, while the fixtures from before the touch still pass, so these lines are what pins bus-api@v1 G40 for `nav.resolved-intent` here.
