# Verification: nidana.model.10 - IR values and function references

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`. None of them starts `flutter`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate. It replays topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets in full and its `behavior` set through the binding `nidana_dart_contracts_test.dart` under `dart test`, restricted to the guarantees this phase delivers (G2, G5, G6, G9, G10), beside topic-model@v1 unrestricted and topology-dsl@v2's three type-level sets (`structure`, `surface`, `reject`):

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl --set structure,surface,reject && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G9,G10
```

The checklist, where `c81b26b` is the parent of Task 1's commit (the phase base). The first four commands print by name the cases and tests that the gate's replay and package run report only as counts; the fifth shows what the restriction leaves out; the next three are searches that must find nothing; the last three show the file set and that no dependency moved:

```sh
fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G9 ' -r expanded
fvm dart test packages/nidana_dart_contracts/test/function_ref_test.dart -r expanded
fvm dart test packages/nidana_dart_contracts/test/transform_edge_test.dart packages/nidana_dart_contracts/test/topology_definition_test.dart --name '^G[56] ' -j 1 -r expanded
fvm dart test packages/nidana_dart_contracts/test/findings_test.dart --name '^G23 ' -r expanded
fvm dart run nidana_contract_check topology-ir --set behavior; echo "exit: $?"
grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/analysis/findings.dart; echo "exit: $?"
grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/analysis; echo "exit: $?"
grep -rnE "^(import|export) .*graph/" packages/nidana_dart_contracts/lib/src/ir; echo "exit: $?"
git diff --name-status c81b26b HEAD -- packages/nidana_dart_contracts
git status --short pubspec.lock
git diff --stat c81b26b HEAD -- packages/nidana_dart_contracts/pubspec.yaml
```

