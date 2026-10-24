# Making the automatic HSDD run a harness

Yes, it can be packaged, and most of it already exists as files. The recommendation is an `hsdd-auto`
orchestrator skill that ships with the HSDD skills, with zero-dependency Node scripts doing the
sequencing, gating and record keeping. Claude Code adapters (permission deny rules, an optional Stop
hook) sit at the edges. That is the shape TBM R6 already decided for TBM: AUTO-11 makes the
orchestrator a skill that invokes the existing skills, AUTO-13 computes the plan with a script. Running
it on another project becomes `/hsdd-auto` plus one config file of owner facts. No prompt writing.

The run now has two segments in one session. S00 to S54 planned the tree on Specification v0.15.0.
Two days later the owner moved `ref/nidana-docs` to v0.15.1, and S55 to S95 routed that change
through hsdd-intake and re-planned what it touched. The second segment is a second mode the harness
needs (intake into a planned tree), and it re-tested several fixes this document proposes.

The rest of this document says what the run consisted of, what it cost, what went wrong, the
packaging options with their trade-offs, and the proposed design.

## What drove this run

| Component | Where it lived | Generic? | In the harness |
|---|---|---|---|
| Kickoff prompt: protocol, decision policy, stop set, blindness, owner facts | `docs/auto-run/KICKOFF.md` | Protocol and policy yes; facts and blindness no | Protocol moves into `SKILL.md`; facts and inputs move into a run config |
| Change request that opened the intake segment | one owner message, 2026-10-20: align everything with v0.15.1 through hsdd-intake, ask nothing, record the decisions | The request yes; its wording no | `/hsdd-auto intake <source>`, with the stop policy in the run config |
| `/goal` condition (Stop-hook evaluator that re-prompts until it holds) | typed by the owner | Yes, derived from tree state | `state.mjs done` computes it; the adapter can still set `/goal` from it |
| Execution plan, written by the model | `docs/auto-run/execution-plan.md`; in the intake, the intake record's Routing section (23 handoffs) | The stage list yes; the step log no | Steps computed by `next.mjs`, from the tree or from an intake record's handoffs; the model writes only the change log |
| Step preamble, pasted verbatim into every dispatch | `docs/auto-run/step-preamble.md`, one version per segment (52 prompts, then 38) | Yes, with slots | Template filled from the run config |
| Step sections, one per dispatch | session scratchpad: four `*-common.md` templates (phase-plan, reconcile, contract-touch, spec-touch) plus hand-written routed items; in the intake, written inline in each dispatch | Templates yes; routed items were the orchestrator's main work | Templates per step kind; routed items from a queue (below) |
| Notes carried between intake steps (deferred findings, per-handoff notes) | session scratchpad files | Yes | The routing queue (below) |
| Step report and decision record schemas | `docs/auto-run/decision.schema.json`, the report block in the preamble | Yes | Unchanged, plus a structured `routed` field and a `model` field |
| Gate | `docs/auto-run/tools/gate.mjs` | Mostly; patched twice mid-run in the first segment, extended once before the intake's first skill step | Generalized: write sets keyed by skill and step kind, orchestrator-owned and owner files from config |
| Owner-file guard | `docs/auto-run/tools/owner-files.json` and the gate's owner patterns (S56) | Yes | `owner_files` in the run config, hashed at start |
| Ledger tool | `docs/auto-run/tools/ledger.mjs` | Yes | Unchanged (the intake added the `intake` step type) |
| Commit script | `commit_step.sh` in the session scratchpad, from S64: gate, both commits, ledger lines, run line, plan row | Yes | `commit.mjs` |
| Waiting on subagents | 57 `ScheduleWakeup` calls in the first segment; none in the intake, which waited for each hand-back message | No, an artifact of background dispatch | The hand-back, or foreground dispatch; a long fallback only |
| Report generator | `gen_report.py`, `report.py` in the session scratchpad; the intake's `REPORT-v0_15_1.md` was written by hand | Yes | `report.mjs` in the skill, with an intake variant |
| Run explorer | `docs/auto-run/explorer/build.py` (written after the first segment, rebuilt for both) | Yes, given the transcripts | `explore.mjs`, fed from dispatch files the harness keeps |
| Experiments convention | the preamble's Experiments rule | Yes | Unchanged |
| Consistency pass | stage 7, added mid-run as DEC-603; in the intake, planned up front as handoff H23 | Yes | A standard stage after the last reconcile |

## What the run cost

