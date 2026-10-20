---
id: topic-model
version: v1
status: stable
kind: shared-model
owner: nidana.model
compatibility: versioned
produced_by: [nidana.model.3, nidana.model.8]
consumers: [nidana.runtime.1, nidana.runtime.2, nidana.runtime.3, nidana.runtime.4, nidana.runtime.6, nidana.runtime.7, nidana.runtime.8, nidana.runtime.9, nidana.runtime.10, nidana.runtime.11, nidana.runtime.12, nidana.runtime.13, nidana.runtime.14, nidana.navigation.1, nidana.navigation.3, nidana.navigation.6, nidana.flutter.1, nidana.flutter.4, nidana.flutter.5, nidana.flutter.6, nidana.flutter.7, nidana.tooling.lint.1, nidana.tooling.lint.2, nidana.tooling.lint.3, nidana.tooling.lint.4, nidana.tooling.codegen.3, nidana.tooling.codegen.5, nidana.tooling.codegen.6, nidana.tooling.codegen.7, nidana.tooling.codegen.8, nidana.tooling.codegen.9, nidana.tooling.codegen.10, nidana.tooling.codegen.11, nidana.integration.1, nidana.integration.2, nidana.integration.3, nidana.integration.4, nidana.integration.5, nidana.integration.6, nidana.integration.7, nidana.integration.8]
external_consumers: [app topic registries, app observers and sinks, app tests asserting on envelopes]
phase_ids: final
---

# Contract: topic-model

- **Governed by:** [ADR-001, ADR-002]

The value types every node of the tree, and every adopting app, constructs and matches on: typed topics and their references, the message envelope with its source and lineage rules, lifecycle scopes, the observer seam, and sensitive-payload redaction. Everything here is a value or a total function. Nothing here reads a clock, schedules work, generates an id or performs I/O; a function that needs a timestamp or a fresh id takes it as an argument (ADR-003 item 8, which governs the producing node).

## Boundary

nidana.model produces three contracts from one package. This contract holds the shared values; the other two hold the topology API and its data form.

| Declaration group | Contract |
|-------------------|----------|
| `Topic`, `StateTopic`, `MultiWriterTopic`, `EventTopic`, `ReplayTopic`, `TopicVariant`, `Dedup`, `Tracing`, the sensitive flag, initial values, `TopicRef`, `isWellFormedTopicName` | topic-model@v1 |
| `MessageEnvelope`, `MessageSource` and its five variants, `Lineage` with its combination rules, `RedactedPayload` | topic-model@v1 |
| `Scope` and its lifetime order | topic-model@v1 |
| `BusObserver`, `ObserveContext`, `SpanHandle`, `LogLevel`, `ObserverCapability` and its admission rule | topic-model@v1 |
| `Topology`, the `topology(id, scope, body)` form, `TopologyBuilder`, the opaque stream handle and every combinator (`reduceInto`, error and time-dependent combinators, the raw-engine escape hatch), the per-read dedup opt-out, any typed topology id, the recording builder and `buildDefinition()`; which lineage function each combinator applies | topology-dsl@v2 |
| `TopologyDefinition`, `TransformEdge`, `CombinatorKind`, `FunctionRef`, the IR's JSON form (including the JSON encoding of `TopicRef`, `Scope` and `MessageSource`), `TopologyGraph`, `toGraph()`, the renderers; the analyses over sets of definitions: inter-topology cycles, intra-topology self-reference, scope compatibility over an ownership table, topic name uniqueness over a set of declarations | topology-ir@v1 |

Not in any of the three: navigation types (root D7, navigation-api@v1); `Bus`, `BusConfig`, publishers, writer handles, `getCurrentValue`, `getBufferedValues` and the providers (bus-api@v2, bus-testing@v2); the cross-feature `AppError` of Guide §4.1, which stays an application type.

Placement rule the next two contracts follow: a value that crosses more than one of the three contracts, or that application code constructs without declaring a topology, lives here; an analysis over a collection of definitions lives in topology-ir@v1, even when it only compares values defined here (scope compatibility uses `Scope.isAtLeastAsLongAs`).

## Interface

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

