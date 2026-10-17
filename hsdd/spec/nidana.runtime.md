# nidana.runtime: Bus Runtime

- **Kind:** internal
- **Purpose:** the bus: turns topic declarations and topology definitions into live RxDart subjects and subscriptions and enforces the Bus Runtime Contract (Spec §3), lifecycle (Spec §7), observation (Spec §9), the error model (Spec §10) and runtime operations (Spec §11)
- **Owns:**
  - package `nidana_dart_runtime`, with its public libraries: the runtime and `testing.dart` (ADR-002)
  - `Bus` construction by explicit reference, never a global accessor (Spec §3.1); `BusConfig` with resource limits, grace period, scheduler provider, dev mode and the diagnostics sink (Spec §11.3, root D8)
  - the per-bus topic registry: lazy subject creation on first runtime access, the runtime name-and-type collision check, `removeTopic` with its atomicity and `force` rules (Spec §3.2, §4.3, §7.5, §3.10)
  - the publish path: StateTopic dedup (Spec §3.12), per-topic ordering (Spec §3.3), reentrancy normalization and dev-mode recursion detection (Spec §3.4), observers in registration order before subscribers with sensitive gating and exception swallowing (Spec §3.7, §9), the startup barrier and its dev-mode window (Spec §3.13), the publisher-less path for event and replay topics only (Spec §2.4)
  - publishers, `StateWriter` handles and the per-bus ownership table: first-claim at activation and at publisher construction, release on deactivation or disposal (Spec §2.4, §3.11 layer 1)
  - the live interpretation of topology-dsl@v1 with envelope threading through every combinator, applying the model's lineage functions (Spec §3.5, §6.3); time-dependent combinators on RxDart inside the provider zone, and a live `switchMap` of its own that does not wait on the previous inner's cancel future (ADR-003)
  - activation: idempotency on `topologyId` (Spec §3.9), cycle rejection (Spec §3.8), scope compatibility (Spec §7.2), `TopologyHandle` deactivation, retention across activations with `reduceInto` seeding (Spec §7.2)
  - scopes and module reference counting with the grace timer, as an adapter-facing API that UI adapters bind to route events (Spec §7.1 to §7.3)
  - `bus.toGraph()` over the active topologies (Spec §6.5)
  - dev-mode logging of terminated pipelines (Spec §10.2)
  - `start()`, `shutdown()` and rejection after shutdown (Spec §11.2)
  - dev-mode diagnostics as typed values to the configured sink (root D8)
  - the scheduler provider, `VirtualScheduler`, `VirtualSchedulerProvider`, `TestBus` and the envelope recorder with redaction of sensitive payloads (Spec §3.6, §9.2, Appendix A.7; ADR-003)
  - the per-topic ordering regression test (Guide §6.5)
  - an SDK-neutral telemetry observer implementing the Guide §8.2 mapping onto `ObserveContext.span` (root D1)
