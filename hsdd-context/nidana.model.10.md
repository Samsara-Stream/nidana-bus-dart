<!-- hsdd-phase-context {"phase":"nidana.model.10","spec":"e9f2289","date":"2026-10-27"} -->
# Current Phase: nidana.model.10 - IR values and function references

## Goal
under `lib/src/ir/`: `TransformEdge`'s three factories with the stage-edge table, `reduceInto` rejected by `stage` and accepted by its own factory only on a state topic, a zero duration accepted and a negative one rejected (G5); `TopologyDefinition`'s well-formedness rules and its `reads` and `writes` derived in canonical order (G6); the Interface's four canonical orders as shared comparators; `isStateBearing` (G10); `FunctionRef.of`, `named` and `anonymous` (G9, which decides OQ-M1); `CombinatorKind`'s order (G2); value equality, hash codes and unmodifiable copies of every IR value; and under `lib/src/analysis/` the value semantics of `TopologyCycle`, `SelfReference`, `WriterConflict`, `ScopeViolation`, `TopicDeclaration` and `TopicNameCollision`, whose constructors normalize their lists to the orders the Interface names (topology-ir@v1 G23). G3 and G7 join the restriction at nidana.model.11, because their cases also cover graphs and claims, and G23 at nidana.model.12, because its case also runs the analyses over a sample graph that `buildDefinition()` records.

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
- **Produces:** [topology-ir@v1]
- **Governed by:** [ADR-001, ADR-002]
- **Scope:** under `lib/src/ir/`: `TransformEdge`'s three factories with the stage-edge table, `reduceInto` rejected by `stage` and accepted by its own factory only on a state topic, a zero duration accepted and a negative one rejected (G5); `TopologyDefinition`'s well-formedness rules and its `reads` and `writes` derived in canonical order (G6); the Interface's four canonical orders as shared comparators; `isStateBearing` (G10); `FunctionRef.of`, `named` and `anonymous` (G9, which decides OQ-M1); `CombinatorKind`'s order (G2); value equality, hash codes and unmodifiable copies of every IR value; and under `lib/src/analysis/` the value semantics of `TopologyCycle`, `SelfReference`, `WriterConflict`, `ScopeViolation`, `TopicDeclaration` and `TopicNameCollision`, whose constructors normalize their lists to the orders the Interface names (topology-ir@v1 G23). G3 and G7 join the restriction at nidana.model.11, because their cases also cover graphs and claims, and G23 at nidana.model.12, because its case also runs the analyses over a sample graph that `buildDefinition()` records.
- **Size estimate:** ~6 files (~400 lines, tests included), ≤ 7 plan tasks
- **Gate:** `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl --set structure,surface,reject && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G9,G10`
- **Verification:** `FunctionRef.of` gives on the VM the names topology-ir@v1's derivation table lists; an edge or a definition that breaks a rule throws at construction, so no ill-formed IR value exists.
- **Review tier:** spot-check
- **Collides with:** [nidana.model.4, nidana.model.5]. It fills `lib/src/ir/` and the value types of `lib/src/analysis/` that those phases declared.
- **Dependencies:** nidana.model.8 (topic reference equality and source rendering, which IR equality and the canonical orders use)

