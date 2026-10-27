# nidana.model.7 Replay Tool: File and Cli Sets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the `file` and `cli` sets of ADR-001 items 6, 7 and 9 in `packages/nidana_contract_check`: the generator command of a contract's `- file:` bullet runs from the workspace root into a fresh empty directory, its Dart is formatted, and the tree is compared with `expected/` byte for byte; each recorded invocation runs its `args` from `files/` or the root, and its exit code, recorded streams (after the `{output}`, `{files}` and `{root}` placeholders) and the tree at `{output}` are compared; `--guarantee` admits a replay only when every id it covers is restricted; one `dart pub get --enforce-lockfile` runs before either set; a command whose package is absent is PENDING. With it land the routed tool fixes these sets need or sit beside.

**Architecture:** The pure core and imperative shell of the earlier tool phases, extended. Pure: `command.dart` reads a command (the generator span, an `args` text), names the packages it runs and builds its process; `tree.dart` compares two file trees; `file_set.dart` and `cli_set.dart` plan each replay from the snapshot (a fixture defect, not admitted, PENDING, or a run) and turn a finished run into an outcome. The shell gains `processes.dart`, the one way the tool starts a process (lenient UTF-8 output, a reason when it cannot start), and `command_runs.dart`, which runs a set's plans: temporary `{output}` directories, `dart format`, reading trees. `shell.dart` runs the one `pub get` before reading the package configuration, then dispatches the two sets.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `dart run`, `dart format` and `dart pub get --enforce-lockfile` of the running SDK; `package:package_config` (now also for package roots), `package:path`, `package:args`. No dependency is added.

**Spec:** `hsdd-context/superpowers/nidana.model.7.md` (the derivative; the generic phase context sits between its markers). Governance it links: `hsdd/spec/nidana.model.md` (phase nidana.model.7, D1, D2), `hsdd/adr/001-executable-contract-validation.md` (items 6, 7, 9 and 10, and its Consequences), `hsdd/adr/002-package-workspace-layout.md` (items 3 and 4). The code this phase extends is `packages/nidana_contract_check/` as nidana.model.6 left it (`hsdd/verify/nidana.model.6.verification.md`). The fixtures the sets meet: `hsdd/contract/fixture/topic-codegen/` (`input/`, `expected/`, 22 cases under `invocation/`) and `hsdd/contract/fixture/nidana-checks/invocation/` (17 cases), with `## Validation` of `hsdd/contract/topic-codegen.md` and `hsdd/contract/nidana-checks.md`. Evidence: `docs/auto-run/experiments/file-cli-sets-plan/`; labels such as F1 or K3 below name steps of its outputs: `output.txt` (D, S, I, F, W, P, G, A from `run.sh`), `staleness-output.txt` (K), `staleness2-output.txt` (M), `staleness3-output.txt` (N), `samples-output.txt` (Q, this plan's own samples, with `probe/replay_case.dart`, the cli set in prototype). Also cited: `docs/auto-run/experiments/replay-sets-plan/output.txt` (W0, X1, X2), `docs/auto-run/experiments/nidana-checks-ci-exit/output.txt` (A10), `docs/auto-run/experiments/topic-codegen-invocations/` and `docs/auto-run/experiments/file-invocations/replay.dart` (the prototypes the governance cites).

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 8 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.7.verification.md from
   hsdd/templates/verification.md at full-review depth, fills every section
   the template asks for at that depth, writes "- none" or dispositioned
   entries under Learnings, and leaves Sign-off for a human reviewer.
6. Nothing under hsdd/ changes except that verification doc. Contracts, ADRs,
   specs and conventions change only through hsdd-contract, hsdd-adr and
   hsdd-reconcile.
7. Build against the Interface and Guarantees in the Contracts section below
   (if any), never against another node's internals.
8. Review tier full-review: design rationale for every non-obvious choice; full verification doc.

Project-wide requirements from the spec and the run, which every task's requirements include:

- Toolchain: `fvm dart` only, every command from the repository root, no global tooling. Inside a temporary directory `fvm` runs no `dart` (D2, `replay-sets-plan` W0), so the tool and the tests start the SDK's `dart` as `Platform.resolvedExecutable`, which under `fvm dart run` and `fvm dart test` is `~/fvm/versions/3.47.7/bin/cache/dart-sdk/bin/dart` (D1, X1).
- No real flutter, ever. The pinned Flutter SDK has no engine artifacts, and fetching them is a network action outside the run rules. No test and no step starts the real `flutter`: a seeded case whose command is `flutter` runs only through `runCli(..., dart: standInSdk().dart)` or `plainDart()` (`test/support/runners.dart`), never through `runTool` and never with `dart: null`. No committed case runs `flutter`.
- Files: nothing outside `packages/nidana_contract_check/` changes, except the verification doc in Task 8. No root file, member `pubspec.yaml` or lockfile changes, and no package is added (ADR-002 items 3 and 4; plugin keys are read without `package:yaml`, decision 11).
- Pure core, imperative shell (nidana.model D2 item 5): the libraries under `lib/src/` that import `dart:io`, read a file or start a process are exactly `runners.dart`, `shell.dart` and `workspace.dart`, plus `processes.dart` from Task 5 and `command_runs.dart` from Task 6; `test/purity_test.dart` pins the list. Values are immutable: final fields, collections built once and never mutated. Alternatives are sealed classes or enums, matched by exhaustive `switch`.
- Tests: the pure core by direct calls over in-memory snapshots (`snapshotOf`) and plain values; the shell by `runCli` in process or by the bin script (`runTool`). A seeded fixture, contract text or stand-in package is a string in test code, never a `.dart` file in the package. A test that runs a generator seeds a temporary workspace with `seedWorkspace(files, standIn: false, generator: true)` (Task 6): no hosted dependency, resolved offline in about 0.1 s (W1), and the tool's `pub get --enforce-lockfile` there needs no network (P2).
- Output (ADR-001 item 9): one line per fixture on stdout, `PASS`, `FAIL` or `PENDING`, the set, the path from the workspace root; `ERROR {set} {slug}: {reason}` on stderr for a set that could not run; on stderr one progress line before `pub get` and before each generator or command run; one summary line; exit 0, 1, 2 or 64 (nidana.model D2 item 1).
- Contract gaps (ADR-001 item 8): every committed `file/` and `cli` fixture was checked against this plan's rules while planning, and none is rejected. One gap in the governance's premise was found and is handled by decision 1 (reported in `docs/auto-run/steps/S121.json`). A committed contract, fixture or recording that a rule as written rejects is never edited: stop at the task boundary and report BLOCKED with the file, the rule and the fix you would propose.
- Formatting and tests: run `fvm dart format` on every Dart file the task creates or changes before committing. Add tests beyond a step's wherever a rule would otherwise go unpinned. The lockfile holds `test` 1.33.0; no test uses a `test` API newer than 1.31.1.
- Prose and commits follow the run rules: no em-dash character in any comment, dartdoc or commit message, and never the phrase the run rules ban; stage explicit paths; conventional subjects (`feat(contract_check): ...`); the commit body ends with `Co-Authored-By: {model} <noreply@anthropic.com>`, where `{model}` names the model that wrote the commit, for example `Claude Sonnet 5.5`.

## Review Focus

The input classes the spec implies but its own Verification does not exercise, most likely to bite first; each has its test in the owning task.

1. **A workspace whose resolution reads stale by pub's mtime rule**, as this repository's does today (M5): every `{package}:{executable}` case with `files/` must still run, never exit 255 on `Could not find a file named "pubspec.yaml"`. Test: Task 7 (`a workspace whose resolution reads stale still runs every case`).
2. **Paths that reach a command or its output through a symbolic link** (macOS `/var` and `/private/var`, a linked checkout): both forms of `{output}`, `{files}` and `{root}` become placeholders, the longer form first. Tests: Task 4 (`withPlaceholders`), Task 7 (the clean cases, whose recordings name the resolved root, `files/` and `{output}`; `from a symbolic link to the workspace root`).
3. **Hidden entries** in `expected/` or in what a generator writes: part of the byte-for-byte comparison, unlike the snapshot (routed from S101). Tests: Task 6 (`a hidden file in expected/ is part of the comparison`; `readTree`).
4. **A command the replay cannot start**, or one that needs a flutter the SDK lacks: an environment error for the slug's set (exit 2), never a FAIL that reads as the case's exit code. Tests: Task 5 (`runProcess` of a missing executable), Task 7 (`flutter runs as the flutter beside the running dart, and its absence is an environment error`).
5. **Bytes that are not UTF-8**, in a command's output or in a recording: the replay neither crashes nor passes them silently. Tests: Task 5 (`runProcess decodes output that is not UTF-8 leniently`), Task 4 (`fixture defects fail the case`).

## Design decisions

The rationale for each non-obvious choice. Each is a decision in `docs/auto-run/steps/S121.json` with its options and evidence.

1. **`{package}:{executable}` runs as its script under the running dart.** A recorded invocation whose command is `{package}:{executable}` runs `{dart} --packages={root}/.dart_tool/package_config.json {package root}/bin/{executable}.dart {arguments}` from its working directory, the package root read from the package configuration. `dart run {package}:{executable}` from a directory with no `pubspec.yaml` exits 255 (`Could not find a file named "pubspec.yaml" in ...`) whenever pub's mtime check reads the resolution as stale, which it does unless every `pubspec.yaml` is no newer than `pubspec.lock` and `pubspec.lock` no newer than `.dart_tool/package_config.json` (K1, K2, K5, K7, M3, M4); neither `dart pub get` nor `dart pub get --enforce-lockfile` rewrites either file when the resolution is unchanged (K3, K4, K6, M1, M2), so the one `pub get` ADR-001 item 9 gives cannot cure it, and this repository reads stale now (M5: `dart run nidana_contract_check` from `scan-clean/files/` exits 255). Twelve committed cases are of this form (four of topic-codegen@v1, eight `scan-*` of nidana-checks@v1). The script form starts on a stale workspace (N2 to N5), prints exactly what `dart run` prints (N7) in the same time (N8; `dart run` compiles a workspace member's executable from source on every run and prints nothing of its own, G1, G2), and a script the package lacks exits 254 (N6). ADR-001 item 7 names the command, not how it runs. The governance's reason for the `pub get` is reported as a contract gap; `pub get` still runs, as item 9 requires (decision 15).
2. **The file replay runs its command as written**, the leading `fvm dart` or `dart` replaced by the running dart: `{dart} run nidana_dart_codegen:generate ...` from the root, where `dart run` re-resolves a stale workspace silently and runs (G4, K5, M4).
3. **The generator command** is the one backticked span of the `- file:` bullets that holds `{output}` and a space. Read literally, "the span that holds `{output}`" names three spans of topic-codegen@v1's bullet, the command and `{output}` alone twice; a command has a program and an argument. No such span, or more than one, fails the replay with a `command` problem. Words are split at spaces; no committed span needs quoting.
4. **Substitution.** File set: `{input}` becomes the absolute path of the slug's `input/` and `{output}` the absolute path `{t}/output` of an empty directory created in a fresh temporary `{t}`, wherever either occurs in a word (`{input}/topics.yaml`). Cli set: an argument that is exactly `{output}` becomes `{t}/output`, at which nothing exists (ADR-001 item 7, "An argument `{output}`").
5. **Formatting.** `{dart} format {output}` from the root, for the file replay and for a recorded invocation with `expected/` (ADR-001 item 7: "as item 6 compares"; the prototype formats too). It formats `.dart` files only, recursively, skipping hidden files and directories (F1); it exits 0 whether or not it changed a file, for an empty directory and for an absent path (F1, F2), and 65 when a file does not parse, still formatting the others (F3); outside any package it formats at the SDK's language version, the tall style, as at the workspace root (F4). A non-zero exit is a `format` problem: the generator wrote Dart that does not parse.
6. **A generator that exits non-zero fails the file replay** (`exit` problem) beside the tree comparison. ADR-001 item 6 says the replay runs the command; topic-codegen@v1 G3 has `generate` write the tree, and a tree written by a failed run is not that.
7. **Trees** are every file below the root, hidden ones included (routed from S101), by `/`-separated relative path, each as bytes; a symbolic link is read through, as `readSnapshot` reads one; directories are not compared (git commits no empty directory); a path that is no directory reads as the empty tree. Problems come by ascending path: `missing-file`, `extra-file`, `changed-file` with the offset of the first differing byte.
8. **Streams.** A recorded `stdout` or `stderr` is read strictly as UTF-8 (one that is not is a `recording` defect of the case, which then does not run); a process's output is decoded leniently (`processes.dart`). After the placeholders the two texts compare exactly; the detail names the first differing line, JSON-quoted, or `end of output`. When the exit code differs and the case records no stderr, the `exit` detail carries the first stderr line, so a gate shows why (`exited 255, expected 1: Could not find ...`).
9. **Placeholders**: `{output}`, then `{files}`, then `{root}` (ADR-001 item 7's order), each in its given and its symlink-resolved form, the longer form first. On macOS one contains the other (`/var/...` inside `/private/var/...`), and replacing the shorter first leaves `/private{output}` (S2). A child reads its working directory resolved (S2) and `dart analyze --format=machine` prints resolved paths (A1), so both forms occur. The given forms are the `{output}` argument, the `files/` path under the root as found and the root as found; the resolved form of `{output}` is its temporary directory resolved, then `/output`, because `{output}` may not exist after the run.
10. **`args` and `exit_code`.** `args` is split at `\n`, a final empty line dropped, every other line one argument as written (an empty line is an empty argument); its first line is `dart`, `flutter` or `{package}:{executable}`, `{package}` matching `[a-z_][a-z0-9_]*` and `{executable}` holding no space, `:` or `/`. `exit_code` is a decimal from 0 to 255 with no leading zero and an optional final newline (every committed one is `{n}\n`). Anything else, or a missing file, fails the case before it runs (`command`, `exit-code`); structure does not check these files.
11. **The packages a command runs** (PENDING, ADR-001 item 9): a `{package}:{executable}` command's package; for `dart run`, the package of its target, the first argument after `run` that does not start with `-`, when it reads `{package}` or `{package}:{executable}`; and for a recorded invocation, each plugin its `files/analysis_options.yaml` enables, the keys of its top-level `plugins:` section. ADR-001 item 7 has a case that needs the plugin enable it there, and `dart analyze` runs the plugin. Without it nidana-checks@v1's eight `analyze-*` cases would run and fail on the exit `dart analyze` gives for a plugin that does not resolve (`nidana-checks-ci-exit` A10: 4), not be PENDING as the phase Verification requires. The keys are read by hand: no `package:yaml` in the tool's row of ADR-002 item 3.
12. **The order of a replay's verdicts:** a fixture defect fails; then a restriction that does not admit it passes it unrun; then an absent package makes it PENDING; otherwise it runs. The restriction comes before PENDING here, unlike the behavior set (nidana.model.6 decision 5), because a `file` or `cli` contract may have several producing leaf-parents whose gates restrict to their own shares (ADR-001 item 10), and "no producer waits on another" (ADR-001 Consequences). nidana-checks@v1 is such a contract: nidana.tooling.lint.1 to .3 gate on `nidana-checks --guarantee G1` and nidana.tooling.codegen.9 on `--guarantee G3,G9,...,G17`; with PENDING first, each would fail on the other producer's cases until its package exists. Item 9 says a replay the restriction admits no case of "is not run and counts as passing". An unrestricted replay reports every case whose package is absent as PENDING, as the phase Verification requires. A defect still fails when not admitted: a contract gap is loud at every gate.
13. **Admission:** unrestricted, or the replay's declared ids are not empty and each is a restriction id of its slug (ADR-001 item 9). A file replay's ids are its `- file:` bullets' covers clauses; a recorded invocation's are the Covers cell of its Case-table row. One that declares none runs only unrestricted ("a slug with no id of its own in the restriction runs none of them"). Detail: `not run: the restriction does not admit all of {ids}`, or `not run: it covers no declared guarantee, and the replay is restricted`.
14. **Fixture paths in lines:** a file replay is `hsdd/contract/fixture/{slug}/expected/`, the tree it compares; a recorded invocation is `hsdd/contract/fixture/{slug}/invocation/{case}/`. One line each, invocations by ascending case name.
15. **One `pub get` per replay.** When any plan holds `file` or `cli`, the shell writes `running dart pub get --enforce-lockfile` to stderr and runs `{dart} pub get --enforce-lockfile` from the root, before it reads the package configuration, which `pub get` may rewrite. A non-zero exit or a process that cannot start makes every `file` and `cli` set of the replay `SetUnavailable` with the reason (exit 2); the other sets still run and print, as they do when the analysis fails. Facts: on success it prints three lines to stdout and exits 0, with no network needed when nothing is hosted (P1, P2); a lockfile that lacks a dependency exits 65 with ``Unable to satisfy `pubspec.yaml` using `pubspec.lock`.`` first on stderr (P3); no lockfile exits 1 with `Retrieving dependencies failed.` first (P4).
16. **`flutter`** runs as the flutter of the Flutter SDK that holds the running dart (`flutterBeside`, as the behavior set uses it). A case that needs one when there is none makes the slug's cli set unavailable before any of its cases starts (nidana.model.6 decision 12).
17. **No process timeout.** ADR-001 requires none, and no runner has one. `Process.run` gives a child an end of input on stdin (I1), so a command waiting for input cannot hang the gate; a timeout's value, and whether it is FAIL or ERROR, would need a governance home. Left routed (Routed items).
18. **Two new shell libraries.** `processes.dart` is the one way the tool starts a process: `runProcess` decodes stdout and stderr with `lenientUtf8` (moved there from `runners.dart`) and turns a `ProcessException` into a reason; the analysis, the behavior runners, `pub get` and both new sets use it (routed). `command_runs.dart` runs the file and cli sets and reads trees; `runners.dart` stays the behavior runner. `purity_test.dart` pins the five `dart:io` libraries, follows `package:nidana_contract_check/` self-imports, and checks that no pure library reaches a `dart:io` one (routed).
19. **A suite slug is read as its suite files alone** (routed from S119). The shell reads, for another slug whose conformance library a binding imports, only those files, into a snapshot that holds them alone, so the planner is unchanged. A read defect elsewhere in that slug's tree no longer ends the replay; an absent or dangling suite file fails its binding as `suite ({path} does not exist)`. Before this phase such a defect ended the whole replay with exit 2 and no fixture line for any slug (nidana.model.6's verification doc said it ended the replayed slug's replay).
20. **A contract text that is not UTF-8** is a structure `contract-text` failure (exit 1), decoded by `decodeSource` as Dart sources are, where it was an environment error (exit 2) while an absent one was a structure failure (routed from S119). The restriction check reads its ids from a lenient decoding, so a restricted replay of that slug still reaches structure.
21. **`notImplemented` goes** once every set is implemented (Task 7): no `_run` branch returns it.
22. **The tests drive a stand-in generator package `gen`** in a seeded workspace. Its `generate` writes an unformatted `out.dart` and `notes.txt`, prints where it wrote and its working directory, exits 2 on a usage error writing nothing, and with `--write-then-fail` writes and exits 1. The seeded `gen` contract and cases pass structure as the tool stands (Q2), and a prototype of this plan's cli set passes every case on a fresh and on a stale workspace and fails each seeded defect (Q3 to Q6).

## Routed items

From `docs/auto-run/impl-execution-plan.md`, "Routed to later phases", the entries naming nidana.model.7 and "Later tool phases", one line each with its disposition:

- `_snapshotsOf` reads a suite slug's whole snapshot, so a read defect in another slug's tree ends a behavior replay with exit 2 and no fixture line (S119): taken, Task 1 (decision 19); this phase's verification doc states the corrected behavior and the understatement in nidana.model.6's.
- `purity_test` pins direct `dart:io` imports only, and `relativeClosure` ignores own-package `package:` self-imports (S119): taken, Task 5, with this phase's two new process libraries (decision 18).
- `lenientUtf8` lives in `runners.dart` though every process uses it (S119): taken, Task 5, into `processes.dart` with `runProcess`, which every process the tool starts goes through (decision 18).
- A contract text that is not UTF-8 exits 2 while an absent one is a structure failure (S119): taken, Task 1 (decision 20).
- `readSnapshot`'s hidden-entry filter must not leak into the byte-for-byte comparisons of `expected/` and `invocation/*/expected/` (S101): taken, Tasks 6 and 7: trees are read by `readTree`, never from the snapshot, hidden entries included (decision 7).
- A process timeout for generator and command runs (S119, Later tool phases): weighed, not taken; left routed to the first gate that runs a suite with timers or isolates (nidana.runtime). ADR-001 requires none, a child's stdin is at end of input (I1) so waiting for input cannot hang, and a timeout's value and outcome class need a governance home (decision 17).
- The checkpoint note (nidana.model.1, .2 and .6 landed 9 to 13 times their line estimate): this phase's estimate is about 450 lines; this plan's file map comes to about 3,500 to 4,500 lines (about 1,400 library, 2,500 tests), 8 to 10 times it. The size is recorded in the step report and the verification doc's Metrics, for the owner's checkpoint.

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_contract_check`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/snapshot.dart` | 1 | `SlugSnapshot.contractUndecodable`, `SlugSnapshot.records`, `holdsRecord` |
| `{pkg}/lib/src/behavior.dart` | 1 | `suitePaths` in place of `suiteSlugs` |
| `{pkg}/lib/src/structure.dart` | 1 | A contract text that is not UTF-8 |
| `{pkg}/lib/src/contract.dart` | 2 | `ContractText.generatorCommands` |
| `{pkg}/lib/src/command.dart` | 2 | Commands read, their packages, their processes; `CommandRule`, `ProcessExit` |
| `{pkg}/lib/src/tree.dart` | 3 | `FileTree`, `treeProblems` |
| `{pkg}/lib/src/run.dart` | 3, 5 | `admitsAll`, `notAdmitted`, `runsCommands`, `pubGetFailure`; `readsPackages` for file and cli |
| `{pkg}/lib/src/file_set.dart` | 3 | The file replay's plan and outcome |
| `{pkg}/lib/src/cli_set.dart` | 4 | The recorded invocations' plans, placeholders and outcomes |
| `{pkg}/lib/src/processes.dart` | 5 | `lenientUtf8`, `runProcess` (`dart:io`) |
| `{pkg}/lib/src/packages.dart` | 5 | `packageRootsOf` |
| `{pkg}/lib/src/report.dart` | 3, 7 | `firstTextLine`; `notImplemented` removed |
| `{pkg}/lib/src/analysis.dart`, `test_report.dart`, `runners.dart` | 5 | `firstTextLine`; the runner through `runProcess` |
| `{pkg}/lib/src/command_runs.dart` | 6, 7 | `readTree`, `runFileSet`, `runCliSet` (`dart:io`) |
| `{pkg}/lib/src/shell.dart` | 1, 5, 6, 7 | Snapshot reads, suites alone, `pub get`, the package roots, the two sets' dispatch |
| `{pkg}/test/support/sample.dart` | 1 | `snapshotOf` decodes the contract text and keeps records |
| `{pkg}/test/support/generator.dart` | 2, 3, 6 | `commandText`; the `gen` contract and fixture tree; the stand-in generator's source |
| `{pkg}/test/support/workspace.dart`, `runners.dart` | 5, 6 | `seedWorkspace(..., generator: true)`; `recordingDart` |
| `{pkg}/test/command_test.dart`, `tree_test.dart`, `file_set_test.dart`, `cli_set_test.dart`, `processes_test.dart`, `command_runs_test.dart` | 2 to 7 | New tests |
| `{pkg}/test/structure_test.dart`, `cli_test.dart`, `behavior_test.dart`, `contract_test.dart`, `report_test.dart`, `packages_test.dart`, `purity_test.dart` | 1 to 7 | Extended tests |
| `hsdd/verify/nidana.model.7.verification.md` | 8 | The verification doc |

---

### Task 1: Snapshot reads: recorded invocations, contract texts and suites alone

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9), in the pub workspace at the repository root. Run every command from the repository root with `fvm dart`. This task changes what the shell reads into a `SlugSnapshot`: the bytes of each recorded invocation's `args`, `exit_code`, `stdout`, `stderr` and `files/analysis_options.yaml` (Task 4 plans from them); a contract text decoded strictly, so one that is not UTF-8 is a structure failure (decision 20); and, for another slug whose conformance library a binding imports, the suite files alone (decision 19). The file and cli sets stay `notImplemented` in this task.

