<!-- hsdd-phase-context {"phase":"nidana.model.4","spec":"a8d43df","date":"2026-10-26"} -->
# Current Phase: nidana.model.4 - topology-dsl@v2 declarations

## Goal
every declaration of topology-dsl@v2's Interface, as D3 defines one: in the main library `Topology` (an `@immutable abstract base class` whose `buildDefinition()` is `@nonVirtual`), `topology()`, `TopologyRef`, `TopologyBuilder` (final, no public constructor) and `TopicStream` (sealed, no public constructor) with every combinator, `PipelineValue`, `RetryPolicy` and `RawOperator`; in the new public library `lib/topology_plan.dart`, whose names the main library does not export, `planOf`, `TopologyPlan`, the eighteen stage classes, `PlanSink`, `WriteSink`, `ReduceIntoSink`, `StageVisitor`, `SinkVisitor`, `visitStage` and `visitSink` (G2); the DSL as one library with part files under `lib/src/topology/` (D4); and topology-ir@v1's `TopologyDefinition` (its factory and five getters) under `lib/src/ir/`, which `buildDefinition()` and `TopologyPlan.definition` return and both topology-dsl@v2 surface libraries name. No stage, sink, builder or plan overrides `==` or `hashCode` (topology-dsl@v2 G30). Bodies that compute throw `UnimplementedError`.

## Where it sits
- Node: nidana.model · the pure, effect-free core every other package builds on: typed topics, the message envelope and its lineage rules, observer interfaces, the topology DSL interface with its recording builder, the TopologyDefinition IR, graphs and renderers, and the pure analyses over the IR
- Owns:
  - package `nidana_dart_contracts` (ADR-002)
  - `StateTopic`, `EventTopic`, `ReplayTopic`, the sealed `MultiWriterTopic` over event and replay topics that bus-api@v2's publish path takes (topic-model@v1 G27), `TopicRef`; topic identity as the pair of name and type (Spec §2.1); the `domain.entity` naming pattern (Spec §4.4); `Dedup` (Spec §3.12); `Tracing` (Guide §8.1); the sensitive flag (Spec §9.2); initial values as pure constants or pure factories (Spec §2.5)
  - `MessageEnvelope` (Spec §2.4) and the lineage rules as pure functions: single-input, multi-input with the trigger and correlation rules, time-shifting and accumulator operators (Spec §2.4, §3.5)
  - `Scope` (Spec §7.1) and the scope-compatibility rule over an ownership table (Spec §7.2)
  - `BusObserver`, `ObserveContext`, `ObserverCapability` as interfaces with no publish path (Spec §3.7)
  - sensitive-payload redaction: the payload type plus a truncated hash (Spec §9.2 item 2)
  - `Topology`, the `topology(id, scope, body)` form, `TopologyBuilder` and the opaque stream handle with the Spec §6.3 combinators, `reduceInto`, error operators and the raw-engine escape hatch (Spec §3.5, §6.1 to §6.3); every combinator is wrapped (root D6)
  - the recording builder, the `TopologyPlan` a declaration records and `planOf`, in the second public library `topology_plan.dart`, which live activation interprets and recording projects to the IR, and `buildDefinition()` (Spec §6.5; topology-dsl@v2 Refinements 1 to 3)
  - `TopologyDefinition`, `TransformEdge`, `CombinatorKind`, `FunctionRef`, and the IR's JSON form (Spec §6.5)
  - `TopologyGraph`, `ShellClaim`, `toGraph()`, and the Mermaid, Graphviz and JSON renderers (Spec §6.5; topology-ir@v1 Refinement 3)
  - pure analyses: inter-topology cycle detection by strongly connected components, the intra-topology self-reference check (Spec §3.8), single-writer conflicts among topology and shell owners (Spec §3.11), scope compatibility (Spec §7.2), topic name uniqueness over a set of declarations (Spec §4.3); the runtime runs the first four through `analyzeTopologyGraph` at activation and at publisher construction, and the workspace scan runs all five in CI (topology-ir@v1), while the bus's own name check at the first use of each declaration is its registry's (bus-api@v2 G7)
  - the contract replay tool, package `nidana_contract_check` (not published), which lands by set over nidana.model.1, nidana.model.2, nidana.model.6 and nidana.model.7, each set before the first gate that runs it (ADR-001 item 9; D1)
- Does not own: subjects, subscriptions, timers, zones and the live interpretation of the DSL (nidana.runtime); source scanning and catalog runs (nidana.tooling); navigation types (nidana.navigation); any dependency beyond the SDK and `meta` in `nidana_dart_contracts`
- Isolation strategy: `nidana_dart_contracts` depends on nothing beyond the SDK and `meta`, so every function is tested by direct calls and property tests with generated inputs, and every topology by recording it and asserting on the IR; the node's gates replay its three contracts with its own replay tool, `surface/`, `reject/` and schema in full and `behavior/` through the bindings to its own declarations and recording builder, restricted to the guarantees delivered so far (ADR-001 item 10); topology-dsl@v2's live suite, which needs a bus, is bound and run by nidana.runtime, which implements the live side

## Phase
- **Consumes:** [topic-model@v1]
- **Produces:** [topology-dsl@v2]
- **Governed by:** [ADR-001, ADR-002, ADR-003]
- **Scope:** every declaration of topology-dsl@v2's Interface, as D3 defines one: in the main library `Topology` (an `@immutable abstract base class` whose `buildDefinition()` is `@nonVirtual`), `topology()`, `TopologyRef`, `TopologyBuilder` (final, no public constructor) and `TopicStream` (sealed, no public constructor) with every combinator, `PipelineValue`, `RetryPolicy` and `RawOperator`; in the new public library `lib/topology_plan.dart`, whose names the main library does not export, `planOf`, `TopologyPlan`, the eighteen stage classes, `PlanSink`, `WriteSink`, `ReduceIntoSink`, `StageVisitor`, `SinkVisitor`, `visitStage` and `visitSink` (G2); the DSL as one library with part files under `lib/src/topology/` (D4); and topology-ir@v1's `TopologyDefinition` (its factory and five getters) under `lib/src/ir/`, which `buildDefinition()` and `TopologyPlan.definition` return and both topology-dsl@v2 surface libraries name. No stage, sink, builder or plan overrides `==` or `hashCode` (topology-dsl@v2 G30). Bodies that compute throw `UnimplementedError`.
- **Size estimate:** ~8 files (~470 lines, about half dartdoc from the Interface), ≤ 5 plan tasks
- **Gate:** `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject`
- **Verification:** code that imports the main library alone cannot name a stage or obtain a plan; `Topology` can be extended and not implemented, and a mutable field in a subclass is reported.
- **Review tier:** gate-only
- **Collides with:** [nidana.model.3, nidana.model.5, nidana.model.9, nidana.model.10, nidana.model.11]. It edits the main library's export list with nidana.model.3 and nidana.model.5, the DSL library with nidana.model.9 and nidana.model.11, and `lib/src/ir/` with nidana.model.5 and nidana.model.10.
- **Dependencies:** nidana.model.3 (topic-model@v1's declarations, which the DSL's signatures name)

