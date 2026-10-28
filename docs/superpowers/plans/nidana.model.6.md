# nidana.model.6 Replay Tool: Behavior Set Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the `behavior` set of ADR-001 items 4 and 9 in `packages/nidana_contract_check`: every `behavior/{implementation}_test.dart` binding runs from the workspace root under `dart test`, or under `flutter test --no-pub` of the running `dart`'s Flutter SDK when it imports `package:flutter_test`; it is PENDING when it or the conformance library it imports names an absent package; under `--guarantee` it is restricted by the ids of the slug whose conformance library it imports, through a name filter anchored at the start of the name, and never started when the restriction admits none of its cases; and the replay prints one line per binding with its counts and the names of its failing cases. With it land the tool fixes routed to this phase that the behavior set's reading and running need.

**Architecture:** The pure core and imperative shell of nidana.model.1 and .2, extended. Pure: `behavior.dart` plans each binding from the snapshots (its suite, its runner, its admitted ids, or a settled outcome: a fixture defect, PENDING, not admitted) and builds the runner's arguments and the flutter path; `test_report.dart` reads package:test's JSON reporter output into counts, failing names or a load failure, and turns one run into an outcome. The shell reads the package configuration once per replay into a context record every set run reads, reads the snapshots of the slugs whose suites a binding imports, runs one runner process per binding from the workspace root, one after another, with a progress line on stderr, and maps a missing flutter or a runner without a report to an environment error.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:test` 1.33.0's `dart test --reporter json` (JSON protocol 0.1.1); Flutter 3.47.7's `flutter test --no-pub --reporter json` as its flutter_tools source states it; `package:args`, `package:path` and `package:package_config` as nidana.model.1 and .2 use them. No dependency is added.

**Spec:** `hsdd-context/superpowers/nidana.model.6.md` (the derivative; the generic phase context sits between its markers). Governance it links: `hsdd/spec/nidana.model.md` (phase nidana.model.6, D1, D2, D3), `hsdd/adr/001-executable-contract-validation.md` (items 2 to 4, 9 and 12), `hsdd/adr/002-package-workspace-layout.md` (items 3 and 4). The code this phase extends is `packages/nidana_contract_check/` as nidana.model.2 left it (`hsdd/verify/nidana.model.1.verification.md`, `hsdd/verify/nidana.model.2.verification.md`). Evidence: `docs/auto-run/experiments/behavior-set-plan/` (`run.sh`, `output.txt`, `summarize.py`, `reader.dart`, `utf8.dart`); labels such as D4 or R1 below name the steps of its `output.txt`. Also cited: `docs/auto-run/experiments/empty-guarantee-selection/output.txt` (E2, E3), `docs/auto-run/experiments/replay-sets-plan/output.txt` (W0, X1, X2), `docs/auto-run/experiments/contract-fixtures/output.txt` (Q10 to Q12).

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 6 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.6.verification.md from
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

- Toolchain: `fvm dart` only, every command from the repository root, no global tooling. Inside a temporary directory `fvm` runs no `dart` (`replay-sets-plan` W0), so the tool and the tests start the SDK's `dart` as `Platform.resolvedExecutable`, which under `fvm dart run` and `fvm dart test` is `~/fvm/versions/3.47.7/bin/cache/dart-sdk/bin/dart` (X1; this experiment's T1).
- No real flutter, ever. This machine's Flutter SDK has no engine artifacts (`bin/cache/pkg/sky_engine` and `bin/cache/artifacts/engine` are absent, T2), and fetching them is a network action outside the run rules. No test and no step may start the real `flutter`: a seeded workspace that holds a `package:flutter_test` binding which is not PENDING runs only through `runCli(..., dart: standInSdk().dart)` (Task 5), never through `runTool` and never with `dart: null`. The committed tree's two Flutter bindings are PENDING (no member provides `flutter_test`), so the committed-tree replays start no flutter.
- Files: nothing outside `packages/nidana_contract_check/` changes, except the verification doc in Task 6. No root file, member `pubspec.yaml` or lockfile changes, and no package is added.
- Pure core, imperative shell (nidana.model D2 item 5): from Task 1 on, `lib/src/shell.dart` and `lib/src/workspace.dart` are the only files under `lib/src/` that import `dart:io`, read a file or start a process (`test/purity_test.dart` pins it); `lib/fixture.dart` may. Values are immutable: final fields, collections built once and never mutated. Alternatives are sealed classes or enums, matched by exhaustive `switch`.
- Tests: the pure core by direct calls over in-memory snapshots (`snapshotOf`) and canned reporter output; the shell by `runCli` in process or by the bin script (`runTool`). A seeded fixture is a string in test code, never a `.dart` file in the package. A test that runs bindings seeds a temporary workspace with `seedWorkspace(files, runners: true)` (Task 5), resolved offline in about 0.2 s (W1).
- Output (ADR-001 item 9): one line per fixture on stdout, `PASS`, `FAIL` or `PENDING`, then the set and the path from the workspace root with `/` separators; `ERROR {set} {slug}: {reason}` on stderr for a set that could not run; `running behavior {path} under {runner}` on stderr before each runner starts; one summary line; exit 0 when every fixture passes, 1 when any fails or is PENDING, 2 on an environment error, 64 on a usage error (nidana.model D2 item 1).
- Contract gaps (ADR-001 item 8): a committed contract, fixture or binding that a rule as written rejects is never edited. Stop at the task boundary and report BLOCKED with the file, the rule it breaks and the fix you would propose. Every committed fixture was checked against this plan's rules while planning (R5, R6, R7): none is rejected.
- Formatting and tests: run `fvm dart format` on every Dart file the task creates or changes before committing. Add tests beyond a step's wherever a rule would otherwise go unpinned. The lockfile holds `test` 1.33.0; no test uses a `test` API newer than 1.31.1.
- Prose and commits follow the run rules: no em-dash character in any comment, dartdoc or commit message, and never the phrase the run rules ban; stage explicit paths; conventional subjects (`feat(contract_check): ...`); the commit body ends with `Co-Authored-By: {model} <noreply@anthropic.com>`, where `{model}` names the model that wrote the commit, for example `Claude Sonnet 5.5` (orchestrator ruling, S107).

## Review Focus

The input classes the spec implies but its own cases do not exercise, most likely to bite first; each has its test in the owning task.

1. **Runner output that is not all JSON events.** flutter_tools prints status lines to stdout through `printStatus` (T3 names one), and a case's `print` arrives as a `print` event. The report reader skips every line that is not a JSON object with a string `type` and counts only `testDone` events, so neither shifts a count. Test: Task 4 (`lines that are not JSON events change nothing`).
2. **A filter the reader admits but no runtime name matches**: a binding that registers its cases under other names, or registers none. `dart test` then exits 79 with a `done` event whose `success` is true (D4, D8), so success alone would pass it. It must fail as `no case ran`. Test: Task 4 (`no case ran is a failure, whatever done says`).
3. **A workspace root reached through a symbolic link** (macOS temporary paths, a linked checkout). The runner gets the binding's path relative to the root and runs from the root; outcomes are attributed per process, never by a path the runner prints, which `flutter test` prints as an absolute file URI (T3). Test: Task 5 (`through a symbolic link to the workspace root`).
4. **A suite that imports a package its binding does not, or the reverse.** The binding is PENDING with the union of the absent packages, never a load failure that reads as a defect. Test: Task 3 (`an absent package of the binding or of its suite alone`).
5. **A Dart source that is not UTF-8**, in this slug or in another slug's suite read for a binding: a fixture failure and exit 1, never exit 2. Tests: Task 2 (structure and the cli), Task 3 (a binding and a suite).

## Design decisions

The rationale for each non-obvious choice. Each is a decision in `docs/auto-run/steps/S118.json` with its options and evidence.

1. **The Flutter runner is checked against a stand-in.** With no engine artifacts here, the tests run a `testWidgets` binding through a stand-in SDK laid out as `{sdk}/bin/flutter` and `{sdk}/bin/cache/dart-sdk/bin/dart`, shell scripts over the real `dart`, and a stand-in `flutter_test` package (F1, F2, D10). That pins what the tool controls: which bindings it gives to flutter, which executable, the exact arguments, the filter and the report reading. flutter_tools 3.47.7 accepts `--reporter json` and a repeatable `--name` with `splitCommas: false`, requires a `pubspec.yaml` in the working directory and `test_api` in the package configuration, hands `-r json` and `--name` to package:test unchanged, and returns its exit code (T3), so the stand-in prints the protocol the real runner prints. The real run stays Outstanding, deferred to nidana.flutter.2, whose gate `flutter-binding --guarantee G9` first starts it through the tool.
2. **One runner process per binding, in sequence.** Counts and failing names then belong to one binding without reading paths from the report (dart test prints the path as given, flutter test an absolute URI, T3, D1), each binding gets the filter of its own suite's slug, and no two flutter runs contend for its startup lock. A run costs 0.5 to 1 s (D1 to D10, R1 to R3).
3. **Which files are bindings.** Every `behavior/{name}_test.dart` directly under `behavior/`, the pattern structure uses, listed in `## Validation` or not: structure already fails an unlisted one. Conformance libraries and nested files get no behavior line.
4. **A binding's suite.** Exactly one of its relative imports (no scheme, not starting with `/`), resolved against the binding's directory, matches `hsdd/contract/fixture/{slug}/behavior/{name}_conformance.dart`; `{slug}` keys the restriction. The source comes from that slug's snapshot, which the shell reads when it is not the replayed slug (`suiteSlugs`), so one reader serves every Dart source.
5. **The order of a binding's verdicts:** an unreadable binding or suite fails; then an absent package makes it PENDING; then a restriction that admits none of its cases passes it unrun; otherwise it runs. PENDING comes before the restriction because ADR-001 item 9 lists a binding among the fixtures that are PENDING, and its Consequences have a replay whose producing package is absent report every fixture that names it as PENDING, so a gate placed too early fails. A PENDING binding starts no runner, so the rule that no runner gets a filter that admits nothing still holds.
6. **PENDING reads the binding's and its suite's imports.** A conformance library is a behavior library (ADR-001 item 9), and the binding cannot load without it. Bindings still import the implementing package directly, which is how the tool sees it. Other relative imports of a binding (none are committed) are not read.
7. **Runner choice:** a binding with an import or export of a `package:flutter_test/` library runs under `flutter test --no-pub`, any other under `dart test`. It is sound only while conformance libraries import neither test package, which structure now checks (decision 16).
8. **The restriction.** request.dart already resolves a bare id to the replayed slug, so a binding's admitted ids are the restriction's ids of its suite's slug: a bare bus-api id never reaches `bus_activation_test.dart`. Admission reads the suite's case names with the fixture reader (`caseIdOf`: `G{n}` and a space at the start), so G2 never admits G25. The filter is built from ids alone, ascending, `^(G2|G5) ` (D2, D3), so no case text is ever escaped; it holds every admitted id, as the restriction was written.
9. **Reading the report.** A load failure is a visible failed test with no group: every real test sits in the suite's root group, while the load pseudo-test has `groupIDs` `[]` and is hidden when the load succeeds (D0, D0b, D6, D7, D9); its detail is the first non-blank text after `Failed to load "{path}":`. Counts come from visible `testDone` events. Zero cases ran is a failure. No `done` event, or one whose `success` is null, is no report.
10. **The line.** `Passed` gains an optional `detail`; a failing run is a `cases` problem with the counts followed by one `failed-case` problem per failing name; a load failure is a `load` problem. Every count prints, as the summary line's do, so the line has one form. No fourth outcome type, so no other set's switch changes.
11. **The flutter path.** The running `dart` belongs to a Flutter SDK only when it sits at `{root}/bin/cache/dart-sdk/bin/dart` (`dart.exe` on Windows); its flutter is `{root}/bin/flutter` (`flutter.bat`) and must exist. That is ADR-001 item 9's "the flutter that belongs to the SDK of the dart running the tool" (T1), and never another SDK's flutter on PATH.
12. **Environment errors:** no flutter for a binding that would run under it, a runner that cannot start, and a runner that prints no complete report make the slug's behavior set unavailable (`ERROR behavior {slug}: {reason}`, exit 2), as `dart analyze` without a report does for surface and reject. The flutter check runs before any binding of the slug starts.
13. **Progress** is one stderr line per runner started. Runs are still computed before the report prints, as the one analysis requires, and stdout keeps one line per fixture.
14. **An id its slug does not declare is a usage error (64)**, checked right after parsing from the contract texts of the slugs the restriction names, before any snapshot is read: a typo would otherwise admit no case and pass. ADR-001 item 9's list of usage errors begins "such as".
15. **A Dart source that is not UTF-8** keeps a null source and its reason in `SlugSnapshot.undecodable`; structure, which always runs first, fails it with an `encoding` problem; surface and reject skip a library they cannot read; the behavior set fails a binding or a suite it cannot read. The reason reads as the schema set's does for documents, `not UTF-8: Invalid UTF-8 byte (at offset 3)` (U1).
16. **ADR-001 item 4's import rule for conformance libraries** is a structure rule, `conformance-import`: a fixture-text property checked at every gate, as the case-name rule is, and item 12 makes structure the checker of item 3 and the items for the contract's kind once the tool exists.
17. **`findWorkspaceRoot` moves to `lib/src/workspace.dart`**, so `lib/fixture.dart`, which every binding compiles, reaches `json_document.dart` and `workspace.dart` alone instead of the whole shell.
18. **What this phase checks of "topic-model@v1's binding loads and its cases fail on `UnimplementedError`, not on loading".** Against the merged declarations the binding loads; 9 of its 41 cases pass; of the 32 failures, 27 are `UnimplementedError` and 5 are expectation failures on identity equality and an uncopied list (R1). nidana.model D3 keeps `==`, `hashCode` and `toString` `Object`'s until nidana.model.8, so all 32 fail on what the type-level phases leave undelivered, and none on loading. The phase checks the part a gate can see: the tool's line separates a load failure (`load`) from case failures (`cases` and `failed-case`), which Tasks 4 and 5 pin; the gate runs no `--set behavior` over the committed tree, so Task 5 and Task 6 record the real replay of `topic-model --set behavior` (a `cases` line, no `load` problem) and Task 6 records the breakdown by first error with the experiment's reader. The tool does not classify exceptions: which one a case dies of is the implementation's state, not a property of the binding.

