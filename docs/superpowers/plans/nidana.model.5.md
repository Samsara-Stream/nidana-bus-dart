# nidana.model.5 topology-ir@v1 Declarations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the declarations of topology-ir@v1's sections Graphs, Renderers, The JSON form and Analyses in `packages/nidana_dart_contracts`, under `lib/src/graph/`, `lib/src/analysis/`, `lib/src/json/` and `lib/src/render/`, exported by the new public library `lib/topology_ir.dart`, which does not re-export the main library, so that `fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set structure,surface,reject,schema` passes all 117 fixtures, the first replay of topology-ir@v1's surface and reject sets against the real package, and `test/exports_test.dart` pins the new library's 24 names by exact set.

**Architecture:** A type-level phase (nidana.model D3): signatures, modifiers, `@immutable`, constructors with their defaults and `const`, a final field behind every getter, and `show` lists. The generative constructors store their arguments; every body that computes throws `UnimplementedError`; `==`, `hashCode` and `toString` stay `Object`'s. One library per area (D4): `graph/graph.dart` holds Graphs and the `GraphRenderer` interface that `TopologyGraph.render` names, so `render/`, `json/` and `analysis/` import `graph/` and the import graph stays acyclic; `analysis/findings.dart` holds the findings and the topic declarations, `analysis/analyses.dart` the six functions, `json/codec.dart` the codec and `JsonRenderer`, `render/renderers.dart` the Mermaid and Graphviz renderers. The main library, `topology_plan.dart` and `lib/src/ir/` are complete from nidana.model.4, and no task edits them.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:meta` 1.19.0 (`@immutable`), the package's only dependency; `package:test` for the package's tests; the replay tool `nidana_contract_check` as nidana.model.2 left it.

**Spec:** `hsdd-context/superpowers/nidana.model.5.md` (the derivative; the phase context with topic-model@v1's, topology-dsl@v2's and topology-ir@v1's Interfaces and Guarantees sits between its markers). The declarations and dartdoc below are copied from topology-ir@v1's Graphs, Renderers, The JSON form and Analyses, `hsdd/contract/topology-ir.md` lines 206 to 439 (the derivative's lines 1043 to 1276 carry the same text). Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D1 item 2 (line 77), D3 (line 102, with its Restated paragraph), D4 (line 112, with its Restated paragraph), D5 (line 128) and D6 (line 135; `test/purity_test.dart`, whose hardened reader admits only `meta`, the package's own `.dart` libraries and the allowed `dart:` libraries, reads every new library). The fixtures the gate replays: `hsdd/contract/fixture/topology-ir/surface/` and `reject/`, and the schema set (`hsdd/contract/schema/topology-ir.schema.json` over `valid/` and `invalid/`), beside topic-model@v1's and topology-dsl@v2's, under `hsdd/contract/fixture/analysis_options.yaml`; the `render/` data directory is read only by the behavior set, which this gate does not run. Evidence: `docs/auto-run/experiments/topology-ir-declarations-plan/` (`run.sh`, `output.txt`, `draft/`), a dry run of this plan's tasks in a temporary copy of HEAD `d302aab`; labels such as T1.4, G or R below name the steps of its `output.txt`. `draft/` is evidence, not code to copy: the code blocks below are the source, and they are its formatter-stable text (X). `docs/auto-run/experiments/model-main-library-closure/` Q6 (S109) is the earlier proof that a `topology_ir.dart` beside nidana.model.4's main library passes this gate's replay.

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 4 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set structure,surface,reject,schema` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.5.verification.md from
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

- Toolchain: `fvm dart` only, every command from the repository root, no global tooling. No dependency changes: no `pubspec.yaml` is edited, and `pubspec.lock` stays byte-identical (G2).
- Files: everything this phase writes lives in `packages/nidana_dart_contracts/` (`lib/`, `test/`), except the verification doc of Task 3. Under `lib/` it only creates files: `lib/topology_ir.dart` and the files under `lib/src/graph/`, `analysis/`, `json/` and `render/`; no file nidana.model.3 or nidana.model.4 wrote under `lib/` changes (D1 item 2, D4). Under `test/` it creates `topology_ir_declarations_test.dart` and edits `exports_test.dart`. `README.md`, `CHANGELOG.md` and `LICENSE` stay as nidana.model.3 wrote them (D4). Nothing under `hsdd/` changes otherwise, and nothing under `hsdd/contract/` ever.
- Declarations (D3): every name, signature, modifier, default and `const` exactly as `hsdd/contract/topology-ir.md` lines 206 to 439 write them, with the dartdoc copied as written, never from memory. Every getter that returns a stored value is a final field; the reject set assigns to `TopologyGraph.topologies`, `ShellClaim.scope` and `SelfReference.edges`, which report `assignment_to_final` only on a field (a getter reports `assignment_to_final_no_setter`, D2). `ShellClaim` and `TopologyGraph` each have one generative constructor, private and `const` (`._`), beside the factory the Interface declares. `TopologyFinding` declares `const TopologyFinding._()`, because `ScopeViolation`'s const constructor needs a const super constructor. `@immutable` (the Interface's prose: every value type is immutable) sits on `ShellClaim`, `TopologyGraph`, the sealed `TopologyFinding`, which carries it for its four variants as `EdgeInput` and `MessageSource` do, `TopicDeclaration` and `TopicNameCollision`; not on `GraphRenderer` or the renderers, which are not value types (G7 names none). Each of the three renderers declares `@override String render(TopologyGraph graph)`, which implementing `GraphRenderer` requires and the root lint set's `annotate_overrides` annotates. No class overrides `==`, `hashCode` or `toString` in this phase (nidana.model.10 and nidana.model.11 deliver G7 and G23).
- Bodies: the generative constructors of `TopologyCycle`, `SelfReference`, `WriterConflict`, `ScopeViolation`, `TopicDeclaration` and `TopicNameCollision` store their arguments as given; sorting and copying are nidana.model.10's (G23) and nidana.model.11's (G3). Every other body throws `UnimplementedError`: the factories of `ShellClaim` and `TopologyGraph`, `TopologyGraph.render`, `toGraph`, the three renderers' `render`, the four codec functions and the six analysis functions. No library imports `dart:convert` yet: `JsonRenderer`'s body throws, and an unused import is reported; nidana.model.13 adds it.
- Comments: the Interface's trailing `//` comments stay trailing line comments, except the five the formatter would split across two lines, which sit on the line above their fields, as nidana.model.4 placed `TopologyDefinition.reads` and `.writes` (F): `TopologyGraph.topologies`, `.claims` and `.topics`, `WriterConflict.writers` and `TopicNameCollision.declarations`. Add no other comment or dartdoc beyond the blocks below.
- Analyzer: `fvm dart analyze --fatal-infos` at the root reports nothing. This phase adds the package's fourth and fifth suppressions, `// ignore: unused_element` above `ShellClaim._` and `TopologyGraph._`, each under a one-line reason, as nidana.model.4 did above `TransformEdge._` and `TopologyDefinition._`: a private constructor beside a factory that throws is reported as `unused_element` (G2).
- Tests: run from the root as `fvm dart test packages/nidana_dart_contracts`. No test asserts a body that throws `UnimplementedError` or an identity comparison, and every expectation stays true after nidana.model.8 (value equality of topic references and sources), nidana.model.10 (sorted finding lists, value equality of findings) and nidana.model.11. No test uses a `test` API newer than 1.31.1.
- Contract gaps (ADR-001 item 8): this gate is the first replay of topology-ir@v1's surface and reject sets against a real package. A fixture that fails against a declaration matching this plan's block is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the fixture path and line, the reported line, severity, code and message, the marker's code, the guarantee its `// covers:` header names, and the fix you would propose. A reject line where the analyzer reports two codes, one marked and one not, is the gap ADR-001 item 4's marker form cannot express (a marker names one code on the next line, and the structure set rejects stacked markers): report it as a contract gap for hsdd-adr. The dry run passed every fixture with one code per line (T2.4, R), so a FAIL most likely means the code differs from its block.
- Formatting and commits: run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output; it changes nothing when they are copied exactly). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for a Sonnet implementer. No em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.

