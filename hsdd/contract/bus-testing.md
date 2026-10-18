---
id: bus-testing
version: v1
status: draft
kind: api
owner: nidana.runtime
compatibility: versioned
produced_by: [nidana.runtime.1, nidana.runtime.5, nidana.runtime.7, nidana.runtime.13, nidana.runtime.14]
consumers: [nidana.navigation.6, nidana.flutter, nidana.integration]
external_consumers: [app topology and service tests, app widget tests]
phase_ids: provisional
---

# Contract: bus-testing

- **Governed by:** [ADR-001, ADR-002, ADR-003]

The deterministic test substrate (Spec §3.6, Appendix A.5, A.7; Guide §6.5, §10.1, C.4): the virtual scheduler that replaces wall-clock time, the `TestBus` that runs on it, the envelope recorder that captures what a bus delivers, with sensitive payloads redacted by default (Spec §9.2 item 2), the asynchronous settle operation for work that starts outside the bus zone (ADR-003 item 6), and the per-topic ordering probe Guide §6.5 asks the test utilities to provide. Everything here is in `package:nidana_dart_runtime/testing.dart`, which is the `nidana-test-utils` of Guide §6.5 and §10.1 on Dart (ADR-002 item 6), and imports neither `package:test` nor `package:flutter_test`, so VM tests and widget tests use it alike.

## Boundary

bus-api@v1's Boundary assigned this contract `testing.dart`. This contract keeps that assignment and refines it in three places:

| Declaration group | Contract |
|-------------------|----------|
| `VirtualSchedulerProvider`, `VirtualScheduler`, `TestBus`, `EnvelopeRecorder`, `RecordedEnvelope`, `OrderingProbe`; the scheduler operations, quiescence, bounds and initial time; deterministic ids on a TestBus; what a recorder records and how it redacts; how a test activates only the topologies under test (OQ-R2) | bus-testing@v1, `testing.dart` |
| `Bus`, `BusConfig`, `SchedulerProvider`, `ProductionSchedulerProvider`, publishers and writers, and what any bus guarantees whatever its provider, a TestBus included | bus-api@v1 |
| `MessageEnvelope`, its `redacted()`, `RedactedPayload`, `TopicRef`, `MessageSource` | topic-model@v1 |
| `Topology`, `TopologyBuilder`, the combinators and their live semantics | topology-dsl@v1 |
| `TopologyGraph`, `ShellClaim`, `TopologyDefinition` | topology-ir@v1 |

- **Refinement 1.** A recorder is not a TestBus feature but a seam of every bus: `EnvelopeRecorder.attach` works on a bus with either provider (ADR-003 item 6), so a widget test on a production-provider bus records envelopes too. `TestBus.recorder` is the recorder a TestBus attaches when it is constructed. A recorder is not a `BusObserver`: it sees `Tracing.disabled` topics and sensitive topics, and counts against no limit.
- **Refinement 2.** The settle operation is the scheduler's (`VirtualScheduler.settle`), not the TestBus's, so several buses that share one provider settle once, and a test that drives a scheduler with no bus settles too.
- **Refinement 3.** bus-api@v1's two bindings forward-reference the names this contract declares and use them unchanged: `TestBus([BusConfig config])`, `TestBus.scheduler` with `triggerActions`, `advanceTimeBy`, `pendingTimerCount` and `settle`, `TestBus.recorder.envelopes`, `RecordedEnvelope.topic` and `RecordedEnvelope.envelope`.

Not here: the widget-test helpers that build a production-provider bus inside a `testWidgets` body and shut it down at unmount (flutter-binding@v1, ADR-003 item 7); the navigation executor's in-memory test router (navigation-api@v1); `fake_async` interoperation, which ADR-003 rules out.

## Interface

