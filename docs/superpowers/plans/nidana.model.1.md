# nidana.model.1 Workspace Root and Replay Tool Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the pub workspace root and `packages/nidana_contract_check` with its pure core (request, contract reader, Dart fixture reader, `structure` set, run plan, report) and its shell, so that `fvm dart run nidana_contract_check --all --set structure` accepts the nine committed contracts and names the fixture and the rule of every seeded defect.

**Architecture:** Pure core, imperative shell (nidana.model D2 item 5). The shell finds the workspace root, discovers slugs under `hsdd/contract/fixture/`, reads each slug into an immutable `SlugSnapshot`, and prints one line per fixture; everything between (parsing the command, reading contract texts and Dart fixtures, the `structure` rules, which sets to run, the report and the exit code) is total functions over values. Results are sealed types (`FixtureOutcome`, `SetRun`, `ParseResult`), so the later tool phases add a variant (`Pending`, a real set runner) without reshaping the report.

**Tech Stack:** Dart 3.13.5 (Flutter 3.47.7 pin in `.fvmrc`) through `fvm dart`; pub workspace; `package:args`, `package:path`; `package:test` for tests.

**Spec:** `hsdd-context/superpowers/nidana.model.1.md` (the derivative; the generic phase context sits between its markers). Governance it links: `hsdd/spec/nidana.model.md` (phase nidana.model.1, D1, D2, D6), `hsdd/adr/001-executable-contract-validation.md` (items 2, 3, 4, 9), `hsdd/adr/002-package-workspace-layout.md` (items 1 to 5, 9). Evidence: `docs/auto-run/experiments/structure-set-plan/` (`run.sh`, `structure_proto.dart`, `output.txt`).

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 8 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.1.verification.md from
   hsdd/templates/verification.md at full-review depth, fills every section
   the template asks for at that depth, writes "- none" or dispositioned
   entries under Learnings, and leaves Sign-off for a human reviewer.
6. Nothing under hsdd/ changes except that verification doc. Contracts, ADRs,
   specs and conventions change only through hsdd-contract, hsdd-adr and
   hsdd-reconcile.
7. Build against the Interface and Guarantees in the Contracts section below
   (if any), never against another node's internals.
8. Review tier full-review: design rationale for every non-obvious choice; full verification doc.

Project-wide requirements from the spec, which every task's requirements include:

- Toolchain: `fvm dart` only, never a bare `dart`; every command runs from the repository root; no global tooling (ADR-002 item 5; the run rules).
- Root files: the root `pubspec.yaml` and `analysis_options.yaml` exactly as Task 1 writes them (ADR-002 items 1 and 2: `name: nidana_workspace`, `publish_to: none`, `sdk: ^3.13.0`, `lints: ^6.1.0` as the only dependency, no `plugins:` section); the committed root `pubspec.lock` is the only lockfile.
- Member: `packages/nidana_contract_check` has `publish_to: none`, no `version`, `resolution: workspace`, and exactly ADR-002 item 3's row at item 4's constraints: `args: ^2.7.0`, `json_schema: ^5.2.2`, `matcher: ^0.12.20`, `package_config: ^2.2.0`, `path: ^1.9.1`, dev `test: ^1.31.1`. No other package. The lockfile holds `test` 1.33.0; no test uses a `test` API newer than 1.31.1.
- Pure core, imperative shell: no file under `lib/src/` except `shell.dart` imports `dart:io` or does I/O; values are immutable (`final` fields, collections built once and never mutated after construction); alternatives are sealed classes or enums.
- Tests: the pure core by direct calls over in-memory snapshots; the shell by running the tool's bin script over seeded trees in temporary directories. A seeded fixture is a string in test code, never a `.dart` file in the package (D2 item 5; ADR-002 Consequences).
- Output: one line per fixture, paths from the workspace root with `/` separators; exit codes 0, 1, 2 and 64 (ADR-001 item 9; D2 item 1).
- A committed contract text or fixture that the `structure` set rejects is a contract gap (ADR-001 item 8): never edit `hsdd/contract/`; stop at the task boundary and report it.
- Prose and commits follow the run rules: no em-dash character in any comment, dartdoc or commit message; stage explicit paths; conventional subjects; the body ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

The input classes the spec implies but its own cases do not exercise, most likely to bite first; each has its test in the owning task.

1. **CRLF line endings** in a contract text or a Dart fixture (an editor or checkout that writes `\r\n`): the readers must give the same result as for `\n`. Tests: Task 3 (`readContract` on CRLF), Task 4 (headers, markers and case names on CRLF).
2. **Strings that look like structure** inside a conformance library: `//` inside a string, brackets and escaped quotes inside a case name, `${...}` holding braces, a topic constructor's `name:` inside a case body. Case names must be read exactly, and nothing inside a string or a nested group is taken for a case. Test: Task 4 (`conformance` source).
3. **Option spellings** a person types: `--set=structure`, a repeated `--set`, `--guarantee "G1, G2"`, `--set ''`. The `=` and repeated forms parse; a value with a space or an empty value is a usage error (64) that quotes the value. Test: Task 2.
4. **Running from a subdirectory** of the workspace (a member directory, a fixture directory): the root is found by ancestor search and the report's paths stay relative to the root. Test: Task 7.
5. **Hidden OS files** such as `.DS_Store` in a fixture tree (macOS Finder writes them; `.gitignore` ignores them, so the committed tree passes while a local run would fail): entries whose name begins with `.` are not part of a snapshot. Test: Task 7.

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_contract_check`.

| File | Task | Responsibility |
|------|------|----------------|
| `pubspec.yaml`, `analysis_options.yaml`, `pubspec.lock` | 1 | The workspace root of ADR-002 items 1 and 2 |
| `{pkg}/pubspec.yaml` | 1 | The member, ADR-002 item 3's row |
| `{pkg}/lib/src/ids.dart` | 1 | `{ids}` lists and `G{n}` (ADR-001 item 3) |
| `{pkg}/lib/src/request.dart` | 2 | The command line as a `Request` (ADR-001 item 9) |
| `{pkg}/lib/src/contract.dart` | 3 | The contract reader: frontmatter, guarantee ids, `## Validation` forms |
| `{pkg}/lib/src/dart_scanner.dart` | 4 | A token scanner for the Dart the fixture reader needs |
| `{pkg}/lib/src/dart_library.dart` | 4 | The fixture reader: directives, `// covers:` headers, markers, case lists |
| `{pkg}/lib/src/snapshot.dart` | 5 | `SlugSnapshot`, the core's whole input for one slug |
| `{pkg}/lib/src/outcome.dart` | 5 | `Rule`, `Problem`, sealed `FixtureOutcome`, shared by every set |
| `{pkg}/lib/src/structure.dart` | 5 | The `structure` set |
| `{pkg}/lib/src/run.dart` | 6 | Which sets a slug has and which a request runs |
| `{pkg}/lib/src/report.dart` | 6 | Sealed `SetRun`, the lines, the summary, the exit code |
| `{pkg}/lib/src/shell.dart` | 7 | Root and slug discovery, reading snapshots, `runCli` |
| `{pkg}/bin/nidana_contract_check.dart` | 7 | The executable `fvm dart run nidana_contract_check` runs |
| `{pkg}/test/*_test.dart`, `{pkg}/test/support/*.dart` | 1 to 7 | Tests and their seeded samples |

There is no public library in this phase: tests import `package:nidana_contract_check/src/...`, and nidana.model.2 adds `lib/fixture.dart`.

---

### Task 1: Workspace root and guarantee id lists

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9), in the pub workspace at the repository root. Run every command from the repository root with `fvm dart`. `lib/src/ids.dart` is pure: it imports nothing.

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `pubspec.lock` (written by `fvm dart pub get`)
- Create: `packages/nidana_contract_check/pubspec.yaml`
- Create: `packages/nidana_contract_check/lib/src/ids.dart`
- Test: `packages/nidana_contract_check/test/ids_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (`lib/src/ids.dart`):
  - `Set<int>? parseIdList(String text)`: the numbers of an `{ids}` list, or null when `text` is not one.
  - `int? parseGuaranteeId(String text)`: the number of `text` when it is exactly one `G{n}`, else null.
  - `String formatIds(Iterable<int> ids)`: `G{n}` in ascending order joined by `, `.

- [ ] **Step 1: Write the failing test**

```dart
// packages/nidana_contract_check/test/ids_test.dart
import 'package:nidana_contract_check/src/ids.dart';
import 'package:test/test.dart';

