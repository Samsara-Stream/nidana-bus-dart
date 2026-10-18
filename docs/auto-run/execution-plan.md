# Automatic HSDD planning run: execution plan

The record of the path this run takes, from settling the inputs to the last
reconcile. It is not a promise: the targets of every stage after the root
decomposition depend on what the root produces, so the step log at the end
grows as steps run, and the change log says what moved and why.

- **Repository:** nidana-bus-dart, branch `auto/v1-planning` (from `main` at `1558e96`).
- **Inputs:** this repository; `ref/nidana-docs/arch/nidana-bus-ref-arch-{spec,guide,rationale}-v0_15_0.md`
  (Spec normative and frozen for v1; Guide and Rationale informative); the HSDD v0.10.0 skills under
  `.agents/skills/`; `~/git/hsdd/docs/users-guide.md` and `~/git/hsdd/spec/hsdd-spec-v0_10.md`; the
  Dart 3.13.5 / Flutter 3.47.7 SDK through fvm; public package documentation.
- **Out of bounds:** older `arch/` versions, `ref/nidana-docs/loop/`, `~/git/nidana-bus-dart`, `~/tmp`,
  Claude memory directories, `~/git/hsdd/docs/superpowers/`, anything describing the manual run.
- **Finish line:** every leaf-parent has a phase plan, reconcile has drained every pending governance
  update, `docs/auto-run/REPORT.md` is committed. Or `hsdd/judgement/STOP.md` is committed and the run ends.

## How a step runs

One step is one HSDD skill invocation on one node, one contract or one ADR, in a fresh general-purpose
subagent. The orchestrator runs no skill in its own context.

1. **Dispatch.** The prompt carries the skill and its arguments, the target, the files it may read, the
   full text of `docs/auto-run/step-preamble.md` (the Blindness section and the Decision policy verbatim,
   the owner's facts, the stop rules for a subagent, the report format), and the step's own section. The
   subagent writes its artifacts and its report to `docs/auto-run/steps/<step_ref>.json`, never commits,
   never writes under `hsdd/judgement/`.
2. **Skill stop.** When the skill stops and asks, the subagent ends its turn with the question verbatim.
   The orchestrator decides as the owner's stand-in, records the decision (`would_have_asked: true`, its
   `stop_class`) in `docs/auto-run/steps/<step_ref>.orchestrator.json`, and dispatches a new subagent
   with the answer (report `<step_ref>.r2.json`). One step may therefore take several dispatches.
3. **Run-stop candidate.** When a subagent reports one of the four run-stop conditions, the orchestrator
   judges it. If it holds: write `hsdd/judgement/STOP.md`, commit, end the run. If it does not: record
   why as a decision and continue.
4. **Gate.** `node docs/auto-run/tools/gate.mjs --skill <skill> [--node <id>] [--pending-adr ...]
   [--contracts-pending]` before committing. It checks the step's changed files against the skill's write
   set (frozen governance only through its owning skill; phase planning writes only its own node's file),
   that `hsdd/scripts/gen-registry.mjs` is a verbatim copy and regenerates the registries clean, that
   every cited ADR, contract, OQ and phase id resolves (ADRs proposed but not yet materialized, and
   contract ids named before the contract stage, are warnings), that every child named by a
   `Decomposes into` line has a spec file, that every contract's Validation paths exist. Then the
   orchestrator reads the artifacts against the subagent's self-check and the skill's own quality gates.
5. **Rework.** A failed gate is reworked once in a new subagent with the finding stated (report
   `<step_ref>.rw.json`). A second failure stops the run.
6. **Commit, twice.** First `hsdd: <step_ref> <skill> <target>` with the step's artifacts (`hsdd/` and any
   `docs/auto-run/experiments/<name>/`). Then the ledger: `node docs/auto-run/tools/ledger.mjs decisions
   <step> <step_ref> <sha> <report>` for each report in dispatch order (subagent, orchestrator answer,
   resumed subagent), `ledger.mjs run ...` for the run log line, `ledger.mjs validate`, and commit
   `judgement: <step_ref>` with `hsdd/judgement/` and the step's reports under `docs/auto-run/steps/`.
7. **Context.** After any summarization: re-read this file, the last twenty lines of
   `hsdd/judgement/decisions.jsonl`, and `git log --oneline -20` before continuing.

The orchestrator's own decisions (setup, plan, stop answers, run-stop judgements) go through the same
ledger tool from a JSON file under `docs/auto-run/steps/`.

