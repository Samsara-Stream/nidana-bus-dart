# Making the automatic HSDD run a harness

Yes, it can be packaged, and most of it already exists as files. The recommendation is an `hsdd-auto`
orchestrator skill that ships with the HSDD skills, with zero-dependency Node scripts doing the
sequencing, gating and record keeping. Claude Code adapters (permission deny rules, an optional Stop
hook) sit at the edges. That is the shape TBM R6 already decided for TBM: AUTO-11 makes the
orchestrator a skill that invokes the existing skills, AUTO-13 computes the plan with a script. Running
it on another project becomes `/hsdd-auto` plus one config file of owner facts. No prompt writing.

The rest of this document says what the run consisted of, what it cost, what went wrong, the
packaging options with their trade-offs, and the proposed design.

## What drove this run

| Component | Where it lived | Generic? | In the harness |
|---|---|---|---|
| Kickoff prompt: protocol, decision policy, stop set, blindness, owner facts | `docs/auto-run/KICKOFF.md` | Protocol and policy yes; facts and blindness no | Protocol moves into `SKILL.md`; facts and inputs move into a run config |
| `/goal` condition (Stop-hook evaluator that re-prompts until it holds) | typed by the owner | Yes, derived from tree state | `state.mjs done` computes it; the adapter can still set `/goal` from it |
| Execution plan, written by the model | `docs/auto-run/execution-plan.md` | The stage list yes; the step log no | Steps computed by `next.mjs`; the model writes only the change log |
| Step preamble, pasted verbatim into 52 prompts | `docs/auto-run/step-preamble.md` | Yes, with slots | Template filled from the run config |
| Step sections, one per dispatch | session scratchpad: four `*-common.md` templates (phase-plan, reconcile, contract-touch, spec-touch) plus hand-written routed items | Templates yes; routed items were the orchestrator's main work | Templates per step kind; routed items from a queue (below) |
| Step report and decision record schemas | `docs/auto-run/decision.schema.json`, the report block in the preamble | Yes | Unchanged, plus a structured `routed` field and a `model` field |
| Gate | `docs/auto-run/tools/gate.mjs` | Mostly; patched twice mid-run | Generalized: write sets keyed by skill and step kind, orchestrator-owned files from config |
| Ledger tool | `docs/auto-run/tools/ledger.mjs` | Yes | Unchanged |
| Waiting on subagents | 57 `ScheduleWakeup` calls | No, an artifact of background dispatch | Foreground dispatch; a long fallback only |
| Report generator | `gen_report.py`, `report.py` in the session scratchpad | Yes | `report.mjs` in the skill |
| Run explorer | `docs/auto-run/explorer/build.py` (written after the run) | Yes, given the transcripts | `explore.mjs`, fed from dispatch files the harness keeps |
| Experiments convention | the preamble's Experiments rule | Yes | Unchanged |
| Consistency pass (stage 7) | added mid-run as DEC-603 | Yes | A standard stage after the last reconcile |

## What the run cost

These numbers size the harness. They come from the session transcripts, through the explorer's data.

- **Steps.** 55 steps, 52 of them subagent dispatches. Every dispatch completed first time: no skill
  stop, no rework, no resumed dispatch. The protocol's stop and rework paths were never exercised, so
  they are untested design, not proven behavior.
- **Time.** 22 h 25 min wall clock, serial. Subagents were working for 20 h 45 min of it, so orchestrator
  overhead was about 6%. Median subagent time per step: contract 37 min, phase-plan 26, ADR 20,
  reconcile 18.5, spec touch 10.
- **Tokens.** Subagents: 1.78M output, 814M cache-read input, 18.3M cache-creation. Orchestrator: 0.68M
  output, 168M cache-read, 1.3M cache-creation. The orchestrator wrote over a quarter of all output
  tokens, mostly step prompts and its own review of reports. That share is what a computed plan and
  templated prompts would remove.
- **Context.** The orchestrator's context was summarized once during the run (at S42) and it resumed
  from the plan, the ledger tail and `git log`, as protocol step 8 intended.
- **Records.** 684 decisions; 304 cite an experiment; 4 have no evidence and say so.

