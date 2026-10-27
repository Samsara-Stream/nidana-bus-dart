---
id: topology-ir
version: v1
status: stable
kind: api
owner: nidana.model
compatibility: versioned
produced_by: [nidana.model.5, nidana.model.10, nidana.model.11, nidana.model.12, nidana.model.13, nidana.model.14]
consumers: [nidana.runtime.1, nidana.runtime.8, nidana.runtime.11, nidana.navigation.3, nidana.navigation.6, nidana.flutter.5, nidana.flutter.6, nidana.flutter.7, nidana.tooling.codegen.1, nidana.tooling.codegen.5, nidana.tooling.codegen.6, nidana.tooling.codegen.7, nidana.tooling.codegen.8, nidana.tooling.codegen.9, nidana.tooling.codegen.10, nidana.tooling.codegen.11, nidana.integration.2, nidana.integration.3, nidana.integration.4, nidana.integration.5, nidana.integration.6, nidana.integration.7, nidana.integration.8]
external_consumers: [CI tools reading topology-graph.json, app topology tests asserting on definitions and graphs]
phase_ids: final
---

# Contract: topology-ir

- **Governed by:** [ADR-001, ADR-002]

The data form of a topology (Spec §6.5, Appendix A.4) and everything computed from it: the IR value types `TopologyDefinition` and `TransformEdge`, how a recorded plan projects to them, how a transformer is named, graphs of topologies and shell claims with their Mermaid, Graphviz and JSON renderings, the JSON form and its schema, and the pure analyses that the runtime runs at activation and the tooling runs in CI (Spec §3.8, §3.11, §4.3, §7.2). Everything here is a value or a total function: nothing reads a clock, schedules work or performs I/O (topic-model@v1 G25), and the IR holds no function (G4).

## Boundary

topic-model@v1 and topology-dsl@v2 assigned this contract the IR, its JSON form (with the JSON encodings of `TopicRef`, `Scope` and `MessageSource`), graphs and renderers, and every analysis over sets of definitions. This contract keeps those assignments and refines them in five places:

| Declaration group | Contract |
|-------------------|----------|
| `TopologyDefinition`, `TransformEdge`, `EdgeInput`, `TopicInput`, `StageInput`, `CombinatorKind`, `FunctionRef`; the projection of a plan (refinement 1); the naming of a transformer (OQ-M1) | topology-ir@v1, main library |
| `TopologyGraph`, `ShellClaim`, `toGraph()`, `GraphRenderer` and the three renderers, the JSON codec, the analyses and their findings, `TopicDeclaration`, `TopicNameCollision` | topology-ir@v1, library `topology_ir.dart` (refinement 2) |
| `Topology.buildDefinition()`, `TopologyPlan.definition`, the stage classes and which `CombinatorKind` each projects to | topology-dsl@v2 |
| `Bus.activate`, the activation checks' wiring and their diagnostics, `bus.toGraph()`, the ownership table, idempotency on `topologyId` (Spec §3.9) | bus-api@v2 |
| `Catalog.scanTopologies`, the path and generator of `topology-graph.json`, the workspace scan that finds publisher claims and topic declarations, the build-time HTML graph | nidana.tooling: topic-codegen@v1, nidana-checks@v1 |
| `TopicRef`, `Scope`, `MessageSource`, `Dedup` | topic-model@v1 |

- **Refinement 1.** Spec §6.5 sketches `TransformEdge` with topic references at both ends, which cannot describe a pipeline of more than one stage, nor which stage a write takes. Here an edge's inputs are topics or earlier edges, a write and a reduceInto are edges whose output is a topic, and each edge carries what the analyses and an equality check need: its function references, its duration and the dedup argument of each read. The definition keeps the Spec's five fields; `reads` and `writes` are derived from the edges.
- **Refinement 2.** The value types sit in the main library because `buildDefinition()`, which topology modules call, returns them. Graphs, renderers, the JSON codec and the analyses sit in a second public library (ADR-002 item 3) that the runtime, the tooling and tests import, so a topology module's namespace carries no renderer or analysis names.
- **Refinement 3.** One graph type serves both views of Spec §6.5: `bus.toGraph()` builds it from the active topologies and the live publishers' claims, the catalog from every topology and claim the workspace declares. A shell publisher's claim enters as a `ShellClaim` value (its source, its scope, its state topics), so the analyses see topology owners and shell owners alike (Spec §3.11, §7.2) and this contract names no bus type.
- **Refinement 4.** The analyses are the only implementation of the checks of Spec §3.8, §3.11 and §7.2 "Scope compatibility". Spec §7.2 "Scope timing" is not an analysis: bus-api@v2 rejects a `MODULE` or `PAGE` activation before `start()` itself (its G42), and the rejection is no finding of this contract. Activation (bus-api@v2) and the workspace scan (nidana-checks@v1, ADR-002 item 8) call the same functions over graphs they build differently (root D4).
- **Refinement 5.** The serialized form is one document type, the graph document, with one schema. `topology-graph.json` (Guide C.3) is the JSON rendering of the catalog's graph; a single definition's JSON form is the object a graph document lists for it.

