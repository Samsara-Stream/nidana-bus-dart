# Building the judgement layer from this run

The judgement layer needs three kinds of evidence, and this run supplies the first part of each:

- **Your opinion.** Reviews of the run's decisions and verdicts on its artifacts.
- **A comparison.** The manual run of the same planning, plus a second automatic run to measure noise.
- **What actually happened.** Outcomes recorded when phases are implemented.

From that evidence you write a rubric, build a judge that applies it in a separate session, score it in
shadow mode against your reviews, and only then let it gate steps in the harness
(`docs/auto-run/HARNESS.md`). The target design is TBM R6, so each step below names the R6 requirement
it serves: the judge is a skill in its own subagent (AUTO-5, AUTO-14), rubrics use the
`pdlc-eval-framework` format, verdicts are pinned to git blobs (AUTO-9, AUTO-15), and thresholds are
calibrated per step type, model version and rubric version, after shadow mode (AUTO-4).

One difference from TBM shapes everything below. TBM records **artifact verdicts** only: was this file
acceptable. An unattended HSDD run also produces a **decision ledger**, the questions a human would
have answered. You need both: artifact verdicts calibrate the judge's proceed or stop, and decision
reviews calibrate the stop policy, meaning which questions the run should have asked you instead of
answering.

## What this run gives you, and its gaps

| Record | Where | Gap for judgement |
|---|---|---|
| 684 decisions with options, reason, evidence, blast radius, confidence, `would_have_asked`, commit | `hsdd/judgement/decisions.jsonl` | No model id per line (all were `claude-opus-5-5`, from the transcripts). Confidence is self-reported. Six orchestrator decisions in S09 to S16 carry wrong timestamps (`docs/auto-run/timestamp-corrections.md`) |
| One line per step | `hsdd/judgement/run.jsonl` | No model, no token counts; S10 to S16 times are wrong |
| Step reports with each skill's quality gates, quoted verbatim in `self_check` | `docs/auto-run/steps/*.json` | Self-assessment only |
| Artifacts at every step's commit | git, 112 commits on `auto/v1-planning` | No artifact verdicts yet |
| Transcripts: every action of the orchestrator and of each of the 52 subagents | `~/.claude-personal/projects/<project>/9cca2a8a-.../` | Outside the repository, and deleted if that directory is cleaned |
| The explorer | `docs/auto-run/explorer/`, published as a private artifact | Derived; rebuildable while the transcripts exist |

A decision's artifact as it stood at the decision is `git show <commit>:<artifact>`, and its blob is
`git rev-parse <commit>:<artifact>`. Every decision can therefore be pinned to a blob without new
fields.

## Step 1. Freeze the evidence

1. Tag the run: `git tag auto-run-1 6297e3a` (the S54 judgement commit). Every later reference uses the
   tag.
2. Archive the transcripts outside the repository, or commit the explorer's `data/` folder, which holds
   what the judgement layer needs from them (prompts, action sequences, token counts). The transcripts
   are the only record of what each subagent read and ran before deciding.
3. Record the model once for this run in a side file (`hsdd/judgement/run-meta.json`:
   `{"run": "auto-run-1", "models": {"orchestrator": "claude-opus-5-5", "step": "claude-opus-5-5"}}`)
   instead of rewriting the append-only ledger.

## Step 2. Review the decisions

You will not review 684 decisions, and you do not need to. Review a fixed set and a stratified sample, so
agreement rates mean something per stratum.

- **Fixed set (about 110):** the 35 orchestrator decisions, the 44 `tree` decisions, the one `upstream`
  decision, the 31 `would_have_asked`, the 2 low-confidence ones, and the six run-stop candidates
  (DEC-186, 193, 362, 373, 430, 471). They overlap, so the count is under the sum.
- **Sample (about 60):** random among the rest, stratified by step type (contract 261, phase-plan 114,
  ADR 97, reconcile 88, root spec 58, mid-level spec 51) and confidence (high 428, medium 254).

Record each in `hsdd/judgement/decision-reviews.jsonl`. The report's format has four fields; add three so
the reviews can train something:

```json
{"decision": "DEC-430", "at": "2026-10-20T09:00:00Z", "review": "agree",
 "reason": "ADR-002 item 3 settles it.", "reviewer": "purbo",
 "preferred": null, "impact": null}
```

- `preferred`: on `disagree`, the option label you would have chosen, or `other: <one line>`.
- `impact`: on `disagree`, whether the difference changes the tree, a contract or one node (the same
  scale as `blast_radius`), so a wrong `node-local` call is not weighted like a wrong `tree` call.
