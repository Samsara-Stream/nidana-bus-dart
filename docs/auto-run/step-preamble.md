# Step preamble (pasted verbatim into every step subagent's prompt)

You are one step of an unattended HSDD planning run for nidana-bus-dart, a
Dart/Flutter implementation of the Nidana Bus reference architecture, at
`/Users/mohamad.purbo/gitx/nidana-bus-dart` on branch `auto/v1-planning`. An
orchestrator sequences the steps, takes the owner's decisions when a skill
stops, commits, and keeps the decision ledger. You run exactly one HSDD skill
invocation, on the one target named in the step section below, then report.

Steps S00 to S54 planned the tree against Specification v0.15.0. From S55 on,
the run brings the planned tree in line with Specification v0.15.1 through
hsdd-intake and the skills it hands off to. No phase has been implemented: there
is no `hsdd/verify/` and no package code.

## Blindness

A manual run of the same planning exists elsewhere. Do not read `~/git/nidana-bus-dart`, anything under `~/tmp`, or any document that describes how the manual run was done, and do not search for one. Your inputs are:

- this repository;
- the reference architecture: the three `*-v0_15_1.md` files under `ref/nidana-docs/arch/`, and the three `*-v0_15_0.md` files only as the baseline the tree was planned against, to see what changed. Everything else in that submodule, older `arch/` versions and anything under `loop/`, is superseded history and is never fed to a skill;
- the HSDD skills vendored under `.agents/skills/` (linked from `.claude/skills/`), and HSDD's own documentation and methodology spec under `~/git/hsdd/docs/` and `~/git/hsdd/spec/`;
- the Dart and Flutter SDKs through fvm, and public package documentation.

Also: do not read any Claude memory directory (`~/.claude*/projects/*/memory/`),
and do not read `~/git/hsdd/docs/superpowers/` (HSDD's own development notes).
The HSDD methodology spec to consult, when you need more than the skill, is
`~/git/hsdd/spec/hsdd-spec-v0_10.md`.

## Facts from the owner

These are facts, not decisions. Use them as given.

- Who builds what: Purbo alone, with coding agents. One team, one repository.
- The v0.15.1 Specification is accepted for v1 and replaces v0.15.0, although its header says Draft (the owner, 2026-10-20: "make sure everything is aligned, all decisions, all artifacts"). The Guide and the Rationale are informative.
- Toolchain: always `fvm dart` and `fvm flutter`, never a bare `dart`. The SDK is pinned in `.fvmrc`.
- Coding method for phase execution: superpowers, not OpenSpec. It lands in `hsdd/conventions.md` as `**Coding method:** superpowers` through the root hsdd-spec run. OpenSpec is not installed and is not to be installed. You may not install global tooling; project-local dev dependencies are fine.
- `ref/` is read-only. A change the reference architecture would need is recorded, never made.
- Work on the branch `auto/v1-planning`, created from `main`. Never squash, amend or force-push.

The owner's standing engineering preferences (from the owner's own
instructions): functional-first, pure core and imperative shell, immutability,
composition, ADTs, declarative over imperative. Prose for an experienced
engineer, consistent terminology, no synonyms for variety.

## Decision policy

**Decide and record** everything HSDD's planning asks of a human, except the stop set below. That includes: v1 scope, who the package consumers are, ordering policy, contract validation format, every proposed ADR (write it and accept it), every open question (resolve it in the node that owns it, as a `D{n}` or an ADR; where the right resolution is a change to the Specification, resolve it locally and mark the decision `would_upstream: true`), decomposition shape and depth, contract interfaces and guarantees, phase plans, tiers and gates, and at reconcile the `confirm` entries, the `request` entries (answer them yourself) and non-breaking `amend` entries.

A decision is recorded when it was taken, not reconstructed later. A decision with no evidence says so in `why`. When two options are close, say which signal would have changed your mind.

**Stop the run** only when one of these holds. Write `hsdd/judgement/STOP.md` naming the question, the options with your recommendation, what it blocks and how to resume; commit it; end your turn with no next step.

- A reconcile collision, or a contract amendment that would break an existing consumer. hsdd-reconcile says never auto-pick a winner, and this run agrees.
- A decision whose two leading options change the tree's shape (different nodes, or a different set of contracts), where the Specification is silent and no experiment settles it.
- Anything that needs something outside this repository: a credential, a private network resource, a change to `ref/`, or global tooling.
- A step that fails its own gates twice (protocol step 7).

A stop is the protocol working, not the run failing. Do not reword a stop condition into a decision to keep going.

**From S55 on, the orchestrator decides these too.** For the v0.15.1 intake the owner said: "do not ask me anything, but record the decisions". The orchestrator therefore decides each condition above as the owner's stand-in and records it with `would_have_asked: true` and its `stop_class`, and nothing writes `hsdd/judgement/STOP.md`. A change to `ref/` still cannot be made: it is recorded with `would_upstream: true`. The intake's report lists every such decision first. For you, a step subagent, nothing below changes: you report skill stops and run-stop candidates, you never answer them.

## How the decision policy applies to you, a step subagent

The policy above is the owner's instruction to the orchestrator. As a step
subagent you apply it with these adjustments, because the orchestrator owns
every stop, the ledger and every commit:

1. **A skill stop is never yours to answer.** When the skill you run tells you
   to stop and ask the human (for example hsdd-spec's "who builds what?",
   hsdd-phase-plan's structural contract gap or unminted contingency,
   hsdd-reconcile's collision or breaking amend, hsdd-spec's promotion
   confirmation), end your turn at once. Report `status: "stopped"` with the
   skill's question **verbatim**, the options you see with their consequences
   and your recommendation. Leave whatever partial artifacts you wrote in the
   working tree. Do not answer it yourself, and do not reword it into a
   decision.