## Review Focus

The input classes the spec implies but the surface and reject sets do not exercise, most likely to bite first; each has its test in the owning task.

1. **A name in the wrong public library**: `surface/graphs.dart` uses every name of `topology_ir.dart`, so a missing name fails the replay, but an extra one (a helper under `lib/src/`, a main-library name shown again) passes it, and a re-export of the whole main library fails it only through `unnecessary_import` (D1). Expected: `topology_ir.dart` shows exactly the 24 names of its four sections and the main library still its 40. Test: Task 2 (`exports_test.dart`).
2. **Findings and declarations in a const table**: a diagnostic mapper or a test keeps expected findings as constants. The Interface makes `ScopeViolation` and `TopicDeclaration` const, while the surface builds `ScopeViolation` only in a non-const list, so a non-const constructor passes the replay (D3). Expected: `const ScopeViolation(...)` and `const TopicDeclaration(...)` compile and keep their fields. Test: Task 1.
3. **Findings and collisions built by hand with lists already in the Interface's orders**: tests and hosts build them that way, and nidana.model.10's constructors will sort them (G23). Expected: each list reads back element by element, equal writers repeated, so the expectation holds before and after the sort. Test: Task 1.
4. **Dispatch over a finding at run time**: activation and the workspace scan map each finding to a diagnostic by a switch, which the surface only compiles. Expected: each of the four variants takes its own case. Test: Task 1.
5. **Renderers as constants beside an application's own**: a host keeps a const table of renderers per output format. Expected: the three renderers and an application's `GraphRenderer` fit one `const List<GraphRenderer>`, each of its own class. Test: Task 2.

## Routed items

