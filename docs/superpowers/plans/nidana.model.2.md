# nidana.model.2 Replay Tool: Surface, Reject and Schema Sets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `package:nidana_contract_check/fixture.dart` (`ConformanceCase<H>`, `expectMatchesSchema`), the `schema`, `surface` and `reject` sets and PENDING detection to `packages/nidana_contract_check`, so that `fvm dart run nidana_contract_check --all --set structure,schema` passes topology-ir@v1's and topic-codegen@v1's schema sets as committed, a seeded reject fixture with a marker on the wrong line, a wrong code or an extra warning fails, and a replay whose producer is absent prints PENDING per fixture and exits 1.

**Architecture:** The pure core and imperative shell of nidana.model.1, extended. The snapshot gains the bytes of the schema file and of every document below `valid/` and `invalid/`; the `schema`, `surface` and `reject` sets are pure functions of a snapshot, the workspace's package names and the diagnostics the shell hands them. The shell becomes async: it reads every snapshot of the request, runs one `dart analyze --format=json` (of the `dart` running the tool) over every surface and reject library that imports no absent package, and none when there is no such library, attributes each reported diagnostic to its fixture by symlink-resolved path, then prints the runs. `Pending` joins the sealed `FixtureOutcome`, and `SetUnavailable` carries the reason of its environment error.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:json_schema` 5.2.2 (draft 2020-12), `package:package_config` 2.2.0, `package:matcher` 0.12.20, `package:path`, `package:args`; `package:test` for tests; the SDK's `dart analyze --format=json`.