## Stages

### Stage 0. Settle the inputs (S00, setup, orchestrator)

- **Reads:** the repository, the three v0.15.0 files, the HSDD skills, users-guide and methodology spec.
- **Done when:** the inputs, their authority, and the run's reading of its own stop rules are written
  down here and in the ledger.
- **Decisions:** how the reference architecture enters the root spec (sources and authority); how the
  tree-shape stop condition is read; how the owner's prose rules apply to HSDD artifacts.

### Stage 1. This plan (S01, plan, orchestrator)

- **Done when:** this file, `docs/auto-run/step-preamble.md` and `docs/auto-run/tools/` are committed
  before any skill runs.
- **Decisions:** planning order; reconcile cadence; phase-plan order; which HSDD skills this run does not
  run; step granularity; who runs experiments; the gate.

### Stage 2. Root decomposition (S02, hsdd-spec, root)

- **Skill and arguments:** `hsdd-spec`, root mode: "Write a high-level system spec for nidana-bus-dart,
  the Dart/Flutter implementation of the Nidana Bus reference architecture v0.15.0, from
  `ref/nidana-docs/arch/` (Spec normative and frozen for v1; Guide and Rationale informative)."
- **Reads:** the three v0.15.0 files in full; `.agents/skills/hsdd-spec/` and its conventions template;
  the HSDD users-guide and methodology spec; `.fvmrc`, `.gitignore` (the workspace intent it records).
- **Done when:** `hsdd/spec/{root}.md` with `## Sources`, overview, child table, typed DAG in Mermaid,
  dev flow, contract matrix, open questions; one `hsdd/spec/{child}.md` per child; `hsdd/conventions.md`
  seeded from the template with `**Coding method:** superpowers`, `**Teams:** single-team`, the ordering
  policy and the OQ prefixes; every hsdd-spec quality gate holds; gate passes with `--contracts-pending`
  and the proposed ADR ids as pending.
