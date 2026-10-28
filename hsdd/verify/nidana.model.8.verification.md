# Verification: nidana.model.8 - Topic model values and lineage

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`. None of them starts `flutter`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate, which replays topic-model@v1 unrestricted (`structure`, `surface`, `reject`, and `behavior` through the binding `nidana_dart_contracts_test.dart` under `dart test`; no `schema` set, ADR-001 item 4) and the type-level sets of topology-dsl@v2 and topology-ir@v1:

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl topology-ir --set structure,surface,reject,schema
```

The checklist, where `3c683b0` is the parent of Task 1's commit (the phase base):

```sh
fvm dart test hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart --name '^G19 a (same-correlation combine keeps|cross-correlation combine takes)' -r expanded
fvm dart test packages/nidana_dart_contracts/test/envelope_test.dart --plain-name 'G15 a sensitive envelope, and its redacted() envelope' -r expanded
grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/topic; echo "exit: $?"
grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/topic; echo "exit: $?"
git diff --name-status 3c683b0 HEAD -- packages/nidana_dart_contracts/lib packages/nidana_dart_contracts/README.md
git status --short pubspec.lock
git diff --stat 3c683b0 HEAD -- packages/nidana_dart_contracts/pubspec.yaml
```

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+95: All tests passed!`, `31 fixtures: 31 passed, 0 failed, 0 pending` (with `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`) and `87 fixtures: 87 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` line appears.
- The checklist prints, in order: the two case names of Spec §2.4's worked examples, then `+2: All tests passed!`; the name of the one G15 test, then `+1: All tests passed!`; no line and `exit: 1` for each of the two `grep -rn` commands; nine lines of `git diff --name-status`, `A` for `lib/src/topic/list_equality.dart` and `M` for `README.md` and the seven other libraries of `lib/src/topic/`; and no output from the last two commands.

## Observed

Run on 2026-10-27. The gate started at 2026-10-27T12:03:45Z and ended at 12:03:50Z, on branch `impl/nidana.model.8` at `ccab161` (phase base `3c683b0`), Dart 3.13.5 through `fvm`. The checklist ran at 12:04:09Z and 12:04:10Z, and its G15 commands at 12:04:10Z and 12:04:11Z.

- The gate exited 0. Its six lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:00 +95: All tests passed!`
  - `31 fixtures: 31 passed, 0 failed, 0 pending` (17 `PASS structure`, 3 `PASS surface`, 10 `PASS reject` and `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`)
  - `87 fixtures: 87 passed, 0 failed, 0 pending` (topology-dsl@v2 and topology-ir@v1; no `FAIL`, `ERROR` or `PENDING` line anywhere in the output)
- The suite count is 95, not the plan's 60: the plan's `+N` figures were off by the extra tests the tasks' implementers added where a rule would otherwise go unpinned, which the plan's Global Constraints allow, and the final fix wave added one (the sentinel test of G15 and G24).
- Checklist:
  - [x] The unrestricted replay of topic-model@v1 passed all 41 behavior cases, where nidana.model.3's declarations passed 9 and failed 32 (`hsdd/verify/nidana.model.6.verification.md`), and passed its 3 surface and 10 reject libraries beside them.
  - [x] Spec §2.4's two worked examples reproduce as written, by name: `G19 a same-correlation combine keeps the correlation and takes the trigger as cause` (`sess-42` kept, cause `e-02`, no fresh id) and `G19 a cross-correlation combine takes one fresh correlation and records the inputs` (one fresh id, parents `pref-update-5` and `market-feed-9`); `+2: All tests passed!`. Spec §2.4 is not checked out on this machine (S113); the examples are checked as the contract's G19 cases encode them, with the values of the phase context's Verification line.
  - [x] A sensitive envelope never renders its payload: the suite's case `G15 a sensitive envelope renders its payload redacted`, and the package test `G15 a sensitive envelope, and its redacted() envelope, never render the payload, whatever the payload`, which renders a class, a `String`, a `List` and a `Map` payload before and after `redacted()` (`+1: All tests passed!`). The plan's command `--name 'G15'` also matches the other three G15 tests of `envelope_test.dart`, one of them the final fix wave's sentinel test, whose payload's `toString` throws; it ran `+4: All tests passed!`, and the command above narrows it to the one.
  - [x] The property tests ran 500 seeds per property (`seeds = 500` in `test/lineage_property_test.dart`) and reached every branch of Spec §2.4's table: the combine property counts the generated inputs with no, one and several distinct correlations and asserts each count exceeds 10 of the 500 seeds.
  - [x] No body under `lib/src/topic/` throws `UnimplementedError` (`grep` printed no line, `exit: 1`), no `ignore:` is left there (no line, `exit: 1`: the `// ignore: unused_element` above `RedactedPayload._` is gone), the export lists are unchanged (`exports_test.dart` passes), `purity_test.dart` passes over the new library (G25, G26), and the lockfile and `pubspec.yaml` are unchanged (`git status --short pubspec.lock` and `git diff --stat` printed nothing). `git diff --name-status` printed nine lines: `A` for `lib/src/topic/list_equality.dart` (not exported) and `M` for `README.md` and the seven other libraries of `lib/src/topic/`.

