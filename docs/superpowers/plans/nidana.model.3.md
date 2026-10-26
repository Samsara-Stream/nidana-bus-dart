# nidana.model.3 topic-model@v1 Declarations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `packages/nidana_dart_contracts` as a workspace member and land every declaration of topic-model@v1's Interface under `lib/src/topic/`, exported from `lib/nidana_dart_contracts.dart`, with `test/purity_test.dart` for G25 and G26, so that `fvm dart run nidana_contract_check topic-model --set structure,surface,reject` passes all 30 fixtures, the first replay of the committed surface and reject sets against a real package.

**Architecture:** A type-level phase (nidana.model D3): signatures, modifiers, `@immutable`, constructors with their defaults and `const`, the asserts the reject set expects, a final field behind every getter the reject set assigns to, and the export list. A member that stores an argument or is a constant of its declaration (`variant`, `valueType`) is delivered; every body that derives a value throws `UnimplementedError`; `==`, `hashCode` and `toString` stay `Object`'s until nidana.model.8. One library per Interface section under `lib/src/topic/` (D4); the main library exports exactly the Interface's 25 names through `show` lists.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:meta` 1.19.0 (`@immutable`), the package's only dependency; `package:test` for the package's tests; the replay tool `nidana_contract_check` as nidana.model.2 left it.

**Spec:** `hsdd-context/superpowers/nidana.model.3.md` (the derivative; the phase context with topic-model@v1's Interface and Guarantees sits between its markers). Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D3 (what a type-level phase lands), D4 (the source layout; README, CHANGELOG and LICENSE written once, here) and D6 (`purity_test.dart`'s exact checks); `hsdd/adr/002-package-workspace-layout.md` items 1 to 5 and 9. The fixtures the gate replays: `hsdd/contract/fixture/topic-model/surface/` and `reject/`, under `hsdd/contract/fixture/analysis_options.yaml`. Evidence: `docs/auto-run/experiments/topic-model-declarations-plan/` (`run.sh`, `output.txt`, `draft/`), a dry run of this plan's four tasks in a temporary copy of the committed tree; labels such as T2.4 or R below name the steps of its `output.txt`. `draft/` is evidence, not code to copy: the code blocks below are the source.

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 5 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model --set structure,surface,reject` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.3.verification.md from
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