- **Does not own:** pure types, lineage rules, the IR and the analyses (nidana.model); route observation and widgets (nidana.flutter); navigation semantics (nidana.navigation); static checks (nidana.tooling); persistence (deferred, root D1)
- **Consumes:** [topic-model@v1, topology-dsl@v1, topology-ir@v1]
- **Produces:** [bus-api@v1, bus-testing@v1]
- **Governed by:** [ADR-001, ADR-002, ADR-003]
- **Sources:**
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_0.md` §1, §2.3 to §2.5, §3.1 to §3.13, §5.3, §5.5, §6.1, §6.3, §6.5, §7.1 to §7.5, §9, §10, §11, Appendix A.5, A.7
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-guide-v0_15_0.md` §2, §4, §6.1, §6.5, §8.1, §8.2, §8.4, §8.5, §10.1
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-rationale-v0_15_0.md` §2.1, §2.2, §3.2
- **Decomposes into:** child nodes minted by a later hsdd-spec run on this node
- **Isolation strategy:** builds against the model's contracts only; runs on the Dart VM with `TestBus` and the virtual scheduler, no Flutter; its gates replay the fixtures of bus-api@v1 and bus-testing@v1 and bind the `behavior/` fixtures of topology-dsl@v1, whose live semantics it implements (ADR-001)

## Overview

The runtime is the imperative shell around the model's pure core: it holds the mutable per-bus state (subjects, the ownership table, the active topology set, observers, reference counts, the startup queue) and the effects (subscriptions, timers, microtasks), and it decides nothing the model's pure functions can decide. Dart runs one isolate per bus, so the thread-safety rules of Spec §3.10 reduce to atomicity of each operation within one event-loop turn; a bus is never shared across isolates.

This node is internal because it spans several mechanisms that do not fit one phase plan. Its own hsdd-spec step decomposes it; the Owns list above is the scope that decomposition divides.

## Inherited from the root

- RxDart is the engine (root D9), resolved at 0.28.0 on the pinned SDK. Subject construction and the delivery timing that follows are this node's decision (OQ-R1).
- Time goes through the scheduler provider, a zone and a clock (ADR-003): the bus's subscriptions, `bus.observe` subscriptions, observer calls, timers and microtasks are all in the provider zone; no code chains on a future from outside it; no `DateTime.now()` and no `Timer` outside it.
- Dev mode defaults to "assertions enabled"; diagnostics are typed values sent to a sink in `BusConfig` (root D8).
- `TestBus` and the recorder live here, in `testing.dart`, with no dependency on `package:test` (root D4, ADR-002).
- Findings from `docs/auto-run/experiments/rxdart-sync-subjects/` that this node's design has to account for (root D9): synchronous delivery of `sync: true` publish subjects; first delivery of `sync: true` behavior and replay subjects in a microtask; `StateError` on a reentrant add to the same subject; depth-first delivery on a reentrant add to another subject; order restored by deferring the reentrant add with `scheduleMicrotask`.

## Open questions

| ID | Question | Status | Waits on | Affects |
|----|----------|--------|----------|---------|
| OQ-R1 | Do the bus's subjects keep RxDart's microtask-delayed first delivery for state and replay topics, or wrap subjects so a new subscriber receives the current value synchronously? | OPEN | the hsdd-contract step for bus-api@v1 (the guarantee consumers see); this node's decomposition records the outcome here | bus-api@v1, nidana.flutter |
| OQ-R2 | [inherits OQ2] What are the envelope recorder's assertion API and the way a test activates only the topologies under test? | OPEN | the hsdd-contract step for bus-testing@v1; this node's decomposition records the outcome here | bus-testing@v1, nidana.flutter, nidana.integration |
| OQ-R3 | Where does StateTopic dedup sit, given the per-read opt-out of Spec §3.12, and does an observer see a publish that dedup suppressed? | OPEN | the hsdd-contract steps for bus-api@v1 and topology-dsl@v1; this node's decomposition records the outcome here | bus-api@v1, topology-dsl@v1 |

### OQ-R1: First delivery of state and replay topics

Spec §2.1 and §7.4 say a state topic "replays immediately to new subscribers", and Spec §3.10 requires a subscription to receive the current value and every later emission or nothing. With `sync: true`, RxDart 0.28 delivers a behavior or replay subject's replay in the first microtask after `listen`, then any events published in between, in order (`docs/auto-run/experiments/rxdart-sync-subjects/output.txt` cases 1, 3, 8 and `output-replay-detail.txt` case a). The atomicity rule holds; "immediately" does not hold synchronously. A `Stream.multi` wrapper does not help: its listener also receives the first value after `listen` returns, and a reentrant `addSync` reorders subscribers (`output-replay-detail.txt` cases c and d). Options: keep RxDart's timing and state it as a bus-api@v1 guarantee, so a UI adapter takes the first frame from `getCurrentValue`; or build subjects on synchronous broadcast controllers that emit the current value during `listen`, at the cost of owning subject code the Specification expects the engine to provide (Spec §2.3).

### OQ-R2: Recorder assertions and topology test isolation

Guide §10.1 leaves the assertion API (equality, pattern matching, predicates) and single-topology isolation open; root OQ2 delegates both here. A fresh `TestBus` activates nothing, so isolation is mostly a question of stubbing the inputs a topology reads whose producers are absent from the test.

### OQ-R3: Dedup placement

Spec §3.12 makes a publish of an equal value a no-op for subscribers and downstream operators, yet lets one read opt out with `Dedup.none`, which means the subject itself must still see every publish. Options: dedup per read (each default read applies `distinctUntilChanged`), with the subject and observers seeing every publish; or dedup at publish with a side channel for opted-out reads. The choice decides what observers and the envelope recorder record.
