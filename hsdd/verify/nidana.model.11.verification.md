# Verification: nidana.model.11 - Projection, graphs and claims

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`. None of them starts `flutter`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate. It replays topic-model@v1 and topology-dsl@v2 unrestricted: topology-dsl@v2's recording suite through `topology_builder_test.dart`, its live suite being bus-api@v2's to bind and nidana.runtime's to replay. It replays topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets in full and its `behavior` set through the binding `nidana_dart_contracts_test.dart` under `dart test`, restricted to G2, G5, G6 and G8 to G12:

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G8,G9,G10,G11,G12
```

The checklist, where `9e7a3d6` is the parent of Task 1's commit (the phase base). The first three commands print by name the cases and tests that the gate reports only as counts; the fourth shows what the restriction leaves out; the next four are searches that must find nothing; the last three show the file set and that no dependency moved:

```sh
fvm dart test hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart --name '^G(9|10|12) ' -r expanded
fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G(8|11|12) ' -r expanded
fvm dart test packages/nidana_dart_contracts/test/projection_test.dart packages/nidana_dart_contracts/test/shell_claim_test.dart packages/nidana_dart_contracts/test/topology_graph_test.dart packages/nidana_dart_contracts/test/error_messages_test.dart -j 1 -r expanded
fvm dart run nidana_contract_check topology-ir --set behavior; echo "exit: $?"
grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/graph packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?"
grep -rn "ignore:" packages/nidana_dart_contracts/lib; echo "exit: $?"
grep -rnE "^(import|export) .*graph/" packages/nidana_dart_contracts/lib/src/ir; echo "exit: $?"
grep -rnE "is an '|'handle'|count inputs'" packages/nidana_dart_contracts/lib; echo "exit: $?"
git diff --name-status 9e7a3d6 HEAD -- packages/nidana_dart_contracts
git status --short pubspec.lock
git diff --stat 9e7a3d6 HEAD -- packages/nidana_dart_contracts/pubspec.yaml
```

The fourth command is the unrestricted replay of the `behavior` set. It exits 1 until nidana.model.14, by design (see Observed).

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+234: All tests passed!`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test`, `59 fixtures: 59 passed, 0 failed, 0 pending`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 17 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G5, G6, G8 to G12` and `61 fixtures: 61 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` line appears. The suite count is the package's tests as the implementers left them, 234; the plan's `+223` was lower by the 11 tests they added where a rule would otherwise go unpinned.
- The checklist prints, in order:
  - the seven case names of the G9, G10 and G12 cases of `topology_builder_test.dart`, then `+7: All tests passed!`;
  - the seven case names of the G8, G11 and G12 cases of topology-ir@v1's binding, then `+7: All tests passed!`;
  - 34 test names, 10 from `projection_test.dart`, 5 from `shell_claim_test.dart`, 11 from `topology_graph_test.dart` and 8 from `error_messages_test.dart` (`-j 1` runs one file at a time), then `+34: All tests passed!` (the plan's 7, 4, 8 and 4, and the 11 tests the implementers added);
  - for the unrestricted replay, `exit: 1` and `FAIL behavior` for the binding with `cases (19 passed, 24 failed, 0 skipped under dart test)`, then `10 fixtures: 9 passed, 1 failed, 0 pending`; the 19 are the restriction's 17, `G7 IR values are equal, with equal hash codes, exactly when their fields are` and `G3 the IR copies the lists it is given; later changes to them do not reach it`, and the 24 failed cases call what nidana.model.12 to nidana.model.14 deliver;
  - no line and `exit: 1` for each of the four searches;
  - thirteen lines of `git diff --name-status`: `A` for `lib/src/ir/projection.dart`, `test/projection_test.dart`, `test/shell_claim_test.dart`, `test/topology_graph_test.dart` and `test/error_messages_test.dart`, and `M` for `lib/src/topology/topology.dart`, `plan.dart`, `builder.dart` and `handle.dart`, `lib/src/ir/definition.dart`, `lib/src/graph/graph.dart`, `lib/src/topic/list_equality.dart` and `test/canonical_order_test.dart`;
  - no output from `git status --short pubspec.lock` and none from `git diff --stat` of `pubspec.yaml`.

## Observed

Run on 2026-10-27, on branch `impl/nidana.model.11` at `0b9b30a` (phase base `9e7a3d6`), Dart 3.13.5 through `fvm`. The implementation step started at 2026-10-27T16:33:01Z. The gate ran once in this task, from 2026-10-27T17:02:12Z to 17:02:19Z. The checklist ran from 17:02:38Z.

- The gate that ran is the amended one. As first written, the Gate restricted topology-ir@v1's replay to G2, G3 and G5 to G12. S136 found that G3's case at line 508 of `behavior/topology_ir_conformance.dart` and G7's at line 821 call `analyzeTopologyGraph`, which nidana.model.12 delivers, so that restriction failed those two whatever this phase built. S137 (hsdd-phase-plan) checked every remaining unshipped gate with a reach table (`docs/auto-run/experiments/model-gate-reach/`) and amended the Gates of nidana.model.11 and nidana.model.13 so that G3 and G7 left them. S138 (hsdd-reconcile) amended topology-ir@v1's Delivery paragraph, and S139 regenerated the phase context. G3 and G7 are checked by this phase's package tests for graphs and claims, which the gate runs. They first replay at nidana.model.12.
- The gate exited 0. Its lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:00 +234: All tests passed!`
  - `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test` (topic-model@v1, unrestricted)
  - `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test` and `59 fixtures: 59 passed, 0 failed, 0 pending` (topology-dsl@v2, unrestricted)
  - `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 17 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G5, G6, G8 to G12` and `61 fixtures: 61 passed, 0 failed, 0 pending` (no `FAIL`, `ERROR` or `PENDING` line anywhere in the output)
