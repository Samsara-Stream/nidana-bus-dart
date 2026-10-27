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
| S101 | implement | superpowers:subagent-driven-development | nidana.model.1: 8 tasks, 3 task fix rounds, final review with one fix wave; gate exit 0, 93 tests, 102/102 structure | done | d761b1f; merged into impl/nidana.model as cab9039 |
| S102 | config | hsdd-config | nidana.model.2 | done | eb1e181 |
| S103 | code-plan | superpowers:writing-plans | nidana.model.2 (7 tasks; every routed item dispositioned) | done | d023480 |
| S104 | implement | superpowers:subagent-driven-development | nidana.model.2: 7 tasks, 2 task fix rounds, final review with one fix wave; gate exit 0, 195 tests, 206/206 structure and schema; surface and reject PENDING by design | done | d9b9b14; merged into impl/nidana.model as 014959f |
| S105 | config | hsdd-config | nidana.model.3 | done | 52e7a18 |
| S106 | code-plan | superpowers:writing-plans | nidana.model.3 (4 tasks; dry-run of every block: gate exit 0, 30/30) | done | 5d420f4 |
| S107 | implement | superpowers:subagent-driven-development | nidana.model.3: 4 tasks, no fix round, final review ready to merge; gate exit 0, topic-model 30/30 (first real surface and reject replay) | done | 881a18f; merged into impl/nidana.model as a8d43df |
| S108 | config | hsdd-config | nidana.model.4 (found the scope cannot analyze: TransformEdge lands at .5) | done | 6c258b4 |
| S109 | phase-plan (inserted) | hsdd-phase-plan | nidana.model re-plan of unshipped .4 and .5 (main library at .4, topology_ir.dart at .5) | done | 6f1d4b4 |
| S110 | reconcile (inserted) | hsdd-reconcile | nidana.model pending section: three Delivery amends within version, conventions fp-progression | done | 87b473a |
| S111 | config | hsdd-config | nidana.model.4 re-run after the re-plan (N 6) | done | a78d464 |
| S112 | code-plan | superpowers:writing-plans | nidana.model.4 (5 tasks; dry run 57/57; purity hardening routed in) | done | d3c8f85 |

## Notes for the report

Findings the report must carry, written down when found so they survive context summaries.

