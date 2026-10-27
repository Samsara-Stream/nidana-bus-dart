# Verification: nidana.model.9 - Recording builder

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`. None of them starts `flutter`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate. It replays topology-dsl@v2's `structure`, `surface` and `reject` sets in full, and its `behavior` set through the binding `topology_builder_test.dart` under `dart test`, restricted to the guarantees this phase delivers (G11, G13 to G17, G30), beside topic-model@v1 unrestricted and topology-ir@v1's four type-level sets:

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl --guarantee G11,G13,G14,G15,G16,G17,G30 && fvm dart run nidana_contract_check topology-ir --set structure,surface,reject,schema
```

The checklist, where `92d39d6` is the parent of Task 1's commit (the phase base). The first three commands run tests that no gate restriction can select (G9's two recording cases, G10's `planOf` half) or that name the misuses by test (G14, G15); the last command shows what the restriction leaves out:

```sh
fvm dart test hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart --name '^G9 (planOf runs|the builder form)' -r expanded
fvm dart test packages/nidana_dart_contracts/test/combining_stages_test.dart --name '^G10' -r expanded
fvm dart test packages/nidana_dart_contracts/test/recording_test.dart packages/nidana_dart_contracts/test/handle_stages_test.dart packages/nidana_dart_contracts/test/combining_stages_test.dart --name '^G1[45] ' -j 1 -r expanded
grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?"
grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?"
git diff --name-status 92d39d6 HEAD -- packages/nidana_dart_contracts
git status --short pubspec.lock
git diff --stat 92d39d6 HEAD -- packages/nidana_dart_contracts/pubspec.yaml
fvm dart run nidana_contract_check topology-dsl --guarantee G14,G15
fvm dart run nidana_contract_check topology-dsl --set behavior
```

