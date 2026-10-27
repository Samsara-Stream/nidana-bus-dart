# Verification: nidana.model.14 - Mermaid and Graphviz renderers

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`. None of them starts `flutter`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate. It replays topic-model@v1, topology-dsl@v2 and topology-ir@v1 unrestricted, this being topology-ir@v1's last producing phase (D5). For topology-dsl@v2 it runs the recording suite through `topology_builder_test.dart`; its live suite is bus-api@v2's to bind and nidana.runtime's to replay. For topology-ir@v1 it runs the `structure`, `surface`, `reject` and `schema` sets in full, the schema set validating the `valid/` and `invalid/` documents against `hsdd/contract/schema/topology-ir.schema.json`, and the `behavior` set through the binding `nidana_dart_contracts_test.dart` with every case. Its three G22 cases compare the renderers' real output with the `render/` goldens and the JSON rendering with the `valid/` files:

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir
```

The checklist, where `d3d2c2c` is the parent of Task 1's commit (the phase base). The first two commands print by name the cases and tests that the gate reports only as counts; the next two are searches that must find nothing; the last three show the file set and that no dependency moved:

```sh
fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G22 ' -r expanded
fvm dart test packages/nidana_dart_contracts/test/mermaid_renderer_test.dart packages/nidana_dart_contracts/test/graphviz_renderer_test.dart -j 1 -r expanded
grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/render; echo "exit: $?"
grep -rnE "DateTime\.now\(|Stopwatch\(|Timer\(|Timer\.periodic\(|scheduleMicrotask\(|Future\.delayed\(|Future\.microtask\(|Random\(|Zone\." packages/nidana_dart_contracts/lib; echo "exit: $?"
git diff --name-status d3d2c2c HEAD -- packages/nidana_dart_contracts
git status --short pubspec.lock
git diff --stat d3d2c2c HEAD -- packages/nidana_dart_contracts/pubspec.yaml packages/nidana_dart_contracts/lib/topology_ir.dart
```

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+371: All tests passed!`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 43 passed, 0 failed, 0 skipped under dart test` with no `restricted to` (the replay is unrestricted), the 46 `PASS schema` lines of topology-ir@v1 (the schema, 38 `invalid/` and 7 `valid/` documents) and `120 fixtures: 120 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` line appears. The suite count is the package's tests as the implementers left them, 371; the plan's floor of `+369` (353 at the phase base and 16 in two new files) is lower by the two tests the controller's type-name ruling added (see Observed).
- The checklist prints, in order:
  - the three G22 case names of topology-ir@v1's binding, then `+3: All tests passed!`;
  - 18 test names, 9 from `mermaid_renderer_test.dart` and 9 from `graphviz_renderer_test.dart` (`-j 1` runs one file at a time), then `+18: All tests passed!` (the plan's 8 and 8, and the one test per file the type-name ruling added);
  - no line and `exit: 1` for each of the two searches;
  - five lines of `git diff --name-status`: `M` for `lib/src/render/renderers.dart`, `A` for `test/src/render_support.dart`, `test/mermaid_renderer_test.dart` and `test/graphviz_renderer_test.dart`, and `M` for `test/topology_graph_test.dart` (the plan counted four lines; the fifth is the comment ruling's comment-only edit);
  - no output from `git status --short pubspec.lock` and none from `git diff --stat`.

## Observed

Run on 2026-10-27, on branch `impl/nidana.model.14` at `ca7b1f3` (phase base `d3d2c2c`), Dart 3.13.5 through `fvm`. The implementation step started at 2026-10-27T21:42:43Z. The gate ran from 2026-10-27T21:56:18Z to 21:56:25Z, and the checklist from 21:56:40Z to 21:56:59Z, both at `ca7b1f3` with no change under `packages/` or `hsdd/` in the working tree.

- The gate exited 0. Its lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:01 +371: All tests passed!`
  - `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test` (topic-model@v1, unrestricted)
  - `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test` (topology-dsl@v2, unrestricted)
  - `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 43 passed, 0 failed, 0 skipped under dart test` (topology-ir@v1, unrestricted: no `restricted to`), then 46 `PASS schema` lines (the schema, 38 `invalid/` and 7 `valid/` documents) and `120 fixtures: 120 passed, 0 failed, 0 pending` (no `FAIL`, `ERROR` or `PENDING` line anywhere in the output). This is the first gate of the node in which every contract replay is unrestricted, and it means topology-ir@v1 is fully produced.
- The package counts differ from the plan's for one reason: the suite is 371 tests against 353 at the phase base, not the plan's 369; the two new test files hold 18 tests, not 16 (9 and 9, not 8 and 8). The two additions are the type-name ruling's tests, one per file.
- Rulings of the controller, with their reasons, in the ledger's order:
  - The comment ruling. The header comment of `test/topology_graph_test.dart` said the G22 render case "waits for nidana.model.14's Mermaid renderer", which stopped being true when Task 2 landed. Task 2's implementer reworded the sentence (a comment, no test changed), because the plan edits no existing test and a stale comment in a shipped test misleads.
  - The type-name ruling. Task 1's review found the `typeName` part of topic identity unpinned: the renderers key a topic node by the whole `TopicRef`, its `typeName` included, but no sample and no built graph holds two topics with one name and variant, so a mutant that keyed by name and variant alone passed every test. Task 2 added one test per renderer file, over a small graph of two such topics (`typeNamesGraph` in `test/src/render_support.dart`), `G22 topics of one name and variant but two type names are two nodes, and each arrow runs to its own`, and left `arrowsGraph` as it was. Task 2's implementer reports that the mutant fails both tests. The cost was two tests. Both rulings are in `ca7b1f3`.
- Evidence from the task reviews, from the controller's ledger (not re-run at the gate): Task 1's review rendered all seven `valid/` samples and compared them byte for byte with `render/*.mmd` only, because `GraphvizRenderer` was still a stub then, and checked that the arrow sequences of the `.mmd` and `.dot` goldens agree. Task 2's review rendered them against both `render/*.mmd` and `render/*.dot`. Task 1's implementer killed 20 of 20 single-point mutations with the brief's tests. Task 2's review also checked the escape order, the join after escaping, the dedup labels and the header and footer against the rule text.
- Deferred review findings (all minor, no code change): the id formats are spelled in `render` and again in `_arrows`, which the tests pin; the indentation walk does not assert that depth-2 lines sit inside a cluster, the whole texts being pinned elsewhere; `_mermaidLabel` and `_graphvizLabel` share a shape and stay separate because their escapes differ.

Checklist:

- [x] The seven samples render to their `render/` goldens byte for byte. The suite's `G22 the Mermaid and Graphviz renderings of every sample equal its render/ files` passes, and so do the package's `G22 every sample renders to its render/ .mmd file byte for byte` and `G22 every sample renders to its render/ .dot file byte for byte`. In the `escaping` sample Mermaid writes `#35;` for `#`, `#quot;`, `#lt;`, `#gt;` and `#10;` for a newline and leaves `\` as it is, and Graphviz writes `\\`, `\"` and `\n` and leaves `<`, `>` and `#` as they are.
- [x] The cases this phase turned green, by name. The first checklist command printed the three G22 cases and `+3: All tests passed!`. Two are the cases this phase turned green, `G22 the Mermaid and Graphviz renderings of every sample equal its render/ files` and `G22 render passes the graph to the renderer, and renderers are pure`; the third, `G22 the JSON rendering of every sample is its valid/ file, byte for byte`, was already green at nidana.model.13 and stays so. The second printed the 18 package test names and `+18: All tests passed!`.
- [x] Rendering, encoding, decoding and the analyses schedule nothing: the suite's `G22 render passes the graph to the renderer, and renderers are pure` passes, and so does each new file's `G22 rendering schedules nothing, and every line ends with a newline and is indented by two spaces per level`, over every sample and every graph the tests build.
- [x] The gate's topology-ir@v1 replay passes 43 of 43, unrestricted, against 41 before this phase, and its schema set passes its 46 documents.
- [x] What the goldens leave open is pinned by the package's tests, all passing in the gate's package run: an anonymous retry (`G22 an edge renders its transformer and its retry on lines of their own, an anonymous reference as (anonymous)`), durations above a second that are not whole seconds (`G22 a duration renders in whole seconds, else whole milliseconds, else microseconds`), a repeated input (`G22 parts and arrows come in graph order: one arrow per input, a repeated input repeated, then the sink output, then the claims`), one topic name of two variants (the same arrows test, over a graph that holds one) and of two type names (the type-name ruling's test), and the characters neither renderer escapes (`G22 Mermaid escapes # first, ...` in `mermaid_renderer_test.dart` and `G22 Graphviz escapes \ first, ...` in `graphviz_renderer_test.dart`, one escape test per renderer). Every other test named here exists in both files. These are six gaps of the replay: the first Learning below lists five of them and the third lists the sixth, the type-name case.
- [x] No `UnimplementedError` remains under `lib/src/render/` (no line, `exit: 1`) and no D6 token appears under `lib/` (no line, `exit: 1`). The export lists are unchanged (`exports_test.dart` passes, four tests), `purity_test.dart` passes over `renderers.dart` (topic-model@v1 G25, G26), and the lockfile, `pubspec.yaml` and `topology_ir.dart` are unchanged (`git status --short pubspec.lock` and `git diff --stat` printed nothing). `git diff --name-status` printed the five lines the checklist expects.

## Outstanding

None.

## Learnings

- No render/ golden of topology-ir@v1 holds an anonymous retry, a duration above a second that is not whole seconds, a repeated input, one topic name of two variants, or a character such as & that the rules leave as it is, so a renderer that writes "retry null", rounds 1500ms down to 1s, collapses repeated arrows, gives two variants of one name one id, or escapes & passes every replay of this node (S149 dry run, seeded defects D4, D6, D7, D12 and D13); this phase's package tests pin all five. Disposition: dropped (reported to hsdd-contract as a low contract gap by S149)
- The phase scope estimated about 260 lines in about 3 files, tests included; the product diff is 903 insertions and 4 deletions in 5 files, of which 174 insertions and 2 deletions in 1 file are library code (see Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint)
- No sample of topology-ir@v1 holds two topics of one name and variant with different `typeName`s, so a renderer that keys topic ids by name and variant, and not by the whole topic reference, passes every replay of this node (found by Task 1's review, a sixth gap beside the first Learning's five); only the type-name ruling's test in each renderer file, `G22 topics of one name and variant but two type names are two nodes, and each arrow runs to its own`, catches it. Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)

## Metrics

- Product diff, `git diff --stat d3d2c2c HEAD -- packages/`, where `d3d2c2c` is the parent of Task 1's commit: 5 files changed, 903 insertions, 4 deletions (HEAD `ca7b1f3`; the commit of this doc changes nothing under `packages/`), of which the library (`lib/src/render/renderers.dart`, 15 lines before and 187 now) is 1 file, 174 insertions and 2 deletions, and the tests are 4 files, 729 insertions and 2 deletions (`test/src/render_support.dart`, `test/mermaid_renderer_test.dart` and `test/graphviz_renderer_test.dart`, all new, 727 insertions, and the comment edit of `test/topology_graph_test.dart`, 2 insertions and 2 deletions), beside the estimate of about 260 lines in about 3 files, tests included; the task count is 3 of the allowed 5 (this doc is Task 3's one file); fix rounds: none. Tasks 1 and 2 needed no fix round after review (both reviews approved at once), and the two controller rulings were made inside Task 2's own commits (`ca7b1f3`), not as fix rounds. This statement covers the task reviews only; if a final fix wave happens, its implementer updates it. Package tests: 353 at the phase base, 371 now.

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
