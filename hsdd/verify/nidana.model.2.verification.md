# Verification: nidana.model.2 - Replay tool: surface, reject and schema sets

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate:

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check && fvm dart run nidana_contract_check --all --set structure,schema
```

The phase produces no contract, so there is no output to validate against a schema of its own. Its schema replay is the `schema` set over the two committed contracts that have a schema file, topology-ir@v1 and topic-codegen@v1:

```sh
fvm dart run nidana_contract_check topology-ir topic-codegen --set schema; echo "exit: $?"
```

The committed tree under the new sets, where every `surface/` and `reject/` library is still PENDING:

```sh
fvm dart run nidana_contract_check topic-model --set surface,reject; echo "exit: $?"
fvm dart run nidana_contract_check --all --set surface,reject; echo "exit: $?"
```

The seeded cases, which the gate's test step also runs as part of the package's suite:

```sh
fvm dart test packages/nidana_contract_check/test/cli_test.dart
```

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, the line `102 fixtures: 102 passed, 0 failed, 0 pending` (the `structure` set over the nine committed contracts), `All tests passed!` with the package's test count, 195, and the line `206 fixtures: 206 passed, 0 failed, 0 pending` (the same 102 `structure` fixtures and 104 `schema` fixtures: the schema file and the documents of topology-ir@v1, 46, and of topic-codegen@v1, 58). No `FAIL`, `ERROR` or `PENDING` fixture line appears.
- The schema replay over topology-ir and topic-codegen exits 0: topology-ir has 9 `PASS structure` lines and 46 `PASS schema` lines, topic-codegen 2 and 58, then `115 fixtures: 115 passed, 0 failed, 0 pending`. Both committed schemas hold as written, and every document below their `valid/` and `invalid/` directories gets the verdict its directory names.
- On the committed tree, `topic-model --set surface,reject` exits 1 with the 17 `PASS structure` lines of topic-model, 3 `PENDING surface` and 10 `PENDING reject` lines, each naming the absent package (`PENDING surface hsdd/contract/fixture/topic-model/surface/envelopes.dart: package nidana_dart_contracts is absent from .dart_tool/package_config.json`), the summary `30 fixtures: 17 passed, 0 failed, 13 pending` and an empty stderr. `--all --set surface,reject` exits 1 with the 102 `PASS structure` lines, 19 `PENDING surface` and 46 `PENDING reject` lines, `167 fixtures: 102 passed, 0 failed, 65 pending` and an empty stderr: no `dart analyze` is started, because every library of the request imports an absent package.
- `cli_test.dart` seeds a workspace with a stand-in package `sample` resolved offline, and runs the tool over it with one `dart analyze`. The run exits 1 with an empty stderr and the summary `20 fixtures: 15 passed, 4 failed, 1 pending`; its lines include the five below (four `FAIL` lines and one `PENDING` line), and the clean surface library and the two clean reject libraries print `PASS`:
  - the warning in a surface library: `FAIL surface hsdd/contract/fixture/sample/surface/dirty.dart: diagnostic (line 1: WARNING unused_import: Unused import: 'dart:async'.)`
  - the marker on the wrong line: `FAIL reject hsdd/contract/fixture/sample/reject/wrong_line.dart: missing-diagnostic (line 5: invalid_use_of_type_outside_library, named by the marker on line 4, not reported); unexpected-diagnostic (line 6: ERROR invalid_use_of_type_outside_library: The class 'Sample' can't be extended outside of its library because it's a final class.)`
  - the wrong code: `FAIL reject hsdd/contract/fixture/sample/reject/wrong_code.dart: missing-diagnostic (line 5: undefined_class, named by the marker on line 4, not reported); unexpected-diagnostic (line 5: ERROR invalid_use_of_type_outside_library: The class 'Sample' can't be extended outside of its library because it's a final class.)`
  - the extra warning: `FAIL reject hsdd/contract/fixture/sample/reject/extra_warning.dart: unexpected-diagnostic (line 8: WARNING unused_local_variable: The value of the local variable 'unused' isn't used.)`
  - the library that imports an absent package: `PENDING surface hsdd/contract/fixture/sample/surface/pending.dart: package producer is absent from .dart_tool/package_config.json`
- The producer-absent replay of `sample` (no stand-in package) prints the six `PASS structure` lines, then `PENDING surface hsdd/contract/fixture/sample/surface/use.dart: package sample is absent from .dart_tool/package_config.json` and the same for `reject/sample_is_closed.dart`, the summary `8 fixtures: 6 passed, 0 failed, 2 pending`, an empty stderr and exit 1.
- A document that is not UTF-8 below `valid/` fails as a fixture, with exit 1: `FAIL schema hsdd/contract/fixture/doc/valid/latin1.json: document (not UTF-8: Invalid UTF-8 byte (at offset 1))`.
- Exit 2 on an environment error, each with its reason on stderr:
  - no package configuration: `ERROR surface sample: no package configuration at .dart_tool/package_config.json; run fvm dart pub get`, and the same for `reject`
  - a `dart` that cannot start: `ERROR surface sample: could not run {path}: ...`
  - a `dart analyze` that prints no report: `ERROR surface sample: dart analyze exited 0 without a JSON report`
  - `--all` with no slug directory: `error: no slug directory under hsdd/contract/fixture/`
  - a symbolic link where a slug directory belongs: `error: a slug's fixture directory is a symbolic link: {path}`
  - a surface or reject library linked to a file outside `hsdd/contract/fixture/`: `ERROR surface sample: hsdd/contract/fixture/sample/surface/outside.dart is a symbolic link to {target}, outside hsdd/contract/fixture/, so dart analyze does not apply the fixture analysis options`
- Exit 64 for a usage error, with the usage text on stderr: `unknown slug 'nosuch'`, and `bare id 'G1'` when several slugs are named.

## Observed

Run on 2026-10-26 (`date -u +%Y-%m-%d`), the gate started at 2026-10-26T21:55:02Z and ended at 21:55:24Z, on branch `impl/nidana.model.2` at `cbee26d` with a clean `packages/` and `hsdd/` tree, Dart 3.13.5 through `fvm`.

- The gate exited 0 (`exit: 0`). Its output, in order:
  - `Resolving dependencies...`, `Downloading packages...`, the pub notice `package_config 2.2.0 (3.0.0 available)` (the constraint `package_config: ^2.2.0` of ADR-002 item 4 holds the version back, as intended) and `Got dependencies!`.
  - `Analyzing nidana-bus-dart...` and `No issues found!`.
  - 102 `PASS structure` lines and no other fixture line, then `102 fixtures: 102 passed, 0 failed, 0 pending`.
  - The test run, ending `00:19 +195: All tests passed!`.
  - 102 `PASS structure` and 104 `PASS schema` lines, no `FAIL`, `ERROR` or `PENDING` line, then `206 fixtures: 206 passed, 0 failed, 0 pending`.
- The test count is 195 (93 at the end of nidana.model.1): `cli_test.dart` 38, `structure_test.dart` 40, `analysis_test.dart` 17, `fixture_test.dart` 17, `report_test.dart` 16, `analyzed_sets_test.dart` 14, `request_test.dart` 14, `schema_test.dart` 11, `contract_test.dart` 8, `dart_library_test.dart` 7, `ids_test.dart` 7, `packages_test.dart` 6. A second run of the package suite with the JSON reporter, for the per-file counts, also passed all 195 and reported 19.2 s for the run.
- Each of Tasks 1 to 6 recorded its failing test output (RED) before writing code and the passing output (GREEN) after; the evidence is in the task reports under `.superpowers/sdd/nidana.model.2/`. The suite grew from 93 to 110 after Task 1 and its fix round, 118, 136 and 161 after Tasks 2 to 4, 178 after Task 5 and 184 after its fix round, and 195 after Task 6.
- The schema replay, `fvm dart run nidana_contract_check topology-ir topic-codegen --set schema`, started at 2026-10-26T21:56:40Z: `exit: 0`, 11 `PASS structure` lines (topology-ir 9, topic-codegen 2), 104 `PASS schema` lines (topology-ir 46, topic-codegen 58), `115 fixtures: 115 passed, 0 failed, 0 pending`, empty stderr.
- `fvm dart run nidana_contract_check topic-model --set surface,reject`: `exit: 1`, 17 `PASS structure`, 3 `PENDING surface` and 10 `PENDING reject` lines, all naming `nidana_dart_contracts`, `30 fixtures: 17 passed, 0 failed, 13 pending`, empty stderr.
- `fvm dart run nidana_contract_check --all --set surface,reject`: `exit: 1`, 102 `PASS structure`, 19 `PENDING surface` and 46 `PENDING reject` lines, `167 fixtures: 102 passed, 0 failed, 65 pending`, empty stderr. By slug, surface and reject: bus-api 3 and 9, bus-testing 3 and 2, flutter-binding 3 and 7, navigation-api 3 and 6, topic-model 3 and 10, topology-dsl 2 and 9, topology-ir 2 and 3. The absent packages the 65 lines name: `nidana_dart_contracts` 46 times, `nidana_dart_runtime` 24, `nidana_dart_navigation` 10, `nidana_dart_runtime_flutter` 10, `flutter` 5 (a line that lists several packages counts for each). No `FAIL` line and no `ERROR` line.
- `fvm dart test packages/nidana_contract_check/test/cli_test.dart` passed all 38 tests (`00:18 +38: All tests passed!`). Among them, the seeded surface and reject workspace gave the lines and the summary of Expected output, the producer-absent replay gave its two `PENDING` lines with exit 1, the replay through a symbolic link to the workspace root still attributed its diagnostic to `surface/dirty.dart`, and the environment cases gave each reason above with exit 2 and the usage cases exit 64.
- What the analyzer-backed tests took, from the test run's timestamps and a second run of the same suite with the JSON reporter:
  - The seeded-workspace group's `setUpAll`, which resolves the stand-in workspace with `pub get --offline` and runs the tool as a child process with its one real `dart analyze`, took 854 ms (873 ms and 1.9 s in two later runs of `cli_test.dart` alone, on 2026-10-26); its seven tests then read that one report in 1 ms or less each and finish within 3 ms of one another. The reporter stamps whole seconds: the set-up line reads `00:04` or `00:05` and the seven tests and `tearDownAll` read `00:05` or `00:06`, depending on the run.
  - The symbolic-link test, in process with a real `dart analyze`, took 180 ms, and the test that links a library to another library and to a file outside the fixtures took about 0.3 s when run alone (315 to 338 ms in three runs; run beside the file's other tests it took 261 ms once and 1.3 s once). The cases that stand in for `dart` (a `/bin/sh` script that prints a canned report, `/bin/echo`, a path that does not exist) took 55 to 70 ms each.
  - The cost of the suite is the child process, not the analyzer: the 24 tests and the one set-up of `cli_test.dart` that start the tool as a child process take 0.65 to 1.3 s each and about 18 s together, out of the 19.2 s of the whole run, and only that set-up also runs the real analyzer.
- Rehearsal of nidana.model.3's first real replay, run on 2026-10-26 (`date -u`) by the final review and reproduced at 22:21:26Z and 22:21:32Z by the final fix wave, against the experiment's stand-in `nidana_dart_contracts` and not the real package. The workspace is a scratch pub workspace outside the repository: a copy of `hsdd/` (`diff -rq` against the committed tree at `9966932` finds no difference), the repository's root `analysis_options.yaml`, and the stand-in package from `docs/auto-run/experiments/topic-model-multi-writer/packages/nidana_dart_contracts`, resolved offline. The tool is this branch's bin script, run from the workspace root by absolute path with the pinned SDK's `dart` (inside a scratch directory `fvm` finds no `.fvmrc`), as `dart run /Users/purbo/gitx/nidana-bus-dart/packages/nidana_contract_check/bin/nidana_contract_check.dart ...`:
  - `topic-model --set structure,surface,reject`: `exit: 0`, 17 `PASS structure`, 3 `PASS surface` and 10 `PASS reject` lines, `30 fixtures: 30 passed, 0 failed, 0 pending`, empty stderr, about 1 s.
  - `topic-model topology-dsl topology-ir --set structure,surface,reject,schema`: `exit: 0`, 42 `PASS structure`, 7 `PASS surface`, 22 `PASS reject` and 46 `PASS schema` lines, `117 fixtures: 117 passed, 0 failed, 0 pending`, empty stderr, about 3 s.
  - What this shows: with a package that resolves, the analyzer path attributes diagnostics to the committed libraries and their markers as the contracts wrote them, with no `FAIL` and no `PENDING` line. What it does not show: that the real `nidana_dart_contracts`, which nidana.model.3 writes, declares what the stand-in declares.
- Final fix wave, 2026-10-26T22:24:26Z to 22:24:48Z, on `9966932` (two tests renamed to state the range bound as the code applies it, names only, no assertion changed): the gate exited 0 (`exit: 0`) with the same counts, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `00:18 +195: All tests passed!` and `206 fixtures: 206 passed, 0 failed, 0 pending`, and no `FAIL`, `ERROR` or `PENDING` line.

## Outstanding

The `surface` and `reject` sets are verified here only against seeded fixtures in temporary workspaces: `cli_test.dart` resolves a stand-in package `sample` offline and runs the tool over it, and `analysis_test.dart` and `analyzed_sets_test.dart` call the pure core over in-memory snapshots. On the committed tree every `surface/` and `reject/` library is PENDING (19 and 46 of them, across seven contracts), because the package each one imports does not exist yet (ADR-001 Consequences). So no committed reject code or marker has yet been replayed against a real declaration, and no committed surface library has yet been analyzed. A rehearsal of nidana.model.3's first replay against the experiment's stand-in `nidana_dart_contracts` passed (the rehearsal bullet of Observed), but the stand-in is not the package: the real verification needs the producing packages and belongs to nidana.model.3 to .5. The first replay of each contract's libraries is the producing phase's gate:

- topic-model@v1 (3 surface and 10 reject libraries, package `nidana_dart_contracts`): nidana.model.3.
- topology-dsl@v2 (2 and 9): nidana.model.4. topology-ir@v1 (2 and 3): nidana.model.5.
- bus-api@v2, bus-testing@v2, navigation-api@v1 and flutter-binding@v2 (the other 36): the first producing phases of nidana.runtime, nidana.navigation and nidana.flutter, once `nidana_dart_runtime`, `nidana_dart_navigation`, `nidana_dart_runtime_flutter` and `flutter` resolve in the workspace.

A reject code or marker that a first replay finds wrong is a contract gap, renegotiated through hsdd-contract (ADR-001 item 8 and Consequences). Proposed disposition: deferred to nidana.model.3, the first of those gates.

## Learnings

- ADR-001 item 3's `{ids}` grammar states no bound on a range; the tool accepts a range of at most 1000 ids (`b - a < 1000`) and reads a wider one as malformed, because an unbounded range hung the replay on a typo. Disposition: dropped (the largest contract declares 42 guarantees and the widest committed range spans 35 ids, so the bound refuses only typos; an ADR-001 touch can state it if a contract ever needs more)
- package:json_schema 5.2.2 applies whatever draft a schema's `$schema` declares, so the tool refuses a root `$schema` other than exactly `https://json-schema.org/draft/2020-12/schema` to hold ADR-001 item 5's draft. Disposition: dropped (both committed schemas declare that URI; the refusal enforces the ADR rather than changing it)
- A surface or reject library linked to a file outside `hsdd/contract/fixture/` would be analyzed under the analysis options at its real location, so the tool refuses it as an environment error; ADR-001 is silent on links in fixture trees. The refusal is stated in `analysis.dart` only (`attributeDiagnostics`, rule 1); `shell.dart` maps the reason it returns to an environment error and states no policy of its own. Disposition: dropped (no committed fixture holds a link; the policy is stated in analysis.dart only and shell.dart maps its reason to an environment error)
- The phase plan estimated about 420 lines in about 8 files, tests included; the product diff is 3927 lines inserted (129 deleted) in 26 files, 1443 lines in 14 files of library code and 2484 lines in 12 files of tests, a sizing finding for the node's remaining phases. Disposition: dropped (sizing is the owner's to revisit at a checkpoint; no later phase's scope changes)

## Metrics

- Gate failures before green: 0. The controller's ledger and the task reports record no failed run of the gate command: Task 5 ran it twice, before and after its fix round (exit 0 both times; `task-5-report.md`, lines 88 and 374), Task 6 ran it (exit 0), and the run above is the fourth (exit 0).
- Fix rounds after task review: 2, one in Task 1 and one in Task 5. Task 1 (`d309842..fa638ea`): `compileSchema` let a declared `$schema` pick the draft, so a draft-07 or unknown URI validated under another keyword set, and a non-string `$schema` leaked a `TypeError`. Task 5 (`855eef2..525dcce`): a library linked outside `hsdd/contract/fixture/` was analyzed under foreign options and passed falsely, and the attribution decisions sat in the shell; the link became an environment error and the attribution moved into the pure core with in-memory tests. Tasks 2, 3, 4 and 6 were approved without a fix round.
- Wall-clock: 1 h 29 min from the start of the implementation step (2026-10-26T20:26:11Z) to this gate (2026-10-26T21:55:02Z), for Tasks 1 to 6 with their reviews and the two fix rounds. The review tier is full-review. No token figures are recorded.
- Product diff, `git diff --stat d96cf72 HEAD -- packages/` (phase base `d96cf72`, HEAD `cbee26d`): 26 files changed, 3927 insertions, 129 deletions. By part: library 14 files (`lib/fixture.dart` and 13 files under `lib/src/`), 1443 insertions, 98 deletions; tests and their seeded samples 12 files, 2484 insertions, 31 deletions. No root file, member `pubspec.yaml` or file under `hsdd/` changed. The phase estimated about 420 lines in about 8 files, tests included, so the actual is about 9.3 times the lines and 3.3 times the files; the task count is 7 of the allowed 7 (this doc is Task 7's one file).
- Process artifacts (the task briefs, reports, review diffs and ledger under `.superpowers/sdd/nidana.model.2/`) are not counted in the product diff.

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