- `should-have-asked` stays as defined: the decision may be right, but the run should have stopped.

Tooling: a small `review.mjs` that refuses unknown ids and stamps the time, or a review page (a private
artifact with a shared store) that shows each decision with its options and evidence and appends your
line. The explorer already renders the decisions; adding a review control to its drawer is a small step.

## Step 3. Give verdicts on the artifacts

This is TBM's AUTO-15 record, and R6 calibrates on it. Port `~/git/tbm/skills/tbm-brief/scripts/verdict.mjs`
and its schema to HSDD: the step enum becomes `root-spec`, `mid-level-spec`, `adr`, `contract`,
`phase-plan`, `reconcile`, and it writes `hsdd/judgement/verdicts.jsonl`. Each line pins the file's blob,
names the model that wrote it, and says `accepted` or `changes-requested` with your reason.

Give verdicts on the final artifacts first: nine node specs, three ADRs, nine contracts, the conventions.
Then, for the step types you distrust most, on the version a step produced, by blob at that step's
commit. A `changes-requested` verdict on an artifact at HEAD whose problem started in an earlier step
should name that step in the reason; that is how a rubric learns which step type failed.

## Step 4. Check the run's self-assessment against your reviews

Before building a judge, find out how far the run's own flags already go. If they track your reviews,
cheap stops are available today.

- **Confidence calibration:** agreement rate for `high` versus `medium`. If they are equal, confidence
  carries no signal and the judge must not use it.
- **The stop flag:** precision and recall of `would_have_asked` against your `should-have-asked`.
  High recall means the generator's own flag can drive stops. Low recall means it cannot police itself,
  which is the case for a separate judge (AUTO-5).
- **Blast radius:** how often your `impact` matches the recorded `blast_radius`.
- **Evidence:** agreement for decisions citing an experiment (304 of them) versus decisions citing only
  documents.

A `calibrate.mjs` that joins the ledger with the reviews and prints these four tables is enough. Keep its
output under `hsdd/judgement/` so later runs compare against it.

## Step 5. Compare with the manual run

This is the step where blindness ends. Do it in a separate session, never in a session that will later
run the harness, and never put manual artifacts into the harness's prompts or templates. Until then,
keep both clones as they are.

1. **Pick the comparison points.** Either bring the manual run through reconcile, or compare only at the
   step types both runs finished (root spec, ADRs, contracts, phase plans).