- **Expected decisions:** the root id; v1 scope (which of Guide Appendix B's layers and Appendix C's
  planned-v1 tools are in, which are deferred); who the package consumers are; the decomposition axis
  under one owner (the "who builds what?" stop is answered by the owner's facts); the child set, their
  kinds and the integration node; the ordering policy; which cross-cutting decisions become proposed
  ADRs (candidates the run already expects: reactive engine and subject construction, time source and
  virtual scheduler, package and workspace layout, contract validation format for Dart API contracts,
  dev-mode diagnostics); which open questions are minted, from Guide §10 and from the Spec's silences.

### Stage 3. Root ADRs (S03.., hsdd-adr, one per ADR the root proposed)

- **Skill and arguments:** `hsdd-adr`: "Materialize and accept ADR-{nnn} {title}, proposed by
  hsdd/spec/{root}.md."
- **Reads:** the proposing spec, the affected node specs, the Spec and Guide sections the ADR rests on.
- **Done when:** `hsdd/adr/{nnn}-{slug}.md` with `status: accepted`; `Governed by` on every affected
  node; the generator copied verbatim on first use; `hsdd/adr/INDEX.md` regenerated; any OQ it resolves
  updated in its owning spec.
- **Expected decisions:** the decision itself (alternatives and why), its consequences per node,
  experiments where it rests on runtime behavior (stream sync delivery, microtask ordering, zones and
  fake_async, analyzer plugin support).

### Stage 4. Root contracts (S.., hsdd-contract, one per contract id on an edge between root children)

- **Skill and arguments:** `hsdd-contract`: "Define the {slug}@v1 contract: {owner} produces it,
  {consumers} consume it, as named in hsdd/spec/{root}.md."
- **Reads:** the root spec, producer and consumer node specs, governing ADRs, the Spec sections the
  interface implements.
- **Done when:** `hsdd/contract/{slug}.md` at `status: draft`, `phase_ids: provisional`, with Interface
  concrete enough to mock, Guarantees, Versioning, Validation; schema and the kind's fixtures written at
  the canonical paths in the format the validation ADR fixes; registry regenerated.
- **Expected decisions:** interface shape, guarantees, compatibility mode, kind, fixture set.

### Stage 5. Mid-level decomposition (per internal node, DAG order)

For each internal child, in producer-first order: `hsdd-spec` on that node (step `mid-level-spec`),
then one `hsdd-adr` step per ADR it proposes, then one `hsdd-contract` step per contract on an edge
between its children. Repeat until every leaf is a leaf-parent. Same done-when as stages 2 to 4, at the
node's level. Expected decisions: the node's children and kinds, depth, its integration node, node-local
`D{n}` choices, contracts between its children, OQs it owns.

### Stage 6. Phase plans, each followed by its reconcile

For each leaf-parent in producer-first order (a node whose produced contracts others consume plans
before them):

- `hsdd-phase-plan` on the node (step `phase-plan`). Reads: conventions, the node spec, its Sources
  (the actual Spec and Guide sections), the contracts it consumes and produces, governing ADRs, sibling
  node specs (never sibling phase plans). Done when: `## Phase Plan` opens with the default gate and the
  summary table, phase sections follow the template, Mermaid phase graph, every producing phase's gate
  replays its contracts, tiers assigned, sizing floor applied, pending-governance section emitted; the
  gate passes with `--skill hsdd-phase-plan --node <id>` (only that node's file changed). Expected
  decisions: phase cut, sizes, tiers, default gate command, merge or split under the floor, every
  `request` assumption and `amend`.
- `hsdd-reconcile` (step `reconcile`) on that plan's pending section. Done when: confirms applied,
  requests answered and applied under hsdd-contract rules, non-breaking amends folded in, contracts
  with both sides confirmed flipped to `phase_ids: final` and, with their artifact present, `stable`;
  section stamped; registry regenerated. A cross-cutting answer becomes its own `hsdd-adr` step, a
  contract change too large for reconcile its own `hsdd-contract` step. A collision or a breaking
  amend stops the run.

### Stage 7. Final reconcile sweep (hsdd-reconcile, whole tree)

Only if anything remains provisional, draft or pending after stage 6: one reconcile pass over the whole
tree. Done when `node docs/auto-run/tools/gate.mjs --final` passes.

### Stage 8. Report (orchestrator)

`docs/auto-run/REPORT.md` per protocol step 9, committed. Then the run stops.

## Step log

| Step | Stage | Skill | Target | Status | Artifact commit |
|------|-------|-------|--------|--------|-----------------|
| S00 | 0 | none (orchestrator) | inputs | done | b3e5c86 |
| S01 | 1 | none (orchestrator) | this plan | done | this file's first commit |
| S02 | 2 | hsdd-spec | nidana (root) | done | f127e15 |
| S03 | 3 | hsdd-adr | ADR-001 executable validation for Dart API contracts | done | 1fc3a48 |
| S04 | 3 | hsdd-adr | ADR-002 package and workspace layout | done | 8c90ba5 |
| S05 | 3 | hsdd-adr | ADR-003 time source and virtual scheduler | done | 435a18b |
| S06 | 4 | hsdd-contract | topic-model@v1 | done | ba86d16 |
| S07 | 4 | hsdd-contract | topology-dsl@v1 | done | b14b2e9 |
| S08 | 4 | hsdd-contract | topology-ir@v1 | done | 03fe7c9 |
| S09 | 4 | hsdd-contract | bus-api@v1 | done | f5ad95c |
| S10 | 4 | hsdd-contract | topic-model@v1 amendment: sealed MultiWriterTopic (for bus-api@v1 G11, G19) | done | ef0dead |
| S11 | 4 | hsdd-contract | bus-testing@v1 | done | 9f64d62 |
| S12 | 4 | hsdd-contract | navigation-api@v1 | done | 9371c72 |
| S13 | 4 | hsdd-contract | bus-api@v1 amendment: pre-start connection guarantee, publish typing, S11 wording fixes | done | 5727b7d |
| S14 | 4 | hsdd-contract | flutter-binding@v1 | done | cd3b670 |
| S15 | 4 | hsdd-contract | topic-codegen@v1 | done | 4e8031f |
| S10..S14 | 4 | hsdd-contract | bus-api, bus-testing, navigation-api, flutter-binding, topic-codegen, nidana-checks (all @v1), in that order | planned | |
| S17 | 4 | hsdd-adr | ADR-001 update: plan-interpretation wording, data directories in the structure set, coverage wording for file and cli contracts, cases without files/ | done | 5385a5f |
| S18 | 4 | hsdd-adr | ADR-003 update: affects gains topology-dsl@v1 (and its Governed by) | done | 376ccc4 |
| S19 | 4 | hsdd-contract | navigation-api@v1 touch: G1 reject line, citations of bus-api@v1 G22, G34, G40, the Flutter executor binding name | done | 31fc505 |
| S20 | 4 | hsdd-contract | bus-api@v1 touch: widened Topic<Object?> reference case, cite nidana-checks@v1 G5 | done | 27ce541 |
| S21 | 4 | hsdd-contract | topic-codegen@v1 touch: catalog's claim rule aligned with nidana-checks@v1's recognizer; recorded invocations for G2, G14, G19 under amended ADR-001 item 7 | done | ca0d8ff |
| S22 | 5 | hsdd-spec | nidana.runtime (mid-level): became a leaf-parent; no children, ADRs or internal contracts | done | 5e6e053 |
| S23 | 5 | hsdd-spec | nidana.tooling (mid-level): two leaf-parents, codegen and lint; no ADRs or internal contracts | done | 5b09188 |
| S24 | 5 | hsdd-adr | ADR-001 update: item 10 for a contract two leaf-parents produce | done | cd87e32 |
| S25 | 5 | hsdd-adr | ADR-002 update: stale plugin-severity consequence; tooling children as owners and in affects | done | 6aa8688 |
| S26 | 5 | hsdd-spec (root refresh) | root D1 check table (explicit_topic_type_arguments), D4 (runtime leaf-parent, tooling children), OQ5, three new tooling edges (bus-testing, navigation-api, flutter-binding), embedded summaries and Sources, conventions' RA/RB example | done | 9239917 |
| S27 | 5 | hsdd-spec (touch) | topology-ir@v1 edges into nidana.navigation and nidana.flutter (headers, root DAG, edge table, matrix) | done | b39c80d |
| S28 | 6 | hsdd-phase-plan | nidana.model | running | |
| S29 | 6 | hsdd-reconcile | nidana.model's pending section | planned | |
| S30.. | 6 | hsdd-phase-plan then hsdd-reconcile | nidana.runtime, nidana.navigation, nidana.flutter, nidana.tooling.lint, nidana.tooling.codegen, nidana.integration, in that order | planned | |

## Change log

- 2026-10-17: first version, written before any skill ran.
- 2026-10-17, after S02: the root has six children (nidana.model, .runtime, .navigation, .flutter, .tooling,
  .integration); two are internal (runtime, tooling), so stage 5 has two mid-level decompositions, runtime
  first. Stage 3 has three ADRs; stage 4 has nine root contracts, authored producer-first (model's three,
  runtime's two, navigation, flutter, tooling's two). Several child OQs (OQ-M1..M3, OQ-R1..R3, OQ-N1, OQ-N2,
  OQ-F1) wait on the contract step that settles them; hsdd-contract cannot write node specs, so each
  contract step reports which OQ it settled and the owning node's next spec or plan step, or a reconcile
  sweep, marks the row. Contract steps add `Governed by: [ADR-001]` (and ADR-003 where it applies).
- 2026-10-17, after S03: the gate tool now skips orchestrator-owned files (this plan, REPORT.md, tools/),
  which S03's gate flagged because the orchestrator had edited this plan while the step ran. ADR-001 adds
  follow-ups: ADR-002 must add `hsdd/**` to the root analysis excludes and `json_schema` to the replay
  tool; contract steps write `G{n}` guarantee ids and `Governed by: [ADR-001]`; the first contract step
  writes `hsdd/contract/fixture/analysis_options.yaml`; bus-api@v1 carries the binding of topology-dsl@v1's
  suite and flutter-binding@v1 the binding of navigation-api@v1's executor suite (producer-first order
  already writes each suite first).
- 2026-10-17, after S04: ADR-002 moves the workspace scan (every check over more than one library or the
  IR) into `nidana_dart_codegen` as a command entry, so nidana-checks@v1 covers two hosts; the plugin
  depends on no nidana package. nidana.model's first phase must create the workspace root (root
  `pubspec.yaml`, `analysis_options.yaml`, `pubspec.lock`), and every phase that adds a member edits the
  root workspace list: phase plans must carry Collides-with entries for that. Passed on to the
  model and tooling steps.
