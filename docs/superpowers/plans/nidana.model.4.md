# nidana.model.4 topology-dsl@v2 Declarations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land every declaration of topology-dsl@v2's Interface in `packages/nidana_dart_contracts`, the DSL as one library with part files under `lib/src/topology/`, its plan declarations in the new public library `lib/topology_plan.dart`, and topology-ir@v1's The IR and Function references under `lib/src/ir/`, so that the main library's export list is complete and `fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject` passes all 57 fixtures, the first replay of topology-dsl@v2's committed surface and reject sets against a real package; and harden `test/purity_test.dart`'s directive reader before these libraries land.

**Architecture:** A type-level phase (nidana.model D3): signatures, modifiers, `@immutable` and `@nonVirtual`, enums, typedefs, constructors with their defaults and `const`, the asserts the Interface states, a final field behind every getter, and the two public libraries' `show` lists. A member that stores an argument is delivered; every body that computes throws `UnimplementedError`; `==`, `hashCode` and `toString` stay `Object`'s. The DSL is one library because the subclasses of the sealed `TopicStream` and `PlanSink` must share it (D4): `lib/src/topology/topology.dart` holds Topologies and Pipeline values and names five part files; the main library and `topology_plan.dart` export disjoint `show` lists of it. The IR is two libraries under `lib/src/ir/`, one per Interface section.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:meta` 1.19.0 (`@immutable`, `@nonVirtual`), the package's only dependency; `package:test` for the package's tests; the replay tool `nidana_contract_check` as nidana.model.2 left it.

**Spec:** `hsdd-context/superpowers/nidana.model.4.md` (the derivative; the phase context with topic-model@v1's and topology-dsl@v2's Interfaces and Guarantees sits between its markers). Governance it relies on but does not inline: `hsdd/contract/topology-ir.md` from `### The IR` (line 56) to `### Graphs` (line 206), whose declarations and dartdoc Task 2 transcribes, and its Libraries and Delivery paragraphs (lines 43 and 45); `hsdd/spec/nidana.model.md` D1 item 2 (line 77), D3 (line 102, with its Restated paragraph), D4 (line 112, with its Restated paragraph), D5 and D6 (`purity_test.dart`'s checks). The fixtures the gate replays: `hsdd/contract/fixture/topology-dsl/surface/` and `reject/` beside topic-model@v1's, under `hsdd/contract/fixture/analysis_options.yaml`. Evidence: `docs/auto-run/experiments/topology-dsl-declarations-plan/` (`run.sh`, `output.txt`, `draft/`, `probe/`), a dry run of this plan's tasks in a temporary copy of HEAD `b63d281`; labels such as T2.4, G or R below name the steps of its `output.txt`. `draft/` is evidence, not code to copy: the code blocks below are the source, and they are its formatter-stable text. `docs/auto-run/experiments/model-main-library-closure/` (S109) is the earlier proof that this closure analyzes and passes this gate.

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 6 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.4.verification.md from
   hsdd/templates/verification.md at gate-only depth, fills every section
   the template asks for at that depth, writes "- none" or dispositioned
   entries under Learnings, and leaves Sign-off for a human reviewer.
6. Nothing under hsdd/ changes except that verification doc. Contracts, ADRs,
   specs and conventions change only through hsdd-contract, hsdd-adr and
   hsdd-reconcile.
7. Build against the Interface and Guarantees in the Contracts section below
   (if any), never against another node's internals.
8. Review tier gate-only: no design discussion in the plan; slim verification doc.

Project-wide requirements from the spec and the run, which every task's requirements include:

- Toolchain: `fvm dart` only, every command from the repository root, no global tooling. No dependency changes: no `pubspec.yaml` is edited, and `pubspec.lock` stays byte-identical (G3).
- Files: everything this phase writes lives in `packages/nidana_dart_contracts/` (`lib/`, `test/`), except the verification doc of Task 5. Nothing under `hsdd/` changes otherwise, and nothing under `hsdd/contract/` ever. `README.md`, `CHANGELOG.md` and `LICENSE` stay as nidana.model.3 wrote them (D4).
- Declarations (D3): every name, signature, modifier, default and `const` exactly as the two Interfaces write them, with the dartdoc copied as written: topology-dsl@v2's from the derivative, topology-ir@v1's from `hsdd/contract/topology-ir.md` lines 56 to 205, never from memory. Every getter is a final field where it returns a stored value; the reject sets assign to `TopologyDefinition.topologyId` and `.transforms`, `TransformEdge.combinator` and `.inputs`, `TopicInput.dedup`, `StageInput.edge` and `FunctionRef.name`, which report `assignment_to_final` only on a field. `TopologyBuilder`, `TopologyPlan`, `TopicStream`, `PlanSink` and every stage and sink class have one constructor, private (`._`), so none has a public constructor (topology-dsl@v2 G2). No class overrides `==`, `hashCode` or `toString` in this phase: not the stages, sinks, builder and plan (topology-dsl@v2 G30), not `TopologyRef` (its equality, G17, is nidana.model.9's), not the IR values (nidana.model.10's).
- Bodies: the generative constructors store their arguments, and `StageInput` asserts its index is not negative (the Interface's "asserted"). `FunctionRef.named` stores its name; its `ArgumentError` for an empty name is nidana.model.10's, with the rest of `FunctionRef`. Every other body throws `UnimplementedError`: `Topology.buildDefinition`, `topology`, every `TopologyBuilder` and `TopicStream` method, `planOf`, `TopologyPlan.definition`, `visitStage`, `visitSink`, `CombineStage.apply`, `WithLatestFromStage.apply`, the factories of `TransformEdge` and `TopologyDefinition`, `TransformEdge.isSink` and `.isStateBearing`, `FunctionRef.of`.
- Comments: the Interfaces' trailing `//` comments stay trailing line comments, with two exceptions the formatter forces: the comments of `TopologyDefinition.reads` and `.writes` sit on the line above their fields. The Interface's comment that `ThrottleStage`, `DelayStage`, `SampleStage`, `TimeoutStage` and `BufferStage` have `DebounceStage`'s members is dropped, because each class is written out. Add no other comment or dartdoc beyond the blocks below.
- Analyzer: `fvm dart analyze --fatal-infos` at the root reports nothing. The package's only suppressions are nidana.model.3's above `RedactedPayload._` and this phase's two above `TransformEdge._` and `TopologyDefinition._`: a private constructor beside a factory that throws is reported as `unused_element`, while one that is its class's only constructor is not (P).
- Tests: run from the root as `fvm dart test packages/nidana_dart_contracts`. No test asserts a body that throws `UnimplementedError` or an identity comparison: nidana.model.9 and nidana.model.10 change both, and every test here must stay true after them. No test uses a `test` API newer than 1.31.1.
- Contract gaps (ADR-001 item 8; nidana.model's First replays): this gate is the first replay of topology-dsl@v2's surface and reject sets against a real package. A fixture that fails against a declaration matching this plan's block is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the fixture path and line, the reported line, severity, code and message, the marker's code, the guarantee its `// covers:` header names, and the fix you would propose. A reject line where the analyzer reports two codes, one marked and one not, is the gap ADR-001 item 4's marker form cannot express (a marker names one code on the next line, and the structure set rejects stacked markers): report it as a contract gap for hsdd-adr. The dry run passed every fixture with one code per line (T4.4, R), so a FAIL most likely means the code differs from its block.
- Formatting and commits: run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output; it changes nothing when they are copied exactly). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for a Sonnet implementer. No em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.

## Review Focus

The input classes the spec implies but the surface and reject sets do not exercise, most likely to bite first; each has its test in the owning task.

1. **A forbidden URI in a form the old directive reader missed**, now that part files and relative imports land under `lib/src/`: a conditional import whose second URI is `dart:io`, `import r'dart:io';`, adjacent literals `'dart:' 'io'` and an escape `'dart:\x69o'` (both import `dart:io`, P), a relative `import`, `export` or `part` that climbs out of `lib/`, a `file:` URI, a listed token inside a comment. Expected: `purity_test.dart` fails on each (T1.5). Tests: Task 1's three reader self-tests.
2. **A declaration exported from the wrong public library**: the reject set checks only that `MapStage`, `TopologyPlan` and `planOf` are absent from the main library, so `visitStage`, `ReadStage` or `StageVisitor` in the main library, a main-library name in `topology_plan.dart`, or an `export` without a `show` list would pass the replay. Expected: each library's `show` lists equal exactly the names its contracts place in it. Test: Task 4 (`exports_test.dart`).
3. **`CombinatorKind`'s order and names**: a reordered or renamed value compiles, and the surface switch is exhaustive either way, while nidana.model.11's projection and nidana.model.13's JSON form read the eighteen names in topology-dsl@v2's combinator-table order. Expected: exactly `map` to `reduceInto` in that order. Test: Task 2.
4. **IR inputs built at run time and with omitted arguments**: a decoder or a projection builds `StageInput` non-const, where only an assertion stops a negative index, and builds `TopicInput` without `dedup`, which must read null, not the topic's policy (topology-dsl@v2 G13). Expected: an `AssertionError` under `dart test`, which runs with assertions on; `dedup` null by default and kept when given. Test: Task 2.
5. **A topology constructed at module load**: registries and tests construct topologies freely, and constructing one must never run its declaration (topology-dsl@v2 G9). Expected: constructing a subclass whose `declare` throws returns normally, and its id and scope read back. Test: Task 3.

## Routed items

- `purity_test.dart`'s directive reader (from S107's final review): hardened in Task 1. It collects every string literal from a directive's keyword to its `;` (every URI of a conditional import, raw strings included), joins adjacent literals into one URI, reads `part` and `part of` directives, rejects a relative URI that resolves outside `lib/`, a URI with any scheme but `dart` and `package`, and a URI with a backslash, and the self-tests exercise the effects token scan through `effectsIn`. Adjacent literals and escapes go beyond the routed list: the probe shows both import `dart:io` (P).
- The RED baseline: `fvm dart run nidana_contract_check topology-dsl topology-ir --set surface,reject` prints `41 fixtures: 25 passed, 16 failed, 0 pending` before this phase (S1); Task 2 Step 2 records it as the phase's failing replay, and Task 5 records its end state, `41 fixtures: 38 passed, 3 failed, 0 pending` (G2), in the verification doc.
- ADR-001 item 4's one-code marker (from S103): no topology-dsl@v2 reject line carries two codes (R); Task 5 records it.

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/test/src/package_files.dart` | 1 | `workspaceRoot()` and `packageDirectory()`, moved out of `purity_test.dart` for every test that reads the package's files |
| `{pkg}/test/purity_test.dart` | 1 | G25 and G26 (D6), with the hardened directive reader and the effects scan as functions |
| `{pkg}/lib/src/ir/definition.dart` | 2 | topology-ir@v1 The IR: `CombinatorKind`, `EdgeInput`, `TopicInput`, `StageInput`, `TransformEdge`, `TopologyDefinition` |
| `{pkg}/lib/src/ir/function_ref.dart` | 2 | topology-ir@v1 Function references: `FunctionRef` |
| `{pkg}/test/ir_declarations_test.dart` | 2 | What the IR declarations fix before any body computes |
| `{pkg}/lib/src/topology/topology.dart` | 3, 4 | The DSL library: Topologies and Pipeline values, and its part directives (two in Task 3, five in Task 4) |
| `{pkg}/lib/src/topology/builder.dart` | 3 | Part: `TopologyBuilder` |
| `{pkg}/lib/src/topology/handle.dart` | 3 | Part: `TopicStream` |
| `{pkg}/test/topology_declarations_test.dart` | 3 | What the DSL's main-library declarations fix before any body computes |
| `{pkg}/lib/src/topology/plan.dart` | 4 | Part: `planOf`, `TopologyPlan`, `visitStage`, `visitSink`, `StageVisitor`, `SinkVisitor` |
| `{pkg}/lib/src/topology/stages.dart` | 4 | Part: the eighteen stage classes |
| `{pkg}/lib/src/topology/sinks.dart` | 4 | Part: `PlanSink`, `WriteSink`, `ReduceIntoSink` |
| `{pkg}/lib/topology_plan.dart` | 4 | The second public library: the plan's 27 names |
| `{pkg}/lib/nidana_dart_contracts.dart` | 2, 3 | The main library: two IR export directives (2), the DSL export directive (3) |
| `{pkg}/test/exports_test.dart` | 4 | Both public libraries' export lists, exactly |
| `hsdd/verify/nidana.model.4.verification.md` | 5 | The verification doc |

---

### Task 1: Harden the purity test's directive reader

You are hardening `packages/nidana_dart_contracts/test/purity_test.dart`, which checks G25 and G26 of topic-model@v1 by reading the package's own files (nidana.model D6), before the DSL and IR libraries land with part files and relative imports. Run every command from the repository root with `fvm dart`. Today its directive reader reads only the first URI of a conditional import, misses `import r'dart:io';`, accepts a relative URI that climbs out of `lib/` and ignores `part` directives; and adjacent string literals (`'dart:' 'io'`) and escapes (`'dart:\x69o'`) both import `dart:io` past it (`docs/auto-run/experiments/topology-dsl-declarations-plan/probe/lib/uris.dart`). The fix: read every string literal from a directive's keyword to its `;`, join adjacent literals, resolve a relative URI against the library's own path and require it inside `lib/`, and reject any other scheme and any backslash. The effects token scan becomes the function `effectsIn`, so a self-test exercises it. `workspaceRoot()` and `packageDirectory()` move to `test/src/package_files.dart`, which Task 4's `exports_test.dart` also imports; `dart test` runs only files ending in `_test.dart`, so the helper is never run as a test.

**Files:**
- Create: `packages/nidana_dart_contracts/test/src/package_files.dart`
- Modify: `packages/nidana_dart_contracts/test/purity_test.dart` (the two helpers move out; `directiveUris` and `allowedUri` are replaced; `effectsIn` is added; `main()` is replaced)

**Interfaces:**
- Consumes: nothing.
- Produces: `Directory workspaceRoot()` and `Directory packageDirectory()` in `test/src/package_files.dart` (Task 4 imports `src/package_files.dart`); in `purity_test.dart`, `List<String> directiveUris(String source)`, `bool allowedUri(String uri, {required String path, required String lib})` and `List<String> effectsIn(String source)`, which later phases' reviews can point at.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/src/package_files.dart` (the two functions exactly as `purity_test.dart` has them today, under a file comment):

```dart
// Locates this package's files from the workspace root, so that tests run
// from the root as `fvm dart test packages/nidana_dart_contracts`
// (nidana.model D5, D6).
import 'dart:io';

/// The workspace root: the nearest ancestor of the working directory that
/// holds `hsdd/contract/`.
Directory workspaceRoot() {
  for (Directory d = Directory.current.absolute; ; d = d.parent) {
    if (Directory('${d.path}/hsdd/contract').existsSync()) {
      return d;
    }
    if (d.parent.path == d.path) {
      throw StateError(
        'no ancestor of ${Directory.current.path} holds hsdd/contract/',
      );
    }
  }
}

/// This package's directory.
Directory packageDirectory() =>
    Directory('${workspaceRoot().path}/packages/nidana_dart_contracts');
```

In `packages/nidana_dart_contracts/test/purity_test.dart`: delete `workspaceRoot()` and `packageDirectory()` with their dartdoc; add `import 'src/package_files.dart';` after `import 'package:test/test.dart';`, separated by a blank line; leave `sectionKeys`, `directiveUris`, `allowedUri`, `libraries()` and `effects` as they are for now; and replace `void main() { ... }` with:

```dart
void main() {
  test('G26 depends on meta alone, with test its only dev dependency', () {
    final String pubspec = File('${packageDirectory().path}/pubspec.yaml')
        .readAsStringSync();
    expect(sectionKeys(pubspec, 'dependencies'), <String>{'meta'});
    expect(sectionKeys(pubspec, 'dev_dependencies'), <String>{'test'});
  });

  test('G25 G26 no library imports dart:io, dart:isolate, dart:ffi, '
      'dart:html, a package other than meta and its own, or a file '
      'outside lib/', () {
    final String lib = '${packageDirectory().path}/lib';
    final List<File> found = libraries();
    expect(found, isNotEmpty);
    for (final File library in found) {
      for (final String uri in directiveUris(library.readAsStringSync())) {
        expect(
          allowedUri(uri, path: library.path, lib: lib),
          isTrue,
          reason: '${library.path} names $uri',
        );
      }
    }
  });

  test('G25 no library reads a clock, schedules work, '
      'generates an id or reaches a zone', () {
    final List<File> found = libraries();
    expect(found, isNotEmpty);
    for (final File library in found) {
      expect(
        effectsIn(library.readAsStringSync()),
        isEmpty,
        reason: library.path,
      );
    }
  });

  test('the directive reader reads every URI of every directive form', () {
    expect(
      directiveUris(
        "import 'dart:io';\nimport \"dart:async\" as a;\n"
        "  export 'package:x/y.dart' show Z;\nimport 'src/a.dart';\n"
        "import 'a.dart'\n    if (dart.library.io) 'dart:io'\n"
        "    if (dart.library.js_interop) 'b.dart';\n"
        "import r'dart:ffi';\nimport 'dart:' \"isolate\";\n"
        "part 'p.dart';\npart of 'l.dart';\n"
        "// import 'dart:html'; in a comment is no directive\n",
      ),
      <String>[
        'dart:io',
        'dart:async',
        'package:x/y.dart',
        'src/a.dart',
        'a.dart',
        'dart:io',
        'b.dart',
        'dart:ffi',
        'dart:isolate',
        'p.dart',
        'l.dart',
      ],
    );
  });

  test('allowedUri admits the SDK but four libraries, meta, this package '
      'and lib/, and nothing else', () {
    bool allowed(String uri) => allowedUri(
      uri,
      path: '/w/lib/src/topology/topology.dart',
      lib: '/w/lib',
    );
    expect(allowed('dart:async'), isTrue);
    expect(allowed('dart:io'), isFalse);
    expect(allowed('dart:isolate'), isFalse);
    expect(allowed('dart:ffi'), isFalse);
    expect(allowed('dart:html'), isFalse);
    expect(allowed(r'dart:\x69o'), isFalse);
    expect(allowed('package:meta/meta.dart'), isTrue);
    expect(allowed('package:nidana_dart_contracts/topology_plan.dart'), isTrue);
    expect(allowed('package:collection/collection.dart'), isFalse);
    expect(allowed('builder.dart'), isTrue);
    expect(allowed('../topic/topic.dart'), isTrue);
    expect(allowed('../../topology_plan.dart'), isTrue);
    expect(allowed('../../../test/purity_test.dart'), isFalse);
    expect(allowed('../../../lib_other/a.dart'), isFalse);
    expect(allowed('file:///w/lib/src/topic/topic.dart'), isFalse);
  });

  test('the effects scan finds every listed token, in a comment too', () {
    expect(effectsIn('const int answer = 42;\n'), isEmpty);
    expect(
      effectsIn('final Timer t = Timer.periodic(d, f);\n// DateTime.now( \n'),
      <String>['DateTime.now(', 'Timer.periodic('],
    );
    expect(effectsIn(effects.join('\n')), effects);
  });

  test('the pubspec reader sees every key of a section', () {
    expect(
      sectionKeys(
        'name: x\ndependencies:\n  meta: ^1.19.0\n\n  # a comment\n'
            '  flutter:\n    sdk: flutter\ndev_dependencies:\n  test: any\n',
        'dependencies',
      ),
      <String>{'meta', 'flutter'},
    );
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_dart_contracts/test/purity_test.dart; echo "exit: $?"`
Expected: `exit: 1`; the file does not compile against the old readers: `Error: No named parameter with the name 'path'.` (twice) and `Error: Method not found: 'effectsIn'.` (four times), then `Some tests failed.` (T1.2).

- [ ] **Step 3: Replace the readers**

In `purity_test.dart`, replace `directiveUris` and `allowedUri`, each with its dartdoc, by:

```dart
/// A string literal, raw or not, in single or double quotes: its body is
/// group 1 or group 2.
final RegExp stringLiteral = RegExp(r'''r?'([^'\n]*)'|r?"([^"\n]*)"''');

/// Adjacent string literals, which Dart reads as one string.
final RegExp adjacentLiterals = RegExp(
  r'''(?:r?'[^'\n]*'|r?"[^"\n]*")(?:\s*(?:r?'[^'\n]*'|r?"[^"\n]*"))*''',
);

/// The URIs of every import, export and part directive in [source], read
/// from the directive's keyword to its `;`: every URI of a conditional
/// import, each run of adjacent literals joined into one.
List<String> directiveUris(String source) => <String>[
  for (final Match directive in RegExp(
    r'^\s*(?:import|export|part)\b[^;]*;',
    multiLine: true,
  ).allMatches(source))
    for (final Match run in adjacentLiterals.allMatches(directive[0]!))
      stringLiteral
          .allMatches(run[0]!)
          .map((Match literal) => literal[1] ?? literal[2]!)
          .join(),
];

/// Whether the library at [path], in a package whose libraries are under
/// [lib], may name [uri] (G25, G26): a `dart:` library other than dart:io,
/// dart:isolate, dart:ffi and dart:html, `package:meta`, this package, or a
/// relative URI that resolves inside [lib]. A URI with a backslash is never
/// allowed, because an escape can spell any URI.
bool allowedUri(String uri, {required String path, required String lib}) {
  if (uri.contains(r'\')) {
    return false;
  }
  if (uri.startsWith('dart:')) {
    return !<String>{
      'dart:io',
      'dart:isolate',
      'dart:ffi',
      'dart:html',
    }.contains(uri);
  }
  if (uri.startsWith('package:')) {
    return uri.startsWith('package:meta/') ||
        uri.startsWith('package:nidana_dart_contracts/');
  }
  if (RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(uri)) {
    return false;
  }
  return Uri.file(path).resolve(uri).toFilePath().startsWith('$lib/');
}
```

and add, after the `effects` list:

```dart
/// The tokens of [effects] that [source] contains, in the list's order.
List<String> effectsIn(String source) => <String>[
  for (final String effect in effects)
    if (source.contains(effect)) effect,
];
```

`sectionKeys`, `libraries()`, `effects` and the file comment stay as they are.

