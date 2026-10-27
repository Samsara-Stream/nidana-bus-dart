# nidana.model.9 Recording Builder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver topology-dsl@v2's recording side under `packages/nidana_dart_contracts/lib/src/topology/`: `planOf`, the `topology()` form, every builder and handle call recording its stage or sink with the misuse checks of G13 to G15, `CombineStage.apply` and `WithLatestFromStage.apply`, `visitStage` and `visitSink`, and `TopologyRef` equality, so that 19 of the recording suite's 24 cases pass (none passes today) while `TopologyPlan.definition` keeps throwing until nidana.model.11, and the package's own tests pin what that suite leaves open.

**Architecture:** Bodies and private members only; every public declaration nidana.model.4 landed stays as it is. A handle knows the builder that made it through a private final field that `TopicStream`'s private constructor sets. The builder is the one mutable object, private to the library: it appends stages and sinks in call order, marks the stages a later stage or a sink consumes, remembers the state topics a sink writes, and `planOf` closes it in a `finally`. Every call checks first (an open builder, then its arguments) and records last, so a rejected call leaves nothing behind. `planOf` turns the record into an immutable `TopologyPlan` of unmodifiable lists and rejects a stage that nothing consumes. Combine and withLatestFrom stages hold a typed closure, built by the call that made them, which `apply` calls; `visitStage` and `visitSink` dispatch through a private `_accept` that each stage and sink class implements at its own type arguments. The tasks go from the record itself to the calls that feed it: `planOf` with reads and writes; the single-input handle calls; the multi-input calls with `reduceInto` and `apply`; the visitors.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:meta` 1.19.0 (`@immutable`, `@nonVirtual`), the package's only dependency; `package:test` for the package's tests, with `dart:async`'s `runZoned` and `ZoneSpecification` to count timers and microtasks; the replay tool `nidana_contract_check` with its `behavior` set (nidana.model.6).

**Spec:** `hsdd-context/superpowers/nidana.model.9.md` (the derivative; the phase context with topic-model@v1's and topology-dsl@v2's whole Interface and Guarantees sits between its markers). The dartdoc already in `lib/src/topology/` came from topology-dsl@v2's Interface, `hsdd/contract/topology-dsl.md` lines 40 to 412, and stays. Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D3 (line 102), D4 (line 112: `lib/src/topology/` is one library with part files, because the subclasses of the sealed `TopicStream` and `PlanSink` must share it), D5 (line 128) and D6 (line 135: `test/purity_test.dart` scans every library under `lib/` for the tokens `DateTime.now(`, `Stopwatch(`, `Timer(`, `Timer.periodic(`, `scheduleMicrotask(`, `Future.delayed(`, `Future.microtask(`, `Random(` and `Zone.`, as substrings, comments included). The fixtures the gate replays: `hsdd/contract/fixture/topology-dsl/` (`surface/`, `reject/`, and `behavior/recording_conformance.dart` through the binding `topology_builder_test.dart`); `behavior/live_conformance.dart` is bound by bus-api@v2 and replayed by nidana.runtime, not by this gate. Evidence: `docs/auto-run/experiments/recording-builder-plan/` (`run.sh`, `output.txt`, `facts/`, `gen_variants.py`, `draft/`), a dry run of this plan's tasks in a temporary copy of HEAD `53ebe2a`; labels such as F, S1, N, T1.2, G, C, A, D or X below name the steps of its `output.txt`. `draft/` is evidence, not code to copy: the blocks below are the source, each a formatter-stable excerpt of a draft file (X).

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 7 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model && fvm dart run nidana_contract_check topology-dsl --guarantee G10,G11,G13,G14,G15,G16,G17,G30 && fvm dart run nidana_contract_check topology-ir --set structure,surface,reject,schema` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.9.verification.md from
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

- **Toolchain:** `fvm dart` only, every command from the repository root, no global tooling. No dependency changes: no `pubspec.yaml` is edited and `pubspec.lock` stays byte-identical (C). The tests that count timers need no package: `runZoned` with a `ZoneSpecification` from `dart:async` intercepts every timer, periodic timer and microtask made inside it (F Z1 to Z10), and ADR-002 item 3's table gives `nidana_dart_contracts` `meta` and `test` alone (no `fake_async`).
- **Files:** under `lib/` this phase edits the six part files of `lib/src/topology/` (`topology.dart`, `builder.dart`, `handle.dart`, `stages.dart`, `sinks.dart`, `plan.dart`) and no other library; the three public libraries' export lists stay exactly as `test/exports_test.dart` pins them. Under `test/` it creates four files and edits none. `README.md`, `CHANGELOG.md` and `LICENSE` stay as they are (D4). Nothing under `hsdd/` changes except the verification doc of Task 5.
- **Interface:** every public name, signature, parameter name, default, modifier, annotation and `const` stays as topology-dsl@v2 states it and nidana.model.4 landed it, and every getter that returns a stored value stays a final field (D3). New members are private, and each task's Interfaces block names them; no class gains a public member, so `TopologyRef` gets `==` and `hashCode` and no `toString`. `TopologyPlan.definition` keeps `=> throw UnimplementedError();` (nidana.model.11). `Topology.buildDefinition()` becomes `planOf(this).definition`, Refinement 2's definition, so it keeps throwing: `StateError` for an empty id (the suite's G15 case asks for it), `UnimplementedError` for every declaration `planOf` accepts.
- **Check order (G14, G15, and the phase's Verification line):** every builder and handle method first throws `StateError` when the declaration that made its builder has returned; then it checks its arguments and throws `ArgumentError` for a misuse; only when every check has passed does it record its stage or sink. A rejected call adds no stage, consumes no handle and claims no topic, so a declaration that catches the error goes on as if the call never happened. `planOf` checks the topology id before it runs `declare`.
- **Identity (F I1 to I11):** a stage or sink holds the very object it was given. A top-level or static function's tear-off, a local function's tear-off and a closure read twice from one variable or list are identical each time; the same closure literal evaluated twice, and an instance method torn off twice, are not; a `const Duration` is canonical, and a `Duration` built at run time is identical only to itself; storing a function at a wider function type or as `Function` keeps it identical. The tests below therefore keep each function and duration in a list or variable and compare with `identical`.
- **Type arguments (F V1 to V5):** a visitor reached through a private method that each stage class implements (`visitor.map<T, R>(this)` inside `MapStage<T, R>`) receives the stage's own type arguments. Reading `transform` through a pattern `MapStage<Object?, Object?>()` throws a `TypeError` at run time, which is why the contract routes interpreters through `visitStage`. A `List<Object?>` handed to a combiner that takes `List<int>` throws a `TypeError` (F C1), so `combineAll` hands its combiner a typed copy made inside a closure the builder call captures (F C2 to C4).
- **Comments:** the Interface's dartdoc stays as written and where nidana.model.4 put it. A new private member gets a `//` comment saying what it holds or checks, as the blocks below show. No word of `lib/` may contain a D6 token, in code or comment: write "timer" and "microtask", never a constructor call (C: no match). No em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.
- **Const collections (B, A, C):** `TopologyRef` now overrides `==`, as topics and topic references do since nidana.model.8, so a non-empty const set of, or a const map keyed by, any of them does not compile. No test of this phase writes one (C: no match in the four new files); the 84 committed Dart libraries under every slug's `surface/`, `reject/` and `behavior/` report the same 3143 diagnostics in 70 of them before and after this phase's bodies, none a const-collection code (B, A).
- **Analyzer:** `fvm dart analyze --fatal-infos` at the root reports nothing after every task. Lints the dry run met: `use_super_parameters` (the stage constructors take the builder as `super.builder`); `prefer_function_declarations_over_variables` (the tests keep closures in lists, not in local variables); strict inference's `inference_failure_on_function_invocation` (a call whose function only throws names its type arguments, as in `.map<int>(...)`); `unused_element` (a private helper lands in the task that first calls it: `_derive` and `_checkNotNegative` in Task 2, `_checkNotEmpty` and `_apply` in Task 3, `_accept` in Task 4). The package keeps nidana.model.4's and nidana.model.5's `// ignore: unused_element` lines, none of which is under `lib/src/topology/`.
- **Tests:** run from the root as `fvm dart test packages/nidana_dart_contracts`. Each task's failing step also replays the conformance cases of its guarantees, `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee {ids}`, which runs the committed binding under `dart test` and starts no `flutter`; no test of this phase starts `flutter` either. The package's tests do not repeat the suite's cases; they pin what it leaves open, and each of the dry run's ten seeded defects that the restricted replay passes fails one of them (D). Add a test beyond the plan's wherever a rule you implement would otherwise go unpinned. No test uses a `test` API newer than 1.31.1. topic-model@v1's replay (41 behavior cases) and topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets pass today and stay green through every task (S1, G); the gate checks both.
- **Contract gaps (ADR-001 item 8):** the dry run passes every committed fixture of topic-model@v1, topology-dsl@v2 and topology-ir@v1 against this plan's code except the two G10 cases of the known gap below (T4.4, G). Any other fixture that fails against code that follows this plan is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the case or library, what it reports, the guarantee, and the fix you would propose.
- **Formatting and commits:** run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for a Sonnet implementer.

## Known contract gap: G10's two cases need `buildDefinition()`

The gate's topology-dsl restriction names G10, and both G10 cases of the recording suite call `buildDefinition()`: `G10 recording calls none of the functions a declaration passes` (`recording_conformance.dart` line 314) and `G10 recording creates no timer and schedules no microtask` (line 327, inside its zone). This phase keeps `TopologyPlan.definition` throwing until nidana.model.11 (Scope; topology-dsl@v2 Delivery), and `TopologyDefinition`'s factory itself throws until nidana.model.10. So against this plan's finished code the gate's topology-dsl replay passes 17 of the 19 cases it runs and fails these two, each on `UnimplementedError` from `TopologyPlan.definition` through `Topology.buildDefinition` (T4.4), and the gate exits 1 there (G). With G10 dropped from the restriction, as the gate already leaves out G9 for the same reason, the gate exits 0 (G). S127 reported it to the orchestrator as a contract gap, with that fix: drop G10 from nidana.model.9's Gate and Scope (hsdd-phase-plan or hsdd-reconcile), and a compatible touch of topology-dsl@v2's Delivery paragraph reading "G9 and G10 but for `buildDefinition()`" (hsdd-contract). This phase still delivers G10 for `planOf`: Task 3's test `G10 recording every combinator calls none of its functions, nor a computed initial value, and creates no timer or microtask` pins it, and the gate runs it with the package's tests. No task changes code to make the two cases pass; Task 5 says what to do with the gate in either form.

## Review Focus

The input classes the spec implies but the conformance suite does not exercise, most likely to bite first; each has its test in the owning task.