## Contracts
### topic-model@v1 · consumes · stable
**Interface**
**Library:** `package:nidana_dart_contracts/nidana_dart_contracts.dart`, the main library of the package `nidana_dart_contracts` at `packages/nidana_dart_contracts/` (ADR-002 item 3). This contract defines no second public library; the same main library carries the declarations of topology-dsl@v2 and topology-ir@v1 unless those contracts name a library of their own. **Code owner:** nidana.model, whose first producing phase lands every declaration below (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/fixture/topic-model/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.model.3 lands every declaration, and a consumer's edge on this contract alone waits on it; a consumer of topology-dsl@v2 or topology-ir@v1 as well waits on nidana.model.5, where their declarations complete the main library the three contracts share. A `hard` edge waits instead on nidana.model.8, the last producing phase (nidana.integration). Until nidana.model.8 merges, a body that computes throws `UnimplementedError` and values compare by identity; nidana.model.8 delivers every behavior guarantee.

The declarations below are the schema of this contract (ADR-001 item 4). Bodies are omitted; the comments and the guarantees state the semantics. Every class here other than the three observer interfaces is an immutable value, annotated `@immutable` from `package:meta`, the package's only dependency.

### Topics

```dart
/// The three topic variants (Spec §2.1).
enum TopicVariant { state, event, replay }

/// Whether a state topic suppresses a publish equal to its current value
/// (Spec §3.12). Equality is Dart's `==` (Spec §3.12 table).
enum Dedup {
  equality, // the default: a publish `==` to the current value is a no-op
  none,     // every publish notifies
}

/// Whether the bus attaches envelope metadata to a topic's publishes
/// (Guide §8.1; Spec §3.5 "Cost"). What the bus and its observers do with an
/// untraced topic is bus-api@v2's; here it only fixes how an untraced value
/// enters lineage (Lineage.root).
enum Tracing { enabled, disabled }

/// A typed reference to a named channel on a bus (Spec §2.1, §4.2). A pure
/// value, shared across bus instances; it holds no subject.
@immutable
sealed class Topic<T> {
  String get name;
  bool get sensitive;            // Spec §9.2
  Tracing get tracing;           // Guide §8.1
  TopicVariant get variant;
  Type get valueType;            // T
  TopicRef get ref;              // TopicRef(name, variant, typeName: '$T')
  bool operator ==(Object other); // same variant, name and valueType (G7)
  int get hashCode;
}

final class StateTopic<T> extends Topic<T> {
  /// A constant initial value (Spec §2.5 "Allowed: constant").
  const StateTopic({
    required String name,
    required T initial,
    Dedup dedup = Dedup.equality,
    bool sensitive = false,
    Tracing tracing = Tracing.enabled,
  });

  /// A pure factory (Spec §2.5 "Allowed: pure factory"), never called at
  /// construction. When the bus calls createInitial() is bus-api@v2's.
  const StateTopic.computed({
    required String name,
    required T Function() initial,
    Dedup dedup = Dedup.equality,
    bool sensitive = false,
    Tracing tracing = Tracing.enabled,
  });

  Dedup get dedup;

  /// The declared value, or the factory's result for this call (G9).
  T createInitial();
}

/// The topics any number of writers may publish to (Spec §2.1, §3.11): the
/// event and replay variants, and no other (G1). The parameter type of a
/// publish path that takes no ownership claim, so a state topic does not
/// fit one (G27).
sealed class MultiWriterTopic<T> extends Topic<T> {}

final class EventTopic<T> extends MultiWriterTopic<T> {
  const EventTopic({
    required String name,
    bool sensitive = false,
    Tracing tracing = Tracing.enabled,
  });
}

final class ReplayTopic<T> extends MultiWriterTopic<T> {
  /// Buffers the [bufferSize] most recent values (Spec §2.1), at least one.
  const ReplayTopic({
    required String name,
    required int bufferSize,
    bool sensitive = false,
    Tracing tracing = Tracing.enabled,
  });

  int get bufferSize;
}
```

The family has three variants, the final classes. `StateTopic<T>` extends `Topic<T>` directly; `EventTopic<T>` and `ReplayTopic<T>` extend it through `MultiWriterTopic<T>`, which declares no member of its own and adds no variant, so `TopicVariant` keeps its three values. A switch over a `Topic` is exhaustive when it names the three variants, or `StateTopic` and `MultiWriterTopic`. Spec §2.1 makes state topics single-writer and the other two multi-writer; `MultiWriterTopic<T>` is that split as a type, which bus-api@v2's `Bus.publish` and `Publisher.publish` take so that the only path from shell code to a state topic is a writer handle (Spec §2.4).

A topic declaration takes no dispatcher hint; on Dart every topic of a bus shares the bus's provider zone (ADR-003 item 9). This decides OQ-M3 (G5). It takes no owner or writer annotation (Spec §3.11) and no persistence option (root D1).

Registries declare topics as `static const` or `static final` members of an `abstract final class` (Spec §4.2, Guide Appendix C.3). Both constructors of each variant are `const`.

### Topic references and names

```dart
/// A serializable reference to a topic (Spec Appendix A.4): what the IR
/// records for reads and writes and what an observer receives.
@immutable
final class TopicRef {
  const TopicRef({
    required String name,
    required TopicVariant variant,
    required String typeName,   // the value type's toString(), as '$T' renders it
  });
  String get name;
  TopicVariant get variant;
  String get typeName;
  bool operator ==(Object other); // all three fields
  int get hashCode;
}

/// Whether [name] follows `domain.entity` or `domain.entity.action`
/// (Spec §4.4): two or three segments separated by '.', each segment
/// lowercase kebab case, `[a-z][a-z0-9]*(-[a-z0-9]+)*`.
bool isWellFormedTopicName(String name);
```

`TopicRef` identifies a topic within one coordination domain, where names are unique (Spec §4.3). It carries the type as a string, so two value types whose names render alike are indistinguishable here; the runtime's name-and-type check compares `Topic.valueType`, which is a `Type`. Topic constructors never validate the name, because a const constructor cannot run a pattern match; `isWellFormedTopicName` is the predicate for any dev-mode diagnostic or check that applies the pattern, and root D1 schedules no v1 check for it.

### Message sources

```dart
/// Who produced a message (Spec §2.4 `source`). toString() renders the
/// Spec's format: 'topology:<id>', 'service:<name>', 'page:<routeOrName>',
/// 'executor:<name>', 'unknown'.
@immutable
sealed class MessageSource {
  /// The inverse of toString(); null for any other text (G17).
  static MessageSource? tryParse(String text);
}

final class TopologySource extends MessageSource {
  const TopologySource(String topologyId);    // non-empty
  String get topologyId;
}

final class ServiceSource extends MessageSource {
  const ServiceSource(String name);           // non-empty
  String get name;
}

final class PageSource extends MessageSource {
  const PageSource(String route);             // non-empty
  String get route;
}

final class ExecutorSource extends MessageSource {
  const ExecutorSource(String name);          // non-empty
  String get name;
}

/// The source of a publisher-less publish (Spec §2.4).
final class UnknownSource extends MessageSource {
  const UnknownSource();
}
```

Each variant compares equal to another of the same variant with an equal field. A non-empty field is asserted at construction.

### Envelopes

```dart
/// The carrier of every value published to a topic (Spec §2.4). The fields
/// are the Spec's; source is typed.
@immutable
final class MessageEnvelope<T> {
  MessageEnvelope({
    required String id,
    required T payload,
    required String correlationId,
    String? causationId,                                   // null for a root message
    List<String> parentCorrelationIds = const <String>[], // copied, unmodifiable
    required DateTime timestamp,
    required MessageSource source,
    required bool sensitive,
  });

  /// The envelope a stage publishes to [topic]: causation and parents from
  /// [lineage]; correlation from [lineage], or freshCorrelationId() when the
  /// lineage has none; sensitive is topic.sensitive (G14).
  factory MessageEnvelope.publishedTo(
    Topic<T> topic, {
    required String id,
    required T payload,
    required Lineage lineage,
    required String Function() freshCorrelationId,
    required DateTime timestamp,
    required MessageSource source,
  });

  String get id;
  T get payload;
  String get correlationId;
  String? get causationId;
  List<String> get parentCorrelationIds;
  DateTime get timestamp;
  MessageSource get source;
  bool get sensitive;

  /// This envelope with a sensitive payload replaced by
  /// RedactedPayload.of(payload); this envelope itself when not sensitive.
  MessageEnvelope<Object?> redacted();

  bool operator ==(Object other); // all eight fields; parents element-wise
  int get hashCode;

  /// Renders a sensitive payload redacted (G15).
  String toString();
}
```

`MessageEnvelope<T>` is covariant in `T`: every envelope is a `MessageEnvelope<Object?>`, which is what observers and recorders take. Payload immutability (Spec §8 rule 2) is the application's discipline; nothing here checks it.

**Sensitivity of a published envelope.** Spec §2.4 says an envelope's `sensitive` mirrors the flag of the topic it was published to; Spec §3.5 propagates `sensitive` from input to output through every stage, with a logical or in a combine. This contract reads them together: the lineage of a pipeline value carries the propagated flag, and the envelope published to a topic carries that topic's flag, so a value derived from a sensitive topic is visible to a non-sensitive observer once a non-sensitive topic carries it. The topic author decides what a topic's payload exposes (Spec §9.2).

### Lineage

```dart
/// The lineage fields of a pipeline value (Spec §2.4, §3.5): what the next
/// published envelope's causationId, correlationId and parentCorrelationIds
/// will be, and whether the value derives from a sensitive input.
@immutable
final class Lineage {
  /// No traced message caused this value: a shell publish starting a flow,
  /// or a value read from a Tracing.disabled topic. A null correlation means
  /// the publish starts a new flow (MessageEnvelope.publishedTo).
  const Lineage.root({String? correlationId, bool sensitive = false});

  /// Caused by [cause], a published envelope: causationId is cause.id;
  /// correlationId, parentCorrelationIds and sensitive are cause's.
  Lineage.causedBy(MessageEnvelope<Object?> cause);

  String? get causationId;
  String? get correlationId;
  List<String> get parentCorrelationIds;   // unmodifiable
  bool get sensitive;

  /// combine and combineLatest (Spec §2.4 table). [trigger] indexes the
  /// input whose new emission fired the operator. causationId is the
  /// trigger's; sensitive is the or of all inputs. Over the inputs that carry
  /// a correlationId: none, the result carries none and no parents; one
  /// distinct value, it is kept and parents are the union of those inputs'
  /// parents in input order; several, the result takes freshCorrelationId(),
  /// called exactly once, and parents are the distinct input correlation ids
  /// in input order. Throws ArgumentError when [inputs] is empty or
  /// [trigger] is out of range.
  static Lineage combine(
    List<Lineage> inputs, {
    required int trigger,
    required String Function() freshCorrelationId,
  });

  /// withLatestFrom (Spec §2.4 table): causation, correlation and parents
  /// from [primary]; sensitive is the or of [primary] and [latest].
  static Lineage withLatestFrom(Lineage primary, List<Lineage> latest);

  bool operator ==(Object other); // all four fields; parents element-wise
  int get hashCode;
}
```

**How the lineage functions are applied.** Lineage is computed per published message, not per pipeline stage. A value enters a pipeline with `Lineage.causedBy(envelope)` of the envelope its read handle delivered, or with `Lineage.root()` when the topic is `Tracing.disabled` or the value is a state topic's declared initial value. A subject seeded from `createInitial()` holds a value that no publish delivered, so no envelope and no message caused it: the initial value enters with `Lineage.root()` at every read that delivers it, a read after a removal reseeds the subject included. With the defaults it carries no correlation id, so a publish it leads to starts a new flow, and it is not sensitive, while the envelope of that publish carries its own topic's flag (G14). A single-input stage (`map`, `filter`, `switchMap` over its outer emission, `pairwise`), a time-shifting stage (`debounce`, `throttle`, `delay`, `sample`, `buffer`) and an accumulator (`scan`, `reduceInto`) pass the lineage of their triggering, surviving or most recent input through unchanged; `Lineage.combine` and `Lineage.withLatestFrom` are the only functions that make a new lineage inside a pipeline. A write publishes with `MessageEnvelope.publishedTo`, given a fresh id and the provider clock's time (ADR-003 item 8). The consequence: every `causationId` a published envelope carries is null or the id of a published envelope, so a causation chain can be walked through observed envelopes only (Spec §2.4 "Correlation vs. Causation"). Spec §3.5 describes a fresh envelope with a fresh id at every stage; those intermediate envelopes are invisible (Spec §3.5 "Where Envelopes Are Visible"), and a published envelope whose cause is one of them could not be traced. topology-dsl@v2 states, per combinator, which of these rules it applies; bus-api@v2 applies `publishedTo` at every publish and `Lineage.root` or `Lineage.causedBy` at shell publishes.

### Scope

```dart
/// A topology's lifetime (Spec §7.1). Topics have no scope.
enum Scope {
  application,
  module,
  page;

  /// Whether this scope lives at least as long as [other]: the order
  /// application, module, page, reflexive (Spec §7.2).
  bool isAtLeastAsLongAs(Scope other);
}
```

### Observers

```dart
/// Observer visibility (Spec §3.7, §9.2).
enum ObserverCapability {
  observeAll,        // sees envelopes of non-sensitive topics
  observeSensitive;  // sees envelopes of sensitive topics; an explicit grant

  /// Whether an observer holding [capabilities] may receive an envelope
  /// whose sensitive flag is [sensitive] (G23).
  static bool permits(Set<ObserverCapability> capabilities, {required bool sensitive});
}

enum LogLevel { debug, info, warning, error }

/// A span opened through ObserveContext.span. Implemented by the sink.
abstract interface class SpanHandle {
  void setAttribute(String key, Object? value);
  void end();
}

/// The only sinks an observer can reach (Spec §3.7): no publish, no bus.
abstract interface class ObserveContext {
  void log(LogLevel level, String message,
      {Map<String, Object?> fields = const <String, Object?>{}});
  void metric(String name, double value,
      {Map<String, String> tags = const <String, String>{}});
  /// [links] are ids of published envelopes whose spans this span links to,
  /// the causation link of Guide §8.2; the sink maps an id to its span.
  SpanHandle span(String name,
      {Map<String, Object?> attributes = const <String, Object?>{},
      List<String> links = const <String>[]});
}

/// A bus-level observer (Spec §3.7, §9.1). Implemented by applications and
/// by the runtime's telemetry observer.
abstract interface class BusObserver {
  Set<ObserverCapability> get capabilities;
  void onPublish(
    TopicRef topic,
    MessageEnvelope<Object?> envelope,
    ObserveContext context,
  );
}
```

When an observer runs, in which zone, in what order, and what happens when it throws are bus-api@v2's guarantees (Spec §3.7, ADR-003 item 2). A span's links are given when the span opens, by message id, so the seam names no telemetry SDK type; the sink that owns the spans resolves an id to the span it opened for that envelope (Guide §8.2 "Causation chain").

### Redaction

```dart
/// A sensitive payload as diagnostics, recorders and devtools show it: its
/// type and a truncated hash (Spec §9.2 item 2).
@immutable
final class RedactedPayload {
  /// typeName is payload.runtimeType.toString(); hash is the low 32 bits of
  /// payload.hashCode as eight lowercase hexadecimal digits.
  factory RedactedPayload.of(Object? payload);
  String get typeName;
  String get hash;
  bool operator ==(Object other); // typeName and hash
  int get hashCode;
  String toString();              // '<redacted {typeName} #{hash}>'
}
```

The hash follows Dart's `==` and `hashCode` contract, so equal payloads redact alike within one run. A low-entropy payload remains guessable from a hash of its value; the Specification accepts that trade for telling redacted values apart.
**Guarantees**
- **G1** The topic family is closed: `Topic<T>` and `MultiWriterTopic<T>` are sealed, `StateTopic<T>`, `EventTopic<T>` and `ReplayTopic<T>` are final, the subtypes of `MultiWriterTopic<T>` are exactly `EventTopic<T>` and `ReplayTopic<T>`, no type outside the library extends or implements any of them, and a switch over a `Topic` or a `MultiWriterTopic` that omits a variant does not compile.
- **G2** Only a state topic carries an initial value and a dedup policy: `createInitial()` and `dedup` are not defined on `EventTopic` or `ReplayTopic`, neither takes a `dedup` argument, and neither is assignable where a `StateTopic<T>` is expected, which is the parameter type of `getCurrentValue` (Spec §2.5).
- **G3** A state topic is declared with its initial value: `initial` is required, a `T` for `StateTopic(...)` and a `T Function()` for `StateTopic.computed(...)` (Spec §2.5).
- **G4** Topics, topic references, envelopes, lineages, sources and redacted payloads are immutable: none of their fields can be assigned, and every list they expose is an unmodifiable copy that later changes to the argument list do not reach.
- **G5** No topic declaration takes a dispatcher hint (Spec §3.6, §11.1; decides OQ-M3).
- **G6** Defaults: `sensitive` is false, `tracing` is `Tracing.enabled`, and a state topic's `dedup` is `Dedup.equality`; `variant` names the topic's class.
- **G7** Two topics are equal, with equal hash codes, exactly when their variant, name and value type are equal; the initial value, dedup, sensitive flag, tracing and buffer size take no part (Spec §2.1). `valueType` is `T`.
- **G8** `topic.ref` equals `TopicRef(name: topic.name, variant: topic.variant, typeName: '${topic.valueType}')`, and two topic references are equal exactly when all three fields are.
- **G9** `createInitial()` returns the declared constant itself; for `StateTopic.computed` it calls the factory once per call and returns its result, and constructing the topic never calls it.
- **G10** A replay topic buffers at least one value: a const declaration with `bufferSize` below 1 does not compile, and a non-const one fails an assertion when assertions are enabled.
- **G11** `isWellFormedTopicName` accepts exactly the names of two or three dot-separated segments, each matching `[a-z][a-z0-9]*(-[a-z0-9]+)*` (Spec §4.4); topic constructors accept any name.
- **G12** An envelope is constructed with its id, payload, correlation id, timestamp, source and sensitive flag, and `MessageEnvelope.publishedTo` with its id and timestamp; the package defaults none of them (ADR-003 item 8).
- **G13** Two envelopes are equal, with equal hash codes, exactly when all eight fields are equal, `parentCorrelationIds` compared element by element in order.
- **G14** `MessageEnvelope.publishedTo(topic, ...)` carries the given id, payload, timestamp and source, the lineage's causation id and parent correlation ids, the lineage's correlation id or else the result of exactly one `freshCorrelationId()` call (none when the lineage has one), and `sensitive == topic.sensitive` whatever the lineage's flag.
- **G15** A sensitive envelope's `toString()` shows `RedactedPayload.of(payload)` and never the payload's own rendering; `redacted()` replaces a sensitive payload with `RedactedPayload.of(payload)` and keeps every other field, and returns a non-sensitive envelope unchanged.
- **G16** The source family is closed: `MessageSource` is sealed, its five variants are final, no type outside the library extends or implements them, and a switch over a `MessageSource` that omits a variant does not compile.
- **G17** A source renders as `topology:{id}`, `service:{name}`, `page:{route}`, `executor:{name}` or `unknown` (Spec §2.4); `MessageSource.tryParse` returns a source equal to the one rendered, splitting at the first colon, and null for any text that is not such a rendering; sources are equal exactly when variant and field are.
- **G18** `Lineage.causedBy(e)` has causation `e.id` and `e`'s correlation id, parent correlation ids and sensitive flag; `Lineage.root()` has no causation, no parents and the correlation id and sensitive flag it was given, null and false by default.
- **G19** `Lineage.combine` follows Spec §2.4's table and worked examples: causation from the trigger, sensitive if any input is, the correlation kept when the correlated inputs share one (parents united in input order) and freshly taken, with exactly one `freshCorrelationId()` call, when they differ (parents are the distinct input correlation ids in input order); inputs without a correlation id contribute none, and it throws `ArgumentError` for an empty input list or a trigger out of range.
- **G20** `Lineage.withLatestFrom(primary, latest)` keeps the primary's causation, correlation and parents and is sensitive if any input is (Spec §2.4 table).
- **G21** `Scope` has exactly the values `application`, `module` and `page`, in that order, and `a.isAtLeastAsLongAs(b)` holds exactly when `a` comes no later than `b` (Spec §7.2).
- **G22** Nothing an observer receives offers a way to publish or to reach a bus: `ObserveContext` declares only `log`, `metric` and `span`, and neither it, `SpanHandle`, `TopicRef` nor `MessageEnvelope` has a member that publishes (Spec §3.7).
- **G23** `ObserverCapability.permits` admits a non-sensitive envelope exactly when the set holds `observeAll`, and a sensitive one exactly when it holds `observeSensitive` (Spec §3.7, §9.2).
- **G24** `RedactedPayload.of(p)` has `typeName == p.runtimeType.toString()` and `hash` equal to the low 32 bits of `p.hashCode` as eight lowercase hexadecimal digits, renders as `<redacted {typeName} #{hash}>`, never contains `p`'s own rendering, and is equal for equal payloads.
- **G25** `nidana_dart_contracts` reads no clock, creates no timer or microtask, generates no id and performs no I/O; a function that needs a timestamp or a fresh id takes it as an argument (ADR-003 item 8).
- **G26** `nidana_dart_contracts` depends on nothing beyond the Dart SDK and `package:meta` (ADR-002 item 4), so a pure Dart module that declares topics and observers pulls in nothing else (root D2).
- **G27** A state topic is not a multi-writer topic (Spec §2.1, §3.11): an `EventTopic<T>` and a `ReplayTopic<T>` are assignable where a `MultiWriterTopic<T>` is expected, and neither a `StateTopic<T>` nor a `Topic<T>` whose variant is not known statically is; at run time `topic is MultiWriterTopic` holds exactly for event and replay topics. A publish path typed over `MultiWriterTopic<T>`, as bus-api@v2's `Bus.publish` and `Publisher.publish` are, therefore does not compile for a state topic.

### topology-dsl@v2 · produces · stable
**Interface**
**Libraries:** `package:nidana_dart_contracts/nidana_dart_contracts.dart`, the main library of `nidana_dart_contracts` at `packages/nidana_dart_contracts/`, carries every declaration under Topologies, The builder, The handle and Pipeline values; `package:nidana_dart_contracts/topology_plan.dart`, a second public library named by this contract (ADR-002 item 3), carries every declaration under The plan. The main library does not export the plan library's declarations. Both import nothing beyond the SDK, `package:meta` and the package's own libraries (topic-model@v1 G26). **Code owner:** nidana.model, whose first producing phase lands every declaration below (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/fixture/topology-dsl/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.model.4 lands every declaration, and with them topology-ir@v1's `TopologyDefinition`, which `buildDefinition()` returns; a consumer's edge on this contract waits on nidana.model.5, where topology-ir@v1's declarations complete the main library both contracts share. A `hard` edge waits instead on nidana.model.11, the last producing phase (nidana.integration). Until the phase that delivers it merges, a body that computes throws `UnimplementedError`: nidana.model.9 delivers recording, `planOf`, the stages, sinks and visitors (G10, G11, G13 to G17, and G9 but for `buildDefinition()`); nidana.model.11 delivers `buildDefinition()` and `TopologyPlan.definition` (G9, G12). G30 holds from nidana.model.4. G18 to G29 are the live implementation's (Live interpretation): nidana.runtime implements them, and they replay through bus-api@v2's `bus_activation_test.dart` from nidana.runtime.12 on (bus-api@v2 Delivery).

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

  /// Writes every value of [stream] to [topic]: one write chain (Errors and
  /// lineage). The stream's value type is the topic's or a subtype of it (G3).
  void write<T, S extends T>(Topic<T> topic, TopicStream<S> stream);

  /// Folds [events] into [topic], which this topology then owns, seeded with
  /// the topic's current value when the activation connects (Spec §6.3,
  /// §7.2): one write chain (Errors and lineage).
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

A topology declares a sink (`write` or `reduceInto`) on a given StateTopic at most once; a second one throws ArgumentError (G14). Event and replay topics take any number of writes. Whether the topic is owned by another topology or a publisher is checked at activation (bus-api@v2, Spec §3.11), not here.

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
| `b.write(topic, s)` | `WriteSink<T>` | none | publishes each value to `topic`; an error that reaches it ends its write chain | the value's | no |
| `b.reduceInto(topic, events, f)` | `ReduceIntoSink<S, E>` | `reduceInto` | publishes `f(state, e)` for each event `e`, `state` starting as the topic's current value when the activation connects and becoming each published value; nothing at the connection; a reducer that throws, or an error that reaches it, ends its write chain | the event's | yes |

**Errors and lineage.** An error inside a live pipeline carries the lineage the stage that raised it would have given its output: a transformer, predicate, combiner, accumulator or recover function that threw raises an error with the lineage of the value it was called for; a switchMap inner stream, or a `toStream` that threw, raises one with its outer value's lineage. A `timeout` error, a `TopicRemoved` that a forced removal raises at a read stage, an error a raw operator emits, and an error that passed through a raw operator carry none, and a `catchError` recovers them with `Lineage.root()`. A raw operator receives each error as the object that was raised. An error passes through every other stage unchanged. An error a pipeline raises never reaches a read stage, because no error reaches a topic (below). Two errors start at a read stage, both raised by the bus as bus-api@v2 states: `TopicRemoved`, when the read's topic is removed with `force`, carrying none because no publish caused the removal (its G9), and a `TypeError` for a value the read cannot convert to its type argument, carrying the lineage that value would have had (its G41). Each then follows the Errors and lineage and Write chains rules like any other error: a `catchError` on its path recovers it, and otherwise it ends every write chain it reaches.

**Write chains.** A write chain is one sink with every stage it reaches upstream (Spec Appendix A.4 "Write chain"): the pipeline a `write` connects to its topic. A `reduceInto` is one write chain too, its fold with the stages that feed its events, because it is a `write` of a `scan` seeded with the topic's current value (Spec Appendix A.1 "Reducer topology"). A topology has one chain per sink, and a stage that several sinks reach belongs to each of their chains. An error ends a chain when it reaches the chain's sink: an error that a `catchError` on its path recovers does not, and a reducer that throws ends its own `reduceInto` (Spec §10.2 principles 2, 4 and 5). When an error ends a chain, the chain ends at once, within the work that carried the error to the sink, and nothing waits for a cancel future (ADR-003 item 3):

- the sink publishes nothing more, and the error reaches no topic, neither as a value nor as an error signal;
- the sink's subscription is cancelled, and with it every stage of the chain that feeds no other live chain: its subscriptions, a `switchMap`'s inner subscription and pending retry, and every timer it holds, so none of its functions runs again. This holds although a Dart stream goes on after an error event (Spec §10.2 principle 5);
- a stage the chain shares with a live chain goes on for that chain. An error raised in such a stage therefore ends every chain it reaches unrecovered, while a chain whose `catchError` recovers it goes on;
- the topology's other chains keep running, and the topology keeps its claims (Spec §3.11) until it is deactivated;
- the error is not rethrown to any caller; how the ended chain is reported is bus-api@v2's (root D8).

An ended chain is not restarted: it stays ended for the rest of the activation, and a later activation of the topology interprets a new plan with every chain live (G18). The state topic of an ended `reduceInto` keeps its value: the last one the fold published, or the one the fold started from when it published none.

**Retry.** When the current inner stream raises an error, or `toStream` throws, switchMap calls `retry(error, attempt)`, where `attempt` counts those errors for the current outer value from 1. A duration `d`: the inner subscription is cancelled, without waiting, and `toStream(value)` is called again `d` later on the provider clock, the error not going downstream. Null, or no policy: the error goes downstream. A newer outer value cancels a pending retry and restarts the count.

### Recording

Recording is `planOf` and `buildDefinition()`; it is pure. It runs `declare` once against a fresh builder, calls none of the functions the declaration passes, creates no timer, schedules no microtask and touches no bus (Spec §6.5). Each builder or handle call adds exactly one stage or sink. A plan's definition has the topology's id and scope, reads the set of `topic.ref` of its read stages, and writes the set of `topic.ref` of its sinks' topics (G12); its transforms are topology-ir@v1's. A declaration whose stages do not all reach a sink is rejected (G15): a handle that feeds nothing is almost always a forgotten write, and it would show as a read in the definition that nothing live performs.

### Live interpretation

A live implementation (nidana.runtime, entry point declared by bus-api@v2) does the following with a topology. This is the semantics the live conformance suite checks (G18 to G29).

1. **One plan per activation.** It calls `planOf` once, runs its activation checks on that plan's `definition` (Spec §3.8, §3.9, §3.11, §7.2), and interprets the same plan. This decides OQ-M2.
2. **Stages are shared.** Each stage is interpreted once per activation; all its consumers, stages and sinks, receive the same emissions, so a function runs once per input value and a switchMap's `toStream` once per outer value, however many consumers the stage has.
3. **Connection after wiring.** Read stages start delivering only after every stage and sink of the activation is subscribed, so a value a read delivers at connection, a state topic's current value or a replay topic's buffer, reaches every consumer. When an activation connects is bus-api@v2's to state, in its G22 and G34: one made during bootstrap is connected by `start()`, which replays nothing to it before then (Spec §3.13), and one made after `start()` is connected before `activate` returns. What this contract fixes for a connection, what it delivers and that wiring precedes it, holds whenever it happens.
4. **Sinks publish with the topology as source.** A sink publishes through `MessageEnvelope.publishedTo` with the value's lineage and `TopologySource(topologyId)` as source (Spec §2.4). When the publish is delivered, and how reentrancy is normalized, is bus-api@v2's (Spec §3.4). When one value of a stage reaches several sinks that take that stage's handle, the sinks publish it in declaration order (Spec §3.3).
5. **Time is the provider's.** Subscriptions, timers and microtasks of the pipeline are made in the provider zone (ADR-003 item 2), the time-dependent stages are RxDart 0.28's operators or `Stream.timeout` applied there (ADR-003 item 4), and a virtual clock therefore drives them exactly.
6. **Deactivation.** It cancels every subscription and timer of the activation, inner subscriptions and pending retries included, without waiting for a cancel future (ADR-003 item 3); the topology's sinks publish nothing after it.
7. **Ending a write chain.** When an error reaches a sink, it ends that sink's write chain as Errors and lineage states, cancelling what feeds no other live chain while the activation goes on.
**Guarantees**
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
- **G19** A live read delivers what the combinator table states (Spec §2.1, §3.12, §3.13, §7.4): a state topic's current value when the activation connects and then every later value its effective dedup lets through, `Dedup.none` delivering an equal publish too; a replay topic's buffer and then every later value; an event topic's later values only.
- **G20** Live `map`, `filter`, `scan`, `pairwise` and `distinctUntilChanged` emit what the combinator table states.
- **G21** Live `combine2`, `combine3`, `combine4`, `combineAll`, `withLatestFrom`, `withLatestFrom2`, `withLatestFrom3` and `merge` emit what the combinator table states, with values in input order.
- **G22** A live `switchMap` calls `toStream` once per outer value, delivers only the current inner stream's values, and on each outer value cancels the previous inner subscription without waiting for its cancel future and listens to the next inner stream within the same delivery, with no real event-loop turn (ADR-003 item 3); its retry follows the Retry rules, timed on the provider clock.
- **G23** Live `debounce`, `throttle`, `delay`, `sample`, `buffer` and `timeout` emit what the combinator table states, timed exactly by the implementation's clock (Spec §3.6, Rationale §3.2; ADR-003 item 4).
- **G24** A live `reduceInto` seeds its fold with the topic's current value when its activation connects, publishes nothing at that connection, publishes the reducer's result for each event, and after a deactivation and re-activation resumes from the retained value (Spec §6.3, §7.2).
- **G25** Every published envelope's causation, correlation and parent correlations follow the Lineage column of the combinator table and the Errors and lineage rules (Spec §2.4, §3.5; topic-model@v1 Lineage).
- **G26** Errors follow the Errors and lineage rules (Spec §10.2, Appendix A.4): `catchError` replaces an error by a value and its stage goes on; an error that reaches a sink, from a function that threw included, ends that sink's write chain for the activation, and a reducer that throws ends its `reduceInto`, whose state keeps its last value; the ended chain publishes nothing more and the error reaches no topic; its sink's subscription and every stage, inner subscription, pending retry and timer that feeds no other live chain are cancelled at once, without waiting for a cancel future, so none of their functions runs again; a stage shared with a live chain, and the topology's other chains, go on; a new activation runs the chain again.
- **G27** A live stage is interpreted once per activation and shared by all its consumers, so each of its functions runs once per input value; one value written by several sinks that take the same handle is delivered in sink declaration order (Spec §3.3).
- **G28** A live raw operator is called once per activation, with the stage input's values, and the values its stream emits, with their lineages, are what the next stage receives and what a sink publishes.
- **G29** After deactivation a topology's sinks publish nothing, and its inner subscriptions, pending retries and timers have been cancelled (Spec §2.2, §7.2).
- **G30** Every stage and sink class, `TopologyBuilder` and `TopologyPlan` keep `Object`'s `==` and `hashCode`: two stages, sinks, builders or plans are equal exactly when they are identical, so two reads of one topic are two stages, each interpreted once (Live interpretation items 2 and 3).

## Decisions
### ADR-001: Executable validation for Dart API contracts · accepted
**Decision**
Resolves OQ8. Contracts in this tree are validated as follows.

1. **Kinds.** `api` for a Dart library surface consumers import and call; `shared-model` for Dart value types consumers construct and match on; `schema` for a serialized data format; `file` for a generated file layout; `cli` for commands, diagnostics and exit codes.
2. **Location and analysis.** Fixtures live under `hsdd/contract/fixture/{slug}/`, schemas at `hsdd/contract/schema/{slug}.schema.json`. The workspace root's `analysis_options.yaml` excludes `hsdd/**`, so only the replay tool analyzes fixtures. `hsdd/contract/fixture/analysis_options.yaml` governs every fixture: no lint set; `strict-casts`, `strict-inference` and `strict-raw-types` on. Fixtures import public libraries only (`package:{name}/{library}.dart`, never `src/`), plus `package:matcher`, `package:test`, `package:flutter_test` and `package:nidana_contract_check/fixture.dart`, all resolved through the workspace's package configuration. These options and this import rule bind the Dart libraries of `surface/`, `reject/` and `behavior/`, the only fixtures the replay tool analyzes. Input and expected trees (`input/`, `expected/`, `invocation/{case}/files/`, `invocation/{case}/expected/`) and data directories (item 9) are data, which the replay tool never analyzes, although a recorded command may analyze its own `files/`.
3. **Guarantee ids.** Each entry of a contract's `## Guarantees / invariants` list begins with a stable id, `- **G{n}** {statement}`. An id is never renumbered and never reused within its slug. Every guarantee is covered by at least one reject fixture, behavior case, schema set, file replay or recorded invocation, or appears in the contract's `## Validation` section as `- not executable: G{n}, {reason}; checked by {node}'s gates`.
   - `{ids}` below is a list of ids `G{n}` and ranges `G{a} to G{b}`, separated by `, ` or ` and `.
   - A reject fixture covers the ids its `// covers: {ids}` header names, and a behavior case the id its name begins with.
   - The schema set, the file replay and recorded invocations carry no id in their files, so `## Validation` declares what they cover. A `- schema:` or `- file:` bullet whose set covers guarantees ends with `covers {ids}.`. Every recorded invocation has one row in a table whose first column is `Case`, holding the case directory's name in backticks, and whose `Covers` cell begins with `{ids}`, optionally followed by `: ` and a note.
   - A guarantee covered only in part also has a not-executable line for the rest, which names that part: `- not executable: G{n}'s {part}, {reason}; checked by {node}'s gates`.
   - The structure set reads the id that begins a not-executable line and the node in `checked by {node}'s gates`; further text may follow.
4. **`api` and `shared-model` contracts** carry no schema file: the Interface's Dart declarations are the schema, made executable by these sets.
   - `surface/`: Dart libraries that use every declaration the Interface lists, writing out the types it states. A file passes when `fvm dart analyze --fatal-infos` reports no diagnostic on it.
   - `reject/`: one Dart library per type-level guarantee, or per misuse that breaks several. Its header names what it covers, `// covers: {ids}` (item 3). A comment on its own line, `// expect-diagnostic: {code}`, expects the diagnostic `{code}`, in lowercase as `dart analyze --format=json` reports it, on the next line. A file passes when the (line, code) pairs reported in it, at every severity, equal the pairs its markers name, and it has at least one marker.
   - `behavior/{subject}_conformance.dart`: conformance libraries. Each declares a harness interface, which is what an implementation supplies: factories for the implementation, and `Future<void> settle()` to bring it to quiescence. Each exports its cases as a value of type `List<ConformanceCase<H>>`. `ConformanceCase<H>` is the record `({String name, Future<void> Function(H harness) body})`, exported by `package:nidana_contract_check/fixture.dart`. Every name is a string literal that begins with the guarantee id, `'G{n} ...'`. A conformance library imports neither `package:test` nor `package:flutter_test`, and asserts with `package:matcher/expect.dart`.
   - `behavior/{implementation}_test.dart`: bindings, one per implementation, named after the implementation in snake case. A binding registers every case of one conformance library, with `test`, or with `testWidgets` for an implementation that needs the widget tree. A binding lives in the fixture directory of the contract whose Interface declares the implementation. When the interface belongs to another contract, the binding imports that contract's conformance library by relative path: bus-api@v2 declares the activation path, `Bus.activate` interpreting the `TopologyPlan` a declaration produces, so `hsdd/contract/fixture/bus-api/behavior/bus_activation_test.dart` binds topology-dsl@v2's live suite. The contract's `## Validation` section lists each binding with the implementation it binds.
   - An `api` contract with a serialized form (topology-ir@v1) also carries item 5's schema and edge cases. Its conformance library includes the round trip of every `valid/` file through the producer's decoder and encoder, and checks the producer's real output with `expectMatchesSchema` from `package:nidana_contract_check/fixture.dart`.
5. **`schema` contracts** carry a JSON Schema, draft 2020-12, and edge cases under `valid/` and `invalid/`. Every `valid/` file validates and no `invalid/` file does. The producer side is checked as item 4's serialized-form clause states.
6. **`file` contracts** carry `input/` and `expected/` trees. The contract's `## Validation` section names the generator command, with `{input}` and `{output}` placeholders. The replay runs it from the workspace root into an empty directory, formats the generated Dart with `fvm dart format`, and compares the result with `expected/` byte for byte, the file set included.
   - A `file` contract whose input is a data format (topic-codegen@v1's topics document) also carries item 5's schema and edge cases for that format.
   - A `file` contract may also carry item 7's recorded invocations, for what one input tree cannot show: its generator's other modes, its rejection of an input, its usage errors and their exit codes.
7. **`cli` contracts** carry one directory per recorded invocation, `invocation/{case}/`. It holds `args`: the command on the first line (`dart`, `flutter` or `{package}:{executable}`), then one argument per line. An argument `{output}` is replaced by a path inside a fresh temporary directory, at which nothing exists when the command starts. It may hold `files/`, an input tree that becomes the working directory; a case without `files/` runs from the workspace root. It holds `exit_code`, and optionally `stdout` and `stderr`, each compared exactly after the absolute paths of `{output}`, of `files/` and of the workspace root, each as given and symlink-resolved, are replaced by `{output}`, `{files}` and `{root}`, in that order. A case that needs the analysis server plugin enables it in `files/analysis_options.yaml` by a relative path to the plugin package.
   - A case whose `args` name `{output}` may hold `expected/`: after the run, the tree at `{output}` must equal it as item 6 compares. Without `expected/`, nothing may exist at `{output}` after the run.
8. **Authorship.** hsdd-contract writes every fixture, binding and schema, and `hsdd/contract/fixture/analysis_options.yaml`, when it authors a contract or a version, before the producing package exists. A phase never writes under `hsdd/contract/`.
9. **Replay tool.** `packages/nidana_contract_check`, not published, owned by nidana.model, with `package:json_schema` as a dependency. It lands by set over four of nidana.model's phases, each set before the first gate that runs it (nidana.model D1): `structure` at nidana.model.1; `surface`, `reject`, `schema`, `package:nidana_contract_check/fixture.dart` and PENDING detection at nidana.model.2; `behavior` at nidana.model.6; `file` and `cli` at nidana.model.7. A phase of another node whose gate runs a set, or whose tests import `fixture.dart`, depends on the phase that lands it. It runs from the workspace root as `fvm dart run nidana_contract_check {slug}... [--set {set},...] [--guarantee {id},...]`, or with `--all` for every slug that has a fixture directory.
   - Sets: `structure`, `surface`, `reject`, `behavior`, `schema`, `file`, `cli`. The default is every set the slug has. `structure` always runs first, whether `--set` names it or not, and needs no implementation: marker and header syntax, item 3's coverage, the bindings listed in `## Validation` against the files present, the fixture directory's layout, and the ban on `src/` imports. `--set` selects among a slug's other sets and never adds a set the slug lacks, so a slug that has none of the named sets, under `--all` or named, runs `structure` alone.
   - Layout: each entry directly under `hsdd/contract/fixture/{slug}/` is either a set directory that items 4 to 7 give the contract's kind (`surface/`, `reject/`, `behavior/`, `valid/`, `invalid/`, `input/`, `expected/`, `invocation/`) or a data directory. A data directory is listed in `## Validation` by a bullet `` - {dir}: `hsdd/contract/fixture/{slug}/{dir}/`, {what it holds and what reads it} ``. `structure` fails on any other entry and on a listed data directory that is absent. No set reads a data directory by itself: conformance cases read one by a path relative to the workspace root (topology-ir@v1's `render/` goldens), or a node's gates read it (topic-codegen@v1's `rejected/` documents).
   - `--guarantee` takes `{slug}/G{n}` and bare `G{n}`. A bare `G{n}` belongs to the one slug the command names, and is a usage error when the command replays more than one slug. A `{slug}/G{n}` may name a slug the command does not replay. The restriction leaves `structure`, `surface`, `reject` and `schema` unrestricted.
   - Under `--guarantee`, a binding runs only the cases whose names begin with an id of the slug whose conformance library it imports, which the tool reads from that import, so a binding whose suite's slug has no id in the restriction runs no case. A bare id therefore restricts only the bindings of the replayed slug's own suites: under a bus-api replay, `hsdd/contract/fixture/bus-api/behavior/bus_activation_test.dart`, which binds topology-dsl@v2's live suite, runs only the cases the restriction names by `topology-dsl/G{n}` ids.
   - Under `--guarantee`, a file replay or recorded invocation runs only when every id `## Validation` declares for it (item 3) is in the restriction, so a slug with no id of its own in the restriction runs none of them.
   - A binding, file replay or recorded invocation that the restriction admits no case of is not run and counts as passing. The tool never starts a test runner with a name filter that admits no case, because `dart test` then exits 79.
   - A binding that imports `package:flutter_test` runs under `flutter test --no-pub`, any other under `dart test`, both from the workspace root, with the `flutter` that belongs to the SDK of the `dart` running the tool.
   - Before the `file` or `cli` set, the tool runs `dart pub get --enforce-lockfile` once at the workspace root, with the `dart` running the tool, so that no case runs on a stale resolution.
   - A fixture that names a package absent from the workspace's package configuration fails, reported as `PENDING` rather than as a defect: a `surface`, `reject` or `behavior` library, a binding included, that imports the package, and a file replay or recorded invocation whose command runs it.
   - The tool prints one line per fixture. It exits 0 when every fixture it runs passes; 1 when any fixture fails or is `PENDING`; 2 on an environment error, such as that `pub get` failing or no `flutter` in the SDK of the running `dart` for a Flutter binding; 64 on a usage error, such as an unknown slug or set, a malformed id, or a bare `G{n}` with more than one slug.
10. **Gates.** The gate of every phase that produces a contract includes `fvm dart run nidana_contract_check {slug}`. `structure`, `surface`, `reject` and `schema` run in full at every producing phase, because under `fp-progression` a contract's first producing phase, the first phase of its producing leaf-parent that its `produced_by` names, lands every declaration of its Interface, and a schema needs no implementation. The replay tool's phases (item 9) produce no contract, so the first producing phases of nidana.model's three contracts are nidana.model.3 to nidana.model.5, one per contract, not the node's first phase. `behavior`, `file` and `cli` run restricted by `--guarantee` to the guarantees the node's phases have delivered so far, cumulatively, and unrestricted at the last phase that produces the contract. nidana.integration's gate runs `--all`, unrestricted.
   - An `api` or `shared-model` contract has one producing leaf-parent. Its `surface` and `reject` sets run in full from its first producing phase, so that one phase must land every declaration they use, a declaration of another contract included, as nidana.model.4 lands topology-ir@v1's `TopologyDefinition` for topology-dsl@v2's surface.
   - A contract of another kind may have more than one producing leaf-parent. The spec of the node whose decomposition gave it those producers names each producer's share of its guarantees, as nidana.tooling D2 does for nidana-checks@v1. A file replay or recorded invocation falls within a share when every id it covers is in that share, and each falls within exactly one share. Each producer's phases run `file` and `cli` restricted to the guarantees that producer's phases have delivered so far, cumulatively, and its last producing phase runs them restricted to its whole share instead of unrestricted. Those last replays together run every case. `structure` and `schema` run in full at every producing phase of every producer. The one unrestricted replay of such a contract is nidana.integration's `--all`.
11. **Consumers.** A consumer of an in-process `api` or `shared-model` contract builds against the producer's real package once the phase that the contract's Delivery paragraph names for a consumer's edge has merged (root D10): the contract's first producing phase, or a later type-level phase when contracts share one library, as topology-dsl@v2's consumers wait on nidana.model.5. A consumer that needs a stand-in binds the contract's conformance library to the stand-in in its own package's `test/` directory, importing the library by relative path, and runs that binding in its gate. A stand-in that does not pass the suite is not a fixture.
12. **What counts for `stable`.** A fixtures directory is this tree's executable validation artifact only when it meets item 3 and the items for its kind. The `structure` set checks this once the replay tool exists; until then the hsdd-contract author and hsdd-reconcile check it by reading.
**Consequences**
- No contract replay can run before nidana.model.1 merges the `structure` set, no other set before the phase item 9 names for it, and no conformance library loads before nidana.model.2 merges `package:nidana_contract_check/fixture.dart`. Every fixture written before its set lands is unverified, reject codes above all, so the first replay against each producer can fail on the fixture itself; that is a contract gap, renegotiated through hsdd-contract mid-phase.
- The workspace root's `analysis_options.yaml` (ADR-002) excludes `hsdd/**` beside `ref/**` and `docs/**`. A workspace-wide `fvm dart analyze` never reports on a fixture; a fixture's diagnostics come from the replay tool only.
- `package:json_schema` joins the workspace's single resolution through the replay tool.
- Every contract's guarantees carry `G{n}` ids. Phase plans cite them in `--guarantee` restrictions, and verification docs cite them.
- A contract whose Interface declares an implementation of another contract's interface carries that binding: bus-api@v2 for topology-dsl@v2's live suite, which its activation path implements, and flutter-binding@v2 for navigation-api@v1's executor protocol, which `FlutterNavigationExecutor` implements. Its producer's gate therefore runs the other contract's suite, and its authoring step needs the other contract's conformance library to exist first.
- What a schema set, a file replay or a recorded invocation covers, which data directories a fixture tree holds, and which guarantees are executable only in part are read from the contract's `## Validation` section, so the forms of items 3 and 9 are part of every contract's text. A misspelt set directory fails `structure` instead of going unreplayed.
- The replay tool's `cli` set carries the `{output}` argument and reuses the `file` set's tree comparison, so a generator's rejections, its other modes and its exit codes are executable as recorded invocations of its `file` contract. A guarantee about them stays not executable only while its contract carries no such case.
- `--guarantee` restricts file replays and recorded invocations by their declared ids, so a node that delivers a generator or a checker over several phases replays, at each gate, only what it has delivered.
- A contract with more than one producing leaf-parent, nidana-checks@v1 today, is replayed unrestricted only by nidana.integration's `--all`. Each producer's last gate runs the cases of its own share, so no producer waits on another. A case whose ids span two shares, or fall within none, would have no producing gate to replay it, and the replay tool cannot see the shares, which live in a node spec. Whoever adds a case to such a contract (hsdd-contract) or plans one of its producers (hsdd-phase-plan) checks by reading that each case falls within exactly one share.
- An `api` or `shared-model` contract cannot be split between leaf-parents without changing item 10 first.
- A Flutter binding runs from the pure-Dart workspace root; no member has to host it.
- Replaying a contract whose producing package is absent from the workspace reports every fixture that names the package as `PENDING` and exits 1, so a gate placed before the phase that creates the package fails instead of passing. A contract's sets other than `structure` and `schema` are replayed from its first producing phase on, by which time the package exists.
- A restricted gate passes a binding whose cases are all delivered after it. A producer that implements another contract's interface, as nidana.runtime implements topology-dsl@v2's activation path, replays that contract's cases at a restricted gate only as the gate names them by `{slug}/G{n}`.
- A changed guarantee changes the fixtures, and every binding of the suite, a consumer's stand-in included, fails loudly instead of drifting.
- No fixture format here is language-neutral. Cross-platform test parity (Guide §10.1) needs its own decision when a second platform port starts.

### ADR-002: Package and workspace layout · accepted
**Decision**
Resolves OQ9 and, together with root D7, OQ12. Partially resolves OQ-T2: item 8 fixes where the workspace scan runs; what it reads is nidana-checks@v1 Refinement 2's.

1. **Workspace root.** The repository root is one pub workspace. Its `pubspec.yaml` has `name: nidana_workspace`, `publish_to: none`, `environment: sdk: ^3.13.0`, `dev_dependencies: lints: ^6.1.0` as its only dependency, and a `workspace:` list that names every member path explicitly, without globs. The root `pubspec.lock` is committed and is the only lockfile outside `docs/`; no member has a lockfile or package configuration of its own. A `dependency_overrides` entry, when one is needed, goes in the root `pubspec.yaml` only. `fvm dart pub get` or `fvm flutter pub get`, run at the root or inside any member, resolves the whole workspace.

2. **Root analysis options.** The root `analysis_options.yaml` is the following, plus item 7's `plugins:` section once it applies:

   ```yaml
   include: package:lints/recommended.yaml
   analyzer:
     exclude:
       - ref/**
       - docs/**
       - hsdd/**
     language:
       strict-casts: true
       strict-inference: true
       strict-raw-types: true
   ```

   It governs every member. A member has no options file of its own unless it adds rules; such a file starts with `include: ../../analysis_options.yaml` and has no `plugins:` section. The workspace stays clean under `fvm dart analyze --fatal-infos` run at the root. The only options files under `hsdd/` are the ones ADR-001 places there.

3. **Members.** Every member lives at `packages/{name}/`, in a directory named after the package, and is owned by exactly one node. A published member's main library is `lib/{name}.dart`; its other public libraries sit directly under `lib/` and are named by the contract that declares them; everything else is under `lib/src/`.

   | Package | Owner | Published | Dependencies | Dev dependencies |
   |---------|-------|-----------|--------------|------------------|
   | `nidana_dart_contracts` | nidana.model | yes | `meta` | `test` |
   | `nidana_dart_runtime` | nidana.runtime | yes | `nidana_dart_contracts`, `rxdart`, `clock`, `meta` | `test` |
   | `nidana_dart_navigation` | nidana.navigation | yes | `nidana_dart_contracts`, `nidana_dart_runtime`, `meta` | `test` |
   | `nidana_dart_runtime_flutter` | nidana.flutter | yes | `flutter` (SDK), `nidana_dart_contracts`, `nidana_dart_runtime`, `nidana_dart_navigation`, `meta`; no router package (OQ-F1, resolved by flutter-binding@v2 Refinement 1 and G18) | `flutter_test` (SDK) |
   | `nidana_dart_codegen` | nidana.tooling.codegen | yes | `nidana_dart_contracts`, `build`, and those of `source_gen`, `analyzer`, `dart_style`, `yaml` and `path` its code imports | `build_test`, `test` |
   | `nidana_dart_lint` | nidana.tooling.lint | yes | `analysis_server_plugin`, `analyzer`, pinned as item 7 states | `analyzer_testing`, `test` |
   | `nidana_contract_check` | nidana.model | no | `args`, `json_schema`, `matcher`, `package_config`, `path` | `test` |
   | `nidana_integration` | nidana.integration | no | `flutter` (SDK), `nidana_dart_contracts`, `nidana_dart_runtime`, `nidana_dart_navigation`, `nidana_dart_runtime_flutter` | `flutter_test` (SDK), `build_runner`, `nidana_dart_codegen` |

   - `nidana_dart_runtime` holds Guide Appendix B.1 layers 2 and 3. Its RxDart-specific code sits behind an internal library seam under `lib/src/`, so a second engine would be a new package, not a rewrite. Its public libraries are `nidana_dart_runtime.dart` and `testing.dart` (`TestBus`, `VirtualScheduler`, the envelope recorder).
   - `nidana_dart_lint`'s entry point is `lib/main.dart` with a top-level `plugin`, as the analysis server requires.
   - The table is the v1 baseline. A phase that needs another third-party package in a member records it as a `D{n}` in the owning node's spec, within item 4's rules.

4. **Dependency rules.**
   - A member depends on another member by a hosted version constraint (`nidana_dart_contracts: ^0.1.0`), never by `path:`. The workspace resolves it to the local member, and the member stays publishable unchanged.
   - A third-party dependency takes the constraint the table below lists, whichever phase adds it and whatever the lockfile holds then. Each lower bound is the version the full planned resolution holds: every dependency of item 3's table in one resolution, Flutter, item 7's pins and root D9's `rxdart: ^0.28.0` included, on the current `.fvmrc` pin. A package that several members declare carries the same constraint in each. Item 7's exact pins are the only exception.

     | Package | Constraint | Package | Constraint |
     |---------|------------|---------|------------|
     | `analysis_server_plugin` | `0.3.18` exact (item 7) | `json_schema` | `^5.2.2` |
     | `analyzer` | `^13.3.0`; `13.3.0` exact in `nidana_dart_lint` (item 7) | `matcher` | `^0.12.20` |
     | `analyzer_testing` | `^0.3.2` | `meta` | `^1.19.0` |
     | `args` | `^2.7.0` | `package_config` | `^2.2.0` |
     | `build` | `^4.0.11` | `path` | `^1.9.1` |
     | `build_runner` | `^2.16.1` | `rxdart` | `^0.28.0` |
     | `build_test` | `^3.5.20` | `source_gen` | `^4.2.4` |
     | `clock` | `^1.1.3` | `test` | `^1.31.1` |
     | `dart_style` | `^3.1.14` | `yaml` | `^3.1.4` |

   - Until the first Flutter member joins, the lockfile can hold a newer `test` within `^1.31.1` (1.33.0 on pub.dev today); no member's tests use a `test` API newer than 1.31.1.
   - A third-party package outside the table, which a node's `D{n}` adds (item 3), takes the caret of the version that one resolution of the table's packages with Flutter, item 7's pins and that package holds. The `D{n}` records the constraint and the probe that showed it, and a later member that declares the package copies it.
   - The member graph is acyclic: `nidana_dart_contracts`, then `nidana_dart_runtime`, then `nidana_dart_navigation`, then `nidana_dart_runtime_flutter`; `nidana_dart_codegen` depends on `nidana_dart_contracts` only; `nidana_dart_lint` and `nidana_contract_check` depend on no nidana package; `nidana_integration` depends on every published runtime package. A member imports another member's public libraries only, never its `lib/src/`, which the root lint set's `implementation_imports` reports.
   - `nidana_dart_contracts` depends on `meta` alone. Flutter appears only in `nidana_dart_runtime_flutter` and `nidana_integration`.
   - No published member lists `test` or `flutter_test` under `dependencies`. `nidana_dart_runtime`'s `testing.dart` and the Flutter adapter's widget-test helpers import neither, so VM tests and widget tests use them alike; `package:matcher` is allowed.
   - No member depends on `custom_lint`.

5. **SDK constraint.** The root and every member declare `environment: sdk: ^3.13.0`, the Dart of the `.fvmrc` pin. A change of the pin changes every SDK constraint, item 4's table, the lockfile and item 7's pins together.

6. **Non-members and packages not created.** `docs/**` holds standalone experiments with their own resolutions and is never a member. A member's `example/` folder, when present, has no `pubspec.yaml` and is part of its member's package; the runnable example app is `nidana_integration`. Not created in v1: `nidana_dart_runtime_rxdart` (folded into the runtime, item 3), `nidana_dart_persistence` (deferred by root D1), `nidana_dart_perf_suite`, `nidana_dart_devtools` (the name stays reserved for v2 runtime devtools; the v1 build-time graph ships in `nidana_dart_codegen`), and a test-utilities package (the `nidana-test-utils` of Guide §6.5 and §10.1 is the runtime's `testing.dart`).

7. **Static analysis mechanism.** The v1 checks that one library's resolved AST decides ship as rules of `nidana_dart_lint`, an analysis server plugin on the Dart 3.10 plugin API (`package:analysis_server_plugin`). A check that needs more than one library, or the IR, is not a plugin rule (item 8).
   - `nidana_dart_lint` depends on `analysis_server_plugin` and `analyzer` only, each pinned to the exact version the full planned resolution holds, which item 4's table lists (0.3.18 and 13.3.0 on the current pin), and on no nidana package. It recognizes nidana API by library URI and element name.
   - The phase that creates `nidana_dart_lint` adds this to the root options, so its rules run over every member under `fvm dart analyze` and in the IDE; before that phase the root options have no `plugins:` section:

     ```yaml
     plugins:
       nidana_dart_lint:
         path: packages/nidana_dart_lint
     ```

   - A recorded invocation under `hsdd/contract/fixture/` enables the plugin in its own `files/analysis_options.yaml` by relative path (ADR-001 item 7).

8. **Codegen command entries.** `nidana_dart_codegen` holds the build_runner builders and command entries under `bin/`, run from the workspace root as `fvm dart run nidana_dart_codegen:{executable}`:
   - a generator command that runs the builders' generators outside build_runner, which the `file` replay of topic-codegen@v1 runs (ADR-001 item 6);
   - the workspace scan, which runs every v1 check over more than one library or over the IR (topic name uniqueness across registries, single-writer, inter-topology cycles, intra-topology self-reference, scope compatibility) by calling `nidana_dart_contracts`' analyses, the functions activation also calls, and which shares the topology catalog scan with graph emission.

   Builders and command entries call the same pure generator functions, so build_runner and the commands write identical bytes. Executable names, arguments, outputs and exit codes belong to topic-codegen@v1 and nidana-checks@v1.

9. **Versions and publishing.** Published members share one version, start at `0.1.0`, stay `0.x` until the v1 release, and move together: a bump changes every published member's `version` and every inter-member constraint in one change. Unpublished members (`nidana_contract_check`, `nidana_integration`) carry `publish_to: none` and no version. Each published member carries a `README.md`, a `CHANGELOG.md` and a copy of the repository's `LICENSE` (Apache-2.0). Publishing, the `repository` field and the publication order are owner actions outside the tree.
**Consequences**
- The workspace builds on analyzer 13.3.0, analysis_server_plugin 0.3.18, build 4.0.11, source_gen 4.2.4, build_runner 2.16.1 and test 1.31.1 until a Flutter pin upgrade moves `test_api`. Codegen and lint code is written against these versions; an analyzer 14 API is not available.
- Every member's third-party constraints are known before the member exists: a member-creating phase copies item 4's table and never derives a constraint from the lockfile it finds. Constraints written that way resolve with every set of members the build order can reach, whichever node lands first. A package outside the table costs a resolution probe of the whole planned set before its `D{n}` is written.
- Until nidana.flutter.1 adds the first Flutter member, the committed lockfile holds the newest `test`, 1.33.0 today, with `test_api` 0.7.15 and `test_core` 0.6.21, and analyzer 14.5.0 as a transitive package until a member pins or constrains it. That phase's `fvm dart pub get` moves them to `test` 1.31.1, `test_api` 0.7.12 and `test_core` 0.6.18, and analyzer to 13.3.0 unless a member already holds it there, so every pure member's tests change `test` version in that phase; no other direct package moves.
- `fvm dart analyze --fatal-infos` at the root checks every member against the lint set, the strict modes and, once it exists, `nidana_dart_lint`. A plugin diagnostic reports at the severity the plugin's `diagnostics` section sets for its code, and otherwise at the severity its code declares, INFO when the code declares none; registering a warning rule rather than a lint rule decides only that the rule runs without being enabled. nidana-checks@v1 fixes each rule's default severity. Plain `fvm dart analyze` fails on a WARNING or an ERROR, and `--fatal-infos` also on an INFO, so every plugin diagnostic fails the root analyze.
- The plugin's rules also run over the tree's own packages, so a rule accepts what those packages legitimately contain, such as topic declarations with literal names.
- A `nidana_dart_lint` that does not build fails every root analyze under `--fatal-infos`, and with it every gate that analyzes: exit 3 when its source does not compile, since the root analyze reports that source's ERROR, and exit 4 when it fails to load for another reason on an otherwise clean workspace. nidana.tooling.lint's phases keep the plugin building at every merge. An analysis without `--fatal-infos` whose only diagnostics are INFOs exits 0 even when the plugin does not load.
- The plugin runs under the analyzer version its tests ran against. A published `nidana_dart_lint` works only with SDKs whose analysis server accepts analysis_server_plugin 0.3.18; the pins move with the SDK pin.
- `hsdd/contract/fixture/analysis_options.yaml` (ADR-001 item 2) also keeps the root-enabled plugin off surface and reject fixtures. A file under `hsdd/` outside any directory with its own options file gets the plugin's diagnostics when analyzed by path.
- A seeded violation never sits in a member's analyzed code. Seeded cases live in excluded trees analyzed by explicit path with their own options file, as nidana-checks@v1's recorded invocations do, or are input to the workspace scan.
- nidana-checks@v1 covers two hosts: `nidana_dart_lint`'s diagnostics under `dart analyze`, and the workspace scan command of `nidana_dart_codegen`. topic-codegen@v1 names the generator command. An app that runs the aggregate checks takes `nidana_dart_codegen` as a dev dependency even when it writes its registries by hand.
- build_runner runs inside the member that applies the builders (`fvm dart run build_runner build` in `packages/nidana_integration`), not at the root, whose only dependency is `lints`.
- Before publication, an app outside this repository consumes the packages by path or git and lists every nidana package it reaches, transitive ones included, under its own `dependency_overrides`. It enables the plugin by a path to `packages/nidana_dart_lint`, which loads because the plugin depends on no nidana package.
- Publication follows the member graph, `nidana_dart_contracts` first, because outside the workspace a hosted constraint resolves against pub.dev.
- Spec §3.11 and Guide Appendix C.2 name custom_lint for Dart, and Guide Appendix C.2 groups the single-writer and scope checks under `nidana_dart_lint`; this tree uses neither (marked for upstreaming).
- `.gitignore`'s comment about non-member examples describes a case this layout never creates; its ignore rule stays correct for `docs/`.

### ADR-003: Time source and virtual scheduler on Dart · accepted
**Decision**
Resolves OQ7 and the clock-control part of OQ2.

1. **The provider is a zone and a clock.** On Dart, the `SchedulerProvider` of Spec §3.6 is a pair: a `Zone`, through which every timer, periodic timer and microtask the bus causes is created, and a `Clock` from `package:clock`, from which every time value the bus produces is read. A bus holds one provider, fixed at construction. Exactly two providers exist; applications cannot define another.
   - The **production provider**, `BusConfig`'s default, is the zone current when the bus is constructed, used as it is without a fork, and `package:clock`'s `clock` as read at that moment. Both are captured when the bus is constructed, not when the config value is built. It intercepts nothing. A bus constructed inside `fakeAsync`, inside `withClock` or inside a `testWidgets` body therefore runs on that zone's timers and that clock, wherever its operations are later called from.
   - The **virtual provider**, `VirtualSchedulerProvider`, wraps a `VirtualScheduler` (item 5).

2. **The bus works inside the provider zone.**
   - Every subscription the bus makes, for topology activation and for its internal wiring, is made inside the provider zone.
   - `bus.observe(topic)` returns a stream whose `listen` subscribes inside the provider zone, so a subscriber's callbacks run there whatever zone it listens from. This is the Dart form of what Spec §3.3 has `bus.observe` do on Combine: subscribe on the topic's delivery dispatcher. A subscriber's errors go to the zone in which `listen` was called (Spec §10.2 principle 5): an exception that its `onData`, `onError` or `onDone` callback throws, a handler it sets later through its `StreamSubscription` included, and an error event it leaves without an `onError` handler, go at once to the uncaught-error handler of that zone, which is the provider zone's only when the subscriber listened from the provider zone. The delivery goes on: the remaining subscribers receive the value, the publish or scheduler operation running the delivery returns normally, and the throwing subscriber keeps receiving later values. The bus catches only what a subscriber's callbacks throw; an exception its own delivery code raises is not caught by this rule.
   - Observers (Spec §3.7) are invoked inside the provider zone.
   - The bus creates its own timers and schedules its own microtasks in the provider zone explicitly, whatever zone the call arrives in: the reentrancy deferral (Spec §3.4); the startup barrier's dev-mode window (Spec §3.13), created by the first queued publish and cancelled by `start()`; the module grace timer (Spec §7.3). A grace period of zero tears the module down synchronously on the last release, with no timer.
   - `shutdown()` cancels every timer the bus created and, by cancelling every pipeline subscription, every timer its pipelines created. No such timer stays pending after it.

3. **Nothing leaves the provider zone.** Work that a bus operation or a topology pipeline starts completes inside the provider zone: no nidana code awaits or chains on a future created outside it, and none chains on the future `StreamSubscription.cancel()` returns, which is the SDK's root-zone future when nothing is pending. The live `switchMap` of the topology DSL cancels the previous inner subscription without waiting for its cancel future and listens to the next inner stream at once. RxDart 0.28's `switchMap` waits for that future, so the runtime does not use it unchanged.

4. **Time-dependent combinators are RxDart's.** The topology DSL's time-dependent combinators, whichever of debounce, throttle, delay, sample, buffer, timeout and timed retry topology-dsl@v2 names, are RxDart 0.28's operators or `Stream.timeout` from `dart:async`, applied inside the pipeline. They take no scheduler argument. Because the pipeline subscribes inside the provider zone, every timer they create, periodic ones included, is a provider-zone timer, and cancelling the pipeline cancels it.

5. **The virtual scheduler.** `VirtualScheduler` is nidana's own, in the runtime's `testing.dart`; no nidana package depends on `fake_async`. It owns a zone, forked from the zone current when the scheduler is constructed, that intercepts `createTimer`, `createPeriodicTimer` and `scheduleMicrotask` and never forwards them, and a virtual clock, which is also `package:clock`'s `clock` inside that zone. Virtual time starts at a fixed instant, whose default bus-testing@v2 names and which the constructor can override; it never reads the wall clock and never moves backward. The three operations of Spec §3.6 are synchronous:
   - `triggerActions()` runs queued microtasks in order, and timers due at the current virtual time in due-time and creation order, running every queued microtask before each timer, until no microtask is queued and no timer is due. Virtual time does not move.
   - `advanceTimeBy(duration)` runs `triggerActions()`, then repeatedly moves virtual time to the earliest timer due at or before the target and runs `triggerActions()` there, then sets virtual time to the target and runs `triggerActions()` once more. A periodic timer fires once for each period crossed, and a timer created during the advance and due within it fires within it. A negative duration throws `ArgumentError`.
   - `advanceTimeTo(timestamp)` is `advanceTimeBy` up to that instant; an instant before the current virtual time throws `ArgumentError`.
   - Calling an operation from inside work the scheduler is running throws `StateError`. An operation that runs more actions than a bound, whose default bus-testing@v2 names, throws `StateError`; that is how a microtask loop or a zero-period periodic timer shows up.
   - Scheduled work runs guarded: an exception that reaches the scheduler goes to the error zone the scheduler was constructed in, and the operation carries on. What a `bus.observe` subscriber's callbacks throw does not reach it, because item 2 sends that to the zone the subscriber listened from.
   - When an operation returns, the scheduler is quiescent: no microtask is queued and no timer is due at the current virtual time. Timers due later stay pending; the scheduler reports how many are pending and when the next one is due, so a test can assert that a timer was cancelled.

6. **TestBus.** `TestBus(config)` is a bus whose provider is virtual: `config`'s provider when it is a `VirtualSchedulerProvider`, a fresh one when `config` leaves the default. A production provider is rejected with `ArgumentError`. A TestBus exposes its scheduler.
   - Everything that bus operations, topology pipelines and `bus.observe` subscriptions schedule is delivered by the scheduler operations alone. A test that drives a TestBus through bus operations and scheduler operations therefore runs synchronously, without `await`, including the first delivery of state and replay topics. A topology activated or a subscription made during bootstrap is connected at `start()` (Spec §3.13) and receives its first values within `start()`, which connects the topologies first, in the connection order, delivering what each connection causes before the next connects, then the subscriptions, in the order they listened, and delivers the queue last (bus-api@v2 G34); a subscription made after `start()` receives its replay in the first provider-zone microtask after `listen` returns (Spec §2.1 "Replay timing"; bus-api@v2 G17, which resolved OQ-R1). This holds for a subscriber that listens from its own zone, such as a test body: its callbacks run in the provider zone (item 2), and only the errors they throw go to its zone.
   - Work that starts outside the provider zone reaches it only across a real event-loop turn: a future the test completes, a timer the test or a shell service creates outside a bus callback, an operator that waits on a future created outside the zone, such as RxDart's `switchMap` chained onto an observed stream. For such tests bus-testing@v2 provides an asynchronous settle operation that alternates `triggerActions()` with real event-loop turns until the scheduler stays quiescent across a turn, up to a bound. The `settle()` of an ADR-001 harness over a TestBus uses it. Settling needs a real event loop, so it is never awaited inside `fakeAsync` or a `testWidgets` body.
   - The envelope recorder attaches to a bus with either provider, so a widget test records envelopes on a production-provider bus.

7. **Flutter widget tests run the production provider.** `tester.pump(duration)` then drives every bus timer and the bus's clock.
   - The bus is constructed inside the test body; one constructed in `setUp` or at file level runs on real time.
   - No bus timer may be pending when the body ends, because flutter_test fails the test once it has unmounted the tree, before tear-downs run. The adapter's widget-test helpers construct the bus in the body and shut it down from the `dispose` of a widget above every scope binding, which runs after the bindings' own `dispose` has released their scope references. A test that constructs its own bus shuts it down before the body ends.
   - A widget test never puts a `VirtualScheduler` behind the bus: `tester.pump` would not move its clock.

8. **Time values come from the provider clock.** Envelope timestamps (Spec §2.4), the dev-mode window, the route transition timestamps navigation executors write, and the durations the telemetry observer measures, through the clock's `stopwatch()`, all come from the provider clock. bus-api@v2 exposes the provider clock, read-only, to shell code that stamps values, so an executor's timestamps share the bus's clock. No nidana package calls `DateTime.now()`, constructs a `Stopwatch` directly, or creates a timer or microtask outside a provider zone. `nidana_dart_contracts` reads no clock and schedules nothing: a function that needs a timestamp or a fresh id takes it as an argument.

9. **One dispatcher per bus.** On Dart, Spec §3.6's per-topic delivery dispatcher is the provider zone on the bus's isolate, the same for every topic. No per-topic dispatcher choice exists, and `bus.observe` performs no dispatcher hop (Spec §11.1).
**Consequences**
- On a TestBus, topologies and every bus operation are deterministic (Rationale §3.2) and need neither real time nor `await`. A test that stubs a shell service with futures it completes itself awaits the settle operation.
- TestBus tests stub every effect. Real I/O started inside the provider zone delivers only when a scheduler operation or the settle operation runs after it arrives, and a shell service's own timers created outside bus callbacks run on real time.
- A `bus.observe` subscriber's callbacks run in the provider zone, not in its own: zone values it set are not visible there, and `package:clock`'s `clock` read there is the provider clock. What those callbacks throw goes to the uncaught-error handler of the zone the subscriber listened from, as Spec §10.2 principle 5 requires: a subscriber that a test body listened with fails that test when it throws, whichever zone built the TestBus, and a widget's subscription reports to the zone the widget subscribed from. Errors from work the bus schedules itself still reach the provider zone's handler, which on a TestBus is the handler of the zone its scheduler was constructed in (item 5), so an app constructs its bus inside the zone its error handling lives in, for example inside `runZonedGuarded` before `runApp`.
- Sending a subscriber's errors to the zone it listened from costs one guarded call per delivery per subscriber, about 8 ns on the VM.
- Operators an application chains onto an observed stream run their timers in the provider zone when RxDart creates them during delivery, and in the application's zone when it creates them at `listen`. The final callback of such a chain runs in the zone the chain was listened from, as on any Dart stream, so its zone values, its errors and the timers it creates are that zone's (`docs/auto-run/experiments/subscriber-error-zone/` C9). nidana guarantees virtual time only for what the bus and topology pipelines schedule.
- An application's own RxDart `switchMap` that switches while its previous inner stream is live resubscribes only from the root microtask queue: on a TestBus after the settle operation, and never within a `testWidgets` body or a `fakeAsync` block.
- nidana.runtime owns the live `switchMap`, including what it does with an error from the previous inner's cancel; every other live combinator is RxDart's.
- The production provider adds no zone of its own, so a bus used from its construction zone delivers as a bare subject would.
- bus-api@v2 states the two providers, the zone rule for `bus.observe` and observers, where a subscriber's errors go, timer cancellation at shutdown, the clock accessor, and when a subscription connected at `start()` receives its first values, as guarantees (G5, G17, G18, G29, G34, G36). Its G41 states what happens to a value that an access cannot convert at its own type argument: a subscription receives a `TypeError` error event in its place, which reaches its `onError` or, without one, the uncaught-error handler of the zone it listened from, as item 2 has it for any error event left unhandled; a topology read raises the `TypeError` at the read stage, a pipeline error that a `catchError` on its path recovers and that otherwise ends every write chain it reaches; the bus sends neither to the provider zone's handler. bus-testing@v2 states the scheduler operations, quiescence, the bounds, the fixed start instant and the settle operation (G5 to G10, G12), and that a subscriber's errors reach the zone the test listened from rather than the scheduler's (G3, G11). Their behavior fixtures run on the VM and need no `fake_async`.
- Inside `testWidgets` the provider clock starts at the wall-clock time of the test start, so widget tests compare timestamps as differences.
- flutter-binding@v2's widget-test helpers own bus shutdown at unmount. navigation-api@v1's executor protocol stamps route transitions from the bus's clock.
- A per-topic dispatcher hint in a topic declaration can have no effect on Dart; topic-model@v1 carries none (its G5, which resolved OQ-M3).
- No v1 lint enforces item 8. A phase gate can search the sources for `DateTime.now(`, `Stopwatch(` and timers created outside the provider implementation.
- Marked for upstreaming: Spec §3.6 and Guide §6.5 do not say how scheduler injection works on Dart, and Guide §6.5 names an `EventLoopScheduler` that RxDart does not have; Guide §10.1's clock-control question has a Dart answer here; Spec §2.3 says the bus implements no schedulers and no stream combinators, while on Dart the test scheduler and the live `switchMap` are nidana's, because RxDart has no scheduler and its `switchMap` escapes every fake-time zone; Spec §11.2's "in `tearDown`" for tests does not hold under flutter_test, which needs the bus shut down before the test body ends; Spec §10.2 principle 5 and Guide §6.1 say which zone a Dart subscriber's error goes to but not which zone its callbacks run in, and on Dart this decision runs them in the provider zone while sending their errors to the zone in which `listen` was called, which no Dart stream does by default.

## Open questions
- OQ-M1 · RESOLVED (2026-10-18): topology-ir@v1 G9 · How does the recorder name a transformer (`FunctionRef`) in Dart?
- OQ-M2 · RESOLVED (2026-10-18): topology-dsl@v2 G18 and Refinement 3, with topology-ir@v1 G4 · How does live activation obtain the transformers a pure-data IR names?
- OQ-M3 · RESOLVED (2026-10-18): topic-model@v1 G5 · Does the Dart topic model carry Spec §3.6's per-topic dispatcher hint at all?

## Discipline
- Test-first: write each behavior's failing test, and see it fail, before
  the code that makes it pass.
- Governance freeze: change nothing under hsdd/ except this phase's
  verification doc; contracts, ADRs, specs and conventions change only
  through hsdd-contract, hsdd-adr and hsdd-reconcile.
- Consume contracts only: build against the Interface and Guarantees above,
  never against another node's internals.
- Contract wrong mid-phase: pause at a task boundary; write the gap, in
  request or amend wording, under the verification doc's Outstanding and
  stop; the human records it in the node's plan, renegotiates at the root
  through hsdd-contract, and propagates the change into this phase's branch;
  re-run the phase switch; resume. Never improvise around the contract.
- Verification doc: hsdd/verify/nidana.model.4.verification.md from
  hsdd/templates/verification.md at gate-only depth. Every Learning
  carries one disposition before sign-off; "- none" is valid, silence is not.
- Contract replay: the gate validates this phase's real output against the
  schema and reproduces the fixtures of topology-dsl@v2.

## Links (spec a8d43df)
- Phase section: hsdd/spec/nidana.model.md, heading "### nidana.model.4: topology-dsl@v2 declarations"
- Node spec: hsdd/spec/nidana.model.md
- topic-model@v1: hsdd/contract/topic-model.md
- topology-dsl@v2: hsdd/contract/topology-dsl.md
- ADR-001: hsdd/adr/001-executable-contract-validation.md
- ADR-002: hsdd/adr/002-package-workspace-layout.md
- ADR-003: hsdd/adr/003-time-source-virtual-scheduler.md
- Conventions: hsdd/conventions.md
- Verification template: hsdd/templates/verification.md