- 2026-10-17, after S05: ADR-003 settles the Dart time source (provider = zone + clock; nidana's own
  VirtualScheduler; the runtime owns a live `switchMap` that does not wait on cancel futures, marked for
  upstreaming against Spec §2.3). Its notes for the contract steps (provider set, observe zone rule,
  settle operation, start instant and bounds, required timestamp and id arguments) are passed into
  S06..S11. Two runtime questions stay for the runtime decomposition: whether shutdown drains the virtual
  queue first, and whether TestBus generates deterministic envelope ids.
- 2026-10-17, after S07: added a governance touch-up after the last root contract (one hsdd-adr step,
  one root hsdd-spec touch), collecting: ADR-003 `affects` gains topology-dsl@v1 (its items 3 and 4
  constrain G22, G23) and the contract's Governed by gains ADR-003; ADR-001 item 4's "live topology
  builder" wording follows S07's plan interpretation; the root OQ5 detail stops saying switchMap covers
  server rewiring (S07 dropped a selecting switch). topology-dsl@v1 decided OQ-M2 (one plan, IR projected
  from it, interpreted live) and the DSL side of OQ-M1 and OQ-R3.
- 2026-10-17, after S08: the touch-up list grows: ADR-001's structure set must tolerate topology-ir@v1's
  `render/` golden directory, and nidana.model's Owns list should name the single-writer analysis
  (topology-ir@v1 holds it; ADR-002 item 8 assumes it). OQ-M1 is decided by topology-ir@v1 G9; OQ-M1,
  OQ-M2, OQ-M3 rows are marked at nidana.model's phase planning or the reconcile sweep.