1. **A declaration that catches a misuse and goes on:** a module that tries a dedup override and falls back, or tries an optional input and catches the `ArgumentError`. The suite asserts only that `planOf` throws. Expected: the rejected call leaves no stage, consumes no handle and claims no topic, so the declaration plans as if the call never happened; a check made after recording leaves a stage nothing consumes, and `planOf` then fails with a misleading `StateError` (D3, D8). Tests: Task 1 (dedup, second sink), Task 2 (negative durations), Task 3 (empty lists, a foreign handle in every input position).
2. **One state topic declared twice apart:** two `StateTopic` values with one name and one value type, from two registries or a non-const construction, with different initial values or dedup, each written by a sink. The suite writes one const topic twice, which an identity check also catches (D4). Expected: the second sink throws `ArgumentError` at its call, because topics compare by variant, name and value type (topic-model@v1 G7); one name with another value type is another topic and is accepted. Test: Task 1.
3. **A handle that outlives its declaration's normal return:** kept from a declaration that threw, or passed into a nested `planOf` of another topology while its own declaration still runs. Expected: `StateError` after a declaration that threw, because `planOf` closes the builder in a `finally` (D5); `ArgumentError` in the other declaration although its builder is open, because ownership is the builder's identity, not its state (D6). Test: Task 1.
4. **An input list the declaration keeps using:** a growable list passed to `combineAll` or `merge` and changed after the call. Expected: the stage keeps the inputs it was given in an unmodifiable list of its own (D7), and `combineAll`'s combiner receives a fresh unmodifiable `List<T>` on each call (D2). Test: Task 3.
5. **An interpreter that applies a stage at its own types:** nested generic types (`List<double>`, the record `pairwise` emits), a write to a wider topic (`EventTopic<Object?>`), and an `apply` given the wrong number of values. Expected: `visitStage` and `visitSink` bind the declaration's type arguments, which the suite does not check (D1); a function called through the visitor rejects a value of another type with `TypeError`; `apply` given more or fewer values than inputs throws `ArgumentError` instead of reading the wrong ones (D10). Tests: Task 4 (types), Task 3 (`apply`).

## Routed items

Each item routed to this phase (`docs/auto-run/impl-execution-plan.md`, "Routed to later phases", the entry naming nidana.model.9), with its disposition:

- G14's "a handle another builder made" needs a handle-to-builder link: Task 1, a private constructor argument, `TopicStream._(this._builder)` with `final TopologyBuilder _builder;`, which every stage's private constructor passes on as `super.builder`; ownership is `identical(handle._builder, this)`.
- `CombineStage.apply` for `combineAll` needs `T`, which `CombineStage<R>` does not carry: Task 3, a typed closure captured in the private constructor (`final R Function(List<Object?> values) _apply;`), which each builder call builds with its own type arguments; `combineAll`'s closure hands the combiner `List<T>.unmodifiable(values.cast<T>())`. `WithLatestFromStage` gets the same.
- Topic value equality from the nidana.model.8 merge, which the one-sink-per-`StateTopic` check uses: Task 1, a `Set<StateTopic<Object?>>` under topic `==` and `hashCode`; its test writes two state topics built apart with one name and type (Review Focus 2).
- No test may write a non-empty const set or map of topic-model values: none of the four new test files does (C), and no fixture's diagnostics change (A).

## Which task turns which failing case green

The binding runs 24 cases and passes none today (S1): every body throws `UnimplementedError`. The gate's restriction runs 19 of them (G10, G11, G13 to G17, G30) and fails all 19. By the task whose code turns each green; every task's failing and passing steps replay its own ids:

