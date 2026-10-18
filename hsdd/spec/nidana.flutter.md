# nidana.flutter: Flutter Binding

- **Kind:** leaf-parent
- **Purpose:** the Flutter UI runtime adapter (Guide Appendix B layer 6, Spec Appendix A.8): bus reference acquisition, topic-driven widgets, page publishers, page and module scope binding, and the Flutter navigation executor
- **Owns:**
  - package `nidana_dart_runtime_flutter` (ADR-002)
  - `BusProvider`, an `InheritedWidget` at the app root, and `BuildContext` access to the bus; no global accessor (Spec §3.1, Guide §6.4)
  - topic-driven widgets: a state-topic builder that renders its first frame from `getCurrentValue` and later frames from `observe` (Spec §2.5), and a replay-topic counterpart over `getBufferedValues`; topology output drives the UI directly, with no interposed state holder (Rationale §5.1, §5.2)
  - page publishers whose `source` is derived from the route, `page:{route}` (Spec §2.4)
  - page-scope binding: a widget that activates its `PAGE` topologies on mount and deactivates them on unmount (Spec §7.1, §7.2)
  - module-scope binding: a route observer that matches route prefixes and acquires and releases the runtime's module scope references on push, pop and replace (Spec §7.3)
  - `FlutterNavigationRouter`, navigation-api@v1's `NavigationRouter` port over Flutter's own `Navigator`, and `FlutterNavigationExecutor`, which wires it to that contract's `NavigationExecutor` and turns platform routes into intents (Guide §3.4, §3.5; flutter-binding@v1 Refinements 1, 2 and 7)
  - bus shutdown when the coordination domain ends (Spec §11.2)
  - a widget-test library for apps, `WidgetTestBus` in the package's `testing.dart`: helpers that run a real bus under `testWidgets` with the production scheduler provider, so `tester.pump` drives time; they construct the bus inside the test body and shut it down when the tree unmounts, so no bus timer is pending when the body ends (ADR-003); the library imports neither `flutter_test` nor `test` (ADR-002 item 4)
- **Does not own:** reference counting arithmetic and the grace timer (nidana.runtime); intent vocabulary, guard and resolution (nidana.navigation); the app's routes, widgets and auth state
- **Consumes:** [topic-model@v1, topology-dsl@v1, bus-api@v1, bus-testing@v1, navigation-api@v1]
- **Produces:** [flutter-binding@v1]
- **Governed by:** [ADR-001, ADR-002, ADR-003]
- **Sources:**
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_0.md` §2.4, §2.5, §3.1, §5.2, §5.6, §7.1 to §7.4, §11.1, §11.2, Appendix A.8
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-guide-v0_15_0.md` §3.4, §3.5, §6.4, §9.3, Appendix B.1
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-rationale-v0_15_0.md` §5.1 to §5.4
- **Decomposes into:** phases (see hsdd-phase-plan)
- **Isolation strategy:** widget tests with `flutter_test` on the real runtime, time driven by `tester.pump` (ADR-003); navigation-api@v1's executor conformance suite is bound to `FlutterNavigationExecutor` and its router under `testWidgets`; nothing needs a device

## Overview

The adapter is thin by design: every decision about delivery, ownership, scope lifetime and grace lives in the runtime, and every decision about intents lives in navigation. This node binds those to Flutter's widget and route lifecycles. Flutter's UI runs on the same isolate as the rest of the Dart code, so no dispatcher hop is needed for UI-bound topics (Spec §11.1).

Two runtime facts shape the widgets (root D9, OQ-R1): `getCurrentValue` is synchronous, while a new `observe` subscription may receive its first value one microtask later. A topic widget therefore takes its first frame from `getCurrentValue` and must not render the replayed first value a second time.

## Open questions

| ID | Question | Status | Waits on | Affects |
|----|----------|--------|----------|---------|
| OQ-F1 | Which router does the Flutter executor and the module binding target: Flutter's own `Navigator` and `Router` APIs, or `go_router` as Guide §3.4 shows, and does that router become a dependency of the adapter? | OPEN | the hsdd-contract step for flutter-binding@v1; this node's phase planning records the outcome here | flutter-binding@v1, nidana.integration |

### OQ-F1: Router target

Spec §7.3 binds module scope through a `RouteObserver` and a route-prefix match; Guide §3.4's executor calls `GoRouter` (`go`, `push`, `pop`, `pushReplacement`). A `RouteObserver` sees `Route` objects whose names depend on how the app configures its router, and `BackTo` needs pop-until semantics the router may lack (Guide §3.2). Options: target the framework's `Navigator` and `Router` APIs with a small adapter interface the app implements for its router; or depend on `go_router` (18.1.0 on pub.dev, 2026-10-14) and support it first. The first keeps the adapter's dependency set to Flutter alone; the second matches the Guide's example and gives route paths for the prefix match without app glue.
