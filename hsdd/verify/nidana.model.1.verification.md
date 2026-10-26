# Verification: nidana.model.1 - Workspace root and replay tool core

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate:

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check
```

The seeded defects, which the gate's last step also runs as part of the package's suite:

```sh
fvm dart test packages/nidana_contract_check/test/cli_test.dart
```

The exit-2 path on the committed tree, which has no `surface`, `reject` or `behavior` implementation yet:

```sh
fvm dart run nidana_contract_check bus-api; echo "exit: $?"
```

The root-file check: read `pubspec.yaml` and `analysis_options.yaml` against ADR-002 items 1 and 2, then run `git ls-files '*pubspec.lock'`.

The phase produces no contract and no schema, so there is no schema replay and no fixture to reproduce.

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, the line `102 fixtures: 102 passed, 0 failed` (one `PASS structure` line per contract text, per slug fixture directory and per Dart library of the nine committed contracts, no `FAIL` line), and `All tests passed!` with the package's test count, 88.
- Each seeded defect in `cli_test.dart` exits 1 and prints exactly one `FAIL` line, naming the fixture and the rule, over the seeded `sample` slug:
  - an unlisted directory: `FAIL structure hsdd/contract/fixture/sample/extra/: layout (extra is neither a set directory of kind api nor a data directory listed in ## Validation)`
  - a reject file without a `covers` header: `FAIL structure hsdd/contract/fixture/sample/reject/sample_is_closed.dart: covers-header (no // covers: header)`
  - an uncovered guarantee: `FAIL structure hsdd/contract/fixture/sample/: coverage (G5 uncovered)`
  - a listed binding that is absent: `FAIL structure hsdd/contract/fixture/sample/behavior/sample_impl_test.dart: binding (listed in ## Validation, absent)`
  - a `src/` import: `FAIL structure hsdd/contract/fixture/sample/surface/use.dart: src-import (package:sample/src/sample_base.dart)`
- Exit 2 for a set this version does not implement (`ERROR {set} {slug}: this version of nidana_contract_check does not implement the {set} set`, after the `structure` lines) and for no workspace root (`error: no ancestor of {path} holds hsdd/contract/`).
- Exit 64 for a usage error (an unknown slug, a bare guarantee id naming no single slug), with the usage text on stderr.
- The root files as ADR-002 items 1 and 2 state them: `pubspec.yaml` with `name: nidana_workspace`, `publish_to: none`, `environment: sdk: ^3.13.0`, `dev_dependencies: lints: ^6.1.0` alone, and a `workspace:` list naming `packages/nidana_contract_check` without a glob; `analysis_options.yaml` equal to item 2's block, with no `plugins:` section; `git ls-files '*pubspec.lock'` printing `pubspec.lock` alone.

## Observed

Run on 2026-10-26 (`date -u +%Y-%m-%d`), the gate started at 2026-10-26T19:09:13Z, on branch `impl/nidana.model.1` at `d7c8beb` with a clean `packages/` tree, Dart 3.13.5 through `fvm`.

- The gate exited 0 (`exit: 0`). Its output, in order:
  - `Got dependencies!` after `Resolving dependencies...`, with the pub notice `package_config 2.2.0 (3.0.0 available)`: the constraint `package_config: ^2.2.0` of ADR-002 item 4 holds the version back, as intended.
  - `Analyzing nidana-bus-dart...` and `No issues found!`.
  - 102 `PASS structure` lines and no `FAIL` or `ERROR` line, then `102 fixtures: 102 passed, 0 failed`. Per slug: bus-api 17, bus-testing 9, flutter-binding 15, navigation-api 15, nidana-checks 2, topic-codegen 2, topic-model 17, topology-dsl 16, topology-ir 9.
  - The last line, `00:04 +88: All tests passed!`.
- The test count is 88: `cli_test.dart` 14, `structure_test.dart` 31, `request_test.dart` 14, `report_test.dart` 14, `dart_library_test.dart` 7, `contract_test.dart` 4, `ids_test.dart` 4. The task reviews added tests beyond the plan's.
- `fvm dart test packages/nidana_contract_check/test/cli_test.dart` passed all 14 tests (`00:04 +14: All tests passed!`). Its five seeded-defect tests each assert exit 1 and that the tool's stdout contains the line below, and each passed:
  - `FAIL structure hsdd/contract/fixture/sample/extra/: layout (extra is neither a set directory of kind api nor a data directory listed in ## Validation)`
  - `FAIL structure hsdd/contract/fixture/sample/reject/sample_is_closed.dart: covers-header (no // covers: header)`
  - `FAIL structure hsdd/contract/fixture/sample/: coverage (G5 uncovered)`
  - `FAIL structure hsdd/contract/fixture/sample/behavior/sample_impl_test.dart: binding (listed in ## Validation, absent)`
  - `FAIL structure hsdd/contract/fixture/sample/surface/use.dart: src-import (package:sample/src/sample_base.dart)`
- The same file passed the exit-2 test for an unimplemented set (stderr holds `ERROR surface sample: this version of nidana_contract_check does not implement the surface set`, stdout still holds `PASS structure hsdd/contract/sample.md`), the exit-2 test for no workspace root (stderr contains `no ancestor of`), the exit-64 test (stderr holds `unknown slug 'nosuch'`, `bare id 'G1'` and `usage: `), the subdirectory run, the hidden-entry run and the two symbolic-link tests.
- On the committed tree, `fvm dart run nidana_contract_check bus-api` printed the 17 `PASS structure` lines of bus-api, then `ERROR surface bus-api`, `ERROR reject bus-api` and `ERROR behavior bus-api` (each "this version of nidana_contract_check does not implement the ... set"), `17 fixtures: 17 passed, 0 failed`, and exited 2. `fvm dart run nidana_contract_check nosuch` printed `error: unknown slug 'nosuch': no directory hsdd/contract/fixture/nosuch/` and the usage text, and exited 64.
- Root files:
  - `pubspec.yaml` has `name: nidana_workspace`, `publish_to: none`, `environment: sdk: ^3.13.0`, `workspace:` with the one entry `packages/nidana_contract_check` (no glob), and `dev_dependencies: lints: ^6.1.0` as its only dependency.
  - `analysis_options.yaml` differs from the yaml block of ADR-002 item 2 in nothing (`diff` against the block is empty), and contains no `plugins:` section.
  - `git ls-files '*pubspec.lock'` printed `pubspec.lock` alone; `.gitignore` ignores a lockfile below the root, and a search of the tree outside `docs/` and `ref/` found no other `pubspec.lock`.
  - The member `packages/nidana_contract_check/pubspec.yaml` has `publish_to: none`, no `version`, `resolution: workspace`, and the constraints of ADR-002 item 4 (`args: ^2.7.0`, `json_schema: ^5.2.2`, `matcher: ^0.12.20`, `package_config: ^2.2.0`, `path: ^1.9.1`, dev `test: ^1.31.1`).

## Outstanding

None.

## Learnings

- bus-api@v2's Validation line for G13's last sentence named no node, which ADR-001 item 3 requires of both not-executable forms; the plan of this phase found it, and an inserted hsdd-contract step, S100 at commit 4d35eaf, appended `; checked by nidana.runtime's gates` as a compatible touch within v2 before the gate replayed the nine contracts. Disposition: spec-updated
- ADR-001 item 9's layout check covers only the entries directly under a slug's fixture directory, so a stray non-Dart file inside `surface/`, `reject/` or `behavior/` fails nothing. Disposition: dropped (the surface, reject and behavior sets read only Dart libraries, so a stray file there changes no replay result)
- ADR-001 is silent on symbolic links in fixture trees; this phase treats a link as a file entry, reads a `.dart` link through it, and fails a dangling one with exit 2, by a controller ruling during Task 7. Disposition: dropped (no committed fixture holds a link, and the policy is stated in shell.dart; an ADR touch can adopt it if one ever appears)
- ADR-002's Consequences say the workspace holds analyzer 14.5.0 as a transitive package, while the lockfile resolved 14.6.0 on 2026-10-26, since no member constrains analyzer yet. Disposition: dropped (a dated observation in the ADR's evidence, not a rule; ADR-002 item 4's table fixes the constraints)
- The phase plan estimated about 450 lines in about 10 files, tests included; the product diff is 3968 lines in 24 files, 2128 lines in 12 files of library and executable code, 1808 lines in 9 files of tests and 32 lines in 3 configuration files, a sizing finding for the node's remaining phases. Disposition: dropped (sizing is the owner's to revisit at a checkpoint; no later phase's scope changes)

## Metrics

- Gate failures before green: 0. The controller's ledger records no failed run of the gate command: Task 7 ran it before its commit and again at `d7c8beb` (exit 0 both times), and this task ran it once (exit 0). The analyzer step alone reported an info twice while code was being written, in the Task 5 self-review and in Task 7 on the brief's spelling of one test string (`unnecessary_brace_in_string_interps`); each was fixed before its task's commit.
- Fix rounds after task review: 2, one in Task 5 (a malformed Case row still covered its ids; eight table rows and the problem order were untested) and one in Task 7 (symbolic links dropped from the snapshot). Tasks 1 to 4 and 6 were approved without a fix round.
- Wall-clock: 1 h 22 min from the start of the implementation step (2026-10-26T17:47:24Z) to this gate (2026-10-26T19:09:13Z), for Tasks 1 to 7 with their reviews and the two fix rounds. No token figures are recorded.
- Product diff, `git diff --stat 61e2e51 HEAD -- pubspec.yaml analysis_options.yaml packages/` (phase base `61e2e51`): 24 files changed, 3968 insertions, 0 deletions. By part: library and executable 12 files, 2128 lines; tests and their seeded samples 9 files, 1808 lines; configuration 3 files, 32 lines. The generated root `pubspec.lock` adds 445 lines outside that stat. The phase estimated about 450 lines in about 10 files, tests included, so the actual is about 8.8 times the lines and 2.4 times the files; the task count is 8 of the allowed 8.
- Process artifacts (the task briefs, reports, review diffs and ledger under `.superpowers/sdd/nidana.model.1/`) are not counted in the product diff.

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
