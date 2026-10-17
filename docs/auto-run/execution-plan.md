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
| S02 | 2 | hsdd-spec | root | next | |

## Change log

- 2026-10-17: first version, written before any skill ran.