**Library:** `package:nidana_dart_runtime/testing.dart`, the second public library of `nidana_dart_runtime` at `packages/nidana_dart_runtime/` (ADR-002 item 3). It exports the six declarations below and nothing else: a test imports the main library and `nidana_dart_contracts` itself, as shell code does (G1). It imports nothing beyond the SDK, `nidana_dart_contracts`' public libraries, the package's own libraries, `clock` and `meta`, so the package gains no dependency for it (bus-api@v1 G39). **Code owner:** nidana.runtime. `TestBus`, `VirtualSchedulerProvider` and the recorder seam share the `lib/src/` library that declares `Bus` and `SchedulerProvider` (bus-api@v1 Refinement 1), so the phase that lands bus-api@v1's declarations, nidana.runtime.1, lands every declaration below with them, first in the node's order (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/fixture/bus-testing/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.runtime.1 lands every declaration, in the library that declares `Bus` (bus-api@v1 Refinement 1); a consumer's `contract` edge waits on it (nidana.tooling), and a `hard` edge waits on nidana.runtime.14, the last producing phase (nidana.navigation, nidana.flutter, nidana.integration). Until the phase that delivers it merges, a body that computes throws `UnimplementedError`. A behavior guarantee is delivered by the phase whose gate first replays it. Cumulatively: nidana.runtime.5 delivers G5 to G8, G10 and G11 (the scheduler, `VirtualSchedulerProvider` and the `TestBus` constructor); nidana.runtime.13 G3 and G12 to G19; nidana.runtime.14 G4 and G9, and replays the binding unrestricted. nidana.runtime.7 lands the recorder seam (`EnvelopeRecorder.attach`, `envelopes`, `RecordedEnvelope`), whose guarantees replay from nidana.runtime.13 on. G1 and G2 hold from nidana.runtime.1; G20 holds at every phase, checked by `packages/nidana_dart_runtime/test/package_properties_test.dart` (nidana.runtime D9).

The declarations are the schema of this contract (ADR-001 item 4). Bodies are omitted; the comments, the terms and the guarantees state the semantics. `Clock` is `package:clock`'s.

### Terms

- **The scheduler's zone** is the zone a `VirtualScheduler` forks from the zone current when it is constructed. Code runs **inside** it when it runs in that zone or in a zone forked from it: the body of `run`, the scheduled work, and everything a bus on a virtual provider does in its provider zone (bus-api@v1 G5).
- **An operation** is a call of `triggerActions`, `advanceTimeBy`, `advanceTimeTo` or `settle`.
- **An action** is running one queued microtask or firing one due timer. A timer is **due** when its due instant is at or before the current virtual time.
- **Quiescent:** no microtask is queued and no timer is due.
- **A real turn** is one zero-duration timer that `settle` creates in the zone it was called from, which is outside the scheduler's zone, and awaits.

### Virtual time

```dart
/// The virtual provider (Spec §3.6; ADR-003 item 1). A bus constructed with
/// it runs in the scheduler's zone and reads the scheduler's clock.
final class VirtualSchedulerProvider extends SchedulerProvider {
  VirtualSchedulerProvider(VirtualScheduler scheduler);
  VirtualScheduler get scheduler;
}

/// Controllable virtual time (Spec §3.6, Appendix A.5; ADR-003 item 5).
final class VirtualScheduler {
  /// Forks the scheduler's zone from the zone current now. Throws
  /// ArgumentError when a bound is below 1.
  VirtualScheduler({
    DateTime? initialTime,     // null: defaultInitialTime
    int maxActions = 100000,   // actions one operation may run (G10)
    int maxSettleTurns = 20,   // real turns one settle may take (G12)
  });

  /// 2000-01-01T00:00:00.000Z.
  static final DateTime defaultInitialTime;

  /// The virtual clock; also package:clock's clock inside the zone.
  Clock get clock;
  int get maxActions;
  int get maxSettleTurns;

  // ---- the operations of Spec §3.6, synchronous
  void triggerActions();                        // G7
  void advanceTimeBy(Duration duration);        // G8
  void advanceTimeTo(DateTime timestamp);       // G8

  // ---- introspection (ADR-003 item 5)
  int get pendingMicrotaskCount;
  int get pendingTimerCount;                    // a periodic timer counts once
  DateTime? get nextTimerDue;                   // null when no timer is pending

  /// Runs [body] inside the scheduler's zone, synchronously, and returns its
  /// result; runs nothing queued (G6).
  R run<R>(R Function() body);

  /// The settle operation of ADR-003 item 6 (G12). Throws StateError at the
  /// call, returning no future, when called inside the scheduler's zone.
  Future<void> settle();
}
```

### The TestBus

```dart
/// A bus on virtual time that records every envelope it delivers (Spec
/// Appendix A.7), one per test case (Spec §3.1). bus-api@v1's one subtype
/// of Bus, so every bus-api@v1 guarantee holds for it.
final class TestBus extends Bus {
  /// The provider is config's VirtualSchedulerProvider, or a fresh one over a
  /// fresh VirtualScheduler when config names none; a config naming the
  /// production provider throws ArgumentError (ADR-003 item 6).
  TestBus([BusConfig config = const BusConfig()]);

  /// The source of every publish made through input and stub.
  static const ServiceSource testSource = ServiceSource('test');

  VirtualScheduler get scheduler;     // the provider's scheduler
  EnvelopeRecorder get recorder;      // attached at construction

  /// A publisher of testSource with no claims, created on first read: the
  /// test's path to event and replay topics (G18).
  Publisher get input;

  /// The writer through which the test stands in for the absent owner of
  /// [topic]: the writer, at this call's type argument, of one publisher of
  /// testSource claiming [topic] alone, at Scope.application, created on the
  /// first call for [topic] at any type argument (G18).
  StateWriter<T> stub<T>(StateTopic<T> topic);
}
```

### The envelope recorder

```dart
/// The envelopes delivered on one bus, from attachment on (Spec §3.5 "Where
/// Envelopes Are Visible"; Guide §10.1, C.4). Sensitive payloads are
/// redacted unless a read opts in with `unredacted` (Spec §9.2 item 2).
final class EnvelopeRecorder {
  /// Attaches a new recorder to [bus], whatever its provider. Throws
  /// StateError when [bus] is shut down.
  factory EnvelopeRecorder.attach(Bus bus);

  /// Every record, in delivery order; an unmodifiable snapshot.
  List<RecordedEnvelope> get envelopes;

  /// The delivered envelopes of [topic], in delivery order; an unmodifiable
  /// snapshot. Throws ArgumentError for a sensitive topic unless
  /// [unredacted] is true.
  List<MessageEnvelope<T>> envelopesOf<T>(Topic<T> topic, {bool unredacted = false});

  /// The payloads of envelopesOf(topic, unredacted: unredacted).
  List<T> payloadsOf<T>(Topic<T> topic, {bool unredacted = false});
}

/// One delivery as a recorder holds it. Made only by a recorder.
@immutable
final class RecordedEnvelope {
  TopicRef get topic;
  /// unredacted.redacted(): the delivered envelope itself when it is not
  /// sensitive, else the same envelope with RedactedPayload.of(payload).
  MessageEnvelope<Object?> get envelope;
  /// The delivered envelope itself: the explicit opt-in of Spec §9.2 item 2.
  MessageEnvelope<Object?> get unredacted;
  bool operator ==(Object other);     // topic and unredacted
  int get hashCode;
  String toString();                  // '{topic name} {envelope}', redacted
}
```

### The ordering probe

```dart
/// The per-topic ordering regression test of Guide §6.5, on any bus: several
/// subscriptions to one topic, compared (Spec §3.3).
final class OrderingProbe<T> {
  /// Subscribes [subscriptions] times to [topic] through bus.observe, now,
  /// one after another. Throws ArgumentError when [subscriptions] is below 2.
  factory OrderingProbe.attach(Bus bus, Topic<T> topic, {int subscriptions = 3});

  Topic<T> get topic;
  /// What each subscription has received, in subscription order; unmodifiable
  /// snapshots.
  List<List<T>> get received;
  /// Whether every subscription has received the same sequence.
  bool get isConsistent;
  /// Cancels every subscription without waiting on a cancel future; idempotent.
  void cancel();
}
```

Misuse that is not one of these throws the SDK's errors, as in bus-api@v1: `ArgumentError` for an argument the Interface excludes, `StateError` for an operation the state excludes.

### How a test uses it

The assertion API (decides the assertion half of OQ-R2) is plain Dart values, not matchers: the recorder returns lists of envelopes and payloads, typed by the topic, which a test compares with `==` (a TestBus makes whole envelopes predictable, G13), destructures with Dart patterns, or filters with `Iterable.where`, and asserts with whatever `expect` its runner provides. Topology test isolation (the other half of OQ-R2) needs no API beyond G18: a TestBus activates nothing on its own, so a test activates the topologies under test, publishes their event and replay inputs through `input`, and stands in for the absent owner of each state topic they read through `stub`.

- **A VM topology test** constructs a `TestBus`, activates the topologies under test before `start()`, publishes inputs, drives time with `scheduler.triggerActions()` and `scheduler.advanceTimeBy(...)`, and asserts on `recorder` and `getCurrentValue`, synchronously. It awaits `scheduler.settle()` only when a stub it completes from its own zone feeds the bus (ADR-003 item 6), and shuts the bus down in its tear-down (Spec §11.2).
- **A widget test** runs a production-provider bus built inside the `testWidgets` body, never a TestBus (ADR-003 item 7). It attaches `EnvelopeRecorder.attach(bus)` before `start()`, drives time with `tester.pump`, never awaits `settle`, and shuts the bus down before the body ends. A recorder adds no timer, so it never leaves one pending at unmount (G17).

## Guarantees / invariants

- **G1** `package:nidana_dart_runtime/testing.dart` exports exactly `TestBus`, `VirtualSchedulerProvider`, `VirtualScheduler`, `EnvelopeRecorder`, `RecordedEnvelope` and `OrderingProbe`, and re-exports nothing of the main library or of `nidana_dart_contracts`.
- **G2** The six are final and no type outside the package extends or implements any of them; `EnvelopeRecorder` and `OrderingProbe` are made only by their `attach` factories and `RecordedEnvelope` only by a recorder; `VirtualSchedulerProvider` and bus-api@v1's `ProductionSchedulerProvider` are the only subtypes of the sealed `SchedulerProvider`, so a switch that names both is exhaustive (bus-api@v1 Refinement 1).
- **G3** `TestBus(config)` (ADR-003 item 6) runs on `config.scheduler` when it is a `VirtualSchedulerProvider`, and on a fresh `VirtualSchedulerProvider` over a fresh `VirtualScheduler` when it is null, that scheduler constructed in the zone current when the TestBus is constructed, so its zone values and error handling are that zone's; a production provider throws `ArgumentError`. `scheduler` is the provider's scheduler, `config` is the config given, and a new TestBus is bootstrapping with nothing active, claimed, observed, recorded or pending. A TestBus is a `Bus` and meets every guarantee of bus-api@v1.
- **G4** A bus constructed with a `VirtualSchedulerProvider`, TestBus or not, runs in the scheduler's zone and reads its clock: `bus.clock` reads the scheduler's virtual time, and every timer and microtask the bus, its pipelines and its observed subscriptions create runs only inside a scheduler operation, never on a real event-loop turn, so a test that drives such a bus through bus operations and scheduler operations runs without `await`. Several buses may share one provider, and then share its clock and its queue.
- **G5** Virtual time starts at `initialTime`, by default `VirtualScheduler.defaultInitialTime`, 2000-01-01T00:00:00.000Z; it never reads the wall clock, moves only through `advanceTimeBy` and `advanceTimeTo`, and never moves backward; `package:clock`'s `clock` read inside the scheduler's zone is the scheduler's clock.
- **G6** Inside the scheduler's zone every `Timer`, periodic `Timer` and microtask is queued in the scheduler and never forwarded: none runs before an operation runs it, and none runs on real time. A virtual timer is a `dart:async` `Timer`: `isActive` until a one-shot timer fires or the timer is cancelled, `tick` counting its firings, `cancel` idempotent. `run(body)` runs `body` inside the scheduler's zone and returns its result, running nothing queued.
- **G7** `triggerActions()` runs the queued microtasks in the order they were queued, then the due timer with the earliest due instant, ties in creation order (a periodic timer ordered as if created when it last fired), running every microtask queued before each next timer, until the scheduler is quiescent; it does not move virtual time. A timer created with a zero or negative duration is due at the instant it was created.
- **G8** `advanceTimeBy(d)` runs `triggerActions()`, then repeatedly moves virtual time to the earliest due instant at or before the target and runs `triggerActions()` there, then sets virtual time to the target and runs `triggerActions()`; each timer therefore fires with the clock reading its due instant, a periodic timer fires once for each period crossed, and a timer created during the advance and due within it fires within it. `advanceTimeTo(t)` is `advanceTimeBy(t - now)`. A negative duration, or an instant before the current virtual time, throws `ArgumentError` and runs nothing.
- **G9** When an operation returns normally the scheduler is quiescent: `pendingMicrotaskCount` is 0 and `nextTimerDue` is null or after the current virtual time. `pendingTimerCount` counts the timers that are active, a periodic one once; `nextTimerDue` is the earliest due instant among them; a fired one-shot timer and a cancelled timer are not counted, so a test asserts that a bus cancelled a timer by its count.
- **G10** An operation called from inside work the scheduler is running throws `StateError` and runs nothing. An operation that would run more than `maxActions` actions throws `StateError` instead of running the next one, which stays queued, with virtual time at the instant it had reached; a later operation carries on from there. This is how a microtask loop or a zero-period periodic timer shows up. A `maxActions` or `maxSettleTurns` below 1 throws `ArgumentError`.
- **G11** Scheduled work runs guarded: an exception it throws goes to the uncaught-error handler of the zone it was scheduled in, which for work scheduled directly in the scheduler's zone, every bus timer and microtask included, is the handler of the zone the scheduler was constructed in; the operation goes on with the next action.
- **G12** `settle()` alternates `triggerActions()` with real turns and completes as soon as the scheduler is quiescent after a real turn; its future fails with `StateError` when the scheduler is still not quiescent after `maxSettleTurns` real turns. It never moves virtual time and leaves timers due later pending. Called inside the scheduler's zone, or from inside work it runs, it throws `StateError` at the call. Work a test starts outside the scheduler's zone, such as a future it completes, has reached the bus when `settle()` completes. The real turns are the only timers `nidana_dart_runtime` creates outside a provider zone (ADR-003 item 6).
- **G13** A TestBus generates envelope ids `e1`, `e2`, and so on, and fresh correlation ids `c1`, `c2`, and so on, each numbered from 1 per TestBus in the order the bus generates them, which meets bus-api@v1 G12. With the fixed initial time this makes a TestBus deterministic: two TestBuses with equal configs, whose schedulers have equal initial times, driven by the same operations in the same order with payloads that have value equality, record equal envelopes, timestamps included. A bus that is not a TestBus generates ids as bus-api@v1 states, whatever its provider.
- **G14** A recorder records each delivery that starts after `attach` returns, at that delivery, before the permitted observers are called (bus-api@v1's delivery rule), as one record of the topic's reference and the delivered envelope, in delivery order; recorders on one bus are called in the order they were attached. It records `Tracing.disabled` and sensitive topics, whether or not anything observes or subscribes to them; a publish queued before `start()` when `start()` delivers it; a state publish equal to the current value, which bus-api@v1 G16 delivers; and the deliveries of the shutdown drain. It records nothing that is not a delivery: a publish that is discarded before delivery, a subscription's first value, a read that dedup skips. Records stay readable after shutdown. `TestBus.recorder` is attached when the TestBus is constructed, so it holds every delivery of the TestBus.
- **G15** Sensitive payloads are redacted by default (Spec §9.2 item 2): `RecordedEnvelope.envelope` is `unredacted.redacted()` (topic-model@v1 G15), the delivered envelope itself for a non-sensitive topic and, for a sensitive one, the same envelope with `RedactedPayload.of(payload)`; `unredacted` is the delivered envelope itself; the `toString()` of a record, and so of a list of records, never renders a sensitive payload; `envelopesOf` and `payloadsOf` throw `ArgumentError` for a sensitive topic unless `unredacted` is true.
- **G16** `envelopes` is the records in delivery order; `envelopesOf<T>(topic)` is, for each record whose topic is `topic.ref`, in delivery order, the delivered envelope itself when it is a `MessageEnvelope<T>`, and otherwise, for an envelope published through a widened reference (bus-api@v1 G41), an equal `MessageEnvelope<T>` built from its eight fields with the payload converted at `T` (topic-model@v1 G12, G13); the list is therefore typed by the topic, and identical to the envelopes delivered except those published through a widened reference, to which it is equal; `payloadsOf<T>(topic)` is their payloads; a payload that is not a `T`, possible only for a value bus-api@v1 G41 lets a widened reference pass, makes both queries throw `TypeError`. Every list the recorder returns is unmodifiable and is a snapshot that later deliveries leave unchanged. Two records are equal, with equal hash codes, exactly when their topics and their delivered envelopes are equal.
- **G17** `EnvelopeRecorder.attach` works on a bus with either provider, a TestBus included, and throws `StateError` on a bus that is shut down; several recorders on one bus each record from their own attachment. A recorder is not an observer and counts against no limit of bus-api@v1 G10, creates no timer or microtask and holds no subscription, so attaching one leaves nothing pending.
- **G18** Test isolation (decides OQ-R2): a TestBus activates nothing on its own, so the topologies a test activates are the only ones active. `input` is one publisher of `TestBus.testSource`, `ServiceSource('test')`, with no claims, created on its first read and the same publisher on every later read. `stub(topic)` is the writer, at the call's type argument, of one publisher of `testSource` that claims `topic` alone at `Scope.application`, created on the first call for `topic` at any type argument, and the same writer on every later call with the same type argument (bus-api@v1 G20, G41); a claim that bus-api@v1 G20 rejects throws `ClaimRejected` and claims nothing. After shutdown a call that would construct a publisher throws `StateError`, and so does publishing through one constructed before (bus-api@v1 G36).
- **G19** `OrderingProbe.attach(bus, topic)` subscribes `subscriptions` times to `topic` through `bus.observe`, one after another, before it returns; `received` holds, per subscription in subscription order, the payloads it has received, which for a state or replay topic start with what bus-api@v1 G17 delivers first; `isConsistent` holds exactly when every subscription has received the same sequence; `cancel` cancels every subscription without waiting on a cancel future, is idempotent, and nothing is received after it. On a conforming bus the probe is consistent after any publishes, reentrant ones included, which is the per-topic ordering property of Spec §3.3 that Guide §6.5 requires a regression test for.
- **G20** `testing.dart` imports neither `package:test` nor `package:flutter_test`, and adds no dependency to `nidana_dart_runtime` (ADR-002 item 4, bus-api@v1 G39); nothing in it reads `DateTime.now()`, constructs a `Stopwatch` directly, or creates a timer or microtask outside a provider zone, except the real turns of G12 (ADR-003 items 6 and 8).

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates.
- Breaking for this contract: removing, renaming or retyping any declaration; a third scheduler provider (bus-api@v1 states the same); changing the default initial time, a default bound, the id format, the drain order, what one operation runs, what settle waits for, the redaction default, what a recorder records or in which order, or the source `input` and `stub` publish with.
- Compatible: a new getter or method on any of the six final classes, a new query on `EnvelopeRecorder`, a new optional named parameter with a default that keeps current behavior on `VirtualScheduler`, `EnvelopeRecorder.attach` or `OrderingProbe.attach`, a second optional positional parameter on `TestBus` that keeps current behavior, a new guarantee that existing fixtures still pass.
- Amended within v1, from nidana.runtime's phase plan (its D6 and D7), drained by hsdd-reconcile on 2026-10-18: (a) G16: for an envelope published through a widened reference, `envelopesOf` returns an equal envelope typed at its type argument where the earlier wording required the identical one, and a payload of another type makes both queries throw `TypeError`; (b) G18 and the comment on `TestBus.stub`: one publisher per topic, and its writer per type argument, where the earlier wording promised one writer for every call. Compatible: identity still holds wherever the earlier wording could hold it, because only a publish through a widened reference makes an envelope of another type argument, and for that one the earlier wording made the query throw a `TypeError` (`docs/auto-run/experiments/bus-api-widened/`, probe P2); `stub` changes only for one topic called at two type arguments, where the earlier wording could not hold, since a writer handed out through a widened reference cannot be returned to a later typed call (T7 there), and one publisher per topic keeps the one claim bus-api@v1 G20 allows; no fixture of any contract compares such an envelope by identity or stubs one topic at two type arguments; one new case each covers (a) and (b), and every case of every suite that imports `nidana_dart_runtime` passes against a stand-in that meets them (`docs/auto-run/experiments/runtime-reconcile-amends/`). The Breaking list above stands; a later change to either rule is breaking.
- Not in v1, each a candidate for a later version: a replay API (Guide C.4 lists "capture, replay, and assertion APIs"); replaying payloads is a loop over `payloadsOf` and `input`, while replaying envelopes with their lineage would need a publish path that sets ids, causation and source, which bus-api@v1 does not have (G12 there, Spec §3.11); `package:matcher` matchers over envelopes; detaching a recorder; a per-call settle bound; cross-platform test parity (Guide §10.1, root D1).

## Validation

- fixture: `hsdd/contract/fixture/bus-testing/`, under `hsdd/contract/fixture/analysis_options.yaml` (ADR-001 item 2); replayed with `fvm dart run nidana_contract_check bus-testing`.
- surface: `hsdd/contract/fixture/bus-testing/surface/` (`test_bus.dart`, `scheduler.dart`, `recording.dart`) uses every declaration with the types the Interface states, assigns a TestBus to `Bus`, constructs a plain `Bus` on a virtual provider, and switches over `SchedulerProvider` naming both providers with no catch-all, so a third provider fails the surface set.
- reject: `hsdd/contract/fixture/bus-testing/reject/`, one library per type-level guarantee: `testing_exports_only_its_own.dart` (G1), `testing_types_are_closed.dart` (G2).
- behavior: conformance library `hsdd/contract/fixture/bus-testing/behavior/bus_testing_conformance.dart`, harness `BusTestingHarness`, cases `busTestingConformance`, covering G3 to G19. The cases construct `testing.dart`'s declarations directly, which have no second implementation, so the harness supplies only `settle`. Cases that let real time pass or await `settle` need a real event loop (ADR-003 item 6), so the suite is bound under `dart test` only.
- binding: `hsdd/contract/fixture/bus-testing/behavior/nidana_dart_runtime_test.dart` binds the suite to `package:nidana_dart_runtime/testing.dart`, under `dart test`. It must pass every case of `busTestingConformance`.
- The last clause of G3, that a TestBus meets every bus-api@v1 guarantee, is checked by bus-api@v1's two bindings, which run the bus-api suite and topology-dsl@v1's live suite on fresh TestBus instances (bus-api@v1 Validation).
- The per-topic ordering regression test of Guide §6.5 runs as bus-api@v1's G13 cases and this contract's G19 cases, in nidana.runtime's gates and, through `--all`, in nidana.integration's gate. An application runs it on its own buses with `OrderingProbe`.
- The binding's package import names the implementation, so the replay tool reports it as `PENDING` until `nidana_dart_runtime` exists (ADR-001 item 9). It runs in nidana.runtime's gates; nidana.integration's gate runs it with `--all`.
- type-level guarantees G1 and G2 are checked by the reject and surface sets.
- not executable: G20, a property of the package's imports and sources rather than of its declarations; checked by nidana.runtime's gates
- No schema: an `api` contract with no serialized form carries none (ADR-001 item 4).
- The fixtures are forward references, written before the package exists. In `docs/auto-run/experiments/bus-testing-fixtures/` (`run.sh`, `output.txt`) the surface set analyzed clean and every reject code was confirmed against a stand-in runtime whose `testing.dart` implements this Interface on the stand-in bus of `docs/auto-run/experiments/bus-api-fixtures/`; this suite passed 45 of 45 cases against it; bus-api@v1's two bindings passed against it unchanged, 86 and 43 cases, with deterministic ids; and each of 34 seeded defects in the stand-in failed the cases of the guarantee it breaks. `output-settle.txt` there records the settle facts G12 rests on. The first replay against the real package, once nidana.model's first phase lands the replay tool, is their first verification (ADR-001 Consequences).
- The v1 amendment (`## Versioning`) is checked in `docs/auto-run/experiments/runtime-reconcile-amends/` (`run.sh`, `output.txt`), on the stand-in of `docs/auto-run/experiments/bus-api-widened/` patched so that `envelopesOf` builds an equal envelope at its type argument for a record of another type argument and `stub` keeps one publisher per topic. This suite passed 47 of 47 cases on the patched stand-in, bus-api@v1's two bindings 98 of 98 and 43 of 43, and every other suite that imports `nidana_dart_runtime` passed unchanged; on the unpatched stand-in the new G16 and G18 cases fail and every other case passes. An `envelopesOf` that skips a record of another type argument, one that skips a payload that is not a `T` instead of throwing, and a `stub` that makes a publisher per type argument each fail the case of what they break.