**Spec:** `hsdd-context/superpowers/nidana.model.2.md` (the derivative; the generic phase context sits between its markers). Governance it links: `hsdd/spec/nidana.model.md` (phase nidana.model.2, D1, D2), `hsdd/adr/001-executable-contract-validation.md` (items 2 to 5 and 9), `hsdd/adr/002-package-workspace-layout.md` (items 3 and 4), and topology-ir@v1's `## Validation`, which states `expectMatchesSchema`. The code this phase extends is `packages/nidana_contract_check/` as nidana.model.1 left it (`hsdd/verify/nidana.model.1.verification.md`). Evidence: `docs/auto-run/experiments/replay-sets-plan/` (`run.sh`, `output.txt`, `probe/`); labels such as A3 or J6 below name the steps of its `output.txt`.

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 7 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check && fvm dart run nidana_contract_check --all --set structure,schema` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.2.verification.md from
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

- Toolchain: `fvm dart` only, every command from the repository root, no global tooling. Inside a temporary directory `fvm` finds no `.fvmrc` and runs no `dart` (`docs/auto-run/experiments/replay-sets-plan/output.txt` W0), so the tool and the tests start the SDK's `dart` as `Platform.resolvedExecutable`, which under both `fvm dart run` and `fvm dart test` is the pinned SDK's `bin/dart` (X1).
- Files: nothing outside `packages/nidana_contract_check/` changes, except the verification doc in Task 7. The root `pubspec.yaml`, `analysis_options.yaml` and `pubspec.lock` and the member's `pubspec.yaml` stay as nidana.model.1 left them: `args`, `json_schema`, `matcher`, `package_config` and `path` are already declared at ADR-002 item 4's constraints, and no package is added.
- Pure core, imperative shell (nidana.model D2 item 5): no file under `lib/src/` except `shell.dart` imports `dart:io`, reads a file or starts a process; `lib/fixture.dart`, the public library fixtures import, may. Values are immutable (final fields, collections built once and never mutated); alternatives are sealed classes or enums, matched by exhaustive `switch`.
- Tests: the pure core by direct calls over in-memory snapshots; the shell by running the bin script (`runTool`) or by calling `runCli` in process. A seeded fixture is a string in test code, never a `.dart` file in the package. A test that needs the analyzer seeds a temporary pub workspace with a stand-in package and resolves it with `Platform.resolvedExecutable pub get --offline` (Task 5).
- Output (ADR-001 item 9): one line per fixture, `PASS`, `FAIL` or `PENDING`, then the set and the path from the workspace root with `/` separators; `ERROR {set} {slug}: {reason}` on stderr for a set that could not run; one summary line; exit 0 when every fixture passes, 1 when any fails or is PENDING, 2 on an environment error, 64 on a usage error.
- The analyzer reads `surface/` and `reject/` libraries only: never an input or expected tree, an `invocation/` case, a `behavior/` library or a data directory such as topic-codegen@v1's `expected/` and `rejected/` or topology-ir@v1's `render/` (ADR-001 item 2). The schema set reads the schema file and the files below `valid/` and `invalid/`, nothing else.
- A committed contract, schema or fixture that a set as written rejects is a contract gap (ADR-001 item 8): never edit `hsdd/contract/`; stop at the task boundary and report BLOCKED with the line, the rule it breaks and the fix you would propose.
- Formatting and tests: run `fvm dart format` on every Dart file the task creates or changes before committing. Tests beyond a step's are welcome where a rule would otherwise go unpinned. The lockfile holds `test` 1.33.0; no test uses a `test` API newer than 1.31.1.
- Prose and commits follow the run rules: no em-dash character in any comment, dartdoc or commit message, and not the phrase the run rules ban; stage explicit paths; conventional subjects (`feat(contract_check): ...`); the body ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

The input classes the spec implies but its own cases do not exercise, most likely to bite first; each has its test in the owning task.

1. **A workspace root reached through a symbolic link** (macOS temporary paths under `/var`, which is `/private/var`; a checkout below a linked home): `dart analyze` reports symlink-resolved paths (A3), so a diagnostic must still reach its fixture. A dropped diagnostic would pass a surface library that has one. Tests: Task 5 (`runCli` handed the root through a link), Task 4 (`groupDiagnostics` names the paths it cannot attribute, and Task 5 makes them an environment error).
2. **Nothing to analyze** (every library of the request imports an absent package, or `--set` names neither `surface` nor `reject`): `dart analyze` with no path analyzes the working directory, so the tool must not start it. Tests: Task 5 (the producer-absent replay exits 1 with an empty stderr), Task 4 (`analysisTargets` is empty).
3. **The marked code reported twice on the marked line, or once more on another line**: the pairs form a set, so the first passes and the second fails as an unexpected diagnostic. Test: Task 4.
4. **A document below `valid/` or `invalid/` that is empty, not JSON, not UTF-8, nested in a subdirectory or not named `.json`**: each is a document the set judges, failing with a reason, never skipped and never an exit 2. Tests: Task 3.
5. **A schema set whose schema file is absent while `valid/` or `invalid/` exists** (the structure set then credits its covers clause with nothing): the set still runs and fails loudly at the schema path. Test: Task 3.

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_contract_check`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/json_document.dart` | 1 | Bytes read as UTF-8 JSON, draft 2020-12 schemas and their validation errors |
| `{pkg}/lib/fixture.dart` | 1 | `ConformanceCase<H>` and `expectMatchesSchema`, the public library fixtures import |
| `{pkg}/lib/src/outcome.dart` | 2 | `Pending` beside `Passed` and `Failed` |
| `{pkg}/lib/src/report.dart` | 2 | PENDING lines, the pending count, the reason an unavailable set carries |
| `{pkg}/lib/src/packages.dart` | 2 | The workspace's package names, and the packages a library names that it lacks |
| `{pkg}/lib/src/snapshot.dart` | 3 | The schema file's bytes and the documents' bytes |
| `{pkg}/lib/src/schema.dart` | 3 | The `schema` set |
| `{pkg}/lib/src/analysis.dart` | 4 | The analyzer's report, attribution to fixtures, the libraries a set analyzes |
| `{pkg}/lib/src/surface.dart` | 4 | The `surface` set |
| `{pkg}/lib/src/reject.dart` | 4 | The `reject` set |
| `{pkg}/lib/src/shell.dart` | 2, 3, 5 | Async replay, one analysis per replay, environment errors, slug discovery |
| `{pkg}/lib/src/ids.dart`, `contract.dart`, `structure.dart` | 6 | Structure-set polish |
| `{pkg}/test/*_test.dart`, `{pkg}/test/support/*.dart` | 1 to 6 | Tests and their seeded samples |

---

### Task 1: JSON documents, schemas and the fixture library

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9), in the pub workspace at the repository root. Run every command from the repository root with `fvm dart`. `lib/fixture.dart` is the tool's one public library: conformance libraries import it as `package:nidana_contract_check/fixture.dart` (ADR-001 item 4), and topology-ir@v1's conformance cases call its `expectMatchesSchema` on the producer's real output. `lib/src/json_document.dart` is pure (no `dart:io`); the schema set (Task 3) reuses it. Facts from `docs/auto-run/experiments/replay-sets-plan/output.txt`: `JsonSchema.validate` of `package:json_schema` 5.2.2 reports every error, and `ValidationError.toString()` is `{instance path, or # (root)}: {message}` (J1, M); `JsonSchema.create` throws `FormatException` for a schema that does not compile and `ArgumentError` for data that is no schema (J2); `format` is an annotation under draft 2020-12, not an assertion (J5); `IOOverrides.runZoned(..., getCurrentDirectory: ...)` changes `Directory.current` inside the zone, and `fail` of `package:matcher/expect.dart` throws `TestFailure` with the message as given (O).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/json_document.dart`
- Create: `packages/nidana_contract_check/lib/fixture.dart`
- Modify: `packages/nidana_contract_check/test/support/sample.dart` (add `docContract`, `docSchema`, `docFiles`)
- Test: `packages/nidana_contract_check/test/fixture_test.dart`

**Interfaces:**
- Consumes (nidana.model.1): `Directory? findWorkspaceRoot(Directory start)` in `lib/src/shell.dart`; test support `Directory seed(Map<String, String> files)` in `test/support/seed.dart`.
- Produces:

```dart
// lib/src/json_document.dart
/// Bytes read as UTF-8 JSON: a [JsonValue], or [NotJson] with the reason.
sealed class JsonDecoding { const JsonDecoding(); }
final class JsonValue extends JsonDecoding { const JsonValue(this.value); final Object? value; }
final class NotJson extends JsonDecoding { const NotJson(this.reason); final String reason; }
JsonDecoding decodeJson(List<int> bytes);

/// A schema compiled under draft 2020-12, or [SchemaProblem] with the reason it does not compile.
sealed class SchemaCompilation { const SchemaCompilation(); }
final class CompiledSchema extends SchemaCompilation { const CompiledSchema(this.schema); final JsonSchema schema; }
final class SchemaProblem extends SchemaCompilation { const SchemaProblem(this.reason); final String reason; }
SchemaCompilation compileSchema(List<int> bytes);

/// Every validation error of [instance], each `{instance path, or # (root)}: {message}`, in the
/// order package:json_schema reports them; empty when [instance] validates.
List<String> schemaErrors(JsonSchema schema, Object? instance);

// lib/fixture.dart
typedef ConformanceCase<H> = ({String name, Future<void> Function(H harness) body});
void expectMatchesSchema(Object? instance, String schemaPath);

// test/support/sample.dart (later tasks reuse these)
const String docContract; // hsdd/contract/doc.md, a contract of kind schema
const String docSchema; // hsdd/contract/schema/doc.schema.json
const Map<String, String> docFiles; // the clean `doc` slug, keyed by path from the workspace root
```

- [ ] **Step 1: Write the failing test and the `doc` sample**

Add to `test/support/sample.dart`, each a raw `r'''...'''` string that starts on the line after `r'''` and ends with exactly one newline, as the file's other samples do. `docContract`:

```markdown
---
id: doc
version: v1
status: stable
kind: schema
---

# doc@v1

## Guarantees / invariants

- **G1** a document names itself and counts from zero.

## Validation

- schema: `hsdd/contract/schema/doc.schema.json`, JSON Schema draft 2020-12, replayed by the `schema` set (ADR-001 item 5); covers G1.
- valid: `hsdd/contract/fixture/doc/valid/`, documents that validate.
- invalid: `hsdd/contract/fixture/doc/invalid/`, documents that do not.
```

`docSchema`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "count": { "type": "integer", "minimum": 0 }
  },
  "required": ["name", "count"],
  "additionalProperties": false
}
```

`docFiles` maps `hsdd/contract/doc.md` to `docContract`, `hsdd/contract/schema/doc.schema.json` to `docSchema`, and three documents, each one line and a newline: `hsdd/contract/fixture/doc/valid/minimal.json` to `{"name": "a", "count": 0}`, `hsdd/contract/fixture/doc/invalid/negative-count.json` to `{"name": "a", "count": -1}`, `hsdd/contract/fixture/doc/invalid/extra-property.json` to `{"name": "a", "count": 0, "extra": true}`.

```dart
// packages/nidana_contract_check/test/fixture_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_contract_check/src/json_document.dart';
import 'package:test/test.dart';

import 'support/sample.dart';
import 'support/seed.dart';

const String schemaPath = 'hsdd/contract/schema/doc.schema.json';

/// Runs [body] with [directory] as the working directory.
T inDirectory<T>(Directory directory, T Function() body) =>
    IOOverrides.runZoned(body, getCurrentDirectory: () => directory);

/// Throws the [TestFailure] `expect` throws, its message exactly [lines].
Matcher failsWith(List<String> lines) => throwsA(isA<TestFailure>()
    .having((TestFailure f) => f.message, 'message', lines.join('\n')));

/// Throws a [StateError] whose message contains [text].
Matcher errsWith(String text) => throwsA(
    isA<StateError>().having((StateError e) => e.message, 'message', contains(text)));

void main() {
  test('ConformanceCase is the record of ADR-001 item 4', () async {
    final List<String> ran = <String>[];
    final ConformanceCase<List<String>> c = (
      name: 'G1 a case',
      body: (List<String> harness) async {
        harness.add('ran');
      },
    );
    await c.body(ran);
    expect(c.name, 'G1 a case');
    expect(ran, <String>['ran']);
  });
  group('expectMatchesSchema', () {
    test('a valid instance passes', () {
      inDirectory(seed(docFiles),
          () => expectMatchesSchema(<String, Object?>{'name': 'a', 'count': 0}, schemaPath));
    });
    test('an invalid instance fails as expect does, listing every validation error', () {
      final Directory root = seed(docFiles);
      expect(
        () => inDirectory(root, () => expectMatchesSchema(
            <String, Object?>{'name': 1, 'count': -1, 'extra': true}, schemaPath)),
        failsWith(<String>[
          'does not match hsdd/contract/schema/doc.schema.json:',
          '  /name: type: wanted [string] got 1',
          '  /count: minimum violated (-1 < 0)',
          '  # (root): unallowed additional property extra',
        ]),
      );
    });
    test('the path is relative to the nearest ancestor of the working directory that holds hsdd/contract/', () {
      final Directory root = seed(<String, String>{...docFiles, 'packages/member/lib/member.dart': '\n'});
      final Directory member = Directory('${root.path}/packages/member');
      inDirectory(member,
          () => expectMatchesSchema(<String, Object?>{'name': 'a', 'count': 0}, schemaPath));
      expect(
        () => inDirectory(member, () => expectMatchesSchema(<Object?>[], schemaPath)),
        failsWith(<String>['does not match $schemaPath:', '  # (root): type: wanted [object] got []']),
      );
    });
    test('no workspace root, an absent schema and a schema that does not compile are errors', () {
      expect(
          () => inDirectory(seed(const <String, String>{'readme.txt': 'x\n'}),
              () => expectMatchesSchema(1, schemaPath)),
          errsWith('holds hsdd/contract/'));
      expect(
          () => inDirectory(seed(docFiles),
              () => expectMatchesSchema(1, 'hsdd/contract/schema/nosuch.schema.json')),
          errsWith('no schema at hsdd/contract/schema/nosuch.schema.json'));
      expect(
          () => inDirectory(seed(<String, String>{schemaPath: '{"type": 5}'}),
              () => expectMatchesSchema(1, schemaPath)),
          errsWith('$schemaPath: does not compile under draft 2020-12: type must be string or array: int'));
    });
  });
  group('json_document', () {
    test('decodeJson reads UTF-8 JSON and names what is neither', () {
      expect((decodeJson(utf8.encode('{"a": [1]}')) as JsonValue).value, <String, Object?>{'a': <Object?>[1]});
      expect((decodeJson(<int>[0x7b, 0xff, 0x7d]) as NotJson).reason, 'not UTF-8: Invalid UTF-8 byte (at offset 1)');
      expect((decodeJson(<int>[]) as NotJson).reason, 'not JSON: Unexpected end of input (at offset 0)');
      expect((decodeJson(utf8.encode('notes\n')) as NotJson).reason, 'not JSON: Unexpected character (at offset 0)');
    });
    test('compileSchema compiles under draft 2020-12 or names why not', () {
      expect(compileSchema(utf8.encode(docSchema)), isA<CompiledSchema>());
      expect((compileSchema(utf8.encode('{')) as SchemaProblem).reason, 'not JSON: Unexpected end of input (at offset 1)');
      expect((compileSchema(utf8.encode('{"type": 5}')) as SchemaProblem).reason,
          'does not compile under draft 2020-12: type must be string or array: int');
      for (final String text in <String>['[1]', 'null', '"text"']) {
        expect((compileSchema(utf8.encode(text)) as SchemaProblem).reason,
            'does not compile under draft 2020-12: a schema is a JSON object or a boolean', reason: text);
      }
    });
    test('schemaErrors lists every error in order, and nothing for a valid instance', () {
      final CompiledSchema compiled = compileSchema(utf8.encode(docSchema)) as CompiledSchema;
      expect(schemaErrors(compiled.schema, <String, Object?>{'name': 'a', 'count': 0}), isEmpty);
      expect(schemaErrors(compiled.schema, <String, Object?>{'count': 1}), <String>[
        '# (root): required prop missing: name from {count: 1}',
        '/name: required prop missing: name from {count: 1}',
      ]);
    });
  });
}
```

The two `required prop missing` lines are how `package:json_schema` 5.2.2 reports one missing property (J1, M); the list keeps what it reports.

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/fixture_test.dart`
Expected: FAIL, `package:nidana_contract_check/fixture.dart` and `src/json_document.dart` do not exist.

- [ ] **Step 3: Implement `lib/src/json_document.dart`**

- `decodeJson`: `utf8.decode(bytes)` (malformed bytes rejected), then `jsonDecode`. A `FormatException` from the first gives `not UTF-8: {message} (at offset {offset})`, from the second `not JSON: {message} (at offset {offset})`; without an offset the parenthesis is left out. Never `toString()` of the exception: for `jsonDecode` it prints the source text.
- `compileSchema`: a `NotJson` reason passes through. A decoded value that is neither a `Map` nor a `bool` gives `does not compile under draft 2020-12: a schema is a JSON object or a boolean` (a JSON string must not reach `JsonSchema.create`, which would decode it a second time). Otherwise `JsonSchema.create(value, schemaVersion: SchemaVersion.draft2020_12)`; a `FormatException` or an `ArgumentError` it throws gives `does not compile under draft 2020-12: {message}` (J2). No remote reference is fetched: `create` is synchronous.
- `schemaErrors`: `schema.validate(instance).errors`, each by `toString()`.

- [ ] **Step 4: Implement `lib/fixture.dart`**

Dartdoc for `expectMatchesSchema`, copied from topology-ir@v1's `## Validation`: it fails the current test as `expect` does, listing every validation error, unless the JSON value `instance` validates against the draft 2020-12 schema at `schemaPath`, a path relative to the workspace root, the nearest ancestor of the current directory that holds `hsdd/contract/`. Find the root with `findWorkspaceRoot(Directory.current)` (import `src/shell.dart` with `show findWorkspaceRoot`); read the file at `schemaPath`, its `/` segments joined under the root with `package:path`; then:

| Condition | Result |
|-----------|--------|
| no root | `StateError('no ancestor of {Directory.current.path} holds hsdd/contract/')` |
| no file at `schemaPath` | `StateError('no schema at {schemaPath} under {root path}')` |
| `compileSchema` gives a `SchemaProblem` | `StateError('{schemaPath}: {reason}')` |
| `schemaErrors` is not empty | `fail` of `package:matcher/expect.dart` with `does not match {schemaPath}:` and one line per error, two spaces before it, joined by `\n` |

A validation error is the producer's failure and reads as one; a missing root or schema is a defect of the environment or the fixture, so it is an error. Compile on every call; there is no cache.

- [ ] **Step 5: Run the tests, the analyzer and the formatter**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add packages/nidana_contract_check/lib/src/json_document.dart packages/nidana_contract_check/lib/fixture.dart packages/nidana_contract_check/test/support/sample.dart packages/nidana_contract_check/test/fixture_test.dart
git commit -m "feat(contract_check): the fixture library and draft 2020-12 schemas" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: PENDING and the report

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. `outcome.dart`, `report.dart` and `packages.dart` are pure: no `dart:io`. ADR-001 item 9: a fixture that names a package absent from the workspace's package configuration fails, reported as PENDING rather than as a defect; the tool exits 1 when any fixture fails or is PENDING, and 2 on an environment error. This task adds the `Pending` outcome, its line and its count, the reason an unavailable set carries, and the pure reading of `.dart_tool/package_config.json`; Tasks 3 to 5 produce `Pending` outcomes and reasons. `PackageConfig.parseString` of `package:package_config` 2.2.0 does no I/O and reports a malformed configuration as a `PackageConfigFormatException`, or through `onError` when one is given (P).

**Files:**
- Modify: `packages/nidana_contract_check/lib/src/outcome.dart`
- Modify: `packages/nidana_contract_check/lib/src/report.dart`
- Create: `packages/nidana_contract_check/lib/src/packages.dart`
- Modify: `packages/nidana_contract_check/lib/src/shell.dart` (each `SetUnavailable(set, snapshot.slug)` becomes `SetUnavailable(set, snapshot.slug, notImplemented(set))`)
- Modify: `packages/nidana_contract_check/test/report_test.dart`
- Modify: `packages/nidana_contract_check/test/cli_test.dart` (every summary line it asserts ends `, 0 pending`)
- Test: `packages/nidana_contract_check/test/packages_test.dart`

**Interfaces:**
- Consumes (nidana.model.1): `FixtureOutcome`, `Passed`, `Failed`, `Problem`; `CheckSet`; `SetRun`, `SetChecked(set, slug, outcomes)`, `outcomeLine`, `unavailableLine`, `summaryLine`, `exitCodeOf`, `exitPassed`, `exitFailed`, `exitEnvironment`; `DartLibrary readDartLibrary(String source)` and `DartLibrary.directives` (the URIs of import and export directives, in order).
- Produces:

```dart
// lib/src/outcome.dart
/// The fixture names a package absent from the workspace's package configuration (ADR-001 item 9).
final class Pending extends FixtureOutcome {
  const Pending(super.path, this.packages);
  final List<String> packages; // the absent packages, ascending, at least one
}

// lib/src/report.dart
/// A set that could not run: an environment error, with its [reason].
final class SetUnavailable extends SetRun {
  const SetUnavailable(super.set, super.slug, this.reason);
  final String reason;
}
String notImplemented(CheckSet set); // the reason of a set this version does not implement
String outcomeLine(CheckSet set, FixtureOutcome outcome); // PASS, FAIL, PENDING
String unavailableLine(SetUnavailable run); // 'ERROR {set} {slug}: {reason}'
String summaryLine(List<SetRun> runs); // '{n} fixtures: {p} passed, {f} failed, {q} pending'
int exitCodeOf(List<SetRun> runs);

// lib/src/packages.dart
const String packageConfigPath = '.dart_tool/package_config.json';
/// The names of the packages [packageConfigJson] configures; null when it is no package configuration.
Set<String>? packageNamesOf(String packageConfigJson);
/// Each package a `package:` URI of [library]'s imports and exports names that [packages] lacks, once, ascending.
List<String> absentPackages(DartLibrary library, Set<String> packages);
```

- [ ] **Step 1: Write the failing test**

```dart
// packages/nidana_contract_check/test/packages_test.dart
import 'package:nidana_contract_check/src/dart_library.dart';
import 'package:nidana_contract_check/src/packages.dart';
import 'package:test/test.dart';

const String config = '''
{
  "configVersion": 2,
  "packages": [
    {"name": "matcher", "rootUri": "file:///cache/matcher-0.12.20", "packageUri": "lib/", "languageVersion": "3.4"},
    {"name": "sample", "rootUri": "../packages/sample", "packageUri": "lib/", "languageVersion": "3.13"}
  ],
  "generator": "pub"
}
''';

void main() {
  test('packageNamesOf reads the names of the configured packages', () {
    expect(packageNamesOf(config), <String>{'matcher', 'sample'});
    expect(packageConfigPath, '.dart_tool/package_config.json');
  });
  test('packageNamesOf is null for text that is no package configuration', () {
    for (final String text in <String>[
      '', 'not json', '{}', '{"configVersion": 2}', '{"configVersion": 2, "packages": [{"name": "a"}]}',
    ]) {
      expect(packageNamesOf(text), isNull, reason: text);
    }
  });
  test('absentPackages names each package an import or export names that the configuration lacks', () {
    final DartLibrary library = readDartLibrary('''
import 'dart:async';
import 'package:zeta/zeta.dart';
import 'package:sample/sample.dart' as s;
export 'package:alpha/src/hidden.dart';
import 'package:zeta/other.dart';
import '../other.dart';
''');
    expect(absentPackages(library, <String>{'sample'}), <String>['alpha', 'zeta']);
    expect(absentPackages(library, <String>{'alpha', 'sample', 'zeta'}), isEmpty);
  });
}
```

In `test/report_test.dart`, replace the `unavailable` constant and add `pending`:

```dart
const SetUnavailable unavailable = SetUnavailable(
  CheckSet.surface, 'sample', 'dart analyze exited 64 without a JSON report');
const SetChecked pending = SetChecked(CheckSet.reject, 'sample', <FixtureOutcome>[
  Pending('hsdd/contract/fixture/sample/reject/a.dart', <String>['sample']),
]);
```

In its `lines` group, replace the tests `an unavailable set` and `the summary counts fixtures` with these, and add the last test to its `exitCodeOf` group; the other tests stay:

```dart
    test('a pending fixture names the absent packages', () {
      expect(
        outcomeLine(CheckSet.surface,
            const Pending('hsdd/contract/fixture/sample/surface/use.dart', <String>['sample'])),
        'PENDING surface hsdd/contract/fixture/sample/surface/use.dart: package sample is absent from .dart_tool/package_config.json',
      );
      expect(
        outcomeLine(CheckSet.reject,
            const Pending('hsdd/contract/fixture/sample/reject/a.dart', <String>['alpha', 'zeta'])),
        'PENDING reject hsdd/contract/fixture/sample/reject/a.dart: packages alpha, zeta are absent from .dart_tool/package_config.json',
      );
    });
    test('an unavailable set prints its reason', () {
      expect(unavailableLine(unavailable), 'ERROR surface sample: dart analyze exited 64 without a JSON report');
      expect(unavailableLine(SetUnavailable(CheckSet.behavior, 'sample', notImplemented(CheckSet.behavior))),
          'ERROR behavior sample: this version of nidana_contract_check does not implement the behavior set');
    });
    test('the summary counts passed, failed and pending fixtures', () {
      expect(summaryLine(const <SetRun>[passing, failing, pending, unavailable]),
          '4 fixtures: 2 passed, 1 failed, 1 pending');
      expect(summaryLine(const <SetRun>[SetChecked(CheckSet.structure, 'sample', <FixtureOutcome>[Passed('a')])]),
          '1 fixture: 1 passed, 0 failed, 0 pending');
      expect(summaryLine(const <SetRun>[]), '0 fixtures: 0 passed, 0 failed, 0 pending');
    });
```

```dart
    test('1 when a fixture is pending, 2 when a set is unavailable as well', () {
      expect(exitCodeOf(const <SetRun>[passing, pending]), exitFailed);
      expect(exitCodeOf(const <SetRun>[pending, unavailable]), exitEnvironment);
    });
```

In `test/cli_test.dart`, `6 fixtures: 6 passed, 0 failed` becomes `6 fixtures: 6 passed, 0 failed, 0 pending` and `8 fixtures: 8 passed, 0 failed` becomes `8 fixtures: 8 passed, 0 failed, 0 pending`; its test of an unimplemented set keeps its expected `ERROR surface sample: this version of nidana_contract_check does not implement the surface set`.

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/packages_test.dart packages/nidana_contract_check/test/report_test.dart`
Expected: FAIL, `packages.dart` and `Pending` do not exist and `SetUnavailable` takes no reason.

- [ ] **Step 3: Implement `Pending`, the report and `packages.dart`**

- `outcomeLine`, by an exhaustive `switch` over `FixtureOutcome`: `Pending` gives `PENDING {set} {path}: package {name} is absent from .dart_tool/package_config.json` for one package and `PENDING {set} {path}: packages {a}, {b} are absent from .dart_tool/package_config.json` for more (the names joined by `, `).
- `notImplemented(set)` is `this version of nidana_contract_check does not implement the {set} set`, so the line of an unimplemented set reads as nidana.model.1's did.
- `summaryLine`: over the outcomes of every `SetChecked`, `{n} fixtures: {passed} passed, {failed} failed, {pending} pending`, with `fixture` for one fixture. Every count is always printed, so the line has one form.
- `exitCodeOf`: `exitEnvironment` when any run is a `SetUnavailable`; else `exitFailed` when any outcome is `Failed` or `Pending`; else `exitPassed`.
- `packageNamesOf`: `PackageConfig.parseString(text, Uri.parse('file:///workspace/.dart_tool/package_config.json'), onError: ...)`; the base URI only resolves relative `rootUri`s. Null when `onError` receives an error or `parseString` throws a `FormatException`; otherwise the set of `Package.name`.
- `absentPackages`: the name of a `package:{name}/...` URI is the text between `package:` and the first `/`; `dart:` and relative URIs name no package.
- `shell.dart`: pass `notImplemented(set)` to each `SetUnavailable` it builds. Nothing else in the shell changes in this task.

- [ ] **Step 4: Run the tests, the analyzer and the formatter**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/outcome.dart packages/nidana_contract_check/lib/src/report.dart packages/nidana_contract_check/lib/src/packages.dart packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/test/report_test.dart packages/nidana_contract_check/test/cli_test.dart packages/nidana_contract_check/test/packages_test.dart
git commit -m "feat(contract_check): PENDING outcomes and set reasons in the report" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: The schema set

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. `snapshot.dart` and `schema.dart` are pure; `shell.dart` does the reading. The `schema` set of ADR-001 items 5 and 9: the schema at `hsdd/contract/schema/{slug}.schema.json` compiles under draft 2020-12, every file below `valid/` validates and no file below `invalid/` does. It reads nothing else, so an input or expected tree and a data directory (topic-codegen@v1's `expected/` and `rejected/`, topology-ir@v1's `render/`) are never read. The shell hands the set bytes, so a document that is not UTF-8 is a defect of that document, not an environment error. `run.dart`'s `setsOf` stays as it is: a slug has the schema set when the schema file, `valid/` or `invalid/` exists, so a schema set without its schema file runs and fails at the schema path instead of going unreplayed. The structure set still always runs first, and its failure does not stop a slug's other sets: each set judges its own fixtures.

**Files:**
- Modify: `packages/nidana_contract_check/lib/src/snapshot.dart`
- Create: `packages/nidana_contract_check/lib/src/schema.dart`
- Modify: `packages/nidana_contract_check/lib/src/shell.dart` (`readSnapshot` reads the schema file's and the documents' bytes; the schema branch of `_run`)
- Modify: `packages/nidana_contract_check/test/support/sample.dart` (`snapshotOf`)
- Modify: `packages/nidana_contract_check/test/structure_test.dart` (its one direct `SlugSnapshot(...)` construction)
- Modify: `packages/nidana_contract_check/test/cli_test.dart` (a `the schema set` group)
- Test: `packages/nidana_contract_check/test/schema_test.dart`

**Interfaces:**
- Consumes: Task 1 (`json_document.dart`): `decodeJson`, `JsonValue`, `NotJson`, `compileSchema`, `CompiledSchema`, `SchemaProblem`, `schemaErrors`; test support `docContract`, `docFiles`. Task 2: `outcomeLine`, `summaryLine` with the pending count. nidana.model.1: `FixtureOutcome`, `Passed`, `Failed`, `Problem`, `Rule`; `schemaPath(slug)`, `fixtureDirectory(slug)`, `holdsSource`; `setsOf`; `SetChecked`; test support `changed`, `seed`, `runTool`.
- Produces:

```dart
// lib/src/snapshot.dart: SlugSnapshot's constructor takes schemaBytes and documents in place of hasSchemaFile
final class SlugSnapshot {
  const SlugSnapshot({required this.slug, required this.contractText, required this.schemaBytes,
      required this.directories, required this.files, required this.documents});
  /// hsdd/contract/schema/{slug}.schema.json as read; null when it is absent.
  final List<int>? schemaBytes;
  bool get hasSchemaFile => schemaBytes != null;
  /// Each file [holdsDocument] accepts, by its relative `/`-separated path, as read.
  final Map<String, List<int>> documents;
  // slug, contractText, directories, files as before
}
/// Whether a file is a document the schema set judges: any file below valid/ or invalid/.
bool holdsDocument(String relativePath);

// lib/src/schema.dart
enum SchemaRule implements Rule {
  schemaFile('schema-file'), document('document'), valid('valid'), invalid('invalid');
}
List<FixtureOutcome> checkSchema(SlugSnapshot snapshot);

// test/support/sample.dart
/// [bytes] are files given as raw bytes, keyed by path from the workspace root; a path in both maps takes its bytes.
SlugSnapshot snapshotOf(String slug, Map<String, String> files,
    {Map<String, List<int>> bytes = const <String, List<int>>{}});
```

- [ ] **Step 1: Write the failing test**

```dart
// packages/nidana_contract_check/test/schema_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/run.dart';
import 'package:nidana_contract_check/src/schema.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String d = 'hsdd/contract/fixture/doc/';
const String schemaFile = 'hsdd/contract/schema/doc.schema.json';

List<FixtureOutcome> check(Map<String, String?> changes,
        {Map<String, List<int>> bytes = const <String, List<int>>{}}) =>
    checkSchema(snapshotOf('doc', changed(docFiles, changes), bytes: bytes));

/// The problems at [path] as 'rule (detail)'; empty when it passed or has no outcome.
List<String> at(List<FixtureOutcome> outcomes, String path) => <String>[
      for (final FixtureOutcome o in outcomes)
        if (o is Failed && o.path == path)
          for (final Problem p in o.problems) '${p.rule.label} (${p.detail})',
    ];

void main() {
  test('the clean doc slug passes: the schema file, then each document by path', () {
    final List<FixtureOutcome> o = check(const <String, String?>{});
    expect(o.map((FixtureOutcome x) => x.path), <String>[
      schemaFile,
      '${d}invalid/extra-property.json',
      '${d}invalid/negative-count.json',
      '${d}valid/minimal.json',
    ]);
    expect(o, everyElement(isA<Passed>()));
  });
  test('a valid/ document that does not validate lists every error', () {
    expect(
      at(check(<String, String?>{'${d}valid/minimal.json': '{"name": 1, "count": -1, "extra": true}'}),
          '${d}valid/minimal.json'),
      <String>[
        'valid (does not validate: /name: type: wanted [string] got 1; /count: minimum violated (-1 < 0); # (root): unallowed additional property extra)',
      ],
    );
  });
  test('an invalid/ document that validates', () {
    expect(
      at(check(<String, String?>{'${d}invalid/negative-count.json': '{"name": "a", "count": 1}'}),
          '${d}invalid/negative-count.json'),
      <String>['invalid (validates against hsdd/contract/schema/doc.schema.json)'],
    );
  });
  test('an empty, non-JSON or non-UTF-8 document is a defect of that document', () {
    final List<FixtureOutcome> o = check(
      <String, String?>{'${d}valid/empty.json': '', '${d}valid/notes.md': 'notes\n'},
      bytes: <String, List<int>>{'${d}invalid/latin1.json': <int>[0x7b, 0xff, 0x7d]},
    );
    expect(at(o, '${d}valid/empty.json'), <String>['document (not JSON: Unexpected end of input (at offset 0))']);
    expect(at(o, '${d}valid/notes.md'), <String>['document (not JSON: Unexpected character (at offset 0))']);
    expect(at(o, '${d}invalid/latin1.json'), <String>['document (not UTF-8: Invalid UTF-8 byte (at offset 1))']);
  });
  test('every file below valid/ and invalid/ is a document, nested ones included, and nothing else is', () {
    final List<FixtureOutcome> o = check(<String, String?>{'${d}valid/nested/deep.json': '{"name": "b", "count": 2}'});
    expect(o.map((FixtureOutcome x) => x.path), contains('${d}valid/nested/deep.json'));
    expect(o, everyElement(isA<Passed>()));
    for (final String path in <String>['valid/a.json', 'invalid/x/y.json', 'valid/notes.md']) {
      expect(holdsDocument(path), isTrue, reason: path);
    }
    for (final String path in <String>[
      'expected/topics.g.dart', 'input/topics.yaml', 'render/checkout.mmd',
      'rejected/two-documents.yaml', 'surface/use.dart', 'validx/a.json',
    ]) {
      expect(holdsDocument(path), isFalse, reason: path);
    }
  });
  test('without the schema file the slug keeps the set, which fails at the schema path alone', () {
    final Map<String, String> files = changed(docFiles, <String, String?>{schemaFile: null});
    expect(setsOf(snapshotOf('doc', files)), contains(CheckSet.schema));
    final List<FixtureOutcome> o = checkSchema(snapshotOf('doc', files));
    expect(o.map((FixtureOutcome x) => x.path), <String>[schemaFile]);
    expect(at(o, schemaFile), <String>['schema-file (absent)']);
  });
  test('a schema that is not JSON or does not compile fails alone', () {
    final List<FixtureOutcome> notJson = check(<String, String?>{schemaFile: '{'});
    expect(notJson.map((FixtureOutcome x) => x.path), <String>[schemaFile]);
    expect(at(notJson, schemaFile), <String>['schema-file (not JSON: Unexpected end of input (at offset 1))']);
    expect(at(check(<String, String?>{schemaFile: '{"type": 5}'}), schemaFile),
        <String>['schema-file (does not compile under draft 2020-12: type must be string or array: int)']);
  });
}
```

Add this group to `test/cli_test.dart` (it needs `import 'dart:io';`, which the file has):

```dart
  group('the schema set', () {
    const String d = 'hsdd/contract/fixture/doc/';
    test('a clean doc slug passes with one line per fixture', () async {
      final ProcessResult r = await runTool(<String>['doc'], workingDirectory: seed(docFiles));
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r), <String>[
        'PASS structure hsdd/contract/doc.md',
        'PASS structure $d',
        'PASS schema hsdd/contract/schema/doc.schema.json',
        'PASS schema ${d}invalid/extra-property.json',
        'PASS schema ${d}invalid/negative-count.json',
        'PASS schema ${d}valid/minimal.json',
        '6 fixtures: 6 passed, 0 failed, 0 pending',
      ]);
    });
    test('a document that is not UTF-8 fails as a fixture, not as an environment error', () async {
      final Directory root = seed(docFiles);
      File('${root.path}/${d}valid/latin1.json').writeAsBytesSync(<int>[0x7b, 0xff, 0x7d]);
      final ProcessResult r = await runTool(<String>['doc', '--set', 'schema'], workingDirectory: root);
      expect(r.exitCode, 1, reason: all(r));
      expect(lines(r), contains('FAIL schema ${d}valid/latin1.json: document (not UTF-8: Invalid UTF-8 byte (at offset 1))'));
    });
    test("a structure failure does not stop the slug's other sets", () async {
      final ProcessResult r = await runTool(<String>['doc'],
          workingDirectory: seed(changed(docFiles, <String, String?>{
            'hsdd/contract/doc.md': docContract.replaceFirst('- **G1**', '- **G2** uncovered.\n- **G1**'),
          })));
      expect(r.exitCode, 1, reason: all(r));
      expect(lines(r), containsAll(<String>[
        'FAIL structure $d: coverage (G2 uncovered)',
        'PASS schema ${d}valid/minimal.json',
      ]));
    });
  });
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/schema_test.dart packages/nidana_contract_check/test/cli_test.dart`
Expected: FAIL, `schema.dart`, `holdsDocument` and `snapshotOf`'s `bytes` do not exist; the cli group fails on `ERROR schema doc: this version of nidana_contract_check does not implement the schema set`.

- [ ] **Step 3: Extend the snapshot, its readers and the test support**

- `holdsDocument(p)`: `p`'s first `/` segment is exactly `valid` or `invalid` and there is a segment after it.
- `readSnapshot` in `shell.dart`: `schemaBytes` is `readAsBytesSync()` of `hsdd/contract/schema/{slug}.schema.json` when it exists, else null; `documents` holds `readAsBytesSync()` of every entry it already records as a file whose relative path `holdsDocument` accepts (a link is read through, as nidana.model.1 reads a linked `.dart` file). Entries whose path has a segment beginning with `.` stay out, as before.
- `snapshotOf` in `test/support/sample.dart`: `schemaBytes` and each document come from `bytes` when the path is there, else from `utf8.encode` of `files`; a path only in `bytes` is a file of the snapshot too.
- `test/structure_test.dart`'s direct construction passes `schemaBytes: clean.schemaBytes` and `documents: clean.documents` in place of `hasSchemaFile:`. `structure.dart` and `run.dart` keep reading `hasSchemaFile`.

- [ ] **Step 4: Implement `checkSchema(SlugSnapshot snapshot) -> List<FixtureOutcome>` in `lib/src/schema.dart` and dispatch it**

The schema file is the first subject, by `schemaPath(slug)`; then every document, by its path from the workspace root (`{fixtureDirectory(slug)}{relative}`), ascending.

| Condition | Outcome |
|-----------|---------|
| `schemaBytes` is null | only `Failed(schemaPath, [schema-file 'absent'])` |
| `compileSchema` gives `SchemaProblem(reason)` | only `Failed(schemaPath, [schema-file reason])` |
| it compiles | `Passed(schemaPath)`, then one outcome per document |
| `decodeJson` of a document gives `NotJson(reason)` | `Failed(document, [document reason])` |
| a document below `valid/` with errors | `Failed(document, [valid 'does not validate: {schemaErrors joined by "; "}'])` |
| a document below `invalid/` without errors | `Failed(document, [invalid 'validates against {schemaPath}'])` |
| otherwise | `Passed(document)` |

When the schema cannot be read or compiled, no document can be judged, so the schema file's line is the set's only line. In `shell.dart`'s `_run`, `CheckSet.schema` gives `SetChecked(set, snapshot.slug, checkSchema(snapshot))`.

- [ ] **Step 5: Run the tests, the analyzer and the formatter**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 6: Replay the committed schema sets**

Run: `fvm dart run nidana_contract_check --all --set structure,schema; echo "exit: $?"`
Expected: `exit: 0`; 102 `PASS structure` lines; 46 `PASS schema` lines for topology-ir (its schema file, 38 documents below `invalid/`, 7 below `valid/`) and 58 for topic-codegen (its schema file, 53 below `invalid/`, 4 below `valid/`); no `FAIL` or `ERROR` line; then `206 fixtures: 206 passed, 0 failed, 0 pending`. `package:json_schema` 5.2.2 accepts every committed `valid/` document and rejects every `invalid/` one (J6). A `FAIL` on a committed schema or document is a contract gap (ADR-001 item 8): edit nothing under `hsdd/`; stop and report BLOCKED with the line, the rule and the fix you would propose.

- [ ] **Step 7: Commit**

```bash
git add packages/nidana_contract_check/lib/src/snapshot.dart packages/nidana_contract_check/lib/src/schema.dart packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/test/support/sample.dart packages/nidana_contract_check/test/structure_test.dart packages/nidana_contract_check/test/cli_test.dart packages/nidana_contract_check/test/schema_test.dart
git commit -m "feat(contract_check): the schema set" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: The surface and reject sets

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. The three library files are pure: no `dart:io`. ADR-001 item 4: a `surface/` library passes when the analyzer reports no diagnostic in it, at any severity; a `reject/` library passes when the (line, code) pairs reported in it, at every severity, equal the pairs its markers name, and it has at least one marker; a marker `// expect-diagnostic: {code}` on its own line names `{code}` on the next line. A library that imports a package absent from the workspace's package configuration is `Pending` whatever is reported. The shell (Task 5) runs one `dart analyze --format=json` and hands these functions its diagnostics, attributed to fixtures. What `dart analyze --format=json` prints (`docs/auto-run/experiments/replay-sets-plan/output.txt`): stdout is one JSON document `{"version":1,"diagnostics":[...]}` and nothing else (A1); each diagnostic has `code` (lowercase), `severity` (`ERROR`, `WARNING` or `INFO`), `location.file` (absolute, symbolic links resolved: A3), `location.range.start.line` (1-based) and `problemMessage`; the report is identical with and without `--fatal-infos`, which changes only the exit code (A2, A5); a path that does not exist gives exit 64, the usage text on stderr and nothing on stdout (A6); only the analyzed files' diagnostics are reported, not those of a library a fixture imports (A1).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/analysis.dart`
- Create: `packages/nidana_contract_check/lib/src/surface.dart`
- Create: `packages/nidana_contract_check/lib/src/reject.dart`
- Modify: `packages/nidana_contract_check/test/support/sample.dart` (add `analysisFiles`)
- Test: `packages/nidana_contract_check/test/analysis_test.dart`, `packages/nidana_contract_check/test/analyzed_sets_test.dart`

**Interfaces:**
- Consumes: Task 2: `Pending(path, packages)`, `absentPackages(DartLibrary, Set<String>)`, `outcomeLine`. Task 3: `snapshotOf(slug, files, {bytes})`. nidana.model.1: `SlugSnapshot.files`, `holdsSource`, `fixtureDirectory`; `readDartLibrary`, `DartLibrary.markers` (`Marker.line`, `Marker.code`, null when malformed); `CheckSet`; `FixtureOutcome`, `Passed`, `Failed`, `Problem`, `Rule`; test support `sampleFiles`, `changed`.
- Produces:

```dart
// lib/src/analysis.dart
final class Diagnostic {
  const Diagnostic({required this.file, required this.line, required this.severity,
      required this.code, required this.message});
  final String file; // as dart analyze reports it: absolute, symbolic links resolved
  final int line; // 1-based
  final String severity; // ERROR, WARNING or INFO
  final String code; // lowercase, as reported
  final String message; // problemMessage
}
/// The diagnostics of `dart analyze --format=json`'s [stdout]; null when it holds no such report.
List<Diagnostic>? parseAnalysis(String stdout);
/// The reason of an analysis that printed no report.
String analysisFailure(int exitCode, String stderr);
typedef GroupedDiagnostics = ({Map<String, List<Diagnostic>> byFixture, List<String> strays});
/// [reported] by fixture path from the workspace root, through [fixtureOf], which maps an
/// analyzer path to a fixture; [strays] are the reported files [fixtureOf] lacks, once, ascending.
GroupedDiagnostics groupDiagnostics(List<Diagnostic> reported, Map<String, String> fixtureOf);
/// `line {line}: {severity} {code}: {message}`.
String diagnosticText(Diagnostic diagnostic);
typedef SetLibrary = ({String path, DartLibrary library, List<String> absent});
/// Every library below `{set}/` for set surface or reject, by path from the workspace root,
/// ascending, with the packages it names that [packages] lacks; empty for every other set.
List<SetLibrary> setLibraries(SlugSnapshot snapshot, CheckSet set, Set<String> packages);
/// The paths of [setLibraries] whose `absent` is empty: what `dart analyze` must analyze.
List<String> analysisTargets(SlugSnapshot snapshot, CheckSet set, Set<String> packages);

// lib/src/surface.dart
enum SurfaceRule implements Rule { diagnostic('diagnostic') }
List<FixtureOutcome> checkSurface(SlugSnapshot snapshot,
    {required Set<String> packages, required Map<String, List<Diagnostic>> diagnostics});

// lib/src/reject.dart
enum RejectRule implements Rule {
  marker('marker'), missingDiagnostic('missing-diagnostic'), unexpectedDiagnostic('unexpected-diagnostic');
}
List<FixtureOutcome> checkReject(SlugSnapshot snapshot,
    {required Set<String> packages, required Map<String, List<Diagnostic>> diagnostics});

// test/support/sample.dart
/// [sampleFiles] with a surface library that has a warning, one that imports a package no
/// workspace holds, and four more reject libraries; the seeds of the analyzer tests.
const Map<String, String> analysisFiles;
```

`diagnostics` maps a fixture path from the workspace root to what was reported in it; a library without an entry has no diagnostic.

- [ ] **Step 1: Write the failing test and the analysis seeds**

`analysisFiles` in `test/support/sample.dart` is `<String, String>{...sampleFiles, ...}` with these six files under `hsdd/contract/fixture/sample/`, each a raw string that starts on the line after `r'''` and ends with exactly one newline (experiment A11 analyzed exactly these against Task 5's stand-in package). `surface/dirty.dart`:

```dart
import 'dart:async';

import 'package:sample/sample.dart';

Sample use() => Sample();
```

`surface/pending.dart`:

```dart
import 'package:producer/producer.dart';

Producer use() => Producer();
```

`reject/assigns_final.dart`:

```dart
// covers: G1
import 'package:sample/sample.dart';

void f(Sample s) {
  // expect-diagnostic: assignment_to_final
  s.count = 1;
}
```

`reject/extra_warning.dart`:

```dart
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class Local extends Sample {}

void f() {
  final int unused = 0;
}
```

`reject/wrong_code.dart`:

```dart
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: undefined_class
final class Local extends Sample {}
```

`reject/wrong_line.dart`:

```dart
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
const int before = 0;
final class Local extends Sample {}
```

```dart
// packages/nidana_contract_check/test/analysis_test.dart
import 'package:nidana_contract_check/src/analysis.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String s = 'hsdd/contract/fixture/sample/';

/// One diagnostic as `dart analyze --format=json` prints it (experiment A1), every key included.
const String report = r'''{"version":1,"diagnostics":[{"code":"unused_import","severity":"WARNING","type":"STATIC_WARNING","location":{"file":"/w/hsdd/contract/fixture/sample/surface/dirty.dart","range":{"start":{"offset":7,"line":1,"column":8},"end":{"offset":19,"line":1,"column":20}}},"problemMessage":"Unused import: 'dart:async'.","correctionMessage":"Try removing the import directive.","documentation":"https://dart.dev/diagnostics/unused_import"}]}''';

String fields(Diagnostic d) => '${d.file}|${d.line}|${d.severity}|${d.code}|${d.message}';

void main() {
  group('parseAnalysis', () {
    test('reads each diagnostic', () {
      expect(parseAnalysis(report)!.map(fields), <String>[
        "/w/hsdd/contract/fixture/sample/surface/dirty.dart|1|WARNING|unused_import|Unused import: 'dart:async'.",
      ]);
      expect(parseAnalysis('{"version":1,"diagnostics":[]}'), isEmpty);
    });
    test('ignores text before the JSON document', () {
      expect(parseAnalysis('A notice.\n$report')!.map(fields), hasLength(1));
    });
    test('is null when stdout holds no report', () {
      for (final String stdout in <String>[
        '', 'Usage: dart analyze [arguments] [<directory>]', '{"version":1}',
        '{"version":1,"diagnostics":[{"code":1}]}', report.substring(0, 40),
      ]) {
        expect(parseAnalysis(stdout), isNull, reason: stdout);
      }
    });
  });
  test('analysisFailure names the exit code and the first line of stderr', () {
    expect(
      analysisFailure(64, "\nDirectory or file doesn't exist: x.dart\n\nUsage: dart analyze [arguments] [<directory>]\n"),
      "dart analyze exited 64 without a JSON report: Directory or file doesn't exist: x.dart",
    );
    expect(analysisFailure(1, ''), 'dart analyze exited 1 without a JSON report');
  });
  test('diagnosticText', () {
    expect(diagnosticText(const Diagnostic(file: '/w/a.dart', line: 3, severity: 'INFO', code: 'c', message: 'm.')),
        'line 3: INFO c: m.');
  });
  test('groupDiagnostics attributes each diagnostic to its fixture and names the files it cannot', () {
    Diagnostic at(String file, int line) =>
        Diagnostic(file: file, line: line, severity: 'ERROR', code: 'x', message: 'm');
    final GroupedDiagnostics g = groupDiagnostics(
      <Diagnostic>[at('/private/w/a.dart', 1), at('/w/a.dart', 2), at('/w/b.dart', 3), at('/elsewhere/c.dart', 4), at('/elsewhere/c.dart', 5)],
      <String, String>{'/private/w/a.dart': '${s}surface/a.dart', '/w/a.dart': '${s}surface/a.dart', '/w/b.dart': '${s}reject/b.dart'},
    );
    expect(
      g.byFixture.map((String path, List<Diagnostic> ds) =>
          MapEntry<String, List<int>>(path, ds.map((Diagnostic d) => d.line).toList())),
      <String, List<int>>{'${s}surface/a.dart': <int>[1, 2], '${s}reject/b.dart': <int>[3]},
    );
    expect(g.strays, <String>['/elsewhere/c.dart']);
  });
  group('the libraries a set analyzes', () {
    final SlugSnapshot snapshot = snapshotOf('sample', analysisFiles);
    test('setLibraries: every library below surface/ or reject/, by path, with the absent packages it names', () {
      expect(
        setLibraries(snapshot, CheckSet.surface, const <String>{'sample'})
            .map((SetLibrary l) => '${l.path} [${l.absent.join(', ')}]'),
        <String>['${s}surface/dirty.dart []', '${s}surface/pending.dart [producer]', '${s}surface/use.dart []'],
      );
    });
    test('analysisTargets: those that import no absent package; never behavior/ or another set', () {
      expect(analysisTargets(snapshot, CheckSet.surface, const <String>{'sample'}),
          <String>['${s}surface/dirty.dart', '${s}surface/use.dart']);
      expect(analysisTargets(snapshot, CheckSet.reject, const <String>{'sample'}), <String>[
        '${s}reject/assigns_final.dart', '${s}reject/extra_warning.dart', '${s}reject/sample_is_closed.dart',
        '${s}reject/wrong_code.dart', '${s}reject/wrong_line.dart',
      ]);
      expect(analysisTargets(snapshot, CheckSet.behavior, const <String>{'sample'}), isEmpty);
      expect(analysisTargets(snapshot, CheckSet.schema, const <String>{'sample'}), isEmpty);
      expect(analysisTargets(snapshot, CheckSet.surface, const <String>{}), isEmpty);
    });
  });
}
```

```dart
// packages/nidana_contract_check/test/analyzed_sets_test.dart
import 'package:nidana_contract_check/src/analysis.dart';
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/reject.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/surface.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String closed = "The class 'Sample' can't be extended outside of its library because it's a final class.";
const Set<String> withSample = <String>{'sample'};

/// A diagnostic reported in the fixture at [path].
Diagnostic reportedAt(String path, int line, String severity, String code, String message) =>
    Diagnostic(file: '/w/$path', line: line, severity: severity, code: code, message: message);

/// What dart analyze reported for [analysisFiles] under the stand-in package (experiment A11).
final Map<String, List<Diagnostic>> reported = <String, List<Diagnostic>>{
  '${s}reject/assigns_final.dart': <Diagnostic>[
    reportedAt('${s}reject/assigns_final.dart', 6, 'ERROR', 'assignment_to_final', "'count' can't be used as a setter because it's final."),
  ],
  '${s}reject/extra_warning.dart': <Diagnostic>[
    reportedAt('${s}reject/extra_warning.dart', 5, 'ERROR', 'invalid_use_of_type_outside_library', closed),
    reportedAt('${s}reject/extra_warning.dart', 8, 'WARNING', 'unused_local_variable', "The value of the local variable 'unused' isn't used."),
  ],
  '${s}reject/sample_is_closed.dart': <Diagnostic>[
    reportedAt('${s}reject/sample_is_closed.dart', 6, 'ERROR', 'invalid_use_of_type_outside_library', closed),
  ],
  '${s}reject/wrong_code.dart': <Diagnostic>[
    reportedAt('${s}reject/wrong_code.dart', 5, 'ERROR', 'invalid_use_of_type_outside_library', closed),
  ],
  '${s}reject/wrong_line.dart': <Diagnostic>[
    reportedAt('${s}reject/wrong_line.dart', 6, 'ERROR', 'invalid_use_of_type_outside_library', closed),
  ],
  '${s}surface/dirty.dart': <Diagnostic>[
    reportedAt('${s}surface/dirty.dart', 1, 'WARNING', 'unused_import', "Unused import: 'dart:async'."),
  ],
};

SlugSnapshot snapshotWith(Map<String, String?> changes) => snapshotOf('sample', changed(analysisFiles, changes));

List<String> surfaceLines(SlugSnapshot snapshot, Map<String, List<Diagnostic>> diagnostics,
        {Set<String> packages = withSample}) =>
    checkSurface(snapshot, packages: packages, diagnostics: diagnostics)
        .map((FixtureOutcome o) => outcomeLine(CheckSet.surface, o)).toList();

List<String> rejectLines(SlugSnapshot snapshot, Map<String, List<Diagnostic>> diagnostics,
        {Set<String> packages = withSample}) =>
    checkReject(snapshot, packages: packages, diagnostics: diagnostics)
        .map((FixtureOutcome o) => outcomeLine(CheckSet.reject, o)).toList();

void main() {
  group('the surface set', () {
    test('one outcome per library by path: clean passes, a diagnostic fails, an absent package is pending', () {
      expect(surfaceLines(snapshotWith(const <String, String?>{}), reported), <String>[
        "FAIL surface ${s}surface/dirty.dart: diagnostic (line 1: WARNING unused_import: Unused import: 'dart:async'.)",
        'PENDING surface ${s}surface/pending.dart: package producer is absent from .dart_tool/package_config.json',
        'PASS surface ${s}surface/use.dart',
      ]);
    });
    test('a diagnostic at any severity fails, listed by line', () {
      expect(
        surfaceLines(snapshotWith(const <String, String?>{}), <String, List<Diagnostic>>{
          '${s}surface/use.dart': <Diagnostic>[
            reportedAt('${s}surface/use.dart', 3, 'INFO', 'deprecated_member_use', "'old' is deprecated and shouldn't be used."),
            reportedAt('${s}surface/use.dart', 1, 'ERROR', 'uri_does_not_exist', "Target of URI doesn't exist: 'package:sample/gone.dart'."),
          ],
        }).last,
        "FAIL surface ${s}surface/use.dart: diagnostic (line 1: ERROR uri_does_not_exist: Target of URI doesn't exist: 'package:sample/gone.dart'.); diagnostic (line 3: INFO deprecated_member_use: 'old' is deprecated and shouldn't be used.)",
      );
    });
    test('a library nested below surface/ is a surface library', () {
      expect(
        surfaceLines(snapshotWith(<String, String?>{
          '${s}surface/more/extra.dart': "import 'package:sample/sample.dart';\n\nSample extra() => Sample();\n",
        }), const <String, List<Diagnostic>>{}),
        contains('PASS surface ${s}surface/more/extra.dart'),
      );
    });
  });
  group('the reject set', () {
    test('the reported (line, code) pairs against the pairs the markers name', () {
      expect(rejectLines(snapshotWith(const <String, String?>{}), reported), <String>[
        'PASS reject ${s}reject/assigns_final.dart',
        "FAIL reject ${s}reject/extra_warning.dart: unexpected-diagnostic (line 8: WARNING unused_local_variable: The value of the local variable 'unused' isn't used.)",
        'PASS reject ${s}reject/sample_is_closed.dart',
        'FAIL reject ${s}reject/wrong_code.dart: missing-diagnostic (line 5: undefined_class, named by the marker on line 4, not reported); unexpected-diagnostic (line 5: ERROR invalid_use_of_type_outside_library: $closed)',
        'FAIL reject ${s}reject/wrong_line.dart: missing-diagnostic (line 5: invalid_use_of_type_outside_library, named by the marker on line 4, not reported); unexpected-diagnostic (line 6: ERROR invalid_use_of_type_outside_library: $closed)',
      ]);
    });
    test('the pairs form a set: the marked code twice on its line passes, once more on another line fails', () {
      const String path = '${s}reject/sample_is_closed.dart';
      Diagnostic onLine(int line) => reportedAt(path, line, 'ERROR', 'invalid_use_of_type_outside_library', closed);
      expect(rejectLines(snapshotWith(const <String, String?>{}), <String, List<Diagnostic>>{path: <Diagnostic>[onLine(6), onLine(6)]}),
          contains('PASS reject $path'));
      expect(rejectLines(snapshotWith(const <String, String?>{}), <String, List<Diagnostic>>{path: <Diagnostic>[onLine(6), onLine(3)]}),
          contains('FAIL reject $path: unexpected-diagnostic (line 3: ERROR invalid_use_of_type_outside_library: $closed)'));
    });
    test('a marked diagnostic that is not reported', () {
      expect(rejectLines(snapshotWith(const <String, String?>{}), const <String, List<Diagnostic>>{}),
          contains('FAIL reject ${s}reject/sample_is_closed.dart: missing-diagnostic (line 6: invalid_use_of_type_outside_library, named by the marker on line 5, not reported)'));
    });
    test('a library without a marker fails, with or without diagnostics; a malformed marker names nothing', () {
      const String path = '${s}reject/no_marker.dart';
      final SlugSnapshot snapshot = snapshotWith(<String, String?>{
        path: "// covers: G1\nimport 'package:sample/sample.dart';\n\n// expect-diagnostic: Bad_Code\nfinal class Local extends Sample {}\n",
      });
      expect(rejectLines(snapshot, const <String, List<Diagnostic>>{}),
          contains('FAIL reject $path: marker (no // expect-diagnostic: marker)'));
      expect(rejectLines(snapshot, <String, List<Diagnostic>>{
        path: <Diagnostic>[reportedAt(path, 5, 'ERROR', 'invalid_use_of_type_outside_library', closed)],
      }), contains('FAIL reject $path: marker (no // expect-diagnostic: marker); unexpected-diagnostic (line 5: ERROR invalid_use_of_type_outside_library: $closed)'));
    });
    test('a library that imports an absent package is pending, whatever is reported', () {
      final List<String> lines = rejectLines(snapshotWith(const <String, String?>{}), reported, packages: const <String>{});
      expect(lines, hasLength(5));
      expect(lines, everyElement(startsWith('PENDING reject ')));
      expect(lines.first, 'PENDING reject ${s}reject/assigns_final.dart: package sample is absent from .dart_tool/package_config.json');
    });
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/analysis_test.dart packages/nidana_contract_check/test/analyzed_sets_test.dart`
Expected: FAIL, `analysis.dart`, `surface.dart`, `reject.dart` and `analysisFiles` do not exist.

- [ ] **Step 3: Implement `lib/src/analysis.dart`**

- `parseAnalysis`: decode `stdout` from its first `{` (text before it is ignored; none is printed today, A1). The result is null unless the document is a map whose `diagnostics` is a list of maps, each with a `String` `code`, a `String` `severity`, a `String` `location.file`, an `int` `location.range.start.line` and a `String` `problemMessage`; other keys are ignored. A `FormatException` from `jsonDecode` gives null.
- `analysisFailure`: `dart analyze exited {exitCode} without a JSON report`, then `: {line}` with the first line of `stderr` that is not blank, trimmed, when there is one.
- `groupDiagnostics`: each diagnostic whose `file` is a key of `fixtureOf` joins the list of `fixtureOf[file]`, in reported order; every other `file` is a stray.
- `setLibraries`: for `CheckSet.surface` and `CheckSet.reject`, every entry of `snapshot.files` whose relative path `holdsSource` accepts, begins with `{set.name}/` and has a source; `path` is `{fixtureDirectory(slug)}{relative}`, `library` is `readDartLibrary` of the source, `absent` is `absentPackages(library, packages)`; ascending by `path`. Any other set gives an empty list.

- [ ] **Step 4: Implement `checkSurface` in `lib/src/surface.dart` and `checkReject` in `lib/src/reject.dart`**

One outcome per `setLibraries` entry, in its order. A non-empty `absent` gives `Pending(path, absent)` before anything is compared.

- **Surface:** the library's diagnostics sorted by line, then code, then message; none gives `Passed`, else `Failed` with one `diagnostic` problem each, its detail `diagnosticText`.
- **Reject:** the expected pairs are `(marker.line + 1, marker.code)` for each marker whose `code` is not null; the reported pairs are the `(line, code)` of the library's diagnostics, as a set, each pair keeping the first diagnostic that gives it. The problems, in this order: `marker` `no // expect-diagnostic: marker` when there is no expected pair; then line by line, ascending, each expected pair not reported (codes ascending) as `missing-diagnostic` `line {n}: {code}, named by the marker on line {n - 1}, not reported`, then each reported pair not expected (codes ascending) as `unexpected-diagnostic` with `diagnosticText` of its diagnostic. No problem gives `Passed`. A malformed marker (`code` null) names nothing here; the structure set reports it.

- [ ] **Step 5: Run the tests, the analyzer and the formatter**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add packages/nidana_contract_check/lib/src/analysis.dart packages/nidana_contract_check/lib/src/surface.dart packages/nidana_contract_check/lib/src/reject.dart packages/nidana_contract_check/test/support/sample.dart packages/nidana_contract_check/test/analysis_test.dart packages/nidana_contract_check/test/analyzed_sets_test.dart
git commit -m "feat(contract_check): the surface and reject sets" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: The shell: one analysis per replay

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. `shell.dart` is the only library that imports `dart:io`; it reads, runs and prints, and leaves every decision to the pure core. This task makes the replay async, runs the `surface` and `reject` sets with one `dart analyze` per replay over every library they analyze across all slugs (none when there is none), and turns what keeps a set from running into `SetUnavailable` reasons. Facts (`docs/auto-run/experiments/replay-sets-plan/output.txt`): `Platform.resolvedExecutable` is the SDK's `dart` under `fvm dart run` and `fvm dart test` (X1), and `fvm` runs no `dart` inside a temporary directory (W0); a process started with a symbolic link as its working directory reads `Directory.current` resolved (X2); one `dart analyze --format=json` takes several file paths and runs in about 0.1 to 0.4 s, over the 65 committed surface and reject libraries too (A1, A10); the paths it reports are symlink-resolved (A3); a fixture under `hsdd/contract/fixture/` is analyzed under `hsdd/contract/fixture/analysis_options.yaml` when given by path, though the root options exclude `hsdd/**` (A8, A9); a temporary workspace with a stand-in package and no hosted dependency resolves with `pub get --offline` in about 0.1 s (W1); the repository's bin script, run by absolute path from such a workspace, resolves its own packages from its own location (A12).

**Files:**
- Modify: `packages/nidana_contract_check/lib/src/shell.dart`
- Create: `packages/nidana_contract_check/test/support/workspace.dart`
- Modify: `packages/nidana_contract_check/test/cli_test.dart`

**Interfaces:**
- Consumes: Task 2: `Pending`, `SetUnavailable(set, slug, reason)`, `notImplemented`, `packageConfigPath`, `packageNamesOf`. Task 3: `checkSchema`, `holdsDocument`. Task 4: `Diagnostic`, `parseAnalysis`, `analysisFailure`, `groupDiagnostics`, `analysisTargets`, `checkSurface`, `checkReject`; test support `analysisFiles`. nidana.model.1: `findWorkspaceRoot`, `readSnapshot`, `parseRequest`, `plannedSets`, `checkStructure`, the report functions; test support `sampleFiles`, `seed`, `runTool`, and in `cli_test.dart` the helpers `lines`, `all`, `cleanLines` and the constant `s`.
- Produces:

```dart
// lib/src/shell.dart
/// The names of the directories directly under hsdd/contract/fixture/, hidden ones excluded; empty
/// when it is absent. Throws FileSystemException for a symbolic link directly under it.
Set<String> discoverSlugs(Directory root);
/// Parses, replays, prints one line per fixture to [out] and errors to [err]; returns the exit code.
/// [dart] runs `dart analyze`; null means Platform.resolvedExecutable, the dart running the tool.
Future<int> runCli(List<String> arguments, {required Directory workingDirectory,
    required StringSink out, required StringSink err, String? dart});

// test/support/workspace.dart
/// `packages/sample/lib/sample.dart` of the seeded workspace.
const String standInSample;
/// [files] in a fresh temporary pub workspace resolved offline: its root's one member is the
/// stand-in package `sample` unless [standIn] is false, and the fixtures' analysis options are
/// this workspace's hsdd/contract/fixture/analysis_options.yaml.
Future<Directory> seedWorkspace(Map<String, String> files, {bool standIn = true});
```

- [ ] **Step 1: Write the failing test and the seeded workspace**

`test/support/workspace.dart`: `standInSample` is this raw string (starting on the line after `r'''`, ending with one newline):

```dart
/// The stand-in package the replay tool's tests analyze fixtures against.
library;

/// A class other libraries may construct but never extend.
final class Sample {
  const Sample();

  /// A final field: assigning it reports `assignment_to_final`.
  final int count = 0;
}
```

`seedWorkspace` writes, with `seed`, `files` plus: `pubspec.yaml` with the lines `name: stand_in_workspace`, `publish_to: none`, `environment:`, `  sdk: ^3.13.0` and, unless `standIn` is false, `workspace:` and `  - packages/sample`; when `standIn`, `packages/sample/pubspec.yaml` with `name: sample`, `publish_to: none`, `environment:`, `  sdk: ^3.13.0`, `resolution: workspace`, and `packages/sample/lib/sample.dart` holding `standInSample`; and `hsdd/contract/fixture/analysis_options.yaml` with the text of that file in this workspace (found with `findWorkspaceRoot(Directory.current)`). Then it runs `Process.run(Platform.resolvedExecutable, <String>['pub', 'get', '--offline'], workingDirectory: root.path)` and expects exit 0, the process output as the reason.

In `test/cli_test.dart`, import `package:nidana_contract_check/src/shell.dart` and `support/workspace.dart`, replace the test `a set this version does not implement is an environment error (2)` by the first test of the group `environment errors exit 2 and name the reason` below, and add:

```dart
  group('the surface and reject sets over a seeded workspace, one dart analyze', () {
    late ProcessResult r;
    setUpAll(() async {
      r = await runTool(<String>['sample', '--set', 'surface,reject'],
          workingDirectory: await seedWorkspace(analysisFiles));
    });
    test('exits 1 and counts every outcome', () {
      expect(r.exitCode, 1, reason: all(r));
      expect(lines(r).last, '20 fixtures: 15 passed, 4 failed, 1 pending');
      expect(r.stderr as String, isEmpty);
    });
    test('a clean surface library and reject libraries whose markers match pass', () {
      expect(lines(r), containsAll(<String>[
        'PASS surface ${s}surface/use.dart',
        'PASS reject ${s}reject/sample_is_closed.dart',
        'PASS reject ${s}reject/assigns_final.dart',
      ]));
    });
    test('a warning fails a surface library', () {
      expect(lines(r), contains("FAIL surface ${s}surface/dirty.dart: diagnostic (line 1: WARNING unused_import: Unused import: 'dart:async'.)"));
    });
    test('a marker on the wrong line fails a reject library', () {
      expect(lines(r), contains("FAIL reject ${s}reject/wrong_line.dart: missing-diagnostic (line 5: invalid_use_of_type_outside_library, named by the marker on line 4, not reported); unexpected-diagnostic (line 6: ERROR invalid_use_of_type_outside_library: The class 'Sample' can't be extended outside of its library because it's a final class.)"));
    });
    test('a wrong code fails a reject library', () {
      expect(lines(r), contains("FAIL reject ${s}reject/wrong_code.dart: missing-diagnostic (line 5: undefined_class, named by the marker on line 4, not reported); unexpected-diagnostic (line 5: ERROR invalid_use_of_type_outside_library: The class 'Sample' can't be extended outside of its library because it's a final class.)"));
    });
    test('an extra warning fails a reject library', () {
      expect(lines(r), contains("FAIL reject ${s}reject/extra_warning.dart: unexpected-diagnostic (line 8: WARNING unused_local_variable: The value of the local variable 'unused' isn't used.)"));
    });
    test('a library that imports an absent package is PENDING', () {
      expect(lines(r), contains('PENDING surface ${s}surface/pending.dart: package producer is absent from .dart_tool/package_config.json'));
    });
  });
  test('a contract whose producer is absent prints PENDING per fixture and exits 1, starting no analysis', () async {
    final ProcessResult r = await runTool(<String>['sample', '--set', 'surface,reject'],
        workingDirectory: await seedWorkspace(sampleFiles, standIn: false));
    expect(r.exitCode, 1, reason: all(r));
    expect(lines(r), <String>[
      ...cleanLines.take(6),
      'PENDING surface ${s}surface/use.dart: package sample is absent from .dart_tool/package_config.json',
      'PENDING reject ${s}reject/sample_is_closed.dart: package sample is absent from .dart_tool/package_config.json',
      '8 fixtures: 6 passed, 0 failed, 2 pending',
    ]);
    expect(r.stderr as String, isEmpty);
  });
  test('through a symbolic link to the workspace root, diagnostics still reach their fixtures', () async {
    final Directory root = await seedWorkspace(analysisFiles);
    final Link link = Link('${seed(const <String, String>{}).path}/linked')..createSync(root.path);
    final StringBuffer out = StringBuffer();
    expect(await runCli(<String>['sample', '--set', 'surface'],
        workingDirectory: Directory(link.path), out: out, err: StringBuffer()), 1);
    expect(out.toString(), contains("FAIL surface ${s}surface/dirty.dart: diagnostic (line 1: WARNING unused_import: Unused import: 'dart:async'.)"));
  });
  group('environment errors exit 2 and name the reason', () {
    test('no package configuration, and a set this version does not implement', () async {
      final ProcessResult r = await runTool(<String>['sample'], workingDirectory: seed(sampleFiles));
      expect(r.exitCode, 2, reason: all(r));
      expect(lines(r), contains('PASS structure hsdd/contract/sample.md'));
      expect(r.stderr as String, allOf(
        contains('ERROR surface sample: no package configuration at .dart_tool/package_config.json; run fvm dart pub get'),
        contains('ERROR reject sample: no package configuration at .dart_tool/package_config.json; run fvm dart pub get'),
        contains('ERROR behavior sample: this version of nidana_contract_check does not implement the behavior set'),
      ));
    });
    test('a dart that cannot start, and a dart analyze that prints no report', () async {
      final Directory root = await seedWorkspace(analysisFiles);
      final String missing = '${root.path}/no-such-dart';
      final StringBuffer err = StringBuffer();
      expect(await runCli(<String>['sample', '--set', 'surface'],
          workingDirectory: root, out: StringBuffer(), err: err, dart: missing), 2);
      expect(err.toString(), contains('ERROR surface sample: could not run $missing: '));
      final StringBuffer echoed = StringBuffer();
      expect(await runCli(<String>['sample', '--set', 'surface'],
          workingDirectory: root, out: StringBuffer(), err: echoed, dart: '/bin/echo'), 2);
      expect(echoed.toString(), contains('ERROR surface sample: dart analyze exited 0 without a JSON report'));
    });
    test('--all with no slug directory', () async {
      final ProcessResult r = await runTool(<String>['--all'],
          workingDirectory: seed(const <String, String>{'hsdd/contract/readme.md': 'x\n'}));
      expect(r.exitCode, 2, reason: all(r));
      expect(r.stderr as String, contains('error: no slug directory under hsdd/contract/fixture/'));
    });
    test('a symbolic link where a slug directory belongs', () async {
      final Directory root = seed(sampleFiles);
      Link('${root.path}/hsdd/contract/fixture/linked').createSync('${root.path}/hsdd/contract/fixture/sample');
      final ProcessResult r = await runTool(<String>['--all', '--set', 'structure'], workingDirectory: root);
      expect(r.exitCode, 2, reason: all(r));
      expect(r.stderr as String, contains("error: a slug's fixture directory is a symbolic link: "));
    });
  });
```

The seeded run counts 12 `structure` outcomes (the contract text, the fixture directory and ten libraries), 3 `surface` and 5 `reject`: 15 passed, 4 failed, 1 pending. `/bin/echo` prints its arguments, which hold no JSON document. The symbolic-link test calls `runCli` in process because a process started with a linked working directory reads it back resolved (X2), so only an in-process call hands the shell an unresolved root and makes it attribute the analyzer's resolved paths.

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/cli_test.dart`
Expected: FAIL: `cli_test.dart` does not compile, because `runCli` takes no `dart`. Keep that output; once the parameter exists (Step 3), the surface and reject cases would also fail on `ERROR ... does not implement the surface set`, and the cases of `--all` with no slug and of a linked slug directory on exit 0.

- [ ] **Step 3: Implement the shell**

`bin/nidana_contract_check.dart` does not change. `runCli` finds the root as before (none: `error: no ancestor of {path} holds hsdd/contract/`, exit 2) and keeps catching `FileSystemException` as `error: {message}: {path}`, exit 2. Then, in order:

1. `discoverSlugs`: a `Link` directly under `hsdd/contract/fixture/` throws `FileSystemException("a slug's fixture directory is a symbolic link", {its path})`. No slug: `error: no slug directory under hsdd/contract/fixture/` to `err`, exit 2.
2. `parseRequest` as before (a usage error: `error: {message}` and `usage` to `err`, exit 64); read the snapshot of every slug of the request, in request order; plan each with `plannedSets`.
3. When some plan holds `surface` or `reject`, read `{root}/.dart_tool/package_config.json`: absent gives the reason `no package configuration at .dart_tool/package_config.json; run fvm dart pub get`; `packageNamesOf` null gives `.dart_tool/package_config.json is not a package configuration`.
4. With the package names, the targets are `analysisTargets` of every planned `surface` and `reject` run of every slug, once each, ascending. Start no process when there is none: `dart analyze` without a path analyzes the working directory.
5. Otherwise run `Process.run(dart ?? Platform.resolvedExecutable, <String>['analyze', '--fatal-infos', '--format=json', ...absolute paths of the targets], workingDirectory: root.path)`. A `ProcessException` gives `could not run {executable}: {message}`; `parseAnalysis` null gives `analysisFailure(exitCode, stderr)`. Map each target for `groupDiagnostics`: both `p.normalize` of its absolute path and `File(...).resolveSymbolicLinksSync()` of it to its path from the root. Any stray gives `dart analyze reported {first stray}, which the replay did not ask it to analyze`.
6. One `SetRun` per planned set, by an exhaustive `switch` over `CheckSet`: `structure` `checkStructure`; `surface` and `reject` `SetUnavailable(set, slug, reason)` when steps 3 to 5 gave a reason, else `SetChecked` of `checkSurface` or `checkReject` with the package names and `byFixture`; `schema` `checkSchema`; `behavior`, `file` and `cli` `SetUnavailable(set, slug, notImplemented(set))` until nidana.model.6 and nidana.model.7.
7. Print every run in order (outcome lines to `out`, `unavailableLine` to `err`), then `summaryLine` to `out`; return `exitCodeOf`.

`--fatal-infos` changes only the exit code of `dart analyze` (A2), which the tool does not read; it is passed so the command is the one ADR-001 item 4 names. Every run is computed before the first line is printed, because the analysis serves every slug.

- [ ] **Step 4: Run the tests, the analyzer and the formatter**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Replay the committed tree**

Run: `fvm dart run nidana_contract_check --all --set surface,reject; echo "exit: $?"`
Expected: `exit: 1`; 102 `PASS structure` lines and 65 `PENDING` lines, one per committed `surface/` and `reject/` library, each naming one or more of `flutter`, `nidana_dart_contracts`, `nidana_dart_navigation`, `nidana_dart_runtime` and `nidana_dart_runtime_flutter`, the packages no member provides yet; nothing on stderr, because no library is analyzed; then `167 fixtures: 102 passed, 0 failed, 65 pending`.
Run: `fvm dart run nidana_contract_check topic-model --set surface,reject; echo "exit: $?"`
Expected: `exit: 1`; 17 `PASS structure` lines, 3 `PENDING surface` and 10 `PENDING reject` lines naming `nidana_dart_contracts`, then `30 fixtures: 17 passed, 0 failed, 13 pending`.
Run: `fvm dart run nidana_contract_check --all --set structure,schema; echo "exit: $?"`
Expected: `exit: 0` and `206 fixtures: 206 passed, 0 failed, 0 pending`.

- [ ] **Step 6: Run the gate (Global Constraint 4)**

Run: `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check && fvm dart run nidana_contract_check --all --set structure,schema`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/test/support/workspace.dart packages/nidana_contract_check/test/cli_test.dart
git commit -m "feat(contract_check): one analysis per replay in an async shell" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Structure-set polish

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. The three files are pure. nidana.model.1's final review routed four reading defects of the `structure` set here: a `G{a} to G{b}` range expands eagerly, so a typo such as `G1 to G100000000` hangs the replay; a covers clause followed by trailing whitespace is not read, and a `- schema:` or `- file:` bullet that holds `covers ` without ending in `covers {ids}.` is silently no clause; the malformed-Case-cell message prints the Covers cell instead of the Case cell; and a long list of ids prints every id. ADR-001 item 3's grammar is unchanged: a range stays `G{a} to G{b}` with `a < b`. Every committed contract reads as before under these rules (checked while planning: no `## Validation` line ends in whitespace, and both committed `- schema:` or `- file:` bullets that hold `covers ` end with the clause).

**Files:**
- Modify: `packages/nidana_contract_check/lib/src/ids.dart`
- Modify: `packages/nidana_contract_check/lib/src/contract.dart`
- Modify: `packages/nidana_contract_check/lib/src/structure.dart`
- Modify: `packages/nidana_contract_check/test/ids_test.dart`, `test/contract_test.dart`, `test/structure_test.dart`

**Interfaces:**
- Consumes (nidana.model.1): `parseIdList`, `formatIds`; `readContract`, `ContractText`, `CoversClause`, `InvocationRow`; `checkStructure`, `StructureRule`; the `check`, `at`, `toolContractWith` helpers and the `sampleReject`, `toolFiles` samples of `structure_test.dart`.
- Produces:

```dart
// lib/src/ids.dart: unchanged signatures
Set<int>? parseIdList(String text); // a range spanning 1000 or more ids is no list
String formatIds(Iterable<int> ids); // a run of three or more ids prints as G{a} to G{b}

// lib/src/contract.dart
final class InvocationRow { /* as before, and: */ final String caseCell; } // the Case cell, trimmed, as written
final class ContractText {
  /* as before, and: */
  /// The `- schema:` and `- file:` bullets that hold `covers ` but do not end with `covers {text}.`
  final List<String> unclosedCovers;
}
```

- [ ] **Step 1: Write the failing test**

Add to `test/ids_test.dart`:

```dart
  test('a range spans fewer than 1000 ids; a wider one is no list, at once', () {
    expect(parseIdList('G1 to G1000'), hasLength(1000));
    expect(parseIdList('G1 to G1001'), isNull);
    expect(parseIdList('G3, G1 to G100000000'), isNull);
  });
  test('formatIds writes a run of three or more ids as a range', () {
    expect(formatIds(<int>{1, 2}), 'G1, G2');
    expect(formatIds(<int>{10, 1, 2, 3, 5, 7, 8, 9}), 'G1 to G3, G5, G7 to G10');
    expect(parseIdList(formatIds(<int>{10, 1, 2, 3, 5, 7, 8, 9})), <int>{1, 2, 3, 5, 7, 8, 9, 10});
  });