The last command is the unrestricted replay of the `behavior` set. It exits 1 until nidana.model.11, by design (see Observed).

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+147: All tests passed!`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `31 fixtures: 31 passed, 0 failed, 0 pending`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 17 passed, 0 failed, 0 skipped under dart test, restricted to topology-dsl G11, G13 to G17, G30`, `28 fixtures: 28 passed, 0 failed, 0 pending` and `60 fixtures: 60 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` line appears. The suite count is the package's tests as the implementers left them, 147; the plan's `+122` was lower by the tests they added where a rule would otherwise go unpinned.
- The checklist prints, in order:
  - the two names `G9 planOf runs declare once against a fresh builder and carries the id and scope` and `G9 the builder form runs its body on each planOf call and never at construction`, then `+2: All tests passed!`;
  - the names `G10 recording every combinator calls none of its functions, nor a computed initial value, and creates no timer or microtask` and `G10 the counter counts a periodic timer and nothing else` (the counter's positive control), then `+2: All tests passed!`;
  - 28 test names, 11 from `recording_test.dart`, 9 from `handle_stages_test.dart` and 8 from `combining_stages_test.dart`, in that order (`-j 1` runs one file at a time), each beginning `G14 ` or `G15 `, then `+28: All tests passed!`;
  - one line, `packages/nidana_dart_contracts/lib/src/topology/plan.dart:39:  TopologyDefinition get definition => throw UnimplementedError();`, and `exit: 0`;
  - no line and `exit: 1` for the `ignore:` search;
  - ten lines of `git diff --name-status`: `M` for the six part files of `lib/src/topology/` and `A` for the four new test files;
  - no output from `git status --short pubspec.lock` and none from `git diff --stat` of `pubspec.yaml`;
  - for the replay of G14 and G15 alone, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 7 passed, 0 failed, 0 skipped under dart test, restricted to topology-dsl G14, G15` and `28 fixtures: 28 passed, 0 failed, 0 pending`;
  - for the unrestricted replay, `FAIL behavior` for `topology_builder_test.dart` with `cases (19 passed, 5 failed, 0 skipped under dart test)` and the five failed cases `G9 buildDefinition runs declare once and equals the definition of a fresh plan`, `G10 recording calls none of the functions a declaration passes`, `G10 recording creates no timer and schedules no microtask` and the two G12 cases, then `17 fixtures: 16 passed, 1 failed, 0 pending`.

## Observed

Run on 2026-10-27. The gate started at 2026-10-27T13:42:48Z and ended at 13:42:54Z, on branch `impl/nidana.model.9` at `71d1871` (phase base `92d39d6`), Dart 3.13.5 through `fvm`. The first gate run was the green one. The checklist's first eight commands ran from 13:43:05Z to 13:43:08Z; the two replays at its end ran after them.

- The gate exited 0. Its lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:00 +147: All tests passed!`
  - `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test` and `31 fixtures: 31 passed, 0 failed, 0 pending`
  - `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 17 passed, 0 failed, 0 skipped under dart test, restricted to topology-dsl G11, G13 to G17, G30` and `28 fixtures: 28 passed, 0 failed, 0 pending`
  - `60 fixtures: 60 passed, 0 failed, 0 pending` (topology-ir@v1; no `FAIL`, `ERROR` or `PENDING` line anywhere in the output)
- Two counts differ from the plan's, both for the same reason (the implementers added tests where a rule would otherwise go unpinned, which the Global Constraints allow): the suite is 147 tests, not 122; and the third checklist command ran 28 tests (11, 9 and 8 by file), not the plan's 13 (5, 4 and 4). The second checklist command ran two tests, not one: `^G10` also selects the counter's positive control.
- Deviation, by controller ruling: the Global Constraints say this phase creates four test files and edits none. Commit `517a2bc` edits `test/combining_stages_test.dart`, Task 3's file, from Task 4 (21 inserted lines). It adds a successful `withLatestFrom` apply and the too-few wrong-length case for `combineAll` and `withLatestFrom`, which kill two mutants that survived Task 3's tests. Against the phase base the diff still shows four added test files and none modified (checklist, `git diff --name-status`).
- Checklist:
  - [x] Recording a declaration calls none of its functions and schedules nothing: the package test `G10 recording every combinator calls none of its functions, nor a computed initial value, and creates no timer or microtask` records one call of every combinator through `planOf` with functions that throw and a computed initial value whose factory throws, inside a zone that counted a timer and a microtask made in it (2) before, and none made by recording (0); its positive control `G10 the counter counts a periodic timer and nothing else` passed beside it (`+2: All tests passed!`). The gate's replay leaves out the recording suite's two G10 cases, which also build the definition; nidana.model.11's unrestricted replay runs them first (Scope).
  - [x] Each misuse G14 and G15 name throws the named error at the call that commits it, not later: the 28 tests of the third checklist command, by name, which assert the throw at the call itself, inside the declaration, and then that the declaration still plans with no stage left behind; or at the first call after `declare` returned, a declaration that threw included; or at `planOf`, before `declare` runs for an empty id and when `declare` returns for a stage that reaches no sink. Beside them the gate's replay passed the suite's seven G14 and G15 cases (the checklist's replay of `--guarantee G14,G15` alone printed `7 passed, 0 failed`).
  - [x] G9's two recording cases pass, by name (`+2: All tests passed!`), and the package tests `G9 planOf runs declare once per call against a fresh builder and carries the id and scope` and `G9 an empty declaration records an empty plan` passed in the gate's package run. No gate restriction can select them (ADR-001 item 9; this plan, "Which task turns which failing case green").
  - [x] The gate's topology-dsl replay passed 17 of 17 cases. The five cases of the unrestricted suite that the restriction leaves out failed in the unrestricted replay (19 passed, 5 failed), and all five call `buildDefinition()` or read `definition`: the G9 `buildDefinition` case, the two G10 cases and the two G12 cases, nidana.model.11's.
  - [x] Only `TopologyPlan.definition` still throws `UnimplementedError` under `lib/src/topology/` (one line, `plan.dart:39`, `exit: 0`); no `ignore:` is there (no line, `exit: 1`); the export lists are unchanged (`exports_test.dart` passes in the package run); `purity_test.dart` passes over the changed library (topic-model@v1 G25, G26); the lockfile and `pubspec.yaml` are unchanged (`git status --short pubspec.lock` and `git diff --stat` printed nothing). `git diff --name-status` printed ten lines: `M` for `builder.dart`, `handle.dart`, `plan.dart`, `sinks.dart`, `stages.dart` and `topology.dart` under `lib/src/topology/`, and `A` for `combining_stages_test.dart`, `handle_stages_test.dart`, `plan_visitors_test.dart` and `recording_test.dart`.

## Outstanding

None.

## Learnings

- nidana.model.9's Gate as first written restricted the topology-dsl replay to G10 among others, while both of the recording suite's G10 cases call buildDefinition(), which nidana.model.11 delivers, so it failed them whatever this phase built, as it would have failed G9; S128 restated the Gate and the Scope without G10 and S129 amended topology-dsl@v2's Delivery paragraph to match. A replay selects cases by guarantee id, so the gate cannot select G9's two recording cases apart from its buildDefinition() case either: the package tests and the by-name checklist run check the planOf half of G9 and G10, and nidana.model.11's unrestricted replay runs all five cases. Disposition: spec-updated
- The recording suite passes a builder whose visitors bind Object? instead of the stage's type arguments, whose one-sink check compares state topics by identity, whose combineAll hands its combiner a modifiable list, or whose rejected calls leave a stage behind; this phase's package tests pin each (S127 dry run, seeded defects D1 to D4, D8). Disposition: dropped (routed to the end-of-node governance sweep for topology-dsl@v2)
- topology-dsl@v2 does not say which error a call that is misused twice over throws, such as a negative duration given to a closed builder, nor what apply does with a value list whose length is not the number of inputs; this phase checks the closed builder first and throws StateError, then the arguments and throws ArgumentError, and apply throws ArgumentError, not RangeError, for a list that is too long or too short. Disposition: dropped (routed to the end-of-node governance sweep for topology-dsl@v2)
- The phase scope estimated about 400 lines in about 5 files; the product diff is 2131 insertions and 59 deletions in 10 files, of which 527 insertions and 59 deletions in 6 files are library code (see Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint)

## Metrics

- Product diff, `git diff --stat 92d39d6 HEAD -- packages/`, where `92d39d6` is the parent of Task 1's commit: 10 files changed, 2131 insertions, 59 deletions (HEAD `71d1871`; the commit of this doc changes nothing under `packages/`), of which the library (the six part files of `lib/src/topology/`) is 6 files, 527 insertions and 59 deletions, and the tests (four new files) 4 files, 1604 insertions, beside the estimate of about 400 lines in about 5 files; the task count is 5 of the allowed 7 (this doc is Task 5's one file).
- Fix rounds: none after task review (Tasks 1 to 4 were each approved without a fix round); gate failures before green: none.

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
