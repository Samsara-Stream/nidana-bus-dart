# Review: Nidana Bus Reference Architecture v0.8.2

Reviewed document: `docs/nidana-bus-ref-arch-v0_8.md`

## Overall assessment

The document is strong on motivation, vocabulary, and architectural intent. The core idea is coherent and interesting: typed topics plus declarative topologies as a coordination layer across shells. The main issue is that the document currently mixes three different things without separating them cleanly enough:

1. architectural principles,
2. desired implementation properties, and
3. behavior that depends on specific reactive runtimes.

Because of that, some sections overclaim, some examples contradict earlier rules, and several runtime-critical semantics are still underspecified. As written, the document is a good vision/RFC draft, but not yet a fully reliable reference architecture for implementers across Dart, Kotlin, Swift, and TypeScript.

## Highest-priority concerns

### 1. The document calls the core "pure" in places where it is clearly stateful and effectful

This is the biggest conceptual inconsistency.

- The bus creates subjects, activates subscriptions, disposes them, generates message IDs, stamps wall-clock timestamps, and may intercept traffic. Those are runtime effects, not pure computation.
- Active topologies are also described as part of the "pure core", but a live subscription graph is not pure in the FP sense. It may still be deterministic or well-bounded, but it is not pure.
- The current wording risks confusing a useful architecture boundary (domain logic isolated from I/O) with a much stronger claim (runtime purity) that the implementation cannot actually satisfy.

Recommendation: distinguish between a pure declarative model and an effectful runtime shell that executes that model.

### 2. The service/topology/I-O boundary is still ambiguous

Multiple sections say topologies are pure and contain no side effects, but examples and combinator guidance imply that async work may happen inside topology pipelines.

- `switchMap` is presented as "API call on search query change" in Section 5.3. That implies side effects in the topology pipeline.
- Section 9 recommends `retryWhen`, `onErrorResumeNext`, and circuit breakers in topologies, which again suggests effectful execution inside topology code.
- Section 2.5 says persistence I/O happens in an async service method at the shell boundary, not inside `declare()`.

These can all be made consistent, but only if the document explicitly defines the service adapter pattern. Right now it does not say whether a topology may invoke effectful stream sources, or whether topologies may only compose already-effectful streams exposed by shell adapters.

Recommendation: define one rule and apply it everywhere:

- either topologies are strictly pure stream wiring over shell-provided streams,
- or topologies may contain effectful reactive operators and are only "declarative", not pure.

### 3. Topic initialization rules conflict with multiple later examples

Section 2.5 says every `StateTopic` must declare an initial value. Later examples omit it repeatedly:

- `docs/nidana-bus-ref-arch-v0_8.md:377`
- `docs/nidana-bus-ref-arch-v0_8.md:1853`
- `docs/nidana-bus-ref-arch-v0_8.md:1863`
- `docs/nidana-bus-ref-arch-v0_8.md:1873`
- `docs/nidana-bus-ref-arch-v0_8.md:2002`
- `docs/nidana-bus-ref-arch-v0_8.md:2008`

That is not a cosmetic issue. The initial-value rule is load-bearing for replay semantics, hydration, lazy topic creation, and UI subscription behavior.

Recommendation: fix the examples and explicitly state whether `EventTopic`/`ReplayTopic` can be created lazily without seed values while `StateTopic` cannot.

### 4. Topic creation semantics are overgeneralized and currently inaccurate

Section 2.5 says that when the bus first encounters a topic reference, it creates a `BehaviorSubject` seeded with the initial value. That only makes sense for `StateTopic`.

- `EventTopic` should not be backed by a replaying subject.
- `ReplayTopic` has its own buffer semantics.
- `Flow`, `Combine`, and Rx implementations do not map one-to-one here.

Recommendation: specify creation semantics per topic variant, not as one generic rule.

### 5. Message envelope propagation is underdefined

The envelope model is useful, but the hard part is not defined:

- How is `correlationId` assigned for root messages?
- How is `causationId` computed when one output depends on multiple inputs, such as `combine`, `zip`, or `withLatest`?
- If a transformer emits multiple downstream messages from one input, do they all share the same parent `id`?
- If a message is replayed from persisted state, is the original timestamp preserved or replaced?
- Are envelope fields visible to transformers, or only to interceptors and tooling?

Without these rules, tracing, replay, and audit claims are not portable across implementations.

### 6. Lazy application scope is underspecified and may be hard to implement correctly

The rule "activate on first read or write to a topic the topology handles" creates several questions:

- How does the bus know which inactive lazy topology "handles" a topic before the topology is active?
- What happens if multiple lazy topologies read or write the same topic?
- What prevents recursive activation when activation itself reads topics?
- Is first access determined by topic name, topic object identity, or declared topology metadata?

