# nidana.navigation: Navigation

- **Kind:** leaf-parent
- **Purpose:** navigation as a cross-cutting concern on the bus (Guide §3): the intent vocabulary, typed routes, the nav-resolver topology template with its pure guard and deep-link resolution, and the platform-neutral executor protocol
- **Owns:**
  - package `nidana_dart_navigation`, pure Dart with no Flutter dependency (ADR-002)
  - `NavIntent` and `ResolvedNavIntent`, in which a deep link is impossible by construction (Guide §3.2, Spec Appendix A.6)
  - `Route` and `RouteRegistry` (Guide §3.2)
  - `RouteState` and `RouteTransition` (Guide §3.2)
  - `RouteAccessRequirement` and `RouteAccessPolicy`, static or reactive (Guide §3.2, §3.4)
  - `NavigationTopics`: `nav.intent`, `nav.resolved-intent`, `nav.current-route`, `nav.history`, `nav.access-policy` (Guide §3.3)
  - the nav-resolver topology template at `APPLICATION` scope, with `applyAuthGuard` and `resolveDeepLinks` as pure functions; the two-topology split that keeps the read/write graph acyclic (Guide §3.4, Spec §3.8)
  - the `NavigationExecutor` protocol: subscribe to resolved intents, claim `nav.current-route` as its shell owner (Spec §3.11), write `currentRoute` and `history` together on each confirmed transition with the intent taken from the platform's confirmation (Guide §3.4); `BackTo` synthesis for routers without a native pop-until (Guide §3.2)
  - the executor protocol's conformance suite, delivered as the `behavior/` fixtures of navigation-api@v1 that every platform executor binds (ADR-001)
  - the deep-link bootstrap order: the resolver is active and the executor constructed before `start()` (Guide §3.5, Spec §3.13)
  - result handling through typed result topics, matched on payload, never on envelope metadata (Guide §3.6)
- **Does not own:** platform router calls and route observation (nidana.flutter); the app's auth state type, roles and route table (app code); bus mechanics (nidana.runtime)
- **Consumes:** [topic-model@v1, topology-dsl@v1, bus-api@v1, bus-testing@v1]
- **Produces:** [navigation-api@v1]
- **Governed by:** [ADR-001, ADR-002, ADR-003]
- **Sources:**
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_0.md` §2.4, §3.8, §3.11, §3.13, Appendix A.6
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-guide-v0_15_0.md` §2, §3.1 to §3.7, Appendix A
- **Decomposes into:** phases (see hsdd-phase-plan)
- **Isolation strategy:** `applyAuthGuard` and `resolveDeepLinks` are pure functions tested directly; the resolver topology is tested structurally through its recorded IR (model only) and live on `TestBus`; the executor protocol and its conformance suite are exercised with an in-memory router, so no Flutter is needed

## Overview

Pages publish intents; the resolver topology guards and resolves them; an executor at the shell performs the platform call and reports the confirmed route. This node owns everything in that chain except the platform call. The package is opt-in by use: an app that never activates the resolver or constructs an executor pays nothing at run time, although the Flutter adapter depends on the package (root D7).

Route transition timestamps go through the bus's scheduler provider clock, never `DateTime.now()` (ADR-003).

## Open questions

| ID | Question | Status | Waits on | Affects |
|----|----------|--------|----------|---------|
| OQ-N1 | How does the library's resolver template bind to an app's own auth state type, which Guide §3.4's resolver reads directly? | OPEN | the hsdd-contract step for navigation-api@v1; this node's phase planning records the outcome here | navigation-api@v1, nidana.flutter, nidana.integration |
| OQ-N2 | Do routes carry typed arguments (`Route<Args>`) or untyped maps? | OPEN | the hsdd-contract step for navigation-api@v1; this node's phase planning records the outcome here | navigation-api@v1, nidana.flutter |

### OQ-N1: Auth binding of the resolver template

Guide §3.4's `nav-resolver` reads `AuthTopics.state` and tests `AuthState.Authenticated` and a user role, both app types. A library template cannot name them. Options: the template takes the app's auth topic and a pure projection from its state to an access principal (authenticated or not, roles); or the template takes a guard function and the topics it reads, leaving `applyAuthGuard` as a default for apps that adopt a library-provided principal type.

### OQ-N2: Typed route arguments

Guide §3.2 leaves typed route arguments to each platform: compile-time safety against registry complexity. The answer shapes `NavIntent.GoTo`, `RouteState.args`, and how the Flutter executor passes arguments to its router (OQ-F1).