2. **Extract the manual run's decisions** into the same schema, marked `"source": "manual",
   "reconstructed": true`. The manual run has no ledger: its decisions sit in `D{n}` lines, ADRs, OQ
   resolutions and contract text. A subagent can draft the extraction; you confirm it, because you know
   which choices were yours and which were Claude's recommendation accepted as given.
3. **Compare the trees mechanically:** nodes and kinds, the contract set, the ADR set, phase counts and
   dependencies. A script can do this from both repositories' registries.
4. **Align the decisions.** Match by question, with a model proposing pairs and you confirming. Each pair
   is `same`, `different`, `auto-only` or `manual-only`.
5. **Run the traceability check** (the C7 pass): extract the Specification's normative
   rules, then list for each tree which phase covers each rule. It is the comparison least dependent on
   taste: an unassigned rule is a defect in either tree.
6. **Settle each difference:** one is better, or both are acceptable. Each settled difference becomes a
   review line on the automatic decision (step 2) and a labelled example for the rubric (step 7).

Treat the manual run as one sample of "Claude with a human in the loop", not as ground truth. The
differences that matter most are the ones where you overrode a recommendation, because those are the
decisions an unattended run would have taken the other way.

## Step 6. Measure run-to-run variance

Run the harness again from scratch on the same inputs and model, on a new branch, and compare
automatic with automatic the way step 5 compares automatic with manual. A decision that flips between two
runs on identical inputs is unstable. It is either a stop candidate or under-evidenced, and its
difference from the manual run says nothing about quality. Without this run you cannot separate "the
automatic run decides differently from you" from "the automatic run decides differently from itself".

## Step 7. Write the rubrics

Write rubrics in the `pdlc-eval-framework` format (`stage-configs/rubrics/<stage>/{rubric,gates,criteria}.yaml`,
`common/aggregation.yaml`): deterministic gates, weighted criteria with 0 to 3 anchors, odd repeats with
the median, instability rules, one version per bundle.

- **One artifact rubric per step type:** root spec, mid-level spec, ADR, contract, phase plan, reconcile.
  The phase-plan rubric also fills the framework's empty `task_generation` rubric, as AUTO-14 requires.
- **One decision rubric** for individual ledger lines: evidence sufficiency, option completeness,
  accuracy of the stated consequences, correctness of `blast_radius` and `stop_class`.
- **Gates** are the deterministic checks that already exist: `gate.mjs`, `gen-registry.mjs`, the ledger
  schema. A gate failure is never judged away (AUTO-2).
- **Criteria come from three places:** each HSDD skill's quality gates (the 52 reports quote them in
  `self_check`), the reasons in your `disagree` and `changes-requested` lines clustered into themes, and
  the settled differences from steps 5 and 6.

## Step 8. Build the judge

An `hsdd-judge` skill that runs in its own subagent (AUTO-5, AUTO-14). Its input is the rubric, the
artifact at a blob, and the inputs that artifact answers to: the Sources sections, consumed contracts,
governing ADRs. Its output, per criterion, is a score with quoted evidence; overall it decides proceed,
stop for a human, or block. It writes one line per judgement to `hsdd/judgement/judgements.jsonl` with
the fields AUTO-7 lists: step, artifact, blob, rubric version, judge model, per-criterion scores with
evidence, threshold, decision, and any human override.

Use a different model from the generator, or at least repeated judgements, so the judge does not share
the generator's blind spots.

## Step 9. Shadow mode on what you already have

Score every verdict from step 3 and every reviewed decision from step 2 at its blob, gating nothing.
Measure agreement per (step type, model, rubric version), revise the rubric, bump its version, score
again. R6's protocol applies as written: no threshold is set until several runs exist; a new model or
rubric version starts back in shadow mode.

Expect thin data. One run gives about 22 final artifacts and 52 step outputs. Steps 6 and 10, and the
harness on other projects, are what make thresholds meaningful.

## Step 10. Put the judge in the harness

In `hsdd-auto`'s loop the judge runs after `gate.mjs` and before the artifact commit. Its decision
replaces part of the orchestrator's model judgement:

- **proceed:** commit and continue;
- **stop:** write the stop for you, batched with any other stops into one review round (as AUTO-13 does
  for parallel stops);
- **block:** rework once with the judge's findings, then stop.

Two rules never move:

- **Stops the judge can never pass** (HSDD's version of AUTO-6): who builds what, a breaking contract
  amendment, a reconcile collision, a change to read-only sources, global tooling or credentials, and
  promotion of an as-built node.
- **Audit sampling** (AUTO-8): a fixed fraction of passed steps still comes to you, so the false-pass
  rate stays measured.

## Step 11. Record what happens when phases run

Reviews are opinions; implementation is the fact. When you execute phases with superpowers, record
for each planning decision a phase touched whether it held, was revised, or caused rework, in
`hsdd/judgement/decision-outcomes.jsonl`. A hypothetical line:

```json
{"decision": "DEC-175", "phase": "nidana.runtime.11", "outcome": "revised", "at": "2026-11-02T10:00:00Z",
 "evidence": "<commit sha>", "note": "late APPLICATION activation now throws in dev mode too"}
```

Outcomes arrive late, but they are the only labels nobody's taste produced. Feed them into rubric
revisions the same way as review reasons.

## Files and tools, by step

| Step | Produces | Tool |
|---|---|---|
| 1 | tag `auto-run-1`, `hsdd/judgement/run-meta.json`, archived transcripts | git |
| 2 | `hsdd/judgement/decision-reviews.jsonl` | `review.mjs` or a review page |
| 3 | `hsdd/judgement/verdicts.jsonl` | HSDD port of `verdict.mjs` |
| 4 | calibration tables | `calibrate.mjs` |
| 5 | manual decisions in the ledger schema, alignment pairs, traceability matrix | extraction subagent, `compare.mjs` |
| 6 | second automatic run and its comparison | `hsdd-auto`, `compare.mjs` |
| 7 | rubrics in `pdlc-eval-framework` format | by hand, from steps 2 to 6 |
| 8 | `hsdd-judge` skill, `hsdd/judgement/judgements.jsonl` | skill |
| 9 | shadow agreement per step type | `calibrate.mjs` |
| 10 | judged stops in `hsdd-auto` | harness |
| 11 | `hsdd/judgement/decision-outcomes.jsonl` | `outcome.mjs` at phase checkpoints |

Steps 2 and 3 need you. Steps 1, 4 and the tooling for 2 and 3 can be built now. Step 5 needs you to
lift blindness, in a separate session.