## Routed items

From `docs/auto-run/impl-execution-plan.md`, "Routed to later phases", the entries naming nidana.model.6, one line each with its disposition:

- ADR-001 item 4: a conformance library imports neither `package:test` nor `package:flutter_test` (S101 Task 5): taken, Task 2, as the structure rule `conformance-import` (decision 16).
- Lift the package-configuration read out of `_analyze` into a replay-level step and pass a context record to `_run` (S104): taken, Task 1 (Task 5 extends the record).
- Move `SlugPlan` from `analysis.dart` to `run.dart` (S104): taken, Task 1.
- Reorder the no-slug check after `parseRequest`, so a usage error exits 64 even with no fixture directory (S104): taken, Task 1.
- Move `findWorkspaceRoot` out of `shell.dart` so conformance libraries stop compiling the tool (S104): taken, Task 1, into `lib/src/workspace.dart`, pinned by `test/purity_test.dart`.
- A progress line for long test runs (S104): taken, Task 5, on stderr (decision 13).
- Invalid UTF-8 in a Dart fixture as a fixture failure rather than exit 2 (S103): taken, Task 2 (snapshot and structure) and Task 3 (a binding and a suite).
- Validate `--guarantee` ids against the slug's declared guarantees (S101): taken, Task 1, usage error 64 (decision 14).
- A conformance library that no binding in any slug imports covers nothing, which needs a cross-slug view (S101): left routed, to the end-of-nidana.model governance sweep. It changes what ADR-001 item 3's coverage counts (item 3 credits every case name), a reading for hsdd-adr before it is code, and it would give the structure set every slug's bindings on every replay instead of one snapshot; every committed conformance library is imported by a binding today (R7), so it changes no verdict now; and it lies outside the behavior set and this six-task sitting.
- Pin `--guarantee=G1`, one-slug `--all` with a bare id, and the usage text, once a set reads the restriction (S101): taken, Task 1.
- topic-model@v1's binding already loads, and not every failure is `UnimplementedError` (S106): taken, decision 18; Tasks 4 and 5 pin load failure against case failure, Task 6 records the reading.

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_contract_check`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/workspace.dart` | 1 | `findWorkspaceRoot` and `workspacePath`, the shell's file-system helpers that `fixture.dart` also needs |
| `{pkg}/lib/fixture.dart` | 1 | Imports `src/workspace.dart` instead of `src/shell.dart` |
| `{pkg}/lib/src/run.dart` | 1 | `SlugPlan`, `slugPlan`, `readsPackages` beside `setsOf` and `plannedSets` |
| `{pkg}/lib/src/request.dart` | 1 | `guaranteeError` |
| `{pkg}/lib/src/analysis.dart` | 1 | `SlugPlan` imported from `run.dart` |
| `{pkg}/lib/src/snapshot.dart` | 2 | `decodeSource`, `SlugSnapshot.undecodable` |
| `{pkg}/lib/src/structure.dart` | 2, 3 | The `encoding` and `conformance-import` rules; `caseIdOf` in place of its private reader |
| `{pkg}/lib/src/outcome.dart`, `report.dart` | 3 | `Passed.detail` and its line |
| `{pkg}/lib/src/dart_library.dart` | 3 | `caseIdOf` |
| `{pkg}/lib/src/behavior.dart` | 3 | Binding plans, runner arguments, the name filter, the flutter path |
| `{pkg}/lib/src/test_report.dart` | 4 | The runner's JSON report, read; a run's outcome |
| `{pkg}/lib/src/shell.dart` | 1, 2, 5 | The replay's order, the package configuration, the context record, snapshots read as bytes, the behavior runs |
| `{pkg}/test/support/sample.dart` | 2, 3 | `snapshotOf` with undecodable sources; `behaviorFiles`, `hostFiles` |
| `{pkg}/test/support/workspace.dart`, `runners.dart`, `seed.dart` | 1, 5 | Imports from `workspace.dart`; `seedWorkspace(..., runners: true)`; the stand-in SDK |
| `{pkg}/test/purity_test.dart`, `behavior_test.dart`, `test_report_test.dart`, `behavior_cli_test.dart` | 1, 3, 4, 5 | New tests |
| `{pkg}/test/request_test.dart`, `cli_test.dart`, `structure_test.dart`, `report_test.dart`, `dart_library_test.dart`, `analysis_test.dart` | 1 to 5 | Extended tests |
| `hsdd/verify/nidana.model.6.verification.md` | 6 | The verification doc |

---

### Task 1: Replay plumbing and the restriction's command line

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9), in the pub workspace at the repository root. Run every command from the repository root with `fvm dart`. This task lands the routed fixes the behavior set is written against: the package configuration is read once per replay, before the analysis, into a `_Context` record that `_run` reads (the behavior set of Task 5 needs the package names too); `SlugPlan` moves to `run.dart`; a usage error is reported before the no-slug check, so it exits 64 even with no fixture directory (nidana.model D2 item 1); a `--guarantee` id its slug does not declare is a usage error; `findWorkspaceRoot` moves to `lib/src/workspace.dart`, so `lib/fixture.dart` stops importing the shell; and the restriction's command-line forms get pinned. The behavior set itself stays `SetUnavailable(notImplemented)` in this task.

**Files:**
- Create: `packages/nidana_contract_check/lib/src/workspace.dart`
- Modify: `packages/nidana_contract_check/lib/fixture.dart`, `lib/src/shell.dart`, `lib/src/run.dart`, `lib/src/analysis.dart`, `lib/src/request.dart`
- Modify: `packages/nidana_contract_check/test/support/seed.dart`, `test/support/workspace.dart` (import `findWorkspaceRoot` from `src/workspace.dart`), `test/analysis_test.dart` (import `SlugPlan` from `src/run.dart`)
- Test: `packages/nidana_contract_check/test/request_test.dart`, `test/cli_test.dart`, `test/purity_test.dart` (new)

**Interfaces:**
- Consumes (nidana.model.1 and .2): `parseRequest`, `Request` (`slugs`, `sets`, `restriction`), `GuaranteeRef` (`({String slug, int number})`), `usage`, `UsageError`, `ParsedRequest` in `request.dart`; `readContract(slug, text).guarantees` in `contract.dart`; `plannedSets` in `run.dart`; `packageNamesOf`, `packageConfigPath` in `packages.dart`; `readDartLibrary(source).directives` in `dart_library.dart`; test support `seed`, `runTool`, `sampleFiles`, `toolFiles`, and in `cli_test.dart` the helpers `lines`, `all` and the constant `s`.
- Produces:

```dart
// lib/src/workspace.dart (imports dart:io and package:path only)
/// The nearest ancestor of [start], [start] included, that holds hsdd/contract/; null when none does.
Directory? findWorkspaceRoot(Directory start);
/// The platform path of the `/`-separated [path] from [root].
String workspacePath(Directory root, String path);

// lib/src/run.dart
/// One slug of a replay: its [snapshot] and the sets planned over it, in order.
typedef SlugPlan = ({SlugSnapshot snapshot, List<CheckSet> sets});
/// The [SlugPlan] of [snapshot] under [request]: the sets [plannedSets] runs over it.
SlugPlan slugPlan(Request request, SlugSnapshot snapshot);
/// Whether [set] reads the workspace's package configuration: surface, reject and behavior do.
bool readsPackages(CheckSet set);

// lib/src/request.dart
/// The usage error of the first id of [request]'s restriction, in command order, that its slug
/// does not declare; null when every id is declared or the request is unrestricted. [declared]
/// holds, for each slug the restriction names, the ids its contract text declares, or null when
/// it has no contract text.
String? guaranteeError(Request request, Map<String, Set<int>?> declared);

// lib/src/shell.dart (private)
sealed class _Packages {}                       // _PackageNames(Set<String> names) | _NoPackages(String reason)
sealed class _Analysis {}                       // _Analyzed(Map<String, List<Diagnostic>> diagnostics) | _AnalysisUnavailable(String reason)
typedef _Context = ({_Packages packages, _Analysis analysis});
SetRun _run(CheckSet set, SlugSnapshot snapshot, _Context context);
```

- [ ] **Step 1: Write the failing tests**

In `test/request_test.dart` add:

