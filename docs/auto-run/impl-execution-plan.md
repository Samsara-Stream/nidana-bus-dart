# Automatic implementation run: execution plan

The record of the path the implementation segment takes, from settling its
inputs to the last phase of its scope. Like the planning run's
`docs/auto-run/execution-plan.md`, it is not a promise: the step log at the
end grows as steps run, and the change log says what moved and why.

- **Owner's request (2026-10-26):** automate the implementation, from
  hsdd-config through superpowers to implemented and verified code, starting
  with the phases of nidana.model, then stop. Take every decision and record it
  as the planning run did; stop only before something dangerous.
- **Repository:** nidana-bus-dart at `/Users/purbo/gitx/nidana-bus-dart`, a
  different machine from the planning run's. The run's root branch is
  `auto/v1-impl-1` (created by the owner at `7a2f215`, the tip of
  `auto/v1-planning`).
- **Toolchain:** fvm 4.3.2 (installed by the owner on 2026-10-26), Flutter
  3.47.7 with Dart 3.13.5 as `.fvmrc` pins; node for the HSDD scripts and the
  run's tools; pub.dev reachable.
- **Inputs:** this repository and its HSDD tree (every contract stable and
  final, ADR-001 to ADR-003 accepted, nidana.model's 14-phase plan); the
  v0.15.1 reference architecture; the HSDD skills under `.agents/skills/`
  (hsdd-config v0.10.0); superpowers 6.4.2 (writing-plans,
  subagent-driven-development, test-driven-development,
  verification-before-completion, requesting-code-review,
  finishing-a-development-branch).
- **Scope:** nidana.model.1 to nidana.model.14. No other node.
- **Finish line:** each of the 14 phases has its code, its gate passing, its
  `hsdd/verify/nidana.model.{n}.verification.md` with Sign-off left for the
  owner, and its branch merged into `impl/nidana.model`; `impl/nidana.model`
  is merged into `auto/v1-impl-1`; `docs/auto-run/REPORT-impl-nidana.model.md`
  is committed. Then the run stops.

## Stop policy

The owner said: do not stop to ask, record the decisions; stop before doing
something dangerous. So every condition the planning kickoff listed as a
run stop (a collision, a breaking amendment, a tree-shape question, a
step failing its gate twice) is decided by the orchestrator as the owner's
stand-in and recorded with `would_have_asked: true` and its `stop_class`.
The run writes `hsdd/judgement/STOP.md` and ends only for:

- an action that is destructive or irreversible beyond the run's own branches
  and files, a push, a credential, a network resource other than pub.dev, a
  change to `ref/`, or global tooling;
- a defect that leaves every path forward a guess (superpowers SDD's own
  fourth stop).

## Branches

Conventions' branch discipline, serial: one node integration branch,
`impl/nidana.model`, cut from `auto/v1-impl-1` after S97's commits; one phase
branch per phase, `impl/nidana.model.{n}`, cut from the node branch when the
phase starts; each phase merges into the node branch with `--no-ff` once its
gate passes and its final review is closed; the node branch merges into
`auto/v1-impl-1` with `--no-ff` at the end. Branches are kept. Nothing is
pushed. No worktree: phases run one at a time in the main checkout.

## How a phase runs

Three steps per phase, step ids allocated at dispatch (S98 onward), each with
two commits: the step's artifacts, then `judgement: S{nn}`
(`docs/auto-run/tools/step-commit.sh`). Every subagent prompt carries the
"Run rules" of `docs/auto-run/impl-step-preamble.md`; skill-step prompts also
carry its "Decisions and the step report".

### 1. Context switch (step kind `config`, skill hsdd-config)

- On the new phase branch, a fresh subagent (sonnet) runs hsdd-config's
  Phase Context Switch for `{phase-id} --method superpowers` (the
  `/hsdd-phase` command's meaning). The first switch also runs Setup, which
  copies the verification template to `hsdd/templates/verification.md`.
- Writes `hsdd-context/{phase-id}.md` and
  `hsdd-context/superpowers/{phase-id}.md`, and its report
  `docs/auto-run/steps/S{nn}.json`.
- Gate: `node docs/auto-run/tools/impl-gate.mjs config {phase-id}` (write
  set, stamp, the skill's equality check, no unfilled braces, the template).
- Commit: `hsdd: S{nn} hsdd-config {phase-id}`.

### 2. The plan (step kind `code-plan`, skill superpowers:writing-plans)

- A fresh subagent (opus) runs `superpowers:writing-plans` on
  `hsdd-context/superpowers/{phase-id}.md`, saving the plan as
  `docs/superpowers/plans/{phase-id}.md`. It runs the derivative's Plan
  check itself and ends with its report; it does not wait for writing-plans'
  Execution Handoff, which the orchestrator takes.
- Gate: `node docs/auto-run/tools/impl-gate.mjs code-plan {phase-id}` (write
  set; the Plan check: constraints 1 to 8 verbatim, a failing-test first step
  in every task but the last, the last task writes the verification doc, at
  most N tasks).
- Commit: `plan: S{nn} writing-plans {phase-id}`.

### 3. Execution (step kind `implement`, superpowers:subagent-driven-development)

The orchestrator is SDD's controller: SDD's controller dispatches subagents,
and a subagent cannot. BASE is the phase branch's head after step 2's
judgement commit.

1. Invoke `superpowers:subagent-driven-development`; resolve the plan's
   workspace (`scripts/sdd-workspace`, under the git-ignored
   `.superpowers/sdd/`); read the plan once; run SDD's pre-flight scan and
   write its table and rulings to the workspace's `progress.md`.
2. Per task: `scripts/task-brief`, one implementer subagent with the brief,
   the Run rules and the report path; then `scripts/review-package` and one
   task reviewer; the fix loop at most five rounds (rounds 1 to 3 resume the
   implementer, 4 and 5 a fresh opus implementer); a completion line in
   `progress.md`.
3. Models (SDD's Model Selection, applied once for the run): implementers on
   opus in full-review phases and sonnet otherwise; task reviewers and
   scoped re-reviews on sonnet; fix rounds 4 and 5 and the final whole-branch
   review on opus.
4. The plan's last task runs the gate and writes the verification doc, with
   Sign-off empty for the owner.
5. Final whole-branch review (`requesting-code-review`'s code-reviewer, opus,
   on `BASE..HEAD`, pointed at the deferred minors and parked findings); one
   fix wave and one scoped re-review if it finds anything; a fix wave that
   touches code re-runs the gate and appends the run to the verification
   doc's Observed.
6. Gate: `node docs/auto-run/tools/impl-gate.mjs implement {phase-id} BASE
   --log <scratch>` (write set over the range: nothing under `hsdd/` but the
   verification doc, nothing under `hsdd-context/`, the plan or
   `docs/auto-run/`; the doc's sections and dispositions; prose rules on added
   lines; registries clean; the tree clean; the phase gate run from the
   context file). This is verification-before-completion: no merge without a
   fresh passing run.
7. finishing-a-development-branch, option "merge locally": `git merge --no-ff
   impl/{phase-id}` into `impl/nidana.model`, message `merge: {phase-id}
   {phase name}`. Then delete the SDD workspace.
8. The controller's rulings (pre-flight, parked findings, breaker
   adjudications, final-review residuals) go to
   `docs/auto-run/steps/S{nn}.orchestrator.json` as decisions;
   `step-commit.sh` records them against the merge commit.

### Contract gaps and other governance defects

A fixture, schema or contract text that fails against an implementation that
matches the Interface is a contract gap (ADR-001 item 8; the phase context's
Discipline). The phase pauses at a task boundary; the orchestrator inserts an
hsdd-contract step on the contract (at the root lineage, which for this serial
run is the node branch, merged into the phase branch afterwards), then
hsdd-reconcile when a phase id or Delivery paragraph moves, re-runs the
switch, and resumes. Each inserted step is a full step with its own id, gate
and two commits. A non-breaking fix is decided and recorded; a breaking one
is decided as the owner's stand-in (`would_have_asked: true`,
`stop_class: breaking-amend`) after weighing the consumers' plans. The same
route applies to an ADR (hsdd-adr) or a node spec or phase plan
(hsdd-spec, hsdd-phase-plan in append mode) that a phase proves wrong.

### Rework

A step that fails its gate is reworked once by resuming the same subagent
with the finding (`SendMessage`), then by a fresh dispatch on a more capable
model. A second failure is decided and recorded, not a stop, unless every
path forward is a guess.

## Context

After any summarization of the orchestrator's context, re-read this file, the
last twenty lines of `hsdd/judgement/decisions.jsonl`, `git log --oneline
-20`, `git branch --show-current`, and the current plan's SDD
`progress.md`, before dispatching anything. Completed tasks are the ones with
a `Task N: complete` line; never re-dispatch them.

## Step log

| Step | Kind | Skill | Target | Status | Artifact commit |
|------|------|-------|--------|--------|-----------------|
| S96 | setup | none (orchestrator) | implementation inputs, scope, stop policy | done | see the judgement commit |
| S97 | plan | none (orchestrator) | this plan, the preamble, the tools | done | see the judgement commit |
| S98 | config | hsdd-config | nidana.model.1 | done | fd8bd3a |
| S99 | code-plan | superpowers:writing-plans | nidana.model.1 (8 tasks; resumed once for the strict not-executable form) | done | 188728d |
| S100 | contract (inserted) | hsdd-contract | bus-api@v2 touch: the G13 not-executable line names nidana.runtime (contract gap from S99) | done | 4d35eaf |

## Notes for the report

Findings the report must carry, written down when found so they survive context summaries.

- S98: hsdd-config's self-contained gate (Rule 2, switch step 9) read literally flags ids that occur only
  inside verbatim excerpts (ADR text, the node's Owns); the subagent scoped it to selected ids and marked
  the decision `would_upstream`, which here means HSDD's own skill text, not the reference architecture.
- Prompts reference the preamble file instead of pasting it (HARNESS.md item 1's cost): the file is
  committed, so each dispatch's instructions stay reproducible from git.

## Change log

- 2026-10-26 (UTC), S96 and S97: segment opened.
- 2026-10-26 (UTC), before S101: the SDD role prompts (implementer, task reviewer, re-reviewer, final
  reviewer), adapted from superpowers 6.4.2 for the unattended run, live in
  `docs/auto-run/impl-sdd-prompts.md`; each dispatch names its role and fills the values. Dispatches
  reference the preamble and the role file instead of pasting them.