- ADR-001 item 4's one-code marker (from S103; nidana.model.3 and nidana.model.4 found no reject line with two codes in their contracts and carried the question here): with this phase's declarations, no reject line of topic-model@v1 (10 libraries), topology-dsl@v2 (9) or topology-ir@v1 (3) carries two codes (R: 22 libraries, 0 such lines). Disposition: closed for nidana.model's three contracts; Task 3 records it as a dropped Learning. The reject libraries of bus-api, bus-testing, navigation-api and flutter-binding first replay at their own producers' gates.
- The baseline S109 measured and S114 recorded: `fvm dart run nidana_contract_check topology-ir --set surface,reject` prints `14 fixtures: 11 passed, 3 failed, 0 pending` before this phase, the three being the libraries that import `topology_ir.dart` (S1). Task 1 Step 2 records it as the phase's failing replay; Task 1 ends at `13 passed, 1 failed` (T1.4) and Task 2 at `14 passed, 0 failed` (T2.4).

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/graph/graph.dart` | 1 | topology-ir@v1 Graphs: `ShellClaim`, `TopologyGraph`, `TopologyDefinitionGraph`; and `GraphRenderer`, which `TopologyGraph.render` names |
| `{pkg}/lib/src/analysis/findings.dart` | 1 | topology-ir@v1 Analyses, the values: `TopologyFinding` and its four variants, `TopicDeclaration`, `TopicNameCollision` |
| `{pkg}/lib/topology_ir.dart` | 1, 2 | The third public library: two export directives (1), then five, 24 names (2) |
| `{pkg}/test/topology_ir_declarations_test.dart` | 1, 2 | What the new declarations fix before any body computes: findings (1), renderers (2) |
| `{pkg}/lib/src/analysis/analyses.dart` | 2 | topology-ir@v1 Analyses, the functions: the five `find` functions and `analyzeTopologyGraph` |
| `{pkg}/lib/src/json/codec.dart` | 2 | topology-ir@v1 The JSON form: the four codec functions; and `JsonRenderer` |
| `{pkg}/lib/src/render/renderers.dart` | 2 | topology-ir@v1 Renderers: `MermaidRenderer`, `GraphvizRenderer` |
| `{pkg}/test/exports_test.dart` | 2 | The three public libraries' export lists, exactly |
| `hsdd/verify/nidana.model.5.verification.md` | 3 | The verification doc |

---

### Task 1: Graphs, claims and findings

You are creating `lib/topology_ir.dart` in `packages/nidana_dart_contracts`, the second public library topology-ir@v1 names and the package's third, with its first two areas: `lib/src/graph/graph.dart` (the section Graphs, and `GraphRenderer`, which `TopologyGraph.render` names) and `lib/src/analysis/findings.dart` (the values of the section Analyses). Run every command from the repository root with `fvm dart`. The main library, `lib/topology_plan.dart` and everything under `lib/src/ir/`, `lib/src/topic/` and `lib/src/topology/` are complete from nidana.model.3 and nidana.model.4; edit none of them, and import their files by relative path. Land the declarations below exactly; their dartdoc is copied from the code blocks of `hsdd/contract/topology-ir.md`: Graphs (lines 211 to 248), `GraphRenderer` (lines 256 to 260) and Analyses (lines 356 to 400 and 411 to 424). These are the declarations the reject libraries `ir_families_are_closed.dart` (G1) and `ir_values_are_immutable.dart` (G3) need, so both pass after this task, and `surface/graphs.dart` fails only on Task 2's names.

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/graph/graph.dart`
- Create: `packages/nidana_dart_contracts/lib/src/analysis/findings.dart`
- Create: `packages/nidana_dart_contracts/lib/topology_ir.dart` (two export directives; Task 2 completes it)
- Test: `packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart`

**Interfaces:**
- Consumes: `TopicRef` from `lib/src/topic/topic.dart`, `MessageSource` from `lib/src/topic/message_source.dart` and `Scope` from `lib/src/topic/scope.dart` (nidana.model.3); `TopologyDefinition` from `lib/src/ir/definition.dart` (nidana.model.4).
- Produces (Task 2 imports `../graph/graph.dart` and `findings.dart`): in `graph.dart`, `final class ShellClaim` (`factory ShellClaim({required MessageSource source, Scope scope = Scope.application, required Set<TopicRef> writes})`; final fields `source`, `scope`, `writes`), `final class TopologyGraph` (`factory TopologyGraph({Iterable<TopologyDefinition> topologies, Iterable<ShellClaim> claims})`; final fields `topologies`, `claims`, `topics`; `String render(GraphRenderer renderer)`), `extension TopologyDefinitionGraph on TopologyDefinition` (`TopologyGraph toGraph()`), `abstract interface class GraphRenderer` (`String render(TopologyGraph graph)`); in `findings.dart`, `sealed class TopologyFinding` with `const TopologyFinding._()`, `final class TopologyCycle`, `SelfReference`, `WriterConflict`, `ScopeViolation` (const), `TopicDeclaration` (const) and `TopicNameCollision`, each with the named constructor parameters the Interface gives and a final field per getter.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart`:

```dart
// What the declarations of topology-ir@v1's topology_ir.dart fix before any
// body computes (nidana.model D3). Every expectation here holds as well once
// the phases that deliver value equality and the sorted finding lists land.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

const TopicRef cart = TopicRef(
  name: 'checkout.cart',
  variant: TopicVariant.state,
  typeName: 'Cart',
);
const TopicRef total = TopicRef(
  name: 'checkout.total',
  variant: TopicVariant.state,
  typeName: 'int',
);

/// The variant [f] is, by an exhaustive switch.
String variantOf(TopologyFinding f) => switch (f) {
  TopologyCycle() => 'cycle',
  SelfReference() => 'self-reference',
  WriterConflict() => 'writer conflict',
  ScopeViolation() => 'scope violation',
};