| Task | Cases (by guarantee: count) | Replay |
|------|-----------------------------|--------|
| 1 | G9: 2 (`planOf` once per call, the builder form), G11: 1 (unmodifiable lists), G13: 1 (dedup on an event or replay read), G15: 1 (empty id), G17: 1, G30: 1 | `--guarantee G13,G15,G17,G30` goes from 0 passed, 7 failed to 4 passed, 3 failed; `--guarantee G11` passes 1 of 5; G9's two cases by name pass (T1.2, T1.4) |
| 2 | G14: 1 (negative duration), G15: 1 (a stage that reaches no sink) | `--guarantee G14,G15` goes from 1 passed, 6 failed to 3 passed, 4 failed; the four left are Task 3's (T2.2, T2.4) |
| 3 | G11: 2 (what a stage holds, `apply`), G13: 1 (what a read records), G14: 3 (a foreign handle, a second sink, an empty list), G15: 1 (use after `declare` returned) | `--guarantee G10,G11,G13,G14,G15` goes from 5 passed, 11 failed to 12 passed, 4 failed: the two G10 cases (the known gap) and two G11 cases that need the visitors (T3.2, T3.4) |
| 4 | G11: 2 (each call's stage class, the sinks), G16: 1 | `--guarantee G11,G16` goes from 3 passed, 3 failed to 6 passed; the gate's restriction then passes 17 of 19, the two G10 cases failing (T4.2, T4.4) |

The five cases this phase leaves failing call `buildDefinition()` or read `definition`: `G9 buildDefinition runs declare once and equals the definition of a fresh plan`, the two G10 cases and the two G12 cases, which nidana.model.11 delivers (T4.4: unrestricted, 19 passed, 5 failed).

**G9 is not in the gate's restriction** (S126): ADR-001 item 9 restricts by guarantee id, and G9's third case calls `buildDefinition()`. Its two recording cases are checked twice. The package's tests, which the gate runs, hold `G9 planOf runs declare once per call against a fresh builder and carries the id and scope` and `G9 an empty declaration records an empty plan` (Task 1). Task 5's checklist runs the binding's two cases by name, `fvm dart test hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart --name '^G9 (planOf runs|the builder form)'`, which selects exactly those two (T1.4, C). `--plain-name` takes one substring, and two `--plain-name` flags must both match one name, so they select nothing and `dart test` exits 79 (N).

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/topology/topology.dart` | 1 | `buildDefinition()` through `planOf`, `topology()` and its private `_BuilderForm`, `TopologyRef` equality |
| `{pkg}/lib/src/topology/plan.dart` | 1, 4 | `planOf` (1); `visitStage` and `visitSink` (4) |
| `{pkg}/lib/src/topology/builder.dart` | 1, 3 | The record and its checks, `read`, `write` (1); `reduceInto`, `combine2` to `combine4`, `combineAll`, `merge` (3) |
| `{pkg}/lib/src/topology/handle.dart` | 1, 2, 3, 4 | The builder link (1); the single-input calls (2); `withLatestFrom` to `withLatestFrom3` (3); `_accept` (4) |
| `{pkg}/lib/src/topology/stages.dart` | 1, 3, 4 | Constructors that take the builder (1); `_apply` and `apply` (3); `_accept` (4) |
| `{pkg}/lib/src/topology/sinks.dart` | 4 | `_accept` |
| `{pkg}/test/recording_test.dart` | 1 | `planOf`, the builder form, reads, writes and references beyond the suite |
| `{pkg}/test/handle_stages_test.dart` | 2 | The single-input handle calls beyond the suite |
| `{pkg}/test/combining_stages_test.dart` | 3 | The multi-input calls, `reduceInto`, `apply` and G10 beyond the suite |
| `{pkg}/test/plan_visitors_test.dart` | 4 | The visitors' type arguments beyond the suite |
| `hsdd/verify/nidana.model.9.verification.md` | 5 | The verification doc |

---

### Task 1: planOf, the builder form, reads, writes and topology references

You are filling in the recording core of `lib/src/topology/` in `packages/nidana_dart_contracts`, a library of part files whose declarations nidana.model.4 landed with bodies that throw `UnimplementedError` (nidana.model D3, D4). Run every command from the repository root with `fvm dart`. Change no public declaration (Global Constraints, Interface). This task turns seven conformance cases green: G9 (2, by name), G11 (1), G13 (1), G15 (1), G17 (1) and G30 (1).

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topology/topology.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/plan.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/builder.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/handle.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/stages.dart`
- Create: `packages/nidana_dart_contracts/test/recording_test.dart`

**Interfaces:**
- Consumes: the declarations of `lib/src/topology/` (nidana.model.4); `Topic` equality (topic-model@v1 G7, nidana.model.8) and the sealed `MultiWriterTopic<T>` (G27).
- Produces, for Tasks 2 to 4 (exact names):
  - in `TopicStream<T>`: the constructor `TopicStream._(this._builder);` and the field `final TopologyBuilder _builder;`.
  - every stage class's private constructor takes the builder first, as `super.builder`, and keeps `: super._()`: `ReadStage._(super.builder, this.topic, this.dedup)`, `MapStage._(super.builder, this.input, this.transform)`, and so on for all eighteen, the other parameters unchanged; `CombineStage._(super.builder, this.inputs, this.combiner)` and `WithLatestFromStage._(super.builder, this.primary, this.latest, this.combiner)`, to which Task 3 appends `this._apply`. The sinks' constructors do not change.
  - in `TopologyBuilder`: `bool _open = true;`, `void _checkOpen()`, `List<H> _checkMade<H extends TopicStream<Object?>>(List<H> handles)` (returns an unmodifiable copy), `void _checkFirstSink(Topic<Object?> topic)`, `S _addStage<S extends TopicStream<Object?>>(S stage, List<TopicStream<Object?>> inputs)`, `void _addSink(PlanSink sink, TopicStream<Object?> input)` and `TopologyPlan _plan(String topologyId, Scope scope)`.
  - the bodies of `planOf`, `topology()`, `Topology.buildDefinition()`, `TopologyBuilder.read` and `TopologyBuilder.write`, and `TopologyRef`'s `==` and `hashCode`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/recording_test.dart` with exactly this content:

```dart
// topology-dsl@v2's recording core, beyond the cases of its recording suite,
// which the gate replays (hsdd/contract/fixture/topology-dsl/behavior/):
// planOf, the builder form, reads and writes with their misuse checks, and
// topology references.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

const StateTopic<int> count = StateTopic<int>(name: 'rec.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<int> out = EventTopic<int>(name: 'rec.out');
const ReplayTopic<int> log = ReplayTopic<int>(name: 'rec.log', bufferSize: 2);

Topology declared(void Function(TopologyBuilder b) body) =>
    topology('rec-core', Scope.page, body);

/// A class-form topology with an empty id, whose declare must never run.
final class Unnamed extends Topology {
  const Unnamed();

  @override
  String get topologyId => '';

  @override
  Scope get scope => Scope.page;

  @override
  void declare(TopologyBuilder b) =>
      throw UnsupportedError('declare ran for an empty topology id');
}

void main() {
  test('G9 planOf runs declare once per call against a fresh builder and '
      'carries the id and scope', () {
    final List<TopologyBuilder> builders = <TopologyBuilder>[];
    final Topology t = topology('rec-form', Scope.module, (TopologyBuilder b) {
      builders.add(b);
      b.write(out, b.read(taps));
    });
    expect(builders, isEmpty);
    final TopologyPlan first = planOf(t);
    final TopologyPlan second = planOf(t);
    expect(builders, hasLength(2));
    expect(identical(builders[0], builders[1]), isFalse);
    expect(first.topologyId, 'rec-form');
    expect(first.scope, Scope.module);
    expect(identical(first.stages.single, second.stages.single), isFalse);
  });

  test('G9 an empty declaration records an empty plan', () {
    final TopologyPlan plan = planOf(declared((TopologyBuilder b) {}));
    expect(plan.stages, isEmpty);
    expect(plan.sinks, isEmpty);
  });

  test('G11 a read and a write hold the topic, dedup and handle they were '
      'given', () {
    late TopicStream<int> read;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        read = b.read(count, dedup: Dedup.none);
        b.write(out, read);
      }),
    );
    final ReadStage<int> stage = plan.stages.single as ReadStage<int>;
    expect(identical(stage, read), isTrue);
    expect(identical(stage.topic, count), isTrue);
    expect(stage.dedup, Dedup.none);
    final WriteSink<int> sink = plan.sinks.single as WriteSink<int>;
    expect(identical(sink.topic, out), isTrue);
    expect(identical(sink.input, read), isTrue);
  });

  test('G13 a dedup argument on an event or replay read throws ArgumentError '
      'at the call and adds no stage', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        expect(() => b.read(taps, dedup: Dedup.none), throwsArgumentError);
        expect(() => b.read(log, dedup: Dedup.equality), throwsArgumentError);
        b.write(out, b.read(count, dedup: Dedup.equality));
      }),
    );
    expect(plan.stages, hasLength(1));
  });

  test('G14 a second sink on a state topic built apart throws ArgumentError '
      'at the call; another value type is another topic', () {
    final String name = <String>['rec.total'].single;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        b.write(StateTopic<int>(name: name, initial: 0), t);
        expect(
          () => b.write(
            StateTopic<int>(name: name, initial: 9, dedup: Dedup.none),
            t,
          ),
          throwsArgumentError,
        );
        b.write(StateTopic<num>(name: name, initial: 0), t);
      }),
    );
    expect(plan.sinks, hasLength(2));
  });

  test('G14 a handle of a declaration still running is another builder\'s', () {
    planOf(
      topology('rec-outer', Scope.page, (TopologyBuilder outer) {
        final TopicStream<int> mine = outer.read(taps);
        expect(
          () => planOf(
            topology(
              'rec-inner',
              Scope.page,
              (TopologyBuilder inner) => inner.write(out, mine),
            ),
          ),
          throwsArgumentError,
        );
        outer.write(out, mine);
      }),
    );
  });

  test('G15 a builder and its handles throw StateError once declare has '
      'returned, by throwing as well', () {
    late TopologyBuilder kept;
    late TopicStream<int> handle;
    expect(
      () => planOf(
        declared((TopologyBuilder b) {
          kept = b;
          handle = b.read(taps);
          throw const FormatException('declare failed');
        }),
      ),
      throwsFormatException,
    );
    expect(() => kept.read(taps), throwsStateError);
    expect(() => kept.write(out, handle), throwsStateError);
  });

  test('G15 an empty topology id fails before any declare runs', () {
    expect(() => planOf(const Unnamed()), throwsStateError);
    expect(() => const Unnamed().buildDefinition(), throwsStateError);
    expect(
      () => topology('', Scope.page, (TopologyBuilder b) {}),
      throwsArgumentError,
    );
  });

  test('G15 a read that reaches no sink fails planOf with StateError', () {
    expect(
      () => planOf(
        declared((TopologyBuilder b) {
          b.write(out, b.read(taps));
          b.read(count);
        }),
      ),
      throwsStateError,
    );
  });

  test('G17 topology references built apart are one set element and one '
      'map key', () {
    final String id = <String>['checkout-flow'].single;
    final Set<TopologyRef> refs = <TopologyRef>{
      TopologyRef(id),
      const TopologyRef('checkout-flow'),
      const TopologyRef('checkout-cart'),
    };
    expect(refs, hasLength(2));
    final Map<TopologyRef, int> owners = <TopologyRef, int>{TopologyRef(id): 1};
    owners[const TopologyRef('checkout-flow')] = 2;
    expect(owners, hasLength(1));
    expect(owners[TopologyRef(id)], 2);
  });
}
```

- [ ] **Step 2: Run it, the replay of G13, G15, G17 and G30, and G9's two cases, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/recording_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+0 -10: Some tests failed.`: all ten fail, six on `UnimplementedError`, the two `G15` tests that expect it on `Expected: throws <Instance of 'StateError'>` and the third on `Expected: throws <Instance of 'FormatException'>`, and `G17 ...` on `Expected: an object with length of <2>` (identity equality) (T1.2).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G13,G15,G17,G30; echo "exit: $?"`
Expected: `exit: 1`; 16 `PASS structure` lines, then `FAIL behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: cases (0 passed, 7 failed, 0 skipped under dart test, restricted to topology-dsl G13, G15, G17, G30)` with seven `failed-case` names, and `17 fixtures: 16 passed, 1 failed, 0 pending` (T1.2).
Run: `fvm dart test hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart --name '^G9 (planOf runs|the builder form)'; echo "exit: $?"`
Expected: `exit: 1` and `+0 -2: Some tests failed.`, both on `UnimplementedError` (T1.2).

- [ ] **Step 3: Implement the recording core**

`topology.dart`: `buildDefinition()` returns `planOf(this).definition`. `topology()` throws `ArgumentError` for an empty id and returns a private final subclass that runs its body on each `declare` call. `TopologyRef` compares and hashes by `id`. The new and changed members, from `buildDefinition` to the end of `TopologyRef`:

```dart
  /// The IR (Spec §6.5): planOf(this).definition.
  @nonVirtual
  TopologyDefinition buildDefinition() => planOf(this).definition;
}

/// The builder shorthand (Spec §6.1). Throws ArgumentError for an empty
/// [topologyId]; [declare] runs on each planOf call.
Topology topology(
  String topologyId,
  Scope scope,
  void Function(TopologyBuilder b) declare,
) {
  if (topologyId.isEmpty) {
    throw ArgumentError.value(topologyId, 'topologyId', 'must not be empty');
  }
  return _BuilderForm(topologyId, scope, declare);
}

/// The topology `topology()` returns: its body runs on each planOf call.
final class _BuilderForm extends Topology {
  const _BuilderForm(this.topologyId, this.scope, this._declare);

  @override
  final String topologyId;

  @override
  final Scope scope;

  final void Function(TopologyBuilder b) _declare;

  @override
  void declare(TopologyBuilder b) => _declare(b);
}

/// A typed, module-local topology identifier (Spec §4.6). Equal by id.
@immutable
final class TopologyRef {
  const TopologyRef(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is TopologyRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
```

`plan.dart`: `planOf` checks the id before `declare` runs, closes the builder in a `finally` so that a handle kept from a declaration that threw records nothing more either (Review Focus 3), and asks the builder for its plan only when `declare` returned normally:

```dart
TopologyPlan planOf(Topology topology) {
  final String topologyId = topology.topologyId;
  if (topologyId.isEmpty) {
    throw StateError(
      'planOf: ${topology.runtimeType} has an empty topologyId (Spec §4.6).',
    );
  }
  final TopologyBuilder builder = TopologyBuilder._();
  try {
    topology.declare(builder);
  } finally {
    builder._open = false;
  }
  return builder._plan(topologyId, topology.scope);
}
```

`handle.dart`: the builder link, which replaces `TopicStream._();` (every method stays `=> throw UnimplementedError();` until Tasks 2 and 3):

```dart
  TopicStream._(this._builder);

  // The builder whose declaration made this handle, which records every
  // stage derived from it (G14, G15).
  final TopologyBuilder _builder;
```

`stages.dart`: each of the eighteen private constructors takes `super.builder` first (Interfaces). `CombineStage` and `WithLatestFromStage` keep `apply` throwing until Task 3; the formatter wraps the latter's constructor:

```dart
  WithLatestFromStage._(super.builder, this.primary, this.latest, this.combiner)
    : super._();
```

`builder.dart`: the record and its checks, at the top of `TopologyBuilder` after its constructor. `_consumed` is an identity set, so it never depends on a stage's equality (G30 keeps `Object`'s anyway); `_written` is a plain set, so state topics compare by topic equality (Review Focus 2). A stage reaches a sink exactly when a later stage or a sink takes it as an input, because a stage's inputs precede it: a chain of consumers only moves forward in creation order and ends at a stage that a sink consumes. `_plan` therefore needs no graph walk:

```dart
  // What the declaration recorded so far, in call order.
  final List<TopicStream<Object?>> _stages = <TopicStream<Object?>>[];
  final List<PlanSink> _sinks = <PlanSink>[];

  // The stages a later stage or a sink takes as an input.
  final Set<TopicStream<Object?>> _consumed =
      Set<TopicStream<Object?>>.identity();

  // The state topics a sink already writes, compared by topic equality.
  final Set<StateTopic<Object?>> _written = <StateTopic<Object?>>{};

  // False once the declaration that made this builder has returned.
  bool _open = true;
```

```dart
  // Throws StateError once the declaration that made this builder has
  // returned (G15).
  void _checkOpen() {
    if (!_open) {
      throw StateError(
        'The declaration that made this builder has returned: its builder '
        'and handles record nothing more.',
      );
    }
  }

  // Throws ArgumentError unless this builder made every one of [handles]
  // (G14); returns them as an unmodifiable copy.
  List<H> _checkMade<H extends TopicStream<Object?>>(List<H> handles) {
    for (final H handle in handles) {
      if (!identical(handle._builder, this)) {
        throw ArgumentError.value(
          handle,
          'handle',
          'was made by another builder: another declaration, or another '
              'planOf call of this one',
        );
      }
    }
    return List<H>.unmodifiable(handles);
  }

  // Throws ArgumentError when a sink already writes [topic], a state topic
  // (G14); event and replay topics take any number of sinks.
  void _checkFirstSink(Topic<Object?> topic) {
    if (topic is StateTopic<Object?> && _written.contains(topic)) {
      throw ArgumentError.value(
        topic.name,
        'topic',
        'already has a sink in this topology; a state topic takes one',
      );
    }
  }

  // Appends [stage] and marks [inputs] consumed. Every check has passed.
  S _addStage<S extends TopicStream<Object?>>(
    S stage,
    List<TopicStream<Object?>> inputs,
  ) {
    _stages.add(stage);
    _consumed.addAll(inputs);
    return stage;
  }

  // Appends [sink], marks [input] consumed and claims a state topic. Every
  // check has passed.
  void _addSink(PlanSink sink, TopicStream<Object?> input) {
    _sinks.add(sink);
    _consumed.add(input);
    final Topic<Object?> topic = sink.topic;
    if (topic is StateTopic<Object?>) {
      _written.add(topic);
    }
  }

  // The plan of the declaration that has returned. Throws StateError when a
  // stage reaches no sink (G15): every stage reaches one exactly when each is
  // the input of a later stage or of a sink, because a stage's inputs precede
  // it.
  TopologyPlan _plan(String topologyId, Scope scope) {
    for (int i = 0; i < _stages.length; i++) {
      if (!_consumed.contains(_stages[i])) {
        throw StateError(
          'Topology $topologyId: stage ${i + 1} of ${_stages.length}, a '
          '${_stages[i].runtimeType}, reaches no sink. Write it, or remove '
          'it.',
        );
      }
    }
    return TopologyPlan._(
      topologyId,
      scope,
      List<TopicStream<Object?>>.unmodifiable(_stages),
      List<PlanSink>.unmodifiable(_sinks),
    );
  }
```