These numbers size the harness. They come from the session transcripts, through the explorer's data,
computed the same way for both segments.

| | Planning, S00 to S54 | Intake, S55 to S95 |
|---|---|---|
| Steps; subagent dispatches | 55; 52 | 41; 38, plus one resume |
| Wall clock, serial | 22 h 25 min | 8 h 24 min |
| Subagents working | 20 h 44 min | 7 h 19 min |
| Orchestrator overhead | 7% | 13% |
| Median subagent time per step | contract 37 min, phase-plan 26, ADR 20, reconcile 18, spec touch 10 | intake 25 min, contract 30, phase-plan 17, spec touch 7, reconcile 7, citation touch 4.5 |
| Subagent tokens | 1.78M output, 814M cache-read, 18.3M cache-creation | 0.58M output, 415M cache-read, 8.9M cache-creation |
| Orchestrator tokens | 0.68M output, 168M cache-read, 1.3M cache-creation | 0.40M output, 84M cache-read, 0.75M cache-creation |
| Orchestrator share of output | 28% | 41% |
| Context summaries during the segment | 1 (at S42) | 0 |
| Decisions; citing an experiment; with no evidence | 684; 304; 4 | 387; 111; 1 |

- **First-time completion.** Every dispatch in both segments completed without a skill stop or a
  run-stop candidate. In the intake the orchestrator decided the one stop class it was sure to meet
  before any subagent met it (DEC-688), so the stop path is still untested. The rework path ran once:
  S65 was resumed with a finding (item 14 below).
- **The orchestrator's share grew.** Intake steps were small (twelve citation touches with a median of
  4.5 minutes) while each prompt stayed 15,000 to 25,000 characters, about 12,000 of them the preamble.
  The orchestrator wrote 41% of all output tokens. That share is what a computed plan and templated
  prompts would remove, and the intake makes the case more strongly than the first segment did.
- **Context.** The orchestrator's context was summarized once in the first segment, and it resumed
  from the plan, the ledger tail and `git log`, as protocol step 8 intended. The intake ran in one
  context.

## What went wrong, and what the harness does instead