With this phase every behavior case of topic-model@v1 passes unrestricted in the package: this is the last phase that produces the contract. Learnings 1, 4 and 5 hold the wording of G15, G24 and G13 that no implementation can meet literally.

## Outstanding

Spec §2.4's worked examples were not compared with the Specification itself, because `ref/nidana-docs` is not checked out on this machine (S113). It takes comparing the two G19 cases (`G19 a same-correlation combine keeps the correlation and takes the trigger as cause` and `G19 a cross-correlation combine takes one fresh correlation and records the inputs`) with Spec §2.4's worked examples once `ref/nidana-docs` is checked out.

Proposed disposition: deferred to the end-of-node governance sweep, or to whenever the reference architecture is available.

## Learnings

- topic-model@v1 G15 and G24 say a redaction never contains the payload's own rendering, which no implementation can hold for a payload whose rendering is short enough to occur in the redaction format: `RedactedPayload.of('String')` renders `<redacted String #...>`, which contains `String`, and the digit of a one-digit number such as `1` occurs among the hash digits of its own redaction. The suite's payload has a distinctive rendering, and this phase's tests use such payloads. Disposition: dropped (routed to the end-of-node governance sweep for topic-model@v1)
- topic-model@v1 G15 has `redacted()` wrap whatever payload a sensitive envelope holds, and `toString()` render `RedactedPayload.of(payload)`, so the rendering of `envelope.redacted()` shows `<redacted RedactedPayload #...>` and loses the payload's type, which Spec §9.2 item 2 shows and which the surface fixture's `AuditObserver` logs; a second `redacted()` wraps the payload again. This phase follows G15 as written. Disposition: dropped (routed to the end-of-node governance sweep for topic-model@v1)
- topic-model@v1's opening sentence and nidana.model's Pure band paragraph say everything in the package is a value or a total function, while the observer interfaces are neither and `Lineage.combine` throws `ArgumentError`; this phase corrected the package README only. Disposition: dropped (routed to the end-of-node governance sweep for topic-model@v1 and nidana.model's Pure band)
- topic-model@v1 G24 says redacted payloads are equal for equal payloads, and its Interface says `==` compares `typeName` and `hash`; `RedactedPayload.of(1) != RedactedPayload.of(1.0)` although `1 == 1.0`, because the type names (`int`, `double`) differ. Disposition: dropped (routed to the end-of-node governance sweep for topic-model@v1)
- topic-model@v1 G13 read literally (all eight fields equal) makes a `MessageEnvelope` whose payload is NaN unequal to itself, so a `Set` of envelopes cannot find it; an `identical()` short-circuit in `==` would be the contract owner's call. Disposition: dropped (routed to the end-of-node governance sweep for topic-model@v1)
- With value equality in place, a non-empty const set of, or a const map keyed by, topics, topic references, sources, envelopes, lineages or redacted payloads does not compile; no committed fixture of any slug holds one and no library of the package does (S124's experiment), and consumer plans must not write one. Disposition: dropped (routed to the consumer nodes' plans)
- The phase scope estimated about 420 lines in about 6 files; the product diff is 1464 insertions and 34 deletions in 15 files (see Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint)

## Metrics

- Product diff, `git diff --stat 3c683b0 HEAD -- packages/`, where `3c683b0` is the parent of Task 1's commit: 15 files changed, 1464 insertions, 34 deletions (HEAD `ccab161`; the commit of this doc changes nothing under `packages/`), of which the library (eight libraries under `lib/src/topic/` and the README) is 9 files, 258 insertions and 34 deletions, and the tests 6 files, 1206 insertions, beside the estimate of about 420 lines in about 6 files; the task count is 6 of the allowed 7 (this doc is Task 6's one file).
- Fix rounds: none after task review (Tasks 1 to 6 were each approved without a fix round), plus the final fix wave. The final review (`3c683b0..d812c3f`) returned With fixes, 0 Critical and 2 Important, both in this doc, and its Minors made one wave of two commits: the sentinel test and the README sentence in the package (`ccab161`), then this doc's corrections.

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
