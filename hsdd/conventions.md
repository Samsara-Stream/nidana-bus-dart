# Project Conventions

> Single source of truth for HSDD naming, layout, and process conventions.
> Seeded by hsdd-spec at the root; updated only at the root (hsdd-spec or
> hsdd-reconcile). Phase planning treats this file as read-only.
> Override any default below and every skill honors it.
>
> This project runs phases with superpowers, not OpenSpec. The template's
> OpenSpec-specific sections keep their place below, rewritten for
> superpowers; each says what it replaces.

## Layout (default)
Every HSDD artifact lives under one root directory, `hsdd/`. Directory names
are singular. Per-phase contexts and superpowers plans stay in this
repository, outside `hsdd/`.

- `hsdd/conventions.md`                       this file
- `hsdd/spec/{node-id}.md`                    node specs and leaf-parent phase plans
- `hsdd/verify/{phase-id}.verification.md`    per-phase verification docs
- `hsdd/contract/{slug}.md` + `hsdd/contract/INDEX.md`  first-class contracts (registry generated)
- `hsdd/contract/schema/{slug}.schema.json`, `hsdd/contract/fixture/{slug}/`  executable validation for `stable` contracts, in the format ADR-001 fixes for this tree
- `hsdd/adr/{nnn}-{title}.md` + `hsdd/adr/INDEX.md`     cross-cutting decisions (authored by hsdd-adr, registry generated)
- `hsdd/scripts/gen-registry.mjs`             registry generator (copied verbatim from hsdd-contract)
- `hsdd/templates/verification.md`            verification-doc template, copied from hsdd-config
- `hsdd-context/{phase-id}.md` + `hsdd-context/superpowers/{phase-id}.md`  generic phase context and its superpowers derivative, written by hsdd-config
- `docs/superpowers/plans/`                   superpowers plans, one per phase, written by `superpowers:writing-plans` (replaces the template's `openspec/config.yaml` + `openspec/changes/` line)
- `hsdd/management/`                          management layer (progress, execution plans, milestones, intake records, atlas), written only by hsdd-checkpoint, hsdd-milestone and hsdd-intake (intake records)
- `hsdd/management/archive/`                  sealed milestone documents (closed campaigns)
- `hsdd/summary/`                             optional reading aids (hsdd-summary); absent means none are rendered

Code layout (the pub workspace at the repository root, `packages/{name}/`,
one owning node per package) is ADR-002's, not this file's.

**Standalone-spec-repo profile:** not used. This project is one repository
holding both the HSDD tree and the code, so `hsdd/` is a plain directory and
every skill runs from the repository root.

## Coding method
**Coding method:** superpowers

Before every phase, hsdd-config writes the generic phase context, then the
superpowers derivative; `/hsdd-phase {phase-id} --method {method}` overrides
the method for one phase.

## Execution setup (superpowers)
Replaces the template's "OpenSpec init" section.

- OpenSpec is not installed and is never installed; there is no `openspec/`
  directory and no `openspec init` step.
- hsdd-config Setup runs once: it records the method and copies the
  verification template to `hsdd/templates/verification.md`.
- Every phase starts with the context switch (`/hsdd-phase {phase-id}`),
  then a session that begins at `superpowers:writing-plans`, given
  `hsdd-context/superpowers/{phase-id}.md`, never at brainstorming. The plan
  check in that file runs before an execution method is chosen; execution is
  `superpowers:subagent-driven-development` or `superpowers:executing-plans`;
  the last task writes the verification doc.
- One HSDD tree, one repository. A second repository would adopt the
  standalone-spec-repo profile; it never gets an `hsdd/spec/` of its own.

## Naming
- Node id: dotted slug path from root (`nidana.runtime`)
- Phase id: `{leaf-parent}.{n}` (`nidana.model.1`)
- Contract: `{slug}@v{n}` (`bus-api@v1`)
- ADR: `ADR-{nnn}`; node-local decision: `D{n}`
- User story / acceptance: `US-{n}` / `AC-{n}.{y}`
- Open question: root `OQ{n}`; node `OQ-{prefix}{n}`; child view of a parent
  question: `[inherits OQ{n}]`. Prefixes in use:
  - `M` = nidana.model
  - `R` = nidana.runtime
  - `N` = nidana.navigation
  - `F` = nidana.flutter
  - `T` = nidana.tooling
  - `I` = nidana.integration
  - a child of an internal node takes its parent's prefix plus one letter
    (children of nidana.runtime are `RA`, `RB`, and so on), declared here by
    the hsdd-spec run that creates the child
- Dart packages: `nidana_dart_{layer}` for published packages, after Guide
  Appendix B.2; unpublished workspace members drop `_dart` (ADR-002)

## Open questions (OQ)
- IDs are stable: never renumbered, never reused. Resolved entries keep
  their row and detail subsection as audit trail; never delete them.
- One definition home: defined exactly once, in the `## Open questions`
  section of the spec that owns the decision. Every other artifact cites
  the ID only.
- Format (owning spec): summary table
  `| ID | Question | Status | Waits on | Affects |` + one `### {ID}: {title}`
  detail subsection per entry.
- Status: `OPEN`, `PARTIAL` (residual under *Waits on*), `RESOLVED (date)`
  (row points at the landing artifact). `ext:` marks an external party;
  link the execution plan's E-track where one exists.
- Resolving = update row + detail, land the decision in its artifact
  (ADR, contract or `D{n}`), and sweep citations that still treat it as
  open (`hsdd-reconcile` does this).
- A node OQ whose answer shapes a contract the root names says so under
  *Waits on*: the hsdd-contract step for that contract decides it, and the
  owning node's next step (or hsdd-reconcile's sweep) marks the row.