1. **Prompts carried wrong facts.** The orchestrator wrote step sections from its memory of earlier
   reports. S47's prompt said ADR-001 had four amendments (it had three); S51 found that nidana.tooling.lint
   D2 was written by S36, not S23 as the prompt claimed. It recurred in the intake: S57's prompt placed
   the RxDart bullet in Spec §3.6 (it is §3.3), and S78's called the S60 stand-in runtime "bus-owned
   storage" (it wraps an RxDart subject). Neither prompt asked for verification; both subagents checked
   the claim against its source while doing the skill's work and corrected it in their reports. The
   cause did not go away. *Harness:* facts
   a prompt asserts come from files (`git log -S` for authorship, the ADR's own `## Amendments`), and
   every prompt tells the subagent to verify asserted facts before acting, as S52's prompt did.
2. **Timestamps.** From S09 to S16 the orchestrator stamped its own records by hand in local time
   labelled UTC (`docs/auto-run/timestamp-corrections.md`). It recurred in the intake. The ten
   orchestrator decisions of S55 and S56 carry hand-picked times: DEC-685 (16:02:10Z) precedes the
   owner's message (16:04:09Z), S55's run line starts at 16:00:00Z, and S56's three times were moved
   earlier after `ledger.mjs` rejected them as future. Subagents can fail the same way: S59 did not
   stamp its decisions as it took them, so 12 of its 13 times are upper bounds from file birth times.
   *Harness:* scripts stamp every time. The orchestrator records a decision through `ledger.mjs`,
   which stamps it; the subagent records one through a `decide.mjs` that appends a stamped decision to
   its report at the moment it is taken. `ledger.mjs` already rejects future times.
3. **Inserted steps forced renumbering.** S46 and S52 shifted later step ids in the plan rows, the
   scratch prompt files and cross-references. The intake fixed this by rule: handoffs took step ids in
   dispatch order and skipped handoffs took none, so its four inserted steps (S68, S81, S83, S84)
   renumbered nothing. *Harness:* step ids are allocated at dispatch, never planned ahead; the plan
   names step kinds and targets.
4. **The step log drifted.** A stale S10..S14 row and a garbled S42 row had to be fixed by hand. In the
   intake, rows moved from planned to running to done by hand edits until S63; from S64 the commit
   script appended each row from its arguments. *Harness:* the step log is generated from `run.jsonl`.
5. **Blindness was only an instruction.** It held for every subagent in both segments, but the
   orchestrator itself read a memory file describing the manual run after each segment had finished. *Harness:* the adapter writes permission deny rules for every out-of-bounds path into the
   project's `.claude/settings.json` before the first step. `Read(...)` rules do not stop `cat` through
   Bash, so the adapter also adds a PreToolUse hook that refuses Bash commands naming those paths, or
   runs the session with the sandbox's filesystem deny list. Running from a separate `CLAUDE_CONFIG_DIR`
   removes memory directories from reach entirely.
6. **The gate was patched twice mid-run.** At S03 it flagged orchestrator-owned files the orchestrator
   had edited while the step ran; at S28 it had to let hsdd-reconcile edit ADR text for step 13's OQ
   citation sweep. In the intake the gate was extended once, at S56, before the first skill step
   (hsdd-intake's write set, the owner-file guard, warnings for references to a superseded contract
   version) and not patched again. *Harness:* both become configuration: an orchestrator-owned file
   list, and write sets per step kind rather than per skill.
7. **Prompts and generators lived in the scratchpad.** The session scratchpad held the step sections
   and the report generator. It recurred in the intake: the commit script, the S57 step file and the
   orchestrator's notes for later handoffs lived there too. That scratchpad has since been emptied, so
   only the transcripts and the explorer's data still hold the prompts. *Harness:* every rendered
   prompt is written to `hsdd/auto/dispatch/<step>.md` and committed in the judgement commit;
   generators and the commit script are part of the skill.
8. **Polling.** In the first segment the orchestrator set 57 wake-ups, each one re-reading state. In
   the intake it set none and waited for each subagent's hand-back message; no step was lost.
   *Harness:* rely on the hand-back, or dispatch in the foreground where the host has none, and keep
   one long fallback wake-up for a hung subagent.
9. **The consistency pass was improvised.** After S42 every contract was stable but plans contradicted
   amended governance in places (one gate would have written `test ^1.33.0`; topic-codegen's staleness
   check could never fail). The orchestrator added stage 7 on its own judgement. The intake planned it:
   the record's last handoff (H23) swept the nodes that were not re-planned, and it ran as written.
   *Harness:* a standard stage: collect every "stale" note from step reports, route each to its owning
   skill, then one hsdd-reconcile sweep.
10. **Strictly serial.** The kickoff ruled out HSDD's parallel planning worktrees. Root ADRs (S03 to
    S05) and contracts with different producers have disjoint write sets apart from registries the
    orchestrator regenerates. Phase plans cannot parallelize under producer-first planning with a
    reconcile after each. The intake's citation touches (S64 to S76, less S68) are the clearest case:
    twelve steps, each on its own contract or ADR, a median of 4.5 minutes each. The saving is real but
    bounded; measure it on the second run rather than assume it.
11. **The owner's tree was not clean.** When the intake began, the owner's uncommitted edit to
    `REPORT.md` and three untracked files sat in the working tree. S56 gave the gate owner patterns and
    a hash snapshot (`tools/owner-files.json`), and every commit staged explicit paths. *Harness:* an
    `owner_files` list in the run config, hashed at start and checked by the gate, and a `commit.mjs`
    that stages only the step's write set.
12. **The stop policy changed with the owner's words.** The kickoff's stop set ended the run with
    `STOP.md`. The intake request said "do not ask me anything, but record the decisions", and the
    orchestrator read it (DEC-686) as: decide each stop condition as the owner's stand-in, record it
    with `would_have_asked: true` and its `stop_class`, never write `STOP.md`. DEC-688 then decided in
    advance the stop class the intake was sure to meet (a breaking change to a stable contract takes the
    next version), so no subagent had to stop. 11 of the intake's 14 `would_have_asked` decisions are
    that class. *Harness:* `stop_policy` in the run config, and a `predecided` map from stop class to
    answer that `dispatch.mjs` puts into every prompt. Both are owner decisions the report lists first.
13. **A step read what its skill does not read.** S83 (hsdd-phase-plan on nidana.navigation) read parts
    of nidana.runtime's phase plan to copy its format; the skill reads sibling specs, never sibling
    plans. No fact rests on it (DEC-954), and later phase-plan prompts stated the house conventions. A
    deny rule cannot catch this, because a node's phase plan lives in its spec file, which the skill may
    read. *Harness:* step-kind templates state the output conventions, and the report schema keeps a
    field for reads outside the skill's read set, which S83 filled voluntarily.
