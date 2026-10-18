---
id: flutter-binding
version: v1
status: stable
kind: api
owner: nidana.flutter
compatibility: versioned
produced_by: [nidana.flutter.1, nidana.flutter.2, nidana.flutter.3, nidana.flutter.4, nidana.flutter.5, nidana.flutter.6, nidana.flutter.7]
consumers: [nidana.tooling.codegen.8, nidana.tooling.codegen.9, nidana.tooling.codegen.11, nidana.integration.5, nidana.integration.6, nidana.integration.7, nidana.integration.8]
external_consumers: [Flutter app bootstrap code, Flutter app pages and widgets, Flutter app widget tests]
phase_ids: final
---

# Contract: flutter-binding

- **Governed by:** [ADR-001, ADR-002, ADR-003]

The Flutter UI runtime adapter (Guide Appendix B.1 layer 6; Spec Appendix A.8): the bus reached through the widget tree, topic-driven widgets that render topology output with no interposed state holder, the page scope with its route-derived publisher, the module scope bound to a Navigator's routes, the Flutter navigation executor over Flutter's own Navigator, shutdown at the end of the coordination domain, and the widget-test bus. Everything here binds runtime and navigation decisions to Flutter lifecycles; none of it decides delivery, ownership, scope lifetime, grace or intent semantics, which bus-api@v1 and navigation-api@v1 own.

## Boundary

| Declaration group | Contract |
|-------------------|----------|
| `BusProvider`, `StateTopicBuilder`, `ReplayTopicBuilder`, `PageScope`, `ModuleRoutes`, `ModuleScopeObserver`, `NavigationRouteBuilder`, `FlutterNavigationRouter`, `FlutterNavigationExecutor`; when each binding acquires and releases what | flutter-binding@v1, main library |
| `WidgetTestBus` | flutter-binding@v1, `testing.dart` |
| `Bus`, publishers, writers, `observe`, `getCurrentValue`, `getBufferedValues`, activation, `ModuleScope`, `ModuleReference`, reference counting and the grace timer, shutdown | bus-api@v1 |
| `EnvelopeRecorder`, `TestBus`, the virtual scheduler | bus-testing@v1 |
| `NavigationRouter`, `NavigationExecutor`, `planNavigation`, the intents, `RouteState`, `NavigationEntry`, `RouteConfirmation`, the navigation topics, `navResolver`, the executor suite | navigation-api@v1 |
| `Topic` and its variants, `PageSource`, `ExecutorSource`, `ServiceSource`, `Scope` | topic-model@v1 |
| `Topology`, `topology(...)` | topology-dsl@v1 |
| `ShellClaim`, `TopologyGraph` | topology-ir@v1 |
| the app's routes, pages, route-to-page mapping, auth state and `WidgetsApp` or `MaterialApp` | application code |

- **Refinement 1. Router target (decides OQ-F1).** The executor and the module binding target Flutter's own `Navigator`, through its imperative API (`push`, `pushReplacement`, `pop`, `popUntil`) and `NavigatorObserver`, hosted by the app's `WidgetsApp` or `MaterialApp`; the adapter depends on no router package (ADR-002 item 3). `docs/auto-run/experiments/flutter-binding-fixtures/` settles the runtime facts. Navigator calls reach its observers synchronously, before the call returns, and `pushReplacement` reports `didReplace` (P2). go_router 18.1.0, the router Guide §3.4 shows, resolves on the pinned SDK but: a `push` reaches the Navigator only after a frame (R2); it has no pop-until (R3); it navigates to the platform's initial route by itself, before any bus guard could see it (R4); its `go` turns `[/, /a]` into `[/, /b]` by its route tree, where navigation-api@v1 Refinement 7 has `GoTo` push (R5); and since 18.0.0 it depends on `material_ui`, `cupertino_ui`, `flutter_localizations` and `intl` (R1), which a widgets-only adapter would then carry. An app on go_router, or on any `Router`-based setup, implements navigation-api@v1's `NavigationRouter` itself, the one interface of that contract an implementation outside it implements, and constructs `NavigationExecutor` over it; `ModuleScopeObserver` works on any Navigator whose routes carry names.
- **Refinement 2. The router works before a Navigator exists.** `runApp` attaches the root widget from a `Timer`, so microtasks queued before or by it run while no Navigator exists (P1). Those are where a production-provider bus delivers what `start()`'s queue causes: the nav-resolver's publish for a deep link queued before `start()` is reentrant and is delivered from a provider-zone microtask (bus-api@v1 G14, G22, G34), and the executor performs it at once. `NavigationExecutor` also reads `router.stack` when it is constructed (navigation-api@v1 G19). The router therefore keeps its stack itself: while no Navigator hosts it, a perform changes that stack and confirms at once, and the Navigator that starts hosting it begins with one route per entry (G12). Guide §3.5's bootstrap runs unchanged: activate the resolver, construct the executor, `start()`, then `runApp`.
- **Refinement 3. Module scope by stack membership.** Spec §7.3 binds module scope to route events and a prefix match, and is silent on a stacked navigator, where a route can be covered without being left. Flutter keeps covered routes mounted (P3), so their pages' `PAGE` topologies stay active, and Spec §7.2 requires a state topic's owner to live at least as long as its readers. Each route on the observed Navigator whose path matches a module therefore holds one reference from its push until its pop or removal, covered or not (G10). The reference is released at the pop, while the route's exit transition may still run; Spec §7.3's grace period covers that, and a module with a longer transition raises its grace period.
- **Refinement 4. Page topologies are held per id.** Activation is idempotent on the topology id and returns one handle (Spec §3.9, bus-api@v1 G23), and deactivating that handle ends the topology for every holder (bus-api@v1 G25). Two mounted pages that name one topology id, such as one route pushed twice, would lose it at the first unmount, the hazard Spec §7.3 describes for React StrictMode on module scope. `PageScope` counts the mounted scopes that name each topology id on each bus and deactivates a topology when the last of them unmounts (G8).
- **Refinement 5. No interposed state holder.** A topic widget keeps no copy of the value (Rationale §5.1, §5.2): every build reads `getCurrentValue` or `getBufferedValues`, the synchronous read Guide §7.2's `useTopic` takes through `useSyncExternalStore`, and the observed subscription only marks the widget for rebuild. Its first values, which bus-api@v1 G17 delivers one microtask after `listen` as what was current then, mark nothing, so the first frame is never rendered twice (G5, G6).
- **Refinement 6. The coordination domain ends with the widget that owns the bus.** Spec §11.2 requires shutdown at the end of the coordination domain and lists triggers per platform, with no Flutter row. Flutter has no reliable process-end callback, and `AppLifecycleState.detached` is entered whenever every view has detached while the engine runs on, so a cached engine can attach a view again and find a bus that cannot restart. The bus is therefore shut down by the owning `BusProvider` when it is disposed, after every widget below it (G4): the end of a test body, a view or scene that closes, an add-to-app view that is torn down. ADR-003 item 7's widget-test shutdown is the same rule.
- **Refinement 7. Platform routes become intents.** With a Navigator-based `WidgetsApp`, a route the platform pushes is pushed by name through `onGenerateRoute`, over the router and past the guard (P5). `FlutterNavigationExecutor` instead publishes the platform's initial route and every route it pushes to `nav.intent` as a `DeepLink`, which is Guide §3.5's capture of OS deep links. A `WidgetsBindingObserver` answers the platform's push first only when it is registered before the `WidgetsApp` mounts (P5, P5b), which Guide §3.5's order, executor before `start()` and `start()` before `runApp`, already gives.