```dart
  test('--guarantee takes the = form, and a bare id under --all of one slug', () {
    expect(
      parsed(<String>['topic-model', '--guarantee=G1']).restriction,
      <GuaranteeRef>{(slug: 'topic-model', number: 1)},
    );
    final ParseResult one = parseRequest(
      <String>['--all', '--guarantee', 'G1'],
      slugs: const <String>{'sample'},
    );
    expect(
      (one as ParsedRequest).request.restriction,
      <GuaranteeRef>{(slug: 'sample', number: 1)},
    );
    expect(
      usageError(<String>['--all', '--guarantee', 'G1']),
      "bare id 'G1' names no single slug: the command replays 4 slugs; write {slug}/G1",
    );
  });
  group('guaranteeError', () {
    test('null when unrestricted, and when every id is declared', () {
      expect(guaranteeError(parsed(<String>['topic-model']), const <String, Set<int>?>{}), isNull);
      expect(
        guaranteeError(
          parsed(<String>['topic-model', '--guarantee', 'G1,G2']),
          const <String, Set<int>?>{'topic-model': <int>{1, 2}},
        ),
        isNull,
      );
    });
    test('the first undeclared id in command order', () {
      expect(
        guaranteeError(
          parsed(<String>['topic-model', '--guarantee', 'G1,G99,G98']),
          const <String, Set<int>?>{'topic-model': <int>{1, 2}},
        ),
        "unknown guarantee 'topic-model/G99': hsdd/contract/topic-model.md declares no G99",
      );
    });
    test('a qualified id is checked against its own slug', () {
      const Map<String, Set<int>?> declared = <String, Set<int>?>{
        'topology-dsl': <int>{1, 2, 3},
      };
      expect(
        guaranteeError(parsed(<String>['topic-model', '--guarantee', 'topology-dsl/G3']), declared),
        isNull,
      );
      expect(
        guaranteeError(parsed(<String>['topic-model', '--guarantee', 'topology-dsl/G4']), declared),
        "unknown guarantee 'topology-dsl/G4': hsdd/contract/topology-dsl.md declares no G4",
      );
    });
    test('a slug without a contract text declares nothing', () {
      expect(
        guaranteeError(
          parsed(<String>['bus-api', '--guarantee', 'G1']),
          const <String, Set<int>?>{'bus-api': null},
        ),
        "unknown guarantee 'bus-api/G1': no contract text at hsdd/contract/bus-api.md",
      );
    });
  });
```

In `test/cli_test.dart` import `package:nidana_contract_check/src/request.dart` with `show usage`, and add:

```dart
  test('a usage error exits 64 even when no slug directory exists; --all then exits 2', () async {
    final Directory root = seed(const <String, String>{'hsdd/contract/readme.md': 'x\n'});
    final ProcessResult named = await runTool(<String>['sample'], workingDirectory: root);
    expect(named.exitCode, 64, reason: all(named));
    expect(named.stderr as String, contains("unknown slug 'sample'"));
    final ProcessResult every = await runTool(<String>['--all'], workingDirectory: root);
    expect(every.exitCode, 2, reason: all(every));
    expect(every.stderr as String, 'error: no slug directory under hsdd/contract/fixture/\n');
  });
  test('the usage text follows the message, exactly', () async {
    final ProcessResult r = await runTool(<String>['nosuch'], workingDirectory: seed(sampleFiles));
    expect(r.exitCode, 64, reason: all(r));
    expect(
      r.stderr as String,
      "error: unknown slug 'nosuch': no directory hsdd/contract/fixture/nosuch/\n$usage\n",
    );
    expect(usage, '''
usage: fvm dart run nidana_contract_check {slug}... [--set {set},...] [--guarantee {id},...]
       fvm dart run nidana_contract_check --all [--set {set},...] [--guarantee {id},...]
sets: structure, surface, reject, behavior, schema, file, cli
ids: G{n} for the one slug named, or {slug}/G{n}''');
  });
  test('an id its slug does not declare is a usage error (64); a qualified id is checked against its own slug', () async {
    final Directory root = seed(<String, String>{...sampleFiles, ...toolFiles});
    final ProcessResult bare = await runTool(
      <String>['sample', '--set', 'structure', '--guarantee', 'G9'],
      workingDirectory: root,
    );
    expect(bare.exitCode, 64, reason: all(bare));
    expect(
      bare.stderr as String,
      allOf(
        contains("error: unknown guarantee 'sample/G9': hsdd/contract/sample.md declares no G9"),
        contains('usage: '),
      ),
    );
    final ProcessResult other = await runTool(
      <String>['sample', '--set', 'structure', '--guarantee', 'tool/G2'],
      workingDirectory: root,
    );
    expect(other.exitCode, 0, reason: all(other));
    final ProcessResult unknown = await runTool(
      <String>['sample', '--set', 'structure', '--guarantee', 'tool/G3'],
      workingDirectory: root,
    );
    expect(unknown.exitCode, 64, reason: all(unknown));
    expect(
      unknown.stderr as String,
      contains("unknown guarantee 'tool/G3': hsdd/contract/tool.md declares no G3"),
    );
  });
  test('a package configuration that is not UTF-8 is not a package configuration (2)', () async {
    final Directory root = seed(sampleFiles);
    File('${root.path}/.dart_tool/package_config.json')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(<int>[0xff]);
    final StringBuffer err = StringBuffer();
    expect(
      await runCli(<String>['sample', '--set', 'surface'],
          workingDirectory: root, out: StringBuffer(), err: err),
      2,
    );
    expect(
      err.toString(),
      contains('ERROR surface sample: .dart_tool/package_config.json is not a package configuration'),
    );
  });
```

Create `test/purity_test.dart`, which pins the shell boundary (nidana.model D2 item 5) by reading directives with the tool's own reader:

```dart
// packages/nidana_contract_check/test/purity_test.dart
import 'dart:io';

import 'package:nidana_contract_check/src/dart_library.dart';
import 'package:nidana_contract_check/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// packages/nidana_contract_check/lib/ of the workspace that holds the test run.
final String lib = p.join(
  findWorkspaceRoot(Directory.current)!.path,
  'packages',
  'nidana_contract_check',
  'lib',
);

List<String> directivesOf(String path) =>
    readDartLibrary(File(path).readAsStringSync()).directives;

void main() {
  test('no library under lib/src/ but shell.dart and workspace.dart imports dart:io', () {
    final List<String> importing = <String>[
      for (final FileSystemEntity f in Directory(p.join(lib, 'src')).listSync())
        if (f is File && directivesOf(f.path).contains('dart:io')) p.basename(f.path),
    ]..sort();
    expect(importing, <String>['shell.dart', 'workspace.dart']);
  });
  test('fixture.dart, which every conformance library imports, reaches json_document.dart and workspace.dart alone', () {
    expect(relativeClosure('fixture.dart'), <String>{'src/json_document.dart', 'src/workspace.dart'});
  });
}
```

`relativeClosure(String from)` is a helper in the same file: the set of paths, relative to `lib`, of every library reached from `lib/{from}` through directives that have no scheme, each resolved against its importer's directory, `from` itself excluded.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/request_test.dart packages/nidana_contract_check/test/purity_test.dart packages/nidana_contract_check/test/cli_test.dart`
Expected: FAIL: `request_test.dart` does not compile (`guaranteeError` is not defined) and `purity_test.dart` does not compile (`src/workspace.dart` does not exist). Keep that output. Once those exist, the cli tests would fail too: `sample` with no fixture directory exits 2, an undeclared id exits 0, and a package configuration that is not UTF-8 exits 2 with `error: Failed to decode data using encoding 'utf-8'`.

- [ ] **Step 3: Implement**

`lib/src/workspace.dart`: move `findWorkspaceRoot` and the helpers it needs from `shell.dart`; add `workspacePath` (the body of `shell.dart`'s `_workspacePath`), which `shell.dart` then calls in place of its private copy. `lib/fixture.dart` imports `src/workspace.dart` in place of `src/shell.dart`; its behavior does not change. Move `SlugPlan` to `run.dart` with `slugPlan` (the body of `shell.dart`'s `_planOf`) and `readsPackages` (an exhaustive `switch` over `CheckSet`: `surface`, `reject` and `behavior` true; nidana.model.7 adds `file` and `cli` when they read it for PENDING); `analysis.dart` imports `SlugPlan` from `run.dart`.

`guaranteeError` walks `request.restriction` in its iteration order (command order: `Set.unmodifiable` keeps insertion order) and returns, for the first ref whose number is not in `declared[ref.slug]`, `unknown guarantee '{slug}/G{n}': hsdd/contract/{slug}.md declares no G{n}`, or, when `declared[ref.slug]` is null, `unknown guarantee '{slug}/G{n}': no contract text at hsdd/contract/{slug}.md`.

`shell.dart`'s `_replay`, in this order:

1. `discoverSlugs(root)`.
2. `parseRequest(arguments, slugs: slugs)`. A `UsageError`: `error: {message}` and `usage` to `err`, exit 64.
3. `request.slugs` empty, which only `--all` with no slug directory gives: `error: no slug directory under hsdd/contract/fixture/` to `err`, exit 2.
4. When `request.restriction` is not null: for each slug it names, `hsdd/contract/{slug}.md` read as `readContract(slug, text).guarantees.toSet()`, or null when the file is absent; a `guaranteeError` is reported as in step 2, exit 64. No snapshot has been read yet.
5. `readSnapshot` and `slugPlan` for each slug of the request, in request order.
6. `_readPackages(root, plans)`: when no plan holds a set that `readsPackages`, `_PackageNames(const <String>{})`, never consulted. Otherwise read `.dart_tool/package_config.json` as bytes: absent gives `_NoPackages('no package configuration at .dart_tool/package_config.json; run fvm dart pub get')`; bytes that are not UTF-8 (strict decode) or a text `packageNamesOf` rejects give `_NoPackages('.dart_tool/package_config.json is not a package configuration')`.
7. `_analyze(root, plans, packages, dart: dart)`: no plan holds a set that `readsAnalysis` gives `_Analyzed(const {})`; `_NoPackages(reason)` gives `_AnalysisUnavailable(reason)`; otherwise the targets and the one `dart analyze` exactly as now. `_Analyzed` no longer carries the package names.
8. `_run(set, snapshot, context)` for each planned set with `context = (packages: ..., analysis: ...)`: `surface` and `reject` take the package names from `context.packages` and the diagnostics from `context.analysis`, and are `SetUnavailable` with whichever reason either gives; `behavior`, `file` and `cli` stay `SetUnavailable(set, slug, notImplemented(set))`.
9. Print every run, then the summary; return `exitCodeOf`.

Update the dartdoc of `runCli`, `_replay` and `_analyze` to say what they now do. Every existing test keeps passing unchanged, the import changes of the Files list aside.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check --all --set structure; echo "exit: $?"`
Expected: `102 fixtures: 102 passed, 0 failed, 0 pending` and `exit: 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/workspace.dart packages/nidana_contract_check/lib/fixture.dart packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/lib/src/run.dart packages/nidana_contract_check/lib/src/analysis.dart packages/nidana_contract_check/lib/src/request.dart packages/nidana_contract_check/test/support/seed.dart packages/nidana_contract_check/test/support/workspace.dart packages/nidana_contract_check/test/analysis_test.dart packages/nidana_contract_check/test/request_test.dart packages/nidana_contract_check/test/cli_test.dart packages/nidana_contract_check/test/purity_test.dart
git commit -m "feat(contract_check): validate guarantee ids and read the package configuration once per replay" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 2: Structure: Dart sources that are not UTF-8, and what a conformance library imports

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. Today `readSnapshot` reads each Dart source with `readAsStringSync`, so a fixture that is not UTF-8 throws and the replay exits 2 as if the environment were broken. This task decodes sources in the pure core, keeps an undecodable one as a reason on the snapshot, and has the `structure` set, which runs first at every replay, fail it with exit 1. It also adds ADR-001 item 4's rule that a conformance library imports neither `package:test` nor `package:flutter_test`, which no set checked: the behavior set picks a binding's runner from the binding's own imports, which is sound only while suites import neither (ADR-001 item 12 makes structure the checker of the items for the contract's kind). No committed fixture breaks either rule (R5).

**Files:**
- Modify: `packages/nidana_contract_check/lib/src/snapshot.dart`
- Modify: `packages/nidana_contract_check/lib/src/shell.dart` (`readSnapshot`)
- Modify: `packages/nidana_contract_check/lib/src/structure.dart`
- Modify: `packages/nidana_contract_check/test/support/sample.dart` (`snapshotOf`)
- Test: `packages/nidana_contract_check/test/structure_test.dart`, `test/cli_test.dart`