```

Add to `test/contract_test.dart` (its `text` sample holds the bullet `- schema: a second schema bullet that covers the document.` and the rows `run-clean`, `run-usage` and `run-bad`):

```dart
  test('Validation lines are right-trimmed; a covers bullet without its closing clause is kept', () {
    final ContractText c = readContract('sample', text
        .replaceFirst('covers G1 to G2 and G4.', 'covers G1 to G2 and G4. \t')
        .replaceFirst('a second schema bullet that covers the document.', 'a bullet that covers G1, then wraps'));
    expect(c.coversClauses.map((CoversClause x) => x.ids), <Set<int>?>[<int>{1, 2, 4}]);
    expect(c.unclosedCovers, <String>['- schema: a bullet that covers G1, then wraps']);
    expect(readContract('sample', text).unclosedCovers, isEmpty);
  });
  test('a row keeps its Case cell as written', () {
    expect(readContract('sample', text).invocationRows.map((InvocationRow x) => x.caseCell),
        <String>['`run-clean`', '`run-usage`', 'run-bad']);
  });
```

In `test/structure_test.dart`, the expectation `validation-form (malformed Case cell: G2: an unknown option)` becomes `validation-form (malformed Case cell: generate-usage)` and `validation-form (malformed Case cell: G1: a row without its backticks)` becomes `validation-form (malformed Case cell: generate-help)`; then add:

```dart
  group('structure-set polish', () {
    test('a covers clause followed by whitespace still covers', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/tool.md': toolContractWith('The file set covers G1.', 'The file set covers G1.  \t'),
      }, slug: 'tool', base: toolFiles);
      expect(o, everyElement(isA<Passed>()));
    });
    test('a covers bullet without its closing clause is a validation-form failure and covers nothing', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/tool.md': toolContractWith('The file set covers G1.', 'The file set covers G1, see below'),
      }, slug: 'tool', base: toolFiles);
      expect(at(o, 'hsdd/contract/tool.md'), <String>[
        'validation-form (bullet holds covers but does not end with covers {ids}.: - file: `hsdd/contract/fixture/tool/input/` holds `in.txt`; the replay runs `fvm dart run tool:generate {input}/in.txt {output}` and compares the tree with `expected/`. The file set covers G1, see below)',
      ]);
      expect(at(o, t), <String>['coverage (G1 uncovered)']);
    });
    test('a covers header with a range of 1000 ids or more is malformed', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}reject/sample_is_closed.dart': sampleReject.replaceFirst('// covers: G1\n', '// covers: G1 to G100000000\n'),
      });
      expect(at(o, '${s}reject/sample_is_closed.dart'), <String>['covers-header (malformed // covers: G1 to G100000000)']);
      expect(at(o, s), <String>['coverage (G1 uncovered)']);
    });
    test('three or more uncovered ids in a row print as a range', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': sampleContract.replaceFirst('- **G4**', '- **G5** a.\n- **G6** b.\n- **G7** c.\n- **G4**'),
      });
      expect(at(o, s), <String>['coverage (G5 to G7 uncovered)']);
    });
  });
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/ids_test.dart packages/nidana_contract_check/test/contract_test.dart packages/nidana_contract_check/test/structure_test.dart`
Expected: FAIL: `contract_test.dart` and `structure_test.dart` do not compile (`unclosedCovers`, `caseCell`), and in `ids_test.dart` the range test fails at `G1 to G1001`, before it reaches the wide range that the eager expansion would hang on, and the format test fails.

- [ ] **Step 3: Implement the polish**

- `ids.dart`: a range `G{a} to G{b}` is a part of a list only when `a < b` and `b - a < 1000`; it is rejected before anything is expanded. `formatIds` sorts the ids and writes each maximal run of consecutive ids as `G{a} to G{b}` when it holds three or more ids, otherwise as single ids, all joined by `, `, so `parseIdList` reads every output back.
- `contract.dart`: after replacing `\r\n` with `\n`, right-trim every line before any section is read. `InvocationRow.caseCell` is the Case cell as `_cells` gives it (trimmed). `unclosedCovers` holds each `## Validation` line beginning `- schema: ` or `- file: ` that matches `\bcovers ` but gives no `CoversClause`.
- `structure.dart`: the malformed-Case-cell detail is `malformed Case cell: {caseCell}`; each `unclosedCovers` line is a `validation-form` problem at the contract text, `bullet holds covers but does not end with covers {ids}.: {line}`, listed right after the malformed covers clauses; it cites and covers nothing.

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the structure replay**