Not here: integration with Flutter's `Router` widget and web URL synchronization; an executor per nested Navigator (one executor per coordination domain, over the app's root Navigator); an event-topic listener widget; a `BuildContext` extension for the bus; adapter dev-mode diagnostics; restoration of the router's routes through Flutter's state restoration.

## Interface

**Libraries:** `package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart`, the main library of `nidana_dart_runtime_flutter` at `packages/nidana_dart_runtime_flutter/` (ADR-002 item 3), carries every declaration below except `WidgetTestBus`; `package:nidana_dart_runtime_flutter/testing.dart`, a second public library named by this contract, carries `WidgetTestBus` and nothing else. Neither re-exports anything of Flutter, `nidana_dart_contracts`, `nidana_dart_runtime` or `nidana_dart_navigation`; app code imports those itself. From Flutter, the main library imports only its `widgets`, `foundation` and `services` libraries, never `material` or `cupertino`; `testing.dart` imports `package:nidana_dart_runtime/testing.dart` for `EnvelopeRecorder`; neither imports `package:test` or `package:flutter_test` (G18). **Code owner:** nidana.flutter, which lands every declaration below in its first phase, nidana.flutter.1 (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/fixture/flutter-binding/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.flutter.1 lands every declaration of both libraries; a consumer's `contract` edge waits on it (nidana.tooling: nidana.tooling.codegen's claim-site tests and workspace scan cases, which resolve this package, from nidana.tooling.codegen.8 on), and a `hard` edge waits on nidana.flutter.7, the last producing phase (nidana.integration). Until the phase that delivers it merges, a body that computes throws `UnimplementedError`; from nidana.flutter.1 on, the const constructors assign their fields, `ownsBus` is true for the unnamed constructor only, `PageScope` and `ModuleRoutes` copy their collection arguments into unmodifiable collections, and `WidgetTestBus.testSource` is complete. A behavior guarantee is delivered by the phase whose gate first replays it: nidana.flutter.2 delivers G9 (`ModuleRoutes`); nidana.flutter.3 G11 to G13 (`FlutterNavigationRouter`); nidana.flutter.4 G3 to G6 (`BusProvider` and the topic widgets); nidana.flutter.5 G7 and G8 (`PageScope`); nidana.flutter.6 G10 and G17 (`ModuleScopeObserver` and `WidgetTestBus`); nidana.flutter.7 G14 to G16 (`FlutterNavigationExecutor`, platform routes and the bootstrap), and replays both bindings unrestricted under `testWidgets`, `flutter_navigation_executor_test.dart` among them, which runs navigation-api@v1's executor suite (its G18 to G24) against `FlutterNavigationExecutor`. nidana.flutter.2 and .3 construct no bus and can merge before nidana.runtime.14, beside nidana.flutter.4; nidana.flutter.5 and .6 run side by side. Each gate replays only the guarantees delivered within its own dependency closure, so a consumer that needs both `PageScope` and `ModuleScopeObserver` waits on both nidana.flutter.5 and .6, or on nidana.flutter.7. G1, G2 and the type-level halves of G3, G5, G6, G7 and G17 hold from nidana.flutter.1 (the `surface` and `reject` sets); G18 and G19 hold at every phase, checked by `packages/nidana_dart_runtime_flutter/test/package_properties_test.dart` (nidana.flutter D5).