**Interfaces:**
- Consumes: Task 1's shell; nidana.model.1: `SlugSnapshot`, `holdsSource`, `checkStructure`, `StructureRule`, `readDartLibrary`; test support `snapshotOf(slug, files, {bytes})`, `changed`, `seed`, `runTool`, and in `structure_test.dart` the helpers `check`, `at`, `conformanceWith` and the constant `s`.
- Produces:

```dart
// lib/src/snapshot.dart
/// A Dart source's bytes read as UTF-8: [SourceText], or [SourceNotUtf8] with the reason.
sealed class SourceDecoding { const SourceDecoding(); }
final class SourceText extends SourceDecoding { const SourceText(this.text); final String text; }
final class SourceNotUtf8 extends SourceDecoding { const SourceNotUtf8(this.reason); final String reason; }
/// [bytes] decoded as UTF-8, malformed bytes rejected; the reason reads
/// `not UTF-8: {message} (at offset {offset})`, or `not UTF-8: {message}` without an offset.
SourceDecoding decodeSource(List<int> bytes);

final class SlugSnapshot {
  const SlugSnapshot({/* as now */, this.undecodable = const <String, String>{}});
  /// Each file [holdsSource] accepts whose bytes are not UTF-8, by its relative `/`-separated
  /// path, with the reason [decodeSource] gives; its entry in [files] is null.
  final Map<String, String> undecodable;
}

// lib/src/structure.dart: StructureRule gains, after srcImport,
encoding('encoding'), conformanceImport('conformance-import')
```

- [ ] **Step 1: Write the failing tests**

In `test/structure_test.dart` (import `dart:convert` and `package:nidana_contract_check/src/snapshot.dart`) add:

```dart
  group('Dart sources that are not UTF-8', () {
    test('decodeSource reads UTF-8 and names the first malformed byte', () {
      expect((decodeSource(utf8.encode('// é\n')) as SourceText).text, '// é\n');
      expect(
        (decodeSource(<int>[0x2f, 0x2f, 0x20, 0xff, 0x0a]) as SourceNotUtf8).reason,
        'not UTF-8: Invalid UTF-8 byte (at offset 3)',
      );
    });
    test('one fails structure at its path with the reason, and is no library', () {
      final SlugSnapshot snapshot = snapshotOf(
        'sample',
        sampleFiles,
        bytes: <String, List<int>>{'${s}reject/latin1.dart': <int>[0x2f, 0x2f, 0x20, 0xff, 0x0a]},
      );
      expect(snapshot.files['reject/latin1.dart'], isNull);
      expect(snapshot.undecodable, <String, String>{
        'reject/latin1.dart': 'not UTF-8: Invalid UTF-8 byte (at offset 3)',
      });
      expect(at(checkStructure(snapshot), '${s}reject/latin1.dart'), <String>[
        'encoding (not UTF-8: Invalid UTF-8 byte (at offset 3))',
      ]);
    });
  });
  group('conformance-import', () {
    test('a conformance library that imports package:test or exports package:flutter_test fails', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformanceWith(
          "import 'package:matcher/expect.dart';\n",
          "import 'package:matcher/expect.dart';\n"
              "import 'package:test/test.dart';\n"
              "export 'package:flutter_test/flutter_test.dart';\n",
        ),
      });
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
        'conformance-import (package:test/test.dart)',
        'conformance-import (package:flutter_test/flutter_test.dart)',
      ]);
    });
    test('a binding may import them, and package:test_api is neither', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformanceWith(
          "import 'package:matcher/expect.dart';\n",
          "import 'package:matcher/expect.dart';\nimport 'package:test_api/scaffolding.dart';\n",
        ),
      });
      expect(o, everyElement(isA<Passed>()));
    });
  });
```

The clean sample's binding imports `package:test/test.dart` and passes already, which the existing clean-sample test pins.

In `test/cli_test.dart` add:

```dart
  test('a Dart fixture that is not UTF-8 fails structure (1), never an environment error', () async {
    final Directory root = seed(sampleFiles);
    File('${root.path}/${s}reject/latin1.dart').writeAsBytesSync(<int>[0x2f, 0x2f, 0x20, 0xff, 0x0a]);
    final ProcessResult r = await runTool(<String>['sample', '--set', 'structure'], workingDirectory: root);
    expect(r.exitCode, 1, reason: all(r));
    expect(
      lines(r),
      contains('FAIL structure ${s}reject/latin1.dart: encoding (not UTF-8: Invalid UTF-8 byte (at offset 3))'),
    );
    expect(r.stderr as String, isEmpty);
  });
```

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/structure_test.dart packages/nidana_contract_check/test/cli_test.dart`
Expected: FAIL: `structure_test.dart` does not compile (`decodeSource` is not defined). Keep that output; the cli test would fail on exit 2 with `error: Failed to decode data using encoding 'utf-8'` on stderr.

- [ ] **Step 3: Implement**

`decodeSource` is `utf8.decode(bytes, allowMalformed: false)` with the `FormatException`'s message and offset in the reason, as `json_document.dart` words it. `readSnapshot` reads each file `holdsSource` accepts as bytes and decodes it with `decodeSource`: `SourceText` gives its `files` entry, `SourceNotUtf8` a null entry and an `undecodable` entry; update its dartdoc, which says bytes are never decoded there. `snapshotOf` in `test/support/sample.dart` does the same for the paths `holdsSource` accepts, so it never throws on such bytes.

In `structure.dart`: for each entry of `snapshot.undecodable`, a problem `encoding ({reason})` at `{fixture directory}{relative path}`, which `_outcomes` then sorts among the other failing paths (a source without text is in no library list, so no other rule reads it). For each library matching the conformance-library pattern, after its case-name problems and in directive order, a problem `conformance-import ({uri})` for each import or export whose URI begins `package:test/` or `package:flutter_test/`. Update the library dartdoc's list of what the set checks.

- [ ] **Step 4: Run the tests, the formatter, the analyzer and the committed tree**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check --all --set structure; echo "exit: $?"`
Expected: `102 fixtures: 102 passed, 0 failed, 0 pending` and `exit: 0`: no committed conformance library imports a test package (R5) and every committed source is UTF-8.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/snapshot.dart packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/lib/src/structure.dart packages/nidana_contract_check/test/support/sample.dart packages/nidana_contract_check/test/structure_test.dart packages/nidana_contract_check/test/cli_test.dart
git commit -m "feat(contract_check): structure fails Dart sources that are not UTF-8 and suites that import a test package" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 3: Binding plans

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 items 4 and 9). Run every command from the repository root with `fvm dart`. `behavior.dart` is pure: it decides, for each binding of a slug, what the behavior set does with it, from the snapshots alone, and builds the runner's command line. A binding is a file `behavior/{name}_test.dart` directly under a slug's `behavior/`; it imports exactly one conformance library by relative path, possibly another slug's (`hsdd/contract/fixture/bus-api/behavior/bus_activation_test.dart` imports `../../topology-dsl/behavior/live_conformance.dart`), and that library's slug keys the `--guarantee` restriction. Facts: `dart test --name '^(G2) '` runs the cases whose names begin with `G2 ` and not `G25 ...` (D2, D3); the fixture reader reads 41, 24 and 43 case names from topic-model's, topology-dsl's recording and topology-ir's suites, exactly the cases their bindings register at run time (R1 to R3, R6); the running `dart` is `{flutter root}/bin/cache/dart-sdk/bin/dart` and its flutter is `{flutter root}/bin/flutter` (T1).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/behavior.dart`
- Modify: `packages/nidana_contract_check/lib/src/outcome.dart`, `lib/src/report.dart`, `lib/src/dart_library.dart`, `lib/src/structure.dart`
- Modify: `packages/nidana_contract_check/test/support/sample.dart` (the behavior samples)
- Test: `packages/nidana_contract_check/test/behavior_test.dart` (new), `test/report_test.dart`, `test/dart_library_test.dart`

**Interfaces:**
- Consumes: Task 2: `SlugSnapshot.undecodable`, `decodeSource` (through `snapshotOf`); nidana.model.1 and .2: `readDartLibrary`, `DartLibrary.directives`, `CaseList.cases`, `CaseName.name`, `absentPackages`, `packageConfigPath`, `GuaranteeRef`, `CheckSet`, `outcomeLine`, `formatIds`, `Rule`, `Passed`, `Failed`, `Pending`, `Problem`, `fixtureDirectory`, `checkStructure`; test support `snapshotOf`, `changed`, `sampleContract`, `sampleFiles`.
- Produces:

```dart
// lib/src/outcome.dart
final class Passed extends FixtureOutcome {
  const Passed(super.path, {this.detail});
  /// What the set adds to the fixture's line, after a colon; null for nothing.
  final String? detail;
}
// lib/src/report.dart: outcomeLine of a Passed is `PASS {set} {path}`, or `PASS {set} {path}: {detail}`.

// lib/src/dart_library.dart
/// The id a case name begins with, `G{n}` and a space; null when it begins with none, or when [name] is null.
int? caseIdOf(String? name);   // structure.dart's _caseId and _caseNameId give way to it

// lib/src/behavior.dart
/// The runners a binding runs under (ADR-001 item 9), each with its command for report text.
enum Runner {
  dart('dart test'),
  flutter('flutter test --no-pub');
  const Runner(this.label);
  final String label;
}

/// The rules of the behavior set.
enum BehaviorRule implements Rule {
  binding('binding'),        // the binding can be read
  suite('suite'),            // it imports exactly one conformance library that can be read
  load('load'),              // it loads under its runner
  cases('cases'),            // a case runs, and every case it runs passes
  failedCase('failed-case'); // one failing case, by name
  const BehaviorRule(this.label);
  @override
  final String label;
}

/// What the behavior set does with one binding.
sealed class BindingPlan {
  const BindingPlan();
  /// The binding's path from the workspace root.
  String get path;
}

/// Decided without running: a fixture defect ([Failed]), [Pending], or [Passed] unrun.
final class BindingSettled extends BindingPlan {
  const BindingSettled(this.outcome);
  final FixtureOutcome outcome;
  @override
  String get path => outcome.path;
}

/// Run the binding at [path] under [runner]; [admitted] is null when unrestricted, else the
/// restriction's ids of [suiteSlug], at least one of which begins one of the suite's case names.
final class BindingRun extends BindingPlan {
  const BindingRun({required this.path, required this.runner, required this.suiteSlug, required this.admitted});
  @override
  final String path;
  final Runner runner;
  final String suiteSlug;
  final Set<int>? admitted;
}

/// The slugs of the conformance libraries the bindings of [snapshot] import, its own included
/// when they import one of its own; a binding whose source was not read contributes none.
Set<String> suiteSlugs(SlugSnapshot snapshot);

/// One plan per binding of [snapshot], ascending by path. [snapshots] holds the snapshots of the
/// other slugs whose suites the bindings import (more may be present); [packages] are the
/// workspace's package names.
List<BindingPlan> planBindings(
  SlugSnapshot snapshot, {
  required Map<String, SlugSnapshot> snapshots,
  required Set<String> packages,
  required Set<GuaranteeRef>? restriction,
});

/// The test-name filter of [ids], ascending, anchored at the start of the name: `^(G2|G5) `.
String nameFilter(Set<int> ids);

/// The runner's arguments for [run], from the workspace root: `test`, then `--no-pub` for
/// flutter, `--reporter json`, `--name {nameFilter}` when restricted, and the binding's path.
List<String> testArguments(BindingRun run);

/// The flutter of the Flutter SDK that holds [dart], when [dart] sits at
/// `{root}/bin/cache/dart-sdk/bin/dart` (or `dart.exe`): `{root}/bin/flutter` (or `flutter.bat`);
/// null for any other path. Whether the file exists is the shell's to check.
String? flutterBeside(String dart);
```