- Toolchain: `fvm dart` only, every command from the repository root, no global tooling. `fvm dart pub get` resolves the whole workspace; adding the member leaves `pubspec.lock` byte-identical (T1.3), because a workspace lockfile records no member and already holds `meta` 1.19.0 and `test` as transitive packages. Commit `pubspec.lock` only if `git status --short pubspec.lock` shows it modified.
- Files: everything new lives in `packages/nidana_dart_contracts/`; outside it, Task 1 adds one line to the root `pubspec.yaml` and Task 4 writes the verification doc. Nothing under `hsdd/` changes otherwise, and nothing under `hsdd/contract/` ever.
- The package (ADR-002 items 3, 4, 5 and 9): `version: 0.1.0`, `resolution: workspace`, `environment: sdk: ^3.13.0`, `dependencies: meta: ^1.19.0`, `dev_dependencies: test: ^1.31.1`, nothing else; no `publish_to`, `homepage` or `repository`; `README.md`, `CHANGELOG.md` and a byte copy of the root `LICENSE`, written once by this phase (D4).
- Declarations (D3): every name, signature, modifier, default and `const` exactly as the Interface writes it; no topic constructor takes a dispatcher hint (G5); the final field behind every getter the reject set assigns to (a getter without a field reports `assignment_to_final_no_setter`, not the `assignment_to_final` the fixtures expect); `==` and `hashCode` stay `Object`'s, and so does `toString`, because its override is the G15, G17 and G24 behavior nidana.model.8 delivers.
- Bodies: a member that returns a stored argument or a constant of its declaration is delivered (every field, `variant`, `valueType`, and `Lineage.root`, a `const` constructor with no body). Every other body throws `UnimplementedError`: `ref`, `createInitial`, `isWellFormedTopicName`, `MessageSource.tryParse`, `MessageEnvelope.publishedTo`, `redacted`, `Lineage.causedBy`, `combine`, `withLatestFrom`, `isAtLeastAsLongAs`, `ObserverCapability.permits`, `RedactedPayload.of`. Do not store `StateTopic`'s `initial` and do not copy `parentCorrelationIds`; nidana.model.8 adds both (G9, G4) without changing a signature.
- Dartdoc carried from the Interface is copied as written, with one exception: `MessageSource`'s five renderings sit in backticks (Task 3), because the root lint set reports the Interface's `<id>` as `unintended_html_in_doc_comment`. The Interface's trailing `//` comments stay trailing line comments. Add no other dartdoc to declarations; the main library gets the two-line library comment given in Task 1.
- Analyzer: `fvm dart analyze --fatal-infos` at the root reports nothing. The only suppression is the `// ignore: unused_element` above `RedactedPayload._` (Task 3).
- Tests: run from the root as `fvm dart test packages/nidana_dart_contracts`. No test asserts a body that throws `UnimplementedError` or identity equality: nidana.model.8 changes both, and every test here must stay true after it. The lockfile holds `test` 1.33.0; no test uses a `test` API newer than 1.31.1.
- Contract gaps (ADR-001 item 8; nidana.model's First replays): the surface and reject fixtures are forward references, and this gate is their first replay against a real package. A fixture that fails against a declaration matching this plan's code block is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the fixture path and line, the reported line, severity, code and message, the marker's code, the guarantee its `// covers:` header names, and the fix you would propose. A reject line where the analyzer reports two codes, one marked and one not, is the gap ADR-001 item 4's marker form cannot express (a marker names one code on the next line, and the structure set rejects stacked markers): report it as a contract gap for hsdd-adr. The dry run passed every fixture with one code per line (T3.4, R), so a FAIL most likely means the code differs from its block.
- Formatting and commits: run `fvm dart format` on every Dart file a task creates or changes before committing. Stage explicit paths; conventional subjects (`feat(dart_contracts): ...`); the body ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.

## Review Focus

The input classes the spec implies but the surface and reject sets do not exercise, most likely to bite first; each has its test in the owning task.

1. **Non-const construction with an argument the const path rejects** (a generated registry's `static final ReplayTopic(bufferSize: n)` with `n < 1`, a source built from an empty string at run time): the reject set sees only the const path, so a missing assert passes the gate. Expected: an `AssertionError` under `dart test`, which runs with assertions on. Tests: Task 2 (G10), Task 3 (the four sources).
2. **Omitted optional arguments**: the surface set checks types, not values, so a wrong default compiles. Expected: `sensitive` false, `tracing` `Tracing.enabled`, `dedup` `Dedup.equality` on both `StateTopic` constructors (G6); an envelope's `causationId` null and `parentCorrelationIds` empty; `Lineage.root()` with no causation, no parents, a null correlation and not sensitive (G18). Tests: Task 2, Task 3.
3. **Constant members read through a wider static type** (`topic.variant` and `topic.valueType` on a `Topic<Object?>`, as a bus reads a registry): each variant answers its own `TopicVariant` and its `T` (G6, G7) already in this phase. Test: Task 2.
4. **A computed state topic whose factory throws or has effects**: constructing the topic never calls the factory (G9), now and after nidana.model.8. Test: Task 2.
5. **An effect reaching `lib/` in a form a text search can miss**: a double-quoted URI, an `as` prefix, an `export` directive, a forbidden token inside a comment, a second dependency in the pubspec. Expected: `purity_test.dart` fails on each (T1.5); an aliased call through an import the test allows stays a review item (D6). Test: Task 1 (the readers' self-test).

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `pubspec.yaml` (root) | 1 | `packages/nidana_dart_contracts` in the `workspace:` list, after `packages/nidana_contract_check` |
| `{pkg}/pubspec.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE` | 1 | The published member of ADR-002 items 3, 4, 5 and 9 |
| `{pkg}/lib/nidana_dart_contracts.dart` | 1, 2, 3 | The main library: its comment (1), then the export list (2, 3) |
| `{pkg}/test/purity_test.dart` | 1 | G25 and G26 (D6) |
| `{pkg}/lib/src/topic/topic.dart` | 2 | Topics; topic references and names |
| `{pkg}/lib/src/topic/scope.dart` | 2 | `Scope` |
| `{pkg}/lib/src/topic/message_source.dart` | 3 | The closed `MessageSource` family |
| `{pkg}/lib/src/topic/envelope.dart` | 3 | `MessageEnvelope` |
| `{pkg}/lib/src/topic/lineage.dart` | 3 | `Lineage` |
| `{pkg}/lib/src/topic/redacted_payload.dart` | 3 | `RedactedPayload` |
| `{pkg}/lib/src/topic/observer.dart` | 3 | `ObserverCapability`, `LogLevel`, `SpanHandle`, `ObserveContext`, `BusObserver` |
| `{pkg}/test/declarations_test.dart` | 2, 3 | What the declarations fix before any body computes |
| `hsdd/verify/nidana.model.3.verification.md` | 4 | The verification doc |

---

### Task 1: The package, its workspace entry and the purity test

You are creating `packages/nidana_dart_contracts`, the pure core of Nidana Bus on Dart, as a member of the pub workspace at the repository root. Run every command from the repository root with `fvm dart`. This task lands the package's files and an empty main library; Tasks 2 and 3 add the declarations. `test/purity_test.dart` checks G25 and G26 of topic-model@v1 by reading the package's own files (nidana.model D6): it finds the workspace root as the nearest ancestor of the working directory that holds `hsdd/contract/`, so it works when `fvm dart test packages/nidana_dart_contracts` runs from the root. It cannot use `package:yaml` (G26 allows `test` as the only dev dependency), so it reads the pubspec line by line.

**Files:**
- Modify: `pubspec.yaml` (root; one line in `workspace:`)
- Create: `packages/nidana_dart_contracts/pubspec.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE`
- Create: `packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart`
- Test: `packages/nidana_dart_contracts/test/purity_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: the workspace member `nidana_dart_contracts` and its main library `lib/nidana_dart_contracts.dart`, whose comment and `library;` directive Tasks 2 and 3 keep while they add `export` lines below them.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/purity_test.dart`:

```dart
// G25 and G26 of topic-model@v1, which its Validation leaves to
// nidana.model's gates (nidana.model D6). A text search misses an aliased
// import; review covers that.
import 'dart:io';

import 'package:test/test.dart';

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

/// The names under the top-level key [section] of the pubspec [text]: the
/// keys indented by exactly two spaces, up to the next line that starts in
/// column zero.
Set<String> sectionKeys(String text, String section) {
  final Set<String> keys = <String>{};
  bool inside = false;
  for (final String line in text.split('\n')) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
      continue;
    }
    if (!line.startsWith(' ')) {
      inside = line.startsWith('$section:');
      continue;
    }
    final Match? key = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (inside && key != null) {
      keys.add(key.group(1)!);
    }
  }
  return keys;
}

/// The URI of every import and export directive in [source].
List<String> directiveUris(String source) => <String>[
  for (final Match m in RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  ).allMatches(source))
    m.group(1)!,
];

/// Whether a library under `lib/` may name [uri] (G25, G26).
bool allowedUri(String uri) {
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
  return true;
}

/// Every Dart library under this package's `lib/`.
List<File> libraries() =>
    Directory('${packageDirectory().path}/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();

const List<String> effects = <String>[
  'DateTime.now(',
  'Stopwatch(',
  'Timer(',
  'Timer.periodic(',
  'scheduleMicrotask(',
  'Future.delayed(',
  'Future.microtask(',
  'Random(',
  'Zone.',
];

void main() {
  test('G26 depends on meta alone, with test its only dev dependency', () {
    final String pubspec = File('${packageDirectory().path}/pubspec.yaml')
        .readAsStringSync();
    expect(sectionKeys(pubspec, 'dependencies'), <String>{'meta'});
    expect(sectionKeys(pubspec, 'dev_dependencies'), <String>{'test'});
  });

  test('G25 G26 no library imports dart:io, dart:isolate, dart:ffi, '
      'dart:html or a package other than meta and its own', () {
    final List<File> found = libraries();
    expect(found, isNotEmpty);
    for (final File library in found) {
      for (final String uri in directiveUris(library.readAsStringSync())) {
        expect(allowedUri(uri), isTrue, reason: '${library.path} names $uri');
      }
    }
  });

  test('G25 no library reads a clock, schedules work, '
      'generates an id or reaches a zone', () {
    final List<File> found = libraries();
    expect(found, isNotEmpty);
    for (final File library in found) {
      final String source = library.readAsStringSync();
      for (final String effect in effects) {
        expect(
          source.contains(effect),
          isFalse,
          reason: '${library.path} contains $effect',
        );
      }
    }
  });

  test('the readers see every directive form and pubspec section', () {
    expect(
      directiveUris(
        "import 'dart:io';\nimport \"dart:async\" as a;\n"
        "  export 'package:x/y.dart' show Z;\nimport 'src/a.dart';\n",
      ),
      <String>['dart:io', 'dart:async', 'package:x/y.dart', 'src/a.dart'],
    );
    expect(allowedUri('dart:io'), isFalse);
    expect(allowedUri('dart:async'), isTrue);
    expect(allowedUri('package:meta/meta.dart'), isTrue);
    expect(allowedUri('package:collection/collection.dart'), isFalse);
    expect(allowedUri('src/topic/topic.dart'), isTrue);
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

- [ ] **Step 2: Run it and the replay, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts; echo "exit: $?"`
Expected: `exit: 1`, `+1 -3: Some tests failed.`: the three G-tests fail with `PathNotFoundException` (`.../packages/nidana_dart_contracts/pubspec.yaml`, then `.../lib/`), and the readers test passes (T1.2).
Run: `fvm dart run nidana_contract_check topic-model --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 1`; 17 `PASS structure` lines, then 3 `PENDING surface` and 10 `PENDING reject` lines, each `...: package nidana_dart_contracts is absent from .dart_tool/package_config.json`, then `30 fixtures: 17 passed, 0 failed, 13 pending` (S1).

- [ ] **Step 3: Create the package and its workspace entry**

In the root `pubspec.yaml`, the `workspace:` list becomes, in path order:

```yaml
workspace:
  - packages/nidana_contract_check
  - packages/nidana_dart_contracts
```

`packages/nidana_dart_contracts/pubspec.yaml`:

```yaml
name: nidana_dart_contracts
description: The pure core of Nidana Bus on Dart, typed topics, message envelopes and their lineage, observer interfaces, and the topology DSL and IR.
version: 0.1.0
environment:
  sdk: ^3.13.0
resolution: workspace
dependencies:
  meta: ^1.19.0
dev_dependencies:
  test: ^1.31.1
```

`packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart` (the comment needs `library;`, or the root lint set reports it as dangling):

```dart
/// The pure, effect-free core of Nidana Bus on Dart, which every other
/// package builds on.
library;
```

`LICENSE`: `cp LICENSE packages/nidana_dart_contracts/LICENSE` (a byte copy; ADR-002 item 9).

`packages/nidana_dart_contracts/CHANGELOG.md` (the release's version bump rewrites it; no phase edits it, D4):

```markdown
## 0.1.0

- Initial version.
```

`packages/nidana_dart_contracts/README.md`, written once for the package as released (D4; the three public libraries are ADR-002 item 3's, and nidana.model.4 and .5 create the other two):

````markdown
# nidana_dart_contracts

The pure, effect-free core of Nidana Bus on Dart, which every other nidana
package builds on: typed topics and their references, the message envelope
and its lineage rules, scopes, the observer interfaces, sensitive-payload
redaction, the topology DSL with its recording builder, and the
`TopologyDefinition` IR with its graphs, renderers and analyses.

Everything here is a value or a total function. The package depends on the
Dart SDK and `package:meta` alone; it reads no clock, creates no timer or
microtask, generates no id and performs no I/O, so a function that needs a
timestamp or a fresh id takes it as an argument. Delivering messages is the
runtime's work, in `nidana_dart_runtime`.

## Libraries

- `package:nidana_dart_contracts/nidana_dart_contracts.dart`: topics,
  envelopes, lineage, scopes, observers and redaction; the topology DSL; the
  IR values.
- `package:nidana_dart_contracts/topology_plan.dart`: the plan a topology
  declaration records, which live activation interprets.
- `package:nidana_dart_contracts/topology_ir.dart`: topology graphs, their
  renderers and JSON form, and the analyses over them.

## Declaring topics

A registry declares its topics as constant members of an
`abstract final class`:

```dart
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

abstract final class CartTopics {
  static const StateTopic<int> itemCount = StateTopic<int>(
    name: 'cart.item-count',
    initial: 0,
  );

  static const EventTopic<String> checkoutRequested = EventTopic<String>(
    name: 'cart.checkout.requested',
  );
}
```

## License

Apache-2.0; see `LICENSE`.
````

Then run `fvm dart pub get` and `git status --short pubspec.lock` (expected: no output; T1.3).

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the replay**

Run: `fvm dart format packages/nidana_dart_contracts`
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+4: All tests passed!`
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 1` and `30 fixtures: 17 passed, 13 failed, 0 pending`: no PENDING line any more, and every surface and reject library FAILs on undefined names (`undefined_class` and the diagnostics that follow from it), because the main library exports nothing yet (T1.4). That is this task's end state, not a gap.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml packages/nidana_dart_contracts/pubspec.yaml packages/nidana_dart_contracts/README.md packages/nidana_dart_contracts/CHANGELOG.md packages/nidana_dart_contracts/LICENSE packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart packages/nidana_dart_contracts/test/purity_test.dart
git commit -m "feat(dart_contracts): add the nidana_dart_contracts package and its purity test" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Add `pubspec.lock` to the `git add` only if `git status --short pubspec.lock` showed it modified.

### Task 2: Topics, topic references, names and scopes

You are adding the topic family of topic-model@v1 to `packages/nidana_dart_contracts`, a pub workspace member whose main library `lib/nidana_dart_contracts.dart` exists with a library comment and no exports. Run every command from the repository root with `fvm dart`. This is a type-level phase (nidana.model D3): land the declarations below exactly, with their dartdoc, which is copied from the contract's Interface. Fields hold their arguments; `variant` and `valueType` return constants; every other body throws `UnimplementedError`; declare no `==`, `hashCode` or `toString`. The sealed `Topic<T>` and `MultiWriterTopic<T>` and their three final subclasses must share one library, so all five are in `topic.dart`; the fields live in `Topic<T>`, behind private constructors. The fixtures this task serves: `surface/topics.dart` and the reject libraries `topic_family_is_closed.dart` (G1), `only_state_topics_carry_values.dart` (G2), `state_topic_requires_initial.dart` (G3), `no_dispatcher_hint.dart` (G5), `replay_buffer_is_positive.dart` (G10) and `state_topic_is_not_multi_writer.dart` (G27), all under `hsdd/contract/fixture/topic-model/`.

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/topic/topic.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topic/scope.dart`
- Modify: `packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart` (add two `export` lines)
- Test: `packages/nidana_dart_contracts/test/declarations_test.dart`

**Interfaces:**
- Consumes (Task 1): `lib/nidana_dart_contracts.dart`, a library comment and `library;`.
- Produces (Task 3 imports `topic.dart` for these): `sealed class Topic<T>` with `final String name`, `final bool sensitive`, `final Tracing tracing`, `TopicVariant get variant`, `Type get valueType`, `TopicRef get ref`; `final class TopicRef` with `final String name`, `final TopicVariant variant`, `final String typeName`; `StateTopic<T>`, `MultiWriterTopic<T>`, `EventTopic<T>`, `ReplayTopic<T>`, `TopicVariant`, `Dedup`, `Tracing`, `bool isWellFormedTopicName(String name)`; and `enum Scope` in `scope.dart`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/declarations_test.dart`:

```dart
// What the declarations of topic-model@v1 fix before any body computes
// (nidana.model D3): defaults, the members that are constants of a
// declaration, and the asserts of non-const construction.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('G6 defaults: not sensitive, traced, deduplicated by equality', () {
    const StateTopic<int> state = StateTopic<int>(name: 'a.count', initial: 0);
    final StateTopic<int> computed = StateTopic<int>.computed(
      name: 'a.count',
      initial: () => 0,
    );
    const EventTopic<int> event = EventTopic<int>(name: 'a.tapped');
    const ReplayTopic<int> replay = ReplayTopic<int>(
      name: 'a.log',
      bufferSize: 1,
    );
    for (final Topic<int> topic in <Topic<int>>[
      state,
      computed,
      event,
      replay,
    ]) {
      expect(topic.sensitive, isFalse);
      expect(topic.tracing, Tracing.enabled);
    }
    expect(state.dedup, Dedup.equality);
    expect(computed.dedup, Dedup.equality);
  });

  test('G6 G7 variant names the class and valueType is T', () {
    final List<Topic<Object?>> topics = <Topic<Object?>>[
      const StateTopic<int>(name: 'a.count', initial: 0),
      const EventTopic<String>(name: 'a.tapped'),
      const ReplayTopic<bool>(name: 'a.log', bufferSize: 2),
    ];
    expect(topics.map((Topic<Object?> t) => t.variant), <TopicVariant>[
      TopicVariant.state,
      TopicVariant.event,
      TopicVariant.replay,
    ]);
    expect(topics.map((Topic<Object?> t) => t.valueType), <Type>[
      int,
      String,
      bool,
    ]);
  });

  test('G9 constructing a computed state topic never calls its factory', () {
    expect(
      () => StateTopic<int>.computed(
        name: 'a.count',
        initial: () => throw StateError('called at construction'),
      ),
      returnsNormally,
    );
  });

  test('G10 a non-const replay topic below one value fails an assertion', () {
    int size = 0;
    expect(
      () => ReplayTopic<int>(name: 'a.log', bufferSize: size),
      throwsA(isA<AssertionError>()),
    );
    size = -1;
    expect(
      () => ReplayTopic<int>(name: 'a.log', bufferSize: size),
      throwsA(isA<AssertionError>()),
    );
  });
}
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_dart_contracts/test/declarations_test.dart; echo "exit: $?"`
Expected: `exit: 1`; the file does not compile: `Error: 'Topic' isn't a type.`, `Error: Couldn't find constructor 'StateTopic'.`, `Error: Undefined name 'TopicVariant'.` and like lines, then `Some tests failed.` (T2.2). The replay still prints `30 fixtures: 17 passed, 13 failed, 0 pending`.

- [ ] **Step 3: Implement `lib/src/topic/topic.dart` and `lib/src/topic/scope.dart`, and export them**

`packages/nidana_dart_contracts/lib/src/topic/topic.dart`:

```dart
import 'package:meta/meta.dart';

/// The three topic variants (Spec §2.1).
enum TopicVariant { state, event, replay }

/// Whether a state topic suppresses a publish equal to its current value
/// (Spec §3.12). Equality is Dart's `==` (Spec §3.12 table).
enum Dedup {
  equality, // the default: a publish `==` to the current value is a no-op
  none, // every publish notifies
}

/// Whether the bus attaches envelope metadata to a topic's publishes
/// (Guide §8.1; Spec §3.5 "Cost"). What the bus and its observers do with an
/// untraced topic is bus-api@v2's; here it only fixes how an untraced value
/// enters lineage (Lineage.root).
enum Tracing { enabled, disabled }

/// A typed reference to a named channel on a bus (Spec §2.1, §4.2). A pure
/// value, shared across bus instances; it holds no subject.
@immutable
sealed class Topic<T> {
  const Topic._({
    required this.name,
    required this.sensitive,
    required this.tracing,
  });

  final String name;
  final bool sensitive; // Spec §9.2
  final Tracing tracing; // Guide §8.1
  TopicVariant get variant;
  Type get valueType => T;
  TopicRef get ref =>
      throw UnimplementedError(); // TopicRef(name, variant, typeName: '$T')
}

final class StateTopic<T> extends Topic<T> {
  /// A constant initial value (Spec §2.5 "Allowed: constant").
  const StateTopic({
    required super.name,
    required T initial,
    this.dedup = Dedup.equality,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : super._();

  /// A pure factory (Spec §2.5 "Allowed: pure factory"), never called at
  /// construction. When the bus calls createInitial() is bus-api@v2's.
  const StateTopic.computed({
    required super.name,
    required T Function() initial,
    this.dedup = Dedup.equality,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : super._();

  final Dedup dedup;

  @override
  TopicVariant get variant => TopicVariant.state;

  /// The declared value, or the factory's result for this call (G9).
  T createInitial() => throw UnimplementedError();
}

/// The topics any number of writers may publish to (Spec §2.1, §3.11): the
/// event and replay variants, and no other (G1). The parameter type of a
/// publish path that takes no ownership claim, so a state topic does not
/// fit one (G27).
sealed class MultiWriterTopic<T> extends Topic<T> {
  const MultiWriterTopic._({
    required super.name,
    required super.sensitive,
    required super.tracing,
  }) : super._();
}

final class EventTopic<T> extends MultiWriterTopic<T> {
  const EventTopic({
    required super.name,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : super._();

  @override
  TopicVariant get variant => TopicVariant.event;
}

final class ReplayTopic<T> extends MultiWriterTopic<T> {
  /// Buffers the [bufferSize] most recent values (Spec §2.1), at least one.
  const ReplayTopic({
    required super.name,
    required this.bufferSize,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : assert(bufferSize >= 1, 'bufferSize must be at least 1'),
       super._();

  final int bufferSize;

  @override
  TopicVariant get variant => TopicVariant.replay;
}

/// A serializable reference to a topic (Spec Appendix A.4): what the IR
/// records for reads and writes and what an observer receives.
@immutable
final class TopicRef {
  const TopicRef({
    required this.name,
    required this.variant,
    required this.typeName, // the value type's toString(), as '$T' renders it
  });

  final String name;
  final TopicVariant variant;
  final String typeName;
}

/// Whether [name] follows `domain.entity` or `domain.entity.action`
/// (Spec §4.4): two or three segments separated by '.', each segment
/// lowercase kebab case, `[a-z][a-z0-9]*(-[a-z0-9]+)*`.
bool isWellFormedTopicName(String name) => throw UnimplementedError();
```

`packages/nidana_dart_contracts/lib/src/topic/scope.dart`:

```dart
/// A topology's lifetime (Spec §7.1). Topics have no scope.
enum Scope {
  application,
  module,
  page;

  /// Whether this scope lives at least as long as [other]: the order
  /// application, module, page, reflexive (Spec §7.2).
  bool isAtLeastAsLongAs(Scope other) => throw UnimplementedError();
}
```

Below `library;` in `lib/nidana_dart_contracts.dart`, after one blank line:

```dart
export 'src/topic/scope.dart' show Scope;
export 'src/topic/topic.dart'
    show
        Dedup,
        EventTopic,
        MultiWriterTopic,
        ReplayTopic,
        StateTopic,
        Topic,
        TopicRef,
        TopicVariant,
        Tracing,
        isWellFormedTopicName;
```

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the replay**

Run: `fvm dart format packages/nidana_dart_contracts`
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+8: All tests passed!` (four purity tests, four declarations tests).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 1` and `30 fixtures: 24 passed, 6 failed, 0 pending` (T2.4): `PASS surface .../surface/topics.dart`; `PASS reject` for `no_dispatcher_hint.dart`, `only_state_topics_carry_values.dart`, `replay_buffer_is_positive.dart`, `state_topic_is_not_multi_writer.dart`, `state_topic_requires_initial.dart` and `topic_family_is_closed.dart`; still `FAIL` on undefined names, until Task 3: `surface/envelopes.dart`, `surface/observers.dart`, `reject/envelope_requires_metadata.dart`, `reject/observer_has_no_publish_path.dart`, `reject/source_family_is_closed.dart`, `reject/values_are_immutable.dart`. A FAIL among the seven this task serves is a stop: see Global Constraints, Contract gaps.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topic/topic.dart packages/nidana_dart_contracts/lib/src/topic/scope.dart packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart packages/nidana_dart_contracts/test/declarations_test.dart
git commit -m "feat(dart_contracts): declare topics, topic references and scopes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Sources, envelopes, lineage, redaction and observers

You are adding the rest of topic-model@v1's Interface to `packages/nidana_dart_contracts`, whose `lib/src/topic/topic.dart` already declares the topic family and `TopicRef`, and whose main library exports them and `Scope`. Run every command from the repository root with `fvm dart`. The type-level rules of Task 2 hold: land the declarations below exactly; fields hold their arguments as given (no list copy; nidana.model.8 adds it, G4); every body that derives a value throws `UnimplementedError`; declare no `==`, `hashCode` or `toString`. Two departures from the Interface are deliberate: `MessageSource`'s dartdoc puts its five renderings in backticks, because the Interface's `'topology:<id>'` trips the root lint `unintended_html_in_doc_comment`; and `RedactedPayload`'s private constructor, which `RedactedPayload.of` will call from nidana.model.8, carries the plan's only `// ignore: unused_element`. `envelope.dart` and `lineage.dart` import each other, which Dart allows. The fixtures this task serves: `surface/envelopes.dart`, `surface/observers.dart`, and the reject libraries `values_are_immutable.dart` (G4), `envelope_requires_metadata.dart` (G12), `source_family_is_closed.dart` (G16) and `observer_has_no_publish_path.dart` (G22).

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/topic/message_source.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topic/envelope.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topic/lineage.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topic/redacted_payload.dart`
- Create: `packages/nidana_dart_contracts/lib/src/topic/observer.dart`
- Modify: `packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart` (the full export list)
- Modify: `packages/nidana_dart_contracts/test/declarations_test.dart` (three tests)

**Interfaces:**
- Consumes (Task 2, `lib/src/topic/topic.dart`): `sealed class Topic<T>` (`MessageEnvelope.publishedTo` takes one) and `final class TopicRef` (`BusObserver.onPublish` takes one).
- Produces: the declarations below; with them the main library exports all 25 names of the Interface.

- [ ] **Step 1: Write the failing test**

Add to `main()` in `packages/nidana_dart_contracts/test/declarations_test.dart`, after the G10 test:

```dart
  test('a source with an empty field fails an assertion', () {
    String empty = '';
    expect(() => TopologySource(empty), throwsA(isA<AssertionError>()));
    expect(() => ServiceSource(empty), throwsA(isA<AssertionError>()));
    expect(() => PageSource(empty), throwsA(isA<AssertionError>()));
    expect(() => ExecutorSource(empty), throwsA(isA<AssertionError>()));
    empty = 'x';
    expect(() => ServiceSource(empty), returnsNormally);
  });

  test('an envelope keeps the fields it is given, with no causation and no '
      'parents by default', () {
    final DateTime at = DateTime.utc(2026);
    const MessageSource source = ServiceSource('s');
    final MessageEnvelope<int> envelope = MessageEnvelope<int>(
      id: 'e-1',
      payload: 1,
      correlationId: 'c-1',
      timestamp: at,
      source: source,
      sensitive: true,
    );
    expect(envelope.id, 'e-1');
    expect(envelope.payload, 1);
    expect(envelope.correlationId, 'c-1');
    expect(envelope.causationId, isNull);
    expect(envelope.parentCorrelationIds, isEmpty);
    expect(envelope.timestamp, at);
    expect(envelope.source, same(source));
    expect(envelope.sensitive, isTrue);
  });

  test('G18 Lineage.root has no causation and no parents, and the '
      'correlation and sensitivity it is given, null and false by default', () {
    const Lineage root = Lineage.root();
    expect(root.causationId, isNull);
    expect(root.correlationId, isNull);
    expect(root.parentCorrelationIds, isEmpty);
    expect(root.sensitive, isFalse);
    const Lineage started = Lineage.root(correlationId: 'f-1', sensitive: true);
    expect(started.causationId, isNull);
    expect(started.correlationId, 'f-1');
    expect(started.parentCorrelationIds, isEmpty);
    expect(started.sensitive, isTrue);
  });
```

- [ ] **Step 2: Run it and record the failure**

Run: `fvm dart test packages/nidana_dart_contracts/test/declarations_test.dart; echo "exit: $?"`
Expected: `exit: 1`; the file does not compile: `Error: Method not found: 'ServiceSource'.`, `Error: 'MessageEnvelope' isn't a type.`, `Error: Undefined name 'Lineage'.` and like lines, then `Some tests failed.` (T3.2). The replay still prints `30 fixtures: 24 passed, 6 failed, 0 pending`.

- [ ] **Step 3: Implement the five libraries and the full export list**

`packages/nidana_dart_contracts/lib/src/topic/message_source.dart`:

```dart
import 'package:meta/meta.dart';

/// Who produced a message (Spec §2.4 `source`). toString() renders the
/// Spec's format: `'topology:<id>'`, `'service:<name>'`,
/// `'page:<routeOrName>'`, `'executor:<name>'`, `'unknown'`.
@immutable
sealed class MessageSource {
  const MessageSource._();

  /// The inverse of toString(); null for any other text (G17).
  static MessageSource? tryParse(String text) => throw UnimplementedError();
}

final class TopologySource extends MessageSource {
  const TopologySource(this.topologyId)
    : assert(topologyId != '', 'topologyId must not be empty'),
      super._();

  final String topologyId;
}

final class ServiceSource extends MessageSource {
  const ServiceSource(this.name)
    : assert(name != '', 'name must not be empty'),
      super._();

  final String name;
}

final class PageSource extends MessageSource {
  const PageSource(this.route)
    : assert(route != '', 'route must not be empty'),
      super._();

  final String route;
}

final class ExecutorSource extends MessageSource {
  const ExecutorSource(this.name)
    : assert(name != '', 'name must not be empty'),
      super._();

  final String name;
}

/// The source of a publisher-less publish (Spec §2.4).
final class UnknownSource extends MessageSource {
  const UnknownSource() : super._();
}
```

`packages/nidana_dart_contracts/lib/src/topic/envelope.dart`:

```dart
import 'package:meta/meta.dart';

import 'lineage.dart';
import 'message_source.dart';
import 'topic.dart';

/// The carrier of every value published to a topic (Spec §2.4). The fields
/// are the Spec's; source is typed.
@immutable
final class MessageEnvelope<T> {
  MessageEnvelope({
    required this.id,
    required this.payload,
    required this.correlationId,
    this.causationId, // null for a root message
    this.parentCorrelationIds = const <String>[], // copied, unmodifiable
    required this.timestamp,
    required this.source,
    required this.sensitive,
  });

  /// The envelope a stage publishes to [topic]: causation and parents from
  /// [lineage]; correlation from [lineage], or freshCorrelationId() when the
  /// lineage has none; sensitive is topic.sensitive (G14).
  factory MessageEnvelope.publishedTo(
    Topic<T> topic, {
    required String id,
    required T payload,
    required Lineage lineage,
    required String Function() freshCorrelationId,
    required DateTime timestamp,
    required MessageSource source,
  }) => throw UnimplementedError();

  final String id;
  final T payload;
  final String correlationId;
  final String? causationId;
  final List<String> parentCorrelationIds;
  final DateTime timestamp;
  final MessageSource source;
  final bool sensitive;

  /// This envelope with a sensitive payload replaced by
  /// RedactedPayload.of(payload); this envelope itself when not sensitive.
  MessageEnvelope<Object?> redacted() => throw UnimplementedError();
}
```

`packages/nidana_dart_contracts/lib/src/topic/lineage.dart`:

```dart
import 'package:meta/meta.dart';

import 'envelope.dart';

/// The lineage fields of a pipeline value (Spec §2.4, §3.5): what the next
/// published envelope's causationId, correlationId and parentCorrelationIds
/// will be, and whether the value derives from a sensitive input.
@immutable
final class Lineage {
  /// No traced message caused this value: a shell publish starting a flow,
  /// or a value read from a Tracing.disabled topic. A null correlation means
  /// the publish starts a new flow (MessageEnvelope.publishedTo).
  const Lineage.root({this.correlationId, this.sensitive = false})
    : causationId = null,
      parentCorrelationIds = const <String>[];

  /// Caused by [cause], a published envelope: causationId is cause.id;
  /// correlationId, parentCorrelationIds and sensitive are cause's.
  Lineage.causedBy(MessageEnvelope<Object?> cause)
    : causationId = null,
      correlationId = null,
      parentCorrelationIds = const <String>[],
      sensitive = false {
    throw UnimplementedError();
  }

  final String? causationId;
  final String? correlationId;
  final List<String> parentCorrelationIds; // unmodifiable
  final bool sensitive;

  /// combine and combineLatest (Spec §2.4 table). [trigger] indexes the
  /// input whose new emission fired the operator. causationId is the
  /// trigger's; sensitive is the or of all inputs. Over the inputs that carry
  /// a correlationId: none, the result carries none and no parents; one
  /// distinct value, it is kept and parents are the union of those inputs'
  /// parents in input order; several, the result takes freshCorrelationId(),
  /// called exactly once, and parents are the distinct input correlation ids
  /// in input order. Throws ArgumentError when [inputs] is empty or
  /// [trigger] is out of range.
  static Lineage combine(
    List<Lineage> inputs, {
    required int trigger,
    required String Function() freshCorrelationId,
  }) => throw UnimplementedError();

  /// withLatestFrom (Spec §2.4 table): causation, correlation and parents
  /// from [primary]; sensitive is the or of [primary] and [latest].
  static Lineage withLatestFrom(Lineage primary, List<Lineage> latest) =>
      throw UnimplementedError();
}
```

`packages/nidana_dart_contracts/lib/src/topic/redacted_payload.dart`:

```dart
import 'package:meta/meta.dart';

/// A sensitive payload as diagnostics, recorders and devtools show it: its
/// type and a truncated hash (Spec §9.2 item 2).
@immutable
final class RedactedPayload {
  // RedactedPayload.of constructs through this once nidana.model.8 lands it.
  // ignore: unused_element
  const RedactedPayload._(this.typeName, this.hash);

  /// typeName is payload.runtimeType.toString(); hash is the low 32 bits of
  /// payload.hashCode as eight lowercase hexadecimal digits.
  factory RedactedPayload.of(Object? payload) => throw UnimplementedError();

  final String typeName;
  final String hash;
}
```

`packages/nidana_dart_contracts/lib/src/topic/observer.dart`:

```dart
import 'envelope.dart';
import 'topic.dart';

/// Observer visibility (Spec §3.7, §9.2).
enum ObserverCapability {
  observeAll, // sees envelopes of non-sensitive topics
  observeSensitive; // sees envelopes of sensitive topics; an explicit grant

  /// Whether an observer holding [capabilities] may receive an envelope
  /// whose sensitive flag is [sensitive] (G23).
  static bool permits(
    Set<ObserverCapability> capabilities, {
    required bool sensitive,
  }) => throw UnimplementedError();
}

enum LogLevel { debug, info, warning, error }

/// A span opened through ObserveContext.span. Implemented by the sink.
abstract interface class SpanHandle {
  void setAttribute(String key, Object? value);
  void end();
}

/// The only sinks an observer can reach (Spec §3.7): no publish, no bus.
abstract interface class ObserveContext {
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  });
  void metric(
    String name,
    double value, {
    Map<String, String> tags = const <String, String>{},
  });

  /// [links] are ids of published envelopes whose spans this span links to,
  /// the causation link of Guide §8.2; the sink maps an id to its span.
  SpanHandle span(
    String name, {
    Map<String, Object?> attributes = const <String, Object?>{},
    List<String> links = const <String>[],
  });
}

/// A bus-level observer (Spec §3.7, §9.1). Implemented by applications and
/// by the runtime's telemetry observer.
abstract interface class BusObserver {
  Set<ObserverCapability> get capabilities;
  void onPublish(
    TopicRef topic,
    MessageEnvelope<Object?> envelope,
    ObserveContext context,
  );
}
```

`packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart` becomes (files in path order, names ascending; exactly the Interface's 25 names):

```dart
/// The pure, effect-free core of Nidana Bus on Dart, which every other
/// package builds on.
library;

export 'src/topic/envelope.dart' show MessageEnvelope;
export 'src/topic/lineage.dart' show Lineage;
export 'src/topic/message_source.dart'
    show
        ExecutorSource,
        MessageSource,
        PageSource,
        ServiceSource,
        TopologySource,
        UnknownSource;
export 'src/topic/observer.dart'
    show BusObserver, LogLevel, ObserveContext, ObserverCapability, SpanHandle;
export 'src/topic/redacted_payload.dart' show RedactedPayload;
export 'src/topic/scope.dart' show Scope;
export 'src/topic/topic.dart'
    show
        Dedup,
        EventTopic,
        MultiWriterTopic,
        ReplayTopic,
        StateTopic,
        Topic,
        TopicRef,
        TopicVariant,
        Tracing,
        isWellFormedTopicName;
```

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the replay**

Run: `fvm dart format packages/nidana_dart_contracts`
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+11: All tests passed!`
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model --set structure,surface,reject; echo "exit: $?"`
Expected: `exit: 0`; 17 `PASS structure`, 3 `PASS surface` and 10 `PASS reject` lines, then `30 fixtures: 30 passed, 0 failed, 0 pending` (T3.4). A FAIL is a stop: see Global Constraints, Contract gaps.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topic/message_source.dart packages/nidana_dart_contracts/lib/src/topic/envelope.dart packages/nidana_dart_contracts/lib/src/topic/lineage.dart packages/nidana_dart_contracts/lib/src/topic/redacted_payload.dart packages/nidana_dart_contracts/lib/src/topic/observer.dart packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart packages/nidana_dart_contracts/test/declarations_test.dart
git commit -m "feat(dart_contracts): declare sources, envelopes, lineage, redaction and observers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.3.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.3.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 3; the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model --set structure,surface,reject) > "${TMPDIR:-/tmp}/nidana.model.3-gate.txt" 2>&1; echo "exit: $?"`, then read the file.
Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+11: All tests passed!` and `30 fixtures: 30 passed, 0 failed, 0 pending` (G). Take the date with `date -u +%Y-%m-%d`. A failure stops here: it is fixed in the task that owns the code, never by editing `hsdd/`; a fixture that fails against a declaration matching its block is a contract gap (Global Constraints).

- [ ] **Step 2: Run the checklist**

Run each and keep its output:
- `grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?"` (expected: no line, `exit: 1`): no code outside the package reaches a declaration except through the main library.
- `sed -n '/^export/,$p' packages/nidana_dart_contracts/lib/nidana_dart_contracts.dart | tr -s ' ,;\n' '\n\n\n\n' | grep -E '^[A-Za-z]+$' | grep -vxE 'export|show' | LC_ALL=C sort | tr '\n' ' '` (expected, the Interface's 25 names and no other: `BusObserver Dedup EventTopic ExecutorSource Lineage LogLevel MessageEnvelope MessageSource MultiWriterTopic ObserveContext ObserverCapability PageSource RedactedPayload ReplayTopic Scope ServiceSource SpanHandle StateTopic Topic TopicRef TopicVariant TopologySource Tracing UnknownSource isWellFormedTopicName`).
- `grep -rn "dispatcher" packages/nidana_dart_contracts/lib; echo "exit: $?"` (expected: no line, `exit: 1`): no topic declaration takes a dispatcher hint (G5, which decides OQ-M3).
- `git status --short pubspec.lock` (expected: no output).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.3.verification.md` at gate-only depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.3 - topic-model@v1 declarations` (a spaced hyphen; no em-dash anywhere in the file). Slim: every section a few lines.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as the phase context writes it, which replays topic-model@v1's `structure`, `surface` and `reject` sets (no schema: a `shared-model` contract with no serialized form carries none, ADR-001 item 4).
- **Expected output:** the gate's exit 0 and the five lines of Step 1.
- **Observed:** dated; the gate's exit code and its five lines as they appeared; then a checklist of four `- [x]` lines, each with its result: the first replay of the 3 surface and 10 reject libraries against the real package passed, so every reject code the stand-in confirmed holds (none differs, no line carries two codes); the main library exports exactly the Interface's 25 names, and no code outside the package imports its `src/`; no topic constructor takes a dispatcher hint (G5, OQ-M3); `purity_test.dart` holds the package to `meta` and `test` and to no clock, timer, microtask, id or I/O (G25, G26), and the lockfile is unchanged.
- **Outstanding:** `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found three; write each that still holds, and any the gate finds:
  - `- topic-model@v1's Interface writes MessageSource's renderings with angle-bracket placeholders, which the root lint unintended_html_in_doc_comment reports, so the copy in message_source.dart puts them in backticks: dropped (an Interface text touch for hsdd-contract, routed by the orchestrator)`
  - `- nidana.model D3's final field behind every getter and throwing bodies leave RedactedPayload's private constructor unused while RedactedPayload.of throws, so the package carries one ignore of unused_element until nidana.model.8: dropped (temporary; nidana.model.8 calls the constructor)`
  - `- The phase scope says the package joins the lockfile; adding the member leaves pubspec.lock byte-identical, because a workspace lockfile records no member and already held meta and test: dropped (no gate depends on it)`
- **Metrics:** one line: the product diff (`git diff --stat` of `packages/` and the root `pubspec.yaml` from the phase's base) in lines, library and tests, beside the estimate of about 430 lines in about 8 files; the task count, 4 of the allowed 5.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.3.verification.md
git commit -m "docs(verify): nidana.model.3 verification" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