The declarations are the schema of this contract (ADR-001 item 4). Bodies are omitted; the comments, the terms and the guarantees state the semantics. Every class is final.

### Terms

- **Mount** and **unmount** are a widget's `State` being inserted into the tree and disposed. **A frame** is one pump of the widget tree.
- **The observed Navigator** of a `NavigatorObserver` is the Navigator whose `observers` list holds it.
- **A router route** is a route a `FlutterNavigationRouter` built for one of its entries. **A foreign route** is any other route on the Navigator that hosts the router: a dialog, a sheet, a route the app pushed itself.
- **Hosted:** a Navigator hosts a router from the call of its `initialRoutes` until that Navigator unmounts; while one does, the router's routes are on it.
- **The path of a route** is `ModuleScopeObserver.pathOf(route)`.

### The bus in the tree

```dart
/// The bus of a widget subtree, reached by explicit reference (Spec §3.1;
/// Guide §6.4). No static member yields a bus without a BuildContext (G3).
final class BusProvider extends StatefulWidget {
  /// Provides [bus] and owns it: shuts it down when disposed (G4).
  const BusProvider({Key? key, required Bus bus, required Widget child});

  /// Provides [bus] without owning it.
  const BusProvider.value({Key? key, required Bus bus, required Widget child});

  Bus get bus;
  Widget get child;
  bool get ownsBus;

  /// The bus of the nearest enclosing BusProvider; registers a dependency.
  /// FlutterError when there is none.
  static Bus of(BuildContext context);

  /// Like [of], null when there is none.
  static Bus? maybeOf(BuildContext context);
}
```

### Topic widgets

```dart
/// Renders a state topic (Spec §2.5; Rationale §5.1): every build renders
/// builder(context, bus.getCurrentValue(topic)) (G5).
final class StateTopicBuilder<T> extends StatefulWidget {
  const StateTopicBuilder({
    Key? key,
    required StateTopic<T> topic,
    required Widget Function(BuildContext context, T value) builder,
  });
  StateTopic<T> get topic;
  Widget Function(BuildContext context, T value) get builder;
}

/// Renders a replay topic: every build renders
/// builder(context, bus.getBufferedValues(topic)) (G6).
final class ReplayTopicBuilder<T> extends StatefulWidget {
  const ReplayTopicBuilder({
    Key? key,
    required ReplayTopic<T> topic,
    required Widget Function(BuildContext context, List<T> values) builder,
  });
  ReplayTopic<T> get topic;
  Widget Function(BuildContext context, List<T> values) get builder;
}
```

The bus is the one `BusProvider.of(context)` gives.

### Page scope

```dart
/// A page's scope (Spec §7.1, §7.2) and its publisher (Spec §2.4): activates
/// [topologies] at mount, deactivates them at unmount (G8), and owns one
/// publisher of PageSource(route) bound to Scope.page (G7). Binds once, at
/// mount, to the bus then provided; a rebuild with other arguments, or a
/// change of the provided bus, keeps that binding (G8).
final class PageScope extends StatefulWidget {
  /// ArgumentError when a topology's scope is not Scope.page. Copies both
  /// collections.
  PageScope({
    Key? key,
    String? route,                     // null: derived from the enclosing route (G7)
    List<Topology> topologies = const <Topology>[],
    Set<StateTopic<Object?>> writes = const <StateTopic<Object?>>{},
    required Widget child,
  });
  String? get route;
  List<Topology> get topologies;       // unmodifiable
  Set<StateTopic<Object?>> get writes; // unmodifiable
  Widget get child;

  /// The publisher of the nearest enclosing PageScope. StateError when
  /// there is none.
  static Publisher publisherOf(BuildContext context);
}
```

### Module scope

```dart
/// One module's route subtree (Spec §7.3). Immutable.
final class ModuleRoutes {
  /// ArgumentError when [prefix] has no segment. Copies [topologies].
  ModuleRoutes({
    required String moduleId,
    required String prefix,            // segments separated by '/', such as 'checkout'
    required List<Topology> topologies,
    Duration? gracePeriod,             // null: bus-api@v1's default
  });
  String get moduleId;
  String get prefix;
  List<Topology> get topologies;       // unmodifiable
  Duration? get gracePeriod;

  /// Whether [path]'s segments begin with the prefix's segments; segments
  /// split at '/', empty ones ignored (G9).
  bool matches(String path);
}

/// Module scopes bound to the routes of the Navigator it observes (Spec
/// §7.3; Refinement 3). Give it to the Navigator's observers, one observer
/// per Navigator.
final class ModuleScopeObserver extends NavigatorObserver {
  /// Declares each module with bus.module(moduleId, topologies,
  /// gracePeriod: gracePeriod), rethrowing what bus-api@v1 G27 and G36 throw.
  ModuleScopeObserver(Bus bus, List<ModuleRoutes> modules);

  Bus get bus;
  List<ModuleScope> get scopes;        // one per module, in order; unmodifiable
  bool get isDisposed;

  /// Releases every reference it holds and stops acquiring; idempotent. For
  /// a Navigator removed for good, which reports no pop of its routes.
  void dispose();

  /// The entry's route path for a router route, else route.settings.name,
  /// else null.
  static String? pathOf(Route<dynamic> route);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute});
}
```

### Navigation

