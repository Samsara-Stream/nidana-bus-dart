# The v0.15.1 intake: report for review

The planned tree now follows Specification v0.15.1. All nine contracts are `stable` with `phase_ids: final`, every pending governance section is drained, and `node docs/auto-run/tools/gate.mjs --final` reports 0 errors. Its 44 warnings are references to a superseded version inside dated history (quoted first texts, migration notes, experiment descriptions), not live citations.

It took 40 steps (S55 to S94, plus this report as S95), 39 subagent dispatches, 386 recorded decisions (DEC-685 to DEC-1070) and 10 new experiments, from 2026-10-20T16:00Z to 2026-10-21T00:27Z. Nothing stopped. As you instructed, every condition that would have stopped the run was decided and recorded with `would_have_asked: true`; there are 14 of them (listed below).

Four contracts took a new version because v0.15.1 changed behavior their own Breaking lists name: topology-dsl, bus-api, bus-testing and flutter-binding are at v2. Two nodes gained phases (nidana.runtime 14 to 16, nidana.flutter 7 to 8). No node or contract was added or removed.

## What v0.15.1 changed, and where it landed

| Specification change | Where it landed |
|---|---|
| §3.13 startup barrier rewritten: bootstrap topologies and subscriptions connect only at `start()`, writers before readers, then the queue | bus-api@v2 G34 (three steps inside `start()`), G22, G17; nidana.runtime D3 and phases .2, .4, .12, .15; navigation-api Refinement 8; flutter-binding@v2 G5, G6 |
| §7.2 scope timing: MODULE or PAGE activation before `start()` rejected | bus-api@v2 G42 (`StateError`); flutter-binding@v2 G8, G10, G20; nidana.integration's new scope-timing slice |
| §10.2 write chain: an error ends only its own `write` pipeline; subscriber errors go to the listen zone | topology-dsl@v2 G26 and Write chains; bus-api@v2 G26, G18, G41; ADR-003 item 2 |
| §4.3 runtime name check: the compared fields | bus-api@v2 G7 (tracing kept, marked for upstreaming) |
| §7.3 `NidanaModule` wrapper widget | flutter-binding@v2 G20; new phase nidana.flutter.8 |
| Guide §6.3 name every transformer (re-activation compares functions) | bus-api@v2 G23; navigation-api@v1 G13 (resolver stage objects built once per call); flutter-binding@v2 Refinement 4 |
| Guide §6.1 a Dart bus needs its own topic storage or a wrapped subject | nidana.runtime D3: the bus owns topic storage and fan-out, RxDart only in time stages (experiment `runtime-topic-storage/`) |
| Guide Appendix C.1 catalogs without reflection | nidana.tooling.codegen D1 (its upstream mark ends) |

The intake record, `hsdd/management/2026-10-20-intake-ref-arch-v0-15-1.md`, has the full landing map (L1 to L10) and the routing. Its `## Produced` lists the bumps and ADRs.

## Decisions to look at first

**The two rules everything else rests on.**

- DEC-686: you said "do not ask me anything", so conditions that used to stop the run were decided and recorded rather than written to STOP.md.
- DEC-688: a change that a stable contract's own Breaking list names takes the next version with a migration note, rather than an in-place amendment. The alternative, amending v1 in place since no code exists, was the earlier run's precedent while contracts were draft. If you read `stable` as binding only once a phase ships, the four v2 bumps could collapse back to v1 amendments; the content would not change.

**Every `would_have_asked` decision (14).**

| Id | Step | What was decided |
|---|---|---|
| DEC-688 | S55 | Breaking changes to stable contracts take the next version (above) |
| DEC-749 | S60 | bus-api takes v2: barrier, scope timing, subscriber errors and conversions, re-activation |
| DEC-734 | S60 | Scope timing rejects with `StateError` naming the topology or module, not a new `BusError` variant |
| DEC-737 | S60 | Subscriber callbacks stay in the provider zone; their unhandled errors go to the listen zone (ADR-003 as amended) |
| DEC-739 | S60 | An off-type value at a topology read is a read-stage error that ends its write chains unless a `catchError` recovers it (reverses runtime D5) |
| DEC-751 | S60 | An event a topology publishes while `start()` connects it reaches observers, not readers connected later (Spec silent; marked upstream) |
| DEC-760 | S61 | bus-testing takes v2 |
| DEC-792, DEC-793, DEC-794 | S63 | flutter-binding takes v2 for scope timing, bootstrap first values and re-activation |
| DEC-919, DEC-927 | S80 | The bus is `running` from the moment `start()` begins; amended within draft v2 |
| DEC-1064, DEC-1070 | S94 | Phases of nodes not re-planned (nidana.model, tooling.codegen, tooling.lint) count as confirmed once their ids are unchanged and their lines name the new versions; the four v2 contracts flipped to stable |

**Design choices with the widest reach (not flagged would_have_asked).**

- nidana.runtime D3 (S78): Guide §6.1 offers two ways for a Dart bus to meet the barrier. The bus now owns topic storage and fan-out instead of wrapping RxDart subjects. Both pass every suite; the owned cell is about 15% cheaper per delivery.
- G23 re-activation (S60): two activations re-use one handle only when IR equality holds and the plan's functions and seeds are `==`. This follows Guide §6.3 and supersedes DEC-167. Consequences: navResolver builds its stage objects once per call (S62), and a page topology with an inline closure throws on a second mount (S63).
- Appended phases: nidana.runtime.15 (observed streams), nidana.runtime.16 (write chains, `reduceInto`, the re-activation comparison) and nidana.flutter.8 (`NidanaModule`). Without them, three phases would have grown to 530 to 700 lines (DEC-916, D12 in nidana.flutter).