Run: `fvm dart format packages/nidana_contract_check`
Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check --all --set structure,schema; echo "exit: $?"`
Expected: `exit: 0` and `206 fixtures: 206 passed, 0 failed, 0 pending`, as before this task. A `FAIL` on a committed contract is a contract gap: stop and report BLOCKED.

- [ ] **Step 5: Run the gate (Global Constraint 4)**

Run: `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check && fvm dart run nidana_contract_check --all --set structure,schema`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add packages/nidana_contract_check/lib/src/ids.dart packages/nidana_contract_check/lib/src/contract.dart packages/nidana_contract_check/lib/src/structure.dart packages/nidana_contract_check/test/ids_test.dart packages/nidana_contract_check/test/contract_test.dart packages/nidana_contract_check/test/structure_test.dart
git commit -m "fix(contract_check): bound id ranges, read covers clauses and Case cells as written" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: Gate and verification doc

You write the phase's verification doc. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.2.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.2.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 6; `packages/nidana_contract_check/test/cli_test.dart` (the seeded reject, surface, PENDING and environment cases); the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check && fvm dart run nidana_contract_check --all --set structure,schema) > "${TMPDIR:-/tmp}/nidana.model.2-gate.txt" 2>&1; echo "exit: $?"`, then read the file.
Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `All tests passed!` with the test count, and `206 fixtures: 206 passed, 0 failed, 0 pending`. Take the date with `date -u +%Y-%m-%d`. A failure stops here: it is fixed in the task that owns the code, never by editing `hsdd/`.

