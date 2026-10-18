---
id: bus-api
version: v1
status: stable
kind: api
owner: nidana.runtime
compatibility: versioned
produced_by: [nidana.runtime.1, nidana.runtime.5, nidana.runtime.6, nidana.runtime.7, nidana.runtime.8, nidana.runtime.11, nidana.runtime.12, nidana.runtime.13, nidana.runtime.14]
consumers: [nidana.navigation.1, nidana.navigation.6, nidana.flutter.1, nidana.flutter.4, nidana.flutter.5, nidana.flutter.6, nidana.flutter.7, nidana.tooling.lint.1, nidana.tooling.lint.2, nidana.tooling.lint.3, nidana.tooling.lint.4, nidana.tooling.codegen.8, nidana.tooling.codegen.9, nidana.tooling.codegen.11, nidana.integration.3, nidana.integration.4, nidana.integration.5, nidana.integration.6, nidana.integration.7, nidana.integration.8]
external_consumers: [app bootstrap code, app services and executors, app pages and widgets, app observers]
phase_ids: final
---

# Contract: bus-api

- **Governed by:** [ADR-001, ADR-002, ADR-003]

The bus as shell code reaches it (Spec §3, §7, §9, §10.2, §11): construction and configuration, the topic registry, the publish path, publishers and state writer handles, activation and topology handles, module scopes with reference counting, observers and the SDK-neutral telemetry observer, the startup barrier, shutdown, the live graph, and the dev-mode diagnostics. Activation is also the live implementation of topology-dsl@v1: `Bus.activate` interprets a `TopologyPlan` as that contract's Live interpretation states, and this contract's fixtures bind its live suite.

## Boundary

nidana.runtime produces two contracts from one package. This contract holds the main library; bus-testing@v1 holds `testing.dart`.

| Declaration group | Contract |
|-------------------|----------|
| `Bus`, `BusConfig`, `BusLifecycle`, `SchedulerProvider`, `ProductionSchedulerProvider`, `DiagnosticSink`; the topic registry operations; `Publisher`, `StateWriter`; `TopologyHandle`; `ModuleScope`, `ModuleReference`; `ActivationObserver`, `TelemetryObserver`; the `BusDiagnostic` family with `ShellDiagnostic`; the `BusError` family, `BusLimit`, `TopicRemoved` | bus-api@v1, main library |
| what a bus guarantees whatever its provider: delivery, ordering, reentrancy, dedup, first delivery, observers, ownership, activation, module scopes, the barrier, shutdown | bus-api@v1 |
| `TestBus`, `VirtualScheduler`, `VirtualSchedulerProvider`, the envelope recorder and its assertion API, the settle operation; the virtual scheduler's operations, quiescence, bounds and fixed start instant; whether a TestBus generates deterministic ids; which topologies a test activates (OQ-R2) | bus-testing@v1, `testing.dart` |
| `MessageEnvelope`, `Lineage`, `MessageSource`, `BusObserver`, `ObserveContext`, `ObserverCapability`, the topic variants and `MultiWriterTopic` | topic-model@v1 |
| `Topology`, `TopologyPlan`, the live semantics of each combinator | topology-dsl@v1 |
| `TopologyDefinition`, `TopologyGraph`, `ShellClaim`, the findings and `analyzeTopologyGraph` | topology-ir@v1 |

- **Refinement 1.** The provider family is sealed across the two contracts. `SchedulerProvider` and both its subclasses are declared in one library under `lib/src/`; the main library exports `SchedulerProvider` and `ProductionSchedulerProvider`, and `testing.dart` exports `VirtualSchedulerProvider`, which bus-testing@v1 declares. Likewise `Bus` is final with exactly one subtype, `TestBus`, declared by bus-testing@v1 in the same library. A `TestBus` is a `Bus`, so it satisfies every guarantee here.
- **Refinement 2.** `BusConfig.scheduler` is nullable, null meaning the production provider, so that `TestBus(config)` can tell a config that leaves the provider unset from one that names the production provider, which it rejects (ADR-003 item 6).
- **Refinement 3.** The publisher-less publish and a publisher's publish take `MultiWriterTopic<T>`, topic-model@v1's sealed supertype of `EventTopic<T>` and `ReplayTopic<T>` (its G27), so a publish to a state topic outside a writer handle does not compile (G11, G19). topic-model@v1 owns that declaration. The value has a type parameter of its own, bounded by the topic's, `publish<T extends Object?, V extends T>`, so inference takes `T` from the topic alone and a value of another type does not compile (G40, Spec §4.2), as topology-dsl@v1's `write<T, S extends T>` does for streams. `T`'s bound is written out because it is the type a failed inference falls back to: with `Object?` in place of the implicit `dynamic`, a state topic passed to `publish` reports `argument_type_not_assignable` alone, with no strict-inference warning on the same line (`docs/auto-run/experiments/bus-api-amendment/`, probe P2).
- **Refinement 4.** Observed streams carry payloads, never envelopes. Envelopes reach shell code only through observers (G29) and through the recorders bus-testing@v1 attaches to a bus (Spec §3.5 "Where Envelopes Are Visible").

Not here: the router and widget bindings of module and page scopes (flutter-binding@v1); the navigation executor protocol, which builds on publishers, writers, `observe` and `bus.clock` (navigation-api@v1); a concrete OpenTelemetry binding and persistence (root D1); the static checks that recognize this surface (nidana-checks@v1).

## Interface

**Library:** `package:nidana_dart_runtime/nidana_dart_runtime.dart`, the main library of `nidana_dart_runtime` at `packages/nidana_dart_runtime/` (ADR-002 item 3). It does not re-export `nidana_dart_contracts`; shell code imports both. It imports nothing beyond the SDK, `nidana_dart_contracts`' public libraries (`nidana_dart_contracts.dart`, `topology_plan.dart`, `topology_ir.dart`), `rxdart`, `clock` and `meta`. **Code owner:** nidana.runtime, which lands every declaration below in its first phase, nidana.runtime.1 (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/fixture/bus-api/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.runtime.1 lands every declaration, and bus-testing@v1's with them; a consumer's `contract` edge waits on it (nidana.navigation, nidana.tooling), and a `hard` edge waits on nidana.runtime.14, the last producing phase (nidana.flutter.4 to .7, the phases of nidana.flutter that run a bus; nidana.integration); nidana.flutter.1, which compiles against the declarations and runs no bus, waits on nidana.runtime.1. Until the phase that delivers it merges, a body that computes throws `UnimplementedError`. A behavior guarantee is delivered by the phase whose gate first replays it, which can come after the phase that implements its slice, because most cases publish through a publisher, call `start()` or activate a topology. Cumulatively: nidana.runtime.5 delivers G3; nidana.runtime.7 G4 and G11; nidana.runtime.8 G7, G8, G12, G13, G15, G17 to G19 and G29 to G31; nidana.runtime.11 G1, G10, G20, G21, G24, G32 and G37; nidana.runtime.12 G6, G9, G14, G16, G22, G23, G25, G26, G34 and G41, and topology-dsl@v1's G18 to G29 through `bus_activation_test.dart`; nidana.runtime.13 G33; nidana.runtime.14 G5, G27, G28, G35 and G36, and replays both bindings unrestricted. nidana.runtime.6 lands the registry, the cells and observed streams, whose guarantees replay from nidana.runtime.8 on, once publishers exist to publish through. G2, G40 and the type-level halves of G1, G3, G4, G5, G8, G11, G19 and G20 hold from nidana.runtime.1; G38 and G39 hold at every phase, checked by `packages/nidana_dart_runtime/test/package_properties_test.dart` (nidana.runtime D9).

