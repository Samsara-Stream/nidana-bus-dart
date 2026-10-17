# Automatic HSDD run: kickoff

How to start the run:

1. Open a **fresh** Claude Code session at this repository root. Not a session that has read any description of the manual run.
2. Read the "Facts from the owner" block in the prompt below and edit anything that is wrong.
3. Paste the whole prompt (everything between the `PROMPT BEGIN` and `PROMPT END` lines, without those lines) as an ordinary message. The session starts working.
4. Type the `/goal` line from the "Goal" section right after, while the session works. It is a separate input, never part of the prompt, and never before it: in an empty session the goal's condition would be the only instruction the model has. The terminal shows `Goal set:`. If the first turn has already ended by the time you set the goal, send `continue`; the evaluator checks at the end of that turn and keeps the session going.
5. The run ends with `docs/auto-run/REPORT.md` or with `hsdd/judgement/STOP.md`.

---

PROMPT BEGIN

You are running HSDD planning for nidana-bus-dart unattended, from scratch, through reconcile. No phase is implemented in this run. You take every planning decision on the owner's behalf and record each one, so the owner reviews them all in one sitting afterwards. This prompt is the approved design: do not run superpowers:brainstorming on it, and do not use superpowers:writing-plans for the execution plan (it is not a code plan). Use the Agent tool for steps, as described below.

## Blindness

A manual run of the same planning exists elsewhere. Do not read `~/git/nidana-bus-dart`, anything under `~/tmp`, or any document that describes how the manual run was done, and do not search for one. Your inputs are:

- this repository;
- the reference architecture: the three `*-v0_15_0.md` files under `ref/nidana-docs/arch/`. Everything else in that submodule, older `arch/` versions and anything under `loop/`, is superseded history and is never fed to a skill;
- the HSDD skills vendored under `.agents/skills/` (linked from `.claude/skills/`), and HSDD's own documentation and methodology spec under `~/git/hsdd/docs/` and `~/git/hsdd/spec/`;
- the Dart and Flutter SDKs through fvm, and public package documentation.

## Facts from the owner

These are facts, not decisions. Use them as given.

- Who builds what: Purbo alone, with coding agents. One team, one repository.
- The v0.15.0 Specification is accepted and frozen for v1, although its header says Draft. The Guide and the Rationale are informative.
- Toolchain: always `fvm dart` and `fvm flutter`, never a bare `dart`. The SDK is pinned in `.fvmrc`.
- Coding method for phase execution: superpowers, not OpenSpec. It lands in `hsdd/conventions.md` as `**Coding method:** superpowers` through the root hsdd-spec run. OpenSpec is not installed and is not to be installed. You may not install global tooling; project-local dev dependencies are fine.
- `ref/` is read-only. A change the reference architecture would need is recorded, never made.
- Work on the branch `auto/v1-planning`, created from `main`. Never squash, amend or force-push.

## Protocol

1. **Write your execution plan first**, at `docs/auto-run/execution-plan.md`, before any HSDD skill runs. It names the stages from settling the inputs to reconcile; for each step the skill it runs and on what node, contract or ADR, what the step reads, what done looks like, and the decisions you expect to take. It is the record of the path, not a promise: update it as you learn, and say in it what changed and why. Commit it before step 1 runs.

2. **One step is one HSDD skill invocation** on one node, one contract or one ADR. Run each step in a fresh subagent (Agent tool, general-purpose). The subagent's prompt carries: the exact skill and its arguments, the node and the files it may read, the Blindness section above, the Decision policy below, and the instruction to report back every decision it took in the decision-record shape (question, options with consequences, chosen, why, evidence, blast radius, confidence). The subagent writes its artifacts and nothing under `hsdd/judgement/`. You, the orchestrator, run no skill in your own context; your context is for sequencing, review and the ledger.

3. **When a skill stops and asks a question**, the subagent ends its turn and returns the question verbatim. You decide as the owner's stand-in, record the decision with `would_have_asked: true` and its `stop_class`, and dispatch a new subagent with the answer. Never let a subagent answer a skill's stop inside its own run: the stop must be visible in the record.

4. **After each step**, in order: check that the artifacts exist and the skill's own quality gates hold (`node hsdd/scripts/gen-registry.mjs` regenerates clean once it exists, nothing under frozen governance changed except through its owning skill, every cited id resolves); commit the step's artifacts in one commit whose message names the step, for example `hsdd: ADR-002 time source`; then append the step's decision lines to `hsdd/judgement/decisions.jsonl` with that commit's sha, append one line to `hsdd/judgement/run.jsonl` (`step_ref`, skill, target, started, finished, artifact commit), and commit those in a second commit, `judgement: <step_ref>`. Two commits per step, always.

5. **Steps run serially.** Do not use HSDD's parallel planning worktrees in this run.