14. **Rework had no named mechanism.** S65 reported a sentence that bus-api@v2 G9 makes false as
    outside its citation touch. The orchestrator resumed the same subagent with `SendMessage` (DEC-813)
    instead of dispatching a new step; the fix kept the subagent's reading of the file and the whole
    step took 8 minutes. *Harness:* the loop names "resume with the finding" as the first rework, before
    a fresh dispatch.

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
/hsdd-auto                  start or resume, reading hsdd/auto/run.yaml
/hsdd-auto intake <source>  route one change into a planned tree: hsdd-intake, then its record's handoffs
/hsdd-auto status           where the run is, what is queued, what stopped
```

When `hsdd/auto/run.yaml` does not exist, the skill asks its questions once and writes the file. That is
the only interactive moment. For this project, after the intake, the file would read:

```yaml
run: v1-planning
branch: auto/v1-planning          # created from base; never squash, amend or force-push
base: main
mode: intake                      # plan-through-reconcile for the first segment; no phase is implemented in either
models: { orchestrator: claude-opus-5-5, step: claude-opus-5-5 }
owner_facts:
  - "Who builds what: Purbo alone, with coding agents. One team, one repository."
  - "The v0.15.1 Specification is accepted for v1 and replaces v0.15.0 (2026-10-20). The Guide and the Rationale are informative."
  - "Coding method for phase execution: superpowers, not OpenSpec."
  - "You may not install global tooling; project-local dev dependencies are fine."
preferences_from: ~/.claude/CLAUDE.md   # functional-first engineering preferences
sources:
  normative: [ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_1.md]
  informative: [ref/nidana-docs/arch/nidana-bus-ref-arch-guide-v0_15_1.md, ref/nidana-docs/arch/nidana-bus-ref-arch-rationale-v0_15_1.md]
  baseline: [ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_0.md]   # what the tree was planned against; read for the diff
