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
| S113 | implement | superpowers:subagent-driven-development | nidana.model.4: 5 tasks, 2 fix rounds (purity reader), final review with one fix wave; gate exit 0, 32 tests, 57/57 | done | ccac409; merged into impl/nidana.model as 3c147db |
| S114 | config | hsdd-config | nidana.model.5 | done | d514fe4 |
| S115 | code-plan | superpowers:writing-plans | nidana.model.5 (3 tasks; dry run 117/117) | done | 2088ab2 |
| S116 | implement | superpowers:subagent-driven-development | nidana.model.5: 3 tasks, 1 doc fix round, final review ready to merge; gate exit 0, 38 tests, 117/117; end of the types band | done | 01991b3; merged into impl/nidana.model as 739c828 |
| S117 | config | hsdd-config | nidana.model.6 | done | 631224a |
| S118 | code-plan | superpowers:writing-plans | nidana.model.6 (6 tasks; routed items taken in; Flutter runner on a stand-in SDK) | done | 34ace02 |
| S119 | implement | superpowers:subagent-driven-development | nidana.model.6: 6 tasks, fix rounds on Tasks 4 (late-error false PASS) and 5 (runners.dart split), final review with fixes, one fix wave; gate exit 0, 292 tests, 102/102; behavior --all 112: 102/3/7 | done | cc375a7; merged into impl/nidana.model as 90116bd |
| S120 | config | hsdd-config | nidana.model.7 (N=8, full-review; the known excerpt-ids warning) | done | e65c944 |
| S121 | code-plan | superpowers:writing-plans | nidana.model.7 (8 tasks; script form for package commands; 2 contract gaps routed) | done | 0eacc99 |
| S122 | implement | superpowers:subagent-driven-development | nidana.model.7: 8 tasks, a pre-review amendment on Task 3 (sealed FileEntry), a doc fix round on Task 8, final review with fixes (tests pinned governance content), one fix wave; gate exit 0, 468 tests, 102/102; --all 321: 235/3/83; the replay tool is complete | done | f4a13fd; merged into impl/nidana.model as eb033bb |
| S123 | config | hsdd-config | nidana.model.8 (N=7, spot-check; produces topic-model@v1, last producing phase; the known excerpt-ids warning) | done | b979378 |
| S124 | code-plan | superpowers:writing-plans | nidana.model.8 (6 tasks; dry run green: topic-model 41 behavior cases; 3 contract gaps routed) | done | 7a245e7 |
| S125 | implement | superpowers:subagent-driven-development | nidana.model.8: 6 tasks, no fix rounds, final review with fixes (doc overclaims), one fix wave; gate exit 0, 95 tests; topic-model 31/31, 41/41 behavior cases; topic-model@v1 fully produced | done | a35f40c; merged into impl/nidana.model as 5d2cf18 |
| S126 | config | hsdd-config | nidana.model.9 (N=7, spot-check; consumes topic-model@v1, produces topology-dsl@v2; the gate does not replay G9) | done | c286b15 |
| S127 | code-plan | superpowers:writing-plans | nidana.model.9 (5 tasks; found the Gate's G10 restriction cannot pass before .11; governance route S128 to S131) | done | 8aa4d1b |
| S128 | phase-plan | hsdd-phase-plan | nidana.model amend of .9's gate (G10 out of the restriction; .11 Scope names G10; one compatible Delivery amend pending) | done | 5caef25 |
| S129 | reconcile | hsdd-reconcile | nidana.model pending section (amend of .9's gate): topology-dsl@v2 Delivery, compatible within v2 | done | c08820a |
| S130 | config | hsdd-config | nidana.model.9 re-run after the gate amend (restriction G11,G13 to G17,G30) | done | 1d0b27d |
| S131 | code-plan | superpowers:writing-plans | nidana.model.9 plan revised to the amended gate (constraint 4, Tasks 3 to 5) | done | bf18a44 |
| S132 | implement | superpowers:subagent-driven-development | nidana.model.9: 5 tasks, no fix rounds (one carried ruling), final review with doc fixes, one doc-only fix wave; gate exit 0, 147 tests; topology-dsl restricted 17/17 | done | 235c403; merged into impl/nidana.model as e9f2289 |
| S133 | config | hsdd-config | nidana.model.10 (N=7, spot-check; every restricted case passable here, checked; baseline 1/10) | done | 03f8fd8 |
| S134 | code-plan | superpowers:writing-plans | nidana.model.10 (6 tasks; dry run: restricted replay 1/10 to 10/10; 2 low contract gaps routed) | done | 3a9e427 |
| S135 | implement | superpowers:subagent-driven-development | nidana.model.10: 6 tasks, no fix rounds (one carried ruling), final review ready to merge, one doc-only wave; gate exit 0, 200 tests; topology-ir restricted 10/10 | done | d8efc63; merged into impl/nidana.model as 9fc5a72 |
| S136 | config | hsdd-config | nidana.model.11 (N=7, spot-check; found the topology-ir restriction's G3 and G7 cases call analyzeTopologyGraph, .12's; governance route S137 to S139) | done | 6bd67bf |
| S137 | phase-plan | hsdd-phase-plan | nidana.model amend of the unshipped gates (.11 and .13 without G3, G7; reach table over .11 to .14: all pass after) | done | 1c49c76 |
| S138 | reconcile | hsdd-reconcile | nidana.model pending section (amend of .11 and .13 gates): topology-ir@v1 Delivery, compatible within v1 | done | 708e7df |
| S139 | config | hsdd-config | nidana.model.11 re-run after the gate amend (topology-ir G2,G5,G6,G8 to G12: 17 cases, 7 for .11) | done | d68ad72 |
| S140 | code-plan | superpowers:writing-plans | nidana.model.11 (5 tasks; dry run gate exit 0: topology-dsl 24/24, topology-ir restricted 17/17; every routed item taken) | done | bba6721 |
| S141 | implement | superpowers:subagent-driven-development | nidana.model.11: 5 tasks, no fix rounds, final review with fixes, one fix wave; gate exit 0, 235 tests; topology-dsl@v2 fully produced (24/24 unrestricted); topology-ir restricted 17/17 | done | 9119de2; merged into impl/nidana.model as c021914 |
| S142 | config | hsdd-config | nidana.model.12 (N=6, full-review; all 31 restricted topology-ir cases reachable, 12 for .12) | done | f0160dd |

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

- S113: `ref/nidana-docs` (the reference architecture) is an uninitialized submodule on this machine, a
  private repository behind a personal SSH alias; the run does not fetch it (credential) and builds from
  the governance (decision in S113.orchestrator.json). Watch nidana.model.8, whose Verification cites Spec
  §2.4's worked examples.

- S118: the pinned Flutter SDK has no engine artifacts (`bin/cache/pkg/sky_engine`, `bin/cache/artifacts`
  absent), so no real `flutter test` runs on this machine; fetching them is a network action outside
  pub.dev, which the run does not take. nidana.model.6 tests its Flutter runner against a stand-in SDK; the
  real run is deferred to nidana.flutter.2. Owner action before the nidana.flutter lane: `fvm flutter precache`
  (or any first `fvm flutter test`), which downloads the artifacts.

- S119 (nidana.model.6): the owner should know before signing its verification doc:
  - the doc's decision 4 line understates one routed defect (see nidana.model.7 below);
  - a skipped-only binding run reads PASS, with the skip count in the line (plan-mandated, parked);
  - the phase is about 13 times its estimate in lines (3988 insertions in 28 files, against about 300 in 5), as nidana.model.1 and .2 were;
  - the Flutter runner is checked only against a stand-in SDK; the real run is Outstanding, deferred to nidana.flutter.2.

- S122 (nidana.model.7): the replay tool is complete (all seven sets). The phase is about 15 times its line
  estimate (6902 insertions in 39 files against about 450 in 7); the tool lane as a whole (nidana.model.1, .2,
  .6, .7) ran 9 to 15 times. None of the 39 committed recorded invocations nor topic-codegen's file replay has
  run against a real producer (all PENDING until nidana.tooling's packages exist); a recorded invocation runs in
  place in its `files/` directory under `hsdd/`.

- S125 (nidana.model.8): topic-model@v1 is fully produced (41/41 behavior cases). The owner should know before
  signing its verification doc: Spec §2.4 is not checked out, so the worked examples are checked as G19's
  conformance cases encode them (an Outstanding item); two phrases ("reproduce as written", "every branch of Spec
  §2.4's table") still read as Spec comparisons beside their qualifier (parked after the one fix wave). Five
  topic-model@v1 wording gaps are routed to the sweep (G13 NaN, G15 and G24 short renderings and re-redaction, G24
  `1` vs `1.0`, the "value or total function" sentence).

## Routed to later phases

Items a phase found that belong to a later phase's context or plan; the orchestrator carries each into
that phase's writing-plans dispatch and strikes it here when the phase's plan covers it.

- nidana.model.6 (behavior set; taken into S118's plan, Task 2): ADR-001 item 4 says a conformance library imports neither `package:test`
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
- nidana.model.6 (from S104's final review; taken into S118's plan, Tasks 1 and 5): lift the package-configuration read out of `_analyze` into a
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
- nidana.model.8 (from S107's final review; taken into S124's plan, Tasks 1 to 5): restore the Interface's trailing comments the declaration
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
- nidana.model.9 (from S113's final review; taken into S127's plan, Tasks 1 and 3): G14's "a handle another builder made" check needs a
  handle-to-builder link (a private constructor argument or an Expando); `CombineStage.apply` for `combineAll`
  needs `T`, which `CombineStage<R>` does not carry, so capture a typed closure in the private constructor.
- nidana.model.11 (from S115): remove the two `// ignore: unused_element` lines above `ShellClaim._` and
  `TopologyGraph._`.
- nidana.model.13 (from S115): the codec adds the `dart:convert` import (not imported at nidana.model.5).
- Consumer nodes (from S115): ADR-001 item 4's one-code marker held for all 22 reject libraries of
  nidana.model's three contracts; the reject sets of bus-api, bus-testing, navigation-api and flutter-binding
  meet it at their producers' first gates (outside this run).
- nidana.model.10 and .11 (from S116's final review; taken into S134's plan, Tasks 3 and 5): D4 puts "the canonical orders" in `lib/src/ir/`, but the
  claim order compares `ShellClaim`, which lives in `graph/graph.dart` and imports `ir/`; a claim comparator in
  `ir/` naming `ShellClaim` makes the libraries import each other. Define the claim order over its parts
  (source, scope, writes) in `ir/`, or keep it in `graph/`. Also: the findings' constructors become
  initializer lists that sort, keeping every parameter name and field type (no call site changes).
- nidana.model.10 (from S112; taken into S134's plan, Tasks 1, 2 and 4): remove the two `// ignore: unused_element` on `TransformEdge._` and
  `TopologyDefinition._`; `FunctionRef.named`'s empty-name `ArgumentError`.
- nidana.model.7 (from S119's final review; taken into S121's plan, Tasks 1 and 5), since it edits the same shell and `structure.dart`:
  `_snapshotsOf` reads a suite slug's whole snapshot, so a read defect in topology-dsl's tree (a dangling link
  where a source is read, a contract text that is not UTF-8) makes a bus-api behavior replay exit 2 with one
  `error:` line and no fixture line for any slug (reproduced in S119's last re-review; reading only the suite
  file narrows it; nidana.model.6's verification doc understates this as ending the replayed slug's replay); `purity_test` pins direct
  `dart:io` imports only and `relativeClosure` ignores own-package `package:` self-imports; `lenientUtf8` lives
  in `runners.dart` though every process uses it; a contract text that is not UTF-8 exits 2 while an absent one
  is a structure failure (exit 1).
- End of nidana.model, governance sweep (from S122): ADR-001 item 7 says `files/` "becomes the working directory",
  and the replay tool runs a recorded invocation in place under `hsdd/contract/fixture/` (required: the committed
  `files/analysis_options.yaml` enable the plugin by a path relative to `files/`); nothing detects a command that
  writes there, and `.gitignore` would hide a `.dart_tool/` or `pubspec.lock` it left. An item 7 touch can require
  a case's command to leave `files/` unchanged, or the tool can compare its listing before and after.
- End of nidana.model, governance sweep (from S122, nidana.model.7 decisions 3 and 11): nidana.model.7's Scope (1)
  (hsdd-spec; it glosses ADR-001 item 6, which says only that `## Validation` "names the generator command")
  says "the backticked span of the contract's `- file:` bullet that holds `{output}`", which names three spans of
  topic-codegen@v1's bullet, read by the tool as the one that also holds a space (an ADR-001 item 6 touch or
  topic-codegen@v1's Validation text, compatible, can name the command span instead); item 7's plugin enabled in `files/analysis_options.yaml`
  is read as a package the case's command runs, which makes the `analyze-*` cases PENDING without
  `nidana_dart_lint` (an ADR-001 item 7 touch). Both readings are pinned by tests.
- End of nidana.model, governance sweep (from S122's final review), for the ADR-001 item 9 and 10 touch: the one
  order of PENDING and the restriction an item 9 touch states must be restriction-first (nidana.tooling.lint.1 to
  .4 and codegen.9 and .11 depend on it; no gate depends on behavior's PENDING-first); a file replay or recorded
  invocation that declares no id runs only unrestricted (a reading; it also makes item 10's "falls within exactly
  one share" vacuous for such a case); a fixture defect fails even when the restriction does not admit the case (a
  reading, nidana.model.6 decision 5 and nidana.model.7 decision 12); a duplicate Case-table row's ids are
  ignored, first row wins (a structure-list touch: item 3 says one row); `plugins: # comment` in a case's
  `files/analysis_options.yaml` reads as no plugin, which turns a PENDING case into a run (item 7 plugin note).
- End of nidana.model, governance sweep (from S124, hsdd-contract on topic-model@v1, compatible): G15 and G24's
  "never contains the payload's own rendering" cannot hold for a very short rendering (`RedactedPayload.of('String')`
  renders `<redacted String #...>`); G15 applied to an already-redacted envelope wraps it again, so the log shows
  `<redacted RedactedPayload #...>` and the payload type is lost (the surface fixture's `AuditObserver` logs exactly
  this; a rule choice for hsdd-contract); "Everything here is a value or a total function" (topic-model line 18 and
  nidana.model's Pure band, hsdd-spec) is inaccurate: the observer interfaces are neither and `Lineage.combine`
  throws. `docs/auto-run/steps/S124.json` contract_gaps. Also (S125 Task 2 review): G24 says a redaction is "equal
  for equal payloads", but the Interface's `==` compares `typeName` and `hash`, so `RedactedPayload.of(1)` and
  `RedactedPayload.of(1.0)` differ although `1 == 1.0` and their hash codes agree. And (S125 Task 5 review): G13
  read literally makes an envelope whose payload is NaN unequal to itself, so a `Set` of envelopes cannot find or
  remove it; an `identical` short-circuit is the contract owner's call. And (S125 final review): `Topic`, `TopicRef`
  and `Lineage` keep `Object.toString` (the Interface declares none), so test failures in nidana.model.9 to .14
  print `Instance of 'TopicRef'`; compatible renderings would need the contract (D4 gives `lib/src/topic/` no later
  owner). Also: Spec §2.4's worked examples are checked only as G19's conformance cases encode them; compare them
  with the Specification once `ref/nidana-docs` is checked out (nidana.model.8's Outstanding).
- End of nidana.model, governance sweep (from S127, hsdd-contract on topology-dsl@v2, non-blocking): the recording
  suite misses several defects seeded against stated rules (wrong type arguments in the visitors, an identity-based
  one-sink check, stages left behind after a rejected call); the contract does not say which error wins when a
  closed builder also gets a bad argument, or what `apply` does with a list of the wrong length (the code checks
  closed first, then arguments, and throws `ArgumentError` on a wrong length). `docs/auto-run/steps/S127.json`.
- nidana.model.11 (from S132's final review, which edits the DSL library; taken into S140's plan, Tasks 1 to 4): the builder's `"... is an replay topic"`
  message grammar; `_checkMade` names the argument `handle` without its position (a foreign fourth handle of
  `combine4` reads "Invalid argument (handle)"); use `combiner`, never `apply`, for `FunctionRef.of`; map a stage
  to its edge index by identity (stages keep `Object`'s `==`, G30); expect `TopologyDefinition`'s `ArgumentError`
  for the corner below and let it propagate from `definition`. From S135's Task 3 review: sort claims with
  `compareClaimKeys((source: c.source, scope: c.scope, writes: c.writes))` and topologies with `compareTopologyIds`
  (both in `lib/src/ir/canonical_order.dart`); the id order alone neither dedupes equal definitions nor rejects
  unequal ones sharing an id (G11, G15), which `TopologyGraph` must do. From S135's final review: make
  `canonical_order_test.dart`'s ir/-never-imports-graph/ check recursive (`listSync(recursive: true)`); reword the
  rendered-alike corner's "second sink edge on a state topic" message, which misleads an author who declared two
  `Topic`s; `elementsEqual` takes `List`s, so `ShellClaim`'s `Set` writes need `.toList()` or a wider helper (and
  its dartdoc names only envelopes and lineages); the "takes exactly 1 inputs" grammar in `definition.dart`.
- nidana.model.12 (from S135's final review): the finding constructors keep repeated elements (G23); where the
  contract implies distinct elements (a cycle's ids and topics, a self-reference's edges) the analyses pass
  distinct values themselves.
- nidana.model.13 (from S135's final review): the decoder checks a `StageInput` index before constructing (the
  constructor's assert is an `AssertionError` under `dart test`; G21 allows only `FormatException`), converts the
  IR factories' `ArgumentError` to `FormatException`, and checks raw repeats before `reads`/`writes` Sets and
  `TopologyGraph` collapse them (`invalid/reads_repeat_topic.json`, `invalid/topologies_repeat.json`); the
  round-trip generators avoid a dedup on an event or replay read and an empty `typeName`. From S141's Task 4
  review: a decoded document listing one state topic as a sink twice reaches `TopologyDefinition`'s second-sink
  message, whose tail ("two state topics of one name whose value types render alike ... are one topic in the IR")
  implied the wrong cause there (reworded in nidana.model.11's final fix wave, S141). From S141's final review: the
  decoder also converts `ShellClaim`'s rejections (`invalid/claim_*.json`) and `TopologyGraph`'s rejection of
  unequal definitions sharing an id to `FormatException`, and checks raw repeats of topology ids and of a claim's
  topics on the JSON lists before constructing (`TopologyGraph` merges equal definitions; a claim's `writes` is a
  `Set`).
- nidana.model.12 (from S141's final review): the analyses return unmodifiable lists (G3's case calls
  `findings.clear()` and expects it to throw); `graph.topologies` is sorted by id with distinct ids,
  `graph.claims` canonical with equal claims kept (G15's "one entry per claim"), `graph.topics` canonical.
- nidana.runtime (planning note, from S141's final review): run G23's idempotency check before building the G24
  graph with the candidate (else an unequal re-activation surfaces `TopologyGraph`'s `ArgumentError` instead of
  `TopologyConflict`); compute `plan.definition` before claiming or wiring anything, so the rendered-alike
  `ArgumentError` leaves nothing behind.
- End of nidana.model, governance sweep (from S132's final review): two `StateTopic`s with one name and value
  types that render alike (one class name from two libraries) pass `planOf` (topology-dsl@v2 G14 compares by
  `Topic` equality, whose `valueType` is a `Type`) but break topology-ir@v1's well-formedness (`TopicRef`
  compares the rendered string), contradicting "From a plan"'s closing sentence that every projected definition
  is well formed; it is also a Spec §4.3 name collision the workspace scan reports.
- End of nidana.model, governance sweep (from S133, low): topic-model@v1 cites ADR-003 items in its Interface and in
  G12 and G25, but its Governed by omits ADR-003 and ADR-003's `affects` omits topic-model@v1, so hsdd-config leaves
  ADR-003 out of a phase that consumes topic-model@v1 without naming ADR-003 itself (impl-gate warns). Add the link
  in both places (hsdd-contract and hsdd-adr), or leave it.
- End of nidana.model, governance sweep (from S134, hsdd-contract on topology-ir@v1, low): G6's rule against a
  `StageInput` with a negative index has no fixture (a negative case needs assertions off, which `dart test` turns
  on) and the Validation section lacks the not-executable line ADR-001 item 3 asks for; the suite misses a
  `retry` accepted on combinators other than `map` and a definition equality that ignores edge order (seeded
  defects D5 and D11, `docs/auto-run/experiments/ir-values-plan/`). Also (S135 Task 1 review): G9's derivation
  table says an extension tear-off is anonymous, which holds for instance members only; a static method of a named
  extension renders `Ext|helper` and an extension-type constructor tear-off `ET|constructor#_#new#tearOff`, which
  the text rule names (the schema accepts any non-empty name); a table clarification for hsdd-contract.
- End of nidana.model, governance sweep (from S135's final review, hsdd-contract, low): `TopicInput` accepts a
  `dedup` on an event or replay topic and `TopicRef` accepts an empty `typeName`, which the schema rejects
  (`invalid/dedup_on_event_read.json`, `typeName` minLength 1), so G20's "decoding a graph's encoding gives the
  graph back" fails for such hand-built graphs; either assert in the constructors as `StageInput` does or narrow
  G20 to graphs the decoder accepts. Plan-made definitions never hold either.
- End of nidana.model, governance sweep (from S139): nidana.model.10's shipped Scope (spec line 361) and its
  verification doc (line 70) still say G3 and G7 join the topology-ir restriction at nidana.model.11; S137 moved
  them to nidana.model.12 (shipped text was left untouched). An hsdd-phase-plan or reconcile touch, or a note.
  Also (S141 Task 2): D4's directory list gives `lib/src/topic/` to nidana.model.3 and .8 only, but nidana.model.11
  made a comment-only dartdoc edit to `list_equality.dart` (safe: no phase ran beside it).
- End of nidana.model, governance sweep (from S140, hsdd-contract on topology-ir@v1, low): no case builds two claims
  that tie on source and scope, so the writes part of the claim order is never replayed; a compatible case.
- nidana.tooling.codegen.6, .9, .11 and nidana.tooling.lint.4 (from S122): the first gates to run the 39 committed
  recorded invocations and topic-codegen's file replay for real (all PENDING until then); their `{files}` and
  `{root}` recordings and in-place `files/` runs are first exercised there.
- End of nidana.model, governance sweep (from S121): ADR-001 item 9's `dart pub get --enforce-lockfile` does not
  make a stale workspace fresh (pub's mtime rule; Dart 3.13.5), so its stated reason is wrong; the replay tool
  runs a `{package}:{executable}` command as `bin/{executable}.dart` of the package's root under the running
  `dart` with `--packages`, which runs either way. hsdd-adr: item 7 states the form, item 9's bullet restates its
  reason; hsdd-spec: nidana.model.7's Scope (4) the same; hsdd-contract (compatible, v1): nidana-checks@v1's
  Validation sentence "resolves nothing in place" (`docs/auto-run/experiments/file-cli-sets-plan/`, S121.json
  contract_gaps). Also: behavior checks PENDING before the restriction, file and cli the restriction before
  PENDING (nidana.model.6 decision 5 against nidana.model.7's); an ADR-001 item 9 touch can state one order.
- End of nidana.model, governance sweep (from S119's final review): `structure` does not check that a binding
  imports exactly one conformance library by relative path (`behavior` fails it as `suite (...)`, but
  `--all --set structure`, which hsdd-contract authors run, passes it): an ADR-001 item 9 structure-list
  touch; a conditional-configuration URI (`import 'a.dart' if (c) 'package:test/test.dart'`) escapes
  `src-import`, `conformance-import` and PENDING (the directive reader reads only the first URI).
- Later tool phases (from S119, nidana.model.6 Task 5 review): the runner process has no timeout, so a binding
  whose case never yields hangs the gate; ADR-001 does not require one. Weigh it when a gate first runs a
  suite with timers or isolates (nidana.runtime).
- End of nidana.model, governance sweep (from S119): ADR-001 item 9's description of the `structure` set does
  not name the two rules nidana.model.6 added: `encoding` (a Dart fixture that is not UTF-8) and
  `conformance-import` (item 4's rule, which item 12 already covers); the hsdd-adr touch can name both.
- End of nidana.model, governance sweep (from S118): "a conformance library that no binding in any slug imports
  covers nothing" is a reading of ADR-001 item 3 for hsdd-adr (it gives structure a workspace-wide input); no
  committed suite is unbound today (`docs/auto-run/experiments/behavior-set-plan/` R7).
- End of nidana.model, governance sweep (from S115's dry run): topology-ir@v1's surface fixtures never build
  `ScopeViolation` with `const` (`surface/graphs.dart:105`), so a non-const constructor passes the replay; only
  the package's own test pins it (`TopicDeclaration` is built `const` at `graphs.dart:122`, so the replay pins
  that one; corrected after S116's Task 3 review). A compatible hsdd-contract touch could add a const use to
  `surface/graphs.dart`.
- End of nidana.model, governance sweep (from S112): topology-ir@v1's Interface prose (line 47) says every value
  type is `@immutable`, but its code blocks show no annotation; the code annotates as the prose says.
- End of nidana.model, governance sweep (from S110): hsdd-adr touch of ADR-001 item 10 (its premise that a
  contract's first producing phase lands every declaration, and its sub-bullet that nidana.model.4 lands only
  `TopologyDefinition`, now understate the split); hsdd-spec touches of `hsdd/spec/nidana.md` line 211
  (Development flow item 1) and `hsdd/spec/nidana.model.md` line 40 ("Inherited from the root"), which still
  say "one contract per phase"; stale reasons (".5 completes the main library") in
  `hsdd/spec/nidana.tooling.codegen.md` line 299 and `hsdd/spec/nidana.navigation.md` line 177, edges correct.
- End of nidana.model, governance sweep (from S107's and S113's final reviews): nidana.model D6's purity token
  list misses `Random.secure(`, `DateTime.timestamp(` (a clock read, verified on the pinned SDK), `Timer.run(`,
  `runZoned`, `Stream.periodic(`, `Future(`; an hsdd-spec touch
  could make the list a floor ("at least").
- nidana.model.6 (from S106; taken into S118's plan, decision 18 and Task 6): the topic-model binding already loads against nidana.model.3's declarations
  (9 cases pass, 32 fail), and not every failure is `UnimplementedError` (some are identity equality or
  `Object.toString`), so nidana.model.6's Verification sentence "cases fail on UnimplementedError, not on
  loading" holds only loosely; its plan should state what it checks.
- nidana.model.8 (from S106; taken into S124's plan, Tasks 1 to 3): what it must add or replace is listed in `docs/auto-run/steps/S106.json`
  `notes_for_orchestrator` (the stored `initial`, the copied `parentCorrelationIds`, removing the
  `// ignore: unused_element` on `RedactedPayload._`, value equality and `toString`).
- nidana.model.4 and .5 (from S106): no topic-model reject line carries two codes; the two-codes item
  carries on to the topology-dsl and topology-ir reject replays.
- nidana.model.6 (from S103; taken into S118's plan, Task 2): invalid UTF-8 in a Dart fixture still exits 2 as an environment error; make it a
  fixture failure when the behavior set reworks reading.
- nidana.model.6 (from S101's final review; taken into S118's plan, Task 1, the cross-slug coverage item left routed): validate `--guarantee` ids against the slug's declared
  guarantees (a typo admits no case and passes under item 9); a conformance library that no binding in any
  slug imports should cover nothing (needs a cross-slug view: topology-dsl's live suite is bound from
  bus-api); pin `--guarantee=G1`, one-slug `--all` with a bare id, and the usage text once a set reads the
  restriction.
- nidana.model.7 (from S101's final review; taken into S121's plan, Tasks 1, 6 and 7): `readSnapshot`'s hidden-entry filter must not leak into the
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