## What went wrong, and what the harness does instead

1. **Prompts carried wrong facts.** The orchestrator wrote step sections from its memory of earlier
   reports. S47's prompt said ADR-001 had four amendments (it had three); S51 found that nidana.tooling.lint
   D2 was written by S36, not S23 as the prompt claimed. *Harness:* facts a prompt asserts come from
   files (`git log -S` for authorship, the ADR's own `## Amendments`), and every prompt tells the
   subagent to verify asserted facts before acting, as S52's prompt did.
2. **Timestamps.** From S09 to S16 the orchestrator stamped its own records by hand in local time
   labelled UTC (`docs/auto-run/timestamp-corrections.md`). *Harness:* scripts stamp every time;
   `ledger.mjs` already rejects future times.
3. **Inserted steps forced renumbering.** S46 and S52 shifted later step ids in the plan rows, the
   scratch prompt files and cross-references. *Harness:* step ids are allocated at dispatch, never
   planned ahead; the plan names step kinds and targets.
4. **The step log drifted.** A stale S10..S14 row and a garbled S42 row had to be fixed by hand.
   *Harness:* the step log is generated from `run.jsonl`.
5. **Blindness was only an instruction.** It held for every subagent, but the orchestrator itself
   read a memory file describing the manual run after the run had finished. *Harness:* the adapter
   writes permission deny rules for every out-of-bounds path into the project's `.claude/settings.json`
   before the first step. `Read(...)` rules do not stop `cat` through Bash, so the adapter also adds a
   PreToolUse hook that refuses Bash commands naming those paths, or runs the session with the sandbox's
   filesystem deny list. Running from a separate `CLAUDE_CONFIG_DIR` removes memory directories from
   reach entirely.
6. **The gate was patched twice mid-run.** At S03 it flagged orchestrator-owned files the orchestrator
   had edited while the step ran; at S28 it had to let hsdd-reconcile edit ADR text for step 13's OQ
   citation sweep. *Harness:* both become configuration: an orchestrator-owned file list, and write sets
   per step kind rather than per skill.
7. **Prompts and generators lived in the scratchpad.** The session scratchpad holds the step sections
   and the report generator; it is deleted with the session. The explorer had to recover the prompts
   from the transcripts. *Harness:* every rendered prompt is written to `hsdd/auto/dispatch/<step>.md`
   and committed in the judgement commit; generators are part of the skill.
8. **Polling.** Background dispatch meant 57 wake-ups, each one re-reading state. *Harness:* dispatch in
   the foreground so the orchestrator's turn resumes with the subagent's result; keep a long fallback
   wake-up only for a hung subagent.
9. **The consistency pass was improvised.** After S42 every contract was stable but plans contradicted
   amended governance in places (one gate would have written `test ^1.33.0`; topic-codegen's staleness
   check could never fail). The orchestrator added stage 7 on its own judgement. *Harness:* a standard
   stage: collect every "stale" note from step reports, route each to its owning skill, then one
   hsdd-reconcile sweep.
10. **Strictly serial.** The kickoff ruled out HSDD's parallel planning worktrees. Root ADRs (S03 to
    S05) and contracts with different producers have disjoint write sets apart from registries the
    orchestrator regenerates. Phase plans cannot parallelize under producer-first planning with a
    reconcile after each. The saving is real but bounded; measure it on the second run rather than
    assume it.

## Packaging options

| | A. Orchestrator skill + scripts | B. Claude Code plugin | C. External runner (Agent SDK or headless CLI) |
|---|---|---|---|
| What it is | `skills/hsdd-auto/SKILL.md` invoking the existing hsdd-* skills through subagents; Node scripts for state, prompts, gate, ledger, commits | The same skill plus a step-subagent definition with restricted tools, hooks (PreToolUse deny, SubagentStop gate), commands | A program with a deterministic state machine; each step is a fresh SDK session |
| Portability | Claude, Codex, Cursor (TBM CC-1) | Claude Code only | Any, but you maintain the integration |
| Enforcement | Scripts it calls, plus the model following `SKILL.md` | Tool level: a subagent cannot run git; blindness cannot be bypassed | Code level |
| Compaction and drift risk | Remains, reduced by computed plans and files on disk | Same as A | None in the sequencer; every step starts cold |
| Judgement points (stop answers, run-stop candidates, inserted steps) | In the orchestrator's context | Same | Need explicit model calls the runner makes |
| Fit with TBM R6 | Matches AUTO-11, AUTO-13 | R6 rejects a plugin for TBM | R6 rejects an external runner |