- [ ] **Step 2: Run the phase's Verification on the committed tree**

Run each and keep its output: `fvm dart run nidana_contract_check topology-ir topic-codegen --set schema; echo "exit: $?"` (exit 0: for topology-ir 9 `PASS structure` and 46 `PASS schema` lines, for topic-codegen 2 and 58, then `115 fixtures: 115 passed, 0 failed, 0 pending`); `fvm dart run nidana_contract_check topic-model --set surface,reject; echo "exit: $?"` (exit 1, `30 fixtures: 17 passed, 0 failed, 13 pending`); `fvm dart run nidana_contract_check --all --set surface,reject; echo "exit: $?"` (exit 1, `167 fixtures: 102 passed, 0 failed, 65 pending`, empty stderr); `fvm dart test packages/nidana_contract_check/test/cli_test.dart` (every test passes).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.2.verification.md` at full-review depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder with content, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.2 - Replay tool: surface, reject and schema sets` (a spaced hyphen; no em-dash anywhere in the file).

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate of Step 1; the commands of Step 2. The phase produces no contract; its schema replay is `--set schema` over topology-ir and topic-codegen.
- **Expected output:** the gate's exit 0 and its lines as Step 1 lists them; topology-ir@v1's and topic-codegen@v1's schema sets pass as committed (46 and 58 fixtures); from `cli_test.dart`, the exact `FAIL reject` lines of the marker on the wrong line, the wrong code and the extra warning, and the `FAIL surface` line of the warning; the producer-absent replay's two `PENDING` lines, `8 fixtures: 6 passed, 0 failed, 2 pending` and exit 1, and on the committed tree the 13 and 65 `PENDING` lines with exit 1; exit 2 with its reason for no package configuration, a `dart` that cannot start, a `dart analyze` without a report, `--all` with no slug and a linked slug directory; exit 64 for a usage error.
- **Observed:** dated; the gate's exit code and lines as they appeared; the test count by file; the Step 2 outputs; what the analyzer-backed tests took, from the test run's timestamps.
- **Outstanding:** what could not be verified here, or `None.` The surface and reject sets have run only over seeded fixtures: every committed `surface/` and `reject/` library is PENDING until nidana.model.3 to nidana.model.5 land their producers (ADR-001 Consequences), and that first replay is their first verification. Say so, and say that nothing in this phase can verify it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason), or `- none` when the gate found nothing about the tree; never leave the section empty.
- **Metrics:** gate failures before green; fix rounds after task review; the product diff in lines (`git diff --stat` of `packages/` from the phase's base) by part (library, tests); the phase estimated about 420 lines in about 8 files, so record the actual beside it; the task count, 7 of the allowed 7.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.2.verification.md
git commit -m "docs(verify): nidana.model.2 verification" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
