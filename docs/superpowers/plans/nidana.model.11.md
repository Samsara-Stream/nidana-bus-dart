# nidana.model.11 Projection, Graphs and Claims Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the projection of a recorded plan to its `TopologyDefinition` by topology-ir@v1's five From a plan rules, through one stage and sink visitor in a new library `packages/nidana_dart_contracts/lib/src/ir/projection.dart`, behind `TopologyPlan.definition` and `buildDefinition()` (topology-dsl@v2 G9, G10, G12; topology-ir@v1 G8), and the bodies of `ShellClaim` and `TopologyGraph` in `lib/src/graph/graph.dart` (G12; G11 with its canonical orders, duplicates and `topics`; G3 unmodifiable copies; G7 equality that ignores the order of the arguments; `toGraph()`; `render(r)`), so that the gate replays topology-dsl@v2 unrestricted, 24 of 24 recording cases (19 today), and topology-ir@v1 restricted to G2, G5, G6, G8 to G12, 17 of 17 cases (10 today), while the package's tests pin G3 and G7 for graphs and claims, which no replay of this gate reaches.

**Architecture:** Bodies, private members and one internal library. `projectPlan(TopologyPlan plan)` walks the plan's stages, then its sinks, through a private class `_Projection` that implements both `StageVisitor<TransformEdge?>` and `SinkVisitor<TransformEdge>`: a read stage yields no edge, every other stage its stage edge, every sink its sink edge, and an identity map from stage to edge index turns each handle into a `StageInput`. `TopologyPlan.definition` calls it on each read and lets `TopologyDefinition`'s `ArgumentError` propagate. `ShellClaim` and `TopologyGraph` are factories that check, copy and sort through the canonical-order comparators nidana.model.10 landed, then construct through their private const constructors; equality compares the fields topology-ir@v1 names, collections element by element. A last code task fixes four error messages routed from earlier reviews. Tasks run leaves first: the projection; the claim; the graph, which sorts claims; the messages; the gate and the verification doc.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:meta` 1.19.0 (`@immutable`), the package's only dependency; `package:test` for the package's tests; the replay tool `nidana_contract_check` with its `behavior` set (nidana.model.6).

**Spec:** `hsdd-context/superpowers/nidana.model.11.md` (the derivative; the phase context with topic-model@v1's, topology-dsl@v2's and topology-ir@v1's whole Interface and Guarantees sits between its markers). The dartdoc already in `lib/src/topology/` and `lib/src/graph/graph.dart` came from those Interfaces (`hsdd/contract/topology-dsl.md`, `hsdd/contract/topology-ir.md`) and stays. Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D3 (line 102: `==` and `hashCode` stay `Object`'s until the delivering phase, this one for graphs and claims; getters are final fields), D4 (line 112: the projection and its visitor under `lib/src/ir/`, `ShellClaim` and `TopologyGraph` under `lib/src/graph/`, the `definition` body in `lib/src/topology/`), D5 (line 128: the gate) and D6 (line 135: `test/purity_test.dart` scans every library under `lib/` for `DateTime.now(`, `Stopwatch(`, `Timer(`, `Timer.periodic(`, `scheduleMicrotask(`, `Future.delayed(`, `Future.microtask(`, `Random(` and `Zone.`, as substrings, comments included). The fixtures the gate replays: `hsdd/contract/fixture/topology-dsl/behavior/recording_conformance.dart` through `topology_builder_test.dart`, and `hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart` through `nidana_dart_contracts_test.dart`. Evidence: `docs/auto-run/experiments/projection-graphs-plan/` (`run.sh`, `output.txt`, `edits.py`, `draft/`), a dry run of this plan's tasks in a temporary copy of HEAD `3979408`; labels such as S1, T1.2, T3.4, X, G, U, C, A and D1 below name the steps of its `output.txt`. `draft/` and `edits.py` are evidence, not code to copy: the blocks below are the source, each formatter-stable (X).

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 7 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G8,G9,G10,G11,G12` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.11.verification.md from
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

- **Toolchain:** `fvm dart` only, every command from the repository root, no global tooling. No dependency changes: no `pubspec.yaml` is edited and `pubspec.lock` stays byte-identical.
- **Files:** under `lib/` this phase creates `lib/src/ir/projection.dart` (Task 1) and edits `lib/src/topology/topology.dart` and `lib/src/topology/plan.dart` (Task 1), `lib/src/graph/graph.dart` (Tasks 2 and 3), the dartdoc of `lib/src/topic/list_equality.dart` (Task 2, comment only), and `lib/src/topology/builder.dart`, `lib/src/topology/handle.dart` and `lib/src/ir/definition.dart` (Task 4); no other library. `lib/src/analysis/` is nidana.model.12's, `lib/src/json/` nidana.model.13's and `lib/src/render/` nidana.model.14's. The three public libraries' export lists stay exactly as `test/exports_test.dart` pins them, and none exports `projection.dart`. Under `test/` it creates four test files and edits one, `test/canonical_order_test.dart` (Task 1, one line). `README.md`, `CHANGELOG.md` and `LICENSE` stay as they are (D4). Nothing under `hsdd/` changes except the verification doc of Task 5.
- **Interface:** every public name, signature, parameter name, default, modifier, annotation and `const` stays as topology-dsl@v2 and topology-ir@v1 state it and nidana.model.4 and nidana.model.5 landed it. Every getter that returns a stored value stays a final field (D3). `ShellClaim` and `TopologyGraph` gain `==` and `hashCode` and no other public member: no `toString`, which the Interface does not declare. `TopologyPlan`, the stages, the sinks and the builder keep `Object`'s `==` and `hashCode` (topology-dsl@v2 G30), and `definition` stays a getter that projects on each read: no cached field. New members are private, except `projectPlan` in `lib/src/ir/projection.dart`, which no public library exports.
- **Equality and hash codes:** `==` compares exactly what topology-ir@v1 names: a claim's `source`, `scope` and `writes`; a graph's `topologies` and `claims`, in their canonical orders ("Two graphs are equal exactly when their topologies and claims, in their canonical orders, are equal"); `topics`, which those determine, takes no part. Collections go through `elementsEqual` from `lib/src/topic/list_equality.dart`, which takes `List`s, so a claim compares `writes.toList()`. `hashCode` is `Object.hash` of the same fields, each collection as `Object.hashAll(collection)`, never the collection itself, which hashes by identity (the dry run's seeded defects D3 and D6). No test pins a hash code's value, only that equal values hash alike.
- **Unmodifiable copies:** a claim's `writes` is `Set<TopicRef>.unmodifiable(sortedCopy(writes, compareTopicRefs))`; a graph's `topologies`, `claims` and `topics` are `List.unmodifiable` copies (`sortedCopy` returns one). The factories read each `Iterable` argument exactly once (`sortedCopy` calls `toList()` once), so a lazy iterable such as `reversed` or a `where` view works, and later changes to the caller's collection never reach the value.
- **Errors:** every rejection throws `ArgumentError.value(value, name, message)` whose `name` is the argument at fault, as the tests pin: `source` and `writes` (`ShellClaim`), `topologies` (`TopologyGraph`). The projection throws nothing of its own: a plan that `planOf` accepted projects to a well-formed definition except with sinks on two state topics whose value types render alike, and then `TopologyDefinition`'s `ArgumentError` named `transforms` propagates, unwrapped, from `definition` and from `buildDefinition()`. A message never builds an article from a variant name (S132's grammar finding).
- **Library boundaries:** `lib/src/ir/projection.dart` imports `lib/src/topology/topology.dart`, which imports `projection.dart` back for `definition`. Dart allows this cycle, and the analyzer reports nothing for it (T1.4). No library under `lib/src/ir/` imports or exports `lib/src/graph/`; Task 1 makes the test that pins it recursive. `lib/src/graph/graph.dart` imports `../ir/canonical_order.dart` and `../topic/list_equality.dart`.
- **Comments:** the Interface's dartdoc and trailing comments stay as written and where nidana.model.4 and nidana.model.5 put them. Each `==` gets a `//` line above its `@override` naming the fields it compares and citing G7; each new private member gets a `//` comment saying what it holds or does. Remove the two `// ignore: unused_element` lines in `graph.dart`, each with the comment line above it: `ShellClaim._`'s in Task 2, `TopologyGraph._`'s in Task 3. No word of `lib/` may contain a D6 token, in code or comment. No em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.
- **Const collections:** `ShellClaim` and `TopologyGraph` now override `==`, as `TopicRef`, the message sources and the IR values do, so a non-empty const set of, or a const map keyed by, any of them does not compile. No test of this phase writes one (`const <TopicRef>{}`, empty, is fine); the four new test files hold none (A). The fixture libraries under every slug's `surface/`, `reject/` and `behavior/` report the same 3143 diagnostics, in 70 of them, before and after this phase (B, A).
- **Analyzer:** `fvm dart analyze --fatal-infos` at the root reports nothing after every task (T1.4 to T4.4).
- **Tests:** run from the root as `fvm dart test packages/nidana_dart_contracts`. Each task's failing step also replays the conformance cases of its guarantees with `fvm dart run nidana_contract_check {slug} --set behavior [--guarantee {ids}]`, which runs the committed binding under `dart test` and starts no `flutter`; no test of this phase starts `flutter` either. G3 and G7 are outside the gate's topology-ir@v1 restriction: their graph and claim cases first replay at nidana.model.12 (nidana.model.11 Scope), so this phase's package tests are the only check of G3 and G7 for graphs and claims, and the dry run's seeded defects D3, D4, D5, D6 and D8 pass the whole gate replay while failing those tests (D). The package's tests do not repeat the suites' cases; they pin what the suites leave open. Add a test beyond the plan's wherever a rule you implement would otherwise go unpinned. No test pins a hash value or uses a `test` API newer than 1.31.1. The 200 package tests of HEAD and topic-model@v1's replay (41 cases) pass today and stay green through every task (S1).
- **Contract gaps (ADR-001 item 8):** the dry run passes every fixture the gate replays (G), and the unrestricted topology-ir@v1 `behavior` set passes 19 of 43 cases, the 24 others calling the analyses, the codec or the renderers or running the analyses over a sample graph (U). Any fixture that fails against code that follows this plan is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the case or library, what it reports, the guarantee, and the fix you would propose.
- **Formatting and commits:** run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for a Sonnet implementer.

## Plan check

The derivative's Plan check, run after self-review: the Global Constraints above contain its constraints 1 to 8 verbatim; every `### Task N:` but the last starts with a failing-test step; Task 5 writes `hsdd/verify/nidana.model.11.verification.md`; the plan has 5 tasks of the allowed 7; it is saved as `docs/superpowers/plans/nidana.model.11.md`. `node docs/auto-run/tools/impl-gate.mjs code-plan nidana.model.11` checks the same mechanically and exits 0 on this plan.

## Review Focus

The input classes the spec implies but the conformance suites do not exercise, most likely to bite first; each has its test in the owning task.

1. **Two state topics whose value types render alike:** a `Cart` from each of two libraries, each the type of a `StateTopic` of one name, each written by one sink of one topology. Expected: `planOf` accepts them (two `Topic`s, topology-dsl@v2 G14), and `definition` and `buildDefinition()` throw `TopologyDefinition`'s `ArgumentError` named `transforms`, unwrapped, whose message names the topic's type and says that value types rendering alike are one topic (S132's routed corner, against the closing sentence of From a plan). Tests: `G8 two state topics whose value types render alike pass planOf, ...` (Task 1) and `G6 a second sink edge on a state topic names the topic and its type, ...` (Task 4).
2. **One read handle taken by several stages and sinks, and a stage taken by several edges:** the `forms` sample's `event`, which a map, a merge and a reduceInto take, and the findings sample's `quiet`, whose read feeds a debounce and a delay that one merge joins. Expected: each consumer gets `TopicInput(topic.ref, dedup: dedup)` of that read, and every consumer of a stage gets the one index of its edge. Tests: `G8 G12 the forms sample projects to the edges of its valid/ document ...`, `G8 the quiet topology of the findings sample ...` and `G8 a read written as it is projects to a write of a topic input ...` (Task 1).
3. **Graph arguments that are lazy or that the caller changes later:** a catalog that passes `definitions.reversed`, a `where` view or a `map` over its declarations, and an activation path that reuses one growable list. Expected: the graph equals the one built from lists, reads each argument once, and keeps its own unmodifiable copies (G3). The dry run's D8 (an argument read twice) passes the gate's replay. Tests: `G3 a graph keeps unmodifiable copies of its lists; ...` and `G7 a graph built from lazy iterables equals one built from lists, and reads each argument once` (Task 3).
4. **Claims that tie on source and scope, and claims and graphs as keys of hash-based collections:** two claims of one service whose writes are a prefix of one another, and a tool that keeps claims or graphs in a `Set`. Expected: the shorter writes first, equal claims kept as two claimants in a graph and one element in a set, equal hash codes for writes given in another order. The dry run's D3 (writes hashed by identity), D4 (claims ordered by source and scope only), D5 (graph equality without claims) and D6 (lists hashed by identity) all pass the gate's replay. Tests: `G7 claims are equal, ...` (Task 2), `G11 claims sort by source rendering, then scope, then writes element by element, a prefix first, ...` and `G7 graphs are equal, ...` (Task 3).
5. **One topology recorded more than once, and two declarations that reuse an id:** the catalog and the active set each record a topology, so a graph receives equal definitions, possibly three times and out of order; two modules declare `checkout` with different wiring. Expected: equal definitions count once; unequal ones with one id throw `ArgumentError` named `topologies`, whichever comes first and with an equal copy beside them. Tests: `G11 a graph lists its topologies by id, each equal definition counted once ...` and `G11 two unequal definitions with one id throw ArgumentError naming the topologies, ...` (Task 3).

## Routed items

Each item `docs/auto-run/impl-execution-plan.md` ("Routed to later phases") routes to this phase, with its disposition:

- (S132) Use `combiner`, never `apply`, for `FunctionRef.of`: Task 1, `_Projection.combine` and `.withLatestFrom` read `stage.combiner`; test `G8 every arity form of combine and withLatestFrom names the combiner ...`; the dry run's D1 fails it and the gate's G8 case.
- (S132) Map a stage to its edge index by identity: Task 1, `Map<TopicStream<Object?>, int>.identity()`. No test can tell it from an equality map while stages keep `Object`'s `==` (G30), so the Interfaces block fixes it.
- (S132, S135) The rendered-alike corner: Task 1 lets `TopologyDefinition`'s `ArgumentError` propagate from `definition` and `buildDefinition()` (test); Task 4 rewords the misleading "second sink edge on a state topic" message (test).
- (S132) The builder's "is an replay topic" grammar: Task 4, an exhaustive switch over `MultiWriterTopic` that renders "an event topic" or "a replay topic".
- (S132) `_checkMade` names the argument `handle` without its position: Task 4, the parameter name (`stream`, `events`, `a` to `d`, `latest`, `b` to `d`) or the list element (`inputs[i]`).
- (S135) Sort claims with `compareClaimKeys` and topologies with `compareTopologyIds`, and dedupe equal definitions and reject unequal ones sharing an id: Task 3.
- (S135) Make the ir/-never-imports-graph/ test recursive: Task 1, `listSync(recursive: true)` in `test/canonical_order_test.dart`.
- (S135) `elementsEqual` takes `List`s: Task 2 compares `writes.toList()`, and rewrites the helper's dartdoc, which named only envelopes and lineages, to name every value that now uses it (a comment in `lib/src/topic/`; D4 splits directories so that phases running side by side edit disjoint files, and nidana.model.11 runs alone).
- (S135) The "takes exactly 1 inputs" grammar in `definition.dart`: Task 4.
- (S115) Remove the two `// ignore: unused_element` in `graph.dart`: Task 2 (`ShellClaim._`) and Task 3 (`TopologyGraph._`).
- (S116, nidana.model.10 and .11) Define the claim order over its parts so that `ir/` never names `ShellClaim`: nidana.model.10 did; Task 3 passes a claim's parts through a private getter `ShellClaim._key`.

## Which task turns which failing case green

The gate's topology-dsl@v2 replay, unrestricted, runs the recording suite's 24 cases and passes 19 today; the five it fails call `buildDefinition()` or `definition` (S1). Its topology-ir@v1 replay, restricted to G2, G5, G6, G8 to G12, runs 17 cases and passes 10 today (G2, G5, G6, G9, G10, which nidana.model.10 delivered); the seven it fails call the projection, `ShellClaim` or `TopologyGraph` (S1).

| Task | Cases turned green | Replay |
|------|--------------------|--------|
| 1 | topology-dsl@v2: `G9 buildDefinition runs declare once and equals the definition of a fresh plan`, both G10 cases, both G12 cases; topology-ir@v1: the three G8 cases | `topology-dsl --set behavior` goes from 19 passed, 5 failed to 24 passed; `topology-ir --set behavior --guarantee G8` from 0 passed, 3 failed to 3 passed (T1.2, T1.4) |
| 2 | topology-ir@v1: `G12 a shell claim takes a service, page or executor source, ...` | `--guarantee G12` from 0 passed, 1 failed to 1 passed (T2.2, T2.4) |
| 3 | topology-ir@v1: the three G11 cases, which also construct claims | `--guarantee G11` from 0 passed, 3 failed to 3 passed; the gate's restriction then passes 17 of 17 (T3.2, T3.4) |
| 4 | none: the messages | `topology-dsl --set behavior` stays at 24 passed (T4.4) |

After Task 3 the topology-ir@v1 `behavior` set, unrestricted, passes 19 of 43: the 17 above, `G7 IR values are equal, ...`, which passed since nidana.model.10, and `G3 the IR copies the lists it is given; later changes to them do not reach it`, which this phase reaches but the restriction leaves out (U). `G3 every collection the IR, graphs, claims and findings expose is unmodifiable` and `G7 graphs, claims, declarations and findings are equal, ...` call `analyzeTopologyGraph` and stay red until nidana.model.12.

**The phase's Verification line**, and where each part is checked: `buildDefinition()` of the contracts' example topologies gives the edges the From a plan rules describe (the suite's G8 cases for `CheckoutFlow` and the `every-combinator` sample; Task 1's tests for topology-ir@v1's JSON example `search`, the `forms` sample, the findings sample's `quiet`, every arity form of combine and withLatestFrom, and reads written as they are); two recordings of one declaration, inline closures included, project equal definitions (the suite's `G8 recording one declaration twice ...` and `G9 buildDefinition ... equals the definition of a fresh plan`, and Task 1's `G9 a plan projects again at each read of its definition ...`).

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/ir/projection.dart` | 1 | Create: `projectPlan` and the stage and sink visitor `_Projection` |
| `{pkg}/lib/src/topology/topology.dart` | 1 | Import `../ir/projection.dart` |
| `{pkg}/lib/src/topology/plan.dart` | 1 | The body of `TopologyPlan.definition` |
| `{pkg}/test/projection_test.dart` | 1 | Create: example topologies, arity forms, reads written as they are, re-projection, the rendered-alike corner |
| `{pkg}/test/canonical_order_test.dart` | 1 | The ir/-never-imports-graph/ check reads `lib/src/ir/` recursively |
| `{pkg}/lib/src/graph/graph.dart` | 2, 3 | `ShellClaim`'s factory and equality (2); `ShellClaim`'s claim key, `TopologyGraph`'s factory, equality and `render`, and `toGraph()` (3) |
| `{pkg}/lib/src/topic/list_equality.dart` | 2 | The dartdoc of `elementsEqual` only |
| `{pkg}/test/shell_claim_test.dart` | 2 | Create: rejections, canonical order and copy of the writes, equality |
| `{pkg}/test/topology_graph_test.dart` | 3 | Create: orders, duplicates, topics, copies, lazy arguments, equality, `toGraph`, `render` |
| `{pkg}/lib/src/topology/builder.dart`, `{pkg}/lib/src/topology/handle.dart` | 4 | The foreign-handle and dedup messages |
| `{pkg}/lib/src/ir/definition.dart` | 4 | The input-count and second-sink messages |
| `{pkg}/test/error_messages_test.dart` | 4 | Create: the four messages |
| `hsdd/verify/nidana.model.11.verification.md` | 5 | The verification doc |

---

### Task 1: The projection behind definition and buildDefinition

You are filling in `TopologyPlan.definition`, which nidana.model.4 declared throwing `UnimplementedError`, with the projection of topology-ir@v1's From a plan, in a new internal library under `lib/src/ir/` (D4). `buildDefinition()` already returns `planOf(this).definition` and does not change. Run every command from the repository root with `fvm dart`. Change no public declaration (Global Constraints, Interface). This task turns topology-dsl@v2's five failing recording cases and topology-ir@v1's three G8 cases green.

**Files:**
- Create: `packages/nidana_dart_contracts/lib/src/ir/projection.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/topology.dart` (imports, lines 3 to 6)
- Modify: `packages/nidana_dart_contracts/lib/src/topology/plan.dart:39`
- Modify: `packages/nidana_dart_contracts/test/canonical_order_test.dart:267`
- Create: `packages/nidana_dart_contracts/test/projection_test.dart`

**Interfaces:**
- Consumes (landed by nidana.model.4, .9 and .10): `TopologyPlan`'s `topologyId`, `scope`, `stages` and `sinks`; `visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor)`, `visitSink<V>(PlanSink sink, SinkVisitor<V> visitor)` and the 18 stage classes and two sink classes with their members (topology-dsl@v2, The plan); `TransformEdge.stage(CombinatorKind, List<EdgeInput>, {FunctionRef? transformer, Duration? duration, FunctionRef? retry})`, `TransformEdge.write(TopicRef, EdgeInput)`, `TransformEdge.reduceInto(TopicRef, EdgeInput, FunctionRef)`, `TopicInput(TopicRef, {Dedup? dedup})`, `StageInput(int)`, `FunctionRef.of(Function)`, `TopologyDefinition({required String topologyId, required Scope scope, required List<TransformEdge> transforms})`; the test helper `test/src/cart_elsewhere.dart` (a second `Cart`).
- Produces: `TopologyDefinition projectPlan(TopologyPlan plan)` in `lib/src/ir/projection.dart`; `TopologyPlan.definition` returning `projectPlan(this)`. Nothing later in this plan calls `projectPlan` directly.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/projection_test.dart` with exactly this content:

```dart
// topology-ir@v1's From a plan, beyond the G8 cases of its conformance suite
// and topology-dsl@v2's G9, G10 and G12 cases of its recording suite, which
// the gate replays: the contracts' example topologies the suites do not
// project, the combiner of every arity form, a read written as it is, and
// two state topics whose value types render alike.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

import 'src/cart_elsewhere.dart' as elsewhere;

final class Results {
  const Results();
}

final class Cart {
  const Cart();
}

Never called(String what) => throw StateError('the projection called $what');

Stream<Results> searchApi(String query) => called('searchApi');
int inc(int v) => called('inc');
int add(int a, int b) => called('add');
int reduceCount(int state, int event) => called('reduceCount');
int pair(int a, int b) => called('pair');
int triple(int a, int b, int c) => called('triple');
int quadruple(int a, int b, int c, int d) => called('quadruple');
int total(List<int> values) => called('total');
int latest1(int v, int a) => called('latest1');
int latest2(int v, int a, int b) => called('latest2');
int latest3(int v, int a, int b, int c) => called('latest3');

// topology-ir@v1's JSON example (the Interface, The JSON form).
const StateTopic<String> query = StateTopic<String>(
  name: 'search.query',
  initial: '',
);
const StateTopic<Results> results = StateTopic<Results>(
  name: 'search.results',
  initial: Results(),
);

// The forms sample of topology-ir@v1's conformance library.
const StateTopic<int> formsState = StateTopic<int>(
  name: 'forms.state',
  initial: 0,
);
const EventTopic<int> formsEvent = EventTopic<int>(name: 'forms.event');
const EventTopic<int> formsOut = EventTopic<int>(name: 'forms.out');
const StateTopic<int> formsTotal = StateTopic<int>(
  name: 'forms.total',
  initial: 0,
);

// The quiet topology of the findings sample.
const StateTopic<int> quiet = StateTopic<int>(name: 'quiet.value', initial: 0);

const StateTopic<int> count = StateTopic<int>(name: 'proj.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'proj.taps');
const EventTopic<int> out = EventTopic<int>(name: 'proj.out');
const ReplayTopic<int> log = ReplayTopic<int>(name: 'proj.log', bufferSize: 2);

TopicInput read(Topic<Object?> topic, {Dedup? dedup}) =>
    TopicInput(topic.ref, dedup: dedup);

FunctionRef named(String name) => FunctionRef.named(name);

TransformEdge one(
  CombinatorKind kind,
  EdgeInput input, {
  FunctionRef? f,
  Duration? d,
}) =>
    TransformEdge.stage(kind, <EdgeInput>[input], transformer: f, duration: d);

TopologyDefinition define(
  String id,
  Scope scope,
  List<TransformEdge> transforms,
) => TopologyDefinition(topologyId: id, scope: scope, transforms: transforms);

void main() {
  test('G8 the search topology of topology-ir@v1\'s JSON example projects to '
      'its debounce, switchMap and write', () {
    final TopologyDefinition d = topology(
      'search',
      Scope.page,
      (TopologyBuilder b) => b.write(
        results,
        b
            .read(query, dedup: Dedup.none)
            .debounce(const Duration(milliseconds: 300))
            .switchMap(searchApi, retry: (Object error, int attempt) => null),
      ),
    ).buildDefinition();
    expect(
      d,
      define('search', Scope.page, <TransformEdge>[
        one(
          CombinatorKind.debounce,
          read(query, dedup: Dedup.none),
          d: const Duration(milliseconds: 300),
        ),
        TransformEdge.stage(
          CombinatorKind.switchMap,
          const <EdgeInput>[StageInput(0)],
          transformer: named('searchApi'),
          retry: const FunctionRef.anonymous(),
        ),
        TransformEdge.write(results.ref, const StageInput(1)),
      ]),
    );
    expect(d.reads.toList(), <TopicRef>[
      const TopicRef(
        name: 'search.query',
        variant: TopicVariant.state,
        typeName: 'String',
      ),
    ]);
    expect(d.writes.toList(), <TopicRef>[
      const TopicRef(
        name: 'search.results',
        variant: TopicVariant.state,
        typeName: 'Results',
      ),
    ]);
  });

  test('G8 G12 the forms sample projects to the edges of its valid/ '
      'document: one read handle feeds a map, a merge and a reduceInto', () {
    final TopologyDefinition d = topology('forms', Scope.page, (
      TopologyBuilder b,
    ) {
      final TopicStream<int> state = b.read(formsState, dedup: Dedup.none);
      final TopicStream<int> event = b.read(formsEvent);
      final TopicStream<int> mapped = event.map(inc);
      final TopicStream<int> latest = mapped.withLatestFrom(state, add);
      final TopicStream<int> merged = b.merge(<TopicStream<int>>[
        latest,
        event,
      ]);
      b.write(formsOut, merged.debounce(const Duration(milliseconds: 5)));
      b.reduceInto(formsTotal, event, reduceCount);
    }).buildDefinition();
    expect(
      d,
      define('forms', Scope.page, <TransformEdge>[
        one(CombinatorKind.map, read(formsEvent), f: named('inc')),
        TransformEdge.stage(CombinatorKind.withLatestFrom, <EdgeInput>[
          const StageInput(0),
          read(formsState, dedup: Dedup.none),
        ], transformer: named('add')),
        TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
          const StageInput(1),
          read(formsEvent),
        ]),
        one(
          CombinatorKind.debounce,
          const StageInput(2),
          d: const Duration(milliseconds: 5),
        ),
        TransformEdge.write(formsOut.ref, const StageInput(3)),
        TransformEdge.reduceInto(
          formsTotal.ref,
          read(formsEvent),
          named('reduceCount'),
        ),
      ]),
    );
    expect(d.reads.toList(), <TopicRef>[formsEvent.ref, formsState.ref]);
    expect(d.writes.toList(), <TopicRef>[formsOut.ref, formsTotal.ref]);
  });

  test('G8 the quiet topology of the findings sample: one read feeds two '
      'stages, whose edges a merge takes by index', () {
    final TopologyDefinition d = topology('quiet', Scope.module, (
      TopologyBuilder b,
    ) {
      final TopicStream<int> v = b.read(quiet);
      b.write(
        quiet,
        b.merge(<TopicStream<int>>[
          v.debounce(Duration.zero),
          v.delay(const Duration(milliseconds: 10)),
        ]),
      );
    }).buildDefinition();
    expect(d.transforms, <TransformEdge>[
      one(CombinatorKind.debounce, read(quiet), d: Duration.zero),
      one(
        CombinatorKind.delay,
        read(quiet),
        d: const Duration(milliseconds: 10),
      ),
      TransformEdge.stage(CombinatorKind.merge, const <EdgeInput>[
        StageInput(0),
        StageInput(1),
      ]),
      TransformEdge.write(quiet.ref, const StageInput(2)),
    ]);
  });

  test('G8 every arity form of combine and withLatestFrom names the combiner '
      'the declaration passed, its inputs in input order', () {
    final TopologyDefinition d = topology('arity', Scope.page, (
      TopologyBuilder b,
    ) {
      final TopicStream<int> c = b.read(count);
      final TopicStream<int> t = b.read(taps);
      final TopicStream<int> l = b.read(log);
      b.write(
        out,
        b.merge(<TopicStream<int>>[
          b.combine2(c, t, pair),
          b.combine3(t, c, l, triple),
          b.combine4(l, t, c, l, quadruple),
          b.combineAll(<TopicStream<int>>[t, l], total),
          t.withLatestFrom(c, latest1),
          l.withLatestFrom2(t, c, latest2),
          c.withLatestFrom3(l, t, c, latest3),
        ]),
      );
    }).buildDefinition();
    TransformEdge combine(List<EdgeInput> inputs, String f) =>
        TransformEdge.stage(
          CombinatorKind.combine,
          inputs,
          transformer: named(f),
        );
    TransformEdge latest(List<EdgeInput> inputs, String f) =>
        TransformEdge.stage(
          CombinatorKind.withLatestFrom,
          inputs,
          transformer: named(f),
        );
    expect(d.transforms.sublist(0, 7), <TransformEdge>[
      combine(<EdgeInput>[read(count), read(taps)], 'pair'),
      combine(<EdgeInput>[read(taps), read(count), read(log)], 'triple'),
      combine(<EdgeInput>[
        read(log),
        read(taps),
        read(count),
        read(log),
      ], 'quadruple'),
      combine(<EdgeInput>[read(taps), read(log)], 'total'),
      latest(<EdgeInput>[read(taps), read(count)], 'latest1'),
      latest(<EdgeInput>[read(log), read(taps), read(count)], 'latest2'),
      latest(<EdgeInput>[
        read(count),
        read(log),
        read(taps),
        read(count),
      ], 'latest3'),
    ]);
    expect(
      d.transforms[7],
      TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        for (int i = 0; i < 7; i++) StageInput(i),
      ]),
    );
    expect(d.transforms, hasLength(9));
  });

  test('G8 a read written as it is projects to a write of a topic input with '
      'the read\'s dedup argument, and an inline closure is anonymous', () {
    final TopologyDefinition d = topology('direct', Scope.application, (
      TopologyBuilder b,
    ) {
      b.write(out, b.read(taps));
      b.write(count, b.read(count, dedup: Dedup.equality));
      b.write(log, b.read(taps).filter((int v) => v > 0));
    }).buildDefinition();
    expect(
      d,
      define('direct', Scope.application, <TransformEdge>[
        one(
          CombinatorKind.filter,
          read(taps),
          f: const FunctionRef.anonymous(),
        ),
        TransformEdge.write(out.ref, read(taps)),
        TransformEdge.write(count.ref, read(count, dedup: Dedup.equality)),
        TransformEdge.write(log.ref, const StageInput(0)),
      ]),
    );
    expect(d.reads.toList(), <TopicRef>[count.ref, taps.ref]);
    expect(d.writes.toList(), <TopicRef>[count.ref, log.ref, out.ref]);
  });

  test('G9 a plan projects again at each read of its definition, equal each '
      'time and equal to buildDefinition', () {
    final Topology t = topology(
      'again',
      Scope.module,
      (TopologyBuilder b) => b.write(out, b.read(taps).map((int v) => v + 1)),
    );
    final TopologyPlan plan = planOf(t);
    expect(plan.definition, plan.definition);
    expect(plan.definition.hashCode, plan.definition.hashCode);
    expect(t.buildDefinition(), plan.definition);
  });

  test('G8 two state topics whose value types render alike pass planOf, and '
      'definition and buildDefinition throw TopologyDefinition\'s '
      'ArgumentError naming the transforms', () {
    const StateTopic<Cart> mine = StateTopic<Cart>(
      name: 'shop.cart',
      initial: Cart(),
    );
    const StateTopic<elsewhere.Cart> theirs = StateTopic<elsewhere.Cart>(
      name: 'shop.cart',
      initial: elsewhere.Cart(),
    );
    final Topology t = topology('alike', Scope.page, (TopologyBuilder b) {
      b.write(mine, b.read(taps).map((int v) => const Cart()));
      b.write(theirs, b.read(taps).map((int v) => const elsewhere.Cart()));
    });
    final TopologyPlan plan = planOf(t);
    expect(plan.sinks, hasLength(2));
    final Matcher rejected = throwsA(
      isA<ArgumentError>().having(
        (ArgumentError e) => e.name,
        'name',
        'transforms',
      ),
    );
    expect(() => plan.definition, rejected);
    expect(t.buildDefinition, rejected);
  });
}
```

- [ ] **Step 2: Run the test and the replays to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/projection_test.dart; echo "exit: $?"`
Expected: `+0 -7: Some tests failed.` and `exit: 1`: six tests on `UnimplementedError`, the rendered-alike test on `Expected: throws <Instance of 'ArgumentError'> with `name`: 'transforms'` (T1.2).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior; echo "exit: $?"`
Expected: `cases (19 passed, 5 failed, ...)`, the five failed cases `G9 buildDefinition runs declare once and equals the definition of a fresh plan`, the two G10 cases and the two G12 cases, `17 fixtures: 16 passed, 1 failed, 0 pending` and `exit: 1` (T1.2).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G8; echo "exit: $?"`
Expected: `cases (0 passed, 3 failed, ...)` and `exit: 1` (T1.2).

- [ ] **Step 3: Create `lib/src/ir/projection.dart` and wire `definition` to it**

The library opens with this comment, then imports `'../topic/topic.dart'`, `'../topology/topology.dart'`, `'definition.dart'` and `'function_ref.dart'`, and nothing else:

```dart
// The projection of a recorded plan to its definition (topology-ir@v1, From
// a plan), behind TopologyPlan.definition and buildDefinition()
// (topology-dsl@v2 G9, G10 and G12; topology-ir@v1 G8). It reads a plan's
// handles, topics, functions and durations through one stage and sink
// visitor, and calls none of the functions: FunctionRef.of reads a
// function's rendering only.
```

The public function and the visitor's state and helpers, which fix rules 1 and 2 (the order of the edges and the identity map):

```dart
/// The definition [plan] projects to by topology-ir@v1's five From a plan
/// rules: one stage edge per non-read stage, in stage order, then one sink
/// edge per sink, in sink order. Throws TopologyDefinition's ArgumentError
/// when the edges are not well formed, which a plan that planOf accepted
/// makes only with sinks on two state topics whose value types render alike.
TopologyDefinition projectPlan(TopologyPlan plan) {
  final _Projection projection = _Projection();
  for (final TopicStream<Object?> stage in plan.stages) {
    projection.addStage(stage);
  }
  for (final PlanSink sink in plan.sinks) {
    projection.addSink(sink);
  }
  return TopologyDefinition(
    topologyId: plan.topologyId,
    scope: plan.scope,
    transforms: projection.edges,
  );
}

// The edges of the stages and sinks it is given, in that order (rules 1 to
// 5). Each visitor method runs with the stage's or sink's own type
// arguments, so it reads a function-typed member at its declared type.
final class _Projection
    implements StageVisitor<TransformEdge?>, SinkVisitor<TransformEdge> {
  // The edges so far: the stage edges, then the sink edges.
  final List<TransformEdge> edges = <TransformEdge>[];

  // The index of each non-read stage's edge, keyed by identity: stages keep
  // Object's == (topology-dsl@v2 G30).
  final Map<TopicStream<Object?>, int> _edgeOf =
      Map<TopicStream<Object?>, int>.identity();

  // Rule 1: a non-read stage adds its edge; a read stage adds none.
  void addStage(TopicStream<Object?> stage) {
    if (visitStage(stage, this) case final TransformEdge edge) {
      _edgeOf[stage] = edges.length;
      edges.add(edge);
    }
  }

  // Rules 1 and 5: a sink adds its sink edge.
  void addSink(PlanSink sink) => edges.add(visitSink(sink, this));

  // Rule 2: a read handle is a topic input with the read's dedup argument;
  // any other handle is the index of its stage's edge, which a plan lists
  // before every stage or sink that takes the handle.
  EdgeInput _input(TopicStream<Object?> handle) => switch (handle) {
    ReadStage<Object?>(:final Topic<Object?> topic, :final Dedup? dedup) =>
      TopicInput(topic.ref, dedup: dedup),
    _ => StageInput(_edgeOf[handle]!),
  };

  // Rules 3 and 4 for a stage of one input: its kind, its input, and its
  // function or duration, when it holds one.
  TransformEdge _single(
    CombinatorKind combinator,
    TopicStream<Object?> input, {
    Function? function,
    Duration? duration,
  }) => TransformEdge.stage(
    combinator,
    <EdgeInput>[_input(input)],
    transformer: function == null ? null : FunctionRef.of(function),
    duration: duration,
  );
```

Then the twenty `@override` visitor methods (rules 3 to 5), one expression each, every input through `_input`. Read every function-typed member inside its own visitor method, never through a pattern such as `MapStage<Object?, Object?>()`, which fails at run time (topology-dsl@v2, The plan):

| Method | Edge |
|--------|------|
| `read<T>` | `null`: a read stage is not an edge |
| `map<T, R>`, `filter<T>`, `scan<T, S>`, `catchError<T>`, `rawEngine<T, R>` | `_single(CombinatorKind.{kind}, stage.input, function: ...)` with `stage.transform`, `stage.test`, `stage.accumulator`, `stage.recover`, `stage.operator` |
| `pairwise<T>`, `distinctUntilChanged<T>` | `_single(CombinatorKind.{kind}, stage.input)` |
| `debounce<T>`, `throttle<T>`, `delay<T>`, `sample<T>`, `buffer<T>`, `timeout<T>` | `_single(CombinatorKind.{kind}, stage.input, duration: stage.duration)` |
| `combine<R>` | `TransformEdge.stage(CombinatorKind.combine, [each of stage.inputs], transformer: FunctionRef.of(stage.combiner))`, under `// The declared combiner, never apply, which is a closure over it.` |
| `withLatestFrom<T, R>` | `TransformEdge.stage(CombinatorKind.withLatestFrom, [stage.primary, then each of stage.latest], transformer: FunctionRef.of(stage.combiner))`, under `// The primary first, then the latest inputs in argument order.` |
| `merge<T>` | `TransformEdge.stage(CombinatorKind.merge, [each of stage.inputs])` |
| `switchMap<T, R>` | `TransformEdge.stage(CombinatorKind.switchMap, [stage.input], transformer: FunctionRef.of(stage.toStream), retry: ...)`, the retry `switch (stage.retry) { final RetryPolicy retry => FunctionRef.of(retry), null => null }` |
| `write<T>` | `TransformEdge.write(sink.topic.ref, _input(sink.input))` |
| `reduceInto<S, E>` | `TransformEdge.reduceInto(sink.topic.ref, _input(sink.events), FunctionRef.of(sink.reducer))` |

Build each input list with a collection-for, `<EdgeInput>[for (final TopicStream<Object?> i in stage.inputs) _input(i)]`.

In `lib/src/topology/topology.dart`, add `import '../ir/projection.dart';` after `import '../ir/definition.dart';`. In `lib/src/topology/plan.dart`, line 39 becomes `TopologyDefinition get definition => projectPlan(this);`, its dartdoc unchanged.

In `test/canonical_order_test.dart`, the test `no library under lib/src/ir/ imports or exports lib/src/graph/` reads the directory recursively (routed item): `ir.listSync()` becomes `ir.listSync(recursive: true)`, on the same line.

- [ ] **Step 4: Run the tests, the analyzer and the same replays**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `+207: All tests passed!` (200 before, 7 added) and `No issues found!` (T1.4).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior; echo "exit: $?"`
Expected: `24 passed, 0 failed, 0 skipped under dart test`, `17 fixtures: 17 passed, 0 failed, 0 pending` and `exit: 0` (T1.4).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G8; echo "exit: $?"`
Expected: `3 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G8` and `exit: 0` (T1.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/ir/projection.dart packages/nidana_dart_contracts/lib/src/topology/topology.dart packages/nidana_dart_contracts/lib/src/topology/plan.dart packages/nidana_dart_contracts/test/projection_test.dart packages/nidana_dart_contracts/test/canonical_order_test.dart
git commit -m "feat(dart_contracts): project a recorded plan to its topology definition" -m "<the co-author trailer your harness gives>"
```

### Task 2: ShellClaim

You are filling in `ShellClaim` in `packages/nidana_dart_contracts/lib/src/graph/graph.dart`, which nidana.model.5 declared with a factory that throws `UnimplementedError` and no value equality (D3): its rules (G12), the canonical order and unmodifiable copy of its writes (G3) and its equality (G7). `TopologyGraph` keeps throwing until Task 3. Run every command from the repository root with `fvm dart`. This task turns topology-ir@v1's G12 case green.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/graph/graph.dart` (imports; `ShellClaim`, lines 8 to 32)
- Modify: `packages/nidana_dart_contracts/lib/src/topic/list_equality.dart:1-3` (dartdoc only)
- Create: `packages/nidana_dart_contracts/test/shell_claim_test.dart`

**Interfaces:**
- Consumes (nidana.model.10): `compareTopicRefs(TopicRef a, TopicRef b)` and `List<T> sortedCopy<T>(Iterable<T> elements, Comparator<T> compare)` from `lib/src/ir/canonical_order.dart`; `bool elementsEqual(List<Object?> a, List<Object?> b)` from `lib/src/topic/list_equality.dart`; the five `MessageSource` classes, with value equality (nidana.model.8).
- Produces, for Task 3: `ShellClaim`'s factory, `==` and `hashCode`; `writes` iterating in canonical order. Task 3 adds the private getter `ClaimKey get _key` that sorts claims; do not add it here, where nothing reads it (`unused_element`).

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/shell_claim_test.dart` with exactly this content:

```dart
// topology-ir@v1's ShellClaim, beyond the G12 case of its conformance suite,
// which the gate replays: the argument each rejection names, the canonical
// order of a claim's writes, its unmodifiable copy (G3) and value equality
// (G7), whose graph and claim cases first replay at nidana.model.12.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

TopicRef state(String name, [String type = 'int']) =>
    TopicRef(name: name, variant: TopicVariant.state, typeName: type);

TopicRef event(String name) =>
    TopicRef(name: name, variant: TopicVariant.event, typeName: 'int');

/// Throws an ArgumentError whose name is [argument].
Matcher rejects(String argument) => throwsA(
  isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', argument),
);

void main() {
  test('G12 a claim takes a service, page or executor source at any scope, '
      'and rejects a topology or unknown source naming the source', () {
    final Set<TopicRef> writes = <TopicRef>{state('a.b')};
    for (final MessageSource source in <MessageSource>[
      const ServiceSource('s'),
      const PageSource('p'),
      const ExecutorSource('e'),
    ]) {
      for (final Scope scope in Scope.values) {
        final ShellClaim claim = ShellClaim(
          source: source,
          scope: scope,
          writes: writes,
        );
        expect(claim.source, source);
        expect(claim.scope, scope);
      }
      expect(
        ShellClaim(source: source, writes: writes).scope,
        Scope.application,
      );
    }
    expect(
      () => ShellClaim(source: const TopologySource('t'), writes: writes),
      rejects('source'),
    );
    expect(
      () => ShellClaim(source: const UnknownSource(), writes: writes),
      rejects('source'),
    );
  });

  test('G12 a claim rejects an empty set, and a set with any topic that is '
      'not a state topic, naming the writes', () {
    const ServiceSource s = ServiceSource('s');
    expect(
      () => ShellClaim(source: s, writes: <TopicRef>{}),
      rejects('writes'),
    );
    expect(
      () =>
          ShellClaim(source: s, writes: <TopicRef>{state('a.b'), event('a.c')}),
      rejects('writes'),
    );
    expect(
      () => ShellClaim(
        source: s,
        writes: <TopicRef>{
          const TopicRef(
            name: 'a.d',
            variant: TopicVariant.replay,
            typeName: 'int',
          ),
          state('a.b'),
        },
      ),
      rejects('writes'),
    );
  });

  test('G3 a claim keeps an unmodifiable copy of its writes, in canonical '
      'order, whatever order they were given in', () {
    final Set<TopicRef> given = <TopicRef>{
      state('b.a'),
      state('a.b', 'String'),
      state('a.b', 'Cart'),
    };
    final ShellClaim claim = ShellClaim(
      source: const ServiceSource('s'),
      writes: given,
    );
    given.add(state('c.c'));
    expect(claim.writes.toList(), <TopicRef>[
      state('a.b', 'Cart'),
      state('a.b', 'String'),
      state('b.a'),
    ]);
    expect(() => claim.writes.add(state('d.d')), throwsUnsupportedError);
    expect(() => claim.writes.clear(), throwsUnsupportedError);
  });

  test('G7 claims are equal, with equal hash codes, exactly when their '
      'source, scope and writes are', () {
    ShellClaim claim(
      MessageSource source,
      Iterable<TopicRef> writes, [
      Scope scope = Scope.application,
    ]) => ShellClaim(source: source, scope: scope, writes: writes.toSet());
    final ShellClaim a = claim(const ServiceSource('s'), <TopicRef>[
      state('a.a'),
      state('a.b'),
    ]);
    final ShellClaim same = claim(
      ServiceSource(<String>['s'].single),
      <TopicRef>[state('a.b'), state('a.a')],
    );
    expect(a, same);
    expect(a.hashCode, same.hashCode);
    expect(
      a,
      isNot(
        claim(const PageSource('s'), <TopicRef>[state('a.a'), state('a.b')]),
      ),
    );
    expect(
      a,
      isNot(
        claim(const ServiceSource('s'), <TopicRef>[
          state('a.a'),
          state('a.b'),
        ], Scope.module),
      ),
    );
    expect(a, isNot(claim(const ServiceSource('s'), <TopicRef>[state('a.a')])));
    expect(
      a,
      isNot(
        claim(const ServiceSource('s'), <TopicRef>[
          state('a.a'),
          state('a.b', 'String'),
        ]),
      ),
    );
    expect(<ShellClaim>{a, same}, hasLength(1));
    expect(a, isNot(a.writes));
  });
}
```

- [ ] **Step 2: Run the test and the G12 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/shell_claim_test.dart; echo "exit: $?"`
Expected: `+0 -4: Some tests failed.` and `exit: 1`: three on `UnimplementedError`, one on `Expected: throws <Instance of 'ArgumentError'> with `name`: 'writes'` (T2.2).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G12; echo "exit: $?"`
Expected: `cases (0 passed, 1 failed, ...)` and `exit: 1` (T2.2).

- [ ] **Step 3: Implement `ShellClaim` in `lib/src/graph/graph.dart`**

Add `import '../ir/canonical_order.dart';` and `import '../topic/list_equality.dart';` to the imports, in sorted order. Delete the comment line and the `// ignore: unused_element` line above `const ShellClaim._(...)`; the constructor stays as it is. Leave `TopologyGraph`, its `ignore` line, the extension and `GraphRenderer` as they are.

The factory checks in this order and then constructs:
1. `source` must be a service, page or executor source, decided by a private top-level function placed after the class, an exhaustive switch so that a new source variant fails to compile here:

```dart
// Whether a shell publisher may claim with [source] (G12): a topology owns
// its topics through its definition, and an unknown source owns nothing.
bool _isShellSource(MessageSource source) => switch (source) {
  ServiceSource() || PageSource() || ExecutorSource() => true,
  TopologySource() || UnknownSource() => false,
};
```

   otherwise `ArgumentError.value(source, 'source', 'is not a service, page or executor source')`;
2. `writes` empty: `ArgumentError.value(writes, 'writes', 'must not be empty')`;
3. the first element whose `variant` is not `TopicVariant.state`: `ArgumentError.value(topic.name, 'writes', 'names a topic that is not a state topic')`;
4. `return ShellClaim._(source: source, scope: scope, writes: Set<TopicRef>.unmodifiable(sortedCopy(writes, compareTopicRefs)));`

Equality, after the fields:

```dart
  // source, scope and writes, element by element in canonical order
  // (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is ShellClaim &&
      other.source == source &&
      other.scope == scope &&
      elementsEqual(other.writes.toList(), writes.toList());

  @override
  int get hashCode => Object.hash(source, scope, Object.hashAll(writes));
```

In `lib/src/topic/list_equality.dart`, replace the three dartdoc lines of `elementsEqual`, which named only envelopes and lineages (routed item), with exactly these; the function does not change:

```dart
/// The element-wise comparison that value equality uses for the lists a
/// value holds: an envelope's and a lineage's parent correlation ids
/// (topic-model@v1 G13), and the lists and sets of the IR values, findings,
/// claims and graphs (topology-ir@v1 G7), a set compared as its list: true
/// when [a] and [b] have the same length and `a[i] == b[i]` at every index.
/// A `List`'s own `==` is identity.
```

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `+211: All tests passed!` (207 before, 4 added) and `No issues found!` (T2.4).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G12; echo "exit: $?"`
Expected: `1 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G12` and `exit: 0` (T2.4). `grep -c 'ignore:' packages/nidana_dart_contracts/lib/src/graph/graph.dart` prints `1`: `TopologyGraph._`'s, which Task 3 removes.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/graph/graph.dart packages/nidana_dart_contracts/lib/src/topic/list_equality.dart packages/nidana_dart_contracts/test/shell_claim_test.dart
git commit -m "feat(dart_contracts): check shell claims and give them value equality" -m "<the co-author trailer your harness gives>"
```

### Task 3: TopologyGraph, toGraph and render

You are filling in `TopologyGraph`, the `toGraph()` extension and `render` in `packages/nidana_dart_contracts/lib/src/graph/graph.dart`: topologies by id with equal definitions counted once and unequal ones with one id rejected, claims in canonical order with equal claims kept, `topics` (G11), unmodifiable copies (G3) and equality that ignores the order of the arguments (G7). Run every command from the repository root with `fvm dart`. This task turns topology-ir@v1's three G11 cases green, which completes the gate's restriction.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/graph/graph.dart` (`ShellClaim`'s claim key; `TopologyGraph`; the extension)
- Create: `packages/nidana_dart_contracts/test/topology_graph_test.dart`

**Interfaces:**
- Consumes: Task 2's `ShellClaim`; from `lib/src/ir/canonical_order.dart` (nidana.model.10) `compareTopicRefs`, `compareTopologyIds(String a, String b)`, `typedef ClaimKey = ({MessageSource source, Scope scope, Iterable<TopicRef> writes})`, `int compareClaimKeys(ClaimKey a, ClaimKey b)` and `sortedCopy`; `TopologyDefinition`'s `topologyId`, `reads`, `writes` and value equality (nidana.model.10).
- Produces: `TopologyGraph`'s factory, `==`, `hashCode` and `render`; `TopologyDefinitionGraph.toGraph()`. nidana.model.12 and .13 build on them.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/topology_graph_test.dart` with exactly this content:

```dart
// topology-ir@v1's TopologyGraph, beyond the G11 cases of its conformance
// suite, which the gate replays: the canonical orders on inputs the suite
// does not build, unequal definitions with one id in any order, topics read
// in several places, unmodifiable copies (G3) and value equality that
// ignores the order of the arguments (G7), whose graph and claim cases
// first replay at nidana.model.12, toGraph() and render.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

TopicRef ref(
  String name, [
  TopicVariant variant = TopicVariant.event,
  String type = 'int',
]) => TopicRef(name: name, variant: variant, typeName: type);

TopicRef state(String name, [String type = 'int']) =>
    ref(name, TopicVariant.state, type);

/// A topology that merges [reads] and writes the merge to each of [writes].
TopologyDefinition rw(
  String id,
  List<TopicRef> reads,
  List<TopicRef> writes, [
  Scope scope = Scope.page,
]) => TopologyDefinition(
  topologyId: id,
  scope: scope,
  transforms: <TransformEdge>[
    TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
      for (final TopicRef r in reads) TopicInput(r),
    ]),
    for (final TopicRef w in writes)
      TransformEdge.write(w, const StageInput(0)),
  ],
);

ShellClaim claim(
  MessageSource source,
  List<TopicRef> writes, [
  Scope scope = Scope.application,
]) => ShellClaim(source: source, scope: scope, writes: writes.toSet());

/// Throws an ArgumentError whose name is [argument].
Matcher rejects(String argument) => throwsA(
  isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', argument),
);

/// An iterable that counts how often it is iterated.
final class Counted<T> extends Iterable<T> {
  Counted(this._elements);

  final List<T> _elements;
  int iterations = 0;

  @override
  Iterator<T> get iterator {
    iterations++;
    return _elements.iterator;
  }
}

/// A renderer that keeps every graph it is given.
final class Keeping implements GraphRenderer {
  final List<TopologyGraph> seen = <TopologyGraph>[];

  @override
  String render(TopologyGraph graph) {
    seen.add(graph);
    return 'rendered ${graph.topologies.length}';
  }
}

void main() {
  final TopologyDefinition a = rw(
    'a',
    <TopicRef>[ref('t.a')],
    <TopicRef>[ref('t.b')],
  );
  final TopologyDefinition b = rw(
    'b',
    <TopicRef>[ref('t.b')],
    <TopicRef>[state('t.c')],
  );
  final TopologyDefinition c = rw(
    'c',
    <TopicRef>[state('t.c')],
    <TopicRef>[ref('t.d')],
  );

  test('G11 a graph lists its topologies by id, each equal definition '
      'counted once however often and in whatever order it comes', () {
    final TopologyDefinition aAgain = rw(
      'a',
      <TopicRef>[ref('t.a')],
      <TopicRef>[ref('t.b')],
    );
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[c, a, b, aAgain, c, a],
    );
    expect(g.topologies, <TopologyDefinition>[a, b, c]);
    expect(
      TopologyGraph(topologies: <TopologyDefinition>[a, a]).topologies,
      <TopologyDefinition>[a],
    );
  });

  test('G11 two unequal definitions with one id throw ArgumentError naming '
      'the topologies, in either order and beside an equal copy', () {
    final TopologyDefinition other = rw(
      'a',
      <TopicRef>[ref('t.a')],
      <TopicRef>[ref('t.b')],
      Scope.module,
    );
    for (final List<TopologyDefinition> given in <List<TopologyDefinition>>[
      <TopologyDefinition>[a, other],
      <TopologyDefinition>[other, a],
      <TopologyDefinition>[a, a, other],
      <TopologyDefinition>[b, other, c, a],
    ]) {
      expect(() => TopologyGraph(topologies: given), rejects('topologies'));
    }
  });

  test('G11 claims sort by source rendering, then scope, then writes element '
      'by element, a prefix first, with equal claims kept', () {
    final TopologyGraph g = TopologyGraph(
      claims: <ShellClaim>[
        claim(const ServiceSource('s'), <TopicRef>[state('t.b')]),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a'), state('t.b')]),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a')], Scope.page),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a')]),
        claim(const PageSource('s'), <TopicRef>[state('t.z')]),
        claim(const ExecutorSource('s'), <TopicRef>[state('t.z')]),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a')], Scope.module),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a')]),
      ],
    );
    expect(g.claims, <ShellClaim>[
      claim(const ExecutorSource('s'), <TopicRef>[state('t.z')]),
      claim(const PageSource('s'), <TopicRef>[state('t.z')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a'), state('t.b')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.b')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a')], Scope.module),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a')], Scope.page),
    ]);
  });

  test('G11 topics are every topic read, written or claimed, each once, in '
      'canonical order', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw(
          'x',
          <TopicRef>[ref('n.a'), state('n.a')],
          <TopicRef>[ref('n.a', TopicVariant.replay)],
        ),
        rw(
          'y',
          <TopicRef>[ref('n.a', TopicVariant.replay)],
          <TopicRef>[state('n.a', 'String')],
        ),
      ],
      claims: <ShellClaim>[
        claim(const ServiceSource('s'), <TopicRef>[state('n.a'), state('m.z')]),
      ],
    );
    expect(g.topics, <TopicRef>[
      state('m.z'),
      state('n.a', 'String'),
      state('n.a'),
      ref('n.a'),
      ref('n.a', TopicVariant.replay),
    ]);
  });

  test('G3 a graph keeps unmodifiable copies of its lists; later changes to '
      'its arguments do not reach it', () {
    final List<TopologyDefinition> topologies = <TopologyDefinition>[b, a];
    final List<ShellClaim> claims = <ShellClaim>[
      claim(const ServiceSource('s'), <TopicRef>[state('t.s')]),
    ];
    final TopologyGraph g = TopologyGraph(
      topologies: topologies,
      claims: claims,
    );
    topologies
      ..clear()
      ..add(c);
    claims.clear();
    expect(g.topologies, <TopologyDefinition>[a, b]);
    expect(g.claims, hasLength(1));
    expect(g.topics, hasLength(4));
    expect(() => g.topologies.add(c), throwsUnsupportedError);
    expect(() => g.claims.clear(), throwsUnsupportedError);
    expect(() => g.topics.removeLast(), throwsUnsupportedError);
    expect(() => TopologyGraph().topologies.add(a), throwsUnsupportedError);
  });

  test('G7 a graph built from lazy iterables equals one built from lists, '
      'and reads each argument once', () {
    final List<ShellClaim> claims = <ShellClaim>[
      claim(const ServiceSource('s'), <TopicRef>[state('t.s')]),
      claim(const PageSource('p'), <TopicRef>[state('t.p')]),
    ];
    final Counted<TopologyDefinition> topologies = Counted<TopologyDefinition>(
      <TopologyDefinition>[c, b, a],
    );
    final Counted<ShellClaim> counted = Counted<ShellClaim>(claims);
    final TopologyGraph g = TopologyGraph(
      topologies: topologies,
      claims: counted,
    );
    expect(topologies.iterations, 1);
    expect(counted.iterations, 1);
    final TopologyGraph lists = TopologyGraph(
      topologies: <TopologyDefinition>[a, b, c],
      claims: claims,
    );
    expect(g, lists);
    expect(
      TopologyGraph(
        topologies: <TopologyDefinition>[a, b, c].reversed,
        claims: claims.where((ShellClaim each) => true),
      ),
      lists,
    );
  });

  test('G7 graphs are equal, with equal hash codes, exactly when their '
      'topologies and claims are, whatever order the arguments came in', () {
    final ShellClaim s = claim(const ServiceSource('s'), <TopicRef>[
      state('t.s'),
    ]);
    final ShellClaim p = claim(const PageSource('p'), <TopicRef>[state('t.p')]);
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[a, b],
      claims: <ShellClaim>[s, p],
    );
    final TopologyGraph same = TopologyGraph(
      topologies: <TopologyDefinition>[b, a, b],
      claims: <ShellClaim>[p, s],
    );
    expect(g, same);
    expect(g.hashCode, same.hashCode);
    expect(<TopologyGraph>{g, same}, hasLength(1));
    expect(
      g,
      isNot(
        TopologyGraph(
          topologies: <TopologyDefinition>[a, b],
          claims: <ShellClaim>[s, p, s],
        ),
      ),
    );
    expect(
      g,
      isNot(
        TopologyGraph(
          topologies: <TopologyDefinition>[a, b, c],
          claims: <ShellClaim>[s, p],
        ),
      ),
    );
    expect(
      g,
      isNot(
        TopologyGraph(
          topologies: <TopologyDefinition>[a, b],
          claims: <ShellClaim>[s],
        ),
      ),
    );
    expect(TopologyGraph(), TopologyGraph(topologies: <TopologyDefinition>[]));
    expect(
      TopologyGraph().hashCode,
      TopologyGraph(claims: <ShellClaim>[]).hashCode,
    );
    expect(TopologyGraph(), isNot(g));
  });

  test('G11 toGraph is the graph of the one definition; render passes the '
      'graph itself to the renderer and returns its text', () {
    final TopologyGraph g = a.toGraph();
    expect(g, TopologyGraph(topologies: <TopologyDefinition>[a]));
    expect(g.topologies.single, a);
    expect(g.claims, isEmpty);
    expect(g.topics, <TopicRef>[ref('t.a'), ref('t.b')]);
    final Keeping renderer = Keeping();
    expect(g.render(renderer), 'rendered 1');
    expect(identical(renderer.seen.single, g), isTrue);
  });
}
```

- [ ] **Step 2: Run the test and the G11 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/topology_graph_test.dart; echo "exit: $?"`
Expected: `+0 -8: Some tests failed.` and `exit: 1`: seven on `UnimplementedError`, one on `Expected: throws <Instance of 'ArgumentError'> with `name`: 'topologies'` (T3.2).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G11; echo "exit: $?"`
Expected: `cases (0 passed, 3 failed, ...)` and `exit: 1` (T3.2).

- [ ] **Step 3: Implement `TopologyGraph`, `toGraph()` and `render` in `lib/src/graph/graph.dart`**

In `ShellClaim`, after its fields, add the key the claim order compares (routed item: the order is defined over a claim's parts in `ir/`, so `ir/` never names `ShellClaim`):

```dart
  // The parts of this claim that the claim order compares.
  ClaimKey get _key => (source: source, scope: scope, writes: writes);
```

In `TopologyGraph`, delete the comment line and the `// ignore: unused_element` line above `const TopologyGraph._(...)`; the constructor and the three fields with their trailing comments stay. The factory:
1. `topologies` by id through a private top-level function placed after the class, which reads its argument once (through `sortedCopy`) and keeps one definition per id:

```dart
// [topologies] by topologyId, one per id (G11): an equal definition counts
// once, and one unequal to the definition already kept for its id throws
// ArgumentError.
List<TopologyDefinition> _distinctById(
  Iterable<TopologyDefinition> topologies,
) {
  final List<TopologyDefinition> kept = <TopologyDefinition>[];
  for (final TopologyDefinition d in sortedCopy(
    topologies,
    (TopologyDefinition a, TopologyDefinition b) =>
        compareTopologyIds(a.topologyId, b.topologyId),
  )) {
    if (kept.isEmpty || kept.last.topologyId != d.topologyId) {
      kept.add(d);
    } else if (kept.last != d) {
      throw ArgumentError.value(
        d.topologyId,
        'topologies',
        'holds two definitions with this id that are not equal',
      );
    }
  }
  return List<TopologyDefinition>.unmodifiable(kept);
}
```

2. `claims` as `sortedCopy(claims, (ShellClaim a, ShellClaim b) => compareClaimKeys(a._key, b._key))`, equal claims kept;
3. `topics` as `sortedCopy` by `compareTopicRefs` of a set literal holding every topic of the kept definitions' `reads`, then their `writes`, then the sorted claims' `writes`, so each topic appears once;
4. `return TopologyGraph._(topologies: ..., claims: ..., topics: ...)`. Read the two arguments only through steps 1 and 2.

`String render(GraphRenderer renderer) => renderer.render(this);`, its dartdoc unchanged. Equality, after `render`:

```dart
  // topologies and claims, element by element in their canonical orders, so
  // the order the arguments came in takes no part (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) =>
      other is TopologyGraph &&
      elementsEqual(other.topologies, topologies) &&
      elementsEqual(other.claims, claims);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(topologies), Object.hashAll(claims));
```

The extension's body becomes `TopologyGraph toGraph() => TopologyGraph(topologies: <TopologyDefinition>[this]);` (the formatter breaks it after `=>`), its dartdoc unchanged.

- [ ] **Step 4: Run the tests, the analyzer and the replays**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `+219: All tests passed!` (211 before, 8 added) and `No issues found!` (T3.4).
Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G11; echo "exit: $?"`
Expected: `3 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G11` and `exit: 0` (T3.4).
Run: `fvm dart run nidana_contract_check topology-ir --guarantee G2,G5,G6,G8,G9,G10,G11,G12; echo "exit: $?"`
Expected: `17 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G5, G6, G8 to G12`, `61 fixtures: 61 passed, 0 failed, 0 pending` and `exit: 0` (T3.4). `grep -c 'ignore:' packages/nidana_dart_contracts/lib/src/graph/graph.dart` prints `0`.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/graph/graph.dart packages/nidana_dart_contracts/test/topology_graph_test.dart
git commit -m "feat(dart_contracts): build topology graphs in canonical order with value equality" -m "<the co-author trailer your harness gives>"
```

### Task 4: What the rejections say

You are correcting four error messages routed from the final reviews of nidana.model.9 and nidana.model.10 (Routed items): the argument a foreign handle was passed as (`lib/src/topology/builder.dart`, `handle.dart`), the variant of a read that takes no dedup argument (`builder.dart`), the input count an edge takes and the second sink edge on a state topic (`lib/src/ir/definition.dart`). No check, no error type and no argument name of a rejection the suites or the existing tests pin changes. Run every command from the repository root with `fvm dart`.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topology/builder.dart` (`_checkMade`, lines 33 to 47; `read`, lines 109 to 116; its ten callers; two private functions at the end)
- Modify: `packages/nidana_dart_contracts/lib/src/topology/handle.dart` (the three `_checkMade` calls, lines 32, 53 and 76)
- Modify: `packages/nidana_dart_contracts/lib/src/ir/definition.dart` (lines 101 to 110 and 407 to 411)
- Create: `packages/nidana_dart_contracts/test/error_messages_test.dart`

**Interfaces:**
- Consumes: Task 1's projection (the G6 test records two state topics whose value types render alike); the builder and IR as they stand.
- Produces: `List<H> _checkMade<H extends TopicStream<Object?>>(List<H> handles, List<String> names)` in `TopologyBuilder`; `List<String> _elementNames(String name, int length)` and `String _variantOf(MultiWriterTopic<Object?> topic)` in the topology library. Nothing later depends on them.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/error_messages_test.dart` with exactly this content:

```dart
// What the recording builder's and the IR's rejections say: the argument a
// foreign handle was passed as, the variant of a read that takes no dedup,
// the input count an edge takes, and why two state topics whose value types
// render alike make a second sink edge (topology-dsl@v2 G13 and G14;
// topology-ir@v1 G5 and G6).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

import 'src/cart_elsewhere.dart' as elsewhere;

final class Cart {
  const Cart();
}

const StateTopic<int> count = StateTopic<int>(name: 'msg.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'msg.taps');
const EventTopic<int> out = EventTopic<int>(name: 'msg.out');
const ReplayTopic<int> log = ReplayTopic<int>(name: 'msg.log', bufferSize: 2);

/// An ArgumentError whose name is [name] and whose message holds [parts].
Matcher rejects(String name, [List<String> parts = const <String>[]]) =>
    throwsA(
      isA<ArgumentError>()
          .having((ArgumentError e) => e.name, 'name', name)
          .having(
            (ArgumentError e) => '${e.message}',
            'message',
            allOf(<Matcher>[for (final String p in parts) contains(p)]),
          ),
    );

/// The plan of a declaration that [body] makes, where [foreign] is a handle
/// an earlier declaration made.
TopologyPlan plan(
  void Function(TopologyBuilder b, TopicStream<int> foreign) body,
) {
  late TopicStream<int> foreign;
  planOf(
    topology('msg-earlier', Scope.page, (TopologyBuilder b) {
      foreign = b.read(taps);
      b.write(out, foreign);
    }),
  );
  return planOf(
    topology('msg', Scope.page, (TopologyBuilder b) => body(b, foreign)),
  );
}

int first(int a, [int? b, int? c, int? d]) => a;

void main() {
  test('G14 a foreign handle is named by the parameter it was passed as, or '
      'by its index in a list', () {
    final Map<String, void Function(TopologyBuilder b, TopicStream<int> f)>
    uses = <String, void Function(TopologyBuilder b, TopicStream<int> f)>{
      'stream': (TopologyBuilder b, TopicStream<int> f) => b.write(out, f),
      'events': (TopologyBuilder b, TopicStream<int> f) =>
          b.reduceInto(count, f, (int s, int e) => s),
      'b': (TopologyBuilder b, TopicStream<int> f) =>
          b.write(out, b.combine2(b.read(taps), f, first)),
      'c': (TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, b.combine3(t, t, f, first));
      },
      'd': (TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, b.combine4(t, t, t, f, first));
      },
      'inputs[1]': (TopologyBuilder b, TopicStream<int> f) => b.write(
        out,
        b.combineAll(<TopicStream<int>>[b.read(taps), f], (List<int> v) => 0),
      ),
      'inputs[2]': (TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, b.merge(<TopicStream<int>>[t, t, f]));
      },
      'latest': (TopologyBuilder b, TopicStream<int> f) =>
          b.write(out, b.read(taps).withLatestFrom(f, first)),
    };
    for (final MapEntry<
          String,
          void Function(TopologyBuilder b, TopicStream<int> f)
        >
        use
        in uses.entries) {
      expect(
        () => plan(use.value),
        rejects(use.key, <String>['another builder']),
        reason: use.key,
      );
    }
    expect(
      () => plan((TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, t.withLatestFrom2(t, f, first));
      }),
      rejects('c'),
    );
    expect(
      () => plan((TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, t.withLatestFrom3(f, t, t, first));
      }),
      rejects('b'),
    );
    expect(
      () => plan((TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, t.withLatestFrom3(t, t, f, first));
      }),
      rejects('d'),
    );
  });

  test('G13 a dedup argument on an event or replay read names the read\'s '
      'variant with its article', () {
    expect(
      () => plan(
        (TopologyBuilder b, TopicStream<int> f) =>
            b.write(out, b.read(taps, dedup: Dedup.none)),
      ),
      rejects('dedup', <String>['msg.taps is an event topic']),
    );
    expect(
      () => plan(
        (TopologyBuilder b, TopicStream<int> f) =>
            b.write(out, b.read(log, dedup: Dedup.equality)),
      ),
      rejects('dedup', <String>['msg.log is a replay topic']),
    );
  });

  test('G5 an edge given the wrong number of inputs says how many its '
      'combinator takes', () {
    final FunctionRef f = FunctionRef.named('f');
    final TopicInput a = TopicInput(taps.ref);
    Matcher says(String message) => throwsA(
      isA<ArgumentError>()
          .having((ArgumentError e) => e.name, 'name', 'inputs')
          .having((ArgumentError e) => e.message, 'message', message),
    );
    expect(
      () => TransformEdge.stage(CombinatorKind.map, <EdgeInput>[
        a,
        a,
      ], transformer: f),
      says('a map edge takes exactly 1 input'),
    );
    expect(
      () => TransformEdge.stage(CombinatorKind.merge, const <EdgeInput>[]),
      says('a merge edge takes at least 1 input'),
    );
    expect(
      () => TransformEdge.stage(CombinatorKind.withLatestFrom, <EdgeInput>[
        a,
      ], transformer: f),
      says('a withLatestFrom edge takes 2 to 4 inputs'),
    );
  });

  test('G6 a second sink edge on a state topic names the topic and its type, '
      'and says that value types rendering alike are one topic', () {
    const StateTopic<Cart> mine = StateTopic<Cart>(
      name: 'shop.cart',
      initial: Cart(),
    );
    const StateTopic<elsewhere.Cart> theirs = StateTopic<elsewhere.Cart>(
      name: 'shop.cart',
      initial: elsewhere.Cart(),
    );
    final Topology t = topology('alike', Scope.page, (TopologyBuilder b) {
      b.write(mine, b.read(taps).map((int v) => const Cart()));
      b.write(theirs, b.read(taps).map((int v) => const elsewhere.Cart()));
    });
    expect(
      t.buildDefinition,
      rejects('transforms', <String>[
        'second sink edge',
        'Cart',
        'render alike',
      ]),
    );
    expect(
      t.buildDefinition,
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.invalidValue,
          'invalidValue',
          'shop.cart',
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fvm dart test packages/nidana_dart_contracts/test/error_messages_test.dart; echo "exit: $?"`
Expected: `+0 -4: Some tests failed.` and `exit: 1`: the G14 test on `with `name`: 'stream'` (HEAD names every foreign handle `handle`), the G13 test on `contains 'msg.log is a replay topic'` (its event read already passes), the G5 test on the message `'a map edge takes exactly 1 input'`, the G6 test on `contains 'second sink edge' and contains 'Cart' and contains 'render alike'` (T4.2).

- [ ] **Step 3: Rewrite the four messages**

In `lib/src/topology/builder.dart`:

- `_checkMade` takes the parameter names, one per handle, and names the first foreign handle by its own; the message is unchanged:

```dart
  // Throws ArgumentError unless this builder made every one of [handles]
  // (G14), naming the first foreign one by its parameter, the element of
  // [names] at its index; returns [handles] as an unmodifiable copy.
  List<H> _checkMade<H extends TopicStream<Object?>>(
    List<H> handles,
    List<String> names,
  ) {
```

  It loops over the indices and throws `ArgumentError.value(handles[i], names[i], <the message as it stands>)`.
- Its ten callers pass these names, each as a `const <String>[...]` except the two list parameters:

  | Caller | `names` |
  |--------|---------|
  | `write` | `['stream']` |
  | `reduceInto` | `['events']` |
  | `combine2`, `combine3`, `combine4` | `['a', 'b']`, `['a', 'b', 'c']`, `['a', 'b', 'c', 'd']`, the handles passed as `<TopicStream<Object?>>[a, b, ...]` as before |
  | `combineAll`, `merge` | `_elementNames('inputs', inputs.length)` |
  | `withLatestFrom`, `withLatestFrom2`, `withLatestFrom3` (in `handle.dart`) | `['latest']`, `['b', 'c']`, `['b', 'c', 'd']` |

- `read`'s rejection of a dedup argument says `'applies to a state topic read only, and ${topic.name} is ${_variantOf(topic)}'` (the `is` test above it has promoted `topic` to `MultiWriterTopic<T>`).
- At the end of the file, after the class:

```dart
// The names of the elements of the list parameter [name], by index:
// 'inputs[0]', 'inputs[1]' and so on.
List<String> _elementNames(String name, int length) => <String>[
  for (int i = 0; i < length; i++) '$name[$i]',
];

// [topic]'s variant with its article, for a message.
String _variantOf(MultiWriterTopic<Object?> topic) => switch (topic) {
  EventTopic<Object?>() => 'an event topic',
  ReplayTopic<Object?>() => 'a replay topic',
};
```

In `lib/src/ir/definition.dart`:

- `TransformEdge.stage`'s input-count rejection keeps `count` and says `'a ${combinator.name} edge takes $count $noun'`, with `final String noun = (rule.maxInputs ?? rule.minInputs) == 1 ? 'input' : 'inputs';` above it: "exactly 1 input", "at least 1 input", "2 to 4 inputs".
- `_checkWellFormed`'s second-sink rejection keeps its value `output.name` and its name `transforms` and says:

```dart
          'edge $i is a second sink edge on this state topic, of type '
              '${output.typeName}; two state topics of one name whose value '
              'types render alike, one class name in two libraries, are one '
              'topic in the IR',
```

- [ ] **Step 4: Run the tests, the analyzer and the recording replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `+223: All tests passed!` (219 before, 4 added) and `No issues found!` (T4.4).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior; echo "exit: $?"`
Expected: `24 passed, 0 failed, 0 skipped under dart test` and `exit: 0` (T4.4).
Run: `grep -rnE "is an '|'handle'|count inputs'" packages/nidana_dart_contracts/lib; echo "exit: $?"`
Expected: no line and `exit: 1` (C).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topology/builder.dart packages/nidana_dart_contracts/lib/src/topology/handle.dart packages/nidana_dart_contracts/lib/src/ir/definition.dart packages/nidana_dart_contracts/test/error_messages_test.dart
git commit -m "fix(dart_contracts): name the argument and the variant in recording and IR rejections" -m "<the co-author trailer your harness gives>"
```

### Task 5: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.11.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.11.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 4; the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run the gate of Global Constraint 4 exactly (it is the Gate line of the Phase block in `hsdd-context/nidana.model.11.md`), as `(<gate>) > "${TMPDIR:-/tmp}/nidana.model.11-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after. Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+223: All tests passed!`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test`, `59 fixtures: 59 passed, 0 failed, 0 pending`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 17 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G5, G6, G8 to G12` and `61 fixtures: 61 passed, 0 failed, 0 pending`, with no `FAIL`, `ERROR` or `PENDING` line (G). Any other result stops here: a failure is fixed in the task that owns the code or, for a fixture that fails against code that follows this plan, reported as a contract gap (Global Constraints).

The `+223` is this plan's count; it is higher by the tests the implementers added.

- [ ] **Step 2: Run the checklist**

`<base>` below is the parent of Task 1's commit (`git log --format=%H -n 1 <Task 1's commit>^`). Run each and keep its output:
- `fvm dart test hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart --name '^G(9|10|12) ' -r expanded` (expected: the seven G9, G10 and G12 case names, then `+7: All tests passed!`) and `fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G(8|11|12) ' -r expanded` (expected: the seven G8, G11 and G12 case names, then `+7: All tests passed!`): the cases this phase turned green, by name (C).
- `fvm dart test packages/nidana_dart_contracts/test/projection_test.dart packages/nidana_dart_contracts/test/shell_claim_test.dart packages/nidana_dart_contracts/test/topology_graph_test.dart packages/nidana_dart_contracts/test/error_messages_test.dart -j 1 -r expanded` (expected: the 23 test names, 7, 4, 8 and 4 in that order, then `+23: All tests passed!`) (C).
- `fvm dart run nidana_contract_check topology-ir --set behavior; echo "exit: $?"` (expected: `exit: 1` and `cases (19 passed, 24 failed, ...)`; the 19 are the restriction's 17, `G7 IR values are equal, ...` and `G3 the IR copies the lists it is given; later changes to them do not reach it`; the 24 others call what nidana.model.12 to .14 deliver) (U).
- `grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/ir packages/nidana_dart_contracts/lib/src/graph packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?"` (expected: no line, `exit: 1`).
- `grep -rn "ignore:" packages/nidana_dart_contracts/lib; echo "exit: $?"` (expected: no line, `exit: 1`).
- `grep -rnE "^(import|export) .*graph/" packages/nidana_dart_contracts/lib/src/ir; echo "exit: $?"` and `grep -rnE "is an '|'handle'|count inputs'" packages/nidana_dart_contracts/lib; echo "exit: $?"` (expected: no line, `exit: 1`, from each).
- `git diff --name-status <base> HEAD -- packages/nidana_dart_contracts` (expected: thirteen lines, `A` for `lib/src/ir/projection.dart` and the four new test files, `M` for `lib/src/topology/topology.dart`, `plan.dart`, `builder.dart`, `handle.dart`, `lib/src/ir/definition.dart`, `lib/src/graph/graph.dart`, `lib/src/topic/list_equality.dart` and `test/canonical_order_test.dart`).
- `git status --short pubspec.lock` and `git diff --stat <base> HEAD -- packages/nidana_dart_contracts/pubspec.yaml` (expected: no output from either).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.11.verification.md` at spot-check depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.11 - Projection, graphs and claims` (a spaced hyphen; no em-dash anywhere in the file). Short: commands, expected output, what to eyeball, Learnings.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as Step 1 ran it, saying that it replays topic-model@v1 and topology-dsl@v2 unrestricted (topology-dsl@v2's recording suite through `topology_builder_test.dart`, its live suite being bus-api@v2's to bind and nidana.runtime's to replay), and topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets in full and its `behavior` set through `nidana_dart_contracts_test.dart` restricted to G2, G5, G6, G8 to G12; the checklist commands of Step 2.
- **Expected output:** the gate's exit code and lines of Step 1; the checklist's expected results of Step 2.
- **Observed:** dated, with the gate's start and end times, the branch and commit, and Dart 3.13.5 through `fvm`; the gate's exit code and its lines as they appeared; then a checklist of `- [x]` lines, each with its result, to eyeball:
  - `buildDefinition()` of the contracts' example topologies gives the edges the From a plan rules describe: the suite's three G8 cases (`CheckoutFlow`, every combinator, two recordings equal) and the package's projection tests by name (topology-ir@v1's JSON example `search`, the `forms` sample, the findings sample's `quiet`, every arity form naming its combiner, reads written as they are);
  - two recordings of one declaration, inline closures included, project equal definitions: the suite's `G8 recording one declaration twice ...` and `G9 buildDefinition ... equals the definition of a fresh plan`, and the package's re-projection test;
  - the gate's two behavior replays, with their pass counts (topology-dsl@v2 24 of 24 against 19 before this phase; topology-ir@v1 17 of 17 against 10), and the unrestricted topology-ir@v1 count (19 of 43), naming the G3 case that passes ahead of its restriction and the G3 and G7 cases that wait for `analyzeTopologyGraph` (nidana.model.12);
  - G3 and G7 for graphs and claims, outside the gate's restriction, pinned by the package's tests in the gate's package run (`G3 a claim keeps ...`, `G7 claims are equal ...`, `G3 a graph keeps ...`, `G7 a graph built from lazy iterables ...`, `G7 graphs are equal ...`);
  - the rendered-alike corner: `planOf` accepts it, and `definition` and `buildDefinition()` throw `ArgumentError` named `transforms` with the reworded message;
  - no `UnimplementedError` remains under `lib/src/ir/`, `lib/src/graph/` or `lib/src/topology/`, no `ignore:` under `lib/`, `lib/src/ir/` imports nothing from `graph/`, none of the three routed messages remains, the export lists are unchanged (`exports_test.dart` passes), `purity_test.dart` passes over the changed libraries (topic-model@v1 G25, G26), and the lockfile and `pubspec.yaml` are unchanged.
- **Outstanding:** `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found the two below and the sizing line; write each that still holds, and any the gate finds:
  - `- The gate's replay passes five defects this phase's package tests catch (S140 dry run, seeded defects D3 to D6 and D8): a claim that hashes its writes by identity, a graph that hashes its lists by identity and graph equality that ignores the claims break assertions of G7's graph case, which leaves the restriction until nidana.model.12 because it also calls analyzeTopologyGraph; no case of topology-ir@v1's suite builds claims that tie on source and scope (claims ordered by source and scope only) or counts how often a graph reads its arguments (a graph that reads an argument twice). Disposition: dropped (G7's case first replays at nidana.model.12; the claim tie and the single read are routed to the end-of-node governance sweep for topology-ir@v1)`;
  - `- Two state topics whose value types render alike, one class name in two libraries, pass planOf but project to a definition with a second sink edge on one TopicRef, so buildDefinition() throws ArgumentError against the closing sentence of From a plan that every definition a plan projects to is well formed; this phase lets the error propagate with a message that names the cause. Disposition: dropped (already routed to the end-of-node governance sweep by S132's final review)`;
  - one sizing line: the phase scope's estimate of about 400 lines in about 6 files against the measured product diff (Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint).
- **Metrics:** one line: the product diff, `git diff --stat <base> HEAD -- packages/`, in files and lines, the library and the tests apart, beside the estimate of about 400 lines in about 6 files; the task count, 5 of the allowed 7.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.11.verification.md
git commit -m "docs(verify): nidana.model.11 verification" -m "<the co-author trailer your harness gives>"
```