- 2026-10-18, after S09: bus-api@v1 needs a compatible topic-model@v1 amendment (a sealed
  MultiWriterTopic over EventTopic and ReplayTopic), inserted as S10; the remaining root contracts shift
  to S11..S15. Judged not a breaking-amend stop: no consumer code exists and every exhaustive switch
  over Topic keeps compiling. bus-testing@v1 (S11) adopts the names bus-api@v1's bindings call. OQ-R1
  (keep microtask-delayed first delivery) and OQ-R3 (dedup per read) are decided by bus-api@v1; the
  runtime decomposition marks the rows. S09 recommends one runtime child own the main library and the
  `lib/src/` library it shares with bus-testing@v1, with behavior split by guarantee across phases.
- 2026-10-18, after S11: bus-testing@v1 decided OQ-R2 (typed value queries; a TestBus activates
  nothing, tests stand in with `input` and `stub`), which leaves root OQ2 with nothing open. The
  touch-up batch gains a compatible bus-api@v1 wording amendment: G38 must allow `settle`'s real
  event-loop turns (bus-testing@v1 G12), and its delivery rule should name recorders attached to the
  bus rather than "the recorder of a TestBus". The runtime decomposition should give one child both the
  main library and `testing.dart` (they share the `lib/src/` library that declares `Bus`).