- The package counts differ from the plan's, for one reason (the implementers added tests where a rule would otherwise go unpinned, which the Global Constraints allow): the suite is 234 tests against 200 at the phase base, not 223; the four new files hold 34 tests, not 23 (10, 5, 11 and 8, not 7, 4, 8 and 4). The additions are three in `projection_test.dart` (stage edges before sink edges, one index per stage however many edges take it, a switchMap's retry), one in `shell_claim_test.dart` (the check order and the invalid values), three in `topology_graph_test.dart` (ids in code unit order, the shared id as the invalid value, equality by value element by element) and four in `error_messages_test.dart` (every position of every call, the full dedup sentence, every combinator's input count, a genuinely repeated sink).
- Routed by the controller (no code change): Task 4's review noted that the reworded second-sink message names the rendered-alike cause even for a genuinely repeated state topic, which only a directly built `TopologyDefinition` or a decoded document reaches; routed to nidana.model.13, the codec's phase. Task 2's review noted that nidana.model's D4 gives `lib/src/topic/` to nidana.model.3 and .8 only, while this phase edited the dartdoc of `list_equality.dart` (a comment, with no phase running beside it); routed to the end-of-node governance sweep.
- Checklist:
  - [x] `buildDefinition()` of the contracts' example topologies gives the edges the From a plan rules describe. The suite's three G8 cases pass by name, `+7` with the G11 and G12 cases of the second command: a plan projects one stage edge per non-read stage, in stage order, then one sink edge per sink (`CheckoutFlow`); every combinator projects to its kind, inputs, function, duration and retry; recording one declaration twice projects equal definitions. The package's `projection_test.dart` passed beside them (`+10`): topology-ir@v1's JSON example `search` projects to its debounce, switchMap and write; the `forms` sample's one read handle feeds a map, a merge and a reduceInto; the findings sample's `quiet` read feeds two stages whose edges a merge takes by index; every arity form of combine and withLatestFrom names the combiner the declaration passed, inputs in input order; a read written as it is projects to a write of a topic input with the read's dedup, and an inline closure is anonymous; and the three tests the implementer added.
  - [x] Two recordings of one declaration, inline closures included, project equal definitions: the suite's `G8 recording one declaration twice projects equal definitions, inline closures included` and topology-dsl@v2's `G9 buildDefinition runs declare once and equals the definition of a fresh plan` pass, and so does the package's `G9 a plan projects again at each read of its definition, equal each time and equal to buildDefinition`. The `definition` getter is `=> projectPlan(this)`, with no cached field; no test tells that apart from a cached field, because equal values hide it (Task 1's review, a minor note).
  - [x] The gate's two behavior replays pass in full. topology-dsl@v2, unrestricted, passes 24 of 24 against 19 before this phase (the five that failed called `buildDefinition()` or `definition`: the G9 case, both G10 cases and both G12 cases). topology-ir@v1, restricted, passes 17 of 17 against 10 before (G2, G5, G6, G9, G10, delivered by nidana.model.10). The unrestricted replay of topology-ir@v1's `behavior` set exited 1 with `cases (19 passed, 24 failed, 0 skipped under dart test)` and `10 fixtures: 9 passed, 1 failed, 0 pending`. The 19 are the 17, `G7 IR values are equal, ...`, which passed since nidana.model.10, and `G3 the IR copies the lists it is given; later changes to them do not reach it`, which this phase reaches ahead of its restriction. Of the 24 failures, two wait for `analyzeTopologyGraph` (nidana.model.12): `G3 every collection the IR, graphs, claims and findings expose is unmodifiable` and `G7 graphs, claims, declarations and findings are equal, ...`; the other 22 call the analyses (G13 to G18, G23), the codec (G4, G19 to G21) or the renderers (G22).
  - [x] G3 and G7 for graphs and claims, outside the gate's restriction, are pinned by the package tests the gate's package run executed, all passing: `G3 a claim keeps an unmodifiable copy of its writes, in canonical order, whatever order they were given in`, `G7 claims are equal, with equal hash codes, exactly when their source, scope and writes are`, `G3 a graph keeps unmodifiable copies of its lists; later changes to its arguments do not reach it`, `G7 a graph built from lazy iterables equals one built from lists, and reads each argument once`, `G7 graphs are equal, with equal hash codes, exactly when their topologies and claims are, whatever order the arguments came in` and `G7 graphs compare definitions and claims by value, element by element, ...`. The dry run's seeded defects D3 to D6 and D8 pass the gate's replay and fail these tests or the G11 claim-order test (`docs/auto-run/experiments/projection-graphs-plan/output.txt`).
  - [x] The rendered-alike corner: two state topics whose value types render alike pass `planOf`, and `definition` and `buildDefinition()` throw `ArgumentError` named `transforms`, unwrapped, whose message now reads `edge i is a second sink edge on this state topic, of type Cart; two state topics of one name whose value types render alike, one class name in two libraries, are one topic in the IR` (`G8 two state topics whose value types render alike pass planOf, ...` and `G6 a second sink edge on a state topic names the topic and its type, ...` pass). The three other routed messages are fixed: a foreign handle is named by its parameter or its index in a list, the dedup rejection names the variant with its article, and an edge given the wrong number of inputs says `input` or `inputs` as its count needs; the old wording is gone from `lib/` (the fourth search found no line).
  - [x] No `UnimplementedError` remains under `lib/src/ir/`, `lib/src/graph/` or `lib/src/topology/` (no line, `exit: 1`), no `ignore:` under `lib/` (no line, `exit: 1`; the two `// ignore: unused_element` lines of `graph.dart` are removed), and `lib/src/ir/` imports and exports nothing from `graph/` (no line, `exit: 1`; `canonical_order_test.dart` now reads `lib/src/ir/` recursively and passes). The export lists are unchanged (`exports_test.dart` passes), `purity_test.dart` passes over the changed libraries (topic-model@v1 G25, G26), and the lockfile and `pubspec.yaml` are unchanged (`git status --short pubspec.lock` and `git diff --stat` printed nothing). `git diff --name-status` printed the thirteen lines the checklist expects.