Recommendation: define a concrete registration/indexing model for lazy topologies, or drop this feature from the core spec until the lifecycle contract is tighter.

## Internal inconsistencies

### 7. "No privileged observers" conflicts with bus-level interception

Section 8 says cross-cutting concerns are not special-cased and the architecture has no privileged observers. Then Section 8.1 introduces bus-level envelope interception that sees every publish/subscribe event.

That is a privileged observer.

Recommendation: acknowledge this explicitly and define interception as a runtime capability outside the topology model.

### 8. Error-as-values and stream-error operators are mixed together without a clear boundary

Section 9 says errors are values, not exceptions, and streams must not terminate on error. But the recommended techniques include reactive error-channel operators like `retryWhen`, `catchError`, and `onErrorResumeNext`.

Those techniques assume stream errors exist.

Recommendation: define two layers:

- shell/runtime failures may first appear as exceptions or error signals,
- topology-visible domain errors must be converted to typed values before they cross feature boundaries.

### 9. Persistence across navigation is presented as "free", but topic cleanup can remove that state

Section 6.5 says state persistence across navigation comes for free because topics outlive topologies. Section 6.6 then recommends topic cleanup strategies, including removal and TTL.

Those two claims are only compatible if the document defines which topics are durable across scope exits and which are not.

Recommendation: add a retention policy to topic definitions and make navigation persistence conditional, not universal.

### 10. The document says any topology can write to any topic, then later hints at owner-only write access

Early sections say any topology can read or write any topic it depends on. Later sections propose ownership annotations and even owner-team write restrictions.

This is an important architectural choice, not a tooling detail. Allowing unrestricted multi-writer state topics creates conflict semantics that the document does not address.

Recommendation: define whether multi-writer topics are first-class, discouraged, or restricted by policy.

### 11. The bus is called a singleton per process, but several platform mappings are not process-shaped

This becomes fuzzy on:

- iPad/macOS multi-window scenarios,
- web SSR request isolation,
- browser tabs or workers,
- tests running multiple app instances in one process.

Recommendation: define the bus as one coordination domain per runtime context, then map that to process, app instance, tab, scene, or request as needed.

## Missing runtime semantics

### 12. Ordering and reentrancy rules are missing

The architecture needs explicit answers for:

- Is publish synchronous, microtask-based, or scheduler-driven?
- If a subscriber publishes to another topic during handling, is delivery reentrant?
- Is per-topic ordering guaranteed?
- Is cross-topic ordering guaranteed at all?
- Are duplicate equal values suppressed automatically for `StateTopic`, or only with explicit `distinctUntilChanged`?

These are core semantics. Different answers lead to different correctness and performance behavior.

### 13. Cycle handling is mentioned but not specified

Section 10 mentions circular topology chains, but the spec does not define:

- whether cycles are allowed,
- whether they are only warned on,
- whether fixed-point behavior is ever intended,
- how the runtime detects or limits runaway feedback loops.

Recommendation: add a cycle policy section.

### 14. Concurrency and scheduler ownership are underspecified

The document says the bus delegates execution to the reactive engine and provides scheduler injection for tests. That is not enough for a cross-platform reference architecture.

Missing details include:

- default scheduler/dispatcher per topology,
- thread affinity for UI-facing topics,
- whether one topology may hop schedulers mid-pipeline,
- atomicity expectations when combining multiple topics updated concurrently.

### 15. Multi-writer state semantics are missing

If two services write to the same `StateTopic`, what is the intended model?

- last-write-wins,
- reducer-only updates,
- compare-and-swap,
- ownership partitioning,
- or "do not do this"?

This matters for auth, feature flags, connectivity, cache state, and persisted rehydration.

### 16. Delivery guarantees and buffering are not defined

The spec talks about event topics, replay topics, persistence, and time-travel, but does not clearly specify:

- at-most-once vs at-least-once delivery within a process,
- behavior with late subscribers,
- buffer overflow policy for replay topics,
- whether backpressure is best-effort or strict,
- what happens when consumers are slower than producers.

## Platform and framework concerns

### 17. The platform guidance is not internally consistent about Rx vs native primitives

Section 13.5 recommends native reactive primitives as the external API and Rx internally. But the Flutter section exposes RxDart directly in the topology surface, and the core topic model is still described mostly in Rx terms.

Recommendation: choose one of these positions:

- Rx-first public API, or
- platform-native public API with an internal adapter layer.

Right now it reads as both.

### 18. The Angular example does not match the described module lifecycle

The example activates `checkoutTopology` in a root-provided service constructor. That is application lifetime behavior, not module scope.