- S98: hsdd-config's self-contained gate (Rule 2, switch step 9) read literally flags ids that occur only
  inside verbatim excerpts (ADR text, the node's Owns); the subagent scoped it to selected ids and marked
  the decision `would_upstream`, which here means HSDD's own skill text, not the reference architecture.
- Prompts reference the preamble file instead of pasting it (HARNESS.md item 1's cost): the file is
  committed, so each dispatch's instructions stay reproducible from git.
- S101 Task 1 review: ADR-002 Consequences' "analyzer 14.5.0 as a transitive package" is one release stale
  (the lockfile resolved 14.6.0 on 2026-10-26, since no member constrains analyzer yet). Governance text, not
  a phase defect; for the owner.
- S101: whether a gate should enforce `dart format` is a phase-plan question for the owner; the run formats
  by ruling (S101.orchestrator.json).
- Implementer commits up to S107 Task 1 carry the run's `Co-Authored-By: Claude Opus 5.5` trailer whatever
  model implemented the task (sonnet for some; the S{nn}.orchestrator.json notes say which); from S107 Task 2
  on, each subagent commit names the model that wrote it (ruling in S107.orchestrator.json).

- nidana.model.1 landed 3968 inserted lines in 24 files against its estimate of about 450 lines in about
  10 files (tests about two thirds; the task reviews added tests beyond the plan's). If the remaining phases
  overrun alike, the node's PE sizing under-counts by a large factor; the owner's checkpoint question.

- S105: hsdd-config's template has no section for a node's own decisions (`D{n}`), so a phase context omits
  the node decisions that fix what a phase lands (nidana.model D3, D4, D6 for the type-level phases); the
  writing-plans prompts point at them. HSDD feedback, like S98's Rule 2 note.

## Routed to later phases

Items a phase found that belong to a later phase's context or plan; the orchestrator carries each into
that phase's writing-plans dispatch and strikes it here when the phase's plan covers it.

- nidana.model.6 (behavior set): ADR-001 item 4 says a conformance library imports neither `package:test`
  nor `package:flutter_test`; no set of nidana.model.1 checks it (the structure set's list in item 9 does
  not name it). From S101 Task 5's review.
- nidana.model.2: every item routed by S101 is dispositioned in S103's plan (`docs/auto-run/steps/S103.json`):
  Pending, the async shell, a reason on `SetUnavailable`, one analysis per replay and the loud `--all` cases
  in its Tasks 2 and 5; the range bound, right-trimming, covers bullets without a clause, the Case-cell message
  and id ranges in Task 6; `setsOf` kept (a missing schema file fails loudly at the schema path); a structure
  failure does not suppress other sets; wrapped continuation lines are not joined (they fail loudly; struck).
- nidana.model.3 to .5 (from S103): ADR-001 item 4's marker form cannot express two diagnostics on one line,
  and structure rejects stacked markers; every committed reject library is PENDING until its producer exists,
  so the first real reject replay (nidana.model.3's gate) is where a line with two codes would surface, as a
  contract gap for hsdd-adr.
- nidana.model.6 (from S104's final review): lift the package-configuration read out of `_analyze` into a
  replay-level step and pass a context record to `_run` (behavior, file and cli also need the package names
  for PENDING); move `SlugPlan` from `analysis.dart` to `run.dart`; reorder the no-slug check after
  `parseRequest` so a usage error exits 64 even with no fixture directory (D2 item 1); consider moving
  `findWorkspaceRoot` out of `shell.dart` so conformance libraries stop compiling the tool; consider a progress
  line for long test runs.
- Checkpoint (from S104's final review): nidana.model.1 and .2 each landed about 9 times their line estimate;
  re-baseline .6 and .7 (about 300 and 450 lines) before trusting the PE sizing.
- End of nidana.model, governance sweep (from S106): topic-model@v1's Interface, "Message sources": the four
  angle-bracket renderings (`'topology:<id>'` and the others) in a doc comment trip `unintended_html_in_doc_comment`
  when copied verbatim under the root lint set; the code puts them in backticks. A compatible hsdd-contract
  touch within v1 would put them in backticks in the contract too. Not blocking: no fixture depends on it.
- nidana.model.4 (from S107's final review; taken into S112's plan, Task 1 and Task 2's RED step): harden `packages/nidana_dart_contracts/test/purity_test.dart`'s
  directive reader before more libraries land (it reads only the first URI of a conditional import, misses
  `import r'dart:io';`, and accepts a relative URI that climbs out of `lib/`; collect every string literal up to
  the directive's `;`, reject relative URIs outside `lib/`, add self-test cases, and exercise the token scan);
  RED baseline: with the package present, `topology-dsl topology-ir --set surface,reject` prints
  `41 fixtures: 25 passed, 16 failed, 0 pending` (FAIL, not PENDING), `uri_does_not_exist` for
  `topology_plan.dart` among them.
- nidana.model.8 (from S107's final review): restore the Interface's trailing comments the declaration
  phase dropped (`// T` on `valueType`, the four `// non-empty`), and carry the Interface's dartdoc and trailing
  comments onto `==`, `hashCode` and `toString`; fix `envelope.dart`'s `// copied, unmodifiable` by copying;
  a private `Lineage` constructor for `combine` and `withLatestFrom`; store `initial` under both const
  `StateTopic` constructors; correct the README's "Everything here is a value or a total function" (observer
  interfaces are neither; `Lineage.combine` throws `ArgumentError`); a one-line test that non-default `dedup` and
  `tracing` reach their fields.
- Consumer nodes (nidana.runtime and later, from S107's final review): once nidana.model.8 overrides `==`, a
  non-empty const set or const map keyed by topics, refs, sources, envelopes or lineages stops compiling
  (`const_set_element_not_primitive_equality`); consumer plans must not rely on such collections. For the
  report and the owner.
- nidana.model.10 (from S112): remove the two `// ignore: unused_element` on `TransformEdge._` and
  `TopologyDefinition._`; `FunctionRef.named`'s empty-name `ArgumentError`.
- End of nidana.model, governance sweep (from S112): topology-ir@v1's Interface prose (line 47) says every value
  type is `@immutable`, but its code blocks show no annotation; the code annotates as the prose says.
- End of nidana.model, governance sweep (from S110): hsdd-adr touch of ADR-001 item 10 (its premise that a
  contract's first producing phase lands every declaration, and its sub-bullet that nidana.model.4 lands only
  `TopologyDefinition`, now understate the split); hsdd-spec touches of `hsdd/spec/nidana.md` line 211
  (Development flow item 1) and `hsdd/spec/nidana.model.md` line 40 ("Inherited from the root"), which still
  say "one contract per phase"; stale reasons (".5 completes the main library") in
  `hsdd/spec/nidana.tooling.codegen.md` line 299 and `hsdd/spec/nidana.navigation.md` line 177, edges correct.
- End of nidana.model, governance sweep (from S107's final review): nidana.model D6's purity token list misses
  `Random.secure(`, `DateTime.timestamp()`, `Timer.run(`, `runZoned`, `Stream.periodic(`; an hsdd-spec touch
  could make the list a floor ("at least").
- nidana.model.6 (from S106): the topic-model binding already loads against nidana.model.3's declarations
  (9 cases pass, 32 fail), and not every failure is `UnimplementedError` (some are identity equality or
  `Object.toString`), so nidana.model.6's Verification sentence "cases fail on UnimplementedError, not on
  loading" holds only loosely; its plan should state what it checks.
- nidana.model.8 (from S106): what it must add or replace is listed in `docs/auto-run/steps/S106.json`
  `notes_for_orchestrator` (the stored `initial`, the copied `parentCorrelationIds`, removing the
  `// ignore: unused_element` on `RedactedPayload._`, value equality and `toString`).
- nidana.model.4 and .5 (from S106): no topic-model reject line carries two codes; the two-codes item
  carries on to the topology-dsl and topology-ir reject replays.
- nidana.model.6 (from S103): invalid UTF-8 in a Dart fixture still exits 2 as an environment error; make it a
  fixture failure when the behavior set reworks reading.
- nidana.model.6 (from S101's final review): validate `--guarantee` ids against the slug's declared
  guarantees (a typo admits no case and passes under item 9); a conformance library that no binding in any
  slug imports should cover nothing (needs a cross-slug view: topology-dsl's live suite is bound from
  bus-api); pin `--guarantee=G1`, one-slug `--all` with a bare id, and the usage text once a set reads the
  restriction.
- nidana.model.7 (from S101's final review): `readSnapshot`'s hidden-entry filter must not leak into the
  byte-for-byte comparisons of `expected/` and `invocation/*/expected/`.

## Change log

- 2026-10-26 (UTC), S96 and S97: segment opened.
- 2026-10-26 (UTC), before S101: the SDD role prompts (implementer, task reviewer, re-reviewer, final
  reviewer), adapted from superpowers 6.4.2 for the unattended run, live in
  `docs/auto-run/impl-sdd-prompts.md`; each dispatch names its role and fills the values. Dispatches
  reference the preamble and the role file instead of pasting them.
- 2026-10-26 (UTC), S101: decisions are stamped when taken with `docs/auto-run/tools/decide.mjs`
  (HARNESS.md item 2); `ledger.mjs` gained a main-module guard so `decide.mjs` can import its check. The SDD
  progress ledger of each phase is archived as `docs/auto-run/steps/S{nn}.sdd-progress.md` before SDD deletes
  its workspace, because it is the only record of the per-task reviews, fix rounds and rulings. The S{nn}
  judgement commit of an implement step lands on the phase branch before the merge (the orchestrator's
  pending files differ between the phase and node branches); the merge commit is recorded in the next
  step's row.