`read` and `write`, the first calls through the record (the other builder methods stay `=> throw UnimplementedError();` until Task 3). A dedup override on a `MultiWriterTopic`, which is exactly an event or a replay topic (topic-model@v1 G27), is the misuse of G13:

```dart
  TopicStream<T> read<T>(Topic<T> topic, {Dedup? dedup}) {
    _checkOpen();
    if (dedup != null && topic is MultiWriterTopic<T>) {
      throw ArgumentError.value(
        dedup,
        'dedup',
        'applies to a state topic read only, and ${topic.name} is an '
            '${topic.variant.name} topic',
      );
    }
    return _addStage(
      ReadStage<T>._(this, topic, dedup),
      const <TopicStream<Object?>>[],
    );
  }

  /// Writes every value of [stream] to [topic]: one write chain (Errors and
  /// lineage). The stream's value type is the topic's or a subtype of it (G3).
  void write<T, S extends T>(Topic<T> topic, TopicStream<S> stream) {
    _checkOpen();
    _checkMade(<TopicStream<Object?>>[stream]);
    _checkFirstSink(topic);
    _addSink(WriteSink<T>._(topic, stream), stream);
  }
```

- [ ] **Step 4: Run the tests, the analyzer and the same replays**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)` from the formatter, `+105: All tests passed!` (95 before this task, 10 added; more if you added tests), `No issues found!` (T1.4).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G13,G15,G17,G30; echo "exit: $?"`
Expected: `exit: 1` and `cases (4 passed, 3 failed, ...)`; the three left are `G13 a read records its dedup argument, null when none is given` (Task 3), `G15 planOf throws StateError when a stage reaches no sink` (Task 2) and `G15 a builder or a handle used after declare returned throws StateError` (Task 3) (T1.4).
Run: `fvm dart test hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart --name '^G9 (planOf runs|the builder form)'; echo "exit: $?"`
Expected: `+2: All tests passed!` and `exit: 0` (T1.4).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G11; echo "exit: $?"`
Expected: `exit: 1` and `cases (1 passed, 4 failed, ...)`: `G11 the stage and sink lists of a plan are unmodifiable` passes; the other four are Tasks 3 and 4's (T1.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topology/topology.dart packages/nidana_dart_contracts/lib/src/topology/plan.dart packages/nidana_dart_contracts/lib/src/topology/builder.dart packages/nidana_dart_contracts/lib/src/topology/handle.dart packages/nidana_dart_contracts/lib/src/topology/stages.dart packages/nidana_dart_contracts/test/recording_test.dart
git commit -m "feat(dart_contracts): record reads and writes into a plan with planOf" -m "<the co-author trailer your harness gives>"
```

### Task 2: The single-input handle calls

You are filling in fourteen methods of `TopicStream<T>` in `lib/src/topology/handle.dart`, the handle calls that take no other handle. Run every command from the repository root with `fvm dart`. This task turns two conformance cases green: G14 (1) and G15 (1).

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topology/handle.dart`
- Create: `packages/nidana_dart_contracts/test/handle_stages_test.dart`

**Interfaces:**
- Consumes: Task 1's `_builder`, `_checkOpen()`, `_addStage(...)` and the stage constructors that take the builder first.
- Produces: the bodies of `map`, `filter`, `switchMap`, `scan`, `pairwise`, `distinctUntilChanged`, `debounce`, `throttle`, `delay`, `sample`, `buffer`, `timeout`, `catchError` and `rawEngine`; in `TopicStream<T>`, `S _derive<S extends TopicStream<Object?>>(S stage)`, which records a stage whose one input is the receiver; and in `handle.dart`, the library function `Duration _checkNotNegative(Duration duration)`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/handle_stages_test.dart` with exactly this content:

```dart
// topology-dsl@v2's single-input handle calls, beyond the cases of its
// recording suite: each adds one stage holding the receiver and the very
// arguments it was given, a negative duration fails at the call, and a
// closed declaration's handle records nothing.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

const EventTopic<int> taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<Object?> any = EventTopic<Object?>(name: 'rec.any');

/// One closure of each function type a single-input handle call takes, held
/// in lists so that each test reads the very object it passed.
final List<String Function(int)> transforms = <String Function(int)>[
  (int v) => '$v',
];
final List<bool Function(int)> tests = <bool Function(int)>[(int v) => v > 0];
final List<Stream<String> Function(int)> factories =
    <Stream<String> Function(int)>[(int v) => Stream<String>.value('$v')];
final List<RetryPolicy> retries = <RetryPolicy>[
  (Object error, int attempt) => null,
];
final List<List<int> Function(List<int>, int)> accumulators =
    <List<int> Function(List<int>, int)>[
      (List<int> acc, int v) => <int>[...acc, v],
    ];
final List<int Function(Object, StackTrace)> recovers =
    <int Function(Object, StackTrace)>[(Object e, StackTrace s) => -1];
final List<RawOperator<int, String>> operators = <RawOperator<int, String>>[
  (Stream<PipelineValue<int>> values, String Function() fresh) =>
      const Stream<PipelineValue<String>>.empty(),
];

/// Durations built at run time, so that only the passed object is identical.
final List<Duration> durations = <Duration>[
  for (int i = 1; i <= 6; i++) Duration(milliseconds: <int>[i].single),
];

Topology declared(void Function(TopologyBuilder b) body) =>
    topology('rec-handle', Scope.page, body);

void main() {
  test('G11 each handle call adds one stage of its class holding the receiver '
      'and the arguments it was given', () {
    late TopicStream<int> t;
    final List<TopicStream<Object?>> made = <TopicStream<Object?>>[];
    final List<int> initial = <int>[];
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        t = b.read(taps);
        made.addAll(<TopicStream<Object?>>[
          t.map<String>(transforms[0]),
          t.filter(tests[0]),
          t.switchMap<String>(factories[0]),
          t.switchMap<String>(factories[0], retry: retries[0]),
          t.scan<List<int>>(initial, accumulators[0]),
          t.pairwise(),
          t.distinctUntilChanged(),
          t.debounce(durations[0]),
          t.throttle(durations[1]),
          t.delay(durations[2]),
          t.sample(durations[3]),
          t.buffer(durations[4]),
          t.timeout(durations[5]),
          t.catchError(recovers[0]),
          t.rawEngine<String>(operators[0]),
        ]);
        for (final TopicStream<Object?> s in made) {
          b.write(any, s);
        }
      }),
    );
    expect(plan.stages, hasLength(16));
    for (int i = 0; i < made.length; i++) {
      expect(identical(plan.stages[i + 1], made[i]), isTrue, reason: '$i');
    }
    final MapStage<int, String> map = made[0] as MapStage<int, String>;
    expect(identical(map.input, t), isTrue);
    expect(identical(map.transform, transforms[0]), isTrue);
    final FilterStage<int> filter = made[1] as FilterStage<int>;
    expect(identical(filter.input, t), isTrue);
    expect(identical(filter.test, tests[0]), isTrue);
    final SwitchMapStage<int, String> plain =
        made[2] as SwitchMapStage<int, String>;
    expect(identical(plain.toStream, factories[0]), isTrue);
    expect(plain.retry, isNull);
    final SwitchMapStage<int, String> retried =
        made[3] as SwitchMapStage<int, String>;
    expect(identical(retried.retry, retries[0]), isTrue);
    final ScanStage<int, List<int>> scan = made[4] as ScanStage<int, List<int>>;
    expect(identical(scan.initial, initial), isTrue);
    expect(identical(scan.accumulator, accumulators[0]), isTrue);
    expect(identical((made[5] as PairwiseStage<int>).input, t), isTrue);
    expect(
      identical((made[6] as DistinctUntilChangedStage<int>).input, t),
      isTrue,
    );
    final List<Duration> held = <Duration>[
      (made[7] as DebounceStage<int>).duration,
      (made[8] as ThrottleStage<int>).duration,
      (made[9] as DelayStage<int>).duration,
      (made[10] as SampleStage<int>).duration,
      (made[11] as BufferStage<int>).duration,
      (made[12] as TimeoutStage<int>).duration,
    ];
    for (int i = 0; i < held.length; i++) {
      expect(identical(held[i], durations[i]), isTrue, reason: '$i');
    }
    expect(
      identical((made[13] as CatchErrorStage<int>).recover, recovers[0]),
      isTrue,
    );
    final RawEngineStage<int, String> raw =
        made[14] as RawEngineStage<int, String>;
    expect(identical(raw.input, t), isTrue);
    expect(identical(raw.operator, operators[0]), isTrue);
  });

  test('G14 a negative duration throws ArgumentError at the call and adds no '
      'stage; a zero duration is accepted', () {
    const Duration negative = Duration(microseconds: -1);
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        expect(() => t.debounce(negative), throwsArgumentError);
        expect(() => t.throttle(negative), throwsArgumentError);
        expect(() => t.delay(negative), throwsArgumentError);
        expect(() => t.sample(negative), throwsArgumentError);
        expect(() => t.buffer(negative), throwsArgumentError);
        expect(() => t.timeout(negative), throwsArgumentError);
        b.write(taps, t.throttle(Duration.zero));
      }),
    );
    expect(plan.stages, hasLength(2));
    expect((plan.stages[1] as ThrottleStage<int>).duration, Duration.zero);
  });

  test('G15 every single-input handle call throws StateError once its '
      'declaration has returned', () {
    late TopicStream<int> kept;
    planOf(declared((TopologyBuilder b) => b.write(taps, kept = b.read(taps))));
    final List<Object? Function()> calls = <Object? Function()>[
      () => kept.map(transforms[0]),
      () => kept.filter(tests[0]),
      () => kept.switchMap(factories[0]),
      () => kept.scan(0, (int acc, int v) => acc),
      () => kept.pairwise(),
      () => kept.distinctUntilChanged(),
      () => kept.debounce(Duration.zero),
      () => kept.throttle(Duration.zero),
      () => kept.delay(Duration.zero),
      () => kept.sample(Duration.zero),
      () => kept.buffer(Duration.zero),
      () => kept.timeout(Duration.zero),
      () => kept.catchError(recovers[0]),
      () => kept.rawEngine(operators[0]),
    ];
    for (int i = 0; i < calls.length; i++) {
      expect(calls[i], throwsStateError, reason: '$i');
    }
  });

  test('G15 a closed handle given a negative duration throws StateError', () {
    late TopicStream<int> kept;
    planOf(declared((TopologyBuilder b) => b.write(taps, kept = b.read(taps))));
    expect(
      () => kept.debounce(const Duration(microseconds: -1)),
      throwsStateError,
    );
  });

  test('G15 a handle call whose stage reaches no sink fails planOf with '
      'StateError', () {
    expect(
      () => planOf(
        declared((TopologyBuilder b) {
          final TopicStream<int> t = b.read(taps);
          b.write(taps, t);
          t.pairwise().map((({int previous, int current}) p) => p.current);
        }),
      ),
      throwsStateError,
    );
  });
}
```

