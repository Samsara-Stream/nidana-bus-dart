# The implementation run, nidana.model: report for review

You asked for the implementation to run unattended, from hsdd-config through superpowers to implemented and
verified code, for the phases of nidana.model, and then to stop; decisions were to be taken and recorded, and
the run was to stop only before something dangerous. It ran from 2026-10-26T16:54Z to 2026-10-27T23:59Z (UTC),
61 steps (S96 to S156) and 256 subagent dispatches, and it never had to stop: `hsdd/judgement/STOP.md` does not
exist. Every phase has its code, a passing gate, its verification doc with Sign-off left for you, and its
branch merged. After the last phase, the run held the end-of-node governance sweep it had promised (DEC-1193),
then merged everything into `auto/v1-impl-1`.

The record: the step log and every routed finding in `docs/auto-run/impl-execution-plan.md`; each step's
report in `docs/auto-run/steps/S{nn}.json` and, for an implement step, its controller rulings in
`S{nn}.orchestrator.json` and its per-task ledger in `S{nn}.sdd-progress.md`; 490 decisions (DEC-1072 to
DEC-1561) in `hsdd/judgement/decisions.jsonl`, each with the commit it landed in.

## Where things stand

- **Branches.** `auto/v1-impl-1` holds the merge of `impl/nidana.model`, which holds one `--no-ff` merge per
  phase (`impl/nidana.model.1` to `.14`) and one for the sweep (`impl/nidana.model.sweep`). Every branch is
  kept. Nothing was pushed, nothing under `ref/` changed, no global tooling was installed by the run (you
  installed fvm 4.3.2 and Flutter 3.47.7 with Dart 3.13.5 on 2026-10-26).
- **Code.** Two workspace packages, 127 files, 33,696 inserted lines with their tests:
  `packages/nidana_contract_check`, the replay tool of ADR-001 (all seven sets), and
  `packages/nidana_dart_contracts`, which produces topic-model@v1, topology-dsl@v2 and topology-ir@v1 in full.
  No stub, `UnimplementedError` or TODO is left in either `lib/`.
- **Gate at the end** (nidana.model.14's Gate line, on `impl/nidana.model` after the sweep): exit 0. Analyzer
  clean, `structure` 102/102, 371 package tests, and the three produced contracts replayed unrestricted, 120/120
  fixtures: topic-model@v1 44 behavior cases, topology-dsl@v2 31, topology-ir@v1 56. The replay tool's own
  suite passes 468 tests.
- **The whole tree** (`fvm dart run nidana_contract_check --all`): 321 fixtures, 238 passed, 0 failed, 83
  PENDING. Every PENDING fixture waits for a package another node produces (bus-api, bus-testing,
  navigation-api, flutter-binding, nidana_dart_codegen, nidana_dart_lint); `--all` exits 1 while any is
  PENDING, as ADR-001 item 9 states.
- **The HSDD gate** (`gate.mjs --final`): the 4 errors it has reported since the planning run (its hash snapshot
  of HARNESS.md, JUDGEMENT-LAYER.md and `explorer/` predates your edits to them; DEC-1119) and 44 warnings of
  history references to superseded contract versions, the same 4 and 44 as on the planning tip.

## The fourteen phases

Each phase ran three steps: hsdd-config (sonnet), writing-plans (opus, with a dry run of the plan's code
against a scratch copy of the package), and subagent-driven-development (implementers on opus in full-review
phases and sonnet otherwise, task reviews on sonnet, the final whole-branch review on opus, one final fix
wave). "Fix rounds" counts rounds after a task review; the lines are inserted lines under `packages/` at the
merge, tests included.

| Phase | What | Steps | Tasks, fix rounds | Tests at merge | Lines vs estimate | Merged as |
|-------|------|-------|-------------------|----------------|-------------------|-----------|
| .1 | Workspace root and replay tool core | S98 to S101 | 8, 3 | 93 (tool) | 4577 vs ~450 | `cab9039` |
| .2 | Replay tool: surface, reject and schema sets | S102 to S104 | 7, 2 | 195 (tool) | 3924 vs ~420 | `014959f` |
| .3 | topic-model@v1 declarations | S105 to S107 | 4, 0 | replay 30/30 | 916 vs ~430 | `a8d43df` |
| .4 | topology-dsl@v2 declarations (with the IR) | S108 to S113 | 5, 2 | 32 | 1164 vs ~700 | `3c147db` |
| .5 | topology-ir@v1 declarations | S114 to S116 | 3, 1 | 38 | 416 vs ~260 | `739c828` |
| .6 | Replay tool: behavior set | S117 to S119 | 6, 2 | 292 (tool) | 3988 vs ~300 | `90116bd` |
| .7 | Replay tool: file and cli sets | S120 to S122 | 8, 1 | 468 (tool) | 6902 vs ~450 | `eb033bb` |
| .8 | Topic model values and lineage | S123 to S125 | 6, 0 | 95 | 1464 vs ~420 | `5d2cf18` |
| .9 | Recording builder | S126 to S132 | 5, 0 | 147 | 2131 vs ~400 | `e9f2289` |
| .10 | IR values and function references | S133 to S135 | 6, 0 | 200 | 2046 vs ~400 | `9fc5a72` |
| .11 | Projection, graphs and claims | S136 to S141 | 5, 0 | 235 | 1772 vs ~400 | `c021914` |
| .12 | Analyses | S142 to S144 | 5, 1 | 270 | 1814 vs ~380 | `333e08a` |
| .13 | JSON form | S145 to S147 | 4, 1 | 353 | 2977 vs ~420 | `102ff8c` |
| .14 | Mermaid and Graphviz renderers | S148 to S150 | 3, 1 | 371 | 903 vs ~260 | `526fdd0` |

Governance steps the run inserted as your stand-in, each through its owning skill with its own gate:

- **S100** hsdd-contract: bus-api@v2's G13 not-executable line names its node (a contract gap S99 found).
- **S109, S110** hsdd-phase-plan and hsdd-reconcile: nidana.model.4 could not analyze as planned (its
  `TopologyDefinition` names `TransformEdge`, which landed at .5), so the unshipped .4 and .5 were re-planned:
  .4 lands the whole main library, .5 `topology_ir.dart` (DEC-1198, would have asked).
- **S128 to S131** and **S137 to S139**: three phase gates restricted their replay to guarantee ids that
  admitted cases needing a later phase's code (.9's G10; .11's and .13's G3 and G7), so they could pass only
  after that phase merged. Each was amended (hsdd-phase-plan, then hsdd-reconcile, then the context re-run and
  the plan revised); S137 checked every remaining unshipped gate's reach at once
  (`docs/auto-run/experiments/model-gate-reach/`). From S133 on, every config step checked its restriction's
  reach before planning.