read_only: [ref/]
out_of_bounds: [~/git/nidana-bus-dart, ~/tmp, ~/.claude*/projects/*/memory, ~/git/hsdd/docs/superpowers]
owner_files: []                   # uncommitted owner files no step may touch; hashed at start
toolchain:
  run: fvm dart          # never a bare dart
  flutter: fvm flutter
prose_rules_from: ~/.claude/CLAUDE.md   # banned characters and phrases, read at render time
stop_set: [collision, breaking-amend, shape-unsettled, external, gate-twice]
stop_policy: decide-and-record    # or stop: write STOP.md and end the run
predecided:                       # answers given before any step meets the stop, each a recorded decision
  breaking-amend: "a breaking change to a stable contract takes the next version with a migration note (DEC-688)"
experiments_dir: docs/auto-run/experiments
```

### Files

```text
skills/hsdd-auto/
  SKILL.md                     the loop, the judgement points, stop handling
  templates/preamble.md        this run's step-preamble.md with {slots}
  templates/steps/             root-spec, mid-level-spec, adr, adr-update, contract, contract-touch,
                               citation-touch, spec-touch, phase-plan, phase-plan-append, reconcile,
                               sweep, intake
  schema/                      decision, step-report, run-line, run-config (JSON Schema)
  scripts/state.mjs            reads the tree, the ledger and the queue; `done` is the goal condition
  scripts/next.mjs             the runnable steps and their inputs (TBM AUTO-13); in intake mode, the
                               record's handoffs in order
  scripts/dispatch.mjs         renders a prompt to hsdd/auto/dispatch/<step>.md
  scripts/decide.mjs           appends one stamped decision to a step report as it is taken
  scripts/gate.mjs             this run's gate, configured from run.yaml
  scripts/ledger.mjs           this run's ledger tool, plus model and token fields
  scripts/commit.mjs           the two commits; refuses a staged file outside the step's write set
  scripts/routed.mjs           the routing queue (below)
  scripts/report.mjs           REPORT.md from the ledger and the reports; an intake variant
  scripts/explore.mjs          the explorer data (a Node port of docs/auto-run/explorer/build.py)
  adapters/claude-code/        settings.json deny rules, the Bash PreToolUse hook, the /goal line
```

### The loop

1. `next.mjs` returns the runnable steps, `done`, or `blocked` (a STOP exists). In intake mode the
   first step is hsdd-intake, and from then on the queue is the record's Routing section in order,
   plus steps the record's insert rule adds.
2. For each step, `dispatch.mjs` renders the prompt, and the orchestrator dispatches one fresh subagent.
3. The subagent returns `completed`, `stopped` (a skill stop, the question verbatim) or
   `run-stop-candidate`.
4. `completed`: `gate.mjs`, then `commit.mjs` (artifacts), `ledger.mjs`, `routed.mjs ingest`,
   `commit.mjs` (judgement). A step that changed nothing gets an empty artifact commit (S71).
5. `stopped`: the orchestrator answers as the owner's stand-in, records the decision with
   `would_have_asked: true`, and re-dispatches with the answer.
6. `run-stop-candidate`: the orchestrator judges it against the stop set. If it holds and
   `stop_policy` is `stop`, write `hsdd/judgement/STOP.md` and end. Under `decide-and-record`, decide
   it and record it with `would_have_asked: true`. If it does not hold, record why and continue.
7. A gate failure or a review finding is reworked once by resuming the same subagent with the finding;
   a second failure stops the run, or under `decide-and-record` is decided and recorded.
8. After the last reconcile: the sweep stage, then `report.mjs`, then stop.

Where the model is needed and where it is not:

| Work | Who |
|---|---|
| Which step runs next, its inputs, its write set | `next.mjs` |
| Rendering the prompt, including routed items and predecided answers | `dispatch.mjs` |
| Gate, commits, ledger lines, timestamps, run log | scripts |
| Answering a skill stop as the owner's stand-in | orchestrator model |
| Deciding a stop class in advance (DEC-688) | orchestrator model, recorded as a setup decision |
| Judging a run-stop candidate | orchestrator model (later the judge) |
| Accepting an `insert-step` item into the plan | orchestrator model, recorded as a `plan` decision |
| The skill's own work | step subagent |

### The routing queue

Most of the orchestrator's real work in this run was routing. Each report's `notes_for_orchestrator`
held follow-ups for later steps ("nidana.runtime's plan must fix its own Contracts table"), which the
orchestrator carried in its context and wove into later prompts under "Items routed to this plan by
earlier steps", or turned into inserted steps (S10, S13, S27, S38, S46, S52). That is where context
loss would hurt most, and it is not structured today.

The intake split the same work in two. The record's handoffs (H1 to H23) were structured, committed and
executed as written. The follow-ups the steps raised along the way went into notes files in the
scratchpad, which are gone; eight of them survive only as the "Left for later" list in
`REPORT-v0_15_1.md`, and three became inserted steps (S68, S81, S83, with S84 as S83's reconcile). The
first half worked;
the second half is what the queue replaces.

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
  is what S53 and S94 used. Naming "sweep after amendments" as a reconcile mode makes the consistency
  pass standard.
- **A machine-readable handoff list.** hsdd-intake's record already holds what a computed plan needs:
  class, landings, ordered handoffs with their prompts, and an insert rule. A structured handoff block
  in the record would let `next.mjs` read it instead of parsing prose.
- **A rule for citations when a source version moves.** Thirteen intake steps (S64 to S76) moved
  citations from v0.15.0 to v0.15.1 under a touch rule the orchestrator wrote (DEC-804): live
  citations move, dated history keeps its version, a sentence that became false is restated and
  recorded. HSDD has no such rule. With one, those steps become mechanical and the gate's stale-version
  warnings can become a checked class.

### Getting there from this run's files

1. Copy `gate.mjs`, `ledger.mjs`, `decision.schema.json` and `step-preamble.md` into
   `~/git/hsdd/skills/hsdd-auto/`, and turn the project facts in the preamble into slots. Both
   preamble versions are in git (the first at `6297e3a`, the intake's at HEAD).
2. Recover the step sections from the explorer's data (`data/steps/S*.json`, field `prompt`, and
   `resumes` for S65) and reduce them to the step-kind templates. The scratchpad copies are already
   gone; the data rebuilt on 2026-10-21 holds all 90 prompts.
3. Write `state.mjs` and `next.mjs` against HSDD's registries (`gen-registry.mjs` output, contract
   front matter, pending sections) and against an intake record's handoffs.
4. Add `routed`, `model` and token fields to the report and run-line schemas, and `decide.mjs`.
5. Write the Claude Code adapter and test that the deny rules hold against Read, Grep and `cat`.
6. Dry-run on a small sandbox project, the way TBM uses `sandbox/acme`, in both modes.
7. Re-run nidana-bus-dart from scratch on a new branch with the harness and compare it with
   `auto/v1-planning`, in the same two segments (plan on v0.15.0, then intake v0.15.1). That second run
   measures run-to-run variance, which the judgement layer needs anyway. A third run planned straight
   on v0.15.1 measures what the intake path leaves behind against planning fresh.