6. **Experiments.** When a decision depends on a runtime fact (how a Dart stream replays, what a zone does, what fake_async settles), write a throwaway program under `docs/auto-run/experiments/<name>/`, run it through fvm, keep the source and the captured output there, and cite the path as evidence. Never guess a fact that ten minutes of code settles.

7. **Rework.** If a step's output fails its gates, rework it once in a new subagent with the finding stated. If it fails again, stop the run (below).

8. **Context.** Your context will be summarized during a long run. Everything you need to resume is on disk: the execution plan, the ledger, the run log, `git log`. After any summarization, re-read `docs/auto-run/execution-plan.md`, the last twenty lines of `hsdd/judgement/decisions.jsonl` and `git log --oneline -20` before continuing.

9. **Finish.** When every leaf-parent has a phase plan and reconcile has drained every pending governance update, write `docs/auto-run/REPORT.md` for the owner's one-sitting review: the tree in one picture with one paragraph per node; the decisions to look at first (lowest confidence, widest blast radius, every stop you answered on the owner's behalf); every decision grouped by blast radius, one line each with its id; the experiments and what each showed; the assumptions you made about the owner's intent; the decisions marked `would_upstream`, as a list of Specification sections with the proposed wording; and how the owner records reviews (one line per decision in `hsdd/judgement/decision-reviews.jsonl`: `decision`, `at`, `review` one of `agree`, `disagree`, `should-have-asked`, `reason`). Commit it. Then stop.

## Decision policy

**Decide and record** everything HSDD's planning asks of a human, except the stop set below. That includes: v1 scope, who the package consumers are, ordering policy, contract validation format, every proposed ADR (write it and accept it), every open question (resolve it in the node that owns it, as a `D{n}` or an ADR; where the right resolution is a change to the Specification, resolve it locally and mark the decision `would_upstream: true`), decomposition shape and depth, contract interfaces and guarantees, phase plans, tiers and gates, and at reconcile the `confirm` entries, the `request` entries (answer them yourself) and non-breaking `amend` entries.

A decision is recorded when it was taken, not reconstructed later. A decision with no evidence says so in `why`. When two options are close, say which signal would have changed your mind.

**Stop the run** only when one of these holds. Write `hsdd/judgement/STOP.md` naming the question, the options with your recommendation, what it blocks and how to resume; commit it; end your turn with no next step.

- A reconcile collision, or a contract amendment that would break an existing consumer. hsdd-reconcile says never auto-pick a winner, and this run agrees.
- A decision whose two leading options change the tree's shape (different nodes, or a different set of contracts), where the Specification is silent and no experiment settles it.
- Anything that needs something outside this repository: a credential, a private network resource, a change to `ref/`, or global tooling.
- A step that fails its own gates twice (protocol step 7).

A stop is the protocol working, not the run failing. Do not reword a stop condition into a decision to keep going.

## Decision record

One JSON line per decision, append-only, in `hsdd/judgement/decisions.jsonl`. The schema is `docs/auto-run/decision.schema.json`; read it before the first line. Fields: `id` (`DEC-001` onward), `at`, `step` (one of `setup`, `plan`, `root-spec`, `mid-level-spec`, `adr`, `contract`, `phase-plan`, `reconcile`), `step_ref`, `artifact`, `question`, `options` (label and consequence each), `chosen`, `why`, `evidence`, `blast_radius` (`node-local`, `contract`, `tree`, `upstream`), `confidence`, `would_have_asked`, `stop_class`, `would_upstream`, `commit`. Create `hsdd/judgement/` at the first line; it is the one place under `hsdd/` that you write directly rather than through a skill, and nothing else under `hsdd/` is.

Begin with the execution plan.

PROMPT END

---

## Goal

Run this after the prompt, as one line:

```text
/goal The automatic HSDD planning run is finished. Either hsdd/judgement/STOP.md exists and names an unresolved question, its options and the steps it blocks; or all of these hold: docs/auto-run/execution-plan.md and docs/auto-run/REPORT.md exist; every node spec under hsdd/spec/ whose Kind is leaf-parent contains a phase summary table; hsdd/contract/INDEX.md lists every contract id the specs name, and every contract file under hsdd/contract/ reads status: stable and phase_ids: final; no file under hsdd/spec/ holds a "Governance updates (pending reconcile)" section with undrained entries; `node hsdd/scripts/gen-registry.mjs` exits 0; every line of hsdd/judgement/decisions.jsonl parses as JSON and carries a commit sha; and `git status` is clean on branch auto/v1-planning.
```

The condition is a disjunction on purpose. The evaluator keeps re-prompting the session until the condition holds, so a legitimate stop must satisfy it; otherwise the session would be pushed past a question only the owner can answer.

## After the run

- Read `docs/auto-run/REPORT.md` first, then the ledger.
- Record one review line per decision in `hsdd/judgement/decision-reviews.jsonl`.
- Record artifact verdicts with the HSDD port of TBM's `verdict.mjs` once it exists (`accepted` or `changes-requested`, pinned to the artifact's blob).
