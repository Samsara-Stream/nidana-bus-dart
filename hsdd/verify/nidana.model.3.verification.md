# Verification: nidana.model.3 - topic-model@v1 declarations

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate, which replays topic-model@v1's `structure`, `surface` and `reject` sets against the real package (no `schema` set: a `shared-model` contract with no serialized form carries no schema, ADR-001 item 4):

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model --set structure,surface,reject
```

The checklist:

```sh
grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?"
sed -n '/^export/,$p' packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart | tr -s ' ,;\n' '\n\n\n\n' | grep -E '^[A-Za-z]+$' | grep -vxE 'export|show' | LC_ALL=C sort | tr '\n' ' '
grep -rn "dispatcher" packages/nidana_dart_contracts/lib; echo "exit: $?"
git status --short pubspec.lock
```

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+11: All tests passed!` and `30 fixtures: 30 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` fixture line appears.
- The checklist prints `exit: 1` for the first and third `grep` (no line), exactly the Interface's 25 names for the export list (`BusObserver Dedup EventTopic ExecutorSource Lineage LogLevel MessageEnvelope MessageSource MultiWriterTopic ObserveContext ObserverCapability PageSource RedactedPayload ReplayTopic Scope ServiceSource SpanHandle StateTopic Topic TopicRef TopicVariant TopologySource Tracing UnknownSource isWellFormedTopicName`), and no output for the lockfile.

## Observed

Run on 2026-10-26 (`date -u +%Y-%m-%d`), the gate started at 2026-10-26T23:15:48Z and ended at 23:15:51Z, on branch `impl/nidana.model.3` at `6e9e816` (phase base `2e301d0`), Dart 3.13.5 through `fvm`.

- The gate exited 0 (`exit: 0`). Its five lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:00 +11: All tests passed!` (4 tests in `purity_test.dart`, 7 in `declarations_test.dart`)
  - `30 fixtures: 30 passed, 0 failed, 0 pending` (17 `PASS structure`, 3 `PASS surface`, 10 `PASS reject`; no `FAIL`, `ERROR` or `PENDING` line)
- Checklist:
  - [x] This is the first replay of topic-model@v1's committed surface and reject fixtures against a real package, nidana.model.2's doc having deferred it to this phase. All 3 surface and 10 reject libraries passed against `nidana_dart_contracts`, as topic-model@v1's first producing phase: every reject code the stand-in confirmed holds, none differs, and no line carries two codes.
  - [x] The main library exports exactly the Interface's 25 names, and no code outside the package imports its `src/` (the `grep` printed no line and `exit: 1`).
  - [x] No topic constructor takes a dispatcher hint (G5, OQ-M3): `grep -rn "dispatcher" packages/nidana_dart_contracts/lib` printed no line and `exit: 1`.
  - [x] `purity_test.dart` holds the package to `meta` and `test` and to no clock, timer, microtask, id or I/O (G25, G26), and passes; the lockfile is unchanged: `git status --short pubspec.lock` printed nothing, and `git diff 2e301d0 HEAD -- pubspec.lock` is empty although the root `pubspec.yaml` gained the `packages/nidana_dart_contracts` workspace line.

## Outstanding

None.

## Learnings

- topic-model@v1's Interface, "Message sources", writes four of MessageSource's five renderings in angle brackets (`'topology:<id>'` and the others), which the root lint set's `unintended_html_in_doc_comment` reports when the dartdoc is copied verbatim, so the code puts them in backticks. Disposition: dropped (no fixture depends on the doc text; a compatible hsdd-contract touch at the end of nidana.model can match the contract to the code)
- nidana.model D3's final field behind every getter and throwing bodies leave RedactedPayload's private constructor unused while RedactedPayload.of throws, so the package carries one ignore of unused_element until nidana.model.8. Disposition: dropped (temporary; nidana.model.8 calls the constructor)
- The phase scope says the phase adds the package to the lockfile; adding the member to the root `workspace:` list left `pubspec.lock` byte-identical, because a workspace lockfile records no member and already held `meta` and `test`. Disposition: dropped (wording in the phase plan; the lockfile rule of ADR-002 item 1 holds)
- topic-model@v1's behavior binding already loads against these declarations; its cases fail on `UnimplementedError` and also on identity equality and `Object.toString` (`fvm dart test hsdd/contract/fixture/topic-model/behavior`, run outside the gate, reports 9 passed and 32 failed), so nidana.model.6's Verification sentence "cases fail on UnimplementedError, not on loading" holds only loosely. Disposition: dropped (routed to nidana.model.6's plan, which states what it checks)
- The phase scope estimated about 430 lines in about 8 files, about half dartdoc; the product diff is 916 lines in 15 files: the library is 384 lines in 8 files, of which 72 are `///` dartdoc lines, beside 270 lines of tests in 2 files, 261 lines in 4 package files (201 of them the copy of `LICENSE`) and 1 line of the root `pubspec.yaml`. Disposition: dropped (sizing is the owner's to revisit at a checkpoint)

## Metrics

- Product diff, `git diff --stat 2e301d0 HEAD -- packages/ pubspec.yaml`: 15 files changed, 916 insertions, 0 deletions, of which the library is 8 files and 384 lines and the tests 2 files and 270 lines, beside the estimate of about 430 lines in about 8 files; the task count is 4 of the allowed 5 (this doc is Task 4's one file).

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
