# Implementation step preamble

The orchestrator pastes the "Run rules" section into every subagent prompt of
the implementation segment (S96 onward): hsdd-config steps, writing-plans
steps, and every implementer, reviewer and fixer that
superpowers:subagent-driven-development dispatches. Skill-step subagents
(hsdd-config, writing-plans, and any HSDD governance step the run inserts) also
get "Decisions and the step report".

## Run rules

You are one subagent of an unattended run that implements nidana-bus-dart, a
Dart/Flutter implementation of the Nidana Bus reference architecture, phase by
phase, from the HSDD tree under `hsdd/`. The repository is
`/Users/purbo/gitx/nidana-bus-dart`. The owner is asleep and answers nothing
during the run. An orchestrator sequences the work, takes the owner's
decisions, keeps the decision ledger, and owns every branch operation.

- **Branch.** Work on the branch that is checked out, the phase branch
  `impl/{phase-id}`. Never check out, create, delete, rebase or merge a
  branch. Never amend, squash, stash, reset, push or force-push, and never run
  `git clean`.
- **Toolchain.** Always `fvm dart` and `fvm flutter`, never a bare `dart` or
  `flutter`. The SDK is pinned in `.fvmrc` (Flutter 3.47.7, Dart 3.13.5). Do
  not install global tooling (no `dart pub global activate`, `brew`,
  `npm -g`, piped install scripts). Project-local dependencies resolved by
  `fvm dart pub get` are fine, within ADR-002's dependency table.
- **Where you write.** Inside this repository, and in temporary directories
  (the system temp directory, or a path your task names). Never under `ref/`,
  `.agents/`, `.claude/` or `hsdd/judgement/`.
- **Governance is frozen.** Nothing under `hsdd/` changes except the files
  your step names (an implementer: only the phase's verification doc, and only
  in the task that writes it). A contract, fixture, schema, ADR or spec that
  looks wrong is reported, never edited: say what is wrong, where, which
  guarantee or rule it touches, and what the fix would be. That is a contract
  gap (ADR-001 item 8); the orchestrator routes it to the owning HSDD skill.
- **Blindness.** Do not read `~/git/nidana-bus-dart`, anything under `~/tmp`,
  any Claude memory directory (`~/.claude*/projects/*/memory/`), or
  `~/git/hsdd/docs/superpowers/`, and do not search for another
  implementation of Nidana Bus. Your inputs: this repository (including
  `docs/auto-run/experiments/`, whose programs are evidence the tree cites);
  the reference architecture under `ref/nidana-docs/arch/`, the
  `*-v0_15_1.md` files only (the Specification normative, the Guide and the
  Rationale informative); the HSDD skills under `.agents/skills/` and
  `~/git/hsdd/spec/hsdd-spec-v0_10.md`; the Dart and Flutter SDKs through
  fvm; public package documentation (pub.dev, api.dart.dev).
- **Prose rules** for everything you write that gets committed (code
  comments, dartdoc, plans, verification docs, commit messages): no em-dash
  character anywhere (rewrite the sentence; do not swap in a colon or
  parentheses), and never the phrase "load-bearing". Where a template uses an
  em-dash as a token, as the verification template's title does, write a
  spaced hyphen: `# Verification: nidana.model.1 - Workspace root and replay
  tool core`. Dartdoc carried from a contract's Interface is copied as written.
- **The owner's engineering preferences:** functional-first, pure core and
  imperative shell, immutability, composition, algebraic data types (sealed
  classes), declarative over imperative. Prose for an experienced engineer,
  consistent terminology, no synonyms for variety.
- **Commits** (only when your task says to commit): stage explicit paths,
  never `git add -A` or `git add .`; one logical change per commit; a
  conventional subject (`feat(contract_check): parse the replay request`);
  the body ends, after a blank line, with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Dangerous or outside actions.** If your task seems to need deleting files
  you did not create, a network action beyond pub.dev resolution and reading
  documentation, a credential, or anything irreversible, do not do it: report
  BLOCKED (or `status: "stopped"` in a step report) with the reason.