void main() {
  test('findings keep the lists they are given in the orders the '
      'Interface names, equal writers repeated', () {
    const ServiceSource history = ServiceSource('search-history');
    final TopologyCycle cycle = TopologyCycle(
      topologyIds: <String>['cart', 'pricing'],
      topics: <TopicRef>[cart, total],
    );
    final SelfReference self = SelfReference(
      topologyId: 'pricing',
      topic: total,
      edges: <int>[0, 2],
    );
    final WriterConflict conflict = WriterConflict(
      topic: cart,
      writers: <MessageSource>[history, history, const TopologySource('cart')],
    );
    expect(cycle.topologyIds, <String>['cart', 'pricing']);
    expect(cycle.topics, <TopicRef>[cart, total]);
    expect(self.topologyId, 'pricing');
    expect(self.topic, total);
    expect(self.edges, <int>[0, 2]);
    expect(conflict.topic, cart);
    expect(conflict.writers, <MessageSource>[
      history,
      history,
      const TopologySource('cart'),
    ]);
  });

  test('a ScopeViolation is const and keeps its five fields', () {
    const ScopeViolation violation = ScopeViolation(
      topic: cart,
      owner: TopologySource('cart'),
      ownerScope: Scope.page,
      readerId: 'summary',
      readerScope: Scope.application,
    );
    expect(violation.topic, cart);
    expect(violation.owner, const TopologySource('cart'));
    expect(violation.ownerScope, Scope.page);
    expect(violation.readerId, 'summary');
    expect(violation.readerScope, Scope.application);
  });

  test('a TopicDeclaration is const and keeps its topic and site; a '
      'TopicNameCollision keeps its name and its declarations by site', () {
    const TopicDeclaration first = TopicDeclaration(
      topic: cart,
      site: 'lib/a_topics.dart:3',
    );
    const TopicDeclaration second = TopicDeclaration(
      topic: TopicRef(
        name: 'checkout.cart',
        variant: TopicVariant.event,
        typeName: 'Cart',
      ),
      site: 'lib/b_topics.dart:9',
    );
    final TopicNameCollision collision = TopicNameCollision(
      name: 'checkout.cart',
      declarations: <TopicDeclaration>[first, second],
    );
    expect(first.topic, cart);
    expect(first.site, 'lib/a_topics.dart:3');
    expect(collision.name, 'checkout.cart');
    expect(collision.declarations, <TopicDeclaration>[first, second]);
  });

  test('a switch over TopologyFinding tells its four variants apart', () {
    final List<TopologyFinding> findings = <TopologyFinding>[
      TopologyCycle(topologyIds: <String>['a', 'b'], topics: <TopicRef>[cart]),
      SelfReference(topologyId: 'a', topic: cart, edges: <int>[0]),
      WriterConflict(
        topic: cart,
        writers: <MessageSource>[
          const PageSource('cart'),
          const ServiceSource('cart'),
        ],
      ),
      const ScopeViolation(
        topic: cart,
        owner: TopologySource('a'),
        ownerScope: Scope.page,
        readerId: 'b',
        readerScope: Scope.module,
      ),
    ];
    expect(findings.map(variantOf), <String>[
      'cycle',
      'self-reference',
      'writer conflict',
      'scope violation',
    ]);
  });
}
```

- [ ] **Step 2: Run it and the replay, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart; echo "exit: $?"`
Expected: `exit: 1`; the file does not compile, opening with `Error: Error when reading 'packages/nidana_dart_contracts/lib/topology_ir.dart': No such file or directory`, then `Error: Type 'TopologyFinding' not found.`, `Error: Method not found: 'SelfReference'.`, `Error: 'ScopeViolation' isn't a type.`, `Error: 'TopicDeclaration' isn't a type.` and like lines, then `+0 -1: Some tests failed.` (T1.2).
Run: `fvm dart run nidana_contract_check topology-ir --set surface,reject; echo "exit: $?"`
Expected: `exit: 1` and `14 fixtures: 11 passed, 3 failed, 0 pending`: every structure line, `surface/definitions.dart` and `reject/ir_holds_no_function.dart` pass, and `surface/graphs.dart`, `reject/ir_families_are_closed.dart` and `reject/ir_values_are_immutable.dart` FAIL, each opening with `uri_does_not_exist` for `package:nidana_dart_contracts/topology_ir.dart`, never PENDING (T1.2, the routed baseline).

- [ ] **Step 3: Implement `lib/src/graph/graph.dart` and `lib/src/analysis/findings.dart`, and export them from `lib/topology_ir.dart`**

`packages/nidana_dart_contracts/lib/src/graph/graph.dart`:

```dart
import 'package:meta/meta.dart';

import '../ir/definition.dart';
import '../topic/message_source.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

/// A shell publisher's claim (Spec §2.4, §3.11, §7.2): its source, the scope
/// it is bound to (application when unbound), and the state topics it
/// claims. Throws ArgumentError when [source] is a TopologySource or
/// UnknownSource, or [writes] is empty or names a topic that is not a state
/// topic.
@immutable
final class ShellClaim {
  // The factory constructs through this once nidana.model.11 lands it.
  // ignore: unused_element
  const ShellClaim._({
    required this.source,
    required this.scope,
    required this.writes,
  });

  factory ShellClaim({
    required MessageSource source,
    Scope scope = Scope.application,
    required Set<TopicRef> writes,
  }) => throw UnimplementedError();

  final MessageSource source;
  final Scope scope;
  final Set<TopicRef> writes; // canonical order; unmodifiable copy
}

/// Topologies and shell claims (Spec §6.5, Appendix A.4, A.9): the active
/// set behind bus.toGraph(), or the static set a catalog scans.
@immutable
final class TopologyGraph {
  // The factory constructs through this once nidana.model.11 lands it.
  // ignore: unused_element
  const TopologyGraph._({
    required this.topologies,
    required this.claims,
    required this.topics,
  });

  /// Throws ArgumentError when two definitions share a topologyId and are
  /// not equal; equal ones count once (Spec §3.9).
  factory TopologyGraph({
    Iterable<TopologyDefinition> topologies = const <TopologyDefinition>[],
    Iterable<ShellClaim> claims = const <ShellClaim>[],
  }) => throw UnimplementedError();

  // by topologyId, distinct ids; unmodifiable
  final List<TopologyDefinition> topologies;
  // canonical order, equal claims kept; unmodifiable
  final List<ShellClaim> claims;
  // every topic read or written, canonical order; unmodifiable
  final List<TopicRef> topics;

  /// renderer.render(this).
  String render(GraphRenderer renderer) => throw UnimplementedError();
}

extension TopologyDefinitionGraph on TopologyDefinition {
  /// Spec §6.5's ir.toGraph(): TopologyGraph(topologies: [this]).
  TopologyGraph toGraph() => throw UnimplementedError();
}

/// Renders a graph as text (Spec §6.5, Appendix A.4 "other graph
/// formats"). Applications may implement it.
abstract interface class GraphRenderer {
  String render(TopologyGraph graph);
}
```