## Outstanding

None.

## Learnings

- topology-ir@v1's G3 and G7 each hold a case that calls `analyzeTopologyGraph` over the `findings` sample, which nidana.model.12 delivers, so this phase's Gate as first written, restricted to G2, G3 and G5 to G12, failed those two cases whatever the phase built (S136 at the context switch); S137 amended the Gates of nidana.model.11 and nidana.model.13 so that G3 and G7 left them, S138 amended topology-ir@v1's Delivery paragraph, and the gate that ran here is the amended one, with G3 and G7 for graphs and claims pinned by this phase's package tests until nidana.model.12 replays them. Disposition: spec-updated
- topology-ir@v1's G11 orders a graph's claims by source, then scope, then writes element by element with a prefix first, but no case or sample builds two claims that tie on source and scope with different writes (the `claims_only` sample's two `service:auth` claims are equal, and the case compares each claim's source and scope only), so an implementation that orders claims by source and scope alone passes the gate's replay (S140 dry run, seeded defect D4); this phase's package test `G11 claims sort by source rendering, then scope, then writes element by element, a prefix first, with equal claims kept` pins it. Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)
- Two state topics whose value types render alike, one class name in two libraries, pass `planOf` but project to a definition with a second sink edge on one `TopicRef`, so `definition` and `buildDefinition()` throw `ArgumentError` against the closing sentence of From a plan that every definition a plan projects to is well formed; this phase lets the error propagate, with a message that names the type and the cause and carries the topic as the invalid value (`G8 two state topics whose value types render alike pass planOf, ...`). Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)
- The phase scope estimated about 400 lines in about 6 files, tests included; the product diff is 1734 insertions and 43 deletions in 13 files, of which 351 insertions and 42 deletions in 8 files are library code (see Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint)

## Metrics

- Product diff, `git diff --stat 9e7a3d6 HEAD -- packages/`, where `9e7a3d6` is the parent of Task 1's commit: 13 files changed, 1734 insertions, 43 deletions (HEAD `0b9b30a`; the commit of this doc changes nothing under `packages/`), of which the library (`graph.dart`, `definition.dart`, `projection.dart`, `list_equality.dart`, `builder.dart`, `handle.dart`, `plan.dart` and `topology.dart`) is 8 files, 351 insertions and 42 deletions, and the tests (four new files and one line of `canonical_order_test.dart`) 5 files, 1383 insertions and 1 deletion, beside the estimate of about 400 lines in about 6 files, tests included; the task count is 5 of the allowed 7 (this doc is Task 5's one file).
- Fix rounds: none after task review (Tasks 1 to 4 were each approved with no Critical or Important finding); gate failures before green: none (the topology-ir restriction passed 13 of 17 after Task 1 and 14 of 17 after Task 2, by the plan's design, until Task 3 completed it). Package tests: 200 at the phase base, 234 now.

## Sign-off
- Reviewer / date:
- Review tier applied:
- Disposition of each Outstanding item: verified | waived (reason) |
  deferred to {phase-id}
- Disposition of each Learning: spec-updated | contract-bumped (id@v) |
  adr-proposed (ADR-nnn) | dropped (reason)

> The review gate is not passed while an Outstanding item or a Learning
> lacks a disposition. Dispositions execute at the root through the owning
> skill (hsdd-contract, hsdd-adr, a node-spec edit), by the human running
> the gate.