```dart
/// The app's mapping from an entry to the Flutter route that presents it;
/// the route must carry [settings] as its settings (G13).
typedef NavigationRouteBuilder = Route<dynamic> Function(
    NavigationEntry entry, RouteSettings settings);

/// navigation-api@v1's NavigationRouter over a Flutter Navigator (decides
/// OQ-F1; Refinements 1, 2). Give navigatorKey, observer, initialRoutes and
/// generateRoute to the app's WidgetsApp or MaterialApp.
final class FlutterNavigationRouter implements NavigationRouter {
  FlutterNavigationRouter(RouteState initial, {required NavigationRouteBuilder routeBuilder});

  // ---- NavigationRouter (navigation-api@v1 G18)
  @override
  List<NavigationEntry> get stack;               // starts [NavigationEntry(initial)]
  @override
  bool get supportsPopUntil;                     // true
  @override
  void perform(List<RouterCall> calls, ResolvedNavIntent intent);
  @override
  Stream<RouteConfirmation> get confirmations;   // broadcast, synchronous

  // ---- the Navigator it drives
  NavigationRouteBuilder get routeBuilder;
  GlobalKey<NavigatorState> get navigatorKey;    // WidgetsApp.navigatorKey
  NavigatorObserver get observer;                // one of WidgetsApp.navigatorObservers
  bool get isHosted;

  /// WidgetsApp.onGenerateInitialRoutes: one new router route per entry,
  /// bottom first; [initialRoute] is ignored (G12).
  List<Route<dynamic>> initialRoutes(String initialRoute);

  /// WidgetsApp.onGenerateRoute: null for every settings; the router builds
  /// no route by name.
  Route<dynamic>? generateRoute(RouteSettings settings);
}

/// The Flutter navigation executor (Spec Appendix A.8; Guide §3.4): a
/// FlutterNavigationRouter and navigation-api@v1's NavigationExecutor over
/// it (navigation-api@v1 Refinement 6), with platform routes forwarded as
/// deep links (Refinement 7). Construct it before start() and before the
/// app's WidgetsApp mounts (Guide §3.5).
final class FlutterNavigationExecutor {
  /// Constructs the router over [initial], then NavigationExecutor(bus,
  /// router, name: name), whose throws it rethrows, claiming and registering
  /// nothing (G14); then, when [forwardPlatformRoutes], the forwarding of G15;
  /// registers dispose with bus.onShutdown.
  FlutterNavigationExecutor(
    Bus bus, {
    required RouteState initial,
    required NavigationRouteBuilder routeBuilder,
    String name = 'flutter-navigation',          // ExecutorSource('flutter-navigation'), Spec §2.4
    bool forwardPlatformRoutes = true,
  });

  Bus get bus;
  FlutterNavigationRouter get router;
  NavigationExecutor get executor;
  bool get isDisposed;
  void dispose();                                // idempotent (G14)
}
```

The router keeps its stack itself and applies each perform to the Navigator in the same call. Removing or replacing a router route other than through `perform`, or popping the root entry's route from app code, is outside this contract: the router does not observe it, and its stack no longer describes the Navigator.

### The widget-test library

Library `package:nidana_dart_runtime_flutter/testing.dart`. It imports neither `package:test` nor `package:flutter_test` (ADR-002 item 4), so it takes no `WidgetTester`: the test pumps what `wrap` returns.

```dart
/// The bus of one widget test (ADR-003 item 7; bus-testing@v1 "How a test
/// uses it"). Construct it inside the testWidgets body.
final class WidgetTestBus {
  /// Bus(config) on the production provider, in the current zone, with an
  /// EnvelopeRecorder attached before this returns. ArgumentError when
  /// config names a VirtualSchedulerProvider.
  WidgetTestBus([BusConfig config = const BusConfig()]);

  /// ServiceSource('test'), the source of TestBus.testSource too.
  static const ServiceSource testSource;

  Bus get bus;
  EnvelopeRecorder get recorder;

  /// A publisher of testSource with no claims, made on first read.
  Publisher get input;

  /// The writer, at T, of one publisher of testSource claiming [topic] alone
  /// at Scope.application, made on the first call for [topic] at any type
  /// argument; the same writer on every call with the same type argument.
  /// ClaimRejected when the bus rejects the claim (G17).
  StateWriter<T> stub<T>(StateTopic<T> topic);

  /// An owning BusProvider over [child]; pump it as the root, and unmounting
  /// it shuts the bus down.
  Widget wrap(Widget child);
}
```

### How an app uses it

```dart
abstract final class AppRoutes {
  static const NavRoute<void> home = NavRoute<void>('home');
  static const NavRoute<int> order = NavRoute<int>('orders/detail');
  static const NavRoute<void> cart = NavRoute<void>('checkout/cart');
}

Route<dynamic> pages(NavigationEntry entry, RouteSettings settings) => MaterialPageRoute<void>(
      settings: settings,
      fullscreenDialog: entry.modal,
      builder: (BuildContext context) => switch (entry.state.route) {
        AppRoutes.order => OrderPage(id: AppRoutes.order.argsOf(entry.state)!),
        AppRoutes.cart => const CartPage(),
        _ => const HomePage(),
      },
    );

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Guide §3.5: resolver, executor, start(), then the tree.
  final Bus bus = Bus();
  bus.activate(navResolver<AuthState>(/* navigation-api@v1 */));
  final FlutterNavigationExecutor navigation = FlutterNavigationExecutor(
    bus,
    initial: RouteState(route: AppRoutes.home),
    routeBuilder: pages,
  );
  final ModuleScopeObserver modules = ModuleScopeObserver(bus, <ModuleRoutes>[
    ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[checkoutFlow]),
  ]);
  bus.start();
  final FlutterNavigationRouter router = navigation.router;
  runApp(BusProvider(
    bus: bus,
    child: MaterialApp(
      navigatorKey: router.navigatorKey,
      navigatorObservers: <NavigatorObserver>[router.observer, modules],
      onGenerateInitialRoutes: router.initialRoutes,
      onGenerateRoute: router.generateRoute,
    ),
  ));
}

// A page: its scope, its state, its events.
final class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) => PageScope(
        topologies: <Topology>[cartForm],          // PAGE-scoped
        child: StateTopicBuilder<CartView>(
          topic: CheckoutTopics.cart,
          builder: (BuildContext context, CartView cart) => CartList(
            cart: cart,
            onCheckout: () => PageScope.publisherOf(context)
                .publish(NavigationTopics.intent, AppRoutes.order.go(cart.orderId)),
          ),
        ),
      );
}
```