- [ ] **Step 4: Run the tests, the analyzer and the formatter**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted ... (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+14: All tests passed!` (7 in `declarations_test.dart`, 7 in `purity_test.dart`; T1.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
The dry run seeded eight violations into the package's libraries (a conditional `dart:io`, a raw string, adjacent literals, an escape, an `export` and a `part` climbing out of `lib/`, a `file:` URI, `Zone.` in a comment) and the test failed on each, naming the library and the URI (T1.5); you need not repeat that.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/test/src/package_files.dart packages/nidana_dart_contracts/test/purity_test.dart
git commit -m "test(dart_contracts): harden the purity test's directive reader" -m "<the co-author trailer your harness gives>"
```

### Task 2: The IR values and function references

You are adding topology-ir@v1's declarations under The IR and Function references to `packages/nidana_dart_contracts`, whose main library `lib/nidana_dart_contracts.dart` already exports topic-model@v1's 25 names through `show` lists. Run every command from the repository root with `fvm dart`. This phase does not produce topology-ir@v1 (its first producing phase is nidana.model.5, which adds `lib/topology_ir.dart` and edits no file this phase writes), but topology-dsl@v2's `buildDefinition()` returns `TopologyDefinition`, whose factory and `transforms` name `TransformEdge`, which names `EdgeInput`, `CombinatorKind` and `FunctionRef` (nidana.model D1 item 2), so they land here, under `lib/src/ir/`, one library per Interface section. Land the declarations below exactly; their dartdoc is copied from `hsdd/contract/topology-ir.md` lines 56 to 205. Fields hold their arguments; `StageInput` asserts its index; every other body throws `UnimplementedError`; declare no `==`, `hashCode` or `toString`. `EdgeInput` declares `const EdgeInput._()`, because an implicit default constructor is not const and the const `TopicInput` and `StageInput` must call a const super constructor (P). The prose above the Interface makes every IR value `@immutable`; the sealed base `EdgeInput` carries the annotation for its two subclasses, as `MessageSource` does.

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/ir/definition.dart`
- Create: `packages/nidana_dart_contracts/lib/src/ir/function_ref.dart`
- Modify: `packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart` (two `export` directives)
- Test: `packages/nidana_dart_contracts/test/ir_declarations_test.dart`

**Interfaces:**
- Consumes: `TopicRef`, `TopicVariant` and `Dedup` from `lib/src/topic/topic.dart` and `Scope` from `lib/src/topic/scope.dart` (nidana.model.3).
- Produces (Task 3 imports `../ir/definition.dart` for `TopologyDefinition`): in `definition.dart`, `enum CombinatorKind` (18 values), `sealed class EdgeInput` with `const EdgeInput._()`, `final class TopicInput` (`final TopicRef topic`, `final Dedup? dedup`), `final class StageInput` (`final int edge`), `final class TransformEdge` (three factories, six final fields, `isSink`, `isStateBearing`), `final class TopologyDefinition` (an unnamed factory with `topologyId`, `scope`, `transforms`, and five final fields); in `function_ref.dart`, `final class FunctionRef` (`FunctionRef.named`, `const FunctionRef.anonymous()`, `factory FunctionRef.of`, `final String? name`).

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/ir_declarations_test.dart`:

```dart
// What the declarations of topology-ir@v1's The IR and Function references
// fix before any body computes (nidana.model D3): the combinator order, the
// arguments the inputs and references keep, and the edge index assertion.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

const TopicRef taps = TopicRef(
  name: 'demo.taps',
  variant: TopicVariant.event,
  typeName: 'int',
);

void main() {
  test('CombinatorKind has eighteen values, in combinator-table order', () {
    expect(CombinatorKind.values.map((CombinatorKind k) => k.name), <String>[
      'map',
      'filter',
      'combine',
      'withLatestFrom',
      'merge',
      'switchMap',
      'scan',
      'pairwise',
      'distinctUntilChanged',
      'debounce',
      'throttle',
      'delay',
      'sample',
      'buffer',
      'timeout',
      'catchError',
      'rawEngine',
      'reduceInto',
    ]);
  });

  test('a TopicInput keeps its topic, and its dedup, null by default', () {
    const TopicInput kept = TopicInput(taps);
    const TopicInput overridden = TopicInput(taps, dedup: Dedup.none);
    expect(kept.topic, same(taps));
    expect(kept.dedup, isNull);
    expect(overridden.dedup, Dedup.none);
  });

  test('a StageInput keeps its index; a negative one fails an assertion', () {
    expect(const StageInput(0).edge, 0);
    expect(const StageInput(3).edge, 3);
    int index = -1;
    expect(() => StageInput(index), throwsA(isA<AssertionError>()));
    index = -7;
    expect(() => StageInput(index), throwsA(isA<AssertionError>()));
  });

  test('FunctionRef.named keeps its name, and an anonymous one has none', () {
    expect(FunctionRef.named('buildTotal').name, 'buildTotal');
    expect(const FunctionRef.anonymous().name, isNull);
  });
}
```

- [ ] **Step 2: Run it and the replays, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/ir_declarations_test.dart; echo "exit: $?"`
Expected: `exit: 1`; the file does not compile: `Error: Undefined name 'CombinatorKind'.`, `Error: 'TopicInput' isn't a type.`, `Error: Couldn't find constructor 'StageInput'.`, `Error: Undefined name 'FunctionRef'.` and like lines, then `Some tests failed.` (T2.2).
Run: `fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 1` and `57 fixtures: 46 passed, 11 failed, 0 pending`: every topic-model@v1 fixture and every structure line passes, and all 2 surface and 9 reject libraries of topology-dsl@v2 FAIL, on `uri_does_not_exist` for `package:nidana_dart_contracts/topology_plan.dart` or on the names this phase declares (`undefined_class`, `non_type_as_type_argument` and the like), never PENDING (S1).
Run: `fvm dart run nidana_contract_check topology-dsl topology-ir --set surface,reject; echo "exit: $?"`
Expected: `exit: 1` and `41 fixtures: 25 passed, 16 failed, 0 pending`, the RED baseline the run routed to this phase (S1).

- [ ] **Step 3: Implement `lib/src/ir/definition.dart` and `lib/src/ir/function_ref.dart`, and export them**

`packages/nidana_dart_contracts/lib/src/ir/definition.dart`:

```dart
import 'package:meta/meta.dart';

import '../topic/scope.dart';
import '../topic/topic.dart';
import 'function_ref.dart';

/// The combinator of an edge (Spec §6.5, Appendix A.4): one value per stage
/// class of topology-dsl@v2 other than ReadStage, and one for reduceInto, in
/// topology-dsl@v2's combinator-table order.
enum CombinatorKind {
  map,
  filter,
  combine,
  withLatestFrom,
  merge,
  switchMap,
  scan,
  pairwise,
  distinctUntilChanged,
  debounce,
  throttle,
  delay,
  sample,
  buffer,
  timeout,
  catchError,
  rawEngine,
  reduceInto,
}

/// What an edge consumes (Spec §6.5 `inputs`). Sealed.
@immutable
sealed class EdgeInput {
  const EdgeInput._();
}

/// The values one read of [topic] delivers: a ReadStage of the plan. [dedup]
/// is the read's argument, null when the read kept the topic's own policy
/// (topology-dsl@v2 G13).
final class TopicInput extends EdgeInput {
  const TopicInput(this.topic, {this.dedup}) : super._();

  final TopicRef topic;
  final Dedup? dedup;
}

/// The values the stage edge at index [edge] of the same definition's
/// transforms emits. [edge] is asserted non-negative.
final class StageInput extends EdgeInput {
  const StageInput(this.edge)
    : assert(edge >= 0, 'edge must not be negative'),
      super._();

  final int edge;
}

/// One element of a topology's wiring other than a read (Spec §6.5): a stage
/// edge, whose values only later edges consume, or a sink edge, whose values
/// are published to [output]. No public unnamed constructor.
@immutable
final class TransformEdge {
  // The three factories construct through this once nidana.model.10 lands
  // them.
  // ignore: unused_element
  const TransformEdge._({
    required this.combinator,
    required this.inputs,
    required this.output,
    required this.transformer,
    required this.duration,
    required this.retry,
  });

  /// A non-read stage. Throws ArgumentError when [combinator] is reduceInto,
  /// or when the inputs, transformer, duration or retry do not fit the
  /// combinator (the table below), or for a negative [duration].
  factory TransformEdge.stage(
    CombinatorKind combinator,
    List<EdgeInput> inputs, {
    FunctionRef? transformer,
    Duration? duration,
    FunctionRef? retry,
  }) => throw UnimplementedError();

  /// A write: [input]'s values published to [topic] unchanged.
  factory TransformEdge.write(TopicRef topic, EdgeInput input) =>
      throw UnimplementedError();

  /// A reduceInto folding [events] into [topic] with [reducer]. Throws
  /// ArgumentError unless [topic] is a state topic.
  factory TransformEdge.reduceInto(
    TopicRef topic,
    EdgeInput events,
    FunctionRef reducer,
  ) => throw UnimplementedError();

  final CombinatorKind? combinator; // null exactly for a write
  final List<EdgeInput> inputs; // unmodifiable copy, in input order
  final TopicRef? output; // a sink's topic; null for a stage
  final FunctionRef? transformer; // the edge's function, when it holds one
  final Duration? duration; // the six time stages only
  final FunctionRef? retry; // a switchMap with a retry policy only
  bool get isSink => throw UnimplementedError(); // output != null
  bool get isStateBearing =>
      throw UnimplementedError(); // Spec §3.8; the rule below
}

/// The IR of one topology (Spec §6.5, Appendix A.4).
@immutable
final class TopologyDefinition {
  // The factory constructs through this once nidana.model.10 lands it.
  // ignore: unused_element
  const TopologyDefinition._({
    required this.topologyId,
    required this.scope,
    required this.reads,
    required this.writes,
    required this.transforms,
  });

  /// Throws ArgumentError for an empty [topologyId] or ill-formed
  /// [transforms] (the rules below).
  factory TopologyDefinition({
    required String topologyId,
    required Scope scope,
    required List<TransformEdge> transforms,
  }) => throw UnimplementedError();

  final String topologyId;
  final Scope scope;
  // the topics of every TopicInput; canonical order; unmodifiable
  final Set<TopicRef> reads;
  // the outputs of the sink edges; canonical order; unmodifiable
  final Set<TopicRef> writes;
  final List<TransformEdge> transforms; // unmodifiable copy
}
```

`packages/nidana_dart_contracts/lib/src/ir/function_ref.dart`:

```dart
import 'package:meta/meta.dart';

/// A serializable reference to a transformer (Spec §6.5, Appendix A.4): a
/// name, or anonymous. It holds no function and is not a Function.
@immutable
final class FunctionRef {
  /// Throws ArgumentError for an empty [name].
  FunctionRef.named(String this.name);
  const FunctionRef.anonymous() : name = null;

  /// The name the Dart VM renders for [function] (decides OQ-M1): the text
  /// between `from Function '` and the next `'` in function.toString(),
  /// anonymous when that text is absent or empty. Never calls [function].
  factory FunctionRef.of(Function function) => throw UnimplementedError();

  final String? name; // null when anonymous
}
```

In `packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart`, add these directives after `library;` and its blank line, before `export 'src/topic/envelope.dart'` (export directives stay in URI order):

```dart
export 'src/ir/definition.dart'
    show
        CombinatorKind,
        EdgeInput,
        StageInput,
        TopicInput,
        TopologyDefinition,
        TransformEdge;
export 'src/ir/function_ref.dart' show FunctionRef;
```

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the replays**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted ... (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+18: All tests passed!` (T2.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 1` and still `57 fixtures: 46 passed, 11 failed, 0 pending`: the topology-dsl@v2 fixtures need Tasks 3 and 4 (T2.4). That is this task's end state, not a gap.
Run: `fvm dart run nidana_contract_check topology-ir --set surface,reject; echo "exit: $?"` (outside the gate, which does not replay topology-ir@v1)
Expected: `exit: 1`, `14 fixtures: 10 passed, 4 failed, 0 pending`, with `PASS reject hsdd/contract/fixture/topology-ir/reject/ir_holds_no_function.dart`, the one topology-ir@v1 fixture that needs nothing but these declarations (T2.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/ir/definition.dart packages/nidana_dart_contracts/lib/src/ir/function_ref.dart packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart packages/nidana_dart_contracts/test/ir_declarations_test.dart
git commit -m "feat(dart_contracts): declare the IR values and function references" -m "<the co-author trailer your harness gives>"
```

### Task 3: Topologies, the builder and the handle

You are adding topology-dsl@v2's main-library declarations (Topologies, The builder, The handle, Pipeline values) to `packages/nidana_dart_contracts`, whose `lib/src/ir/definition.dart` declares `TopologyDefinition` and whose main library exports topic-model@v1's and the IR's names. Run every command from the repository root with `fvm dart`. The DSL is one library, `lib/src/topology/topology.dart`, with part files (nidana.model D4), because Task 4's stage and sink classes must share the library of the sealed `TopicStream` and `PlanSink`; this task creates the library with two parts, `builder.dart` and `handle.dart`, and Task 4 adds three. A part file starts with `part of 'topology.dart';` and has no imports of its own: the library's imports serve every part. Land the declarations below exactly; their dartdoc is copied from the derivative's topology-dsl@v2 Interface. `TopologyBuilder` and `TopicStream` have one private constructor each, so neither has a public one (G2); every method and `topology()` throw `UnimplementedError`, and `buildDefinition()` is `@nonVirtual` and throws. Declare no `==`, `hashCode` or `toString`, `TopologyRef`'s included. The fixtures this task serves: `surface/topologies.dart` and eight of the nine reject libraries under `hsdd/contract/fixture/topology-dsl/` (every one but `dsl_types_are_closed.dart`, which imports `topology_plan.dart`).

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/topology/topology.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topology/builder.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topology/handle.dart`
- Modify: `packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart` (one `export` directive)
- Test: `packages/nidana_dart_contracts/test/topology_declarations_test.dart`

**Interfaces:**
- Consumes (Task 2, nidana.model.3): `TopologyDefinition` from `lib/src/ir/definition.dart`; `Lineage` from `lib/src/topic/lineage.dart`; `Scope` from `lib/src/topic/scope.dart`; `Topic`, `StateTopic` and `Dedup` from `lib/src/topic/topic.dart`.
- Produces (Task 4 relies on these): the library `lib/src/topology/topology.dart` with its imports (`package:meta/meta.dart`, `../ir/definition.dart`, `../topic/lineage.dart`, `../topic/scope.dart`, `../topic/topic.dart`) and the directives `part 'builder.dart';` and `part 'handle.dart';`; `sealed class TopicStream<T>` with the private generative constructor `TopicStream._()`, which every stage class calls as `super._()`; `TopologyBuilder` with `TopologyBuilder._()`; `abstract base class Topology`; `typedef RetryPolicy` and `typedef RawOperator<T, R>`, which the stage classes name.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/topology_declarations_test.dart`:

```dart
// What the declarations of topology-dsl@v2's main library fix before any
// body computes (nidana.model D3): a topology in class form is inert data,
// and a topology reference keeps its id.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

final class Unrecorded extends Topology {
  const Unrecorded();

  @override
  String get topologyId => 'unrecorded';

  @override
  Scope get scope => Scope.page;

  @override
  void declare(TopologyBuilder b) =>
      throw StateError('declare ran outside planOf');
}

void main() {
  test('G9 constructing a topology in class form never runs declare', () {
    late final Topology declared;
    expect(() => declared = Unrecorded(), returnsNormally);
    expect(declared.topologyId, 'unrecorded');
    expect(declared.scope, Scope.page);
  });

  test('G7 a TopologyRef keeps the id it is given', () {
    expect(const TopologyRef('checkout-flow').id, 'checkout-flow');
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_dart_contracts/test/topology_declarations_test.dart; echo "exit: $?"`
Expected: `exit: 1`; the file does not compile: `Error: Type 'Topology' not found.`, `Error: 'TopologyBuilder' isn't a type.`, `Error: Couldn't find constructor 'TopologyRef'.` and like lines, then `Some tests failed.` (T3.2). The gate's replay still prints `57 fixtures: 46 passed, 11 failed, 0 pending`.

- [ ] **Step 3: Implement the DSL library with its builder and handle parts, and export it**

`packages/nidana_dart_contracts/lib/src/topology/topology.dart`:

```dart
import 'package:meta/meta.dart';

import '../ir/definition.dart';
import '../topic/lineage.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

part 'builder.dart';
part 'handle.dart';

/// A topology in class form (Spec §6.1, Guide §6.3). Applications extend it;
/// a subclass is final, base or sealed. Annotated @immutable: a topology is
/// inert data (Spec §2.2).
@immutable
abstract base class Topology {
  const Topology();

  /// Module-local (Spec §4.6); non-empty.
  String get topologyId;

  /// Declared explicitly (Spec §7.2).
  Scope get scope;

  /// Pure wiring (Spec §6.1): builder and handle calls only. Runs once per
  /// planOf call, never at construction.
  void declare(TopologyBuilder b);

  /// The IR (Spec §6.5): planOf(this).definition.
  @nonVirtual
  TopologyDefinition buildDefinition() => throw UnimplementedError();
}

/// The builder shorthand (Spec §6.1). Throws ArgumentError for an empty
/// [topologyId]; [declare] runs on each planOf call.
Topology topology(
  String topologyId,
  Scope scope,
  void Function(TopologyBuilder b) declare,
) => throw UnimplementedError();

/// A typed, module-local topology identifier (Spec §4.6). Equal by id.
@immutable
final class TopologyRef {
  const TopologyRef(this.id);

  final String id;
}

/// A value inside a live pipeline (Spec §3.5): its payload and the lineage
/// its next published envelope will carry (topic-model@v1 Lineage).
typedef PipelineValue<T> = ({T payload, Lineage lineage});

/// switchMap's retry: the delay before toStream(value) is called again after
/// the inner stream's [attempt]-th error for the current outer value
/// (1-based), or null to let the error through.
typedef RetryPolicy = Duration? Function(Object error, int attempt);

/// The raw operator: given the stage input's values, and a source of fresh
/// correlation ids for Lineage.combine, it returns the stage's values. The
/// author applies the lineage rules (Spec §3.5).
typedef RawOperator<T, R> = Stream<PipelineValue<R>> Function(
  Stream<PipelineValue<T>> values,
  String Function() freshCorrelationId,
);
```

`packages/nidana_dart_contracts/lib/src/topology/builder.dart`:

```dart
part of 'topology.dart';

/// The only builder (Spec §6.5): it records the declaration into a plan.
/// Final, no public constructor; planOf creates one per call.
final class TopologyBuilder {
  TopologyBuilder._();

  /// A read of [topic] (Spec §6.1). [dedup] overrides a StateTopic's own
  /// policy for this read only (Spec §3.12); null keeps it. A non-null
  /// [dedup] on an EventTopic or ReplayTopic read throws ArgumentError.
  TopicStream<T> read<T>(Topic<T> topic, {Dedup? dedup}) =>
      throw UnimplementedError();

  /// Writes every value of [stream] to [topic]: one write chain (Errors and
  /// lineage). The stream's value type is the topic's or a subtype of it (G3).
  void write<T, S extends T>(Topic<T> topic, TopicStream<S> stream) =>
      throw UnimplementedError();

  /// Folds [events] into [topic], which this topology then owns, seeded with
  /// the topic's current value when the activation connects (Spec §6.3,
  /// §7.2): one write chain (Errors and lineage).
  void reduceInto<S, E>(
    StateTopic<S> topic,
    TopicStream<E> events,
    S Function(S state, E event) reducer,
  ) => throw UnimplementedError();

  TopicStream<R> combine2<A, B, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    R Function(A a, B b) combiner,
  ) => throw UnimplementedError();
  TopicStream<R> combine3<A, B, C, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(A a, B b, C c) combiner,
  ) => throw UnimplementedError();
  TopicStream<R> combine4<A, B, C, D, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(A a, B b, C c, D d) combiner,
  ) => throw UnimplementedError();

  /// [combiner] receives an unmodifiable list of the inputs' latest values,
  /// in input order. Throws ArgumentError for an empty [inputs].
  TopicStream<R> combineAll<T, R>(
    List<TopicStream<T>> inputs,
    R Function(List<T> values) combiner,
  ) => throw UnimplementedError();

  /// Throws ArgumentError for an empty [inputs].
  TopicStream<T> merge<T>(List<TopicStream<T>> inputs) =>
      throw UnimplementedError();
}
```

`packages/nidana_dart_contracts/lib/src/topology/handle.dart`:

```dart
part of 'topology.dart';

/// The opaque stream handle (Spec §6.1): a stage of the plan. Sealed; made
/// only by the builder and by its own methods. It has no synchronous value
/// accessor, is not a Stream and has no listen (G1).
sealed class TopicStream<T> {
  TopicStream._();

  TopicStream<R> map<R>(R Function(T value) transform) =>
      throw UnimplementedError();
  TopicStream<T> filter(bool Function(T value) test) =>
      throw UnimplementedError();

  TopicStream<R> withLatestFrom<B, R>(
    TopicStream<B> latest,
    R Function(T value, B latest) combiner,
  ) => throw UnimplementedError();
  TopicStream<R> withLatestFrom2<B, C, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    R Function(T value, B b, C c) combiner,
  ) => throw UnimplementedError();
  TopicStream<R> withLatestFrom3<B, C, D, R>(
    TopicStream<B> b,
    TopicStream<C> c,
    TopicStream<D> d,
    R Function(T value, B b, C c, D d) combiner,
  ) => throw UnimplementedError();

  /// [toStream] is the shell's stream factory (Spec §6.3); [retry] is the
  /// timed retry of its inner stream (ADR-003 item 4).
  TopicStream<R> switchMap<R>(
    Stream<R> Function(T value) toStream, {
    RetryPolicy? retry,
  }) => throw UnimplementedError();

  TopicStream<S> scan<S>(
    S initial,
    S Function(S accumulated, T value) accumulator,
  ) => throw UnimplementedError();
  TopicStream<({T previous, T current})> pairwise() =>
      throw UnimplementedError();
  TopicStream<T> distinctUntilChanged() => throw UnimplementedError();

  /// Time-dependent combinators (Spec §3.6, §6.3) take a Duration and no
  /// scheduler (ADR-003 item 4). A negative duration throws ArgumentError.
  TopicStream<T> debounce(Duration duration) => throw UnimplementedError();
  TopicStream<T> throttle(Duration duration) => throw UnimplementedError();
  TopicStream<T> delay(Duration duration) => throw UnimplementedError();
  TopicStream<T> sample(Duration duration) => throw UnimplementedError();
  TopicStream<List<T>> buffer(Duration duration) => throw UnimplementedError();
  TopicStream<T> timeout(Duration duration) => throw UnimplementedError();

  /// Turns a shell-boundary failure into a value (Spec §6.3, §10.2).
  TopicStream<T> catchError(
    T Function(Object error, StackTrace stackTrace) recover,
  ) => throw UnimplementedError();

  /// The raw-engine escape hatch (Spec §3.5 "Escape Hatch").
  TopicStream<R> rawEngine<R>(RawOperator<T, R> operator) =>
      throw UnimplementedError();
}
```

In `packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart`, add after the last directive, `export 'src/topic/topic.dart' show ...;`. With it the main library's export list is complete: topic-model@v1's 25 names, the IR's 7 and these 8 (Task 4's `exports_test.dart` pins all 40):

```dart
export 'src/topology/topology.dart'
    show
        PipelineValue,
        RawOperator,
        RetryPolicy,
        TopicStream,
        Topology,
        TopologyBuilder,
        TopologyRef,
        topology;
```

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the replays**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted ... (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+20: All tests passed!` (T3.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 1` and `57 fixtures: 55 passed, 2 failed, 0 pending`: `PASS surface .../topology-dsl/surface/topologies.dart` and eight `PASS reject` lines; the two FAILs are `surface/plan.dart` and `reject/dsl_types_are_closed.dart`, each opening with `uri_does_not_exist` for `package:nidana_dart_contracts/topology_plan.dart`, which Task 4 creates (T3.4). Any other FAIL is a stop: see Global Constraints, Contract gaps.
Run: `fvm dart run nidana_contract_check topology-ir --set surface,reject; echo "exit: $?"` (outside the gate)
Expected: `exit: 1` and `14 fixtures: 11 passed, 3 failed, 0 pending`, `surface/definitions.dart` now passing (T3.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topology/topology.dart packages/nidana_dart_contracts/lib/src/topology/builder.dart packages/nidana_dart_contracts/lib/src/topology/handle.dart packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart packages/nidana_dart_contracts/test/topology_declarations_test.dart
git commit -m "feat(dart_contracts): declare topologies, the builder and the handle" -m "<the co-author trailer your harness gives>"
```

### Task 4: The plan library

You are adding topology-dsl@v2's The plan to `packages/nidana_dart_contracts`: three part files of the DSL library `lib/src/topology/topology.dart`, which already declares `Topology`, `TopologyBuilder`, `TopicStream` (with its private constructor `TopicStream._()`), `RetryPolicy` and `RawOperator` and names the parts `builder.dart` and `handle.dart`; and the second public library `lib/topology_plan.dart`, which exports the plan's 27 names and nothing the main library exports (G2). Run every command from the repository root with `fvm dart`. Land the declarations below exactly; their dartdoc is copied from the derivative's topology-dsl@v2 Interface. Every stage and sink class is final and has one private constructor storing its members, so none has a public constructor and nothing outside the library extends one; `planOf`, `TopologyPlan.definition`, `visitStage`, `visitSink` and the two `apply` methods throw `UnimplementedError`; no class declares `==`, `hashCode` or `toString` (G30). The parts take their imports from the library file, which already imports everything they name. The fixtures this task completes: `surface/plan.dart` and `reject/dsl_types_are_closed.dart`.

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/topology/plan.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topology/stages.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topology/sinks.dart`
- Create: `packages/nidana_dart_contracts/lib/topology_plan.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/topology.dart` (three `part` directives)
- Test: `packages/nidana_dart_contracts/test/exports_test.dart`

**Interfaces:**
- Consumes (Task 3): `TopicStream._()`, `TopologyBuilder`, `Topology`, `RetryPolicy`, `RawOperator<T, R>` and the library's imports; (Task 2) `TopologyDefinition`; (Task 1) `packageDirectory()` from `test/src/package_files.dart`.
- Produces: `TopologyPlan planOf(Topology topology)`; `final class TopologyPlan` (`topologyId`, `scope`, `stages`, `sinks` as final fields, `definition` a getter); `V visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor)`; `V visitSink<V>(PlanSink sink, SinkVisitor<V> visitor)`; `StageVisitor<V>` (18 methods) and `SinkVisitor<V>` (2); the eighteen stage classes; `sealed class PlanSink` with `WriteSink<T>` and `ReduceIntoSink<S, E>`; the library `package:nidana_dart_contracts/topology_plan.dart`. nidana.model.9 fills the bodies and calls the private constructors; nidana.model.11 changes the body of `TopologyPlan.definition`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/exports_test.dart`:

```dart
// The two public libraries nidana.model.4 completes export exactly the names
// their contracts place in them (topology-dsl@v2 G2; nidana.model D4), so a
// declaration cannot leak from one library into the other.
import 'dart:io';

import 'package:test/test.dart';

import 'src/package_files.dart';

/// The names the export directives of [source] show, or null when one of
/// them has no show list and so exports everything its library declares.
Set<String>? shownNames(String source) {
  final Set<String> names = <String>{};
  for (final Match export in RegExp(
    r'^export\b[^;]*;',
    multiLine: true,
  ).allMatches(source)) {
    final Match? show = RegExp(r'\bshow\b([^;]*);').firstMatch(export[0]!);
    if (show == null) {
      return null;
    }
    names.addAll(show[1]!.split(',').map((String name) => name.trim()));
  }
  return names;
}

Set<String>? shownBy(String library) => shownNames(
  File('${packageDirectory().path}/lib/$library').readAsStringSync(),
);

void main() {
  test('the main library exports exactly the declarations topic-model@v1, '
      'topology-dsl@v2 and topology-ir@v1 place in it', () {
    expect(shownBy('nidana_dart_contracts.dart'), <String>{
      // topic-model@v1
      'BusObserver', 'Dedup', 'EventTopic', 'ExecutorSource', 'Lineage',
      'LogLevel', 'MessageEnvelope', 'MessageSource', 'MultiWriterTopic',
      'ObserveContext', 'ObserverCapability', 'PageSource',
      'RedactedPayload', 'ReplayTopic', 'Scope', 'ServiceSource',
      'SpanHandle', 'StateTopic', 'Topic', 'TopicRef', 'TopicVariant',
      'TopologySource', 'Tracing', 'UnknownSource', 'isWellFormedTopicName',
      // topology-dsl@v2: Topologies, The builder, The handle, Pipeline values
      'PipelineValue', 'RawOperator', 'RetryPolicy', 'TopicStream',
      'Topology', 'TopologyBuilder', 'TopologyRef', 'topology',
      // topology-ir@v1: The IR, Function references
      'CombinatorKind', 'EdgeInput', 'FunctionRef', 'StageInput',
      'TopicInput', 'TopologyDefinition', 'TransformEdge',
    });
  });

  test('G2 topology_plan.dart exports exactly the declarations under '
      "topology-dsl@v2's The plan", () {
    expect(shownBy('topology_plan.dart'), <String>{
      'planOf',
      'TopologyPlan',
      'visitStage',
      'visitSink',
      'StageVisitor',
      'SinkVisitor',
      'PlanSink',
      'WriteSink',
      'ReduceIntoSink',
      'ReadStage',
      'MapStage',
      'FilterStage',
      'CombineStage',
      'WithLatestFromStage',
      'MergeStage',
      'SwitchMapStage',
      'ScanStage',
      'PairwiseStage',
      'DistinctUntilChangedStage',
      'DebounceStage',
      'ThrottleStage',
      'DelayStage',
      'SampleStage',
      'BufferStage',
      'TimeoutStage',
      'CatchErrorStage',
      'RawEngineStage',
    });
  });

  test('the export reader sees show lists and exports without one', () {
    expect(
      shownNames(
        "library;\n\nexport 'a.dart' show A, b;\nexport 'c.dart'\n"
        '    show\n        C,\n        D;\n',
      ),
      <String>{'A', 'b', 'C', 'D'},
    );
    expect(shownNames("export 'a.dart' show A;\nexport 'b.dart';\n"), isNull);
    expect(shownNames("export 'a.dart' hide A;\n"), isNull);
  });
}
```

- [ ] **Step 2: Run it and the replay, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/exports_test.dart; echo "exit: $?"`
Expected: `exit: 1`, `+2 -1: Some tests failed.`: the `topology_plan.dart` test fails with `PathNotFoundException: Cannot open file, path = '.../packages/nidana_dart_contracts/lib/topology_plan.dart'`; the main-library test passes, because Task 3 completed that list, and so does the reader's self-test (T4.2).
Run: `fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 1` and `57 fixtures: 55 passed, 2 failed, 0 pending`, as Task 3 left it.

- [ ] **Step 3: Implement the three parts and `lib/topology_plan.dart`**

In `packages/nidana_dart_contracts/lib/src/topology/topology.dart`, the part directives become, in this order:

```dart
part 'builder.dart';
part 'handle.dart';
part 'plan.dart';
part 'sinks.dart';
part 'stages.dart';
```

`packages/nidana_dart_contracts/lib/src/topology/plan.dart`:

```dart
part of 'topology.dart';

/// Runs topology.declare once against a fresh builder and returns its plan.
/// Throws StateError when topologyId is empty or a stage reaches no sink;
/// an error declare throws, a builder's ArgumentError included, propagates.
TopologyPlan planOf(Topology topology) => throw UnimplementedError();

/// The executable form of one declaration (Spec §6.5).
@immutable
final class TopologyPlan {
  TopologyPlan._(this.topologyId, this.scope, this.stages, this.sinks);

  final String topologyId;
  final Scope scope;

  /// Every stage, in the order the declaration created them; unmodifiable.
  /// A stage's inputs precede it.
  final List<TopicStream<Object?>> stages;

  /// Every write and reduceInto, in declaration order; unmodifiable.
  final List<PlanSink> sinks;

  /// The IR projected from this plan (topology-ir@v1); equal to
  /// topology.buildDefinition() for a deterministic declaration.
  TopologyDefinition get definition => throw UnimplementedError();
}

/// Passes [stage] to the visitor method of its class, binding the stage's
/// type arguments; likewise visitSink.
V visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor) =>
    throw UnimplementedError();
V visitSink<V>(PlanSink sink, SinkVisitor<V> visitor) =>
    throw UnimplementedError();

/// Implemented by a live implementation's interpreter, and by any reader
/// that needs a stage's type arguments.
abstract interface class StageVisitor<V> {
  V read<T>(ReadStage<T> stage);
  V map<T, R>(MapStage<T, R> stage);
  V filter<T>(FilterStage<T> stage);
  V combine<R>(CombineStage<R> stage);
  V withLatestFrom<T, R>(WithLatestFromStage<T, R> stage);
  V merge<T>(MergeStage<T> stage);
  V switchMap<T, R>(SwitchMapStage<T, R> stage);
  V scan<T, S>(ScanStage<T, S> stage);
  V pairwise<T>(PairwiseStage<T> stage);
  V distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage);
  V debounce<T>(DebounceStage<T> stage);
  V throttle<T>(ThrottleStage<T> stage);
  V delay<T>(DelayStage<T> stage);
  V sample<T>(SampleStage<T> stage);
  V buffer<T>(BufferStage<T> stage);
  V timeout<T>(TimeoutStage<T> stage);
  V catchError<T>(CatchErrorStage<T> stage);
  V rawEngine<T, R>(RawEngineStage<T, R> stage);
}

abstract interface class SinkVisitor<V> {
  V write<T>(WriteSink<T> sink);
  V reduceInto<S, E>(ReduceIntoSink<S, E> sink);
}
```

`packages/nidana_dart_contracts/lib/src/topology/stages.dart`:

```dart
part of 'topology.dart';

// The stage classes: each final, extending TopicStream, no public
// constructor. Every member holds the value the declaration passed,
// identical to it (G11).

final class ReadStage<T> extends TopicStream<T> {
  ReadStage._(this.topic, this.dedup) : super._();

  final Topic<T> topic;
  final Dedup? dedup; // as given; null keeps the topic's
}

final class MapStage<T, R> extends TopicStream<R> {
  MapStage._(this.input, this.transform) : super._();

  final TopicStream<T> input;
  final R Function(T value) transform;
}

final class FilterStage<T> extends TopicStream<T> {
  FilterStage._(this.input, this.test) : super._();

  final TopicStream<T> input;
  final bool Function(T value) test;
}

/// combine2, combine3, combine4 and combineAll.
final class CombineStage<R> extends TopicStream<R> {
  CombineStage._(this.inputs, this.combiner) : super._();

  final List<TopicStream<Object?>> inputs; // unmodifiable, in input order
  final Function combiner; // the function the declaration passed

  /// Calls combiner with [values], the inputs' latest payloads in input order.
  R apply(List<Object?> values) => throw UnimplementedError();
}

/// withLatestFrom, withLatestFrom2 and withLatestFrom3.
final class WithLatestFromStage<T, R> extends TopicStream<R> {
  WithLatestFromStage._(this.primary, this.latest, this.combiner) : super._();

  final TopicStream<T> primary;
  final List<TopicStream<Object?>> latest; // unmodifiable, in argument order
  final Function combiner;
  R apply(T value, List<Object?> latest) => throw UnimplementedError();
}

final class MergeStage<T> extends TopicStream<T> {
  MergeStage._(this.inputs) : super._();

  final List<TopicStream<T>> inputs; // unmodifiable
}

final class SwitchMapStage<T, R> extends TopicStream<R> {
  SwitchMapStage._(this.input, this.toStream, this.retry) : super._();

  final TopicStream<T> input;
  final Stream<R> Function(T value) toStream;
  final RetryPolicy? retry;
}

final class ScanStage<T, S> extends TopicStream<S> {
  ScanStage._(this.input, this.initial, this.accumulator) : super._();

  final TopicStream<T> input;
  final S initial;
  final S Function(S accumulated, T value) accumulator;
}

final class PairwiseStage<T> extends TopicStream<({T previous, T current})> {
  PairwiseStage._(this.input) : super._();

  final TopicStream<T> input;
}

final class DistinctUntilChangedStage<T> extends TopicStream<T> {
  DistinctUntilChangedStage._(this.input) : super._();

  final TopicStream<T> input;
}

final class DebounceStage<T> extends TopicStream<T> {
  DebounceStage._(this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class ThrottleStage<T> extends TopicStream<T> {
  ThrottleStage._(this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class DelayStage<T> extends TopicStream<T> {
  DelayStage._(this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class SampleStage<T> extends TopicStream<T> {
  SampleStage._(this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class BufferStage<T> extends TopicStream<List<T>> {
  BufferStage._(this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class TimeoutStage<T> extends TopicStream<T> {
  TimeoutStage._(this.input, this.duration) : super._();

  final TopicStream<T> input;
  final Duration duration;
}

final class CatchErrorStage<T> extends TopicStream<T> {
  CatchErrorStage._(this.input, this.recover) : super._();

  final TopicStream<T> input;
  final T Function(Object error, StackTrace stackTrace) recover;
}

final class RawEngineStage<T, R> extends TopicStream<R> {
  RawEngineStage._(this.input, this.operator) : super._();

  final TopicStream<T> input;
  final RawOperator<T, R> operator;
}
```

`packages/nidana_dart_contracts/lib/src/topology/sinks.dart` (a sink's `topic` field overrides `PlanSink.topic`, so it carries `@override`, which the root lint set's `annotate_overrides` requires):

```dart
part of 'topology.dart';

/// A write or a reduceInto. Sealed; no public constructor.
sealed class PlanSink {
  PlanSink._();

  Topic<Object?> get topic;
}

final class WriteSink<T> extends PlanSink {
  WriteSink._(this.topic, this.input) : super._();

  @override
  final Topic<T> topic;
  final TopicStream<T> input;
}

final class ReduceIntoSink<S, E> extends PlanSink {
  ReduceIntoSink._(this.topic, this.events, this.reducer) : super._();

  @override
  final StateTopic<S> topic;
  final TopicStream<E> events;
  final S Function(S state, E event) reducer;
}
```

`packages/nidana_dart_contracts/lib/topology_plan.dart` (the comment needs `library;`, or the root lint set reports it as dangling):

```dart
/// The plan a topology declaration records, which live activation
/// interprets.
library;

export 'src/topology/topology.dart'
    show
        BufferStage,
        CatchErrorStage,
        CombineStage,
        DebounceStage,
        DelayStage,
        DistinctUntilChangedStage,
        FilterStage,
        MapStage,
        MergeStage,
        PairwiseStage,
        PlanSink,
        RawEngineStage,
        ReadStage,
        ReduceIntoSink,
        SampleStage,
        ScanStage,
        SinkVisitor,
        StageVisitor,
        SwitchMapStage,
        ThrottleStage,
        TimeoutStage,
        TopologyPlan,
        WithLatestFromStage,
        WriteSink,
        planOf,
        visitSink,
        visitStage;
```

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the replay**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted ... (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+23: All tests passed!` (T4.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 0`; 33 `PASS structure`, 5 `PASS surface` and 19 `PASS reject` lines, then `57 fixtures: 57 passed, 0 failed, 0 pending` (T4.4). A FAIL is a stop: see Global Constraints, Contract gaps.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topology/topology.dart packages/nidana_dart_contracts/lib/src/topology/plan.dart packages/nidana_dart_contracts/lib/src/topology/stages.dart packages/nidana_dart_contracts/lib/src/topology/sinks.dart packages/nidana_dart_contracts/lib/topology_plan.dart packages/nidana_dart_contracts/test/exports_test.dart
git commit -m "feat(dart_contracts): declare the plan library" -m "<the co-author trailer your harness gives>"
```

### Task 5: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.4.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.4.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 4; the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl --set structure,surface,reject) > "${TMPDIR:-/tmp}/nidana.model.4-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after.
Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+23: All tests passed!` and `57 fixtures: 57 passed, 0 failed, 0 pending` (G). A failure stops here: it is fixed in the task that owns the code, never by editing `hsdd/`; a fixture that fails against a declaration matching its block is a contract gap (Global Constraints).

- [ ] **Step 2: Run the checklist**

Run each and keep its output:
- `grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?"` (expected: no line, `exit: 1`): no code outside the package reaches a declaration except through the two public libraries.
- `grep -rnE "operator ==|hashCode" packages/nidana_dart_contracts/lib/src/topology packages/nidana_dart_contracts/lib/src/ir; echo "exit: $?"` (expected: no line, `exit: 1`): no stage, sink, builder or plan overrides `==` or `hashCode` (G30), and no IR value before nidana.model.10.
- `fvm dart run nidana_contract_check topology-ir --set surface,reject; echo "exit: $?"`, outside the gate (expected: `exit: 1`, `14 fixtures: 11 passed, 3 failed, 0 pending`; `PASS surface .../topology-ir/surface/definitions.dart` and `PASS reject .../topology-ir/reject/ir_holds_no_function.dart`, the two that use the main library alone; FAIL for `surface/graphs.dart`, `reject/ir_families_are_closed.dart` and `reject/ir_values_are_immutable.dart`, each opening with `uri_does_not_exist` for `package:nidana_dart_contracts/topology_ir.dart`, then the undefined names that follow from it; G2).
- `fvm dart run nidana_contract_check topology-dsl topology-ir --set surface,reject; echo "exit: $?"`, the routed RED baseline command (expected: `exit: 1`, `41 fixtures: 38 passed, 3 failed, 0 pending`, the three failures those above; G2).
- `git status --short pubspec.lock` (expected: no output).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.4.verification.md` at gate-only depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.4 - topology-dsl@v2 declarations` (a spaced hyphen; no em-dash anywhere in the file). Slim: every section a few lines.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as the phase context writes it, which replays topic-model@v1's and topology-dsl@v2's `structure`, `surface` and `reject` sets (no `schema` set: neither contract has a serialized form, so neither carries a schema, ADR-001 item 4); the checklist commands of Step 2.
- **Expected output:** the gate's exit 0 and the five lines of Step 1; the checklist's expected results of Step 2.
- **Observed:** dated, with the gate's start and end times, the branch and commit, and Dart 3.13.5 through `fvm`; the gate's exit code and its five lines as they appeared; then a checklist of four `- [x]` lines, each with its result:
  - the first replay of topology-dsl@v2's 2 surface and 9 reject libraries against the real package passed: every reject code the stand-ins confirmed holds, none differs, and no line carries two codes, since a reject library passes only when its reported (line, code) pairs equal its one-code markers;
  - code that imports the main library alone cannot name a stage or obtain a plan (`plan_is_a_separate_library.dart` passes), `Topology` can be extended and not implemented and a mutable field in a subclass is reported (`topology_is_a_base_class.dart` passes), the two public libraries export exactly the names their contracts place in them (`exports_test.dart` passes: the main library 40, `topology_plan.dart` 27), and no code outside the package imports its `src/`;
  - topology-ir@v1's surface and reject sets, run outside the gate, pass `surface/definitions.dart` and `reject/ir_holds_no_function.dart` and fail only the three that import `topology_ir.dart`, which nidana.model.5 lands, on `uri_does_not_exist` and the undefined names that follow; the routed RED baseline command went from `41 fixtures: 25 passed, 16 failed, 0 pending` to `41 fixtures: 38 passed, 3 failed, 0 pending`;
  - no stage, sink, builder or plan overrides `==` or `hashCode` (G30); `purity_test.dart`, its directive reader hardened, holds the package to `meta` and `test` and to no clock, timer, microtask, id or I/O (G25, G26); the lockfile is unchanged.
- **Outstanding:** `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found the four below and the sizing line; write each that still holds, and any the gate finds:
  - `- No topology-dsl@v2 reject line needs two diagnostic codes: all 9 reject libraries pass with one code per marked line, so ADR-001 item 4's one-code marker suffices for this contract. Disposition: dropped (the question routed at nidana.model.2's planning closes for topology-dsl@v2; topology-ir@v1's reject set first replays at nidana.model.5)`
  - `- nidana.model D3's final field behind every getter and throwing factories leave the private constructors of TransformEdge and TopologyDefinition unused, so the package carries two more ignores of unused_element until nidana.model.10. Disposition: dropped (temporary; nidana.model.10 constructs through them)`
  - `- topology-ir@v1's Interface prose says every IR value type is annotated @immutable, while its code block, unlike topic-model@v1's, shows no annotation; the declarations follow the prose, the sealed EdgeInput included. Disposition: dropped (no fixture depends on it; a compatible hsdd-contract touch at the end of nidana.model can add the annotations to the block)`
  - `- nidana.model D6 names an aliased import as the form a text search misses; adjacent string literals and escape sequences in a URI also import dart:io, and the hardened directive reader now rejects both. Disposition: dropped (closed in purity_test.dart; D6 stays true)`
  - one sizing line: the phase scope's estimate of about 700 lines in about 12 files against the measured product diff (Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint).
- **Metrics:** one line: the product diff, `git diff --stat <base> HEAD -- packages/`, where `<base>` is the parent of Task 1's commit, in files and lines, the library and the tests apart, beside the estimate of about 700 lines in about 12 files; the task count, 5 of the allowed 6.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.4.verification.md
git commit -m "docs(verify): nidana.model.4 verification" -m "<the co-author trailer your harness gives>"
```