If Angular is supposed to support module or route-scoped topology activation, the example should use route providers, lazy route boundaries, or component-level activation.

### 19. The Vue example subscribes to a topic but never shows topology activation

The React section has `useTopology`. The Vue example only reads topic state. That leaves a gap in the recommended pattern.

Recommendation: add a Vue composable or route-level pattern for topology activation/deactivation.

### 20. The React hook API is incomplete relative to the SSR section

`useSyncExternalStore` normally needs a server snapshot function for SSR-safe rendering. The document later discusses SSR/hydration, but the hook shown only provides the client-side snapshot.

The issue is not huge, but it is exactly the sort of gap implementers will trip over.

### 21. TypeScript examples need a more precise contract story

The TS examples use `void` event payloads and plain object returns, while earlier sections strongly prefer named structures over primitives and ADTs for state. TS can support discriminated unions very well, but that advantage is not used consistently.

## Claims that should be softened or evidenced

### 22. The resilience section overstates what is "eliminated by construction"

Some listed items are only reduced, not eliminated.

- Immutable payloads do not eliminate all race conditions. Ordering races, stale reads, and feedback-loop races still exist.
- Pure functions do not eliminate all unhandled exceptions on Dart/Kotlin/Swift/TypeScript. Developers can still throw, index out of bounds, divide by zero, unwrap null, or call unsafe APIs.
- Topology isolation does not automatically prevent cascading failure if multiple topologies depend on a corrupted shared topic.

Recommendation: move more of these claims from "eliminated" to "mitigated under constraints".

### 23. The determinism section is stronger than the implementation model supports

The claim that activation order does not matter, and that only explicit time-dependent operators introduce non-determinism, is too strong for hot streams and concurrent runtimes.

Potential nondeterminism sources include:

- scheduler choice,
- subscription timing,
- merge/interleave order from concurrent producers,
- replay timing during activation,
- side effects hidden inside upstream stream sources.

Recommendation: scope determinism claims to a narrower model, such as a closed topology over controlled schedulers and fully specified source ordering.

### 24. The category-theory and formal-verification section is interesting, but too assertive in places

This section is intellectually ambitious, but several claims read stronger than they are:

- hot observables and effectful streams do not behave like clean category-theory objects without caveats,
- Kahn Process Network analogies break down once operators like `switchMap`, `debounce`, `timeout`, and replaying hot streams are involved,
- "boundedness is decidable for finite-state topologies" is not something most readers will accept without a narrower formal model.

Recommendation: frame this section as intuition and possible future formalization, unless a precise execution model is defined first.

### 25. AI-agent compatibility claims are plausible, but not yet demonstrated

The doc argues that topology graphs make the architecture friendlier to AI coding agents. That may be true, but the document currently treats it as near-established fact rather than a hypothesis.

Recommendation: present this as an expected tooling benefit unless backed by concrete experiments or examples.

## Security and operational concerns that need more attention

### 26. Envelope interception and audit topics can easily leak sensitive data

The spec uses auth, payment, and analytics examples, but does not define redaction rules.

Open questions:

- Are payloads ever copied wholesale into audit streams?
- Can tokens, PII, or payment details appear in envelope metadata or tooling exports?
- Can devtools be enabled in production builds?

Recommendation: add a security/privacy subsection covering redaction, sampling, opt-in auditability, and environment gating.

### 27. Server-driven topology rewiring expands the trust boundary substantially

Section 16.4 notices this, but the concern is larger than the current wording suggests. Even wiring-only changes can silently bypass policy controls if topic permissions and side-effect boundaries are not formalized.

This feature should probably remain explicitly out of scope for the base architecture until the static model is tighter.

## Suggested questions to resolve before calling this a reference architecture

1. Is the runtime core pure, or is only the topology definition pure?
2. Can topologies contain effectful stream sources/operators, or must effects stay in shell adapters?
3. What are the publish, ordering, replay, and reentrancy semantics?
4. What is the supported multi-writer model for topics?
5. What exact metadata propagation rules govern envelopes through fan-in/fan-out transforms?
6. Which lifecycle features are mandatory for v1, and which are optional experiments?
7. Which claims are architectural goals versus verified properties of a concrete implementation?

## Bottom line

This is a promising architecture draft with a strong center of gravity, especially around typed coordination contracts and explicit topology wiring. The main risk is not that the idea is weak. The risk is that the document currently presents several advanced properties as if they are already unified and implementation-ready, when the runtime contract is still missing key semantics and some examples contradict the stated rules.

If the next revision focuses on tightening the execution model, reducing overclaims, and aligning all examples with the stated invariants, the document will get materially stronger.