A widget test builds `WidgetTestBus()` in the `testWidgets` body, stubs the state its page reads with `stub`, publishes inputs with `input`, pumps `t.wrap(page)`, calls `t.bus.start()`, drives time with `tester.pump`, and asserts on `t.recorder` and the tree; the owning provider shuts the bus down when the body ends.

## Guarantees / invariants

- **G1** The main library exports exactly `BusProvider`, `StateTopicBuilder`, `ReplayTopicBuilder`, `PageScope`, `ModuleRoutes`, `ModuleScopeObserver`, `NavigationRouteBuilder`, `FlutterNavigationRouter` and `FlutterNavigationExecutor`; `testing.dart` exports exactly `WidgetTestBus`; neither re-exports any declaration of Flutter, `nidana_dart_contracts`, `nidana_dart_runtime`, `nidana_dart_navigation` or the other library.
- **G2** Every class of this contract is final and no type outside the package extends or implements one; `FlutterNavigationRouter` implements navigation-api@v1's `NavigationRouter`, `ModuleScopeObserver` is a `NavigatorObserver`, and the four widgets are `StatefulWidget`s.
- **G3** The bus is reached through the tree (Spec §3.1; Guide §6.4): `BusProvider.of(context)` is the bus of the nearest enclosing `BusProvider` and registers a dependency, so a widget that read it rebuilds when that provider provides another bus, and only then; `maybeOf` is null and `of` throws `FlutterError` where there is no provider; `BusProvider` declares no static member that yields a bus without a `BuildContext`.
- **G4** Shutdown at the end of the coordination domain (Spec §11.2; Refinement 6): a `BusProvider` made with the unnamed constructor owns its bus (`ownsBus`) and shuts it down when it is disposed, after every widget below it has been disposed, so the scope bindings below release what they hold first (ADR-003 item 7); rebuilt with another bus, it shuts the previous bus down and provides the new one; a `BusProvider.value` never shuts its bus down.
- **G5** State topic widget (Spec §2.5; Rationale §5.1; Refinement 5): `StateTopicBuilder` takes a `StateTopic<T>` only and its builder a `T`; every build renders `builder(context, bus.getCurrentValue(topic))`, so the first frame needs no delivery; at mount it subscribes through a widened reference, `bus.observe<Object?>(topic)`, so its subscription receives every delivery whatever its type and no conversion of it can fail; its subscription's first value, the value current when it listened (bus-api@v1 G17), causes no rebuild; each later value its subscription receives marks it for rebuild, so the next frame renders the current value once, however many values arrived; a change of `topic`, or of the bus its provider provides, cancels the subscription and subscribes anew under the same first-value rule; unmount cancels the subscription without waiting on its cancel future; an error on the subscription, such as `TopicRemoved` (bus-api@v1 G9), is not rethrown and ends the rebuilds; a value that is not of type `T`, which only a widened reference can put into the topic (bus-api@v1 G41), counts among the subscription's first values or marks the widget for rebuild like any other, and nothing reaches the provider zone's uncaught-error handler; the build's `getCurrentValue` then throws the `TypeError` of bus-api@v1 G8 and G41, which Flutter reports as an error during build, and the next delivery of a value of type `T` rebuilds the widget and renders it; it holds no copy of the value.
- **G6** Replay topic widget: `ReplayTopicBuilder` takes a `ReplayTopic<T>` only and its builder a `List<T>`; it meets G5 with `bus.getBufferedValues(topic)` in place of `getCurrentValue`, and its subscription's first values, the buffer when it listened, cause no rebuild; while the buffer holds a value that is not of type `T`, every build throws G5's `TypeError`, and the first delivery that leaves no such value in the buffer renders it.
- **G7** Page publisher (Spec §2.4, §7.2): at mount a `PageScope` constructs `bus.publisher(PageSource(route), writes: writes, scope: Scope.page)`, rethrowing `ClaimRejected` (bus-api@v1 G20), where `route` is the given route, else the path of the enclosing `ModalRoute`'s entry when it is a router route, else that route's `settings.name` without its leading `/`, except that a name of `/` alone, Flutter's default route name and the name `WidgetsApp` gives its home route, gives the route `/`, because topic-model@v1 asserts a non-empty `PageSource` route; an empty or absent name counts as none, and with none of these, mounting throws `StateError`; `writes` takes state topics only; `PageScope.publisherOf(context)` is the publisher of the nearest enclosing `PageScope` and throws `StateError` where there is none; unmount disposes the publisher, releasing its claims.
- **G8** Page scope (Spec §7.1, §7.2, §3.9; Refinement 4): constructing a `PageScope` with a topology whose scope is not `Scope.page` throws `ArgumentError`, and both collections are unmodifiable copies; at mount it activates its topologies in order, then constructs its publisher; at unmount it disposes the publisher, then releases its topologies in reverse order; on each bus a topology id named by several mounted `PageScope`s is activated by the first to mount and deactivated when the last of them unmounts; a mount whose activation or claim throws releases what that mount acquired and rethrows; a `PageScope` binds once, at mount: a rebuild with other arguments keeps that binding, and so does a change of the bus the enclosing `BusProvider` provides (G3, G4), so the scope stays bound to the bus it mounted under, with its topologies and its publisher there, until it unmounts, and does not rebind to the new bus.
- **G9** Module routes: a `ModuleRoutes` whose prefix has no segment throws `ArgumentError`; `matches(path)` holds exactly when the prefix's segments are the first segments of `path`, segments being split at `/` with empty ones ignored, so a leading `/` changes nothing and `checkout` matches `checkout` and `checkout/cart` but not `checkouts` or `shop/checkout`; `topologies` is an unmodifiable copy; the fields are those given.
- **G10** Module scope (Spec §7.3; Refinement 3): constructing a `ModuleScopeObserver` declares each module with `bus.module` and rethrows what that throws; `scopes` are those scopes, in order. Each route on the observed Navigator whose path matches a module holds one reference of it, acquired at `didPush`, the Navigator's initial routes included, and released at `didPop` or `didRemove`; at `didReplace` the new route's references are acquired before the old route's are released; a route that matches several modules holds one reference of each, and one with no path or matching none holds none. An acquire that throws (bus-api@v1 G28) is reported through `FlutterError.reportError`, holds no reference, and leaves the Navigator working. After `dispose`, which releases every reference held and is idempotent, or once the bus is shut down, the observer acquires nothing.
- **G11** Flutter router port (navigation-api@v1 G18): a `FlutterNavigationRouter` meets navigation-api@v1 G18 over a Flutter Navigator, and `supportsPopUntil` is true; its stack starts as `NavigationEntry(initial)`; it reports each confirmation synchronously, before `perform` returns; while hosted, a perform applies `PushRoute` as `push`, `ReplaceRoute` as `pushReplacement`, `PopRoute` as `pop` and `PopUntilRoute` as `popUntil` to the route of the topmost entry of its route, so that when `perform` returns the router routes on the Navigator are those of the stack's entries, in order; a perform validates every call and builds every route before it touches the Navigator, so one that throws leaves the Navigator, the stack and the confirmations untouched.
- **G12** Hosting (Refinement 2; Guide §3.5): while no Navigator hosts the router, a perform changes its stack alone and confirms at once; `initialRoutes(name)` returns one new router route per entry of the current stack, bottom first, whatever `name` is; a Navigator that unmounts leaves the stack as it was, and the next Navigator that hosts the router starts from it with new routes; `generateRoute` returns null for every settings.
- **G13** Router routes (Refinement 1): the route of an entry is `routeBuilder(entry, settings)` with `settings` named `/` plus the entry's route path and carrying the entry as its arguments, and a builder that returns a route with other settings makes the perform or `initialRoutes` throw `ArgumentError`; a foreign route is not an entry, so its push and its pop change and confirm nothing, and a perform first pops the foreign routes above the top entry's route; a pop of the top entry's route that no perform made, such as the platform's back reaching the Navigator through `WidgetsApp` or a page's own `Navigator.maybePop`, is confirmed as `const Back()` (navigation-api@v1 G18), and a pop that the route refuses, such as a `PopScope` with `canPop` false, is not a pop.
- **G14** Flutter executor (Spec Appendix A.8; Guide §3.4): `FlutterNavigationExecutor(bus, ...)` constructs a `FlutterNavigationRouter` over `initial` and a `NavigationExecutor` over it named `name`, `flutter-navigation` unless given, so its source renders `executor:flutter-navigation` (Spec §2.4) and navigation-api@v1 G19 to G24 hold of it; a construction that throws claims nothing, publishes nothing and registers nothing; it registers its `dispose` with `bus.onShutdown`; `dispose` is idempotent, disposes the `NavigationExecutor` and stops the forwarding of G15.
- **G15** Platform routes (Guide §3.5; Refinement 7): when `forwardPlatformRoutes` is true, the construction publishes the platform's initial route, when it is not `/`, to `nav.intent` as `DeepLink(Uri.parse(route))` through a publisher of `ExecutorSource(name)` that claims nothing, queued when the bus has not started (bus-api@v1 G34); until disposed, each route the platform pushes is published the same way and answered as handled, so no route is pushed on the Navigator by name, provided the executor was constructed before the app's `WidgetsApp` mounted; when it is false, neither happens.
- **G16** The bootstrap (Guide §3.5; Spec §3.13): with the nav-resolver activated and a `FlutterNavigationExecutor` constructed before `start()`, and `start()` called before any Navigator mounts, a deep link queued before `start()`, the platform's initial route included, is resolved, guarded and performed before any Navigator exists, and the first frame of the Navigator that then hosts the router shows its route above the initial route, with the module scopes their paths match acquired.
- **G17** Widget-test bus (ADR-003 item 7; bus-testing@v1): `WidgetTestBus(config)` constructs `Bus(config)` on the production provider in the current zone, so inside a `testWidgets` body `tester.pump` drives its clock and timers, and throws `ArgumentError` for a `VirtualSchedulerProvider`; it exposes no virtual scheduler and no settle operation; `recorder` is attached before the constructor returns, so it records every delivery of the bus, `start()`'s queue included; `input` is one publisher of `ServiceSource('test')` with no claims, made on first read; `stub(topic)` is the writer, at the call's type argument, of one publisher of `ServiceSource('test')` that claims `topic` alone at `Scope.application`, made on the first call for `topic` at any type argument, and the same writer on every later call with the same type argument (bus-api@v1 G20, G41); a claim that bus-api@v1 G20 rejects throws `ClaimRejected` and claims nothing, as bus-testing@v1 G18 states for `TestBus.stub`; `wrap(child)` is an owning `BusProvider` (G4), so unmounting it shuts the bus down and no bus timer is pending when the body ends.
- **G18** `nidana_dart_runtime_flutter` depends on Flutter (SDK), `nidana_dart_contracts`, `nidana_dart_runtime`, `nidana_dart_navigation` and `meta` only, so no router package (decides OQ-F1); from Flutter, the main library imports only its `widgets`, `foundation` and `services` libraries, never `material` or `cupertino`; neither public library imports `package:test` or `package:flutter_test` (ADR-002 items 3 and 4).
- **G19** `nidana_dart_runtime_flutter` creates no timer or microtask and reads no wall clock: what it schedules is the bus's, in the provider zone, and Flutter's frames; the only time it reads is the bus clock, through `NavigationExecutor` (ADR-003 item 8).

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates.
- Breaking for this contract: removing, renaming or retyping any declaration; making a class non-final; changing what a widget renders or when it rebuilds, when a binding acquires or releases, the page source derivation, the prefix rule, which routes are entries, what a perform does to the Navigator, the hosting rule, the settings of a router route, the default executor name, the platform route forwarding or its default, what `WidgetTestBus` constructs or with which source, which `BusProvider` shuts its bus down, or which operation throws what.
- Compatible: a new optional named parameter with a default that keeps current behavior; a new getter or method on a final class; a new widget or helper; a new guarantee that existing fixtures still pass.
- Not in v1, each a candidate for a later version: integration with Flutter's `Router` widget and web URL synchronization; an executor over a nested Navigator; an event-topic listener widget; a `BuildContext` extension for the bus; page publishers that claim at module scope; adapter dev-mode diagnostics, such as one for a route the app removed from under the router; restoration of the router's routes; a go_router `NavigationRouter` in a separate package.
- Amended within v1, from nidana.flutter's phase plan (its D7, D8, D10 and D11), drained by hsdd-reconcile on 2026-10-18: (a) G5 and G6: a topic widget subscribes through a widened reference, so a value that is not of the topic's value type, which only a widened reference can publish (bus-api@v1 G41), reaches no provider-zone handler, fails the build with `TypeError`, which Flutter reports, and the next delivery of a value of the topic's type renders again; (b) G7: a route named `/` alone gives the page route `/`, and an empty or absent name counts as none; (c) G8 and the comment on `PageScope`: a `PageScope` keeps its binding when the provided bus changes; (d) G17 and the comment on `WidgetTestBus.stub`: one publisher per topic and its writer per type argument, where the earlier wording promised one writer for every call, and `ClaimRejected` for a claim the bus rejects; (e) the Interface's code-owner sentence names nidana.flutter.1, and the Delivery paragraph states which phase delivers which guarantee. Compatible: nothing changes for a value of the topic's type, and G5 and G6 stated no behavior for another, for which bus-api@v1 G41 as amended has `getCurrentValue` and `getBufferedValues` throw; the rule as written gave a route named `/` the empty route, which `PageSource` rejects, so no conforming outcome existed for it; "binds once" already read as (c); `stub` changes only for one topic stubbed at two type arguments, where the earlier wording could not hold, because a writer cached at one type argument fails the cast to another, and one publisher per topic keeps the one claim bus-api@v1 G20 allows, as bus-testing@v1 G18 now states for `TestBus.stub`; no fixture of any contract published an off-type value to a topic widget, mounted a `PageScope` under a route named `/`, changed the provided bus under a mounted `PageScope`, or stubbed one topic at two type arguments. One new case each covers G5's and G6's off-type rule, (b), (c) and (d), and every case from before the amendment passes against a stand-in that meets it (`docs/auto-run/experiments/flutter-reconcile-amends/`). The Breaking list above stands; a later change to any of these rules is breaking.