Not here: duplicate topology ids across modules (the graph rejects them, G11; reporting them is the catalog's), orphan and unreachable topics and the sequencer check (v2, root D1), topology diff (root D1), binary-module manifests (root D1), and the topic catalog `topics.md` (topic-codegen@v1).

## Interface

**Libraries:** `package:nidana_dart_contracts/nidana_dart_contracts.dart`, the main library of `nidana_dart_contracts` at `packages/nidana_dart_contracts/`, carries every declaration under The IR and Function references; `package:nidana_dart_contracts/topology_ir.dart`, a second public library named by this contract (ADR-002 item 3), carries every declaration under Graphs, Renderers, The JSON form and Analyses. `topology_ir.dart` does not re-export the main library. Both import nothing beyond the SDK (`dart:convert` included), `package:meta` and the package's own libraries (topic-model@v1 G26). **Code owner:** nidana.model, by whose first producing phase every declaration below has landed (ordering policy `fp-progression`, root D10; Delivery, below). **Validation artifacts:** `hsdd/contract/schema/topology-ir.schema.json` and `hsdd/contract/fixture/topology-ir/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names. nidana.model.4 lands the declarations under The IR and Function references with topology-dsl@v2's, because `TopologyDefinition`, which `buildDefinition()` returns, names them; nidana.model.5 lands those under Graphs, Renderers, The JSON form and Analyses, and a consumer's edge on this contract waits on it. A `hard` edge waits instead on nidana.model.14, the last producing phase (nidana.integration). Until the phase that delivers it merges, a body that computes throws `UnimplementedError` and a value compares by identity: nidana.model.10 delivers the IR values, `TransformEdge`'s rules, `FunctionRef`, `isStateBearing` and the findings' value semantics (G2, G5, G6, G9, G10, G23); nidana.model.11 the projection, `ShellClaim` and `TopologyGraph` (G8, G11, G12, and G3 and G7 but for the findings the analyses return); nidana.model.12 the analyses (G3, G7, G13 to G18); nidana.model.13 the JSON codec and `JsonRenderer` (G4, G19 to G21); nidana.model.14 the Mermaid and Graphviz renderers (G22).

The declarations are the schema of the Dart surface (ADR-001 item 4); the JSON Schema is the schema of the serialized form (ADR-001 item 5). Bodies are omitted; the comments, the rules and the guarantees state the semantics. Every class here other than the sealed bases `EdgeInput` and `TopologyFinding` and the interface `GraphRenderer` is final; every value type is immutable, annotated `@immutable` from `package:meta`, with value equality. The code blocks show the annotation where the declarations carry it: on the sealed bases `EdgeInput` and `TopologyFinding`, where it covers their subclasses, and on `TransformEdge`, `TopologyDefinition`, `FunctionRef`, `ShellClaim`, `TopologyGraph`, `TopicDeclaration` and `TopicNameCollision`.

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
@immutable
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
@immutable
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
@immutable
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

Projection calls none of the plan's functions (topology-dsl@v2 G10): `FunctionRef.of` reads a function's `toString()`, nothing else. Because `planOf` already rejects a stage that reaches no sink and a second sink on one state topic, a plan projects to a well-formed definition, with one exception. Two state topics of one name whose value types render alike, one class name from two libraries, are two topics to `planOf`, which compares topics as topic-model@v1 G7 does (topology-dsl@v2 G14), and one `TopicRef` to the IR, which compares the rendered `typeName`. For a plan with a sink on each, the edges hold a second sink edge on one state topic, so `TopologyPlan.definition` and `buildDefinition()` throw `TopologyDefinition`'s `ArgumentError`, naming `transforms`. Two such topics are also a Spec §4.3 name collision, which `findTopicNameCollisions` reports and the workspace scan reports as an error (nidana-checks@v1 G13).

### Function references

```dart
/// A serializable reference to a transformer (Spec §6.5, Appendix A.4): a
/// name, or anonymous. It holds no function and is not a Function.
@immutable
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

What the derivation yields on the pinned SDK, from `docs/auto-run/experiments/function-ref-derivation/`, for private names `docs/auto-run/experiments/function-ref-private-key/`, and for the extension forms `docs/auto-run/experiments/sweep-topology-ir-text/`:

| Function form | JIT and AOT | AOT with `--obfuscate` | dart2js, dart2wasm |
|---------------|-------------|------------------------|--------------------|
| top-level function, `buildTotal` | `buildTotal` | an obfuscated name, stable within the build | anonymous |
| static method `Reducers.reduceCount` | `reduceCount` (no class) | obfuscated | anonymous |
| instance method tear-off `formatter.format` | `format` | obfuscated | anonymous |
| generic function, instantiated or not | its name | obfuscated | anonymous |
| constructor tear-off `Box.new` | `Box.` | obfuscated | anonymous |
| implicit `call` tear-off of a callable object | `call` | `call` | anonymous |
| static method of a named extension or of an extension type, `Ext.helper`, `ET.make` | `Ext\|helper`, `ET\|make`: the extension's name, `\|` and the method's | obfuscated | anonymous |
| constructor tear-off of an extension type, a factory included, `ET.new`, `ET.named` | `ET\|constructor#_#new#tearOff`, `ET\|constructor#_#named#tearOff` | obfuscated | anonymous |
| inline closure, closure in a variable, local function, instance method tear-off of an extension or an extension type | anonymous | anonymous | anonymous |
| a form above other than the extension forms, with a private name: `_reduce`, `Reducers._reduce`, `formatter._format`, `Box._internal`, `_Box.new` | `@{key}` after each private identifier: `_reduce@{key}`, `_reduce@{key}`, `_format@{key}`, `Box._internal@{key}`, `_Box@{key}.`; the key differs between JIT and AOT, and between programs and runners (Private names, below) | obfuscated, `@{key}` kept | anonymous |

A name is a label for graphs and for equality, not an identity: two static methods of one name in different classes render alike. The catalog and the CI checks run on the VM, where public names are as written (Spec §6.2 names transformers as standalone functions). A web build gets anonymous references only, never a compiler's internal name: dart2js renders inline closures as `main_closure`, which the derivation does not read.

**Private names.** The VM renders a private identifier followed by `@` and its library's key, and the derivation keeps the key, because it takes the text as rendered (G9). Within one process every private name of a library carries the same key. The key belongs to the process, not to the source: it changes with the library's URL and with how many libraries the program loads before that library, so one library's key differs between a JIT and an AOT build of one program (`@22518013` against `@18518013`), between `dart run` and the Flutter tester (`@21518013`), and between two programs that load other libraries, or the same libraries in another order, ahead of it; the same program under the same runner gets the same key on every run (`docs/auto-run/experiments/function-ref-private-key/`). A definition, graph or graph document holding a private transformer therefore renders differently, and compares unequal (G7), when another program or runner records it: the build-time catalog's JIT recording equals an AOT app's `bus.toGraph()` only when every transformer is public (topic-codegen@v1's `definitions` bullet; nidana.integration D8 keeps its example's transformers public for this reason). Within one process, recording one declaration twice still projects equal definitions (G8). The key is `@` followed by digits; outside an obfuscated build, removing each key gives the name as written (`_Holder@22518013._secret@22518013` reads `_Holder._secret`). An extension form renders its whole name as one identifier, so the key, when there is one, comes once at its end: `_Ext|helper@{key}` for a static method of a private extension and `_ET|constructor#_#new#tearOff@{key}` for a private extension type's constructor, while a private static method of a public extension renders `Ext|_helper`, with no key. This describes what G9's rule yields and adds no guarantee; the behavior case for it asserts the `@` and a key, never the key's value.

### Graphs

Library `package:nidana_dart_contracts/topology_ir.dart`.

```dart
/// A shell publisher's claim (Spec §2.4, §3.11, §7.2): its source, the scope
/// it is bound to (application when unbound), and the state topics it
/// claims. Throws ArgumentError when [source] is a TopologySource or
/// UnknownSource, or [writes] is empty or names a topic that is not a state
/// topic.
@immutable
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
@immutable
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
- edge: the combinator's name, or `write` for a write, followed by one space and the duration when the edge has one; the transformer's name when it has one; `retry`, one space and the retry's name when it has one. An anonymous reference renders as `(anonymous)`, so an anonymous retry renders `retry (anonymous)`. A duration renders as whole seconds `{n}s` when it is a multiple of a second, else whole milliseconds `{n}ms` when it is a multiple of a millisecond, else `{n}us`;
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

Arrows come per topology in graph order, per edge in order: one from each input, in input order, to the edge (from `t{i}` for a `TopicInput`, labeled with its dedup when it has one; from `p{j}e{n}` for a `StageInput(n)`), then, for a sink edge, one from the edge to its output topic; then per claim, one to each claimed topic in canonical order. Every line ends with a newline. Escaping: Mermaid replaces `#` with `#35;`, then `"` with `#quot;`, `<` with `#lt;`, `>` with `#gt;` and a newline with `#10;`, and breaks lines with `<br/>`; Graphviz replaces `\` with `\\`, `"` with `\"` and a newline with `\n`, and breaks lines with `\n`. The goldens under `render/` were parsed by Mermaid 11.12.0 and laid out by Graphviz 14.0.1 (`docs/auto-run/experiments/topology-ir-fixtures/`). Graphviz lays out no empty cluster, so a topology with no edges, such as the `escaping` sample's `idle`, is in the `.dot` text as the rules give it but is not drawn (the same experiment's `output.txt`, `clusters=1` for `escaping.dot`).

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
- An integer of the form, `durationMicros` or `edge`, is a JSON number with no fractional part, as JSON Schema counts integers: `5000`, `5000.0` and `5e3` are one duration, and the encoder writes `5000`. The decoder reads one into a Dart `int`, so it rejects an integer of 2^63 or more, which the schema accepts and which no `Duration` and no index can hold. The schema states no upper bound because none would draw that line: a validator that compares numbers as doubles, as a JavaScript validator does and as `package:json_schema` 5.2.2 does, takes 2^63 - 1 and 2^63 for one number, so a `maximum` of 2^63 - 1 accepts 2^63 and an `exclusiveMaximum` of 2^63 rejects 2^63 - 1, which the decoder accepts (`docs/auto-run/experiments/sweep-topology-ir-text/`).
- An edge carries `combinator` (absent for a write), `inputs`, then `output`, `transformer`, `durationMicros` and `retry` only where the edge has them. An input is `{"topic": TopicRef}`, with `"dedup"` only when the read gave one, or `{"edge": n}`.
- The encoder lists topologies, claims, `reads`, `writes` and each claim's `writes` in canonical order. The decoder accepts those lists in any order and re-encodes them in canonical order.
- The decoder also enforces what the schema cannot state: the definition rules above, `reads` and `writes` equal to the topics the edges read and the sink edges write, each once, distinct topology ids, and integers below 2^63.
- A graph can hold a value the schema and the decoder reject: `TopicInput` accepts a `dedup` on an event or replay topic, topic-model@v1's `TopicRef` an empty `typeName`, and, in code run without assertions, topic-model@v1's sources an empty name, whose rendering a claim's `source` pattern rejects. Such a graph, built by hand, encodes, and the decoder rejects its encoding, so G20 gives a graph back only where the decoder accepts its encoding. A definition a plan projects to holds neither of the first two, because `read` rejects a `dedup` on an event or replay topic (topology-dsl@v2 G13) and every topic reference it holds is a `Topic`'s `ref`, whose `typeName` is the value type's rendering (topic-model@v1).
- `JsonRenderer` renders `JsonEncoder.withIndent('  ')` of the encoding, followed by a newline. `topology-graph.json` (Guide C.3) is that rendering of the catalog's graph: nidana.tooling emits it through topic-codegen@v1, which names its path and generator, and nidana-checks@v1's workspace scan reads the same graph.
- The schema is closed (`additionalProperties: false` throughout) and `format` names the contract version, so a v1 decoder rejects a document of another version instead of misreading it.

### Analyses

```dart
/// A finding of the analyses (Spec §3.8, §3.11, §7.2). Sealed.
@immutable
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
@immutable
final class TopicDeclaration {
  const TopicDeclaration({required TopicRef topic, required String site});
  TopicRef get topic;
  String get site;
}

/// Spec §4.3: [name] declared more than once.
@immutable
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
- **Scope violations.** For each state topic, each owner (its writers, with the topology's or the claim's scope) and each topology that reads it: a violation when `ownerScope.isAtLeastAsLongAs(readerScope)` does not hold (Spec §7.2). Ordered by topic in canonical order, then owner by its source's rendering and then its scope (application, module, page), then reader in graph order. Owners are therefore not in graph order: every claim comes before every topology owner, because a claim's source renders `executor:`, `page:` or `service:` and a topology's renders `topology:`. Two equal owners, as two equal claims are, give one violation per reader.
- **Topic name collisions.** Over the distinct declarations given, one `TopicNameCollision` per name with two or more of them, whatever their variants and types, ordered by name (Spec §4.3: the CI step fails on any collision; the runtime's own check compares types).

How the two hosts use them (root D4): activation (bus-api@v2) builds a graph of the active definitions, the candidate and the live claims, and rejects the activation, or the publisher construction, when `analyzeTopologyGraph` reports a finding; because a graph without findings stays without them when topologies or claims are removed (G17), the active set it keeps stays clean. The workspace scan (nidana-checks@v1) builds the catalog's graph and reports every finding, and calls `findTopicNameCollisions` over the topic declarations it finds.

## Guarantees / invariants

- **G1** The IR's families are closed: `EdgeInput` is sealed with exactly `TopicInput` and `StageInput`, `TopologyFinding` is sealed with exactly `TopologyCycle`, `SelfReference`, `WriterConflict` and `ScopeViolation`, every class here other than those two and `GraphRenderer` is final, no type outside the library extends or implements any of them, and a switch that omits an input form, a finding variant or a `CombinatorKind` value does not compile.
- **G2** `CombinatorKind` has exactly the eighteen values topology-dsl@v2 names, in the order listed.
- **G3** IR values, graphs, claims, declarations and findings are immutable: no field can be assigned, and every list and set they expose is an unmodifiable copy that later changes to the argument do not reach.
- **G4** The IR holds no function (Spec §6.5, Appendix A.4): `FunctionRef` is not a `Function`, cannot be called and exposes no function, nor does any edge; every definition a plan projects to encodes to JSON and decodes back equal.
- **G5** `TransformEdge.stage` accepts exactly the inputs, transformer, duration and retry the stage-edge table allows for its combinator, rejects reduceInto and negative durations with `ArgumentError`, and accepts a zero duration; `TransformEdge.write` makes an edge with no combinator; `TransformEdge.reduceInto` accepts only a state topic.
- **G6** `TopologyDefinition` derives `reads` from the edges' topic inputs and `writes` from the sink edges' outputs, each in canonical order, and rejects with `ArgumentError` an empty id, a stage input that is negative, not earlier, or a sink, a stage edge after a sink edge, an unconsumed stage edge, and a second sink on one state topic; event and replay topics take any number of sinks.
- **G7** Definitions, edges, inputs, function references, claims, graphs, declarations, collisions and findings are equal, with equal hash codes, exactly when the fields the Interface names are equal, lists element by element; a graph's equality ignores the order its arguments came in.
- **G8** A plan projects to a definition by the five rules of From a plan: stage edges in stage order then sink edges in sink order, read handles as topic inputs with their dedup argument, every other handle as the index of its stage's edge, inputs in input order with withLatestFrom's primary first, and each stage's function, duration and retry; recording one declaration twice projects equal definitions, inline closures included.
- **G9** `FunctionRef.of(f)` is named by the text between `from Function '` and the next `'` of `f.toString()`, which on the VM is the name of a top-level function, a static method without its class, or a method tear-off, with `@` and its library's key after a private name, an extension form's whole name counting as one name (Private names); on the VM it is anonymous for a closure and a local function; it never calls `f`; `FunctionRef.named('')` throws `ArgumentError` (decides OQ-M1).
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
- **G20** Every `valid/` file decodes and re-encodes to an equal JSON value; decoding a graph's encoding gives the graph back whenever the decoder accepts that encoding, which it does not for a graph built by hand with a value the schema rejects (The JSON form); the decoder accepts topologies, claims, `reads`, `writes` and claimed topics in any order.
- **G21** The decoder throws `FormatException`, and no other error, for every `invalid/` file, for a schema-valid document that breaks a decoder rule, and for any other value.
- **G22** The Mermaid and Graphviz renderings of every sample graph equal its `render/` files, which follow the rendering rules; the JSON rendering equals its `valid/` file byte for byte; `graph.render(r)` is `r.render(graph)`, and rendering, encoding, decoding and the analyses create no timer and schedule no microtask.
- **G23** The constructors of `TopologyCycle`, `SelfReference`, `WriterConflict` and `TopicNameCollision` put the lists they are given in the orders the Interface names: `topologyIds` sorted, `topics` in canonical order, `edges` ascending, `writers` in canonical order with equal sources kept, `declarations` by site, then topic in canonical order; a finding or collision built in another order equals, with an equal hash code, the one built in those orders.

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates. A v2 serialized form changes `format` to `topology-ir@v2`.
- Breaking for this contract: removing, renaming or retyping any declaration; adding a `CombinatorKind` value, an `EdgeInput` form or a `TopologyFinding` variant, which consumers switch over exhaustively (G1); changing the projection rules, the naming rule of `FunctionRef.of`, the state-bearing rule, a canonical order, an analysis's semantics or result order, a rendering rule, or any JSON key, encoding or the `format` string; adding a key to the JSON form, because the schema and the decoder are closed.
- Compatible: a new analysis function; a new getter on a final class; a new optional named parameter with a default that keeps current behavior; a new guarantee that existing fixtures still pass.
- Amended within v1, from nidana.model's phase plan (nidana.model.10), drained by hsdd-reconcile on 2026-10-18: G23, the finding and collision constructors sort their lists into the orders the Interface's comments name, with a sentence under Analyses and one behavior case. Compatible: no declaration changes; every finding the suite and the `findings` sample build is already in those orders, so every existing case passes against a stand-in that sorts and one that keeps the order given, and only the new case tells them apart (`docs/auto-run/experiments/model-reconcile-amends/`); no other contract's fixtures construct a finding or a collision. A constructor that keeps the order given is now a defect.
- Amended within v1 by hsdd-contract on 2026-10-18, from a finding of the hsdd-reconcile pass that drained nidana.navigation's plan: the Function references table gains the row for private names, which the VM renders with `@` and the library's key; a Private names paragraph says what the key depends on and that a definition, graph or graph document holding a private transformer compares unequal across programs and runners; the sentence after the table says public names are as written; G9's gloss names the key; and one G9 behavior case covers the row without asserting the key's value. Compatible: G9's rule, the text between `from Function '` and the next `'`, already yields the key, so no declaration, rule, canonical order, rendering rule, JSON key or schema changes. The stand-in that follows the rule passes every case, and a `FunctionRef.of` that strips the key, which passed every case before, fails the new case alone (`docs/auto-run/experiments/function-ref-private-key/`). No other contract's fixtures bind this suite; no consumer phase compares a private transformer's name across programs (nidana.integration D8 and nidana.tooling.codegen's note on function references keep their transformers public), and for the external consumers the paragraph states behavior they already meet.
- Touched within v1, 2026-10-21, for Specification v0.15.1 (`hsdd/management/2026-10-20-intake-ref-arch-v0-15-1.md`, section "Citations of a superseded version", handoff H7c). Every live citation of topology-dsl and bus-api names v2, the version those contracts took in that intake; the Validation paragraph on `docs/auto-run/experiments/topology-ir-fixtures/` keeps the version of topology-dsl that experiment replayed. Refinement 4 now limits the analyses to Spec §7.2 "Scope compatibility" and names bus-api@v2's G42 as where Spec §7.2 "Scope timing" is enforced, a rejection that is no finding of this contract. Compatible: no declaration, guarantee, case, fixture behavior, JSON key or schema changed; the one fixture edit is a comment line of `surface/definitions.dart`.
- Amended within v1, 2026-10-27, from nidana.model's re-plan of nidana.model.4 and nidana.model.5 (its D1, Restated 2026-10-26), drained by hsdd-reconcile. The Delivery paragraph had nidana.model.5 land every declaration but `TopologyDefinition`, which landed with topology-dsl@v2 at nidana.model.4; it now has nidana.model.4 land the declarations under The IR and Function references with topology-dsl@v2's, and nidana.model.5 those under Graphs, Renderers, The JSON form and Analyses. `TopologyDefinition`'s factory and `transforms` getter name `TransformEdge`, which names `EdgeInput`, `CombinatorKind` and `FunctionRef`, and a Dart declaration cannot name an undeclared type, so `TopologyDefinition` alone, as the plan first scoped nidana.model.4, does not analyze (`docs/auto-run/experiments/model-main-library-closure/`, Q5). The Interface's code-owner sentence now says every declaration has landed by the first producing phase, where it said that phase lands every declaration. Compatible: the Breaking list names no phase assignment, and no declaration, guarantee, case, fixture, JSON key or schema changes. `produced_by` is unchanged, so nidana.model.5 is still the first producing phase, whose gate first replays the `surface` and `reject` sets in full (ADR-001 item 10), and no consumer's edge moves: every consumer waits on nidana.model.5 or a later phase, and no declaration lands later than before. With the main library's IR at nidana.model.4, a stand-in package analyzes clean, and nidana.model.4's and nidana.model.5's gate replays pass against it (the same experiment, Q1, Q2 and Q6).
- Amended within v1, 2026-10-27, from nidana.model's amend of the Gates of nidana.model.11 and nidana.model.13 (nidana.model.11, Scope, Restated 2026-10-27 a second time), drained by hsdd-reconcile. The Delivery paragraph had nidana.model.11 deliver G3 and G7 whole; it now has nidana.model.11 deliver them but for the findings the analyses return, and nidana.model.12 deliver them with the analyses. G3's case at line 508 of `behavior/topology_ir_conformance.dart` (its call at line 512) and G7's case at line 821 (its call at line 832) call `analyzeTopologyGraph` over the `findings` sample, and a replay selects cases by guarantee id (ADR-001 item 9), so a replay restricted to G3 and G7 failed those two cases at nidana.model.11 whatever it built, and at nidana.model.13, whose closure holds nidana.model.11 but not nidana.model.12 (nidana.model D5). nidana.model.11's Gate now restricts the topology-ir@v1 replay to G2, G5, G6 and G8 to G12 and nidana.model.13's to G2, G4 to G6, G8 to G12 and G19 to G21; nidana.model.12's Gate, which lists G3 and G7 as before, is the first to run their cases, and nidana.model.14, the last producing phase, replays the contract unrestricted. Compatible: the Breaking list names no phase assignment, and no declaration, guarantee, case, fixture, JSON key or schema changes. `produced_by` is unchanged and no consumer's edge moves: nidana.model.11 still delivers the bodies G3 and G7 hold for graphs and claims at that phase (unmodifiable copies, value equality and hash codes; nidana.model.10 delivered them for the IR values), and no consumer can have relied on G3 or G7 for the findings before nidana.model.12, because `analyzeTopologyGraph` throws until then. A static scan of every case each unshipped gate replays, checked against today's replay (every case it says reaches no unimplemented body passes today, 0 misses), finds these two the only cases nidana.model.11's restriction admitted that reach a later phase, and the same two in nidana.model.13's (`docs/auto-run/experiments/model-gate-reach/`, sections A, S4 and V). G4 and G19 to G21 (nidana.model.13) and G22 (nidana.model.14) first replay where the paragraph puts them. G23 stays with nidana.model.10, whose constructors deliver it, though its one case, which runs the analyses over the same sample, first replays at nidana.model.12.
- Touched within v1, 2026-10-27, by the end-of-nidana.model governance sweep (S153), after every phase that produces this contract had shipped. The items are the ones `docs/auto-run/impl-execution-plan.md` routed here under "Routed to later phases", and each change states what the shipped package already does. The Interface's code blocks show `@immutable` where the declarations carry it, which the prose already said, and the prose adds that the annotation on the sealed bases covers their subclasses. From a plan no longer says that every definition a plan projects to is well formed: two state topics of one name whose value types render alike are two topics to `planOf` and one `TopicRef` to the IR, so a plan with a sink on each makes `TopologyPlan.definition` and `buildDefinition()` throw `TopologyDefinition`'s `ArgumentError`, as the package does, and the paragraph names the Spec §4.3 collision the scan reports for them. The derivation table under Function references gains rows for a static method of a named extension or an extension type (`Ext|helper`) and for an extension type's constructor tear-off (`ET|constructor#_#new#tearOff`), both of which G9's rule names; its anonymous row says instance method tear-off of an extension or an extension type, the case its "extension method tear-off" held for; and Private names, with G9's gloss of its rule, says where an extension form takes its key: at the end of its whole name, and only when that name is private. The rendering rules say that an anonymous retry renders `retry (anonymous)`, and that Graphviz does not draw an empty cluster. The JSON form says that an integer is a JSON number with no fractional part, as in JSON Schema, and that the decoder rejects an integer of 2^63 or more, which the schema accepts and no `Duration` or index can hold; it says why the schema states no upper bound; and it names the values a graph built by hand can hold whose encoding the decoder rejects. G20 now gives a graph back from its encoding whenever the decoder accepts that encoding, where it had said so of every graph. The scope violations' order is settled as the package orders it: owners by their source's rendering and then their scope, which puts every claim before every topology owner, not in graph order. Validation has the not-executable line that ADR-001 item 3 asks for G6's rejection of a negative stage input, and `surface/graphs.dart` builds a `ScopeViolation` as a constant. Compatible: no declaration, default, rule, canonical order, analysis result, rendering, JSON key, encoding or schema changed, and each clause that reads differently restates what the package does or what the Interface or a guarantee already said. G20's narrowing drops a promise that no decoder meeting G21 and the schema could keep, because both already required the decoder to reject those encodings (`invalid/dedup_on_event_read.json`, the `typeName` minLength). Every fixture as it stood passes against the shipped package, and so does the surface fixture as touched, which fails against a copy of the package whose `ScopeViolation` constructor is not const (`docs/auto-run/experiments/sweep-topology-ir-text/`, `run.sh` and `output.txt`). Left as they were, for the owner: `invalid/` gains no document for an empty `typeName`, a dedup on a replay read or a claim that lists one topic twice, because `packages/nidana_dart_contracts/test/json_reject_test.dart` pins the exact list of `invalid/` files and fails on any other (the experiment holds the three documents, each failing the schema and rejected by the decoder with a `FormatException`); and a topology with no edges stays undrawn by Graphviz, since drawing it would change a rendering rule and the renderer.
- Not in v1, each a candidate for a later version: stage type arguments in the IR; a `scan`'s initial value; a qualified name for static methods; orphan and unreachable topic analyses, sequencer detection and binary-module manifests (root D1); topology diff (root D1); a finding for duplicate topology ids.

## Validation

- schema: `hsdd/contract/schema/topology-ir.schema.json`, JSON Schema draft 2020-12, the graph document; replayed by the `schema` set: every file under `valid/` validates, none under `invalid/` does (ADR-001 item 5).
- fixture: `hsdd/contract/fixture/topology-ir/`, under `hsdd/contract/fixture/analysis_options.yaml` (ADR-001 item 2); replayed with `fvm dart run nidana_contract_check topology-ir`.
- valid: `hsdd/contract/fixture/topology-ir/valid/`, one graph document per sample graph of the conformance library (`checkout`, `claims_only`, `empty`, `escaping`, `every_combinator`, `findings`, `forms`), each the producer's `JsonRenderer` output for its sample.
- invalid: `hsdd/contract/fixture/topology-ir/invalid/`, 38 documents, each `valid/forms.json` with one schema rule broken, named after the rule.
- render: `hsdd/contract/fixture/topology-ir/render/`, one Mermaid file (`.mmd`) and one Graphviz file (`.dot`) per sample, named after it: the renderings the behavior set compares (G22).
- surface: `hsdd/contract/fixture/topology-ir/surface/definitions.dart` uses every declaration of the main library's IR with the types the Interface states and switches exhaustively over `EdgeInput` and `CombinatorKind`; `surface/graphs.dart` uses every declaration of `topology_ir.dart`, implements `GraphRenderer`, switches exhaustively over `TopologyFinding`, and builds `ScopeViolation` and `TopicDeclaration` as constants, as their const constructors allow.
- reject: `hsdd/contract/fixture/topology-ir/reject/`, one library per type-level guarantee: `ir_families_are_closed.dart` (G1), `ir_values_are_immutable.dart` (G3), `ir_holds_no_function.dart` (G4).
- behavior: conformance library `hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart`, harness `TopologyIrHarness`, cases `topologyIrConformance`, covering G2 to G23, and the sample graphs `topologyIrSamples`. Its harness carries only `settle()`, because the IR has one implementation by design. Its serialized-form cases (ADR-001 item 4) round-trip every `valid/` file through the producer's decoder and encoder, check the producer's real output with `expectMatchesSchema`, and read `valid/`, `invalid/`, `render/` and the schema by paths relative to the workspace root, the nearest ancestor of the current directory that holds `hsdd/contract/`.
- binding: `hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart` binds the suite to the producer's own declarations in `nidana_dart_contracts`, under `dart test`. It must pass every case of `topologyIrConformance`.
- not executable: G6's rejection of a stage input whose index is negative, because a binding runs under `dart test`, which enables assertions, so `StageInput`'s own assertion throws an `AssertionError` before `TopologyDefinition` sees the index; checked by nidana.model's gates, whose package tests build such an input in a program run without assertions and expect the `ArgumentError`
- `expectMatchesSchema`, which nidana.model.2 writes into `package:nidana_contract_check/fixture.dart` (ADR-001 items 4 and 9), has the signature `void expectMatchesSchema(Object? instance, String schemaPath)`: it fails the current test as `expect` does, listing every validation error, unless the JSON value `instance` validates against the draft 2020-12 schema at `schemaPath`, a path relative to the workspace root found as above.
- Consumers' stand-ins: a consumer that stands in for this contract's functions binds the suite in its own `test/` (ADR-001 item 11); the runtime's activation checks and the tooling's checks call the producer's functions, so they need no stand-in: they compile against the declarations from nidana.model.5 and call each function once the phase that delivers it has merged (Delivery).
- The fixtures are forward references, written before the package exists. In `docs/auto-run/experiments/topology-ir-fixtures/` (`run.sh`, `output.txt`) every reject code was confirmed against a stand-in that implements this Interface, the surface set analyzed clean, the behavior suite passed against the stand-in, seeded defects in the stand-in failed the cases of the guarantee they break, the schema set passed under `package:json_schema` 5.2.2 and Ajv 8.17.1, and topology-dsl@v1's surface, reject and recording sets still passed against the stand-in's projection. The reject codes for G3 assume the Interface's getters are final fields (`assignment_to_final`); a getter without a field reports `assignment_to_final_no_setter`, a fixture gap the first replay would surface. The first replay against the real package, once nidana.model's first phase lands the replay tool, is their first verification (ADR-001 Consequences).
- The `const` use of `ScopeViolation` that the touch of 2026-10-27 added to `surface/graphs.dart` (Versioning) was written after the package shipped. It analyzes clean against the package, and the surface set fails it against a copy of the package whose `ScopeViolation` constructor is not const, which every surface fixture as it stood passes (`docs/auto-run/experiments/sweep-topology-ir-text/`, `run.sh` and `output.txt`).
