# Verification: nidana.model.4 - topology-dsl@v2 declarations

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate, which replays topic-model@v1's and topology-dsl@v2's `structure`, `surface` and `reject` sets against the real package (no `schema` set: neither contract has a serialized form, so neither carries a schema, ADR-001 item 4):

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject
```

The checklist:

```sh
grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?"
grep -rnE "operator ==|hashCode" packages/nidana_dart_contracts/lib/src/topology packages/nidana_dart_contracts/lib/src/ir; echo "exit: $?"
fvm dart run nidana_contract_check topology-ir --set surface,reject; echo "exit: $?"
fvm dart run nidana_contract_check topology-dsl topology-ir --set surface,reject; echo "exit: $?"
git status --short pubspec.lock
```

The third command runs outside the gate. The fourth is the routed RED baseline command.

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+28: All tests passed!` and `57 fixtures: 57 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` fixture line appears.
- The checklist prints `exit: 1` for the first two `grep` commands (no line) and nothing for the lockfile. The `topology-ir` run exits 1 with `14 fixtures: 11 passed, 3 failed, 0 pending`: `PASS surface .../topology-ir/surface/definitions.dart` and `PASS reject .../topology-ir/reject/ir_holds_no_function.dart` pass, because they use the main library alone, and `surface/graphs.dart`, `reject/ir_families_are_closed.dart` and `reject/ir_values_are_immutable.dart` fail, each opening with `uri_does_not_exist` for `package:nidana_dart_contracts/topology_ir.dart`, then the undefined names that follow from it. The routed command exits 1 with `41 fixtures: 38 passed, 3 failed, 0 pending`, the same three failures.

## Observed

Run on 2026-10-27 (`date -u +%Y-%m-%d`), the gate started at 2026-10-27T01:26:06Z and ended at 01:26:11Z, on branch `impl/nidana.model.4` at `312616e` (phase base `e27a3af`), Dart 3.13.5 through `fvm`. The checklist ran at 2026-10-27T01:26:25Z.

- The gate exited 0 (`exit: 0`). Its five lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:00 +28: All tests passed!` (12 tests in `purity_test.dart`, 7 in `declarations_test.dart`, 4 in `ir_declarations_test.dart`, 3 in `exports_test.dart`, 2 in `topology_declarations_test.dart`)
  - `57 fixtures: 57 passed, 0 failed, 0 pending` (topic-model@v1: 17 `PASS structure`, 3 `PASS surface`, 10 `PASS reject`; topology-dsl@v2: 16 `PASS structure`, 2 `PASS surface`, 9 `PASS reject`; no `FAIL`, `ERROR` or `PENDING` line)
- Checklist:
  - [x] This is the first replay of topology-dsl@v2's 2 surface and 9 reject libraries against the real package. All 11 passed: every reject code the stand-ins confirmed holds, none differs, and no line carries two codes, since a reject library passes only when its reported (line, code) pairs equal its one-code markers.
  - [x] Code that imports the main library alone cannot name a stage or obtain a plan (`plan_is_a_separate_library.dart` passes). `Topology` can be extended and not implemented, and a mutable field in a subclass is reported (`topology_is_a_base_class.dart` passes). The two public libraries export exactly the names their contracts place in them (`exports_test.dart` passes: the main library 40, `topology_plan.dart` 27). No code outside the package imports its `src/` (the first `grep` printed no line and `exit: 1`).
  - [x] topology-ir@v1's surface and reject sets, run outside the gate, exited 1 with `14 fixtures: 11 passed, 3 failed, 0 pending`. They pass `surface/definitions.dart` and `reject/ir_holds_no_function.dart` and fail only the three libraries that import `topology_ir.dart`, which nidana.model.5 lands: `surface/graphs.dart`, `reject/ir_families_are_closed.dart` and `reject/ir_values_are_immutable.dart`, on `uri_does_not_exist` and the undefined names that follow. The routed RED baseline command went from `41 fixtures: 25 passed, 16 failed, 0 pending` before this phase to `41 fixtures: 38 passed, 3 failed, 0 pending`, the same three failures.
  - [x] No stage, sink, builder or plan overrides `==` or `hashCode` (G30): the second `grep` printed no line and `exit: 1`. `purity_test.dart`, its directive reader hardened, holds the package to `meta` and `test` and to no clock, timer, microtask, id or I/O (G25, G26) and passes. The lockfile is unchanged: `git status --short pubspec.lock` printed nothing, and `git diff e27a3af HEAD -- pubspec.yaml pubspec.lock` is empty.

## Outstanding

None.

## Learnings

- The phase as first planned could not analyze: topology-ir@v1's `TopologyDefinition` names `TransformEdge` and the other IR value types, which the first plan landed at nidana.model.5. The context switch S108 found it; S109 (hsdd-phase-plan, through commit 5bbdf23) re-planned nidana.model.4 and nidana.model.5 and moved the main library's IR declarations to this phase; S110 (hsdd-reconcile) amended three Delivery paragraphs within version and the conventions' `fp-progression` sentence; S111 re-ran the switch. Disposition: spec-updated
- The purity test's directive reader (nidana.model D6) let a forbidden import through conditional imports, raw strings, percent and backslash escapes, comments inside a directive, an escaped quote before a comment marker, a `;` inside a conditional-import string and `dart:./io`. This phase closed each with a self-test; what remains, a directive not at a line start and string interpolation, is D6's own text-search limit. Disposition: dropped (D6 accepts a text search with review behind it; dart format splits same-line directives, and every commit step formats)
- topology-ir@v1's Interface prose says every value type is annotated `@immutable`, while its code blocks show no annotation; the code annotates as the prose says. Disposition: dropped (the code follows the prose; a compatible hsdd-contract touch in the end-of-node governance sweep can align the code blocks)
- No topology-dsl@v2 reject line needs two diagnostics on one line: all 9 reject libraries pass with one code per marked line, so ADR-001 item 4's one-code marker held for this contract. Disposition: dropped (topology-ir@v1's reject replay at nidana.model.5 is the remaining check)
- nidana.model D3's final field behind every getter and throwing factories leave the private constructors of `TransformEdge` and `TopologyDefinition` unused, so the package carries two more ignores of `unused_element` until nidana.model.10. Disposition: dropped (temporary; nidana.model.10 constructs through them)
- The phase scope estimated about 700 lines in about 12 files; the product diff is 1089 insertions and 51 deletions in 15 files (see Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint)

## Metrics

- Product diff, `git diff --stat e27a3af HEAD -- packages/`, where `e27a3af` is the parent of Task 1's commit: 15 files changed, 1089 insertions, 51 deletions, of which the library is 10 files and 614 lines (87 of them `///` dartdoc) and the tests 5 files and 475 insertions (`purity_test.dart` alone 267 insertions and 51 deletions), beside the estimate of about 700 lines in about 12 files; the task count is 5 of the allowed 6 (this doc is Task 5's one file).

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