- [ ] **Step 2: Run it and the replay of G14 and G15, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/handle_stages_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+0 -5: Some tests failed.`: one test on `UnimplementedError`, one on `Expected: throws <Instance of 'ArgumentError'>` and three on `Expected: throws <Instance of 'StateError'>` (T2.2).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G14,G15; echo "exit: $?"`
Expected: `exit: 1` and `cases (1 passed, 6 failed, ...)`: only Task 1's empty-id case passes (T2.2).

- [ ] **Step 3: Implement the fourteen calls**

Each method checks its builder first, then its argument, then records through `_derive`: `map` and `debounce` show the two shapes, and `_derive` and `_checkNotNegative` follow the class (the function after its closing brace):

```dart
  TopicStream<R> map<R>(R Function(T value) transform) {
    _builder._checkOpen();
    return _derive(MapStage<T, R>._(_builder, this, transform));
  }
```

```dart
  TopicStream<T> debounce(Duration duration) {
    _builder._checkOpen();
    return _derive(
      DebounceStage<T>._(_builder, this, _checkNotNegative(duration)),
    );
  }
```

```dart
  // Records [stage], whose one input is this handle.
  S _derive<S extends TopicStream<Object?>>(S stage) =>
      _builder._addStage(stage, <TopicStream<Object?>>[this]);
}

// Returns [duration], or throws ArgumentError when it is negative (G14); a
// zero duration is accepted.
Duration _checkNotNegative(Duration duration) {
  if (duration.isNegative) {
    throw ArgumentError.value(duration, 'duration', 'must not be negative');
  }
  return duration;
}
```

The other twelve take the same shape, each building its class with the receiver as `input` and its own arguments in the order the class declares its fields: `filter` builds `FilterStage<T>._(_builder, this, test)`; `switchMap` builds `SwitchMapStage<T, R>._(_builder, this, toStream, retry)`; `scan` builds `ScanStage<T, S>._(_builder, this, initial, accumulator)`; `pairwise` builds `PairwiseStage<T>._(_builder, this)`; `distinctUntilChanged` builds `DistinctUntilChangedStage<T>._(_builder, this)`; `throttle`, `delay`, `sample`, `buffer` and `timeout` build `ThrottleStage<T>`, `DelayStage<T>`, `SampleStage<T>`, `BufferStage<T>` and `TimeoutStage<T>` like `debounce`, with `_checkNotNegative(duration)`; `catchError` builds `CatchErrorStage<T>._(_builder, this, recover)`; `rawEngine` builds `RawEngineStage<T, R>._(_builder, this, operator)`. The three `withLatestFrom` methods stay `=> throw UnimplementedError();` until Task 3.

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)`, `+110: All tests passed!`, `No issues found!` (T2.4).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G14,G15; echo "exit: $?"`
Expected: `exit: 1` and `cases (3 passed, 4 failed, ...)`; the four left are Task 3's: `G14 a handle made by another declaration ...`, `G14 a second sink on one StateTopic ...` (its `reduceInto` half), `G14 an empty input list ...` and `G15 a builder or a handle used after declare returned ...` (T2.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topology/handle.dart packages/nidana_dart_contracts/test/handle_stages_test.dart
git commit -m "feat(dart_contracts): record the single-input handle calls" -m "<the co-author trailer your harness gives>"
```

### Task 3: The multi-input calls, reduceInto and apply

You are filling in the builder calls that take several handles or fold into a state topic, the three `withLatestFrom` handle calls, and `apply` of the two stage classes that hold a combiner. Run every command from the repository root with `fvm dart`. This task turns seven conformance cases green: G11 (2), G13 (1), G14 (3) and G15 (1); after it the two G10 cases still fail, as the known gap says.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topology/builder.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/handle.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/stages.dart`
- Create: `packages/nidana_dart_contracts/test/combining_stages_test.dart`

**Interfaces:**
- Consumes: Task 1's record and checks; Task 2's handle calls (the G10 test chains them).
- Produces: the bodies of `reduceInto`, `combine2`, `combine3`, `combine4`, `combineAll` and `merge` in `TopologyBuilder`, with the private `void _checkNotEmpty(List<TopicStream<Object?>> inputs)`; the bodies of `withLatestFrom`, `withLatestFrom2` and `withLatestFrom3` in `TopicStream<T>`; in `CombineStage<R>`, the constructor `CombineStage._(super.builder, this.inputs, this.combiner, this._apply)` and the field `final R Function(List<Object?> values) _apply;`; in `WithLatestFromStage<T, R>`, the constructor with `this._apply` last and the field `final R Function(T value, List<Object?> latest) _apply;`; both `apply` bodies.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/combining_stages_test.dart` with exactly this content:

```dart
// topology-dsl@v2's multi-input calls and reduceInto, beyond the cases of
// its recording suite: inputs held in order as unmodifiable copies, apply at
// the declaration's own types, the misuse checks of G14 and G15 at the call
// that commits them, and G10: recording every combinator calls nothing and
// schedules nothing.
import 'dart:async';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

const StateTopic<int> count = StateTopic<int>(name: 'rec.count', initial: 0);
const StateTopic<String> label = StateTopic<String>(
  name: 'rec.label',
  initial: '',
);
const EventTopic<int> taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<String> words = EventTopic<String>(name: 'rec.words');
const EventTopic<Object?> any = EventTopic<Object?>(name: 'rec.any');

/// One combiner of each arity, held in lists so that each test reads the
/// very object it passed.
final List<String Function(int, String)> pairs = <String Function(int, String)>[
  (int a, String b) => '$a$b',
];
final List<String Function(int, String, bool)> triples =
    <String Function(int, String, bool)>[(int a, String b, bool c) => '$a$b$c'];
final List<String Function(List<int>)> joins = <String Function(List<int>)>[
  (List<int> values) => values.join(','),
];

Topology declared(void Function(TopologyBuilder b) body) =>
    topology('rec-combining', Scope.page, body);

/// How many timers, periodic timers and microtasks [body] makes.
int scheduledBy(void Function() body) {
  int scheduled = 0;
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, f) {
        scheduled++;
        return parent.createTimer(zone, duration, f);
      },
      createPeriodicTimer: (self, parent, zone, period, f) {
        scheduled++;
        return parent.createPeriodicTimer(zone, period, f);
      },
      scheduleMicrotask: (self, parent, zone, f) {
        scheduled++;
        parent.scheduleMicrotask(zone, f);
      },
    ),
  );
  return scheduled;
}

Never _called(String what) => throw StateError('recording called $what');