## The earlier run's upstream proposals, read against v0.15.1

Of the 38 decisions S00 to S54 marked `would_upstream`, the intake record (S57) found:

- **Adopted by v0.15.1 (4):** DEC-032 (asynchronous first delivery on Dart, Spec §2.1, §3.3), DEC-168 (the name check's fields, except tracing), DEC-249 (module scope by stack membership, Spec §7.3), DEC-365 (an explicit catalog list, Guide Appendix C.1).
- **Contradicted (3):** DEC-166 (connect at `activate`; v0.15.1 connects at `start()`), DEC-158 for subscriptions made during bootstrap, DEC-167 (re-activation ignores closure bodies; the Guide now compares functions).
- **Still open (31):** the rest, unchanged by v0.15.1.

These are direct evidence for the judgement layer: the specification's author settled 7 of the run's 38 proposals, and agreed with 4 of them.

**New upstream marks from this intake (9):** DEC-702, DEC-741 (tracing in the name check), DEC-717 (which zone a Dart subscriber's callbacks run in), DEC-732 (the bootstrap subscription order), DEC-751 (events during `start()`), DEC-906, DEC-919, DEC-927 (calls made while `start()` runs), and DEC-1027 (DEC-586's hydration mark, carried over).

One related observation (S92) has no ledger line. A topology's publish caused while `start()` delivers the queue lands after the rest of the queue, so a request queued behind a `LoggedIn` sees the pre-login auth state. The example avoids it. It belongs on the same list as DEC-751.

## Record gaps and process notes

- **Timestamps.** S59's subagent did not stamp each decision as it took it; 12 of its 13 times are upper bounds from file birth times, and the run log says so. Later steps stamped each decision. S57's 17 decisions carry times within twenty seconds of each other, so they were stamped at writing time. Artifact text dates the intake's touches 2026-10-21 (local WIB), while most ledger times are 2026-10-20 UTC.
- **Isolation slip.** S83 read parts of nidana.runtime's phase plan for its format; hsdd-phase-plan reads sibling specs, never sibling plans. No fact rests on it (DEC-954). Later phase-plan prompts named the conventions explicitly.
- **Orchestrator errors caught by steps.**
  - My S57 prompt placed the RxDart bullet in Spec §3.6; it is §3.3.
  - My S78 prompt called the S60 stand-in "bus-owned storage"; it wraps an RxDart subject.
  - Both were corrected in the step and are recorded in its report.
- **Inserted steps.**
  - S68: topology-dsl's `TopicRemoved` lineage.
  - S81: runtime spec text after the re-plan.
  - S83, S84: navigation re-plan under the insert rule.
  - S65 was resumed once to restate one more sentence.
  - Each insertion has its own decision line.
- **Owner files.** `REPORT.md`, `HARNESS.md`, `JUDGEMENT-LAYER.md` and `explorer/` were not touched; the gate checked their hashes at every step. The explorer does not show stage 9 yet.

## Left for later, deliberately

None of these is false under v0.15.1; each predates it or is a sharpening.

- topic-model line ~306 says shell publishes take `Lineage.root` or `Lineage.causedBy`; bus-api only ever makes them root.
- nidana.runtime D2's port bullet omits the `reduceInto` seed and the provider-zone timer that phase .9's port carries.
- bus-api@v2 G9 does not say whether a read that recovered `TopicRemoved` receives from the fresh subject (the stand-in gives none).
- navigation-api's Validation bullet says "The cases call `start()` after `executor` returns"; one G19 case starts first.
- topic-codegen Registration point 2 and codegen D1 item 2 say "what the app's bootstrap passes"; MODULE and PAGE topologies never activate in bootstrap.
- topology-dsl@v2's Delivery parenthetical for nidana.model.11 names only nidana.integration.
- nidana.navigation's OQ-N1 resolution cites Spec §7.6, which its Sources never listed.
- A lint for inline closures in `declare()` (Guide §6.3, bus-api@v2 G23) would be a compatible nidana-checks addition; no Spec or Guide check table lists it.

## Experiments added

`subscriber-error-zone` (S58), `topology-dsl-write-chain` (S59), `bus-api-v2` (S60, S67), `bus-testing-v0151` (S61), `navigation-api-v0151` (S62), `flutter-binding-v0151` (S63), `runtime-topic-storage` (S78), `runtime-replay-schedule-v2` (S79), `bus-api-start-running` (S80), `navigation-executor-during-start` (S83). Each holds its source, a `run.sh` where it replays fixtures, and `output.txt`.

## How to review

- Read this file, then the intake record, then the would_have_asked lines above in `hsdd/judgement/decisions.jsonl`.
- Record reviews as before: one line per decision in `hsdd/judgement/decision-reviews.jsonl`, with `decision`, `at`, `review` (`agree`, `disagree` or `should-have-asked`) and `reason`.
- The step map is in `docs/auto-run/execution-plan.md` under stage 9. Each step has two commits on `auto/v1-planning`, `hsdd: SNN ...` then `judgement: SNN`.
