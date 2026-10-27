# nidana.model.14 Mermaid and Graphviz Renderers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver topology-ir@v1's `MermaidRenderer` and `GraphvizRenderer` in `packages/nidana_dart_contracts/lib/src/render/renderers.dart` by the contract's Mermaid and Graphviz rules (node ids, label lines, durations in whole seconds, milliseconds or microseconds, each renderer's escaping and line break, the order of parts and arrows, two-space indentation and a newline after every line; G22), with package tests for the rules no sample shows. The gate's replay of all three contracts, unrestricted, then passes topology-ir@v1's 43 behavior cases, against 41 today.

**Architecture:** One library, `lib/src/render/renderers.dart` (nidana.model D4), which nidana.model.5 declared with two stubs and `topology_ir.dart` exports by name; no public declaration changes. Private helpers both renderers share: the label lines of a topic, a topology, an edge and a claim, built from fields and unescaped; the text of a duration; and one walk of the graph that lists every arrow in the rules' order as a record `({String from, String to, Dedup? dedup})`. Each renderer escapes each label line by its own rule, joins the lines with its own line break, and writes its own syntax around them; the text is a list of lines, each followed by a newline. Tasks: the Mermaid renderer with the shared helpers; the Graphviz renderer; the gate and the verification doc.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; the library imports only the package's own libraries (no `dart:` library at all); `package:test` for the package's tests, which read the fixtures with `dart:io` and count scheduled work with `dart:async`'s `runZoned`; the replay tool `nidana_contract_check` with its `behavior` set.

