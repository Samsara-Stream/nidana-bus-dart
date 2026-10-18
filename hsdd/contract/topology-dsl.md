---
id: topology-dsl
version: v1
status: draft
kind: api
owner: nidana.model
compatibility: versioned
produced_by: [nidana.model.4, nidana.model.9, nidana.model.11]
consumers: [nidana.runtime.1, nidana.runtime.9, nidana.runtime.10, nidana.runtime.11, nidana.runtime.12, nidana.runtime.14, nidana.navigation, nidana.flutter, nidana.tooling, nidana.integration]
external_consumers: [app topology modules, app topology tests]
phase_ids: provisional
---

# Contract: topology-dsl

- **Governed by:** [ADR-001, ADR-002, ADR-003]

The topology declaration API (Spec §2.2, §6.1 to §6.5): the class and builder forms of a topology, the builder, the opaque stream handle and every combinator, the per-read dedup opt-out, the typed topology identifier, and the plan a declaration records. A declaration runs once against the builder and produces a `TopologyPlan`: an immutable value whose stages hold the functions the declaration passed. Two things are done with a plan. Recording projects it to the IR, `TopologyDefinition` (topology-ir@v1), which holds no function. Live activation interprets it into subscriptions; that interpretation is nidana.runtime's, and bus-api@v1 declares its entry point. This contract fixes both: what a plan records, and what a live implementation must do with each stage.

## Boundary

topic-model@v1's Boundary assigned this contract the topology API. This contract keeps that assignment and refines it in four places:

| Declaration group | Contract |
|-------------------|----------|
| `Topology`, `topology(id, scope, declare)`, `TopologyRef`, `TopologyBuilder`, `TopicStream` and every combinator, the per-read dedup argument, `PipelineValue`, `RetryPolicy`, `RawOperator` | topology-dsl@v1, main library |
| `TopologyPlan`, `planOf`, the stage classes, `PlanSink` and its two classes, `StageVisitor`, `SinkVisitor`, `visitStage`, `visitSink` | topology-dsl@v1, library `topology_plan.dart` (refinement 1) |
| `Topology.buildDefinition()` and `TopologyPlan.definition`, declared here with the return type `TopologyDefinition` that topology-ir@v1 declares; which `CombinatorKind` value each stage projects to (the combinator table below) | topology-dsl@v1 (refinement 2) |
| `TopologyDefinition` and its fields, `TransformEdge`, `CombinatorKind`, `FunctionRef` and the naming of a transformer (OQ-M1), the JSON form, graphs, renderers, every analysis over definitions | topology-ir@v1 |
| `Bus.activate`, `TopologyHandle`, activation checks, idempotency on `topologyId` (Spec §3.9), publish timing and reentrancy, the provider zone and clock | bus-api@v1, bus-testing@v1 |
| `Lineage`, `MessageEnvelope`, `Topic`, `Dedup`, `Scope`, `MessageSource` | topic-model@v1 |

- **Refinement 1.** The plan is the executable form of a declaration, and only a live implementation, a catalog or a test reads it. It sits in a second public library so that a topology module, which imports the main library alone, can neither name a stage nor obtain a plan (G2).
- **Refinement 2.** `buildDefinition()` returns `planOf(this).definition`. This contract fixes the definition's `topologyId`, `scope`, `reads` and `writes` (G12) and names the `CombinatorKind` of each stage. topology-ir@v1 declares the enum with exactly those values and fixes everything else about the definition: how stages and sinks become `TransformEdge` entries, and how a transformer is named.
- **Refinement 3.** The plan is the answer to OQ-M2: live activation obtains its transformers from the plan of a single `planOf` call, whose definition it checks, so `declare()` runs once per activation and the IR stays pure data (G18).
- **Refinement 4.** There is no combinator that selects among pipelines. A selection between topic pipelines is a `combine` over a configuration topic (for state-like pipelines) or a `withLatestFrom` gate per pipeline joined by `merge` (for event pipelines). `switchMap` selects among shell-provided streams.

Not here: the navigation resolver template (navigation-api@v1), the topology catalog scan (nidana.tooling, OQ-T1), dev-mode diagnostics for a terminated pipeline (bus-api@v1, root D8).

## Interface