## Guarantees / invariants

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

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates.
- Breaking for this contract: removing, renaming or retyping any declaration; adding a variant to `Topic`, `MessageSource` or any enum here, because consumers switch over them exhaustively (G1, G16); adding a member to `BusObserver`, `ObserveContext` or `SpanHandle`, which applications implement; changing a lineage rule, a default, equality, the source rendering or the redaction format.
- Compatible: a new optional named constructor parameter with a default that preserves current behavior, a new getter or method on a final class, a new top-level function, a new guarantee that existing fixtures still pass, a new sealed type between `Topic` and existing variants that adds no variant (an abstract one is breaking, because it leaves a switch that names the variants non-exhaustive).
- Amended within v1, at bus-api@v1's request (its Refinement 3): `MultiWriterTopic<T>` added as the sealed supertype of `EventTopic<T>` and `ReplayTopic<T>`, G1 extended to it and G27 added; the "How the lineage functions are applied" paragraph now states the lineage of a state topic's initial value, `Lineage.root()`, as topology-dsl@v1's read row already applies it. Compatible because it adds no variant: every switch over a `Topic` that names the three variants stays exhaustive, no member, default or rule changes, and every fixture written before the amendment passes against an implementation that carries it (`docs/auto-run/experiments/topic-model-multi-writer/`). One inference result changes, which no declaration here states: the least upper bound of an event topic and a replay topic is now `MultiWriterTopic<T>` where it was `Topic<T>`, so a variable or collection whose type was inferred from those two alone no longer accepts a state topic until its type is written out (`probe/lub.dart` there).
- Not in v1, each a candidate for a later version: a dispatcher hint (G5); a persistence option (root D1); span events or status on `SpanHandle`; a dedup policy with a custom equality.

## Validation

- fixture: `hsdd/contract/fixture/topic-model/`, under `hsdd/contract/fixture/analysis_options.yaml` (ADR-001 item 2); replayed with `fvm dart run nidana_contract_check topic-model`.
- surface: `hsdd/contract/fixture/topic-model/surface/` (`topics.dart`, `envelopes.dart`, `observers.dart`). `topics.dart` matches the topic family both ways, by its three variants and by `StateTopic` and `MultiWriterTopic`, and passes event and replay topics where a `MultiWriterTopic` is expected. `observers.dart` implements `BusObserver`, `ObserveContext` and `SpanHandle` in full, so a member added to any of them fails the surface set; with the reject set this checks the "declares only" half of G22.
- reject: `hsdd/contract/fixture/topic-model/reject/`, one library per type-level guarantee: `topic_family_is_closed.dart` (G1), `only_state_topics_carry_values.dart` (G2), `state_topic_requires_initial.dart` (G3), `values_are_immutable.dart` (G4), `no_dispatcher_hint.dart` (G5), `replay_buffer_is_positive.dart` (G10), `envelope_requires_metadata.dart` (G12), `source_family_is_closed.dart` (G16), `observer_has_no_publish_path.dart` (G22), `state_topic_is_not_multi_writer.dart` (G27). `topic_family_is_closed.dart` rejects an outside implementation of `MultiWriterTopic` and a switch over one that omits a variant as well.
- behavior: conformance library `hsdd/contract/fixture/topic-model/behavior/topic_model_conformance.dart`, harness `TopicModelHarness`, cases `topicModelConformance`, covering G4, G6 to G11, G13 to G15, G17 to G21, G23, G24 and G27.
- binding: `hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart` binds the suite to the producer's own declarations in `nidana_dart_contracts`, under `dart test`.
- not executable: G25, a property of the package's source rather than of its declarations; checked by nidana.model's gates
- not executable: G26, a property of the package's pubspec; checked by nidana.model's gates
- No schema: a `shared-model` contract with no serialized form carries none (ADR-001 item 4). The JSON encodings of `TopicRef`, `Scope` and `MessageSource` belong to topology-ir@v1's schema.
- The fixtures are forward references, written before the package exists. Their reject codes were confirmed against a stand-in that implements this Interface, and the behavior suite passed against it, in `docs/auto-run/experiments/topic-model-fixtures/` (`output.txt`). For the `MultiWriterTopic` amendment, `docs/auto-run/experiments/topic-model-multi-writer/` (`run.sh`, `output.txt`) replays the fixtures as they stood before it and as amended against a stand-in that carries `MultiWriterTopic`, all passing; confirms the new reject codes; shows that the amended surface and reject sets fail against a stand-in without it, and that seeded defects (`MultiWriterTopic` abstract instead of sealed, `StateTopic` a multi-writer topic) fail the fixtures of G1 and G27; and replays the surface and reject sets of topology-dsl@v1, topology-ir@v1 and bus-api@v1 against both stand-ins, where the first two pass either way and bus-api@v1's pass only with the amendment. The first replay against the real package, once nidana.model's first phase lands the replay tool, is their first verification (ADR-001 Consequences).
