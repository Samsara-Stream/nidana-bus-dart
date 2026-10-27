# nidana.model.10 IR Values and Function References Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver topology-ir@v1's IR value bodies under `packages/nidana_dart_contracts/lib/src/ir/` (`FunctionRef.of`, `named` and `anonymous`; `TransformEdge`'s three factories with the stage-edge table, `isSink` and `isStateBearing`; `TopologyDefinition`'s well-formedness with `reads` and `writes` derived in canonical order; the four canonical orders as shared comparators; value equality, hash codes and unmodifiable copies of every IR value) and the value semantics of the six finding and declaration types under `lib/src/analysis/`, so that the gate's topology-ir replay, restricted to G2, G5, G6, G9 and G10, passes 10 of 10 cases (1 passes today), and the package's own tests pin what that replay leaves open.

**Architecture:** Bodies, private members and one internal library only; every public declaration nidana.model.4 and nidana.model.5 landed stays as it is. Each IR value is made by a factory that checks its arguments first and then constructs through the private const constructor with unmodifiable copies, so no ill-formed value exists. The stage-edge table is a private record per combinator; a definition's well-formedness is one pass over its edges and a consumption check. The canonical orders are top-level comparators in a new library, `lib/src/ir/canonical_order.dart`, which no public library exports; the claim order compares a record of a claim's parts, so `lib/src/ir/` never imports `lib/src/graph/`. The definition and the findings sort through those comparators. `==` compares exactly the fields the Interface names, lists element by element, and `hashCode` hashes each list with `Object.hashAll`. The tasks go from leaves to their users: `FunctionRef`; edge inputs and edges; the canonical orders; the definition; the findings; the gate and the verification doc.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:meta` 1.19.0 (`@immutable`), the package's only dependency; `package:test` for the package's tests, with `dart:io` in two of them (one reads `lib/src/ir/`, one runs a Dart program without assertions); the replay tool `nidana_contract_check` with its `behavior` set (nidana.model.6).

**Spec:** `hsdd-context/superpowers/nidana.model.10.md` (the derivative; the phase context with topic-model@v1's and topology-ir@v1's whole Interface and Guarantees sits between its markers). The dartdoc already in `lib/src/ir/` and `lib/src/analysis/findings.dart` came from topology-ir@v1's Interface, `hsdd/contract/topology-ir.md` lines 41 to 440, and stays. Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D3 (line 102: a type-level phase leaves `==` and `hashCode` as `Object`'s until the phase that delivers value equality, this one for the IR), D4 (line 112: `lib/src/ir/` holds the IR values, `FunctionRef`, the canonical orders and the projection; `lib/src/analysis/` the findings and declarations in one library), D5 (line 128) and D6 (line 135: `test/purity_test.dart` scans every library under `lib/` for the tokens `DateTime.now(`, `Stopwatch(`, `Timer(`, `Timer.periodic(`, `scheduleMicrotask(`, `Future.delayed(`, `Future.microtask(`, `Random(` and `Zone.`, as substrings, comments included). The fixtures the gate replays: `hsdd/contract/fixture/topology-ir/` (`surface/`, `reject/`, the schema with `valid/` and `invalid/`, and `behavior/topology_ir_conformance.dart` through the binding `nidana_dart_contracts_test.dart`). Evidence: `docs/auto-run/experiments/ir-values-plan/` (`run.sh`, `output.txt`, `facts/`, `gen_variants.py`, `draft/`, `suite_reach.sh`, `suite_reach.txt`), a dry run of this plan's tasks in a temporary copy of HEAD `06d90bc`; labels such as F1, S1, B, T1.2, G, U, C, A or X below name the steps of its `output.txt`, and "dry run D2" names its seeded defect D2, while a bare D3 to D6 is a decision of `hsdd/spec/nidana.model.md`. `draft/` is evidence, not code to copy: the blocks below are the source, each formatter-stable (X).

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 7 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl --set structure,surface,reject && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G9,G10` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.10.verification.md from
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

- **Toolchain:** `fvm dart` only, every command from the repository root, no global tooling. No dependency changes: no `pubspec.yaml` is edited and `pubspec.lock` stays byte-identical (C).
- **Files:** under `lib/` this phase edits `lib/src/ir/function_ref.dart` (Task 1), `lib/src/ir/definition.dart` (Tasks 2 and 4) and `lib/src/analysis/findings.dart` (Task 5), and creates `lib/src/ir/canonical_order.dart` (Task 3); no other library. `lib/src/graph/` is nidana.model.11's and `lib/src/analysis/analyses.dart` nidana.model.12's. The three public libraries' export lists stay exactly as `test/exports_test.dart` pins them, and none exports the new library. Under `test/` it creates five test files and one helper library, `test/src/cart_elsewhere.dart`, and edits no existing test. `README.md`, `CHANGELOG.md` and `LICENSE` stay as they are (D4). Nothing under `hsdd/` changes except the verification doc of Task 6.
- **Interface:** every public name, signature, parameter name (the findings' named parameters included), default, modifier, annotation and `const` stays as topology-ir@v1 states it and nidana.model.4 and nidana.model.5 landed it. Every getter that returns a stored value stays a final field (D3; `reject/ir_values_are_immutable.dart` expects `assignment_to_final`); `isSink` and `isStateBearing` stay computed getters. `TopicInput`, `StageInput` (with its assertion), `FunctionRef.anonymous`, `ScopeViolation` and `TopicDeclaration` keep their `const` constructors, which the surface fixtures and the existing tests use. A class gains `==` and `hashCode` and no other public member: no `toString`, which the Interface does not declare (nidana.model.9 kept `TopologyRef` the same way). New members are private, except the top-level declarations of `lib/src/ir/canonical_order.dart`, which no public library exports.
- **Equality and hash codes (F1, F2):** `==` compares exactly the fields topology-ir@v1's Equality paragraph and G7 name, lists element by element with `elementsEqual` from `lib/src/topic/list_equality.dart`. `hashCode` is `Object.hash` of the same fields, each list as `Object.hashAll(list)`, never the list itself: `Object.hash` hashes a list by identity, so two equal lists hash apart (H1, H2), while `Object.hashAll` is element-wise and order-sensitive (H3, H4). `Object.hash` and an enum's `hashCode` change from run to run and stay fixed within one (F2: three lines differ), so no test pins a hash code's value, only that equal values hash alike. A definition's `==` leaves out `reads` and `writes`, which its edges determine; a `Set`'s own `==` is identity (U6), so tests compare sets through the matchers or `toList()`.
- **Unmodifiable copies (F1):** every list an IR value, finding or collision exposes is a `List<T>.unmodifiable` copy, sorted where the Interface names an order; `reads` and `writes` are `Set<TopicRef>.unmodifiable` of the sorted list, which keeps the first occurrence of each element in that order (U1), is a copy (U2) and throws `UnsupportedError` on change (U3, U4).
- **Errors:** every rejection throws `ArgumentError.value(value, name, message)` whose `name` is the argument at fault, as the tests pin: `name` (`FunctionRef.named`); `combinator`, `inputs`, `transformer`, `duration` and `retry` (`TransformEdge.stage`); `topic` (`TransformEdge.reduceInto`); `topologyId` and `transforms` (`TopologyDefinition`). The message is free; it says what the argument must be, and never builds "an {variant}" from a variant name (S132's grammar finding): write "is not a state topic".
- **Library boundaries (routed item):** no library under `lib/src/ir/` imports or exports `lib/src/graph/`, which imports `lib/src/ir/`; Task 3's test pins it.
- **Comments:** the Interface's dartdoc and trailing comments stay as written and where nidana.model.4 and nidana.model.5 put them. Each `==` gets a `//` line above its `@override` naming the fields it compares and citing G7, as the blocks below show; a new private member gets a `//` comment saying what it holds or checks. No word of `lib/` may contain a D6 token, in code or comment. No em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.
- **Const collections (B, A, C):** `TopicInput`, `StageInput`, `FunctionRef`, `TransformEdge`, `TopologyDefinition`, the four findings, `TopicDeclaration` and `TopicNameCollision` now override `==`, as `TopicRef` and the message sources do since nidana.model.8, so a non-empty const set of, or a const map keyed by, any of them does not compile. No test of this phase writes one (A: no match in the five new test files; `transform_edge_test.dart`'s table is a `final` map keyed by `CombinatorKind`); const lists are fine. The fixture libraries under every slug's `surface/`, `reject/` and `behavior/` report the same 3143 diagnostics, in 70 of them, before and after this phase's bodies, none a const-collection code (B, A).
- **Analyzer:** `fvm dart analyze --fatal-infos` at the root reports nothing after every task (T1.4 to T5.4). `unused_element` decides where each private helper lands: `_marker` and `_nonEmpty` in Task 1; `_StageRule`, `_ruleOf` and `_checkPresence` in Task 2; `_checkWellFormed` in Task 4; `_bySiteThenTopic` in Task 5. The `// ignore: unused_element` line above `TransformEdge._` goes in Task 2 and the one above `TopologyDefinition._` in Task 4, each with the comment line above it, because the factories now construct through those constructors; the two in `lib/src/graph/graph.dart` stay for nidana.model.11.
- **Tests:** run from the root as `fvm dart test packages/nidana_dart_contracts`. Each task's failing step also replays the conformance cases of its guarantees, `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee {ids}`, which runs the committed binding under `dart test` and starts no `flutter`; no test of this phase starts `flutter` either. `dart test` runs with assertions enabled, so `StageInput(-1)` throws `AssertionError` in a test; Task 4's one test of a negative index therefore runs a small program through `Platform.resolvedExecutable`, which runs without assertions (T4.4; dry run D4). A test may import `package:nidana_dart_contracts/src/...` of its own package, as `test/lineage_test.dart` does. The package's tests do not repeat the suite's cases; they pin what it leaves open, and each of the dry run's thirteen seeded defects fails at least one of them, ten of which the gate's replay passes (D). Add a test beyond the plan's wherever a rule you implement would otherwise go unpinned. No test uses a `test` API newer than 1.31.1. The 147 package tests of HEAD, topic-model@v1's replay (41 behavior cases) and topology-dsl@v2's `structure`, `surface` and `reject` sets pass today and stay green through every task (S1, G).
- **Contract gaps (ADR-001 item 8):** the dry run passes every committed fixture of topic-model@v1, topology-dsl@v2's three sets and topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets, and the ten behavior cases of the gate's restriction plus G7's IR case; the other 32 behavior cases call graphs, claims, the projection, the analyses, the codec or the renderers, which nidana.model.11 to nidana.model.14 deliver (U). Any other fixture that fails against code that follows this plan is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the case or library, what it reports, the guarantee, and the fix you would propose.
- **Formatting and commits:** run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for a Sonnet implementer.

## Plan check

The derivative's Plan check, run after self-review: the Global Constraints above contain its constraints 1 to 8 verbatim; every `### Task N:` but the last starts with a failing-test step; Task 6 writes `hsdd/verify/nidana.model.10.verification.md`; the plan has 6 tasks of the allowed 7; it is saved as `docs/superpowers/plans/nidana.model.10.md`. `node docs/auto-run/tools/impl-gate.mjs code-plan nidana.model.10` checks the same mechanically and exits 0 on this plan.

## Review Focus

The input classes the spec implies but the conformance suite does not exercise, most likely to bite first; each has its test in the owning task.

1. **IR values as keys of hash-based collections:** a graph or a tool that puts edges, definitions, function references or findings in a `Set` or a `Map`. Expected: equal values built apart are one element, because each list is hashed element by element; an edge that hashes its input list by identity passes the gate's replay (dry run D2). Tests: `G7 function references are equal, with equal hash codes, exactly when their names are` (Task 1), `G7 edges are equal, ...` (Task 2), `G7 definitions are equal, ...` (Task 4), `G23 findings and collisions built in any order are equal, with equal hash codes` (Task 5).
2. **A caller that reuses the list it passed:** a builder that fills one growable list per edge or finding and clears it for the next. Expected: every value keeps its own unmodifiable copy (G3, which joins the gate at nidana.model.11); an edge that keeps the caller's list passes the gate's replay (dry run D8). Tests: `G3 an edge keeps an unmodifiable copy of its inputs` (Task 2), `G3 a definition keeps ...` (Task 4), `G3 findings and collisions keep unmodifiable copies of their lists` (Task 5).
3. **One topic read in several places, with and without a dedup argument, and topics of several variants under one name:** Expected: `reads` and `writes` hold each topic once, in canonical order, whose variants run state, event, replay, not alphabetically (a variant order by name fails G6's case, dry run D3). Tests: `topic references sort by name, then variant as state, event, replay, then type name by code unit` (Task 3), `G6 reads hold each topic read once, ...` and `G6 a state topic and an event topic of one name are two topics, each with its sink` (Task 4).
4. **Two value types whose names render alike:** a `Cart` from each of two packages, each the type of a state topic of one name. Expected: they are two `Topic`s and one `TopicRef`, so a definition with a sink on each throws `ArgumentError` naming `transforms`, which nidana.model.11's projection lets propagate from `buildDefinition()` (S132's routed corner). Test: `G6 two state topics whose value types render alike are one topic to the IR, so a sink on each throws` (Task 4).
5. **A transformer in a form the suite does not name:** a constructor tear-off, a named constructor, a generic function, a `call` tear-off, a private class, an extension method, or a closure that wraps a named function. Expected: the names G9's rule yields, which topology-ir@v1's Function references table lists (`Box.`, `identity`, `call`, `_Hidden@{key}.`), `Box.named` for a named constructor, which the table does not list (F1 R), and anonymous for an extension tear-off and every closure, which is why nidana.model.11 takes `FunctionRef.of` of a stage's `combiner`, never of its `apply` closure (F1 R). Tests: Task 1's first three G9 tests.

## Routed items

Each item routed to this phase (`docs/auto-run/impl-execution-plan.md`, "Routed to later phases", the entries naming nidana.model.10, and nidana.model.11's needs from S132's final review), with its disposition:

- The claim order compares `ShellClaim`, which `lib/src/graph/graph.dart` declares on top of `lib/src/ir/`: Task 3 defines it over the claim's parts, `compareClaimKeys(ClaimKey a, ClaimKey b)` with `typedef ClaimKey = ({MessageSource source, Scope scope, Iterable<TopicRef> writes})`, in `lib/src/ir/canonical_order.dart`, which imports no `graph/` library; Task 3's last test pins the boundary, and nidana.model.11 sorts claims by passing each claim's three fields.
- The findings' constructors become initializer lists that sort, keeping every parameter name and field type: Task 5; no call site changes (the existing `topology_ir_declarations_test.dart` and the surface fixtures pass unchanged, T5.4 and G).
- Remove the two `// ignore: unused_element` on `TransformEdge._` and `TopologyDefinition._`: Task 2 and Task 4, with the comment line above each.
- `FunctionRef.named`'s empty-name `ArgumentError`: Task 1, an initializer that throws `ArgumentError` named `name`.
- (nidana.model.11) `FunctionRef.of` is called on a stage's `combiner`, never its `apply`: no IR change; Task 1's test shows a closure that calls a named function is anonymous while the function itself is named.
- (nidana.model.11) stages map to edge indices by identity: no IR change; `StageInput` holds an index, and the identity map is nidana.model.11's projection.
- (nidana.model.11) the `TopologyDefinition` factory throws `ArgumentError` for an ill-formed definition, two state topics whose value types render alike included: Task 4, and its test of that corner (Review Focus 4).
- No test may write a non-empty const set or map of value-equal types: none of the five new test files does (A), and no fixture's diagnostics change (A).

## Which task turns which failing case green

The gate's restricted replay runs 10 cases and passes 1 today, `G2 CombinatorKind has exactly the eighteen values, in order`, which nidana.model.4's enum already satisfies and no task changes (S1). The other nine fail on `UnimplementedError`. By the task whose code turns each green; every task's failing and passing steps replay its own ids:

| Task | Cases (by guarantee: count) | Replay |
|------|-----------------------------|--------|
| 1 | G9: 3 (public names, anonymous forms with `FunctionRef.named('')`, private names) | `--guarantee G9` goes from 0 passed, 3 failed to 3 passed (T1.2, T1.4) |
| 2 | G5: 3 (input counts, transformer, duration and retry, sinks), G10: 1 | `--guarantee G5,G10` goes from 0 passed, 4 failed to 4 passed (T2.2, T2.4) |
| 3 | none: the comparators that Task 4's G6 case and Task 5's findings sort by | none |
| 4 | G6: 2 (reads and writes in canonical order, rejections) | `--guarantee G6` goes from 0 passed, 2 failed to 2 passed; the gate's restriction then passes all 10 (T4.2, T4.4) |
| 5 | none in the restriction: G23's case also runs the analyses over a sample graph, so it joins the gate at nidana.model.12, and Task 5's tests check G23 until then | none |

After Task 5 the unrestricted suite passes 11 of 43 cases: the ten above and `G7 IR values are equal, with equal hash codes, exactly when their fields are`, which joins the gate at nidana.model.11 with G3 because G7's other case builds graphs (U).

**The phase's Verification line**, and where each part is checked: `FunctionRef.of` gives on the VM the names topology-ir@v1's derivation table lists (Task 1: the suite's three G9 cases and the package test's forms beyond them, under `dart test`; F1 R under `dart run`); an edge or a definition that breaks a rule throws at construction, so no ill-formed IR value exists (Tasks 2 and 4: every factory checks before it constructs, and the private constructors have no other caller; the suite's G5 and G6 cases and the package tests that name the argument at fault, the negative index included); the gate's restricted replay passes 10 of 10 (G).

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/ir/function_ref.dart` | 1 | `FunctionRef.of`, the empty-name check, equality |
| `{pkg}/lib/src/ir/definition.dart` | 2, 4 | Edge inputs' equality, `TransformEdge`'s factories, table, getters and equality (2); `TopologyDefinition`'s factory, rules and equality (4) |
| `{pkg}/lib/src/ir/canonical_order.dart` | 3 | The four canonical orders as comparators, and `sortedCopy` |
| `{pkg}/lib/src/analysis/findings.dart` | 5 | Sorting constructors and equality of the findings, declarations and collisions |
| `{pkg}/test/function_ref_test.dart` | 1 | Function references beyond the suite |
| `{pkg}/test/transform_edge_test.dart` | 2 | The whole stage-edge table, sinks, copies and equality of edges and inputs |
| `{pkg}/test/canonical_order_test.dart` | 3 | The comparators, `sortedCopy`, the `ir/` to `graph/` boundary |
| `{pkg}/test/topology_definition_test.dart` | 4 | Reads and writes, rejections, the negative index, the rendered-alike corner, copies and equality |
| `{pkg}/test/src/cart_elsewhere.dart` | 4 | A second `Cart` class for the rendered-alike corner |
| `{pkg}/test/findings_test.dart` | 5 | Sorted lists, copies and equality of findings, declarations and collisions |
| `hsdd/verify/nidana.model.10.verification.md` | 6 | The verification doc |

---

### Task 1: FunctionRef

You are filling in `FunctionRef` in `packages/nidana_dart_contracts/lib/src/ir/function_ref.dart`, which nidana.model.4 declared with `of` throwing `UnimplementedError`, an unchecked `named` and no value equality (nidana.model D3). Run every command from the repository root with `fvm dart`. Change no public declaration (Global Constraints, Interface). This task turns the gate's three G9 cases green.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/ir/function_ref.dart`
- Create: `packages/nidana_dart_contracts/test/function_ref_test.dart`

**Interfaces:**
- Consumes: nothing beyond the declaration as it stands.
- Produces, for Tasks 2 to 5 (exact names): `FunctionRef`'s `==` (by `name`) and `hashCode` (`name.hashCode`); `FunctionRef.named(String name)` throwing `ArgumentError` named `name` for `''`; the body of `factory FunctionRef.of(Function function)`; in the library, `const String _marker = "from Function '";` and `String _nonEmpty(String name)`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/function_ref_test.dart` with exactly this content:

```dart
// topology-ir@v1's function references, beyond the G9 cases of its
// conformance suite, which the gate replays: the other forms of the
// Function references table, the rendering of private names, the empty-name
// error, and value equality (G7, which joins the gate at nidana.model.11).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

int topLevel(int v) => throw StateError('FunctionRef.of called topLevel');
T identity<T>(T v) => v;

final class Box {
  const Box(this.v);
  const Box.named(this.v);
  final int v;
}

final class _Hidden {
  const _Hidden();
  String _format(int v) => '$v';
}

final class Adder {
  const Adder();
  int call(int v) => v + 1;
}

final class Statics {
  static int Function(int) closure() =>
      (int v) => v;
}

extension on int {
  int twice() => this * 2;
}

void main() {
  test('G9 FunctionRef.of names a constructor tear-off, a generic function '
      'and a call tear-off as the VM renders them', () {
    expect(FunctionRef.of(Box.new).name, 'Box.');
    expect(FunctionRef.of(Box.named).name, 'Box.named');
    expect(FunctionRef.of(identity).name, 'identity');
    expect(FunctionRef.of(identity<int>).name, 'identity');
    expect(FunctionRef.of(const Adder().call).name, 'call');
  });

  test('G9 FunctionRef.of keeps the library key after a private class, '
      'constructor and method name', () {
    expect(
      FunctionRef.of(_Hidden.new).name,
      matches(RegExp(r'^_Hidden@\d+\.$')),
    );
    expect(
      FunctionRef.of(const _Hidden()._format).name,
      matches(RegExp(r'^_format@\d+$')),
    );
  });

  test('G9 FunctionRef.of is anonymous for an extension method tear-off, a '
      'closure a static method returns, and a closure that calls a named '
      'function', () {
    expect(FunctionRef.of(3.twice), const FunctionRef.anonymous());
    expect(FunctionRef.of(Statics.closure()), const FunctionRef.anonymous());
    expect(
      FunctionRef.of((int v) => topLevel(v)),
      const FunctionRef.anonymous(),
    );
    expect(FunctionRef.of(topLevel).name, 'topLevel');
  });

  test('G9 FunctionRef.of and FunctionRef.named agree on a public name', () {
    expect(FunctionRef.of(topLevel), FunctionRef.named('topLevel'));
    expect(
      FunctionRef.of(topLevel).hashCode,
      FunctionRef.named('topLevel').hashCode,
    );
  });

  test('G9 FunctionRef.named keeps any non-empty name and throws '
      'ArgumentError naming the argument for an empty one', () {
    expect(FunctionRef.named(' ').name, ' ');
    expect(FunctionRef.named('a b').name, 'a b');
    expect(
      () => FunctionRef.named(''),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.name,
          'name',
          'name',
        ),
      ),
    );
  });

  test('G7 function references are equal, with equal hash codes, exactly '
      'when their names are', () {
    expect(FunctionRef.named('a'), FunctionRef.named('a'));
    expect(FunctionRef.named('a').hashCode, FunctionRef.named('a').hashCode);
    expect(FunctionRef.named('a'), isNot(FunctionRef.named('b')));
    expect(FunctionRef.named('a'), isNot(FunctionRef.named('A')));
    expect(
      FunctionRef.of((int v) => v).hashCode,
      const FunctionRef.anonymous().hashCode,
    );
    expect(<FunctionRef>{
      FunctionRef.named('a'),
      FunctionRef.named('a'),
      const FunctionRef.anonymous(),
      FunctionRef.of((int v) => v),
    }, hasLength(2));
  });
}
```

- [ ] **Step 2: Run the test and the G9 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/function_ref_test.dart; echo "exit: $?"`
Expected: `+0 -6: Some tests failed.` and `exit: 1`: four tests fail on `UnimplementedError` from `of`, one on `Expected: throws <Instance of 'ArgumentError'> with `name`: 'name'`, one on `Expected: <Instance of 'FunctionRef'>` (identity equality) (T1.2).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G9; echo "exit: $?"`
Expected: `cases (0 passed, 3 failed, ...)` and `exit: 1` (T1.2).

- [ ] **Step 3: Implement `FunctionRef` in `lib/src/ir/function_ref.dart`**

`named` checks in its initializer list, so the class keeps its final field and gains no body:

```dart
  /// Throws ArgumentError for an empty [name].
  FunctionRef.named(String name) : name = _nonEmpty(name);
```

with, after the class, `// What precedes a function's name in the VM's rendering of it (G9).` above `const String _marker = "from Function '";`, and `// [name] when it is not empty (G9).` above `String _nonEmpty(String name)`, which throws `ArgumentError.value(name, 'name', 'must not be empty')` for `''` and returns `name` otherwise.

`factory FunctionRef.of(Function function)` reads `function.toString()` once and calls nothing else on `function`. With `String.indexOf`: when `_marker` is absent, `const FunctionRef.anonymous()`; else the name is the text after the first `_marker` up to the next `'`; when there is no next `'`, or the text is empty, anonymous; else `FunctionRef.named(text)`. The text is kept as rendered, `@` and the library key included (G9; F1 R: `_private@21481238`).

Equality, after the field:

```dart
  // name (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) => other is FunctionRef && other.name == name;

  @override
  int get hashCode => name.hashCode;
```

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)` from the formatter, `+153: All tests passed!` (147 before this task, 6 added; more if you added tests), `No issues found!` (T1.4).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G9; echo "exit: $?"`
Expected: `3 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G9`, `10 fixtures: 10 passed, 0 failed, 0 pending` and `exit: 0` (T1.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/ir/function_ref.dart packages/nidana_dart_contracts/test/function_ref_test.dart
git commit -m "feat(dart_contracts): name function references as the VM renders them" -m "<the co-author trailer your harness gives>"
```

### Task 2: Edge inputs and TransformEdge

You are filling in `TopicInput`, `StageInput` and `TransformEdge` in `packages/nidana_dart_contracts/lib/src/ir/definition.dart`; `TopologyDefinition`, in the same file, stays as it is until Task 4. Run every command from the repository root with `fvm dart`. This task turns four of the gate's cases green: G5 (3) and G10 (1).

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/ir/definition.dart` (everything above `/// The IR of one topology`)
- Create: `packages/nidana_dart_contracts/test/transform_edge_test.dart`

**Interfaces:**
- Consumes: Task 1's `FunctionRef` equality; `bool elementsEqual(List<Object?> a, List<Object?> b)` from `lib/src/topic/list_equality.dart` (import `'../topic/list_equality.dart'`); `TopicRef` equality (nidana.model.8).
- Produces, for Tasks 4 and 5 (exact names): `==` and `hashCode` of `TopicInput` (fields `topic`, `dedup`), `StageInput` (field `edge`) and `TransformEdge` (all six fields); the bodies of `TransformEdge.stage`, `TransformEdge.write`, `TransformEdge.reduceInto`, `isSink` and `isStateBearing`; in the library, `typedef _StageRule`, `_StageRule _ruleOf(CombinatorKind combinator)` and `void _checkPresence(Object? value, String name, CombinatorKind combinator, bool required)`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/transform_edge_test.dart` with exactly this content:

```dart
// topology-ir@v1's edges and edge inputs, beyond the G5 and G10 cases of its
// conformance suite, which the gate replays: the whole stage-edge table, the
// argument each rejection names, sinks of every variant, unmodifiable copies
// (G3) and value equality (G7), which join the gate at nidana.model.11.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

TopicRef ref(String name, [TopicVariant variant = TopicVariant.event]) =>
    TopicRef(name: name, variant: variant, typeName: 'int');

final FunctionRef f = FunctionRef.named('f');
const Duration ms = Duration(milliseconds: 1);

/// What topology-ir@v1's stage-edge table allows for each combinator but
/// reduceInto: the input counts accepted among 0 to 5, and whether a
/// transformer, a duration and a retry are taken.
final Map<CombinatorKind, (List<int>, bool, bool, bool)> table =
    <CombinatorKind, (List<int>, bool, bool, bool)>{
      CombinatorKind.map: (<int>[1], true, false, false),
      CombinatorKind.filter: (<int>[1], true, false, false),
      CombinatorKind.combine: (<int>[1, 2, 3, 4, 5], true, false, false),
      CombinatorKind.withLatestFrom: (<int>[2, 3, 4], true, false, false),
      CombinatorKind.merge: (<int>[1, 2, 3, 4, 5], false, false, false),
      CombinatorKind.switchMap: (<int>[1], true, false, true),
      CombinatorKind.scan: (<int>[1], true, false, false),
      CombinatorKind.pairwise: (<int>[1], false, false, false),
      CombinatorKind.distinctUntilChanged: (<int>[1], false, false, false),
      CombinatorKind.debounce: (<int>[1], false, true, false),
      CombinatorKind.throttle: (<int>[1], false, true, false),
      CombinatorKind.delay: (<int>[1], false, true, false),
      CombinatorKind.sample: (<int>[1], false, true, false),
      CombinatorKind.buffer: (<int>[1], false, true, false),
      CombinatorKind.timeout: (<int>[1], false, true, false),
      CombinatorKind.catchError: (<int>[1], true, false, false),
      CombinatorKind.rawEngine: (<int>[1], true, false, false),
    };

List<EdgeInput> inputs(int count) => <EdgeInput>[
  for (int i = 0; i < count; i++) TopicInput(ref('t.$i')),
];

/// Throws an ArgumentError whose name is [argument].
Matcher rejects(String argument) => throwsA(
  isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', argument),
);

void main() {
  test('G5 every combinator but reduceInto takes the input counts, '
      'transformer, duration and retry the table allows, and rejects the '
      'others naming the argument', () {
    expect(table.keys, hasLength(CombinatorKind.values.length - 1));
    for (final MapEntry<CombinatorKind, (List<int>, bool, bool, bool)> row
        in table.entries) {
      final CombinatorKind k = row.key;
      final (List<int> counts, bool fn, bool time, bool retry) = row.value;
      final FunctionRef? t = fn ? f : null;
      final Duration? d = time ? ms : null;
      for (int n = 0; n <= 5; n++) {
        if (counts.contains(n)) {
          expect(
            TransformEdge.stage(
              k,
              inputs(n),
              transformer: t,
              duration: d,
            ).inputs,
            hasLength(n),
            reason: '${k.name} with $n inputs',
          );
        } else {
          expect(
            () =>
                TransformEdge.stage(k, inputs(n), transformer: t, duration: d),
            rejects('inputs'),
            reason: '${k.name} with $n inputs',
          );
        }
      }
      final List<EdgeInput> some = inputs(counts.first);
      expect(
        () => TransformEdge.stage(
          k,
          some,
          transformer: fn ? null : f,
          duration: d,
        ),
        rejects('transformer'),
        reason: k.name,
      );
      expect(
        () => TransformEdge.stage(
          k,
          some,
          transformer: t,
          duration: time ? null : ms,
        ),
        rejects('duration'),
        reason: k.name,
      );
      if (retry) {
        expect(
          TransformEdge.stage(k, some, transformer: t, retry: f).retry,
          f,
          reason: k.name,
        );
      } else {
        expect(
          () => TransformEdge.stage(
            k,
            some,
            transformer: t,
            duration: d,
            retry: f,
          ),
          rejects('retry'),
          reason: k.name,
        );
      }
    }
  });

  test('G5 a negative duration names the duration and reduceInto names the '
      'combinator', () {
    expect(
      () => TransformEdge.stage(
        CombinatorKind.timeout,
        inputs(1),
        duration: const Duration(microseconds: -1),
      ),
      rejects('duration'),
    );
    expect(
      () => TransformEdge.stage(
        CombinatorKind.reduceInto,
        inputs(1),
        transformer: f,
      ),
      rejects('combinator'),
    );
  });

  test('G5 a stage edge holds what it was given and no output', () {
    final TransformEdge e = TransformEdge.stage(
      CombinatorKind.switchMap,
      inputs(1),
      transformer: f,
      retry: FunctionRef.named('r'),
    );
    expect(e.combinator, CombinatorKind.switchMap);
    expect(e.inputs, inputs(1));
    expect(e.transformer, f);
    expect(e.duration, isNull);
    expect(e.retry, FunctionRef.named('r'));
    expect(e.output, isNull);
    expect(e.isSink, isFalse);
  });

  test('G5 a write takes a topic of any variant; a reduceInto holds its '
      'reducer and nothing else', () {
    for (final TopicVariant v in TopicVariant.values) {
      final TransformEdge w = TransformEdge.write(
        ref('w', v),
        const StageInput(0),
      );
      expect(w.output, ref('w', v));
      expect(w.isSink, isTrue);
      expect(w.isStateBearing, isFalse);
    }
    final TransformEdge r = TransformEdge.reduceInto(
      ref('s', TopicVariant.state),
      const StageInput(2),
      f,
    );
    expect(r.inputs, <EdgeInput>[const StageInput(2)]);
    expect(r.duration, isNull);
    expect(r.retry, isNull);
    expect(
      () => TransformEdge.reduceInto(ref('e'), const StageInput(0), f),
      rejects('topic'),
    );
  });

  test('G3 an edge keeps an unmodifiable copy of its inputs', () {
    final List<EdgeInput> given = inputs(2);
    final TransformEdge e = TransformEdge.stage(CombinatorKind.merge, given);
    given.add(TopicInput(ref('late')));
    expect(e.inputs, inputs(2));
    expect(() => e.inputs.add(const StageInput(0)), throwsUnsupportedError);
    expect(
      () => TransformEdge.write(ref('w'), const StageInput(0)).inputs.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => TransformEdge.reduceInto(
        ref('s', TopicVariant.state),
        const StageInput(0),
        f,
      ).inputs.clear(),
      throwsUnsupportedError,
    );
  });

  test('G7 edge inputs are equal, with equal hash codes, exactly when their '
      'fields are', () {
    expect(TopicInput(ref('a')), TopicInput(ref('a')));
    expect(TopicInput(ref('a')).hashCode, TopicInput(ref('a')).hashCode);
    expect(
      TopicInput(ref('a'), dedup: Dedup.none),
      TopicInput(ref('a'), dedup: Dedup.none),
    );
    expect(
      TopicInput(ref('a'), dedup: Dedup.none),
      isNot(TopicInput(ref('a'), dedup: Dedup.equality)),
    );
    expect(TopicInput(ref('a')), isNot(TopicInput(ref('b'))));
    expect(StageInput(<int>[1].single), const StageInput(1));
    expect(StageInput(<int>[1].single).hashCode, const StageInput(1).hashCode);
    expect(const StageInput(1), isNot(TopicInput(ref('a'))));
  });

  test('G7 edges are equal, with equal hash codes, exactly when all six '
      'fields are, inputs element by element', () {
    TransformEdge make({
      CombinatorKind k = CombinatorKind.debounce,
      List<EdgeInput>? given,
      Duration d = ms,
    }) => TransformEdge.stage(k, given ?? inputs(1), duration: d);
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(<TransformEdge>{make(), make()}, hasLength(1));
    expect(make(k: CombinatorKind.delay), isNot(make()));
    expect(make(given: <EdgeInput>[TopicInput(ref('x'))]), isNot(make()));
    expect(make(d: const Duration(microseconds: 1001)), isNot(make()));
    expect(
      TransformEdge.stage(CombinatorKind.merge, inputs(2)),
      isNot(
        TransformEdge.stage(CombinatorKind.merge, inputs(2).reversed.toList()),
      ),
    );
    expect(
      TransformEdge.stage(CombinatorKind.map, inputs(1), transformer: f),
      isNot(
        TransformEdge.stage(
          CombinatorKind.map,
          inputs(1),
          transformer: const FunctionRef.anonymous(),
        ),
      ),
    );
    final TopicRef s = ref('s', TopicVariant.state);
    expect(
      TransformEdge.write(s, const StageInput(0)),
      TransformEdge.write(s, const StageInput(0)),
    );
    expect(
      TransformEdge.write(s, const StageInput(0)),
      isNot(TransformEdge.reduceInto(s, const StageInput(0), f)),
    );
    expect(
      TransformEdge.write(s, const StageInput(0)),
      isNot(TransformEdge.write(ref('s'), const StageInput(0))),
    );
  });
}
```

- [ ] **Step 2: Run the test and the G5 and G10 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/transform_edge_test.dart; echo "exit: $?"`
Expected: `+0 -7: Some tests failed.` and `exit: 1`: four on `UnimplementedError`, the others on an expected `ArgumentError` or equality (T2.2).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G5,G10; echo "exit: $?"`
Expected: `cases (0 passed, 4 failed, ...)` and `exit: 1` (T2.2).

- [ ] **Step 3: Implement the edge inputs and `TransformEdge` in `lib/src/ir/definition.dart`**

Delete the two comment lines and the `// ignore: unused_element` line above `const TransformEdge._(...)`; the constructor stays as it is.

`TopicInput` and `StageInput` keep their `const` constructors, and `StageInput` its assertion. Each gains, after its fields:

```dart
  // topic and dedup (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopicInput && other.topic == topic && other.dedup == dedup;

  @override
  int get hashCode => Object.hash(topic, dedup);
```

and for `StageInput`, `// edge (topology-ir@v1 G7)`, `other is StageInput && other.edge == edge` and `edge.hashCode`.

The stage-edge table of topology-ir@v1's What a stage edge holds, as a private record per combinator, and the presence check the factory applies to it, after the `TransformEdge` class:

```dart
// What a stage edge of one combinator holds (topology-ir@v1, What a stage
// edge holds): from minInputs to maxInputs inputs (null: no upper bound); a
// transformer and a duration exactly when required, else none; a retry
// allowed only where optional.
typedef _StageRule = ({
  int minInputs,
  int? maxInputs,
  bool transformer,
  bool duration,
  bool retry,
});

_StageRule _ruleOf(CombinatorKind combinator) => switch (combinator) {
  CombinatorKind.map ||
  CombinatorKind.filter ||
  CombinatorKind.scan ||
  CombinatorKind.catchError ||
  CombinatorKind.rawEngine => (
    minInputs: 1,
    maxInputs: 1,
    transformer: true,
    duration: false,
    retry: false,
  ),
  CombinatorKind.switchMap => (
    minInputs: 1,
    maxInputs: 1,
    transformer: true,
    duration: false,
    retry: true,
  ),
  CombinatorKind.combine => (
    minInputs: 1,
    maxInputs: null,
    transformer: true,
    duration: false,
    retry: false,
  ),
  CombinatorKind.withLatestFrom => (
    minInputs: 2,
    maxInputs: 4,
    transformer: true,
    duration: false,
    retry: false,
  ),
  CombinatorKind.merge => (
    minInputs: 1,
    maxInputs: null,
    transformer: false,
    duration: false,
    retry: false,
  ),
  CombinatorKind.pairwise || CombinatorKind.distinctUntilChanged => (
    minInputs: 1,
    maxInputs: 1,
    transformer: false,
    duration: false,
    retry: false,
  ),
  CombinatorKind.debounce ||
  CombinatorKind.throttle ||
  CombinatorKind.delay ||
  CombinatorKind.sample ||
  CombinatorKind.buffer ||
  CombinatorKind.timeout => (
    minInputs: 1,
    maxInputs: 1,
    transformer: false,
    duration: true,
    retry: false,
  ),
  CombinatorKind.reduceInto => throw ArgumentError.value(
    combinator,
    'combinator',
    'a reduceInto edge is made by TransformEdge.reduceInto',
  ),
};

// Throws ArgumentError when [value] is absent where [required], or present
// where not.
void _checkPresence(
  Object? value,
  String name,
  CombinatorKind combinator,
  bool required,
) {
  if (required && value == null) {
    throw ArgumentError.value(
      value,
      name,
      'a ${combinator.name} edge needs one',
    );
  }
  if (!required && value != null) {
    throw ArgumentError.value(
      value,
      name,
      'a ${combinator.name} edge holds none',
    );
  }
}
```

`factory TransformEdge.stage(...)` checks in this order, each failure an `ArgumentError` named as given: `_ruleOf(combinator)` (`combinator`, for reduceInto); `inputs.length` below `minInputs` or above a non-null `maxInputs` (`inputs`); `_checkPresence(transformer, 'transformer', combinator, rule.transformer)`; `_checkPresence(duration, 'duration', combinator, rule.duration)`; `duration.isNegative` (`duration`; a zero duration passes); a non-null `retry` where `!rule.retry` (`retry`). Then it returns `TransformEdge._` with `inputs: List<EdgeInput>.unmodifiable(inputs)`, `output: null` and the other arguments as given.

`factory TransformEdge.write(topic, input)` returns `TransformEdge._` with `combinator: null`, `inputs: List<EdgeInput>.unmodifiable(<EdgeInput>[input])`, `output: topic` and the three function and duration fields null; any variant is accepted.

`factory TransformEdge.reduceInto(topic, events, reducer)` throws `ArgumentError.value(topic.name, 'topic', 'is not a state topic, and a reduceInto writes one')` unless `topic.variant == TopicVariant.state`, and otherwise returns `TransformEdge._` with `combinator: CombinatorKind.reduceInto`, `inputs` the unmodifiable `[events]`, `output: topic`, `transformer: reducer`, `duration` and `retry` null.

`bool get isSink => output != null; // output != null`. `isStateBearing` is a `switch (combinator)`: `scan` and `reduceInto` are true; `debounce`, `delay`, `sample` and `buffer` are `duration! > Duration.zero` (the table makes their duration non-null); everything else, a write's null included, is false. Keep the trailing comment `// Spec §3.8; the rule below` after the closing `};`.

Equality, after `isStateBearing`:

```dart
  // all six fields, inputs element by element (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TransformEdge &&
      other.combinator == combinator &&
      elementsEqual(other.inputs, inputs) &&
      other.output == output &&
      other.transformer == transformer &&
      other.duration == duration &&
      other.retry == retry;

  @override
  int get hashCode => Object.hash(
    combinator,
    Object.hashAll(inputs),
    output,
    transformer,
    duration,
    retry,
  );
```

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)`, `+160: All tests passed!` (153 before, 7 added), `No issues found!` (T2.4).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G5,G10; echo "exit: $?"`
Expected: `4 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G5, G10` and `exit: 0` (T2.4).
Run: `grep -c "ignore:" packages/nidana_dart_contracts/lib/src/ir/definition.dart`
Expected: `1`, the line above `TopologyDefinition._`, which Task 4 removes (T2.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/ir/definition.dart packages/nidana_dart_contracts/test/transform_edge_test.dart
git commit -m "feat(dart_contracts): build transform edges by the stage-edge table" -m "<the co-author trailer your harness gives>"
```

### Task 3: The canonical orders

You are creating `packages/nidana_dart_contracts/lib/src/ir/canonical_order.dart`, topology-ir@v1's four canonical orders as comparators that the definition (Task 4), the findings (Task 5) and nidana.model.11's graphs and claims sort by. No public library exports it. Run every command from the repository root with `fvm dart`. No conformance case depends on this task alone; Task 4's G6 case checks the topic order through `reads` and `writes`.

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/ir/canonical_order.dart`
- Create: `packages/nidana_dart_contracts/test/canonical_order_test.dart`

**Interfaces:**
- Consumes: `TopicRef`, `TopicVariant` (`lib/src/topic/topic.dart`), `MessageSource` and its `toString()` (`lib/src/topic/message_source.dart`), `Scope` (`lib/src/topic/scope.dart`); the library imports these three and nothing else.
- Produces, for Tasks 4 and 5 and nidana.model.11 (exact signatures):

```dart
int compareTopicRefs(TopicRef a, TopicRef b);
int compareTopologyIds(String a, String b);
int compareMessageSources(MessageSource a, MessageSource b);
typedef ClaimKey = ({
  MessageSource source,
  Scope scope,
  Iterable<TopicRef> writes,
});
int compareClaimKeys(ClaimKey a, ClaimKey b);
List<T> sortedCopy<T>(Iterable<T> elements, Comparator<T> compare);
```

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/canonical_order_test.dart` with exactly this content:

```dart
// topology-ir@v1's four canonical orders as the shared comparators of
// lib/src/ir/canonical_order.dart, which the IR, the graphs and the findings
// sort by (nidana.model D4). No public library exports them.
import 'dart:io';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/src/ir/canonical_order.dart';
import 'package:test/test.dart';

import 'src/package_files.dart';

TopicRef ref(String name, TopicVariant variant, [String type = 'int']) =>
    TopicRef(name: name, variant: variant, typeName: type);

const TopicVariant state = TopicVariant.state;
const TopicVariant event = TopicVariant.event;
const TopicVariant replay = TopicVariant.replay;

ClaimKey claim(MessageSource source, Scope scope, Iterable<TopicRef> writes) =>
    (source: source, scope: scope, writes: writes);

void main() {
  test('topic references sort by name, then variant as state, event, '
      'replay, then type name by code unit', () {
    final List<TopicRef> refs = <TopicRef>[
      ref('b', state),
      ref('a', replay),
      ref('a', event, 'int'),
      ref('a', event, 'String'),
      ref('a', state, 'int'),
      ref('a', state, 'Cart'),
    ];
    expect(sortedCopy(refs, compareTopicRefs), <TopicRef>[
      ref('a', state, 'Cart'),
      ref('a', state, 'int'),
      ref('a', event, 'String'),
      ref('a', event, 'int'),
      ref('a', replay),
      ref('b', state),
    ]);
    expect(compareTopicRefs(ref('a', event), ref('a', event)), 0);
    expect(
      compareTopicRefs(ref('a.b', replay), ref('a.c', state)),
      lessThan(0),
    );
    expect(compareTopicRefs(ref('a', replay), ref('a', event)), greaterThan(0));
  });

  test('topology ids sort by String.compareTo', () {
    expect(
      sortedCopy(<String>['b', 'B', 'a', 'a-b', 'A'], compareTopologyIds),
      <String>['A', 'B', 'a', 'a-b', 'b'],
    );
  });

  test('message sources sort by their rendering', () {
    expect(
      sortedCopy(const <MessageSource>[
        UnknownSource(),
        TopologySource('a'),
        ServiceSource('b'),
        PageSource('/z'),
        ExecutorSource('nav'),
        ServiceSource('a'),
      ], compareMessageSources),
      const <MessageSource>[
        ExecutorSource('nav'),
        PageSource('/z'),
        ServiceSource('a'),
        ServiceSource('b'),
        TopologySource('a'),
        UnknownSource(),
      ],
    );
  });

  test('claims sort by source, then scope, then writes element by element in '
      'canonical order, a prefix first', () {
    const ServiceSource a = ServiceSource('a');
    const ServiceSource b = ServiceSource('b');
    final TopicRef x = ref('x', state);
    final TopicRef y = ref('y', state);
    final List<ClaimKey> claims = <ClaimKey>[
      claim(b, Scope.application, <TopicRef>[x]),
      claim(a, Scope.page, <TopicRef>[x]),
      claim(a, Scope.application, <TopicRef>[y]),
      claim(a, Scope.application, <TopicRef>[y, x]),
      claim(a, Scope.module, <TopicRef>[x]),
      claim(a, Scope.application, <TopicRef>[x]),
    ];
    expect(
      sortedCopy(claims, compareClaimKeys)
          .map(
            (ClaimKey c) =>
                '${c.source} ${c.scope.name} '
                '${c.writes.map((TopicRef t) => t.name).join(',')}',
          )
          .toList(),
      <String>[
        'service:a application x',
        'service:a application y,x',
        'service:a application y',
        'service:a module x',
        'service:a page x',
        'service:b application x',
      ],
    );
    expect(
      compareClaimKeys(
        claim(a, Scope.application, <TopicRef>[x]),
        claim(a, Scope.application, <TopicRef>[x, y]),
      ),
      lessThan(0),
    );
    expect(
      compareClaimKeys(
        claim(a, Scope.application, <TopicRef>[y, x]),
        claim(a, Scope.application, <TopicRef>{x, y}),
      ),
      0,
    );
    expect(
      compareClaimKeys(
        claim(a, Scope.application, <TopicRef>[y]),
        claim(a, Scope.application, <TopicRef>[x, y]),
      ),
      greaterThan(0),
    );
  });

  test('sortedCopy keeps repeated elements, leaves its argument alone and is '
      'unmodifiable', () {
    final List<int> given = <int>[3, 1, 3, 2];
    final List<int> sorted = sortedCopy(
      given,
      (int a, int b) => a.compareTo(b),
    );
    expect(sorted, <int>[1, 2, 3, 3]);
    expect(given, <int>[3, 1, 3, 2]);
    expect(() => sorted.add(4), throwsUnsupportedError);
  });

  test('no library under lib/src/ir/ imports or exports lib/src/graph/', () {
    final RegExp graph = RegExp(
      r"^(import|export)\s+'[^']*graph/",
      multiLine: true,
    );
    final Directory ir = Directory('${packageDirectory().path}/lib/src/ir');
    expect(<String>[
      for (final FileSystemEntity f in ir.listSync())
        if (f is File && graph.hasMatch(f.readAsStringSync())) f.path,
    ], isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fvm dart test packages/nidana_dart_contracts/test/canonical_order_test.dart; echo "exit: $?"`
Expected: `+0 -1: Some tests failed.` and `exit: 1`: the file does not load, `Error: Method not found: 'sortedCopy'.`, `'compareClaimKeys'` and the other names (T3.2).

- [ ] **Step 3: Create `lib/src/ir/canonical_order.dart`**

The library is short and each line of it is a decision, so here it is whole:

```dart
// topology-ir@v1's canonical orders (the Interface's Canonical orders), as
// comparators the IR, the graphs and the findings share (nidana.model D4).
// The claim order compares a claim's parts, so that this library never names
// ShellClaim, which lib/src/graph/ declares on top of lib/src/ir/.
import '../topic/message_source.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

/// Topic references: by `name` (`String.compareTo`), then `variant` (state,
/// event, replay), then `typeName`.
int compareTopicRefs(TopicRef a, TopicRef b) {
  final int byName = a.name.compareTo(b.name);
  if (byName != 0) {
    return byName;
  }
  final int byVariant = a.variant.index.compareTo(b.variant.index);
  if (byVariant != 0) {
    return byVariant;
  }
  return a.typeName.compareTo(b.typeName);
}

/// Topologies: by `topologyId`.
int compareTopologyIds(String a, String b) => a.compareTo(b);

/// Message sources: by `toString()`.
int compareMessageSources(MessageSource a, MessageSource b) =>
    a.toString().compareTo(b.toString());

/// The parts of a shell claim that the claim order compares.
typedef ClaimKey = ({
  MessageSource source,
  Scope scope,
  Iterable<TopicRef> writes,
});

/// Claims: by `source.toString()`, then `scope` (application, module, page),
/// then their `writes` element by element in canonical order, a shorter list
/// first when one is a prefix of the other.
int compareClaimKeys(ClaimKey a, ClaimKey b) {
  final int bySource = compareMessageSources(a.source, b.source);
  if (bySource != 0) {
    return bySource;
  }
  final int byScope = a.scope.index.compareTo(b.scope.index);
  if (byScope != 0) {
    return byScope;
  }
  final List<TopicRef> left = sortedCopy(a.writes, compareTopicRefs);
  final List<TopicRef> right = sortedCopy(b.writes, compareTopicRefs);
  for (int i = 0; i < left.length && i < right.length; i++) {
    final int byTopic = compareTopicRefs(left[i], right[i]);
    if (byTopic != 0) {
      return byTopic;
    }
  }
  return left.length.compareTo(right.length);
}

/// An unmodifiable list of [elements] sorted by [compare], repeated elements
/// kept.
List<T> sortedCopy<T>(Iterable<T> elements, Comparator<T> compare) =>
    List<T>.unmodifiable(elements.toList()..sort(compare));
```

Three of those decisions: the variant order is `TopicVariant`'s declaration order, `index`, never the variant's name, which sorts event, replay, state (dry run D3); the topology order compares ids, not `TopologyDefinition`s, so this library does not import `definition.dart`, which imports it, and `TopologyCycle.topologyIds` sorts by the same comparator; `compareClaimKeys` sorts copies of both `writes`, so the order holds for writes given in any order (the test's `{x, y}` against `[y, x]`). Every comparator here compares every field its type's `==` compares, so the instability of `List.sort` cannot reorder unequal elements.

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)`, `+166: All tests passed!` (160 before, 6 added), `No issues found!` (T3.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/ir/canonical_order.dart packages/nidana_dart_contracts/test/canonical_order_test.dart
git commit -m "feat(dart_contracts): add the canonical orders as shared comparators" -m "<the co-author trailer your harness gives>"
```

### Task 4: TopologyDefinition

You are filling in `TopologyDefinition` in `packages/nidana_dart_contracts/lib/src/ir/definition.dart`: its factory with topology-ir@v1's well-formedness rules (A well-formed definition), `reads` and `writes` derived in canonical order, and value equality. Run every command from the repository root with `fvm dart`. This task turns the gate's two G6 cases green, and with them all ten of its restriction.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/ir/definition.dart` (`TopologyDefinition` and a new library function after it)
- Create: `packages/nidana_dart_contracts/test/topology_definition_test.dart`
- Create: `packages/nidana_dart_contracts/test/src/cart_elsewhere.dart`

**Interfaces:**
- Consumes: Task 2's edges, `isSink` and input equality; Task 3's `compareTopicRefs` and `sortedCopy` (import `'canonical_order.dart'`); `elementsEqual`; `workspaceRoot()` from `test/src/package_files.dart` in the test.
- Produces: the body of `factory TopologyDefinition({required String topologyId, required Scope scope, required List<TransformEdge> transforms})`; `==` (`topologyId`, `scope`, `transforms` element by element) and `hashCode`; in the library, `void _checkWellFormed(List<TransformEdge> edges)`.

- [ ] **Step 1: Write the failing tests**

Create `packages/nidana_dart_contracts/test/src/cart_elsewhere.dart` with exactly this content:

```dart
// A value type whose name renders like the Cart that
// topology_definition_test.dart declares: two types, one TopicRef type name.
final class Cart {
  const Cart();
}
```

Create `packages/nidana_dart_contracts/test/topology_definition_test.dart` with exactly this content:

```dart
// topology-ir@v1's TopologyDefinition, beyond the G6 cases of its
// conformance suite, which the gate replays: reads and writes over repeated
// topics, the argument each rejection names, a negative stage input built
// without assertions, two value types that render alike, unmodifiable copies
// (G3) and value equality (G7), which join the gate at nidana.model.11.
import 'dart:io';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

import 'src/cart_elsewhere.dart' as elsewhere;
import 'src/package_files.dart';

final class Cart {
  const Cart();
}

TopicRef ref(String name, [TopicVariant variant = TopicVariant.event]) =>
    TopicRef(name: name, variant: variant, typeName: 'int');

final FunctionRef f = FunctionRef.named('f');

TransformEdge map(EdgeInput input) =>
    TransformEdge.stage(CombinatorKind.map, <EdgeInput>[input], transformer: f);

TopologyDefinition define(
  List<TransformEdge> transforms, {
  String id = 'def',
  Scope scope = Scope.page,
}) => TopologyDefinition(topologyId: id, scope: scope, transforms: transforms);

/// Throws an ArgumentError whose name is [argument].
Matcher rejects(String argument) => throwsA(
  isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', argument),
);

/// Run without assertions, so that StageInput's assertion cannot stop a
/// negative index before TopologyDefinition sees it.
const String negativeStageInput = '''
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

void main() {
  final StageInput input = StageInput(int.parse('-1'));
  print('StageInput(\${input.edge})');
  try {
    TopologyDefinition(
      topologyId: 'negative',
      scope: Scope.page,
      transforms: <TransformEdge>[
        TransformEdge.write(
          const TopicRef(name: 'a.b', variant: TopicVariant.event, typeName: 'int'),
          input,
        ),
      ],
    );
    print('accepted');
  } on ArgumentError catch (e) {
    print('ArgumentError(\${e.name})');
  }
}
''';

void main() {
  test('G6 reads hold each topic read once, whatever its dedup argument and '
      'the edge that reads it, and writes each sink topic once, both in '
      'canonical order', () {
    final TopologyDefinition d = define(<TransformEdge>[
      map(TopicInput(ref('x.a', TopicVariant.replay))),
      TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        TopicInput(ref('x.a', TopicVariant.state), dedup: Dedup.none),
        const StageInput(0),
        TopicInput(ref('x.a', TopicVariant.state)),
      ]),
      TransformEdge.write(ref('y.e'), const StageInput(1)),
      TransformEdge.write(
        ref('y.e'),
        TopicInput(ref('x.a', TopicVariant.state)),
      ),
      TransformEdge.write(ref('y.e', TopicVariant.replay), const StageInput(1)),
      TransformEdge.reduceInto(
        ref('y.d', TopicVariant.state),
        const StageInput(1),
        f,
      ),
    ]);
    expect(d.reads.toList(), <TopicRef>[
      ref('x.a', TopicVariant.state),
      ref('x.a', TopicVariant.replay),
    ]);
    expect(d.writes.toList(), <TopicRef>[
      ref('y.d', TopicVariant.state),
      ref('y.e'),
      ref('y.e', TopicVariant.replay),
    ]);
  });

  test('G6 one stage edge may feed several later edges, and one edge may '
      'take a stage twice', () {
    final TopologyDefinition d = define(<TransformEdge>[
      map(TopicInput(ref('a'))),
      TransformEdge.stage(CombinatorKind.combine, const <EdgeInput>[
        StageInput(0),
        StageInput(0),
      ], transformer: f),
      TransformEdge.write(ref('b'), const StageInput(0)),
      TransformEdge.write(ref('c'), const StageInput(1)),
    ]);
    expect(d.transforms, hasLength(4));
    expect(d.writes.toList(), <TopicRef>[ref('b'), ref('c')]);
  });

  test('G6 a state topic and an event topic of one name are two topics, each '
      'with its sink', () {
    final TopologyDefinition d = define(<TransformEdge>[
      TransformEdge.write(ref('n', TopicVariant.state), TopicInput(ref('a'))),
      TransformEdge.write(ref('n'), TopicInput(ref('a'))),
    ]);
    expect(d.writes.toList(), <TopicRef>[
      ref('n', TopicVariant.state),
      ref('n'),
    ]);
  });

  test('G6 two state topics whose value types render alike are one topic to '
      'the IR, so a sink on each throws', () {
    const StateTopic<Cart> mine = StateTopic<Cart>(
      name: 'shop.cart',
      initial: Cart(),
    );
    const StateTopic<elsewhere.Cart> theirs = StateTopic<elsewhere.Cart>(
      name: 'shop.cart',
      initial: elsewhere.Cart(),
    );
    expect(mine, isNot(theirs));
    expect(mine.ref, theirs.ref);
    expect(
      () => define(<TransformEdge>[
        TransformEdge.write(mine.ref, TopicInput(ref('a'))),
        TransformEdge.write(theirs.ref, TopicInput(ref('b'))),
      ]),
      rejects('transforms'),
    );
  });

  test('G6 an empty id names the topologyId and an ill-formed edge list names '
      'the transforms', () {
    expect(
      () => define(const <TransformEdge>[], id: ''),
      rejects('topologyId'),
    );
    expect(
      () => define(<TransformEdge>[
        TransformEdge.write(ref('b'), const StageInput(0)),
      ]),
      rejects('transforms'),
    );
    expect(
      () => define(<TransformEdge>[
        map(TopicInput(ref('a'))),
        map(const StageInput(0)),
        TransformEdge.write(ref('b'), const StageInput(0)),
      ]),
      rejects('transforms'),
    );
  });

  test('G6 a negative stage input, which only code run without assertions '
      'can build, is rejected', () async {
    final Directory temp = Directory.systemTemp.createTempSync('ir_negative');
    addTearDown(() => temp.deleteSync(recursive: true));
    final File script = File('${temp.path}/negative.dart')
      ..writeAsStringSync(negativeStageInput);
    final ProcessResult result = await Process.run(
      Platform.resolvedExecutable,
      <String>[
        '--packages=${workspaceRoot().path}/.dart_tool/package_config.json',
        script.path,
      ],
    );
    expect(result.stderr, '');
    expect(result.stdout, 'StageInput(-1)\nArgumentError(transforms)\n');
    expect(result.exitCode, 0);
  });

  test('G3 a definition keeps an unmodifiable copy of its edges, and its reads '
      'and writes are unmodifiable', () {
    final List<TransformEdge> given = <TransformEdge>[
      TransformEdge.write(ref('b'), TopicInput(ref('a'))),
    ];
    final TopologyDefinition d = define(given);
    given.add(TransformEdge.write(ref('c'), TopicInput(ref('a'))));
    expect(d.transforms, hasLength(1));
    expect(d.writes.toList(), <TopicRef>[ref('b')]);
    expect(() => d.transforms.clear(), throwsUnsupportedError);
    expect(() => d.reads.add(ref('z')), throwsUnsupportedError);
    expect(() => d.writes.remove(ref('b')), throwsUnsupportedError);
  });

  test('G7 definitions are equal, with equal hash codes, exactly when their '
      'id, scope and edges, element by element, are', () {
    List<TransformEdge> edges() => <TransformEdge>[
      map(TopicInput(ref('a'))),
      TransformEdge.write(ref('b'), const StageInput(0)),
      TransformEdge.write(ref('c'), const StageInput(0)),
    ];
    expect(define(edges()), define(edges()));
    expect(define(edges()).hashCode, define(edges()).hashCode);
    expect(<TopologyDefinition>{
      define(edges()),
      define(edges()),
    }, hasLength(1));
    expect(define(edges(), id: 'other'), isNot(define(edges())));
    expect(define(edges(), scope: Scope.module), isNot(define(edges())));
    final List<TransformEdge> swapped = edges();
    swapped.insert(1, swapped.removeAt(2));
    expect(define(swapped).writes, define(edges()).writes);
    expect(define(swapped), isNot(define(edges())));
  });
}
```

- [ ] **Step 2: Run the test and the G6 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/topology_definition_test.dart; echo "exit: $?"`
Expected: `+0 -8: Some tests failed.` and `exit: 1`: five on `UnimplementedError`, two on an expected `ArgumentError`, and the negative-index test on `Expected: ''`, because the program's stderr carries the `UnimplementedError` (T4.2).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G6; echo "exit: $?"`
Expected: `cases (0 passed, 2 failed, ...)` and `exit: 1` (T4.2).

- [ ] **Step 3: Implement `TopologyDefinition` in `lib/src/ir/definition.dart`**

Add `import 'canonical_order.dart';` and delete the comment line and the `// ignore: unused_element` line above `const TopologyDefinition._(...)`; the constructor stays as it is.

The factory throws `ArgumentError.value(topologyId, 'topologyId', 'must not be empty')` for an empty id; copies `transforms` once with `List<TransformEdge>.unmodifiable`; runs `_checkWellFormed` on the copy; and returns `TopologyDefinition._` with that copy as `transforms`, `reads` as `Set<TopicRef>.unmodifiable(sortedCopy(topics, compareTopicRefs))`, where `topics` lists the topic of every `TopicInput` of every edge, stage and sink edges alike, and `writes` the same over the `output` of every sink edge. Repeats collapse in the set, which keeps the sorted order (U1).

After the class:

```dart
// Throws ArgumentError when [edges] break a rule of a well-formed definition
// (topology-ir@v1 G6): each stage input names an earlier stage edge, no stage
// edge follows a sink edge, every stage edge is consumed by a later edge, and
// no state topic has a second sink edge.
void _checkWellFormed(List<TransformEdge> edges) {
```

It throws an `ArgumentError` named `transforms` for each of these, its message naming the edge index:

1. walking the edges in order, at edge `i`, a `StageInput(n)` with `n < 0 || n >= i` (negative, the edge itself or a later one, or beyond the list): the `n < 0` part is reachable only without assertions (Global Constraints, Tests);
2. at edge `i`, a `StageInput(n)` whose edge `edges[n].isSink`;
3. a stage edge after the first sink edge;
4. a sink edge whose `output` is a state topic (`variant == TopicVariant.state`) that an earlier sink edge already writes, compared by `TopicRef` equality, so two refs built apart, or from two types that render alike, are one topic; event and replay topics take any number of sinks;
5. after the walk, a stage edge that no `StageInput` of a later edge named.

Equality, after the fields:

```dart
  // topologyId, scope and transforms element by element (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopologyDefinition &&
      other.topologyId == topologyId &&
      other.scope == scope &&
      elementsEqual(other.transforms, transforms);

  @override
  int get hashCode =>
      Object.hash(topologyId, scope, Object.hashAll(transforms));
```

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)`, `+174: All tests passed!` (166 before, 8 added), `No issues found!` (T4.4).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G6; echo "exit: $?"`
Expected: `2 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G6` and `exit: 0` (T4.4).
Run: `fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G9,G10; echo "exit: $?"`
Expected: `10 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G5, G6, G9, G10`, `61 fixtures: 61 passed, 0 failed, 0 pending` and `exit: 0` (G).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/ir/definition.dart packages/nidana_dart_contracts/test/topology_definition_test.dart packages/nidana_dart_contracts/test/src/cart_elsewhere.dart
git commit -m "feat(dart_contracts): check topology definitions and derive reads and writes" -m "<the co-author trailer your harness gives>"
```

### Task 5: The findings' value semantics

You are filling in the value semantics of `TopologyCycle`, `SelfReference`, `WriterConflict`, `ScopeViolation`, `TopicDeclaration` and `TopicNameCollision` in `packages/nidana_dart_contracts/lib/src/analysis/findings.dart`: constructors that put their lists in the orders the Interface names (G23), unmodifiable copies (G3) and equality (G7). The analyses in `analyses.dart` keep throwing until nidana.model.12. Run every command from the repository root with `fvm dart`. No case of the gate's restriction depends on this task: G23's case also runs the analyses and joins the gate at nidana.model.12.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/analysis/findings.dart`
- Create: `packages/nidana_dart_contracts/test/findings_test.dart`

**Interfaces:**
- Consumes: Task 3's `compareTopicRefs`, `compareTopologyIds`, `compareMessageSources` and `sortedCopy` (import `'../ir/canonical_order.dart'`); `elementsEqual` (import `'../topic/list_equality.dart'`); `TopicRef` and `MessageSource` equality (nidana.model.8).
- Produces: the four sorting constructors, with every parameter name and field type kept; `==` and `hashCode` of the six types; in the library, `int _bySiteThenTopic(TopicDeclaration a, TopicDeclaration b)`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/findings_test.dart` with exactly this content:

```dart
// The value semantics of topology-ir@v1's findings, declarations and
// collisions: constructors that put their lists in the orders the Interface
// names (G23), unmodifiable copies (G3) and value equality (G7). G23's
// conformance case also runs the analyses, so it joins the gate at
// nidana.model.12, and these tests check it until then.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

TopicRef ref(String name, [TopicVariant variant = TopicVariant.event]) =>
    TopicRef(name: name, variant: variant, typeName: 'int');

TopicRef state(String name) => ref(name, TopicVariant.state);

void main() {
  test('G23 a cycle sorts its ids and its topics in canonical order, '
      'repeated elements kept', () {
    final TopologyCycle c = TopologyCycle(
      topologyIds: <String>['b', 'a', 'B', 'a'],
      topics: <TopicRef>[ref('y'), ref('x', TopicVariant.replay), state('x')],
    );
    expect(c.topologyIds, <String>['B', 'a', 'a', 'b']);
    expect(c.topics, <TopicRef>[
      state('x'),
      ref('x', TopicVariant.replay),
      ref('y'),
    ]);
  });

  test('G23 a self-reference sorts its edges ascending, repeated indices '
      'kept', () {
    expect(
      SelfReference(
        topologyId: 't',
        topic: state('s'),
        edges: <int>[10, 2, 2, 0],
      ).edges,
      <int>[0, 2, 2, 10],
    );
  });

  test('G23 a writer conflict sorts its writers by rendering, equal sources '
      'repeated', () {
    expect(
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[
          TopologySource('t'),
          ServiceSource('s'),
          PageSource('/p'),
          ServiceSource('s'),
          ExecutorSource('e'),
        ],
      ).writers,
      const <MessageSource>[
        ExecutorSource('e'),
        PageSource('/p'),
        ServiceSource('s'),
        ServiceSource('s'),
        TopologySource('t'),
      ],
    );
  });

  test('G23 a collision sorts its declarations by site, then topic in '
      'canonical order, repeated declarations kept', () {
    const TopicDeclaration bState = TopicDeclaration(
      topic: TopicRef(name: 'n', variant: TopicVariant.state, typeName: 'int'),
      site: 'lib/b.dart:1',
    );
    const TopicDeclaration aEvent = TopicDeclaration(
      topic: TopicRef(name: 'n', variant: TopicVariant.event, typeName: 'int'),
      site: 'lib/a.dart:1',
    );
    const TopicDeclaration aState = TopicDeclaration(
      topic: TopicRef(name: 'n', variant: TopicVariant.state, typeName: 'int'),
      site: 'lib/a.dart:1',
    );
    expect(
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[bState, aEvent, aState, bState],
      ).declarations,
      <TopicDeclaration>[aState, aEvent, bState, bState],
    );
  });

  test('G23 findings and collisions built in any order are equal, with '
      'equal hash codes', () {
    final List<(Object, Object)> pairs = <(Object, Object)>[
      (
        TopologyCycle(
          topologyIds: <String>['a', 'b'],
          topics: <TopicRef>[ref('x'), ref('y')],
        ),
        TopologyCycle(
          topologyIds: <String>['b', 'a'],
          topics: <TopicRef>[ref('y'), ref('x')],
        ),
      ),
      (
        SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0, 1]),
        SelfReference(topologyId: 't', topic: state('s'), edges: <int>[1, 0]),
      ),
      (
        WriterConflict(
          topic: state('w'),
          writers: const <MessageSource>[ServiceSource('a'), PageSource('b')],
        ),
        WriterConflict(
          topic: state('w'),
          writers: const <MessageSource>[PageSource('b'), ServiceSource('a')],
        ),
      ),
      (
        TopicNameCollision(
          name: 'n',
          declarations: <TopicDeclaration>[
            TopicDeclaration(topic: ref('n'), site: 'a'),
            TopicDeclaration(topic: state('n'), site: 'b'),
          ],
        ),
        TopicNameCollision(
          name: 'n',
          declarations: <TopicDeclaration>[
            TopicDeclaration(topic: state('n'), site: 'b'),
            TopicDeclaration(topic: ref('n'), site: 'a'),
          ],
        ),
      ),
    ];
    for (final (Object sorted, Object shuffled) in pairs) {
      expect(shuffled, sorted);
      expect(shuffled.hashCode, sorted.hashCode);
    }
  });

  test('G7 findings, declarations and collisions are unequal when any field '
      'the Interface names differs', () {
    ScopeViolation violation({
      TopicRef? topic,
      MessageSource owner = const TopologySource('o'),
      Scope ownerScope = Scope.page,
      String readerId = 'r',
      Scope readerScope = Scope.module,
    }) => ScopeViolation(
      topic: topic ?? state('t'),
      owner: owner,
      ownerScope: ownerScope,
      readerId: readerId,
      readerScope: readerScope,
    );
    expect(violation(), violation());
    expect(violation().hashCode, violation().hashCode);
    expect(violation(topic: state('u')), isNot(violation()));
    expect(violation(owner: const ServiceSource('o')), isNot(violation()));
    expect(violation(ownerScope: Scope.module), isNot(violation()));
    expect(violation(readerId: 's'), isNot(violation()));
    expect(violation(readerScope: Scope.application), isNot(violation()));
    expect(
      TopologyCycle(topologyIds: <String>['a', 'b'], topics: <TopicRef>[]),
      isNot(
        TopologyCycle(topologyIds: <String>['a', 'c'], topics: <TopicRef>[]),
      ),
    );
    expect(
      TopologyCycle(topologyIds: <String>['a'], topics: <TopicRef>[ref('x')]),
      isNot(
        TopologyCycle(topologyIds: <String>['a'], topics: <TopicRef>[ref('y')]),
      ),
    );
    expect(
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0]),
      isNot(SelfReference(topologyId: 'u', topic: state('s'), edges: <int>[0])),
    );
    expect(
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0]),
      isNot(SelfReference(topologyId: 't', topic: state('r'), edges: <int>[0])),
    );
    expect(
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0]),
      isNot(
        SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0, 0]),
      ),
    );
    expect(
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[ServiceSource('a')],
      ),
      isNot(
        WriterConflict(
          topic: state('v'),
          writers: const <MessageSource>[ServiceSource('a')],
        ),
      ),
    );
    expect(
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[ServiceSource('a')],
      ),
      isNot(
        WriterConflict(
          topic: state('w'),
          writers: const <MessageSource>[
            ServiceSource('a'),
            ServiceSource('a'),
          ],
        ),
      ),
    );
    expect(
      TopicDeclaration(topic: ref('a'), site: 'x'),
      TopicDeclaration(topic: ref('a'), site: 'x'),
    );
    expect(
      TopicDeclaration(topic: ref('a'), site: 'x').hashCode,
      TopicDeclaration(topic: ref('a'), site: 'x').hashCode,
    );
    expect(
      TopicDeclaration(topic: ref('a'), site: 'x'),
      isNot(TopicDeclaration(topic: state('a'), site: 'x')),
    );
    expect(
      TopicNameCollision(name: 'n', declarations: <TopicDeclaration>[]),
      isNot(TopicNameCollision(name: 'm', declarations: <TopicDeclaration>[])),
    );
    expect(
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[
          TopicDeclaration(topic: ref('n'), site: 'a'),
        ],
      ),
      isNot(TopicNameCollision(name: 'n', declarations: <TopicDeclaration>[])),
    );
  });

  test('G3 findings and collisions keep unmodifiable copies of their '
      'lists', () {
    final List<String> ids = <String>['a', 'b'];
    final List<TopicRef> topics = <TopicRef>[ref('x')];
    final List<int> edges = <int>[0];
    final List<MessageSource> writers = <MessageSource>[
      const ServiceSource('s'),
    ];
    final List<TopicDeclaration> declarations = <TopicDeclaration>[
      TopicDeclaration(topic: ref('n'), site: 'a'),
    ];
    final TopologyCycle cycle = TopologyCycle(topologyIds: ids, topics: topics);
    final SelfReference self = SelfReference(
      topologyId: 't',
      topic: state('s'),
      edges: edges,
    );
    final WriterConflict conflict = WriterConflict(
      topic: state('w'),
      writers: writers,
    );
    final TopicNameCollision collision = TopicNameCollision(
      name: 'n',
      declarations: declarations,
    );
    ids.add('c');
    topics.clear();
    edges.add(1);
    writers.clear();
    declarations.clear();
    expect(cycle.topologyIds, <String>['a', 'b']);
    expect(cycle.topics, <TopicRef>[ref('x')]);
    expect(self.edges, <int>[0]);
    expect(conflict.writers, const <MessageSource>[ServiceSource('s')]);
    expect(collision.declarations, hasLength(1));
    expect(() => cycle.topologyIds.add('z'), throwsUnsupportedError);
    expect(() => cycle.topics.clear(), throwsUnsupportedError);
    expect(() => self.edges.add(2), throwsUnsupportedError);
    expect(() => conflict.writers.clear(), throwsUnsupportedError);
    expect(() => collision.declarations.clear(), throwsUnsupportedError);
  });

  test('G7 findings of two variants are never equal', () {
    final List<TopologyFinding> findings = <TopologyFinding>[
      TopologyCycle(topologyIds: <String>['t'], topics: <TopicRef>[state('s')]),
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[]),
      WriterConflict(topic: state('s'), writers: const <MessageSource>[]),
      ScopeViolation(
        topic: state('s'),
        owner: const TopologySource('t'),
        ownerScope: Scope.page,
        readerId: 't',
        readerScope: Scope.page,
      ),
    ];
    for (int i = 0; i < findings.length; i++) {
      for (int j = 0; j < findings.length; j++) {
        expect(findings[i] == findings[j], i == j, reason: '$i against $j');
      }
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fvm dart test packages/nidana_dart_contracts/test/findings_test.dart; echo "exit: $?"`
Expected: `+1 -7: Some tests failed.` and `exit: 1`: seven fail on order, copies or equality; `G7 findings of two variants are never equal` passes already, under identity equality, and guards the `==` this task writes (T5.2).

- [ ] **Step 3: Implement the findings' value semantics in `lib/src/analysis/findings.dart`**

The four constructors that take lists become initializer lists that sort; their parameters stop being initializing formals and keep their names and types:

```dart
  TopologyCycle({
    required List<String> topologyIds,
    required List<TopicRef> topics,
  }) : topologyIds = sortedCopy(topologyIds, compareTopologyIds),
       topics = sortedCopy(topics, compareTopicRefs),
       super._();

  SelfReference({
    required this.topologyId,
    required this.topic,
    required List<int> edges,
  }) : edges = sortedCopy(edges, (int a, int b) => a.compareTo(b)),
       super._();

  WriterConflict({required this.topic, required List<MessageSource> writers})
    : writers = sortedCopy(writers, compareMessageSources),
      super._();

  TopicNameCollision({
    required this.name,
    required List<TopicDeclaration> declarations,
  }) : declarations = sortedCopy(declarations, _bySiteThenTopic);
```

`ScopeViolation` and `TopicDeclaration` keep their `const` constructors unchanged. After the class `TopicNameCollision`:

```dart
// The order of a collision's declarations: by site, then topic in canonical
// order (topology-ir@v1 G23).
int _bySiteThenTopic(TopicDeclaration a, TopicDeclaration b) {
  final int bySite = a.site.compareTo(b.site);
  return bySite != 0 ? bySite : compareTopicRefs(a.topic, b.topic);
}
```

Each of the six types gains `==` and `hashCode` over exactly its fields, lists through `elementsEqual` and `Object.hashAll`, under a comment line naming them: `// topologyIds and topics, element by element (topology-ir@v1 G7)`; `// topologyId, topic and edges, element by element (topology-ir@v1 G7)`; `// topic and writers, element by element (topology-ir@v1 G7)`; `// all five fields (topology-ir@v1 G7)` for `ScopeViolation`; `// topic and site (topology-ir@v1 G7)`; `// name and declarations, element by element (topology-ir@v1 G7)`. Each `==` starts with `other is` the class itself, so findings of two variants are never equal.

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)`, `+182: All tests passed!` (174 before, 8 added), `No issues found!` (T5.4). `test/topology_ir_declarations_test.dart`, whose findings are already in canonical order, passes unchanged.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/analysis/findings.dart packages/nidana_dart_contracts/test/findings_test.dart
git commit -m "feat(dart_contracts): sort finding lists and give findings value equality" -m "<the co-author trailer your harness gives>"
```

### Task 6: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.10.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.10.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 5; the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run the gate of Global Constraint 4 exactly (it is the Gate line of the Phase block in `hsdd-context/nidana.model.10.md`), as `(<gate>) > "${TMPDIR:-/tmp}/nidana.model.10-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after. Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+182: All tests passed!`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `31 fixtures: 31 passed, 0 failed, 0 pending`, `27 fixtures: 27 passed, 0 failed, 0 pending`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 10 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G5, G6, G9, G10` and `61 fixtures: 61 passed, 0 failed, 0 pending` (G). Any other result stops here: a failure is fixed in the task that owns the code or, for a fixture that fails against code that follows this plan, reported as a contract gap (Global Constraints).

The `+182` is this plan's count; it is higher by the tests the implementers added.

- [ ] **Step 2: Run the checklist**

`<base>` below is the parent of Task 1's commit (`git log --format=%H -n 1 <Task 1's commit>^`). Run each and keep its output:
- `fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G9 ' -r expanded` (expected: the three G9 case names, then `+3: All tests passed!`) and `fvm dart test packages/nidana_dart_contracts/test/function_ref_test.dart -r expanded` (expected: its six names, then `+6: All tests passed!`): `FunctionRef.of` gives on the VM the names the derivation table lists, under `dart test` (C).
- `fvm dart test packages/nidana_dart_contracts/test/transform_edge_test.dart packages/nidana_dart_contracts/test/topology_definition_test.dart --name '^G[56] ' -j 1 -r expanded` (expected: ten names, four from `transform_edge_test.dart` and six from `topology_definition_test.dart`, then `+10: All tests passed!`): an edge or a definition that breaks a rule throws at construction, naming the argument at fault, the negative index included (C).
- `fvm dart run nidana_contract_check topology-ir --set behavior; echo "exit: $?"` (expected: `exit: 1` and `cases (11 passed, 32 failed, ...)`; the eleven are the restriction's ten and `G7 IR values are equal, with equal hash codes, exactly when their fields are`; the 32 others call what nidana.model.11 to nidana.model.14 deliver) (U).
- `grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/analysis/findings.dart; echo "exit: $?"` (expected: no line, `exit: 1`).
- `grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/analysis; echo "exit: $?"` (expected: no line, `exit: 1`).
- `grep -rnE "^(import|export) .*graph/" packages/nidana_dart_contracts/lib/src/ir; echo "exit: $?"` (expected: no line, `exit: 1`).
- `git diff --name-status <base> HEAD -- packages/nidana_dart_contracts` (expected: ten lines, `M` for `lib/src/ir/function_ref.dart`, `lib/src/ir/definition.dart` and `lib/src/analysis/findings.dart`, `A` for `lib/src/ir/canonical_order.dart`, the five new test files and `test/src/cart_elsewhere.dart`).
- `git status --short pubspec.lock` and `git diff --stat <base> HEAD -- packages/nidana_dart_contracts/pubspec.yaml` (expected: no output from either).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.10.verification.md` at spot-check depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.10 - IR values and function references` (a spaced hyphen; no em-dash anywhere in the file). Short: commands, expected output, what to eyeball, Learnings.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as Step 1 ran it, saying that it replays topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets in full and its `behavior` set through the binding `nidana_dart_contracts_test.dart` under `dart test`, restricted to the guarantees this phase delivers, beside topic-model@v1 unrestricted and topology-dsl@v2's three type-level sets; the checklist commands of Step 2.
- **Expected output:** the gate's exit code and lines of Step 1; the checklist's expected results of Step 2.
- **Observed:** dated, with the gate's start and end times, the branch and commit, and Dart 3.13.5 through `fvm`; the gate's exit code and its lines as they appeared; then a checklist of `- [x]` lines, each with its result, to eyeball:
  - `FunctionRef.of` gives on the VM the names topology-ir@v1's derivation table lists: the suite's three G9 cases (public names, anonymous forms, private names with `@` and a key) and the package test's six, by name (checklist), beside the dry run's `dart run` table (`docs/auto-run/experiments/ir-values-plan/output.txt`, F1 R);
  - an edge or a definition that breaks a rule throws at construction: the ten G5 and G6 package tests by name (checklist), each asserting the `ArgumentError` and the argument it names, the negative stage input run without assertions included, beside the suite's three G5 and two G6 cases in the gate's replay; the private constructors have no caller but the checking factories;
  - the gate's topology-ir replay, with its pass count (10 of 10, against 1 of 10 before this phase), and the unrestricted count (11 of 43), naming the G7 case that passes ahead of its restriction;
  - the findings' constructors sort, keep repeats and copy (the package's G23 tests in the gate's package run; G23's case joins the gate at nidana.model.12);
  - no `UnimplementedError` and no `ignore:` remains under `lib/src/ir/` or in `findings.dart`, `lib/src/ir/` imports nothing from `graph/`, the export lists are unchanged (`exports_test.dart` passes), `purity_test.dart` passes over the changed libraries (topic-model@v1 G25, G26), and the lockfile and `pubspec.yaml` are unchanged.
- **Outstanding:** `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found the two below and the sizing line; write each that still holds, and any the gate finds:
  - `- topology-ir@v1's conformance suite does not reach three rules this phase implements: G5's retry rejection on combinators other than map, G6's negative stage input (its binding runs under dart test with assertions enabled, so StageInput's own assertion fires first, and topology-ir@v1's Validation has no not-executable line for that part of G6), and the edge order in a definition's equality (G7); this phase's package tests pin each (S134 dry run, seeded defects D4, D5 and D11, and suite_reach.txt). Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)`;
  - `- Two state topics whose value types render alike, one class name in two libraries, are two Topics and one TopicRef, so a definition with a sink on each throws ArgumentError; this phase pins the IR side, and nidana.model.11's buildDefinition() will raise it for a plan that planOf accepts. Disposition: dropped (already routed to the end-of-node governance sweep by S132's final review)`;
  - one sizing line: the phase scope's estimate of about 400 lines in about 6 files against the measured product diff (Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint).
- **Metrics:** one line: the product diff, `git diff --stat <base> HEAD -- packages/`, in files and lines, the library and the tests apart, beside the estimate of about 400 lines in about 6 files; the task count, 6 of the allowed 7.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.10.verification.md
git commit -m "docs(verify): nidana.model.10 verification" -m "<the co-author trailer your harness gives>"
```