**Libraries:** `package:nidana_dart_contracts/nidana_dart_contracts.dart`, the main library of `nidana_dart_contracts` at `packages/nidana_dart_contracts/`, carries every declaration under Topologies, The builder, The handle and Pipeline values; `package:nidana_dart_contracts/topology_plan.dart`, a second public library named by this contract (ADR-002 item 3), carries every declaration under The plan. The main library does not export the plan library's declarations. Both import nothing beyond the SDK, `package:meta` and the package's own libraries (topic-model@v1 G26). **Code owner:** nidana.model, whose first producing phase lands every declaration below (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/fixture/topology-dsl/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.model.4 lands every declaration, and with them topology-ir@v1's `TopologyDefinition`, which `buildDefinition()` returns; a consumer's edge on this contract waits on nidana.model.5, where topology-ir@v1's declarations complete the main library both contracts share. Until the phase that delivers it merges, a body that computes throws `UnimplementedError`: nidana.model.9 delivers recording, `planOf`, the stages, sinks and visitors (G10, G11, G13 to G17, and G9 but for `buildDefinition()`); nidana.model.11 delivers `buildDefinition()` and `TopologyPlan.definition` (G9, G12). G30 holds from nidana.model.4. G18 to G29 are the live implementation's (Live interpretation): nidana.runtime implements them, and they replay through bus-api@v1's `bus_activation_test.dart` from nidana.runtime.12 on (bus-api@v1 Delivery).

The declarations are the schema of this contract (ADR-001 item 4). Bodies are omitted; the comments, the combinator table and the guarantees state the semantics.

### Topologies

```dart
/// A topology in class form (Spec §6.1, Guide §6.3). Applications extend it;
/// a subclass is final, base or sealed. Annotated @immutable: a topology is
/// inert data (Spec §2.2).
@immutable
abstract base class Topology {
  const Topology();

  /// Module-local (Spec §4.6); non-empty.
  String get topologyId;

  /// Declared explicitly (Spec §7.2).
  Scope get scope;

  /// Pure wiring (Spec §6.1): builder and handle calls only. Runs once per
  /// planOf call, never at construction.
  void declare(TopologyBuilder b);

  /// The IR (Spec §6.5): planOf(this).definition.
  @nonVirtual
  TopologyDefinition buildDefinition();
}

/// The builder shorthand (Spec §6.1). Throws ArgumentError for an empty
/// [topologyId]; [declare] runs on each planOf call.
Topology topology(
  String topologyId,
  Scope scope,
  void Function(TopologyBuilder b) declare,
);

/// A typed, module-local topology identifier (Spec §4.6). Equal by id.
@immutable
final class TopologyRef {
  const TopologyRef(String id);
  String get id;
  bool operator ==(Object other);
  int get hashCode;
}
```

A registry never declares a `TopologyRef`, and nothing in this package exports one (Spec §4.6); an application keeps its references module-private. Both forms produce the same plan for the same wiring (Spec §6.1).

### The builder

```dart
/// The only builder (Spec §6.5): it records the declaration into a plan.
/// Final, no public constructor; planOf creates one per call.
final class TopologyBuilder {
  /// A read of [topic] (Spec §6.1). [dedup] overrides a StateTopic's own
  /// policy for this read only (Spec §3.12); null keeps it. A non-null
  /// [dedup] on an EventTopic or ReplayTopic read throws ArgumentError.
  TopicStream<T> read<T>(Topic<T> topic, {Dedup? dedup});

  /// Writes every value of [stream] to [topic]. The stream's value type is
  /// the topic's or a subtype of it (G3).
  void write<T, S extends T>(Topic<T> topic, TopicStream<S> stream);

  /// Folds [events] into [topic], which this topology then owns, seeded with
  /// the topic's current value at activation (Spec §6.3, §7.2).
  void reduceInto<S, E>(
    StateTopic<S> topic,
    TopicStream<E> events,
    S Function(S state, E event) reducer,
  );

  TopicStream<R> combine2<A, B, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    R Function(A a, B b) combiner,
  );
  TopicStream<R> combine3<A, B, C, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(A a, B b, C c) combiner,
  );
  TopicStream<R> combine4<A, B, C, D, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(A a, B b, C c, D d) combiner,
  );

  /// [combiner] receives an unmodifiable list of the inputs' latest values,
  /// in input order. Throws ArgumentError for an empty [inputs].
  TopicStream<R> combineAll<T, R>(
    List<TopicStream<T>> inputs,
    R Function(List<T> values) combiner,
  );

  /// Throws ArgumentError for an empty [inputs].
  TopicStream<T> merge<T>(List<TopicStream<T>> inputs);
}
```

A topology declares a sink (`write` or `reduceInto`) on a given StateTopic at most once; a second one throws ArgumentError (G14). Event and replay topics take any number of writes. Whether the topic is owned by another topology or a publisher is checked at activation (bus-api@v1, Spec §3.11), not here.

### The handle

```dart
/// The opaque stream handle (Spec §6.1): a stage of the plan. Sealed; made
/// only by the builder and by its own methods. It has no synchronous value
/// accessor, is not a Stream and has no listen (G1).
sealed class TopicStream<T> {
  TopicStream<R> map<R>(R Function(T value) transform);
  TopicStream<T> filter(bool Function(T value) test);

  TopicStream<R> withLatestFrom<B, R>(
    TopicStream<B> latest,
    R Function(T value, B latest) combiner,
  );
  TopicStream<R> withLatestFrom2<B, C, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(T value, B b, C c) combiner,
  );
  TopicStream<R> withLatestFrom3<B, C, D, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(T value, B b, C c, D d) combiner,
  );

  /// [toStream] is the shell's stream factory (Spec §6.3); [retry] is the
  /// timed retry of its inner stream (ADR-003 item 4).
  TopicStream<R> switchMap<R>(
    Stream<R> Function(T value) toStream, {
    RetryPolicy? retry,
  });

  TopicStream<S> scan<S>(S initial, S Function(S accumulated, T value) accumulator);
  TopicStream<({T previous, T current})> pairwise();
  TopicStream<T> distinctUntilChanged();

  /// Time-dependent combinators (Spec §3.6, §6.3) take a Duration and no
  /// scheduler (ADR-003 item 4). A negative duration throws ArgumentError.
  TopicStream<T> debounce(Duration duration);
  TopicStream<T> throttle(Duration duration);
  TopicStream<T> delay(Duration duration);
  TopicStream<T> sample(Duration duration);
  TopicStream<List<T>> buffer(Duration duration);
  TopicStream<T> timeout(Duration duration);

  /// Turns a shell-boundary failure into a value (Spec §6.3, §10.2).
  TopicStream<T> catchError(T Function(Object error, StackTrace stackTrace) recover);

  /// The raw-engine escape hatch (Spec §3.5 "Escape Hatch").
  TopicStream<R> rawEngine<R>(RawOperator<T, R> operator);
}
```

Every builder and handle method throws StateError once the declaration that made the builder has returned, and ArgumentError when a handle it is given was made by another builder (another declaration, or another `planOf` call of the same one) (G14, G15). Topology bodies compose only through these methods; the engine is reachable only through `rawEngine` (root D6).

### Pipeline values

```dart
/// A value inside a live pipeline (Spec §3.5): its payload and the lineage
/// its next published envelope will carry (topic-model@v1 Lineage).
typedef PipelineValue<T> = ({T payload, Lineage lineage});

/// switchMap's retry: the delay before toStream(value) is called again after
/// the inner stream's [attempt]-th error for the current outer value
/// (1-based), or null to let the error through.
typedef RetryPolicy = Duration? Function(Object error, int attempt);

/// The raw operator: given the stage input's values, and a source of fresh
/// correlation ids for Lineage.combine, it returns the stage's values. The
/// author applies the lineage rules (Spec §3.5).
typedef RawOperator<T, R> = Stream<PipelineValue<R>> Function(
  Stream<PipelineValue<T>> values,
  String Function() freshCorrelationId,
);
```

Transformers see payloads only (Spec §2.4, §6.2); `PipelineValue` and `Lineage` reach a declaration only through `rawEngine`.

### The plan

Library `package:nidana_dart_contracts/topology_plan.dart`.

```dart
/// Runs topology.declare once against a fresh builder and returns its plan.
/// Throws StateError when topologyId is empty or a stage reaches no sink;
/// an error declare throws, a builder's ArgumentError included, propagates.
TopologyPlan planOf(Topology topology);

/// The executable form of one declaration (Spec §6.5).
@immutable
final class TopologyPlan {
  String get topologyId;
  Scope get scope;

  /// Every stage, in the order the declaration created them; unmodifiable.
  /// A stage's inputs precede it.
  List<TopicStream<Object?>> get stages;

  /// Every write and reduceInto, in declaration order; unmodifiable.
  List<PlanSink> get sinks;

  /// The IR projected from this plan (topology-ir@v1); equal to
  /// topology.buildDefinition() for a deterministic declaration.
  TopologyDefinition get definition;
}

/// Passes [stage] to the visitor method of its class, binding the stage's
/// type arguments; likewise visitSink.
V visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor);
V visitSink<V>(PlanSink sink, SinkVisitor<V> visitor);

/// Implemented by a live implementation's interpreter, and by any reader
/// that needs a stage's type arguments.
abstract interface class StageVisitor<V> {
  V read<T>(ReadStage<T> stage);
  V map<T, R>(MapStage<T, R> stage);
  V filter<T>(FilterStage<T> stage);
  V combine<R>(CombineStage<R> stage);
  V withLatestFrom<T, R>(WithLatestFromStage<T, R> stage);
  V merge<T>(MergeStage<T> stage);
  V switchMap<T, R>(SwitchMapStage<T, R> stage);
  V scan<T, S>(ScanStage<T, S> stage);
  V pairwise<T>(PairwiseStage<T> stage);
  V distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage);
  V debounce<T>(DebounceStage<T> stage);
  V throttle<T>(ThrottleStage<T> stage);
  V delay<T>(DelayStage<T> stage);
  V sample<T>(SampleStage<T> stage);
  V buffer<T>(BufferStage<T> stage);
  V timeout<T>(TimeoutStage<T> stage);
  V catchError<T>(CatchErrorStage<T> stage);
  V rawEngine<T, R>(RawEngineStage<T, R> stage);
}

abstract interface class SinkVisitor<V> {
  V write<T>(WriteSink<T> sink);
  V reduceInto<S, E>(ReduceIntoSink<S, E> sink);
}

// The stage classes: each final, extending TopicStream, no public
// constructor. Every member holds the value the declaration passed,
// identical to it (G11).
final class ReadStage<T> extends TopicStream<T> {
  Topic<T> get topic;
  Dedup? get dedup;                       // as given; null keeps the topic's
}
final class MapStage<T, R> extends TopicStream<R> {
  TopicStream<T> get input;
  R Function(T value) get transform;
}
final class FilterStage<T> extends TopicStream<T> {
  TopicStream<T> get input;
  bool Function(T value) get test;
}
/// combine2, combine3, combine4 and combineAll.
final class CombineStage<R> extends TopicStream<R> {
  List<TopicStream<Object?>> get inputs;  // unmodifiable, in input order
  Function get combiner;                  // the function the declaration passed
  /// Calls combiner with [values], the inputs' latest payloads in input order.
  R apply(List<Object?> values);
}
/// withLatestFrom, withLatestFrom2 and withLatestFrom3.
final class WithLatestFromStage<T, R> extends TopicStream<R> {
  TopicStream<T> get primary;
  List<TopicStream<Object?>> get latest;  // unmodifiable, in argument order
  Function get combiner;
  R apply(T value, List<Object?> latest);
}
final class MergeStage<T> extends TopicStream<T> {
  List<TopicStream<T>> get inputs;        // unmodifiable
}
final class SwitchMapStage<T, R> extends TopicStream<R> {
  TopicStream<T> get input;
  Stream<R> Function(T value) get toStream;
  RetryPolicy? get retry;
}
final class ScanStage<T, S> extends TopicStream<S> {
  TopicStream<T> get input;
  S get initial;
  S Function(S accumulated, T value) get accumulator;
}
final class PairwiseStage<T> extends TopicStream<({T previous, T current})> {
  TopicStream<T> get input;
}
final class DistinctUntilChangedStage<T> extends TopicStream<T> {
  TopicStream<T> get input;
}
final class DebounceStage<T> extends TopicStream<T> {
  TopicStream<T> get input;
  Duration get duration;
}
// ThrottleStage<T>, DelayStage<T>, SampleStage<T> and TimeoutStage<T> have
// the same two members as DebounceStage<T>; BufferStage<T> has them too and
// extends TopicStream<List<T>>.
final class CatchErrorStage<T> extends TopicStream<T> {
  TopicStream<T> get input;
  T Function(Object error, StackTrace stackTrace) get recover;
}
final class RawEngineStage<T, R> extends TopicStream<R> {
  TopicStream<T> get input;
  RawOperator<T, R> get operator;
}

/// A write or a reduceInto. Sealed; no public constructor.
sealed class PlanSink {
  Topic<Object?> get topic;
}
final class WriteSink<T> extends PlanSink {
  Topic<T> get topic;
  TopicStream<T> get input;
}
final class ReduceIntoSink<S, E> extends PlanSink {
  StateTopic<S> get topic;
  TopicStream<E> get events;
  S Function(S state, E event) get reducer;
}
```

An interpreter reaches a stage's functions through `visitStage`, which binds the stage's type arguments. Reading a function-typed member through a pattern such as `MapStage<Object?, Object?>()` fails at run time, because the member's type is contravariant in a type argument.

Stages, sinks, builders and plans keep `Object`'s `==` and `hashCode` (G30): two reads of one topic are two stages, each interpreted once (Live interpretation items 2 and 3), and an interpreter may key a map by stage.

### Combinators

One row per builder or handle call. "Emits" is what a live implementation's stage delivers to its consumers. "Lineage" is the lineage each output carries, applying topic-model@v1's Lineage functions ("How the lineage functions are applied"). "Self-reference" says whether the stage mediates a read of a topic the same topology writes (Spec §3.8): topology-ir@v1's self-reference analysis accepts a path from such a read to its write only through a stage marked yes.

| Call | Plan class | `CombinatorKind` | Emits | Lineage | Self-reference |
|------|------------|------------------|-------|---------|----------------|
| `b.read(topic, dedup:)` | `ReadStage<T>` | none | state topic: the current value when the activation connects, then each later value its effective dedup lets through (`dedup ?? topic.dedup`; `Dedup.equality`: no value `==` to the one it delivered last); replay topic: the buffer when the activation connects, then each later value; event topic: each later value | `Lineage.causedBy(envelope)`; `Lineage.root()` for a `Tracing.disabled` topic and for a state topic's declared initial value, which no message caused | no |
| `s.map(f)` | `MapStage<T, R>` | `map` | `f(v)` for each value | the input's | no |
| `s.filter(test)` | `FilterStage<T>` | `filter` | each value `test` accepts | the input's | no |
| `b.combine2`, `combine3`, `combine4`, `combineAll` | `CombineStage<R>` | `combine` | once every input has a value, then on each input value: the combiner of the inputs' latest values, in input order | `Lineage.combine` of the inputs' latest lineages, the emitting input as trigger | no |
| `s.withLatestFrom`, `2`, `3` | `WithLatestFromStage<T, R>` | `withLatestFrom` | on each primary value, once every latest input has a value: the combiner of the primary value and the latest values; earlier primary values are dropped | `Lineage.withLatestFrom(primary, latest)` | no |
| `b.merge(inputs)` | `MergeStage<T>` | `merge` | the values of every input, in arrival order | each value's own | no |
| `s.switchMap(toStream, retry:)` | `SwitchMapStage<T, R>` | `switchMap` | the values of `toStream(v)` for the latest outer value `v`; on each outer value it cancels the previous inner subscription without waiting for its cancel future and listens to the next inner stream within the same delivery (ADR-003 item 3); retry per `RetryPolicy` | the outer value's | no |
| `s.scan(initial, f)` | `ScanStage<T, S>` | `scan` | each accumulated value, never `initial` | the input's | yes |
| `s.pairwise()` | `PairwiseStage<T>` | `pairwise` | `(previous: p, current: v)` for each value from the second | the current value's | no |
| `s.distinctUntilChanged()` | `DistinctUntilChangedStage<T>` | `distinctUntilChanged` | each value not `==` to the value before it | the input's | no |
| `s.debounce(d)` | `DebounceStage<T>` | `debounce` | a value once `d` has passed with no newer value | the surviving value's | when `d` is positive |
| `s.throttle(d)` | `ThrottleStage<T>` | `throttle` | a value when none was emitted in the preceding `d`; the others are dropped | the emitted value's | no |
| `s.delay(d)` | `DelayStage<T>` | `delay` | each value, `d` later | the value's | when `d` is positive |
| `s.sample(d)` | `SampleStage<T>` | `sample` | at the end of each period `d`, counted from the first value, the most recent value if one arrived in that period | the emitted value's | when `d` is positive |
| `s.buffer(d)` | `BufferStage<T>` | `buffer` | at the end of each period `d`, counted from the first value, the values of that period as an unmodifiable list, never an empty one | the last value of the batch's | when `d` is positive |
| `s.timeout(d)` | `TimeoutStage<T>` | `timeout` | each value; a `TimeoutException` error when `d` passes, after the activation connects or after the last value or error, with neither; one error per such silence | the value's; the error carries none | no |
| `s.catchError(recover)` | `CatchErrorStage<T>` | `catchError` | each value; `recover(error, stackTrace)` in place of each error, after which the stage goes on | the value's; a recovered value carries the error's lineage | no |
| `s.rawEngine(operator)` | `RawEngineStage<T, R>` | `rawEngine` | what the stream `operator` returns emits | what the operator sets | no |
| `b.write(topic, s)` | `WriteSink<T>` | none | publishes each value to `topic` | the value's | no |
| `b.reduceInto(topic, events, f)` | `ReduceIntoSink<S, E>` | `reduceInto` | publishes `f(state, e)` for each event `e`, `state` starting as the topic's current value at activation and becoming each published value; nothing at activation | the event's | yes |

**Errors and lineage.** An error inside a live pipeline carries the lineage the stage that raised it would have given its output: a transformer, predicate, combiner, accumulator or recover function that threw raises an error with the lineage of the value it was called for; a switchMap inner stream, or a `toStream` that threw, raises one with its outer value's lineage. A `timeout` error, an error a raw operator emits, and an error that passed through a raw operator carry none, and a `catchError` recovers them with `Lineage.root()`. A raw operator receives each error as the object that was raised. An error passes through every other stage unchanged. An error that reaches a sink ends that sink for the rest of the activation (Spec §10.2): it publishes nothing more, the topology's other sinks go on, and the error is not rethrown to any caller; how it is reported is bus-api@v1's (root D8).

**Retry.** When the current inner stream raises an error, or `toStream` throws, switchMap calls `retry(error, attempt)`, where `attempt` counts those errors for the current outer value from 1. A duration `d`: the inner subscription is cancelled, without waiting, and `toStream(value)` is called again `d` later on the provider clock, the error not going downstream. Null, or no policy: the error goes downstream. A newer outer value cancels a pending retry and restarts the count.

### Recording

Recording is `planOf` and `buildDefinition()`; it is pure. It runs `declare` once against a fresh builder, calls none of the functions the declaration passes, creates no timer, schedules no microtask and touches no bus (Spec §6.5). Each builder or handle call adds exactly one stage or sink. A plan's definition has the topology's id and scope, reads the set of `topic.ref` of its read stages, and writes the set of `topic.ref` of its sinks' topics (G12); its transforms are topology-ir@v1's. A declaration whose stages do not all reach a sink is rejected (G15): a handle that feeds nothing is almost always a forgotten write, and it would show as a read in the definition that nothing live performs.

### Live interpretation

A live implementation (nidana.runtime, entry point declared by bus-api@v1) does the following with a topology. This is the semantics the live conformance suite checks (G18 to G29).

1. **One plan per activation.** It calls `planOf` once, runs its activation checks on that plan's `definition` (Spec §3.8, §3.9, §3.11, §7.2), and interprets the same plan. This decides OQ-M2.
2. **Stages are shared.** Each stage is interpreted once per activation; all its consumers, stages and sinks, receive the same emissions, so a function runs once per input value and a switchMap's `toStream` once per outer value, however many consumers the stage has.
3. **Connection after wiring.** Read stages start delivering only after every stage and sink of the activation is subscribed, so a value a read delivers at connection, a state topic's current value or a replay topic's buffer, reaches every consumer.
4. **Sinks publish with the topology as source.** A sink publishes through `MessageEnvelope.publishedTo` with the value's lineage and `TopologySource(topologyId)` as source (Spec §2.4). When the publish is delivered, and how reentrancy is normalized, is bus-api@v1's (Spec §3.4). When one value of a stage reaches several sinks that take that stage's handle, the sinks publish it in declaration order (Spec §3.3).
5. **Time is the provider's.** Subscriptions, timers and microtasks of the pipeline are made in the provider zone (ADR-003 item 2), the time-dependent stages are RxDart 0.28's operators or `Stream.timeout` applied there (ADR-003 item 4), and a virtual clock therefore drives them exactly.
6. **Deactivation.** It cancels every subscription and timer of the activation, inner subscriptions and pending retries included, without waiting for a cancel future (ADR-003 item 3); the topology's sinks publish nothing after it.

## Guarantees / invariants

- **G1** The read handle is opaque (Spec §6.1, root D6): `TopicStream<T>` declares no member that returns a current value or a `T` synchronously, is not a `Stream`, and has no `listen`, so reading a value to decide wiring does not compile, and neither does handing a handle to an engine operator or combinator.
- **G2** Handles, builders, stages, sinks and plans are made only by the DSL: `TopicStream` and `PlanSink` are sealed, `TopologyBuilder`, `TopologyPlan` and every stage and sink class are final, none has a public constructor, and the plan declarations are exported only from `topology_plan.dart`, so code that imports the main library alone cannot name a stage or obtain a plan.
- **G3** A write type-checks against its topic (Spec §4.2): `write(topic, stream)` compiles exactly when the stream's value type is the topic's value type or a subtype of it; inference does not widen the topic's type to admit an unrelated or a wider stream.
- **G4** `reduceInto` folds into a `StateTopic` only (Spec §6.3, §7.2): an event or replay topic as its target does not compile, nor does a reducer over another state type or an events handle of another type than the reducer takes.
- **G5** Every function a combinator takes, other than the raw operator, is typed over payload types (Spec §2.4, §3.5, §6.2): a transformer over `MessageEnvelope` or `Lineage`, or one whose parameter types do not fit the handles, does not compile.
- **G6** Time-dependent combinators take one `Duration` and no scheduler argument (Spec §3.6; ADR-003 item 4).
- **G7** A topology declares its id, its scope and its body (Spec §4.6, §6.1, §7.2): `topology()` takes all three, a subclass that leaves out `topologyId`, `scope` or `declare` does not compile, and `TopologyRef` takes a `String`.
- **G8** `Topology` is an immutable base class: it can be extended and not implemented, a subclass is final, base or sealed, `buildDefinition()` cannot be overridden, and a mutable field in a subclass is reported, so a topology's definition always comes from its own declaration (Spec §6.5).
- **G9** `planOf(t)` runs `t.declare` exactly once against a fresh builder and returns a plan with `t`'s id and scope; `buildDefinition()` runs `declare` once and equals `planOf(t).definition`; the `topology()` form runs its body on each `planOf` call and never at construction.
- **G10** Recording is inert (Spec §6.5): `planOf` and `buildDefinition()` call none of the functions the declaration passes, create no timer and schedule no microtask.
- **G11** Each builder or handle call adds exactly one stage, of the class the combinator table names, in call order, holding the handles, functions, durations and initial values it was given, identical to them; each `write` and `reduceInto` adds one sink, in call order; `apply` of a combine or withLatestFrom stage calls the declared function with the values in input order; a plan's lists are unmodifiable.
- **G12** A plan's definition has the topology's `topologyId` and `scope`, `reads` equal to the set of `topic.ref` of its read stages, and `writes` equal to the set of `topic.ref` of its sinks' topics.
- **G13** A read records its `dedup` argument, null when none is given; a non-null `dedup` on an event or replay topic read throws `ArgumentError` (Spec §3.12).
- **G14** A builder or handle call throws `ArgumentError` when given a handle another builder made, when it would add a second sink on one `StateTopic`, when given a negative duration, and when given an empty input list (`combineAll`, `merge`); a zero duration is accepted, and event and replay topics take any number of sinks.
- **G15** `planOf` throws `StateError` when a stage reaches no sink or the topology id is empty; `topology()` throws `ArgumentError` for an empty id; a builder or handle used after `declare` returned throws `StateError`.
- **G16** `visitStage` and `visitSink` pass each stage and sink to the visitor method of its class, with the stage or sink itself.
- **G17** Two topology references are equal, with equal hash codes, exactly when their ids are equal.
- **G18** A live implementation runs `declare` once per activation and interprets the plan whose definition it checked, a re-activation running it again (decides OQ-M2); every envelope a sink publishes has `TopologySource(topologyId)` as its source (Spec §2.4).
- **G19** A live read delivers what the combinator table states (Spec §2.1, §3.12, §7.4): a state topic's current value when the activation connects and then every later value its effective dedup lets through, `Dedup.none` delivering an equal publish too; a replay topic's buffer and then every later value; an event topic's later values only.
- **G20** Live `map`, `filter`, `scan`, `pairwise` and `distinctUntilChanged` emit what the combinator table states.
- **G21** Live `combine2`, `combine3`, `combine4`, `combineAll`, `withLatestFrom`, `withLatestFrom2`, `withLatestFrom3` and `merge` emit what the combinator table states, with values in input order.
- **G22** A live `switchMap` calls `toStream` once per outer value, delivers only the current inner stream's values, and on each outer value cancels the previous inner subscription without waiting for its cancel future and listens to the next inner stream within the same delivery, with no real event-loop turn (ADR-003 item 3); its retry follows the Retry rules, timed on the provider clock.
- **G23** Live `debounce`, `throttle`, `delay`, `sample`, `buffer` and `timeout` emit what the combinator table states, timed exactly by the implementation's clock (Spec §3.6, Rationale §3.2; ADR-003 item 4).
- **G24** A live `reduceInto` seeds its fold with the topic's current value at activation, publishes nothing at activation, publishes the reducer's result for each event, and after a deactivation and re-activation resumes from the retained value (Spec §6.3, §7.2).
- **G25** Every published envelope's causation, correlation and parent correlations follow the Lineage column of the combinator table and the Errors and lineage rules (Spec §2.4, §3.5; topic-model@v1 Lineage).
- **G26** Errors follow the Errors and lineage rules (Spec §10.2): `catchError` replaces an error by a value and its stage goes on; an error that reaches a sink, from a function that threw included, ends that sink for the activation while the topology's other sinks go on; a reducer that throws ends its `reduceInto` and the state keeps its last value.
- **G27** A live stage is interpreted once per activation and shared by all its consumers, so each of its functions runs once per input value; one value written by several sinks that take the same handle is delivered in sink declaration order (Spec §3.3).
- **G28** A live raw operator is called once per activation, with the stage input's values, and the values its stream emits, with their lineages, are what the next stage receives and what a sink publishes.
- **G29** After deactivation a topology's sinks publish nothing, and its inner subscriptions, pending retries and timers have been cancelled (Spec §2.2, §7.2).
- **G30** Every stage and sink class, `TopologyBuilder` and `TopologyPlan` keep `Object`'s `==` and `hashCode`: two stages, sinks, builders or plans are equal exactly when they are identical, so two reads of one topic are two stages, each interpreted once (Live interpretation items 2 and 3).

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates.
- Breaking for this contract: removing, renaming or retyping any declaration; adding a stage or sink class, or a method to `StageVisitor` or `SinkVisitor`, because every live implementation implements the visitors in full; adding a combinator, which adds a stage class; changing what a stage emits, its lineage rule, its `CombinatorKind`, its self-reference marking, the Errors and lineage rules or the Retry rules; adding a member to `Topology` that subclasses must implement.
- Compatible: a new optional named parameter with a default that keeps current behavior, on a builder or handle method or on `topology()`; a new guarantee that existing fixtures still pass.
- Amended within v1, from nidana.model's phase plan (its D3, nidana.model.4), drained by hsdd-reconcile on 2026-10-18: G30, the identity equality of stages, sinks, builders and plans, with a sentence under The plan and one recording case. Compatible: no declaration changes, the stand-ins every earlier fixture passed against already had identity equality (`docs/auto-run/experiments/topology-dsl-fixtures/`; the live stand-in keys stages by an identity map, `docs/auto-run/experiments/bus-api-widened/`), and every existing case still passes beside the new one (`docs/auto-run/experiments/model-reconcile-amends/`). Giving a stage value equality is now a breaking change.
- Not in v1, each a candidate for a later version: an explicit transformer name on a combinator (OQ-M1 is answered by derivation in topology-ir@v1); a selecting switch among pipelines (Refinement 4); `onErrorResumeNext`, whose fallback-state use is `catchError` (Guide §4); a multi-input `rawEngine`; count-based `buffer`; `distinctUntilChanged` with a custom equality; `combine5` and above (`combineAll` or nesting covers them); a trailing-edge `throttle`.

## Validation

- fixture: `hsdd/contract/fixture/topology-dsl/`, under `hsdd/contract/fixture/analysis_options.yaml` (ADR-001 item 2); replayed with `fvm dart run nidana_contract_check topology-dsl`.
- surface: `hsdd/contract/fixture/topology-dsl/surface/topologies.dart` uses every declaration of the main library: both topology forms, every builder and handle method, the typedefs and `buildDefinition()`. `surface/plan.dart` uses every declaration of the plan library and implements `StageVisitor` and `SinkVisitor` in full, so a stage or sink class added to the Interface fails the surface set.
- reject: `hsdd/contract/fixture/topology-dsl/reject/`, one library per type-level guarantee: `handle_is_opaque.dart` (G1), `dsl_types_are_closed.dart` and `plan_is_a_separate_library.dart` (G2), `write_type_checks.dart` (G3), `reduce_into_targets_state.dart` (G4), `transformers_see_payloads.dart` (G5), `time_takes_duration.dart` (G6), `topology_declares_id_and_scope.dart` (G7), `topology_is_a_base_class.dart` (G8).
- behavior, recording: conformance library `hsdd/contract/fixture/topology-dsl/behavior/recording_conformance.dart`, harness `RecordingHarness`, cases `recordingConformance`, covering G9 to G17 and G30. Its harness carries only `settle()`, because recording has one implementation by design.
- binding: `hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart` binds the recording suite to the producer's recording builder in `nidana_dart_contracts`, under `dart test`. It must pass every case of `recordingConformance`.
- behavior, live: conformance library `hsdd/contract/fixture/topology-dsl/behavior/live_conformance.dart`, harness `LiveTopologyHarness` with `LiveRun`, cases `liveConformance`, covering G18 to G29. The harness names no bus type: it is stated in topic-model@v1 and topology-dsl@v1 types and `Duration`. A binding adapts its live implementation to it: `start` constructs a fresh implementation on a virtual clock, activates the given topologies in order and starts it; `publish` publishes as shell code, through a writer that claims a state topic; `watch` subscribes with the topic's own dedup policy and records envelopes; `current` reads a state topic's current value; `advance` moves the clock and runs what is due, synchronously; `activate` and `deactivate` act on one topology; `settle` is the implementation's asynchronous settle. On nidana.runtime these map onto a `TestBus`, its publisher and writer handles, its envelope recorder or an envelope-level observe, `getCurrentValue`, `VirtualScheduler.advanceTimeBy`, topology handles, and bus-testing@v1's settle operation (ADR-003 items 5 and 6).
- live binding: this directory holds none. The live implementation's binding lives with the contract whose Interface declares that implementation (ADR-001 item 4): the behavior set of bus-api@v1's fixture directory, written by the bus-api@v1 step, importing `live_conformance.dart` by relative path. It must pass every case of `liveConformance`. nidana.runtime's gate runs it; nidana.model's gate does not, because recording has no live side. A consumer's stand-in that binds the suite in its own `test/` follows ADR-001 item 11.
- type-level guarantees G1 to G8 have no binding: the reject and surface sets check the declarations themselves.
- No schema: an `api` contract with no serialized form carries none (ADR-001 item 4). The IR's JSON form and its schema are topology-ir@v1's.
- The fixtures are forward references, written before the package exists. In `docs/auto-run/experiments/topology-dsl-fixtures/` (`run.sh`, `output.txt`) every reject code was confirmed against a stand-in that implements this Interface, the surface set analyzed clean, the recording suite passed against the stand-in's recorder, the live suite passed against a stand-in live implementation on RxDart 0.28 and a virtual scheduler, and seeded defects in both stand-ins failed the cases of the guarantee they break. `docs/auto-run/experiments/topology-dsl-typing/` settled the write signature of G3. The first replay against the real package, once nidana.model's first phase lands the replay tool, is their first verification (ADR-001 Consequences).