**Files:**
- Modify: `packages/nidana_contract_check/lib/src/snapshot.dart`, `lib/src/behavior.dart`, `lib/src/structure.dart`, `lib/src/shell.dart`
- Modify: `packages/nidana_contract_check/test/support/sample.dart` (`snapshotOf`)
- Test: `packages/nidana_contract_check/test/structure_test.dart`, `test/behavior_test.dart`, `test/cli_test.dart`

**Interfaces:**
- Consumes: `SlugSnapshot`, `decodeSource`, `SourceText`, `SourceNotUtf8`, `holdsSource`, `fixtureDirectory`, `contractPath` (`snapshot.dart`); `planBindings`, `suiteSlugs` (`behavior.dart`); `checkStructure`, `StructureRule.contractText` (`structure.dart`); `readSnapshot`, `_declaredBy`, `_snapshotsOf`, `discoverSlugs`, `lenientUtf8` (still in `runners.dart` until Task 5); test support `snapshotOf`, `seed`, `seedWorkspace`, `runTool`, `sampleFiles`, `sampleContract`, `toolFiles`, `behaviorFiles`, `hostFiles`, and `lines` and `all` in `cli_test.dart`.
- Produces:

```dart
// lib/src/snapshot.dart
final class SlugSnapshot {
  const SlugSnapshot({
    required this.slug,
    required this.contractText,
    required this.schemaBytes,
    required this.directories,
    required this.files,
    required this.documents,
    this.undecodable = const <String, String>{},
    this.contractUndecodable,
    this.records = const <String, List<int>>{},
  });
  /// Why the contract text is not UTF-8, as [decodeSource] words it; null when it is UTF-8 or
  /// absent. [contractText] is null when this is not.
  final String? contractUndecodable;
  /// Each file [holdsRecord] accepts, by its relative `/`-separated path, as read.
  final Map<String, List<int>> records;
  // the other fields as they are
}
/// Whether the shell reads a file's bytes as part of a recorded invocation (ADR-001 item 7):
/// `invocation/{case}/args`, `exit_code`, `stdout` or `stderr`, or
/// `invocation/{case}/files/analysis_options.yaml`, by its `/`-separated path relative to its
/// slug's fixture directory.
bool holdsRecord(String relativePath);

// lib/src/behavior.dart (replaces suiteSlugs)
/// The paths from the workspace root of the conformance libraries the bindings of [snapshot]
/// import, another slug's included; a binding whose source was not read contributes none.
Set<String> suitePaths(SlugSnapshot snapshot);
```

- [ ] **Step 1: Write the failing tests**

In `test/structure_test.dart`, beside the `isBindingPath` test:

```dart
  test('holdsRecord accepts a recorded invocation\'s four files and its files/analysis_options.yaml alone', () {
    for (final String path in <String>[
      'invocation/c/args',
      'invocation/c/exit_code',
      'invocation/c/stdout',
      'invocation/c/stderr',
      'invocation/c/files/analysis_options.yaml',
    ]) {
      expect(holdsRecord(path), isTrue, reason: path);
    }
    for (final String path in <String>[
      'invocation/args',
      'invocation/c/args.txt',
      'invocation/c/files/args',
      'invocation/c/expected/stdout',
      'invocation/c/files/lib/analysis_options.yaml',
      'input/args',
    ]) {
      expect(holdsRecord(path), isFalse, reason: path);
    }
  });
  test('a contract text that is not UTF-8 fails at its path, alone', () {
    final List<FixtureOutcome> o = checkStructure(
      snapshotOf('sample', sampleFiles, bytes: <String, List<int>>{
        'hsdd/contract/sample.md': <int>[0xff, ...utf8.encode(sampleContract)],
      }),
    );
    expect(o.map((FixtureOutcome x) => outcomeLine(CheckSet.structure, x)), <String>[
      'FAIL structure hsdd/contract/sample.md: contract-text (not UTF-8: Invalid UTF-8 byte (at offset 0))',
    ]);
  });
```

In `test/behavior_test.dart`, the `suiteSlugs` test becomes `suitePaths names the suite files the bindings import, another slug's included`: `suitePaths(host)` and `suitePaths(sample)` are each `{'hsdd/contract/fixture/sample/behavior/sample_conformance.dart'}`, and `suitePaths` of the host snapshot whose binding is the bytes `[0xff]` is empty.

In `test/cli_test.dart` (`const String t = 'hsdd/contract/fixture/tool/';` and `h = 'hsdd/contract/fixture/host/'` at the top):

1. `readSnapshot keeps the bytes of a recorded invocation's files and no other's`: `root = seed({...toolFiles, '${t}invocation/generate-usage/stdout': 'out\n', '${t}invocation/generate-usage/stderr': 'err\n', '${t}invocation/generate-usage/files/analysis_options.yaml': 'plugins:\n', '${t}invocation/generate-usage/files/in.txt': 'x\n', '${t}invocation/generate-usage/expected/out.txt': 'y\n'})`; `readSnapshot(root, 'tool').records.keys` equals `{'invocation/generate-usage/args', 'invocation/generate-usage/exit_code', 'invocation/generate-usage/stdout', 'invocation/generate-usage/stderr', 'invocation/generate-usage/files/analysis_options.yaml'}`, and `utf8.decode(records['invocation/generate-usage/args']!)` is `'tool:generate\n--frob\n'`.
2. `a contract text that is not UTF-8 fails structure (1), and a restriction still reads its ids`: `root = seed(sampleFiles)`, then `File('${root.path}/hsdd/contract/sample.md').writeAsBytesSync([0xff, ...utf8.encode(sampleContract)])`. `runTool(['sample', '--set', 'structure'])` exits 1 with `lines(r)` exactly `['FAIL structure hsdd/contract/sample.md: contract-text (not UTF-8: Invalid UTF-8 byte (at offset 0))', '1 fixture: 0 passed, 1 failed, 0 pending']`; with `'--guarantee', 'G1'` added it exits 1 with the same lines.
3. `a read defect in another slug's tree outside its suite stops no binding's replay`: `root = await seedWorkspace({...behaviorFiles, ...hostFiles})` (no runners, so the bindings are PENDING and no runner starts); `Link('${root.path}/hsdd/contract/fixture/sample/surface/broken.dart').createSync('${root.path}/nowhere.dart')`. `runTool(['host', '--set', 'behavior'])` exits 1, its stderr holds no `error:`, and `lines(r)` contains `'PENDING behavior ${h}behavior/host_impl_test.dart: packages matcher, nidana_contract_check, test are absent from .dart_tool/package_config.json'`.
4. `a suite file that is a dangling link fails its binding, not the replay`: the same seeding; delete `hsdd/contract/fixture/sample/behavior/sample_conformance.dart` and create a `Link` there to `${root.path}/nowhere.dart`. `runTool(['host', '--set', 'behavior'])` exits 1 and `lines(r)` contains `'FAIL behavior ${h}behavior/host_impl_test.dart: suite (hsdd/contract/fixture/sample/behavior/sample_conformance.dart does not exist)'`.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/structure_test.dart packages/nidana_contract_check/test/behavior_test.dart packages/nidana_contract_check/test/cli_test.dart`
Expected: FAIL: compile errors (`holdsRecord`, `suitePaths` and `records` are undefined); once stubbed, tests 2 to 4 exit 2 with an `error:` line where they expect 1. Keep the output.

- [ ] **Step 3: Implement**

- `snapshot.dart`: the two fields and `holdsRecord` (a pattern over the relative path: `invocation/{one segment}/` then `args`, `exit_code`, `stdout`, `stderr` or `files/analysis_options.yaml`).
- `shell.dart`, `readSnapshot`: the contract text is read as bytes and decoded by `decodeSource`, its text or its reason going to `contractText` or `contractUndecodable`; every non-hidden file entry that `holdsRecord` accepts goes to `records` as bytes, read as sources are (through a link). `_declaredBy` decodes the contract text with `lenientUtf8`.
- `shell.dart`, `_snapshotsOf`: for each path of `suitePaths(plan.snapshot)` of each plan holding `behavior` whose slug (its fourth segment) `discovered` holds and the request does not, read that file alone: one snapshot per such slug, ascending, with `contractText` and `schemaBytes` null, no directories and no documents, and in `files` and `undecodable` each suite file that `File(...).existsSync()` finds (false for an absent file and for a dangling link), decoded by `decodeSource`. The planner reads a suite from that snapshot as before, and one it lacks fails as `suite ({path} does not exist)`. Update `planBindings`' dartdoc: `snapshots` holds, for each other slug whose suites the bindings import, a snapshot holding at least those suite files.
- `structure.dart`: with no contract text, the one outcome is `contract-text ({contractUndecodable})` when that is set, else `contract-text (no contract text at {path})` as now.
- `test/support/sample.dart`, `snapshotOf`: the contract text through `decodeSource`, setting `contractText` or `contractUndecodable`, and `records` from every path below the fixture directory that `holdsRecord` accepts.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/snapshot.dart packages/nidana_contract_check/lib/src/behavior.dart packages/nidana_contract_check/lib/src/structure.dart packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/test/support/sample.dart packages/nidana_contract_check/test/structure_test.dart packages/nidana_contract_check/test/behavior_test.dart packages/nidana_contract_check/test/cli_test.dart
git commit -m "feat(contract_check): read recorded invocations, strict contract texts and suites alone" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 2: Commands: the generator span, args, packages and processes

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. This task adds the pure reading of the commands the file and cli sets run (ADR-001 items 6 and 7): the generator command of a `- file:` bullet, the command of an `args` text, the packages a command runs (for PENDING, decision 11) and the process that runs it (decision 1). Nothing runs yet.

**Files:**
- Create: `packages/nidana_contract_check/lib/src/command.dart`
- Modify: `packages/nidana_contract_check/lib/src/contract.dart`
- Create: `packages/nidana_contract_check/test/support/generator.dart` (`commandText`; Task 3 adds the `gen` sample)
- Test: `packages/nidana_contract_check/test/command_test.dart` (new), `test/contract_test.dart`

**Interfaces:**
- Consumes: `readContract`, `ContractText` (`contract.dart`); `Rule` (`outcome.dart`).
- Produces:

```dart
// lib/src/contract.dart, in ContractText (readContract fills it)
/// The backticked spans of the `- file:` bullets that hold `{output}` and a space, in order:
/// the generator commands they name (ADR-001 item 6).
final List<String> generatorCommands;

// lib/src/command.dart (pure; imports outcome.dart)
/// The rules of the sets that run commands, `file` and `cli`.
enum CommandRule implements Rule {
  command('command'), exitCode('exit-code'), recording('recording'), exit('exit'),
  stdout('stdout'), stderr('stderr'), format('format'), missingFile('missing-file'),
  extraFile('extra-file'), changedFile('changed-file'), output('output');
}
/// How a process ended: its exit [code] and its output, decoded.
typedef ProcessExit = ({int code, String stdout, String stderr});
/// A command a file replay or a recorded invocation runs (ADR-001 items 6 and 7).
sealed class Command { const Command(this.arguments); final List<String> arguments; }
/// `dart` [arguments]: the dart that runs the tool runs them.
final class DartCommand extends Command { const DartCommand(super.arguments); }
/// `flutter` [arguments]: the flutter of the Flutter SDK that holds the running dart runs them.
final class FlutterCommand extends Command { const FlutterCommand(super.arguments); }
/// `{package}:{executable}` [arguments].
final class PackageCommand extends Command {
  const PackageCommand(this.package, this.executable, super.arguments);
  final String package;
  final String executable;
}
/// A command read: [CommandRead], or [CommandUnreadable] with the reason.
sealed class CommandReading { const CommandReading(); }
final class CommandRead extends CommandReading { const CommandRead(this.command); final Command command; }
final class CommandUnreadable extends CommandReading { const CommandUnreadable(this.reason); final String reason; }
/// The one generator command of [commands], [ContractText.generatorCommands]: its words after
/// a leading `fvm dart` or `dart`, as a DartCommand.
CommandReading readGeneratorCommand(List<String> commands);
/// The command of a recorded invocation's `args` [text] (decision 10).
CommandReading readArgs(String text);
/// The packages [command] runs (decision 11): a PackageCommand's package; for a DartCommand
/// whose first argument is `run`, the package of the first later argument that does not start
/// with `-`, when it reads `{package}` or `{package}:{executable}`; none otherwise.
Set<String> commandPackages(Command command);
/// The plugin packages [analysisOptions] enables: the keys of its top-level `plugins:` section.
Set<String> pluginPackages(String analysisOptions);
/// [command] with each argument that is exactly `{output}` replaced by [output], its kind,
/// package and executable kept (ADR-001 item 7).
Command withOutput(Command command, String output);
/// The executable and arguments of a process.
typedef CommandProcess = ({String executable, List<String> arguments});
/// The process that runs [command] (decision 1): [dart] with its arguments for a DartCommand;
/// [flutter] with them for a FlutterCommand; for a PackageCommand, [dart] with
/// `--packages={packageConfig}`, the file path of `bin/{executable}.dart` below the package's
/// root in [roots], then its arguments. Null for a FlutterCommand when [flutter] is null and
/// for a PackageCommand whose package [roots] lacks.
CommandProcess? processOf(
  Command command, {
  required String dart,
  required String? flutter,
  required String packageConfig,
  required Map<String, Uri> roots,
});
```

- [ ] **Step 1: Write the failing tests**

In `test/contract_test.dart`:

1. `generatorCommands holds the spans of - file: bullets that hold {output} and a space`: a contract whose `## Validation` has the bullet ``- file: `hsdd/contract/fixture/gen/input/` holds `word.txt`; the replay runs `fvm dart run gen:generate {input}/word.txt {output}`, formats the Dart in `{output}` and compares `{output}/a` with `expected/`.``, a second bullet ``- file: then `dart run gen:other {output}`.`` and a bullet ``- schema: `dart run x {output}`.`` reads `generatorCommands` as `['fvm dart run gen:generate {input}/word.txt {output}', 'dart run gen:other {output}']`.
2. `the committed topic-codegen text names one generator command`: from the workspace root (`findWorkspaceRoot(Directory.current)`), `readContract('topic-codegen', File('{root}/hsdd/contract/topic-codegen.md').readAsStringSync()).generatorCommands` is `['fvm dart run nidana_dart_codegen:generate --graph {input}/topology-graph.json {input}/topics.yaml {output}']`.

Create `test/support/generator.dart` (library doc: the samples the file and cli set tests share) with `String commandText(Command command)`, which renders a `DartCommand` as `'dart [{arguments joined by ", "}]'`, a `FlutterCommand` as `'flutter [...]'` and a `PackageCommand` as `'package {package}:{executable} [...]'`: `DartCommand(['', 'x'])` is `'dart [, x]'` and `PackageCommand('gen', 'generate', [])` is `'package gen:generate []'`.

Create `test/command_test.dart`, with a helper `String read(CommandReading r)` that renders `CommandRead` by `commandText` and `CommandUnreadable` as `'unreadable: {reason}'`:

- `readGeneratorCommand`:
  - `['fvm dart run gen:generate {input}/word.txt {output}']` reads `dart [run, gen:generate, {input}/word.txt, {output}]`; `['dart  run gen:generate {output}']` (two spaces) reads `dart [run, gen:generate, {output}]`.
  - `[]` reads `unreadable: no - file: bullet names a generator command: a backticked span that holds {output} and a space`.
  - `['dart a {output}', 'dart b {output}']` reads `unreadable: 2 backticked spans of - file: bullets hold {output} and a space, expected one: dart a {output}; dart b {output}`.
  - `['gen:generate {output}']` reads `unreadable: the generator command does not begin with fvm dart or dart: gen:generate {output}`.
- `readArgs`:
  - `'gen:generate\n--echo\n{output}\n'` reads `package gen:generate [--echo, {output}]`; `'gen:generate'` reads `package gen:generate []`.
  - `'dart\nanalyze\n--format=machine\n.\n'` reads `dart [analyze, --format=machine, .]`; `'dart\n\nx\n'` reads `dart [, x]` (an empty line is an empty argument).
  - `'flutter\n--version\n'` reads `flutter [--version]`.
  - `''` reads `unreadable: args holds no command`; `'fvm dart\nx\n'` reads `unreadable: args names no command: "fvm dart"; the command is dart, flutter or {package}:{executable}`; so do `'\n'` (`""`), `'Gen:x\n'` and `'gen:a/b\n'`, each with its first line JSON-quoted.