The fifth command is the unrestricted replay of the `behavior` set. It exits 1 until nidana.model.14, by design (see Observed).

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+200: All tests passed!`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `31 fixtures: 31 passed, 0 failed, 0 pending`, `27 fixtures: 27 passed, 0 failed, 0 pending`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 10 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G5, G6, G9, G10` and `61 fixtures: 61 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` line appears. The suite count is the package's tests as the implementers left them, 200; the plan's `+182` was lower by the tests they added where a rule would otherwise go unpinned.
- The checklist prints, in order:
  - the three G9 case names of the suite, then `+3: All tests passed!`;
  - the eight test names of `function_ref_test.dart`, then `+8: All tests passed!` (the plan's six and two the implementer added);
  - sixteen test names, eight from `transform_edge_test.dart` and eight from `topology_definition_test.dart` (`-j 1` runs one file at a time), each beginning `G5 ` or `G6 `, then `+16: All tests passed!` (the plan's ten, four and six, and the tests the implementers and the controller's ruling added);
  - the seven `G23 ` test names of `findings_test.dart`, then `+7: All tests passed!`;
  - for the unrestricted replay, `exit: 1` and `FAIL behavior` for the binding with `cases (11 passed, 32 failed, 0 skipped under dart test)`, then `10 fixtures: 9 passed, 1 failed, 0 pending`; the eleven are the restriction's ten and `G7 IR values are equal, with equal hash codes, exactly when their fields are`, and the 32 failed cases call what nidana.model.11 to nidana.model.14 deliver;
  - no line and `exit: 1` for each of the three searches;
  - ten lines of `git diff --name-status`: `M` for `lib/src/ir/function_ref.dart`, `lib/src/ir/definition.dart` and `lib/src/analysis/findings.dart`, and `A` for `lib/src/ir/canonical_order.dart`, the five new test files and `test/src/cart_elsewhere.dart`;
  - no output from `git status --short pubspec.lock` and none from `git diff --stat` of `pubspec.yaml`.

## Observed

Run on 2026-10-27, on branch `impl/nidana.model.10` at `9ea70e2` (phase base `c81b26b`), Dart 3.13.5 through `fvm`. The implementation step started at 2026-10-27T14:38:37Z. The gate ran twice, both times green; the run recorded here started at 2026-10-27T15:13:56Z and ended at 15:14:04Z (the first ended at 15:13:47Z). The checklist ran from 15:14:14Z.

- The gate exited 0. Its lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:00 +200: All tests passed!`
  - `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test` and `31 fixtures: 31 passed, 0 failed, 0 pending`
  - `27 fixtures: 27 passed, 0 failed, 0 pending` (topology-dsl@v2)
  - `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 10 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G5, G6, G9, G10` and `61 fixtures: 61 passed, 0 failed, 0 pending` (no `FAIL`, `ERROR` or `PENDING` line anywhere in the output)
- Three counts differ from the plan's, for one reason (the implementers added tests where a rule would otherwise go unpinned, which the Global Constraints allow): the suite is 200 tests, not 182; `function_ref_test.dart` has 8 tests, not 6; and the `^G[56] ` run has 16, not 10 (8 and 8, not 4 and 6).
- Deviation, by controller ruling: the Global Constraints say this phase creates five test files and edits no existing test. Commit `9ea70e2`, from Task 4's review, edits `test/topology_definition_test.dart`, Task 4's file, from Task 5 (one test added): `G6 two state topics of one name whose value types differ are two topics, each with its sink` builds a definition with a state sink on a `StateTopic<int>` and one on a `StateTopic<String>` of one name, accepts it and expects two writes. A mutant that compared state sinks by name alone passed every earlier test. Task 5 therefore landed as two commits, `5e4e1b1` and `9ea70e2`. Against the phase base the diff still shows five added test files and one helper, none modified (checklist, `git diff --name-status`).
- Deviation, by controller ruling: S135 routed two review notes to later work and changed no code of this phase for them. Task 3's review note went to nidana.model.11: sort claims with `compareClaimKeys` over a claim's source, scope and writes and topologies with `compareTopologyIds`, and note that the id order alone neither dedupes equal definitions nor rejects unequal ones sharing an id (G11, G15), which `TopologyGraph` must do. Task 1's review note about the derivation table went to the end-of-node governance sweep (Learnings).
- Checklist:
  - [x] `FunctionRef.of` gives on the VM the names topology-ir@v1's derivation table lists: the suite's three G9 cases pass by name (public names for a top-level function, a static method and a method tear-off; anonymous for a closure and a local function, and never calls the function; private names as the VM renders them, the name followed by `@` and the library key, unequal to the name as written), `+3: All tests passed!`. The package's eight tests passed beside them (`+8`): a constructor tear-off, a generic function and a call tear-off; the library key kept after a private class, constructor and method name; anonymous for an extension method tear-off, a closure a static method returns and a closure that calls a named function; `of` and `named` agreeing on a public name; `named` keeping any non-empty name and throwing `ArgumentError` naming the argument for an empty one; G7 equality and hash codes by name; equal to no other kind of object; and one tear-off taken twice as one name. The dry run's `dart run` table agrees (`docs/auto-run/experiments/ir-values-plan/output.txt`, F1 R).
  - [x] An edge or a definition that breaks a rule throws at construction, naming the argument at fault: the sixteen tests of the third checklist command passed (`+16`). The eight G5 tests of `transform_edge_test.dart` cover the whole stage-edge table (input counts, transformer, duration and retry per combinator, each rejection an `ArgumentError` naming the argument), a negative and a zero duration, the first fault named when there are several, sink edges and a `reduceInto` that refuses every variant but state. The eight G6 tests of `topology_definition_test.dart` cover reads and writes over repeated topics in canonical order, a stage fed to several edges, a state topic and an event topic of one name as two topics, the empty id (`topologyId`) and every well-formedness rule (`transforms`), the corner of value types that render alike (a sink on each throws) and its converse (types that differ are accepted, with two writes), and the negative stage input, run without assertions through `Platform.resolvedExecutable`, which prints `StageInput(-1)` and `ArgumentError(transforms)`. Beside them the gate's replay passed the suite's three G5 and two G6 cases. The private constructors `TransformEdge._` and `TopologyDefinition._` have no caller but the checking factories (`definition.dart` lines 124, 136, 159 and 343).
  - [x] The gate's topology-ir replay passed 10 of 10 cases (against 1 of 10 before this phase, where only `G2 CombinatorKind has exactly the eighteen values, in order` passed). The unrestricted replay of the `behavior` set exited 1 with `cases (11 passed, 32 failed, 0 skipped under dart test)` and `10 fixtures: 9 passed, 1 failed, 0 pending`; the eleven are the ten and `G7 IR values are equal, with equal hash codes, exactly when their fields are`, which passes ahead of its restriction. None of the 32 failures is a case of G2, G5, G6, G9 or G10; they cover graphs, claims, the projection, the analyses, the codec and the renderers, nidana.model.11 to nidana.model.14's.
  - [x] Not in the gate: G3, G7 and G23. G3 and G7 join the restriction at nidana.model.11 and G23 at nidana.model.12, because their cases also build graphs or run the analyses over a sample graph that `buildDefinition()` records. Until then the package's own tests cover them, and all passed in the gate's package run: `G3 an edge keeps an unmodifiable copy of its inputs`, `G3 a definition keeps an unmodifiable copy of its edges, and its reads and writes ...`, `G3 findings and collisions keep unmodifiable copies of their lists`, the G7 tests of edges, edge inputs, definitions, function references and findings (equal exactly when their fields are, with equal hash codes), and the G23 tests.
  - [x] The findings' constructors sort, keep repeats and copy: the seven `G23 ` tests of `findings_test.dart` passed (`+7`), for a cycle's ids and topics, a self-reference's edges, a writer conflict's writers, a collision's declarations by site as code units, then topic, findings built in any order equal with equal hash codes, and a constructor that sorts its own copy and leaves the caller's list as it came.
  - [x] No `UnimplementedError` remains under `lib/src/ir/` or in `findings.dart` (no line, `exit: 1`), no `ignore:` under `lib/src/ir/` or `lib/src/analysis/` (no line, `exit: 1`; the two `// ignore: unused_element` lines in `lib/src/graph/graph.dart` stay for nidana.model.11), and `lib/src/ir/` imports and exports nothing from `graph/` (no line, `exit: 1`). The export lists are unchanged (`exports_test.dart` passes in the package run), `purity_test.dart` passes over the changed libraries (topic-model@v1 G25, G26), and the lockfile and `pubspec.yaml` are unchanged (`git status --short pubspec.lock` and `git diff --stat` printed nothing). `git diff --name-status` printed ten lines: `M` for `function_ref.dart`, `definition.dart` and `findings.dart`, and `A` for `canonical_order.dart`, `canonical_order_test.dart`, `findings_test.dart`, `function_ref_test.dart`, `topology_definition_test.dart`, `transform_edge_test.dart` and `test/src/cart_elsewhere.dart`.

## Outstanding

None.

## Learnings

- topology-ir@v1's G6 rejects a StageInput with a negative index, but no fixture builds one and its Validation section has no not-executable line for it: the binding runs under dart test with assertions enabled, so StageInput's own assertion fires first; this phase's package test runs a small program through Platform.resolvedExecutable, without assertions, and expects ArgumentError naming transforms (S134 dry run, seeded defect D4). Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)
- topology-ir@v1's conformance suite passes a stage edge that accepts a retry on a combinator other than map (seeded defect D5) and a definition whose equality ignores the order of its edges (D11); this phase's package tests pin both, the first in the table test of transform_edge_test.dart and the second in the G7 definitions test of topology_definition_test.dart (S134 dry run, suite_reach.txt). Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)
- topology-ir@v1's derivation table says an extension tear-off is anonymous, which holds for instance members only: on Dart 3.13.5 a static method of a named extension renders Ext|helper, so FunctionRef.of names it, and an extension-type constructor tear-off renders ET|constructor#_#new#tearOff; the text rule names both and the schema accepts any non-empty name, while the package pins the instance case only (S135 Task 1 review, probed again at the gate). Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)
- Two state topics whose value types render alike, one class name in two libraries, pass planOf, because topology-dsl@v2's G14 compares them by Topic equality, but are one TopicRef to the IR, so the TopologyDefinition factory throws ArgumentError naming transforms for a definition with a sink on each; this contradicts the closing sentence of "From a plan" that every projected definition is well formed, this phase pins the IR side, and nidana.model.11's buildDefinition() will raise it for a plan that planOf accepts. Disposition: dropped (already routed to the end-of-node governance sweep by S132's final review and to nidana.model.11)
- The phase scope estimated about 400 lines in about 6 files; the product diff is 2046 insertions and 19 deletions in 10 files, of which 487 insertions and 19 deletions in 4 files are library code (see Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint)

## Metrics

- Product diff, `git diff --stat c81b26b HEAD -- packages/`, where `c81b26b` is the parent of Task 1's commit: 10 files changed, 2046 insertions, 19 deletions (HEAD `9ea70e2`; the commit of this doc changes nothing under `packages/`), of which the library (`function_ref.dart`, `definition.dart`, `canonical_order.dart` and `findings.dart`) is 4 files, 487 insertions and 19 deletions, and the tests (five test files and the helper `test/src/cart_elsewhere.dart`) 6 files, 1559 insertions, beside the estimate of about 400 lines in about 6 files; the task count is 6 of the allowed 7 (this doc is Task 6's one file).
- Fix rounds: none after task review (Tasks 1 to 5 were each approved without a fix round); gate failures before green: none.

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