The declarations are the schema of this contract (ADR-001 item 4). Bodies are omitted; the comments, the delivery rules and the guarantees state the semantics. `Clock` is `package:clock`'s; shell code calls `bus.clock.now()` and `bus.clock.stopwatch()` without importing it.

### Configuration and providers

```dart
/// Where a bus's dev-mode diagnostics go (root D8). Called in the provider
/// zone, guarded: an exception it throws goes to that zone's handler.
typedef DiagnosticSink = void Function(BusDiagnostic diagnostic);

/// The time source of a bus (Spec §3.6; ADR-003 item 1). Sealed, with
/// exactly ProductionSchedulerProvider and bus-testing@v1's
/// VirtualSchedulerProvider (Refinement 1).
sealed class SchedulerProvider {
  const SchedulerProvider();
}

/// The zone current when the bus is constructed, unforked, and
/// package:clock's clock as read then; both captured by the Bus
/// constructor, not by this value.
final class ProductionSchedulerProvider extends SchedulerProvider {
  const ProductionSchedulerProvider();
}

/// A bus's configuration (Spec §3.6, §11.3; root D8). Immutable.
@immutable
final class BusConfig {
  const BusConfig({
    this.scheduler,          // null: the production provider
    this.devMode,            // null: whether assertions are enabled when the bus is constructed
    this.diagnostics,        // null: print each diagnostic's toString()
    this.observeContext,     // null: log prints a line; metric and span discard
    this.maxTopics = 1000,
    this.maxActiveTopologies = 200,
    this.maxObservers = 20,
    this.maxReentrancyDepth = 10,
    this.moduleScopeGracePeriod = const Duration(milliseconds: 100),
    this.startupWindow = const Duration(seconds: 5),
  });

  final SchedulerProvider? scheduler;
  final bool? devMode;
  final DiagnosticSink? diagnostics;
  final ObserveContext? observeContext;   // the sinks observers write to (Spec §3.7)
  final int maxTopics;                    // subjects on this bus (G10)
  final int maxActiveTopologies;          // active topologies (G10)
  final int maxObservers;                 // registered observers (G10)
  final int maxReentrancyDepth;           // reentrant hops before a diagnostic (G15)
  final Duration moduleScopeGracePeriod;  // the default of every module scope (G28)
  final Duration startupWindow;           // dev-mode window before start (G35)
}

enum BusLifecycle { bootstrapping, running, shutDown }
```

### The bus

```dart
/// One bus per coordination domain, reached by explicit reference (Spec
/// §3.1). Final; its one subtype is bus-testing@v1's TestBus.
final class Bus {
  /// Throws ArgumentError when a limit in [config] is below 1 or a duration
  /// is negative. Captures the production provider's zone and clock here.
  Bus([BusConfig config = const BusConfig()]);

  BusConfig get config;
  bool get devMode;                 // G4
  Clock get clock;                  // the provider clock, read-only (ADR-003 item 8)
  BusLifecycle get lifecycle;

  // ---- lifecycle (Spec §3.13, §11.2)
  void start();                     // G34
  void shutdown();                  // G36
  /// Registers shell-side disposal, run by shutdown in reverse order (G36).
  void onShutdown(void Function() callback);

  // ---- topics (Spec §2.4, §2.5, §3.2, §7.5)
  /// The publisher-less path: event and replay topics only (G11), the value
  /// typed by the topic (G40).
  void publish<T extends Object?, V extends T>(MultiWriterTopic<T> topic, V value);
  /// The payloads delivered on [topic] (G16 to G18, G41).
  Stream<T> observe<T>(Topic<T> topic);
  T getCurrentValue<T>(StateTopic<T> topic);          // G8
  List<T> getBufferedValues<T>(ReplayTopic<T> topic); // G8
  /// True when removed or absent; false when refused (G9).
  bool removeTopic(Topic<Object?> topic, {bool force = false});

  // ---- publishers (Spec §2.4, §3.11)
  Publisher publisher(
    MessageSource source, {
    Set<StateTopic<Object?>> writes = const <StateTopic<Object?>>{},
    Scope scope = Scope.application,
  });

  // ---- topologies (Spec §3.8, §3.9, §6.5, §7.1 to §7.3)
  TopologyHandle activate(Topology topology);
  ModuleScope module(String moduleId, List<Topology> topologies, {Duration? gracePeriod});
  TopologyGraph toGraph();          // G37

  // ---- observers (Spec §3.7, §9)
  void addObserver(BusObserver observer);
  bool removeObserver(BusObserver observer);

  // ---- diagnostics (root D8)
  /// Delivers [diagnostic] to the sink in dev mode; does nothing otherwise.
  void reportDiagnostic(ShellDiagnostic diagnostic);
}
```

### Publishers

```dart
/// Shell code's handle for publishing with an explicit source (Spec §2.4,
/// Appendix A.1). Made only by Bus.publisher.
final class Publisher {
  MessageSource get source;                 // a service, page or executor source
  Scope get scope;                          // the scope it is bound to (Spec §7.2)
  Set<StateTopic<Object?>> get writes;      // its claims; unmodifiable
  bool get isDisposed;

  /// Event and replay topics only (G19), the value typed by the topic (G40).
  void publish<T extends Object?, V extends T>(MultiWriterTopic<T> topic, V value);
  /// The writer of a claimed topic; ArgumentError for any other (G20, G41).
  StateWriter<T> writer<T>(StateTopic<T> topic);
  /// Idempotent; releases the claims (G21).
  void dispose();
}

/// The only path from shell code to a state topic (Spec §2.4, §3.11).
final class StateWriter<T> {
  StateTopic<T> get topic;
  void publish(T value);
}
```

### Topologies and module scopes

```dart
/// An activation (Spec §3.9, Appendix A.3). Made only by Bus.activate.
final class TopologyHandle {
  String get topologyId;
  Scope get scope;
  TopologyDefinition get definition;   // the definition activation checked
  bool get isActive;
  void deactivate();                    // synchronous, idempotent (G25)
}

/// A module's topologies, reference-counted with a grace period (Spec §7.3),
/// the API a UI adapter binds route events to. Made only by Bus.module.
final class ModuleScope {
  String get moduleId;
  List<Topology> get topologies;        // unmodifiable, activation order
  Duration get gracePeriod;
  int get references;                   // unreleased references
  bool get isActive;                    // its topologies are active
  ModuleReference acquire();            // G28
}

/// One acquired reference. Made only by ModuleScope.acquire.
final class ModuleReference {
  ModuleScope get scope;
  bool get isReleased;
  void release();                       // counts once per reference (G28)
}
```

