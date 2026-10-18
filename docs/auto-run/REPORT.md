# Automatic HSDD planning run: report

The run planned nidana-bus-dart from scratch through reconcile, unattended, on branch
`auto/v1-planning`, and implemented no phase. It ended without a stop: every leaf-parent has a phase
plan, every contract is `stable` with `phase_ids: final`, no pending governance section is left, and
`node docs/auto-run/tools/gate.mjs --final` passes. Every decision the planning asked of a human was
taken on the owner's behalf and is recorded in `hsdd/judgement/decisions.jsonl` (684 decisions),
each with the commit that holds its artifact. `hsdd/judgement/run.jsonl` has one line per step.
`docs/auto-run/execution-plan.md` is the path the run took and why it moved.

- **Shape:** root `nidana` with six children; `nidana.tooling` has two. Seven leaf-parents hold 64
  phases.
- **Governance:** ADR-001 (executable contract validation), ADR-002 (package and workspace layout)
  and ADR-003 (time source and virtual scheduler) are accepted, each amended in place since. There are
  nine contracts, all `@v1`, `stable`, `phase_ids: final`, each with fixtures the replay tool runs.
- **Steps:** 54 steps, S00 to S53, and this report as S54. Each skill step was committed twice: its
  artifacts, then its judgement lines. There are 53 experiments under `docs/auto-run/experiments/`.
- **Stops:** no HSDD skill stopped to ask, and no run-stop condition held. The orchestrator judged
  every run-stop candidate a subagent raised and recorded why each one did not hold: DEC-186, DEC-193,
  DEC-362, DEC-373, DEC-430 and DEC-471 (listed below).

## The tree

```
nidana                               internal (root)
├── nidana.model                     leaf-parent, 14 phases   topic-model@v1, topology-dsl@v1, topology-ir@v1
├── nidana.runtime                   leaf-parent, 14 phases   bus-api@v1, bus-testing@v1
├── nidana.navigation                leaf-parent,  6 phases   navigation-api@v1
├── nidana.flutter                   leaf-parent,  7 phases   flutter-binding@v1
├── nidana.tooling                   internal
│   ├── nidana.tooling.codegen       leaf-parent, 11 phases   topic-codegen@v1, nidana-checks@v1 (scan share)
│   └── nidana.tooling.lint          leaf-parent,  4 phases   nidana-checks@v1 (plugin share)
└── nidana.integration               leaf-parent,  8 phases   produces none; consumes all nine
```

Packages, one pub workspace at the repository root (ADR-002): `nidana_dart_contracts` and
`nidana_contract_check` (the replay tool, not published) from nidana.model, `nidana_dart_runtime`,
`nidana_dart_navigation`, `nidana_dart_runtime_flutter`, `nidana_dart_codegen`, `nidana_dart_lint`, and
`nidana_integration` (the example app, not published). The critical path is nidana.model, then
nidana.runtime, then nidana.navigation and nidana.flutter side by side, then nidana.integration: 21
phases. nidana.tooling.codegen runs beside it with two phases of slack (root Development flow, as S47
restated it).

**nidana (root).** D1 sets the v1 scope. It follows the Guide's own v1 plan for Dart and Flutter,
narrowed where the Guide records a design as open and widened only where the Specification requires a
mechanism. Persistence, a concrete OpenTelemetry binding, devtools and the perf suite are deferred,
each with the signal that would bring it in. The children are capability slices along package
boundaries (D3). D9 makes RxDart the only engine, and D6 has the Dart DSL wrap every combinator so the
recorder sees every edge. D10 defines what an edge between Dart packages means: a `contract` edge waits
on the producer phase the contract's Delivery paragraph names, and a `hard` edge is read per phase.
The conventions fix `fp-progression` ordering, one-PE phases and superpowers as the coding method.

**nidana.model, 14 phases.** This is the pure core: topics, the envelope and its lineage, observer
interfaces, the topology DSL and its recording builder, the TopologyDefinition IR, graphs, renderers and
the pure analyses. The replay tool comes first (.1 and .2), then one type-level phase per contract (.3
to .5), then the tool's behavior, file and cli sets (.6, .7). Behavior lands after that: values and
lineage (.8), the recording builder (.9), IR values (.10), projection and graphs (.11), analyses (.12),
the JSON form (.13) and renderers (.14). It stayed a leaf-parent at 14 phases against HSDD's "add a
level" tip (DEC-430), because ADR-002 item 3 gives the three contracts one package and ADR-001 item 10
puts a contract's declarations in one leaf-parent's first producing phase.

**nidana.runtime, 14 phases.** This node is the bus, with `TestBus`, the virtual scheduler and the
envelope recorder in its `testing.dart`. S22 reversed root D4 and made it a leaf-parent (DEC-362).
`TestBus` extends the final `Bus`, so both produced contracts share one library. Fixtures may not
import `src/` (ADR-001 item 2), so an internal contract between runtime children could never become
stable. The surface lands first,
then a pure band (.2 to .4), virtual time (.5), the delivery lane (.6 to .8), the pipeline lane (.9,
.10), activation (.11, .12), test support (.13) and module scopes with lifecycle (.14). It owns a live
`switchMap` that does not wait on RxDart's cancel future (ADR-003; marked for upstreaming).

**nidana.navigation, 6 phases.** This node holds the intent vocabulary, typed `NavRoute`s (renamed
from Route, which Flutter exports), the nav-resolver template and the platform-neutral executor
protocol with an in-memory router. The resolver resolves a deep link first and then guards the
resolved intent, where the Guide guards first (DEC-217, marked for upstreaming).

**nidana.flutter, 7 phases.** This node holds the bus provider, topic widgets, page scope (holders
counted per bus and topology id), module scope by stack membership, the widget-test bus, and
`FlutterNavigationExecutor` over Flutter's own Navigator with no router dependency (DEC-247). The
bootstrap follows Guide §3.5's order.

**nidana.tooling.** This internal node has two leaf-parents. nidana-checks@v1 has two producers: the
plugin's per-library rules and codegen's workspace scan. Reconcile took the union of their phases
(nidana.tooling D2), and nidana.integration's `--all` is the one unrestricted replay of both shares.