**Spec:** `hsdd-context/superpowers/nidana.model.14.md` (the derivative; the phase context with topic-model@v1's, topology-dsl@v2's and topology-ir@v1's whole Interface and Guarantees sits between its markers). The rules the renderers follow are topology-ir@v1's Renderers section, "Mermaid and Graphviz rules" (`hsdd/contract/topology-ir.md`, lines 269 to 287, carried whole in the derivative), and G22. Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D4 (line 112: the renderers under `lib/src/render/`), D5 (line 128: the gate; this is topology-ir@v1's last producing phase, so its gate replays all three contracts unrestricted) and D6 (line 135: `test/purity_test.dart` scans every `.dart` file under `lib/` for `DateTime.now(`, `Stopwatch(`, `Timer(`, `Timer.periodic(`, `scheduleMicrotask(`, `Future.delayed(`, `Future.microtask(`, `Random(` and `Zone.` as text, comments and dartdoc included). The fixtures the gate replays: `hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart` through `nidana_dart_contracts_test.dart` (the three G22 cases are at lines 1449, 1460 and 1469), the 14 goldens under `render/` (a `.mmd` and a `.dot` for each of the samples `checkout`, `claims_only`, `empty`, `escaping`, `every_combinator`, `findings` and `forms`) and the 7 files under `valid/`. Evidence: `docs/auto-run/experiments/renderers-plan/` (`run.sh`, `output.txt`, `variants.py`, `defects.py`, `fill_plan.py`, `plan.template.md`, `draft/`), a dry run of this plan's tasks in a temporary copy of HEAD `ce03308`; labels such as S1, T1.2, T2.4, X, G, C and D7 below name the steps of its `output.txt`. `draft/` is evidence: the code blocks below are spliced from it by `fill_plan.py`, each formatter-stable (S0, X), and `variants.py` derives Task 1's `renderers.dart` from `draft/lib/src/render/renderers.dart`, which is Task 2's.

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 5 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.14.verification.md from
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

- **Toolchain:** `fvm dart` only, every command from the repository root, no global tooling. No step and no test of this phase starts `flutter`. No dependency changes: no `pubspec.yaml` is edited and `pubspec.lock` stays byte-identical.
- **Files:** under `lib/` this phase edits `lib/src/render/renderers.dart` alone (Tasks 1 and 2). Every other library stays as it is, and so do the three public libraries' export lists, which `test/exports_test.dart` pins. Under `test/` this phase creates `test/src/render_support.dart` and `test/mermaid_renderer_test.dart` (Task 1) and `test/graphviz_renderer_test.dart` (Task 2), and edits no existing test. `README.md`, `CHANGELOG.md` and `LICENSE` stay as they are (D4). Nothing under `hsdd/` changes except the verification doc of Task 3.
- **Interface:** the two public classes stay exactly as nidana.model.5 landed them: `final class MermaidRenderer implements GraphRenderer { const MermaidRenderer(); ... }` and the same for `GraphvizRenderer`, with no dartdoc (topology-ir@v1's Interface gives them none). Only the body of each `render` changes, with a `//` comment above its `@override` saying what it renders. No public declaration is added; every helper is private to `renderers.dart` and gets a `//` comment saying what it returns.
- **Labels from fields:** a label is built from `TopicRef.name`, `TopicVariant.name`, `TopicRef.typeName`, `TopologyDefinition.topologyId`, `Scope.name`, `CombinatorKind.name`, `FunctionRef.name` and `Dedup.name`, and from `MessageSource.toString()`, which is the contract's own rendering (topic-model@v1 G17). Never interpolate a `TopicRef`, a topic or an enum value itself: `TopicRef` keeps `Object.toString()` (`Instance of 'TopicRef'`), and an enum renders as `Scope.page`.
- **Purity:** no D6 token may appear under `lib/`, in code, comment or dartdoc: no `Zone.`, no `Timer(`, no `Random(` and the others listed under Spec. The renderers read no clock, create no timer and schedule nothing (topic-model@v1 G25; topology-ir@v1 G22, whose third case first replays in this phase and which each new test file also pins).
- **Prose:** no em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.
- **Const collections:** `TopicRef` overrides `==`, so a non-empty const set of topic references does not compile; the tests build each claim's `writes` as a non-const `<TopicRef>{...}`. Const lists and const records are fine, and the tests use them.
- **Analyzer:** `fvm dart analyze --fatal-infos` at the root reports nothing after every task (T1.4, T2.4); `renderers.dart` imports exactly what each task's code uses, the same four libraries in both tasks.
- **Tests:** run from the root as `fvm dart test packages/nidana_dart_contracts`. Each task's failing step also replays G22's conformance cases with `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G22`, which runs the committed binding under `dart test`. The package's tests do not repeat the suite's cases; they pin what the seven samples leave open: durations in every unit and above a second, every time stage, an anonymous retry, a repeated input, a stage two edges read, one topic name of two variants, each escape in every kind of label, the characters each renderer leaves as they are, the empty graph, indentation, and no scheduled work. The counts below are floors: add a test beyond the plan's wherever a rule you implement would otherwise go unpinned, and the totals rise by that many. No test uses a `test` API newer than 1.31.1. The 353 package tests of HEAD, topic-model@v1's replay (41 cases) and topology-dsl@v2's (24 cases) pass today and stay green through every task (S1).
- **Contract gaps (ADR-001 item 8):** the dry run passes every fixture the gate replays (G). Any fixture that fails against code that follows this plan is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the case, what it reports, the guarantee, and the fix you would propose.
- **Formatting and commits:** run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for a Sonnet implementer.

## Plan check

The derivative's Plan check, run after self-review: the Global Constraints above contain its constraints 1 to 8 verbatim; every `### Task N:` but the last starts with a failing-test step; Task 3 writes `hsdd/verify/nidana.model.14.verification.md`; the plan has 3 tasks of the allowed 5; it is saved as `docs/superpowers/plans/nidana.model.14.md`. `node docs/auto-run/tools/impl-gate.mjs code-plan nidana.model.14` checks the same mechanically and exits 0 on this plan.

## Review Focus

The input classes the spec implies but the seven samples do not show, most likely to bite first; each has its test in the owning task, and each of the dry run's seeded defects named here passes the gate's unrestricted replay and fails a package test (D).

1. **A switchMap whose retry policy is a closure:** `s.switchMap(search, retry: (e, n) => ...)`, the usual way to write a policy, records an anonymous retry, which no sample holds. Expected: the edge's third line is `retry (anonymous)`, as "An anonymous reference renders as `(anonymous)`" has it. The dry run's D6 (`retry null`) passes the gate. Tests: `G22 an edge renders its transformer and its retry on lines of their own, an anonymous reference as (anonymous)` in both files.
2. **A duration above a second that is not whole seconds:** `debounce(Duration(milliseconds: 1500))`, `sample(Duration(seconds: 1, microseconds: 1))`. Expected: `1500ms` and `1000001us`, never a rounded `1s`; zero is `0s`; a long duration stays in whole seconds (`31536000000s`). Every sample duration above a second is whole, so D7 (seconds for anything of a second or more) passes the gate. Tests: `G22 a duration renders in whole seconds, else whole milliseconds, else microseconds` and `G22 each time stage renders its combinator and its duration on its first line` in both files.
3. **A graph a person draws to debug wiring:** `b.combine2(x, x, f)` (one handle twice), one stage two sinks read, a topic name used for two variants by mistake, topologies and claims registered in any order. Expected: one arrow per input, a repeated input repeated; ids from `graph.topics`, so `a.x` as a state topic and `a.x` as an event topic are two nodes; parts in graph order whatever the argument order. No sample repeats an input or shares a name across variants: D12 (repeated arrows collapse) and D13 (topic ids keyed by name) pass the gate. Tests: `G22 parts and arrows come in graph order: one arrow per input, a repeated input repeated, then the sink output, then the claims` in both files.
4. **Names the renderers' syntax gives meaning to, beyond the escaping sample:** a page route with a query string, a function name with a `$`, a type name with `&`, `|`, `{` or `'`, a name that holds an escape's own text (`#quot;`), a backslash before a quote or before an `n`. Expected: exactly the replacements the rule names, in its order, and every other character as it is. D4 (Mermaid also escapes `&`) passes the gate. Tests: `G22 Mermaid escapes # first, ...` and `G22 Graphviz escapes \ first, ...`.
5. **Rendering inside a zone that intercepts work:** a graph rendered inside a `fakeAsync` test, a `testWidgets` body or a bus's provider zone, or diffed in CI. Expected: no timer and no microtask, a newline after every line and two spaces per level. The suite's G22 purity case renders one sample; the package tests render every sample and every graph above. Tests: `G22 rendering schedules nothing, and every line ends with a newline and is indented by two spaces per level` and `G22 an empty graph renders as ...` in both files.

## Design decisions

Only the decisions this phase settles (review tier spot-check). Each is a decision in `docs/auto-run/steps/S149.json` with its options and evidence.

1. **One library, private helpers.** Both renderers and their helpers share `renderers.dart`: the label lines, the durations and the arrow walk are one rule set that both formats apply, and a second library would add src-public names for no reader (D4: "the Mermaid and Graphviz renderers"). The library grows from 15 to 187 lines (C).
2. **Labels are lists of unescaped lines.** `_topicLabel`, `_topologyLabel`, `_edgeLabel` and `_claimLabel` return the lines the rule lists; `_mermaidLabel` and `_graphvizLabel` escape each line and then join the lines with the renderer's break, as "Labels are lines of text, each escaped, then joined by the renderer's line break" has it. Escaping after joining would turn Mermaid's `<br/>` into `#lt;br/#gt;` and Graphviz's `\n` break into `\\n` (D3 fails the gate).
3. **Each renderer's escapes in the rule's order.** Mermaid replaces `#` first and Graphviz `\` first, so that the escapes the later replacements write are not escaped again (D1, D2 fail the gate). Nothing else is escaped (D4, D5).
4. **Durations by integer arithmetic.** `inMicroseconds` with `%` and `~/` against `Duration.microsecondsPerSecond` and `Duration.microsecondsPerMillisecond`: whole seconds, else whole milliseconds, else microseconds; zero is a multiple of a second, `0s`, as the samples show (`delay 0s`).
5. **An anonymous retry renders `retry (anonymous)`.** The rule says "`retry` and the retry's name when it has one. An anonymous reference renders as `(anonymous)`", and its transformer clause, "the transformer's name when it has one", renders an anonymous transformer `(anonymous)` in the samples (`filter` then `(anonymous)`). No golden holds an anonymous retry, so the package tests pin it (Review Focus 1).
6. **One arrow walk, records out.** `_arrows(graph)` lists every arrow once, in the rules' order, as `({String from, String to, Dedup? dedup})`; each renderer only formats them. Topic ids come from a `Map<TopicRef, String>` over `graph.topics`, keyed by the whole reference, so one name of two variants keeps two ids; every topic an edge or a claim names is in `graph.topics` (G11), so the lookup's `!` cannot fail.
7. **The text as a list of lines.** Each `render` is one list literal with collection `for` and `if`, joined by `_text`, which writes a newline after every line, the last included: declarative, and the newline rule holds in one place (D15 fails the gate).
8. **The tests read the samples from `valid/`.** `sampleGraph(name)` decodes `valid/{name}.json` with nidana.model.13's decoder, which gives the sample graph back (G20), instead of importing the conformance library, which imports `package:nidana_contract_check/fixture.dart` and `package:matcher`, neither a dependency of this package (ADR-002 item 3). The suite's G22 case compares the samples' own recordings.

## Routed items

`docs/auto-run/impl-execution-plan.md` ("Routed to later phases") routes nothing to this phase. S148's two notes are taken here: an anonymous retry (Design decision 5) and labels from fields (Global Constraints, Labels from fields).

## Which task turns which failing case green

The gate's last command replays topic-model@v1, topology-dsl@v2 and topology-ir@v1 unrestricted. Today it exits 1: topology-ir@v1's `behavior` set passes 41 of 43 cases, and the two it fails call `MermaidRenderer.render`, whose stub throws `UnimplementedError` (S1). `G22 the JSON rendering of every sample is its valid/ file, byte for byte` passes already (nidana.model.13).

| Task | Cases turned green | Replay `topology-ir --set behavior --guarantee G22` |
|------|--------------------|--------|
| 1 | none: both remaining G22 cases render with both renderers, and after Task 1 they fail at `GraphvizRenderer.render` instead (T1.4) | 1 passed, 2 failed before and after (T1.2, T1.4) |
| 2 | `G22 the Mermaid and Graphviz renderings of every sample equal its render/ files`, `G22 render passes the graph to the renderer, and renderers are pure` | 1 passed, 2 failed to 3 passed; the gate's last command then passes 120 of 120 fixtures, topology-ir@v1's `behavior` set 43 of 43 (T2.2, T2.4) |

**The phase's Verification line**, and where each part is checked: the seven samples render to their `render/` goldens byte for byte, the `escaping` sample showing each renderer's escapes (the suite's `G22 the Mermaid and Graphviz renderings of every sample equal its render/ files`, and the package's `G22 every sample renders to its render/ .mmd file byte for byte` and `... .dot file byte for byte`); rendering, encoding, decoding and the analyses schedule nothing (the suite's `G22 render passes the graph to the renderer, and renderers are pure`, and each new file's `G22 rendering schedules nothing, ...`).

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/render/renderers.dart` | 1, 2 | `MermaidRenderer.render` and the shared helpers: label lines, durations, the arrow walk, the text (1); `GraphvizRenderer.render` and its label escaping (2) |
| `{pkg}/test/src/render_support.dart` | 1 | Create: the samples read from `valid/`, the duration table, the graphs built for the rules no sample shows, the scheduled-work counter |
| `{pkg}/test/mermaid_renderer_test.dart` | 1 | Create: Mermaid's goldens, empty graph, durations, time stages, function lines, arrows, escapes, no scheduled work and indentation |
| `{pkg}/test/graphviz_renderer_test.dart` | 2 | Create: the same rules in Graphviz's syntax |
| `hsdd/verify/nidana.model.14.verification.md` | 3 | The verification doc |

---

### Task 1: MermaidRenderer and the shared helpers

You are filling in `MermaidRenderer.render` in `packages/nidana_dart_contracts/lib/src/render/renderers.dart` (15 lines today, two stubs), with the private helpers both renderers share. `GraphvizRenderer.render` stays `throw UnimplementedError()` until Task 2. Run every command from the repository root with `fvm dart`. Change no public declaration (Global Constraints, Interface). This task turns no suite case green: the two G22 cases it reaches also call the Graphviz renderer (Which task turns which failing case green).

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/render/renderers.dart` (all 15 lines)
- Create: `packages/nidana_dart_contracts/test/src/render_support.dart`
- Create: `packages/nidana_dart_contracts/test/mermaid_renderer_test.dart`

**Interfaces:**
- Consumes (landed by nidana.model.4, .5, .10, .11 and .13): `TopologyGraph` (`topics`, canonical; `topologies`, by id; `claims`, canonical; `render(GraphRenderer)`), `TopologyDefinition` (`topologyId`, `scope`, `transforms`; the factory), `TransformEdge` (`combinator`, null for a write; `inputs`; `output`; `transformer`; `duration`; `retry`; the factories `.stage`, `.write`, `.reduceInto`), `TopicInput` (`topic`, `dedup`), `StageInput` (`edge`), `TopicRef` (`name`, `variant`, `typeName`), `FunctionRef` (`name`, null when anonymous; `.named`, `.anonymous`), `ShellClaim` (`source`, `scope`, `writes`, canonical), `MessageSource.toString()`, the enums' `name`; `decodeTopologyGraph` and, from `test/src/json_support.dart`, `fixtureText(String relative)`, `fixtureJson(String relative)` and `fixtureNames(String set)`.
- Produces: `MermaidRenderer.render(TopologyGraph graph)`, and, private to `renderers.dart`, which Task 2 uses: `String _text(List<String> lines)`, `List<String> _topicLabel(TopicRef topic)`, `List<String> _topologyLabel(TopologyDefinition definition)`, `List<String> _edgeLabel(TransformEdge edge)`, `List<String> _claimLabel(ShellClaim claim)`, `typedef _Arrow = ({String from, String to, Dedup? dedup})` and `List<_Arrow> _arrows(TopologyGraph graph)`. In `test/src/render_support.dart`, which Task 2's test uses: `List<String> sampleNames()`, `TopologyGraph sampleGraph(String name)`, `stateRef`, `eventRef`, `replayRef`, `const List<(Duration, String)> durationTexts`, `TopologyGraph delayGraph(Duration duration)`, `timeStagesGraph()`, `functionsGraph()`, `arrowsGraph()`, `escapesGraph()`, `List<TopologyGraph> everyGraph()` and `(List<String>, int) countingScheduled(List<String> Function() render)`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/src/render_support.dart` with exactly this content:

```dart
@@FILE test/src/render_support.dart@@
```

Create `packages/nidana_dart_contracts/test/mermaid_renderer_test.dart` with exactly this content (each expected text is the rule applied by hand to the graph the test builds; the raw strings keep `\` and `$` as they are):

```dart
@@FILE test/mermaid_renderer_test.dart@@
```

- [ ] **Step 2: Run the test and the G22 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/mermaid_renderer_test.dart`
Expected: `+0 -8: Some tests failed.`, each of the 8 tests failing with `UnimplementedError` (T1.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G22; echo "exit: $?"`
Expected: `FAIL behavior ... cases (1 passed, 2 failed, 0 skipped under dart test, restricted to topology-ir G22)`, the failed cases being `G22 the Mermaid and Graphviz renderings of every sample equal its render/ files` and `G22 render passes the graph to the renderer, and renderers are pure`, then `exit: 1` (T1.2).

- [ ] **Step 3: Implement `MermaidRenderer.render` and the shared helpers in `lib/src/render/renderers.dart`**

Replace the whole file with exactly this content:

```dart
@@T1 renderers@@
```

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `Formatted ... (0 changed)`, at least `+361: All tests passed!` (353 and the 8 new), `No issues found!` (T1.4).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G22; echo "exit: $?"`
Expected: still `cases (1 passed, 2 failed, ...)` and `exit: 1`, now failing at `GraphvizRenderer.render` (`UnimplementedError` from `renderers.dart` line 39), which Task 2 fills (T1.4). A failure that names `MermaidRenderer` or shows a text difference is a defect of this task.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/render/renderers.dart packages/nidana_dart_contracts/test/src/render_support.dart packages/nidana_dart_contracts/test/mermaid_renderer_test.dart
git commit -m "feat(dart_contracts): render topology graphs as Mermaid flowcharts" -m "<the co-author trailer your harness gives>"
```

### Task 2: GraphvizRenderer

You are filling in `GraphvizRenderer.render` in `packages/nidana_dart_contracts/lib/src/render/renderers.dart`, on the helpers Task 1 landed. Run every command from the repository root with `fvm dart`. This task turns the two remaining G22 cases green, and with them the gate's unrestricted replay.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/render/renderers.dart`
- Create: `packages/nidana_dart_contracts/test/graphviz_renderer_test.dart`

**Interfaces:**
- Consumes: Task 1's `_text`, `_topicLabel`, `_topologyLabel`, `_edgeLabel`, `_claimLabel`, `_Arrow` and `_arrows`; everything `test/src/render_support.dart` produces; `fixtureText` from `test/src/json_support.dart`.
- Produces: `GraphvizRenderer.render(TopologyGraph graph)` and the private `String _graphvizLabel(List<String> lines)`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/graphviz_renderer_test.dart` with exactly this content:

```dart
@@FILE test/graphviz_renderer_test.dart@@
```

- [ ] **Step 2: Run the test and the G22 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/graphviz_renderer_test.dart`
Expected: `+0 -8: Some tests failed.`, each of the 8 tests failing with `UnimplementedError` (T2.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G22; echo "exit: $?"`
Expected: `cases (1 passed, 2 failed, 0 skipped under dart test, restricted to topology-ir G22)`, `exit: 1` (T2.2).

- [ ] **Step 3: Implement `GraphvizRenderer.render` in `lib/src/render/renderers.dart`**

Replace the `GraphvizRenderer` class (its stub `render` included) with exactly this:

```dart
@@BLOCK graphviz_class@@
```

Then add `_graphvizLabel` between `_mermaidLabel` and the `// One arrow:` comment of `_Arrow`, with one blank line before and after it:

```dart
@@BLOCK graphviz_label@@
```

The imports do not change. The file is then 187 lines; `grep -c "UnimplementedError" packages/nidana_dart_contracts/lib/src/render/renderers.dart` prints `0`.

- [ ] **Step 4: Run the tests, the analyzer and the replays**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos`
Expected: `Formatted ... (0 changed)`, at least `+369: All tests passed!` (Task 1's count and the 8 new), `No issues found!` (T2.4).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G22 && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir`
Expected: `PASS behavior ... 3 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G22`, then `PASS behavior` lines with `41 passed` (topic-model@v1), `24 passed` (topology-dsl@v2) and `43 passed, 0 failed, 0 skipped under dart test` (topology-ir@v1), 46 `PASS schema` lines and `120 fixtures: 120 passed, 0 failed, 0 pending` (T2.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/render/renderers.dart packages/nidana_dart_contracts/test/graphviz_renderer_test.dart
git commit -m "feat(dart_contracts): render topology graphs as Graphviz digraphs" -m "<the co-author trailer your harness gives>"
```

### Task 3: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.14.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.14.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 and 2; the gate output; from the controller, the fix rounds each task and review took.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run the gate of Global Constraint 4 exactly (it is the Gate line of the Phase block in `hsdd-context/nidana.model.14.md`), as `(<gate>) > "${TMPDIR:-/tmp}/nidana.model.14-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after. Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+369: All tests passed!` or more, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 43 passed, 0 failed, 0 skipped under dart test` with no `restricted to` (the replay is unrestricted), the 46 `PASS schema` lines of topology-ir@v1 and `120 fixtures: 120 passed, 0 failed, 0 pending`, with no `FAIL`, `ERROR` or `PENDING` line (G). Any other result stops here: a failure is fixed in the task that owns the code or, for a fixture that fails against code that follows this plan, reported as a contract gap (Global Constraints).

The `+369` is this plan's count (353 at the phase base and 16 in two new files); it is higher by the tests the implementers added.

- [ ] **Step 2: Run the checklist**

`<base>` below is the parent of Task 1's commit (`git log --format=%H -n 1 <Task 1's commit>^`). Run each and keep its output:
- `fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G22 ' -r expanded` (expected: the three G22 case names, then `+3: All tests passed!`): the cases this phase turned green, by name, beside the JSON case (C).
- `fvm dart test packages/nidana_dart_contracts/test/mermaid_renderer_test.dart packages/nidana_dart_contracts/test/graphviz_renderer_test.dart -j 1 -r expanded` (expected: at least the 16 test names, 8 and 8 in that order, then `+16: All tests passed!` or more) (C).
- `grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/render; echo "exit: $?"` and `grep -rnE "DateTime\.now\(|Stopwatch\(|Timer\(|Timer\.periodic\(|scheduleMicrotask\(|Future\.delayed\(|Future\.microtask\(|Random\(|Zone\." packages/nidana_dart_contracts/lib; echo "exit: $?"` (expected: no line, `exit: 1`, from each) (C).
- `git diff --name-status <base> HEAD -- packages/nidana_dart_contracts` (expected: four lines, `M` for `lib/src/render/renderers.dart`, `A` for `test/src/render_support.dart`, `test/mermaid_renderer_test.dart` and `test/graphviz_renderer_test.dart`).
- `git status --short pubspec.lock` and `git diff --stat <base> HEAD -- packages/nidana_dart_contracts/pubspec.yaml packages/nidana_dart_contracts/lib/topology_ir.dart` (expected: no output from either).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.14.verification.md` at spot-check depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.14 - Mermaid and Graphviz renderers` (a spaced hyphen; no em-dash anywhere in the file, and not the phrase the run rules ban). Short: commands, expected output, what to eyeball, Learnings.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as Step 1 ran it, saying that it replays topic-model@v1, topology-dsl@v2 and topology-ir@v1 unrestricted, this being topology-ir@v1's last producing phase (D5): topology-dsl@v2's recording suite through `topology_builder_test.dart`, its live suite being bus-api@v2's to bind and nidana.runtime's to replay; topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets in full, the schema set validating `valid/` and `invalid/` against `hsdd/contract/schema/topology-ir.schema.json`, and its `behavior` set through `nidana_dart_contracts_test.dart` with every case, whose G22 cases compare the renderers' real output with the `render/` goldens and the JSON rendering with the `valid/` files; the checklist commands of Step 2.
- **Expected output:** the gate's exit code and lines of Step 1; the checklist's expected results of Step 2.
- **Observed:** dated, with the gate's start and end times, the branch and commit, and Dart 3.13.5 through `fvm`; the gate's exit code and its lines as they appeared; the package count against the plan's and why they differ, if they do; then a checklist of `- [x]` lines, each with its result, to eyeball:
  - the seven samples render to their `render/` goldens byte for byte, the `escaping` sample showing each renderer's escapes: the suite's `G22 the Mermaid and Graphviz renderings of every sample equal its render/ files` and the package's `G22 every sample renders to its render/ .mmd file byte for byte` and `... .dot file byte for byte`;
  - rendering, encoding, decoding and the analyses schedule nothing: the suite's `G22 render passes the graph to the renderer, and renderers are pure`, and each new file's `G22 rendering schedules nothing, ...`, over every sample and every graph the tests build;
  - the gate's topology-ir@v1 replay, 43 of 43 against 41 before this phase, unrestricted, and its schema set's 46 documents;
  - what the goldens leave open, pinned by the package's tests: an anonymous retry, durations above a second that are not whole seconds, a repeated input, one topic name of two variants, characters neither renderer escapes;
  - no `UnimplementedError` remains under `lib/src/render/`, no D6 token under `lib/`, the export lists are unchanged (`exports_test.dart` passes), `purity_test.dart` passes over `renderers.dart` (topic-model@v1 G25, G26), and the lockfile, `pubspec.yaml` and `topology_ir.dart` are unchanged.
- **Outstanding:** `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found the two below; write each that still holds, and any the gate finds:
  - `- No render/ golden of topology-ir@v1 holds an anonymous retry, a duration above a second that is not whole seconds, a repeated input, one topic name of two variants, or a character such as & that the rules leave as it is, so a renderer that writes "retry null", rounds 1500ms down to 1s, collapses repeated arrows, gives two variants of one name one id, or escapes & passes every replay of this node (S149 dry run, seeded defects D4, D6, D7, D12 and D13); this phase's package tests pin all five. Disposition: dropped (reported to hsdd-contract as a low contract gap by S149)`;
  - one sizing line: the phase scope's estimate of about 260 lines in about 3 files against the measured product diff (Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint).
- **Metrics:** one line: the product diff, `git diff --stat <base> HEAD -- packages/`, in files and lines, the library and the tests apart, beside the estimate of about 260 lines in about 3 files, tests included; the task count, 3 of the allowed 5; the fix rounds each task and review took, and any final fix wave, exactly as the controller reports them (none is a valid count; say which commit each round made); package tests at the phase base (353) and now.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.14.verification.md
git commit -m "docs(verify): nidana.model.14 verification" -m "<the co-author trailer your harness gives>"
```