### Observers

```dart
/// An observer that is also told of activations (Guide §8.2 "Topology
/// activation"). Registered with addObserver like any BusObserver.
abstract interface class ActivationObserver implements BusObserver {
  void onActivate(String topologyId, Scope scope, ObserveContext context);
}

/// The SDK-neutral telemetry observer (root D1; Guide §8.2): spans through
/// ObserveContext.span, named and attributed as G33 states.
final class TelemetryObserver implements ActivationObserver {
  TelemetryObserver({
    Set<ObserverCapability> capabilities =
        const <ObserverCapability>{ObserverCapability.observeAll},
  });
  @override
  Set<ObserverCapability> get capabilities;   // unmodifiable
  @override
  void onPublish(TopicRef topic, MessageEnvelope<Object?> envelope, ObserveContext context);
  @override
  void onActivate(String topologyId, Scope scope, ObserveContext context);
}
```

### Diagnostics and errors

```dart
/// A dev-mode diagnostic (root D8). Sealed; immutable; no field holds a payload.
/// toString() renders one line naming its fields.
@immutable
sealed class BusDiagnostic { const BusDiagnostic(); }

final class PublisherlessPublish extends BusDiagnostic {      // Spec §2.4
  const PublisherlessPublish({required TopicRef topic});
  TopicRef get topic;
}
final class ReentrancyDepthExceeded extends BusDiagnostic {   // Spec §3.4
  ReentrancyDepthExceeded({required List<TopicRef> chain});
  List<TopicRef> get chain;          // root publish first; unmodifiable
}
final class ObserverThrew extends BusDiagnostic {             // Spec §3.7
  const ObserverThrew({required BusObserver observer, required TopicRef? topic,
      required Object error, required StackTrace stackTrace});
  BusObserver get observer;
  TopicRef? get topic;               // null when onActivate threw
  Object get error;
  StackTrace get stackTrace;
}
final class StartNotCalled extends BusDiagnostic {            // Spec §3.13
  const StartNotCalled({required Duration window, required int queued});
  Duration get window;
  int get queued;                    // publishes queued when the window ended
}
final class PipelineTerminated extends BusDiagnostic {        // Spec §10.2
  const PipelineTerminated({required String topologyId, required TopicRef sink,
      required Object error, required StackTrace stackTrace});
  String get topologyId;
  TopicRef get sink;                 // the topic of the sink the error ended
  Object get error;                  // as raised, unwrapped
  StackTrace get stackTrace;
}
final class TopicLimitExceeded extends BusDiagnostic {        // Spec §11.3
  const TopicLimitExceeded({required TopicRef topic, required int maxTopics});
  TopicRef get topic;
  int get maxTopics;
}
final class LateApplicationActivation extends BusDiagnostic { // Spec §7.2
  const LateApplicationActivation({required String topologyId});
  String get topologyId;
}
final class ShutdownCallbackThrew extends BusDiagnostic {     // Spec §11.2
  const ShutdownCallbackThrew({required Object error, required StackTrace stackTrace});
  Object get error;
  StackTrace get stackTrace;
}
/// The extension point for other packages' dev-mode diagnostics (root D8):
/// base, so extended and never implemented outside this package.
abstract base class ShellDiagnostic extends BusDiagnostic {
  const ShellDiagnostic();
  String get origin;                 // the reporting component, such as 'executor:flutter-navigation'
}

/// The throws this contract states (Spec §3.8, §3.9, §3.11, §4.3, §11.3).
sealed class BusError extends Error {}

final class ActivationRejected extends BusError {             // G24
  ActivationRejected({required String topologyId, required List<TopologyFinding> findings});
  String get topologyId;
  List<TopologyFinding> get findings;   // analyzeTopologyGraph's order; unmodifiable
}
final class ClaimRejected extends BusError {                  // G20
  ClaimRejected({required MessageSource source, required List<TopologyFinding> findings});
  MessageSource get source;
  List<TopologyFinding> get findings;
}
final class TopologyConflict extends BusError {               // G23
  TopologyConflict({required TopologyDefinition active, required TopologyDefinition candidate});
  String get topologyId;
  TopologyDefinition get active;
  TopologyDefinition get candidate;
}
final class TopicCollision extends BusError {                 // G7
  TopicCollision({required Topic<Object?> registered, required Topic<Object?> requested});
  String get name;
  Topic<Object?> get registered;
  Topic<Object?> get requested;
}
enum BusLimit { topics, activeTopologies, observers }
final class BusLimitExceeded extends BusError {               // G10
  BusLimitExceeded({required BusLimit limit, required int max});
  BusLimit get limit;
  int get max;
}

/// The error a forced removal delivers to a topic's subscriptions (G9).
@immutable
final class TopicRemoved implements Exception {
  const TopicRemoved(TopicRef topic);
  TopicRef get topic;
}
```

Misuse that is not one of these throws the SDK's errors: `ArgumentError` for an argument the Interface excludes, `StateError` for an operation the bus's state excludes (a delivery in progress, shutdown).

### Delivery rules

These define the terms the guarantees use.

- **A publish** is a call of `Bus.publish`, `Publisher.publish`, `StateWriter.publish`, or a topology sink publishing a value. It constructs its envelope at once, with `MessageEnvelope.publishedTo`, a fresh id and `bus.clock.now()` (topic-model@v1).
- **A delivery** hands one publish's envelope to the topic's subject: the recorders attached to the bus first, in attachment order (bus-testing@v1 G14, G17), then the permitted observers in registration order, then the subscriptions. It runs in the provider zone, synchronously.
- **When a publish is delivered.** Before `start()`, it is queued (G34). After `start()`, a publish made while no delivery is in progress is delivered before the call returns; a publish made during a delivery is **reentrant** and is delivered after that delivery completes, from a provider-zone microtask that delivers the reentrant publishes in the order they were made, including the ones their own deliveries make (G14). A sink publish caused by a delivery is reentrant; one made from a timer, such as a debounce firing, is not.
- **A read** is an observed subscription or an activation's read stage. Its effective dedup policy is the read's own argument for a topology read, else the topic's `dedup` for a state topic, else none (G16).
- **The connection** of an activation is its reads' first values: a state topic's current value, a replay topic's buffer (topology-dsl@v1 Live interpretation 3). It reaches the reads before `activate` returns, so before any later delivery, those `start()` makes included, and from then on each delivery of a read's topic reaches the read during that delivery; the publishes it causes are made from a provider-zone microtask (G22). It is not a publish; the startup barrier does not hold it back.
- **A widened reference** to a topic is a reference whose static type argument is a proper supertype of the topic's value type, as generic shell code holds a topic: a `Topic<Object?>` or a `StateTopic<Object?>` that holds a `StateTopic<int>`, a `MultiWriterTopic<num>` that holds an `EventTopic<int>`. Dart's covariant generics assign one without a cast, and inference gives a call through it the reference's type argument (G41).