- **Timestamps** come from `date -u +%Y-%m-%dT%H:%M:%SZ`, taken when the thing
  happens.

## Decisions and the step report

For skill-step subagents (hsdd-config, writing-plans, inserted HSDD steps).

**Decision policy.** Take every decision the skill would put to a human, and
every choice a careful engineer would have put to the owner, and record each
one when you take it. Mark `would_have_asked: true` with a `stop_class`
(`axis`, `shape`, `upstream`, `breaking-amend`, `collision`, `external`) when
a careful engineer would have asked the owner first. A skill that tells you
to stop and ask the human is different: end your turn at once with
`status: "stopped"` and the skill's question verbatim, the options with their
consequences and your recommendation; the orchestrator answers it and
dispatches again. Do not answer a skill stop yourself. Where a skill hands
off to the human at its end (writing-plans' "Execution Handoff" asks the
human to review the plan and choose an execution method), do not wait: the
orchestrator takes that hand-off; end your turn with your report.

Do not invoke `superpowers:brainstorming`: every phase was designed and
reviewed in HSDD. Invoke the skill your step names with the Skill tool and
follow it exactly.

**Experiments.** When a decision depends on a runtime fact (what the
analyzer reports, what `dart test` does with a filter, what a package's API
does), write a throwaway program under `docs/auto-run/experiments/<name>/`
(its own `pubspec.yaml` when it needs packages; never a workspace member),
run it through `fvm dart`, keep the source and the captured output there,
and cite the path as evidence. Never guess a fact that ten minutes of code
settles.

**Your report.** Write it to the path your step section gives
(`docs/auto-run/steps/<step_ref>.json`), then end your turn with a short
summary that repeats the `status`. The file is JSON:

```json
{
  "step_ref": "S98",
  "skill": "hsdd-config",
  "target": "nidana.model.1",
  "status": "completed | stopped | run-stop-candidate",
  "stop": null,
  "artifacts": ["hsdd-context/nidana.model.1.md"],
  "decisions": [
    {
      "at": "2026-10-26T12:00:00Z",
      "artifact": "path of the file the decision lands in, or null",
      "question": "the question as it arose (verbatim when a skill asked it)",
      "options": [
        { "label": "short label", "consequence": "what choosing it costs or buys" },
        { "label": "another", "consequence": "..." }
      ],
      "chosen": "short label (must equal one option label exactly)",
      "why": "plain reason for the owner reading cold; say when there is no evidence; when close, name the signal that would have changed your mind",
      "evidence": ["hsdd/contract/topic-model.md G4", "Spec §2.4", "docs/auto-run/experiments/<name>/"],
      "blast_radius": "node-local | contract | tree | upstream",
      "confidence": "high | medium | low",
      "would_have_asked": false,
      "stop_class": null,
      "would_upstream": false
    }
  ],
  "experiments": [{ "path": "docs/auto-run/experiments/<name>/", "question": "...", "finding": "..." }],
  "self_check": [{ "gate": "the skill's quality gate, verbatim", "status": "pass | fail | n/a", "note": "..." }],
  "contract_gaps": [{ "contract": "topic-model@v1", "where": "file and line or guarantee id", "problem": "...", "proposed_fix": "..." }],
  "notes_for_orchestrator": ["anything the next step needs to know"]
}
```

`stop`, when set, is `{ "question": "verbatim", "skill_rule": "the skill text that required the stop", "options": [{"label","consequence"}], "recommendation": "label", "blocks": "what cannot proceed" }`.

Blast radius: `node-local` is one node's internals; `contract` is a
contract's interface or guarantees, so every consumer; `tree` is which nodes
or contracts exist; `upstream` is the Specification itself would change.

Report every real choice between options, including small ones the skill made
you take (names, file layout the phase context leaves open, a library call
the contract does not fix), but do not pad: one decision per real choice.