void main() {
  test('G11 combine, withLatestFrom and merge stages hold their inputs in '
      'order and their combiner', () {
    late TopicStream<int> t;
    late TopicStream<String> w;
    late TopicStream<bool> f;
    late TopicStream<String> c2;
    late TopicStream<String> w2;
    late TopicStream<int> m;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        t = b.read(taps);
        w = b.read(words);
        f = t.map((int v) => v > 0);
        c2 = b.combine2(t, w, pairs[0]);
        w2 = t.withLatestFrom2(w, f, triples[0]);
        m = b.merge(<TopicStream<int>>[t, t]);
        b.write(words, b.merge(<TopicStream<String>>[c2, w2]));
        b.write(taps, m);
      }),
    );
    expect(plan.stages, hasLength(7));
    final CombineStage<String> combine = c2 as CombineStage<String>;
    expect(combine.inputs, hasLength(2));
    expect(identical(combine.inputs[0], t), isTrue);
    expect(identical(combine.inputs[1], w), isTrue);
    expect(identical(combine.combiner, pairs[0]), isTrue);
    final WithLatestFromStage<int, String> latest =
        w2 as WithLatestFromStage<int, String>;
    expect(identical(latest.primary, t), isTrue);
    expect(identical(latest.latest[0], w), isTrue);
    expect(identical(latest.latest[1], f), isTrue);
    expect(identical(latest.combiner, triples[0]), isTrue);
    final MergeStage<int> merge = m as MergeStage<int>;
    expect(identical(merge.inputs[0], t), isTrue);
    expect(identical(merge.inputs[1], t), isTrue);
    expect(() => combine.inputs.add(t), throwsUnsupportedError);
    expect(() => latest.latest.clear(), throwsUnsupportedError);
    expect(() => merge.inputs.add(t), throwsUnsupportedError);
  });

  test(
    'G11 combineAll and merge copy the input list the declaration passed',
    () {
      late TopicStream<int> first;
      late TopicStream<String> all;
      late TopicStream<int> merged;
      planOf(
        declared((TopologyBuilder b) {
          first = b.read(taps);
          final List<TopicStream<int>> inputs = <TopicStream<int>>[first];
          all = b.combineAll(inputs, joins[0]);
          merged = b.merge(inputs);
          inputs.add(first);
          b.write(words, all);
          b.write(taps, merged);
        }),
      );
      final CombineStage<String> combine = all as CombineStage<String>;
      expect(combine.inputs, hasLength(1));
      expect(identical(combine.inputs.single, first), isTrue);
      expect(identical(combine.combiner, joins[0]), isTrue);
      expect((merged as MergeStage<int>).inputs, hasLength(1));
    },
  );

  test('G11 apply calls the combiner at its own types with the values in '
      'input order', () {
    late TopicStream<String> c2;
    late TopicStream<String> all;
    late TopicStream<String> w2;
    List<int>? seen;
    planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        c2 = b.combine2(t, w, pairs[0]);
        all = b.combineAll(<TopicStream<int>>[t, t, t], (List<int> values) {
          seen = values;
          return values.join(',');
        });
        w2 = t.withLatestFrom2(w, t.map((int v) => v.isEven), triples[0]);
        b.write(words, b.merge(<TopicStream<String>>[c2, all, w2]));
      }),
    );
    expect((c2 as CombineStage<String>).apply(<Object?>[1, 'a']), '1a');
    expect((all as CombineStage<String>).apply(<Object?>[3, 1, 2]), '3,1,2');
    expect(seen, isA<List<int>>());
    expect(() => seen!.add(4), throwsUnsupportedError);
    expect(
      (w2 as WithLatestFromStage<int, String>).apply(7, <Object?>['b', true]),
      '7btrue',
    );
  });

  test('G11 apply throws ArgumentError for a value list whose length is not '
      'the number of inputs, and TypeError for a value of another type', () {
    late TopicStream<String> c2;
    late TopicStream<String> all;
    late TopicStream<String> w1;
    planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        c2 = b.combine2(t, w, pairs[0]);
        all = b.combineAll(<TopicStream<int>>[t, t], joins[0]);
        w1 = t.withLatestFrom(w, (int v, String s) => '$v$s');
        b.write(words, b.merge(<TopicStream<String>>[c2, all, w1]));
      }),
    );
    final CombineStage<String> combine = c2 as CombineStage<String>;
    expect(() => combine.apply(<Object?>[1]), throwsArgumentError);
    expect(() => combine.apply(<Object?>[1, 'a', 2]), throwsArgumentError);
    expect(
      () => (all as CombineStage<String>).apply(<Object?>[1, 2, 3]),
      throwsArgumentError,
    );
    expect(
      () => (w1 as WithLatestFromStage<int, String>).apply(1, <Object?>[
        'a',
        'b',
      ]),
      throwsArgumentError,
    );
    expect(() => combine.apply(<Object?>['a', 1]), throwsA(isA<TypeError>()));
  });

  test('G14 an empty input list throws ArgumentError at the call and adds no '
      'stage', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        expect(
          () => b.combineAll(<TopicStream<int>>[], joins[0]),
          throwsArgumentError,
        );
        expect(() => b.merge(<TopicStream<int>>[]), throwsArgumentError);
        b.write(taps, b.read(taps));
      }),
    );
    expect(plan.stages, hasLength(1));
  });

  test('G14 a handle another declaration made throws ArgumentError in any '
      'input position, and the call adds no stage', () {
    late TopicStream<int> foreign;
    planOf(
      declared((TopologyBuilder b) => b.write(taps, foreign = b.read(taps))),
    );
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        expect(
          () => b.combine3(t, w, foreign, (int a, String b, int c) => a),
          throwsArgumentError,
        );
        expect(
          () => b.combine4(t, t, t, foreign, (int a, int b, int c, int d) => a),
          throwsArgumentError,
        );
        expect(
          () => b.combineAll(<TopicStream<int>>[t, foreign], joins[0]),
          throwsArgumentError,
        );
        expect(
          () => b.merge(<TopicStream<int>>[t, t, foreign]),
          throwsArgumentError,
        );
        expect(
          () => t.withLatestFrom3(
            w,
            t,
            foreign,
            (int v, String a, int b, int c) => v,
          ),
          throwsArgumentError,
        );
        expect(
          () => b.reduceInto(label, foreign, (String s, int e) => s),
          throwsArgumentError,
        );
        b.write(taps, t);
        b.reduceInto(label, w, (String s, String e) => e);
      }),
    );
    expect(plan.stages, hasLength(2));
    expect(plan.sinks, hasLength(2));
  });

  test('G14 a write and a reduceInto on one state topic throw ArgumentError '
      'at the second call, in either order', () {
    for (final bool reduceFirst in <bool>[true, false]) {
      final TopologyPlan plan = planOf(
        declared((TopologyBuilder b) {
          final TopicStream<int> t = b.read(taps);
          void reduce() => b.reduceInto(count, t, (int s, int e) => s + e);
          void write() => b.write(count, t);
          (reduceFirst ? reduce : write)();
          expect(reduceFirst ? write : reduce, throwsArgumentError);
          expect(reduceFirst ? reduce : write, throwsArgumentError);
        }),
      );
      expect(plan.sinks, hasLength(1), reason: 'reduceFirst: $reduceFirst');
    }
  });

  test('G15 every multi-input call and reduceInto throws StateError once its '
      'declaration has returned', () {
    late TopologyBuilder closed;
    late TopicStream<int> kept;
    planOf(
      declared((TopologyBuilder b) {
        closed = b;
        b.write(taps, kept = b.read(taps));
      }),
    );
    final List<Object? Function()> calls = <Object? Function()>[
      () => closed.combine2(kept, kept, (int a, int b) => a),
      () => closed.combine3(kept, kept, kept, (int a, int b, int c) => a),
      () => closed.combine4(
        kept,
        kept,
        kept,
        kept,
        (int a, int b, int c, int d) => a,
      ),
      () => closed.combineAll(<TopicStream<int>>[kept], joins[0]),
      () => closed.combineAll(<TopicStream<int>>[], joins[0]),
      () => closed.merge(<TopicStream<int>>[kept]),
      () => closed.reduceInto(count, kept, (int s, int e) => s),
      () => kept.withLatestFrom(kept, (int a, int b) => a),
      () => kept.withLatestFrom2(kept, kept, (int a, int b, int c) => a),
      () => kept.withLatestFrom3(
        kept,
        kept,
        kept,
        (int a, int b, int c, int d) => a,
      ),
    ];
    for (int i = 0; i < calls.length; i++) {
      expect(calls[i], throwsStateError, reason: '$i');
    }
  });

  test('G10 recording every combinator calls none of its functions, nor a '
      'computed initial value, and creates no timer or microtask', () {
    final StateTopic<int> computed = StateTopic<int>.computed(
      name: 'rec.computed',
      initial: () => _called('a computed initial value'),
    );
    Topology every() => declared((TopologyBuilder b) {
      final TopicStream<int> t = b.read(taps);
      final TopicStream<int> c = b.read(computed, dedup: Dedup.none);
      final TopicStream<int> c2 = b.combine2(
        t,
        c,
        (int a, int b) => _called('a combiner'),
      );
      final TopicStream<int> c3 = b.combine3(
        t,
        c,
        c2,
        (int a, int b, int d) => _called('a combiner'),
      );
      final TopicStream<int> c4 = b.combine4(
        t,
        c,
        c2,
        c3,
        (int a, int b, int d, int e) => _called('a combiner'),
      );
      final TopicStream<int> all = b.combineAll(<TopicStream<int>>[
        c4,
        c3,
      ], (List<int> v) => _called('a combiner'));
      final TopicStream<int> w = all
          .withLatestFrom<int, int>(t, (int v, int a) => _called('a combiner'))
          .withLatestFrom2<int, int, int>(
            t,
            c,
            (int v, int a, int b) => _called('a combiner'),
          )
          .withLatestFrom3<int, int, int, int>(
            t,
            c,
            c2,
            (int v, int a, int b, int d) => _called('a combiner'),
          );
      final TopicStream<int> s = b
          .merge(<TopicStream<int>>[w, t])
          .map<int>((int v) => _called('a transformer'))
          .filter((int v) => _called('a predicate'))
          .switchMap<int>(
            (int v) => _called('a stream factory'),
            retry: (Object e, int n) => _called('a retry policy'),
          )
          .scan<int>(0, (int acc, int v) => _called('an accumulator'))
          .distinctUntilChanged()
          .debounce(const Duration(milliseconds: 1))
          .throttle(const Duration(milliseconds: 1))
          .delay(const Duration(milliseconds: 1))
          .sample(const Duration(milliseconds: 1))
          .timeout(const Duration(milliseconds: 1))
          .catchError(
            (Object e, StackTrace st) => _called('a recover function'),
          )
          .rawEngine<int>(
            (Stream<PipelineValue<int>> v, String Function() fresh) =>
                _called('a raw operator'),
          );
      b.write(any, s.pairwise());
      b.write(any, s.buffer(const Duration(milliseconds: 1)));
      b.reduceInto(count, s, (int st, int e) => _called('a reducer'));
      b.reduceInto(computed, t, (int st, int e) => _called('a reducer'));
    });
    // The counter counts: a timer and a microtask made in its zone.
    expect(
      scheduledBy(() {
        Timer(Duration.zero, () {}).cancel();
        scheduleMicrotask(() {});
      }),
      2,
    );
    late TopologyPlan plan;
    expect(scheduledBy(() => plan = planOf(every())), 0);
    expect(plan.stages, hasLength(24));
    expect(plan.sinks, hasLength(4));
  });
}
```

- [ ] **Step 2: Run it and the replay of G10, G11, G13, G14 and G15, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/combining_stages_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+0 -9: Some tests failed.`: six on `UnimplementedError`, two on `Expected: throws <Instance of 'ArgumentError'>` and one on `Expected: throws <Instance of 'StateError'>` (T3.2).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G10,G11,G13,G14,G15; echo "exit: $?"`
Expected: `exit: 1` and `cases (5 passed, 11 failed, ...)` (T3.2).

- [ ] **Step 3: Implement the calls and `apply`**

`builder.dart`: each call checks the builder, then its inputs (`_checkNotEmpty` before `_checkMade` for a list), then its sink rule, and records last. A combine call builds its stage's `_apply` closure from its own type arguments, so `apply` calls the combiner with each value cast to its input's type, and `combineAll` hands its combiner a fresh unmodifiable `List<T>` (F C1 to C4; Review Focus 4):

```dart
  void reduceInto<S, E>(
    StateTopic<S> topic,
    TopicStream<E> events,
    S Function(S state, E event) reducer,
  ) {
    _checkOpen();
    _checkMade(<TopicStream<Object?>>[events]);
    _checkFirstSink(topic);
    _addSink(ReduceIntoSink<S, E>._(topic, events, reducer), events);
  }
```

```dart
  TopicStream<R> combine2<A, B, R>(
    TopicStream<A> a,
    TopicStream<B> b,
    R Function(A a, B b) combiner,
  ) {
    _checkOpen();
    final List<TopicStream<Object?>> inputs = _checkMade(<TopicStream<Object?>>[
      a,
      b,
    ]);
    return _addStage(
      CombineStage<R>._(
        this,
        inputs,
        combiner,
        (List<Object?> values) => combiner(values[0] as A, values[1] as B),
      ),
      inputs,
    );
  }
```

`combine3` and `combine4` are `combine2` with three and four inputs: `values[2] as C`, then `values[3] as D`, in the closure, which the formatter puts one argument per line for `combine4`.

`combineAll` and `merge`, the two calls that take a list:

```dart
  TopicStream<R> combineAll<T, R>(
    List<TopicStream<T>> inputs,
    R Function(List<T> values) combiner,
  ) {
    _checkOpen();
    _checkNotEmpty(inputs);
    final List<TopicStream<T>> made = _checkMade(inputs);
    return _addStage(
      CombineStage<R>._(
        this,
        made,
        combiner,
        (List<Object?> values) =>
            combiner(List<T>.unmodifiable(values.cast<T>())),
      ),
      made,
    );
  }

  /// Throws ArgumentError for an empty [inputs].
  TopicStream<T> merge<T>(List<TopicStream<T>> inputs) {
    _checkOpen();
    _checkNotEmpty(inputs);
    final List<TopicStream<T>> made = _checkMade(inputs);
    return _addStage(MergeStage<T>._(this, made), made);
  }
```

```dart
  // Throws ArgumentError for an empty input list (G14).
  void _checkNotEmpty(List<TopicStream<Object?>> inputs) {
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
    }
  }
```

`handle.dart`: the receiver is the primary input, and the latest inputs are checked and copied like a builder call's. `withLatestFrom2` and `withLatestFrom3` take `<TopicStream<Object?>>[b, c]` and `[b, c, d]` and cast `values[1] as C` and `values[2] as D` in turn:

```dart
  TopicStream<R> withLatestFrom<B, R>(
    TopicStream<B> latest,
    R Function(T value, B latest) combiner,
  ) {
    _builder._checkOpen();
    final List<TopicStream<Object?>> made = _builder._checkMade(
      <TopicStream<Object?>>[latest],
    );
    return _builder._addStage(
      WithLatestFromStage<T, R>._(
        _builder,
        this,
        made,
        combiner,
        (T value, List<Object?> values) => combiner(value, values[0] as B),
      ),
      <TopicStream<Object?>>[this, ...made],
    );
  }