## Companion skills (recommended)
Obra's superpowers (github.com/obra/superpowers) is the coding method itself
here, not a set of skills wired into OpenSpec:

- `writing-plans` starts every phase, from the superpowers derivative
- `subagent-driven-development` or `executing-plans` executes the plan
- `test-driven-development` inside every task, `verification-before-completion`
  before the last task
- `systematic-debugging` on failure
- `requesting-code-review` / `receiving-code-review` at the review gate
- `using-git-worktrees` for phases that run in parallel
- `brainstorming` is not used at phase start: the phase was designed and
  reviewed in HSDD

Stack skills (optional): `mermaid-pastel-style` for every Mermaid diagram.
No Dart tech skill is installed, so the superpowers derivative carries no
tech-skill constraint.

## Phase design
**Ordering policy:** fp-progression

`fp-progression`: types, then pure functions, then effects, then composition,
as four ordered bands. Phase 1 of a leaf-parent is the type-level skeleton,
which lands the declarations of every contract the node produces; pure-core
phases precede every effect phase; the final phase is the imperative shell.
Chosen for the owner's functional-first practice (pure core, imperative
shell) and because the first phase then unblocks every `contract` and
`shared-model` edge out of the node (root D10). `hsdd-phase-plan` reads this
line; sizing, tiers, gates and the summary table do not depend on it.

- One Phase Equivalent (PE) per phase: <= 8 plan tasks (tasks of the
  superpowers plan; where a phase template says "OpenSpec tasks" it means
  plan tasks here), roughly <= 400 changed lines of non-generated code, one
  review sitting (~5h) end to end
- Review tiers: gate-only | spot-check | full-review
- Gate commands call `fvm dart` and `fvm flutter`, never a bare `dart` or
  `flutter`, and run from the workspace root unless they name a package
  directory
- A gate of a phase that produces a contract runs that contract's replay
  (ADR-001)

## Teams
**Teams:** single-team

One owner, Purbo with coding agents, builds every node. No node carries a
`- **Team:**` field.

## Contracts
`hsdd/contract/INDEX.md` (generated) is the single index of established contracts.
Do not list contracts here; run `node hsdd/scripts/gen-registry.mjs` after any
contract change. What a contract's executable validation contains, per
kind, is ADR-001's.

## Parallel development protocol (planning and execution)
- Governance files (`hsdd/contract/`, `hsdd/adr/`, this file, both `INDEX.md`)
  are read-only during phase planning, at the root and in every worktree.
- `hsdd-phase-plan` emits intended changes as a
  `## Governance updates (pending reconcile)` section in its own node's plan
  file (`confirm` / `note` / `amend` / `request` entries).
- After phase-plan branches merge, run `hsdd-reconcile` at the root: it drains
  pending sections, resolves `request` entries with the human, finalizes
  contract `phase_ids`, and regenerates the registries.
- Planners never read sibling worktrees or other nodes' phase plans (sibling
  node specs from hsdd-spec are shared and fine to read); contracts are the
  only inter-node knowledge.

### Execution protocol (per-phase superpowers sessions)
Replaces the template's "per-phase OpenSpec cycles" protocol.

- **Phase contexts are per-phase files.** `hsdd-context/{phase-id}.md` and
  `hsdd-context/superpowers/{phase-id}.md` are written by every context
  switch and committed on the phase branch; per-phase files never conflict
  on merge. When governance changes mid-phase, re-run the switch; the files
  are rewritten whole.
- **Plans are per-phase files.** Each phase's superpowers plan is saved under
  `docs/superpowers/plans/` with the phase id in its file name, never under
  `hsdd/`.
- **Branch discipline.** One integration branch per node; phase branches merge
  into it; node integration branches merge into the root branch. A node's plan
  file (`hsdd/spec/{node-id}.md`) is written on exactly one lineage: never
  re-plan or copy a plan onto a diverged sibling lineage. `hsdd-reconcile`
  runs once, at the root lineage, after the node plans are merged there; its
  commit exists only on the root. History is never squashed, amended or
  force-pushed; multi-phase work is never squash-merged.
- **Textual contention serializes.** Phases whose plan sections carry
  `Collides with` entries naming each other execute serially on the node's
  integration branch. Spawn parallel worktrees only for phases with no
  collision between them.
- **Plan naming** (replaces OpenSpec capability naming). A plan is named
  after its phase, so two phases never write one plan file; colliding phases
  serialize through `Collides with`, not through plan names.