**nidana.tooling.codegen, 11 phases.** `nidana_dart_codegen` writes `lib/topics.g.dart` from
`lib/topics.yaml` through the builder and `generate` with the same bytes. It also writes the topic
catalog and graph page, and runs the `catalog` command, which loads an app's
`tool/nidana_catalog.dart` registration and records its topologies (D1, marked for upstreaming against
Spec §6.5's `@Topology`). The workspace scan shares the claim recognizer with `catalog`. Two lanes, the
registry and the workspace, meet at .11.

**nidana.tooling.lint, 4 phases.** `nidana_dart_lint` is an analysis server plugin, not custom_lint,
because custom_lint pins analyzer 8.x against the workspace's 13.3.0 (ADR-002; marked for upstreaming).
It depends on no nidana package, so it loads anywhere. Phases .1 to .3 wait only on the replay tool's
sets, and .4 reports the rules and replays the `analyze-*` cases.

**nidana.integration, 8 phases.** `nidana_integration` is an example Flutter app with end-to-end
slices for bootstrap, hydration, single-writer, module scope, guarded navigation, observation and CI.
The unrestricted `--all` replay runs first at .6 and again at .7 and .8. The CI slice runs codegen and
the v1 checks over the example and fails on seeded violations. Cart hydration as Guide Appendix A shows
it cannot fire for a MODULE-scoped topology, so the example leaves it out (D5, marked for upstreaming).

## Decisions to look at first

Four cuts of the ledger, then the whole ledger by blast radius. Each line gives the decision id, the
step, its confidence and its flags, the question, and what was chosen; the full record (options with
consequences, the reason, the evidence) is the line with that id in `hsdd/judgement/decisions.jsonl`.

- **Lowest confidence.** Two decisions are marked low. DEC-175 makes a late APPLICATION activation a
  dev-mode report rather than a throw. DEC-427 orders the root workspace list by path.
- **Widest blast radius.** DEC-053 is the one `upstream` decision. Of the 44 `tree` decisions, these
  shaped the tree most: v1 scope (DEC-014 to DEC-016), the child set (DEC-019), the package layout
  (DEC-026, DEC-052), the plugin over custom_lint (DEC-027), the time source (DEC-028), the runtime as
  a leaf-parent (DEC-362), the tooling split (DEC-373) and nidana.model kept at 14 phases (DEC-430).
- **Stops answered on the owner's behalf.** No skill stopped, so no stop was answered. What the
  orchestrator decided itself is listed below: the inputs and the run's protocol (DEC-001 to DEC-010),
  six run-stop candidates judged not to hold, the follow-up batching, and the stage-7 consistency pass
  (DEC-603 to DEC-606). The candidates judged not to hold:
  - DEC-186 and DEC-193: a compatible topic-model@v1 amendment and its inference effect, before any
    consumer code existed.
  - DEC-362: the runtime as a leaf-parent, a shape question. It is medium confidence and marked
    `would_have_asked`.
  - DEC-373: the tooling split.
  - DEC-430: nidana.model at 14 phases, medium confidence.
  - DEC-471: a bus-api@v1 G8 wording edit that S31 flagged as possibly breaking.

  DEC-002 records how the shape stop was read: it holds only when both leading options are defensible
  and nothing (the Specification, the owner's facts, an experiment, the Guide, the Rationale or HSDD's
  rules) gives either one a stated reason.

### Lowest confidence

- **DEC-175** (S09, low, would have asked: axis). Spec §7.2 says the bus enforces that APPLICATION topologies activate before start(). Does a later APPLICATION activation throw? Chosen: report LateApplicationActivation in dev mode and activate.
- **DEC-427** (S28, low). Which order should the shared root workspace list follow, as a proposed convention? Chosen: path order, one member per line.

### Widest blast radius: tree and upstream

- **DEC-001** (S00, high). How does the reference architecture enter the root hsdd-spec run: which files, with what authority? Chosen: Spec, Guide and Rationale, each with its authority.
- **DEC-002** (S00, medium, would have asked: shape). How is the run-stop condition 'two leading options change the tree's shape, the Specification is silent, no experiment settles it' read, given that the same policy lists v1 scope and decomposition ... Chosen: Both defensible, no stated reason.
- **DEC-005** (S01, medium). In what order do decomposition and contract authoring run? Chosen: Per level.
- **DEC-006** (S01, medium, would have asked: collision). When does hsdd-reconcile run: once after every leaf-parent is planned, or after each phase plan? Chosen: After each phase plan.
- **DEC-011** (S02, high). What are the root node's id and name? Chosen: nidana.
- **DEC-012** (S02, high). hsdd-spec asks "who builds what?" Chosen: Capability slices along package boundaries.
- **DEC-014** (S02, medium, would have asked: shape). Does navigation (Guide Appendix B layer 4, Guide §3) ship in v1? Chosen: Navigation in v1, executor in the Flutter adapter.
- **DEC-015** (S02, high, would have asked: shape). Does persistence (Guide Appendix B layer 5) ship in v1? Chosen: Defer persistence.
- **DEC-016** (S02, high, would have asked: shape). Which Layer 7 tools ship in v1? Chosen: Guide's planned-v1 tools.
- **DEC-019** (S02, medium). What is the root's child set, and what kind is each child? Chosen: Six children: model, runtime, navigation, flutter, tooling, integration.
- **DEC-020** (S02, medium). Where do TestBus, the virtual scheduler and the envelope recorder live: in the runtime, or in a separate test-utilities node and package? Chosen: Inside nidana.runtime, as its testing.dart library.
- **DEC-022** (S02, high). Do the root's children need an integration node? Chosen: Add nidana.integration.
- **DEC-024** (S02, medium). What do contract and shared-model edges mean between Dart packages, where a consumer cannot compile without the producer's declarations? Chosen: Start after the producer's first phase.
- **DEC-025** (S02, medium). What does executable validation (hsdd-contract's schema or fixtures) mean for this tree's contracts, most of which are Dart API surfaces? Chosen: Compile, reject and conformance fixtures for Dart surfaces; JSON Schema for data.
- **DEC-026** (S02, medium, upstream). What package set and workspace layout does the tree use? Chosen: Pub workspace at the repository root, Guide B.2 names, runtime layers in one package.
- **DEC-027** (S02, high, upstream). Which static-analysis mechanism carries the v1 checks: custom_lint, which Spec §3.11 and Guide C.2 name, or the Dart 3.10 analysis server plugin API? Chosen: Analysis server plugin, no custom_lint in the workspace.
- **DEC-028** (S02, medium, upstream). How do Spec §3.6's SchedulerProvider and VirtualScheduler map onto Dart, where RxDart's time operators take no scheduler? Chosen: Zone plus clock provider, own VirtualScheduler.
- **DEC-033** (S02, medium). Which ordering policy does conventions.md declare? Chosen: fp-progression.
- **DEC-052** (S04, high, upstream). Does the package set and naming of the root's proposal hold on the pinned SDK (eight members under packages/, Guide B.2 names where a package keeps its layer's role, layers 2 and 3 folded into ... Chosen: Keep the proposal's package set and names.
- **DEC-053** (S04, high, upstream). Does the analysis server plugin stay the static-analysis mechanism once the real single resolution is known (the proposal's rationale said that without custom_lint 'the SDK's analyzer 14.5.0 resolves')? Chosen: Analysis server plugin, no custom_lint.
- **DEC-054** (S04, medium). What does the root analysis_options.yaml contain beyond the proposal's excludes? Chosen: lints/recommended plus strict-casts, strict-inference, strict-raw-types.
- **DEC-055** (S04, high). ADR-001 follow-up: does the root's exclude list add hsdd/** beside ref/** and docs/**? Chosen: Exclude ref/**, docs/** and hsdd/**.
- **DEC-057** (S04, high). How do members declare dependencies on each other: hosted version constraints or path dependencies? Chosen: Hosted version constraints.
- **DEC-059** (S04, high). Where do example/ folders go: non-member packages with uncommitted lockfiles (the proposal), nested workspace members, or plain folders inside their member with no pubspec? Chosen: No pubspec: part of the member.
- **DEC-060** (S04, high). ADR-001 follow-up on the plugin mechanism: where is nidana_dart_lint enabled so that dart analyze runs its rules? Chosen: Workspace root options, added by the phase that creates the plugin.
- **DEC-066** (S04, medium). What strictness does the workspace-wide analyze hold? Chosen: Clean under fvm dart analyze --fatal-infos at the root.
- **DEC-090** (S05, medium). Which nodes and contracts does ADR-003 affect (the proposal listed nidana.runtime, nidana.navigation, nidana.flutter, nidana.integration, bus-api@v1, bus-testing@v1)? Chosen: Proposal's set plus nidana.model, navigation-api@v1, flutter-binding@v1.
- **DEC-355** (S22, medium, would have asked: shape). Break down nidana.runtime into its child nodes (capability slices within one owner's territory), cut against bus-api@v1 and bus-testing@v1: which children, of which kind, joined by which contracts ... Chosen: Leaf-parent, no children.
- **DEC-362** (S22, medium, would have asked: shape). S22 reversed root D4: nidana.runtime becomes a leaf-parent (about twelve phases over ten internal slices) instead of an internal node with children. The two leading options (leaf-parent; or two ... Chosen: Not a stop; accept the leaf-parent.
- **DEC-363** (S23, medium, would have asked: shape). Is nidana.tooling decomposed into children, and along which boundary, or is it itself a leaf-parent as S22 concluded for the runtime? Chosen: Two leaf-parent children, one per package.
- **DEC-370** (S23, high). Do the children consume bus-testing@v1, navigation-api@v1 and flutter-binding@v1, whose declarations the checks recognize by name and whose packages the recorded invocations import? Chosen: Consume them as contract edges.
- **DEC-373** (S23, high). S23 decomposed nidana.tooling into two leaf-parents, nidana.tooling.codegen (about nine phases) and nidana.tooling.lint (about three), with nidana-checks@v1 produced by both; the alternative is one ... Chosen: Not a stop; accept two children.
- **DEC-376** (S24, medium, would have asked: shape). The general form must also say what happens to the sets item 10 runs in full (surface, reject) when a contract has several producers: item 10 justifies running them in full by 'the first phase of the ... Chosen: api and shared-model contracts have one producing leaf-parent.
- **DEC-402** (S26, high). S26 found that navigation-api@v1's and flutter-binding@v1's behavior suites import topology_ir.dart, so nidana.navigation and nidana.flutter consume topology-ir@v1, but neither node's Consumes nor ... Chosen: Short hsdd-spec touch now.
- **DEC-430** (S28, medium, would have asked: shape). nidana.model now has 14 phases, past HSDD's 'add a level, do not widen' tip. Decompose it into children before going on, or keep it a leaf-parent? Chosen: Keep it a leaf-parent.
- **DEC-436** (S29, medium). note 1 (root pubspec.yaml workspace list and pubspec.lock shared by every member-creating phase; proposed: list in path order, one member per line): does it change a convention, and where does it land? Chosen: conventions, Execution protocol.
- **DEC-437** (S29, medium). note 2 (the replay tool's sets land in nidana.model.1, .2, .6 and .7, which adds non-contract waits for other nodes' gates): does it change a convention? Chosen: conventions, Phase design.
- **DEC-438** (S29, high). note 3 (the conventions' 'Phase 1 of a leaf-parent is the type-level skeleton' holds for nidana.model only as a band; proposed text 'the type-level band, which opens the plan after any gate ... Chosen: rewrite the fp-progression paragraph.
- **DEC-439** (S29, medium). Should the Delivery paragraph this pass wrote become a convention for every later reconcile, so the steps that drain nidana.runtime's and the other plans do the same? Chosen: state it under Contracts.
- **DEC-511** (S35, high). Note 2 (a Flutter member's tests run from the root as fvm flutter test --no-pub packages/{member}; under flutter test Isolate.resolvePackageUri throws, so a test that reads its own sources finds the ... Chosen: add a Phase design bullet.
- **DEC-537** (S37, medium). Note 4 (nidana_dart_codegen's analyzer constraint must admit 13.3.0 whichever of its phase and nidana.tooling.lint.1 lands first): a conventions bullet, or an amendment of ADR-002 item 9? Chosen: route to an hsdd-adr amendment of ADR-002 item 9.
- **DEC-538** (S37, high). S37 found that ADR-002 item 4's rule (a third-party caret constraint's lower bound is the version the committed lockfile resolves when the dependency is added) produces constraints that cannot ... Chosen: Amend ADR-002 now, before codegen's plan.
- **DEC-539** (S38, high). Which rule replaces item 4's 'lower bound is the version the committed lockfile resolves when the dependency is added', so that every member's constraints resolve at every point of the build order the phase plans allow? Chosen: lower bounds from the full planned resolution, as a table in item 4.
- **DEC-599** (S42, high). Note 3: the root `fvm dart analyze` reads `build/` directories and no `.dart_tool/`. Does it change a convention? Chosen: apply as a Phase design rule for every gate.
- **DEC-600** (S42, medium). Note 4: a Flutter member's test finds the pinned `dart` at `$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart` and can drive the toolchain from it. Does it change a convention? Chosen: apply beside the ancestor-search rule.

### Taken by the orchestrator on the owner's behalf

- **DEC-001** (S00, high). How does the reference architecture enter the root hsdd-spec run: which files, with what authority? Chosen: Spec, Guide and Rationale, each with its authority.
- **DEC-002** (S00, medium, would have asked: shape). How is the run-stop condition 'two leading options change the tree's shape, the Specification is silent, no experiment settles it' read, given that the same policy lists v1 scope and decomposition ... Chosen: Both defensible, no stated reason.
- **DEC-003** (S00, high). Which prose rules bind every artifact the run writes (the owner's banned character and banned phrase)? Chosen: Owner's ban, with parser-equivalent tokens.
- **DEC-004** (S00, high). The inputs include 'HSDD's own documentation under ~/git/hsdd/docs/'. Does that cover docs/superpowers/ and the Claude memory directory? Chosen: users-guide and the methodology spec only; no memory, no docs/superpowers/.
- **DEC-005** (S01, medium). In what order do decomposition and contract authoring run? Chosen: Per level.
- **DEC-006** (S01, medium, would have asked: collision). When does hsdd-reconcile run: once after every leaf-parent is planned, or after each phase plan? Chosen: After each phase plan.
- **DEC-007** (S01, high). In what order are leaf-parents phase-planned? Chosen: Producer first (topological by contract edge).
- **DEC-008** (S01, high). Which HSDD skills does this run use? Chosen: Planning skills only: hsdd-spec, hsdd-adr, hsdd-contract, hsdd-phase-plan, hsdd-reconcile.
- **DEC-009** (S01, high). Who runs experiments, and where do they land in the commit history? Chosen: The step subagent, inside its step.
- **DEC-010** (S01, high). How are the skill's gates checked after each step? Chosen: Mechanical gate plus read-through.
- **DEC-117** (S06, high). S06 suggests an optional hsdd-adr touch that adds topic-model@v1 to ADR-003's affects, so the contract header could carry Governed by ADR-003. Run it? Chosen: Leave affects as it is.
- **DEC-141** (S07, high). S07 asks for two governance touches: add topology-dsl@v1 to ADR-003's affects (ADR-003 items 3 and 4 constrain its live guarantees G22 and G23), with ADR-001 item 4's wording 'live topology builder' ... Chosen: Batch after the last root contract.
- **DEC-186** (S09, high). bus-api@v1 needs topic-model@v1 to gain `sealed class MultiWriterTopic<T> extends Topic<T>` with EventTopic and ReplayTopic extending it, so that a publisher-less publish and a publisher's publish to ... Chosen: Amend topic-model@v1 now, compatibly.
- **DEC-187** (S09, high). bus-api@v1's two bindings call bus-testing@v1 names that do not exist yet (TestBus, TestBus.scheduler, recorder.envelopes). S09 suggests letting the bus-testing@v1 step edit bus-api's binding files ... Chosen: bus-testing@v1 adopts the names the bindings use.
- **DEC-193** (S10, high). S10 found that the MultiWriterTopic amendment changes type inference: the inferred common type of an event topic and a replay topic moves from Topic<T> to MultiWriterTopic<T>, so `final mixed = ... Chosen: Compatible; proceed.
- **DEC-234** (S12, high). S12 asks for a bus-api@v1 amendment: (a) a topology activated before start() is connected to its reads before start() delivers the queue, with cases that catch a runtime dropping a queued deep link ... Chosen: Amend bus-api@v1 now, before flutter-binding@v1, all four changes in one step.
- **DEC-246** (S13, high). S13 declared publish<T extends Object?, V extends T>(MultiWriterTopic<T>, V) instead of the publish<T, V extends T> the orchestrator named, because the named form makes a failed inference fall back ... Chosen: Same change; accept.
- **DEC-310** (S16, high). With all nine root contracts written, which accumulated follow-ups run now, before the runtime and tooling decompositions, and which wait? Chosen: ADR and contract touches now; root prose in one root refresh after stage 5.
- **DEC-320** (S17, medium). S17 went beyond the listed changes: it extended item 7 so a file contract may carry recorded invocations with expected exit codes (the item 6 option), and extended items 9 and 10 so --guarantee ... Chosen: Keep them.
- **DEC-321** (S17, high). From S09 the orchestrator stamped its own decisions (DEC-186, 187, 193, 234, 246, 310) and the S10 to S16 run lines with local time (UTC+7) labelled as UTC, about seven hours late. The ledger is ... Chosen: Publish a correction file and guard the tool.
- **DEC-329** (S18, high). ADR-003 item 8 says no nidana package calls DateTime.now(), constructs a Stopwatch directly, or creates a timer or microtask outside a provider zone; read literally it covers nidana_dart_codegen and ... Chosen: Read it as binding the governed nodes.
- **DEC-344** (S20, medium). S20 leaves three compatible follow-ups in contracts other than bus-api@v1: bus-testing@v1 G16 (envelopesOf and payloadsOf throw a TypeError on an envelope published through a widened reference), the ... Chosen: Route to the producers' phase planning as amend entries.
- **DEC-362** (S22, medium, would have asked: shape). S22 reversed root D4: nidana.runtime becomes a leaf-parent (about twelve phases over ten internal slices) instead of an internal node with children. The two leading options (leaf-parent; or two ... Chosen: Not a stop; accept the leaf-parent.
- **DEC-373** (S23, high). S23 decomposed nidana.tooling into two leaf-parents, nidana.tooling.codegen (about nine phases) and nidana.tooling.lint (about three), with nidana-checks@v1 produced by both; the alternative is one ... Chosen: Not a stop; accept two children.
- **DEC-374** (S23, high). S23 recommends two ADR touches (ADR-001 item 10 for a contract two leaf-parents produce; ADR-002's stale 'Plugin rules report at INFO severity', which nidana-checks@v1 G1 contradicts for three rules) ... Chosen: Before phase planning.
- **DEC-402** (S26, high). S26 found that navigation-api@v1's and flutter-binding@v1's behavior suites import topology_ir.dart, so nidana.navigation and nidana.flutter consume topology-ir@v1, but neither node's Consumes nor ... Chosen: Short hsdd-spec touch now.
- **DEC-429** (S28, high). S28's plan fails one item of hsdd-phase-plan's Phase Design Checklist on purpose, 'Phase 1 defines all shared types and contract-bounded interfaces': the replay tool comes first and each contract's ... Chosen: Accept the deviation.
- **DEC-430** (S28, medium, would have asked: shape). nidana.model now has 14 phases, past HSDD's 'add a level, do not widen' tip. Decompose it into children before going on, or keep it a leaf-parent? Chosen: Keep it a leaf-parent.
- **DEC-442** (S29, high). S29 lists wording follow-ups: ADR-001 item 9 ('written in its first phase', and the replay tool's command-line semantics from nidana.model D2), 'first phase' to 'first producing phase' in ADR-001 and ... Chosen: One consistency pass after stage 6.
- **DEC-471** (S31, high). While applying the G41 amend, S31 edited bus-api@v1 G8 ('neither throws except TopicCollision') so it also names G41's TypeError for an off-type value, and flagged it as a possible breaking amend. Is ... Chosen: Not a stop; keep the edit.
- **DEC-538** (S37, high). S37 found that ADR-002 item 4's rule (a third-party caret constraint's lower bound is the version the committed lockfile resolves when the dependency is added) produces constraints that cannot ... Chosen: Amend ADR-002 now, before codegen's plan.
- **DEC-603** (S43, medium). How does the run fix the stale and inexact text the stage-6 steps collected, now that every contract is stable and gate.mjs --final already passes? Chosen: Owning skill per artifact, one reconcile sweep for plan lines.
- **DEC-604** (S43, high). Does ADR-002 item 4's constraint table need an amendment to list pub_semver ^2.2.1, which nidana.tooling.codegen D3 declares? Chosen: Leave ADR-002 as is.
- **DEC-605** (S43, medium). Should the nine contracts' provenance bullet ('the first replay against the real package, once nidana.model's first phase lands the replay tool') be reworded, now that the tool lands over nidana.model.1, .2, .6 and .7? Chosen: Leave the nine bullets.
- **DEC-606** (S43, high). Should ADR-002 record that build_runner 2.16.1 dropped --delete-conflicting-outputs and silently rewrites a stale committed output (S41 note, S42 optional follow-up)? Chosen: Keep it in nidana.integration D7.

### Decisions a careful engineer would have put to the owner

- **DEC-002** (S00, medium, would have asked: shape). How is the run-stop condition 'two leading options change the tree's shape, the Specification is silent, no experiment settles it' read, given that the same policy lists v1 scope and decomposition ... Chosen: Both defensible, no stated reason.
- **DEC-006** (S01, medium, would have asked: collision). When does hsdd-reconcile run: once after every leaf-parent is planned, or after each phase plan? Chosen: After each phase plan.
- **DEC-014** (S02, medium, would have asked: shape). Does navigation (Guide Appendix B layer 4, Guide §3) ship in v1? Chosen: Navigation in v1, executor in the Flutter adapter.
- **DEC-015** (S02, high, would have asked: shape). Does persistence (Guide Appendix B layer 5) ship in v1? Chosen: Defer persistence.
- **DEC-016** (S02, high, would have asked: shape). Which Layer 7 tools ship in v1? Chosen: Guide's planned-v1 tools.
- **DEC-078** (S05, medium, would have asked: upstream, upstream). RxDart 0.28's switchMap, switching while the previous inner is live, chains on the previous inner's cancel() future, which is the SDK's root-zone null future, so its resubscription escapes the ... Chosen: Live switchMap that does not wait, synchronous operations.
- **DEC-098** (S06, medium, would have asked: upstream, upstream). Is envelope lineage computed per pipeline stage, as Spec §3.5 describes (a fresh envelope and id at every stage), or per published message? Chosen: per published message.
- **DEC-099** (S06, medium, would have asked: upstream, upstream). What is the sensitive flag of an envelope published to a topic when its inputs differ: the destination topic's flag (Spec §2.4) or the flag propagated through the pipeline (Spec §3.5)? Chosen: mirror the destination topic.
- **DEC-175** (S09, low, would have asked: axis). Spec §7.2 says the bus enforces that APPLICATION topologies activate before start(). Does a later APPLICATION activation throw? Chosen: report LateApplicationActivation in dev mode and activate.
- **DEC-204** (S11, medium, would have asked: axis). Guide C.4 lists 'capture, replay, and assertion APIs' for the TestBus envelope recorder, planned v1. Is a replay API in bus-testing@v1? Chosen: not in v1; listed under Versioning as a candidate.
- **DEC-219** (S12, high, would have asked: upstream, upstream). The Specification and the Guide name the route type Route, which package:flutter/widgets.dart also exports. Keep the name or rename it? Chosen: NavRoute.
- **DEC-221** (S12, medium, would have asked: upstream, upstream). What does each intent do to the stack (the Specification is silent; Guide §3.4 maps GoTo to go_router's location-based go)? Chosen: GoTo pushes; Replace replaces the top; Back pops; BackTo pops to the topmost entry of its route; ShowModal pushes modal; DismissModal pops a modal.
- **DEC-243** (S13, medium, would have asked: axis). After the connection, does every later delivery reach a topology's read during that delivery, so the deliveries start() makes reach a topology's reads in queue order across topics? Chosen: pin it: a connected read receives each later delivery during that delivery.
- **DEC-247** (S14, high, would have asked: axis, upstream). OQ-F1: which router do the Flutter executor and the module binding target: Flutter's own Navigator and Router APIs, or go_router as Guide §3.4 shows, and does that router become a dependency of the adapter? Chosen: Flutter Navigator, no router dependency.
- **DEC-249** (S14, medium, would have asked: axis, upstream). Which routes hold a module scope reference: every route on the Navigator's stack whose path matches, or only the visible top route? Chosen: Stack membership.
- **DEC-257** (S14, medium, would have asked: upstream, upstream). What ends the coordination domain on Flutter: the owning provider's dispose only, or also AppLifecycleState.detached? Chosen: Owning provider's dispose only.
- **DEC-258** (S14, medium, would have asked: axis). Platform routes (the initial route and routes the platform pushes): who turns them into intents? Chosen: The executor forwards them as DeepLink, on by default.
- **DEC-266** (S14, medium, would have asked: axis). Which conveniences does v1 leave out? Chosen: Leave out Router-widget integration and web URL sync, nested-Navigator executors, an event-topic listener widget, a BuildContext extension, route restoration.
- **DEC-282** (S15, medium, would have asked: external). How does the build-time topology graph page (Guide C.4) render the graph? Chosen: static HTML embedding topology-ir@v1's Mermaid rendering, Mermaid 11.12.0 loaded from jsDelivr when opened.
- **DEC-296** (S16, medium, would have asked: axis). Is a check against explicit type arguments on publish a v1 rule (S13's suggestion)? Chosen: v1 rule over four sinks.
- **DEC-297** (S16, medium, would have asked: axis). What is a known-sensitive type, and where is Spec §9.2's configurable list? Chosen: suffixes plus a Sensitive annotation on types and aliases.
- **DEC-317** (S17, medium, would have asked: axis). S15 proposed extending item 6 so a file contract can carry several input/expected cases, including cases with an expected exit code (making topic-codegen@v1's G2, G14 and G19 executable). Does this belong in v1? Chosen: item 7 gains {output} and expected/; file contracts may carry recorded invocations.
- **DEC-338** (S20, medium, would have asked: axis). Does G41 cover writes through a widened reference (Bus.publish, Publisher.publish, writer and StateWriter.publish, a topology sink), and what about the envelope's type argument and a value outside the topic's value type? Chosen: include writes of a value of the value type; leave the envelope's type argument and off-type values outside.
- **DEC-340** (S20, high, would have asked: axis). What does G20's 'returns the same handle on every call' mean once writer is reachable through a widened reference? Chosen: same handle per type argument.
- **DEC-355** (S22, medium, would have asked: shape). Break down nidana.runtime into its child nodes (capability slices within one owner's territory), cut against bus-api@v1 and bus-testing@v1: which children, of which kind, joined by which contracts ... Chosen: Leaf-parent, no children.
- **DEC-362** (S22, medium, would have asked: shape). S22 reversed root D4: nidana.runtime becomes a leaf-parent (about twelve phases over ten internal slices) instead of an internal node with children. The two leading options (leaf-parent; or two ... Chosen: Not a stop; accept the leaf-parent.
- **DEC-363** (S23, medium, would have asked: shape). Is nidana.tooling decomposed into children, and along which boundary, or is it itself a leaf-parent as S22 concluded for the runtime? Chosen: Two leaf-parent children, one per package.
- **DEC-365** (S23, medium, would have asked: upstream, upstream). OQ-T1 residual: how does a package register its topologies for catalog, and how are their constructor arguments supplied (Spec §6.5's build-time DI)? Chosen: A registration library the app writes.
- **DEC-376** (S24, medium, would have asked: shape). The general form must also say what happens to the sets item 10 runs in full (surface, reject) when a contract has several producers: item 10 justifies running them in full by 'the first phase of the ... Chosen: api and shared-model contracts have one producing leaf-parent.
- **DEC-430** (S28, medium, would have asked: shape). nidana.model now has 14 phases, past HSDD's 'add a level, do not widen' tip. Decompose it into children before going on, or keep it a leaf-parent? Chosen: Keep it a leaf-parent.
- **DEC-465** (S31, medium, would have asked: breaking-amend). The G41 amend makes getCurrentValue and getBufferedValues throw TypeError at the call for an off-type value, while G8 says 'neither throws except TopicCollision'. Is the amend still compatible, and what happens to G8? Chosen: compatible; G8 names the TypeError.

## Every decision, by blast radius


### upstream (1)

- **DEC-053** (S04, high, upstream). Does the analysis server plugin stay the static-analysis mechanism once the real single resolution is known (the proposal's rationale said that without custom_lint 'the SDK's analyzer 14.5.0 resolves')? Chosen: Analysis server plugin, no custom_lint.

### tree (44)

- **DEC-001** (S00, high). How does the reference architecture enter the root hsdd-spec run: which files, with what authority? Chosen: Spec, Guide and Rationale, each with its authority.
- **DEC-002** (S00, medium, would have asked: shape). How is the run-stop condition 'two leading options change the tree's shape, the Specification is silent, no experiment settles it' read, given that the same policy lists v1 scope and decomposition ... Chosen: Both defensible, no stated reason.
- **DEC-005** (S01, medium). In what order do decomposition and contract authoring run? Chosen: Per level.
- **DEC-006** (S01, medium, would have asked: collision). When does hsdd-reconcile run: once after every leaf-parent is planned, or after each phase plan? Chosen: After each phase plan.
- **DEC-011** (S02, high). What are the root node's id and name? Chosen: nidana.
- **DEC-012** (S02, high). hsdd-spec asks "who builds what?" Chosen: Capability slices along package boundaries.
- **DEC-014** (S02, medium, would have asked: shape). Does navigation (Guide Appendix B layer 4, Guide §3) ship in v1? Chosen: Navigation in v1, executor in the Flutter adapter.
- **DEC-015** (S02, high, would have asked: shape). Does persistence (Guide Appendix B layer 5) ship in v1? Chosen: Defer persistence.
- **DEC-016** (S02, high, would have asked: shape). Which Layer 7 tools ship in v1? Chosen: Guide's planned-v1 tools.
- **DEC-019** (S02, medium). What is the root's child set, and what kind is each child? Chosen: Six children: model, runtime, navigation, flutter, tooling, integration.
- **DEC-020** (S02, medium). Where do TestBus, the virtual scheduler and the envelope recorder live: in the runtime, or in a separate test-utilities node and package? Chosen: Inside nidana.runtime, as its testing.dart library.
- **DEC-022** (S02, high). Do the root's children need an integration node? Chosen: Add nidana.integration.
- **DEC-024** (S02, medium). What do contract and shared-model edges mean between Dart packages, where a consumer cannot compile without the producer's declarations? Chosen: Start after the producer's first phase.
- **DEC-025** (S02, medium). What does executable validation (hsdd-contract's schema or fixtures) mean for this tree's contracts, most of which are Dart API surfaces? Chosen: Compile, reject and conformance fixtures for Dart surfaces; JSON Schema for data.
- **DEC-026** (S02, medium, upstream). What package set and workspace layout does the tree use? Chosen: Pub workspace at the repository root, Guide B.2 names, runtime layers in one package.
- **DEC-027** (S02, high, upstream). Which static-analysis mechanism carries the v1 checks: custom_lint, which Spec §3.11 and Guide C.2 name, or the Dart 3.10 analysis server plugin API? Chosen: Analysis server plugin, no custom_lint in the workspace.
- **DEC-028** (S02, medium, upstream). How do Spec §3.6's SchedulerProvider and VirtualScheduler map onto Dart, where RxDart's time operators take no scheduler? Chosen: Zone plus clock provider, own VirtualScheduler.
- **DEC-033** (S02, medium). Which ordering policy does conventions.md declare? Chosen: fp-progression.
- **DEC-052** (S04, high, upstream). Does the package set and naming of the root's proposal hold on the pinned SDK (eight members under packages/, Guide B.2 names where a package keeps its layer's role, layers 2 and 3 folded into ... Chosen: Keep the proposal's package set and names.
- **DEC-054** (S04, medium). What does the root analysis_options.yaml contain beyond the proposal's excludes? Chosen: lints/recommended plus strict-casts, strict-inference, strict-raw-types.
- **DEC-055** (S04, high). ADR-001 follow-up: does the root's exclude list add hsdd/** beside ref/** and docs/**? Chosen: Exclude ref/**, docs/** and hsdd/**.
- **DEC-057** (S04, high). How do members declare dependencies on each other: hosted version constraints or path dependencies? Chosen: Hosted version constraints.
- **DEC-059** (S04, high). Where do example/ folders go: non-member packages with uncommitted lockfiles (the proposal), nested workspace members, or plain folders inside their member with no pubspec? Chosen: No pubspec: part of the member.
- **DEC-060** (S04, high). ADR-001 follow-up on the plugin mechanism: where is nidana_dart_lint enabled so that dart analyze runs its rules? Chosen: Workspace root options, added by the phase that creates the plugin.
- **DEC-066** (S04, medium). What strictness does the workspace-wide analyze hold? Chosen: Clean under fvm dart analyze --fatal-infos at the root.
- **DEC-090** (S05, medium). Which nodes and contracts does ADR-003 affect (the proposal listed nidana.runtime, nidana.navigation, nidana.flutter, nidana.integration, bus-api@v1, bus-testing@v1)? Chosen: Proposal's set plus nidana.model, navigation-api@v1, flutter-binding@v1.
- **DEC-355** (S22, medium, would have asked: shape). Break down nidana.runtime into its child nodes (capability slices within one owner's territory), cut against bus-api@v1 and bus-testing@v1: which children, of which kind, joined by which contracts ... Chosen: Leaf-parent, no children.
- **DEC-362** (S22, medium, would have asked: shape). S22 reversed root D4: nidana.runtime becomes a leaf-parent (about twelve phases over ten internal slices) instead of an internal node with children. The two leading options (leaf-parent; or two ... Chosen: Not a stop; accept the leaf-parent.
- **DEC-363** (S23, medium, would have asked: shape). Is nidana.tooling decomposed into children, and along which boundary, or is it itself a leaf-parent as S22 concluded for the runtime? Chosen: Two leaf-parent children, one per package.
- **DEC-370** (S23, high). Do the children consume bus-testing@v1, navigation-api@v1 and flutter-binding@v1, whose declarations the checks recognize by name and whose packages the recorded invocations import? Chosen: Consume them as contract edges.
- **DEC-373** (S23, high). S23 decomposed nidana.tooling into two leaf-parents, nidana.tooling.codegen (about nine phases) and nidana.tooling.lint (about three), with nidana-checks@v1 produced by both; the alternative is one ... Chosen: Not a stop; accept two children.
- **DEC-376** (S24, medium, would have asked: shape). The general form must also say what happens to the sets item 10 runs in full (surface, reject) when a contract has several producers: item 10 justifies running them in full by 'the first phase of the ... Chosen: api and shared-model contracts have one producing leaf-parent.
- **DEC-402** (S26, high). S26 found that navigation-api@v1's and flutter-binding@v1's behavior suites import topology_ir.dart, so nidana.navigation and nidana.flutter consume topology-ir@v1, but neither node's Consumes nor ... Chosen: Short hsdd-spec touch now.
- **DEC-430** (S28, medium, would have asked: shape). nidana.model now has 14 phases, past HSDD's 'add a level, do not widen' tip. Decompose it into children before going on, or keep it a leaf-parent? Chosen: Keep it a leaf-parent.
- **DEC-436** (S29, medium). note 1 (root pubspec.yaml workspace list and pubspec.lock shared by every member-creating phase; proposed: list in path order, one member per line): does it change a convention, and where does it land? Chosen: conventions, Execution protocol.
- **DEC-437** (S29, medium). note 2 (the replay tool's sets land in nidana.model.1, .2, .6 and .7, which adds non-contract waits for other nodes' gates): does it change a convention? Chosen: conventions, Phase design.
- **DEC-438** (S29, high). note 3 (the conventions' 'Phase 1 of a leaf-parent is the type-level skeleton' holds for nidana.model only as a band; proposed text 'the type-level band, which opens the plan after any gate ... Chosen: rewrite the fp-progression paragraph.
- **DEC-439** (S29, medium). Should the Delivery paragraph this pass wrote become a convention for every later reconcile, so the steps that drain nidana.runtime's and the other plans do the same? Chosen: state it under Contracts.
- **DEC-511** (S35, high). Note 2 (a Flutter member's tests run from the root as fvm flutter test --no-pub packages/{member}; under flutter test Isolate.resolvePackageUri throws, so a test that reads its own sources finds the ... Chosen: add a Phase design bullet.
- **DEC-537** (S37, medium). Note 4 (nidana_dart_codegen's analyzer constraint must admit 13.3.0 whichever of its phase and nidana.tooling.lint.1 lands first): a conventions bullet, or an amendment of ADR-002 item 9? Chosen: route to an hsdd-adr amendment of ADR-002 item 9.
- **DEC-538** (S37, high). S37 found that ADR-002 item 4's rule (a third-party caret constraint's lower bound is the version the committed lockfile resolves when the dependency is added) produces constraints that cannot ... Chosen: Amend ADR-002 now, before codegen's plan.
- **DEC-539** (S38, high). Which rule replaces item 4's 'lower bound is the version the committed lockfile resolves when the dependency is added', so that every member's constraints resolve at every point of the build order the phase plans allow? Chosen: lower bounds from the full planned resolution, as a table in item 4.
- **DEC-599** (S42, high). Note 3: the root `fvm dart analyze` reads `build/` directories and no `.dart_tool/`. Does it change a convention? Chosen: apply as a Phase design rule for every gate.
- **DEC-600** (S42, medium). Note 4: a Flutter member's test finds the pinned `dart` at `$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart` and can drive the toolchain from it. Does it change a convention? Chosen: apply beside the ancestor-search rule.

### contract (366)

- **DEC-013** (S02, medium). Who are the package consumers? Chosen: App teams, their CI, pure Dart modules and the tree itself.
- **DEC-021** (S02, medium). Does the contracts package hold only data types, or also the DSL interface, the recording builder and the IR analyses? Chosen: Contracts package holds DSL interface, recorder and pure analyses.
- **DEC-023** (S02, medium). Which contracts sit on the root's edges? Chosen: Nine contracts.
- **DEC-029** (S02, high, upstream). Guide §6.3's Dart example composes topology bodies with RxDart's Streams.combineLatest2 on read handles. Does the Dart DSL allow that? Chosen: Wrap every combinator in the model's DSL.
- **DEC-030** (S02, medium, upstream). Where do the navigation types (NavIntent, RouteState, NavigationTopics) live: in the contracts package as Guide B.1 lists them, or in the navigation package? Chosen: Navigation package, with the Flutter adapter depending on it.
- **DEC-031** (S02, medium). What is dev mode on Dart, where do dev-mode diagnostics go, and is that an ADR? Chosen: BusConfig dev mode and typed diagnostics, carried by bus-api@v1.
- **DEC-037** (S02, medium). What kind is topology-ir@v1, whose content is Dart types and analysis functions plus a JSON form? Chosen: api with a serialized form.
- **DEC-038** (S03, high). Materialize ADR-001 as accepted, or as proposed with the Decision left as a TODO? Chosen: accepted.
- **DEC-040** (S03, high). Fixtures live under hsdd/ at the workspace root, belong to the root package, and reject fixtures hold deliberate errors. How are they kept out of workspace-wide analysis, and which analysis options apply to them? Chosen: root excludes hsdd/**, fixture-local options with no lints and strict modes.
- **DEC-041** (S03, high). How does a reject fixture name its expected diagnostic, and when does it pass? Chosen: line-anchored marker, exact match at every severity.
- **DEC-042** (S03, high). What shape does a behavior fixture take so one suite validates implementations that need different test runners (VM and widget tree)? Chosen: cases as values plus per-implementation bindings.
- **DEC-043** (S03, medium). Where do bindings live, who writes them, how are they named, and how are they bound before the producing package exists? Chosen: in the fixture directory of the contract that declares the implementation, written by hsdd-contract.
- **DEC-044** (S03, high). What does the replay do with a binding whose implementing package does not exist yet? Chosen: fail, reported as PENDING.
- **DEC-045** (S03, high). How does the replay choose the test runner for a binding, and from which directory does it run? Chosen: by import, from the workspace root, pinned SDK.
- **DEC-046** (S03, high). How is the replay tool invoked from a gate? Chosen: one CLI: fvm dart run nidana_contract_check {slug}... [--set] [--guarantee] or --all.
- **DEC-047** (S03, medium). Which fixture sets does an intermediate producing phase's gate run, when later phases deliver the remaining behavior? Chosen: type-level sets in full, behavior restricted cumulatively, unrestricted at the last producing phase.
- **DEC-048** (S03, medium). What must an api or shared-model fixture set minimally contain to count as the executable validation artifact at hsdd-reconcile's draft to stable flip, given that reconcile itself only checks that the path exists? Chosen: guarantee ids with full coverage.
- **DEC-049** (S03, high). Which schema dialect and validator, and how does the producer's gate check its real output against the schema? Chosen: draft 2020-12 via package:json_schema; producer side as behavior cases.
- **DEC-050** (S03, medium). What exact protocol do file and cli replays follow? Chosen: generator command with placeholders; invocation directories with path normalization.
- **DEC-061** (S04, medium, upstream). The analysis server resolves a plugin in its own synthetic package outside the workspace, where a hosted constraint on an unpublished sibling fails. Where do the workspace scan and the checks that ... Chosen: Command entry of nidana_dart_codegen; nidana_dart_lint depends on no nidana package.
- **DEC-063** (S04, high). ADR-001 follow-up: does the codegen's command entry that runs outside build_runner (the file replay of topic-codegen@v1) belong in this ADR or in the codegen contract? Chosen: Package shape here, command interface in the contract.
- **DEC-065** (S04, medium). May a published member list test or flutter_test under dependencies (for example the Flutter adapter's widget-test helpers taking a WidgetTester)? Chosen: Neither test nor flutter_test in a published member's dependencies; matcher allowed.
- **DEC-070** (S04, high). Does the ADR fix library naming inside members, which contract fixtures import by package URI? Chosen: Main library lib/{name}.dart; other public libraries named by their contract; the rest under lib/src/.
- **DEC-071** (S04, high). Which ids does affects name: the seven nodes of the proposal only, or also the nine contracts? Chosen: Seven nodes and all nine contracts.
- **DEC-074** (S05, high). Should the production provider fork Zone.current at bus construction, as the root proposed, or capture Zone.current as it is? Chosen: Capture Zone.current without forking.
- **DEC-075** (S05, high). Does the production provider read package:clock's clock at each call, or capture it when the bus is constructed? Chosen: Capture clock at bus construction.
- **DEC-076** (S05, high). Does bus.observe(topic) subscribe inside the provider zone, or return the subject's stream so subscribers keep their own zone (the proposal's item 6: a test's own subscription gets its replay only after a real turn)? Chosen: listen re-enters the provider zone.
- **DEC-077** (S05, high). In which zone does the bus invoke observers (Spec §3.7) and create its own timers and microtasks (reentrancy deferral, dev-mode window, grace timer)? Chosen: Explicitly in the provider zone.
- **DEC-078** (S05, medium, would have asked: upstream, upstream). RxDart 0.28's switchMap, switching while the previous inner is live, chains on the previous inner's cancel() future, which is the SDK's root-zone null future, so its resubscription escapes the ... Chosen: Live switchMap that does not wait, synchronous operations.
- **DEC-079** (S05, high). Do the topology DSL's time-dependent combinators stay RxDart's operators (proposal item 4), now that periodic operators and cancellation are tested? Chosen: RxDart operators inside the pipeline, no scheduler argument.
- **DEC-080** (S05, high). Is VirtualScheduler nidana's own implementation, or a wrapper over package:fake_async, and does any nidana package depend on fake_async? Chosen: Own implementation, no fake_async dependency.
- **DEC-081** (S05, high). What do triggerActions, advanceTimeBy and advanceTimeTo do with microtasks (replay, Spec §3.4 deferral) and periodic timers, and how does a test observe quiescence? Chosen: Event-loop order, monotonic time, bounded, quiescent on return.
- **DEC-082** (S05, high). Is the virtual clock also package:clock's clock inside the virtual zone? Chosen: Yes, fork the zone under withClock(virtualClock).
- **DEC-083** (S05, high). How does a TestBus test handle work that starts outside the provider zone (a stub future the test completes, RxDart operators an app chains), and what is the settle() of an ADR-001 harness over a TestBus? Chosen: bus-testing@v1 adds an asynchronous settle.
- **DEC-084** (S05, medium). Which provider may a TestBus have, and can widget tests record envelopes? Chosen: TestBus is always virtual; the recorder attaches to any bus.
- **DEC-085** (S05, high, upstream). How do Flutter widget tests construct and shut down the bus, given that flutter_test fails a test whose fake timers are still pending after it unmounts the tree? Chosen: Build in the body, shut down from an ancestor's dispose.
- **DEC-086** (S05, high). What does a zero grace period do, and what does shutdown do with timers? Chosen: Zero grace tears down synchronously; shutdown cancels every timer.
- **DEC-087** (S05, medium). Is the set of scheduler providers closed (production and virtual), or may applications implement SchedulerProvider? Chosen: Closed set of two.
- **DEC-088** (S05, high). How does shell code outside the runtime (navigation executors stamping RouteTransition, the telemetry observer) get the bus's time without DateTime.now()? Chosen: bus-api@v1 exposes the provider clock read-only.
- **DEC-092** (S06, high). Which of nidana.model's declarations belong to topic-model@v1, and which to topology-dsl@v1 and topology-ir@v1? Chosen: shared values here, API and IR elsewhere.
- **DEC-093** (S06, medium). Does topic-model@v1 get a public library of its own, or does it live in the package's main library? Chosen: main library only.
- **DEC-096** (S06, high). OQ-M3: does the Dart topic model carry Spec §3.6's per-topic dispatcher hint at all? Chosen: omit the field.
- **DEC-097** (S06, medium). Is MessageEnvelope.source a String, as Spec §2.4 shows it, or a typed value? Chosen: sealed MessageSource.
- **DEC-098** (S06, medium, would have asked: upstream, upstream). Is envelope lineage computed per pipeline stage, as Spec §3.5 describes (a fresh envelope and id at every stage), or per published message? Chosen: per published message.
- **DEC-099** (S06, medium, would have asked: upstream, upstream). What is the sensitive flag of an envelope published to a topic when its inputs differ: the destination topic's flag (Spec §2.4) or the flag propagated through the pipeline (Spec §3.5)? Chosen: mirror the destination topic.
- **DEC-100** (S06, medium). How does a value read from a Tracing.disabled topic enter lineage? Chosen: lineage-neutral root without a correlation.
- **DEC-101** (S06, medium). How do the pure lineage functions obtain a fresh correlation id, given that nidana_dart_contracts generates no id (ADR-003 item 8)? Chosen: a String Function() argument.
- **DEC-102** (S06, medium). When inputs of a combine share one correlation id, which parent correlation ids does the output carry? Chosen: union in input order.
- **DEC-103** (S06, medium). What makes two topics equal? Chosen: variant, name and value type.
- **DEC-104** (S06, high). How does a StateTopic declare a constant or a computed initial value in Dart? Chosen: two const constructors and createInitial().
- **DEC-105** (S06, medium). What does the topic name predicate accept, and do constructors validate names? Chosen: two or three kebab segments, no constructor check.
- **DEC-106** (S06, high). Is a replay topic's buffer size required and bounded below? Chosen: required bufferSize, asserted at least 1.
- **DEC-107** (S06, high). Does Dedup offer a custom equality in v1? Chosen: enum of equality and none.
- **DEC-108** (S06, high). Which constructor arguments of MessageEnvelope are required? Chosen: all but causationId and parents.
- **DEC-109** (S06, medium). How is a sensitive payload redacted, and does an envelope's toString redact it? Chosen: runtime type and 32-bit hashCode, redacted toString.
- **DEC-110** (S06, medium). What does the observer seam's span API offer, given that root D1 puts an SDK-neutral telemetry observer implementing Guide §8.2's mapping in v1? Chosen: links by message id at span creation.
- **DEC-111** (S06, medium). What does an observer holding only observeSensitive receive? Chosen: sensitive envelopes only.
- **DEC-112** (S06, medium). Does Guide §4.1's AppError become a library type in topic-model@v1? Chosen: leave it to applications.
- **DEC-113** (S06, high). kind and compatibility of topic-model@v1 Chosen: shared-model, versioned.
- **DEC-115** (S06, high). Write hsdd/contract/fixture/analysis_options.yaml as the first contract step? Chosen: write it exactly as ADR-001 item 2 states.
- **DEC-116** (S06, high). Does topic-model@v1 carry a JSON Schema? Chosen: no schema.
- **DEC-118** (S07, high). Which signature makes writing a handle of the wrong value type to a topic a compile error (Spec §4.2), given that Dart generics are covariant and inference solves a type argument two arguments ... Chosen: write<T, S extends T>(Topic<T>, TopicStream<S>).
- **DEC-119** (S07, high). How do the recording and the live implementations of the DSL relate: two implementations of a builder interface, or one recording builder whose plan a live implementation interprets? Chosen: one recording builder, plan interpreted live.
- **DEC-120** (S07, high). OQ-M2: How does live activation obtain the transformers a pure-data IR names? Chosen: one plan, IR projected from it.
- **DEC-121** (S07, medium). OQ-M1, DSL side: does every combinator take an explicit transformer name? Chosen: no name parameter; the plan keeps the function.
- **DEC-122** (S07, high, upstream). What is the Dart surface of a topology and its combinators: builder functions only, or methods on the handle, and how closed are the types? Chosen: Spec and Guide split.
- **DEC-123** (S07, medium, upstream). Which combinators does the v1 DSL provide beyond the Spec §6.3 table, and how are the Spec's error operators (retryWhen, catchError, onErrorResumeNext) realized on Dart? Chosen: curated: table, merge, timeout, catchError, retry on switchMap.
- **DEC-124** (S07, medium, upstream). Does the DSL provide a switch that selects among topic pipelines (Spec §6.1 and §7.1 'switchMap ... to select between pipelines'), beside switchMap over a shell stream factory? Chosen: no selecting switch.
- **DEC-125** (S07, medium). What does an unhandled error in a live pipeline do on Dart, where a stream error does not end the stream? Chosen: the sink it reaches ends.
- **DEC-126** (S07, high). Is a stage evaluated once for all its consumers, or once per consumer, in a live activation? Chosen: shared within an activation.
- **DEC-127** (S07, medium). Which sinks does Spec §3.3's fan-out order cover? Chosen: sinks that take the same handle.
- **DEC-128** (S07, medium). What does recording do with a stage that reaches no sink? Chosen: reject the declaration.
- **DEC-129** (S07, high). Where does the plan library live? Chosen: a second public library, topology_plan.dart.
- **DEC-130** (S07, high). Is ADR-003 item 3's live switchMap property (cancel the previous inner without waiting, listen to the next at once) a guarantee of topology-dsl@v1 or of bus-api@v1? Chosen: topology-dsl@v1.
- **DEC-131** (S07, high). What do the time-dependent combinators emit, given that ADR-003 item 4 makes them RxDart 0.28's operators or Stream.timeout? Chosen: those semantics, with buffer never emitting an empty batch.
- **DEC-132** (S07, medium). What lineage does a value carry that catchError produces from an error, and that a read delivers for a state topic's declared initial value? Chosen: the lineage the raising stage would have passed.
- **DEC-133** (S07, medium). Which stages mediate an intra-topology self-reference (Spec §3.8) for topology-ir@v1's analysis? Chosen: scan, reduceInto, and debounce, delay, sample and buffer with a positive duration.
- **DEC-134** (S07, high, upstream). What does the raw-engine escape hatch hand the author: envelopes or pipeline values? Chosen: Stream<PipelineValue<T>> with a fresh-correlation source.
- **DEC-135** (S07, medium). OQ-R3 (nidana.runtime), DSL side: what does a read deliver under the per-read dedup opt-out, and does this contract fix where dedup sits? Chosen: read semantics only.
- **DEC-136** (S07, high). How are the conformance cases organized so that both the recording and the live implementation can be bound, without this contract naming bus types? Chosen: two libraries, two harnesses.
- **DEC-142** (S08, high, upstream). How does TransformEdge represent a pipeline of several stages, a write and a reduceInto, when Spec §6.5 sketches an edge with topic references at both ends? Chosen: Edges over topic or stage inputs, sinks as edges.
- **DEC-143** (S08, high). OQ-M1: How does the recorder name a transformer (FunctionRef) in Dart? Chosen: Derive from toString, VM pattern only.
- **DEC-144** (S08, high, upstream). Does the IR carry the durations of debounce, delay, sample and buffer, or does the self-reference analysis treat them as not mediating? Chosen: Carry durations.
- **DEC-145** (S08, medium). Which public library carries the IR, the graphs, the renderers, the JSON codec and the analyses? Chosen: Value types in the main library, the rest in topology_ir.dart.
- **DEC-146** (S08, high). Does a definition take reads and writes as arguments, or derive them from its edges? Chosen: Derive them.
- **DEC-147** (S08, high). How does a shell publisher's claim and its scope enter the scope-compatibility and single-writer analyses without this contract naming a bus type? Chosen: ShellClaim values inside TopologyGraph.
- **DEC-148** (S08, medium). What does a graph do with two definitions of one topologyId, and with two equal claims? Chosen: Collapse equal definitions, reject unequal ones, keep equal claims.
- **DEC-149** (S08, high). What shape do the analyses take: what they consume, what they return, and which checks are here? Chosen: One function per analysis over TopologyGraph, typed findings in a sealed family, plus analyzeTopologyGraph.
- **DEC-150** (S08, medium, upstream). What exactly is an unmediated self-read, and what does a SelfReference finding report? Chosen: Paths of non-state-bearing edges from a read to a write of the topic, every edge on them reported.
- **DEC-151** (S08, high). What counts as a topic name collision (Spec §4.3)? Chosen: Any two distinct declarations of one name.
- **DEC-152** (S08, high). Are the JSON form of a single definition and the aggregated topology-graph.json one schema or two? Chosen: One schema, one document type.
- **DEC-153** (S08, medium). Who emits the aggregated topology-graph.json, and through which contract? Chosen: nidana.tooling through topic-codegen@v1.
- **DEC-154** (S08, medium). Is the JSON form closed or open to unknown keys, and how strict is the decoder about order? Chosen: Closed schema with a format string, canonical encoder, order-lenient decoder.
- **DEC-155** (S08, medium). How precisely does the contract fix the Mermaid and Graphviz renderings? Chosen: Exact rules pinned by goldens.
- **DEC-156** (S08, medium). What is the signature of expectMatchesSchema, which ADR-001 item 4 names but does not type, and how do conformance cases find the schema and the valid/, invalid/ and render/ files? Chosen: expectMatchesSchema(Object? instance, String schemaPath), paths relative to the workspace root found by walking up.
- **DEC-158** (S09, high, upstream). OQ-R1: do the bus's subjects keep RxDart's microtask-delayed first delivery for state and replay topics, or wrap subjects so a new subscriber receives the current value synchronously? Chosen: keep the microtask-delayed first delivery.
- **DEC-159** (S09, medium, upstream). OQ-R3: where does StateTopic dedup sit, given the per-read opt-out of Spec §3.12, and does an observer see a publish that dedup suppressed? Chosen: dedup per read; observers and the current value see every publish.
- **DEC-160** (S09, medium). How does the Interface make a publisher-less publish, and a publisher's publish, unable to reach a StateTopic, as Spec §2.4 requires? Chosen: amend topic-model@v1 with a sealed MultiWriterTopic<T> above EventTopic<T> and ReplayTopic<T>, and take it in publish.
- **DEC-161** (S09, high). Where is the boundary between bus-api@v1 and bus-testing@v1, given ADR-003's closed set of two providers and a TestBus that is a bus? Chosen: main library to bus-api, testing.dart to bus-testing, with SchedulerProvider sealed across both and Bus final with TestBus as its one subtype, declared in one src library.
- **DEC-162** (S09, medium). Is Bus an implementable interface (stand-ins, mocks) or a final class? Chosen: final class, TestBus its only subtype.
- **DEC-163** (S09, high). How are dev-mode diagnostics typed so that other nidana packages can report through the bus's sink (root D8)? Chosen: sealed BusDiagnostic with final runtime variants plus a base ShellDiagnostic other packages extend, delivered through reportDiagnostic.
- **DEC-164** (S09, high). What do the throws the Specification requires look like on Dart? Chosen: a sealed BusError family (ActivationRejected, ClaimRejected, TopologyConflict, TopicCollision, BusLimitExceeded) carrying findings, plus SDK ArgumentError and StateError for misuse.
- **DEC-165** (S09, medium). How is reentrant publish normalization realized: which publishes are reentrant, and how are deferred publishes ordered? Chosen: a publish made during a delivery joins one per-bus FIFO drained by one provider-zone microtask, including the publishes the drain itself causes; timer-driven publishes are not reentrant.
- **DEC-166** (S09, high, upstream). What does the startup barrier hold back: only shell publishers' publishes, as Spec §3.13 words it, or every publish? Chosen: every publish, a topology's and a publisher-less one included; the connection and observed first values are not publishes and are not held.
- **DEC-167** (S09, medium, upstream). Spec §3.9: when is a second activation under the same topologyId 'the same declaration', given that definitions do not see a scan seed, closure bodies or two functions with one name? Chosen: equal topology-ir@v1 definitions are the same declaration; declare runs once more for the check.
- **DEC-168** (S09, medium, upstream). Spec §4.3's runtime name check throws on 'a different type'. Does a second declaration of the same name and type that differs in its sensitive flag, tracing, dedup or buffer size collide? Chosen: collide on variant, value type, sensitive, tracing, dedup or buffer size.
- **DEC-169** (S09, medium, upstream). How do maxTopics (Spec §11.3, 'activate fails if exceeded') and getCurrentValue's 'never throws' (Spec §2.5) combine? Chosen: activation over the limit throws BusLimitExceeded; any other access over it creates the subject and reports TopicLimitExceeded in dev mode.
- **DEC-170** (S09, medium). Does a shell publish carry causation, as Spec §2.4's PaymentResult example suggests, or is it always a root message? Chosen: always a root message: fresh correlation, no causation.
- **DEC-171** (S09, medium). What does Tracing.disabled do on this bus? Chosen: its envelopes reach no observer and a pipeline reading it starts a new flow; the envelopes still carry generated metadata.
- **DEC-172** (S09, medium). What shape does the module scope API that UI adapters bind route events to take (Spec §7.3)? Chosen: bus.module(id, topologies, gracePeriod) returning one ModuleScope per id; acquire() returns a ModuleReference token whose release counts once.
- **DEC-173** (S09, medium). Spec §2.4: 'a publisher bound to a module or page scope releases it with that scope'. Does bus-api@v1 bind publishers to module scopes? Chosen: no: scope is declared on the publisher for the analyses, and the caller disposes it when it releases the module or the page unmounts.
- **DEC-174** (S09, medium). Is the SDK-neutral telemetry observer (root D1) part of bus-api@v1, and how does it see activations when BusObserver has only onPublish? Chosen: TelemetryObserver in the main library, plus an ActivationObserver interface the bus also notifies.
- **DEC-175** (S09, low, would have asked: axis). Spec §7.2 says the bus enforces that APPLICATION topologies activate before start(). Does a later APPLICATION activation throw? Chosen: report LateApplicationActivation in dev mode and activate.
- **DEC-176** (S09, medium). What happens to a publish that is queued (before start, or reentrant) when its publisher is disposed or its topology deactivated? Chosen: discard it.
- **DEC-177** (S09, medium). ADR-003 left open whether shutdown() drains the virtual queue first. What does shutdown do with pending work? Chosen: deliver the bus's own pending reentrant publishes synchronously, discard the startup queue, run nothing else of the provider zone.
- **DEC-178** (S09, high). ADR-003 left open whether a TestBus generates deterministic envelope ids. What does bus-api@v1 say? Chosen: ids and correlation ids are opaque and pairwise distinct; whether a TestBus makes them deterministic is bus-testing@v1's.
- **DEC-179** (S09, high). How does the bus-api conformance harness let a case drive time without naming bus-testing@v1 types? Chosen: BusApiHarness with bus(config), flush, advance, pendingTimers and settle, all in bus-api and SDK types; production-provider capture tested by constructing a Bus inside a TestBus delivery.
- **DEC-180** (S09, medium). How does the binding of topology-dsl@v1's live suite implement LiveRun.watch, which must return envelopes, including those of a Tracing.disabled topic? Chosen: a view of the TestBus's envelope recorder from the watch on, filtered to the topic and read with its own dedup.
- **DEC-181** (S09, high). Forced removal and shutdown must end observed subscriptions with done; a closed RxDart BehaviorSubject delivers done from a microtask the virtual scheduler does not run. What does the contract guarantee? Chosen: the bus ends every observed subscription itself, with done delivered before removeTopic or shutdown returns.
- **DEC-183** (S09, medium). Dev-mode recursion detection (Spec §3.4): what happens past maxReentrancyDepth? Chosen: report ReentrancyDepthExceeded once per chain, at the hop that crosses the threshold, and keep delivering.
- **DEC-184** (S09, medium). Where do observers' log, metric and span calls go? Chosen: one ObserveContext per bus in BusConfig, defaulting to a context whose log prints and whose metric and span discard.
- **DEC-185** (S09, medium). Does the runtime's main library re-export nidana_dart_contracts? Chosen: no; shell code imports both.
- **DEC-186** (S09, high). bus-api@v1 needs topic-model@v1 to gain `sealed class MultiWriterTopic<T> extends Topic<T>` with EventTopic and ReplayTopic extending it, so that a publisher-less publish and a publisher's publish to ... Chosen: Amend topic-model@v1 now, compatibly.
- **DEC-187** (S09, high). bus-api@v1's two bindings call bus-testing@v1 names that do not exist yet (TestBus, TestBus.scheduler, recorder.envelopes). S09 suggests letting the bus-testing@v1 step edit bus-api's binding files ... Chosen: bus-testing@v1 adopts the names the bindings use.
- **DEC-188** (S10, high). Is adding sealed MultiWriterTopic<T> between Topic<T> and EventTopic<T>/ReplayTopic<T> a compatible amendment of topic-model@v1, or a breaking one that needs v2 (and so a run stop)? Chosen: amend v1 compatibly.
- **DEC-189** (S10, high). Which guarantee carries which part of the MultiWriterTopic rule? Chosen: extend G1, add G27 for assignability.
- **DEC-191** (S10, medium). Fold in S07's note: state the lineage a state topic's initial value carries when it is first observed or read? Chosen: add it now as Lineage.root() with defaults.
- **DEC-192** (S10, high). How does ## Versioning record the amendment? Chosen: amendment line plus a new Compatible class.
- **DEC-193** (S10, high). S10 found that the MultiWriterTopic amendment changes type inference: the inferred common type of an event topic and a replay topic moves from Topic<T> to MultiWriterTopic<T>, so `final mixed = ... Chosen: Compatible; proceed.
- **DEC-194** (S11, medium). OQ-R2, first half (Guide §10.1 'Envelope recording'): what is the envelope recorder's assertion API: pattern matching, equality, custom predicates? Chosen: typed queries returning plain values.
- **DEC-195** (S11, medium). OQ-R2, second half (Guide §10.1 'Topology test isolation'): how does a test activate only the topologies under test without the APPLICATION set? Chosen: TestBus activates nothing; input and stub helpers stand in for absent producers.
- **DEC-196** (S11, high). Spec §9.2 item 2: the TestBus envelope recorder defaults to redacting sensitive payloads, raw view by explicit opt-in. Where does the opt-in live, given that bus-api@v1's bindings read ... Chosen: per read: RecordedEnvelope.unredacted and an unredacted: true argument on the typed queries.
- **DEC-197** (S11, high). Does a TestBus generate deterministic envelope ids (bus-api@v1 says only that ids are opaque and pairwise distinct)? Chosen: deterministic with a fixed format: e1, e2, ... and c1, c2, ... per TestBus.
- **DEC-198** (S11, high). ADR-003 item 5 leaves the default start instant of the virtual clock to this contract. Which instant? Chosen: 2000-01-01T00:00:00.000Z, overridable by initialTime.
- **DEC-199** (S11, medium). ADR-003 items 5 and 6 leave the action bound and the settle bound to this contract. Which defaults, and where are they set? Chosen: constructor parameters maxActions = 100000 per operation and maxSettleTurns = 20 per settle.
- **DEC-200** (S11, high). ADR-003 item 5: the scheduler 'reports how many are pending and when the next one is due'. What introspection does VirtualScheduler expose? Chosen: pendingTimerCount, nextTimerDue and pendingMicrotaskCount.
- **DEC-201** (S11, high). ADR-003 item 6: the envelope recorder attaches to a bus with either provider. How does it attach to a production-provider bus, given that Bus is bus-api@v1's final class? Chosen: EnvelopeRecorder.attach(bus): a delivery seam of every bus, called before the observers.
- **DEC-202** (S11, medium). Guide §6.5: the per-topic ordering regression test is mandatory and 'the test harness in nidana-test-utils provides it'. Does this contract expose a reusable harness, and where does the test run? Chosen: OrderingProbe in testing.dart, plus the runtime's own cases.
- **DEC-203** (S11, high). How does the settle operation behave at its edges: where does it live, when does it fail, and what happens when it is called inside the scheduler's zone? Chosen: on VirtualScheduler; StateError at the call inside the zone; the future fails after maxSettleTurns real turns.
- **DEC-204** (S11, medium, would have asked: axis). Guide C.4 lists 'capture, replay, and assertion APIs' for the TestBus envelope recorder, planned v1. Is a replay API in bus-testing@v1? Chosen: not in v1; listed under Versioning as a candidate.
- **DEC-205** (S11, medium). Does VirtualScheduler expose its zone, given that bus-api@v1 lists 'access to the provider zone' as not in v1 for Bus? Chosen: run(body): runs a body inside the zone and returns its result.
- **DEC-206** (S11, medium). Does testing.dart re-export the main library or nidana_dart_contracts? Chosen: no re-export: testing.dart exports its six declarations only.
- **DEC-207** (S11, high). Are the recorder's lists live views or snapshots? Chosen: unmodifiable snapshots taken at the call.
- **DEC-208** (S11, high). What does a plain Bus do with a VirtualSchedulerProvider, which bus-api@v1's constructor text does not mention? Chosen: it runs on that scheduler, TestBus or not; only a TestBus adds the recorder, input, stub and deterministic ids.
- **DEC-209** (S11, high). bus-api@v1 G38 says nidana_dart_runtime creates no timer or microtask outside a provider zone, while ADR-003 item 6 requires the settle operation to alternate with real event-loop turns. How is the conflict handled? Chosen: state the exception here (G12, G20) and ask for a compatible clarification of bus-api@v1 G38.
- **DEC-211** (S11, high). Does VirtualSchedulerProvider take its scheduler as a required argument or create one when none is given? Chosen: required positional argument, as Spec §3.6 writes VirtualSchedulerProvider(virtualScheduler).
- **DEC-212** (S12, high). OQ-N2: Do routes carry typed arguments (Route<Args>) or untyped maps? Chosen: typed NavRoute<A>, arguments optional A?.
- **DEC-213** (S12, high). How are GoTo, Replace and ShowModal built so that their arguments are checked against the route? Chosen: built only by route methods (route.go(args)), no public constructor.
- **DEC-214** (S12, medium). OQ-N1: How does the library's resolver template bind to an app's own auth state type, which Guide §3.4's resolver reads directly? Chosen: generic template over the app's auth StateTopic<S> with a pure projection to a library AccessPrincipal.
- **DEC-215** (S12, medium). What does the guard do while the app's auth state is still initializing at a cold-start deep link? Chosen: a PendingPrincipal variant with its own redirect, defaulting to the unauthenticated one.
- **DEC-216** (S12, medium). Where does a refused intent go, given that a library guard cannot name the app's login and unauthorized routes (Guide §3.4 hardcodes AuthRoutes.login with a returnTo map)? Chosen: AccessRedirects: app-provided pure functions from the attempted intent to the intent to perform.
- **DEC-217** (S12, high, upstream). In which order does the resolver guard and resolve deep links? Chosen: resolve first, then guard the resolved intent.
- **DEC-218** (S12, high). How is ResolvedNavIntent declared so that a deep link is impossible by construction? Chosen: a sealed subfamily of NavIntent: NavIntent = DeepLink | ResolvedNavIntent.
- **DEC-219** (S12, high, would have asked: upstream, upstream). The Specification and the Guide name the route type Route, which package:flutter/widgets.dart also exports. Keep the name or rename it? Chosen: NavRoute.
- **DEC-220** (S12, high). What does the executor protocol consist of, and what does a platform implement? Chosen: a final NavigationExecutor in this package over a NavigationRouter port the platform implements.
- **DEC-221** (S12, medium, would have asked: upstream, upstream). What does each intent do to the stack (the Specification is silent; Guide §3.4 maps GoTo to go_router's location-based go)? Chosen: GoTo pushes; Replace replaces the top; Back pops; BackTo pops to the topmost entry of its route; ShowModal pushes modal; DismissModal pops a modal.
- **DEC-222** (S12, medium). What does the executor do with an intent the stack does not admit (Back at the root, BackTo a route not on the stack, DismissModal with no modal on top)? Chosen: refuse: nothing navigates or is written; dev mode reports NavigationRefused.
- **DEC-223** (S12, high). How does a router report transitions, and how many history entries does a synthesized BackTo produce? Chosen: one perform per intent, validated before acting, confirmed once with the stack it left and the intent; platform transitions confirmed with const Back().
- **DEC-224** (S12, medium). Does the executor write the router's initial route at construction, and does it report a construction after start()? Chosen: write the initial top to nav.current-route (no history entry) and report LateExecutorConstruction in dev mode.
- **DEC-225** (S12, high). Whether this contract declares the in-memory router publicly, and where its binding lives. Chosen: public InMemoryRouter in package:nidana_dart_navigation/testing.dart; its binding in this contract's fixture directory.
- **DEC-227** (S12, medium). Is the app's deep-link mapping total or may it return nothing? Chosen: total: DeepLinkResolver returns a ResolvedNavIntent.
- **DEC-228** (S12, medium). Does the contract pin the resolver template's stages and ids, and the access-requirement spelling? Chosen: pin id nav-resolver, APPLICATION scope, reads, writes and the stage order; requirement variants PublicAccess, AuthenticatedAccess, RoleAccess, CustomAccess with a fallback on the policy.
- **DEC-229** (S12, medium). How does the contract own result handling (Guide §3.6)? Chosen: a resultsFor helper over the topology DSL (withLatestFrom, filter, map) plus the stated pattern.
- **DEC-230** (S12, high). Names and defaults: executor default name, resolver id, history buffer, testing library name. Chosen: ExecutorSource('navigation') by default; resolver id 'nav-resolver', not configurable; nav.history buffer 20; testing.dart.
- **DEC-231** (S12, high). The S11 stand-in runtime delivers an activation's connection one microtask after activate, so a deep link queued before start() reaches the resolver's withLatestFrom before its auth read has a value ... Chosen: pin the real bootstrap and read bus-api@v1 G22 with G34 as requiring the connection before the queue (Refinement 8).
- **DEC-232** (S12, high). bus-api@v1's publish<T>(MultiWriterTopic<T>, T) widens T, so publishing a DeepLink to nav.resolved-intent compiles. Does this contract carry a reject line for it now? Chosen: state G1 for this contract's own declarations and record the gap (Refinement 9).
- **DEC-234** (S12, high). S12 asks for a bus-api@v1 amendment: (a) a topology activated before start() is connected to its reads before start() delivers the queue, with cases that catch a runtime dropping a queued deep link ... Chosen: Amend bus-api@v1 now, before flutter-binding@v1, all four changes in one step.
- **DEC-235** (S13, high). Change (b): which signature makes a value of the wrong type a compile error without changing any fixture outside bus-api@v1? Chosen: publish<T extends Object?, V extends T>.
- **DEC-236** (S13, high). Change (a): is the connection rule a sharpening of G22 and G34 or a new guarantee after G39? Chosen: sharpen G22, G34 and the connection rule.
- **DEC-237** (S13, high). Does G22 pin that the publishes a connection causes are made from a provider-zone microtask, never within activate, as S12 asked, or keep only 'delivered once the microtasks queued during activate have run'? Chosen: pin the deferral, with a case.
- **DEC-239** (S13, high). Change (b): extend G11 and G19 with the value-type rule, or add a guarantee? Chosen: new G40 with its own reject library.
- **DEC-240** (S13, medium). Explicit type arguments can still widen T through Dart's covariant generics (publish<num, double> on an EventTopic<int> compiles, probe P16, P26). What does G40 say about them? Chosen: state the limit in G40.
- **DEC-241** (S13, high). Change (c): how does G38 admit the settle operation's real event-loop turns? Chosen: except them in G38, citing bus-testing@v1 G12 and ADR-003 item 6.
- **DEC-242** (S13, high). Change (d): how does the delivery rule name the recorders? Chosen: the recorders attached to the bus first, in attachment order (bus-testing@v1 G14, G17).
- **DEC-243** (S13, medium, would have asked: axis). After the connection, does every later delivery reach a topology's read during that delivery, so the deliveries start() makes reach a topology's reads in queue order across topics? Chosen: pin it: a connected read receives each later delivery during that delivery.
- **DEC-244** (S13, high). Is this amendment within v1, given that the Breaking list names retyping a declaration and changing a delivery rule? Chosen: within v1, with a Versioning line.
- **DEC-246** (S13, high). S13 declared publish<T extends Object?, V extends T>(MultiWriterTopic<T>, V) instead of the publish<T, V extends T> the orchestrator named, because the named form makes a failed inference fall back ... Chosen: Same change; accept.
- **DEC-247** (S14, high, would have asked: axis, upstream). OQ-F1: which router do the Flutter executor and the module binding target: Flutter's own Navigator and Router APIs, or go_router as Guide §3.4 shows, and does that router become a dependency of the adapter? Chosen: Flutter Navigator, no router dependency.
- **DEC-248** (S14, high). Settle the bootstrap: NavigationExecutor reads router.stack when constructed, so either the Navigator is mounted first, or the router accepts calls before mount. Chosen: Router accepts performs before mount.
- **DEC-249** (S14, medium, would have asked: axis, upstream). Which routes hold a module scope reference: every route on the Navigator's stack whose path matches, or only the visible top route? Chosen: Stack membership.
- **DEC-250** (S14, medium). When is a popped route's module reference released: at didPop, or when the route is disposed after its exit transition? Chosen: At didPop.
- **DEC-251** (S14, high). On a route replacement inside a module's subtree, in which order are references acquired and released? Chosen: Acquire new, then release old.
- **DEC-252** (S14, high). What does the module observer do when an acquire throws (bus-api@v1 G28 rethrows an activation failure)? Chosen: Report through FlutterError.reportError.
- **DEC-253** (S14, medium, upstream). Two mounted PageScopes that name one topology id (one route pushed twice): how is the shared handle released? Chosen: Count holders per bus and topology id.
- **DEC-254** (S14, medium). Does a PageScope rebind when rebuilt with other arguments (route, topologies, writes)? Chosen: Bind once, at mount.
- **DEC-255** (S14, high). How does a topic widget render: read getCurrentValue at every build with the subscription only invalidating, or keep the observed values in its State? Chosen: Render the bus's current value; subscription only invalidates.
- **DEC-256** (S14, medium). How does an app say whether a BusProvider owns, and so shuts down, its bus? Chosen: Unnamed constructor owns, BusProvider.value does not.
- **DEC-257** (S14, medium, would have asked: upstream, upstream). What ends the coordination domain on Flutter: the owning provider's dispose only, or also AppLifecycleState.detached? Chosen: Owning provider's dispose only.
- **DEC-258** (S14, medium, would have asked: axis). Platform routes (the initial route and routes the platform pushes): who turns them into intents? Chosen: The executor forwards them as DeepLink, on by default.
- **DEC-259** (S14, medium). Which settings does a router route carry, and who builds the Flutter route? Chosen: App builds the route from (entry, settings); settings named '/' + path carrying the entry; other settings rejected.
- **DEC-260** (S14, medium). How does the router treat routes it did not build (dialogs, sheets, app pushes)? Chosen: Not entries; a perform pops the ones above the top entry first.
- **DEC-261** (S14, high). The executor's default name. Chosen: flutter-navigation.
- **DEC-262** (S14, medium). What does the widget-test library offer, given it may import neither test framework and so takes no WidgetTester? Chosen: WidgetTestBus: bus, recorder, input, stub, wrap.
- **DEC-263** (S14, high). What is the module-scope binding mechanism on Flutter? Chosen: A NavigatorObserver subclass.
- **DEC-264** (S14, high). How does a module prefix match a route path? Chosen: By segments, ignoring a leading '/' and empty segments.
- **DEC-265** (S14, medium). A Navigator that unmounts reports no pop of its routes (P6): how are its module references released? Chosen: ModuleScopeObserver.dispose.
- **DEC-266** (S14, medium, would have asked: axis). Which conveniences does v1 leave out? Chosen: Leave out Router-widget integration and web URL sync, nested-Navigator executors, an event-topic listener widget, a BuildContext extension, route restoration.
- **DEC-267** (S14, high). Which Flutter libraries may the main library import? Chosen: widgets, foundation and services only.
- **DEC-268** (S14, medium). What does the contract say about app code that removes or replaces router routes itself? Chosen: Outside the contract; no guarantee.
- **DEC-269** (S14, medium). One page widget for topologies and publisher, or two? Chosen: One PageScope with topologies and a publisher.
- **DEC-273** (S15, high, upstream). Where does topics.yaml live and what does it generate: one Dart file per domain (Guide C.3's auth_topics.dart), one library per schema file, or one schema file per domain? Chosen: one library per schema file at lib/topics.yaml to lib/topics.g.dart.
- **DEC-274** (S15, medium, upstream). What does topics.yaml's initial hold? Chosen: a Dart expression string, or a YAML number, boolean or null written as the Dart literal.
- **DEC-275** (S15, medium). How does a topics document say which Dart libraries declare its types? Chosen: per-domain dart.imports list.
- **DEC-276** (S15, high). Does the topics document reject unknown keys, or ignore them? Chosen: closed: every unknown key is an error.
- **DEC-277** (S15, high). Does the file contract also carry a JSON Schema for topics.yaml with valid/ and invalid/ cases, and in which syntax are the cases written? Chosen: schema with JSON-syntax cases, plus rejected/ YAML for the generator-only rules.
- **DEC-278** (S15, high). What exact Dart shape does a generated registry member take? Chosen: static final with the type written on the field and the constructor, non-default arguments only, no collections.
- **DEC-279** (S15, high). How are class and member names derived, and what happens when a key cannot become a Dart identifier? Chosen: camel-case derivation, and reject collisions, reserved words and Object member names (R2, R3).
- **DEC-280** (S15, high). How is a description rendered into a doc comment and the catalog? Chosen: Markdown, with < and > outside code spans backslash-escaped.
- **DEC-281** (S15, medium). What does the topic catalog topics.md contain and how are graph topics matched to document topics? Chosen: per-domain and per-topic sections with property tables, readers and writers from the graph matched by name, plus topology, claim and outside-topic sections.
- **DEC-282** (S15, medium, would have asked: external). How does the build-time topology graph page (Guide C.4) render the graph? Chosen: static HTML embedding topology-ir@v1's Mermaid rendering, Mermaid 11.12.0 loaded from jsDelivr when opened.
- **DEC-283** (S15, high). Which commands does nidana_dart_codegen expose for this contract, with which arguments and exit codes? Chosen: generate [--graph <graph>] <topics> <output> (pure) and catalog <package>... <output> (runs topology code), exit 0, 1 for rejected input, 2 for usage.
- **DEC-284** (S15, medium). Must this contract fix any part of OQ-T1 (how Catalog.scanTopologies obtains every TopologyDefinition without reflection)? Chosen: fix the output and the definitions' origin only: topology-graph.json holds buildDefinition() of the registered topologies, recorded on the VM unobfuscated; leave registration to the decomposition.
- **DEC-285** (S15, high). Does topology-graph.json hold shell claims, and from where? Chosen: yes, the claims nidana-checks@v1's workspace scan resolves; unresolvable ones left out with a warning.
- **DEC-286** (S15, medium). One input/expected pair, as ADR-001 item 6 reads, or several cases? Chosen: one input/expected pair, with a graph, covering every feature in one document.
- **DEC-288** (S15, medium). Is a domain's owner required? Chosen: required.
- **DEC-289** (S15, high). Which outputs does the build_runner builder write? Chosen: the registry library only.
- **DEC-291** (S16, high). Which v1 checks are plugin rules and which are scan checks? Chosen: ADR-002 split.
- **DEC-292** (S16, high). What severity does each plugin rule report at by default? Chosen: blocking rules WARNING, sensitivity INFO.
- **DEC-293** (S16, medium). How are diagnostic codes named, and what do the messages say? Chosen: unprefixed snake case.
- **DEC-294** (S16, medium). What is a raw-string topic use on Dart, where no bus method takes a string? Chosen: literal name outside a static-field initializer.
- **DEC-295** (S16, high). What counts as a global bus accessor? Chosen: variables, static fields and getters.
- **DEC-296** (S16, medium, would have asked: axis). Is a check against explicit type arguments on publish a v1 rule (S13's suggestion)? Chosen: v1 rule over four sinks.
- **DEC-297** (S16, medium, would have asked: axis). What is a known-sensitive type, and where is Spec §9.2's configurable list? Chosen: suffixes plus a Sensitive annotation on types and aliases.
- **DEC-298** (S16, high). Which code do the checks read? Chosen: outside test directories.
- **DEC-299** (S16, medium). Which constructs in application code are claim sites? Chosen: four sites.
- **DEC-300** (S16, high). When does a claim's write set or scope resolve statically, and what happens otherwise? Chosen: set literal of declared state topics; else warning and left out.
- **DEC-301** (S16, medium). What source does a claim get when its source argument does not resolve (a parameter, a PageScope without route)? Chosen: stand-in named by the site.
- **DEC-302** (S16, high). What does the scan read (OQ-T2's residual: workspace AST scan, catalog IR plus AST claims, or both with the plugin surfacing verdicts)? Chosen: graph topologies plus own source walk.
- **DEC-303** (S16, medium). What are the scan command's name, output format and exit codes? Chosen: scan, pipe-separated lines, 0/1/2.
- **DEC-305** (S16, high). How does the scan render a TopicRef's typeName, so that a claim and a topology writing one topic compare equal? Chosen: as the VM renders '$T'.
- **DEC-307** (S16, high). Where must dart analyze run for the plugin to report? Chosen: at the enabling root or on files.
- **DEC-308** (S16, high). Frontmatter: kind, compatibility, producers, consumers, schema Chosen: cli, versioned, node ids, no schema.
- **DEC-311** (S17, high). Decide whether this is an in-place amendment of the accepted ADR or a superseding ADR, and record why. Chosen: amend in place.
- **DEC-312** (S17, high). How should item 4's cross-contract binding example, and the matching Consequences bullet, read now that topology-dsl@v1 has no live builder? Chosen: name bus-api@v1's activation path and bus_activation_test.dart.
- **DEC-313** (S17, high). Which directories may a fixture tree hold besides the named sets, and what does the structure set do with them? Chosen: data directories listed in Validation; structure fails on any other entry.
- **DEC-314** (S17, medium). How does item 3's coverage rule count the schema set, the file replay and recorded invocations, whose files carry no G{n}? Chosen: declared in Validation in the forms the contracts use.
- **DEC-315** (S17, high). Item 3 and item 4 give one form each, '// covers: G{n}' and '- not executable: G{n}, ...'; contracts also wrote two-id reject headers and not-executable lines for part of a guarantee. Admit them or ... Chosen: admit {ids} headers and G{n}'s {part} lines.
- **DEC-316** (S17, high). Item 7 does not say where a recorded invocation without files/ runs. Chosen: the workspace root.
- **DEC-317** (S17, medium, would have asked: axis). S15 proposed extending item 6 so a file contract can carry several input/expected cases, including cases with an expected exit code (making topic-codegen@v1's G2, G14 and G19 executable). Does this belong in v1? Chosen: item 7 gains {output} and expected/; file contracts may carry recorded invocations.
- **DEC-318** (S17, high). Item 6 does not say a file contract may carry a schema and valid/ and invalid/ cases for its input format, which topic-codegen@v1 does. Chosen: state it in item 6.
- **DEC-319** (S17, medium). Item 10 runs every set but behavior in full at every producing phase, and --guarantee restricts only behavior cases; how do the file and cli sets gate a node that delivers a generator or a checker over several phases? Chosen: --guarantee restricts file replays and recorded invocations by declared ids.
- **DEC-320** (S17, medium). S17 went beyond the listed changes: it extended item 7 so a file contract may carry recorded invocations with expected exit codes (the item 6 option), and extended items 9 and 10 so --guarantee ... Chosen: Keep them.
- **DEC-322** (S18, high). Does topology-dsl@v1 belong in ADR-003's affects, with the matching Governed by on the contract? Chosen: Add topology-dsl@v1.
- **DEC-330** (S19, high). How does the contract state the rejection of a DeepLink published to nav.resolved-intent that bus-api@v1 G40 now gives: as a clause of G1, as a new guarantee, or as reject lines alone? Chosen: extend G1 with a publish clause.
- **DEC-331** (S19, high). Which publish paths does the new reject coverage exercise: the Publisher call S13 probed (P19), or both publish paths G40 types? Chosen: both Bus.publish and Publisher.publish.
- **DEC-332** (S19, high). Refinement 8: keep this contract's own reading of bus-api@v1 G22 and G34 and add citations, or replace the reading with what G22 and G34 now state? Chosen: cite G22 and G34 as stated, history to Versioning.
- **DEC-333** (S19, high). Refinement 9: does the contract say that explicit type arguments still let a DeepLink onto nav.resolved-intent, or leave it implicit in 'with its type arguments inferred'? Chosen: state the residual.
- **DEC-334** (S19, medium). The Validation bullet on the Flutter binding of the executor suite: name the file flutter-binding@v1 wrote only, or also the order in which its executor constructs and pumps? Chosen: path and construct-before-pump order.
- **DEC-335** (S19, high). Is the touch compatible within v1, or does G1's new clause make it breaking? Chosen: compatible within v1.
- **DEC-336** (S20, high). Is the widened-reference guarantee a new G41 or a sharpening of an existing guarantee (G6 or G7)? Chosen: new G41.
- **DEC-337** (S20, high). Which read-side operations does G41 cover, and what does each return through a widened reference? Chosen: every read, typed by the reference.
- **DEC-338** (S20, medium, would have asked: axis). Does G41 cover writes through a widened reference (Bus.publish, Publisher.publish, writer and StateWriter.publish, a topology sink), and what about the envelope's type argument and a value outside the topic's value type? Chosen: include writes of a value of the value type; leave the envelope's type argument and off-type values outside.
- **DEC-339** (S20, high). How does the registry key and type a subject so the order of first access does not matter (topic-model@v1's valueType)? Chosen: key by name, compare topic values, store at Object?, convert at each access.
- **DEC-340** (S20, high, would have asked: axis). What does G20's 'returns the same handle on every call' mean once writer is reachable through a widened reference? Chosen: same handle per type argument.
- **DEC-341** (S20, high). How does For static analysis cite nidana-checks@v1 G5, which adds top-level and static getters to the global-accessor definition? Chosen: restate G5's set and cite G5.
- **DEC-342** (S20, high). Where is the term 'widened reference' defined? Chosen: a Delivery rules bullet.
- **DEC-343** (S20, high). Where do the G41 cases live, and how is 'either order' exercised? Chosen: six cases in bus_api_conformance.dart, each running both orders on fresh buses.
- **DEC-344** (S20, medium). S20 leaves three compatible follow-ups in contracts other than bus-api@v1: bus-testing@v1 G16 (envelopesOf and payloadsOf throw a TypeError on an envelope published through a widened reference), the ... Chosen: Route to the producers' phase planning as amend entries.
- **DEC-345** (S21, high). Does rejected/ move into the generate-rejected-* recorded invocations (S17's recommendation), stay and be duplicated into them, or stay as the one copy that the cases name by path? Chosen: keep rejected/ and name it by path.
- **DEC-348** (S21, medium). Make G2 executable in full by recording generate over every valid/ and invalid/ document too, or only over rejected/, with a part line for the rest? Chosen: rejected/ only, part line for the rest.
- **DEC-350** (S21, high). State catalog's alignment with nidana-checks@v1's claim recognizer by editing G20, G21 and the Interface bullet in place, or by adding a guarantee G22? Chosen: edit G20, G21 and the bullet in place.
- **DEC-351** (S21, medium). Does topic-codegen@v1 pin the form of catalog's stderr warning, for example nidana-checks@v1's warning|unresolved_claim|{site}|{message} line (S16's suggestion), or leave its text unpinned? Chosen: leave the text unpinned.
- **DEC-352** (S21, medium). A stand-in source names its site relative to the working directory (nidana-checks@v1 G11, G17), so topology-graph.json then depends on where catalog runs. Does topic-codegen@v1 G17 ('the outputs ... ... Chosen: G17 is generate's.
- **DEC-360** (S22, medium). Routed amend, bus-testing@v1 G16: what do envelopesOf and payloadsOf return for an envelope published through a widened reference (a MessageEnvelope<Object?>, which cannot be both typed by the topic and identical)? Chosen: Equal rebuilt envelope when not a MessageEnvelope<T>.
- **DEC-361** (S22, high). Routed amend, bus-testing@v1 G18: how does TestBus.stub return 'the same writer on every later call' when calls come at different type arguments? Chosen: One publisher per topic, writer per type argument.
- **DEC-365** (S23, medium, would have asked: upstream, upstream). OQ-T1 residual: how does a package register its topologies for catalog, and how are their constructor arguments supplied (Spec §6.5's build-time DI)? Chosen: A registration library the app writes.
- **DEC-366** (S23, high). OQ-T1 residual: how does catalog load topology libraries that import Flutter, since dart run has no dart:ui? Chosen: dart run, or flutter test when the registration reaches dart:ui.
- **DEC-368** (S23, medium). Does the registration mechanism enter topic-codegen@v1 now, through a contract touch step, or as an amend from nidana.tooling.codegen's phase plan? Chosen: amend topic-codegen@v1 from the phase plan.
- **DEC-369** (S23, medium). nidana-checks@v1 is produced by both children: how do the producing phases replay it under ADR-001 item 10, and how does reconcile treat two producers? Chosen: Partition by host; each child's last phase runs its host's full id set.
- **DEC-372** (S23, high). Routed item (S20.orchestrator): which leaf-parent's plan emits the amend of nidana-checks@v1's global-accessor note, which still describes bus-api@v1's earlier, narrower definition? Chosen: nidana.tooling.lint's plan.
- **DEC-375** (S24, high). In general form, how is a contract with more than one producing leaf-parent replayed under item 10, given that 'unrestricted at the last phase that produces the contract' has no single reading for two producers? Chosen: per-producer shares, each case within exactly one share.
- **DEC-377** (S24, medium). Where are the producers' shares of a multi-producer contract recorded? Chosen: the spec of the node whose decomposition made the producers.
- **DEC-397** (S26, medium). navigation-api@v1's and flutter-binding@v1's behavior suites, which nidana.navigation's and nidana.flutter's gates run, import package:nidana_dart_contracts/topology_ir.dart (ShellClaim ... Chosen: report and leave the edges.
- **DEC-403** (S27, medium). package:nidana_dart_contracts/nidana_dart_contracts.dart carries the declarations of three contracts (topic-model@v1, topology-dsl@v1, topology-ir@v1). When a fixture imports it, which contracts does its node consume? Chosen: by the declarations the fixture names.
- **DEC-404** (S27, high). topology-ir@v1 into nidana.navigation: the behavior suites its gates run (navigation_conformance.dart, navigation_executor_conformance.dart through in_memory_router_test.dart and ... Chosen: contract.
- **DEC-405** (S27, high). topology-ir@v1 into nidana.flutter: flutter_binding_conformance.dart compares bus.toGraph() claims with ShellClaim values and reads TopologyDefinition ids from bus.toGraph() ... Chosen: contract.
- **DEC-408** (S28, high). ADR-001 item 9 puts the replay tool in this node's first phase, and the conventions' fp-progression line and root Development flow item 1 put the type-level skeleton of all three contracts there too ... Chosen: tool phases first, then one type-level phase per contract.
- **DEC-413** (S28, high). What does a type-level phase land: are value equality and simple getters part of the skeleton? Chosen: declarations with final fields, constructors and asserts; computing bodies throw; Object equality until the values phases.
- **DEC-415** (S28, high). At which phase does each behavior guarantee join the --guarantee restriction, given that the tool restricts by case-name prefix? Chosen: by the phase that makes every case of the id pass.
- **DEC-420** (S28, medium). Which exit codes does the replay tool use? Chosen: 0 pass, 1 fail or PENDING, 2 environment error, 64 usage error.
- **DEC-421** (S28, high). Does PENDING cover only bindings (ADR-001 item 9's text) or every fixture that names an absent package? Chosen: every fixture: surface, reject, behavior, file replays and recorded invocations.
- **DEC-422** (S28, medium). How do --set and --guarantee behave across several slugs and sets a slug lacks? Chosen: structure always runs; --set never adds a set; under --guarantee a slug with no id runs no behavior, file or cli case; a bare id needs exactly one slug.
- **DEC-425** (S28, high). Do stages, sinks, builders and plans compare by identity or by value, and is that stated to consumers? Chosen: identity, stated as an amend.
- **DEC-426** (S28, medium). Do the finding and collision constructors keep the list order given or normalize it to the orders the Interface comments name? Chosen: normalize.
- **DEC-431** (S29, high). topology-ir@v1's consumers frontmatter is [nidana.runtime, nidana.tooling, nidana.integration], while root D10 (S27) added nidana.navigation and nidana.flutter as consumers. Add them now, or wait for ... Chosen: wait for their confirm entries.
- **DEC-432** (S29, medium). The three confirm entries carry 'for consumer plans' sub-bullets (which producing phase delivers which guarantees, which phase a consumer's edge waits on). Consumer planners never read the producer's ... Chosen: a Delivery paragraph in each contract.
- **DEC-433** (S29, high). amend topology-dsl@v1 (stages, sinks, builders and plans compare by identity) was 'proposed as a new guarantee after G29, or as a sentence under The plan'. Which, and how is it covered per ADR-001 item 3? Chosen: G30 plus a sentence under The plan, with one recording case.
- **DEC-434** (S29, high). amend topology-ir@v1 (finding and collision constructors sort their lists into the Interface's orders): a new guarantee, or a change to G7's equality text? Chosen: G23 plus a sentence under Analyses, with one behavior case.
- **DEC-455** (S30, medium). Which phases are listed as producing bus-api@v1 and bus-testing@v1? Chosen: Phases that implement public members.
- **DEC-458** (S30, high). amend bus-api@v1 G41's outside clause per D5: can it break a consumer? Chosen: Compatible.
- **DEC-459** (S30, high). amend bus-testing@v1 G16 per D6: can it break a consumer? Chosen: Compatible.
- **DEC-460** (S30, high). amend bus-testing@v1 G18 per D7: can it break a consumer? Chosen: Compatible.
- **DEC-462** (S31, high). bus-testing@v1's consumers frontmatter is [nidana.navigation, nidana.flutter, nidana.integration], while nidana.runtime's Contracts table (S26 finding) and S30's confirm sub-bullet name ... Chosen: wait for its confirm entry.
- **DEC-463** (S31, high). How do nidana.runtime's consumer confirms land in the three model contracts' consumers lists: replace the node id with the confirmed phase ids, or keep the node id? Chosen: replace the node id with its phase ids.
- **DEC-464** (S31, high). The three behavioral amends (bus-api@v1 G41 off-type clause, bus-testing@v1 G16, bus-testing@v1 G18) add behavior their existing cases do not reach. Cover them with new cases in this edit, or apply ... Chosen: five new cases now.
- **DEC-465** (S31, medium, would have asked: breaking-amend). The G41 amend makes getCurrentValue and getBufferedValues throw TypeError at the call for an off-type value, while G8 says 'neither throws except TopicCollision'. Is the amend still compatible, and what happens to G8? Chosen: compatible; G8 names the TypeError.
- **DEC-466** (S31, medium). The amend entry says each conversion runs 'in the delivery callback of the one subscription or topology read it serves' and lists the conversions made at a call. A read's connection is converted ... Chosen: state the connection explicitly.
- **DEC-467** (S31, high). In the Delivery paragraphs, does 'phase X delivers G{n}' name the phase whose gate first replays the guarantee or the phase that implements its slice? Chosen: the phase that first replays it.
- **DEC-468** (S31, high). topology-dsl@v1's Delivery paragraph says G18 to G29 'are the live implementation's'. Does it gain the phase that delivers them, which S30's topology-dsl confirm sub-bullet states (replayed from nidana.runtime.12 on)? Chosen: add the phase.
- **DEC-471** (S31, high). While applying the G41 amend, S31 edited bus-api@v1 G8 ('neither throws except TopicCollision') so it also names G41's TypeError for an off-type value, and flagged it as a possible breaking amend. Is ... Chosen: Not a stop; keep the edit.
- **DEC-472** (S32, high). navigation-api@v1 G13 fixes the nav-resolver's edges and order but not the functions they record; topology-ir@v1 G9 leaves a closure anonymous. Should the template's two stage functions be closures ... Chosen: method tear-offs of private stage classes.
- **DEC-478** (S32, high). What does nidana.navigation.1, the type-level phase, land beyond signatures: constructors, consts, equality? Chosen: copying constructors, bodies throw.
- **DEC-484** (S32, high). Which phases does the confirm entry list as consumers of bus-testing@v1 and topology-ir@v1, given that every behavior replay compiles conformance libraries importing testing.dart and topology_ir.dart? Chosen: phases that use them.
- **DEC-485** (S33, high). Step 3 (collision detection): does the amend of navigation-api@v1 G13, which fixes the resolver's recorded transformer names to resolveDeepLinks, FunctionRef.of(principalOf) and applyAuthGuard ... Chosen: no collision, apply the entries.
- **DEC-486** (S33, high). topology-ir@v1's consumers frontmatter does not list nidana.navigation at all. Does the plan's confirm entry add nidana.navigation.3 and nidana.navigation.6, or does the edge need its own root or hsdd-contract step first? Chosen: add the confirmed phase ids.
- **DEC-487** (S33, high). How to write navigation-api@v1's Delivery paragraph from the produced_by sub-bullets (conventions, Contracts): transcribe them only, or also state that nidana.navigation.3 and nidana.navigation.4 run ... Chosen: transcribe plus the side-by-side sentence.
- **DEC-488** (S33, high). ADR-001 item 3 needs the G13 stage-name clause covered. Add a new behavior case, add assertions to the existing first G13 case (the plan's suggestion), or record a not-executable line naming nidana.navigation's gates? Chosen: new G13 case over both forms.
- **DEC-489** (S33, high). Is the G13 amend backward-compatible, so it applies within v1 keeping the version, or could it break a consumer and go to the human with a version bump? Chosen: compatible, apply within v1.
- **DEC-490** (S33, high). State the stage names in G13 unconditionally, or qualify them 'on the VM' as topology-ir@v1 G9 does? Chosen: qualify 'on the VM', citing topology-ir@v1 G9.
- **DEC-492** (S34, high). flutter-binding@v1's topic widgets read getCurrentValue / getBufferedValues at their T in every build, which bus-api@v1 G41 (amended in S31) now makes throw TypeError for an off-type value published ... Chosen: widened subscription, amend G5 and G6.
- **DEC-493** (S34, high). flutter-binding@v1 G17 says WidgetTestBus.stub returns 'the same writer on every call for topic', the per-type-argument problem bus-testing@v1 G18 and bus-api@v1 G20 had. Amend or node-local? Chosen: one publisher per topic, writer per type argument, amend G17.
- **DEC-496** (S34, medium). The root types runtime to flutter 'hard' for bus-api@v1 and bus-testing@v1 and its Development flow starts the node after the runtime ships. Which producer phase does each nidana.flutter phase wait on? Chosen: per phase by need.
- **DEC-503** (S34, medium). G8 says a PageScope binds once, at mount. What happens when the enclosing BusProvider starts providing another bus? Chosen: keep the binding, amend G8.
- **DEC-504** (S34, medium). G7 derives an unnamed PageScope's route from settings.name without its leading '/'. For a route named '/', Flutter's default route and WidgetsApp's home route, that is the empty string, which ... Chosen: '/' gives PageSource('/'), amend G7.
- **DEC-505** (S35, high). Step 3 (collision detection): does any entry of nidana.flutter's section conflict with another node's entry or assumption, in particular the G7 amend (a route named / gives the page source page:/) ... Chosen: no collision, apply the entries.
- **DEC-506** (S35, high). How to write flutter-binding@v1's Delivery paragraph from the produced_by sub-bullet (conventions, Contracts), and whether to change the Interface's code-owner sentence, which the plan says already ... Chosen: transcribe plus the side-by-side sentence, and name nidana.flutter.1 in the code-owner sentence.
- **DEC-507** (S35, high). bus-api@v1's and bus-testing@v1's Delivery paragraphs say a hard edge waits on nidana.runtime.14 for nidana.flutter, while the plan's D6 has nidana.flutter.1 wait on nidana.runtime.1 (declarations ... Chosen: record nidana.flutter.1's wait on nidana.runtime.1.
- **DEC-508** (S35, high). Step 6: are the four amends (G5 and G6 off-type values through a widened subscription; G7 a route named / gives /; G8 binding kept across a bus change; G17 one publisher per topic with a writer per ... Chosen: all four compatible, apply within v1.
- **DEC-509** (S35, high). ADR-001 item 3 coverage of the amended clauses: add behavior cases now (S34 recommended G5/G6 and G17, G7 and G8 optional), add only the recommended ones, or record not-executable lines naming ... Chosen: five cases: G5, G6, G7, G8, G17.
- **DEC-523** (S36, high). raw_string_topic: G4 accepts the whole initializer of 'a static field'; the rule detail says 'a static field, static const or static final, of any class'. Which does the plugin implement, and what is amended? Chosen: implement G4, amend the detail.
- **DEC-524** (S36, high). unflagged_sensitive_topic's {1} when the value type contains more than one known-sensitive type: which one is named? Chosen: first in a depth-first search, alias first.
- **DEC-525** (S37, high). hsdd-reconcile step 3: is `confirm nidana-checks@v1 produced_by: [nidana.tooling.lint.1 to .4]` a collision (two nodes claiming the same artifact), given that nidana.tooling.codegen also produces nidana-checks@v1? Chosen: complementary share, apply union.
- **DEC-526** (S37, high). Which id stands for nidana.tooling.codegen's still-unplanned share in nidana-checks@v1 produced_by and in the consumers of topic-model@v1, topology-dsl@v1 and bus-api@v1, once lint's phase ids ... Chosen: name nidana.tooling.codegen.
- **DEC-527** (S37, high). bus-testing@v1 consumers did not name nidana.tooling at all: does the confirm add lint's ids only, or also a nidana.tooling.codegen placeholder? Chosen: lint's ids only.
- **DEC-528** (S37, high). Amendment (c) states that raw_string_topic accepts the whole initializer of any static field, of any declaration kind, const, final, late or none of these. No recorded case held such a field (ADR-001 ... Chosen: accepted forms appended to analyze-raw-string-topic.
- **DEC-529** (S37, medium). Amendment (d) fixes unflagged_sensitive_topic's {1} for a value type that contains several known-sensitive types (depth-first, alias first). No recorded case held two. Where is it covered? Chosen: four topics appended to analyze-sensitive-fatal-infos, Covers G1, G2, G7.
- **DEC-530** (S37, high). Apply amendments (a) (the global_bus_accessor detail cites bus-api@v1 For static analysis) and (b) (Refinement 4 says root D1 lists explicit_topic_type_arguments) as editorial within v1? Chosen: apply as editorial.
- **DEC-531** (S37, high). Is amendment (c), widening the raw_string_topic detail from 'static const or static final, of any class' to G4's 'any static field', compatible within v1? Chosen: compatible, keep v1.
- **DEC-532** (S37, high). Is amendment (d), the search order for {1} with several known-sensitive types, compatible within v1? Chosen: compatible, keep v1.
- **DEC-533** (S37, high). What does nidana-checks@v1's Delivery paragraph say while only one of its two producers is planned, and does the code-owner sentence change? Chosen: plugin share now, scan share at codegen's drain.
- **DEC-534** (S37, high). Do the consumed contracts' Delivery paragraphs change with lint's consumer confirms? Chosen: leave them unchanged.
- **DEC-535** (S37, medium). flutter-binding@v1's Delivery paragraph says nidana.tooling.lint's recorded invocations resolve nidana_dart_runtime_flutter and wait on nidana.flutter.1; lint D5 shows no analyze-* case imports it. ... Chosen: leave it, report it.
- **DEC-543** (S38, high). Context Q11c records exit 3 for a plugin that does not compile, and plugin-rebuild R6 observed exit 4. Which fact does the ADR state? Chosen: state the general rule.
- **DEC-545** (S39, high). D1 point 3 says the Flutter tester needs no flutter_test dependency (catalog-loading T5); B11 shows a package resolved alone without flutter_test or test is refused. How does the plan and the contract treat it? Chosen: qualify in a new D4 and in the amend.
- **DEC-556** (S39, high). Which phases count as producers and what do their gates restrict to, when most guarantees are implemented before the command that makes their cases replayable exists? Chosen: implementing phases produce; delivered by the first replaying gate.
- **DEC-559** (S39, medium). topic-codegen@v1 says catalog's usage exit is 'as for generate' and leaves cases unstated: a package without pubspec.yaml, --graph given twice to generate, a graph file that is not JSON. Which codes? Chosen: spell them out by amend.
- **DEC-560** (S39, high). S33 found that a private transformer renders _name@{key} with a key that differs between JIT and AOT. topic-codegen@v1 says the static graph is the one activation checks (structurally identical). ... Chosen: amend topic-codegen@v1 with the caveat.
- **DEC-561** (S39, high). What does the scan do with a library whose imports or names do not resolve? Chosen: not nidana's, not reported.
- **DEC-562** (S40, high). hsdd-reconcile step 3: does any entry of nidana.tooling.codegen's section collide with another node's entry or assumption (two nodes claiming one artifact, contradictory confirms, an amend against ... Chosen: no collision, apply.
- **DEC-563** (S40, high). Apply the eight confirm entries: which placeholder each replaces, and does any contract reach phase_ids: final? Chosen: replace placeholders, keep provisional.
- **DEC-564** (S40, medium). topic-codegen@v1's owner is nidana.tooling, and its only producer is now nidana.tooling.codegen. Change owner to the child? Chosen: keep owner nidana.tooling.
- **DEC-565** (S40, high). What does topic-codegen@v1's Delivery paragraph say, given that most guarantees are implemented by pure phases (.2 to .5) before the command that makes their cases replayable exists (.6)? Chosen: delivered by the first replaying gate.
- **DEC-566** (S40, high). The registration amend says the Boundary row 'How catalog obtains the topologies of a package (OQ-T1)' points at the Interface. That row also holds the scan's recognition and the static checks, owned ... Chosen: two rows.
- **DEC-567** (S40, high). Are the three topic-codegen@v1 amends (registration mechanism; usage errors spelled out; JIT versus AOT private transformer keys) compatible within v1? Chosen: compatible, keep v1.
- **DEC-568** (S40, medium). The usage-errors amend adds behavior to G19 and G21. Which cases become recorded invocations (ADR-001 item 3; ADR-001 Consequences: a guarantee about usage errors stays not executable only while its ... Chosen: five cases for the codes v1 left undetermined.
- **DEC-569** (S40, high). What graph document does generate-graph-not-json hold, and does it run from the workspace root or from files/? Chosen: files/ with a document cut short.
- **DEC-570** (S40, medium). With the registration form decided, G20's not-executable reason ('the registration form catalog reads is nidana.tooling's decomposition's (OQ-T1)') is stale. What is the reason now? Chosen: catalog would write under hsdd/.
- **DEC-571** (S40, medium). The not-executable lines read 'checked by nidana.tooling's gates'. Now that nidana.tooling.codegen's phases are confirmed as the producer of topic-codegen@v1 and of nidana-checks@v1's scan share, name the child? Chosen: name nidana.tooling.codegen's gates.
- **DEC-572** (S40, high). Are the two nidana-checks@v1 amends (editorial Boundary split and Refinement 2 citation; code that does not resolve is neither a topic creation nor a claim site, and dart analyze precedes the scan) compatible within v1? Chosen: compatible, keep v1.
- **DEC-573** (S40, high). No recorded case holds code that does not resolve. Where is the unresolved-code rule covered (ADR-001 item 3)? Chosen: a library appended to scan-unresolved-claim.
- **DEC-574** (S40, high). How does nidana-checks@v1's Delivery paragraph state the scan share? Chosen: replace the placeholder sentence with the scan's phases.
- **DEC-575** (S40, high). Do the consumed contracts' Delivery paragraphs change with codegen's consumer confirms? Chosen: only flutter-binding@v1's parenthetical.
- **DEC-577** (S40, high). Step 13: which citations still treat OQ-T1 as open, and how are they swept? Chosen: sweep contract citations and refresh the OQ row.
- **DEC-594** (S41, medium). Which phases does the confirm entry for nidana-checks@v1's consumers name, given that every gate's root analyze runs the plugin over the member? Chosen: the phases that use the contract by design: .1, .6, .7, .8.
- **DEC-597** (S42, high). ADR-001 item 12 makes a fixtures directory the executable validation artifact only when it meets item 3 and its kind's items, checked by the structure set once the replay tool exists and by ... Chosen: path existence plus the prototype structure check.
- **DEC-605** (S43, medium). Should the nine contracts' provenance bullet ('the first replay against the real package, once nidana.model's first phase lands the replay tool') be reworded, now that the tool lands over nidana.model.1, .2, .6 and .7? Chosen: Leave the nine bullets.
- **DEC-610** (S43, high). With the suite-keyed restriction, does item 9 also state that a {slug}/G{n} may name a slug the command does not replay? Chosen: state it.
- **DEC-611** (S43, high). Does the empty-selection rule (no admitted case: not run, counts as passing) cover bindings only, as S31 stated it, or bindings, file replays and recorded invocations alike? Chosen: bindings, file replays and recorded invocations.
- **DEC-612** (S43, high). Does item 9 state the one 'pub get --enforce-lockfile' before the file or cli set and its failure as an environment error (S21), which only nidana.model.7's scope and D2 item 1 hold today? Chosen: state it.
- **DEC-617** (S44, high). How much does the amendment say about the library key: only that it differs between JIT and AOT (S33's finding), or what the key depends on? Chosen: what the key depends on, as measured.
- **DEC-618** (S44, high). Does the private-name row need a behavior case, and if so what does it assert? Chosen: a case asserting the @ and a key, never the value.
- **DEC-619** (S44, high). Where does the new text go: one table row, or a row plus a paragraph? Chosen: row plus a Private names paragraph.
- **DEC-620** (S44, medium). G9's gloss reads 'which on the VM is the name of a top-level function, a static method without its class, or a method tear-off', inexact for a private name; and the paragraph after the table says the ... Chosen: add a clause to G9's gloss and say 'public names'.
- **DEC-623** (S44, high). Could the amendment break a consumer, which would need a v2 and so a stop? Chosen: compatible, keep v1.
- **DEC-629** (S45, high). Could the amendment break a consumer, so that it needs v2 and a migration note rather than an in-version amendment? Chosen: compatible, keep v1.
- **DEC-633** (S46, high). Could the amendment break a consumer, so that it needs v2 and a migration note rather than an in-version amendment? Chosen: compatible, keep v1.

### node-local (273)

- **DEC-003** (S00, high). Which prose rules bind every artifact the run writes (the owner's banned character and banned phrase)? Chosen: Owner's ban, with parser-equivalent tokens.
- **DEC-004** (S00, high). The inputs include 'HSDD's own documentation under ~/git/hsdd/docs/'. Does that cover docs/superpowers/ and the Claude memory directory? Chosen: users-guide and the methodology spec only; no memory, no docs/superpowers/.
- **DEC-007** (S01, high). In what order are leaf-parents phase-planned? Chosen: Producer first (topological by contract edge).
- **DEC-008** (S01, high). Which HSDD skills does this run use? Chosen: Planning skills only: hsdd-spec, hsdd-adr, hsdd-contract, hsdd-phase-plan, hsdd-reconcile.
- **DEC-009** (S01, high). Who runs experiments, and where do they land in the commit history? Chosen: The step subagent, inside its step.
- **DEC-010** (S01, high). How are the skill's gates checked after each step? Chosen: Mechanical gate plus read-through.
- **DEC-017** (S02, medium). Guide Appendix C.4 plans an OpenTelemetry exporter for v1. What ships? Chosen: SDK-neutral telemetry observer, SDK binding deferred.
- **DEC-018** (S02, medium, upstream). Spec §6.3 states a CI lint that warns when a service exposes a stream factory and also publishes; Guide Appendix C has no row for it. Is it in v1? Chosen: Defer it and report upstream.
- **DEC-032** (S02, medium, upstream). Is the reactive engine and subject construction on Dart a cross-cutting ADR? Chosen: Node-local to nidana.runtime, timing surfaced in bus-api@v1.
- **DEC-034** (S02, high). Which OQ prefixes do the node specs use? Chosen: One letter per child, one more letter per grandchild.
- **DEC-035** (S02, high). How do the template's OpenSpec-specific sections of conventions.md adapt to the superpowers method without dropping the template's structure? Chosen: Keep every section, rewrite the OpenSpec ones for superpowers.
- **DEC-036** (S02, medium). Child-owned open questions whose answers shape a root-level contract (OQ-M1 to OQ-M3, OQ-R1 to OQ-R3, OQ-N1, OQ-N2, OQ-F1) come up before the owning node's own step runs. Resolve them at the root ... Chosen: Mint in the owning child as OPEN, waiting on the contract step.
- **DEC-039** (S03, high). Filename slug and title of ADR-001. Chosen: 001-executable-contract-validation, root title kept.
- **DEC-051** (S04, high). What slug does the ADR file take? Chosen: 002-package-workspace-layout.
- **DEC-056** (S04, medium). Does the root workspace: list name members explicitly or by glob? Chosen: Explicit member list.
- **DEC-058** (S04, medium). How are third-party version constraints written across members that share one resolution? Chosen: Caret on the locked version, same constraint in every member.
- **DEC-062** (S04, high). How does nidana_dart_lint constrain analyzer and analysis_server_plugin, given that the plugin runs under the synthetic package's resolution while its tests run under the workspace's? Chosen: Exact pins to the lockfile's versions.
- **DEC-064** (S04, high). ADR-001 follow-up: what is nidana_contract_check's full dependency set, given it joins the single resolution? Chosen: args, json_schema, matcher, package_config, path; test as dev.
- **DEC-067** (S04, medium). Which SDK constraint do the members declare? Chosen: ^3.13.0, the Dart of the .fvmrc pin.
- **DEC-068** (S04, high). How are member versions managed before v1? Chosen: Lockstep from 0.1.0; unpublished members carry no version.
- **DEC-069** (S04, medium). Do published members carry pub metadata files in v1, although publishing is an owner action? Chosen: README, CHANGELOG and a copy of the repository LICENSE in each published member.
- **DEC-072** (S04, high). OQ-T2 asks where the single-writer workspace scan runs. With item 8 fixing its host, does the row stay OPEN or become PARTIAL? Chosen: PARTIAL, residual: what the scan reads.
- **DEC-073** (S05, high). What slug does the ADR file take? Chosen: 003-time-source-virtual-scheduler.
- **DEC-089** (S05, high). Does ADR-003 settle the Dart topic model's dispatcher hint (nidana.model's OQ-M3), or only the dispatcher's meaning? Chosen: State the dispatcher, leave OQ-M3 to the model.
- **DEC-091** (S05, high). Which spec lines does accepting ADR-003 change, beyond the proposal pointer and Governed by? Chosen: Update the lines the ADR changes.
- **DEC-094** (S06, high). Do produced_by and consumers name node ids or guessed first phase ids while no phase plan exists? Chosen: node ids.
- **DEC-095** (S06, high). Does the contract header list ADR-003 under Governed by? Chosen: ADR-001 and ADR-002 only.
- **DEC-114** (S06, medium). What does the behavior harness of a shared-model contract supply, and what is the binding named? Chosen: settle only, binding named after the package.
- **DEC-117** (S06, high). S06 suggests an optional hsdd-adr touch that adds topic-model@v1 to ADR-003's affects, so the contract header could carry Governed by ADR-003. Run it? Chosen: Leave affects as it is.
- **DEC-137** (S07, medium). What is the recording binding named? Chosen: topology_builder_test.dart.
- **DEC-138** (S07, medium). Does topology-dsl@v1's Governed by list ADR-003, whose affects omits this contract while its items 3 and 4 constrain it? Chosen: [ADR-001, ADR-002].
- **DEC-139** (S07, high). What do produced_by, consumers and external_consumers name? Chosen: node ids, provisional.
- **DEC-140** (S07, high). Does this contract declare a typed topology identifier? Chosen: declare TopologyRef.
- **DEC-141** (S07, high). S07 asks for two governance touches: add topology-dsl@v1 to ADR-003's affects (ADR-003 items 3 and 4 constrain its live guarantees G22 and G23), with ADR-001 item 4's wording 'live topology builder' ... Chosen: Batch after the last root contract.
- **DEC-157** (S08, medium). How are the serialized-form fixtures laid out: where do valid/ documents come from, what do invalid/ documents mutate, and where do rendering goldens live? Chosen: Recorded samples as goldens, one small base for invalid/, render/ data files.
- **DEC-182** (S09, high). Which assignments does the immutability reject fixture pin, given that assigning a getter reports assignment_to_final for a final field and assignment_to_final_no_setter for a getter without one? Chosen: BusConfig's fields only, which its const constructor makes final.
- **DEC-190** (S10, high). How is G27 covered, and where do G1's new cases go? Chosen: reject file plus behavior case and surface uses, G1 cases appended to its file.
- **DEC-210** (S11, high). What does the bus-testing conformance harness supply, and under which runner is the suite bound? Chosen: settle only, as topic-model@v1's harness; bound under dart test only.
- **DEC-226** (S12, high). How are the conformance cases split between libraries and bindings? Chosen: two libraries: a VM-only navigation suite on TestBus (one implementation) and a runner-neutral executor suite (one per platform), the VM binding registering each executor case on both pop-until capabilities.
- **DEC-233** (S12, high). Seeded defects survived (from read off the bus, argsOf with a same-typed other route, query-parameter equality). Add cases or accept the gaps? Chosen: add the three assertions.
- **DEC-238** (S13, high). How do the new (a) cases detect a late connection? Chosen: a withLatestFrom gate over a state read.
- **DEC-245** (S13, high). The Validation section said the fixtures assume topic-model@v1 declares MultiWriterTopic. Keep the assumption or cite the declaration? Chosen: cite topic-model@v1 G27 and docs/auto-run/experiments/topic-model-multi-writer/.
- **DEC-270** (S14, high). In the executor suite's Flutter binding, is the executor constructed before or after the hosting WidgetsApp is pumped (S12's template pumps first)? Chosen: Construct, then pump.
- **DEC-271** (S14, high). How do the bindings perform the platform's back? Chosen: The navigation channel's popRoute message.
- **DEC-272** (S14, high). How does a conformance library that imports no flutter_test observe the tree? Chosen: Harness methods for the tester's operations; cases observe through their own widgets, builder callbacks and NavigatorObservers.
- **DEC-287** (S15, high). Does the generator format its Dart itself, given the replay formats anyway? Chosen: format with package:dart_style at language 3.13.
- **DEC-290** (S15, high). Frontmatter: consumers, external consumers, governance. Chosen: consumers [nidana.integration], three external consumers, Governed by ADR-001 and ADR-002.
- **DEC-304** (S16, high). Must the scan report duplicate topology ids itself (S08's note)? Chosen: no, the document cannot hold them.
- **DEC-306** (S16, high). How are recorded invocations laid out so that test directories exist and dart run works? Chosen: plugin cases: files/ is the package root; scan cases: packages under files/.
- **DEC-309** (S16, high). Which guarantees are not executable, and is stderr recorded? Chosen: three not-executable lines, no stderr.
- **DEC-310** (S16, high). With all nine root contracts written, which accumulated follow-ups run now, before the runtime and tooling decompositions, and which wait? Chosen: ADR and contract touches now; root prose in one root refresh after stage 5.
- **DEC-321** (S17, high). From S09 the orchestrator stamped its own decisions (DEC-186, 187, 193, 234, 246, 310) and the S10 to S16 run lines with local time (UTC+7) labelled as UTC, about seven hours late. The ledger is ... Chosen: Publish a correction file and guard the tool.
- **DEC-323** (S18, high). Does topic-model@v1 belong in ADR-003's affects, re-testing the S06 orchestrator decision against the contract as it now stands? Chosen: Leave topic-model@v1 out.
- **DEC-324** (S18, high). Does topology-ir@v1 belong in ADR-003's affects? Chosen: Leave topology-ir@v1 out.
- **DEC-325** (S18, high). Does topic-codegen@v1 belong in ADR-003's affects? Chosen: Leave topic-codegen@v1 out.
- **DEC-326** (S18, high). Does nidana-checks@v1 belong in ADR-003's affects? Chosen: Leave nidana-checks@v1 out.
- **DEC-327** (S18, high). How is the in-place change to an accepted ADR's affects recorded? Chosen: Dated Amendments line.
- **DEC-328** (S18, high). Does the new link need a sentence in ADR-003's Decision or Consequences? Chosen: No sentence.
- **DEC-329** (S18, high). ADR-003 item 8 says no nidana package calls DateTime.now(), constructs a Stopwatch directly, or creates a timer or microtask outside a provider zone; read literally it covers nidana_dart_codegen and ... Chosen: Read it as binding the governed nodes.
- **DEC-346** (S21, medium). Do generate-graph-undecodable and generate-usage-output-is-a-file hold their inputs in files/ as copies (S17's design), or name topology-ir@v1's invalid/format_v2.json and input/topics.yaml in place? Chosen: copies in files/.
- **DEC-347** (S21, high). Record exactly the sixteen cases S17 listed, or add a usage case for a missing graph file? Chosen: add generate-usage-missing-graph.
- **DEC-349** (S21, high). Which ids does each case's Covers cell declare? Chosen: S17's mapping.
- **DEC-353** (S21, high). What does G19's part line name: the diagnostic form only (S17's wording), or also the 'writes nothing' of a usage error whose <output> is an existing file? Chosen: diagnostic form and the file given as <output>.
- **DEC-354** (S21, high). The two missing-file usage cases named input/missing.yaml and input/missing.json (S17's form), which the run's gate (docs/auto-run/tools/gate.mjs) reports as Validation paths that do not exist. Where ... Chosen: bare names at the workspace root.
- **DEC-356** (S22, medium). With one leaf-parent, how is the package's code divided so phases own disjoint files and the internal mechanisms stay testable apart? Chosen: Slice libraries with package-internal seams.
- **DEC-357** (S22, high). How do topology reads get their connection before activate returns and every later delivery during that delivery (bus-api@v1 G22, G34), while observed subscriptions keep G17's microtask first delivery? Chosen: Two read paths per cell.
- **DEC-358** (S22, high). How does the registry represent a topic reached through a widened reference and at its value type in either order (bus-api@v1 G41)? Chosen: Cells at Object? with per-access conversion.
- **DEC-359** (S22, medium). Where does the TypeError go when an off-type value published through a widened reference fails one subscription's or read's conversion, so it never stops delivery to the others (bus-api@v1 G13)? Chosen: Provider zone's uncaught-error handler, value skipped there.
- **DEC-364** (S23, high). What are the children's ids and OQ prefixes? Chosen: nidana.tooling.codegen and nidana.tooling.lint, prefixes TA and TB.
- **DEC-367** (S23, medium). Does a builder write a committed catalog entry point (which would join topic-codegen@v1 as a file layout), or does catalog generate a transient one? Chosen: catalog writes a transient entry under .dart_tool.
- **DEC-371** (S23, high). OQ-T2 remainder: which library holds the claim recognizer that catalog and scan share? Chosen: One package-internal library of nidana_dart_codegen.
- **DEC-374** (S23, high). S23 recommends two ADR touches (ADR-001 item 10 for a contract two leaf-parents produce; ADR-002's stale 'Plugin rules report at INFO severity', which nidana-checks@v1 G1 contradicts for three rules) ... Chosen: Before phase planning.
- **DEC-378** (S24, high). Do nidana.tooling.codegen and nidana.tooling.lint belong in ADR-001's affects, and does nidana.tooling stay? Chosen: add both children, keep nidana.tooling.
- **DEC-379** (S25, high). ADR-002 says plugin rules report at INFO; nidana-checks@v1 G1 declares three rules at WARNING and one at INFO. Which of the two is wrong? Chosen: ADR-002 is wrong, correct it in place.
- **DEC-380** (S25, high). How should ADR-002's Consequences state plugin severity once the INFO claim is corrected? Chosen: State the mechanism, leave per-rule defaults to nidana-checks@v1.
- **DEC-381** (S25, high). Which node does item 3's Owner column name for nidana_dart_codegen and nidana_dart_lint after nidana.tooling's decomposition? Chosen: The owning leaf-parent.
- **DEC-382** (S25, medium). Two more sentences in the injected sections went stale with nidana.tooling's decomposition: Consequences' 'nidana.tooling's phases keep the plugin building' and the Decision preamble's 'what it [the ... Chosen: Fix both in this amendment.
- **DEC-383** (S25, high). Does nidana.runtime's change from internal to leaf-parent (S22) touch anything in ADR-002? Chosen: No change, record that in Amendments.
- **DEC-384** (S25, high). S04 chose item 2's 'clean under fvm dart analyze --fatal-infos' partly because plugin rules were believed to report only at INFO. Does that strictness still hold on the corrected fact? Chosen: Keep --fatal-infos.
- **DEC-385** (S26, high). How is root D4 restated now that nidana.runtime is a leaf-parent (nidana.runtime D1) and nidana.tooling has two leaf-parent children (nidana.tooling D1), keeping D4's id? Chosen: restate in place with dated history.
- **DEC-386** (S26, medium). How does root D1's v1 check table take explicit_topic_type_arguments (nidana-checks@v1 Refinement 4), and which node does each tooling row name? Chosen: split the checks row by host and name the tooling children.
- **DEC-387** (S26, high). Root D1 called the sensitive-flag check 'sensitive flag (warning)'. Keep the word, or restate it against nidana-checks@v1? Chosen: restate as non-blocking.
- **DEC-388** (S26, medium). The three new edges into nidana.tooling (bus-testing@v1, navigation-api@v1, flutter-binding@v1, nidana.tooling D3): add them to the DAG, edge table and matrix only, or also restate the root's ... Chosen: edges and restated dev flow.
- **DEC-389** (S26, high). Root OQ5's detail said server-controlled rewiring is covered by topology-dsl@v1's switchMap, which topology-dsl@v1 Refinement 4 contradicts. Which forms does the reworded detail name? Chosen: the forms topology-dsl@v1 Refinement 4 states.
- **DEC-390** (S26, high). nidana.model's header is stale against its three contracts in more places than the two the brief names (MultiWriterTopic, the single-writer analysis). Correct only those two, or every stale header field? Chosen: every stale header field.
- **DEC-391** (S26, high). nidana.navigation's header names Route and an executor 'protocol' that every platform executor binds. Rename Route only, or restate the Owns against navigation-api@v1? Chosen: restate the Owns against navigation-api@v1.
- **DEC-392** (S26, medium). nidana.flutter's header says FlutterNavigationExecutor implements the navigation-api@v1 protocol 'against the router OQ-F1 selects'. Restate it against flutter-binding@v1 now, while the OQ-F1 row stays OPEN? Chosen: restate against flutter-binding@v1 now.
- **DEC-393** (S26, high). nidana.tooling's Owns says explicit_topic_type_arguments is a check 'which root D1 does not list'. After root D1 lists it, edit that clause or leave it? Chosen: edit the clause.
- **DEC-394** (S26, high). How closely do the root's embedded child blocks follow the child headers? Chosen: structural fields exact, Owns and Isolation as summaries.
- **DEC-395** (S26, medium). The root contract matrix names nidana.tooling as producer of topic-codegen@v1 and nidana-checks@v1, and the contracts' produced_by and consumers frontmatter does not yet carry the tooling children or ... Chosen: name the tooling children and say the frontmatter catches up at reconcile.
- **DEC-396** (S26, high). The Proposed ADRs entries now mention each ADR's in-place amendments. Identify them by date and content, or by the run's step ids? Chosen: by date and content.
- **DEC-398** (S26, high). Overview flow 4 said the nav-resolver 'guards and resolves'. Keep the Guide's order, or follow navigation-api@v1? Chosen: follow navigation-api@v1 Refinement 3.
- **DEC-399** (S26, high). Root D9 still called subject construction 'nidana.runtime's decision (OQ-R1)'. Keep the pointer, or state what was decided? Chosen: state the decided guarantees.
- **DEC-400** (S26, high). Root D2 said Flutter app developers depend in tests on the runtime's testing.dart only. Restate against the contracts? Chosen: all three testing libraries.
- **DEC-401** (S26, high). The OQ-prefix example 'children of nidana.runtime are RA, RB' is hypothetical since nidana.runtime D1. What replaces it? Chosen: nidana.tooling's real TA and TB.
- **DEC-406** (S27, high). Every api and shared-model fixture tree imports package:nidana_contract_check/fixture.dart, the replay tool nidana.model writes in its first phase. Does that import imply an edge? Chosen: no edge.
- **DEC-407** (S27, high). Do the two new edges change the root's Development flow or critical path? Chosen: leave the flow as written.
- **DEC-409** (S28, high). In which order do the three type-level phases land, given that the surface sets cross-reference (topology-dsl@v1's surface names TopologyDefinition; topology-ir@v1's names topology(), TopologyBuilder ... Chosen: topic-model, then topology-dsl with TopologyDefinition, then topology-ir.
- **DEC-410** (S28, medium). How is the replay tool split across phases? Chosen: four phases by first use.
- **DEC-411** (S28, high). Do the tool's behavior and file/cli phases run before the type-level phases or beside them? Chosen: beside them, after nidana.model.2.
- **DEC-412** (S28, medium). Does the tool package declare all of ADR-002 item 3's dependencies in its first phase, or add each when first used? Chosen: whole row in nidana.model.1.
- **DEC-414** (S28, medium). How are the pure-band phases cut and ordered? Chosen: values; recording beside IR values; projection with graphs and claims; analyses beside JSON; renderers last.
- **DEC-416** (S28, high). What does each gate replay beyond the contracts its phase produces? Chosen: every node contract in the phase's dependency closure, at the closure's restriction, plus structure over all nine.
- **DEC-417** (S28, high). How are topic-model@v1 G25 and G26, not executable and left to this node's gates, checked by a concrete fvm gate? Chosen: a purity test in nidana_dart_contracts' test/.
- **DEC-418** (S28, medium). How is nidana_dart_contracts laid out below its three public libraries? Chosen: one directory per area, the DSL as one library with parts.
- **DEC-419** (S28, medium). Which review tier does each phase get? Chosen: tool phases and analyses full-review; declarations gate-only; other pure phases spot-check.
- **DEC-423** (S28, medium). How does the tool avoid a stale workspace resolution showing as a recorded invocation's exit 255? Chosen: run dart pub get --enforce-lockfile once before the file or cli set; a failure is an environment error.
- **DEC-424** (S28, medium). How does the file set find the generator command in a contract's Validation prose? Chosen: the backticked span of the '- file:' bullet that holds {output}, a leading fvm dart or dart run as the tool's own dart.
- **DEC-427** (S28, low). Which order should the shared root workspace list follow, as a proposed convention? Chosen: path order, one member per line.
- **DEC-428** (S28, high). How are the three open questions this node owns recorded? Chosen: RESOLVED rows pointing at the contract guarantees, detail subsections extended.
- **DEC-429** (S28, high). S28's plan fails one item of hsdd-phase-plan's Phase Design Checklist on purpose, 'Phase 1 defines all shared types and contract-bounded interfaces': the replay tool comes first and each contract's ... Chosen: Accept the deviation.
- **DEC-435** (S29, high). nidana.model's plan restricts its gates by --guarantee lists written before G30 and G23 existed: nidana.model.9's topology-dsl list and nidana.model.10 to .13's topology-ir lists omit them, so they ... Chosen: leave the plan; report it.
- **DEC-440** (S29, high). note 4 (the replay tool's command semantics: exit codes 0, 1, 2 and 64, PENDING for every fixture naming an absent package, --set never adds a set, --guarantee with no id for a slug runs none of its ... Chosen: no conventions change; an hsdd-adr step.
- **DEC-441** (S29, high). ADR-003's Consequences say 'whether topic-model@v1 carries one stays OQ-M3', but OQ-M3 is RESOLVED (topic-model@v1 G5). Sweep the line only, or also add a dated Amendments entry as the ADR's earlier in-place edits did? Chosen: sweep the line only.
- **DEC-442** (S29, high). S29 lists wording follow-ups: ADR-001 item 9 ('written in its first phase', and the replay tool's command-line semantics from nidana.model D2), 'first phase' to 'first producing phase' in ADR-001 and ... Chosen: One consistency pass after stage 6.
- **DEC-443** (S30, medium). How are the ten slices of D2 ordered under fp-progression: every slice's pure part in one pure band before any effect phase, or each pure part just before its own slice's effects, with virtual time ... Chosen: Strict bands.
- **DEC-444** (S30, high). Where do start() and shutdown() land, given that the Slices table puts the startup barrier and shutdown in the lifecycle slice, which closes the plan? Chosen: start with the publish path, shutdown incremental (D8).
- **DEC-445** (S30, high). How do gates check bus-api@v1 G38, G39 and bus-testing@v1 G20 ('checked by nidana.runtime's gates'), given that every gate must be an fvm command? Chosen: Package test plus one provider library (D9).
- **DEC-446** (S30, high). Is the delivery slice one phase or several? Chosen: Pure core, registry and cells, publish path; ownership separate.
- **DEC-447** (S30, high). Is the pipeline one phase or two? Chosen: Two phases.
- **DEC-448** (S30, medium). Is activation one phase or two? Chosen: Checks and handles, then wiring.
- **DEC-449** (S30, medium). Where do the small slices go: telemetry (about 100 lines) and the residual lifecycle (startup window, onShutdown, G36 order)? Chosen: Telemetry with test support, lifecycle with module scopes.
- **DEC-450** (S30, high). When does a guarantee join a producing gate's --guarantee list? Chosen: When every case of it can pass.
- **DEC-451** (S30, medium). How are producing phases' gates written: 'node default plus' the replay, or the full command? Chosen: Full command per producing phase.
- **DEC-452** (S30, medium). How are the pipeline phases verified before activation composes them? Chosen: Unit tests against a port of the test's own.
- **DEC-453** (S30, medium). Does the pipeline reuse the delivery core's per-read dedup state, making nidana.runtime.9 depend on nidana.runtime.2? Chosen: Reuse the delivery core's dedup.
- **DEC-454** (S30, medium). Does test support and telemetry (nidana.runtime.13) wait on activation wiring, or run beside it after ownership with a smaller replay? Chosen: Wait on activation wiring.
- **DEC-456** (S30, high). Phase 1 is above the ~400-line PE (about 420 lines). Split it? Chosen: Keep one phase.
- **DEC-457** (S30, medium). Review tiers for the effect phases: full-review throughout, or spot-check for the ownership phase? Chosen: full-review for every effect phase but test support.
- **DEC-461** (S31, medium). S30's gates nidana.runtime.5 to .11 assume the replay tool passes bus_activation_test.dart (bus-api@v1's binding of topology-dsl@v1's live suite) when no case of it falls within --guarantee. Does ... Chosen: agree.
- **DEC-469** (S31, high). The drained entries resolve no OQ, but two citations of OQ-R1 (RESOLVED 2026-10-17 by bus-api@v1 G17) still read as open: ADR-003 item 6 'whichever first-delivery timing OQ-R1 gives', and ... Chosen: sweep both.
- **DEC-470** (S31, medium). note 1 (nidana.runtime.1 is the node's only member-creating phase; the conventions' 'one phase each of nidana.runtime' is nidana.runtime.1): does it change a convention? Chosen: no change.
- **DEC-473** (S32, medium). How to cut nidana.navigation into phases under fp-progression: where the resolver template and resultsFor go, and whether the in-memory router stands alone. Chosen: six phases, template with the guard.
- **DEC-474** (S32, high). Review tier of nidana.navigation.3 (access values, resolveDeepLinks, applyAuthGuard, navResolver, resultsFor), a mostly pure phase. Chosen: full-review.
- **DEC-475** (S32, high). Where do the live resolver replays (G14, G16) land: with the resolver template, or in the final phase with the executor? Chosen: final phase.
- **DEC-476** (S32, high). Which phase replays G9 (the five topic declarations, complete at nidana.navigation.1), whose case needs topic-model@v1's values from nidana.model.8? Chosen: nidana.navigation.3.
- **DEC-477** (S32, medium). Should the executor and the live composition (G14, G15, G16, G24 and the bootstrap test) be one phase or two? Chosen: one phase.
- **DEC-479** (S32, high). Source layout of nidana_dart_navigation below its two public libraries (D2). Chosen: one library per area.
- **DEC-480** (S32, medium). At nidana.navigation.2 to .5 the --guarantee restriction admits no case of in_memory_router_test.dart (the executor suite, G18 to G24). Can those gates replay behavior at all? Chosen: replay restricted, relying on nidana.model D2.
- **DEC-481** (S32, high). How do this node's gates check navigation-api@v1 G26 and G27, which the contract marks not executable? Chosen: a package properties test.
- **DEC-482** (S32, medium). What does NavigationExecutor do when a router violates G18 (a perform that throws, an error event on confirmations), and is that a contract matter? Chosen: no handling, node-local.
- **DEC-483** (S32, high). nidana.navigation.1 comes to about 500 lines, over the ~400-line PE target. Split it or accept it? Chosen: accept, gate-only.
- **DEC-491** (S33, high). Do the two note entries (nidana.navigation.1 creates the workspace member; package_properties_test.dart checks G26 and G27) change a convention, and should the second rename the not-executable lines ... Chosen: no conventions change; Validation lines unchanged.
- **DEC-494** (S34, high). How does the package properties test that checks G18 and G19 find the package's pubspec and sources when it runs under fvm flutter test from the workspace root? Chosen: ancestor search for the workspace root.
- **DEC-495** (S34, high). How is nidana.flutter cut into phases under fp-progression and the PE limit? Chosen: seven phases: declarations; pure core; router; provider and topic widgets; page scope; module observer with widget-test bus; executor and bootstrap.
- **DEC-497** (S34, high). What does the type-level phase nidana.flutter.1 land for widgets and argument checks? Chosen: declarations with final fields, constructors that assign and copy, everything else throwing.
- **DEC-498** (S34, high). Source layout of nidana_dart_runtime_flutter below its two public libraries. Chosen: one library per area, pure core under lib/src/core/.
- **DEC-499** (S34, high). What does each gate replay of flutter-binding@v1? Chosen: surface and reject at .1; behavior restricted to the phase's own dependency closure; unrestricted at .7.
- **DEC-500** (S34, medium). How do pathOf and PageScope recognize a router route (a route a FlutterNavigationRouter built for one of its entries)? Chosen: identity registry (Expando keyed by the built route).
- **DEC-501** (S34, medium). When forwardPlatformRoutes is true, FlutterNavigationExecutor needs WidgetsBinding.instance at construction. Does it initialize the binding itself? Chosen: require the app's bootstrap to initialize it.
- **DEC-502** (S34, medium). Review tier of nidana.flutter.4 (bus provider and topic widgets). Chosen: full-review.
- **DEC-510** (S35, high). Note 1 (nidana.flutter.1 creates the workspace member and edits the shared pubspec.yaml and pubspec.lock, bringing the Flutter SDK packages into the resolution): does it change a convention? Chosen: no conventions change.
- **DEC-512** (S35, high). Step 13 sweep: ADR-002 item 3's row for nidana_dart_runtime_flutter still reads 'a router package only if OQ-F1 selects one', treating OQ-F1 as open, although S34 marked OQ-F1 RESOLVED with no router ... Chosen: sweep the citation in place and record it under Amendments.
- **DEC-513** (S36, medium). How many phases, and how are the four rules cut across them under fp-progression? Chosen: four phases: type level, two pure decision lanes, reporting.
- **DEC-514** (S36, high). Where does D1's recognition helper land: in the type-level phase or in a pure decision lane? Chosen: in nidana.tooling.lint.1.
- **DEC-515** (S36, high). What does each producing gate replay of nidana-checks@v1, given ADR-001 item 9's every-id rule? Chosen: G1 at .1 to .3, G1 to G8 at .4.
- **DEC-516** (S36, medium). How are the four rules' decisions paired into the two parallel lanes? Chosen: the spec's slices: raw string with accessor, type arguments with sensitivity.
- **DEC-517** (S36, medium). Review tier of nidana.tooling.lint.3 (type-argument and sensitivity decisions) Chosen: full-review.
- **DEC-518** (S36, high). Which test harness do the rule tests use, given ADR-002 item 3 lists analyzer_testing and test as the plugin's only dev dependencies? Chosen: AnalysisRuleTest under plain package:test.
- **DEC-519** (S36, high). The run says consuming phases test against real packages or bind a contract's suite, never hand-rolled mocks. What do the rule tests resolve against? Chosen: in-memory recognition stand-ins, real packages through the analyze-* replay.
- **DEC-520** (S36, medium). Which phases wait on the producers' declaration phases (nidana.model.5, nidana.runtime.1)? Chosen: only nidana.tooling.lint.4.
- **DEC-521** (S36, medium). nidana.tooling.lint.1 comes to about 430 lines with tests, past the roughly 400-line PE. Keep it whole or split it? Chosen: keep one gate-only phase of about 430 lines.
- **DEC-522** (S36, high). Does a test guard the plugin's pins and its independence from nidana packages, or is that left to review? Chosen: package_properties_test.dart from .1 on.
- **DEC-536** (S37, medium). Do notes 1 to 3 (the new package and three shared root files; every root analyze loads the plugin from lint.1, exit 4 on a plugin that does not compile; from lint.4 the rules report over every ... Chosen: drop as derived.
- **DEC-540** (S38, medium). How does a third-party package outside the table (added later by a node's D{n}, item 3) get its lower bound? Chosen: probe of the whole planned set plus the package, recorded in the D{n}.
- **DEC-541** (S38, high). What does the ADR say about test being held at 1.33.0 inside ^1.31.1 until the first Flutter member, and about the table on a pin change? Chosen: bind tests to the lower bound and state the move.
- **DEC-542** (S38, high). Item 7 pins the plugin's two packages 'to the exact version the committed lockfile resolves (0.3.18 and 13.3.0 on the current pin)'. Does that wording need the same fix? Chosen: align item 7 with item 4's table.
- **DEC-544** (S39, high). Where do catalog's runner tests get fixture packages that a real runner can load, given that seeded registrations (not compiling, throwing) cannot sit in analyzed code and the Flutter tester needs a resolved package? Chosen: temporary packages resolved alone offline.
- **DEC-546** (S39, high). The registry renderer must call DartFormatter at language 3.13, whose languageVersion is a pub_semver Version; pub_semver is outside ADR-002 item 4's table. Which constraint, or avoid the package? Chosen: pub_semver ^2.2.1 by probe.
- **DEC-547** (S39, high). How do this node's gates check topic-codegen@v1 G20's schema check of the catalog document? Chosen: json_schema dev dependency.
- **DEC-548** (S39, medium). Parse the three commands' arguments with package:args or by hand? Chosen: hand-written pure parsers.
- **DEC-549** (S39, high). Does each phase add the dependencies it first imports, or does the member-creating phase declare them all? Chosen: declare every dependency in nidana.tooling.codegen.1.
- **DEC-550** (S39, medium). Recognizer and scan tests need Dart sources with seeded claims and declarations: where do they live, and do they import the real nidana packages or stand-in libraries with the same package names? Chosen: temp packages with a synthesized package config, real packages.
- **DEC-551** (S39, high). How do this node's gates check topic-codegen@v1 G10 (the registry compiles and analyzes clean under the root lint set, strict modes and --fatal-infos)? Chosen: committed golden registry under test/golden.
- **DEC-552** (S39, medium). How many phases, cut where? Chosen: eleven phases in two lanes.
- **DEC-553** (S39, high). One documents phase waiting on nidana.model.14, or a no-graph phase now and a graph phase after nidana.model.13 and .14? Chosen: split at the model boundary.
- **DEC-554** (S39, medium). The scan as one phase (pure report plus a thin shell) or two (report, then command)? Chosen: one scan phase.
- **DEC-555** (S39, medium). catalog in one phase or two, and on what does its loading depend? Chosen: loading phase beside the claim sites, then the command.
- **DEC-557** (S39, medium). Review tiers per phase. Chosen: .1 gate-only, .2 to .5 spot-check, .6 to .11 full-review.
- **DEC-558** (S39, high). Does the node's default gate include a format check? Chosen: include dart format --set-exit-if-changed on the member.
- **DEC-576** (S40, high). Do the two note entries (the shared root workspace files; pub_semver ^2.2.1 outside ADR-002 item 4's table) change a convention? Chosen: drop both from conventions; route pub_semver to an ADR touch.
- **DEC-578** (S41, high). How does the CI slice run the codegen and the v1 checks over the example and assert their outputs? Chosen: tests of the member that spawn the commands.
- **DEC-579** (S41, medium). What is the failing half of the root's success criterion, 'the v1 static checks pass over it and fail on seeded violations'? Chosen: recorded invocations plus violations seeded beside the example.
- **DEC-580** (S41, high). Where does nidana.integration.8's gate write what catalog and generate produce? Chosen: .dart_tool/nidana_integration/.
- **DEC-581** (S41, medium). How are the seven end-to-end slices and the live replays cut into phases under fp-progression? Chosen: eight phases in four bands with two lanes.
- **DEC-582** (S41, medium). Which producer phase does each phase of this hard-edge consumer wait on? Chosen: per phase: declarations at the landing phase, behavior at the last producing phase.
- **DEC-583** (S41, medium). Which phase first runs the unrestricted `fvm dart run nidana_contract_check --all`, and which run it again? Chosen: first at nidana.integration.6, again at .7 and .8.
- **DEC-584** (S41, medium). Which tier does each phase take, given the integration-node default of full-review? Chosen: full-review except spot-check for .1 and .5.
- **DEC-585** (S41, medium). What does the example app contain? Chosen: Guide Appendix A trimmed to the slices.
- **DEC-586** (S41, high, upstream). Guide Appendix A has the persistence service publish Hydrated on cart.events at startup for the MODULE-scoped checkout-flow; does the example hydrate the cart that way? Chosen: leave cart hydration out and mark Appendix A for upstreaming.
- **DEC-587** (S41, high). Where do the example's topologies live, and which catalog runner records them? Chosen: pure libraries, recorded with dart run.
- **DEC-588** (S41, high). Which phases edit the member's pubspec, the topics document and the root workspace files? Chosen: nidana.integration.1 alone, declaring everything up front.
- **DEC-589** (S41, high). How is the example's registry produced and kept fresh, given that the CI slice diffs the committed lib/topics.g.dart against generate (topic-codegen@v1 G11)? Chosen: committed, staleness checked before build_runner runs.
- **DEC-590** (S41, medium). How does the example keep catalog's static graph comparable with the running app's bus.toGraph()? Chosen: public transformers, one factory, literal page route, containment check.
- **DEC-591** (S41, high). How do the member's VM-style and widget tests run, and how do the bootstrap functions serve both? Chosen: flutter_test only; bootstrap stops short of start().
- **DEC-592** (S41, medium). Which observer is the sensitive-capable one in the observation slice? Chosen: bus-api@v1's TelemetryObserver with observeSensitive.
- **DEC-593** (S41, medium). Where does the guard send an intent while auth.state is still AuthInitializing, as a cold-start deep link meets it? Chosen: a splash route carrying the attempted intent.
- **DEC-595** (S42, high). The three nidana.model contracts' Delivery paragraphs say a consumer's edge waits on nidana.model.3 or nidana.model.5 and name no `hard` edge, while nidana.integration's `hard` edges wait on each ... Chosen: add the hard-edge clause.
- **DEC-596** (S42, high). navigation-api@v1's Delivery says a `hard` edge waits on nidana.navigation.6 (nidana.integration), but the confirm makes nidana.integration.1 a consumer that declares `AppRoutes` against the ... Chosen: name nidana.integration.1's wait on nidana.navigation.1.
- **DEC-598** (S42, high). Notes 1 (the member and the shared root workspace list and lockfile) and 2 (the unrestricted replay first at nidana.integration.6, again at .7 and .8): do they change a convention? Chosen: drop both.
- **DEC-601** (S42, high). Note 5: build_runner 2.16.1 has removed `--delete-conflicting-outputs` and silently rewrites a stale committed output. Does it change a convention? Chosen: drop as node-local.
- **DEC-602** (S42, medium). nidana-checks@v1 In CI says nidana.integration's gate 'runs the same steps' as an app's CI (build_runner, then analyze, catalog and scan into `build/`), while nidana.integration.8 runs build_runner ... Chosen: leave it and report.
- **DEC-603** (S43, medium). How does the run fix the stale and inexact text the stage-6 steps collected, now that every contract is stable and gate.mjs --final already passes? Chosen: Owning skill per artifact, one reconcile sweep for plan lines.
- **DEC-604** (S43, high). Does ADR-002 item 4's constraint table need an amendment to list pub_semver ^2.2.1, which nidana.tooling.codegen D3 declares? Chosen: Leave ADR-002 as is.
- **DEC-606** (S43, high). Should ADR-002 record that build_runner 2.16.1 dropped --delete-conflicting-outputs and silently rewrites a stale committed output (S41 note, S42 optional follow-up)? Chosen: Keep it in nidana.integration D7.
- **DEC-607** (S43, high). Does stating the replay tool's landing phases, its command-line semantics and the 'first producing phase' wording amend ADR-001 in place, or does it need a superseding ADR? Chosen: amend in place.
- **DEC-608** (S43, medium). Item 9 'written in its first phase': state the four landing phases in the ADR, or only point at nidana.model D1 and the conventions' replay-tool list? Chosen: state the phases, citing D1.
- **DEC-609** (S43, high). Where do the command-line semantics go: new sub-bullets of item 9, or a new item 13? Chosen: item 9 sub-bullets.
- **DEC-613** (S43, high). How does item 10 (and Context bullet 1) define 'first producing phase': the first phase produced_by names, or the first phase of the producing leaf-parent that produced_by names? Chosen: first phase of its producing leaf-parent in produced_by.
- **DEC-614** (S43, high). Item 11 'once the producer's first phase has merged': replace with 'first producing phase', or with the phase the contract's Delivery paragraph names for a consumer's edge? Chosen: the Delivery paragraph's phase.
- **DEC-615** (S43, high). The Consequences bullet 'Replaying a contract before its producer's first phase has merged fails with PENDING': re-key it to the first producing phase, or to the producing package's absence? Chosen: the producing package's absence.
- **DEC-616** (S43, medium). Item 9 says which flutter a Flutter binding runs (the SDK of the running dart), and nidana.model.7 says a file command's leading 'fvm dart' runs as the running dart, but nothing says which dart a ... Chosen: leave the ADR silent.
- **DEC-621** (S44, medium). Does the contract say what the key looks like, so a tool can compare up to it, as topic-codegen@v1 allows? Chosen: state its form as observed.
- **DEC-622** (S44, high). Which cross-references does the Private names paragraph cite? Chosen: topic-codegen@v1 and nidana.integration D8.
- **DEC-624** (S45, high). How should the plugin's Running it state the exit codes of a plugin that does not load, so that an app's CI does not read exit 0 as 'the rules ran'? Chosen: codes plus the one reliable outcome.
- **DEC-625** (S45, high). Is In CI's app order (catalog into build/, scan --graph build/topology-graph.json) sound for an app whose own dart analyze reads build/ on a later run, or must the contract tell apps to write elsewhere? Chosen: say nothing.
- **DEC-626** (S45, high). How should In CI's sentence about nidana.integration read, so it is true of nidana.integration without restating its plan? Chosen: name the departures and cite D3, D6, D7.
- **DEC-627** (S45, medium). Should In CI's run without --fatal-infos say what exit 0 then shows? Chosen: add a clause pointing at the new paragraph.
- **DEC-628** (S45, medium). Should In CI also tell apps that commit a registry to check it for staleness before build_runner, which rewrites a stale committed output silently (S42's optional note b)? Chosen: leave it to topic-codegen@v1.
- **DEC-630** (S46, high). How should the app-build paragraph state the stale-registry check so that it can fail on a stale committed lib/topics.g.dart, given that build_runner 2.16.1 rewrites a stale committed output from ... Chosen: before build_runner, generate without --graph.
- **DEC-631** (S46, high). Does any guarantee or recorded invocation depend on the order of the staleness check, so that the amendment needs a guarantee, fixture or recorded case? Chosen: guidance only, no coverage change.
- **DEC-632** (S46, medium). Validation's G11 not-executable line says G11 is 'exercised by nidana.integration's gate comparing its committed lib/topics.g.dart with generate's output'. Does it need the same correction? Chosen: tighten it.
- **DEC-634** (S47, high). Development flow item 1 and the lint lane of item 2: restate in prose only, pointing at nidana.model D1 and nidana.tooling.lint D5, or cite the phase ids the plans use? Chosen: cite the phase ids.
- **DEC-635** (S47, high). Development flow items 3 and 4 (outside the step's list) say nidana.navigation and nidana.flutter start after the runtime ships and nidana.integration runs after every producer ships; nidana.flutter ... Chosen: restate per phase.
- **DEC-636** (S47, high). The critical path sentence names nidana.model, nidana.runtime, nidana.flutter, nidana.integration and says codegen's workspace lane may join it. Is it right against the plans, and if not, how is the ... Chosen: name both tied routes.
- **DEC-637** (S47, high). How is D10 corrected: only the two phrases the step names ('the producer's first phase', fixture.dart with nidana.model's first phase), or also the hard-edge reading and the reason given for typing ... Chosen: restate the whole decision text, dated.
- **DEC-638** (S47, high). The step says ADR-001's ## Amendments section now has four entries, and to count before writing the number. The file holds three top-level entries (2026-10-17; 2026-10-18 after nidana.tooling D1 ... Chosen: three, as the file holds.
- **DEC-639** (S47, high). Outside the step's list, the root's ADR-002 entry names one amendment where ADR-002's ## Amendments now holds three (S25, the S35 citation sweep, S38), and D4 says nidana.runtime's plan has about ... Chosen: fix both as restatements.
- **DEC-640** (S47, high). The replay-tool bullet says 'Where root D10, ADR-001 or a contract says the replay tool or fixture.dart comes with nidana.model's first phase, read this list'. Drop ADR-001 only, or also root D10 ... Chosen: drop both, cite item 9.
- **DEC-641** (S47, medium). The embedded nidana.integration block's Isolation strategy says '`hard` edges to every producer, so it runs after they ship', which nidana.integration D2 refines per phase. Change the embedded block? Chosen: leave it.
- **DEC-642** (S48, high). How should the Owns bullet for the replay tool state where it lands, now that ADR-001 item 9 (as amended in S43) no longer says 'written in this node's first phase'? Chosen: name the four landing phases.
- **DEC-643** (S48, high). How should the 'Inherited from the root' fp-progression bullet read, given D1 replaced 'the first phase lands the type-level skeleton of all three contracts and the replay tool' and S47 rewrote root ... Chosen: restate D1 and root item 1 with the consumer waits.
- **DEC-644** (S48, high). Does the Isolation strategy line make the stale first-phase claim, and should it change? Chosen: leave unchanged.
- **DEC-645** (S48, medium). The Overview names 'the activation-time checks of Spec §3.8 and §7.2' as shared with CI, while root D4 and topology-ir@v1 Refinement 4 name §3.8, §3.11 and §7.2. Fix it here or list it? Chosen: list it.
- **DEC-646** (S49, high). Isolation strategy says 'builds against the model's contracts only, from nidana.model's first phase on (root D10)'. nidana.runtime.1's Depends on column names nidana.model.2 and nidana.model.5. Which ... Chosen: nidana.model.5 for the contracts, .2 and .6 for the replay sets.
- **DEC-647** (S49, high). Isolation strategy says 'the phases that deliver activation also bind the behavior/ fixtures of topology-dsl@v1'. nidana.runtime.11 delivers the activation checks, but only nidana.runtime.12 onward ... Chosen: restate with nidana.runtime.12.
- **DEC-648** (S49, high). Contracts section line: 'Every edge out of this node waits on its first phase ... (root D10); the hard edges wait for the node to ship.' Is it right against the conventions' reading rule, root D10 as ... Chosen: restate per phase.
- **DEC-649** (S49, high). Development flow: correct only 'Virtual time comes next', or restate the flow in the phase plan's order with phase ids? Chosen: restate the whole flow with phase ids.
- **DEC-650** (S49, high). D1 Consequences: the clause calling bus-api@v1's old Interface wording 'a wording for hsdd-reconcile's sweep' is done (S31). Drop the clause, or say so? Chosen: state the current fact and add a dated correction.
- **DEC-651** (S49, medium). D1 point 1 cites a conventions rule, 'phase 1 of a leaf-parent lands every declaration of the contracts it produces', which S29 replaced with each contract's first producing phase (ADR-001 item 10 ... Chosen: fix as a restatement.
- **DEC-652** (S49, high). D5, D6 and D7 (S22) describe bus-api@v1 G41, bus-testing@v1 G16 and G18 in their pre-amend wording, in the present tense, and say the phase plan 'may emit' or 'emits' the amends. S31 applied all ... Chosen: fix as restatements with dated corrections.
- **DEC-653** (S49, medium). The Slices table places 'its recorder' in the virtual time row and 'the startup barrier' with G34 in the lifecycle row, while the plan lands the recorder seam at nidana.runtime.7 and start() at ... Chosen: leave the Slices table.
- **DEC-654** (S50, medium). "Carried into the children's phase plans": both children's plans emitted these entries and hsdd-reconcile drained them. Restate the section as history that points at where each item landed, or remove ... Chosen: Restate as pointers.
- **DEC-655** (S50, high). How to mark the restatements inside D1, D2 and D3, whose numbers must be kept: rewrite the stale sentences in place only, or rewrite them and add a dated note to each decision saying what changed? Chosen: Rewrite plus dated note.
- **DEC-656** (S50, high). D1 point 4 gives phase estimates (about nine for codegen, about three for lint) that the plans exceeded (eleven and four). Leave the estimates, replace them, or show both? Chosen: Estimate and planned count.
- **DEC-657** (S50, high). D2's Replays bullet presents its reading of ADR-001 item 10 for two producers as this node's own, and calls the other reading 'the literal reading'. ADR-001 item 10 now states the rule itself. ... Chosen: Cite amended item 10.
- **DEC-658** (S50, high). How to qualify nidana.tooling.codegen D1 point 3's sentence that the Flutter tester records the same document as dart run, within the one sentence this step may edit, while saying what changed and when? Chosen: Qualify inline with date.
- **DEC-659** (S51, high). How should the Development flow state this node's start condition, which as written has the whole node wait on nidana.model's and nidana.runtime's first phases, while D5 and the plan's Depends on ... Chosen: Phase-level start condition.
- **DEC-660** (S51, medium). D5, which this step may not edit, refers to the Development flow's node-level start condition ('what the Development flow above states for the node'; its alternative 'as the Development flow reads at ... Chosen: Dated Corrected note in Development flow.
- **DEC-661** (S51, high). Overview line 25 says 'about three phases'; the plan has four. Name the count only, or the estimate and the planned count? Chosen: Estimate and planned count.
- **DEC-662** (S51, high). Inherited line 29 says a plugin that does not build fails every root analyze and every gate. ADR-002 Consequences, as amended in S38, says it fails every root analyze under --fatal-infos, and that an ... Chosen: Qualify with --fatal-infos.
- **DEC-663** (S51, medium). D1 (written in S23) puts the application-code test in the recognition helper; the plan lands the helper at nidana.tooling.lint.1 without it and the application-code guard, in each rule's ... Chosen: Name the guard apart, with Corrected note.
- **DEC-664** (S51, high). 'Carried into the phase plan': both items were emitted by this node's plan and drained by hsdd-reconcile in S37. Restate as pointers to where each landed, or remove the section? Chosen: Restate as pointers.
- **DEC-665** (S52, high). How should the Development flow state when the node starts and what each lane waits on, now that the plan's Depends on column names every phase-level wait? Chosen: Phase ids from the plan.
- **DEC-666** (S52, high). What should the drained 'Carried into the phase plan' section say? Chosen: Pointers to where each item landed.
- **DEC-667** (S52, medium). Should the slice diagram's 'skeleton (phase 1)' label cite the phase id? Chosen: Cite nidana.tooling.codegen.1.
- **DEC-668** (S52, high). The Inherited lines say the last producing phase replays every scan-* case and that the scan's replays wait on 'those nodes' first phases', naming only nidana_dart_navigation and ... Chosen: Restate with phase ids and all three packages.
- **DEC-669** (S52, high). The Isolation strategy says every producing phase replays topic-codegen@v1 (schema, file replay, recorded invocations) and the scan-* invocations 'restricted by --guarantee'; the plan runs `--set ... Chosen: Restate by dependency closure with phase ids.
- **DEC-670** (S52, high). The sentence under the Slices table lists topic-codegen@v1's not-executable guarantees as G9, G10, G11 and G19's diagnostic form; the contract's Validation also leaves G2 in part, G19's unchanged ... Chosen: Complete it from both Validation sections.
- **DEC-671** (S52, high). D1 (written in S23, 5b09188) says the Flutter tester 'needs no flutter_test dependency (T5)' and describes the topic-codegen@v1 amendment in the future tense. How should it be corrected against ... Chosen: Qualify point 3 keeping the phrase D4 quotes.
- **DEC-672** (S52, high). D2 (written in S23, 5b09188) says the unresolved findings are reported by the scan as two line codes 'and catalog as stderr warnings'. Checked against nidana-checks@v1 (amendment (g), unresolved ... Chosen: Qualify the warning clause only.
- **DEC-673** (S53, high). Item 1: how should the member-creating phase scopes restate third-party constraints after ADR-002 item 4's S38 amendment? Chosen: name the carets and cite the table.
- **DEC-674** (S53, high). Item 4: from which producing phase does topology-dsl@v1 G30 join the restricted replays? Chosen: nidana.model.9.
- **DEC-675** (S53, high). Item 4: from which producing phase does topology-ir@v1 G23 join the restricted replays? Chosen: nidana.model.12.
- **DEC-676** (S53, high). Item 5: how does nidana.model.6 state the suite-keyed restriction and the empty-selection rule of ADR-001 item 9 as amended in S43? Chosen: restate both rules in the scope, with test cases.
- **DEC-677** (S53, high). Item 5: restate D1, D2 and D3 against ADR-001 as amended and root D10 as restated, and does D2 item 4 also need restating although the brief names only D2's opening, item 2 and closing? Chosen: restate D2 item 4 too.
- **DEC-678** (S53, high). Item 9(b): can nidana.runtime.5's gate replay its restriction if the `TestBus` constructor attaches its recorder while `EnvelopeRecorder.attach` lands only at nidana.runtime.7? Chosen: clarify .5 and .7: the constructor attaches no recorder until .7.
- **DEC-679** (S53, high). Item 9(a): do D8 and D9 disagree with the Development flow S49 restated? Chosen: leave both unchanged.
- **DEC-680** (S53, high). Item 2: which exit codes do D3 item 4 and nidana.tooling.lint.1's Verification state for a plugin that does not build? Chosen: both codes, keyed by cause.
- **DEC-681** (S53, medium). Item 3: should nidana.flutter.1's gate run the pure members' `fvm dart test`, since its `pub get` moves `test` from 1.33.0 to 1.31.1 for every pure member? Chosen: add the four closure members' tests.
- **DEC-682** (S53, high). Item 8: cite ADR-001 item 9 instead of nidana.model D2 for the empty-selection behavior? Chosen: cite ADR-001 item 9.
- **DEC-683** (S53, high). Beyond the listed items, the sweep found plan lines that point at drained governance entries ('the `amend` below', 'governance note below', 'the governance `amend` for ...', 'Governance updates ... Chosen: fix them, with Corrected paragraphs on decisions.
- **DEC-684** (S53, high). Item 6: how to widen the Function references sentence and correct the counts and the In CI attribution? Chosen: widen to 'differs between programs and runners', name both pairs, keep the conclusion.

## Experiments

53 experiments under `docs/auto-run/experiments/`, each with its source and captured output. The finding is the step report's, from the step that ran it (later steps that extended it are listed after).

- **`function-ref-names/`** (S02). A tear-off's toString() carries the function name in JIT and in AOT without --obfuscate (Closure: (int, int) => int from Function 'buildTotal': static.), omits the class of a static method, carries no name for an inline closure; obfuscated release builds rename it. Recorded as evidence for OQ-M1.
- **`lint-mechanism/`** (S02). Both run a one-rule check flagging Bus.instance (dart analyze with a plugins: entry; dart run custom_lint). custom_lint 0.8.1 resolves only with analyzer 8.4.0 and, in one resolution with build, source_gen, build_runner and analysis_server_plugin, holds all of them back (build 4.0.7, source_gen 4.2.4, analysis_server_plugin 0.3.3); without it the same set resolves analyzer 14.5.0, build 5.0.0, source_gen 4.3.1, analysis_server_plugin 0.3.24. sample_app/analysis_options.yaml holds a machine-specific absolute path to the probe plugin.
- **`rxdart-sync-subjects/`** (S02). PublishSubject(sync: true) delivers synchronously. BehaviorSubject and ReplaySubject with sync: true deliver the replay to a new subscriber in the first microtask after listen, then buffered events in order, and synchronously afterwards. A reentrant add to the same sync subject throws StateError; to another sync subject it is delivered depth-first before the first subject's remaining subscribers; deferring it with scheduleMicrotask restores order. BehaviorSubject does not dedup. Stream.multi does not deliver synchronously on listen and a reentrant addSync reorders subscribers.
- **`sdk-workspace/`** (S02). Yes. A two-member workspace with rxdart resolves and runs. A positive fixture under fixture/ analyzes clean; dart analyze --format=machine reports ERROR|COMPILE_TIME_ERROR|UNDEFINED_METHOD on the reject fixture (exit 3); dart test runs a behavior fixture from the workspace root and from inside a member by relative path.
- **`time-source/`** (S02). fake_async controls debounceTime only when the subscription was made inside its zone; timers of subscriptions made outside stay real. clock.now() is virtualized, DateTime.now() is not. Nested fake zones keep separate clocks. A small zone intercepting createTimer and scheduleMicrotask controls debounceTime, throttleTime and delay, captures a sync BehaviorSubject's replay microtask and the Spec §3.4 deferral, and runs tests synchronously; a listener outside the zone needs a real event-loop turn. RxDart 0.28.0 defines no scheduler type (output-rxdart-schedulers.txt).
- **`time-source-flutter/`** (S02). Yes to both: with a pass-through zone, debounceTime fires at tester.pump(300ms); with a virtual zone, tester.pump(1s) leaves it untouched and advanceTimeBy(300ms) fires it.
- **`workspace-flutter-member/`** (S02). Yes: fvm dart pub get and fvm flutter pub get both resolve at the root, dart test passes in the pure member, flutter test passes in the Flutter member, dart analyze at the root reports no issues.
- **`contract-fixtures/`** (S03). Root exclude of hsdd/** hides fixtures from workspace-wide analyze while explicit paths are still analyzed; a nested hsdd/contract/fixture/analysis_options.yaml replaces the root lint set. --format=json gives lowercase codes and 1-based lines at every severity; a line-anchored marker prototype passes the good set and fails wrong-line, extra-diagnostic and wrong-code fixtures (the plausible final_class_extended_outside_of_library is really invalid_use_of_type_outside_library). One value-based conformance library binds under test and under testWidgets; flutter test --no-pub runs it from the pure-Dart root; dart test cannot. Absent-package bindings fail to load and are detectable from package_config. json_schema 5.2.2 handles draft 2020-12. dart run {member} works from the root. An input tree enables an analysis server plugin by relative path, including a workspace-member plugin.
- **`workspace-layout/`** (S04). One resolution with Flutter and test holds analyzer 13.3.0, analysis_server_plugin 0.3.18, build 4.0.11, source_gen 4.2.4, build_runner 2.16.1, test 1.31.1 (flutter_test pins test_api 0.7.12, test_core 0.6.18 caps analyzer <14). Hosted sibling constraints resolve locally and mismatches fail; globs work; pub get in a member writes the root lockfile only. A non-member example/ package fails the root pub get (exit 69); nested members work; pubspec-free examples are part of the member. Excludes hide ref/, docs/, hsdd/; members inherit the root lint set and strict modes. A member's options cannot enable a plugin (plugins_in_inner_options); root-enabled, the plugin reports in every member, stays off fixtures under a nested options file, and fails analyze with exit 3 when it does not compile; its rules report at INFO. The plugin runs from a synthetic package outside the workspace: a hosted dependency on an unpublished sibling fails to load (exit 4), a path dependency loads, open constraints resolve analyzer 14.5.0 there against 13.3.0 in the workspace, exact pins align them and load. build_runner runs in the Flutter member; a command over the same pure generator writes identical bytes; dart run package:executable works from the root. Publish dry-run of a hosted-constraint member fails only on LICENSE; a path dependency is a publish error. An outside app needs dependency_overrides for every unpublished sibling. analyzer_testing 0.3.2 resolves beside analyzer 13.3.0.
- **`time-source-widget/`** (S05). A provider captured in the body is driven by tester.pump; clock.now() starts at the wall-clock time and advances exactly with pump, DateTime.now() does not. A provider captured in setUp is outside the fake zone and not driven. RxDart switchMap never listens to the next inner within the body after a switch; the no-wait switchMap delivers at the right fake time. A pending timer fails the test after the tree unmounts and before tear-downs; descendants dispose first, so an ancestor's shutdown cancels a grace timer a descendant started; a cancelled debounce leaves nothing pending.
- **`virtual-scheduler/`** (S05). debounceTime, throttleTime, delay, sampleTime, bufferTime, Stream.timeout, interval, Rx.retryWhen and a mapper-made Stream.periodic run on virtual time only and leave no timer after cancel. RxDart 0.28's switchMap, switching while an inner is live, chains on cancel()'s root-zone null future, so its next inner is listened only after a real turn, and never inside fakeAsync; a no-wait switchMap keeps exact timing. A listen that re-enters the zone delivers the replay under triggerActions and runs consumer callbacks in the zone; consumer-chained operators are virtual when RxDart makes their timers during delivery, real when at listen. zone.scheduleMicrotask and zone.run(Timer) reach the virtual queue from outside. Drain order matches the event loop; periodic, monotonic, bound and reentrancy checks work; errors go to the scheduler's construction error zone. clock.now() is virtual inside the zone. A captured provider follows fakeAsync and withClock as built. A stub completed outside needs a real turn; settle handles it. A pass-through fork costs 1.3x per delivery. fake_async's elapse spins forever on a zero-period periodic timer.
- **`topic-model-fixtures/`** (S06). Against a stand-in nidana_dart_contracts (Dart 3.13.5): the three surface libraries analyze clean under --fatal-infos; all nine reject files pass the (line, code) rule, every code confirmed (invalid_use_of_type_outside_library for extends and implements of final and sealed classes, non_exhaustive_switch_expression, undefined_method, undefined_getter, argument_type_not_assignable, invalid_assignment, undefined_named_parameter, missing_required_argument, assignment_to_final, const_eval_throws_exception); 40 behavior cases pass under dart test from the root and a --name '^G19 ' filter selects 7; a prototype structure set finds all 26 guarantees covered (24 by fixtures, 2 not executable) and fails a negative control; eight seeded defects in the stand-in each fail the cases of their guarantee; a member added to ObserveContext fails the surface set. The probe found that a const declaration missing a required argument reports three diagnostics on one line and an uninstantiated generic call adds inference_failure_on_function_invocation, so the fixtures avoid both forms.
- **`topology-dsl-fixtures/`** (S07). All 9 reject files pass with one diagnostic per marker (codes confirmed: undefined_getter, undefined_method, invalid_assignment, argument_type_not_assignable, invalid_use_of_type_outside_library, new_with_undefined_constructor_default, undefined_class, undefined_function, could_not_infer, undefined_named_parameter, extra_positional_arguments, not_enough_positional_arguments, non_abstract_class_inherits_abstract_member, invalid_override_of_non_virtual_member, subtype_of_base_or_final_is_not_base_final_or_sealed, must_be_immutable). Both surface files analyze clean under --fatal-infos. The structure prototype covers all 29 guarantees with 66 cases. The recording suite (23 cases) passes against the stand-in recorder; the live suite (43 cases) passes against a stand-in live implementation on RxDart 0.28 and a virtual scheduler. Every seeded defect in either stand-in fails the cases of the guarantee it breaks, including a switchMap that waits for the previous cancel future and one that resumes through a root-zone microtask as RxDart 0.28 does. Adding a stage kind to StageVisitor fails the surface set. probe/ records the single-diagnostic forms.
- **`topology-dsl-typing/`** (S07). write<T>(Topic<T>, TopicStream<T>) compiles an unrelated and a wider stream (T inferred as Object). write<T, S extends T>(Topic<T>, TopicStream<S>) reports one could_not_infer for both and accepts a subtype stream into a supertype topic. A handle-receiver writeTo rejects the sound case and admits the unsound one; a curried form is sound; an invariant typedef rejects sound writes with two diagnostics; horizontal inference through a function literal does not help. reduceInto(StateTopic<S>, TopicStream<E>, S Function(S, E)) rejects mismatches but reports two diagnostics unless type arguments are explicit.
- **`function-ref-derivation/`** (S08). JIT and AOT render 'from Function NAME' for top-level functions, static methods (no class), instance method tear-offs, generic functions, constructor tear-offs ('Box.') and implicit call tear-offs ('call'); inline closures, closures in variables, local named functions and extension method tear-offs render no name. --obfuscate keeps the pattern with obfuscated names stable within the build. dart2js renders 'Closure NAME' with compiler-internal names even for inline closures (main_closure) and minified names at -O4; dart2wasm renders no name at all. The VM-pattern derivation is therefore anonymous on web builds and never false.
- **`topology-ir-fixtures/`** (S08). Against a stand-in of nidana_dart_contracts implementing this Interface (its recorder's plan projection rewritten to the contract's rules): the structure prototype covers all 22 guarantees (41 cases, 1 binding); both surface libraries analyze clean under --fatal-infos; all three reject files report exactly their marked (line, code) pairs, every code confirmed on first write; package:json_schema 5.2.2 and Ajv 8.17.1 (strict) agree that the 7 valid/ files validate and the 38 invalid/ files fail, each at the intended path; the binding passes all 41 cases from the root and from a member directory; the 7 Mermaid goldens parse with Mermaid 11.12.0 and the 7 DOT goldens lay out with Graphviz 14.0.1, and undoing the escapes makes both fail; the Interface example validates and round-trips; regenerating goldens reproduces the committed files; each of 22 seeded defects in the stand-in fails the cases of the guarantee it breaks (two mutations that first survived led to a tightened G6 case, a new G7 case and a replaced G13 mutation); adding a CombinatorKind value fails the surface set; topology-dsl@v1's structure, surface, reject and recording sets still pass against the new projection.
- **`bus-api-fixtures/`** (S09). With a stand-in topic model carrying the proposed MultiWriterTopic and a stand-in runtime on RxDart 0.28 sync subjects: structure PASS for all 39 guarantees (86 cases, 2 bindings, 14 fixture files); surface clean; all 8 reject files PASS with their (line, code) pairs; the bus-api suite passes 86 of 86 and the live suite 43 of 43 on a stand-in TestBus; 38 seeded defects in the stand-in each fail the cases of the guarantee they break (T10), 4 seeded defects fail live cases (T11), including a recorder that drops untraced topics; adding a BusDiagnostic variant fails the surface set (T12).
- **`topic-model-multi-writer/`** (S10). Against the amended stand-in, the topic-model@v1 fixtures at df5e8f8 pass every set (structure 26/26, surface clean, 9 reject files, 40 behavior cases), the amended fixtures pass every set (27/27, 10 reject files, 41 cases), topology-dsl@v1 and topology-ir@v1 surface and reject sets pass as they do without the amendment, bus-api@v1's surface and reject sets pass, and the bus-api suite (86) and topology-dsl@v1's live suite (43) pass. Without the amendment the new topic-model surface and the two changed reject files fail, and bus-api@v1's two publish reject files fail. Seeded defects: MultiWriterTopic abstract instead of sealed fails G1's reject and surface, including the pre-existing three-variant switch; StateTopic as a MultiWriterTopic fails G27's reject and behavior case. Inference: the least upper bound of an event and a replay topic changes from Topic<T> to MultiWriterTopic<T>, so a variable or list inferred from those two alone rejects a later state topic (probe/lub.dart: no diagnostic before, two errors after).
- **`bus-testing-fixtures/`** (S11). With the stand-in topic model of bus-api-fixtures and a stand-in runtime whose testing.dart implements the Interface: structure PASS for all 20 guarantees (45 cases, 1 binding, 7 fixture files) and bus-api@v1's structure still PASS; surface clean under --fatal-infos; both reject files PASS with their (line, code) pairs (undefined_class for G1, invalid_use_of_type_outside_library and new_with_undefined_constructor_default for G2), so no code is unconfirmed; the bus-testing suite passes 45 of 45 under dart test and a --name '^G12 ' restriction selects its 3 G12 cases; bus-api@v1's surface, reject and behavior files analyze and pass against this testing.dart, and its two bindings pass unchanged, 86 and 43 cases, with the names adopted and deterministic ids (T8, T9); each of 34 seeded defects in the stand-in fails the cases of the guarantee it breaks (T10), no run timed out. One first-draft defect was vacuous and was replaced: swapping runGuarded for run in the scheduler's microtask handler changes nothing, because the SDK's scheduleMicrotask and Timer already bind their callbacks guarded; a zone that swallows errors is the defect that breaks G11. Two first-draft cases could hang a broken implementation (an unbounded microtask loop escaping the zone; a feeder timer left running when settle misbehaves); the loop is now capped at 1000 iterations and the feeder cancelled in a finally block, so a defect fails those cases instead of hanging the gate.
- **`navigation-api-fixtures/`** (S12). Surface clean; all six reject files pass with confirmed codes (one pattern_never_matches_value_type warning); structure 27 guarantees, 66 cases, 2 bindings; navigation suite 40/40; executor suite 52/52 on InMemoryRouter (both capabilities) and 26/26 under fvm flutter test with testWidgets against a stand-in Flutter router over Navigator on a production-provider bus; 33 seeded defects each fail the cases of their guarantee.
- **`bus-api-amendment/`** (S13). No fixture outside bus-api@v1 changes. On the stand-in of navigation-api-fixtures with the typed publish and topology reads on a synchronous non-replaying controller: structure passes for bus-api (40 guarantees, 89 cases), bus-testing and navigation-api; every surface clean; every reject code of the three confirmed (publish_value_matches_topic.dart: six could_not_infer and one type_argument_not_matching_bounds); bus-api 89/89, topology-dsl live 43/43, bus-testing 45/45, navigation 40/40, executor 52/52 on InMemoryRouter and 26/26 under fvm flutter test with testWidgets. On the S11 runtime the new G22 connection case and the G34 deep-link case fail and the typed-publish rejects fail. Seeded defects: connection publishes inside activate fail the G22 microtask case and the existing G34 activation-order case; the navigation-api-fixtures read stage fails the G34 case ([41, 51] for [41, 57]); the S11 interpreter fails both new connection cases. The orchestrator's named form publish<T, V extends T> adds inference_failure_on_function_invocation on a state topic and fails navigation-api@v1's reject set; publish<T extends Object?, V extends T> does not.
- **`flutter-binding-fixtures/`** (S14). Navigator: observer callbacks run synchronously inside push, pushReplacement (reported as didReplace), replace, pop and popUntil (P2); the initial routes are reported as pushes, bottom first, and covered routes stay mounted (P3); a platform popRoute pops the top route through WidgetsApp's maybePop, never the root, and PopScope(canPop: false) refuses it (P4); a platform pushRouteInformation is answered by the first binding observer that returns true, else WidgetsApp pushes it by name through onGenerateRoute (P5), and an observer registered after WidgetsApp mounted comes too late (P5b); an unmounted Navigator detaches its observers and reports no pop of its routes (P6); a dialog is an observed push of an unnamed route and popUntil on a route identity pops it (P7); a page's Navigator.maybePop is an observed pop (P8); on the production binding runApp mounts the Navigator only after a timer, so microtasks run before it exists (P1). go_router 18.1.0 resolves on the pinned SDK and brings material_ui, cupertino_ui, flutter_localizations, intl, logging and flutter_web_plugins (R1); its push reaches the Navigator only after a frame (R2); it has no popUntil (R3); it navigates to the platform's initial route by itself (R4); go('/b') over [/, /a] leaves [/, /b] (R5). Fixtures against a stand-in nidana_dart_runtime_flutter, from a pure-Dart workspace root with the fixtures under hsdd/: structure 19 guarantees, 52 cases, 2 bindings; surface clean; 7 reject libraries, every code confirmed; this suite 52 of 52 and navigation-api@v1's executor suite 26 of 26 under fvm flutter test --no-pub; the name prefix 'G10 ' selected 8 cases; 33 seeded defects each failed the cases of the guarantee it breaks. Side finding (tool/widened_observe.dart, output-widened-observe.txt): the stand-in runtime types a subject by the static type of the first access, so reaching a topic through a Topic<Object?> reference and at its declared type on one bus throws a TypeError either way; bus-api@v1's fixtures always use the declared type.
- **`topic-codegen-fixtures/`** (S15). Yes on every count (output.txt T1 to T13). generate over input/ reproduced expected/ byte for byte with and without fvm dart format and from absolute paths (T1 to T3); the library analyzed clean in a stand-in app under lints/recommended, strict modes and --fatal-infos (T4); build_runner 2.16.1 with build 4.0.11 applied ^lib/topics.yaml only, wrote the command's bytes, failed on a rejected document and then deleted the stale output (T5); package:json_schema 5.2.2 and strict Ajv 8.17.1 classified 4 valid and 53 invalid cases as marked, and input/topics.yaml and the 5 parsable rejected/ documents validate (T6, T7); the generator accepted all valid/, rejected all invalid/ and rejected/ with exit 1 and no output, with file:line:column diagnostics (T8, T9); without a graph it wrote the same registry and a catalog without graph rows (T10); usage errors exit 2, an undecodable graph 1 (T11); the page's pre text equals topology-ir@v1 render/checkout.mmd and Mermaid 11.12.0 parses it (T7).
- **`nidana-checks-fixtures/`** (S16). T1: 17 of 17 invocations pass (run.sh, output.txt). T0: the stand-in members (copied from flutter-binding-fixtures) and the plugin's own sources analyze clean under the root lint set, strict modes and the root-enabled plugin with --fatal-infos. T2: every graph document validates against topology-ir@v1's schema (json_schema 5.2.2) and decodes, except scan-graph-undecodable's. T3: a raw machine-format run names the absolute files/ path on 6 lines, which the recording writes {files}. T4: the whole workspace rsynced to another absolute path replays 17 of 17. T5: five seeded defects each fail exactly the cases of the guarantee they break while control cases pass (rules in test/: analyze-clean; sensitivity at WARNING: three sensitive cases; scan reading the document's claims: scan-clean; scan reading test/: scan-clean, scan-topic-name-collision; PageScope unrecognized: writer-conflict, scope-violation, unresolved-claim). P1: the analyzer's display string equals the VM's '$T' for interface, generic, nullable, enum, record, named-record, aliased and map types; function types differ ((String) => int against int Function(String)). P2: dart analyze on a package root or a file reports the plugin's diagnostics; on a subdirectory (lib) it reports none and exits 0. Probes during authoring also showed: a plugin is honored only in the options at a package root; dart run from a directory holding pubspec.yaml runs an implicit pub get that writes .dart_tool and pubspec.lock there; dart run prints no build message on a non-terminal stdout; plugin severities follow LintCode's declared severity or the diagnostics section; // ignore: nidana_dart_lint/{code} and ignore_for_file suppress.
- **`file-invocations/`** (S17). run.sh / output.txt: sixteen candidate cases for topic-codegen@v1's generate (generate-no-graph with expected/topics.g.dart identical to the file replay's and a no-graph topics.md; generate-graph-undecodable; four generate-usage-* cases; ten generate-rejected-* cases from rejected/) passed, 16 of 16; the four cases without files/ ran from the workspace root with root-relative arguments; four seeded defects each failed the case they break. The stand-in creates nothing at {output} on exit 1 or 2.
- **`navigation-api-touch/`** (S19). On the stand-in packages of flutter-binding-fixtures, unchanged (T0; runtime and navigation those of bus-api-amendment, typed publish on both paths): pages.publish and bus.publish of DeepLink(uri) to nav.resolved-intent each report could_not_infer alone, as does a NavIntent-typed value; resolved intents, nav.intent publishes, explicit type arguments publish<NavIntent, DeepLink> and the pre-amendment form compile (T1 Q01 to Q09). The fixtures differ only in reject/resolved_intent_is_never_a_deep_link.dart (T2). Before (6843dc2) and after alike: structure for navigation-api (27 guarantees, 66 cases, 2 bindings) and flutter-binding (19, 52, 2) passes, surface clean, every reject code confirmed, the navigation suite 40/40, the executor suite 52/52 on InMemoryRouter, flutter_navigation_executor_test.dart 26/26 under fvm flutter test --no-pub. The amended ADR-001 structure prototype passes all nine contracts (T3). With both publish signatures reverted to publish<T>(MultiWriterTopic<T>, T), the amended reject set fails on that file alone (the two could_not_infer lines vanish) while the before-touch reject set passes, so the new lines are what pins G40 for this topic (T4).
- **`bus-api-widened/`** (S20). P1: S14's probe throws a TypeError in both orders on the S13 runtime and passes on the patched one. T1, T1b: structure passes (bus-api 41 guarantees, 95 cases; amended ADR-001 prototype: 9 contracts, 0 problems). T2 to T4: surface, reject and behavior libraries of bus-api, bus-testing, navigation-api and flutter-binding analyze as before. T5 (patched): bus-api 95/95, topology-dsl live 43/43, bus-testing 45/45, navigation 40/40, executor on InMemoryRouter 52/52, flutter-binding 52/52 and 26/26 under fvm flutter test. T7 (S13 runtime): exactly the six G41 cases fail (five on _Cell<Object?> cast to _Cell<int>, one on StateWriter<Object?> cast to StateWriter<int>); every other suite passes. T8: four seeded defects each fail the G41 case they break. P2: a widened publish builds MessageEnvelope<Object?>; bus-testing@v1's recorder envelopesOf and payloadsOf, typed by the topic, then throw a TypeError. P3: T == topic.valueType tells whether a call's type argument is the value type (int, List<int>), and that is all a Type offers.
- **`topic-codegen-invocations/`** (S21). E1: 17 of 17 pass with docs/auto-run/experiments/file-invocations/replay.dart; the 14 cases without files/ ran from the workspace root. E2: the file replay is byte-identical to expected/ and the schema check has 63 PASS, 0 FAIL (5 rejected/ documents skipped as not one YAML document, as before). E3: generate-no-graph's expected/topics.g.dart equals expected/topics.g.dart byte for byte, and its topics.md equals expected/topics.md once the graph rows, the three graph sections and the header lines are removed. E4: structure_check.dart reports 0 problems over all nine contracts (topic-codegen: schema 1, file 12, cli 4, not executable 5, in part 2, data directory rejected), and reports both defects seeded into a copy (a case directory with no row; G2 dropped from the rejected rows while its part line stays). E5: six defects seeded into the stand-in generator each fail only the cases of the guarantee they break, and the file replay passes every one of them: a page without a graph and a registry that differs without a graph fail generate-no-graph (G14); creating the output before checking inputs fails the 10 rejected cases and generate-graph-undecodable (G2, G19); usage errors exiting 1 fail the 5 usage cases (G19); a missing graph exiting 1 fails only generate-usage-missing-graph (G19), which S17's sixteen cases would have missed; R3 unenforced fails the two R3 cases (G2; the reserved-word case exits 255 because the stand-in's formatter rejects the invalid Dart it produces). The restored generator passes 17 of 17. E6: with rejected/two-documents.yaml moved away, its case fails with exit 2 instead of passing. Harness fact: copying a workspace member with fresh mtimes (cp -R) makes dart run re-resolve, which fails with exit 255 from a case's files/ (no pubspec.yaml); the script copies with cp -Rp.
- **`off-type-delivery/`** (S22). A cast in onData (sync broadcast controller, sync PublishSubject, sync BehaviorSubject before and after replay, after distinct) goes to the zone's uncaught-error handler; listeners before and after receive the value, add() returns normally, and the failing listener receives the next value. A cast inside map instead becomes an error event on that subscription's onError.
- **`catalog-loading/`** (S23). Results on the pinned SDK with the stand-in nidana_dart_contracts. T1: dart run of the entry in a pure package exits 0 in about 2.6 s and records transformer names from the factory arguments (flatRate). T2: the same entry in a package whose page library imports Flutter exits 254 on dart:ui. T3: flutter test --no-pub runs a parameterless main() in a file outside test/ that is not named _test.dart, writes the document and exits 79 ('No tests ran'), in about 5.6 s; a main(List<String>) fails to compile in the tester's listener. T4: the Flutter tester records a byte-identical document to dart run's. T5: no flutter_test dev dependency is needed. T6: a throwing registration exits 1 under the Flutter tester and writes nothing. T7: dart run --packages from outside the package gives the same document.
- **`plugin-severity/`** (S25). The severity configured for the code in the plugin's diagnostics section wins; otherwise the LintCode's declared severity, which defaults to INFO. registerWarningRule versus registerLintRule decides only default enablement (warning rules run unless disabled, lint rules only when enabled, also by a configured severity). The type is STATIC_WARNING for all. Exit codes: ERROR 3, WARNING 2, INFO 0 or 1 under --fatal-infos. workspace-layout's stand-ins declare no severity; nidana-checks-fixtures' declares WARNING on three codes. Both experiments were right about their stand-ins; nidana-checks@v1 is consistent.
- **`model-gate-commands/`** (S28). fvm dart test packages/{member} and packages/{member}/test both run from the root (cwd is the root, G1, G2); fvm dart run {member} runs from the root (G4); a missing member directory fails (G5); pub get --enforce-lockfile passes with a current lockfile (G6) and exits 65 when a member adds json_schema the lockfile lacks (G7); root analyze --fatal-infos is clean (G8).
- **`model-reconcile-amends/`** (S29). Against ../topology-ir-fixtures' stand-in with the four finding and collision constructors made to sort: the recording suite passes 24 of 24 and the topology-ir suite 42 of 42; the prototype structure set passes both slugs (30 and 23 guarantees covered) and the amended ADR-001 prototype passes all nine contracts. Value equality seeded into a read stage, a write sink, the builder or the plan fails G30 alone; each constructor reverted to keep the order given fails G23 alone; the original order-keeping stand-in fails G23 and nothing else. Both libraries and bindings analyze clean under --fatal-infos on Dart 3.13.5.
- **`runtime-replay-schedule/`** (S30). bus-api@v1: G3 at .5; G4, G11 at .7; G7, G8, G12, G13, G15, G17 to G19, G29 to G31 at .8; G1, G10, G20, G21, G24, G32, G37 at .11; G6, G9, G14, G16, G22, G23, G25, G26, G34, G41 at .12; G33 at .13; G5, G27, G28, G35, G36 at .14. bus-testing@v1: G5 to G8, G10, G11 at .5; G3, G12 to G19 at .13; G4, G9 at .14. Live suite G18 to G29 at .12. 66 of 95 bus-api cases and 23 of 45 bus-testing cases call start(); shutdown() appears in bus-api G8, G18, G36 and bus-testing G5, G9, G14, G17, G18. The classification is a regex over case bodies plus a hand list of activation cases that need no pipeline wiring; it is a planning estimate that the first real gates confirm.
- **`empty-guarantee-selection/`** (S31). E1: a filter that admits a case runs it, exit 0. E2: a filter that admits no case prints 'No tests ran.' and exits 79, a failure to any tool that passes exit codes through. E3: the bare ids G1, G3 ... G37 used as '^(G1|...|G37) ' run the live suite's cases named G18 and G19, so a tool that ignores which suite a binding runs would run topology-dsl@v1 cases before nidana.runtime.12 wires the pipeline. A tool that follows ADR-001 item 9 and D2 (bare ids belong to the replayed slug; a binding's suite slug comes from its import; a binding with no admitted case is not run) passes nidana.runtime.5 to .11.
- **`runtime-reconcile-amends/`** (S31). Patched stand-in (../bus-api-widened/ with four hunks: guarded topology-read conversion, activate rollback, envelopesOf conversion at T, one stub publisher per topic): structure 41 guarantees and 98 cases for bus-api, 20 and 47 for bus-testing; S17's prototype 9 contracts, 0 problems; analyze clean; bus-api 98/98, live 43/43, bus-testing 47/47, navigation 40/40 and 52/52, flutter-binding 52/52 and 26/26 under fvm flutter test. Unpatched stand-in: the two G41 cases for calls and topology reads, the G16 case and the G18 case fail; every other case passes, the new observed-subscription G41 case included. Seeded defects (unguarded read conversion, no activate rollback, envelopesOf skipping other type arguments, envelopesOf skipping off-type payloads, a stub publisher per type argument) each fail the case of what they break.
- **`navigation-stage-names/`** (S32). S1: closures record FunctionRef.anonymous() for the intent map and the withLatestFrom in both forms; tear-offs record resolveDeepLinks and applyAuthGuard; the auth map records principalOf either way; two resolvers of one configuration record equal definitions in every case. S2: the navigation suite passes 40/40 and the executor suite 52/52 on InMemoryRouter with closures and with tear-offs. S3: the error reaches the listening zone's uncaught-error handler and the subscription keeps receiving later events.
- **`navigation-g13-coverage/`** (S33). Fixture diff is the one new case. Structure: 27 guarantees, 67 cases, 2 bindings, G13 by 4 cases. Behavior libraries analyze clean. The new case fails against the closures stand-in (Expected FunctionRef(resolveDeepLinks), Actual FunctionRef.anonymous()) and against a seeded wrapped projection (Expected FunctionRef(_principalOf@21345819), Actual anonymous), with every other case passing; against named stages the navigation suite passes 41 of 41 and the executor suite 52 of 52; pre-amendment fixtures pass 40 of 40 and 52 of 52. T7 side finding: the VM renders a private function or method name with a library key, `_name@{key}`; the key is stable across JIT runs (21497603 twice) but differs under AOT (17497603). Public names, including a public method of a private class, render bare in both.
- **`flutter-phase-facts/`** (S34). F1: both resolution commands exit 0. F2: the member's tests run from the root by path (member dir or its test dir) with the root as working directory. F3: Isolate.resolvePackageUri throws UnsupportedError under fvm flutter test; an ancestor search finds the workspace root. F4: the typed subscription leaves a stale ErrorWidget after an on-type value (F4a), sends the conversion TypeError to the provider zone and marks nothing (F4b), and fails a replay widget's mount for good (F4c); the widened subscription has zero provider-zone errors, reports the build TypeError through Flutter and renders the next on-type value in all three. F5: the stand-in's stub<int> after stub<Object?> throws TypeError; one publisher per topic with writer<T> keeps one claim and a stable writer per type argument.
- **`flutter-reconcile-amends/`** (S35). T0: stand-in packages identical to flutter-phase-facts'. T1: the fixture diff is the five cases and the _guardedBus helper. T2: structure passes, 19 guarantees, 57 cases, 2 bindings (G5 8, G6 4, G7 6, G8 6, G17 7 fixtures). T3: behavior libraries analyze clean. T4: on the stand-in as copied, the new G5, G6, G7 and G17 cases fail (53 pass, 4 fail) and the executor suite passes 26 of 26. T5: on the patched stand-in (topic widgets observe at Object?, route / gives /, stub keeps one publisher per topic), which analyzes clean, 57 of 57 and 26 of 26. T6: a seeded PageScope that rebinds on a bus change fails the new G8 case only (56 pass, 1 fails). T7: pre-amendment fixtures pass 52 of 52 and 26 of 26 on the patched stand-in. T8: '^(G3|G4|G5|G6) ' selects the new G5 and G6 cases (15 cases), '^(G7|G8) ' the new G7 and G8 cases (11), '^G17 ' the new G17 case (6). T9: fvm dart pub get exits 0 from no lockfile with a Flutter member, the lockfile carries flutter from source sdk, and fvm dart pub get --enforce-lockfile then exits 0.
- **`lint-pin-resolution/`** (S36). Without Flutter the workspace resolves analyzer 14.5.0 and test 1.33.0 (L1); adding the plugin's member moves analyzer to 13.3.0 and leaves test at 1.33.0, whose test_core admits analyzer 13 (L2); a member constrained to analyzer ^14.5.0 beside the plugin fails resolution (L3).
- **`plugin-rebuild/`** (S36). Yes: edits under lib/src/ and to lib/main.dart are picked up by the next dart analyze, which recompiles the plugin's AOT snapshot (about 11 s; about 4 s with nothing changed); one synthetic package per path is reused. A plugin that does not compile fails dart analyze with exit 4. Gates need no cache clearing.
- **`plugin-rule-tests/`** (S36). Yes on analyzer 13.3.0, analysis_server_plugin 0.3.18, analyzer_testing 0.3.2 and test 1.31.1: assertDiagnostics matches offset, length and message; resolveFile plus a direct call tests the decision; a test/ library is skipped in memory; a lib/src/ declaration is recognized and a same-named class of another package is not. newPackage must be called before AnalysisRuleTest.setUp.
- **`lint-reconcile-amends/`** (S37). T1: amended fixtures 17 of 17 on the stand-in plugin (analyzer 13.3.0, analysis_server_plugin 0.3.18); analyze-raw-string-topic's stdout is unchanged. T2: committed fixtures 17 of 17. T3: C1 (class-only static fields) and C2 (const or final only, not late) fail amended analyze-raw-string-topic and pass every committed case; D1 (type arguments reversed), D2 (named fields before positional), D3 (named fields against name order) and D4 (alias after the type it names) fail amended analyze-sensitive-fatal-infos and pass every committed case. The analyzer displays a record's named fields sorted by name ('({ApiCredential api, RefreshToken refresh})'), and an alias's {0} shows the aliased type ('Map<String, ApiCredential>' for SessionToken).
- **`constraint-lower-bounds/`** (S38). P0: the full planned resolution (every item 3 row, item 7 pins, rxdart ^0.28.0) holds args 2.7.0, json_schema 5.2.2, matcher 0.12.20, package_config 2.2.0, path 1.9.1, test 1.31.1, meta 1.19.0, rxdart 0.28.0, clock 1.1.3, analysis_server_plugin 0.3.18, analyzer 13.3.0, analyzer_testing 0.3.2, build 4.0.11, source_gen 4.2.4, dart_style 3.1.14, yaml 3.1.4, build_test 3.5.20, build_runner 2.16.1, lints 6.1.0. P1: test and package_config are held by flutter_test's test_api 0.7.12 pin, analyzer_testing, source_gen, build_runner and build_test by analyzer 13.3.0, build by build_test. P2a, P2b: the accepted rule writes test ^1.33.0 and package_config ^3.0.0 at nidana.model.1 and nidana.flutter.1's pub get fails along the planned and tooling-first orders; P2c: package_config ^3.0.0 fails on its own. P3a, P3b: with flutter_test in the root from nidana.model.1 the accepted rule writes the table's constraints and resolves along both orders. P4: carets at P0's versions resolve all 20 reachable member sets from no lockfile; test (1.33.0) is the only declared package above its bound before the Flutter member. P5a, P5b: incremental pub get resolves every stage along both orders, --enforce-lockfile passes after each, and nidana.flutter.1's stage moves test, test_api, test_core (and a transitive analyzer) down. P5c: item 7 read literally pins analyzer 14.1.0 and analysis_server_plugin 0.3.20 when the plugin lands first, and the codegen's ^13.3.0 then fails. P6: both final lockfiles equal P0's in all 88 packages.
- **`plugin-compile-exit/`** (S38). E1: the root analyze, which also analyzes the plugin's broken source, reports that ERROR and exits 3 (Q11c's shape). E2: a clean member analyzed alone exits 4 (R6's shape). E3: WARNINGs in the analyzed files give 2; E4: an ERROR gives 3; E5: INFOs only give 0 without --fatal-infos; E6: 1 under --fatal-infos; E7: plugin restored, an ERROR gives 3. Exit 4 occurs only when nothing analyzed reports a diagnostic.
- **`codegen-plan-facts/`** (S39). A: pub_semver resolves to 2.2.1 in the full planned resolution (already transitive, 88 packages, every direct package at the table); ^2.2.1 resolves from no lockfile with the codegen first, beside the plugin and in the full set; the formatter call compiles and analyzes clean. B: dart run works from an unresolved nested package through the workspace config (B1 to B3); the Flutter tester crashes from an unresolved nested package and from a synthesized config (B4, B9); a package resolved alone without flutter_test or test is refused by the tester (B11) and runs with flutter_test (B13, exit 79); a pure package resolved alone runs under dart run (B12); a self package: import fails in an unresolved package (B6); the root analyze reads nested fixture packages and reports lints there (B7); the analyzer resolves synthesized-config temp packages with no diagnostic (B10).
- **`codegen-reconcile-amends/`** (S40). A1: amended topic-codegen invocations 22 of 22 on the stand-in generator of topic-codegen-fixtures plus a stand-in of catalog's argument handling. A2: committed 17 of 17. A3: AD1 (second --graph replaces the first) fails only generate-usage-graph-twice; AD2 (trailing --graph ignored) only generate-usage-graph-without-value; AD3 (non-JSON graph as a usage error, exit 2) only generate-graph-not-json; AD4 (one argument as the output of no package) only catalog-usage-no-package; AD5 (directory without pubspec.yaml as a package) only catalog-not-a-package; each passes all 17 committed cases. B1: amended nidana-checks invocations 17 of 17 on the stand-in scan and plugin; the analyzer reports URI_DOES_NOT_EXIST and UNDEFINED_CLASS in lib/unresolved.dart and nothing for the prefixed names of the missing import, and the scan reports none of it. B2: committed 17 of 17. B3: a stand-in taking an unresolved publisher invocation for Bus.publisher reports unresolved.dart:16:7 and :20:7 and fails scan-unresolved-claim, passing every committed case (the colliding prefixed topic creation is not exercised by a seeded defect). C: the structure prototype passes all nine contracts (topic-codegen: cli covers 5 ids, 3 in part; nidana-checks unchanged counts), 0 problems.
- **`integration-plan-facts/`** (S41). I1: FLUTTER_ROOT is set and the root package configuration's flutterRoot names the same SDK; the pinned dart is $FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart. I2: dart run nidana_dart_codegen:scan from the root, 6 s. I3: a temporary package outside the workspace with a synthesized package configuration and the plugin enabled by absolute path reports all four rules, exit 2, 9 s. I4: the scan over the example and the seeded package reports topic_name_collision and writer_conflict across them, exit 1. I5: a nested flutter test runs, 3 s, no startup lock. I6: the root analyze reads build/ (root and member) and not .dart_tool/. I7: build_runner 2.16.1 builds over a committed output in a fresh checkout, ignores the removed --delete-conflicting-outputs with a warning, and silently rewrites a stale committed output with exit 0.
- **`reconcile-final-checks/`** (S42). C1: the file-invocations structure prototype reports 0 problems over 226 guarantees in nine contracts; 64 Validation paths, 0 missing; 10 bindings, all listed. C2: the root analyze reports the stray library under the root's `build/` and a member's `build/`, and none under the root's `.dart_tool/`, a member's `.dart_tool/` or `{member}/.dart_tool/nidana_dart_codegen/`.
- **`cli-dart-resolution/`** (S43). Platform.resolvedExecutable is the pinned SDK (3.47.7, Dart 3.13.5), and fvm puts /Users/mohamad.purbo/fvm/versions/3.47.7/bin first on the child's PATH, so 'dart' by name resolves to the pinned SDK, also with PATH stripped of every other dart. No ADR change needed for the cli set's 'dart' first line while gates run the tool through fvm.
- **`function-ref-private-key/`** (S44). The VM renders `@` and the library key after each private identifier (`_hidden@K`, `_format@K`, `Holder._internal@K`, `_Holder@K.`, `_Holder@K._secret@K`); AOT with --obfuscate keeps `@K` after an obfuscated name; dart2js -O1, -O4 and dart2wasm give anonymous. For one library, K is @22518013 under `dart run`, its rerun, another entry file with the same imports, and `dart test`; @21518013 under the Flutter tester; @18518013 under AOT; @28518013 (JIT) and @24518013 (AOT) when six libraries are imported ahead of it; @22518013 when the same six come after it; a copy at another URL in the same process gets @23284448. So K follows the library's URL and how many libraries load before it. Suite: the stand-in of model-reconcile-amends, copied unchanged, passes all 43 cases; structure holds (G9 3 fixtures; nine contracts, 0 problems); the conformance library analyzes clean; a FunctionRef.of that strips the key, or makes a private name anonymous, fails the new case alone; before the amendment the stripping defect passed every case.
- **`nidana-checks-ci-exit/`** (S45). The failure line goes to stderr in both output forms (A2 to A12). With the plugin not loading, the exit code follows the app's other diagnostics: ERROR 3 (A7), WARNING 2 (A6, A12), INFO 0 without --fatal-infos (A4, A11) and 1 with it (A5), and 4 when nothing is reported, with or without --fatal-infos (A2, A3, A9, A10), including an app whose only defect is a violation of the plugin's rule (A8). A loaded plugin on a clean app exits 0 (A1) and reports its rule (A0, A13). So exit 0 with no diagnostic reported, which every exit 0 under --fatal-infos is, implies the plugin loaded; no other outcome tells. Resolution failure (pub exit 69) and compile failure behave alike. Same pins as plugin-compile-exit/ (Dart 3.13.5 under Flutter 3.47.7, analyzer 13.3.0, analysis_server_plugin 0.3.18).

## Assumptions about the owner's intent

These are readings of the owner's instructions that the run acted on without being told. Each one,
if wrong, moves the decisions listed with it.

1. **v1 is the Guide's planned-v1, not everything the Specification describes.** The owner froze the
   Specification for v1 but named no scope. The run took the Guide's own planned-v1 markings as the
   scope and widened it only where the Specification requires a mechanism (root D1; DEC-014 to
   DEC-016). Persistence is out; navigation is in.
2. **"Frozen" allows a local deviation, recorded for upstream.** Where the Specification and Dart
   disagree, or two Specification sections disagree, the run resolved locally and marked the decision
   `would_upstream` instead of stopping. Examples are the live switchMap (DEC-078), lineage per
   published message (DEC-098), the sensitive flag mirroring the topic (DEC-099) and the analysis
   server plugin over custom_lint (DEC-027, DEC-053). Only a change to `ref/` would have stopped the
   run, and none was needed.
3. **Consumers are GoTo Financial app teams first.** Root D2 names Flutter app teams, their CI, and
   pure-Dart domain modules as the consumers, and pub.dev adopters later. The run therefore planned
   publishable packages at 0.1.0 with path or git consumption before publication, and no server-side
   Dart.
4. **"Purbo alone, with coding agents" sets the phase size.** One PE per phase (at most 8 tasks, about
   400 changed lines, one review sitting). Tiers are by risk, with full review where a phase carries
   concurrency, time or a contract's semantics.
5. **The owner's functional-first preference is a planning rule.** The run took it as the ordering
   policy `fp-progression` (types, pure functions, effects, composition) in every plan, and as the
   reason pure bands come before effect phases (DEC-033; nidana.runtime's pure band).
6. **No web URL synchronization in v1.** The Flutter executor targets Flutter's own Navigator, with no
   router dependency (DEC-247). An owner with a v1 web app, or one already on go_router, would decide
   otherwise.
7. **The shape stop is narrow.** The run read "the Specification is silent and no experiment settles
   it" as also requiring that neither the Guide, the Rationale, the owner's facts nor HSDD's rules give
   one option a stated reason (DEC-002). Under a broader reading, DEC-362 (runtime as a leaf-parent)
   and DEC-430 (nidana.model at 14 phases) would have stopped the run.
8. **Plans should be executable without contradiction.** After stage 6 the run spent stage 7 (S43 to
   S53) correcting text the plans and their governance disagreed on, instead of only listing it here
   (DEC-603). The run's goal condition did not require this.

## Proposed upstream changes

Thirty-eight decisions carry `would_upstream: true`. Each was resolved locally, as the run's rules
require, and none touched `ref/`. Below they are grouped by the section of the reference architecture
they would change, with proposed wording. Wording in quotes is a proposal for the owner to edit, not
text the run has applied anywhere. Where several decisions bear on one section they share an entry.

### Specification

- **Spec §2.3, "the bus does not implement stream combinators"** (DEC-078). Proposed addition: "A
  runtime may implement a combinator itself when the platform library's implementation leaves the
  scheduler provider's control; it then keeps the semantics §6.3 states. On Dart this applies to
  switchMap, whose RxDart implementation resubscribes after a root-zone future." Evidence:
  `docs/auto-run/experiments/virtual-scheduler/`, `docs/auto-run/experiments/time-source-widget/`.
- **Spec §2.4 and §3.5, lineage per stage or per published message** (DEC-098, DEC-134). Proposed
  wording for §3.5: "Lineage is computed per published message. A stage with one input passes its
  input's lineage through; combine and withLatestFrom derive a new lineage from their inputs.
  Envelope ids and timestamps are minted when a value is published, so every causationId names a
  published envelope." For the escape hatch: "On a platform that mints envelopes at publish, the raw
  engine receives pipeline values and applies the lineage functions; it does not construct envelopes."
- **Spec §2.4, §3.5 and §9.2, the sensitive flag of a derived envelope** (DEC-099). Proposed wording
  for §2.4: "`sensitive` is the flag of the topic the envelope is published to. A flag propagated
  through a pipeline (§3.5) is diagnostic and does not gate observers; a topic that holds derived
  sensitive data must itself be flagged (§9.2)."
- **Spec §3.3 and §3.10, RxDart timing** (DEC-032, DEC-158). Proposed replacement for §3.3's "no
  machinery beyond `sync: true`": "RxDart's sync subjects deliver a replayed or current value to a new
  listener in a microtask after `listen` returns, throw StateError on a re-entrant add to the same
  subject, and deliver depth-first across subjects; a Dart runtime accounts for all three." For
  §3.10: "A new subscriber receives the current value before any value published after it subscribed.
  On platforms whose streams never call a listener inside `listen`, that first delivery is
  asynchronous and the synchronous read is `getCurrentValue`."
- **Spec §3.6 and §6.3, the combinator table and error operators** (DEC-123). Proposed additions to
  §6.3's table: a `merge` row (several event inputs, lineage passed through per value) and a mapping
  note: "retryWhen is a retry policy on the effectful stream source of a switchMap; onErrorResumeNext's
  fallback is catchError."
- **Spec §3.8, which stages mediate a self-read** (DEC-144, DEC-150). Proposed wording: "A self-read is
  unmediated when a path from a read of topic T to a write of T passes only through stages that are not
  state-bearing. debounce, delay, sample and buffer are state-bearing only with a positive duration,
  which the definition records. The finding names every edge on an unmediated path."
- **Spec §3.9, "the same declaration"** (DEC-167). Proposed wording: "Two activations under one
  topologyId are the same declaration when their TopologyDefinitions are equal. Differences a
  definition does not record, such as closure bodies or scan seeds, are not detected."
- **Spec §3.11 and the lint mechanism** (DEC-027, DEC-053). Proposed wording: replace "custom_lint" with
  "the platform's analyzer plugin mechanism (on Dart, the analysis server plugin API since Dart 3.10)".
  custom_lint 0.8.1 pins analyzer 8.x, which cannot share a workspace resolution with current Flutter.
- **Spec §3.12, dedup and observers** (DEC-159). Proposed addition: "Dedup applies per read. Observers
  and `getCurrentValue` see every publish, including one equal to the current value."
- **Spec §3.13, what the startup barrier holds** (DEC-166). Proposed wording: "Before `start()`, every
  publish is queued: a shell publisher's, a topology's and an unowned one. Activation connections and
  the first values they observe are not publishes and are not held."
- **Spec §4.3, which declaration fields collide** (DEC-168). Proposed wording: "A second declaration of
  a name collides unless its variant, value type, sensitive flag, tracing setting, dedup setting and
  buffer size all match the first."
- **Spec §4.5, topics.yaml** (DEC-273, DEC-274). Proposed additions: "`initial` holds a platform
  expression, or a scalar literal the platform writes as its own literal; Initializing and empty in
  the example are identifiers in scope of the generated file." And, if per-domain files stay in Guide
  C.3: "A generator writes one output per schema file; a schema file may hold several domains."
- **Spec §6.1 and §7.1, switchMap to select between pipelines** (DEC-124). Proposed wording: "Selecting
  between state pipelines is a combine over the configuration topic; between event pipelines, a
  withLatestFrom gate per pipeline joined by merge. switchMap is for effectful stream factories." The
  stand-in showed a switch among shared stages conflicts with replay semantics of reads.
- **Spec §6.3, the stream-factory lint** (DEC-018). Either add a Guide Appendix C row with a status, or
  drop the sentence from §6.3. v1 defers it.
- **Spec §6.5, the TransformEdge sketch** (DEC-142). Proposed replacement: "An edge's inputs are topic
  reads (with their dedup argument) or earlier edges; a write and a reduceInto are edges whose output
  is a topic. The definition's `reads` and `writes` derive from the edges." The sketch with topics at
  both ends cannot describe a pipeline of more than one stage.
- **Spec §6.5, `@Topology` registration** (DEC-365). Proposed wording: "Build-time registration is a
  platform mechanism; on Dart, a registration library the app writes that constructs each topology
  with its arguments." Dart cannot declare an annotation named Topology beside the class.
- **Spec §7.1 and §7.3, scope holders** (DEC-249, DEC-253). Proposed additions: §7.3 "A module stays
  active while any route of its subtree is on the navigator's stack, covered or not." §7.1 "Two mounted
  page scopes naming one topology id share one activation; the topology ends when the last of them
  unmounts."
- **Spec §11.2, test teardown and the Flutter row** (DEC-085, DEC-257). Proposed: the test row reads
  "shut down before the test body ends, from the dispose of a widget above every scope binding" for
  widget tests; add a Flutter row "the owning provider's dispose; AppLifecycleState.detached does not
  end the domain".
- **Spec §11.3 and §2.5, maxTopics and getCurrentValue** (DEC-169). Proposed wording: "Activation over
  maxTopics throws. Any other access over the cap creates the topic and reports a dev-mode
  diagnostic, so `getCurrentValue` keeps its never-throws rule."
- **Spec Appendix A.6, the route type and intent semantics** (DEC-219, DEC-221). Proposed: name the type
  NavRoute (Route collides with Flutter's widgets library); state the stack meaning of each intent:
  "GoTo pushes; Replace replaces the top; Back pops; BackTo pops to the topmost entry of its route;
  ShowModal pushes a modal; DismissModal pops one."

### Guide

- **Guide §3.4, guard order and router** (DEC-217, DEC-247). Proposed: resolve a deep link first, then
  guard the resolved intent (the Guide's order lets a deep link bypass the guard); show the Flutter
  executor over Navigator, with go_router as an app-side NavigationRouter.
- **Guide §6.3 and Appendix B.3, combining reads and declaring topologies** (DEC-029, DEC-122).
  Proposed: the Dart example uses the DSL's `combine2` on the builder, not `Streams.combineLatest2` on
  handles, which the recorder cannot see; and a topology subclass is declared `final class` over the
  `Topology` base class, so no type implements Topology with a definition unrelated to its
  declaration (Spec §6.5).
- **Guide §6.5, EventLoopScheduler** (DEC-028). RxDart 0.28 defines no scheduler type; proposed: "On
  Dart the provider is a zone plus `package:clock`; RxDart's time operators honor it when the
  subscription is made inside that zone."
- **Guide Appendix B.1, navigation ADTs** (DEC-030). Proposed: list NavIntent, RouteState and
  NavigationTopics under the navigation package, consistent with §3.3 and §3.7.
- **Guide Appendix B.2, the package list** (DEC-026, DEC-052). B.2 has no test-utilities or telemetry
  package, which §6.5, §10.1 and C.4 name. Proposed: either add them or say TestBus ships in the
  runtime package's `testing.dart`.
- **Guide Appendix C.1 to C.3, where the workspace scan runs** (DEC-061). Proposed: the aggregate checks
  run in the codegen tool beside graph emission; the analyzer plugin keeps per-library rules, because
  a plugin resolves outside the workspace.
- **Guide Appendix C.3, the generated file name** (DEC-273). Proposed: one generated library per schema
  file (`lib/topics.g.dart`), not one per domain.
- **Guide Appendix A, cart hydration** (DEC-586). The persistence service publishes `Hydrated` on
  `cart.events` at startup for the MODULE-scoped checkout-flow, which is not active until the user
  enters the module, so the event reaches no reducer (Spec §3.13, §7.4). Proposed: hydrate the cart
  into an APPLICATION-scoped state topic, or have checkout-flow read a retained hydration state on
  activation.

## Known residue

These inexact or deferred items are left as they are, each with the decision or the reason:

- **The nine contracts' provenance bullet** still says the replay tool comes with nidana.model's first
  phase. The tool lands over .1, .2, .6 and .7, and the Delivery paragraphs and conventions say which
  set lands where (DEC-605).
- **`pub_semver ^2.2.1` is not in ADR-002 item 4's table.** nidana.tooling.codegen D3 records the
  probe, as item 4 allows for a package outside the table (DEC-604).
- **build_runner 2.16.1's dropped flag and silent rewrite** are recorded in nidana.integration D7 only
  (DEC-606).
- **ADR-003's `## Amendments` does not list the S29 and S31 citation sweeps** that hsdd-reconcile's
  step 13 made in its text.
- **The conventions' reading rule for "the producer's first phase"** still names texts that no longer
  use the phrase (S47). It is harmless.
- **nidana-checks@v1's In CI** opens the app sequence with build_runner and does not point at
  topic-codegen@v1's staleness check, which now runs before build_runner (S46). It does not contradict
  it.
- **Slice tables and diagrams** in nidana.runtime and nidana.tooling.lint keep slice-level labels
  ("phase 1", the recorder in the virtual-time slice), which the restated Development flows map to
  phases (S49, S51).
- **nidana.tooling.lint's tests on `test` 1.31.1.** nidana.flutter.1's gate now reruns the pure
  members' tests after it moves `test` from 1.33.0 to 1.31.1, but if every lint phase merges before
  nidana.flutter.1, lint's tests never run on 1.31.1. Closing that needs a dependency edge, which the
  sweep could not add (S53). nidana.tooling.codegen's tests do rerun, because codegen.8 waits on
  nidana.flutter.1.
- **Delivery wording against the gates.** topology-ir@v1's Delivery paragraph says G23 lands at
  nidana.model.10, while its first replay is at .12; topology-dsl@v1 says G30 holds from .4, first
  replayed at .9 (S53). Both are true; one sentence each would line them up with the gates.

## Notes on the record

- **Timestamps.** From S09 to S16 the orchestrator stamped its own decisions and run lines with local
  time (UTC+7) labelled as UTC. `docs/auto-run/timestamp-corrections.md` gives the corrected bounds;
  the ledger is append-only, so the lines stay as written, and `ledger.mjs` has rejected future times
  since (DEC-321).
- **DEC-003's question text** quotes the owner's banned phrase, because it records the ban. The ledger
  is append-only; this report paraphrases that one line.
- **Superseded evidence.** S04's evidence for "plugin rules report at INFO" generalised from a
  stand-in; `docs/auto-run/experiments/plugin-severity/` (S25) supersedes it, and ADR-002 was corrected.
- **Plan decisions.** Decisions of step type `plan` were taken by the orchestrator: DEC-005 to DEC-010
  (S01) and DEC-603 to DEC-606 (stage 7). Their artifact is the execution plan.
- **Inserted steps.** S10, S13, S27, S38, S46 and S52 were inserted when a step found a gap; the change
  log in the execution plan says why for each.

## How to record a review

Append one JSON object per line to `hsdd/judgement/decision-reviews.jsonl` (create the file with the
first review):

```json
{"decision": "DEC-362", "at": "2026-10-20T09:00:00Z", "review": "agree", "reason": "ADR-002 item 3 settles it."}
```

- `decision`: the id from `hsdd/judgement/decisions.jsonl`.
- `at`: when you reviewed it, UTC.
- `review`: one of `agree`, `disagree`, `should-have-asked`. `should-have-asked` means the decision
  may be right but the run should have stopped for it. It is the signal for tightening the stop set or
  the `would_have_asked` judgement.
- `reason`: one sentence.

One line per decision you have a view on; silence is not agreement. The order above is a suggested
reading path: the stops-on-behalf list, then low confidence, then `tree` and `upstream`, then the
`would_have_asked` list.