- `commandPackages`: `PackageCommand('gen', 'generate', [])` gives `{'gen'}`; `DartCommand(['run', 'nidana_dart_codegen:generate', '--graph', 'x'])` gives `{'nidana_dart_codegen'}`; `DartCommand(['run', '--enable-asserts', 'gen'])` gives `{'gen'}`; `DartCommand(['run', 'bin/x.dart'])`, `DartCommand(['analyze', '.'])` and `FlutterCommand(['test'])` give `{}`.
- `pluginPackages`:
  - the text of the committed `nidana-checks/invocation/analyze-configuration/files/analysis_options.yaml`, copied as a string (comment lines, then `plugins:`, `  nidana_dart_lint:`, `    path: ../../../../../../../packages/nidana_dart_lint`, `    diagnostics:` and three nested keys) gives `{'nidana_dart_lint'}`.
  - `'plugins:\n  # a lint\n  a_lint:\n    path: x\n  b_lint:\n    path: y\nanalyzer:\n  language:\n    strict-casts: true\n'` gives `{'a_lint', 'b_lint'}`; with `\r\n` line ends, the same.
  - `'analyzer:\n  plugins:\n    - old_lint\n'` (nested, the legacy form) and `''` give `{}`.
- `withOutput(PackageCommand('gen', 'generate', ['--out={output}', '{output}', 'x{output}']), '/t/output')` is a `PackageCommand` with package `gen`, executable `generate` and arguments `['--out={output}', '/t/output', 'x{output}']`.
- `processOf`, with `dart: '/sdk/dart'`, `packageConfig: '/w/.dart_tool/package_config.json'`, `roots: {'gen': Uri.parse('file:///w/packages/gen/')}`: a `DartCommand(['analyze', '.'])` gives `(executable: '/sdk/dart', arguments: ['analyze', '.'])`; `FlutterCommand(['--version'])` gives `('/sdk/flutter', ['--version'])` with `flutter: '/sdk/flutter'` and null with `flutter: null`; `PackageCommand('gen', 'generate', ['a'])` gives `('/sdk/dart', ['--packages=/w/.dart_tool/package_config.json', '/w/packages/gen/bin/generate.dart', 'a'])`; `PackageCommand('nosuch', 'x', [])` gives null.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/command_test.dart packages/nidana_contract_check/test/contract_test.dart`
Expected: FAIL: `command.dart` does not exist and `generatorCommands` is undefined. Keep the output.

- [ ] **Step 3: Implement**

`readContract` collects `generatorCommands` from the `## Validation` lines that begin `- file: `, each backticked span (`` `([^`]+)` ``) holding `{output}` and a space. `command.dart` implements the signatures above. `readArgs` splits at `\n` and drops one final empty element; its package pattern is `^([a-z_][a-z0-9_]*):([^\s:/]+)$`; the reason's line is `jsonEncode`d. `readGeneratorCommand` splits the span at spaces, drops empty words, and takes the words after `fvm`, `dart` or after `dart`. `pluginPackages` reads `\r\n` as `\n`, finds a line that is exactly `plugins:`, takes the lines after it up to the next line that is neither empty nor indented nor a comment, and returns the keys (`^\s+([a-z_][a-z0-9_]*)\s*:`) at the indentation of the first indented line that is not a comment. `processOf`'s script is `roots[package]!.resolve('bin/$executable.dart').toFilePath()`.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/command.dart packages/nidana_contract_check/lib/src/contract.dart packages/nidana_contract_check/test/support/generator.dart packages/nidana_contract_check/test/command_test.dart packages/nidana_contract_check/test/contract_test.dart
git commit -m "feat(contract_check): read the commands the file and cli sets run" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 3: Trees, admission and the file replay's plan

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. This task adds, all pure: the byte-for-byte comparison of two file trees (decision 7), the `--guarantee` admission of a file replay or recorded invocation (decision 13), the first stderr line a reason quotes, and the file set's plan and outcome (ADR-001 item 6; decisions 3, 4, 6 and 12). It also adds the `gen` sample the later tasks share.

**Files:**
- Create: `packages/nidana_contract_check/lib/src/tree.dart`, `lib/src/file_set.dart`
- Modify: `packages/nidana_contract_check/lib/src/run.dart`, `lib/src/report.dart` (`firstTextLine`)
- Modify: `packages/nidana_contract_check/test/support/generator.dart` (the `gen` sample)
- Create: `packages/nidana_contract_check/test/tree_test.dart`, `test/file_set_test.dart`
- Test: `packages/nidana_contract_check/test/report_test.dart` (the `run.dart` and `report.dart` additions)

**Interfaces:**
- Consumes: Task 2's `CommandRule`, `ProcessExit`, `readGeneratorCommand`, `CommandRead`, `CommandUnreadable`, `DartCommand`, `commandPackages`; `readContract`, `CoversClause` (`contract.dart`); `SlugSnapshot`, `fixtureDirectory`, `contractPath` (`snapshot.dart`); `GuaranteeRef`, `CheckSet` (`request.dart`); `formatIds` (`ids.dart`); `Passed`, `Failed`, `Pending`, `Problem` (`outcome.dart`); test support `snapshotOf`, `changed`.
- Produces:

```dart
// lib/src/tree.dart (pure)
/// A tree of files: each file's bytes by its `/`-separated path relative to the tree's root.
typedef FileTree = Map<String, List<int>>;
/// The problems of [actual] against [expected], byte for byte with the file set included
/// (ADR-001 item 6), by ascending path: `missing-file` ({path}) for a file only [expected] has,
/// `extra-file` ({path}) for one only [actual] has, `changed-file` ({path}: first difference at
/// byte {offset}) for one whose bytes differ, the offset where one ends being a difference.
List<Problem> treeProblems(FileTree expected, FileTree actual);

// lib/src/run.dart
/// Whether a file replay or recorded invocation of [slug] that covers [ids] runs under
/// [restriction] (ADR-001 item 9): unrestricted, or [ids] is not empty and each is a restriction
/// id of [slug].
bool admitsAll(Set<GuaranteeRef>? restriction, String slug, Set<int> ids);
/// The detail of a replay [admitsAll] does not admit.
String notAdmitted(Set<int> ids);
/// Whether [set] runs commands, before which the replay runs `dart pub get --enforce-lockfile`
/// once: file and cli do.
bool runsCommands(CheckSet set);

// lib/src/report.dart
/// The first line of [text] that is not blank, trimmed; null when there is none.
String? firstTextLine(String text);

// lib/src/file_set.dart (pure)
/// The path the file set names [slug]'s file replay by: `hsdd/contract/fixture/{slug}/expected/`.
String fileReplayPath(String slug);
/// What the file set does with a slug's file replay.
sealed class FilePlan { const FilePlan(); String get path; }
/// Decided without running: a fixture defect ([Failed]), [Passed] unrun, or [Pending].
final class FileSettled extends FilePlan { const FileSettled(this.outcome); final FixtureOutcome outcome; }
/// Run the generator: [arguments] are the running dart's, `{input}` and `{output}` kept;
/// [input] and [expected] are the slug's `input` and `expected` directories from the root.
final class FileRun extends FilePlan {
  const FileRun({required this.path, required this.arguments, required this.input, required this.expected});
  final String path; final List<String> arguments; final String input; final String expected;
}
/// The file replay of [snapshot] (decision 12): a defect of its command fails; a restriction
/// that does not admit the ids of its `- file:` covers clauses passes it unrun; a package the
/// command runs that [packages] lacks makes it [Pending]; otherwise it runs.
FilePlan planFileReplay(SlugSnapshot snapshot, {required Set<String> packages, required Set<GuaranteeRef>? restriction});
/// [run]'s arguments with every `{input}` and `{output}` in them replaced by [input] and [output].
List<String> generatorArguments(FileRun run, {required String input, required String output});
/// The outcome of [run]: [Passed] when [generator] and [format] exited 0 and the trees are
/// equal; else [Failed] with an `exit` problem, a `format` problem, then [treeProblems], each
/// that applies, in that order.
FixtureOutcome fileOutcome(FileRun run, {required ProcessExit generator, required ProcessExit format, required FileTree expected, required FileTree actual});
```

Problem details: `exit (the generator exited {code})`, `format (dart format exited {code})`, each followed by `: {firstTextLine(stderr)}` when there is one. Unreadable command details: `no contract text at hsdd/contract/{slug}.md`, else the reason `readGeneratorCommand` gives.

- [ ] **Step 1: Write the failing tests and the gen sample**

Add to `test/support/generator.dart` the `gen` slug the file and cli set tests share, kind `file`, as strings keyed by path from the workspace root (the stand-in generator Task 6 adds runs it): `const String genContract` exactly:

```markdown
---
id: gen
version: v1
status: stable
kind: file
---

# gen@v1

## Guarantees / invariants

- **G1** generate writes the expected tree.
- **G2** generate exits 2 on a usage error and writes nothing.
- **G3** generate prints where it wrote and the directory it ran from.
- **G4** generate reads its input relative to the directory it runs from.
- **G5** a case's files analyze as recorded.

## Validation

- file: `hsdd/contract/fixture/gen/input/` holds `word.txt`; the replay runs `fvm dart run gen:generate {input}/word.txt {output}`, formats the Dart in `{output}` and compares `{output}` with `expected/`. The file set covers G1.
- invocations: one directory per case under `hsdd/contract/fixture/gen/invocation/`.

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `analyze-lib` | `dart analyze --format=machine .` | 2 | G5 |
| `generate-from-files` | `gen:generate word.txt {output}` | 0 | G4: from files/ |
| `generate-tree` | `gen:generate --echo hsdd/contract/fixture/gen/input/word.txt {output}` | 0 | G1, G3 |
| `generate-usage` | `gen:generate --frob {output}` | 2 | G2 |
```

the public constants `const String genOutDart = "void main() {\n  print('hello');\n}\n";` and `const String genNotes = 'from hello\n';`, and `const Map<String, String> genFiles` holding, with `g = 'hsdd/contract/fixture/gen/'` and `i = '${g}invocation/'`:

| Key | Value |
|-----|-------|
| `hsdd/contract/gen.md` | `genContract` |
| `${g}input/word.txt` | `'hello\n'` |
| `${g}expected/out.dart`, `${i}generate-tree/expected/out.dart`, `${i}generate-from-files/expected/out.dart` | `genOutDart` |
| `${g}expected/notes.txt`, `${i}generate-tree/expected/notes.txt`, `${i}generate-from-files/expected/notes.txt` | `genNotes` |
| `${i}analyze-lib/args` | `'dart\nanalyze\n--format=machine\n.\n'` |
| `${i}analyze-lib/exit_code` | `'2\n'` |
| `${i}analyze-lib/stdout` | `"WARNING\|STATIC_WARNING\|UNUSED_IMPORT\|{files}/lib/a.dart\|1\|8\|12\|Unused import: 'dart:async'.\n"` (the pipes unescaped) |
| `${i}analyze-lib/files/pubspec.yaml` | `'name: example_app\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\n'` |
| `${i}analyze-lib/files/lib/a.dart` | `"import 'dart:async';\n\nvoid f() {}\n"` |
| `${i}generate-from-files/args` | `'gen:generate\nword.txt\n{output}\n'` |
| `${i}generate-from-files/exit_code` | `'0\n'` |
| `${i}generate-from-files/stdout` | `'wrote {output}\ncwd {files}\n'` |
| `${i}generate-from-files/files/word.txt` | `'hello\n'` |
| `${i}generate-tree/args` | `'gen:generate\n--echo\nhsdd/contract/fixture/gen/input/word.txt\n{output}\n'` |
| `${i}generate-tree/exit_code` | `'0\n'` |
| `${i}generate-tree/stdout` | `'wrote {output}\ncwd {root}\nresolved {output}\n'` |
| `${i}generate-usage/args` | `'gen:generate\n--frob\n{output}\n'` |
| `${i}generate-usage/exit_code` | `'2\n'` |
| `${i}generate-usage/stderr` | `'usage: generate [--echo] [--write-then-fail] <input> <output>\n'` |

This is `docs/auto-run/experiments/file-cli-sets-plan/samples/` as strings (Q2: structure passes it).

Create `test/tree_test.dart`; render problems as `'${p.rule.label} (${p.detail})'`:
- equal trees, the empty pair included, give `[]`.
- `{'a.txt': [1, 2, 3]}` against `{'a.txt': [1, 2, 4]}` gives `['changed-file (a.txt: first difference at byte 2)']`; against `{'a.txt': [1, 2]}` the same (one ends at 2).
- expected `{'.keep': [0], 'a': [1], 'b': [2]}` against actual `{'b': [3], 'c': [4]}` gives `['missing-file (.keep)', 'missing-file (a)', 'changed-file (b: first difference at byte 0)', 'extra-file (c)']`.