**Recommendation:** A as the core, with B's enforcement pieces as a Claude Code adapter that the skill
installs into the project (settings deny rules, the Bash PreToolUse hook, optionally the `/goal`
condition). TBM's CC-1 allows tool-specific adapters at the edges. C is worth it only if unattended runs
in CI become a goal; the judgement points would then need their own prompts, which is close to building
the judge (`docs/auto-run/JUDGEMENT-LAYER.md`).

## Proposed design: `hsdd-auto`

### Invocation

```text
/hsdd-auto            start or resume, reading hsdd/auto/run.yaml
/hsdd-auto status     where the run is, what is queued, what stopped
```

When `hsdd/auto/run.yaml` does not exist, the skill asks its questions once and writes the file. That is
the only interactive moment. For this project the file would read:

```yaml
run: v1-planning
branch: auto/v1-planning          # created from base; never squash, amend or force-push
base: main
mode: plan-through-reconcile      # no phase is implemented
models: { orchestrator: claude-opus-5-5, step: claude-opus-5-5 }
owner_facts:
  - "Who builds what: Purbo alone, with coding agents. One team, one repository."
  - "The v0.15.0 Specification is accepted and frozen for v1, although its header says Draft. The Guide and the Rationale are informative."
  - "Coding method for phase execution: superpowers, not OpenSpec."
  - "You may not install global tooling; project-local dev dependencies are fine."
preferences_from: ~/.claude/CLAUDE.md   # functional-first engineering preferences
sources:
  normative: [ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_0.md]
  informative: [ref/nidana-docs/arch/nidana-bus-ref-arch-guide-v0_15_0.md, ref/nidana-docs/arch/nidana-bus-ref-arch-rationale-v0_15_0.md]
read_only: [ref/]
out_of_bounds: [~/git/nidana-bus-dart, ~/tmp, ~/.claude*/projects/*/memory, ~/git/hsdd/docs/superpowers]
toolchain:
  run: fvm dart          # never a bare dart
  flutter: fvm flutter
prose_rules_from: ~/.claude/CLAUDE.md   # banned characters and phrases, read at render time
stop_set: [collision, breaking-amend, shape-unsettled, external, gate-twice]
experiments_dir: docs/auto-run/experiments
```

### Files

```text
skills/hsdd-auto/
  SKILL.md                     the loop, the judgement points, stop handling
  templates/preamble.md        this run's step-preamble.md with {slots}
  templates/steps/             root-spec, mid-level-spec, adr, adr-update, contract, contract-touch,
                               spec-touch, phase-plan, reconcile, sweep
  schema/                      decision, step-report, run-line, run-config (JSON Schema)
  scripts/state.mjs            reads the tree, the ledger and the queue; `done` is the goal condition
  scripts/next.mjs             the runnable steps and their inputs (TBM AUTO-13)
  scripts/dispatch.mjs         renders a prompt to hsdd/auto/dispatch/<step>.md
  scripts/gate.mjs             this run's gate, configured from run.yaml
  scripts/ledger.mjs           this run's ledger tool, plus model and token fields
  scripts/commit.mjs           the two commits; refuses a staged file outside the step's write set
  scripts/routed.mjs           the routing queue (below)
  scripts/report.mjs           REPORT.md from the ledger and the reports
  scripts/explore.mjs          the explorer data (a Node port of docs/auto-run/explorer/build.py)
  adapters/claude-code/        settings.json deny rules, the Bash PreToolUse hook, the /goal line
```

### The loop

1. `next.mjs` returns the runnable steps, `done`, or `blocked` (a STOP exists).
2. For each step, `dispatch.mjs` renders the prompt, and the orchestrator dispatches one fresh subagent
   in the foreground.