- 2026-10-18, after S12: navigation-api@v1 decided OQ-N1 (generic resolver over the app's auth
  `StateTopic<S>` and a pure principal mapping) and OQ-N2 (typed `NavRoute<A>`; `Route` renamed because
  Flutter's widgets library declares one). It found that bus-api@v1 lacks a guarantee that a topology
  activated before `start()` is connected before the queue is delivered, and that `publish<T>` widens
  `T`. Both, with S11's two wording fixes, go into a bus-api@v1 amendment run now as S13, before
  flutter-binding@v1, which depends on the bootstrap guarantee; the remaining root contracts shift to
  S14..S16.
- 2026-10-18, after S13: bus-api@v1 amended within v1 (connection before `activate` returns and queue
  order across topics at `start()`; `publish<T extends Object?, V extends T>` with new G40; G38 and the
  recorder wording). The bound is written out because the bare form breaks a navigation-api@v1 reject
  fixture under strict inference. nidana.runtime's decomposition must give topology reads a synchronous
  path that does not go through RxDart's replay. nidana-checks@v1 may add a check against explicit type
  arguments on `publish` (closes G40's gap).
- 2026-10-18, after S14: flutter-binding@v1 decided OQ-F1 (Flutter's own Navigator; no router
  dependency) and the bootstrap (the router keeps its own stack and accepts performs before a Navigator
  hosts it, so Guide §3.5's order holds: resolver, executor, `start()`, `runApp`). nidana-checks@v1 must
  recognize `PageScope(writes:)` as a claim site and `PageScope(topologies:)`, `ModuleRoutes(topologies:)`
  as activation sites. The touch-up list gains a bus-api@v1 case for a topic reached through a widened
  `Topic<Object?>` reference (the stand-in throws TypeError).
- 2026-10-18, after S15: topic-codegen@v1 fixes `topics.yaml`, the generated `lib/topics.g.dart`, the
  catalog, the graph page and `topology-graph.json` (command `catalog`); OQ-T1 becomes PARTIAL (only
  the graph's content and source are fixed). The ADR touch-up gains ADR-001 item 3's coverage wording for
  `file` and `cli` contracts and item 6's lack of expected exit codes for file cases.
- 2026-10-18, after S16: all nine root contracts exist; the strict gate (no `--contracts-pending`)
  passes. nidana-checks@v1 decided OQ-T2 (the scan reads catalog's topologies and resolves claims
  itself) and added an `explicit_topic_type_arguments` rule; OQ-T1 stays PARTIAL. The touch-up batch is
  fixed as S17..S21 (two ADR updates, three compatible contract touches); root prose waits for one root
  hsdd-spec refresh at the end of stage 5.
- 2026-10-17 (UTC), after S17: ADR-001 amended in place (no supersession; item numbers kept). The
  orchestrator's own timestamps from S09 to S16 were local time labelled UTC; corrected bounds are in
  `docs/auto-run/timestamp-corrections.md`, and `ledger.mjs` now rejects future times. Dates in this
  change log before this entry that read 2026-10-18 are local dates. S21 gains topic-codegen@v1's
  recorded invocations.
- 2026-10-17 (UTC), after S18: ADR-003 now affects topology-dsl@v1. The reconcile sweep must fix
  ADR-003's Consequences, which still call the dispatcher hint OQ-M3 although topic-model@v1 G5
  decided it.
- 2026-10-17 (UTC), after S20: bus-api@v1 gains G41 (one subject per topic whatever the reference's
  type argument) and narrows G20 to "same type argument". The touch batch ends at S21. Carried into
  phase planning as amend entries the producers emit: bus-testing@v1 G16 (envelopesOf and payloadsOf on
  a widened-published envelope) and G18 (stub writer per type argument), for nidana.runtime's plan;
  flutter-binding@v1 G17 (same stub wording), for nidana.flutter's plan; nidana-checks@v1's
  global-accessor note, for nidana.tooling's plan. The runtime decomposition must read S20's registry
  notes: subjects hold values at `Object?`, envelopes are never cast to the value type, writers are
  kept per (topic, type argument), and an off-type widened publish must not stop delivery (G13).
- 2026-10-17 (UTC), after S21: the touch batch is done; stage 4 is complete. Note for nidana.model's
  replay tool: run `pub get` before replaying recorded invocations (a stale resolution exits 255).
- 2026-10-18 (UTC), after S22: nidana.runtime is a leaf-parent (its D1, reversing root D4), with ten
  internal slices mapped to every guarantee of bus-api@v1 and bus-testing@v1. Root OQ2, OQ-R1..R3 are
  RESOLVED. The root refresh must restate root D4 and the conventions' RA/RB example; the reconcile sweep
  must reword bus-api@v1's "the child of nidana.runtime that owns the main library". nidana.runtime's
  phase plan emits three amends on bus-testing@v1 G16, G18 and bus-api@v1 G41 (its D5, D6, D7).
- 2026-10-18 (UTC), after S23: nidana.tooling has two leaf-parents (codegen about nine phases, lint
  about three); nidana-checks@v1 is produced by both (reconcile applies the union of their produced_by
  confirms). OQ-T1 and OQ-T2 are RESOLVED. Stage 6 leaf-parents, producer-first: nidana.model,
  nidana.runtime, nidana.navigation, nidana.flutter, nidana.tooling.lint, nidana.tooling.codegen,
  nidana.integration.
- 2026-10-18 (UTC), after S25: a plugin diagnostic's severity is its LintCode's declared severity
  (default INFO); ADR-002's earlier "plugin rules report at INFO" generalised from a stand-in and is
  corrected; S04's evidence for that line is superseded by docs/auto-run/experiments/plugin-severity/.
- 2026-10-18 (UTC), after S26: root refreshed. Inserted S27, a short hsdd-spec touch adding the
  topology-ir@v1 edge to nidana.navigation and nidana.flutter. Routed to phase plans: the producers'
  plans and reconcile confirm nidana.tooling as a consumer of bus-testing@v1, navigation-api@v1 and
  flutter-binding@v1, and nidana.tooling.codegen and .lint as producers of topic-codegen@v1 and
  nidana-checks@v1; nidana.tooling.lint's plan amends nidana-checks@v1 Refinement 4's "Root D1 does not
  list it"; nidana.runtime's plan fixes its own Contracts table (bus-testing@v1 row lacks nidana.tooling).
  Stage 6 now starts at S28.