```

`stages.dart`: `apply` throws `ArgumentError` when it is given more or fewer values than the stage has inputs, rather than reading the wrong ones or failing with a `RangeError` (Review Focus 5; the contract leaves this open, and D10 shows that only the too-many case tells the check from its absence), then calls `_apply`:

```dart
  CombineStage._(super.builder, this.inputs, this.combiner, this._apply)
    : super._();

  final List<TopicStream<Object?>> inputs; // unmodifiable, in input order
  final Function combiner; // the function the declaration passed

  // combiner, called at the type arguments of the builder call that made
  // this stage.
  final R Function(List<Object?> values) _apply;

  /// Calls combiner with [values], the inputs' latest payloads in input order.
  R apply(List<Object?> values) {
    if (values.length != inputs.length) {
      throw ArgumentError.value(
        values,
        'values',
        'holds ${values.length} values for ${inputs.length} inputs',
      );
    }
    return _apply(values);
  }
```

```dart
  WithLatestFromStage._(
    super.builder,
    this.primary,
    this.latest,
    this.combiner,
    this._apply,
  ) : super._();

  final TopicStream<T> primary;
  final List<TopicStream<Object?>> latest; // unmodifiable, in argument order
  final Function combiner;

  // combiner, called at the type arguments of the handle call that made
  // this stage.
  final R Function(T value, List<Object?> latest) _apply;

  R apply(T value, List<Object?> latest) {
    if (latest.length != this.latest.length) {
      throw ArgumentError.value(
        latest,
        'latest',
        'holds ${latest.length} values for ${this.latest.length} inputs',
      );
    }
    return _apply(value, latest);
  }
```

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)`, `+119: All tests passed!`, `No issues found!` (T3.4).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G10,G11,G13,G14,G15; echo "exit: $?"`
Expected: `exit: 1` and `cases (12 passed, 4 failed, ...)`; the four left are `G10 recording calls none of the functions a declaration passes` and `G10 recording creates no timer and schedules no microtask` (the known gap, each on `UnimplementedError` from `TopologyPlan.definition`), and `G11 each combinator call adds one stage, in call order, of its combinator class` and `G11 sinks list the write and reduceInto calls in call order with their topics and inputs` (Task 4) (T3.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topology/builder.dart packages/nidana_dart_contracts/lib/src/topology/handle.dart packages/nidana_dart_contracts/lib/src/topology/stages.dart packages/nidana_dart_contracts/test/combining_stages_test.dart
git commit -m "feat(dart_contracts): record combines, merges, withLatestFrom and reduceInto" -m "<the co-author trailer your harness gives>"
```

### Task 4: visitStage and visitSink

You are filling in the two visitors of `lib/src/topology/plan.dart` through a private method each stage and sink class implements. Run every command from the repository root with `fvm dart`. This task turns three conformance cases green: G11 (2) and G16 (1).

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/topology/handle.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/stages.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/sinks.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/topology/plan.dart`
- Create: `packages/nidana_dart_contracts/test/plan_visitors_test.dart`

**Interfaces:**
- Consumes: the stage and sink classes of Tasks 1 to 3; `StageVisitor<V>` and `SinkVisitor<V>` (nidana.model.4).
- Produces: in `TopicStream<T>`, the abstract `V _accept<V>(StageVisitor<V> visitor);`; in `PlanSink`, the abstract `V _accept<V>(SinkVisitor<V> visitor);`; an `@override` of it in each of the eighteen stage classes and the two sink classes; the bodies of `visitStage` and `visitSink`. nidana.model.11's projection and nidana.runtime's interpreter reach every stage through these.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/plan_visitors_test.dart` with exactly this content:

```dart
// topology-dsl@v2's visitors, beyond the cases of its recording suite:
// visitStage and visitSink bind each stage's and sink's own type arguments,
// so an interpreter reads and calls a stage's functions at their types.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

const StateTopic<int> count = StateTopic<int>(name: 'rec.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<String> words = EventTopic<String>(name: 'rec.words');
const EventTopic<Object?> any = EventTopic<Object?>(name: 'rec.any');

/// What a visitor saw: the stage's class with the type arguments it
/// received, and for map, filter and scan what an interpreter builds, a
/// function over Object? that calls the stage's own function at its types.
typedef Bound = ({String types, Object? Function(Object?)? call});

final class Bind implements StageVisitor<Bound> {
  const Bind();

  Bound _named(String types) => (types: types, call: null);

  @override
  Bound read<T>(ReadStage<T> stage) => _named('read<$T>');
  @override
  Bound map<T, R>(MapStage<T, R> stage) =>
      (types: 'map<$T, $R>', call: (Object? v) => stage.transform(v as T));
  @override
  Bound filter<T>(FilterStage<T> stage) =>
      (types: 'filter<$T>', call: (Object? v) => stage.test(v as T));
  @override
  Bound combine<R>(CombineStage<R> stage) => _named('combine<$R>');
  @override
  Bound withLatestFrom<T, R>(WithLatestFromStage<T, R> stage) =>
      _named('withLatestFrom<$T, $R>');
  @override
  Bound merge<T>(MergeStage<T> stage) => _named('merge<$T>');
  @override
  Bound switchMap<T, R>(SwitchMapStage<T, R> stage) =>
      _named('switchMap<$T, $R>');
  @override
  Bound scan<T, S>(ScanStage<T, S> stage) => (
    types: 'scan<$T, $S>',
    call: (Object? v) => stage.accumulator(stage.initial, v as T),
  );
  @override
  Bound pairwise<T>(PairwiseStage<T> stage) => _named('pairwise<$T>');
  @override
  Bound distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage) =>
      _named('distinctUntilChanged<$T>');
  @override
  Bound debounce<T>(DebounceStage<T> stage) => _named('debounce<$T>');
  @override
  Bound throttle<T>(ThrottleStage<T> stage) => _named('throttle<$T>');
  @override
  Bound delay<T>(DelayStage<T> stage) => _named('delay<$T>');
  @override
  Bound sample<T>(SampleStage<T> stage) => _named('sample<$T>');
  @override
  Bound buffer<T>(BufferStage<T> stage) => _named('buffer<$T>');
  @override
  Bound timeout<T>(TimeoutStage<T> stage) => _named('timeout<$T>');
  @override
  Bound catchError<T>(CatchErrorStage<T> stage) => _named('catchError<$T>');
  @override
  Bound rawEngine<T, R>(RawEngineStage<T, R> stage) =>
      _named('rawEngine<$T, $R>');
}

final class BindSink implements SinkVisitor<String> {
  const BindSink();

  @override
  String write<T>(WriteSink<T> sink) => 'write<$T>';
  @override
  String reduceInto<S, E>(ReduceIntoSink<S, E> sink) => 'reduceInto<$S, $E>';
}

Topology declared(void Function(TopologyBuilder b) body) =>
    topology('rec-visit', Scope.page, body);

void main() {
  test('G16 visitStage passes each stage to the method of its class with '
      'the stage\'s own type arguments', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        final TopicStream<String> s = t.map((int v) => '$v');
        final TopicStream<List<String>> batches = b
            .merge(<TopicStream<String>>[
              s.filter((String v) => v.isNotEmpty),
              b.combine2(t, w, (int a, String c) => '$a$c'),
              t.withLatestFrom(w, (int v, String c) => c),
            ])
            .switchMap((String v) => Stream<double>.value(1.5))
            .scan(
              <double>[],
              (List<double> acc, double v) => <double>[...acc, v],
            )
            .map((List<double> v) => v.length)
            .distinctUntilChanged()
            .debounce(Duration.zero)
            .throttle(Duration.zero)
            .delay(Duration.zero)
            .sample(Duration.zero)
            .timeout(Duration.zero)
            .catchError((Object e, StackTrace st) => 0)
            .rawEngine<String>(
              (Stream<PipelineValue<int>> v, String Function() fresh) =>
                  const Stream<PipelineValue<String>>.empty(),
            )
            .buffer(Duration.zero);
        b.write(any, batches.pairwise());
      }),
    );
    expect(
      <String>[
        for (final TopicStream<Object?> stage in plan.stages)
          visitStage(stage, const Bind()).types,
      ],
      <String>[
        'read<int>',
        'read<String>',
        'map<int, String>',
        'filter<String>',
        'combine<String>',
        'withLatestFrom<int, String>',
        'merge<String>',
        'switchMap<String, double>',
        'scan<double, List<double>>',
        'map<List<double>, int>',
        'distinctUntilChanged<int>',
        'debounce<int>',
        'throttle<int>',
        'delay<int>',
        'sample<int>',
        'timeout<int>',
        'catchError<int>',
        'rawEngine<int, String>',
        'buffer<String>',
        'pairwise<List<String>>',
      ],
    );
  });

  test('G16 visitSink passes each sink to the method of its class with the '
      'sink\'s own type arguments', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        b.write(any, t);
        b.reduceInto(count, b.read(words), (int s, String w) => s + w.length);
        b.write(taps, t);
      }),
    );
    expect(
      <String>[
        for (final PlanSink sink in plan.sinks)
          visitSink(sink, const BindSink()),
      ],
      <String>['write<Object?>', 'reduceInto<int, String>', 'write<int>'],
    );
  });

  test('G16 through visitStage an interpreter calls a stage\'s functions at '
      'their own types', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        b.write(
          words,
          b
              .read(taps)
              .filter((int v) => v.isEven)
              .scan(1, (int acc, int v) => acc * v)
              .map((int v) => 'x$v'),
        );
      }),
    );
    final List<Object? Function(Object?)> call = <Object? Function(Object?)>[
      for (final TopicStream<Object?> stage in plan.stages.skip(1))
        visitStage(stage, const Bind()).call!,
    ];
    expect(call[0](4), isTrue);
    expect(call[1](6), 6);
    expect(call[2](6), 'x6');
    expect(() => call[2]('six'), throwsA(isA<TypeError>()));
  });
}
```

- [ ] **Step 2: Run it and the replay of G11 and G16, and record the failures**

Run: `fvm dart test packages/nidana_dart_contracts/test/plan_visitors_test.dart; echo "exit: $?"`
Expected: `exit: 1` and `+0 -3: Some tests failed.`, all three on `UnimplementedError` (T4.2).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G11,G16; echo "exit: $?"`
Expected: `exit: 1` and `cases (3 passed, 3 failed, ...)` (T4.2).

- [ ] **Step 3: Implement the visitors**

In `handle.dart`, after the `_builder` field:

```dart
  // Calls the visitor method of this stage's class with this stage, binding
  // its type arguments (G16).
  V _accept<V>(StageVisitor<V> visitor);
```

In `sinks.dart`, the same in `PlanSink` after `Topic<Object?> get topic;`, with `SinkVisitor<V>` and "this sink's class". Each stage class, after its fields, calls the visitor method named after its class with its own type parameters in the order the class declares them, and each sink class does the same; for example:

```dart
final class MapStage<T, R> extends TopicStream<R> {
  MapStage._(super.builder, this.input, this.transform) : super._();

  final TopicStream<T> input;
  final R Function(T value) transform;