`packages/nidana_dart_contracts/lib/src/analysis/findings.dart`:

```dart
import 'package:meta/meta.dart';

import '../topic/message_source.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

/// A finding of the analyses (Spec §3.8, §3.11, §7.2). Sealed.
@immutable
sealed class TopologyFinding {
  const TopologyFinding._();
}

/// Spec §3.8, inter-topology: a strongly connected set of two or more
/// topologies. [topics] are the topics one member writes and another reads.
final class TopologyCycle extends TopologyFinding {
  TopologyCycle({required this.topologyIds, required this.topics}) : super._();

  final List<String> topologyIds; // sorted
  final List<TopicRef> topics; // canonical order
}

/// Spec §3.8, intra-topology: [topic] is read and written by [topologyId]
/// through no state-bearing edge. [edges] are the indices of every edge on
/// such a path.
final class SelfReference extends TopologyFinding {
  SelfReference({
    required this.topologyId,
    required this.topic,
    required this.edges,
  }) : super._();

  final String topologyId;
  final TopicRef topic;
  final List<int> edges; // ascending
}

/// Spec §3.11: a state topic with more than one writer. A topology writes
/// as TopologySource(topologyId), a claim as its source.
final class WriterConflict extends TopologyFinding {
  WriterConflict({required this.topic, required this.writers}) : super._();

  final TopicRef topic;
  // canonical order, one per writer, equal sources repeated
  final List<MessageSource> writers;
}

/// Spec §7.2: [owner] of the state topic [topic] has a shorter scope than
/// the topology [readerId] that reads it.
final class ScopeViolation extends TopologyFinding {
  const ScopeViolation({
    required this.topic,
    required this.owner,
    required this.ownerScope,
    required this.readerId,
    required this.readerScope,
  }) : super._();

  final TopicRef topic;
  final MessageSource owner;
  final Scope ownerScope;
  final String readerId;
  final Scope readerScope;
}

/// A topic declaration a scan found, and where (a label the caller chooses,
/// such as a file and line).
@immutable
final class TopicDeclaration {
  const TopicDeclaration({required this.topic, required this.site});

  final TopicRef topic;
  final String site;
}

/// Spec §4.3: [name] declared more than once.
@immutable
final class TopicNameCollision {
  TopicNameCollision({required this.name, required this.declarations});

  final String name;
  // by site, then topic in canonical order
  final List<TopicDeclaration> declarations;
}
```

`packages/nidana_dart_contracts/lib/topology_ir.dart` (the comment needs `library;`, or the root lint set reports it as dangling; export directives in URI order, `show` names in ASCII order):