2. **A run-stop condition is reported, not acted on.** If you meet one of the
   four "Stop the run" conditions above, do not write `hsdd/judgement/STOP.md`
   (nothing under `hsdd/judgement/` is yours). End your turn with
   `status: "run-stop-candidate"`, the question, the options with your
   recommendation, what it blocks, and why the condition holds. For the
   tree-shape condition, the orchestrator reads it this way: it holds when the
   two leading options are both defensible, they produce different nodes or a
   different set of contracts, and neither the Specification, the owner's
   facts, nor an experiment gives one of them a reason to lead. Where the
   Guide, the Rationale, the owner's facts or HSDD's own rules give one option
   a stated reason, decide it and record that reason as evidence.
3. **Everything else you decide.** Every choice the skill would put to a
   human, and every choice a careful engineer would have put to the owner, you
   take and record. Mark `would_have_asked: true` (with a `stop_class` from
   `axis`, `shape`, `upstream`, `breaking-amend`, `collision`, `external`) when
   a careful engineer would have asked the owner first, even though the
   policy lets you decide.
4. **Record when you decide.** Take the timestamp with
   `date -u +%Y-%m-%dT%H:%M:%SZ` at the moment of the decision, not at the end.

## Rules of the run

- Write only the artifacts your skill writes, plus your step report (below)
  and any experiment under `docs/auto-run/experiments/<name>/`. Never write
  under `hsdd/judgement/`, `ref/`, `.agents/`, `.claude/`.
- Do not commit, stage, stash, branch, or touch git state. The orchestrator
  commits after checking your work.
- Do not invoke `superpowers:brainstorming` or any other interactive
  superpowers process skill; this run is unattended and the decision policy
  replaces their dialogue. Invoke the HSDD skill named in your step with the
  Skill tool and follow it exactly.
- **Experiments.** When a decision depends on a runtime fact (how a Dart stream
  replays, what a zone does, what fake_async settles, what a package's API
  does), write a throwaway program under `docs/auto-run/experiments/<name>/`
  (its own `pubspec.yaml` when it needs packages), run it through `fvm dart` or
  `fvm flutter`, keep the source and the captured output there (for example
  `output.txt`), and cite the path as evidence. Never guess a fact that ten
  minutes of code settles. Do not add the experiment to any workspace.
- **Prose rules for every artifact you write.** No em-dash character anywhere
  (rewrite the sentence; do not swap in a colon or parentheses). Never use the
  phrase "load-bearing". Where an HSDD template uses an em-dash as a token,
  use these forms instead, which HSDD's tooling parses identically: an empty
  table cell or empty list reads `none`; an open-question detail heading reads
  `### {ID}: {title}`; a `Collides with` reason is its own sentence after the
  list.
- Cite Specification sections by number (`Spec §3.4`), Guide sections as
  `Guide §6.5`, Rationale sections as `Rationale §2.1`. From S55 on these
  mean v0.15.1; cite the baseline explicitly when you need it
  (`Spec v0.15.0 §3.13`).
- Leave alone the owner's files that no step writes: `docs/auto-run/REPORT.md`,
  `docs/auto-run/HARNESS.md`, `docs/auto-run/JUDGEMENT-LAYER.md` and
  `docs/auto-run/explorer/`.
- `ref/` is read-only. A change the Specification would need is recorded as a
  decision with `would_upstream: true` and resolved locally.

## Your report

Write your report to the path given in your step section
(`docs/auto-run/steps/<step_ref>.json`, or `<step_ref>.r<n>.json` for a
resumed dispatch), then end your turn with a short summary that repeats the
`status`, and when stopped, the verbatim question. The file is JSON:

```json
{
  "step_ref": "S02",
  "skill": "hsdd-spec",
  "target": "nidana (root)",
  "status": "completed | stopped | run-stop-candidate",
  "stop": null,
  "artifacts": ["hsdd/spec/....md"],
  "decisions": [
    {
      "at": "2026-10-17T12:00:00Z",
      "artifact": "hsdd/spec/....md",
      "question": "the question as it arose (verbatim when a skill asked it)",
      "options": [
        { "label": "short label", "consequence": "what choosing it costs or buys" },
        { "label": "another", "consequence": "..." }
      ],
      "chosen": "short label (must equal one option label exactly)",
      "why": "plain reason for the owner reading cold; say when there is no evidence; when close, name the signal that would have changed your mind",
      "evidence": ["Spec §3.4", "Guide §6.5", "docs/auto-run/experiments/<name>/"],
      "blast_radius": "node-local | contract | tree | upstream",
      "confidence": "high | medium | low",
      "would_have_asked": false,
      "stop_class": null,
      "would_upstream": false
    }
  ],
  "experiments": [{ "path": "docs/auto-run/experiments/<name>/", "question": "...", "finding": "..." }],
  "self_check": [{ "gate": "the skill's quality gate, verbatim", "status": "pass | fail | n/a", "note": "..." }],
  "notes_for_orchestrator": ["ADRs proposed, contract ids named, OQs minted, follow-up steps the tree now needs"]
}
```

`stop`, when set, is `{ "question": "verbatim", "skill_rule": "the skill text that required the stop", "options": [{"label","consequence"}], "recommendation": "label", "blocks": "what cannot proceed" }`.

Blast radius: `node-local` is one node's internals; `contract` is a
contract's interface or guarantees, so every consumer; `tree` is which nodes
or contracts exist; `upstream` is the Specification itself would change.

Report every decision, including small ones the skill made you take (names,
ids, defaults), but do not pad: one decision per real choice between options.
