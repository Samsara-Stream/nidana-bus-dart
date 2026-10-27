# nidana.model.8 Topic Model Values and Lineage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver every topic-model@v1 body under `packages/nidana_dart_contracts/lib/src/topic/`, so that the unrestricted replay `fvm dart run nidana_contract_check topic-model` passes all 41 behavior cases of `hsdd/contract/fixture/topic-model/behavior/topic_model_conformance.dart` (9 pass and 32 fail today) beside its surface and reject sets, and the package's own tests pin what that suite leaves open: property tests over generated lineages, and the inputs of the Review Focus.

**Architecture:** Bodies only. Every declaration, parameter, default, modifier and export nidana.model.3 landed stays as it is; the new names are private, or live in one internal library, `lib/src/topic/list_equality.dart`, which the main library does not export. Each value compares by exactly the fields its guarantee names, in its own class or in its sealed base (`Topic<T>`, `MessageSource`), and hashes those fields with `Object.hash`, a list with `Object.hashAll`. The lineage rules are static pure functions over `Lineage` values built through one private constructor. The tasks go from leaves to dependents: topics; sources, scopes, capabilities and redacted payloads; lineage values with the envelope's parent copy; `Lineage.combine`; envelopes, which render through `RedactedPayload` and publish through `Lineage`.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:meta` 1.19.0 (`@immutable`), the package's only dependency; `package:test` for the package's tests, with `dart:math`'s `Random` for the property tests; the replay tool `nidana_contract_check` with its `behavior` set (nidana.model.6).

**Spec:** `hsdd-context/superpowers/nidana.model.8.md` (the derivative; the phase context with topic-model@v1's whole Interface and Guarantees sits between its markers). The dartdoc and trailing comments below come from topic-model@v1's Interface, `hsdd/contract/topic-model.md` lines 45 to 389. Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D3 (line 102), D4 (line 112), D5 (line 128) and D6 (line 135; `test/purity_test.dart` scans every library under `lib/` for banned imports and for the tokens `DateTime.now(`, `Stopwatch(`, `Timer(`, `Timer.periodic(`, `scheduleMicrotask(`, `Future.delayed(`, `Future.microtask(`, `Random(` and `Zone.`, as substrings, comments included). The fixtures the gate replays: `hsdd/contract/fixture/topic-model/` (`surface/`, `reject/`, and `behavior/` through the binding `nidana_dart_contracts_test.dart`), under `hsdd/contract/fixture/analysis_options.yaml`. Evidence: `docs/auto-run/experiments/topic-model-values-plan/` (`run.sh`, `output.txt`, `facts/`, `probe/`, `draft/`), a dry run of this plan's tasks in a temporary copy of HEAD `6dddef2`; labels such as F, A, T1.2, G, C or D below name the steps of its `output.txt`. `draft/` is evidence, not code to copy: the blocks below are the source, and each is the formatter-stable text of a draft file or part of one (X).

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 7 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl topology-ir --set structure,surface,reject,schema` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.8.verification.md from
   hsdd/templates/verification.md at spot-check depth, fills every section
   the template asks for at that depth, writes "- none" or dispositioned
   entries under Learnings, and leaves Sign-off for a human reviewer.
6. Nothing under hsdd/ changes except that verification doc. Contracts, ADRs,
   specs and conventions change only through hsdd-contract, hsdd-adr and
   hsdd-reconcile.
7. Build against the Interface and Guarantees in the Contracts section below
   (if any), never against another node's internals.
8. Review tier spot-check: design notes only for a decision this phase actually settles; short verification doc.

Project-wide requirements from the spec and the run, which every task's requirements include:

- **Toolchain:** `fvm dart` only, every command from the repository root, no global tooling. No dependency changes: no `pubspec.yaml` is edited and `pubspec.lock` stays byte-identical (C). The property tests need no package: ADR-002 item 3's table gives `nidana_dart_contracts` `meta` and `test` alone, and they draw from `dart:math`'s `Random(seed)` under `test/`, which `purity_test.dart` does not scan (D6 scans `lib/`).
- **Files:** under `lib/` this phase edits the seven libraries of `lib/src/topic/` and creates `lib/src/topic/list_equality.dart`; no other library changes, and the three public libraries' export lists stay exactly as `test/exports_test.dart` pins them. Under `test/` it creates six files and edits none. It edits one sentence of `README.md` (Task 4); `CHANGELOG.md` and `LICENSE` stay as nidana.model.3 wrote them (D4). Nothing under `hsdd/` changes except the verification doc of Task 6.
- **Interface:** every public name, signature, parameter name, default, modifier, annotation and `const` stays as topic-model@v1 states it and nidana.model.3 landed it; every getter that returns a stored value stays a final field (the reject codes of G4 depend on it, D3). New members are private (`StateTopic._constant`, `StateTopic._factory`, `Lineage._`, the top-level `_segment`) or the one function `elementsEqual` of `list_equality.dart`. No class gains a public member the Interface does not declare: no `toString` on `Topic`, `TopicRef` or `Lineage`.
- **Comments:** the Interface's dartdoc is copied as written and stays where nidana.model.3 put it. The Interface's trailing comments that nidana.model.3 dropped come back: `// T` after `valueType`, and `// non-empty` after each of the four source constructors' parameter lists. The Interface's trailing comments on `==`, `hashCode` and `toString` go on a `//` line directly above the member's `@override` (Topic: `// same variant, name and valueType (G7)`; TopicRef: `// all three fields`; Lineage: `// all four fields; parents element-wise`; MessageEnvelope: `// all eight fields; parents element-wise`; RedactedPayload: `// typeName and hash`, and `// '<redacted {typeName} #{hash}>'` above its `toString`), and MessageEnvelope's dartdoc `/// Renders a sensitive payload redacted (G15).` above its `toString`'s `@override`. A trailing comment the formatter would split moves to the line above, as nidana.model.5 placed its long ones: `Topic.ref`'s, and the envelope constructor's `// copied, unmodifiable`, which the formatter otherwise breaks over two lines (the dry run's first draft). MessageSource's class dartdoc keeps its four angle-bracket renderings in backticks (the root lint set's `unintended_html_in_doc_comment`). No word of `lib/` may contain a D6 token, in code or comment. No em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.
- **Hash codes (F):** `Object.hash`, `Object.hashAll` and an enum value's `hashCode` change from run to run (F, the four lines that differ between two runs); `String`, `int`, `Type` and `DateTime` hash codes did not, but nothing guarantees it. No test pins a hash code literal, except the hexadecimal digits `RedactedPayload.of` takes from a payload class whose own `hashCode` returns a constant. `Object.hash` of a `List` hashes the list's identity, so two equal lists hash apart (F L2), while `Object.hashAll` hashes the elements (F L3): hash `parentCorrelationIds` with `Object.hashAll`, never as an argument of `Object.hash` itself.
- **Const collections (A0, A):** once a class overrides `==`, a non-empty const set of its values, or a const map keyed by them, does not compile: `const_set_element_not_primitive_equality` and `const_map_key_not_primitive_equality`, also inside an implicit const context such as a set in a const list (probe line 44). A const list of them, a const map whose values they are, an empty const set and a constant pattern in a switch stay legal (probe, no diagnostic). The same probe compiles cleanly against the committed declarations (A0). The 84 committed Dart libraries under every slug's `surface/`, `reject/` and `behavior/` report exactly the same diagnostics before and after this phase's bodies (3143 in 70 of them, most of them the absent packages of other nodes), none of them a const-collection code, and a text search of the package and every fixture finds no such literal (B, A). No test of this phase writes one.
- **Analyzer:** `fvm dart analyze --fatal-infos` at the root reports nothing after every task. This phase removes the package's `// ignore: unused_element` above `RedactedPayload._` with its reason line (Task 2), and leaves nidana.model.4's and nidana.model.5's. Lints the dry run met: `prefer_initializing_formals` reports a private field named after a parameter (`_initial = initial`), hence `_constant`; `equal_elements_in_set` reports two equal const elements in one set literal, and `prefer_collection_literals` reports `[...].toSet()`; `hash_and_equals` reports an `==` without its `hashCode` (D1). The root lint set also holds `use_null_aware_elements`; the drafts write the null-aware `?` element where a nullable value enters a collection.
- **Tests:** run from the root as `fvm dart test packages/nidana_dart_contracts`. Each task's failing step also replays the conformance cases of its guarantees, `fvm dart run nidana_contract_check topic-model --set behavior --guarantee {ids}`, which runs the committed binding under `dart test` and starts no `flutter`; no test of this phase starts `flutter` either. The package's tests do not repeat the suite's cases; they pin what the suite leaves open. Add a test beyond the plan's wherever a rule you implement would otherwise go unpinned. No test uses a `test` API newer than 1.31.1.
- **Contract gaps (ADR-001 item 8):** the dry run passes every committed fixture of topic-model@v1, topology-dsl@v2 and topology-ir@v1 against this plan's code (T5.4, G). A conformance case, surface or reject library that fails against code that follows this plan is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the case or library, what it reports, the guarantee, and the fix you would propose.
- **Formatting and commits:** run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output; it reports `0 changed` when they are copied exactly). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for a Sonnet implementer.