## Contracts
### topic-model@v1 · consumes · stable
**Interface**
**Library:** `package:nidana_dart_contracts/nidana_dart_contracts.dart`, the main library of the package `nidana_dart_contracts` at `packages/nidana_dart_contracts/` (ADR-002 item 3). This contract defines no second public library; the same main library carries the declarations of topology-dsl@v2 and topology-ir@v1 unless those contracts name a library of their own. **Code owner:** nidana.model, whose first producing phase lands every declaration below (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/fixture/topic-model/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.model.3 lands every declaration, and a consumer's edge on this contract alone waits on it; a consumer of topology-dsl@v2 or topology-ir@v1 as well waits on nidana.model.5, where their declarations complete: the main library the three contracts share after nidana.model.4, and `topology_ir.dart` after nidana.model.5. A `hard` edge waits instead on nidana.model.8, the last producing phase (nidana.integration). Until nidana.model.8 merges, a body that computes throws `UnimplementedError` and values compare by identity; nidana.model.8 delivers every behavior guarantee.

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

### topology-ir@v1 · produces · stable
**Interface**
**Libraries:** `package:nidana_dart_contracts/nidana_dart_contracts.dart`, the main library of `nidana_dart_contracts` at `packages/nidana_dart_contracts/`, carries every declaration under The IR and Function references; `package:nidana_dart_contracts/topology_ir.dart`, a second public library named by this contract (ADR-002 item 3), carries every declaration under Graphs, Renderers, The JSON form and Analyses. `topology_ir.dart` does not re-export the main library. Both import nothing beyond the SDK (`dart:convert` included), `package:meta` and the package's own libraries (topic-model@v1 G26). **Code owner:** nidana.model, by whose first producing phase every declaration below has landed (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/schema/topology-ir.schema.json` and `hsdd/contract/fixture/topology-ir/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.model.4 lands the declarations under The IR and Function references with topology-dsl@v2's, because `TopologyDefinition`, which `buildDefinition()` returns, names them; nidana.model.5 lands those under Graphs, Renderers, The JSON form and Analyses, and a consumer's edge on this contract waits on it. A `hard` edge waits instead on nidana.model.14, the last producing phase (nidana.integration). Until the phase that delivers it merges, a body that computes throws `UnimplementedError` and a value compares by identity: nidana.model.10 delivers the IR values, `TransformEdge`'s rules, `FunctionRef`, `isStateBearing` and the findings' value semantics (G2, G5, G6, G9, G10, G23); nidana.model.11 the projection, `ShellClaim` and `TopologyGraph` (G3, G7, G8, G11, G12); nidana.model.12 the analyses (G13 to G18); nidana.model.13 the JSON codec and `JsonRenderer` (G4, G19 to G21); nidana.model.14 the Mermaid and Graphviz renderers (G22).

The declarations are the schema of the Dart surface (ADR-001 item 4); the JSON Schema is the schema of the serialized form (ADR-001 item 5). Bodies are omitted; the comments, the rules and the guarantees state the semantics. Every class here other than the sealed bases `EdgeInput` and `TopologyFinding` and the interface `GraphRenderer` is final; every value type is immutable (annotated `@immutable`) with value equality.

**Canonical orders**, used wherever a rule below says "in canonical order":

- topic references: by `name` (`String.compareTo`), then `variant` (state, event, replay), then `typeName`;
- topologies: by `topologyId`;
- claims: by `source.toString()`, then `scope` (application, module, page), then their `writes` element by element in canonical order, a shorter list first when one is a prefix of the other;
- message sources: by `toString()`.

### The IR

```dart
/// The combinator of an edge (Spec §6.5, Appendix A.4): one value per stage
/// class of topology-dsl@v2 other than ReadStage, and one for reduceInto, in
/// topology-dsl@v2's combinator-table order.
enum CombinatorKind {
  map, filter, combine, withLatestFrom, merge, switchMap, scan, pairwise,
  distinctUntilChanged, debounce, throttle, delay, sample, buffer, timeout,
  catchError, rawEngine, reduceInto,
}

/// What an edge consumes (Spec §6.5 `inputs`). Sealed.
sealed class EdgeInput {}

/// The values one read of [topic] delivers: a ReadStage of the plan. [dedup]
/// is the read's argument, null when the read kept the topic's own policy
/// (topology-dsl@v2 G13).
final class TopicInput extends EdgeInput {
  const TopicInput(TopicRef topic, {Dedup? dedup});
  TopicRef get topic;
  Dedup? get dedup;
}

/// The values the stage edge at index [edge] of the same definition's
/// transforms emits. [edge] is asserted non-negative.
final class StageInput extends EdgeInput {
  const StageInput(int edge);
  int get edge;
}

/// One element of a topology's wiring other than a read (Spec §6.5): a stage
/// edge, whose values only later edges consume, or a sink edge, whose values
/// are published to [output]. No public unnamed constructor.
final class TransformEdge {
  /// A non-read stage. Throws ArgumentError when [combinator] is reduceInto,
  /// or when the inputs, transformer, duration or retry do not fit the
  /// combinator (the table below), or for a negative [duration].
  factory TransformEdge.stage(
    CombinatorKind combinator,
    List<EdgeInput> inputs, {
    FunctionRef? transformer,
    Duration? duration,
    FunctionRef? retry,
  });

  /// A write: [input]'s values published to [topic] unchanged.
  factory TransformEdge.write(TopicRef topic, EdgeInput input);

  /// A reduceInto folding [events] into [topic] with [reducer]. Throws
  /// ArgumentError unless [topic] is a state topic.
  factory TransformEdge.reduceInto(
      TopicRef topic, EdgeInput events, FunctionRef reducer);

  CombinatorKind? get combinator;   // null exactly for a write
  List<EdgeInput> get inputs;       // unmodifiable copy, in input order
  TopicRef? get output;             // a sink's topic; null for a stage
  FunctionRef? get transformer;     // the edge's function, when it holds one
  Duration? get duration;           // the six time stages only
  FunctionRef? get retry;           // a switchMap with a retry policy only
  bool get isSink;                  // output != null
  bool get isStateBearing;          // Spec §3.8; the rule below
}

/// The IR of one topology (Spec §6.5, Appendix A.4).
final class TopologyDefinition {
  /// Throws ArgumentError for an empty [topologyId] or ill-formed
  /// [transforms] (the rules below).
  factory TopologyDefinition({
    required String topologyId,
    required Scope scope,
    required List<TransformEdge> transforms,
  });

  String get topologyId;
  Scope get scope;
  Set<TopicRef> get reads;            // the topics of every TopicInput; canonical order; unmodifiable
  Set<TopicRef> get writes;           // the outputs of the sink edges; canonical order; unmodifiable
  List<TransformEdge> get transforms; // unmodifiable copy
}
```

**What a stage edge holds**, per combinator (`TransformEdge.stage`):

| `CombinatorKind` | Inputs | `transformer` | `duration` | `retry` |
|------------------|--------|---------------|------------|---------|
| `map`, `filter`, `scan`, `catchError`, `rawEngine` | 1 | required | none | none |
| `switchMap` | 1 | required | none | optional |
| `combine` | 1 or more | required | none | none |
| `withLatestFrom` | 2 to 4, the primary first | required | none | none |
| `merge` | 1 or more | none | none | none |
| `pairwise`, `distinctUntilChanged` | 1 | none | none | none |
| `debounce`, `throttle`, `delay`, `sample`, `buffer`, `timeout` | 1 | none | required, not negative | none |

A write has one input and nothing else; a reduceInto has one input and a transformer.

**State-bearing edges** (Spec §3.8, topology-dsl@v2's Self-reference column): `isStateBearing` holds for `scan` and `reduceInto`, and for `debounce`, `delay`, `sample` and `buffer` with a positive duration; for no other edge. The IR carries every time stage's duration so that this rule is decided from the IR alone.

**A well-formed definition.** `TopologyDefinition` rejects with ArgumentError: an empty `topologyId`; a `StageInput` whose index is negative, is not below its own edge's index, or names a sink edge; a stage edge after a sink edge; a stage edge no later edge consumes; a second sink edge on one state topic (topology-dsl@v2 G14). `reads` and `writes` are derived, never given.

**Equality.** Two definitions are equal exactly when their `topologyId`, `scope` and `transforms` (element by element) are equal; two edges exactly when all six fields are equal, `inputs` element by element; inputs and function references by their fields. A definition does not record a `scan`'s initial value, a closure's body, or which of two functions rendering the same name a stage holds, so two declarations that differ only there project to equal definitions.

### From a plan

`TopologyPlan.definition` (topology-dsl@v2) projects a plan to a definition, and `buildDefinition()` returns it:

1. One stage edge per non-read stage of the plan, in stage order, then one sink edge per sink, in sink order. Read stages are not edges.
2. A stage's handle becomes `TopicInput(topic.ref, dedup: dedup)` when the handle is a `ReadStage`, else `StageInput(i)`, where `i` is the index of that stage's edge.
3. A stage edge's combinator is topology-dsl@v2's `CombinatorKind` for its class; its inputs are the stage's in order: `input` for single-input stages, `inputs` for `CombineStage` and `MergeStage`, `primary` then `latest` for `WithLatestFromStage`.
4. Its `transformer` is `FunctionRef.of` the function the stage holds: `transform`, `test`, `combiner`, `toStream`, `accumulator`, `recover`, `operator`. Its `duration` is the stage's for the six time stages. Its `retry` is `FunctionRef.of(retry)` for a `SwitchMapStage` with a retry policy.
5. A `WriteSink` becomes `TransformEdge.write(topic.ref, input)`; a `ReduceIntoSink` becomes `TransformEdge.reduceInto(topic.ref, events, FunctionRef.of(reducer))`.

Projection calls none of the plan's functions (topology-dsl@v2 G10): `FunctionRef.of` reads a function's `toString()`, nothing else. Every definition a plan projects to is well formed, because `planOf` already rejects a stage that reaches no sink and a second sink on one state topic.

### Function references

```dart
/// A serializable reference to a transformer (Spec §6.5, Appendix A.4): a
/// name, or anonymous. It holds no function and is not a Function.
final class FunctionRef {
  /// Throws ArgumentError for an empty [name].
  FunctionRef.named(String name);
  const FunctionRef.anonymous();

  /// The name the Dart VM renders for [function] (decides OQ-M1): the text
  /// between `from Function '` and the next `'` in function.toString(),
  /// anonymous when that text is absent or empty. Never calls [function].
  factory FunctionRef.of(Function function);

  String? get name;   // null when anonymous
}
```

What the derivation yields on the pinned SDK, from `docs/auto-run/experiments/function-ref-derivation/` and, for private names, `docs/auto-run/experiments/function-ref-private-key/`:

| Function form | JIT and AOT | AOT with `--obfuscate` | dart2js, dart2wasm |
|---------------|-------------|------------------------|--------------------|
| top-level function, `buildTotal` | `buildTotal` | an obfuscated name, stable within the build | anonymous |
| static method `Reducers.reduceCount` | `reduceCount` (no class) | obfuscated | anonymous |
| instance method tear-off `formatter.format` | `format` | obfuscated | anonymous |
| generic function, instantiated or not | its name | obfuscated | anonymous |
| constructor tear-off `Box.new` | `Box.` | obfuscated | anonymous |
| implicit `call` tear-off of a callable object | `call` | `call` | anonymous |
| inline closure, closure in a variable, local function, extension method tear-off | anonymous | anonymous | anonymous |
| a form above with a private name: `_reduce`, `Reducers._reduce`, `formatter._format`, `Box._internal`, `_Box.new` | `@{key}` after each private identifier: `_reduce@{key}`, `_reduce@{key}`, `_format@{key}`, `Box._internal@{key}`, `_Box@{key}.`; the key differs between JIT and AOT, and between programs and runners (Private names, below) | obfuscated, `@{key}` kept | anonymous |

A name is a label for graphs and for equality, not an identity: two static methods of one name in different classes render alike. The catalog and the CI checks run on the VM, where public names are as written (Spec §6.2 names transformers as standalone functions). A web build gets anonymous references only, never a compiler's internal name: dart2js renders inline closures as `main_closure`, which the derivation does not read.

**Private names.** The VM renders a private identifier followed by `@` and its library's key, and the derivation keeps the key, because it takes the text as rendered (G9). Within one process every private name of a library carries the same key. The key belongs to the process, not to the source: it changes with the library's URL and with how many libraries the program loads before that library, so one library's key differs between a JIT and an AOT build of one program (`@22518013` against `@18518013`), between `dart run` and the Flutter tester (`@21518013`), and between two programs that load other libraries, or the same libraries in another order, ahead of it; the same program under the same runner gets the same key on every run (`docs/auto-run/experiments/function-ref-private-key/`). A definition, graph or graph document holding a private transformer therefore renders differently, and compares unequal (G7), when another program or runner records it: the build-time catalog's JIT recording equals an AOT app's `bus.toGraph()` only when every transformer is public (topic-codegen@v1's `definitions` bullet; nidana.integration D8 keeps its example's transformers public for this reason). Within one process, recording one declaration twice still projects equal definitions (G8). The key is `@` followed by digits; outside an obfuscated build, removing each key gives the name as written (`_Holder@22518013._secret@22518013` reads `_Holder._secret`). This describes what G9's rule yields and adds no guarantee; the behavior case for it asserts the `@` and a key, never the key's value.

### Graphs

Library `package:nidana_dart_contracts/topology_ir.dart`.

```dart
/// A shell publisher's claim (Spec §2.4, §3.11, §7.2): its source, the scope
/// it is bound to (application when unbound), and the state topics it
/// claims. Throws ArgumentError when [source] is a TopologySource or
/// UnknownSource, or [writes] is empty or names a topic that is not a state
/// topic.
final class ShellClaim {
  factory ShellClaim({
    required MessageSource source,
    Scope scope = Scope.application,
    required Set<TopicRef> writes,
  });
  MessageSource get source;
  Scope get scope;
  Set<TopicRef> get writes;   // canonical order; unmodifiable copy
}

/// Topologies and shell claims (Spec §6.5, Appendix A.4, A.9): the active
/// set behind bus.toGraph(), or the static set a catalog scans.
final class TopologyGraph {
  /// Throws ArgumentError when two definitions share a topologyId and are
  /// not equal; equal ones count once (Spec §3.9).
  factory TopologyGraph({
    Iterable<TopologyDefinition> topologies = const <TopologyDefinition>[],
    Iterable<ShellClaim> claims = const <ShellClaim>[],
  });

  List<TopologyDefinition> get topologies; // by topologyId, distinct ids; unmodifiable
  List<ShellClaim> get claims;             // canonical order, equal claims kept; unmodifiable
  List<TopicRef> get topics;               // every topic read or written, canonical order; unmodifiable

  /// renderer.render(this).
  String render(GraphRenderer renderer);
}

extension TopologyDefinitionGraph on TopologyDefinition {
  /// Spec §6.5's ir.toGraph(): TopologyGraph(topologies: [this]).
  TopologyGraph toGraph();
}
```

A graph keeps equal claims as separate claimants: two publishers constructed with the same source and the same writes are two writers (G15). Two graphs are equal exactly when their topologies and claims, in their canonical orders, are equal.

### Renderers

```dart
/// Renders a graph as text (Spec §6.5, Appendix A.4 "other graph
/// formats"). Applications may implement it.
abstract interface class GraphRenderer {
  String render(TopologyGraph graph);
}

final class MermaidRenderer implements GraphRenderer { const MermaidRenderer(); }
final class GraphvizRenderer implements GraphRenderer { const GraphvizRenderer(); }

/// The graph document as JSON text (The JSON form).
final class JsonRenderer implements GraphRenderer { const JsonRenderer(); }
```

**Mermaid and Graphviz rules.** Node ids: topic `i` of `graph.topics` is `t{i}`; topology `j` of `graph.topologies` is `p{j}`, and its edge `k` is `p{j}e{k}`; claim `m` of `graph.claims` is `s{m}`. Labels are lines of text, each escaped, then joined by the renderer's line break:

- topic: its name; its variant and type name, separated by one space;
- topology: its `topologyId`; its scope;
- edge: the combinator's name, or `write` for a write, followed by one space and the duration when the edge has one; the transformer's name when it has one; `retry` and the retry's name when it has one. An anonymous reference renders as `(anonymous)`. A duration renders as whole seconds `{n}s` when it is a multiple of a second, else whole milliseconds `{n}ms` when it is a multiple of a millisecond, else `{n}us`;
- claim: its source rendering; its scope.

Output, in order, with two-space indentation per level:

| Part | Mermaid | Graphviz |
|------|---------|----------|
| header | `flowchart LR` | `digraph topologies {` then `rankdir=LR;` |
| each topic | `t{i}(["{label}"])` | `t{i} [shape=ellipse, label="{label}"];` |
| each topology, its edges inside | `subgraph p{j}["{label}"]`, then `p{j}e{k}["{label}"]` per edge, then `end` | `subgraph cluster_p{j} {`, then `label="{label}";`, then `p{j}e{k} [shape=box, label="{label}"];` per edge, then `}` |
| each claim | `s{m}["{label}"]` | `s{m} [shape=box, style=rounded, label="{label}"];` |
| arrows | `{from} --> {to}`, or `{from} -->\|dedup {policy}\| {to}` | `{from} -> {to};`, or `{from} -> {to} [label="dedup {policy}"];` |
| footer | none | `}` |

Arrows come per topology in graph order, per edge in order: one from each input, in input order, to the edge (from `t{i}` for a `TopicInput`, labeled with its dedup when it has one; from `p{j}e{n}` for a `StageInput(n)`), then, for a sink edge, one from the edge to its output topic; then per claim, one to each claimed topic in canonical order. Every line ends with a newline. Escaping: Mermaid replaces `#` with `#35;`, then `"` with `#quot;`, `<` with `#lt;`, `>` with `#gt;` and a newline with `#10;`, and breaks lines with `<br/>`; Graphviz replaces `\` with `\\`, `"` with `\"` and a newline with `\n`, and breaks lines with `\n`. The goldens under `render/` were parsed by Mermaid 11.12.0 and laid out by Graphviz 14.0.1 (`docs/auto-run/experiments/topology-ir-fixtures/`).

### The JSON form

```dart
/// The graph document of [graph] as a JSON value (maps, lists, strings,
/// integers, booleans and null), keys in the order the schema lists them.
Map<String, Object?> encodeTopologyGraph(TopologyGraph graph);

/// The graph a graph document describes. Throws FormatException, and no
/// other error, for any value that is not a graph document of this version
/// or breaks a rule of the decoder.
TopologyGraph decodeTopologyGraph(Object? json);

/// The object a graph document lists for [definition], and its inverse.
Map<String, Object?> encodeTopologyDefinition(TopologyDefinition definition);
TopologyDefinition decodeTopologyDefinition(Object? json);
```

The graph document, keys in this order; `hsdd/contract/schema/topology-ir.schema.json` (draft 2020-12) states it exactly. An example, which validates and round-trips (`docs/auto-run/experiments/topology-ir-fixtures/interface-example.json`), laid out compactly here; `JsonRenderer` indents every level by two spaces:

```json
{
  "format": "topology-ir@v1",
  "topologies": [
    {
      "topologyId": "search",
      "scope": "page",
      "reads": [{ "name": "search.query", "variant": "state", "typeName": "String" }],
      "writes": [{ "name": "search.results", "variant": "state", "typeName": "Results" }],
      "transforms": [
        {
          "combinator": "debounce",
          "inputs": [{ "topic": { "name": "search.query", "variant": "state", "typeName": "String" }, "dedup": "none" }],
          "durationMicros": 300000
        },
        {
          "combinator": "switchMap",
          "inputs": [{ "edge": 0 }],
          "transformer": { "name": "searchApi" },
          "retry": { "name": null }
        },
        {
          "inputs": [{ "edge": 1 }],
          "output": { "name": "search.results", "variant": "state", "typeName": "Results" }
        }
      ]
    }
  ],
  "claims": [
    {
      "source": "service:search-history",
      "scope": "application",
      "writes": [{ "name": "search.history", "variant": "state", "typeName": "History" }]
    }
  ]
}
```

- `TopicRef` is `{name, variant, typeName}`, the variant and a `Scope` by enum name; a `MessageSource` is its rendering (topic-model@v1 G17); a `Dedup` by enum name; a `FunctionRef` is `{"name": string}` or `{"name": null}`; a duration is `durationMicros`, an integer.
- An edge carries `combinator` (absent for a write), `inputs`, then `output`, `transformer`, `durationMicros` and `retry` only where the edge has them. An input is `{"topic": TopicRef}`, with `"dedup"` only when the read gave one, or `{"edge": n}`.
- The encoder lists topologies, claims, `reads`, `writes` and each claim's `writes` in canonical order. The decoder accepts those lists in any order and re-encodes them in canonical order.
- The decoder also enforces what the schema cannot state: the definition rules above, `reads` and `writes` equal to the topics the edges read and the sink edges write, each once, and distinct topology ids.
- `JsonRenderer` renders `JsonEncoder.withIndent('  ')` of the encoding, followed by a newline. `topology-graph.json` (Guide C.3) is that rendering of the catalog's graph: nidana.tooling emits it through topic-codegen@v1, which names its path and generator, and nidana-checks@v1's workspace scan reads the same graph.
- The schema is closed (`additionalProperties: false` throughout) and `format` names the contract version, so a v1 decoder rejects a document of another version instead of misreading it.

### Analyses

```dart
/// A finding of the analyses (Spec §3.8, §3.11, §7.2). Sealed.
sealed class TopologyFinding {}

/// Spec §3.8, inter-topology: a strongly connected set of two or more
/// topologies. [topics] are the topics one member writes and another reads.
final class TopologyCycle extends TopologyFinding {
  TopologyCycle({required List<String> topologyIds, required List<TopicRef> topics});
  List<String> get topologyIds;  // sorted
  List<TopicRef> get topics;     // canonical order
}

/// Spec §3.8, intra-topology: [topic] is read and written by [topologyId]
/// through no state-bearing edge. [edges] are the indices of every edge on
/// such a path.
final class SelfReference extends TopologyFinding {
  SelfReference({required String topologyId, required TopicRef topic, required List<int> edges});
  String get topologyId;
  TopicRef get topic;
  List<int> get edges;           // ascending
}

/// Spec §3.11: a state topic with more than one writer. A topology writes
/// as TopologySource(topologyId), a claim as its source.
final class WriterConflict extends TopologyFinding {
  WriterConflict({required TopicRef topic, required List<MessageSource> writers});
  TopicRef get topic;
  List<MessageSource> get writers; // canonical order, one per writer, equal sources repeated
}

/// Spec §7.2: [owner] of the state topic [topic] has a shorter scope than
/// the topology [readerId] that reads it.
final class ScopeViolation extends TopologyFinding {
  const ScopeViolation({
    required TopicRef topic,
    required MessageSource owner,
    required Scope ownerScope,
    required String readerId,
    required Scope readerScope,
  });
  TopicRef get topic;
  MessageSource get owner;
  Scope get ownerScope;
  String get readerId;
  Scope get readerScope;
}

List<TopologyCycle> findTopologyCycles(TopologyGraph graph);
List<SelfReference> findSelfReferences(TopologyDefinition definition);
List<WriterConflict> findWriterConflicts(TopologyGraph graph);
List<ScopeViolation> findScopeViolations(TopologyGraph graph);

/// Every finding: cycles, then the self-references of each topology in graph
/// order, then writer conflicts, then scope violations.
List<TopologyFinding> analyzeTopologyGraph(TopologyGraph graph);

/// A topic declaration a scan found, and where (a label the caller chooses,
/// such as a file and line).
final class TopicDeclaration {
  const TopicDeclaration({required TopicRef topic, required String site});
  TopicRef get topic;
  String get site;
}

/// Spec §4.3: [name] declared more than once.
final class TopicNameCollision {
  TopicNameCollision({required String name, required List<TopicDeclaration> declarations});
  String get name;
  List<TopicDeclaration> get declarations; // by site, then topic in canonical order
}

List<TopicNameCollision> findTopicNameCollisions(Iterable<TopicDeclaration> declarations);
```

The constructors of `TopologyCycle`, `SelfReference`, `WriterConflict` and `TopicNameCollision` sort the lists they are given into the orders these comments name, keeping repeated elements (G23). The orders are therefore invariants of every finding and collision, not only of the analyses' results, and one built in another order equals the one an analysis returns.

What each analysis computes; every returned list is unmodifiable and holds distinct findings except where stated:

- **Cycles.** Over the graph's topologies, an arc runs from a topology A to a different topology B when A writes a topic, of any variant, that B reads. One `TopologyCycle` per strongly connected component of two or more topologies, ordered by the first of its ids. A topology reading its own write is a self-reference, not a cycle; claims take no part, because a shell's reads are not in the IR.
- **Self-references.** For each topic in both `reads` and `writes` of the definition, in canonical order: an unmediated path is a sequence of edges, none state-bearing, whose first consumes a `TopicInput` of the topic, each next one a `StageInput` of the one before, and whose last is a write of the topic. One `SelfReference` per topic with such a path, `edges` listing every edge on any of them. A path through a state-bearing edge, a reduceInto included, is mediated (Spec §3.8).
- **Writer conflicts.** For each state topic in canonical order, its writers are the topologies whose `writes` hold it and the claims whose `writes` hold it, one entry per claim. One `WriterConflict` per state topic with two or more writers. Event and replay topics have none (Spec §3.11).
- **Scope violations.** For each state topic in canonical order, each owner (its writers, with the topology's or the claim's scope) and each topology that reads it, in graph order: a violation when `ownerScope.isAtLeastAsLongAs(readerScope)` does not hold (Spec §7.2). Ordered by topic, then owner, then reader.
- **Topic name collisions.** Over the distinct declarations given, one `TopicNameCollision` per name with two or more of them, whatever their variants and types, ordered by name (Spec §4.3: the CI step fails on any collision; the runtime's own check compares types).

How the two hosts use them (root D4): activation (bus-api@v2) builds a graph of the active definitions, the candidate and the live claims, and rejects the activation, or the publisher construction, when `analyzeTopologyGraph` reports a finding; because a graph without findings stays without them when topologies or claims are removed (G17), the active set it keeps stays clean. The workspace scan (nidana-checks@v1) builds the catalog's graph and reports every finding, and calls `findTopicNameCollisions` over the topic declarations it finds.
**Guarantees**
- **G1** The IR's families are closed: `EdgeInput` is sealed with exactly `TopicInput` and `StageInput`, `TopologyFinding` is sealed with exactly `TopologyCycle`, `SelfReference`, `WriterConflict` and `ScopeViolation`, every class here other than those two and `GraphRenderer` is final, no type outside the library extends or implements any of them, and a switch that omits an input form, a finding variant or a `CombinatorKind` value does not compile.
- **G2** `CombinatorKind` has exactly the eighteen values topology-dsl@v2 names, in the order listed.
- **G3** IR values, graphs, claims, declarations and findings are immutable: no field can be assigned, and every list and set they expose is an unmodifiable copy that later changes to the argument do not reach.
- **G4** The IR holds no function (Spec §6.5, Appendix A.4): `FunctionRef` is not a `Function`, cannot be called and exposes no function, nor does any edge; every definition a plan projects to encodes to JSON and decodes back equal.
- **G5** `TransformEdge.stage` accepts exactly the inputs, transformer, duration and retry the stage-edge table allows for its combinator, rejects reduceInto and negative durations with `ArgumentError`, and accepts a zero duration; `TransformEdge.write` makes an edge with no combinator; `TransformEdge.reduceInto` accepts only a state topic.
- **G6** `TopologyDefinition` derives `reads` from the edges' topic inputs and `writes` from the sink edges' outputs, each in canonical order, and rejects with `ArgumentError` an empty id, a stage input that is negative, not earlier, or a sink, a stage edge after a sink edge, an unconsumed stage edge, and a second sink on one state topic; event and replay topics take any number of sinks.
- **G7** Definitions, edges, inputs, function references, claims, graphs, declarations, collisions and findings are equal, with equal hash codes, exactly when the fields the Interface names are equal, lists element by element; a graph's equality ignores the order its arguments came in.
- **G8** A plan projects to a definition by the five rules of From a plan: stage edges in stage order then sink edges in sink order, read handles as topic inputs with their dedup argument, every other handle as the index of its stage's edge, inputs in input order with withLatestFrom's primary first, and each stage's function, duration and retry; recording one declaration twice projects equal definitions, inline closures included.
- **G9** `FunctionRef.of(f)` is named by the text between `from Function '` and the next `'` of `f.toString()`, which on the VM is the name of a top-level function, a static method without its class, or a method tear-off, with `@` and its library's key after a private name; on the VM it is anonymous for a closure and a local function; it never calls `f`; `FunctionRef.named('')` throws `ArgumentError` (decides OQ-M1).
- **G10** `isStateBearing` holds exactly for `scan`, `reduceInto`, and `debounce`, `delay`, `sample` and `buffer` with a positive duration.
- **G11** A graph lists its topologies by `topologyId`, counting equal definitions once and rejecting two unequal ones with one id with `ArgumentError`, its claims in canonical order with equal claims kept, and `topics` as every topic its topologies read or write and its claims claim, in canonical order; `d.toGraph()` equals `TopologyGraph(topologies: [d])`.
- **G12** A shell claim takes a service, page or executor source, `Scope.application` unless given, and one or more state topics; a topology or unknown source, an empty set or a non-state topic throws `ArgumentError`.
- **G13** `findTopologyCycles` reports one finding per strongly connected set of two or more topologies of the read and write graph, with its sorted ids and the topics between its members, and none for a self-read or for claims (Spec §3.8).
- **G14** `findSelfReferences` reports one finding per self-read topic with an unmediated path, listing every edge on such paths, and none for a path through a state-bearing edge (Spec §3.8).
- **G15** `findWriterConflicts` reports one finding per state topic with two or more writers, topologies as `TopologySource(topologyId)` and each claim as its source, and none for event or replay topics (Spec §3.11).
- **G16** `findScopeViolations` reports one finding per state topic, owner and reading topology where the owner's scope is not at least as long as the reader's, topology owners and claims alike (Spec §7.2).
- **G17** `analyzeTopologyGraph` returns the cycles, then each topology's self-references in graph order, then the writer conflicts, then the scope violations; a graph with no finding has none after any of its topologies or claims are removed.
- **G18** `findTopicNameCollisions` reports one finding per name with two or more distinct declarations, whatever their types, declarations ordered by site, and counts a repeated declaration once (Spec §4.3).
- **G19** `encodeTopologyGraph` of every sample graph of the conformance library matches the schema and equals its `valid/` file; a graph document lists `encodeTopologyDefinition` of each topology, in graph order.
- **G20** Every `valid/` file decodes and re-encodes to an equal JSON value; decoding a graph's encoding gives the graph back; the decoder accepts topologies, claims, `reads`, `writes` and claimed topics in any order.
- **G21** The decoder throws `FormatException`, and no other error, for every `invalid/` file, for a schema-valid document that breaks a decoder rule, and for any other value.
- **G22** The Mermaid and Graphviz renderings of every sample graph equal its `render/` files, which follow the rendering rules; the JSON rendering equals its `valid/` file byte for byte; `graph.render(r)` is `r.render(graph)`, and rendering, encoding, decoding and the analyses create no timer and schedule no microtask.
- **G23** The constructors of `TopologyCycle`, `SelfReference`, `WriterConflict` and `TopicNameCollision` put the lists they are given in the orders the Interface names: `topologyIds` sorted, `topics` in canonical order, `edges` ascending, `writers` in canonical order with equal sources kept, `declarations` by site, then topic in canonical order; a finding or collision built in another order equals, with an equal hash code, the one built in those orders.

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

## Open questions
- OQ-M1 · RESOLVED (2026-10-18): topology-ir@v1 G9 · How does the recorder name a transformer (`FunctionRef`) in Dart?
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
- Verification doc: hsdd/verify/nidana.model.10.verification.md from
  hsdd/templates/verification.md at spot-check depth. Every Learning
  carries one disposition before sign-off; "- none" is valid, silence is not.
- Contract replay: the gate validates this phase's real output against the
  schema and reproduces the fixtures of topology-ir@v1.

## Links (spec e9f2289)
- Phase section: hsdd/spec/nidana.model.md, heading "### nidana.model.10: IR values and function references"
- Node spec: hsdd/spec/nidana.model.md
- topic-model@v1: hsdd/contract/topic-model.md
- topology-ir@v1: hsdd/contract/topology-ir.md
- ADR-001: hsdd/adr/001-executable-contract-validation.md
- ADR-002: hsdd/adr/002-package-workspace-layout.md
- Conventions: hsdd/conventions.md
- Verification template: hsdd/templates/verification.md