### For static analysis

nidana.tooling's checks run no bus and recognize this surface by package and name (ADR-002 item 7): a claim is a call of the `Bus` instance method `publisher` declared in package `nidana_dart_runtime`, whose first positional argument is the source, whose `writes` named argument is a set of state topic references, and whose `scope` named argument is the bound scope; the declaring library is under `lib/src/`, so a check matches the package name `nidana_dart_runtime` and the element names, never a library path. A global bus accessor is a top-level variable, a static field, a top-level getter or a static getter whose type is `Bus` or a subclass, nullable or not, in application code (Spec §3.1), which is exactly what nidana-checks@v1 G5 reports; `Bus` itself declares none (G1).

## Guarantees / invariants

- **G1** A bus is reached by explicit reference (Spec §3.1): it is constructed by `Bus(config)`, `Bus` declares no static member that returns a bus, and each bus has its own subjects, current values, ownership table, observers, active topologies and module scopes, while topic values are shared across buses.
- **G2** The bus and its handles are made only by the runtime: `Bus`, `BusConfig`, `Publisher`, `StateWriter`, `TopologyHandle`, `ModuleScope`, `ModuleReference` and `TelemetryObserver` are final, `BusError` is sealed, no type outside the package extends or implements any of them, and none of the handles has a public constructor.
- **G3** `BusConfig` is immutable, with final fields and the defaults the Interface lists: no provider (the production one), dev mode and sinks unset, `maxTopics` 1000, `maxActiveTopologies` 200, `maxObservers` 20, `maxReentrancyDepth` 10, a 100 ms grace period and a 5 s startup window (Spec §3.4, §3.13, §7.3, §11.3); a bus keeps the config it was given, and constructing a bus throws `ArgumentError` when a limit is below 1 or a duration is negative.
- **G4** Dev mode (root D8): `bus.devMode` is `config.devMode`, or, when that is null, whether assertions are enabled when the bus is constructed. In dev mode every diagnostic this contract names is a `BusDiagnostic` value delivered when it arises, in the provider zone, to `config.diagnostics` or, when that is null, to `print`, and it is never thrown; outside dev mode none is delivered. `BusDiagnostic` is sealed, its runtime variants final, and `ShellDiagnostic` is its one extension point: a base class another package extends and delivers through `reportDiagnostic`. No diagnostic has a field that holds a payload; an error it carries is the object that was raised.
- **G5** The time source (ADR-003 items 1 to 3 and 8): exactly two scheduler providers exist and applications cannot define another; the production provider is the zone and `package:clock`'s clock current when the bus is constructed; the bus makes every subscription, calls every observer and creates every timer and microtask in the provider zone, and listening to an observed stream subscribes inside it, so a subscriber's callbacks run there; no bus operation waits on a cancel future; `bus.clock` is the provider clock, and every envelope's timestamp is `bus.clock.now()` at its publish.
- **G6** Subjects are created lazily (Spec §2.5, §3.2): on the first activation that reads or writes the topic, or the first `publish`, `observe`, `getCurrentValue` or `getBufferedValues` naming it; a claim creates none; a state topic's `createInitial()` is called once, when its subject is created, and otherwise only as G8 states after shutdown.
- **G7** Names are unique on a bus (Spec §4.3): the access that creates a subject registers the topic's name, and an access or a claim naming a topic of that name that differs from the registered one in variant, value type, sensitive flag, tracing, dedup policy or buffer size throws `TopicCollision`; equal declarations share one subject; a removal unregisters the name.
- **G8** Current and buffered values (Spec §2.5): `getCurrentValue` takes a `StateTopic` only and `getBufferedValues` a `ReplayTopic` only, so any other variant does not compile; `getCurrentValue` is the declared initial value until a publish to the topic is delivered, then the last value delivered; `getBufferedValues` is the most recent delivered values up to the buffer size, oldest first, unmodifiable; neither throws except `TopicCollision`, or the `TypeError` G41 states for a value that is not of the topic's value type, and publishes queued before `start()` are not reflected; after shutdown both answer from what the topic held, the initial value or an empty list for a topic that had no subject, and create nothing.
- **G9** Removal (Spec §3.2, §3.10, §7.5): `removeTopic` returns true when the topic has no subject; it returns false and changes nothing when the subject has a subscriber, an observed subscription or an active topology's read, and `force` is false; otherwise it delivers `TopicRemoved` to every topology read of the topic, ends every observed subscription with a `TopicRemoved` error and then done before it returns, and removes the subject and the name, so the next access creates a fresh subject from `createInitial()`; claims on the topic are untouched; called during a delivery it throws `StateError`.
- **G10** Resource limits (Spec §11.3): an activation that would make more than `maxActiveTopologies` active topologies or more than `maxTopics` subjects throws `BusLimitExceeded` naming the limit and activates nothing; `addObserver` beyond `maxObservers` throws `BusLimitExceeded`; any other access that creates a subject beyond `maxTopics` creates it and reports `TopicLimitExceeded`, because `getCurrentValue` never throws for a missing subject (Spec §2.5).
- **G11** The publisher-less path (Spec §2.4): `bus.publish` takes an event or replay topic only, so a state topic does not compile; its publish carries `UnknownSource` and starts a new flow (G12), and dev mode reports `PublisherlessPublish` for it.
- **G12** A shell publish is a root message (Spec §2.4; Guide §3.6): a publish through `bus.publish`, a publisher or a writer has a fresh id, a fresh correlation id, no causation, no parent correlation ids, the publisher's source and the topic's sensitive flag; the ids a bus generates are distinct from one another, as are its fresh correlation ids; both are opaque strings.
- **G13** Per-topic ordering (Spec §3.3, §3.10; Guide §6.5): a topic's deliveries reach every observer and subscription current at each delivery, never part of them, in one order that is the same for all of them; after `start()`, a publish made while no delivery is in progress reaches the established subscriptions before the call returns.
- **G14** Reentrancy normalization (Spec §3.3, §3.4): a publish made during a delivery is delivered after that delivery completes, in a provider-zone microtask, after every reentrant publish made before it; one to the topic being delivered does not fail; publishes made one after another with no other publish between them are delivered consecutively in that order, so one value a topology writes to several sinks is delivered consecutively in sink declaration order.
- **G15** Recursion detection (Spec §3.4): a reentrant publish's chain is the topics from the non-reentrant publish that started it to itself; dev mode reports `ReentrancyDepthExceeded` with that chain once, at the publish that is the chain's `maxReentrancyDepth + 1`-th reentrant hop, and every publish of the chain is still delivered.
- **G16** StateTopic dedup (Spec §3.12; decides OQ-R3): every publish to a state topic is delivered, becomes its current value and reaches its observers, an equal one included; dedup applies per read: a read whose effective policy is `Dedup.equality` skips a value `==` to the last value it received, its first value being the one current when it connected, and a `Dedup.none` read receives every publish; event and replay topics never deduplicate.
- **G17** First delivery (Spec §2.1, §3.10, §7.4; decides OQ-R1): an observed subscription of a state topic receives, in the first provider-zone microtask after `listen` returns, the value current when it listened, then the values delivered since, in order, none missed or repeated; one of a replay topic receives its buffer the same way; from then on, and for an event topic from `listen` on, it receives each delivery synchronously (G13); the synchronous first value of a state or replay topic is `getCurrentValue` or `getBufferedValues`.
- **G18** Observed streams: `observe` returns a broadcast stream of payloads; each `listen` is a subscription with its own first value and dedup state; a subscriber callback that throws stops neither the delivery to the other subscriptions nor later deliveries, its error going to the provider zone's uncaught-error handler; a cancelled subscription receives nothing more; shutdown ends every subscription with done before it returns; after shutdown `observe` throws `StateError`, and listening to a stream obtained before receives done only.
- **G19** Publishers (Spec §2.4, §7.2): `bus.publisher` takes a `ServiceSource`, `PageSource` or `ExecutorSource` and throws `ArgumentError` for a `TopologySource` or `UnknownSource`; its scope is `Scope.application` unless given; `writes` takes state topics only and `Publisher.publish` event and replay topics only, so neither accepts another variant; a publisher publishes with its own source.
- **G20** Claims and writers (Spec §2.4, §3.11 layer 1, §7.2): a publisher with claims is checked once, at construction, over the graph of G37 with its claim added, and any finding (a `WriterConflict` naming the current owner, a `ScopeViolation`) throws `ClaimRejected` with the findings and claims nothing; `writer(topic)` exists only for a claimed topic and throws `ArgumentError` for any other, returns the same handle on every call with the same type argument (G41), is typed by the topic, and publishes with the publisher's source; a publisher has no other path to a state topic.
- **G21** Release (Spec §2.4, §3.11): `dispose` is idempotent, releases the claims, discards the publisher's publishes not yet delivered, and makes `publish` on the publisher and its writers throw `StateError`; deactivating a topology releases its writes; ownership never passes between live claimants.
- **G22** Activation (Spec §2.2, §3.5, §3.13, §6.5): `activate` interprets the topology's plan as topology-dsl@v1's Live interpretation states; a sink publish is a publish of this bus, carrying `TopologySource(topologyId)` and the pipeline value's lineage, observed, deduplicated per read, queued before `start()` and reentrant during a delivery. The connection reaches the reads before `activate` returns, and every later delivery of a read's topic reaches the read during that delivery. A read therefore receives its first values before any delivery that starts after `activate` returns, whether that delivery's publish was made after the activation or was queued before `start()`, even before the activation (G34), and the deliveries `start()` makes reach the reads of a topology activated before it in queue order, across topics. The publishes the connection causes are made from a provider-zone microtask queued during `activate`, so none is delivered before `activate` returns, and once the provider-zone microtasks queued during `activate` have run, each has been delivered, or queued while the bus is bootstrapping. An `APPLICATION` topology activated after `start()` is reported as `LateApplicationActivation` in dev mode (Spec §3.13, §7.2).
- **G23** Idempotency (Spec §3.9): activating a topology whose id is active runs `declare` once and compares the definitions; equal ones return the active handle and change nothing, unequal ones (any edge or the scope) throw `TopologyConflict`; definitions equal under topology-ir@v1's equality count as the same declaration, including two that differ only where a definition does not look (a scan seed, a closure body, two functions rendering one name); after deactivation the topology activates again with a fresh handle.
- **G24** Activation checks (Spec §3.8, §3.11, §7.2): before wiring, activation analyzes the graph of G37 with the candidate's definition added, and any finding (an inter-topology cycle, an unmediated self-reference, a second writer of a state topic, an owner with a shorter scope than a reader) throws `ActivationRejected` with the findings, leaving nothing of the candidate active or claimed.
- **G25** Deactivation (Spec §2.2, §7.2): `deactivate` is synchronous and idempotent; it cancels every subscription and timer of the activation without waiting on a cancel future, releases its writes, and discards its publishes not yet delivered; a handle returned to several activations (G23) is one handle, and deactivating it ends the topology for every holder.
- **G26** Terminated pipelines (Spec §10.2): when an error ends a sink (topology-dsl@v1 Errors and lineage), dev mode reports `PipelineTerminated` with the topology id, the sink's topic and the error as raised; the bus does not restart the sink, and only a new activation runs it again.
- **G27** Module declaration (Spec §7.3): `module` declares one scope per id; repeating it with the same topology ids in the same order and the same grace period returns that scope, and any other declaration under the id throws `ArgumentError`, as do an empty id, an empty list, a topology whose scope is not `Scope.module` and a negative grace period; the grace period defaults to `config.moduleScopeGracePeriod`.
- **G28** Module reference counting (Spec §7.3, §7.4): an `acquire` at zero references cancels a pending grace timer or activates the topologies in order, and when one cannot activate it deactivates those it activated, leaves the count at zero and rethrows; each acquire adds one reference and each reference releases once, its second `release` doing nothing; the last release starts a grace timer in the provider zone, or with a zero grace period deactivates at once, synchronously; an acquire before the timer fires keeps the topologies; when it fires they are deactivated in reverse order; an acquire after that activates them again.
- **G29** Observers (Spec §3.7, §9.1): `addObserver` registers an observer and throws `ArgumentError` for one already registered; `removeObserver` unregisters it and returns whether it was registered; at each delivery the permitted observers are called synchronously, in registration order, before any subscription, in the provider zone, with the topic's reference, the envelope and `config.observeContext` or the default sinks.
- **G30** Observer gating (Spec §3.7, §9.2; Guide §8.1): an observer receives an envelope exactly when `ObserverCapability.permits(capabilities, sensitive: envelope.sensitive)` holds and the topic is not `Tracing.disabled`; an untraced topic's subscribers still receive its values.
- **G31** Observer failure (Spec §3.7): an exception an observer throws is swallowed and reported as `ObserverThrew` in dev mode, and the delivery goes on to the later observers and the subscriptions.
- **G32** Activation observers (Guide §8.2): after each activation that creates a handle, every registered `ActivationObserver` receives `onActivate` with the topology id and scope, in registration order, in the provider zone; an activation that returns an active handle notifies none; an exception is handled as G31 states, with no topic.
- **G33** Telemetry (root D1; Guide §8.2): `TelemetryObserver` opens and ends one span per envelope it receives, named after the topic, with the attributes `nidana.id`, `nidana.correlation_id`, `nidana.causation_id` (when there is one), `nidana.source` (the source's rendering), `nidana.payload_type` (the payload's runtime type name) and `nidana.sensitive: true` (for a sensitive envelope), linked to the causation id when there is one; it opens and ends one span `nidana.activation` per activation with `nidana.topology_id` and `nidana.scope` (the scope's name); it records no payload, and its capabilities default to `observeAll`.
- **G34** The startup barrier (Spec §3.13, §11.2): a bus is bootstrapping until `start()`; meanwhile `activate`, `publisher`, `observe`, `module` and `addObserver` work, and every publish, a topology's included, is queued in publication order, reaching no observer or subscription and no current or buffered value; `start()` delivers the queue in that order before it returns and is idempotent; every topology activated before `start()` is connected when `start()` delivers the queue (G22), even when nothing runs between the activation and `start()`, so a publish queued before an activation, such as a deep link, reaches that activation's reads after their first values, and the queue reaches those reads in its order; from then on a publish is delivered as G13 and G14 state, so activation order before `start()` does not change what is delivered.
- **G35** The startup window (Spec §3.13): in dev mode the first publish queued before `start()` starts a timer of `config.startupWindow` in the provider zone; if the bus is still bootstrapping when it fires, it reports `StartNotCalled` once, with the window and the number of publishes queued; `start()` and `shutdown()` cancel it.
- **G36** Shutdown (Spec §11.2; ADR-003 item 2): `shutdown` is synchronous and idempotent: it delivers the pending reentrant publishes and those their deliveries cause, discards the publishes queued before `start()`, runs the `onShutdown` callbacks in reverse registration order (one that throws is reported as `ShutdownCallbackThrew` and the rest still run), deactivates every module scope and topology, disposes every publisher, ends every observed subscription with done and cancels every timer the bus and its pipelines created, so none stays pending; afterwards `publish`, `observe`, `activate`, `publisher`, `module`, `acquire`, `addObserver`, `removeTopic`, `onShutdown`, `start` and every publisher's and writer's `publish` throw `StateError`, while `deactivate`, `release`, `dispose`, `removeObserver` and `shutdown` do nothing and `getCurrentValue`, `getBufferedValues`, `toGraph` and `reportDiagnostic` still answer.
- **G37** The live graph (Spec §6.5): `toGraph()` is the `TopologyGraph` of the active topologies' definitions and, for every live publisher with claims, a `ShellClaim` of its source, scope and claimed topics; activation (G24) and claims (G20) are checked over this graph with the candidate added.
- **G38** `nidana_dart_runtime` reads no wall clock, constructs no `Stopwatch` directly and creates no timer or microtask outside a provider zone, except the real event-loop turns of bus-testing@v1's settle operation, which ADR-003 item 6 requires (bus-testing@v1 G12, G20; ADR-003 items 6 and 8).
- **G39** `nidana_dart_runtime` depends on `nidana_dart_contracts`, `rxdart`, `clock` and `meta` only, and neither public library imports `package:test` or `package:flutter_test` (ADR-002 items 3 and 4).
- **G40** Publish typing (Spec §4.2): with its type arguments inferred, a call of `Bus.publish` or `Publisher.publish` compiles exactly when the topic is an event or replay topic (G11, G19) and the value's static type is the topic's value type or a subtype of it; inference does not widen the topic's type to admit the value, so a `String` published to an `EventTopic<int>`, or a `num` to a `ReplayTopic<int>`, does not compile; a generic caller that holds a `MultiWriterTopic<T>` and a `T` publishes without type arguments; `StateWriter.publish` takes the topic's value type (G20). Explicit type arguments can still widen the topic's type through Dart's covariant generics, as `publish<num, double>` on an `EventTopic<int>` does; such a call is outside this guarantee.
- **G41** Widened references (Spec §3.2, §4.2, §4.3): a topic reached through a widened reference and at its value type, in either order and in any mix on one bus, is one subject. The registry keys a subject by the topic's name and registers the topic value of the access that creates it; G7 compares topic values, `valueType` among their fields (topic-model@v1 G7), never the type argument of a reference, so neither access throws a `TypeError` or a `TopicCollision`, while a topic declared with another value type still collides. Through a widened reference whose type argument is `R`: `observe` returns a `Stream<R>` that delivers the same payloads, with the same first values (G17) and dedup (G16), as a subscription at the value type; `getCurrentValue` returns the same value, and `getBufferedValues` an unmodifiable `List<R>` of the same values in the same order (G8); a topology's read receives the same values, its connection included (G22); a publish of a value of the topic's value type, through `Bus.publish`, `Publisher.publish`, the `StateWriter<R>` that `writer` returns for the reference, or a topology's sink, is delivered as the same publish made at the value type, to the recorders, observers, subscriptions and reads at either type; an observer receives `topic.ref`, which is the same through every reference (topic-model@v1 G8). A value that is not of the topic's value type, which a widened reference lets a call pass as G40's explicit type arguments do, is checked neither by the publish nor by the delivery, and the topic's current value and buffer hold it. Each conversion at an access's type argument runs in the delivery callback of the one subscription or topology read it serves, its first values and a read's connection included, so its `TypeError` goes to the provider zone's uncaught-error handler, as a throwing subscriber's error does (G18); that subscription or read skips the value and keeps receiving later deliveries, and the recorders, the observers and every other subscription and read receive the delivery (G13). A conversion made at a call (`getCurrentValue`, `getBufferedValues`, or a `reduceInto` seed during `activate`) throws the `TypeError` to the caller, and an `activate` that throws activates nothing. Outside this guarantee: whether the envelope of a publish made through a widened reference is a `MessageEnvelope` of the topic's value type rather than of `R`.

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates.
- Breaking for this contract: removing, renaming or retyping any declaration; adding a variant to `BusDiagnostic`, `BusError`, `BusLimit` or `BusLifecycle`, which consumers switch over exhaustively; adding a member to `ActivationObserver`, which applications implement; changing a default, a delivery rule, the timing of first delivery, the dedup placement, the reentrancy rule, what an observer sees, a telemetry attribute or span name, what shutdown does, or which operation throws what.
- Compatible: a new optional named parameter with a default that keeps current behavior; a new getter or method on a final class; a new `ShellDiagnostic` subclass in another package; a new guarantee that existing fixtures still pass.
- Amended within v1, at the request of bus-testing@v1 and navigation-api@v1 (its Refinements 8 and 9): (a) G22, G34 and the connection rule state that the connection reaches an activation's reads before `activate` returns and that every later delivery reaches them during that delivery, so `start()` delivers the queue to the topologies activated before it, already connected, in queue order; and that the publishes a connection causes are made from a provider-zone microtask; (b) `Bus.publish` and `Publisher.publish` take the value as a second type parameter, `publish<T extends Object?, V extends T>`, and G40 states the typing (Refinement 3); (c) G38 excepts the real turns of bus-testing@v1's settle operation, which ADR-003 item 6 already required; (d) the delivery rule names the recorders attached to the bus, in attachment order, as bus-testing@v1 G14 states. The Breaking list above names retyping a declaration and changing a delivery rule; the amendment stays within v1 because no package and no consumer code exists, every contract is `draft`, and every fixture of every other contract that imports `nidana_dart_runtime` passes unchanged against a stand-in amended for (a) and (b) (`docs/auto-run/experiments/bus-api-amendment/`, T1 to T7). (a) states what G22's earlier wording, G34 and Spec §3.13 ("no `APPLICATION` topology can miss an event that was published before it subscribed") already intended and navigation-api@v1 already reads; the earlier fixtures did not pin it, and a runtime that passed them dropped a deep link queued before `start()`. (b) rejects only calls that compiled by inferring `T` wider than the topic's value type, so with a value the topic cannot carry (a `TypeError` at run time on the stand-in, navigation-api@v1 Refinement 9), and calls that passed one explicit type argument, which only this contract's own fixtures did. (c) and (d) change no rule a consumer relies on.
- Amended within v1 a second time, at the request of flutter-binding@v1's authoring and of nidana-checks@v1 (its `global_bus_accessor` rule): (e) G41 states that a topic reached through a widened reference and at its value type is one subject in either order, the delivery rules define a widened reference, and G20's same writer handle holds per type argument, because a `StateWriter<Object?>` returned for a widened reference before any call at the value type cannot be returned to a later call that asks for a `StateWriter<int>`; (f) For static analysis defines a global bus accessor as nidana-checks@v1 G5 reports it, getters included. Compatible: no declaration, default, delivery rule or stated throw changes for an access at the topic's value type; G41 adds behavior where the earlier stand-in runtime threw a `TypeError` that no guarantee stated (`docs/auto-run/experiments/flutter-binding-fixtures/output-widened-observe.txt`); G20 changes only across type arguments, which no fixture compares; and every fixture of every contract that imports `nidana_dart_runtime` passes unchanged against a stand-in that meets G41 (`docs/auto-run/experiments/bus-api-widened/`, T5). (f) changes no guarantee here: the paragraph describes what nidana.tooling's checks recognize, and nidana-checks@v1 owns the check.
- Amended within v1 a third time, from nidana.runtime's phase plan (its D5 and D1), drained by hsdd-reconcile on 2026-10-18: (g) G41 states what happens to a value that is not of the topic's value type, which it had left outside: neither the publish nor the delivery checks it, the current value and the buffer hold it, the conversion of a subscription or a topology read fails into the provider zone's handler and that subscription or read alone skips the value, a conversion at a call throws `TypeError` to the caller, and an `activate` that throws activates nothing; G8 names that `TypeError` beside `TopicCollision`; (h) the Interface's code-owner sentence names nidana.runtime.1, because nidana.runtime has no children, and the Delivery paragraph states which phase delivers which guarantee. Compatible: nothing changes for a value of the topic's value type; G41 stated no behavior for an off-type value, and G8's "neither throws" had no conforming behavior for one, because the value delivered last is not of the type `getCurrentValue` returns and topic-model@v1 offers no publish-time check (nidana.runtime D4, D5); no fixture of any other contract publishes an off-type value; three new G41 cases cover (g), and every case of every suite that imports `nidana_dart_runtime` passes against a stand-in that meets it (`docs/auto-run/experiments/runtime-reconcile-amends/`). Changing what happens to an off-type value is now a breaking change.
- Not in v1, each a candidate for a later version: a per-subscription dedup argument on `observe`; binding a publisher to a module scope's lifetime, which the caller does by disposing it when it releases the module; a shell publish linked to the delivery that prompted it (causation from shell code, Guide §10.2); access to the provider zone; persistence hooks (root D1); a dedicated audit topic (Spec §9.1 Approach B, root D1).

## Validation

- fixture: `hsdd/contract/fixture/bus-api/`, under `hsdd/contract/fixture/analysis_options.yaml` (ADR-001 item 2); replayed with `fvm dart run nidana_contract_check bus-api`.
- surface: `hsdd/contract/fixture/bus-api/surface/` (`bus.dart`, `topologies.dart`, `observation.dart`) uses every declaration with the types the Interface states, implements `ActivationObserver`, extends `ShellDiagnostic`, and switches exhaustively over `BusDiagnostic`, `BusError`, `BusLimit` and `BusLifecycle`, so a variant added to any of them fails the surface set.
- reject: `hsdd/contract/fixture/bus-api/reject/`, one library per type-level guarantee: `no_global_accessor.dart` (G1), `runtime_types_are_closed.dart` (G2), `config_is_immutable.dart` (G3), `diagnostics_are_closed.dart` (G4), `scheduler_providers_are_closed.dart` (G5), `current_value_is_state_only.dart` (G8), `no_publisherless_state_publish.dart` (G11), `publisher_reaches_state_through_writer.dart` (G19, G20), `publish_value_matches_topic.dart` (G40).
- behavior: conformance library `hsdd/contract/fixture/bus-api/behavior/bus_api_conformance.dart`, harness `BusApiHarness`, cases `busApiConformance`, covering G1, G3 to G37 and G41. The harness names no bus-testing@v1 type: a binding supplies buses on a virtual provider (`bus`), the virtual scheduler's `triggerActions` and `advanceTimeBy` (`flush`, `advance`), its pending timer count (`pendingTimers`) and the settle operation (`settle`). The G13 cases are the per-topic ordering regression test of Guide §6.5.
- binding: `hsdd/contract/fixture/bus-api/behavior/nidana_dart_runtime_test.dart` binds the bus-api suite to the producer's bus, each case on fresh `TestBus` instances, under `dart test`. It must pass every case of `busApiConformance`.
- binding: `hsdd/contract/fixture/bus-api/behavior/bus_activation_test.dart` binds topology-dsl@v1's live suite (`../../topology-dsl/behavior/live_conformance.dart`, harness `LiveTopologyHarness` with `LiveRun`, cases `liveConformance`) to `Bus.activate` on a `TestBus`, under `dart test` (ADR-001 item 4). `start` constructs a `TestBus`, activates the topologies in order and calls `start()`; `publish` publishes an event or replay value through one publisher and a state value through a writer of a publisher that claims that topic; `watch` returns a view of the TestBus's envelope recorder from the moment of the watch, filtered to the topic and read with the topic's own dedup policy, the value current at the watch being the first value received and never appended; `deliveries` is every envelope those views hold, in delivery order; `current` is `getCurrentValue`; `advance` is `advanceTimeBy`; `activate` and `deactivate` act on topology handles; `settle` is the settle operation. It must pass every case of `liveConformance`.
- Both bindings use these bus-testing@v1 declarations from `package:nidana_dart_runtime/testing.dart`, as forward references: `TestBus([BusConfig config])`, a `Bus`; `TestBus.scheduler`, a `VirtualScheduler` with `void triggerActions()`, `void advanceTimeBy(Duration)`, `int get pendingTimerCount` and `Future<void> settle()`; `TestBus.recorder`, whose `envelopes` is a `List<RecordedEnvelope>` of every envelope delivered on the bus, untraced topics included, in delivery order, at delivery time; `RecordedEnvelope` with `TopicRef topic` and `MessageEnvelope<Object?> envelope`. A TestBus constructs a fresh `VirtualScheduler` in the zone current at its construction (ADR-003 items 5 and 6), which the G18 case relies on. bus-testing@v1 declares every one of these names, and `TestBus.recorder` is the recorder a TestBus attaches at construction (its Refinement 1, G14).
- Each binding's package imports name the implementation, so the replay tool reports a binding as `PENDING` until `nidana_dart_runtime` exists (ADR-001 item 9). Both run in nidana.runtime's gates; nidana.integration's gate runs them with `--all`.
- type-level guarantees G2 and G40 and the type-level halves of G1, G3, G4, G5, G8, G11, G19 and G20 are checked by the reject and surface sets.
- not executable: G38, a property of the package's source rather than of its declarations; checked by nidana.runtime's gates
- not executable: G39, a property of the package's pubspec and imports; checked by nidana.runtime's gates
- No schema: an `api` contract with no serialized form carries none (ADR-001 item 4); the graph `toGraph()` returns serializes through topology-ir@v1's schema.
- The fixtures are forward references, written before the package exists. topic-model@v1 declares `MultiWriterTopic` (its G27), and `docs/auto-run/experiments/topic-model-multi-writer/` replays this contract's surface and reject sets against a topic model with and without it. In `docs/auto-run/experiments/bus-api-fixtures/` (`run.sh`, `output.txt`) every reject code was confirmed against a stand-in that implements this Interface on RxDart 0.28 sync subjects, with a stand-in topic model carrying `MultiWriterTopic`; the surface set analyzed clean; the bus-api suite and topology-dsl@v1's live suite passed against the stand-in on a stand-in `TestBus`; and seeded defects in the stand-in failed the cases of the guarantee they break. The same experiment found that a closed RxDart `BehaviorSubject` delivers done to its subscriber from a microtask outside the provider zone (`output-close.txt`), which is why G9 and G18 have the bus end observed subscriptions itself.
- The v1 amendment (`## Versioning`) is checked in `docs/auto-run/experiments/bus-api-amendment/` (`run.sh`, `output.txt`), on the stand-in of `docs/auto-run/experiments/navigation-api-fixtures/` with the typed publish, and with topology reads served by a synchronous broadcast controller rather than the RxDart subject, whose replay to a new listener holds back every delivery made before its first microtask. Structure passed for this contract (40 guarantees, 89 cases), bus-testing@v1 and navigation-api@v1; every surface library analyzed clean; every reject code of the three was confirmed, `publish_value_matches_topic.dart`'s included; this suite passed 89 of 89 cases, topology-dsl@v1's live suite 43 of 43, bus-testing@v1's suite 45 of 45, navigation-api@v1's navigation suite 40 of 40 and its executor suite 52 of 52 on `InMemoryRouter` and 26 of 26 under `fvm flutter test` and `testWidgets`. The new G22 connection case and G34 deep-link case read a state topic through a `withLatestFrom` gate, which drops a value that arrives before the read's first value: against the runtime of `docs/auto-run/experiments/bus-testing-fixtures/`, whose connection arrives one microtask after `activate`, both fail, and against the runtime of `docs/auto-run/experiments/navigation-api-fixtures/`, whose connection is synchronous while later deliveries wait behind the RxDart replay, the G34 case fails on its queued state publish. Making a connection's publishes synchronous fails the G22 microtask case and the G34 activation-order case; the publish forms `publish<T, V extends T>` and `publish<T>(MultiWriterTopic<T>, T)` fail the reject set, the first through a strict-inference warning on a state topic, which fails navigation-api@v1's reject set too (Refinement 3).
- The second v1 amendment (`## Versioning`, (e) and (f)) is checked in `docs/auto-run/experiments/bus-api-widened/` (`run.sh`, `output.txt`), on the stand-in of `docs/auto-run/experiments/bus-api-amendment/` patched so that a subject holds its values at `Object?` whatever the type argument of the access that creates it, each access converts at its own type argument, and writers are kept per topic and type argument. Structure passed for this contract (41 guarantees, 95 cases), bus-testing@v1, navigation-api@v1 and flutter-binding@v1; every surface library of the four analyzed clean and every reject code was confirmed; on the patched stand-in this suite passed 95 of 95 cases, topology-dsl@v1's live suite 43 of 43, bus-testing@v1's suite 45 of 45, navigation-api@v1's navigation suite 40 of 40 and its executor suite 52 of 52, and flutter-binding@v1's two bindings 52 of 52 and 26 of 26 under `fvm flutter test`. On the unpatched stand-in the six G41 cases fail, five on a `_Cell<Object?>` cast to `_Cell<int>` and one on a `StateWriter<Object?>` cast to `StateWriter<int>`, and every other case of every suite passes. Seeded defects in the patched stand-in (writers kept per topic only, a modifiable buffer copy, a collision check that ignores the value type, no dedup at a nullable type argument) each fail the G41 case of what they break. Probe P2 there shows that the envelope of a widened publish is a `MessageEnvelope<Object?>`, which G41 leaves outside, and that bus-testing@v1's recorder, typed by the topic, then throws a `TypeError` for it.
- The third v1 amendment (`## Versioning`, (g)) is checked in `docs/auto-run/experiments/runtime-reconcile-amends/` (`run.sh`, `output.txt`), on the stand-in of `docs/auto-run/experiments/bus-api-widened/` patched so that a topology read skips a value it cannot convert, its `TypeError` sent to the provider zone's handler, and an `activate` that throws while wiring deactivates what it wired. Structure passed for this contract (41 guarantees, 98 cases) and bus-testing@v1, and S17's prototype found no problem in the nine contracts; the conformance libraries and bindings analyzed clean; on the patched stand-in this suite passed 98 of 98 cases, topology-dsl@v1's live suite 43 of 43, bus-testing@v1's suite 47 of 47, navigation-api@v1's two suites 40 of 40 and 52 of 52, and flutter-binding@v1's two bindings 52 of 52 and 26 of 26 under `fvm flutter test`. On the unpatched stand-in the new cases for a read's off-type value and for a call's conversion fail and every other case passes; the case for an observed subscription passes there too, because that stand-in already converted in the subscription's own callback. A read that converts outside a guard, so that its connection's `TypeError` escapes `activate`, and an `activate` that stays active after a seed fails, each fail the case of what they break.
- The first replay against the real package, once nidana.model's first phase lands the replay tool, is the first verification of every fixture here (ADR-001 Consequences).