```dart
/// Topology graphs with their shell claims, the renderers and the JSON form
/// of a graph, and the pure analyses over graphs and definitions.
library;

export 'src/analysis/findings.dart'
    show
        ScopeViolation,
        SelfReference,
        TopicDeclaration,
        TopicNameCollision,
        TopologyCycle,
        TopologyFinding,
        WriterConflict;
export 'src/graph/graph.dart'
    show GraphRenderer, ShellClaim, TopologyDefinitionGraph, TopologyGraph;
```

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the replays**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted 27 files (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+36: All tests passed!` (T1.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topology-ir --set surface,reject; echo "exit: $?"`
Expected: `exit: 1` and `14 fixtures: 13 passed, 1 failed, 0 pending`: `PASS reject` for `ir_families_are_closed.dart`, `ir_holds_no_function.dart` and `ir_values_are_immutable.dart`, and `FAIL surface .../surface/graphs.dart` on exactly fourteen diagnostics, every one a name Task 2 declares: `creation_with_non_type` on lines 55, 56, 57 and 59 (`MermaidRenderer`, `GraphvizRenderer`, `JsonRenderer`), and `undefined_function` on lines 63 to 66 (the codec), 70, 72, 74, 75 and 76 (the analyses) and 116 (`findTopicNameCollisions`) (T1.4). That is this task's end state, not a gap; any other diagnostic on that file, or a FAIL of a reject library, is a stop (Global Constraints, Contract gaps).
Run: `fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set structure,surface,reject,schema; echo "exit: $?"`
Expected: `exit: 1` and `117 fixtures: 116 passed, 1 failed, 0 pending`, the one failure `surface/graphs.dart` as above (T1.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/graph/graph.dart packages/nidana_dart_contracts/lib/src/analysis/findings.dart packages/nidana_dart_contracts/lib/topology_ir.dart packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart
git commit -m "feat(dart_contracts): declare graphs, claims and findings" -m "<the co-author trailer your harness gives>"
```

### Task 2: Analyses, the JSON form, the renderers and the export list

You are completing `lib/topology_ir.dart` in `packages/nidana_dart_contracts`, whose `lib/src/graph/graph.dart` declares `ShellClaim`, `TopologyGraph`, `TopologyDefinitionGraph` and `GraphRenderer`, and whose `lib/src/analysis/findings.dart` declares the findings, `TopicDeclaration` and `TopicNameCollision` (Task 1). Run every command from the repository root with `fvm dart`. Add the functions of the section Analyses in `lib/src/analysis/analyses.dart`, the section The JSON form with `JsonRenderer` in `lib/src/json/codec.dart`, and `MermaidRenderer` and `GraphvizRenderer` in `lib/src/render/renderers.dart` (nidana.model D4), then export all five libraries from `lib/topology_ir.dart`, whose 24 names `test/exports_test.dart` then pins by exact set as it pins the other two libraries. Land the declarations below exactly; their dartdoc is copied from the code blocks of `hsdd/contract/topology-ir.md`: Renderers (lines 262 to 266), The JSON form (lines 292 to 303) and Analyses (lines 402 to 409 and 426). Every body throws `UnimplementedError`. Import no `dart:convert`: nothing here uses it before nidana.model.13.

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart`
- Create: `packages/nidana_dart_contracts/lib/src/json/codec.dart`
- Create: `packages/nidana_dart_contracts/lib/src/render/renderers.dart`
- Modify: `packages/nidana_dart_contracts/lib/topology_ir.dart` (replaced: five export directives)
- Modify: `packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart` (one class, one test)
- Modify: `packages/nidana_dart_contracts/test/exports_test.dart` (the file comment, one test)

**Interfaces:**
- Consumes: from Task 1, `TopologyGraph` and `GraphRenderer` (`../graph/graph.dart`), `TopologyFinding`, `TopologyCycle`, `SelfReference`, `WriterConflict`, `ScopeViolation`, `TopicDeclaration` and `TopicNameCollision` (`findings.dart`); `TopologyDefinition` from `lib/src/ir/definition.dart` (nidana.model.4); `shownBy(String library)` in `test/exports_test.dart` (nidana.model.4).
- Produces: in `analyses.dart`, `findTopologyCycles(TopologyGraph)`, `findSelfReferences(TopologyDefinition)`, `findWriterConflicts(TopologyGraph)`, `findScopeViolations(TopologyGraph)`, `analyzeTopologyGraph(TopologyGraph)` and `findTopicNameCollisions(Iterable<TopicDeclaration>)` with the Interface's return types; in `codec.dart`, `encodeTopologyGraph`, `decodeTopologyGraph`, `encodeTopologyDefinition`, `decodeTopologyDefinition` and `final class JsonRenderer implements GraphRenderer` (`const JsonRenderer()`); in `renderers.dart`, `final class MermaidRenderer` and `final class GraphvizRenderer`, each `implements GraphRenderer` with a const unnamed constructor; `lib/topology_ir.dart` exporting the 24 names, which nidana.model.10 to nidana.model.14 fill in.

- [ ] **Step 1: Write the failing tests**

In `packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart`, add this class after `variantOf` and its blank line, before `void main() {`:

```dart
/// A renderer an application writes.
final class ClaimCount implements GraphRenderer {
  const ClaimCount();

  @override
  String render(TopologyGraph graph) => '${graph.claims.length}';
}
```

and this test after the last test inside `main()`, separated from it by a blank line:

```dart
  test('the three renderers are const GraphRenderers, beside one an '
      'application writes', () {
    const List<GraphRenderer> renderers = <GraphRenderer>[
      MermaidRenderer(),
      GraphvizRenderer(),
      JsonRenderer(),
      ClaimCount(),
    ];
    expect(renderers.map((GraphRenderer r) => r.runtimeType), <Type>[
      MermaidRenderer,
      GraphvizRenderer,
      JsonRenderer,
      ClaimCount,
    ]);
  });
```

In `packages/nidana_dart_contracts/test/exports_test.dart`, replace the file comment (its first three lines) with:

```dart
// The three public libraries export exactly the names their contracts place
// in them (topology-dsl@v2 G2; topology-ir@v1's Libraries; nidana.model D4),
// so a declaration cannot leak from one library into another.
```

and add this test after the `G2 topology_plan.dart ...` test, separated by a blank line, before `the export reader sees ...`:

```dart
  test('topology_ir.dart exports exactly the declarations under '
      "topology-ir@v1's Graphs, Renderers, The JSON form and Analyses", () {
    expect(shownBy('topology_ir.dart'), <String>{
      // Graphs
      'ShellClaim', 'TopologyGraph', 'TopologyDefinitionGraph',
      // Renderers
      'GraphRenderer', 'MermaidRenderer', 'GraphvizRenderer', 'JsonRenderer',
      // The JSON form
      'encodeTopologyGraph', 'decodeTopologyGraph',
      'encodeTopologyDefinition', 'decodeTopologyDefinition',
      // Analyses
      'TopologyFinding', 'TopologyCycle', 'SelfReference', 'WriterConflict',
      'ScopeViolation', 'findTopologyCycles', 'findSelfReferences',
      'findWriterConflicts', 'findScopeViolations', 'analyzeTopologyGraph',
      'TopicDeclaration', 'TopicNameCollision', 'findTopicNameCollisions',
    });
  });
```

- [ ] **Step 2: Run them and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart; echo "exit: $?"`
Expected: `exit: 1`; the file does not compile: `Error: Method not found: 'MermaidRenderer'.`, `Error: Method not found: 'GraphvizRenderer'.`, `Error: Method not found: 'JsonRenderer'.` and `Error: Undefined name 'MermaidRenderer'.` with like lines, then `+0 -1: Some tests failed.` (T2.2).
Run: `fvm dart test packages/nidana_dart_contracts/test/exports_test.dart; echo "exit: $?"`
Expected: `exit: 1`; the new test fails with `Expected: Set:[`, `Actual: Set:[` and `Which: does not contain 'MermaidRenderer'`, the other three pass, then `+3 -1: Some tests failed.` (T2.2).

- [ ] **Step 3: Implement `analyses.dart`, `codec.dart` and `renderers.dart`, and complete `lib/topology_ir.dart`**

`packages/nidana_dart_contracts/lib/src/analysis/analyses.dart`:

```dart
import '../graph/graph.dart';
import '../ir/definition.dart';
import 'findings.dart';

List<TopologyCycle> findTopologyCycles(TopologyGraph graph) =>
    throw UnimplementedError();
List<SelfReference> findSelfReferences(TopologyDefinition definition) =>
    throw UnimplementedError();
List<WriterConflict> findWriterConflicts(TopologyGraph graph) =>
    throw UnimplementedError();
List<ScopeViolation> findScopeViolations(TopologyGraph graph) =>
    throw UnimplementedError();

/// Every finding: cycles, then the self-references of each topology in graph
/// order, then writer conflicts, then scope violations.
List<TopologyFinding> analyzeTopologyGraph(TopologyGraph graph) =>
    throw UnimplementedError();

List<TopicNameCollision> findTopicNameCollisions(
  Iterable<TopicDeclaration> declarations,
) => throw UnimplementedError();
```

`packages/nidana_dart_contracts/lib/src/json/codec.dart`:

```dart
import '../graph/graph.dart';
import '../ir/definition.dart';

/// The graph document of [graph] as a JSON value (maps, lists, strings,
/// integers, booleans and null), keys in the order the schema lists them.
Map<String, Object?> encodeTopologyGraph(TopologyGraph graph) =>
    throw UnimplementedError();

/// The graph a graph document describes. Throws FormatException, and no
/// other error, for any value that is not a graph document of this version
/// or breaks a rule of the decoder.
TopologyGraph decodeTopologyGraph(Object? json) => throw UnimplementedError();

/// The object a graph document lists for [definition], and its inverse.
Map<String, Object?> encodeTopologyDefinition(TopologyDefinition definition) =>
    throw UnimplementedError();
TopologyDefinition decodeTopologyDefinition(Object? json) =>
    throw UnimplementedError();

/// The graph document as JSON text (The JSON form).
final class JsonRenderer implements GraphRenderer {
  const JsonRenderer();

  @override
  String render(TopologyGraph graph) => throw UnimplementedError();
}
```

`packages/nidana_dart_contracts/lib/src/render/renderers.dart`:

```dart
import '../graph/graph.dart';

final class MermaidRenderer implements GraphRenderer {
  const MermaidRenderer();

  @override
  String render(TopologyGraph graph) => throw UnimplementedError();
}

final class GraphvizRenderer implements GraphRenderer {
  const GraphvizRenderer();

  @override
  String render(TopologyGraph graph) => throw UnimplementedError();
}
```

Replace `packages/nidana_dart_contracts/lib/topology_ir.dart` with:

```dart
/// Topology graphs with their shell claims, the renderers and the JSON form
/// of a graph, and the pure analyses over graphs and definitions.
library;

export 'src/analysis/analyses.dart'
    show
        analyzeTopologyGraph,
        findScopeViolations,
        findSelfReferences,
        findTopicNameCollisions,
        findTopologyCycles,
        findWriterConflicts;
export 'src/analysis/findings.dart'
    show
        ScopeViolation,
        SelfReference,
        TopicDeclaration,
        TopicNameCollision,
        TopologyCycle,
        TopologyFinding,
        WriterConflict;
export 'src/graph/graph.dart'
    show GraphRenderer, ShellClaim, TopologyDefinitionGraph, TopologyGraph;
export 'src/json/codec.dart'
    show
        JsonRenderer,
        decodeTopologyDefinition,
        decodeTopologyGraph,
        encodeTopologyDefinition,
        encodeTopologyGraph;
export 'src/render/renderers.dart' show GraphvizRenderer, MermaidRenderer;
```

- [ ] **Step 4: Run the tests, the analyzer, the formatter and the replays**

Run: `fvm dart format packages/nidana_dart_contracts`
Expected: `Formatted 30 files (0 changed)`.
Run: `fvm dart test packages/nidana_dart_contracts`
Expected: `+38: All tests passed!` (T2.4).
Run: `fvm dart analyze --fatal-infos`
Expected: `No issues found!`
Run: `fvm dart run nidana_contract_check topology-ir --set surface,reject; echo "exit: $?"`
Expected: `exit: 0` and `14 fixtures: 14 passed, 0 failed, 0 pending` (T2.4).
Run: `fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set structure,surface,reject,schema; echo "exit: $?"`
Expected: `exit: 0`; 42 `PASS structure`, 7 `PASS surface`, 22 `PASS reject` and 46 `PASS schema` lines, then `117 fixtures: 117 passed, 0 failed, 0 pending` (T2.4). A FAIL is a stop: see Global Constraints, Contract gaps.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/analysis/analyses.dart packages/nidana_dart_contracts/lib/src/json/codec.dart packages/nidana_dart_contracts/lib/src/render/renderers.dart packages/nidana_dart_contracts/lib/topology_ir.dart packages/nidana_dart_contracts/test/topology_ir_declarations_test.dart packages/nidana_dart_contracts/test/exports_test.dart
git commit -m "feat(dart_contracts): declare the analyses, the JSON form and the renderers" -m "<the co-author trailer your harness gives>"
```

### Task 3: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.5.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.5.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 and 2; the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set structure,surface,reject,schema) > "${TMPDIR:-/tmp}/nidana.model.5-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after.
Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+38: All tests passed!` and `117 fixtures: 117 passed, 0 failed, 0 pending` (G). A failure stops here: it is fixed in the task that owns the code, never by editing `hsdd/`; a fixture that fails against a declaration matching its block is a contract gap (Global Constraints).

- [ ] **Step 2: Run the checklist**

`<base>` below is the parent of Task 1's commit (`git log --format=%H -n 1 <Task 1's commit>^`). Run each and keep its output:
- `git diff --name-status <base> HEAD -- packages/nidana_dart_contracts/lib` (expected: six lines, each `A` and a path under `packages/nidana_dart_contracts/lib/`: `src/analysis/analyses.dart`, `src/analysis/findings.dart`, `src/graph/graph.dart`, `src/json/codec.dart`, `src/render/renderers.dart`, `topology_ir.dart`): the phase created `topology_ir.dart` and its four areas and edited no file of the main library, `topology_plan.dart` or `lib/src/ir/`.
- `grep -n '^export' packages/nidana_dart_contracts/lib/topology_ir.dart` (expected: five lines, each `export 'src/...'`, none naming `nidana_dart_contracts.dart`): `topology_ir.dart` does not re-export the main library.
- `grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?"` (expected: no line, `exit: 1`): no code outside the package reaches a declaration except through the three public libraries.
- `grep -rnE "operator ==|hashCode|toString\(\)" packages/nidana_dart_contracts/lib/src/graph packages/nidana_dart_contracts/lib/src/analysis packages/nidana_dart_contracts/lib/src/json packages/nidana_dart_contracts/lib/src/render; echo "exit: $?"` (expected: no line, `exit: 1`): no graph, claim, finding or declaration overrides `Object`'s members before nidana.model.10 and nidana.model.11.
- `git status --short pubspec.lock` (expected: no output).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.5.verification.md` at gate-only depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.5 - topology-ir@v1 declarations` (a spaced hyphen; no em-dash anywhere in the file). Slim: every section a few lines.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as the phase context writes it, which replays the `structure`, `surface`, `reject` and `schema` sets of topic-model@v1, topology-dsl@v2 and topology-ir@v1; one sentence that the `schema` set validates every `valid/` document and no `invalid/` one against `hsdd/contract/schema/topology-ir.schema.json`, and that the producer's own encoding is checked against the schema by the behavior set once nidana.model.13 delivers the codec (G19, `expectMatchesSchema`); the checklist commands of Step 2.
- **Expected output:** the gate's exit 0 and the five lines of Step 1; the checklist's expected results of Step 2.
- **Observed:** dated, with the gate's start and end times, the branch and commit, and Dart 3.13.5 through `fvm`; the gate's exit code and its five lines as they appeared; then a checklist of four `- [x]` lines, each with its result:
  - the first replay of topology-ir@v1's 2 surface and 3 reject libraries against the real package passed, beside topic-model@v1's and topology-dsl@v2's (22 reject libraries in all): every reject code the stand-ins confirmed holds, none differs, and no line carries two codes, since a reject library passes only when its reported (line, code) pairs equal its one-code markers; the routed baseline command went from `14 fixtures: 11 passed, 3 failed, 0 pending` to `14 fixtures: 14 passed, 0 failed, 0 pending`;
  - `topology_ir.dart` exports exactly the 24 declarations of topology-ir@v1's Graphs, Renderers, The JSON form and Analyses and the main library none of them (`exports_test.dart` passes: the main library 40, `topology_plan.dart` 27, `topology_ir.dart` 24), it does not re-export the main library, and no code outside the package imports its `src/`;
  - no IR value, graph, claim or finding can be assigned to (`ir_values_are_immutable.dart` passes), the families are closed (`ir_families_are_closed.dart` passes), and a `FunctionRef` cannot be called (`ir_holds_no_function.dart` passes);
  - the phase created `topology_ir.dart` and its four areas and edited no file nidana.model.4 wrote under `lib/`; no new class overrides `==`, `hashCode` or `toString`; `purity_test.dart` holds the package to `meta` and `test` and to no clock, timer, microtask, id or I/O over the new libraries (G25, G26); the lockfile is unchanged.
- **Outstanding:** `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found the three below and the sizing line; write each that still holds, and any the gate finds:
  - `- No reject line of nidana.model's three contracts needs two diagnostic codes: the 10 topic-model@v1, 9 topology-dsl@v2 and 3 topology-ir@v1 reject libraries all pass with one code per marked line, so ADR-001 item 4's one-code marker suffices for them. Disposition: dropped (closes the question routed from nidana.model.2's planning for this node; the reject sets of bus-api, bus-testing, navigation-api and flutter-binding first replay at their own producers' gates)`
  - `- nidana.model D3's final field behind every getter leaves the private constructors of ShellClaim and TopologyGraph unused beside their throwing factories, so the package carries two more ignores of unused_element until nidana.model.11. Disposition: dropped (temporary; nidana.model.11 constructs through them)`
  - `- topology-ir@v1's Interface prose says every value type is annotated @immutable, while its Graphs and Analyses code blocks, like its IR blocks, show no annotation; the declarations follow the prose, the sealed TopologyFinding included. Disposition: dropped (already routed to the governance sweep at the end of nidana.model; no fixture depends on it)`
  - one sizing line: the phase scope's estimate of about 260 lines in about 8 files against the measured product diff (Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint).
- **Metrics:** one line: the product diff, `git diff --stat <base> HEAD -- packages/`, in files and lines, the library and the tests apart, beside the estimate of about 260 lines in about 8 files; the task count, 3 of the allowed 4.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.5.verification.md
git commit -m "docs(verify): nidana.model.5 verification" -m "<the co-author trailer your harness gives>"
```