## Validation

- fixture: `hsdd/contract/fixture/flutter-binding/`, under `hsdd/contract/fixture/analysis_options.yaml` (ADR-001 item 2); replayed with `fvm dart run nidana_contract_check flutter-binding`.
- surface: `hsdd/contract/fixture/flutter-binding/surface/` (`binding.dart`, `navigation.dart`, `testing.dart`) uses every declaration with the types the Interface states: both provider constructors, both topic widgets and a page scope with topologies and writes in an app's page, the router assigned to `NavigationRouter`, its `initialRoutes` and `generateRoute` assigned to Flutter's `InitialRouteListFactory` and `RouteFactory`, Guide §3.5's bootstrap wired into a `WidgetsApp`, the module observer assigned to `NavigatorObserver`, and the widget-test bus as a test body uses it.
- reject: `hsdd/contract/fixture/flutter-binding/reject/`, one library per type-level guarantee: `adapter_exports_only_its_own.dart` and `testing_exports_only_its_own.dart` (G1), `binding_types_are_closed.dart` (G2), `no_global_bus_accessor.dart` (G3), `topic_builders_are_typed.dart` (G5, G6), `page_writes_are_state_topics.dart` (G7), `widget_test_bus_has_no_virtual_time.dart` (G17).
- behavior: conformance library `hsdd/contract/fixture/flutter-binding/behavior/flutter_binding_conformance.dart`, harness `FlutterBindingHarness`, cases `flutterBindingConformance`, covering G3 to G17. The harness names no `flutter_test` type: a binding supplies production-provider buses built in the test body (`bus`), the widget tester's `pumpWidget`, `pump` and `pumpAndSettle`, the platform's back and route push as navigation channel messages (`platformBack`, `platformPushRoute`), the platform's initial route (`setPlatformInitialRoute`) and the caught exception (`takeException`). The cases observe the tree through their own widgets and `NavigatorObserver`s, never through finders, and drive time only through `pump`, so the suite binds under `testWidgets` only.
- binding: `hsdd/contract/fixture/flutter-binding/behavior/nidana_dart_runtime_flutter_test.dart` binds this contract's suite to the producer's `nidana_dart_runtime_flutter`, under `testWidgets`; it shuts every bus the harness built down, unmounts the tree and resets the platform's initial route before each body ends (ADR-003 item 7). It must pass every case of `flutterBindingConformance`.
- binding: `hsdd/contract/fixture/flutter-binding/behavior/flutter_navigation_executor_test.dart` binds navigation-api@v1's executor suite (`../../navigation-api/behavior/navigation_executor_conformance.dart`, harness `NavigationExecutorHarness` with `NavigationRun`, cases `navigationExecutorConformance`) to `FlutterNavigationExecutor`, under `testWidgets` (ADR-001 item 4; navigation-api@v1 Validation). `bus` constructs `Bus(config)` in the test body; `executor` constructs a `FlutterNavigationExecutor` named as asked and then pumps a `WidgetsApp` hosting its router, as an app's bootstrap constructs it before anything mounts (G12), and returns its `executor` and `router`; `platformBack` sends the navigation channel's `popRoute` message, which reaches the Navigator through `WidgetsApp`, then `pumpAndSettle`; `elapse` is `tester.pump(duration)`; `settle` is `tester.pumpAndSettle()`; every bus is shut down and the tree unmounted before the body ends. It must pass every case of `navigationExecutorConformance`, which covers navigation-api@v1 G18 to G24 for this executor and G11's first clause here.
- Both bindings import `package:flutter_test`, so the replay tool runs them under `flutter test --no-pub` from the workspace root (ADR-001 item 9). Their package imports name the implementation, so the replay tool reports them as `PENDING` until `nidana_dart_runtime_flutter` exists. They run in nidana.flutter's gates; nidana.integration's gate runs them with `--all`.
- type-level guarantees G1 and G2 and the type-level halves of G3, G5, G6, G7 and G17 are checked by the reject and surface sets.
- not executable: G18, a property of the package's pubspec and imports; checked by nidana.flutter's gates
- not executable: G19, a property of the package's sources rather than of its declarations; checked by nidana.flutter's gates
- No schema: an `api` contract with no serialized form carries none (ADR-001 item 4).
- The fixtures are forward references, written before the package exists. In `docs/auto-run/experiments/flutter-binding-fixtures/` (`run.sh`, `output.txt`) a stand-in `nidana_dart_runtime_flutter` implements this Interface on the stand-in runtime and navigation packages of `docs/auto-run/experiments/bus-api-amendment/`, in a pure-Dart workspace root with the fixtures under `hsdd/`, as ADR-001 item 9 lays it out. The probes P1 to P8 settle the Navigator facts and R1 to R5 the go_router facts Refinement 1 cites. Structure passed for this contract (19 guarantees, 52 cases, 2 bindings); the surface set analyzed clean; every reject code of the 7 reject libraries was confirmed against the stand-in; both bindings ran under `fvm flutter test --no-pub` from the workspace root, this suite passing 52 of 52 cases and navigation-api@v1's executor suite 26 of 26; the name prefix `G10 ` selected that guarantee's 8 cases; and each of 33 seeded defects in the stand-in failed the cases of the guarantee it breaks. The experiment's first suite run also showed that a module acquire thrown from a `NavigatorObserver` callback leaves the Navigator locked, which is why G10 reports it instead. The first replay against the real package, once nidana.model's first phase lands the replay tool, is their first verification (ADR-001 Consequences).
- The v1 amendment (`## Versioning`) is checked in `docs/auto-run/experiments/flutter-reconcile-amends/` (`run.sh`, `output.txt`), on the stand-in packages of `docs/auto-run/experiments/flutter-phase-facts/` (a runtime that meets bus-api@v1 G41 and bus-testing@v1 G18 as amended) with the adapter patched so that the topic widgets observe at `Object?`, a route named `/` gives the page route `/`, and `stub` keeps one publisher per topic. Structure passed (19 guarantees, 57 cases, 2 bindings). On the patched stand-in this suite passed 57 of 57 cases and navigation-api@v1's executor suite 26 of 26, and the fixtures from before the amendment passed 52 of 52 and 26 of 26; on the unpatched stand-in the new G5, G6, G7 and G17 cases fail and every other case passes; a seeded `PageScope` that rebinds when the provided bus changes fails the new G8 case and no other. The G5 and G6 cases build their bus in an error zone of their own, so an error reaching the provider zone fails them by assertion.