- [ ] **Step 1: Write the failing tests and the behavior samples**

Add to `test/support/sample.dart` the samples the behavior tests share. Each raw string starts on the line after `r'''` and ends with exactly one newline. `behaviorFiles` is a `final Map<String, String>`: `sampleFiles` with `hsdd/contract/sample.md` replaced by `sampleContract` whose binding bullet is followed by the bullet ``- binding: `hsdd/contract/fixture/sample/behavior/widget_impl_test.dart` binds the suite, under `testWidgets`.``, and with these three libraries under `hsdd/contract/fixture/sample/behavior/`. `sample_conformance.dart` (it compiles against the seeded workspace's stand-in `Sample`, whose `count` is 0):

```dart
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:sample/sample.dart';

abstract interface class SampleHarness {
  Future<void> settle();
}

final List<ConformanceCase<SampleHarness>> sampleConformance =
    <ConformanceCase<SampleHarness>>[
  (
    name: 'G2 a sample counts from zero',
    body: (SampleHarness h) async => expect(const Sample().count, 0),
  ),
  (name: 'G2 a second case of G2', body: (SampleHarness h) async {}),
  (
    name: 'G3 a sample is redacted',
    body: (SampleHarness h) async => expect(const Sample().count, 1),
  ),
  (
    name: 'G1 a body not implemented yet',
    body: (SampleHarness h) async => throw UnimplementedError('G1'),
  ),
];
```

`sample_impl_test.dart`:

```dart
// ignore: unused_import
import 'package:sample/sample.dart';
import 'package:test/test.dart';

import 'sample_conformance.dart';

final class _Harness implements SampleHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
```

`widget_impl_test.dart` is `sample_impl_test.dart` with `import 'package:flutter_test/flutter_test.dart';` in place of the `package:test` import (placed first, imports sorted) and the registration `testWidgets(c.name, (WidgetTester tester) => c.body(_Harness()));`.

`hostFiles` (a `const Map<String, String>`) is a second slug, `host`, whose one binding binds the sample's suite. `hsdd/contract/host.md`:

```markdown
---
id: host
version: v1
status: stable
kind: api
---

# host@v1

## Guarantees / invariants

- **G1** a host binds another contract's suite.

## Validation

- binding: `hsdd/contract/fixture/host/behavior/host_impl_test.dart` binds sample@v1's suite (`../../sample/behavior/sample_conformance.dart`), under `dart test`.
- not executable: G1, a property no fixture shows; checked by nidana.model's gates
```

`hsdd/contract/fixture/host/behavior/host_impl_test.dart`:

```dart
import 'package:test/test.dart';

import '../../sample/behavior/sample_conformance.dart';

final class _Harness implements SampleHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
```

Create `test/behavior_test.dart`:

```dart
// packages/nidana_contract_check/test/behavior_test.dart
import 'package:nidana_contract_check/src/behavior.dart';
import 'package:nidana_contract_check/src/ids.dart';
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/structure.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String h = 'hsdd/contract/fixture/host/';
const Set<String> everyPackage = <String>{
  'flutter_test', 'matcher', 'nidana_contract_check', 'sample', 'test',
};

/// A settled plan as its report line; a run as `RUN {path} {runner} {suite slug} {ids, or all}`.
String describe(BindingPlan plan) => switch (plan) {
  BindingSettled(:final FixtureOutcome outcome) => outcomeLine(CheckSet.behavior, outcome),
  BindingRun(:final String path, :final Runner runner, :final String suiteSlug, :final Set<int>? admitted) =>
    'RUN $path ${runner.label} $suiteSlug ${admitted == null ? 'all' : formatIds(admitted)}',
};

final SlugSnapshot sample = snapshotOf('sample', behaviorFiles);

List<String> plans(
  SlugSnapshot snapshot, {
  Map<String, SlugSnapshot> others = const <String, SlugSnapshot>{},
  Set<String> packages = everyPackage,
  Set<GuaranteeRef>? restriction,
}) => planBindings(snapshot, snapshots: others, packages: packages, restriction: restriction)
    .map(describe)
    .toList();
```

and these tests, each a `test(...)` in `main` with the name given. In them `(sample, 4)` is short for the `GuaranteeRef` `(slug: 'sample', number: 4)`, a restriction is a `Set<GuaranteeRef>` passed as `restriction:`, and a line given without its prefix (`suite (imports no conformance library)`) is the binding's whole `FAIL behavior {path}: ...` line:

- `the behavior and host samples pass the structure set`: `checkStructure(sample)` and `checkStructure(snapshotOf('host', hostFiles))` are every one `Passed`.
- `unrestricted, each binding runs every case under the runner its imports choose`: `plans(sample)` is `['RUN ${s}behavior/sample_impl_test.dart dart test sample all', 'RUN ${s}behavior/widget_impl_test.dart flutter test --no-pub sample all']`.
- `a bare id restricts the bindings of the replayed slug's own suite`: with `restriction: {(slug: 'sample', number: 2)}`, both lines end `sample G2`.
- `an id no case begins with: not run, passing`: with `{(slug: 'sample', number: 4)}`, `['PASS behavior ${s}behavior/sample_impl_test.dart: not run: the restriction admits no case of ${s}behavior/sample_conformance.dart', 'PASS behavior ${s}behavior/widget_impl_test.dart: not run: the restriction admits no case of ${s}behavior/sample_conformance.dart']`.
- `the id is anchored: G2 admits no G25 case`: over `snapshotOf('sample', changed(behaviorFiles, {'${s}behavior/sample_conformance.dart': conformance.replaceAll("name: 'G2 ", "name: 'G25 ")}))`, where `conformance` is `behaviorFiles['${s}behavior/sample_conformance.dart']!`, `{(sample, 2)}` gives the two not-run lines and `{(sample, 25)}` two runs ending `sample G25`.
- `a binding of another slug's suite is restricted by that slug's ids alone`: for `snapshotOf('host', hostFiles)` with `others: {'sample': sample}`: `{(host, 1)}` gives `['PASS behavior ${h}behavior/host_impl_test.dart: not run: the restriction admits no case of ${s}behavior/sample_conformance.dart']`, although `G1 a body not implemented yet` begins with G1; `{(sample, 3)}` gives `['RUN ${h}behavior/host_impl_test.dart dart test sample G3']`; `{(host, 1), (sample, 2), (sample, 3)}` gives `['RUN ${h}behavior/host_impl_test.dart dart test sample G2, G3']`; unrestricted gives `['RUN ${h}behavior/host_impl_test.dart dart test sample all']`.
- `a suite that is absent or not UTF-8 fails the binding`: host with no `others` gives `['FAIL behavior ${h}behavior/host_impl_test.dart: suite (${s}behavior/sample_conformance.dart does not exist)']`; with `others: {'sample': snapshotOf('sample', behaviorFiles, bytes: {'${s}behavior/sample_conformance.dart': [0xff]})}` it gives `['FAIL behavior ${h}behavior/host_impl_test.dart: suite (${s}behavior/sample_conformance.dart: not UTF-8: Invalid UTF-8 byte (at offset 0))']`.
- `a binding that is not UTF-8, or imports no or two conformance libraries, fails`: host with `bytes: {'${h}behavior/host_impl_test.dart': [0xff]}` gives `['FAIL behavior ${h}behavior/host_impl_test.dart: binding (not UTF-8: Invalid UTF-8 byte (at offset 0))']`; the host binding without its relative import gives `suite (imports no conformance library)`; with `import '../../other/behavior/other_conformance.dart';` added after it, `suite (imports 2 conformance libraries: ${s}behavior/sample_conformance.dart, hsdd/contract/fixture/other/behavior/other_conformance.dart)` (directive order).
- `an absent package of the binding or of its suite alone makes the binding PENDING, before the restriction`: `packages: everyPackage.difference({'sample'})` gives both sample bindings `PENDING behavior {path}: package sample is absent from .dart_tool/package_config.json`, and so does adding `restriction: {(sample, 4)}`; for host with `others: {'sample': sample}`, `everyPackage.difference({'matcher'})` gives `['PENDING behavior ${h}behavior/host_impl_test.dart: package matcher is absent from .dart_tool/package_config.json']` (only the suite imports matcher); `everyPackage.difference({'flutter_test'})` gives `['RUN ${s}behavior/sample_impl_test.dart dart test sample all', 'PENDING behavior ${s}behavior/widget_impl_test.dart: package flutter_test is absent from .dart_tool/package_config.json']`.
- `only files directly under behavior/ named _test.dart are bindings`: adding `${s}behavior/sub/nested_test.dart` (a copy of `sample_impl_test.dart` importing `../sample_conformance.dart`) leaves `plans(...)` the two runs of the unrestricted test.
- `suiteSlugs names the slugs whose suites the bindings import`: `{'sample'}` for `snapshotOf('host', hostFiles)` and for `sample`; empty for host when its binding is not UTF-8.
- `nameFilter anchors ascending ids at the start of the name`: `nameFilter({5, 2})` is `'^(G2|G5) '`, `nameFilter({18})` is `'^(G18) '`.
- `testArguments`: `BindingRun(path: 'p', runner: Runner.dart, suiteSlug: 'x', admitted: null)` gives `['test', '--reporter', 'json', 'p']`; the same with `Runner.flutter` and `admitted: {5, 2}` gives `['test', '--no-pub', '--reporter', 'json', '--name', '^(G2|G5) ', 'p']`.
- `flutterBeside finds the flutter of the Flutter SDK that holds the dart`: `'/sdk/bin/cache/dart-sdk/bin/dart'` gives `'/sdk/bin/flutter'`; `'/sdk/bin/cache/dart-sdk/bin/dart.exe'` gives `'/sdk/bin/flutter.bat'`; `'/usr/lib/dart/bin/dart'`, `'/sdk/bin/dart'` and `'/sdk/bin/cache/dart-sdk/bin/dartvm'` give null.

In `test/dart_library_test.dart`: `caseIdOf reads the G{n} and space a case name begins with`: `caseIdOf('G12 a case')` is 12; `'G1'`, `'G01 a'`, `'g1 a'`, `'G0 a'`, `' G1 a'` and null give null. In `test/report_test.dart`: `a passed outcome with a detail prints it after a colon`: `outcomeLine(CheckSet.behavior, const Passed('p', detail: 'd'))` is `'PASS behavior p: d'`, and `const Passed('p')` still prints `'PASS behavior p'`.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/behavior_test.dart packages/nidana_contract_check/test/dart_library_test.dart packages/nidana_contract_check/test/report_test.dart`
Expected: FAIL: the files do not compile (`behavior.dart` does not exist; `caseIdOf` and `Passed.detail` are not defined). Keep that output.

- [ ] **Step 3: Implement**

`planBindings` takes the files of `snapshot` whose relative path matches `^behavior/[^/]+_test\.dart$`, ascending, and decides each in this order (design decision 5), the path from the workspace root being `{fixtureDirectory(slug)}{relative}`:

1. Its source is undecodable: `Failed(path, [Problem(BehaviorRule.binding, reason)])`.
2. Its directives with no scheme (`Uri.parse(uri).hasScheme` false) and not starting with `/`, resolved with `p.posix.normalize(p.posix.join(p.posix.dirname(path), uri))`, that match `^hsdd/contract/fixture/([^/]+)/behavior/[^/]+_conformance\.dart$`: none gives `suite (imports no conformance library)`; more than one, `suite (imports {n} conformance libraries: {paths joined by ', ', in directive order})`.
3. The suite's source is `snapshot` itself for its own slug, else `snapshots[suiteSlug]`, at the relative path below that slug's fixture directory: undecodable gives `suite ({suite path}: {reason})`; absent (no snapshot, or no such file), `suite ({suite path} does not exist)`.
4. `absentPackages` of the binding and of the suite, joined, once, ascending: not empty gives `Pending(path, absent)`.
5. A restriction: its ids of the suite's slug; when no case name of the suite's case lists has a `caseIdOf` among them, `Passed(path, detail: 'not run: the restriction admits no case of {suite path}')`.
6. Otherwise `BindingRun`: `Runner.flutter` when a directive of the binding begins `package:flutter_test/`, else `Runner.dart`; `admitted` null when unrestricted, else the ids of step 5.

`suiteSlugs` reads the same resolved imports (step 2, any count) of every binding with a decoded source. `flutterBeside` splits with `p.split` and requires the last five segments to be `bin`, `cache`, `dart-sdk`, `bin` and `dart` or `dart.exe`. `structure.dart` uses `caseIdOf` and drops `_caseId` and `_caseNameId`; its outcomes do not change.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/behavior.dart packages/nidana_contract_check/lib/src/outcome.dart packages/nidana_contract_check/lib/src/report.dart packages/nidana_contract_check/lib/src/dart_library.dart packages/nidana_contract_check/lib/src/structure.dart packages/nidana_contract_check/test/support/sample.dart packages/nidana_contract_check/test/behavior_test.dart packages/nidana_contract_check/test/dart_library_test.dart packages/nidana_contract_check/test/report_test.dart
git commit -m "feat(contract_check): plan each behavior binding" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 4: Runner reports and binding outcomes

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. `test_report.dart` is pure: it reads what a runner printed with `--reporter json` and turns one run into the binding's outcome. The protocol is package:test's JSON reporter, version 0.1.1 (`~/.pub-cache/hosted/pub.dev/test_core-0.6.21/lib/src/runner/reporter/json.dart`), which `flutter test` also prints, since flutter_tools hands `-r json` to package:test (T3). Its facts, from `docs/auto-run/experiments/behavior-set-plan/output.txt`: one JSON object per line, each with a string `type` (D0); a `testStart` carries `test.id`, `test.name` and `test.groupIDs`; a `testDone` carries `testID`, `result` (`success`, `failure` or `error`), `skipped` (a skipped case's `result` is `success`) and `hidden`; an `error` carries `testID`, `error` and `isFailure`; a suite's load is a pseudo-test named `loading {path}` with `groupIDs` `[]`, hidden when the load succeeds and a visible error when it fails, its error text beginning `Failed to load "{path}":` and continuing on the same line or the next (D0b, D6, D7, D9); every real case has a non-empty `groupIDs` (D0, D1); a filter that admits nothing, or a binding with no case, ends with `done` `success: true` and exit 79 (D4, D8); a case's `print` is a `print` event (D0).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/test_report.dart`
- Test: `packages/nidana_contract_check/test/test_report_test.dart` (new)

**Interfaces:**
- Consumes: Task 3: `BindingRun` (`path`, `runner`, `suiteSlug`, `admitted`), `Runner.label`, `BehaviorRule`, `Passed(path, detail:)`; nidana.model.1 and .2: `Failed`, `Problem`, `formatIds`, `outcomeLine`, `CheckSet`.
- Produces:

```dart
// lib/src/test_report.dart
/// What a runner printed with `--reporter json`, read.
sealed class TestReport { const TestReport(); }
/// The output holds no complete report: no `done` event, or one whose `success` is null.
final class NoReport extends TestReport { const NoReport(); }
/// A complete report: the cases ran, or the binding did not load.
sealed class Reported extends TestReport { const Reported(); }
final class CasesRan extends Reported {
  const CasesRan({required this.passed, required this.failed, required this.skipped, required this.failing});
  final int passed;
  final int failed;
  final int skipped;
  /// The names of the failed cases, in the order they started.
  final List<String> failing;
}
final class LoadFailed extends Reported {
  const LoadFailed(this.error);
  /// The first non-blank text of the load error after `Failed to load "{path}":`.
  final String error;
}
TestReport readTestReport(String stdout);
/// `{runner} exited {exitCode} without a JSON report for {path}`, then `: {line}` with the first
/// line of [stderr] that is not blank, trimmed, when there is one.
String runnerFailure(BindingRun run, int exitCode, String stderr);
/// The outcome of [run] by [report].
FixtureOutcome ranOutcome(BindingRun run, Reported report);
```

- [ ] **Step 1: Write the failing tests**

Create `test/test_report_test.dart`. Build reports from event maps so each test states only what it reads:

```dart
// packages/nidana_contract_check/test/test_report_test.dart
import 'dart:convert';

import 'package:nidana_contract_check/src/behavior.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/test_report.dart';
import 'package:test/test.dart';

String report(List<Map<String, Object?>> events) => events.map(jsonEncode).join('\n');

const Map<String, Object?> opening = <String, Object?>{
  'type': 'start', 'protocolVersion': '0.1.1', 'runnerVersion': '1.33.0', 'pid': 1, 'time': 0,
};
Map<String, Object?> started(int id, String name, {List<int> groups = const <int>[2]}) => <String, Object?>{
  'type': 'testStart', 'time': 0,
  'test': <String, Object?>{'id': id, 'name': name, 'suiteID': 0, 'groupIDs': groups},
};
Map<String, Object?> loading(int id) => started(id, 'loading p_test.dart', groups: const <int>[]);
Map<String, Object?> ended(int id, String result, {bool skipped = false, bool hidden = false}) => <String, Object?>{
  'type': 'testDone', 'testID': id, 'result': result, 'skipped': skipped, 'hidden': hidden, 'time': 0,
};
Map<String, Object?> failedWith(int id, String error, {bool isFailure = false}) => <String, Object?>{
  'type': 'error', 'testID': id, 'error': error, 'stackTrace': '', 'isFailure': isFailure, 'time': 0,
};
Map<String, Object?> printed(int id, String message) => <String, Object?>{
  'type': 'print', 'testID': id, 'messageType': 'print', 'message': message, 'time': 0,
};
Map<String, Object?> finished(bool? success) => <String, Object?>{'type': 'done', 'success': success, 'time': 0};

/// D0: a pass, an expectation failure, an error, a skip and a case that prints.
final List<Map<String, Object?>> d0 = <Map<String, Object?>>[
  opening,
  loading(1), ended(1, 'success', hidden: true),
  started(3, 'G1 passes'), ended(3, 'success'),
  started(4, 'G2 fails'), failedWith(4, 'Expected: <2>\n  Actual: <1>\n', isFailure: true), ended(4, 'failure'),
  started(5, 'G3 throws'), failedWith(5, 'UnimplementedError: x'), ended(5, 'error'),
  started(6, 'G4 skipped'), ended(6, 'success', skipped: true),
  started(7, 'G5 prints'), printed(7, 'hello'), ended(7, 'success'),
  finished(false),
];

/// A report as one line: `none`, `load: {error}`, or `{passed}/{failed}/{skipped} {failing joined by |}`.
String text(TestReport r) => switch (r) {
  NoReport() => 'none',
  LoadFailed(:final String error) => 'load: $error',
  CasesRan(:final int passed, :final int failed, :final int skipped, :final List<String> failing) =>
    '$passed/$failed/$skipped ${failing.join('|')}',
};

const BindingRun dartRun = BindingRun(path: 'p', runner: Runner.dart, suiteSlug: 'sample', admitted: null);
```

and these tests:

- `counts come from visible testDone events, failures in start order`: `text(readTestReport(report(d0)))` is `'2/2/1 G2 fails|G3 throws'`.
- `a visible failed test with no group is a load failure, its detail after Failed to load`: `[opening, loading(1), failedWith(1, 'Failed to load "p_test.dart":\np_test.dart:4:31: Error: Method not found: \'undefinedName\'.\n  test(...);\n  ^^^'), ended(1, 'error'), finished(false)]` gives `"load: p_test.dart:4:31: Error: Method not found: 'undefinedName'."`; the error `'Failed to load "p_test.dart": Bad state: a case list that fails to build'` gives `'load: Bad state: a case list that fails to build'`; an error text with no `Failed to load` line, `'boom'`, gives `'load: boom'`.
- `no case ran is counted as none ran, whatever done says`: `[opening, loading(1), ended(1, 'success', hidden: true), finished(true)]` gives `'0/0/0 '`.
- `lines that are not JSON events change nothing`: `report(d0)` with these lines inserted after its first line: `Waiting for another flutter command to release the startup lock...`, `--experimental-faster-testing was parsed but will be ignored.`, `[1, 2]`, `"text"`, `{"no": "type"}` and an empty line, gives `'2/2/1 G2 fails|G3 throws'`.
- `no done event, or a done whose success is null, is no report`: `''`, `report(d0)` without its last event, and `report(d0)` with `finished(null)` in place of `finished(false)` each give `'none'`.
- `ranOutcome prints counts, failing names and the restriction on the binding's line`: through `outcomeLine(CheckSet.behavior, ranOutcome(run, report))`:
  - `dartRun`, `CasesRan(passed: 2, failed: 2, skipped: 1, failing: ['G2 fails', 'G3 throws'])`: `'FAIL behavior p: cases (2 passed, 2 failed, 1 skipped under dart test); failed-case (G2 fails); failed-case (G3 throws)'`;
  - `BindingRun(path: 'p', runner: Runner.flutter, suiteSlug: 'sample', admitted: {2})`, `CasesRan(passed: 2, failed: 0, skipped: 0, failing: [])`: `'PASS behavior p: 2 passed, 0 failed, 0 skipped under flutter test --no-pub, restricted to sample G2'`;
  - `dartRun`, `CasesRan(passed: 0, failed: 0, skipped: 2, failing: [])`: `'PASS behavior p: 0 passed, 0 failed, 2 skipped under dart test'`;
  - `BindingRun(..., admitted: {9})` under dart, no case ran: `'FAIL behavior p: cases (no case ran under dart test, restricted to sample G9)'`;
  - `dartRun`, `LoadFailed('x')`: `'FAIL behavior p: load (did not load under dart test: x)'`.
- `runnerFailure names the runner, the exit code, the binding and the first line of stderr`: a flutter run of path `p`, exit 3, stderr `'\n  boom\nmore\n'`: `'flutter test --no-pub exited 3 without a JSON report for p: boom'`; `dartRun`, exit 255, stderr `''`: `'dart test exited 255 without a JSON report for p'`.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/test_report_test.dart`
Expected: FAIL: the file does not compile (`test_report.dart` does not exist). Keep that output.

- [ ] **Step 3: Implement**

`readTestReport`: each line that `jsonDecode`s to a map with a string `type` is an event, read by map patterns as `parseAnalysis` reads diagnostics; any other line, and an event whose fields have other types, is skipped. The last `done` event decides completeness (design decision 9). A test is visible when its `testDone` has `hidden` false; a test with no `testDone` is not counted. The first visible test with empty `groupIDs` and a result of `failure` or `error` gives `LoadFailed` from its first `error` event's text: when its first line matches `^Failed to load ".*":` the rest of that line and the following lines are read, else the whole text; the first of them that is not blank, trimmed. Otherwise `CasesRan` over the visible tests: passed is `success` and not skipped, skipped is skipped, failed is `failure` or `error`, `failing` their names in `testStart` order.

`ranOutcome` (design decision 10), with `{runner}` `run.runner.label` and `{restriction}` empty when `run.admitted` is null, else `, restricted to {run.suiteSlug} {formatIds(run.admitted!)}`: `LoadFailed` is `Failed` with `load (did not load under {runner}: {error})`; `CasesRan` with no case is `Failed` with `cases (no case ran under {runner}{restriction})`; with no failure, `Passed` with detail `{passed} passed, 0 failed, {skipped} skipped under {runner}{restriction}`; otherwise `Failed` with `cases ({passed} passed, {failed} failed, {skipped} skipped under {runner}{restriction})` and one `failed-case ({name})` per failing name, in order.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/test_report.dart packages/nidana_contract_check/test/test_report_test.dart
git commit -m "feat(contract_check): read test runner reports into binding outcomes" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 5: The shell runs the behavior set

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. `shell.dart` reads, runs and prints, and leaves every decision to the pure core of Tasks 3 and 4. This task runs each binding the planner gives a `BindingRun`, one process after another, from the workspace root, under `{dart} test` or under the `flutter` beside the running `dart`, and maps the reports to outcomes. **Never start the real flutter** (Global requirements): this machine's Flutter SDK has no engine artifacts (T2). Every seeded workspace that holds the widget binding is replayed through `runCli` with `dart: standInSdk().dart` or `dart: plainDart()`; only a replay of `host` alone, whose one binding runs under `dart test`, may go through `runTool`. Facts: a temporary workspace with the stand-in members below resolves offline in 0.2 s, and the stand-in `flutter_test` runs a `testWidgets` binding under `dart test` (W1, D10); a stand-in SDK of two shell scripts over the real `dart` runs it as the flutter runner would (F1, F2); `dart test` from the workspace root takes about 3 s on its first run in a fresh workspace and about 0.5 s after (D1 to D10); it leaves only `.dart_tool/test` in the workspace (F3); a process started with a linked working directory reads it resolved (`replay-sets-plan` X2), so only an in-process `runCli` hands the shell an unresolved root.

**Files:**
- Modify: `packages/nidana_contract_check/lib/src/shell.dart`
- Modify: `packages/nidana_contract_check/test/support/workspace.dart` (`runners`)
- Create: `packages/nidana_contract_check/test/support/runners.dart`
- Create: `packages/nidana_contract_check/test/behavior_cli_test.dart`
- Modify: `packages/nidana_contract_check/test/cli_test.dart` (the behavior set is no longer unimplemented)

**Interfaces:**
- Consumes: Task 1: `_Context`, `_Packages`, `_readPackages`, `readsPackages`, `slugPlan`, `discoverSlugs`; Task 2: `readSnapshot`; Task 3: `suiteSlugs`, `planBindings`, `BindingSettled`, `BindingRun`, `Runner`, `testArguments`, `flutterBeside`; Task 4: `readTestReport`, `NoReport`, `Reported`, `ranOutcome`, `runnerFailure`; nidana.model.1 and .2: `SetChecked`, `SetUnavailable`, `CheckSet`; test support `behaviorFiles`, `hostFiles`, `standInSample`, `seed`, `runTool`, `lines`.
- Produces:

```dart
// lib/src/shell.dart (private): the context every set run reads
typedef _Context = ({
  Directory root,
  _Packages packages,
  _Analysis analysis,
  Map<String, SlugSnapshot> snapshots, // every slug read: the request's and the suites' slugs
  Set<GuaranteeRef>? restriction,
  String dart,
  String? flutter,     // flutterBeside(dart) when that file exists
  StringSink progress, // err
});
Future<SetRun> _run(CheckSet set, SlugSnapshot snapshot, _Context context);

// test/support/workspace.dart
/// [files] in a fresh temporary pub workspace resolved offline: its root's one member is the
/// stand-in package `sample` unless [standIn] is false, and the fixtures' analysis options are
/// this workspace's hsdd/contract/fixture/analysis_options.yaml. With [runners], `sample` also
/// depends on `matcher` and dev-depends on `test`, and the stand-in members `nidana_contract_check`
/// and `flutter_test` join the workspace, so bindings run under `dart test`.
Future<Directory> seedWorkspace(Map<String, String> files, {bool standIn = true, bool runners = false});

// test/support/runners.dart
/// A stand-in Flutter SDK in a fresh temporary directory deleted after the test:
/// `bin/cache/dart-sdk/bin/dart` runs the real dart with its arguments, and `bin/flutter` appends
/// its arguments, one line per call, to [flutterCalls], expects `test --no-pub` first and runs the
/// real `dart test` with the rest. With [flutterReports] false, `bin/flutter` prints `boom` to
/// stderr and exits 3 instead.
({String dart, File flutterCalls}) standInSdk({bool flutterReports = true});
/// A script named `dart` in a fresh temporary directory, held by no Flutter SDK, that runs the real dart.
String plainDart();
```

- [ ] **Step 1: Write the failing tests and the seeding**

`seedWorkspace` with `runners: true` (which requires `standIn`) writes, besides what it writes now: `packages/sample/pubspec.yaml` with these lines appended to the stand-in's, `dependencies:`, `  matcher: any`, `dev_dependencies:`, `  test: any`; `packages/nidana_contract_check/pubspec.yaml` (`name: nidana_contract_check`, `publish_to: none`, `environment:`, `  sdk: ^3.13.0`, `resolution: workspace`) and its `lib/fixture.dart`:

```dart
/// Stands in for package:nidana_contract_check/fixture.dart in a seeded workspace.
library;

typedef ConformanceCase<H> = ({
  String name,
  Future<void> Function(H harness) body,
});
```

`packages/flutter_test/pubspec.yaml` (`name: flutter_test`, `publish_to: none`, `environment:`, `  sdk: ^3.13.0`, `resolution: workspace`, `dependencies:`, `  test: any`) and its `lib/flutter_test.dart`:

```dart
/// Stands in for package:flutter_test in a seeded workspace: testWidgets over package:test.
library;

import 'package:test/test.dart' show test;

export 'package:test/test.dart';

/// Stands in for flutter_test's WidgetTester.
final class WidgetTester {
  const WidgetTester._();
}

/// Registers [description] as a test whose body is given a [WidgetTester].
void testWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => test(description, () => body(const WidgetTester._()));
```

and the root `pubspec.yaml`'s `workspace:` list names `packages/sample`, `packages/nidana_contract_check` and `packages/flutter_test`. Resolution stays `pub get --offline`, expecting exit 0.

`test/support/runners.dart` writes its scripts with `File.writeAsStringSync` into a directory from `seed(const <String, String>{})`, makes them executable with `Process.runSync('chmod', ['+x', ...])` (expecting exit 0), and quotes `Platform.resolvedExecutable` in single quotes. The `dart` script is `#!/bin/sh` then `exec '{real dart}' "$@"`. The `flutter` script, for `flutterReports` true:

```sh
#!/bin/sh
printf '%s\n' "$*" >> "$0.calls"
[ "$1" = test ] && [ "$2" = --no-pub ] || { echo "stand-in flutter: expected test --no-pub" >&2; exit 64; }
shift 2
exec '{real dart}' test "$@"
```

and for `flutterReports` false, the same first two lines, then `echo boom >&2` and `exit 3`. `flutterCalls` is the file `{sdk}/bin/flutter.calls`. `plainDart` writes the `dart` script into a fresh directory as `{dir}/dart`.

Create `test/behavior_cli_test.dart`:

```dart
// packages/nidana_contract_check/test/behavior_cli_test.dart
import 'dart:io';

import 'package:nidana_contract_check/src/shell.dart';
import 'package:test/test.dart';

import 'support/runners.dart';
import 'support/sample.dart';
import 'support/seed.dart';
import 'support/workspace.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String h = 'hsdd/contract/fixture/host/';
const List<String> hostStructure = <String>[
  'PASS structure hsdd/contract/host.md',
  'PASS structure hsdd/contract/fixture/host/',
  'PASS structure hsdd/contract/fixture/host/behavior/host_impl_test.dart',
];
const String notAdmitted = 'not run: the restriction admits no case of ${s}behavior/sample_conformance.dart';

typedef Replay = ({int code, List<String> out, List<String> err});

/// [arguments] replayed in process from [from] with [dart] as the running dart.
Future<Replay> replay(List<String> arguments, {required Directory from, required String dart}) async {
  final StringBuffer out = StringBuffer();
  final StringBuffer err = StringBuffer();
  final int code = await runCli(arguments, workingDirectory: from, out: out, err: err, dart: dart);
  List<String> split(StringBuffer b) => b.isEmpty ? const <String>[] : b.toString().trimRight().split('\n');
  return (code: code, out: split(out), err: split(err));
}

void main() {
  late Directory root;
  setUpAll(() async {
    root = await seedWorkspace(<String, String>{...behaviorFiles, ...hostFiles}, runners: true);
  });
  // the tests below
}
```

The tests, in this order, each in `main` after the `setUpAll`:

1. `unrestricted, each binding runs under its runner and its line holds its counts and failing cases`: with `sdk = standInSdk()`, `replay(['sample', '--set', 'behavior'], from: root, dart: sdk.dart)` exits 1; `out` contains `FAIL behavior ${s}behavior/sample_impl_test.dart: cases (2 passed, 2 failed, 0 skipped under dart test); failed-case (G3 a sample is redacted); failed-case (G1 a body not implemented yet)` and the same line for `widget_impl_test.dart` with `under flutter test --no-pub`; its last line is `9 fixtures: 7 passed, 2 failed, 0 pending`; `err` is exactly `['running behavior ${s}behavior/sample_impl_test.dart under dart test', 'running behavior ${s}behavior/widget_impl_test.dart under flutter test --no-pub']`; `sdk.flutterCalls.readAsLinesSync()` is `['test --no-pub --reporter json ${s}behavior/widget_impl_test.dart']`.
2. `one id runs exactly the cases whose names begin with it, under dart test and under flutter test --no-pub`: `['sample', '--set', 'behavior', '--guarantee', 'G2']` exits 0; `out` contains `PASS behavior ${s}behavior/sample_impl_test.dart: 2 passed, 0 failed, 0 skipped under dart test, restricted to sample G2` and `PASS behavior ${s}behavior/widget_impl_test.dart: 2 passed, 0 failed, 0 skipped under flutter test --no-pub, restricted to sample G2`; the flutter calls are `['test --no-pub --reporter json --name ^(G2)  ${s}behavior/widget_impl_test.dart']` (the filter's own space, then the separator).
3. `a binding of another slug's suite runs exactly the cases its {slug}/G{n} ids name`: `['host', '--set', 'behavior', '--guarantee', 'sample/G2,sample/G3']` exits 1 and `out` is `[...hostStructure, 'FAIL behavior ${h}behavior/host_impl_test.dart: cases (2 passed, 1 failed, 0 skipped under dart test, restricted to sample G2, G3); failed-case (G3 a sample is redacted)', '4 fixtures: 3 passed, 1 failed, 0 pending']`.
4. `and none for bare ids alone, even where a bare id equals one of its case ids`: `['host', '--set', 'behavior', '--guarantee', 'G1']` (host's own G1; the suite has a case `G1 a body not implemented yet`) exits 0, `out` is `[...hostStructure, 'PASS behavior ${h}behavior/host_impl_test.dart: $notAdmitted', '4 fixtures: 4 passed, 0 failed, 0 pending']`, and `err` is empty: no runner started.
5. `a binding the restriction admits no case of passes with no case run, and the replay exits 0`: `['sample', '--set', 'behavior', '--guarantee', 'G4']` exits 0; `out` contains `PASS behavior ${s}behavior/sample_impl_test.dart: $notAdmitted` and the same for `widget_impl_test.dart`; `err` is empty and `sdk.flutterCalls.existsSync()` is false.
6. `a binding of an absent package prints PENDING, never a test failure, and starts no runner`: over `await seedWorkspace(behaviorFiles)` (no runners: the package configuration holds `sample` alone), `['sample', '--set', 'behavior']` exits 1; `out` contains `PENDING behavior ${s}behavior/sample_impl_test.dart: packages matcher, nidana_contract_check, test are absent from .dart_tool/package_config.json` and `PENDING behavior ${s}behavior/widget_impl_test.dart: packages flutter_test, matcher, nidana_contract_check are absent from .dart_tool/package_config.json`; the last line is `9 fixtures: 7 passed, 0 failed, 2 pending`; `err` is empty.
7. `a binding that does not compile fails on load, not on its cases`: write `${h}behavior/broken_impl_test.dart` into `root` (remove it in `addTearDown`), holding `import 'package:test/test.dart';`, `import '../../sample/behavior/sample_conformance.dart';` and a `main` that registers `test(c.name, () => c.body(undefinedHarness))` for each case. `['host', '--set', 'behavior']` with a stand-in SDK exits 1; `out` has a line that starts with `FAIL behavior ${h}behavior/broken_impl_test.dart: load (did not load under dart test: ${h}behavior/broken_impl_test.dart:` and contains `undefinedHarness`, and the line `FAIL behavior ${h}behavior/host_impl_test.dart: cases (2 passed, 2 failed, 0 skipped under dart test); failed-case (G3 a sample is redacted); failed-case (G1 a body not implemented yet)`. (Structure also fails the unlisted binding; this test reads the behavior lines.)
8. `no flutter in the SDK of the running dart is an environment error (2), and no binding of the slug runs`: with `dart = plainDart()`, `['sample', '--set', 'behavior']` exits 2 and `err` is exactly `['ERROR behavior sample: no flutter in the Flutter SDK of $dart; ${s}behavior/widget_impl_test.dart runs under flutter test --no-pub']`; with `--guarantee G4` added it exits 0, because no binding would run.
9. `a runner that prints no report is an environment error (2)`: with `standInSdk(flutterReports: false)`, `['sample', '--set', 'behavior']` exits 2 and `err` contains `ERROR behavior sample: flutter test --no-pub exited 3 without a JSON report for ${s}behavior/widget_impl_test.dart: boom`.
10. `through a symbolic link to the workspace root, outcomes still reach their bindings`: with `Link('${seed(const <String, String>{}).path}/linked')..createSync(root.path)`, `replay(['host', '--set', 'behavior', '--guarantee', 'sample/G2'], from: Directory(link.path), dart: standInSdk().dart)` exits 0 and `out` contains `PASS behavior ${h}behavior/host_impl_test.dart: 2 passed, 0 failed, 0 skipped under dart test, restricted to sample G2`.
11. `the bin script replays a dart binding end to end`: `runTool(['host', '--set', 'behavior', '--guarantee', 'sample/G2'], workingDirectory: root)` exits 0, `lines(r)` is `[...hostStructure, 'PASS behavior ${h}behavior/host_impl_test.dart: 2 passed, 0 failed, 0 skipped under dart test, restricted to sample G2', '4 fixtures: 4 passed, 0 failed, 0 pending']` and stderr is `'running behavior ${h}behavior/host_impl_test.dart under dart test\n'`. (`lines` is `cli_test.dart`'s helper; copy it.)

In `test/cli_test.dart`, the test `no package configuration, and a set this version does not implement` becomes `no package configuration is a reason for every set that reads it`, expecting `ERROR behavior sample: no package configuration at .dart_tool/package_config.json; run fvm dart pub get` in place of the not-implemented line.

- [ ] **Step 2: Run them and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/behavior_cli_test.dart packages/nidana_contract_check/test/cli_test.dart`
Expected: FAIL: `behavior_cli_test.dart` does not compile (`seedWorkspace` takes no `runners`; `support/runners.dart` does not exist). Keep that output; once they exist, every behavior test fails on `ERROR behavior sample: this version of nidana_contract_check does not implement the behavior set` with exit 2.

- [ ] **Step 3: Implement**

In `_replay`, after the plans (Task 1's step 5): for each plan that holds `behavior`, read with `readSnapshot` each slug of `suiteSlugs(plan.snapshot)` that `discoverSlugs` found and that is not read yet; `snapshots` maps every slug read to its snapshot. `flutter` is `flutterBeside(dart)` when `File(...).existsSync()`, else null. `_run` becomes `Future<SetRun>` and the runs are awaited in order. Its `behavior` branch:

1. `_NoPackages(reason)`: `SetUnavailable(behavior, slug, reason)`.
2. `planBindings(snapshot, snapshots: context.snapshots, packages: ..., restriction: context.restriction)`.
3. When some `BindingRun` has `Runner.flutter` and `context.flutter` is null: `SetUnavailable` with `no flutter in the Flutter SDK of {dart}; {path} runs under flutter test --no-pub`, naming the first such binding, before any binding of the slug starts.
4. Each plan in order: a `BindingSettled` gives its outcome. A `BindingRun` writes `running behavior {path} under {runner.label}` to `context.progress`, then `Process.run({dart, or the flutter}, testArguments(run), workingDirectory: context.root.path)`: a `ProcessException` gives `SetUnavailable` with `could not run {executable}: {message}`; `readTestReport(stdout)` of `NoReport` gives `SetUnavailable` with `runnerFailure(run, exitCode, stderr)`; a `Reported` gives `ranOutcome(run, report)`. The first `SetUnavailable` ends the slug's behavior set.
5. `SetChecked(behavior, slug, outcomes)`.

Update the dartdoc of `shell.dart`'s library comment, `runCli` and `_replay`: the shell now also runs one test runner per binding.

- [ ] **Step 4: Run the tests, the formatter and the analyzer**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Replay the committed tree**

Run: `fvm dart run nidana_contract_check topic-model --set behavior; echo "exit: $?"`
Expected: `exit: 1`; 17 `PASS structure` lines; one line that begins `FAIL behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: cases (9 passed, 32 failed, 0 skipped under dart test); failed-case (` and holds 32 `failed-case` problems and no `load` problem; `18 fixtures: 17 passed, 1 failed, 0 pending`; stderr is the one line `running behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart under dart test` (R1: the binding loads against nidana.model.5's declarations).
Run: `fvm dart run nidana_contract_check --all --set behavior; echo "exit: $?"`
Expected: `exit: 1`; 102 `PASS structure` lines; 7 `PENDING behavior` lines, two each for bus-api (`nidana_dart_runtime`), flutter-binding (`flutter`, `flutter_test`, `nidana_dart_navigation`, `nidana_dart_runtime`, `nidana_dart_runtime_flutter`) and navigation-api, one for bus-testing; 3 `FAIL behavior` lines with a `cases` problem and no `load` problem: topic-model (9 passed, 32 failed), topology-dsl's `topology_builder_test.dart` (0 passed, 24 failed) and topology-ir's `nidana_dart_contracts_test.dart` (1 passed, 42 failed) (R1 to R3); `112 fixtures: 102 passed, 3 failed, 7 pending`; stderr holds three `running behavior` lines and no `ERROR` line; no flutter is started.

A different count is a finding, not a test to adjust: stop and report it.

- [ ] **Step 6: Run the gate (Global Constraint 4)**

Run: `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/test/support/workspace.dart packages/nidana_contract_check/test/support/runners.dart packages/nidana_contract_check/test/behavior_cli_test.dart packages/nidana_contract_check/test/cli_test.dart
git commit -m "feat(contract_check): run the behavior set" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```

### Task 6: Gate and verification doc

You write the phase's verification doc. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.6.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.6.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 5; `packages/nidana_contract_check/test/behavior_cli_test.dart` (the seeded runner cases); the gate output; `docs/auto-run/experiments/behavior-set-plan/` (`summarize.py`, `output.txt`); this plan's Design decisions and Routed items.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check) > "${TMPDIR:-/tmp}/nidana.model.6-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the times with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after.
Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending` and `All tests passed!` with the package's test count. A failure stops here: it is fixed in the task that owns the code, never by editing `hsdd/`.

- [ ] **Step 2: Run the phase's Verification on the committed tree**

Run each and keep its output: `fvm dart run nidana_contract_check topic-model --set behavior; echo "exit: $?"` and `fvm dart run nidana_contract_check --all --set behavior; echo "exit: $?"` (each as Task 5 Step 5 states); `fvm dart test --reporter json hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart | python3 -I docs/auto-run/experiments/behavior-set-plan/summarize.py --kinds`, the breakdown of the binding's failures by first error, which the tool does not print (R1: 41 visible tests, 9 passed, 32 failed; 27 `UnimplementedError`, 5 expectation failures, 0 other errors); `fvm dart test packages/nidana_contract_check/test/behavior_cli_test.dart` (every test passes).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.6.verification.md` at full-review depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder with content, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.6 - Replay tool: behavior set` (a spaced hyphen; no em-dash anywhere in the file).

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate of Step 1; the commands of Step 2. The phase produces no contract, so there is no output of its own to validate against a schema.
- **Expected output:** the gate's exit 0 and its lines as Step 1 lists them; from `behavior_cli_test.dart`, the exact lines of tests 1 to 6 and 8 and 9 (one id under each runner, with the stand-in flutter's recorded call; the other slug's suite by `{slug}/G{n}` ids and none for bare ids alone; a binding no case of which is admitted, passing with no case run and exit 0; PENDING with no runner started; the two environment errors); the committed-tree replays of Task 5 Step 5; and what "loads and fails, not on loading" means here (design decision 18): a `cases` line and no `load` problem for topic-model@v1's binding, 9 passed and 32 failed, 27 of them on `UnimplementedError` and 5 on the `==` and `toString` that stay `Object`'s under nidana.model D3, from the experiment's reader, not the tool.
- **Observed:** dated (`date -u`); the gate's exit code and lines as they appeared; the test count by file; the Step 2 outputs; how long the runner tests took, from the test run's timestamps.
- **Outstanding:** the real `flutter test --no-pub`. This machine's Flutter SDK has no engine artifacts, so the Flutter runner was verified only against a stand-in SDK whose `flutter` runs `dart test`; that the pinned flutter runs a binding under `hsdd/` from the pure-Dart workspace root with `--reporter json` and `--name` as the tool calls it rests on flutter_tools 3.47.7's source (T3) and on `contract-fixtures` Q10 and Q11, run on another machine. Proposed disposition: deferred to nidana.flutter.2, whose gate `fvm dart run nidana_contract_check flutter-binding --guarantee G9` is the first to start the real flutter through the tool (nidana.flutter.1 needs the artifacts first, to resolve its Flutter member).
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Candidates to weigh, each kept only if the gate still shows it: the phase Verification's "fail on `UnimplementedError`" holds for 27 of topic-model's 32 failures, the rest failing on what nidana.model D3 leaves `Object`'s (proposed `dropped (D3 decides it; nidana.model.8 delivers the equality)`); an undeclared `--guarantee` id is now a usage error, which ADR-001 item 9's list of usage errors does not name (proposed `dropped (item 9's list begins such as; an ADR-001 touch may name it)`); the cross-slug coverage item left routed (Routed items; proposed `dropped (routed to the end-of-node sweep, no committed suite is unbound)`); the phase's size against its estimate of about 300 lines in about 5 files (proposed `dropped (sizing is the owner's to revisit at a checkpoint)`). Write `- none` only when nothing applies; never leave the section empty.
- **Metrics:** gate failures before green; fix rounds after task review; wall-clock from the start of the implementation step to the gate; the product diff in lines, `git diff --stat {base} HEAD -- packages/` with `{base}` the commit before Task 1's first commit, by part (library, tests); the phase estimated about 300 lines in about 5 files, so record the actual beside it; the task count, 6 of the allowed 6.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.6.verification.md
git commit -m "docs(verify): nidana.model.6 verification" -m "Co-Authored-By: {model} <noreply@anthropic.com>"
```