## Review Focus

The input classes the spec implies but the conformance suite does not exercise, most likely to bite first; each has its test in the owning task.

1. **Equal values built apart, as set elements and map keys:** the recording builder checks one sink per state topic by topic equality (nidana.model.9), observers and recorders collect sources and envelopes in sets (bus-api@v2's suite compares a `Set<MessageSource>`), and an envelope reaches an observer widened to `MessageEnvelope<Object?>`. The suite compares pairs by `==` and hash code and never puts a value in a set or a map. Expected: equal topics, references, sources, lineages, redacted payloads and envelopes built apart from non-const arguments collapse to one set element or map key, and an envelope equals its widened twin. Tests: Task 1 (topics, references), Task 2 (sources, redacted payloads), Task 3 (lineages), Task 5 (envelopes, widened).
2. **A state topic whose value type is nullable, declared with a null initial value:** `StateTopic<User?>` that starts with no user is common. Expected: `createInitial()` returns null, for the constant and for the computed form; a store that reads `_constant ?? _factory!()` throws instead (D2). Test: Task 1.
3. **A topic name with a trailing newline, a tab, inner white space or a non-ASCII letter:** names come from generated registries and hand-typed strings. Expected: not well formed. The suite's G11 cases still pass when the pattern runs once over the whole name with `multiLine: true`, which accepts `'auth.state\n'` (D3); a pattern per segment, anchored without `multiLine`, rejects it (F R2). Test: Task 1.
4. **Source text that is padded, has colons in its field, or names the right variant in the wrong case:** telemetry and recorded logs carry sources as text. Expected: `tryParse` splits at the first colon only and keeps the rest of the text as the field, white space and colons included (`'executor::'` is `ExecutorSource(':')`), and returns null for `' service:a'`, `'service :a'`, `'unknown '` and `'UNKNOWN'`. Test: Task 2.
5. **A sensitive envelope of any payload shape, rendered after `redacted()` as well:** an audit observer logs `envelope.redacted().toString()` (topic-model@v1's surface `observers.dart`). The suite renders one sensitive envelope with a class payload. Expected: a class, a `String`, a `List` and a `Map` payload never appear in the rendering, before or after `redacted()`. Test: Task 5.

## Routed items

Each item routed to this phase (`docs/auto-run/impl-execution-plan.md`, "Routed to later phases"; `docs/auto-run/steps/S106.json`), with its disposition:

- Restore the Interface's dropped trailing comments (`// T` on `valueType`, the four `// non-empty`): Task 1 (`// T`), Task 2 (`// non-empty`).
- Carry the Interface's dartdoc and trailing comments onto `==`, `hashCode` and `toString`: Task 1 (Topic, TopicRef), Task 2 (RedactedPayload), Task 3 (Lineage), Task 5 (MessageEnvelope), placed as Global Constraints, Comments, states.
- `envelope.dart` copies where the comment says `// copied, unmodifiable`: Task 3, `List<String>.unmodifiable` in the constructor's initializer list.
- A private `Lineage` constructor for `combine` and `withLatestFrom`: Task 3 (`const Lineage._`), used by `withLatestFrom` there and by `combine` in Task 4.
- Store `initial` under both const `StateTopic` constructors: Task 1 (`_constant` and `_factory`).
- Correct the README's "Everything here is a value or a total function": Task 4 Step 3, exact text given.
- A one-line test that non-default `dedup` and `tracing` reach their fields: Task 1, the first test of `topic_test.dart` (it passes before the bodies land: it pins nidana.model.3's declarations).
- Remove the `// ignore: unused_element` on `RedactedPayload._` once `RedactedPayload.of` calls it: Task 2.
- Keep the backticks around the angle-bracket renderings: Task 2 leaves MessageSource's class dartdoc as it is (Global Constraints, Comments).
- Const collections (the "Consumer nodes" entry): checked by the dry run. No committed fixture of any slug, no library of the package and no test holds a non-empty const set of, or a const map keyed by, these values (A), so there is no contract gap; Task 6 records the rule for consumer plans as a Learning.

## Which task turns which failing case green

The binding passes 9 of its 41 cases today (S1): two of G6, one each of G7, G10, G11, G13, G17 and G18, and G27, which hold on nidana.model.3's declarations (defaults, asserts, identity on const canonicalized values). The other 32, by the task whose code turns each green; every task's last step replays its own ids:

| Task | Cases (by guarantee: count) | Replay |
|------|-----------------------------|--------|
| 1 | G7: 1, G8: 2, G9: 2, G11: 2 | `--guarantee G7,G8,G9,G11` goes from 2 passed, 7 failed to 9 passed (T1.2, T1.4) |
| 2 | G17: 3, G21: 1, G23: 1, G24: 2 | `--guarantee G17,G21,G23,G24` goes from 1 passed, 7 failed to 8 passed (T2.2, T2.4) |
| 3 | G4: 1 (the envelope's copy), G18: 1 (`causedBy`), G20: 1 | `--guarantee G4,G18,G20` goes from 1 passed, 4 failed to 4 passed, 1 failed; the one left is Task 4's (T3.2, T3.4) |
| 4 | G4: 1 (a lineage's parents, through `combine`), G19: 7, Spec §2.4's two worked examples among them | `--guarantee G4,G19` goes from 1 passed, 8 failed to 9 passed (T4.2, T4.4) |
| 5 | G13: 1, G14: 3, G15: 3 | `--guarantee G13,G14,G15` goes from 1 passed, 7 failed to 8 passed; then the unrestricted replay passes all 41 (T5.2, T5.4) |

Spec §2.4's worked examples are the cases `G19 a same-correlation combine keeps the correlation and takes the trigger as cause` (`sess-42` kept, cause `e-02`, no fresh id) and `G19 a cross-correlation combine takes one fresh correlation and records the inputs` (one fresh id, parents `pref-update-5` and `market-feed-9`). A sensitive envelope that never renders its payload is `G15 a sensitive envelope renders its payload redacted`, and Task 5's test over four payload shapes.

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/topic/topic.dart` | 1 | Topic equality, `ref`, initial values, `TopicRef` equality, `isWellFormedTopicName` |
| `{pkg}/test/topic_test.dart` | 1 | Topics, references and names beyond the suite |
| `{pkg}/lib/src/topic/message_source.dart` | 2 | The renderings, `tryParse`, source equality |
| `{pkg}/lib/src/topic/scope.dart` | 2 | `Scope.isAtLeastAsLongAs` |
| `{pkg}/lib/src/topic/observer.dart` | 2 | `ObserverCapability.permits` |
| `{pkg}/lib/src/topic/redacted_payload.dart` | 2 | `RedactedPayload.of`, its equality and rendering |
| `{pkg}/test/message_source_test.dart` | 2 | Sources beyond the suite |
| `{pkg}/test/redacted_payload_test.dart` | 2 | Redacted payloads beyond the suite |
| `{pkg}/lib/src/topic/list_equality.dart` | 3 | `elementsEqual`, the element-wise comparison of parent correlation ids; not exported |
| `{pkg}/lib/src/topic/lineage.dart` | 3, 4 | The private constructor, `causedBy`, `withLatestFrom`, equality (3); `combine` (4) |
| `{pkg}/lib/src/topic/envelope.dart` | 3, 5 | The constructor's unmodifiable copy (3); `publishedTo`, `redacted()`, equality, the redacting `toString()` (5) |
| `{pkg}/test/lineage_test.dart` | 3 | Lineage values beyond the suite |
| `{pkg}/test/lineage_property_test.dart` | 4 | Property tests of `combine` and `withLatestFrom` over generated lineages |
| `{pkg}/README.md` | 4 | One corrected sentence |
| `{pkg}/test/envelope_test.dart` | 5 | Envelopes beyond the suite |
| `hsdd/verify/nidana.model.8.verification.md` | 6 | The verification doc |

---

### Task 1: Topics, topic references and names

You are filling in the bodies of `lib/src/topic/topic.dart` in `packages/nidana_dart_contracts`, whose declarations nidana.model.3 landed with bodies that throw `UnimplementedError` and `Object`'s `==` (nidana.model D3). Run every command from the repository root with `fvm dart`. Change no declaration (Global Constraints, Interface). This task turns seven conformance cases green: G7 (1), G8 (2), G9 (2) and G11 (2).

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topic/topic.dart`
- Create: `packages/nidana_dart_contracts/test/topic_test.dart`

**Interfaces:**
- Consumes: the declarations of `topic.dart` (nidana.model.3).
- Produces: `Topic<T>.operator ==` and `Topic<T>.hashCode` (variant, name and `valueType`, G7), `Topic<T>.ref`, `TopicRef.operator ==` and `TopicRef.hashCode` (name, variant and `typeName`, G8), `StateTopic<T>.createInitial()` (G9) and `bool isWellFormedTopicName(String name)` (G11). Later tasks and nidana.model.9 and nidana.model.10 compare topics and references by these.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/topic_test.dart`:

```dart
// topic-model@v1's topics, topic references and topic names, beyond the
// cases of its conformance suite, which the gate replays
// (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('non-default dedup, sensitive and tracing reach their fields', () {
    final List<Topic<int>> topics = <Topic<int>>[
      const StateTopic<int>(
        name: 'a.count',
        initial: 0,
        dedup: Dedup.none,
        sensitive: true,
        tracing: Tracing.disabled,
      ),
      StateTopic<int>.computed(
        name: 'a.count',
        initial: () => 0,
        dedup: Dedup.none,
        sensitive: true,
        tracing: Tracing.disabled,
      ),
      const EventTopic<int>(
        name: 'a.tapped',
        sensitive: true,
        tracing: Tracing.disabled,
      ),
      const ReplayTopic<int>(
        name: 'a.log',
        bufferSize: 2,
        sensitive: true,
        tracing: Tracing.disabled,
      ),
    ];
    for (final Topic<int> topic in topics) {
      expect(topic.sensitive, isTrue);
      expect(topic.tracing, Tracing.disabled);
      if (topic is StateTopic<int>) {
        expect(topic.dedup, Dedup.none);
      }
    }
  });

  test('G9 a nullable value type keeps a null initial value, constant or '
      'computed', () {
    const StateTopic<String?> constant = StateTopic<String?>(
      name: 'a.draft',
      initial: null,
    );
    final StateTopic<String?> computed = StateTopic<String?>.computed(
      name: 'a.draft',
      initial: () => null,
    );
    expect(constant.createInitial(), isNull);
    expect(computed.createInitial(), isNull);
  });

  test('G7 G8 equal topics and references built apart are one set element '
      'and one map key', () {
    final String name = <String>['a.count'].single;
    final Set<Topic<Object?>> topics = <Topic<Object?>>{
      StateTopic<int>(name: name, initial: 0),
      StateTopic<int>(name: name, initial: 1, dedup: Dedup.none),
      StateTopic<int?>(name: name, initial: 0),
      EventTopic<int>(name: name),
    };
    expect(topics, hasLength(3));
    final Map<TopicRef, String> owners = <TopicRef, String>{
      StateTopic<int>(name: name, initial: 0).ref: 'first',
    };
    owners[StateTopic<int>(name: name, initial: 2, sensitive: true).ref] =
        'second';
    expect(owners, <TopicRef, String>{
      TopicRef(name: name, variant: TopicVariant.state, typeName: 'int'):
          'second',
    });
  });

  test('G8 a reference names a nested value type as its type argument '
      'reads', () {
    final StateTopic<Map<String, List<int>?>> index =
        StateTopic<Map<String, List<int>?>>(
          name: 'a.index',
          initial: const <String, List<int>?>{},
        );
    expect(index.ref.typeName, 'Map<String, List<int>?>');
    expect(index.ref.typeName, '${index.valueType}');
  });

  test('G11 a name with a trailing newline, a non-ASCII letter or inner '
      'white space is not well formed', () {
    for (final String name in <String>[
      'auth.state\n',
      'auth.state\t',
      'auth.ståte',
      'auth.st ate',
      ' auth.state',
      'auth.STATE',
      'auth.-',
      'a.b.c.d',
    ]) {
      expect(isWellFormedTopicName(name), isFalse, reason: name);
    }
    for (final String name in <String>[
      'a.b',
      'a.b.c',
      'a1.b2-c3',
      'auth.v-2',
    ]) {
      expect(isWellFormedTopicName(name), isTrue, reason: name);
    }
  });
}
```

- [ ] **Step 2: Run it and the replay of G7, G8, G9 and G11, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/topic_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+1 -4: Some tests failed.`: the four tests named `G9 ...`, `G7 G8 ...`, `G8 ...` and `G11 ...` fail, on `UnimplementedError` and on `Expected: an object with length of <3>` with `Which: has length of <4>` (identity equality); `non-default dedup, sensitive and tracing reach their fields` passes, since it pins what nidana.model.3 landed (T1.2).
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G7,G8,G9,G11; echo "exit: $?"`
Expected: `exit: 1`; 17 `PASS structure` lines, then `FAIL behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: cases (2 passed, 7 failed, 0 skipped under dart test, restricted to topic-model G7 to G9, G11)` with seven `failed-case` names, and `18 fixtures: 17 passed, 1 failed, 0 pending` (T1.2).

- [ ] **Step 3: Implement the bodies of `topic.dart`**

- `StateTopic<T>` keeps its initial value in two private final fields, `final T? _constant;` and `final T Function()? _factory;`, which each const constructor sets in its initializer list; `createInitial()` calls `_factory` when it is set and returns `_constant as T` otherwise. Not `_constant ?? _factory!()`, which throws for a nullable `T` declared with `initial: null` (D2), and not a field named `_initial`, which the root lint set's `prefer_initializing_formals` reports. The class from its first constructor to `createInitial`:

```dart
  /// A constant initial value (Spec §2.5 "Allowed: constant").
  const StateTopic({
    required super.name,
    required T initial,
    this.dedup = Dedup.equality,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : _constant = initial,
       _factory = null,
       super._();

  /// A pure factory (Spec §2.5 "Allowed: pure factory"), never called at
  /// construction. When the bus calls createInitial() is bus-api@v2's.
  const StateTopic.computed({
    required super.name,
    required T Function() initial,
    this.dedup = Dedup.equality,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : _constant = null,
       _factory = initial,
       super._();

  final Dedup dedup;

  // The declared constant, when _factory is null.
  final T? _constant;
  final T Function()? _factory;

  @override
  TopicVariant get variant => TopicVariant.state;

  /// The declared value, or the factory's result for this call (G9).
  T createInitial() {
    final T Function()? factory = _factory;
    return factory == null ? _constant as T : factory();
  }
```

- `Topic<T>` declares `==` and `hashCode` once, in the sealed base, for its three variants: `other` is a `Topic<Object?>` with equal `variant`, `name` and `valueType`, and `Object.hash(variant, name, valueType)`. `ref` returns `TopicRef(name: name, variant: variant, typeName: '$T')`, with the Interface's comment `// TopicRef(name, variant, typeName: '$T')` on the line above it; `valueType` gets its trailing `// T` back.
- `TopicRef` compares and hashes `name`, `variant` and `typeName`.
- `isWellFormedTopicName` splits `name` at `'.'` and holds when there are two or three segments and every one matches a private top-level `final RegExp _segment = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$');`, without `multiLine`: Dart's `$` then matches only at the end of the input, never before a trailing newline (F R2), and `''.split('.')` is one empty segment (F R4).
- Comments as Global Constraints, Comments, states for `Topic` and `TopicRef`.

- [ ] **Step 4: Run the formatter, the tests, the analyzer and the replay**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted 31 files (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+43: All tests passed!` (T1.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G7,G8,G9,G11; echo "exit: $?"`
Expected: `exit: 0`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 9 passed, 0 failed, 0 skipped under dart test, restricted to topic-model G7 to G9, G11` and `18 fixtures: 18 passed, 0 failed, 0 pending` (T1.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topic/topic.dart packages/nidana_dart_contracts/test/topic_test.dart
git commit -m "feat(dart_contracts): compare topics and references, keep initial values, check topic names" -m "<the co-author trailer your harness gives>"
```

### Task 2: Sources, scopes, capabilities and redacted payloads

You are filling in the bodies of four libraries of `packages/nidana_dart_contracts/lib/src/topic/`: `message_source.dart`, `scope.dart`, `observer.dart` and `redacted_payload.dart`, whose declarations nidana.model.3 landed. Run every command from the repository root with `fvm dart`. Change no declaration. This task turns seven conformance cases green: G17 (3), G21 (1), G23 (1) and G24 (2).

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topic/message_source.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topic/scope.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topic/observer.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topic/redacted_payload.dart`
- Create: `packages/nidana_dart_contracts/test/message_source_test.dart`
- Create: `packages/nidana_dart_contracts/test/redacted_payload_test.dart`

**Interfaces:**
- Consumes: the declarations of the four libraries (nidana.model.3).
- Produces: `MessageSource.toString()` (`topology:{id}`, `service:{name}`, `page:{route}`, `executor:{name}`, `unknown`), `static MessageSource? MessageSource.tryParse(String text)`, `MessageSource.operator ==` and `hashCode`; `bool Scope.isAtLeastAsLongAs(Scope other)`; `static bool ObserverCapability.permits(Set<ObserverCapability> capabilities, {required bool sensitive})`; `factory RedactedPayload.of(Object? payload)`, `RedactedPayload.operator ==`, `hashCode` and `toString()` (`<redacted {typeName} #{hash}>`). Task 5 renders and redacts sensitive payloads with `RedactedPayload.of`.

- [ ] **Step 1: Write the failing tests**

Create `packages/nidana_dart_contracts/test/message_source_test.dart`:

```dart
// topic-model@v1's message sources, beyond the cases of its conformance
// suite, which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('G17 tryParse splits at the first colon and keeps all the rest, '
      'white space and colons included, as the field', () {
    expect(
      MessageSource.tryParse('topology: spaced'),
      const TopologySource(' spaced'),
    );
    expect(MessageSource.tryParse('executor::'), const ExecutorSource(':'));
    expect(MessageSource.tryParse('service:a:b'), const ServiceSource('a:b'));
  });

  test('G17 tryParse returns null for padded, misspelt or truncated '
      'renderings', () {
    for (final String text in <String>[
      ' service:a',
      'service :a',
      'unknown ',
      'UNKNOWN',
      'page',
      'executor:',
      'topology',
    ]) {
      expect(MessageSource.tryParse(text), isNull, reason: text);
    }
  });

  test('G17 sources built apart are one set element per variant and '
      'field', () {
    final String name = <String>['auth'].single;
    final Set<MessageSource> sources = <MessageSource>{
      ServiceSource(name),
      ServiceSource(name),
      ExecutorSource(name),
      PageSource(name),
      TopologySource(name),
      const UnknownSource(),
      UnknownSource(),
    };
    expect(sources, hasLength(5));
    expect(ServiceSource(name).hashCode, const ServiceSource('auth').hashCode);
  });
}
```

Create `packages/nidana_dart_contracts/test/redacted_payload_test.dart`:

```dart
// topic-model@v1's redacted payloads, beyond the cases of its conformance
// suite, which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

/// A payload whose hash code is wider than 32 bits.
final class _Wide {
  const _Wide();
  @override
  bool operator ==(Object other) => other is _Wide;
  @override
  int get hashCode => 0x71234abcd;
}

void main() {
  test('G24 the hash keeps the low 32 bits of a hash code wider than 32 '
      'bits', () {
    expect(RedactedPayload.of(const _Wide()).hash, '1234abcd');
  });

  test('G24 a payload of a core type redacts to its runtime type and eight '
      'lowercase hexadecimal digits', () {
    for (final Object? payload in <Object?>[
      'card-4242-4242',
      42,
      <int>[1, 2],
      <String, String>{'token': 'tok-secret'},
      null,
    ]) {
      final RedactedPayload redacted = RedactedPayload.of(payload);
      expect(redacted.typeName, payload.runtimeType.toString());
      expect(redacted.hash, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(
        redacted.toString(),
        '<redacted ${redacted.typeName} #${redacted.hash}>',
      );
    }
    expect(RedactedPayload.of('card-4242-4242').typeName, 'String');
    expect(
      RedactedPayload.of(<String, String>{'token': 'tok-secret'}).toString(),
      isNot(contains('tok-secret')),
    );
  });

  test('G24 redacted payloads of equal payloads are one set element', () {
    final String card = <String>['card-4242-4242'].single;
    expect(<RedactedPayload>{
      RedactedPayload.of(card),
      RedactedPayload.of(card),
      RedactedPayload.of('other'),
    }, hasLength(2));
  });
}
```

G21 and G23 get no package test: the suite's cases check `isAtLeastAsLongAs` over all nine pairs of scopes and `permits` over all four capability sets in both modes.

- [ ] **Step 2: Run them and the replay of G17, G21, G23 and G24, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/message_source_test.dart packages/nidana_dart_contracts/test/redacted_payload_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+0 -6: Some tests failed.`: every test fails, on `UnimplementedError` and on `Expected: an object with length of <5>` with `Which: has length of <7>` (T2.2).
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G17,G21,G23,G24; echo "exit: $?"`
Expected: `exit: 1`; `FAIL behavior ...nidana_dart_contracts_test.dart: cases (1 passed, 7 failed, 0 skipped under dart test, restricted to topic-model G17, G21, G23, G24)` with seven `failed-case` names, and `18 fixtures: 17 passed, 1 failed, 0 pending` (T2.2).

- [ ] **Step 3: Implement the bodies of the four libraries**

- `message_source.dart`: the sealed base renders every variant with one exhaustive switch, and compares and hashes sources by that rendering. The rendering names the variant before its first colon and the field after it, and `tryParse` is its inverse (G17), so two sources render alike exactly when their variant and field are equal. The base from its private constructor to `hashCode`:

```dart
  const MessageSource._();

  /// The inverse of toString(); null for any other text (G17).
  static MessageSource? tryParse(String text) {
    if (text == 'unknown') {
      return const UnknownSource();
    }
    final int colon = text.indexOf(':');
    if (colon < 0 || colon == text.length - 1) {
      return null;
    }
    final String field = text.substring(colon + 1);
    return switch (text.substring(0, colon)) {
      'topology' => TopologySource(field),
      'service' => ServiceSource(field),
      'page' => PageSource(field),
      'executor' => ExecutorSource(field),
      _ => null,
    };
  }

  @override
  String toString() => switch (this) {
    TopologySource(:final String topologyId) => 'topology:$topologyId',
    ServiceSource(:final String name) => 'service:$name',
    PageSource(:final String route) => 'page:$route',
    ExecutorSource(:final String name) => 'executor:$name',
    UnknownSource() => 'unknown',
  };

  // Equal exactly when variant and field are (G17): the rendering names the
  // variant before its first colon and the field after it.
  @override
  bool operator ==(Object other) =>
      other is MessageSource && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}
```

  Each of the four variants with a field gets its Interface comment back after its parameter list, as the formatter keeps it:

```dart
final class TopologySource extends MessageSource {
  const TopologySource(this.topologyId) // non-empty
    : assert(topologyId != '', 'topologyId must not be empty'),
      super._();

  final String topologyId;
}
```

  The class dartdoc keeps its backticks. The other three constructors take `// non-empty` the same way.
- `scope.dart`: `isAtLeastAsLongAs` is `index <= other.index` (G21: the declaration order is the lifetime order).
- `observer.dart`: `permits` is `capabilities.contains(sensitive ? observeSensitive : observeAll)` (G23).
- `redacted_payload.dart`: delete the two lines above `const RedactedPayload._` (the reason comment and `// ignore: unused_element`). `RedactedPayload.of` returns `RedactedPayload._(payload.runtimeType.toString(), payload.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0'))`: the low 32 bits as eight lowercase hexadecimal digits, `ffffffff` for a hash code of -1 and `1234abcd` for `0x71234abcd` (F X). `==` and `hashCode` cover `typeName` and `hash` (`Object.hash(typeName, hash)`); `toString()` is `'<redacted $typeName #$hash>'`. Comments as Global Constraints, Comments, states.

- [ ] **Step 4: Run the formatter, the tests, the analyzer and the replay**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted 33 files (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+49: All tests passed!` (T2.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G17,G21,G23,G24; echo "exit: $?"`
Expected: `exit: 0`, `PASS behavior ...nidana_dart_contracts_test.dart: 8 passed, 0 failed, 0 skipped under dart test, restricted to topic-model G17, G21, G23, G24` and `18 fixtures: 18 passed, 0 failed, 0 pending` (T2.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topic/message_source.dart packages/nidana_dart_contracts/lib/src/topic/scope.dart packages/nidana_dart_contracts/lib/src/topic/observer.dart packages/nidana_dart_contracts/lib/src/topic/redacted_payload.dart packages/nidana_dart_contracts/test/message_source_test.dart packages/nidana_dart_contracts/test/redacted_payload_test.dart
git commit -m "feat(dart_contracts): render and parse sources, order scopes, admit observers, redact payloads" -m "<the co-author trailer your harness gives>"
```

### Task 3: Lineage values and the envelope's parent copy

You are filling in `Lineage.causedBy`, `Lineage.withLatestFrom` and lineage equality in `packages/nidana_dart_contracts/lib/src/topic/lineage.dart`, adding the internal library `lib/src/topic/list_equality.dart`, and making `MessageEnvelope`'s constructor keep an unmodifiable copy of its parent correlation ids, in `lib/src/topic/envelope.dart`. `Lineage.combine` keeps throwing until Task 4; every other envelope body stays as it is until Task 5. Run every command from the repository root with `fvm dart`. This task turns three conformance cases green: G4's envelope case, G18's `causedBy` case and G20.

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/topic/list_equality.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topic/lineage.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topic/envelope.dart` (the unnamed constructor only)
- Create: `packages/nidana_dart_contracts/test/lineage_test.dart`

**Interfaces:**
- Consumes: `MessageEnvelope`'s fields (nidana.model.3).
- Produces: `bool elementsEqual(List<Object?> a, List<Object?> b)` in `list_equality.dart`, which Task 5's envelope equality also uses and the main library does not export; `const Lineage._({required String? causationId, required String? correlationId, required List<String> parentCorrelationIds, required bool sensitive})`, whose callers pass an unmodifiable list, and which Task 4's `combine` builds through; `Lineage.causedBy`, `Lineage.withLatestFrom`, `Lineage.operator ==` and `hashCode`; `MessageEnvelope.parentCorrelationIds`, an unmodifiable copy (G4).

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/lineage_test.dart`:

```dart
// topic-model@v1's lineage values, beyond the cases of its conformance
// suite, which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

MessageEnvelope<int> envelope({
  String id = 'e-1',
  String correlationId = 'c-1',
  List<String> parents = const <String>[],
  bool sensitive = false,
}) => MessageEnvelope<int>(
  id: id,
  payload: 1,
  correlationId: correlationId,
  parentCorrelationIds: parents,
  timestamp: DateTime.utc(2026, 10, 27, 12),
  source: const UnknownSource(),
  sensitive: sensitive,
);

void main() {
  test('G4 G18 a lineage caused by an envelope exposes unmodifiable '
      'parents', () {
    final Lineage lineage = Lineage.causedBy(
      envelope(parents: <String>['p-1']),
    );
    expect(lineage.parentCorrelationIds, <String>['p-1']);
    expect(
      () => lineage.parentCorrelationIds.add('p-2'),
      throwsUnsupportedError,
    );
  });

  test('lineages built apart are equal exactly when all four fields are, '
      'parents in order, and equal ones are one set element', () {
    final Lineage a = Lineage.causedBy(
      envelope(parents: <String>['p-1', 'p-2']),
    );
    final Lineage b = Lineage.causedBy(
      envelope(parents: <String>['p-1', 'p-2']),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(<Lineage>{a, b}, hasLength(1));
    for (final Lineage other in <Lineage>[
      Lineage.causedBy(envelope(id: 'e-2', parents: <String>['p-1', 'p-2'])),
      Lineage.causedBy(
        envelope(correlationId: 'c-2', parents: <String>['p-1', 'p-2']),
      ),
      Lineage.causedBy(envelope(parents: <String>['p-2', 'p-1'])),
      Lineage.causedBy(
        envelope(parents: <String>['p-1', 'p-2'], sensitive: true),
      ),
    ]) {
      expect(a == other, isFalse, reason: '${other.causationId}');
    }
    final String flow = <String>['c-1'].single;
    expect(
      Lineage.root(correlationId: flow),
      const Lineage.root(correlationId: 'c-1'),
    );
  });

  test('G20 withLatestFrom over several latest values is sensitive when '
      'any is, and keeps the primary causation, correlation and parents', () {
    final Lineage primary = Lineage.causedBy(
      envelope(id: 'e-9', correlationId: 'order-1', parents: <String>['p-1']),
    );
    final Lineage plain = Lineage.causedBy(envelope(correlationId: 'c-2'));
    final Lineage secret = Lineage.causedBy(
      envelope(correlationId: 'c-3', sensitive: true),
    );
    final Lineage out = Lineage.withLatestFrom(primary, <Lineage>[
      plain,
      plain,
      secret,
    ]);
    expect(out.causationId, 'e-9');
    expect(out.correlationId, 'order-1');
    expect(out.parentCorrelationIds, <String>['p-1']);
    expect(out.sensitive, isTrue);
    expect(Lineage.withLatestFrom(primary, <Lineage>[plain, plain]), primary);
  });
}
```

- [ ] **Step 2: Run it and the replay of G4, G18 and G20, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/lineage_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+0 -3: Some tests failed.`, every test on `UnimplementedError` from `Lineage.causedBy` (T3.2).
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G4,G18,G20; echo "exit: $?"`
Expected: `exit: 1`; `FAIL behavior ...nidana_dart_contracts_test.dart: cases (1 passed, 4 failed, 0 skipped under dart test, restricted to topic-model G4, G18, G20)` with the `failed-case` names `G4 an envelope keeps an unmodifiable copy of its parent correlation ids`, `G4 a lineage keeps unmodifiable parent correlation ids`, `G18 a lineage caused by an envelope points at it and keeps its flow` and `G20 withLatestFrom keeps the primary cause and flow and unites sensitivity`, and `18 fixtures: 17 passed, 1 failed, 0 pending` (T3.2).

- [ ] **Step 3: Implement `list_equality.dart`, the lineage values and the envelope's copy**

- `list_equality.dart`: `bool elementsEqual(List<Object?> a, List<Object?> b)`, true when both have the same length and `a[i] == b[i]` at every index, under a dartdoc that says it is the element-wise comparison of parent correlation ids that envelope and lineage equality use (G13), since a `List`'s own `==` is identity (F L1). No import.
- `lineage.dart`: `causedBy`'s initializer list takes `cause.id`, `cause.correlationId`, `cause.parentCorrelationIds` and `cause.sensitive`. It shares the envelope's list rather than copying it: that list is already the envelope's unmodifiable copy (this task's constructor change), and `MessageEnvelope` is final, so no subclass can hand over another. The private constructor sits after `causedBy`:

```dart
  // combine and withLatestFrom; parentCorrelationIds is unmodifiable.
  const Lineage._({
    required this.causationId,
    required this.correlationId,
    required this.parentCorrelationIds,
    required this.sensitive,
  });
```

  `withLatestFrom(primary, latest)` returns `Lineage._` with `primary`'s causation, correlation and parents and `sensitive: primary.sensitive || latest.any((Lineage l) => l.sensitive)` (G20). `==` compares the four fields, the parents with `elementsEqual`; `hashCode` is `Object.hash(causationId, correlationId, Object.hashAll(parentCorrelationIds), sensitive)`. `lineage.dart` imports `list_equality.dart`. `combine` still throws `UnimplementedError`.
- `envelope.dart`, the unnamed constructor alone: `parentCorrelationIds` becomes a plain named parameter with the same default, copied in the initializer list, its Interface comment on the line above (the formatter would split it as a trailing comment):

```dart
  MessageEnvelope({
    required this.id,
    required this.payload,
    required this.correlationId,
    this.causationId, // null for a root message
    // copied, unmodifiable
    List<String> parentCorrelationIds = const <String>[],
    required this.timestamp,
    required this.source,
    required this.sensitive,
  }) : parentCorrelationIds = List<String>.unmodifiable(parentCorrelationIds);
```

- [ ] **Step 4: Run the formatter, the tests, the analyzer and the replay**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted 35 files (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+52: All tests passed!` (T3.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G4,G18,G20; echo "exit: $?"`
Expected: `exit: 1`; `FAIL behavior ...: cases (4 passed, 1 failed, 0 skipped under dart test, restricted to topic-model G4, G18, G20)`, the one `failed-case` being `G4 a lineage keeps unmodifiable parent correlation ids`, which calls `Lineage.combine` (Task 4); `18 fixtures: 17 passed, 1 failed, 0 pending` (T3.4). That is this task's end state, not a gap.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topic/list_equality.dart packages/nidana_dart_contracts/lib/src/topic/lineage.dart packages/nidana_dart_contracts/lib/src/topic/envelope.dart packages/nidana_dart_contracts/test/lineage_test.dart
git commit -m "feat(dart_contracts): derive lineages from envelopes and copy envelope parents" -m "<the co-author trailer your harness gives>"
```

### Task 4: Lineage.combine, its property tests and the README

You are filling in `Lineage.combine` in `packages/nidana_dart_contracts/lib/src/topic/lineage.dart`, which Task 3 gave a private constructor `Lineage._` and value equality, and correcting one sentence of the package's `README.md`. Run every command from the repository root with `fvm dart`. This task turns eight conformance cases green: G4's lineage case and the seven of G19, Spec §2.4's two worked examples among them.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topic/lineage.dart` (`combine` only)
- Modify: `packages/nidana_dart_contracts/README.md` (one sentence)
- Create: `packages/nidana_dart_contracts/test/lineage_property_test.dart`

**Interfaces:**
- Consumes: `const Lineage._({required String? causationId, required String? correlationId, required List<String> parentCorrelationIds, required bool sensitive})`, `Lineage.causedBy`, `Lineage.withLatestFrom` and lineage equality (Task 3).
- Produces: `static Lineage Lineage.combine(List<Lineage> inputs, {required int trigger, required String Function() freshCorrelationId})` (G19), which topology-dsl@v2's combine stages apply (nidana.model.9, nidana.runtime).

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/lineage_property_test.dart`. Each property runs 500 fixed seeds and names the seed in every failure; the generator draws a root lineage (with or without a correlation) or one caused by an envelope with up to four distinct parents, so that every branch of Spec §2.4's table is reached, which the last property asserts (more than 10 seeds each for none, one and several distinct correlations):

```dart
// Property tests of topic-model@v1's Lineage.combine and
// Lineage.withLatestFrom (G4, G19, G20) over lineages generated from fixed
// seeds with dart:math, so that a failure names the seed that reproduces it
// and the package takes no dependency beyond test (ADR-002 item 3).
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

/// How many seeds each property runs.
const int seeds = 500;

/// The correlations a generated lineage draws from; null is a root lineage
/// with no correlation.
const List<String?> correlations = <String?>[null, 'c-a', 'c-b', 'c-c'];

/// The parent correlation ids a generated envelope draws from.
const List<String> parentPool = <String>['p-1', 'p-2', 'p-3', 'p-4'];

/// One generated lineage: a root lineage, with or without a correlation,
/// or one caused by an envelope with up to four distinct parents in random
/// order; sensitive or not.
Lineage lineage(Random random, String id) {
  final String? correlation = correlations[random.nextInt(4)];
  final bool sensitive = random.nextBool();
  if (correlation == null || random.nextInt(4) == 0) {
    return Lineage.root(correlationId: correlation, sensitive: sensitive);
  }
  final List<String> parents = (List<String>.of(
    parentPool,
  )..shuffle(random)).sublist(0, random.nextInt(parentPool.length + 1));
  return Lineage.causedBy(
    MessageEnvelope<int>(
      id: id,
      payload: 0,
      correlationId: correlation,
      parentCorrelationIds: parents,
      timestamp: DateTime.utc(2026, 10, 27),
      source: const UnknownSource(),
      sensitive: sensitive,
    ),
  );
}

/// One to five generated inputs.
List<Lineage> inputs(Random random) => <Lineage>[
  for (int i = 0, n = 1 + random.nextInt(5); i < n; i++)
    lineage(random, 'e-$i'),
];

/// The distinct correlation ids of [lineages], in input order.
List<String> distinctCorrelations(List<Lineage> lineages) => <String>[
  ...<String>{for (final Lineage l in lineages) ?l.correlationId},
];

/// Whether [ids] lists each element of [lists], taken in order and
/// flattened, exactly once, at its first occurrence's position.
bool listsFirstOccurrences(List<String> ids, Iterable<List<String>> lists) {
  final List<String> flat = <String>[for (final List<String> l in lists) ...l];
  final List<int> firsts = <int>[for (final String id in ids) flat.indexOf(id)];
  return ids.toSet().length == ids.length &&
      ids.toSet().containsAll(flat) &&
      !firsts.contains(-1) &&
      <int>[for (int i = 1; i < firsts.length; i++) firsts[i] - firsts[i - 1]]
          .every((int step) => step > 0);
}

/// A combine over generated inputs, and the fresh correlation ids it took.
typedef Combination = ({
  List<Lineage> inputs,
  int trigger,
  Lineage out,
  List<String> minted,
});

Combination combined(int seed) {
  final Random random = Random(seed);
  final List<Lineage> ins = inputs(random);
  final int trigger = random.nextInt(ins.length);
  final List<String> minted = <String>[];
  final Lineage out = Lineage.combine(
    ins,
    trigger: trigger,
    freshCorrelationId: () {
      minted.add('fresh-$seed-${minted.length}');
      return minted.last;
    },
  );
  return (inputs: ins, trigger: trigger, out: out, minted: minted);
}

void main() {
  test('G19 combine calls freshCorrelationId exactly once when the '
      'correlated inputs differ, and never otherwise', () {
    for (int seed = 0; seed < seeds; seed++) {
      final Combination c = combined(seed);
      final int distinct = distinctCorrelations(c.inputs).length;
      expect(c.minted, hasLength(distinct > 1 ? 1 : 0), reason: 'seed $seed');
    }
  });

  test('G19 combine takes the causation from the trigger and is sensitive '
      'exactly when an input is', () {
    for (int seed = 0; seed < seeds; seed++) {
      final Combination c = combined(seed);
      expect(
        c.out.causationId,
        c.inputs[c.trigger].causationId,
        reason: 'seed $seed',
      );
      expect(
        c.out.sensitive,
        c.inputs.any((Lineage l) => l.sensitive),
        reason: 'seed $seed',
      );
    }
  });

  test('G4 G19 combine keeps one shared correlation with its inputs\' '
      'parents united in input order, takes a fresh one over the distinct '
      'input correlations in input order, and carries none over none', () {
    final List<int> byDistinct = <int>[0, 0, 0];
    for (int seed = 0; seed < seeds; seed++) {
      final Combination c = combined(seed);
      final List<String> distinct = distinctCorrelations(c.inputs);
      final List<String> parents = c.out.parentCorrelationIds;
      byDistinct[min(distinct.length, 2)]++;
      switch (distinct.length) {
        case 0:
          expect(c.out.correlationId, isNull, reason: 'seed $seed');
          expect(parents, isEmpty, reason: 'seed $seed');
        case 1:
          expect(c.out.correlationId, distinct.single, reason: 'seed $seed');
          expect(
            listsFirstOccurrences(parents, <List<String>>[
              for (final Lineage l in c.inputs)
                if (l.correlationId != null) l.parentCorrelationIds,
            ]),
            isTrue,
            reason: 'seed $seed: $parents',
          );
        default:
          expect(c.out.correlationId, c.minted.single, reason: 'seed $seed');
          expect(
            listsFirstOccurrences(parents, <List<String>>[
              for (final Lineage l in c.inputs)
                if (l.correlationId case final String id) <String>[id],
            ]),
            isTrue,
            reason: 'seed $seed: $parents',
          );
      }
      expect(() => parents.add('x'), throwsUnsupportedError);
    }
    // The seeds reach every branch: no, one and several correlations.
    expect(byDistinct, everyElement(greaterThan(10)));
  });

  test('G20 withLatestFrom keeps the primary causation, correlation and '
      'parents and is sensitive exactly when an input is', () {
    for (int seed = 0; seed < seeds; seed++) {
      final Random random = Random(seed);
      final Lineage primary = lineage(random, 'e-primary');
      final List<Lineage> latest = inputs(random).sublist(1);
      final Lineage out = Lineage.withLatestFrom(primary, latest);
      expect(out.causationId, primary.causationId, reason: 'seed $seed');
      expect(out.correlationId, primary.correlationId, reason: 'seed $seed');
      expect(
        out.parentCorrelationIds,
        primary.parentCorrelationIds,
        reason: 'seed $seed',
      );
      expect(
        out.sensitive,
        primary.sensitive || latest.any((Lineage l) => l.sensitive),
        reason: 'seed $seed',
      );
    }
  });
}
```

- [ ] **Step 2: Run it and the replay of G4 and G19, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/lineage_property_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+1 -3: Some tests failed.`: the three `combine` properties fail on `UnimplementedError`; the `withLatestFrom` property passes on Task 3's code (T4.2).
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G4,G19; echo "exit: $?"`
Expected: `exit: 1`; `FAIL behavior ...: cases (1 passed, 8 failed, 0 skipped under dart test, restricted to topic-model G4, G19)` with the `failed-case` names `G4 a lineage keeps unmodifiable parent correlation ids` and the seven G19 cases, and `18 fixtures: 17 passed, 1 failed, 0 pending` (T4.2).

- [ ] **Step 3: Implement `Lineage.combine` and correct the README**

`combine` reads as Spec §2.4's table, in this order:

1. Reject before anything else, so that a rejected call takes no fresh id: an empty `inputs` throws `ArgumentError.value(inputs, 'inputs', 'must not be empty')`, then `RangeError.checkValidIndex(trigger, inputs, 'trigger')` throws for a trigger out of range. A `RangeError` is an `ArgumentError` (F A2, A3), which the suite's `throwsArgumentError` accepts.
2. The distinct correlation ids of the inputs, in input order: `<String>{for (final Lineage input in inputs) ?input.correlationId}`, a set literal, which keeps insertion order (F O1), with the null-aware element the root lint set asks for.
3. `causationId` is `inputs[trigger].causationId`; `sensitive` is `inputs.any(...)`.
4. A switch expression over the number of distinct correlation ids builds `Lineage._`: none, no correlation and `const <String>[]`; one, that id, and as parents `List<String>.unmodifiable` of a set literal that spreads the parents of every input that carries a correlation id, in input order (a union: a repeated parent is kept once); several, `freshCorrelationId()`, called in this branch only and so exactly once, and as parents `List<String>.unmodifiable` of the distinct ids.

In `packages/nidana_dart_contracts/README.md`, replace the paragraph's first sentence, `Everything here is a value or a total function.` (the observer interfaces are neither, and `Lineage.combine` throws `ArgumentError`), so that the paragraph opens:

```markdown
Everything here is an immutable value, a pure function, or one of the
observer interfaces an application implements; a function rejects an
argument outside its domain with an `ArgumentError`, as `Lineage.combine`
does for an empty input list. The package depends on the
```

and the rest of the paragraph stays as it is.

- [ ] **Step 4: Run the formatter, the tests, the analyzer and the replay**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted 36 files (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+56: All tests passed!`; the property test file alone takes under a second (T4.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G4,G19; echo "exit: $?"`
Expected: `exit: 0`, `PASS behavior ...: 9 passed, 0 failed, 0 skipped under dart test, restricted to topic-model G4, G19` and `18 fixtures: 18 passed, 0 failed, 0 pending` (T4.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topic/lineage.dart packages/nidana_dart_contracts/README.md packages/nidana_dart_contracts/test/lineage_property_test.dart
git commit -m "feat(dart_contracts): combine lineages by Spec 2.4's table" -m "<the co-author trailer your harness gives>"
```

### Task 5: Envelopes

You are filling in the remaining bodies of `packages/nidana_dart_contracts/lib/src/topic/envelope.dart`: `MessageEnvelope.publishedTo`, `redacted()`, `==`, `hashCode` and the redacting `toString()`. Its constructor already keeps an unmodifiable copy of the parents (Task 3); `Lineage` (Tasks 3 and 4), `RedactedPayload` and source rendering (Task 2) are complete. Run every command from the repository root with `fvm dart`. This task turns the last seven conformance cases green, G13 (1), G14 (3) and G15 (3), and with them the unrestricted replay.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topic/envelope.dart`
- Create: `packages/nidana_dart_contracts/test/envelope_test.dart`

**Interfaces:**
- Consumes: `Lineage`'s getters (Task 3), `RedactedPayload.of` (Task 2), `MessageSource.toString()` (Task 2), `elementsEqual` (Task 3), `Topic.sensitive` (nidana.model.3).
- Produces: `factory MessageEnvelope.publishedTo(Topic<T> topic, {required String id, required T payload, required Lineage lineage, required String Function() freshCorrelationId, required DateTime timestamp, required MessageSource source})` (G14), `MessageEnvelope<Object?> redacted()` (G15), `MessageEnvelope.operator ==` and `hashCode` (G13), `toString()` (G15), which bus-api@v2's publish path and observers call.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/envelope_test.dart`. Its first test pins the rendering this phase chooses, which G15 constrains only for a sensitive payload:

```dart
// topic-model@v1's envelopes, beyond the cases of its conformance suite,
// which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

final DateTime at = DateTime.utc(2026, 10, 27, 12);

/// A payload whose own rendering a test can look for.
final class Card {
  const Card(this.number);
  final String number;
  @override
  String toString() => 'Card($number)';
}

MessageEnvelope<T> envelope<T>(T payload, {bool sensitive = false}) =>
    MessageEnvelope<T>(
      id: 'e-1',
      payload: payload,
      correlationId: 'c-1',
      causationId: 'e-0',
      parentCorrelationIds: <String>['p-1', 'p-2'],
      timestamp: at,
      source: const PageSource('search'),
      sensitive: sensitive,
    );

void main() {
  test('an envelope renders its eight fields, a payload that is not '
      'sensitive as its own rendering', () {
    expect(
      envelope<String>('shoes').toString(),
      'MessageEnvelope(id: e-1, payload: shoes, correlationId: c-1, '
      'causationId: e-0, parentCorrelationIds: [p-1, p-2], '
      'timestamp: 2026-10-27 12:00:00.000Z, source: page:search, '
      'sensitive: false)',
    );
  });

  test('G15 a sensitive envelope, and its redacted() envelope, never render '
      'the payload, whatever the payload', () {
    for (final Object? payload in <Object?>[
      const Card('4242-4242'),
      'card 4242-4242',
      <String>['4242-4242'],
      <String, Object?>{'card': '4242-4242'},
    ]) {
      final MessageEnvelope<Object?> secret = envelope<Object?>(
        payload,
        sensitive: true,
      );
      expect(secret.toString(), isNot(contains('4242-4242')));
      expect(
        secret.toString(),
        contains('payload: ${RedactedPayload.of(payload)},'),
      );
      expect(secret.redacted().toString(), isNot(contains('4242-4242')));
    }
  });

  test('G13 envelopes of different type arguments are equal when their '
      'eight fields are, and one set element', () {
    final MessageEnvelope<String> typed = envelope<String>('shoes');
    final MessageEnvelope<Object?> widened = envelope<Object?>('shoes');
    expect(widened, typed);
    expect(widened.hashCode, typed.hashCode);
    expect(<MessageEnvelope<Object?>>{typed, widened}, hasLength(1));
  });

  test('G4 G14 a published envelope keeps an unmodifiable copy of its '
      'lineage parents', () {
    final MessageEnvelope<int> out = MessageEnvelope<int>.publishedTo(
      const EventTopic<int>(name: 'a.out'),
      id: 'e-2',
      payload: 2,
      lineage: Lineage.causedBy(envelope<String>('shoes')),
      freshCorrelationId: () => 'fresh',
      timestamp: at,
      source: const TopologySource('flow'),
    );
    expect(out.parentCorrelationIds, <String>['p-1', 'p-2']);
    expect(() => out.parentCorrelationIds.add('p-3'), throwsUnsupportedError);
  });
}
```

- [ ] **Step 2: Run it and the replay of G13, G14 and G15, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/envelope_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+0 -4: Some tests failed.`, on `Actual: 'Instance of \'MessageEnvelope<String>\''` (Object's `toString`), on identity equality and on `UnimplementedError` from `publishedTo` (T5.2).
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G13,G14,G15; echo "exit: $?"`
Expected: `exit: 1`; `FAIL behavior ...: cases (1 passed, 7 failed, 0 skipped under dart test, restricted to topic-model G13 to G15)` with seven `failed-case` names, and `18 fixtures: 17 passed, 1 failed, 0 pending` (T5.2).

- [ ] **Step 3: Implement the envelope bodies**

- `publishedTo` returns `MessageEnvelope<T>(...)` with the given id, payload, timestamp and source, the lineage's causation id and parent correlation ids, `correlationId: lineage.correlationId ?? freshCorrelationId()` (`??` calls it only when the lineage has none: exactly one call or none, G14) and `sensitive: topic.sensitive`, whatever the lineage's flag.
- `redacted()` returns, for a sensitive envelope, a `MessageEnvelope<Object?>` with `payload: RedactedPayload.of(payload)` and every other field as it is; for any other envelope, `this`.
- `==` holds when `other is MessageEnvelope<Object?>` (every envelope is one, so the type argument takes no part: G13 compares the eight fields, and an observer's widened envelope equals its typed twin) and the eight fields are equal, the parents by `elementsEqual`. `hashCode` is `Object.hash` of the eight fields with `Object.hashAll(parentCorrelationIds)` in the parents' place (D4: the list itself hashes its identity, and the suite's G13 case fails). `envelope.dart` imports `list_equality.dart` and `redacted_payload.dart`.
- `toString()` renders the eight fields in the constructor's order, a sensitive payload as `RedactedPayload.of(payload)`:

```dart
  /// Renders a sensitive payload redacted (G15).
  @override
  String toString() =>
      'MessageEnvelope(id: $id, '
      'payload: ${sensitive ? RedactedPayload.of(payload) : payload}, '
      'correlationId: $correlationId, causationId: $causationId, '
      'parentCorrelationIds: $parentCorrelationIds, timestamp: $timestamp, '
      'source: $source, sensitive: $sensitive)';
```

- Comments as Global Constraints, Comments, states.

- [ ] **Step 4: Run the formatter, the tests, the analyzer and the replays**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted 37 files (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+60: All tests passed!` (T5.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topic-model --set behavior --guarantee G13,G14,G15; echo "exit: $?"`
Expected: `exit: 0`, `PASS behavior ...: 8 passed, 0 failed, 0 skipped under dart test, restricted to topic-model G13 to G15` and `18 fixtures: 18 passed, 0 failed, 0 pending` (T5.4).
Run: `fvm dart run nidana_contract_check topic-model; echo "exit: $?"`
Expected: `exit: 0`; 17 `PASS structure`, 3 `PASS surface` and 10 `PASS reject` lines, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test` and `31 fixtures: 31 passed, 0 failed, 0 pending` (T5.4). A FAIL is a stop: see Global Constraints, Contract gaps.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topic/envelope.dart packages/nidana_dart_contracts/test/envelope_test.dart
git commit -m "feat(dart_contracts): publish, compare, redact and render envelopes" -m "<the co-author trailer your harness gives>"
```

### Task 6: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.8.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.8.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 5; the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl topology-ir --set structure,surface,reject,schema) > "${TMPDIR:-/tmp}/nidana.model.8-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after.
Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+60: All tests passed!`, `31 fixtures: 31 passed, 0 failed, 0 pending` (with `PASS behavior ...nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`) and `87 fixtures: 87 passed, 0 failed, 0 pending` (G). A failure stops here: it is fixed in the task that owns the code, never by editing `hsdd/`; a fixture that fails against code that follows this plan is a contract gap (Global Constraints).

- [ ] **Step 2: Run the checklist**

`<base>` below is the parent of Task 1's commit (`git log --format=%H -n 1 <Task 1's commit>^`). Run each and keep its output:
- `fvm dart test hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart --name '^G19 a (same-correlation combine keeps|cross-correlation combine takes)' -r expanded` (expected: the two case names, then `+2: All tests passed!`): Spec §2.4's two worked examples, by name (C).
- `fvm dart test packages/nidana_dart_contracts/test/envelope_test.dart --name 'G15' -r expanded` (expected: `+1: All tests passed!`): a sensitive envelope of four payload shapes never renders its payload, before or after `redacted()` (C).
- `grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/topic; echo "exit: $?"` and `grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/topic; echo "exit: $?"` (expected: no line, `exit: 1`, each): every topic-model@v1 body computes, and no suppression is left under `lib/src/topic/`.
- `git diff --name-status <base> HEAD -- packages/nidana_dart_contracts/lib packages/nidana_dart_contracts/README.md` (expected: nine lines, `A` for `lib/src/topic/list_equality.dart` and `M` for `README.md` and the seven other libraries of `lib/src/topic/`).
- `git status --short pubspec.lock` and `git diff --stat <base> HEAD -- packages/nidana_dart_contracts/pubspec.yaml` (expected: no output from either).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.8.verification.md` at spot-check depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.8 - Topic model values and lineage` (a spaced hyphen; no em-dash anywhere in the file). Short: commands, expected output, what to eyeball, Learnings.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as the phase context writes it, which replays topic-model@v1 unrestricted (`structure`, `surface`, `reject`, and `behavior` through the binding `nidana_dart_contracts_test.dart` under `dart test`; no `schema` set, ADR-001 item 4) and topology-dsl@v2's and topology-ir@v1's type-level sets; the checklist commands of Step 2.
- **Expected output:** the gate's exit 0 and its six lines of Step 1; the checklist's expected results of Step 2.
- **Observed:** dated, with the gate's start and end times, the branch and commit, and Dart 3.13.5 through `fvm`; the gate's exit code and its six lines as they appeared; then a checklist of `- [x]` lines, each with its result, to eyeball:
  - the unrestricted replay of topic-model@v1 passed all 41 behavior cases, where nidana.model.3's declarations passed 9 and failed 32 (`hsdd/verify/nidana.model.6.verification.md`), with its 3 surface and 10 reject libraries;
  - Spec §2.4's two worked examples reproduce as written: the same-correlation combine keeps `sess-42` with cause `e-02` and takes no fresh id; the cross-correlation combine takes one fresh id with parents `pref-update-5` and `market-feed-9` (the two cases by name);
  - a sensitive envelope never renders its payload: G15's case, and Task 5's test over a class, a `String`, a `List` and a `Map` payload, before and after `redacted()`;
  - the property tests ran 500 seeds per property and reached every branch of Spec §2.4's table;
  - no body under `lib/src/topic/` throws `UnimplementedError`, the `// ignore: unused_element` above `RedactedPayload._` is gone, the export lists are unchanged (`exports_test.dart` passes), `purity_test.dart` passes over the new library, and the lockfile and `pubspec.yaml` are unchanged.
- **Outstanding:** `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found the four below and the sizing line; write each that still holds, and any the gate finds:
  - `- topic-model@v1 G15 and G24 say a redaction never contains the payload's own rendering, which no implementation can hold for a payload whose rendering is short enough to occur in the redaction format, such as the String 'String' or a one-digit number; the suite's payload has a distinctive rendering, and this phase's tests use such payloads. Disposition: dropped (wording; reported as a contract gap by S124 for a compatible hsdd-contract touch)`
  - `- topic-model@v1 G15 has redacted() wrap whatever payload a sensitive envelope holds, and toString() render RedactedPayload.of(payload), so the rendering of envelope.redacted() shows <redacted RedactedPayload #...> and loses the payload's type, which Spec §9.2 item 2 shows and which the surface fixture's AuditObserver logs; this phase follows G15 as written. Disposition: dropped (reported as a contract gap by S124 for hsdd-contract, which owns any change to the redaction rule)`
  - `- topic-model@v1's opening sentence and nidana.model's Pure band paragraph say everything in the package is a value or a total function, while the observer interfaces are neither and Lineage.combine throws ArgumentError; this phase corrected the package README only. Disposition: dropped (reported as a contract gap by S124 for the governance sweep at the end of nidana.model)`
  - `- With value equality in place, a non-empty const set of, or a const map keyed by, topics, topic references, sources, envelopes, lineages or redacted payloads does not compile; no committed fixture of any slug holds one, and consumer plans must not write one. Disposition: dropped (already routed to the consumer nodes' plans)`
  - one sizing line: the phase scope's estimate of about 420 lines in about 6 files against the measured product diff (Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint).
- **Metrics:** one line: the product diff, `git diff --stat <base> HEAD -- packages/`, in files and lines, the library and the tests apart, beside the estimate of about 420 lines in about 6 files; the task count, 6 of the allowed 7.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.8.verification.md
git commit -m "docs(verify): nidana.model.8 verification" -m "<the co-author trailer your harness gives>"
```