In `test/report_test.dart`, a group `admission`:
- `admitsAll(null, 'gen', {})` and `admitsAll(null, 'gen', {1})` are true.
- with `r = {(slug: 'gen', number: 1), (slug: 'gen', number: 3), (slug: 'other', number: 2)}`: `admitsAll(r, 'gen', {1, 3})` and `{1}` are true; `{1, 2}` (G2 is other's), `{}` and `admitsAll(r, 'other', {1})` are false.
- `notAdmitted({3, 1})` is `'not run: the restriction does not admit all of G1, G3'`; `notAdmitted({})` is `'not run: it covers no declared guarantee, and the replay is restricted'`.
- `runsCommands` is true for `file` and `cli` and false for every other set.
- `firstTextLine('\n  \n  boom  \nnext')` is `'boom'`; `firstTextLine(' \n')` and `firstTextLine('')` are null.

Create `test/file_set_test.dart` (`const String path = 'hsdd/contract/fixture/gen/expected/';`, `final SlugSnapshot gen = snapshotOf('gen', genFiles);`, a helper rendering a `FileSettled` by `outcomeLine(CheckSet.file, outcome)` and a `FileRun` as `'RUN {path} [{arguments joined by ", "}] {input} {expected}'`):
1. `unrestricted with its package, the replay runs`: `planFileReplay(gen, packages: {'gen'}, restriction: null)` renders `RUN hsdd/contract/fixture/gen/expected/ [run, gen:generate, {input}/word.txt, {output}] hsdd/contract/fixture/gen/input hsdd/contract/fixture/gen/expected`.
2. `a package the command runs that the workspace lacks is PENDING`: `packages: {}` renders `PENDING file hsdd/contract/fixture/gen/expected/: package gen is absent from .dart_tool/package_config.json`.
3. `the restriction admits it only when every id it covers is restricted, before PENDING`: `{(gen, 1)}` with `{'gen'}` runs; `{(gen, 2)}` renders `PASS file hsdd/contract/fixture/gen/expected/: not run: the restriction does not admit all of G1`, with `{'gen'}` and with `{}` alike; `{(other, 1)}` also not run.
4. `a file bullet that covers nothing runs only unrestricted`: with `genContract` minus ` The file set covers G1.` and `{(gen, 1)}`, `PASS ...: not run: it covers no declared guarantee, and the replay is restricted`; unrestricted it runs.
5. `a command it cannot read fails, admitted or not`: with `fvm dart run gen:generate` replaced by `gen:generate` in the contract text, under `{(gen, 2)}`: `FAIL file hsdd/contract/fixture/gen/expected/: command (the generator command does not begin with fvm dart or dart: gen:generate {input}/word.txt {output})`; with no contract text: `FAIL file ...: command (no contract text at hsdd/contract/gen.md)`.
6. `generatorArguments`: the run of test 1 with `input: '/w/hsdd/contract/fixture/gen/input'` and `output: '/t/output'` gives `['run', 'gen:generate', '/w/hsdd/contract/fixture/gen/input/word.txt', '/t/output']`.
7. `fileOutcome`, over that run, `e = {'notes.txt': utf8.encode(genNotes)}`, `ok = (code: 0, stdout: '', stderr: '')`: `generator: ok, format: ok, expected: e, actual: e` passes (`PASS file hsdd/contract/fixture/gen/expected/`); `generator: (code: 1, stdout: '', stderr: '\nfailed after writing\n')` with equal trees gives `FAIL ...: exit (the generator exited 1: failed after writing)`; `generator: (code: 255, stdout: '', stderr: '')` gives `exit (the generator exited 255)`; `format: (code: 65, stdout: '', stderr: 'Could not format because the source could not be parsed:\n\nline 2 ...')` gives `format (dart format exited 65: Could not format because the source could not be parsed:)`; `actual: {'notes.txt': utf8.encode('from Hello\n')}` gives `changed-file (notes.txt: first difference at byte 5)`; all three at once give them in the order exit, format, changed-file.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/tree_test.dart packages/nidana_contract_check/test/file_set_test.dart packages/nidana_contract_check/test/report_test.dart`
Expected: FAIL: `tree.dart` and `file_set.dart` do not exist; `admitsAll`, `notAdmitted`, `runsCommands` and `firstTextLine` are undefined. Keep the output.

- [ ] **Step 3: Implement**

Implement the signatures above; `firstTextLine` is the line selection `analysisFailure` and `runnerFailure` make today (Task 5 has them call it). `planFileReplay`: read the contract text (`contractText` null gives the `no contract text` defect); `readGeneratorCommand(contract.generatorCommands)`; the ids are the union of the `ids` of the `coversClauses` whose `bullet` is `file` (a malformed clause contributes none); then decision 12's order. `treeProblems` sorts the union of both key sets ascending.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/tree.dart packages/nidana_contract_check/lib/src/file_set.dart packages/nidana_contract_check/lib/src/run.dart packages/nidana_contract_check/lib/src/report.dart packages/nidana_contract_check/test/support/generator.dart packages/nidana_contract_check/test/tree_test.dart packages/nidana_contract_check/test/file_set_test.dart packages/nidana_contract_check/test/report_test.dart
git commit -m "feat(contract_check): plan the file replay and compare trees" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 4: The recorded invocations' plans and outcomes

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. This task adds the pure side of the `cli` set (ADR-001 item 7): each `invocation/{case}/` planned from the snapshot's records (decisions 10 to 13), the placeholders of a recorded stream (decision 9), and a finished case's outcome (decisions 7 and 8).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/cli_set.dart`
- Test: `packages/nidana_contract_check/test/cli_set_test.dart` (new)

**Interfaces:**
- Consumes: Task 1's `SlugSnapshot.records`; Task 2's `Command` family, `readArgs`, `commandPackages`, `pluginPackages`, `CommandRule`, `ProcessExit`; Task 3's `FileTree`, `treeProblems`, `admitsAll`, `notAdmitted`, `firstTextLine`; `readContract`, `InvocationRow`; `decodeSource`; `fixtureDirectory`; test support `snapshotOf`, `changed`, `genFiles`, `genContract`, `genNotes`, `commandText`.
- Produces:

```dart
// lib/src/cli_set.dart (pure)
/// The path the cli set names a recorded invocation by: `hsdd/contract/fixture/{slug}/invocation/{name}/`.
String invocationPath(String slug, String name);
/// What the cli set does with one recorded invocation.
sealed class InvocationPlan { const InvocationPlan(); String get path; }
/// Decided without running: a fixture defect ([Failed]), [Passed] unrun, or [Pending].
final class InvocationSettled extends InvocationPlan { const InvocationSettled(this.outcome); final FixtureOutcome outcome; }
/// Run the case: [command] as its `args` read it, `{output}` kept; [files] and [expected] are
/// its `files` and `expected` directories from the root, null when absent; [exitCode], [stdout]
/// and [stderr] are recorded, a stream null when not recorded.
final class InvocationRun extends InvocationPlan {
  const InvocationRun({required this.path, required this.command, required this.files, required this.expected, required this.exitCode, required this.stdout, required this.stderr});
  final String path; final Command command; final String? files; final String? expected;
  final int exitCode; final String? stdout; final String? stderr;
  /// Whether an argument is exactly `{output}`.
  bool get namesOutput;
}
/// One plan per `invocation/{case}` directory of [snapshot], ascending by case name (decision 12).
List<InvocationPlan> planInvocations(SlugSnapshot snapshot, {required Set<String> packages, required Set<GuaranteeRef>? restriction});
/// A path a recorded stream names by [placeholder], in its [given] and its symlink-[resolved] form.
typedef PathForms = ({String given, String resolved, String placeholder});
/// [text] with each of [forms], in order, replaced by its placeholder, the longer of its two
/// forms first (decision 9).
String withPlaceholders(String text, List<PathForms> forms);
/// What is at `{output}` after a case ran.
sealed class OutputState { const OutputState(); }
/// Nothing exists at `{output}`.
final class NoOutput extends OutputState { const NoOutput(); }
/// A file, or a link, is at `{output}`.
final class OutputFile extends OutputState { const OutputFile(); }
/// A directory is at `{output}`, read as [tree]; [format] is how `dart format` over it ended,
/// null when the case has no `expected/` and it was not formatted.
final class OutputTree extends OutputState { const OutputTree(this.tree, this.format); final FileTree tree; final ProcessExit? format; }
/// The outcome of [run], which ended as [exit], with [output] at `{output}` (NoOutput when it
/// names none) and [expected] its `expected/` tree (empty when it has none), the streams
/// compared after [forms]: [Passed], else [Failed] with `exit`, `stdout`, `stderr`, `format`,
/// then the output's problems, each that applies, in that order.
FixtureOutcome invocationOutcome(InvocationRun run, {required ProcessExit exit, required OutputState output, required FileTree expected, required List<PathForms> forms});
```

Details (decision 8): `exit (exited {code}, expected {recorded})`, followed by `: {first non-blank line of the stderr after forms}` when the case records no stderr and there is one; `stdout (line {n}: expected {a}, got {b})` and the same for `stderr`, `{a}` and `{b}` each the `jsonEncode`d line or `end of output`, lines split at `\n`, `{n}` the first differing one from 1; `format (dart format exited {code})` with the first stderr line as for the file set. Output, a case without `expected/`: nothing is fine; `output ({output} is a file, expected nothing there)`; `output ({output} exists after the run, expected nothing there: {files ascending, joined by ", "})`, ending at `there` for an empty directory. With `expected/`: `output (nothing at {output}, expected the tree of expected/)`; `output ({output} is a file, expected the tree of expected/)`; a tree gives its `format` problem, then `treeProblems(expected, tree)`. Defects, all of a case's in one [Failed], in this order: `command (no args file)` or `command (args: {decodeSource reason})` or `command ({readArgs reason})`; `exit-code (no exit_code file)` or `exit-code (exit_code: {reason})` or `exit-code (exit_code holds {jsonEncode(text)}, expected a decimal exit code from 0 to 255 and an optional newline)`; `recording (stdout: {reason})`, `recording (stderr: {reason})`.

- [ ] **Step 1: Write the failing tests**

Create `test/cli_set_test.dart` (`const String i = 'hsdd/contract/fixture/gen/invocation/';`, `final SlugSnapshot gen = snapshotOf('gen', genFiles);`, and a `describe` helper rendering an `InvocationSettled` by `outcomeLine(CheckSet.cli, outcome)` and an `InvocationRun` as `'RUN {path} {commandText(command)} files: {files or -} expected: {expected or -} exit: {exitCode} stdout: {jsonEncode(stdout) or -} stderr: {jsonEncode(stderr) or -}'`). A row is added to `genContract`'s table by appending it to the text, whose last lines are the table:

1. `each case directory gives one plan, ascending, with its recordings`: `planInvocations(gen, packages: {'gen'}, restriction: null).map(describe)` is exactly
   - `RUN ${i}analyze-lib/ dart [analyze, --format=machine, .] files: ${i}analyze-lib/files expected: - exit: 2 stdout: "WARNING|STATIC_WARNING|UNUSED_IMPORT|{files}/lib/a.dart|1|8|12|Unused import: 'dart:async'.\n" stderr: -`
   - `RUN ${i}generate-from-files/ package gen:generate [word.txt, {output}] files: ${i}generate-from-files/files expected: ${i}generate-from-files/expected exit: 0 stdout: "wrote {output}\ncwd {files}\n" stderr: -`
   - `RUN ${i}generate-tree/ package gen:generate [--echo, hsdd/contract/fixture/gen/input/word.txt, {output}] files: - expected: ${i}generate-tree/expected exit: 0 stdout: "wrote {output}\ncwd {root}\nresolved {output}\n" stderr: -`
   - `RUN ${i}generate-usage/ package gen:generate [--frob, {output}] files: - expected: - exit: 2 stdout: - stderr: "usage: generate [--echo] [--write-then-fail] <input> <output>\n"`
   (`jsonEncode` writes the strings with `\n` escaped as shown.)
2. `a package the command runs that the workspace lacks is PENDING; a dart command names none`: `packages: {}` gives `RUN ${i}analyze-lib/ ...` unchanged and `PENDING cli ${i}generate-from-files/: package gen is absent from .dart_tool/package_config.json` and the same for `generate-tree` and `generate-usage`.
3. `a plugin files/analysis_options.yaml enables is a package the command runs`: `gen` plus `${i}analyze-plugin/args` `'dart\nanalyze\n.\n'`, `exit_code` `'0\n'`, `files/analysis_options.yaml` `'plugins:\n  absent_lint:\n    path: ../absent_lint\n'`, and a row `` | `analyze-plugin` | `dart analyze .` | 0 | G5 | `` in the table: with `{'gen'}`, `PENDING cli ${i}analyze-plugin/: package absent_lint is absent from .dart_tool/package_config.json`; with `{'gen', 'absent_lint'}`, a `RUN` line.
4. `a case runs only when every id it covers is restricted, before PENDING`: `restriction: {(gen, 2)}` with `packages: {}` gives `generate-usage` `PENDING` and `PASS cli ${i}analyze-lib/: not run: the restriction does not admit all of G5`, `... generate-from-files/: ... all of G4`, `... generate-tree/: ... all of G1, G3`; `{(gen, 1)}` admits none of the four (generate-tree also covers G3).
5. `a case with no row runs only unrestricted`: a directory `${i}extra/` with `args` `'dart\n--version\n'` and `exit_code` `'0\n'` and no row: unrestricted a `RUN` line; under `{(gen, 2)}`, `PASS cli ${i}extra/: not run: it covers no declared guarantee, and the replay is restricted`.
6. `fixture defects fail the case, admitted or not`: over `snapshotOf('gen', changed(genFiles, ...))` (bytes through `snapshotOf`'s `bytes`), under `{(gen, 5)}`, which does not admit `generate-usage`: `generate-usage` with no `args` and no `exit_code` gives `FAIL cli ${i}generate-usage/: command (no args file); exit-code (no exit_code file)`; `exit_code` `'x\n'` gives `exit-code (exit_code holds "x\n", expected a decimal exit code from 0 to 255 and an optional newline)`, and so do `'256\n'`, `'02\n'` and `'-1\n'`, while `'2'` is no defect (the case is then `not run`); `args` the bytes `[0xff]` gives `command (args: not UTF-8: Invalid UTF-8 byte (at offset 0))`; `args` `'fvm dart\n'` gives `command (args names no command: "fvm dart"; the command is dart, flutter or {package}:{executable})`; `stderr` the bytes `[0xff]` gives `recording (stderr: not UTF-8: Invalid UTF-8 byte (at offset 0))`.
7. `withPlaceholders replaces the longer form of each path first, in order`: with `[(given: '/var/t/output', resolved: '/private/var/t/output', placeholder: '{output}'), (given: '/w/x/files', resolved: '/w/x/files', placeholder: '{files}'), (given: '/w', resolved: '/w', placeholder: '{root}')]`, `'a /private/var/t/output/b /var/t/output /w/x/files/c /w/d'` becomes `'a {output}/b {output} {files}/c {root}/d'`; with root forms `(given: '/link/ws', resolved: '/ws', ...)`, `'/link/ws/a /ws/b'` becomes `'{root}/a {root}/b'`.
8. `invocationOutcome`, for the runs of test 1, with no forms unless stated, `e = {'notes.txt': utf8.encode(genNotes)}`, `ok = (code: 0, stdout: '', stderr: '')`, `usageExit = (code: 2, stdout: '', stderr: 'usage: generate [--echo] [--write-then-fail] <input> <output>\n')` and `fromFilesExit = (code: 0, stdout: 'wrote {output}\ncwd {files}\n', stderr: '')`:
   - generate-usage, `usageExit`, `NoOutput()`, `{}`: `PASS cli ${i}generate-usage/`; the same with `code: 0`: `FAIL cli ${i}generate-usage/: exit (exited 0, expected 2)`.
   - generate-tree, `(code: 255, stdout: '', stderr: 'Could not find a file named "pubspec.yaml" in "/w".\n')`, forms `[(given: '/w', resolved: '/w', placeholder: '{root}')]`, `NoOutput()`, `e`: `FAIL cli ${i}generate-tree/: exit (exited 255, expected 0: Could not find a file named "pubspec.yaml" in "{root}".); stdout (line 1: expected "wrote {output}", got ""); output (nothing at {output}, expected the tree of expected/)`.
   - generate-from-files, `OutputTree(e, ok)` and `e`: with `fromFilesExit`, `PASS cli ${i}generate-from-files/`; with stdout `'wrote {output}\ncwd {root}\n'`, `FAIL cli ${i}generate-from-files/: stdout (line 2: expected "cwd {files}", got "cwd {root}")`; with stdout `'wrote {output}\n'`, `stdout (line 2: expected "cwd {files}", got "")`. With `fromFilesExit`: `OutputTree({'notes.txt': utf8.encode('from Hello\n')}, (code: 65, stdout: '', stderr: 'bad\n'))` gives `format (dart format exited 65: bad); changed-file (notes.txt: first difference at byte 5)`, and `OutputFile()` gives `output ({output} is a file, expected the tree of expected/)`.
   - generate-usage with `usageExit`: `OutputTree({'notes.txt': [1], 'out.dart': [2]}, null)` gives `FAIL cli ${i}generate-usage/: output ({output} exists after the run, expected nothing there: notes.txt, out.dart)`; `OutputTree({}, null)` gives `output ({output} exists after the run, expected nothing there)`; `OutputFile()` gives `output ({output} is a file, expected nothing there)`.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/cli_set_test.dart`
Expected: FAIL: `cli_set.dart` does not exist. Keep the output.

- [ ] **Step 3: Implement**

Implement the signatures above. The cases are the `directories` entries `invocation/{name}` (one segment), ascending. Records decode with `decodeSource`; `files/analysis_options.yaml` with `utf8.decode(bytes, allowMalformed: true)`, since only its keys are read. A case's ids: the `ids` of the first `invocationRows` row whose `caseName` is the case's name; none when there is no such row or its Covers cell is malformed. The packages a case names: `commandPackages(command)` with `pluginPackages` of its options file; absent ones ascending. `exit_code` matches `^(0|[1-9][0-9]*)\n?$` with a value up to 255.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/cli_set.dart packages/nidana_contract_check/test/cli_set_test.dart
git commit -m "feat(contract_check): plan recorded invocations and judge their runs" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 5: Processes, package roots and the replay's pub get

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. This task gives the shell one way to start a process (decision 18): `processes.dart`, which `runners.dart` and the analysis now use, with `lenientUtf8` moved into it; the package configuration read with each package's root (decision 1 needs them); and the one `dart pub get --enforce-lockfile` that runs before the `file` or `cli` set (decision 15). Those two sets still end `notImplemented` unless `pub get` failed. It also hardens `purity_test.dart` (routed).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/processes.dart`
- Modify: `packages/nidana_contract_check/lib/src/runners.dart`, `lib/src/shell.dart`, `lib/src/run.dart`, `lib/src/packages.dart`, `lib/src/analysis.dart`, `lib/src/test_report.dart`
- Modify: `packages/nidana_contract_check/test/support/runners.dart` (`recordingDart`)
- Test: `packages/nidana_contract_check/test/processes_test.dart` (new), `test/purity_test.dart`, `test/packages_test.dart`, `test/report_test.dart`, `test/cli_test.dart`

**Interfaces:**
- Consumes: Task 2's `ProcessExit`; Task 3's `runsCommands` and `firstTextLine`; `packageNamesOf`, `packageConfigPath`; `analysisFailure`, `runnerFailure`; the shell's `_Context`, `_Packages`, `_PackageNames`, `_NoPackages`, `_readPackages`, `_analyzeTargets`, `_run`; test support `seed`, `seedWorkspace`, `runTool`, `plainDart`, `sampleFiles`, `toolFiles`.
- Produces:

```dart
// lib/src/processes.dart (imports dart:io)
/// UTF-8 that decodes malformed bytes as U+FFFD instead of throwing: how the replay decodes the
/// output of every process it starts, so bytes that are not UTF-8 never stop a replay.
const Utf8Codec lenientUtf8 = Utf8Codec(allowMalformed: true);   // moved from runners.dart
/// What starting one process gave: it [Exited], or it [NotStarted].
sealed class ProcessRun { const ProcessRun(); }
final class Exited extends ProcessRun { const Exited(this.exit); final ProcessExit exit; }
/// The process could not start: [reason] is `could not run {executable}: {message}`.
final class NotStarted extends ProcessRun { const NotStarted(this.reason); final String reason; }
/// Runs [executable] with [arguments] from [workingDirectory] to its exit, its output decoded by
/// [lenientUtf8]; a ProcessException becomes [NotStarted].
Future<ProcessRun> runProcess(String executable, List<String> arguments, {required String workingDirectory});

// lib/src/packages.dart
/// The root of each package [packageConfigJson] configures, absolute and ending in `/`, its
/// relative `rootUri`s resolved against [configurationUri]; null when it is no package
/// configuration, as [packageNamesOf] judges one.
Map<String, Uri>? packageRootsOf(String packageConfigJson, Uri configurationUri);

// lib/src/run.dart
/// `dart pub get --enforce-lockfile exited {exitCode}`, then `: {firstTextLine(stderr)}` when there is one.
String pubGetFailure(int exitCode, String stderr);
// readsPackages: file and cli now read the package configuration too.

// lib/src/shell.dart (private)
final class _PackageNames extends _Packages {
  const _PackageNames(this.roots);
  final Map<String, Uri> roots;
  Set<String> get names => roots.keys.toSet();
}
typedef _Context = ({ /* the fields as they are, and */ String? pubGetFailure });
/// Runs `{dart} pub get --enforce-lockfile` from [root] once when a plan holds a set that
/// [runsCommands], after a progress line; null when it passed or did not run, else the reason.
Future<String?> _pubGet(Directory root, List<SlugPlan> plans, {required String dart, required StringSink progress});

// test/support/runners.dart
/// A script named `dart` in a fresh temporary directory, held by no Flutter SDK: it appends its
/// arguments, one line per call, to [calls]; with [pubFails], a call whose first argument is
/// `pub` prints the line "Unable to satisfy `pubspec.yaml` using `pubspec.lock`." to stderr and exits 65;
/// every other call runs the real dart.
({String dart, File calls}) recordingDart({bool pubFails = false});
```

- [ ] **Step 1: Write the failing tests**

`test/purity_test.dart`:
- The `dart:io` test becomes `no library under lib/src/ but processes.dart, runners.dart, shell.dart and workspace.dart imports dart:io`, expecting `['processes.dart', 'runners.dart', 'shell.dart', 'workspace.dart']`.
- Extract `String? targetOf(String uri, String from)`: the path relative to `lib/` that a directive [uri] of the library at [from] names: a URI with no scheme resolved against [from]'s directory, `package:nidana_contract_check/{path}` as `{path}`, any other URI null. `relativeTargetsOf` uses it. Test `targetOf follows the package's own package: URIs`: `targetOf('package:nidana_contract_check/src/shell.dart', 'fixture.dart')` is `'src/shell.dart'`; `targetOf('b.dart', 'src/a.dart')` is `'src/b.dart'`; `targetOf('src/a.dart', 'fixture.dart')` is `'src/a.dart'`; `targetOf('package:path/path.dart', 'fixture.dart')` and `targetOf('dart:io', 'fixture.dart')` are null.
- `no pure library reaches a library that imports dart:io`: for each `.dart` file directly under `lib/src/` not in the list above, `relativeClosure('src/{name}')` holds none of `src/processes.dart`, `src/runners.dart`, `src/shell.dart`, `src/workspace.dart`.

Create `test/processes_test.dart`:
- `runProcess runs to the exit and decodes the output`: `runProcess(Platform.resolvedExecutable, ['--version'], workingDirectory: Directory.systemTemp.path)` is `Exited` with code 0, and its stdout and stderr together contain `Dart SDK version: 3.13.5`.
- `runProcess decodes output that is not UTF-8 leniently`: a script `p.join(seed({}).path, 'bytes.dart')` holding `import 'dart:io'; void main() { stdout.add(<int>[0xff, 0x0a]); stderr.add(<int>[0x61, 0xfe]); exitCode = 3; }` run by `Platform.resolvedExecutable` gives `Exited` with `(code: 3, stdout: '\uFFFD\n', stderr: 'a\uFFFD')`.
- `runProcess of an executable that does not exist is NotStarted`: `'/nonexistent/dart'` gives `NotStarted` whose reason starts with `'could not run /nonexistent/dart: '`.

`test/packages_test.dart`: `packageRootsOf resolves each root against the configuration`: `'{"configVersion": 2, "packages": [{"name": "sample", "rootUri": "../packages/sample", "packageUri": "lib/"}, {"name": "path", "rootUri": "file:///cache/path-1.9.1/", "packageUri": "lib/"}]}'` with `Uri.parse('file:///w/.dart_tool/package_config.json')` gives `{'sample': Uri.parse('file:///w/packages/sample/'), 'path': Uri.parse('file:///cache/path-1.9.1/')}`; `'not json'` gives null.

`test/report_test.dart`: ``pubGetFailure(65, 'Unable to satisfy `pubspec.yaml` using `pubspec.lock`.\n\nTo update ...')`` is ``'dart pub get --enforce-lockfile exited 65: Unable to satisfy `pubspec.yaml` using `pubspec.lock`.'``; `pubGetFailure(1, '')` is `'dart pub get --enforce-lockfile exited 1'`; `readsPackages` is true for `surface`, `reject`, `behavior`, `file`, `cli` and false for `structure` and `schema`.

`test/cli_test.dart`:
1. `one dart pub get --enforce-lockfile runs at the root before the file or cli set, and never for the other sets`: `root = await seedWorkspace({...sampleFiles, ...toolFiles}, standIn: false)`; `rec = recordingDart()`; `runCli(['--all'], workingDirectory: root, out: out, err: err, dart: rec.dart)`: the lines of `rec.calls` that start with `pub ` are exactly `['pub get --enforce-lockfile']` and it is the first line; the first line of `err` is `running dart pub get --enforce-lockfile`. With a fresh `recordingDart()`, `runCli(['--all', '--set', 'structure,surface,reject,behavior,schema'], ...)` writes no line starting `pub ` and no `running dart pub get` line.
2. `a failing pub get makes every file and cli set unavailable with its reason (2), and the other sets still print`: `root = seed({...sampleFiles, ...toolFiles})`; `runCli(['tool'], ..., dart: recordingDart(pubFails: true).dart)` returns 2; `err` contains ``ERROR file tool: dart pub get --enforce-lockfile exited 65: Unable to satisfy `pubspec.yaml` using `pubspec.lock`.`` and the same line for `cli`; `out` contains `PASS structure hsdd/contract/tool.md`.
3. `without a lockfile the real pub get fails, and the replay exits 2`: `root = await seedWorkspace(toolFiles, standIn: false)`, then delete `pubspec.lock`; `runTool(['tool', '--set', 'file'])` exits 2 and its stderr contains `ERROR file tool: dart pub get --enforce-lockfile exited 1: Retrieving dependencies failed.` (P4).

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/processes_test.dart packages/nidana_contract_check/test/purity_test.dart packages/nidana_contract_check/test/packages_test.dart packages/nidana_contract_check/test/report_test.dart packages/nidana_contract_check/test/cli_test.dart`
Expected: FAIL: `processes.dart`, `packageRootsOf`, `pubGetFailure` and `recordingDart` do not exist; once stubbed, the purity list and the cli tests fail (no `pub get` runs). Keep the output.

- [ ] **Step 3: Implement**

- `processes.dart` as above; `runners.dart`'s `_started` and the shell's `_analyzeTargets` start their processes through `runProcess`, their reasons and outcomes unchanged (their tests pin them); `runners.dart` no longer declares `lenientUtf8`, and the shell imports it from `processes.dart`. `analysisFailure` and `runnerFailure` use `firstTextLine`.
- `packageNamesOf` becomes the key set of `packageRootsOf(json, its fixed URI)`; `_readPackages` reads roots with `File(workspacePath(root, packageConfigPath)).absolute.uri`.
- `_replay`: after the plans and the snapshots, `final String? pubGetFailure = await _pubGet(root, plans, dart: dart, progress: err);`, then `_readPackages` as now. `_pubGet` writes `running dart pub get --enforce-lockfile` to `progress`, runs `{dart} pub get --enforce-lockfile` from the root, and returns null on exit 0, `pubGetFailure(code, stderr)` on another exit, and `NotStarted`'s reason when it cannot start.
- `_run`: `file` and `cli` are `SetUnavailable` with `context.pubGetFailure` when it is set, else with `notImplemented` as now.
- `recordingDart` as `plainDart` is written, its script appending `"$*"` to `"$0.calls"` first.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/processes.dart packages/nidana_contract_check/lib/src/runners.dart packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/lib/src/run.dart packages/nidana_contract_check/lib/src/packages.dart packages/nidana_contract_check/lib/src/analysis.dart packages/nidana_contract_check/lib/src/test_report.dart packages/nidana_contract_check/test/support/runners.dart packages/nidana_contract_check/test/processes_test.dart packages/nidana_contract_check/test/purity_test.dart packages/nidana_contract_check/test/packages_test.dart packages/nidana_contract_check/test/report_test.dart packages/nidana_contract_check/test/cli_test.dart
git commit -m "feat(contract_check): start every process one way and run pub get before commands" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 6: The shell runs the file set

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. This task runs the file replay Task 3 plans: a fresh `{t}/output`, the generator from the root, `dart format` over it, both trees read with hidden entries (decisions 4 to 7). Tests replay a stand-in generator package `gen` in a seeded workspace (decision 22). Facts: `dart run gen:generate` of a workspace member prints only the program's output and takes about 0.2 s (G1, G2); the seeded workspace's `pub get --enforce-lockfile` passes offline (P1, P2); `dart format` behaves as decision 5 states (F1 to F4).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/command_runs.dart`
- Modify: `packages/nidana_contract_check/lib/src/shell.dart`
- Modify: `packages/nidana_contract_check/test/support/generator.dart` (`standInGenerator`), `test/support/workspace.dart` (`generator`), `test/purity_test.dart` (the list)
- Create: `packages/nidana_contract_check/test/command_runs_test.dart`

**Interfaces:**
- Consumes: Task 3's `FilePlan`, `FileSettled`, `FileRun`, `planFileReplay`, `generatorArguments`, `fileOutcome`, `FileTree`; Task 5's `runProcess`, `Exited`, `NotStarted`, `_PackageNames.roots`, `_Context.pubGetFailure`; `SetChecked`, `SetUnavailable`, `CheckSet`, `workspacePath`; test support `genFiles`, `seedWorkspace`, `runTool`, `changed`.
- Produces:

```dart
// lib/src/command_runs.dart (imports dart:io)
/// The files below [directory], hidden ones included, each read as bytes by its `/`-separated
/// path relative to it; a symbolic link is read through. The empty tree when [directory] is no
/// directory. Throws FileSystemException.
FileTree readTree(Directory directory);
/// The file set over [slug]'s [plan]: [SetChecked] with its one outcome, the run's from the
/// generator started by [dart] from [root] into a fresh `{t}/output`, `{dart} format {output}`
/// and the two trees, `{t}` deleted after; [SetUnavailable] when a process cannot start. A line
/// `running file {path}` goes to [progress] before the generator starts.
Future<SetRun> runFileSet(String slug, FilePlan plan, {required Directory root, required String dart, required StringSink progress});

// test/support/generator.dart
/// `packages/gen/bin/generate.dart` of a seeded workspace with a generator.
const String standInGenerator;

// test/support/workspace.dart
/// [files] in a fresh temporary pub workspace resolved offline: its members are the stand-in
/// package `sample` unless [standIn] is false; with [runners], also the stand-in
/// `nidana_contract_check` and `flutter_test`; with [generator], also the stand-in generator
/// package `gen` (no dependency) whose `bin/generate.dart` is [standInGenerator].
Future<Directory> seedWorkspace(Map<String, String> files, {bool standIn = true, bool runners = false, bool generator = false});
```

`standInGenerator` is exactly `docs/auto-run/experiments/file-cli-sets-plan/samples/packages/gen/bin/generate.dart` (its usage line is `usage: generate [--echo] [--write-then-fail] <input> <output>`; it writes `out.dart` as `void   main( ) {print(  '{word}' ) ;}` and a newline, which `dart format` turns into `genOutDart`, and `notes.txt` as `from {word}` and a newline; it prints `wrote {output as given}`, `cwd {Directory.current.path}`, and with `--echo` `resolved {output resolved}`; `--write-then-fail` writes, prints `failed after writing` to stderr and exits 1). The `gen` member's `pubspec.yaml` is `name: gen`, `publish_to: none`, `environment:`, `  sdk: ^3.13.0`, `resolution: workspace`.

- [ ] **Step 1: Write the failing tests and the seeding**

Add `standInGenerator` and the `generator` flag (the root's `workspace:` list names each member the flags give, and no `workspace:` key when none). In `test/purity_test.dart` add `command_runs.dart` to the `dart:io` list and the pure-closure check.

Create `test/command_runs_test.dart` (copy `lines` and `all` from `cli_test.dart`; `List<String> errLines(ProcessResult r)` splits stderr into lines, empty for none; `const String g = 'hsdd/contract/fixture/gen/';`; `const List<String> genStructure = ['PASS structure hsdd/contract/gen.md', 'PASS structure hsdd/contract/fixture/gen/'];`; `Future<Directory> genWorkspace([Map<String, String?> changes = const <String, String?>{}]) => seedWorkspace(changed(genFiles, changes), standIn: false, generator: true);`). A group `the file set`:

1. `readTree reads every file below a directory, hidden ones included, and nothing for a path that is no directory`: a seeded `{a.txt: 'a', sub/.hidden: 'h', .dot/b.txt: 'b'}` reads as those three paths with their bytes; a file path and an absent path read as `{}`.
2. `the generator's tree, formatted, equals expected/`: `runTool(['gen', '--set', 'file'], workingDirectory: await genWorkspace())` exits 0; `lines(r)` is `[...genStructure, 'PASS file ${g}expected/', '3 fixtures: 3 passed, 0 failed, 0 pending']`; `errLines(r)` is `['running dart pub get --enforce-lockfile', 'running file ${g}expected/']`. (The generator writes `out.dart` unformatted, so this pins the formatting.)
3. `one changed byte fails it`: with `${g}expected/notes.txt` `'from Hello\n'`, exit 1 and `'FAIL file ${g}expected/: changed-file (notes.txt: first difference at byte 5)'`.
4. `a missing file fails it`: with `${g}expected/more.txt` `'more\n'` added, `'FAIL file ${g}expected/: missing-file (more.txt)'`.
5. `an extra file fails it`: with `${g}expected/notes.txt` removed (`null`), `'FAIL file ${g}expected/: extra-file (notes.txt)'`.
6. `a hidden file in expected/ is part of the comparison`: with `${g}expected/.keep` `''` added, `'FAIL file ${g}expected/: missing-file (.keep)'`.
7. `a generator that exits non-zero fails it, even when its tree is right`: with the contract's `gen:generate {input}` replaced by `gen:generate --write-then-fail {input}`, `'FAIL file ${g}expected/: exit (the generator exited 1: failed after writing)'`.
8. `a generator package the workspace lacks is PENDING, and nothing runs`: `seedWorkspace(genFiles, standIn: false)` (no generator member): exit 1; the file line is `'PENDING file ${g}expected/: package gen is absent from .dart_tool/package_config.json'`; `errLines(r)` is `['running dart pub get --enforce-lockfile']`.
9. `the restriction admits it only when every id it covers is restricted`: `['gen', '--set', 'file', '--guarantee', 'G1']` passes as test 2; `--guarantee G2` exits 0 with `'PASS file ${g}expected/: not run: the restriction does not admit all of G1'` and no `running file` line.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/command_runs_test.dart packages/nidana_contract_check/test/purity_test.dart`
Expected: FAIL: `command_runs.dart` does not exist; once stubbed, tests 2 to 9 end `ERROR file gen: this version of nidana_contract_check does not implement the file set` with exit 2. Keep the output.

- [ ] **Step 3: Implement**

`runFileSet` as its dartdoc states: `{t}` from `Directory.systemTemp.createTempSync('ncc_file_')`, `{output}` its `output` subdirectory created empty, the input `workspacePath(root, run.input)`; the expected tree `readTree(Directory(workspacePath(root, run.expected)))`, the actual `readTree` of `{output}`; `{t}` deleted in a `finally`. `readTree` lists with `recursive: true, followLinks: false` and reads each `File` and `Link` as bytes. The shell's `_run` gives `file` a `_fileRun`: the `pubGetFailure` reason, else the `_NoPackages` reason, else `runFileSet(slug, planFileReplay(snapshot, packages: names, restriction: context.restriction), ...)`. Update the dartdoc of `shell.dart`'s library comment, `runCli` and `_replay`: the shell runs one `pub get` and the file set's generators.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/command_runs.dart packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/test/support/generator.dart packages/nidana_contract_check/test/support/workspace.dart packages/nidana_contract_check/test/purity_test.dart packages/nidana_contract_check/test/command_runs_test.dart
git commit -m "feat(contract_check): run the file set" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 7: The shell runs the cli set

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. This task runs the recorded invocations Task 4 plans (decisions 1, 8, 9 and 16), removes `notImplemented`, and replays the committed tree. **Never start the real flutter**: a seeded `flutter` case runs through `runCli` with `standInSdk().dart` or `plainDart()` only. Facts: a `{package}:{executable}` case from `files/` runs in the script form on a fresh and on a stale workspace (N2 to N5, Q4, Q5); a child reads its working directory resolved (S2); `dart analyze --format=machine` prints resolved paths (A1); a child's stdin is at end of input (I1).

**Files:**
- Modify: `packages/nidana_contract_check/lib/src/command_runs.dart`, `lib/src/shell.dart`, `lib/src/report.dart` (`notImplemented` removed)
- Test: `packages/nidana_contract_check/test/command_runs_test.dart`, `test/report_test.dart`

**Interfaces:**
- Consumes: Task 2's `withOutput`, `processOf`, `FlutterCommand`; Task 4's `InvocationPlan`, `InvocationSettled`, `InvocationRun`, `planInvocations`, `PathForms`, `OutputState` and its variants, `invocationOutcome`; Task 5's `runProcess`; Task 6's `readTree`; `packageConfigPath`, `workspacePath`, `flutterBeside`; test support `standInSdk`, `plainDart` (`test/support/runners.dart`), `genWorkspace`, `genStructure`, `runTool`, `lines`, `errLines`.
- Produces:

```dart
// lib/src/command_runs.dart
/// The cli set over [slug]'s [plans], in order. Each run is resolved to its process first by
/// [processOf] with [dart], [flutter], the package configuration under [root] and [roots]; the
/// first that cannot be makes the set [SetUnavailable] with `no flutter in the Flutter SDK of
/// {dart}; {path} runs flutter`, and no case of the slug starts. Otherwise each run gets a
/// fresh `{t}`, its `{output}` arguments become `{t}/output`, it starts from its `files/` or
/// [root] after a line `running cli {path}` to [progress], `{output}` is read (formatted first
/// when the case has `expected/`), and [invocationOutcome] judges it with the placeholders of
/// `{output}`, its `files/` and [root]; `{t}` is deleted after. A process that cannot start
/// makes the set [SetUnavailable] with its reason, starting no case after it.
Future<SetRun> runCliSet(String slug, List<InvocationPlan> plans, {required Directory root, required String dart, required String? flutter, required Map<String, Uri> roots, required StringSink progress});
```

- [ ] **Step 1: Write the failing tests**

In `test/command_runs_test.dart`, a group `the cli set` (`const String i = '${g}invocation/';`; a row helper `String row(String name, String command, int exit, String covers)` giving `` '| `$name` | `$command` | $exit | $covers |' ``, and changes that append a row to `genContract`'s table):

1. `the clean cases pass: exit codes, streams with {output}, {files} and {root}, and the trees at {output}`: `runTool(['gen', '--set', 'cli'], workingDirectory: await genWorkspace())` exits 0; `lines(r)` is `[...genStructure, 'PASS cli ${i}analyze-lib/', 'PASS cli ${i}generate-from-files/', 'PASS cli ${i}generate-tree/', 'PASS cli ${i}generate-usage/', '6 fixtures: 6 passed, 0 failed, 0 pending']`; `errLines(r)` is `['running dart pub get --enforce-lockfile', 'running cli ${i}analyze-lib/', 'running cli ${i}generate-from-files/', 'running cli ${i}generate-tree/', 'running cli ${i}generate-usage/']`. (The workspace is under the system temporary directory, so the recordings' `{root}`, `{files}` and resolved `{output}` pin the resolved forms, S1, S2, A1.)
2. `a wrong exit code fails the case`: with `${i}generate-usage/exit_code` `'0\n'`, exit 1 and `'FAIL cli ${i}generate-usage/: exit (exited 2, expected 0)'`.
3. `output left at {output} fails a case without expected/`: a case `${i}generate-leaves-output/` with `args` `'gen:generate\n--write-then-fail\nhsdd/contract/fixture/gen/input/word.txt\n{output}\n'`, `exit_code` `'1\n'` and the row `row('generate-leaves-output', 'gen:generate --write-then-fail hsdd/contract/fixture/gen/input/word.txt {output}', 1, 'G2')`: exit 1 and `'FAIL cli ${i}generate-leaves-output/: output ({output} exists after the run, expected nothing there: notes.txt, out.dart)'`.
4. `a stream that differs fails the case at its first differing line`: with `${i}generate-tree/stdout` `'wrote {output}\ncwd {files}\nresolved {output}\n'`: `'FAIL cli ${i}generate-tree/: stdout (line 2: expected "cwd {files}", got "cwd {root}")'`.
5. `the tree at {output} is compared with expected/ as the file set compares`: with `${i}generate-tree/expected/notes.txt` `'from Hello\n'`: `'FAIL cli ${i}generate-tree/: changed-file (notes.txt: first difference at byte 5)'`.
6. `a package the command runs, a plugin included, that the workspace lacks is PENDING, and the rest runs`: `runTool(['gen', '--set', 'cli'])` over `seedWorkspace(changed(genFiles, {analyze-plugin case and row as in Task 4's test 3}), standIn: false)` (no generator member): exit 1; the cli lines are `'PASS cli ${i}analyze-lib/'`, `'PENDING cli ${i}analyze-plugin/: package absent_lint is absent from .dart_tool/package_config.json'`, and `'PENDING cli ${i}generate-{from-files,tree,usage}/: package gen is absent from .dart_tool/package_config.json'`; `errLines(r)` is `['running dart pub get --enforce-lockfile', 'running cli ${i}analyze-lib/']`.
7. `the restriction runs a case only when every id it covers is restricted`: `['gen', '--set', 'cli', '--guarantee', 'G2']` exits 0, with `PASS cli ${i}generate-usage/` and `PASS cli ${i}analyze-lib/: not run: the restriction does not admit all of G5`, `... generate-from-files/: not run: ... all of G4`, `... generate-tree/: not run: ... all of G1, G3`; stderr holds `running cli` for `generate-usage` alone.
8. `flutter runs as the flutter beside the running dart, and its absence is an environment error`: a case `${i}flutter-version/` (`args` `'flutter\n--version\n'`, `exit_code` `'64\n'`, `stderr` `'stand-in flutter: expected test --no-pub\n'`, row covering G5): with `sdk = standInSdk()`, `runCli(['gen', '--set', 'cli'], dart: sdk.dart, ...)` returns 0, `out` holds `PASS cli ${i}flutter-version/`, and `sdk.flutterCalls.readAsLinesSync()` is `['--version']`; with `dart = plainDart()`, it returns 2, `err` holds `ERROR cli gen: no flutter in the Flutter SDK of $dart; ${i}flutter-version/ runs flutter` and no `running cli` line.
9. `a workspace whose resolution reads stale still runs every case`: in a fresh `genWorkspace()`, `File('${root.path}/packages/gen/pubspec.yaml').setLastModifiedSync(DateTime.now().add(const Duration(seconds: 10)))`; `runTool(['gen', '--set', 'cli'])` exits 0 with the lines of test 1 (decision 1; `dart run` from `files/` would exit 255 here, K2, Q5).
10. `from a symbolic link to the workspace root, the placeholders still apply`: `Link('${seed({}).path}/linked')..createSync(root.path)`; `runCli(['gen', '--set', 'cli'], workingDirectory: Directory(link.path), ...)` (with `dart: null`; no case runs flutter) returns 0 and `out` holds the four `PASS cli` lines.

In `test/report_test.dart`, remove the case that prints `notImplemented(CheckSet.behavior)`, or have it build its `SetUnavailable` from a literal reason.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/command_runs_test.dart`
Expected: FAIL: `runCliSet` does not exist; once stubbed, the cli tests end `ERROR cli gen: this version of nidana_contract_check does not implement the cli set` with exit 2. Keep the output.

- [ ] **Step 3: Implement**

`runCliSet` as its dartdoc states. `{t}` from `Directory.systemTemp.createTempSync('ncc_cli_')`; `{output}` is `p.join(t.path, 'output')`, not created; the working directory `workspacePath(root, run.files!)` or `root.path`. After the run: `FileSystemEntity.typeSync(output, followLinks: false)` gives `NoOutput`, `OutputFile` (a file or a link) or, for a directory, `OutputTree(readTree(...), format)` with `format` from `runProcess(dart, ['format', output], workingDirectory: root.path)` when `run.expected` is set, else null. The forms: `(given: output, resolved: p.join(t.resolveSymbolicLinksSync(), 'output'), placeholder: '{output}')`, then for `files/` `(given: its path, resolved: Directory(its path).resolveSymbolicLinksSync(), placeholder: '{files}')`, then `(given: root.path, resolved: root.resolveSymbolicLinksSync(), placeholder: '{root}')`. The shell's `_run` gives `cli` a `_cliRun` built as `_fileRun` is, passing `context.flutter` and the roots. Remove `notImplemented` from `report.dart`; `_run` no longer uses it. Update `shell.dart`'s library dartdoc for the recorded invocations.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Replay the committed tree**

Each command from the repository root; keep stdout and stderr.

Run: `fvm dart run nidana_contract_check --all --set file; echo "exit: $?"`
Expected: `exit: 1`; 102 `PASS structure` lines; one line `PENDING file hsdd/contract/fixture/topic-codegen/expected/: package nidana_dart_codegen is absent from .dart_tool/package_config.json`; `103 fixtures: 102 passed, 0 failed, 1 pending`; stderr is the one line `running dart pub get --enforce-lockfile`.

Run: `fvm dart run nidana_contract_check --all --set cli; echo "exit: $?"`
Expected: `exit: 1`; 102 `PASS structure` lines; 39 `PENDING cli` lines: topic-codegen's 22 cases and nidana-checks' nine `scan-*` cases naming `package nidana_dart_codegen`, nidana-checks' eight `analyze-*` cases naming `package nidana_dart_lint`; `141 fixtures: 102 passed, 0 failed, 39 pending`; stderr the `pub get` line alone.

Run: `fvm dart run nidana_contract_check topic-codegen nidana-checks; echo "exit: $?"`
Expected: `exit: 1`; 4 `PASS structure`, 58 `PASS schema`, 1 `PENDING file`, 39 `PENDING cli`; `102 fixtures: 62 passed, 0 failed, 40 pending`. Their structure and schema sets pass; every file replay and recorded invocation is PENDING.

Run: `fvm dart run nidana_contract_check nidana-checks --guarantee G1,G2,G3,G4,G5,G6,G7,G8; echo "exit: $?"`
Expected: `exit: 1`; 2 `PASS structure`; the eight `analyze-*` cases `PENDING` (`package nidana_dart_lint`); the nine `scan-*` cases `PASS cli ...: not run: the restriction does not admit all of ...`; `19 fixtures: 11 passed, 0 failed, 8 pending` (decision 12: nidana.tooling.lint.4's gate, before nidana_dart_codegen exists, waits on no other producer).

Run: `fvm dart run nidana_contract_check topic-codegen --guarantee G1; echo "exit: $?"`
Expected: `exit: 0`; 2 `PASS structure`, 58 `PASS schema`, the file replay and the 22 cases `PASS ...: not run: ...`; `83 fixtures: 83 passed, 0 failed, 0 pending` (nidana.tooling.codegen.1's gate: none covers G1 alone).

Run: `fvm dart run nidana_contract_check --all; echo "exit: $?"`
Expected: `exit: 1`; `321 fixtures: 235 passed, 3 failed, 83 pending` (the 281 of nidana.model.6's sets, as replayed at this phase's base, and 40 `PENDING`); stderr is `running dart pub get --enforce-lockfile`, then the three `running behavior` lines; no `ERROR` line; no flutter started.

A different count is a finding, not a test to adjust: stop and report it.

- [ ] **Step 6: Run the gate (Global Constraint 4)**

Run: `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add packages/nidana_contract_check/lib/src/command_runs.dart packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/lib/src/report.dart packages/nidana_contract_check/test/command_runs_test.dart packages/nidana_contract_check/test/report_test.dart
git commit -m "feat(contract_check): run the cli set" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 8: Gate and verification doc

You write the phase's verification doc. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.7.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.7.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 7; `packages/nidana_contract_check/test/command_runs_test.dart` (the seeded file and cli cases); the gate output; `docs/auto-run/experiments/file-cli-sets-plan/` (`staleness2.sh` and its output for M5); `hsdd/verify/nidana.model.6.verification.md` (its line legend); this plan's Design decisions and Routed items.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check) > "${TMPDIR:-/tmp}/nidana.model.7-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the times with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after.
Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending` and `All tests passed!` with the package's test count. A failure stops here: it is fixed in the task that owns the code, never by editing `hsdd/`.

- [ ] **Step 2: Run the phase's Verification on the committed tree**

Run each command of Task 7 Step 5 and keep its output, and `fvm dart test packages/nidana_contract_check/test/command_runs_test.dart` (every test passes). The gate runs neither `--set file` nor `--set cli` over the committed tree: what the phase Verification says of the committed fixtures comes from these replays, and what it says of seeded defects comes from the tests.

- [ ] **Step 3: Write `hsdd/verify/nidana.model.7.verification.md` at full-review depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder with content, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.7 - Replay tool: file and cli sets` (a spaced hyphen; no em-dash anywhere in the file).

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate of Step 1; the commands of Step 2. State that the gate checks the structure set over the nine contracts and the package's tests, which replay the seeded `gen` slug's file replay and recorded invocations against the stand-in generator; that it runs no `--set file` or `--set cli` over the committed tree; and that the committed-tree lines come from the Step 2 replays. The phase produces no contract, so there is no output of its own to validate against a schema.
- **Expected output:** the gate's lines as Step 1 lists them; from `command_runs_test.dart`, the exact lines of the file group's tests 2 to 8 and the cli group's tests 1 to 3, 6, 8 and 9 (one changed byte, a missing and an extra file; a wrong exit code and output left at `{output}`; PENDING with nothing run; flutter's absence as an environment error; the stale workspace); the committed-tree replays of Task 7 Step 5 with their counts. Then the line legend: copy nidana.model.6's "How to read a behavior line" bullets as they stand, and add the new forms:
  - `PASS file hsdd/contract/fixture/{slug}/expected/`, and `PASS cli hsdd/contract/fixture/{slug}/invocation/{case}/`.
  - `PASS {file or cli} {path}: not run: the restriction does not admit all of {ids}`, or `: not run: it covers no declared guarantee, and the replay is restricted`: not started; the restriction is decided before PENDING for these two sets (decision 12).
  - `PENDING {file or cli} {path}: package {name} is absent from .dart_tool/package_config.json`, or `packages {names} are absent ...`: the package a `{package}:{executable}` command or a `dart run` target names, and for a recorded invocation each plugin its `files/analysis_options.yaml` enables; nothing started.
  - `FAIL file {path}: ...` with, in order, `exit (the generator exited {code}[: {line}])`, `format (dart format exited {code}[: {line}])`, then `missing-file ({file})`, `extra-file ({file})` and `changed-file ({file}: first difference at byte {offset})` by ascending path; or one `command ({reason})` when the generator command cannot be read.
  - `FAIL cli {path}: ...` with, in order, `exit (exited {code}, expected {recorded}[: {first stderr line}])`, `stdout (line {n}: expected {quoted or end of output}, got {quoted or end of output})`, the same for `stderr`, `format (...)`, then `output ({output} exists after the run, expected nothing there[: {files}])`, `output ({output} is a file, expected ...)`, `output (nothing at {output}, expected the tree of expected/)` or the tree problems; or its defects before any run: `command (...)`, `exit-code (...)`, `recording ({stream}: not UTF-8: ...)`.
  - `ERROR {file or cli} {slug}: {reason}` on stderr, exit 2, in place of every line of the slug's set: `dart pub get --enforce-lockfile exited {code}[: {line}]` (for every file and cli set of the replay), `could not run {executable}: {message}`, `no flutter in the Flutter SDK of {dart}; {path} runs flutter`, or the package configuration's reason.
  - On stderr: `running dart pub get --enforce-lockfile` once per replay that plans either set, `running file {path}` and `running cli {path}` before each run.
  - Also state the corrected behavior of a suite slug's read (decision 19): before this phase a read defect anywhere in the tree of a slug whose suite a binding imports ended the whole replay with exit 2 and no fixture line for any slug, which nidana.model.6's verification doc understated as ending the replayed slug's replay; now only the suite files are read, and an absent or dangling one fails its binding with `suite ({path} does not exist)`.
- **Observed:** dated (`date -u`); the gate's exit code and lines as they appeared; the test count by file; the Step 2 outputs; how long the seeded file and cli tests took; every deviation from this plan, each with the ruling and the test that pins it; the choices where the plan left room.
- **Outstanding:** the real producers do not exist, so the file and cli sets ran against the stand-in generator and the seeded `dart analyze` case only; topic-codegen@v1's file replay and 22 cases and nidana-checks@v1's 17 are PENDING. Proposed disposition: deferred to the first gates that admit them against the real packages: nidana.tooling.codegen.6 (the file replay and the `generate-*` cases), nidana.tooling.codegen.9 (the `scan-*` cases), nidana.tooling.codegen.11 (the `catalog-*` cases) and nidana.tooling.lint.4 (the `analyze-*` cases, which also first load the real plugin through a case's `files/analysis_options.yaml`). Also: no `flutter` command ran but the stand-in's (no committed case uses one); deferred with the real flutter of nidana.model.6's Outstanding.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Candidates, each kept only if the gate still shows it: ADR-001 item 9 gives one `dart pub get --enforce-lockfile` so no case runs on a stale resolution, and nidana.model.7's Scope gives as its reason that `dart run` from `files/` exits 255 on one, but `pub get` refreshes none of the mtimes `dart run` reads when the resolution is unchanged, the repository reads stale (M5), and the tool runs `{package}:{executable}` as its script instead (decision 1; the contract gap of `docs/auto-run/steps/S121.json`; proposed `dropped (routed as contract gap S121 to hsdd-adr for ADR-001 items 7 and 9)` unless the orchestrator has already routed it otherwise); "the backticked span ... that holds `{output}`" names three spans of topic-codegen@v1's bullet, read as the one that also holds a space (decision 3; proposed `dropped (routed to the end-of-node sweep's ADR-001 touch)`); a plugin a case's `files/analysis_options.yaml` enables is read as a package its command runs (decision 11; same disposition); for file replays and recorded invocations the restriction is decided before PENDING, unlike the behavior set (decision 12; same disposition); the phase's size against its estimate of about 450 lines (proposed `dropped (sizing is the owner's to revisit at a checkpoint)`). Write `- none` only when nothing applies; never leave the section empty.
- **Metrics:** gate failures before green; fix rounds after task review; wall-clock from the start of the implementation step to the gate; the product diff in lines, `git diff --stat {base} HEAD -- packages/` with `{base}` the commit before Task 1's first commit, by part (library, tests), beside the estimate of about 450 lines in about 7 files; the task count, 8 of the allowed 8.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.7.verification.md
git commit -m "docs(verify): nidana.model.7 verification" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```