  @override
  V _accept<V>(StageVisitor<V> visitor) => visitor.map<T, R>(this);
}
```

So `ReadStage<T>` calls `visitor.read<T>(this)`, `CombineStage<R>` calls `visitor.combine<R>(this)`, `WithLatestFromStage<T, R>` calls `visitor.withLatestFrom<T, R>(this)`, `ScanStage<T, S>` calls `visitor.scan<T, S>(this)`, `PairwiseStage<T>` calls `visitor.pairwise<T>(this)` (its `T`, not the record it emits), `BufferStage<T>` calls `visitor.buffer<T>(this)`, `RawEngineStage<T, R>` calls `visitor.rawEngine<T, R>(this)`, and likewise for the other eleven; `WriteSink<T>` calls `visitor.write<T>(this)` and `ReduceIntoSink<S, E>` calls `visitor.reduceInto<S, E>(this)`. Writing the type arguments out keeps a reader from wondering whether inference chose them; a visitor called at `Object?` instead passes the whole recording suite and fails only this task's tests (D1).

In `plan.dart`:

```dart
V visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor) =>
    stage._accept(visitor);
V visitSink<V>(PlanSink sink, SinkVisitor<V> visitor) => sink._accept(visitor);
```

- [ ] **Step 4: Run the tests, the analyzer and the replays**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `(0 changed)`, `+122: All tests passed!`, `No issues found!` (T4.4).
Run: `fvm dart run nidana_contract_check topology-dsl --set behavior --guarantee G11,G16; echo "exit: $?"`
Expected: `exit: 0`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 6 passed, 0 failed, 0 skipped under dart test, restricted to topology-dsl G11, G16` and `17 fixtures: 17 passed, 0 failed, 0 pending` (T4.4).
Run: `fvm dart run nidana_contract_check topology-dsl --guarantee G10,G11,G13,G14,G15,G16,G17,G30; echo "exit: $?"`
Expected: `exit: 1`; the 2 surface and 9 reject libraries pass, and `FAIL behavior ...topology_builder_test.dart: cases (17 passed, 2 failed, 0 skipped under dart test, restricted to topology-dsl G10, G11, G13 to G17, G30)` with the two G10 cases only, then `28 fixtures: 27 passed, 1 failed, 0 pending`: the known gap, nothing else (T4.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/topology/handle.dart packages/nidana_dart_contracts/lib/src/topology/stages.dart packages/nidana_dart_contracts/lib/src/topology/sinks.dart packages/nidana_dart_contracts/lib/src/topology/plan.dart packages/nidana_dart_contracts/test/plan_visitors_test.dart
git commit -m "feat(dart_contracts): visit stages and sinks at their own type arguments" -m "<the co-author trailer your harness gives>"
```

### Task 5: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.9.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.9.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 4; the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Read the Gate line of `hsdd-context/nidana.model.9.md` (its Phase block) and run that command exactly, as `(<gate>) > "${TMPDIR:-/tmp}/nidana.model.9-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after. Two forms are known (G):

- **The form in Global Constraint 4**, whose topology-dsl restriction names G10. Expected: `exit: 1`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+122: All tests passed!`, `31 fixtures: 31 passed, 0 failed, 0 pending` (with `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`), then `FAIL behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: cases (17 passed, 2 failed, 0 skipped under dart test, restricted to topology-dsl G10, G11, G13 to G17, G30)`, whose two failed cases are the G10 cases of the known gap, and `28 fixtures: 27 passed, 1 failed, 0 pending`. The `&&` chain stops there, so also run its last command on its own, `fvm dart run nidana_contract_check topology-ir --set structure,surface,reject,schema; echo "exit: $?"` (expected: `60 fixtures: 60 passed, 0 failed, 0 pending`, `exit: 0`), and keep both outputs. If the failure is exactly those two G10 cases, each on `UnimplementedError` from `TopologyPlan.definition`, it is the known gap: change no code and nothing under `hsdd/`, finish Steps 2 to 4, and report DONE_WITH_CONCERNS naming the gap. Any other failure stops here: it is fixed in the task that owns the code, or, for a fixture that fails against code that follows this plan, reported as a contract gap (Global Constraints).
- **The form with G10 dropped from the restriction**, if the orchestrator's fix for the gap has landed. Expected: `exit: 0`; the same lines up to topic-model, then `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 17 passed, 0 failed, 0 skipped under dart test, restricted to topology-dsl G11, G13 to G17, G30`, `28 fixtures: 28 passed, 0 failed, 0 pending` and `60 fixtures: 60 passed, 0 failed, 0 pending`.

The `+122` is this plan's count; it is higher by the tests the implementers added.

- [ ] **Step 2: Run the checklist**

`<base>` below is the parent of Task 1's commit (`git log --format=%H -n 1 <Task 1's commit>^`). Run each and keep its output:
- `fvm dart test hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart --name '^G9 (planOf runs|the builder form)' -r expanded` (expected: the two case names, `G9 planOf runs declare once against a fresh builder and carries the id and scope` and `G9 the builder form runs its body on each planOf call and never at construction`, then `+2: All tests passed!`): G9's two recording cases, which no restriction can select (C).
- `fvm dart test packages/nidana_dart_contracts/test/combining_stages_test.dart --name '^G10' -r expanded` (expected: the one name `G10 recording every combinator calls none of its functions, nor a computed initial value, and creates no timer or microtask`, then `+1: All tests passed!`): recording calls nothing and schedules nothing, with the counter's positive control (C).
- `fvm dart test packages/nidana_dart_contracts/test/recording_test.dart packages/nidana_dart_contracts/test/handle_stages_test.dart packages/nidana_dart_contracts/test/combining_stages_test.dart --name '^G1[45] ' -j 1 -r expanded` (expected: thirteen test names, five from `recording_test.dart`, four from `handle_stages_test.dart` and four from `combining_stages_test.dart`, then `+13: All tests passed!`; `-j 1` runs one file at a time, so the names come in order): each misuse G14 and G15 name throws its error at the call that commits it (C).
- `grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?"` (expected: one line, `packages/nidana_dart_contracts/lib/src/topology/plan.dart:39:  TopologyDefinition get definition => throw UnimplementedError();`, and `exit: 0`): only nidana.model.11's body still throws.
- `grep -rn "ignore:" packages/nidana_dart_contracts/lib/src/topology; echo "exit: $?"` (expected: no line, `exit: 1`).
- `git diff --name-status <base> HEAD -- packages/nidana_dart_contracts` (expected: ten lines, `M` for the six part files of `lib/src/topology/` and `A` for the four new test files).
- `git status --short pubspec.lock` and `git diff --stat <base> HEAD -- packages/nidana_dart_contracts/pubspec.yaml` (expected: no output from either).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.9.verification.md` at spot-check depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.9 - Recording builder` (a spaced hyphen; no em-dash anywhere in the file). Short: commands, expected output, what to eyeball, Learnings.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as Step 1 ran it, saying that it replays topology-dsl@v2's `structure`, `surface` and `reject` sets in full and its `behavior` set through the binding `topology_builder_test.dart` under `dart test`, restricted to the guarantees this phase delivers, beside topic-model@v1 unrestricted and topology-ir@v1's four type-level sets; the checklist commands of Step 2.
- **Expected output:** the gate's exit code and lines of Step 1, for the form that ran; the checklist's expected results of Step 2.
- **Observed:** dated, with the gate's start and end times, the branch and commit, and Dart 3.13.5 through `fvm`; the gate's exit code and its lines as they appeared; then a checklist of `- [x]` lines, each with its result, to eyeball:
  - recording a declaration calls none of its functions and schedules nothing: the package test `G10 recording every combinator calls none of its functions, nor a computed initial value, and creates no timer or microtask` records one call of every combinator with functions that throw and a computed initial value whose factory throws, inside a zone that counted a timer and a microtask made in it (2) before and none made by recording (0); the recording suite's two G10 cases, which also build the definition, wait for nidana.model.11 (Outstanding, unless the gate's form had G10 dropped);
  - each misuse G14 and G15 name throws the named error at the call that commits it, not later: the thirteen tests of the third checklist command, by name, which assert the throw at the call itself, inside the declaration, and then that the declaration still plans with no stage left behind; or at the first call after `declare` returned, a declaration that threw included; or at `planOf`, before `declare` runs for an empty id and when `declare` returns for a stage that reaches no sink; beside the suite's seven G14 and G15 cases in the gate's replay;
  - G9's two recording cases pass, by name (checklist), and the package tests `G9 planOf runs declare once per call against a fresh builder and carries the id and scope` and `G9 an empty declaration records an empty plan` pass in the gate's package run; no gate restriction can select them (ADR-001 item 9; this plan, "Which task turns which failing case green");
  - the gate's topology-dsl replay, with its pass and fail counts; the five cases of the unrestricted suite that still fail all call `buildDefinition()` or read `definition`, nidana.model.11's;
  - only `TopologyPlan.definition` still throws `UnimplementedError` under `lib/src/topology/`, no `ignore:` is there, the export lists are unchanged (`exports_test.dart` passes), `purity_test.dart` passes over the changed library (topic-model@v1 G25, G26), and the lockfile and `pubspec.yaml` are unchanged.
- **Outstanding:** when the gate ran in the form that names G10, one item: `topology-dsl@v2 G10's two recording cases fail at this phase's gate on UnimplementedError from TopologyPlan.definition, because each calls buildDefinition(); G10 for planOf is checked by combining_stages_test.dart. Deferred to nidana.model.11, whose gate replays topology-dsl@v2 unrestricted; reported as a contract gap by S127.` Otherwise `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found the four below and the sizing line; write each that still holds, and any the gate finds:
  - `- nidana.model.9's Gate restricted the topology-dsl replay to G10 among others, while both of the recording suite's G10 cases call buildDefinition(), which nidana.model.11 delivers; the restriction fails them at this phase, as it would have failed G9, which the Gate already leaves out. Disposition: dropped (reported as a contract gap by S127; the orchestrator routes the fix to nidana.model.9's Gate and topology-dsl@v2's Delivery paragraph)`, or `Disposition: spec-updated` if the gate that ran had G10 dropped;
  - `- The recording suite passes a builder whose visitors bind Object? instead of the stage's type arguments, whose one-sink check compares state topics by identity, whose combineAll hands its combiner a modifiable list, or whose rejected calls leave a stage behind; this phase's package tests pin each (S127 dry run, seeded defects D1 to D4, D8). Disposition: dropped (reported as a contract gap by S127 for hsdd-contract to add cases)`;
  - `- topology-dsl@v2 does not say which error a call that is misused twice over throws, a closed builder given a negative duration, nor what apply does with a value list whose length is not the number of inputs; this phase throws StateError first, and ArgumentError for a wrong length. Disposition: dropped (decided in S127's plan; reported as a contract gap for a compatible hsdd-contract touch)`;
  - `- The recording suite's names begin with their guarantee id, so a gate restriction cannot select G9's two recording cases apart from its buildDefinition() case; the plan checked them by name. Disposition: dropped (ADR-001 item 9 restricts by id by design; nidana.model.11's unrestricted replay runs all three)`;
  - one sizing line: the phase scope's estimate of about 400 lines in about 5 files against the measured product diff (Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint).
- **Metrics:** one line: the product diff, `git diff --stat <base> HEAD -- packages/`, in files and lines, the library and the tests apart, beside the estimate of about 400 lines in about 5 files; the task count, 5 of the allowed 7.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.9.verification.md
git commit -m "docs(verify): nidana.model.9 verification" -m "<the co-author trailer your harness gives>"
```