void main() {
  group('parseIdList', () {
    test('reads ids and ranges separated by ", " and " and "', () {
      expect(parseIdList('G1'), <int>{1});
      expect(parseIdList('G19, G20'), <int>{19, 20});
      expect(parseIdList('G1, G3 to G7'), <int>{1, 3, 4, 5, 6, 7});
      expect(parseIdList('G3 to G8, G12, G13 and G15 to G18'),
          <int>{3, 4, 5, 6, 7, 8, 12, 13, 15, 16, 17, 18});
    });
    test('is null for anything else', () {
      for (final String text in <String>[
        '', 'the closed families', 'G0', 'G01', 'g1', 'G1,G2', 'G1 , G2',
        'G1.', 'G5 to G5', 'G7 to G3', 'G1, ', 'G1 and', 'topic-model/G1',
      ]) {
        expect(parseIdList(text), isNull, reason: text);
      }
    });
  });
  test('parseGuaranteeId reads exactly one id', () {
    expect(parseGuaranteeId('G12'), 12);
    for (final String text in <String>['G0', 'G', 'G1a', ' G1', 'topic-model/G1', 'G1 to G2']) {
      expect(parseGuaranteeId(text), isNull, reason: text);
    }
  });
  test('formatIds lists ids in ascending order', () {
    expect(formatIds(<int>{5, 1, 3}), 'G1, G3, G5');
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/ids_test.dart`
Expected: FAIL. No `pubspec.yaml` exists yet, so the test cannot load. Keep the output for the task report.

- [ ] **Step 3: Write the root files and the member pubspec, byte for byte**

`pubspec.yaml`:

```yaml
name: nidana_workspace
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - packages/nidana_contract_check
dev_dependencies:
  lints: ^6.1.0
```

`analysis_options.yaml` (ADR-002 item 2, no `plugins:` section):

```yaml
include: package:lints/recommended.yaml
analyzer:
  exclude:
    - ref/**
    - docs/**
    - hsdd/**
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

`packages/nidana_contract_check/pubspec.yaml` (no `version`; the member has no options file of its own):

```yaml
name: nidana_contract_check
description: Replays the contract fixtures under hsdd/contract/ (ADR-001 item 9).
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
dependencies:
  args: ^2.7.0
  json_schema: ^5.2.2
  matcher: ^0.12.20
  package_config: ^2.2.0
  path: ^1.9.1
dev_dependencies:
  test: ^1.31.1
```

- [ ] **Step 4: Resolve the workspace**

Run: `fvm dart pub get`
Expected: exit 0 (it reaches pub.dev). It writes `pubspec.lock`, `.dart_tool/package_config.json`, `.dart_tool/package_graph.json`, `.dart_tool/pub/workspace_ref.json` and `packages/nidana_contract_check/.dart_tool/pub/workspace_ref.json`; `.gitignore` ignores every `.dart_tool/`. The lockfile holds args 2.7.0, json_schema 5.2.2, matcher 0.12.20, package_config 2.2.0, path 1.9.1, test 1.33.0 and lints 6.1.0 (`docs/auto-run/experiments/structure-set-plan/output.txt`, W1 and W2). No other lockfile and no `pubspec_overrides.yaml` appears.

Run the test again: `fvm dart test packages/nidana_contract_check/test/ids_test.dart`
Expected: FAIL, now on the missing `package:nidana_contract_check/src/ids.dart`.

- [ ] **Step 5: Implement `lib/src/ids.dart`**

ADR-001 item 3's grammar, exactly: an id is `G` and a positive decimal number without a leading zero (`^G[1-9][0-9]*$`); a range is `G{a} to G{b}` with `a < b` and covers `a` to `b` inclusive; a list splits on the regular expression `, | and ` and every part must be an id or a range; the empty string is no list. No trimming: callers pass exact text.

- [ ] **Step 6: Run the tests, the analyzer and the lockfile check**

Run: `fvm dart test packages/nidana_contract_check/test/ids_test.dart`
Expected: PASS (4 tests).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!` (the root options exclude `ref/`, `docs/` and `hsdd/`; output.txt W4).
Run: `fvm dart pub get --enforce-lockfile`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml analysis_options.yaml pubspec.lock packages/nidana_contract_check/pubspec.yaml packages/nidana_contract_check/lib/src/ids.dart packages/nidana_contract_check/test/ids_test.dart
git commit -m "feat(contract_check): workspace root and guarantee id lists" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: The request

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. `lib/src/request.dart` is pure: it imports `package:args/args.dart` and `ids.dart`, never `dart:io`. Tests use no `package:test` API newer than 1.31.1.

**Files:**
- Create: `packages/nidana_contract_check/lib/src/request.dart`
- Test: `packages/nidana_contract_check/test/request_test.dart`

**Interfaces:**
- Consumes (Task 1, `lib/src/ids.dart`): `int? parseGuaranteeId(String text)`.
- Produces (`lib/src/request.dart`):

```dart
/// The replay tool's sets (ADR-001 item 9); `--set` names each by its enum name.
enum CheckSet { structure, surface, reject, behavior, schema, file, cli }

/// One guarantee, `--guarantee`'s bare ids resolved to the replayed slug.
typedef GuaranteeRef = ({String slug, int number});

final class Request {
  const Request({required this.slugs, required this.sets, required this.restriction});
  /// Command order without repeats; every slug in ascending order under --all.
  final List<String> slugs;
  /// The sets --set named; null when it named none (every set a slug has).
  final Set<CheckSet>? sets;
  /// The guarantees --guarantee named; null when unrestricted.
  final Set<GuaranteeRef>? restriction;
}

sealed class ParseResult { const ParseResult(); }
final class ParsedRequest extends ParseResult { const ParsedRequest(this.request); final Request request; }
final class UsageError extends ParseResult { const UsageError(this.message); final String message; }

/// Parses the command line against the slugs that have a fixture directory.
ParseResult parseRequest(List<String> arguments, {required Set<String> slugs});

/// Printed after a usage error.
const String usage;
```

- [ ] **Step 1: Write the failing test**

```dart
// packages/nidana_contract_check/test/request_test.dart
import 'package:nidana_contract_check/src/request.dart';
import 'package:test/test.dart';

const Set<String> slugs = <String>{'topic-model', 'topology-dsl', 'topology-ir', 'bus-api'};

Request parsed(List<String> arguments) {
  final ParseResult r = parseRequest(arguments, slugs: slugs);
  expect(r, isA<ParsedRequest>(), reason: r is UsageError ? r.message : null);
  return (r as ParsedRequest).request;
}

String usageError(List<String> arguments) {
  final ParseResult r = parseRequest(arguments, slugs: slugs);
  expect(r, isA<UsageError>());
  return (r as UsageError).message;
}

void main() {
  test('one slug, every set, unrestricted', () {
    final Request r = parsed(<String>['topic-model']);
    expect(r.slugs, <String>['topic-model']);
    expect(r.sets, isNull);
    expect(r.restriction, isNull);
  });
  test('--all replays every slug in ascending order', () {
    expect(parsed(<String>['--all', '--set', 'structure']).slugs,
        <String>['bus-api', 'topic-model', 'topology-dsl', 'topology-ir']);
  });
  test('named slugs keep command order without repeats', () {
    expect(parsed(<String>['topology-ir', 'topic-model', 'topology-ir']).slugs,
        <String>['topology-ir', 'topic-model']);
  });
  test('--set takes comma lists, repeats and the = form', () {
    expect(parsed(<String>['topic-model', '--set', 'structure,schema', '--set=surface']).sets,
        <CheckSet>{CheckSet.structure, CheckSet.schema, CheckSet.surface});
  });
  test('a bare id belongs to the one slug named', () {
    expect(parsed(<String>['topology-dsl', '--guarantee', 'G10,G11']).restriction,
        <GuaranteeRef>{(slug: 'topology-dsl', number: 10), (slug: 'topology-dsl', number: 11)});
  });
  test('a {slug}/G{n} may name a slug the command does not replay', () {
    expect(parsed(<String>['bus-api', '--guarantee', 'G3,topology-dsl/G18']).restriction,
        <GuaranteeRef>{(slug: 'bus-api', number: 3), (slug: 'topology-dsl', number: 18)});
    expect(parsed(<String>['topic-model', 'topology-dsl', '--guarantee', 'topology-ir/G2']).restriction,
        <GuaranteeRef>{(slug: 'topology-ir', number: 2)});
  });
  group('usage errors', () {
    test('no slug and no --all', () => expect(usageError(<String>[]), contains('name a slug or --all')));
    test('--all with a slug', () => expect(usageError(<String>['--all', 'topic-model']), contains('--all takes no slug')));
    test('an unknown slug', () => expect(usageError(<String>['nosuch']), contains("unknown slug 'nosuch'")));
    test('an unknown or empty set', () {
      expect(usageError(<String>['topic-model', '--set', 'surfaces']), contains("unknown set 'surfaces'"));
      expect(usageError(<String>['topic-model', '--set', '']), contains("unknown set ''"));
    });
    test('a malformed id, a space after a comma included', () {
      for (final String id in <String>['G0', 'g1', 'G1a', ' G2', 'topic-model/', '/G1']) {
        expect(usageError(<String>['topic-model', '--guarantee', id]), contains("malformed guarantee id '$id'"));
      }
      expect(usageError(<String>['topic-model', '--guarantee', 'G1, G2']), contains("malformed guarantee id ' G2'"));
    });
    test('an unknown slug in an id', () {
      expect(usageError(<String>['topic-model', '--guarantee', 'nosuch/G1']), contains("unknown slug 'nosuch'"));
    });
    test('a bare id with more than one slug', () {
      expect(usageError(<String>['topic-model', 'topology-dsl', '--guarantee', 'G1']), contains("bare id 'G1'"));
      expect(usageError(<String>['--all', '--guarantee', 'G1']), contains("bare id 'G1'"));
    });
    test('an unknown option or a missing value', () {
      expect(usageError(<String>['--frobnicate', 'topic-model']), contains('frobnicate'));
      expect(usageError(<String>['topic-model', '--set']), contains('--set'));
    });
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/request_test.dart`
Expected: FAIL, `package:nidana_contract_check/src/request.dart` does not exist.

- [ ] **Step 3: Implement `lib/src/request.dart`**

Parse with `ArgParser()..addFlag('all', negatable: false)..addMultiOption('set')..addMultiOption('guarantee')` (`splitCommas` is on by default, so `--set a,b`, a repeated `--set` and `--set=a` all collect; `--set ''` gives one empty value and `--guarantee "G1, G2"` gives `' G2'`, which the checks below reject: `docs/auto-run/experiments/structure-set-plan/output.txt` W6 and `args-probe/output.txt` there). A `FormatException` from `parse` becomes `UsageError(e.message)`. Then check in this order, each failure a `UsageError` with exactly this message:

1. neither slugs nor `--all`: `name a slug or --all`; both: `--all takes no slug`.
2. a slug not in `slugs`: `unknown slug '{s}': no directory hsdd/contract/fixture/{s}/`.
3. a set name not in `CheckSet.values` by name: `unknown set '{x}'; the sets are structure, surface, reject, behavior, schema, file, cli`.
4. each `--guarantee` value: a bare `G{n}` (`parseGuaranteeId`), or `{slug}/G{n}` split at the first `/` with a non-empty slug and a `G{n}` after it; anything else: `malformed guarantee id '{x}'; write G{n} or {slug}/G{n}`; a qualified slug not in `slugs`: `unknown slug '{s}' in '{x}'`.
5. a bare id when the command replays a number of slugs other than one: `bare id '{x}' names no single slug: the command replays {n} slugs; write {slug}/{x}`.

`usage` is:

```text
usage: fvm dart run nidana_contract_check {slug}... [--set {set},...] [--guarantee {id},...]
       fvm dart run nidana_contract_check --all [--set {set},...] [--guarantee {id},...]
sets: structure, surface, reject, behavior, schema, file, cli
ids: G{n} for the one slug named, or {slug}/G{n}
```

The restriction is parsed and kept; no set of this phase reads it (ADR-001 item 9: it leaves `structure` unrestricted).

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm dart test packages/nidana_contract_check/test/request_test.dart`
Expected: PASS.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/request.dart packages/nidana_contract_check/test/request_test.dart
git commit -m "feat(contract_check): parse the replay request" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: The contract reader

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. `lib/src/contract.dart` is pure: no `dart:io`. The reader is total: it never throws, and keeps malformed forms as values for the `structure` set (Task 5) to judge.

**Files:**
- Create: `packages/nidana_contract_check/lib/src/contract.dart`
- Test: `packages/nidana_contract_check/test/contract_test.dart`

**Interfaces:**
- Consumes (Task 1, `lib/src/ids.dart`): `Set<int>? parseIdList(String text)`.
- Produces (`lib/src/contract.dart`):

```dart
/// The kinds of ADR-001 item 1, with the set directories items 4 to 7 give each.
enum ContractKind {
  api('api', <String>{'surface', 'reject', 'behavior', 'valid', 'invalid'}),
  sharedModel('shared-model', <String>{'surface', 'reject', 'behavior'}),
  schema('schema', <String>{'valid', 'invalid'}),
  file('file', <String>{'input', 'expected', 'valid', 'invalid', 'invocation'}),
  cli('cli', <String>{'invocation'});
  const ContractKind(this.label, this.setDirectories);
  final String label;
  final Set<String> setDirectories;
  static ContractKind? byLabel(String? label);
}

/// A `- schema:` or `- file:` bullet that ends with `covers {text}.`
final class CoversClause {
  const CoversClause({required this.bullet, required this.text, required this.ids});
  final String bullet; // 'schema' or 'file'
  final String text;
  final Set<int>? ids; // null when text is not an {ids} list
}

/// A row of the recorded-invocation table.
final class InvocationRow {
  const InvocationRow({required this.caseName, required this.covers, required this.ids});
  final String? caseName; // null when the Case cell is not one backticked name
  final String covers; // the Covers cell
  final Set<int>? ids; // the {ids} the Covers cell begins with; null when malformed
}

/// A `- not executable:` line (ADR-001 item 3).
final class NotExecutableLine {
  const NotExecutableLine({required this.text, required this.id, required this.partial, required this.node});
  final String text; // the whole line
  final int? id; // the id it begins with; null when none
  final bool partial; // `G{n}'s {part}, ...` rather than `G{n}, ...`
  final String? node; // from `; checked by {node}'s gates`; null when absent
}

final class ContractText {
  const ContractText({required this.id, required this.kindLabel, required this.guarantees,
      required this.malformedGuarantees, required this.bindings, required this.listedDirectories,
      required this.coversClauses, required this.invocationRows, required this.notExecutable});
  final String? id; // frontmatter `id`
  final String? kindLabel; // frontmatter `kind`, as written
  final List<int> guarantees; // `- **G{n}** ` entries in order, repeats kept
  final List<String> malformedGuarantees; // other `- ` lines of that section
  final List<String> bindings; // paths of `- binding:` bullets
  final Set<String> listedDirectories; // {dir} of `- {dir}: \`hsdd/contract/fixture/{slug}/{dir}/\`` bullets
  final List<CoversClause> coversClauses;
  final List<InvocationRow> invocationRows;
  final List<NotExecutableLine> notExecutable;
  ContractKind? get kind => ContractKind.byLabel(kindLabel);
}

ContractText readContract(String slug, String text);
```

- [ ] **Step 1: Write the failing test**

```dart
// packages/nidana_contract_check/test/contract_test.dart
import 'package:nidana_contract_check/src/contract.dart';
import 'package:test/test.dart';

const String text = '''
---
id: sample
version: v1
kind: api
---

# sample@v1

## Guarantees / invariants

- **G1** a sample type is closed.
- **G2** a sample value round-trips.
- G3 an entry without its bold id.
- **G4** a property of the package's pubspec.

## Validation

- surface: `hsdd/contract/fixture/sample/surface/` uses every declaration.
- goldens: `hsdd/contract/fixture/sample/goldens/`, renderings the behavior set compares.
- notes: `hsdd/contract/fixture/other/notes/`, another slug's directory.
- binding: `hsdd/contract/fixture/sample/behavior/sample_impl_test.dart` binds the suite, under `dart test`.
- schema: `hsdd/contract/schema/sample.schema.json`, replayed by the `schema` set (ADR-001 item 5).
- file: `hsdd/contract/fixture/sample/input/` holds one file. The file set covers G1 to G2 and G4.
- schema: a second schema bullet that covers the document.
- not executable: G4, a property of the package's pubspec; checked by nidana.model's gates
- not executable: G2's last clause, on a value no case builds; checked by nidana.runtime's gates, which build it
- not executable: G1's last sentence, on an exception no case can raise
- not executable: the rest of it

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `run-clean` | `tool:run` | 0 | G1, G2: a clean tree |
| `run-usage` | `tool:run --frob` | 2 | G4 |
| run-bad | `tool:run` | 1 | two |
''';

void expectSample(ContractText c) {
  expect(c.id, 'sample');
  expect(c.kindLabel, 'api');
  expect(c.kind, ContractKind.api);
  expect(c.guarantees, <int>[1, 2, 4]);
  expect(c.malformedGuarantees, <String>['- G3 an entry without its bold id.']);
  expect(c.bindings, <String>['hsdd/contract/fixture/sample/behavior/sample_impl_test.dart']);
  expect(c.listedDirectories, <String>{'surface', 'goldens'});
  expect(c.coversClauses.map((CoversClause x) => x.bullet), <String>['file', 'schema']);
  expect(c.coversClauses.map((CoversClause x) => x.text), <String>['G1 to G2 and G4', 'the document']);
  expect(c.coversClauses.map((CoversClause x) => x.ids), <Set<int>?>[<int>{1, 2, 4}, null]);
  expect(c.invocationRows.map((InvocationRow x) => x.caseName), <String?>['run-clean', 'run-usage', null]);
  expect(c.invocationRows.map((InvocationRow x) => x.covers), <String>['G1, G2: a clean tree', 'G4', 'two']);
  expect(c.invocationRows.map((InvocationRow x) => x.ids), <Set<int>?>[<int>{1, 2}, <int>{4}, null]);
  expect(c.notExecutable.map((NotExecutableLine x) => x.id), <int?>[4, 2, 1, null]);
  expect(c.notExecutable.map((NotExecutableLine x) => x.partial), <bool>[false, true, true, false]);
  expect(c.notExecutable.map((NotExecutableLine x) => x.node), <String?>['nidana.model', 'nidana.runtime', null, null]);
}

void main() {
  test('reads the frontmatter, the guarantee ids and every Validation form', () {
    expectSample(readContract('sample', text));
  });
  test('reads CRLF text as it reads LF text', () {
    expectSample(readContract('sample', text.replaceAll('\n', '\r\n')));
  });
  test('a text without frontmatter has no id and no kind', () {
    final ContractText c = readContract('sample', '# sample\n\n## Guarantees / invariants\n\n- **G1** one.\n');
    expect(c.id, isNull);
    expect(c.kindLabel, isNull);
    expect(c.kind, isNull);
    expect(c.guarantees, <int>[1]);
  });
  test('ContractKind.byLabel reads the five labels and nothing else', () {
    expect(ContractKind.values.map((ContractKind k) => ContractKind.byLabel(k.label)), ContractKind.values);
    expect(ContractKind.byLabel('widget'), isNull);
    expect(ContractKind.byLabel(null), isNull);
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/contract_test.dart`
Expected: FAIL, `package:nidana_contract_check/src/contract.dart` does not exist.

- [ ] **Step 3: Implement `lib/src/contract.dart`**

Replace every `\r\n` with `\n` first. Then:

- **Frontmatter:** when the first line is `---`, the lines up to the next `---` line; `id` and `kind` are the trimmed values of the lines beginning `id: ` and `kind: `. No frontmatter: both null.
- **Sections:** a section is the lines after a line exactly `## Guarantees / invariants` or `## Validation`, up to the next line beginning `## ` (a `### ` line does not end it). An absent section is empty.
- **Guarantees:** every line of that section beginning `- `: matching `^- \*\*G([1-9][0-9]*)\*\* ` adds the number to `guarantees`; any other goes whole to `malformedGuarantees`.
- **Bindings:** each `## Validation` line matching ``^- binding: `([^`]+)` `` adds the backticked path.
- **Listed directories:** each line matching ``^- ([a-z0-9_-]+): `hsdd/contract/fixture/{slug}/([a-z0-9_-]+)/` `` (the slug escaped) whose two groups are equal adds that name, set directories included (ADR-001 item 9's data-directory bullet).
- **Covers clauses:** each line beginning `- schema: ` or `- file: ` that matches `\bcovers ([^.]*)\.$` gives a `CoversClause` with `ids = parseIdList(text)`; a bullet without that ending gives none (ADR-001 item 3).
- **Invocation table:** the first line matching `^\|\s*Case\s*\|` is the header; split it on `|` and trim to find the `Covers` column; the next line is the separator row; every following line beginning `|` is a row until the first line that does not. Case cell matching `` ^`([^`]+)`$ `` gives `caseName`, else null; `covers` is the trimmed Covers cell; `ids` is `parseIdList` of the cell's text before its first `: `. A table without a Covers column gives rows whose `covers` is `''` and `ids` null.
- **Not-executable lines:** each line beginning `- not executable: `: `id` and `partial` from `^- not executable: G([1-9][0-9]*)('s |, )` (`'s ` means partial); `node` from the first `; checked by (\S+)'s gates`; further text may follow (ADR-001 item 3).

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm dart test packages/nidana_contract_check/test/contract_test.dart`
Expected: PASS.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/contract.dart packages/nidana_contract_check/test/contract_test.dart
git commit -m "feat(contract_check): read contract texts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: The Dart fixture reader

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. Both files are pure: no `dart:io`. The tool has no analyzer dependency (ADR-002 item 3's row), so it reads fixtures with its own small scanner. Behavior case names are the `name` field of the record literals in the exported `List<ConformanceCase<H>>`, never a match of `name:` text, because conformance libraries also pass `name:` to topic constructors (phase scope (3)).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/dart_scanner.dart`
- Create: `packages/nidana_contract_check/lib/src/dart_library.dart`
- Test: `packages/nidana_contract_check/test/dart_library_test.dart`

**Interfaces:**
- Consumes (Task 1, `lib/src/ids.dart`): `Set<int>? parseIdList(String text)`.
- Produces:

```dart
// lib/src/dart_scanner.dart
enum TokenKind { identifier, string, punctuation, other }

final class Token {
  const Token(this.kind, this.text, this.line, {this.value});
  final TokenKind kind;
  final String text; // the source text
  final int line; // 1-based line of its first character
  final String? value; // a string's value, escapes decoded; null when it interpolates, and for other kinds
}

List<Token> scanDart(String source);

// lib/src/dart_library.dart
final class CoversHeader {
  const CoversHeader(this.line, this.text, this.ids);
  final int line;
  final String text; // after `// covers: `, trailing space trimmed
  final Set<int>? ids;
}

final class Marker {
  const Marker({required this.line, required this.code, required this.followedByCode});
  final int line;
  final String? code; // null when the line is not exactly `// expect-diagnostic: {code}`
  final bool followedByCode; // a next line exists, is not blank and is not a `//` comment
}

typedef CaseName = ({int line, String? name}); // name null: not a string literal

final class CaseList {
  const CaseList({required this.name, required this.cases, required this.problems});
  final String name;
  final List<CaseName> cases;
  final List<String> problems;
}

final class DartLibrary {
  const DartLibrary({required this.directives, required this.coversHeaders, required this.markers, required this.caseLists});
  final List<String> directives; // URIs of import and export directives, in order
  final List<CoversHeader> coversHeaders; // `// covers:` lines of the leading comment block
  final List<Marker> markers; // every line that mentions expect-diagnostic
  final List<CaseList> caseLists; // public top-level List<ConformanceCase<...>> declarations
}

DartLibrary readDartLibrary(String source);
```

- [ ] **Step 1: Write the failing test**

```dart
// packages/nidana_contract_check/test/dart_library_test.dart
import 'package:nidana_contract_check/src/dart_library.dart';
import 'package:nidana_contract_check/src/dart_scanner.dart';
import 'package:test/test.dart';

const List<String> rejectLines = <String>[
  '// Reject fixture for sample@v1 G1: the sample type is closed.', // 1
  '// covers: G1, G2', // 2
  "import 'package:sample/sample.dart';", // 3
  '', // 4
  '// expect-diagnostic: invalid_use_of_type_outside_library', // 5
  'final class Local extends Sample {}', // 6
  '', // 7
  'void f(Sample s) {', // 8
  '  // expect-diagnostic: undefined_method', // 9
  '  s.publish(); // expect-diagnostic: trailing', // 10
  '// expect-diagnostic: Bad_Code', // 11
  'int x = 1;', // 12
  '// expect-diagnostic: unused_local', // 13
  '', // 14
  '// covers: G3', // 15
  '}', // 16
  '// expect-diagnostic: at_the_end', // 17
];

const String conformance = r"""
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart' show ConformanceCase;
import 'package:sample/sample.dart' as s;

abstract interface class SampleHarness {
  Future<void> settle();
}

const s.Topic _t = s.Topic(name: 'G8 a top-level topic, not a case');

final List<ConformanceCase<SampleHarness>> sampleConformance =
    <ConformanceCase<SampleHarness>>[
  // name: 'G9 a commented-out case'
  (
    name: 'G1 reads http://example.com/a ) ] } and \'quotes\'',
    body: (SampleHarness h) async {
      const s.Topic t = s.Topic(name: 'G9 a topic inside a body');
      expect('${t.name} } ]', isNotEmpty);
    },
  ),
  (
    body: (SampleHarness h) async {},
    name: 'G2 adjacent ' "strings",
  ),
  (name: 'G3 interpolates $x', body: (SampleHarness h) async {}),
  (name: r'G4 raw \n', body: (SampleHarness h) async {}),
  (name: '''G5 triple''', body: (SampleHarness h) async {}),
  ...otherCases,
  (body: (SampleHarness h) async {}),
];

final List<ConformanceCase<SampleHarness>> _privateCases = <ConformanceCase<SampleHarness>>[
  (name: 'G7 private', body: (SampleHarness h) async {}),
];
""";

void expectConformance(DartLibrary d) {
  expect(d.caseLists.map((CaseList l) => l.name), <String>['sampleConformance']);
  final CaseList l = d.caseLists.single;
  expect(l.cases.map((CaseName c) => c.name), <String?>[
    "G1 reads http://example.com/a ) ] } and 'quotes'",
    'G2 adjacent strings',
    null,
    r'G4 raw \n',
    'G5 triple',
  ]);
  expect(l.cases.first.line, 15);
  expect(l.problems, hasLength(2));
  expect(l.problems[0], allOf(startsWith('line 28: '), endsWith('an element of sampleConformance is not a record literal')));
  expect(l.problems[1], allOf(startsWith('line 29: '), endsWith('a record of sampleConformance has no name field')));
}

void main() {
  test('scanDart skips comments and keeps strings whole', () {
    final List<Token> t = scanDart(r"""a // b 'c'
'x//y' /* /* n */ */ r'\n' "${'}'}" b2""");
    expect(t.map((Token x) => x.kind), <TokenKind>[
      TokenKind.identifier, TokenKind.string, TokenKind.string, TokenKind.string, TokenKind.identifier,
    ]);
    expect(t.map((Token x) => x.value), <String?>[null, 'x//y', r'\n', null, null]);
    expect(t.map((Token x) => x.line), <int>[1, 2, 2, 2, 2]);
  });
  test('directives: import and export URIs in order, prefixes and combinators ignored', () {
    final DartLibrary d = readDartLibrary(r"""
// covers: G1
library;

import 'package:a/a.dart' as a show B;
export 'package:b/src/c.dart';
import "../../x/behavior/y_conformance.dart";

void f() { final String s = 'import'; }
""");
    expect(d.directives, <String>['package:a/a.dart', 'package:b/src/c.dart', '../../x/behavior/y_conformance.dart']);
  });
  test('the covers header is read from the leading comment block only', () {
    final DartLibrary d = readDartLibrary(rejectLines.join('\n'));
    expect(d.coversHeaders.map((CoversHeader h) => (h.line, h.text)), <(int, String)>[(2, 'G1, G2')]);
    expect(d.coversHeaders.single.ids, <int>{1, 2});
  });
  test('markers: code on its own line, and what follows it', () {
    final DartLibrary d = readDartLibrary(rejectLines.join('\n'));
    expect(d.markers.map((Marker m) => (m.line, m.code, m.followedByCode)), <(int, String?, bool)>[
      (5, 'invalid_use_of_type_outside_library', true),
      (9, 'undefined_method', true),
      (10, null, false),
      (11, null, true),
      (13, 'unused_local', false),
      (17, 'at_the_end', false),
    ]);
  });
  test('case names are the name fields of the exported list, nothing else', () {
    expectConformance(readDartLibrary(conformance));
  });
  test('CRLF sources read as LF sources', () {
    expectConformance(readDartLibrary(conformance.replaceAll('\n', '\r\n')));
    final DartLibrary d = readDartLibrary(rejectLines.join('\r\n'));
    expect(d.coversHeaders.single.ids, <int>{1, 2});
    expect(d.markers.map((Marker m) => m.code), <String?>[
      'invalid_use_of_type_outside_library', 'undefined_method', null, null, 'unused_local', 'at_the_end',
    ]);
  });
  test('the typed-literal form is a case list; a list from elsewhere is a problem', () {
    final DartLibrary d = readDartLibrary(r"""
final sampleConformance = <ConformanceCase<H>>[
  (name: 'G1 inferred', body: (H h) async {}),
];
final List<ConformanceCase<H>> fromElsewhere = otherCases;
""");
    expect(d.caseLists.map((CaseList l) => l.name), <String>['sampleConformance', 'fromElsewhere']);
    expect(d.caseLists[0].cases.map((CaseName c) => c.name), <String>['G1 inferred']);
    expect(d.caseLists[1].problems, <String>['fromElsewhere is not initialized by a list literal']);
  });
}
```

In `conformance`, line 15 holds `name: 'G1 ...`, line 28 `...otherCases,` and line 29 `(body: ...),` (line 1 is the first `import`: Dart drops the newline right after an opening `"""`). Count again after editing the source.

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/dart_library_test.dart`
Expected: FAIL, the two libraries do not exist.

- [ ] **Step 3: Implement `scanDart(String source) -> List<Token>` in `lib/src/dart_scanner.dart`**

Track the line as you scan (no recount from the start). Skip spaces, tabs, `\r` and `\n`; `//` to the end of the line; `/* ... */` with nesting. A string starts at `'`, `"`, `'''` or `"""`, raw when an `r` directly precedes the quote; it ends at the same quote sequence (or the end of the source). In a non-raw string, a backslash takes the next character (`n`, `t` and `r` decode to newline, tab and carriage return; any other character stands for itself), and `$name` or `${...}` makes the string interpolated (`value` null); `${` scans nested tokens, strings and comments included, up to its matching `}`, and those nested tokens are not part of the result. An identifier is `[A-Za-z_$][A-Za-z0-9_$]*`; a token starting with a digit runs over `[0-9A-Za-z_.]` and is `other`; every other character is one `punctuation` token, so `>>` is two `>` tokens and `...` three `.` tokens.

- [ ] **Step 4: Implement `readDartLibrary(String source) -> DartLibrary` in `lib/src/dart_library.dart`**

Replace `\r\n` with `\n` first.

- **Directives:** over `scanDart`, an identifier `import` or `export` at bracket depth 0 directly followed by a string token gives that string's value.
- **Covers headers:** the leading block is the lines from the top while each is blank or, after leading spaces, begins with `//`. Each line of it matching `^// covers: (.*)$` gives a `CoversHeader` with the right-trimmed text and `parseIdList` of it.
- **Markers:** every line containing `expect-diagnostic` is a `Marker`; `code` is the group of `^\s*// expect-diagnostic: ([a-z][a-z0-9_]*)\s*$`, else null; `followedByCode` as the interface states.
- **Case lists** (the algorithm the signature leaves open):
  1. Walk the tokens at bracket depth 0, stepping over every `(`, `[` and `{` group whole; depth counts those three brackets only.
  2. A declaration is either `List` `<` `ConformanceCase` ... `>` NAME `=` (the type's angle group ends at its matching `>`, counting `<` and `>` tokens only) or NAME `=` `<` `ConformanceCase`. A NAME beginning with `_` is not public and is skipped.
  3. After `=`: an optional `<...>` angle group, then `[`; anything else gives the problem `{name} is not initialized by a list literal`.
  4. Each element at the list's own depth is an optional `const` and a record literal `(` ... `)`. Any other element gives `line {n}: an element of {name} is not a record literal` (the line of its first token) and is skipped to the next `,` at the list's depth.
  5. In a record, at the record's own depth only, an identifier `name` followed by `:` starts the name field; its expression runs to the next `,` at that depth or to the record's `)`. One or more string tokens, none interpolated, give their values joined; any other expression gives null. The case's line is the line of that `name` token. A record without the field gives `line {n}: a record of {name} has no name field` (the line of its `(`).
  6. A `name:` inside a nested group (a topic constructor in a body, a nested record) is never read, because it sits deeper than the record's own depth; comments never reach the tokens.

- [ ] **Step 5: Run the tests and the analyzer**

Run: `fvm dart test packages/nidana_contract_check/test/dart_library_test.dart`
Expected: PASS.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add packages/nidana_contract_check/lib/src/dart_scanner.dart packages/nidana_contract_check/lib/src/dart_library.dart packages/nidana_contract_check/test/dart_library_test.dart
git commit -m "feat(contract_check): read Dart fixtures" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: The structure set

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. The three library files are pure: no `dart:io`. `checkStructure` is ADR-001 item 9's `structure` set: marker and header syntax, item 3's coverage, the bindings listed in `## Validation` against the files present, the layout with data directories, and the ban on `src/` imports. The samples in `test/support/sample.dart` are strings, never `.dart` files, because a seeded violation never sits in a member's analyzed code (D2 item 5).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/snapshot.dart`
- Create: `packages/nidana_contract_check/lib/src/outcome.dart`
- Create: `packages/nidana_contract_check/lib/src/structure.dart`
- Create: `packages/nidana_contract_check/test/support/sample.dart`
- Test: `packages/nidana_contract_check/test/structure_test.dart`

**Interfaces:**
- Consumes:
  - Task 1 (`ids.dart`): `String formatIds(Iterable<int> ids)`.
  - Task 3 (`contract.dart`): `ContractText readContract(String slug, String text)`; `ContractText` fields `id`, `kindLabel`, `kind` (`ContractKind?`), `guarantees`, `malformedGuarantees`, `bindings`, `listedDirectories`, `coversClauses` (`bullet`, `text`, `ids`), `invocationRows` (`caseName`, `covers`, `ids`), `notExecutable` (`text`, `id`, `partial`, `node`); `ContractKind.setDirectories`.
  - Task 4 (`dart_library.dart`): `DartLibrary readDartLibrary(String source)`; `directives`, `coversHeaders` (`line`, `text`, `ids`), `markers` (`line`, `code`, `followedByCode`), `caseLists` (`name`, `cases` of `({int line, String? name})`, `problems`).
- Produces:

```dart
// lib/src/snapshot.dart
/// What the shell reads for one slug: the pure core's whole input.
final class SlugSnapshot {
  const SlugSnapshot({required this.slug, required this.contractText, required this.hasSchemaFile,
      required this.directories, required this.files});
  final String slug;
  final String? contractText; // hsdd/contract/{slug}.md; null when absent
  final bool hasSchemaFile; // hsdd/contract/schema/{slug}.schema.json exists
  final Set<String> directories; // below hsdd/contract/fixture/{slug}/, relative, `/`-separated, no trailing slash
  final Map<String, String?> files; // below it, relative: source when holdsSource(path), else null
}
/// Whether the shell reads a file's source: a `.dart` file below surface/, reject/ or behavior/.
bool holdsSource(String relativePath);
String contractPath(String slug); // 'hsdd/contract/{slug}.md'
String fixtureDirectory(String slug); // 'hsdd/contract/fixture/{slug}/'

// lib/src/outcome.dart
/// A rule a set checks; each set names its rules with an enum implementing this.
abstract interface class Rule { String get label; }
final class Problem { const Problem(this.rule, this.detail); final Rule rule; final String detail; }
/// What one set concluded about one fixture, named by its path from the workspace root.
sealed class FixtureOutcome { const FixtureOutcome(this.path); final String path; }
final class Passed extends FixtureOutcome { const Passed(super.path); }
final class Failed extends FixtureOutcome { const Failed(super.path, this.problems); final List<Problem> problems; }

// lib/src/structure.dart
enum StructureRule implements Rule {
  contractText('contract-text'), validationForm('validation-form'), layout('layout'),
  coverage('coverage'), unknownId('unknown-id'), coversHeader('covers-header'), marker('marker'),
  caseName('case-name'), binding('binding'), invocationRow('invocation-row'), srcImport('src-import');
  const StructureRule(this.label);
  @override
  final String label;
}
List<FixtureOutcome> checkStructure(SlugSnapshot snapshot);

// test/support/sample.dart (later tasks reuse these)
const String sampleContract; // hsdd/contract/sample.md
const String sampleReject; // hsdd/contract/fixture/sample/reject/sample_is_closed.dart
const Map<String, String> sampleFiles; // the clean `sample` slug, keyed by path from the workspace root
const Map<String, String> toolFiles; // the clean `tool` slug (kind file)
Map<String, String> changed(Map<String, String> base, Map<String, String?> changes); // null removes
SlugSnapshot snapshotOf(String slug, Map<String, String> files); // as the shell would read it
```

- [ ] **Step 1: Write the failing test and its samples**

`test/support/sample.dart` holds these contents (each a raw `r'''...'''` string that starts on the line after `r'''` and ends with exactly one newline, which the marker tests below rely on), keyed in `sampleFiles` and `toolFiles` by the paths shown. `snapshotOf` takes `hsdd/contract/{slug}.md` as `contractText`, sets `hasSchemaFile` when `hsdd/contract/schema/{slug}.schema.json` is a key, and for each key below `hsdd/contract/fixture/{slug}/` adds its relative path to `files` (source only when `holdsSource`) and every ancestor directory of it to `directories`.

`hsdd/contract/sample.md` (`sampleContract`):

```markdown
---
id: sample
version: v1
status: stable
kind: api
---

# sample@v1

## Guarantees / invariants

- **G1** a sample type is closed.
- **G2** a sample value round-trips.
- **G3** a sample value is redacted.
- **G4** a property of the package's pubspec.

## Validation

- surface: `hsdd/contract/fixture/sample/surface/` uses every declaration.
- reject: `hsdd/contract/fixture/sample/reject/`, one library per type-level guarantee.
- behavior: conformance library `hsdd/contract/fixture/sample/behavior/sample_conformance.dart`, cases `sampleConformance`.
- binding: `hsdd/contract/fixture/sample/behavior/sample_impl_test.dart` binds the suite, under `dart test`.
- goldens: `hsdd/contract/fixture/sample/goldens/`, renderings the behavior set compares.
- not executable: G4, a property of the package's pubspec; checked by nidana.model's gates
- not executable: G3's last clause, on a value no case can build; checked by nidana.model's gates
```

`hsdd/contract/fixture/sample/reject/sample_is_closed.dart` (`sampleReject`):

```dart
// Reject fixture for sample@v1 G1: the sample type is closed.
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class Local extends Sample {}
```

`hsdd/contract/fixture/sample/behavior/sample_conformance.dart` (the `name:` on line 12 is the first case; the `G9` topic in its body is no case):

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
    name: 'G2 a sample value round-trips',
    body: (SampleHarness h) async {
      expect(Topic(name: 'G9 a topic, not a case').name, isNotEmpty);
    },
  ),
  (
    name: 'G3 a sample value is redacted',
    body: (SampleHarness h) async {},
  ),
];
```

`hsdd/contract/fixture/sample/behavior/sample_impl_test.dart`:

```dart
import 'package:test/test.dart';

import 'sample_conformance.dart';

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
```

`hsdd/contract/fixture/sample/surface/use.dart`:

```dart
import 'package:sample/sample.dart';

Sample use() => Sample();
```

`hsdd/contract/fixture/sample/goldens/sample.txt`: `golden` and a newline.

`hsdd/contract/tool.md` (in `toolFiles`):

```markdown
---
id: tool
version: v1
status: stable
kind: file
---

# tool@v1

## Guarantees / invariants

- **G1** generate writes the expected tree.
- **G2** generate exits 2 on an unknown option.

## Validation

- file: `hsdd/contract/fixture/tool/input/` holds `in.txt`; the replay runs `fvm dart run tool:generate {input}/in.txt {output}` and compares the tree with `expected/`. The file set covers G1.
- invocations: one directory per case under `hsdd/contract/fixture/tool/invocation/`.

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `generate-usage` | `tool:generate --frob` | 2 | G2: an unknown option |
```

and `hsdd/contract/fixture/tool/input/in.txt` (`in`), `hsdd/contract/fixture/tool/expected/out.txt` (`out`), `hsdd/contract/fixture/tool/invocation/generate-usage/args` (`tool:generate`, `--frob`, one per line), `hsdd/contract/fixture/tool/invocation/generate-usage/exit_code` (`2`), each ending in a newline.

```dart
// packages/nidana_contract_check/test/structure_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/structure.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String t = 'hsdd/contract/fixture/tool/';

List<FixtureOutcome> check(Map<String, String?> changes, {String slug = 'sample', Map<String, String> base = sampleFiles}) =>
    checkStructure(snapshotOf(slug, changed(base, changes)));

/// The problems at [path] as 'rule (detail)'; empty when it passed or has no outcome.
List<String> at(List<FixtureOutcome> outcomes, String path) => <String>[
      for (final FixtureOutcome o in outcomes)
        if (o is Failed && o.path == path)
          for (final Problem p in o.problems) '${p.rule.label} (${p.detail})',
    ];

String contractWith(String from, String to) => sampleContract.replaceFirst(from, to);

void main() {
  test('the sample passes: one outcome per subject, in order', () {
    final List<FixtureOutcome> o = check(const <String, String?>{});
    expect(o.map((FixtureOutcome x) => x.path), <String>[
      'hsdd/contract/sample.md', s, '${s}behavior/sample_conformance.dart',
      '${s}behavior/sample_impl_test.dart', '${s}reject/sample_is_closed.dart', '${s}surface/use.dart',
    ]);
    expect(o, everyElement(isA<Passed>()));
  });
  test('the tool sample passes', () {
    final List<FixtureOutcome> o = check(const <String, String?>{}, slug: 'tool', base: toolFiles);
    expect(o.map((FixtureOutcome x) => x.path), <String>['hsdd/contract/tool.md', t]);
    expect(o, everyElement(isA<Passed>()));
  });
  group('layout', () {
    test('an unlisted directory or file', () {
      final List<FixtureOutcome> o = check(<String, String?>{'${s}extra/a.txt': 'a', '${s}notes.txt': 'n'});
      expect(at(o, '${s}extra/'), <String>['layout (extra is neither a set directory of kind api nor a data directory listed in ## Validation)']);
      expect(at(o, '${s}notes.txt'), <String>['layout (notes.txt is neither a set directory of kind api nor a data directory listed in ## Validation)']);
    });
    test('a listed data directory that is absent', () {
      expect(at(check(<String, String?>{'${s}goldens/sample.txt': null}), '${s}goldens/'), <String>['layout (listed in ## Validation, absent)']);
    });
    test('a shared-model contract has no valid/ directory', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': contractWith('kind: api', 'kind: shared-model'), '${s}valid/a.json': '{}'});
      expect(at(o, '${s}valid/'), <String>['layout (valid is neither a set directory of kind shared-model nor a data directory listed in ## Validation)']);
    });
  });
  group('headers and markers', () {
    test('a reject file without a covers header', () {
      final List<FixtureOutcome> o = check(<String, String?>{'${s}reject/sample_is_closed.dart': sampleReject.replaceFirst('// covers: G1\n', '')});
      expect(at(o, '${s}reject/sample_is_closed.dart'), <String>['covers-header (no // covers: header)']);
      expect(at(o, s), <String>['coverage (G1 uncovered)']);
    });
    test('a malformed or repeated covers header', () {
      expect(at(check(<String, String?>{'${s}reject/sample_is_closed.dart': sampleReject.replaceFirst('G1\n', 'the closed family\n')}), '${s}reject/sample_is_closed.dart'),
          <String>['covers-header (malformed // covers: the closed family)']);
      expect(at(check(<String, String?>{'${s}reject/sample_is_closed.dart': '// covers: G2\n$sampleReject'}), '${s}reject/sample_is_closed.dart'),
          <String>['covers-header (more than one // covers: header)']);
    });
    test('a covers header that names an undeclared id', () {
      expect(at(check(<String, String?>{'${s}reject/sample_is_closed.dart': sampleReject.replaceFirst('G1\n', 'G1, G7\n')}), '${s}reject/sample_is_closed.dart'),
          <String>['unknown-id (G7 is not a guarantee of sample)']);
    });
    test('no marker, a malformed marker, a marker with no code after it', () {
      const String noMarker = '// covers: G1\nfinal class Local extends Sample {}\n';
      expect(at(check(<String, String?>{'${s}reject/sample_is_closed.dart': noMarker}), '${s}reject/sample_is_closed.dart'),
          <String>['marker (no // expect-diagnostic: marker)']);
      expect(at(check(<String, String?>{'${s}reject/sample_is_closed.dart': '$sampleReject// expect-diagnostic: Bad_Code\nint x = 1;\n'}), '${s}reject/sample_is_closed.dart'),
          <String>['marker (line 7: not a marker of the form // expect-diagnostic: {code})']);
      expect(at(check(<String, String?>{'${s}reject/sample_is_closed.dart': '$sampleReject// expect-diagnostic: unused_local\n'}), '${s}reject/sample_is_closed.dart'),
          <String>['marker (line 7: not followed by a line of code)']);
    });
  });
  group('coverage and case names', () {
    test('a guarantee nothing covers', () {
      expect(at(check(<String, String?>{'hsdd/contract/sample.md': contractWith('- **G4**', '- **G5** uncovered.\n- **G4**')}), s),
          <String>['coverage (G5 uncovered)']);
    });
    test('a case name that does not begin with its id', () {
      final String conformance = sampleFiles['${s}behavior/sample_conformance.dart']!;
      final List<FixtureOutcome> o = check(<String, String?>{'${s}behavior/sample_conformance.dart': conformance.replaceFirst("'G2 a", "'g2 a")});
      expect(at(o, '${s}behavior/sample_conformance.dart'),
          <String>['case-name (line 12: case name does not begin with G{n} and a space: g2 a sample value round-trips)']);
      expect(at(o, s), <String>['coverage (G2 uncovered)']);
    });
    test('a conformance library without one public case list', () {
      final List<FixtureOutcome> o = check(<String, String?>{'${s}behavior/sample_conformance.dart': 'abstract interface class SampleHarness {}\n'});
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>['case-name (0 public List<ConformanceCase> declarations, expected one)']);
      expect(at(o, s), <String>['coverage (G2, G3 uncovered)']);
    });
  });
  group('bindings and imports', () {
    test('a listed binding that is absent, a binding that is not listed', () {
      expect(at(check(<String, String?>{'${s}behavior/sample_impl_test.dart': null}), '${s}behavior/sample_impl_test.dart'),
          <String>['binding (listed in ## Validation, absent)']);
      expect(at(check(<String, String?>{'${s}behavior/extra_test.dart': 'void main() {}\n'}), '${s}behavior/extra_test.dart'),
          <String>['binding (not listed in ## Validation)']);
    });
    test('a src/ import or export', () {
      final String use = sampleFiles['${s}surface/use.dart']!;
      expect(at(check(<String, String?>{'${s}surface/use.dart': "import 'package:sample/src/sample_base.dart';\n$use"}), '${s}surface/use.dart'),
          <String>['src-import (package:sample/src/sample_base.dart)']);
      expect(at(check(<String, String?>{'${s}surface/use.dart': "export 'package:sample/src/sample_base.dart';\n$use"}), '${s}surface/use.dart'),
          <String>['src-import (package:sample/src/sample_base.dart)']);
    });
  });
  group('Validation forms', () {
    test('a whole not-executable line must name its node, and covers nothing without it', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': contractWith("pubspec; checked by nidana.model's gates", 'pubspec')});
      expect(at(o, 'hsdd/contract/sample.md'), <String>["validation-form (G4's not-executable line names no node: ; checked by {node}'s gates)"]);
      expect(at(o, s), <String>['coverage (G4 uncovered)']);
    });
    test('a partial not-executable line must name its node too', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': contractWith("build; checked by nidana.model's gates", 'build')});
      expect(at(o, 'hsdd/contract/sample.md'), <String>["validation-form (G3's not-executable line names no node: ; checked by {node}'s gates)"]);
      expect(at(o, s), isEmpty);
    });
    test('invocation directories against the Case table', () {
      expect(at(check(<String, String?>{'${t}invocation/extra/args': 'tool:generate\n'}, slug: 'tool', base: toolFiles), '${t}invocation/extra/'),
          <String>['invocation-row (no row in the Case table)']);
      expect(at(check(<String, String?>{'${t}invocation/generate-usage/args': null, '${t}invocation/generate-usage/exit_code': null}, slug: 'tool', base: toolFiles),
          '${t}invocation/generate-usage/'), <String>['invocation-row (a row of the Case table, absent)']);
    });
    test('a malformed Covers cell or covers clause', () {
      final String tool = toolFiles['hsdd/contract/tool.md']!;
      List<FixtureOutcome> withTool(String from, String to) =>
          check(<String, String?>{'hsdd/contract/tool.md': tool.replaceFirst(from, to)}, slug: 'tool', base: toolFiles);
      final List<FixtureOutcome> cell = withTool('| G2: an unknown option |', '| two |');
      expect(at(cell, 'hsdd/contract/tool.md'), <String>['validation-form (malformed Covers cell of generate-usage: two)']);
      expect(at(cell, t), <String>['coverage (G2 uncovered)']);
      final List<FixtureOutcome> clause = withTool('covers G1.', 'covers the tree.');
      expect(at(clause, 'hsdd/contract/tool.md'), <String>['validation-form (malformed covers clause: covers the tree.)']);
      expect(at(clause, t), <String>['coverage (G1 uncovered)']);
    });
  });
  group('the contract text', () {
    test('absent: one outcome', () {
      final List<FixtureOutcome> o = check(<String, String?>{'hsdd/contract/sample.md': null});
      expect(o.map((FixtureOutcome x) => x.path), <String>['hsdd/contract/sample.md']);
      expect(at(o, 'hsdd/contract/sample.md'), <String>['contract-text (no contract text at hsdd/contract/sample.md)']);
    });
    test('a wrong id, an unknown kind, a repeated guarantee', () {
      expect(at(check(<String, String?>{'hsdd/contract/sample.md': contractWith('id: sample', 'id: other')}), 'hsdd/contract/sample.md'),
          <String>['contract-text (frontmatter id is other, expected sample)']);
      expect(at(check(<String, String?>{'hsdd/contract/sample.md': contractWith('kind: api', 'kind: widget')}), 'hsdd/contract/sample.md'),
          <String>['contract-text (unknown kind widget)']);
      expect(at(check(<String, String?>{'hsdd/contract/sample.md': contractWith('- **G4**', '- **G2** again.\n- **G4**')}), 'hsdd/contract/sample.md'),
          <String>['contract-text (G2 repeats)']);
    });
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/structure_test.dart`
Expected: FAIL, `snapshot.dart`, `outcome.dart` and `structure.dart` do not exist.

- [ ] **Step 3: Implement `snapshot.dart` and `outcome.dart`**

`holdsSource(p)` is true when `p` ends with `.dart` and its first segment is `surface`, `reject` or `behavior`. `contractPath('x')` is `hsdd/contract/x.md`; `fixtureDirectory('x')` is `hsdd/contract/fixture/x/`.

- [ ] **Step 4: Implement `checkStructure(SlugSnapshot snapshot) -> List<FixtureOutcome>` in `structure.dart`**

Subjects: the contract text (`contractPath`), the fixture directory (`fixtureDirectory`), and every file whose source the snapshot holds (a Dart library below `surface/`, `reject/` or `behavior/`); each gets a `Passed` or a `Failed`. Any other path appears only when it fails. Order: the contract text, the fixture directory, then every other path ascending. A path with problems is one `Failed`, its problems in the order of the checks below. A directory path ends in `/`; `{dir}` below is `fixtureDirectory(slug)`. When the contract text is absent, return only `Failed(contractPath, [contract-text 'no contract text at {contractPath}'])`.

| Check | Rule | Path | Detail |
|-------|------|------|--------|
| frontmatter `id` is not the slug | contract-text | contract | `frontmatter id is {id or none}, expected {slug}` |
| `kind` is no `ContractKind` (then skip the layout checks) | contract-text | contract | `unknown kind {kind or none}` |
| each malformed guarantee entry | contract-text | contract | `guarantee entry does not begin with - **G{n}**: {entry}` |
| an id that occurs twice among `guarantees` | contract-text | contract | `G{n} repeats` |
| a covers clause whose `ids` is null | validation-form | contract | `malformed covers clause: covers {text}.` |
| a row whose `caseName` is null | validation-form | contract | `malformed Case cell: {covers}` |
| a row whose `ids` is null | validation-form | contract | `malformed Covers cell of {case}: {covers}` |
| a not-executable line whose `id` is null | validation-form | contract | `not-executable line begins with no G{n}: {text}` |
| a not-executable line, whole or partial, with an `id` and a null `node` | validation-form | contract | `G{n}'s not-executable line names no node: ; checked by {node}'s gates` |
| a listed binding not of the form `{dir}behavior/{name}_test.dart` with no further `/` | binding | contract | `listed binding {path} is not in {dir}behavior/` |
| a top-level file (no `/` in its relative path), or a top-level directory that is neither a set directory of the kind nor a listed data directory | layout | `{dir}{entry}` or `{dir}{entry}/` | `{entry} is neither a set directory of kind {kind label} nor a data directory listed in ## Validation` |
| a listed directory outside the kind's set directories that is absent | layout | `{dir}{name}/` | `listed in ## Validation, absent` |
| per library: each directive matching `^package:[^/]+/src/` | src-import | library | the URI |
| per `reject/` library: no covers header, or more than one | covers-header | library | `no // covers: header` / `more than one // covers: header` |
| per `reject/` library: the one header's `ids` is null | covers-header | library | `malformed // covers: {text}` |
| per `reject/` library: a marker whose `code` is null | marker | library | `line {n}: not a marker of the form // expect-diagnostic: {code}` |
| per `reject/` library: a marker with a code and not `followedByCode` | marker | library | `line {n}: not followed by a line of code` |
| per `reject/` library: no marker with a code | marker | library | `no // expect-diagnostic: marker` |
| per `behavior/{name}_conformance.dart` (directly in `behavior/`): public case lists other than exactly one | case-name | library | `{n} public List<ConformanceCase> declarations, expected one` |
| each list problem | case-name | library | the problem |
| each case whose name is null | case-name | library | `line {n}: case name is not a string literal` |
| each case whose name does not match `^G([1-9][0-9]*) ` | case-name | library | `line {n}: case name does not begin with G{n} and a space: {name}` |
| `behavior/{name}_test.dart` (directly in `behavior/`) not among the listed bindings | binding | library | `not listed in ## Validation` |
| a listed binding (of the right form) that is not a file | binding | the binding's path | `listed in ## Validation, absent` |
| an `invocation/{case}` directory with no row of that `caseName` | invocation-row | `{dir}invocation/{case}/` | `no row in the Case table` |
| a row whose `caseName` has no `invocation/{case}` directory | invocation-row | `{dir}invocation/{case}/` | `a row of the Case table, absent` |
| ids cited at one path that `guarantees` lacks (the library for a header or case names; the contract for Validation forms) | unknown-id | citing path | `G7 is not a guarantee of {slug}`; for several, `G7, G8 are not guarantees of {slug}` (`formatIds`) |
| declared ids that nothing covers | coverage | `{dir}` | `{ids} uncovered` (`formatIds`) |

Coverage (ADR-001 item 3): an id is covered by the one parsed header of a `reject/` library, by a case name `G{n} ...` of a conformance library, by a covers clause, by an invocation row, or by a whole not-executable line that names its node. Both forms of ADR-001 item 3, whole (`- not executable: G{n}, {reason}; checked by {node}'s gates`) and partial (`- not executable: G{n}'s {part}, {reason}; checked by {node}'s gates`), must carry the `checked by {node}'s gates` clause; a line without it is a `validation-form` failure and covers nothing. A partial line is read for its id, which must be declared, and covers nothing even with its node, because item 3 asks for it beside a fixture that covers the rest.

- [ ] **Step 5: Run the tests and the analyzer**

Run: `fvm dart test packages/nidana_contract_check/test/structure_test.dart`
Expected: PASS.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add packages/nidana_contract_check/lib/src/snapshot.dart packages/nidana_contract_check/lib/src/outcome.dart packages/nidana_contract_check/lib/src/structure.dart packages/nidana_contract_check/test/support/sample.dart packages/nidana_contract_check/test/structure_test.dart
git commit -m "feat(contract_check): the structure set" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: The run plan and the report

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. Both files are pure: no `dart:io`. The later tool phases share these: nidana.model.2 adds a `Pending` outcome and the first real runners for other sets, so keep the sealed types closed and the switch over them exhaustive.

**Files:**
- Create: `packages/nidana_contract_check/lib/src/run.dart`
- Create: `packages/nidana_contract_check/lib/src/report.dart`
- Test: `packages/nidana_contract_check/test/report_test.dart`

**Interfaces:**
- Consumes:
  - Task 2 (`request.dart`): `enum CheckSet { structure, surface, reject, behavior, schema, file, cli }`; `Request({required List<String> slugs, required Set<CheckSet>? sets, required Set<GuaranteeRef>? restriction})`.
  - Task 5 (`snapshot.dart`, `outcome.dart`, `structure.dart`): `SlugSnapshot` (`slug`, `hasSchemaFile`, `directories`, `files`); `FixtureOutcome`, `Passed(path)`, `Failed(path, problems)`, `Problem(rule, detail)`, `Rule.label`; `StructureRule`; test support `sampleFiles`, `toolFiles`, `changed`, `snapshotOf`.
- Produces:

```dart
// lib/src/run.dart
/// The sets a slug has: structure always; surface, reject, behavior when that directory exists;
/// schema when the schema file or a valid/ or invalid/ directory exists; file when input/ or
/// expected/ exists; cli when invocation/ exists.
Set<CheckSet> setsOf(SlugSnapshot snapshot);
/// structure first, then each other set the slug has and the request selects, in CheckSet order.
List<CheckSet> plannedSets(Request request, SlugSnapshot snapshot);

// lib/src/report.dart
const int exitPassed = 0;
const int exitFailed = 1;
const int exitEnvironment = 2;
const int exitUsage = 64;
sealed class SetRun { const SetRun(this.set, this.slug); final CheckSet set; final String slug; }
final class SetChecked extends SetRun { const SetChecked(super.set, super.slug, this.outcomes); final List<FixtureOutcome> outcomes; }
/// A set this version of the tool does not implement yet: an environment error.
final class SetUnavailable extends SetRun { const SetUnavailable(super.set, super.slug); }
String outcomeLine(CheckSet set, FixtureOutcome outcome);
String unavailableLine(SetUnavailable run);
String summaryLine(List<SetRun> runs);
int exitCodeOf(List<SetRun> runs);
```

- [ ] **Step 1: Write the failing test**

```dart
// packages/nidana_contract_check/test/report_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/run.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/structure.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

Request request({Set<CheckSet>? sets}) => Request(slugs: const <String>['sample'], sets: sets, restriction: null);

const SetChecked passing = SetChecked(CheckSet.structure, 'sample', <FixtureOutcome>[Passed('a'), Passed('b')]);
const SetChecked failing = SetChecked(CheckSet.structure, 'tool', <FixtureOutcome>[
  Failed('c', <Problem>[Problem(StructureRule.layout, 'x')]),
]);
const SetUnavailable unavailable = SetUnavailable(CheckSet.surface, 'sample');

void main() {
  group('setsOf', () {
    test('the sample has structure, surface, reject and behavior', () {
      expect(setsOf(snapshotOf('sample', sampleFiles)),
          <CheckSet>{CheckSet.structure, CheckSet.surface, CheckSet.reject, CheckSet.behavior});
    });
    test('the tool sample has structure, file and cli', () {
      expect(setsOf(snapshotOf('tool', toolFiles)), <CheckSet>{CheckSet.structure, CheckSet.file, CheckSet.cli});
    });
    test('a schema file or a valid/ or invalid/ directory gives schema', () {
      expect(setsOf(snapshotOf('sample', changed(sampleFiles, <String, String?>{'hsdd/contract/schema/sample.schema.json': '{}'}))),
          contains(CheckSet.schema));
      expect(setsOf(snapshotOf('sample', changed(sampleFiles, <String, String?>{'hsdd/contract/fixture/sample/invalid/a.json': '{}'}))),
          contains(CheckSet.schema));
    });
  });
  group('plannedSets', () {
    final SlugSnapshot sample = snapshotOf('sample', sampleFiles);
    test('every set the slug has, structure first', () {
      expect(plannedSets(request(), sample), <CheckSet>[CheckSet.structure, CheckSet.surface, CheckSet.reject, CheckSet.behavior]);
    });
    test('structure runs whether --set names it or not', () {
      expect(plannedSets(request(sets: <CheckSet>{CheckSet.reject}), sample), <CheckSet>[CheckSet.structure, CheckSet.reject]);
    });
    test('--set never adds a set the slug lacks', () {
      expect(plannedSets(request(sets: <CheckSet>{CheckSet.schema, CheckSet.cli}), sample), <CheckSet>[CheckSet.structure]);
    });
  });
  group('lines', () {
    test('a passed fixture', () {
      expect(outcomeLine(CheckSet.structure, const Passed('hsdd/contract/fixture/sample/')), 'PASS structure hsdd/contract/fixture/sample/');
    });
    test('a failed fixture lists every problem', () {
      expect(
          outcomeLine(CheckSet.structure, const Failed('hsdd/contract/fixture/sample/x.dart',
              <Problem>[Problem(StructureRule.layout, 'one'), Problem(StructureRule.marker, 'two')])),
          'FAIL structure hsdd/contract/fixture/sample/x.dart: layout (one); marker (two)');
    });
    test('an unavailable set', () {
      expect(unavailableLine(unavailable), 'ERROR surface sample: this version of nidana_contract_check does not implement the surface set');
    });
    test('the summary counts fixtures', () {
      expect(summaryLine(const <SetRun>[passing, failing, unavailable]), '3 fixtures: 2 passed, 1 failed');
    });
  });
  group('exitCodeOf', () {
    test('0 when every fixture passes, and for no run', () {
      expect(exitCodeOf(const <SetRun>[passing]), exitPassed);
      expect(exitCodeOf(const <SetRun>[]), exitPassed);
    });
    test('1 when a fixture fails', () => expect(exitCodeOf(const <SetRun>[passing, failing]), exitFailed));
    test('2 when a set is unavailable, failures or not', () {
      expect(exitCodeOf(const <SetRun>[passing, failing, unavailable]), exitEnvironment);
    });
    test('the four codes of ADR-001 item 9', () {
      expect(<int>[exitPassed, exitFailed, exitEnvironment, exitUsage], <int>[0, 1, 2, 64]);
    });
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/report_test.dart`
Expected: FAIL, `run.dart` and `report.dart` do not exist.

- [ ] **Step 3: Implement `run.dart` and `report.dart`**

`outcomeLine` is `PASS {set} {path}` for `Passed` and `FAIL {set} {path}: {rule} ({detail}); {rule} ({detail})...` for `Failed`, by an exhaustive `switch` over `FixtureOutcome`. `unavailableLine` is `ERROR {set} {slug}: this version of nidana_contract_check does not implement the {set} set`. `summaryLine` counts the outcomes of every `SetChecked`: `{n} fixtures: {passed} passed, {failed} failed`. `exitCodeOf`: `exitEnvironment` when any run is a `SetUnavailable`; else `exitFailed` when any outcome is `Failed`; else `exitPassed`. An environment error outranks a failure because the replay is then incomplete, so a gate must not read its failures as the whole story.

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm dart test packages/nidana_contract_check/test/report_test.dart`
Expected: PASS.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_contract_check/lib/src/run.dart packages/nidana_contract_check/lib/src/report.dart packages/nidana_contract_check/test/report_test.dart
git commit -m "feat(contract_check): plan the sets and report the run" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: The shell and the executable

You are building part of `packages/nidana_contract_check`, the contract replay tool (ADR-001 item 9). Run every command from the repository root with `fvm dart`. `shell.dart` is the only library that imports `dart:io`; it reads, runs and prints, and leaves every decision to the pure core. Tests run the tool's bin script with `Platform.resolvedExecutable` from seeded temporary directories: run by absolute path from outside the workspace, the script still resolves its packages (`docs/auto-run/experiments/structure-set-plan/output.txt`, W7).

**Files:**
- Create: `packages/nidana_contract_check/lib/src/shell.dart`
- Create: `packages/nidana_contract_check/bin/nidana_contract_check.dart`
- Create: `packages/nidana_contract_check/test/support/seed.dart`
- Test: `packages/nidana_contract_check/test/cli_test.dart`

**Interfaces:**
- Consumes:
  - Task 2: `ParseResult parseRequest(List<String> arguments, {required Set<String> slugs})`, `ParsedRequest.request`, `UsageError.message`, `usage`, `Request.slugs`, `CheckSet`.
  - Task 5: `SlugSnapshot({slug, contractText, hasSchemaFile, directories, files})`, `bool holdsSource(String relativePath)`, `List<FixtureOutcome> checkStructure(SlugSnapshot)`; test support `sampleContract`, `sampleReject`, `sampleFiles`, `toolFiles`, `changed`.
  - Task 6: `List<CheckSet> plannedSets(Request, SlugSnapshot)`, `SetRun`, `SetChecked(set, slug, outcomes)`, `SetUnavailable(set, slug)`, `outcomeLine`, `unavailableLine`, `summaryLine`, `exitCodeOf`, `exitEnvironment`, `exitUsage`.
- Produces:

```dart
// lib/src/shell.dart
/// The nearest ancestor of [start], [start] included, that holds hsdd/contract/; null when none does.
Directory? findWorkspaceRoot(Directory start);
/// The names of the directories directly under hsdd/contract/fixture/, hidden ones excluded; empty when it is absent.
Set<String> discoverSlugs(Directory root);
/// Reads one slug; entries whose name begins with '.' are not part of it. Throws FileSystemException.
SlugSnapshot readSnapshot(Directory root, String slug);
/// Parses, replays, prints one line per fixture to [out] and errors to [err]; returns the exit code.
Future<int> runCli(List<String> arguments, {required Directory workingDirectory, required StringSink out, required StringSink err});

// test/support/seed.dart
/// Writes [files], keyed by `/`-separated paths, into a fresh temporary directory deleted after the test.
Directory seed(Map<String, String> files);
/// Runs the bin script with [arguments] from [workingDirectory].
Future<ProcessResult> runTool(List<String> arguments, {required Directory workingDirectory});
```

- [ ] **Step 1: Write the failing test**

`seed` writes each file with its parent directories under `Directory.systemTemp.createTempSync('ncc_')` and registers `addTearDown` to delete it. `runTool` runs `Process.run(Platform.resolvedExecutable, [bin, ...arguments], workingDirectory: ...)`, where `bin` is `packages/nidana_contract_check/bin/nidana_contract_check.dart` under `findWorkspaceRoot(Directory.current)`, joined with `package:path`.

```dart
// packages/nidana_contract_check/test/cli_test.dart
import 'dart:io';

import 'package:test/test.dart';

import 'support/sample.dart';
import 'support/seed.dart';

const String s = 'hsdd/contract/fixture/sample/';
const List<String> cleanLines = <String>[
  'PASS structure hsdd/contract/sample.md',
  'PASS structure hsdd/contract/fixture/sample/',
  'PASS structure hsdd/contract/fixture/sample/behavior/sample_conformance.dart',
  'PASS structure hsdd/contract/fixture/sample/behavior/sample_impl_test.dart',
  'PASS structure hsdd/contract/fixture/sample/reject/sample_is_closed.dart',
  'PASS structure hsdd/contract/fixture/sample/surface/use.dart',
  '6 fixtures: 6 passed, 0 failed',
];

List<String> lines(ProcessResult r) => (r.stdout as String).trimRight().split('\n');
String all(ProcessResult r) => '${r.stdout}${r.stderr}';

void main() {
  test('a clean slug passes with one line per fixture', () async {
    final ProcessResult r = await runTool(<String>['sample', '--set', 'structure'], workingDirectory: seed(sampleFiles));
    expect(r.exitCode, 0, reason: all(r));
    expect(lines(r), cleanLines);
  });
  test('--all replays every slug in ascending order', () async {
    final ProcessResult r = await runTool(<String>['--all', '--set', 'structure'],
        workingDirectory: seed(<String, String>{...sampleFiles, ...toolFiles}));
    expect(r.exitCode, 0, reason: all(r));
    expect(lines(r), <String>[
      ...cleanLines.take(6),
      'PASS structure hsdd/contract/tool.md',
      'PASS structure hsdd/contract/fixture/tool/',
      '8 fixtures: 8 passed, 0 failed',
    ]);
  });
  group('each seeded defect names the fixture and the rule, and exits 1', () {
    final String use = sampleFiles['${s}surface/use.dart']!;
    for (final (String name, Map<String, String?> change, String line) in <(String, Map<String, String?>, String)>[
      ('an unlisted directory', <String, String?>{'${s}extra/notes.txt': 'notes\n'},
          'FAIL structure ${s}extra/: layout (extra is neither a set directory of kind api nor a data directory listed in ## Validation)'),
      ('a reject file without a covers header', <String, String?>{'${s}reject/sample_is_closed.dart': sampleReject.replaceFirst('// covers: G1\n', '')},
          'FAIL structure ${s}reject/sample_is_closed.dart: covers-header (no // covers: header)'),
      ('an uncovered guarantee', <String, String?>{'hsdd/contract/sample.md': sampleContract.replaceFirst('- **G4**', '- **G5** uncovered.\n- **G4**')},
          'FAIL structure $s: coverage (G5 uncovered)'),
      ('a listed binding that is absent', <String, String?>{'${s}behavior/sample_impl_test.dart': null},
          'FAIL structure ${s}behavior/sample_impl_test.dart: binding (listed in ## Validation, absent)'),
      ('a src/ import', <String, String?>{'${s}surface/use.dart': "import 'package:sample/src/sample_base.dart';\n$use"},
          'FAIL structure ${s}surface/use.dart: src-import (package:sample/src/sample_base.dart)'),
    ]) {
      test(name, () async {
        final ProcessResult r = await runTool(<String>['--all', '--set', 'structure'], workingDirectory: seed(changed(sampleFiles, change)));
        expect(r.exitCode, 1, reason: all(r));
        expect(lines(r), contains(line));
      });
    }
  });
  test('a set this version does not implement is an environment error (2)', () async {
    final ProcessResult r = await runTool(<String>['sample'], workingDirectory: seed(sampleFiles));
    expect(r.exitCode, 2, reason: all(r));
    expect(lines(r), contains('PASS structure hsdd/contract/sample.md'));
    expect(r.stderr as String, contains('ERROR surface sample: this version of nidana_contract_check does not implement the surface set'));
  });
  test('usage errors exit 64 and print the usage', () async {
    final Directory root = seed(<String, String>{...sampleFiles, ...toolFiles});
    final ProcessResult unknown = await runTool(<String>['nosuch'], workingDirectory: root);
    expect(unknown.exitCode, 64, reason: all(unknown));
    expect(unknown.stderr as String, allOf(contains("unknown slug 'nosuch'"), contains('usage: ')));
    final ProcessResult bare = await runTool(<String>['sample', 'tool', '--guarantee', 'G1'], workingDirectory: root);
    expect(bare.exitCode, 64, reason: all(bare));
    expect(bare.stderr as String, contains("bare id 'G1'"));
  });
  test('no workspace root is an environment error (2)', () async {
    final ProcessResult r = await runTool(<String>['--all'], workingDirectory: seed(const <String, String>{'readme.txt': 'x\n'}));
    expect(r.exitCode, 2, reason: all(r));
    expect(r.stderr as String, contains('no ancestor of'));
  });
  test('from a subdirectory the root is found and paths stay relative to it', () async {
    final Directory root = seed(sampleFiles);
    final ProcessResult r = await runTool(<String>['sample', '--set', 'structure'],
        workingDirectory: Directory('${root.path}/hsdd/contract/fixture/sample/behavior'));
    expect(r.exitCode, 0, reason: all(r));
    expect(lines(r), cleanLines);
  });
  test('hidden entries such as .DS_Store are not part of a snapshot', () async {
    final ProcessResult r = await runTool(<String>['sample', '--set', 'structure'],
        workingDirectory: seed(<String, String>{...sampleFiles, '${s}.DS_Store': 'x', '${s}reject/.DS_Store': 'x'}));
    expect(r.exitCode, 0, reason: all(r));
    expect(lines(r), cleanLines);
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_contract_check/test/cli_test.dart`
Expected: FAIL, `shell.dart` and the bin script do not exist.

- [ ] **Step 3: Implement `shell.dart` and the bin script**

`runCli` does, in order: find the root from `workingDirectory` (none: `error: no ancestor of {path} holds hsdd/contract/` to `err`, return `exitEnvironment`); `discoverSlugs`; `parseRequest` (a `UsageError`: `error: {message}` and `usage` to `err`, return `exitUsage`); then for each slug of the request, `readSnapshot` and, for each set of `plannedSets`, a `SetRun` from an exhaustive `switch` over `CheckSet`: `structure` gives `SetChecked(set, slug, checkStructure(snapshot))`, every other set `SetUnavailable(set, slug)` until the phase that lands it (nidana.model.2, .6, .7) replaces its branch. Print each outcome's `outcomeLine` to `out` and each `unavailableLine` to `err` as the runs complete, then `summaryLine` to `out`, and return `exitCodeOf`. A `FileSystemException` while reading prints `error: {message}: {path}` to `err` and returns `exitEnvironment`.

`readSnapshot` lists `hsdd/contract/fixture/{slug}/` recursively without following links, skips every entry with a path segment that begins with `.`, records directories and files by `/`-separated relative paths (`package:path`'s `relative` and `posix.joinAll(split(...))`), reads a file's source only when `holdsSource` says so, reads `hsdd/contract/{slug}.md` when it exists, and sets `hasSchemaFile` from `hsdd/contract/schema/{slug}.schema.json`.

`bin/nidana_contract_check.dart`:

```dart
import 'dart:io';

import 'package:nidana_contract_check/src/shell.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments, workingDirectory: Directory.current, out: stdout, err: stderr);
}
```

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm dart test packages/nidana_contract_check`
Expected: PASS, every test of the package.
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`

- [ ] **Step 5: Replay the structure set over the nine committed contracts**

Run: `fvm dart run nidana_contract_check --all --set structure`
Expected: exit 0; 102 `PASS structure` lines (per slug: the contract text, the fixture directory and each Dart library under `surface/`, `reject/` and `behavior/`), then `102 fixtures: 102 passed, 0 failed` (the prototype's counts over the nine contracts, `docs/auto-run/experiments/structure-set-plan/output.txt` S2). A `FAIL` line on a committed contract or fixture is a contract gap (ADR-001 item 8): do not edit anything under `hsdd/`; stop and report BLOCKED with the line, the rule it breaks and the fix you would propose.

- [ ] **Step 6: Run the gate (Global Constraint 4)**

Run: `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check`
Expected: exit 0. Keep the output for the verification doc.

- [ ] **Step 7: Commit**

```bash
git add packages/nidana_contract_check/lib/src/shell.dart packages/nidana_contract_check/bin/nidana_contract_check.dart packages/nidana_contract_check/test/support/seed.dart packages/nidana_contract_check/test/cli_test.dart
git commit -m "feat(contract_check): the shell and the executable" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: Gate and verification doc

You write the phase's verification doc. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.1.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.1.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 7; `packages/nidana_contract_check/test/cli_test.dart` (the seeded defects); the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_contract_check) > "${TMPDIR:-/tmp}/nidana.model.1-gate.txt" 2>&1; echo "exit: $?"`, then read the file.
Expected: `exit: 0`; the file holds `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed` and `All tests passed!`. Take the date with `date -u +%Y-%m-%d`. A failure stops here: fix it in the task that owns the code, never by editing `hsdd/`.

- [ ] **Step 2: Check the root files against ADR-002 items 1 and 2**

Read `pubspec.yaml` and `analysis_options.yaml` against ADR-002 item 1 (`name: nidana_workspace`, `publish_to: none`, `environment: sdk: ^3.13.0`, `dev_dependencies: lints: ^6.1.0` only, `workspace:` naming `packages/nidana_contract_check` without globs) and item 2 (the block exactly, no `plugins:`). Run `git ls-files '*pubspec.lock'`; expected: `pubspec.lock` alone.

- [ ] **Step 3: Write `hsdd/verify/nidana.model.1.verification.md` at full-review depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder with content, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.1 - Workspace root and replay tool core` (a spaced hyphen; no em-dash anywhere in the file).

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate command of Step 1; `fvm dart test packages/nidana_contract_check/test/cli_test.dart` for the seeded defects; the root-file check of Step 2. The phase produces no contract, so no schema replay.
- **Expected output:** exit 0 of the gate; `102 fixtures: 102 passed, 0 failed`; the package's test count with `All tests passed!`; for each seeded defect the exit 1 and the exact `FAIL` line `cli_test.dart` asserts (an unlisted directory, a reject file without a `covers` header, an uncovered guarantee, a listed binding that is absent, a `src/` import); exit 2 for a set this version does not implement and for no workspace root; 64 for a usage error; the root files as ADR-002 items 1 and 2 state them.
- **Observed:** dated; the gate's exit code and the lines above as they appeared; the test count; the five seeded defects' lines; the root-file check.
- **Outstanding:** what could not be verified here, or `None.`
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason), or `- none` when the gate found nothing about the tree; never leave the section empty.
- **Metrics:** gate failures before green; the product diff in lines (`git diff --stat` of `pubspec.yaml`, `analysis_options.yaml` and `packages/` from the phase's base); the phase estimated ~450 lines in ~10 files, so record the actual figures beside it.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.1.verification.md
git commit -m "docs(verify): nidana.model.1 verification" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