- **S151 to S156**, the sweep: compatible touches within the current versions, stating what the shipped code
  does. topic-model@v1 (S151, 3 new cases), topology-dsl@v2 and nidana-checks@v1 (S152, 7 new cases),
  topology-ir@v1 (S153 text; S154, 13 new cases and two samples extended with goldens derived independently),
  ADR-001 amended in place (S155), and four specs (S156: "one contract per phase" restated, D6's token list a
  floor, dated notes beside the shipped .7 and .10 cards). Every new case passes against the shipped package and
  fails at least one defect seeded in a scratch copy. No reconcile was needed.

## What you should do

1. **Sign off the 14 verification docs**, `hsdd/verify/nidana.model.{1..14}.verification.md`. Sign-off is
   empty in each, and every Learning carries a proposed disposition. What to know before signing is listed
   under "Before you sign" below.
2. **Before the nidana.flutter lane:** `fvm flutter precache` (or any first `fvm flutter test`). The pinned SDK
   has no engine artifacts on this machine, so no real `flutter test` ran: nidana.model.6's Flutter runner is
   tested against a stand-in SDK only, and the real run is deferred to nidana.flutter.2 (DEC-1257, DEC-1279).
3. **Check out `ref/nidana-docs`** when you can. The reference architecture is an uninitialized private
   submodule here, behind a personal SSH alias; the run did not fetch it (a credential) and built from the
   governance (DEC-1237). Spec §2.4's worked examples are checked only as topic-model@v1's G19 cases encode
   them (nidana.model.8's Outstanding item).
4. **Run the render check over the extended goldens:** `npm ci` in
   `docs/auto-run/experiments/topology-ir-fixtures/render-check/`, then its `check.mjs` over
   `hsdd/contract/fixture/topology-ir/render/`. S154's four extended goldens match the shipped renderers and an
   independent script, but no Mermaid parser or Graphviz layout read them (npm needs the network).
5. **Revisit the sizing at a checkpoint.** Every phase landed 1.6 to 15 times its line estimate; the replay
   tool's phases ran 9 to 15 times. The plan's PE sizing under-counts tests and dartdoc by a wide factor
   (`hsdd-checkpoint` is the tool for it).

## Decisions to look at first

No decision was taken at low confidence; 370 high and 120 medium. By blast radius: 393 node-local, 76
contract, 20 tree, 1 upstream (DEC-1505, the Spec §2.4 comparison left for you). The 24 marked `would_have_asked` (a careful engineer would have asked you
first), grouped:

- **How the run works:** DEC-1078 (subagent-driven-development for every phase), DEC-1086 (Sign-off left
  empty, the run continues once the gate passes and the final review closes), DEC-1119 (the gate's four known
  owner-file errors are tolerated).
- **The environment:** DEC-1237 (build from the governance, not the unfetched Specification), DEC-1257 and
  DEC-1279 (the Flutter runner against a stand-in SDK), DEC-1285 (a `{package}:{executable}` command runs as a
  script under the running `dart`, since `dart run` exits 255 from a `files/` directory on a stale workspace),
  DEC-1305 (that finding's governance route, taken in the sweep).
- **Governance re-plans:** DEC-1198 (re-plan .4 and .5), DEC-1335 and DEC-1351 (.9's gate), DEC-1405 (.11's and
  .13's gates), DEC-1196, DEC-1197, DEC-1174 and DEC-1216 (phase contexts that omit node decisions: followed the
  template and reported the gap), DEC-1106 (the not-executable line's node clause).
- **Rule choices the sweep wrote down as the code does them:** DEC-1463 and DEC-1519 (topology-ir@v1's owner
  order of scope violations; two state topics whose value types render alike), DEC-1499 (redaction applies to
  an already-redacted payload), DEC-1502 (envelope equality takes no identity shortcut, so a NaN payload is
  unequal to itself), DEC-1504 (no renderings for `Topic`, `TopicRef`, `Lineage`), DEC-1536 (an unbound
  conformance library still counts), DEC-1542 (each replay set keeps its shipped order of restriction and
  PENDING).

## Choices left to you

The sweep's rule was to change governance text only, never shipped code. Each item below needs a code or test
change and, for some, a guarantee amendment; each is cheap now, before any consumer node ships.

- **topic-model@v1** (S151): redaction that keeps the payload's type name instead of wrapping a
  `RedactedPayload` again (G15); an identity short-circuit in the envelope's `==` (G13; Dart records compare
  fields by identity first); `toString` renderings for `Topic`, `TopicRef` and `Lineage`, whose test failures
  print `Instance of 'TopicRef'`. The new cases pin the first two as written, so a reversal edits them too.
- **topology-ir@v1** (S153, S154):
  - three `invalid/` documents (an empty `typeName`, a dedup on a replay read, a claim repeating a topic) are
    ready in `docs/auto-run/experiments/sweep-topology-ir-text/would-be-invalid/`, but `json_reject_test.dart`
    pins the exact list of 38 files, so they go in together with that test's entries;
  - Graphviz leaves an empty cluster out of its layout, so a topology with no edges is not drawn; a rendering
    rule is on the Breaking list;
  - optionally, `planOf` rejecting two state topics whose value types render alike, and constructor asserts in
    `TopicInput` and `TopicRef`;
  - a G8 case for the rendered-alike pair needs a second library under `behavior/`.
- **The replay tool and ADR-001** (S155): ADR-001 now names the rules no set checks. Making `structure` check
  them is a tool change: a binding's single conformance library, unbound conformance libraries, duplicate
  Case-table rows (a second row's ids count toward coverage today), conditional-import URIs, the exact
  `plugins:` line, `dart run` in a case with `files/`, and `files/` left unchanged by a run. Also open: one
  restriction-and-PENDING order for every set (DEC-1306), the file set's parity with the cli set for a link at
  `{output}` (DEC-1311), and a runner timeout (none today; a case that never yields hangs a gate).
- **nidana.model** (S156): add `Random.secure(`, `DateTime.timestamp(`, `Timer.run(`, `runZoned`,
  `Stream.periodic(` and `Future(` to `purity_test.dart`'s list (it passes today; D6 is now a floor). Annotate
  `hsdd/verify/nidana.model.10.verification.md` line 70, which still places G3 and G7 at .11.
- **Small text left outside the sweep's write sets:** `hsdd/spec/nidana.tooling.lint.md` line 190 keeps the
  graph label "main library complete"; topic-model@v1's compile-only surface fixture still logs
  `envelope.redacted().toString()`, which its Redaction section now advises against.

## Before you sign

- **All phases:** each verification doc's counts are as of its phase. The sweep later added cases: topic-model
  41 to 44, topology-dsl 24 to 31, topology-ir 43 to 56.
- **nidana.model.1:** ADR-002's Consequences say analyzer 14.5.0 is transitive; the lockfile resolved 14.6.0.
  Whether a gate should enforce `dart format` is yours; the run formatted by ruling.
- **nidana.model.6:** its decision 4 line understates one routed defect; a binding run with only skipped cases
  reads PASS, with the skip count (plan-mandated); the Flutter runner is checked against a stand-in SDK only.
- **nidana.model.7:** none of the 39 committed recorded invocations nor topic-codegen's file replay has run
  against a real producer (PENDING until nidana.tooling's packages exist); a recorded invocation runs in place
  in its `files/` directory under `hsdd/`.
- **nidana.model.8:** two phrases ("reproduce as written", "every branch of Spec §2.4's table") still read as
  Spec comparisons beside their qualifier.
- **Commit trailers:** implementer commits up to S107 Task 1 carry `Co-Authored-By: Claude Opus 5.5` whatever
  model wrote them; from S107 Task 2 on, each subagent commit names its own model (S107.orchestrator.json).

## Feedback for HSDD and superpowers

None of the 15 decisions marked `would_upstream` proposes a change to the reference architecture: 13 concern
hsdd-config's skill text, and 2 (DEC-1268, DEC-1271) ADR-001 readings that the sweep settled in S155.

- hsdd-config's self-contained gate (Rule 2) read literally flags ids that occur only inside verbatim excerpts;
  every config step scoped it to the ids the file selects (DEC-1097 and its repeats).
- hsdd-config's template has no section for a node's own decisions (`D{n}`), so a phase context omits the node
  decisions that fix what a phase lands; every plan prompt pointed at them (DEC-1174 and others).
- hsdd-phase-plan wrote three gates whose `--guarantee` restriction admitted a later phase's cases. A reach
  check at phase-plan time (which cases each restriction admits, and whether the phase's dependency closure
  makes them pass) would have caught all three; `docs/auto-run/experiments/model-gate-reach/` is a prototype.
- In superpowers' controller role, the run's own dispatches twice stated a fact wrongly in a verification doc
  (nidana.model.13's seeded-defect account, nidana.model.14's review evidence); both were caught by the task
  review of the doc. A doc-writing task is worth a review as strict as a code task's.

## Routed to later nodes

These stay in `docs/auto-run/impl-execution-plan.md`, "Routed to later phases", for those nodes' plans:

- **Consumers of topic-model@v1:** once `==` is overridden (it is), a non-empty const set or const map keyed by
  topics, refs, sources, envelopes or lineages does not compile; consumer plans must not rely on one.
- **nidana.runtime:** run G23's idempotency check before building the G24 graph with the candidate, and compute
  `plan.definition` before claiming or wiring anything (S141's final review).
- **nidana.tooling.codegen:** how nidana-checks picks the site for a scope violation whose owner's source two
  equal claims share (S144); its .6, .9 and .11 and nidana.tooling.lint.4 are the first gates to run the 39
  recorded invocations and topic-codegen's file replay for real.

## Experiments added

Each is a directory under `docs/auto-run/experiments/` with its `run.sh` (or program) and captured output:
`analyses-plan`, `behavior-set-plan`, `file-cli-sets-plan`, `ir-values-plan`, `json-form-plan`,
`model-gate-reach`, `model-main-library-closure`, `projection-graphs-plan`, `recording-builder-plan`,
`renderers-plan`, `replay-sets-plan`, `structure-set-plan`, `topic-model-declarations-plan`,
`topic-model-values-plan`, `topology-dsl-declarations-plan`, `topology-ir-declarations-plan` (each phase plan's
dry run, most with seeded defects), and `sweep-topic-model`, `sweep-topology-dsl`, `sweep-topology-ir-text`,
`sweep-topology-ir-cases`, `sweep-adr-001`, `sweep-specs` (the sweep's evidence).

## How to review

Read this report, then the decisions above in `hsdd/judgement/decisions.jsonl`. Record a review as one line per
decision in `hsdd/judgement/decision-reviews.jsonl`:
`{"decision": "DEC-1198", "at": "<UTC time>", "review": "agree" | "disagree" | "should-have-asked", "reason": "..."}`.
A phase's work is on its kept branch (`impl/nidana.model.{n}`), and its plan is
`docs/superpowers/plans/nidana.model.{n}.md`.
