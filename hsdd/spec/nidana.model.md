# nidana.model: Model

- **Kind:** leaf-parent
- **Purpose:** the pure, effect-free core every other package builds on: typed topics, the message envelope and its lineage rules, observer interfaces, the topology DSL interface with its recording builder, the TopologyDefinition IR, graphs and renderers, and the pure analyses over the IR
- **Owns:**
  - package `nidana_dart_contracts` (ADR-002)
  - `StateTopic`, `EventTopic`, `ReplayTopic`, `TopicRef`; topic identity as the pair of name and type (Spec §2.1); the `domain.entity` naming pattern (Spec §4.4); `Dedup` (Spec §3.12); `Tracing` (Guide §8.1); the sensitive flag (Spec §9.2); initial values as pure constants or pure factories (Spec §2.5)
  - `MessageEnvelope` (Spec §2.4) and the lineage rules as pure functions: single-input, multi-input with the trigger and correlation rules, time-shifting and accumulator operators (Spec §2.4, §3.5)
  - `Scope` (Spec §7.1) and the scope-compatibility rule over an ownership table (Spec §7.2)
  - `BusObserver`, `ObserveContext`, `ObserverCapability` as interfaces with no publish path (Spec §3.7)
  - sensitive-payload redaction: the payload type plus a truncated hash (Spec §9.2 item 2)
  - `Topology`, the `topology(id, scope, body)` form, `TopologyBuilder` and the opaque stream handle with the Spec §6.3 combinators, `reduceInto`, error operators and the raw-engine escape hatch (Spec §3.5, §6.1 to §6.3); every combinator is wrapped (root D6)
  - the recording builder and `buildDefinition()` (Spec §6.5)
  - `TopologyDefinition`, `TransformEdge`, `CombinatorKind`, `FunctionRef`, and the IR's JSON form (Spec §6.5)
  - `TopologyGraph`, `toGraph()`, and the Mermaid, Graphviz and JSON renderers (Spec §6.5)
  - pure analyses: inter-topology cycle detection by strongly connected components, the intra-topology self-reference check (Spec §3.8), scope compatibility (Spec §7.2), topic name uniqueness over a set of declarations (Spec §4.3)
  - the contract replay tool, package `nidana_contract_check` (not published), written in this node's first phase (ADR-001)
- **Does not own:** subjects, subscriptions, timers, zones and the live interpretation of the DSL (nidana.runtime); source scanning and catalog runs (nidana.tooling); navigation types (nidana.navigation); any dependency beyond the SDK and `meta` in `nidana_dart_contracts`
- **Consumes:** none
- **Produces:** [topic-model@v1, topology-dsl@v1, topology-ir@v1]
- **Governed by:** [ADR-001, ADR-002, ADR-003]
- **Sources:**
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_0.md` §1, §2.1 to §2.5, §3.5, §3.8, §3.12, §4.1, §4.2, §4.4, §4.6, §6.1 to §6.5, §7.1, §7.2, §8, §9.2, Appendix A.1 to A.4
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-guide-v0_15_0.md` §1.1, §1.4, §6.3, §8.1, Appendix B.1 to B.3
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-rationale-v0_15_0.md` §3.1 to §3.3, §4.1
- **Decomposes into:** phases (see hsdd-phase-plan)
- **Isolation strategy:** `nidana_dart_contracts` depends on nothing beyond the SDK and `meta`, so every function is tested by direct calls and property tests with generated inputs, and every topology by recording it and asserting on the IR; the node's gates replay the `surface/`, `reject/` and schema fixtures of its three contracts with its own replay tool; the `behavior/` fixtures of topology-dsl@v1 that need a live bus are bound by nidana.runtime, which implements the live side

## Overview

This node is the pure core of the tree: everything in it is a value or a total function, so it can be reasoned about and tested without a bus, a zone or a widget. Topology modules in adopting apps depend on this package alone; the runtime (live activation) and the tooling (static catalog and checks) both consume the same recorder and the same analyses, so the activation-time checks of Spec §3.8 and §7.2 and the CI checks cannot drift apart (root D4).

The package name follows Guide B.2's layer 1 name for traceability; its content differs from Guide B.1 in two ways the root decided: navigation types are not here (root D7), and the DSL interface, recorder and analyses are (root D4).

## Inherited from the root

- Ordering policy `fp-progression` (conventions): the first phase lands the type-level skeleton of all three contracts and the replay tool, because every other node's first edge waits on it (root D10).
- Every combinator is a method on this node's handle or builder; topology bodies never call RxDart on read handles (root D6).
- Diagnostics and dev mode are runtime concerns reached through bus-api@v1 (root D8); nothing here logs.

## Open questions

| ID | Question | Status | Waits on | Affects |
|----|----------|--------|----------|---------|
| OQ-M1 | How does the recorder name a transformer (`FunctionRef`) in Dart? | OPEN | the hsdd-contract step for topology-ir@v1; this node's phase planning records the outcome as a D{n} here | topology-dsl@v1, topology-ir@v1, nidana.tooling |
| OQ-M2 | How does live activation obtain the transformers a pure-data IR names? | OPEN | the hsdd-contract steps for topology-dsl@v1 and topology-ir@v1; this node's phase planning records the outcome here | topology-dsl@v1, topology-ir@v1, nidana.runtime |
| OQ-M3 | Does the Dart topic model carry Spec §3.6's per-topic dispatcher hint at all? | OPEN | the hsdd-contract step for topic-model@v1; this node's phase planning records the outcome here | topic-model@v1, nidana.runtime |

### OQ-M1: Naming transformers

Spec §6.5's `FunctionRef` is a serializable reference to a named transformer, and Spec §6.2 says transformers should be named standalone functions. Dart has no reflection in Flutter builds. The experiment `docs/auto-run/experiments/function-ref-names/` shows a tear-off's `toString()` carries the function name in both JIT and AOT builds without obfuscation (`Closure: (int, int) => int from Function 'buildTotal': static.`), omits the class of a static method, carries no name for an inline closure, and loses the name under `--obfuscate`. Options: derive names from `toString()`; require an explicit name on each combinator; accept an optional name and fall back to derivation, then to a positional placeholder; or leave naming to the static catalog in nidana.tooling. The build-time catalog runs on the VM without obfuscation, which favors derivation with an explicit override; the decision is the interface author's.

### OQ-M2: Executable transformers behind a pure-data IR

Spec §6.5 says the bus "interprets the same IR for live activation", while `TransformEdge` holds a serializable `FunctionRef`, not a function. Options: an edge carries an opaque executable beside its `FunctionRef`, excluded from equality and from the JSON form; or activation records the IR for checks and then runs `declare()` a second time against a live builder. The first matches the Specification's wording; the second keeps the IR pure data but relies on `declare()` being deterministic, which Spec §6.1 already demands.

### OQ-M3: Dispatcher hint on one isolate

Spec §3.6 lets a topic declare a preferred dispatcher and says the runtime uses the hint "where supported". On Dart every topic of a bus shares the isolate's event loop (Spec §3.6 table), so the hint has no effect. Options: omit the field from the Dart topic model, or accept it and ignore it so that a declaration translated from another platform compiles.