3. The subagent returns `completed`, `stopped` (a skill stop, the question verbatim) or
   `run-stop-candidate`.
4. `completed`: `gate.mjs`, then `commit.mjs` (artifacts), `ledger.mjs`, `routed.mjs ingest`,
   `commit.mjs` (judgement).
5. `stopped`: the orchestrator answers as the owner's stand-in, records the decision with
   `would_have_asked: true`, and re-dispatches with the answer.
6. `run-stop-candidate`: the orchestrator judges it against the stop set. If it holds, write
   `hsdd/judgement/STOP.md` and end. If not, record why and continue.
7. A gate failure is reworked once with the finding stated; a second failure stops the run.
8. After the last reconcile: the sweep stage, then `report.mjs`, then stop.

Where the model is needed and where it is not:

| Work | Who |
|---|---|
| Which step runs next, its inputs, its write set | `next.mjs` |
| Rendering the prompt, including routed items | `dispatch.mjs` |
| Gate, commits, ledger lines, timestamps, run log | scripts |
| Answering a skill stop as the owner's stand-in | orchestrator model |
| Judging a run-stop candidate | orchestrator model (later the judge) |
| Accepting an `insert-step` item into the plan | orchestrator model, recorded as a `plan` decision |
| The skill's own work | step subagent |

### The routing queue

Most of the orchestrator's real work in this run was routing. Each report's `notes_for_orchestrator`
held follow-ups for later steps ("nidana.runtime's plan must fix its own Contracts table"), which the
orchestrator carried in its context and wove into later prompts under "Items routed to this plan by
earlier steps", or turned into inserted steps (S10, S13, S27, S38, S46, S52). That is where context
loss would hurt most, and it is not structured today.

The proposal: the step report gains a `routed` array.

```json
{ "target": "nidana.runtime", "kind": "must-address", "text": "add nidana.tooling to the bus-testing@v1 row of the Contracts table", "from": "S26" }
```

`kind` is `must-address`, `consider` or `insert-step`. `routed.mjs` keeps the queue in
`hsdd/auto/queue.jsonl`. `dispatch.mjs` injects the open items for a step's target, and the step's report
must close each one, as addressed or explained. An open `must-address` item blocks the final gate. An
`insert-step` item becomes a step once the orchestrator accepts it.

### What should move into HSDD itself

- **An autonomy flag the skills read.** Today the preamble overrides each skill's "stop and ask" by
  instruction. A skill that knows it runs unattended can emit a structured stop record itself.
- **Decisions at source.** Each `SKILL.md` names its ask-the-human points. In unattended mode the skill
  writes the decision record (question, options with consequences, chosen, why, evidence) where the
  question arises, instead of the subagent reconstructing it for the report.
- **Template tokens.** HSDD templates use an em-dash as an empty-cell and heading token; the preamble
  had to map each one to a replacement HSDD's tooling parses identically. A configurable token set
  removes that rule from every prompt.
- **The sweep.** hsdd-reconcile's step 2 already runs named steps when no pending section exists, which
  is what S53 used. Naming "sweep after amendments" as a reconcile mode makes the consistency pass
  standard.

### Getting there from this run's files

1. Copy `gate.mjs`, `ledger.mjs`, `decision.schema.json` and `step-preamble.md` into
   `~/git/hsdd/skills/hsdd-auto/`, and turn the project facts in the preamble into slots.
2. Recover the step sections from the explorer's data (`data/steps/S*.json`, field `prompt`) and reduce
   them to the step-kind templates. The scratchpad copies will not survive the session.
3. Write `state.mjs` and `next.mjs` against HSDD's registries (`gen-registry.mjs` output, contract
   front matter, pending sections).
4. Add `routed`, `model` and token fields to the report and run-line schemas.
5. Write the Claude Code adapter and test that the deny rules hold against Read, Grep and `cat`.
6. Dry-run on a small sandbox project, the way TBM uses `sandbox/acme`.
7. Re-run nidana-bus-dart from scratch on a new branch with the harness and compare it with
   `auto/v1-planning`. That second run measures run-to-run variance, which the judgement layer needs
   anyway.
