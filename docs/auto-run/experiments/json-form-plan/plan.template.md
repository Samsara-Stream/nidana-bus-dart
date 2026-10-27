# nidana.model.13 JSON Form Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver topology-ir@v1's JSON form in `packages/nidana_dart_contracts/lib/src/json/codec.dart`: `encodeTopologyGraph` and `encodeTopologyDefinition` (keys in the schema's order, lists in the canonical orders the graph and the definition already hold, `durationMicros`, an input's `dedup` only when the read gave one; G19), `JsonRenderer` (`JsonEncoder.withIndent('  ')` of the encoding, then a newline), and `decodeTopologyGraph` and `decodeTopologyDefinition`, which accept topologies, claims, reads, writes and claimed topics in any order and throw `FormatException`, and no other error, for every value that is not a graph document of this version or breaks a decoder rule (G4, G20, G21), with property tests over seeded generated graphs and mutated documents. The gate's topology-ir@v1 replay, restricted to G2, G4 to G6, G8 to G12 and G19 to G21, then passes 26 of 26 cases (17 today) beside its 46 schema documents.

**Architecture:** One library, `lib/src/json/codec.dart` (nidana.model D4), which nidana.model.5 declared with stubs and `topology_ir.dart` exports by name; no public declaration changes. The encoder is a set of pure functions from the IR to fresh map and list literals, keys inserted in the schema's order, iterating the orders `TopologyGraph`, `TopologyDefinition` and `ShellClaim` already keep; it sorts nothing. The decoder is a set of private functions, one per object of the form, each taking the JSON value and its JSONPath (`$`, `$.topologies[0].transforms[3]`), checking shape with `is` tests (never a cast that can fail), building through the IR's, the claim's and the graph's own factories, and turning the `ArgumentError` those factories throw into a `FormatException` at the path of the object they were building. What no factory checks (a non-negative index before `StageInput` asserts it, a non-empty `typeName`, a dedup only on a state read, the claim source's kind, repeats that a `Set` or the graph would collapse, `reads` and `writes` against the edges, distinct topology ids) the decoder checks itself. Tasks: the encoder with `JsonRenderer`; the decoder reading every document of the right shape; the decoder's rules; the gate and the verification doc.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `dart:convert` (`JsonEncoder.withIndent`, `jsonEncode`) in the library, which topology-ir@v1's Libraries line allows; `package:meta` 1.19.0, the package's only dependency; `package:test` for the package's tests, with `dart:math`'s `Random` seeded inside the tests for generated values; the replay tool `nidana_contract_check` with its `behavior` and `schema` sets.

**Spec:** `hsdd-context/superpowers/nidana.model.13.md` (the derivative; the phase context with topic-model@v1's, topology-dsl@v2's and topology-ir@v1's whole Interface and Guarantees sits between its markers). topology-ir@v1's The JSON form (`hsdd/contract/topology-ir.md`, lines 289 to 351, carried whole in the derivative) and its schema `hsdd/contract/schema/topology-ir.schema.json` are the rules the codec follows. Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D3 (line 102: the declarations stay as nidana.model.5 landed them, getters as final fields), D4 (line 112: the codec and `JsonRenderer` under `lib/src/json/`), D5 (line 128: the gate; this phase runs beside nidana.model.12 and restricts to its own closure, so G3 and G7 stay out of it) and D6 (line 135: `test/purity_test.dart` scans every library under `lib/` for `DateTime.now(`, `Stopwatch(`, `Timer(`, `Timer.periodic(`, `scheduleMicrotask(`, `Future.delayed(`, `Future.microtask(`, `Random(` and `Zone.`, as substrings, comments included, and allows any `dart:` library but `dart:io`, `dart:isolate`, `dart:ffi` and `dart:html`). The fixtures the gate replays: `hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart` through `nidana_dart_contracts_test.dart` (the nine cases of this phase are at lines 566, 1279, 1291, 1304, 1317, 1327, 1353, 1366 and 1422), the 7 files under `valid/`, the 38 under `invalid/` (each `valid/forms.json` with one schema rule broken) and the schema. Evidence: `docs/auto-run/experiments/json-form-plan/` (`run.sh`, `output.txt`, `variants.py`, `defects.py`, `fill_plan.py`, `facts/`, `draft/`), a dry run of this plan's tasks in a temporary copy of HEAD `ec540de`; labels such as S1, F3, T1.2, T3.4, I, X, G, U, C and D7 below name the steps of its `output.txt`. `draft/` is evidence: the test blocks below are the source, each formatter-stable (X), and `variants.py` derives Task 1's and Task 2's `codec.dart` from `draft/lib/src/json/codec.dart`, which is Task 3's.

## Global Constraints

@@CONSTRAINTS@@

Project-wide requirements from the spec and the run, which every task's requirements include:

- **Toolchain:** `fvm dart` only, every command from the repository root, no global tooling. No dependency changes: no `pubspec.yaml` is edited and `pubspec.lock` stays byte-identical.
- **Files:** under `lib/` this phase edits `lib/src/json/codec.dart` alone (Tasks 1 to 3). Every other library stays as it is, and so do the three public libraries' export lists, which `test/exports_test.dart` pins. `lib/src/analysis/` is nidana.model.12's, which runs beside this phase (D5), and `lib/src/render/` nidana.model.14's. Under `test/` this phase creates `test/src/json_support.dart` (Task 1, extended in Task 2) and one test file per code task, and edits no existing test. `README.md`, `CHANGELOG.md` and `LICENSE` stay as they are (D4). Nothing under `hsdd/` changes except the verification doc of Task 4.
- **Interface:** the five public declarations stay exactly as nidana.model.5 landed them, their dartdoc included (it is topology-ir@v1's Interface text). No public declaration is added; every helper is private to `codec.dart` and gets a `//` comment saying what it reads or writes, and `JsonRenderer.render` gets a `//` comment above its `@override` saying what it renders.
- **Encoding:** the encoder returns fresh `<String, Object?>{...}` and `<Object?>[...]` literals, a new value on each call, its keys inserted in the schema's order: a map literal keeps insertion order and `JsonEncoder` writes keys in that order (F1.4). It iterates `graph.topologies`, `graph.claims`, `definition.reads`, `definition.writes`, `definition.transforms`, `edge.inputs` and `claim.writes` as they are, already in canonical order (topology-ir@v1 G6, G11, G12), and sorts nothing. Enums are written by `.name`, a source by `toString()`, a duration by `inMicroseconds`, always an `int` (F2.1).
- **Decoding errors:** every rejection is `FormatException('$path: $problem')`, where `path` is the JSONPath of the place (`$` the document, or the definition object for `decodeTopologyDefinition`; `.key` for a member; `[i]` for an element) and `problem` is one of the exact phrases Tasks 2 and 3 list. A message never renders the value it rejects, which may be large or contain itself; it names a key only when the key is unexpected, through `jsonEncode(key)`. The decoder never casts what it has not tested (`is Map`, `is List`, `is String`, a pattern), catches only `ArgumentError`, and only around a call to an IR, claim or graph factory; any other error escaping it is a defect, which the property tests catch.
- **Purity:** no word of `lib/` may contain a D6 token, in code or comment (substrings: no `Zone.`, no `Random(`, no `Timer(`). The codec reads no clock, creates no timer and schedules nothing (topic-model@v1 G25; topology-ir@v1 G22, whose case first replays at nidana.model.14, pinned here by Task 2's test).
- **Prose:** no em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.
- **Const collections:** topic references, sources, IR values and graphs override `==`, so a non-empty const set of, or a const map keyed by, any of them does not compile; no test of this phase writes one. Const lists are fine, and the tests use them; no test of this phase writes a const set or a const map.
- **Analyzer:** `fvm dart analyze --fatal-infos` at the root reports nothing after every task (T1.4, T2.4, T3.4); `codec.dart` imports exactly what each task's code uses, because an unused import is a warning.
- **Tests:** run from the root as `fvm dart test packages/nidana_dart_contracts`. Each task's failing step also replays the conformance cases of its guarantees with `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee {ids}`, which runs the committed binding under `dart test`; no step and no test of this phase starts `flutter`. Property tests draw from `dart:math`'s `Random(seed)` inside `test/` only, `seeds` (500) seeds each, every expectation's `reason` naming the seed, and assert a floor on what the seeds reach so that a generator change cannot make them vacuous (F4). The package's tests do not repeat the suite's cases; they pin what the suite leaves open: key order and the rendered bytes (the suite compares maps, whose `==` ignores key order, and G22's JSON case is outside the restriction), each rejection's place, and the values the IR's constructors accept that the schema rejects. Add a test beyond the plan's wherever a rule you implement would otherwise go unpinned. No test pins a hash value or uses a `test` API newer than 1.31.1. The 270 package tests of HEAD, topic-model@v1's replay (41 cases) and topology-dsl@v2's (24 cases) pass today and stay green through every task (S1).
- **Contract gaps (ADR-001 item 8):** the dry run passes every fixture the gate replays (G), and the unrestricted topology-ir@v1 `behavior` set passes 41 of 43 cases, the two others calling the Mermaid and Graphviz renderers (nidana.model.14) (U). Two low gaps found while planning do not block (Design decisions 5 and 9). Any fixture that fails against code that follows this plan is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the case, what it reports, the guarantee, and the fix you would propose.
- **Formatting and commits:** run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for a Sonnet implementer.

## Plan check

The derivative's Plan check, run after self-review: the Global Constraints above contain its constraints 1 to 8 verbatim; every `### Task N:` but the last starts with a failing-test step; Task 4 writes `hsdd/verify/nidana.model.13.verification.md`; the plan has 4 tasks of the allowed 6; it is saved as `docs/superpowers/plans/nidana.model.13.md`. `node docs/auto-run/tools/impl-gate.mjs code-plan nidana.model.13` checks the same mechanically and exits 0 on this plan.

## Review Focus

The input classes the spec implies but the conformance suite does not exercise, most likely to bite first; each has its test in the owning task.

1. **`topology-graph.json` diffed in CI, byte for byte:** a catalog run regenerates the file and a check compares it with the committed one. Expected: two-space indentation, a newline at the end, every key in the schema's order, the same bytes for the same graph however its parts were given. The suite's G19 and G20 cases compare decoded maps, whose `==` ignores key order, and G22's JSON case is outside this gate's restriction: the dry run's D2 (an edge's transformer before its output), D3 (no newline) and D4 (four spaces) pass the gate's replay (D). Tests: `G19 an edge carries combinator, inputs, output, transformer, durationMicros and retry in that order, ...`, `G19 a graph built from its parts in any order encodes the same, ...` and `G22 JsonRenderer writes the encoding indented by two spaces, ...` (Task 1); `G20 every valid/ file decodes, and JsonRenderer renders the graph back byte for byte` (Task 2).
2. **A document another tool wrote:** a Python or JavaScript step that rewrites the file with `5000.0` for a duration, or `1.0` for an index. Expected: the integer it equals, as the schema has it (package:json_schema 5.2.2 validates both, F3); a fraction, a negative number, a number at or above 2^63, NaN and infinity rejected with a `FormatException` at that place. The dry run's D13 (only `int` accepted) passes the gate's replay. Tests: `G20 the decoder accepts what the schema allows and no sample holds: ...` (Task 2) and `G21 a Dart value that is no JSON value of the form is rejected ...` (Task 3).
3. **Values the IR's constructors accept and the schema rejects:** a dedup on a replay or event read, an empty `typeName` in reads, writes, an input, an output or a claim, a claim listing one topic twice, the same topology twice. Expected: a `FormatException` at the place, because `TopicInput`, `TopicRef`, a `Set` and `TopologyGraph` would accept or collapse them silently. No `invalid/` file holds a replay dedup, an empty `typeName` or a claim's repeated topic: the dry run's D8, D10 and D11 pass the gate's replay. Tests: `G21 a dedup on an event or a replay read and an empty typeName are rejected, ...` and `G21 a repeated topic in reads, writes or a claim, and a repeated topology id, ...` (Task 3).
4. **A rejection a person has to act on:** a CI log that says only "FormatException". Expected: the JSONPath of the place and what must be there, the factory's argument and message where a factory rejected it, and never the rejected value, which may be large or contain itself. The dry run's D7 (repeats left to the reads comparison) and D16 (a message that renders the value with `jsonEncode`) pass the gate's replay, which checks only the exception's type. Tests: `G21 a value of the wrong shape is rejected with a FormatException that names its JSONPath ...` (Task 2), the 38 `G21 invalid/{name}.json is rejected with a FormatException at the place it breaks a rule` and `G21 a Dart value that is no JSON value of the form is rejected ..., one that contains itself included` (Task 3).
5. **Dart callers that hand the decoder their own collections:** a `Map<Object?, Object?>`, an unmodifiable map or list, a `const` list, a `Set` where an array belongs, a `DateTime` where a string belongs. Expected: the JSON-shaped ones decode, the others are rejected with a `FormatException`, never a `TypeError` from a failed cast. Tests: `G20 the decoder reads Dart maps and lists that jsonDecode does not make: ...` (Task 2) and `G21 a Dart value that is no JSON value of the form is rejected ...` (Task 3).

## Design decisions

Only the decisions this phase settles (review tier spot-check). Each is a decision in `docs/auto-run/steps/S146.json` with its options and evidence.

1. **One library.** Encoder, decoder and renderer share `codec.dart`, its helpers private: the JSON form is one unit whose keys both directions name, and a separate decoder library would add a delegation layer and a second set of src-public names (D4: "the codec and `JsonRenderer`"). The library grows from 26 to 468 lines (C).
2. **Fresh literals for the encoding.** `encodeTopologyGraph` returns a new mutable map on each call; the caller owns it (Task 1's test mutates one). Key order comes from insertion (F1.4).
3. **The factories stay the rule book.** The decoder builds through `TransformEdge.stage`, `.write`, `.reduceInto`, `TopologyDefinition`, `ShellClaim` and `TopologyGraph`, and turns their `ArgumentError` into `FormatException('$path: ${error.name}: ${error.message}')` at the path of the object they were building, instead of restating the stage-edge table and the well-formed-definition rules. It checks itself only what no factory checks. It does not catch `TypeError`, `AssertionError` or `Error`: those are defects, and the property tests fail on them.
4. **JSONPath messages that never render a value.** `FormatException.message` is `'$path: $problem'`. `ArgumentError`'s own `toString()` renders its invalid value, which reads `Instance of 'FunctionRef'` or `Instance of 'TopologySource'` (T3.2), so the factory messages are rebuilt from `name` and `message`.
5. **Whole-number doubles are integers below 2^63.** JSON Schema counts `5000.0` as an integer and package:json_schema 5.2.2 validates it, and `1e30` too (F3); `jsonDecode` returns a `double` for any number with a fraction part or an exponent, and `double.toInt()` clamps at 2^63 (F2.2, F2.3). `_integer` accepts an `int`, or a `double` with no fraction below 2^63, and rejects the rest. A schema-valid document whose duration or index is 2^63 or more cannot be held by `Duration` or an `int`, and the decoder rejects it, which G21's text does not name: a low contract gap (`docs/auto-run/steps/S146.json`).
6. **Objects are maps whose keys are all strings; arrays are lists.** `_object` accepts any `Map` whose keys are all `String`s and reads it through `cast<String, Object?>()`; `_list` accepts any `List`. A `Set` or another `Iterable` is no array.
7. **Order of checks.** An object's required keys in the order the plan lists them, then its unexpected keys in the map's order; members in document order; a definition's `reads` and `writes` compared after `TopologyDefinition` derives its own; topology ids after every topology is read. Each fixture breaks one rule, so the order decides only which of several breaks a message names; the tests pin it.
8. **A generator of its own for the property tests.** `test/src/json_support.dart` generates every combinator with every input form, named and anonymous function references with names the VM renders (private keys, constructor tear-offs), every variant, scope and shell source kind, an empty topic name, durations from zero to 365000 days; the analyses' generator (`test/src/analysis_support.dart`) covers fewer forms. It never gives a dedup to an event or replay read and never an empty `typeName`, which `TopicInput` and `TopicRef` accept and the schema rejects (routed item 6). The mutation generator changes one to three objects or arrays of a generated document; against Task 2's codec it finds 22 documents and 52 definition objects that throw something other than a `FormatException` (F4), so Task 3's property test fails first.
9. **A gap in `invalid/`, not filled here.** No `invalid/` file holds an empty `typeName`, a dedup on a replay read or a claim listing one topic twice, so a decoder that accepts them passes every replay this node runs, nidana.model.14's unrestricted one included (D8, D10, D11). Task 3's tests pin them; the gap goes to hsdd-contract (`docs/auto-run/steps/S146.json`).

## Routed items

Each item `docs/auto-run/impl-execution-plan.md` ("Routed to later phases") routes to this phase, with its disposition:

- (S115) The `dart:convert` import: Task 1 adds `import 'dart:convert';` to `codec.dart` for `JsonEncoder.withIndent`, and Task 2 uses its `jsonEncode` for an unexpected key's name.
- (S135) Check a `StageInput` index before constructing, since the constructor's assert is an `AssertionError` under `dart test`: Task 3, `_integer` rejects a negative index at `.edge` before `StageInput` is built; tests `G21 invalid/input_edge_negative.json ...` and `G21 an edge index below zero is rejected before StageInput would assert it`; the dry run's D12 fails both and the gate's G21 case.
- (S135, S141) Convert the IR factories', `ShellClaim`'s and `TopologyGraph`'s `ArgumentError` to `FormatException`: Task 3, `_build` around every factory call, at the path of the object being built; twelve `invalid/` files reach it; D14. `TopologyGraph`'s rejection cannot arise after the raw id check, and its call goes through `_build` all the same.
- (S135, S141) Check raw repeats of reads, writes, topology ids and claim topics on the JSON lists before constructing: Task 3, `_decodeTopics` (reads, writes, a claim's writes) and `_checkDistinctIds`; tests `G21 invalid/reads_repeat_topic.json ...`, `G21 invalid/topologies_repeat.json ...` and `G21 a repeated topic in reads, writes or a claim, ...`; D6, D7, D8. The `invalid/claim_*.json` files cover a claim's source, scope and writes rules, which `_build` and the source check reject; none repeats a topic, so the package test pins that.
- (S135, sweep item) Reject a dedup on an event or replay read and an empty `typeName`, which `TopicInput` and `TopicRef` accept: Task 3, in `_decodeInput` and `_decodeTopic`; test `G21 a dedup on an event or a replay read and an empty typeName are rejected, ...`; D10, D11.
- (S135) The round-trip generators avoid both: Task 2, `test/src/json_support.dart`'s `_read` gives a dedup to a state read only, and `generatedTopics` holds no empty `typeName` (Design decision 8).
- (S141, Task 4 review) A decoded document with two sinks on one state topic reaches `TopologyDefinition`'s second-sink message, reworded in S141: Task 3 passes it through `_build` as `$.topologies[0]: transforms: edge 5 is a second sink edge on this state topic, ...`, pinned by `G21 a schema-valid document that breaks a rule the schema cannot state ...`.

## Which task turns which failing case green

The gate's topology-ir@v1 replay, restricted to G2, G4 to G6, G8 to G12 and G19 to G21, runs 26 cases and passes 17 today, all of nidana.model.10's and nidana.model.11's guarantees; the nine it fails call the codec, whose stubs throw `UnimplementedError` (S1). Its schema set passes its 46 documents today and after every task.

| Task | Cases turned green | Replay |
|------|--------------------|--------|
| 1 | `G19 the encoding of every sample graph matches the schema and equals its valid/ file`, `G19 a definition encodes to the object its graph document lists` | `--guarantee G19` from 0 passed, 2 failed to 2 passed (T1.2, T1.4) |
| 2 | `G4 every definition a plan projects to is pure data: it encodes to JSON and decodes back equal`, the three G20 cases (`every valid/ file decodes and re-encodes to an equal JSON value`, `decoding the encoding of a graph gives the graph back`, `the decoder accepts topologies, claims, reads, writes and claimed topics in any order`), and `G21 the decoder rejects any other value with a FormatException and no other error` | `--guarantee G4,G20,G21` from 0 passed, 7 failed to 5 passed, 2 failed (T2.2, T2.4) |
| 3 | `G21 every invalid/ file fails the schema and the decoder rejects it with a FormatException`, `G21 the decoder rejects a schema-valid document that breaks a rule the schema cannot state` | `--guarantee G21` from 1 passed, 2 failed to 3 passed; the gate's restriction then passes 26 of 26 (T3.2, T3.4) |

After Task 3 the topology-ir@v1 `behavior` set, unrestricted, passes 41 of 43: G22's JSON case (`G22 the JSON rendering of every sample is its valid/ file, byte for byte`) passes ahead of its phase, and the two G22 cases that call `MermaidRenderer` and `GraphvizRenderer` wait for nidana.model.14 (U).

**The phase's Verification line**, and where each part is checked: every `invalid/` document fails the decoder with a `FormatException` and nothing else (the suite's `G21 every invalid/ file fails the schema and ...`, which also checks that the schema rejects each; Task 3's 38 per-file tests, which pin each one's place, and `I` of the dry run); each sample's encoding matches the schema and equals its `valid/` file (the suite's `G19 the encoding of every sample graph ...`, through `expectMatchesSchema`, and Task 2's `G20 every valid/ file decodes, and JsonRenderer renders the graph back byte for byte`, which compares the bytes).

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/json/codec.dart` | 1, 2, 3 | The encoder and `JsonRenderer` (1); the decoder's readers of every object of the form (2); the decoder's rules and the factories' rejections (3) |
| `{pkg}/test/src/json_support.dart` | 1, 2 | Create: the fixture readers and the Interface's example (1); the seeded graph generator (2) |
| `{pkg}/test/json_encode_test.dart` | 1 | Create: key order, edge and input forms, durations, function references, claims, rendered text |
| `{pkg}/test/json_decode_test.dart` | 2 | Create: valid/ bytes, what the schema allows, Dart collections, shape messages, round trips and any order over generated graphs, no scheduled work |
| `{pkg}/test/json_reject_test.dart` | 3 | Create: each invalid/ file's message, rules the schema cannot state, the constructors' leniencies, repeats, Dart values, mutated and arbitrary values |
| `hsdd/verify/nidana.model.13.verification.md` | 4 | The verification doc |

---

### Task 1: The encoder and JsonRenderer

You are filling in three of the five stubs nidana.model.5 left in `packages/nidana_dart_contracts/lib/src/json/codec.dart`: `encodeTopologyGraph`, `encodeTopologyDefinition` and `JsonRenderer.render`. The two decoders stay `throw UnimplementedError()` until Task 2. Run every command from the repository root with `fvm dart`. Change no public declaration (Global Constraints, Interface). This task turns the suite's two G19 cases green.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/json/codec.dart` (all 26 lines)
- Create: `packages/nidana_dart_contracts/test/src/json_support.dart`
- Create: `packages/nidana_dart_contracts/test/json_encode_test.dart`

**Interfaces:**
- Consumes (landed by nidana.model.4, .5, .10 and .11): `TopologyGraph` (`topologies`, by id; `claims`, canonical), `ShellClaim` (`source`, `scope`, `writes`, canonical), `TopologyDefinition` (`topologyId`, `scope`, `reads` and `writes`, canonical; `transforms`), `TransformEdge` (`combinator`, null for a write; `inputs`; `output`; `transformer`; `duration`; `retry`), `TopicInput` (`topic`, `dedup`), `StageInput` (`edge`), `TopicRef` (`name`, `variant`, `typeName`), `FunctionRef` (`name`, null when anonymous), `MessageSource.toString()`, the enums' `name`; `GraphRenderer` and `TopologyGraph.render`; `workspaceRoot()` from `test/src/package_files.dart`; `topology(...)` and `buildDefinition()` for the test's recorded sample.
- Produces: `Map<String, Object?> encodeTopologyGraph(TopologyGraph graph)`, `Map<String, Object?> encodeTopologyDefinition(TopologyDefinition definition)`, `JsonRenderer.render(TopologyGraph graph)`, and, private to `codec.dart`, `const String _format = 'topology-ir@v1'`, which Task 2's decoder compares a document's `format` with, and `const JsonEncoder _indented = JsonEncoder.withIndent('  ')`. In `test/src/json_support.dart`: `String fixtureText(String relative)`, `Object? fixtureJson(String relative)` (both relative to `hsdd/contract/fixture/topology-ir/`), `const String interfaceExample` and `TopologyGraph interfaceExampleGraph()`, which Tasks 2 and 3 use.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/src/json_support.dart` with exactly this content (Task 2 adds to it):

```dart
@@SUPPORT_T1@@
```

Create `packages/nidana_dart_contracts/test/json_encode_test.dart` with exactly this content:

```dart
@@FILE test/json_encode_test.dart@@
```

- [ ] **Step 2: Run the test and the G19 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/json_encode_test.dart`
Expected: `+0 -10: Some tests failed.`, each test failing with `UnimplementedError` (T1.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G19; echo "exit: $?"`
Expected: `FAIL behavior ... cases (0 passed, 2 failed, 0 skipped under dart test, restricted to topology-ir G19)`, `exit: 1` (T1.2).

- [ ] **Step 3: Implement the encoder and `JsonRenderer.render` in `lib/src/json/codec.dart`**

Keep the five public declarations and their dartdoc where they are. Imports: `dart:convert`, `../graph/graph.dart`, `../ir/definition.dart`, `../ir/function_ref.dart` and `../topic/topic.dart` (for `TopicRef` and `Dedup`). After `JsonRenderer`, the private constants `_format` and `_indented` (Interfaces), then the encoders, each with a `//` comment:

- `encodeTopologyGraph(graph)`: `{'format': _format, 'topologies': [encodeTopologyDefinition of each of graph.topologies], 'claims': [_encodeClaim of each of graph.claims]}`.
- `encodeTopologyDefinition(definition)`: `{'topologyId': ..., 'scope': scope.name, 'reads': [_encodeTopic ...], 'writes': [_encodeTopic ...], 'transforms': [_encodeEdge ...]}`.
- `Map<String, Object?> _encodeEdge(TransformEdge edge)`: `'combinator': combinator.name` only when `combinator` is not null (a write has none), then `'inputs'`, then `'output'`, `'transformer'`, `'durationMicros'` (`duration.inMicroseconds`) and `'retry'`, each only when the edge holds it, in that order; a collection `if (edge.output case final TopicRef output) 'output': ...` writes each.
- `Map<String, Object?> _encodeInput(EdgeInput input)`: a switch over the sealed `EdgeInput`: `TopicInput` gives `{'topic': _encodeTopic(topic)}` with `'dedup': dedup.name` after it only when `dedup` is not null; `StageInput` gives `{'edge': edge}`.
- `Map<String, Object?> _encodeTopic(TopicRef topic)`: `{'name', 'variant': variant.name, 'typeName'}`.
- `Map<String, Object?> _encodeFunction(FunctionRef function)`: `{'name': function.name}`, null for an anonymous one.
- `Map<String, Object?> _encodeClaim(ShellClaim claim)`: `{'source': source.toString(), 'scope': scope.name, 'writes': [_encodeTopic ...]}`.
- `JsonRenderer.render(graph)`: `'${_indented.convert(encodeTopologyGraph(graph))}\n'`, with a `//` comment above `@override`.

`decodeTopologyGraph` and `decodeTopologyDefinition` keep `=> throw UnimplementedError();`.

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G19`
Expected: `+280: All tests passed!`, `No issues found!`, `PASS behavior ... 2 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G19` (T1.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/json/codec.dart packages/nidana_dart_contracts/test/src/json_support.dart packages/nidana_dart_contracts/test/json_encode_test.dart
git commit -m "feat(dart_contracts): encode topology graphs and render them as JSON" -m "<the co-author trailer your harness gives>"
```

### Task 2: The decoder reads every graph document

You are filling in `decodeTopologyGraph` and `decodeTopologyDefinition` in `packages/nidana_dart_contracts/lib/src/json/codec.dart` so that every document of the right shape decodes, in any list order, and every value of the wrong shape (a wrong JSON type, a missing or unexpected key, an unknown name, another format) is rejected with a `FormatException` at its JSONPath. The rules that remain, the factories' rejections included, are Task 3's: after this task the decoder still lets some `ArgumentError` and one `AssertionError` through, by design (F4). Run every command from the repository root with `fvm dart`. This task turns G4, the three G20 cases and `G21 the decoder rejects any other value ...` green.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/json/codec.dart`
- Modify: `packages/nidana_dart_contracts/test/src/json_support.dart`
- Create: `packages/nidana_dart_contracts/test/json_decode_test.dart`

**Interfaces:**
- Consumes: Task 1's encoder, `_format` and `JsonRenderer`, and `fixtureText`, `fixtureJson`, `interfaceExample` and `interfaceExampleGraph()`; the factories `TransformEdge.stage(CombinatorKind, List<EdgeInput>, {FunctionRef? transformer, Duration? duration, FunctionRef? retry})`, `TransformEdge.write(TopicRef, EdgeInput)`, `TransformEdge.reduceInto(TopicRef, EdgeInput, FunctionRef)`, `TopologyDefinition({required String topologyId, required Scope scope, required List<TransformEdge> transforms})`, `ShellClaim({required MessageSource source, Scope scope, required Set<TopicRef> writes})`, `TopologyGraph({Iterable<TopologyDefinition> topologies, Iterable<ShellClaim> claims})`; the constructors `TopicRef(...)`, `TopicInput(TopicRef, {Dedup? dedup})`, `StageInput(int)`, `FunctionRef.named(String)`, `FunctionRef.anonymous()`; `MessageSource.tryParse(String)`, null for any text that is no rendering (topic-model@v1 G17).
- Produces: the two decoders, and these private functions of `codec.dart`, which Task 3 extends (each `path` is the JSONPath of `json`):
  - `TopologyDefinition _decodeDefinition(Object? json, String path)`; `decodeTopologyDefinition(json)` is `_decodeDefinition(json, r'$')`.
  - `TransformEdge _decodeEdge(Object? json, String path)`, `EdgeInput _decodeOneInput(Object? json, String path)`, `EdgeInput _decodeInput(Object? json, String path)`, `TopicRef _decodeTopic(Object? json, String path)`, `List<TopicRef> _decodeTopics(Object? json, String path)`, `FunctionRef _decodeFunction(Object? json, String path)`, `ShellClaim _decodeClaim(Object? json, String path)`.
  - `Map<String, Object?> _object(Object? json, String path, Set<String> required, [Set<String> optional = const <String>{}])`, `List<T> _list<T>(Object? json, String path, T Function(Object? json, String path) decode)`, `String _string(Object? json, String path)`, `int _integer(Object? json, String path)`, `T _named<T extends Enum>(List<T> values, Object? json, String path)`, `Never _reject(String path, String problem)`.
  - In `test/src/json_support.dart`: `const int seeds = 500`, `List<String> fixtureNames(String set)`, `generatedTopics`, `generatedFunctions`, `generatedDurations`, `generatedSources`, `generatedIds`, `TopologyDefinition generatedDefinition(Random random, String id)`, `ShellClaim generatedClaim(Random random)` and `TopologyGraph generatedGraph(int seed)`, which Task 3 uses.

- [ ] **Step 1: Write the failing test**

In `packages/nidana_dart_contracts/test/src/json_support.dart`, add `import 'dart:math';` after `import 'dart:io';`, and append this at the end of the file, after `interfaceExampleGraph`:

```dart
@@SUPPORT_GENERATED@@
```

Create `packages/nidana_dart_contracts/test/json_decode_test.dart` with exactly this content:

```dart
@@FILE test/json_decode_test.dart@@
```

- [ ] **Step 2: Run the test and the replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/json_decode_test.dart`
Expected: `+1 -9: Some tests failed.`: the nine tests that call a decoder fail with `UnimplementedError`; `G20 the generated graphs reach every combinator, ...`, which checks the generator alone, passes (T2.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G4,G20,G21; echo "exit: $?"`
Expected: `cases (0 passed, 7 failed, 0 skipped under dart test, restricted to topology-ir G4, G20, G21)`, `exit: 1` (T2.2).

- [ ] **Step 3: Implement the decoder's readers in `lib/src/json/codec.dart`**

Add the imports `../topic/message_source.dart` and `../topic/scope.dart`. The decoders and the helpers below follow the encoders, after a `//` comment that says what every decoder does with its `path`. Every rejection goes through `Never _reject(String path, String problem) => throw FormatException('$path: $problem');`. The exact problems, which Task 2's and Task 3's tests pin:

| Where | Rejects | `$path: $problem` |
|-------|---------|-------------------|
| `_object` | not a `Map`, or a key that is not a `String` | `{path}: must be an object` |
| `_object` | a required key absent, the first in `required`'s order | `{path}.{key}: is missing` |
| `_object` | a key in neither set, the first in the map's order, after the required check | `{path}: must not have the key {jsonEncode(key)}` |
| `_list` | not a `List` | `{path}: must be an array` |
| `_string` | not a `String` | `{path}: must be a string` |
| `_integer` | not an integer, as below | `{path}: must be an integer` (Task 3 changes it) |
| `_named` | not a `String` naming one of `values` | `{path}: must be one of {the names joined by ', '}` |
| `decodeTopologyGraph` | `format` other than `_format` | `$.format: must be "topology-ir@v1"` |
| `_decodeOneInput` | not exactly one element | `{path}: must hold exactly one input` |
| `_decodeFunction` | `name` neither a `String` nor null | `{path}.name: must be a string or null` (Task 3 changes it) |
| `_decodeClaim` | `MessageSource.tryParse` of the source gives null | `{path}.source: must be "service:", "page:" or "executor:" followed by a name` |

What each reads, in this order:

- `decodeTopologyGraph(json)`: `_object(json, r'$', const <String>{'format', 'topologies', 'claims'})`; the format check; `_list(document['topologies'], r'$.topologies', _decodeDefinition)`; `_list(document['claims'], r'$.claims', _decodeClaim)`; then `TopologyGraph(topologies: ..., claims: ...)`.
- `_decodeDefinition`: `_object` with required `topologyId`, `scope`, `reads`, `writes`, `transforms`; `_string` of `topologyId`; `_named(Scope.values, ...)` of `scope`; `_decodeTopics` of `reads` and of `writes`, read for their shape only in this task (call them as statements, since an unused local is a warning); `_list(..., _decodeEdge)` of `transforms`; then `TopologyDefinition(...)`.
- `_decodeEdge`: when `json` is not a `Map` or has no `combinator` key, a write: `_object` with required `inputs`, `output`, then `_decodeOneInput` of `inputs`, `_decodeTopic` of `output`, `TransformEdge.write(output, input)`. Else `_named(CombinatorKind.values, json['combinator'], '$path.combinator')`; for `reduceInto`, `_object` with required `combinator`, `inputs`, `output`, `transformer`, then `_decodeOneInput`, `_decodeTopic`, `_decodeFunction`, `TransformEdge.reduceInto(output, events, reducer)`; for any other kind, `_object` with required `combinator`, `inputs` and optional `transformer`, `durationMicros`, `retry`, then `_list(..., _decodeInput)` of `inputs`, `_decodeFunction` of `transformer` and of `retry` when present, `Duration(microseconds: _integer(...))` of `durationMicros` when present, and `TransformEdge.stage(kind, inputs, transformer: ..., duration: ..., retry: ...)`, which decides what the kind holds.
- `_decodeOneInput`: `_list(json, path, _decodeInput)`, exactly one element.
- `_decodeInput`: when `json` is a `Map` with an `edge` key, `_object` with required `edge`, then `StageInput(_integer(...))`; else `_object` with required `topic` and optional `dedup`, `_decodeTopic` of `topic`, and `TopicInput(topic)`, or `TopicInput(topic, dedup: _named(Dedup.values, ...))` when `dedup` is present.
- `_decodeTopic`: `_object` with required `name`, `variant`, `typeName`; `_string`, `_named(TopicVariant.values, ...)`, `_string`; `TopicRef(...)`. An empty `name` is fine: the schema allows one (F3).
- `_decodeTopics`: `_list(json, path, _decodeTopic)`.
- `_decodeFunction`: `_object` with required `name`; null gives `const FunctionRef.anonymous()`, a `String` `FunctionRef.named(name)`.
- `_decodeClaim`: `_object` with required `source`, `scope`, `writes`; the source as above; `_named(Scope.values, ...)`; `_decodeTopics` of `writes`; `ShellClaim(source: ..., scope: ..., writes: writes.toSet())`.
- `_object`: test `json is! Map || json.keys.any((Object? key) => key is! String)` first, then read through `json.cast<String, Object?>()`; required keys in the set literal's order, then unexpected keys.
- `_list`: `<T>[for (int i = 0; i < json.length; i++) decode(json[i], '$path[$i]')]`.
- `_named`: `values.asNameMap()[json]` when `json` is a `String`, never `values.byName`, which throws `ArgumentError` for an unknown name (F2.4).
- `_integer`, in this task, accepts any whole number below 2^63 in magnitude (Task 3 adds the sign):

```dart
@@INTEGER_T2@@
```

- [ ] **Step 4: Run the tests, the analyzer and the same replay**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G4,G20,G21; echo "exit: $?"`
Expected: `+290: All tests passed!`, `No issues found!`, then `cases (5 passed, 2 failed, ...)`, the two failed cases `G21 every invalid/ file fails the schema ...` and `G21 the decoder rejects a schema-valid document that breaks a rule ...`, which Task 3 turns green, and `exit: 1` (T2.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/json/codec.dart packages/nidana_dart_contracts/test/src/json_support.dart packages/nidana_dart_contracts/test/json_decode_test.dart
git commit -m "feat(dart_contracts): decode topology graph documents of the right shape" -m "<the co-author trailer your harness gives>"
```

### Task 3: The decoder's rules

You are completing the decoder in `packages/nidana_dart_contracts/lib/src/json/codec.dart` with every rule Task 2 left out: the factories' `ArgumentError` becomes a `FormatException`, and the decoder checks what no factory checks. Run every command from the repository root with `fvm dart`. This task turns the last two G21 cases green, and with them the gate's restriction, 26 of 26.

**Files:**
- Modify: `packages/nidana_dart_contracts/lib/src/json/codec.dart`
- Create: `packages/nidana_dart_contracts/test/json_reject_test.dart`

**Interfaces:**
- Consumes: Task 2's decoder and helpers; `seeds`, `fixtureNames`, `fixtureJson` and `generatedGraph(int seed)` from `test/src/json_support.dart`; the factories' rejections, each `ArgumentError.value(value, name, message)` (nidana.model.10 and .11).
- Produces: `T _build<T>(String path, T Function() build)`, `void _checkDistinctIds(List<TopologyDefinition> topologies, String path)` and `void _checkSameTopics(List<TopicRef> listed, Set<TopicRef> derived, String path, String what)`, private to `codec.dart`. Nothing later calls them.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/json_reject_test.dart` with exactly this content:

```dart
@@FILE test/json_reject_test.dart@@
```

- [ ] **Step 2: Run the test and the G21 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/json_reject_test.dart`
Expected: `+19 -27: Some tests failed.`; the failures show the factories' `ArgumentError`, an `AssertionError` for `invalid/input_edge_negative.json`, documents accepted that must be rejected, and the Task 2 messages Task 3 changes (T3.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G21; echo "exit: $?"`
Expected: `cases (1 passed, 2 failed, 0 skipped under dart test, restricted to topology-ir G21)`, `exit: 1` (T3.2).

- [ ] **Step 3: Add the rules to the decoder in `lib/src/json/codec.dart`**

Every factory call of the decoder goes through `_build` at the path of the object it builds (the graph at `$`, a definition, an edge, a claim); read every member before it, so that only the factory runs inside the closure:

```dart
@@BUILD@@
```

The checks, each a `_reject` with the exact problem:

| Where | Rejects | `$path: $problem` |
|-------|---------|-------------------|
| `_integer` | a negative number, as below | `{path}: must be a non-negative integer` (replaces `must be an integer`) |
| `_decodeTopic` | an empty `typeName`, after reading it | `{path}.typeName: must not be empty` |
| `_decodeInput` | a `dedup` on a read whose topic is not a state topic, after reading the dedup | `{path}.dedup: may be given only on a read of a state topic` |
| `_decodeTopics` | a topic equal to an earlier one of the array (a `Map<TopicRef, int>` of first indices) | `{path}[{i}]: repeats {path}[{first}]` |
| `_decodeFunction` | an empty name (the `String` case gets `when name.isNotEmpty`) | `{path}.name: must be a non-empty string or null` (replaces `must be a string or null`) |
| `_decodeClaim` | a source `tryParse` reads as a topology or unknown source (a switch whose case is `final MessageSource s && (ServiceSource() \|\| PageSource() \|\| ExecutorSource())`) | `{path}.source: must be "service:", "page:" or "executor:" followed by a name` (unchanged) |
| `_checkDistinctIds`, after the topologies are read | a topology id equal to an earlier one (a `Map<String, int>` of first indices) | `$.topologies[{i}].topologyId: repeats the id of $.topologies[{first}]` |
| `_checkSameTopics`, in `_decodeDefinition` after `TopologyDefinition` is built: reads, then writes | a `reads` (`writes`) array whose topics are not exactly `definition.reads` (`definition.writes`); with no repeat in the array, its length and `containsAll` decide | `{path}.reads: must list each topic the edges read, once`, `{path}.writes: must list each topic the sink edges write, once` |
| `_build` | an `ArgumentError` of the factory | `{path}: {error.name}: {error.message}` |

`_decodeDefinition` now keeps `reads` and `writes` as locals for `_checkSameTopics`. `_integer` becomes:

```dart
@@INTEGER@@
```

- [ ] **Step 4: Run the tests, the analyzer and the replays**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G21 && fvm dart run nidana_contract_check topology-ir --guarantee G2,G4,G5,G6,G8,G9,G10,G11,G12,G19,G20,G21`
Expected: `+336: All tests passed!`, `No issues found!`, `PASS behavior ... 3 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G21`, then `PASS behavior ... 26 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G4 to G6, G8 to G12, G19 to G21` and `61 fixtures: 61 passed, 0 failed, 0 pending` (T3.4). `grep -c "UnimplementedError" packages/nidana_dart_contracts/lib/src/json/codec.dart` prints `0`.

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/json/codec.dart packages/nidana_dart_contracts/test/json_reject_test.dart
git commit -m "feat(dart_contracts): reject every value that is no topology graph document" -m "<the co-author trailer your harness gives>"
```

### Task 4: Gate and verification doc

You write the phase's verification doc after running its gate. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.13.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.13.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 3; the gate output.
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Run the gate of Global Constraint 4 exactly (it is the Gate line of the Phase block in `hsdd-context/nidana.model.13.md`), as `(<gate>) > "${TMPDIR:-/tmp}/nidana.model.13-gate.txt" 2>&1; echo "exit: $?"`, then read the file. Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ` before and after. Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+336: All tests passed!`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test`, `59 fixtures: 59 passed, 0 failed, 0 pending`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 26 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G4 to G6, G8 to G12, G19 to G21`, the 46 `PASS schema` lines of topology-ir@v1 (the schema, 38 `invalid/` and 7 `valid/` documents) and `61 fixtures: 61 passed, 0 failed, 0 pending`, with no `FAIL`, `ERROR` or `PENDING` line (G). Any other result stops here: a failure is fixed in the task that owns the code or, for a fixture that fails against code that follows this plan, reported as a contract gap (Global Constraints).

The `+336` is this plan's count (270 at the phase base and 66 in three new files); it is higher by the tests the implementers added.

- [ ] **Step 2: Run the checklist**

`<base>` below is the parent of Task 1's commit (`git log --format=%H -n 1 <Task 1's commit>^`). Run each and keep its output:
- `fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G(4|19|20|21) ' -r expanded` (expected: the nine case names of G4, G19, G20 and G21, then `+9: All tests passed!`): the cases this phase turned green, by name (C).
- `fvm dart test packages/nidana_dart_contracts/test/json_encode_test.dart packages/nidana_dart_contracts/test/json_decode_test.dart packages/nidana_dart_contracts/test/json_reject_test.dart -j 1 -r expanded` (expected: the 66 test names, 10, 10 and 46 in that order, then `+66: All tests passed!`) (X).
- `fvm dart run nidana_contract_check topology-ir --set behavior; echo "exit: $?"` (expected: `exit: 1` and `cases (41 passed, 2 failed, ...)`; the two failed are `G22 the Mermaid and Graphviz renderings of every sample equal its render/ files` and `G22 render passes the graph to the renderer, and renderers are pure`, which call the renderers nidana.model.14 delivers; `G22 the JSON rendering of every sample is its valid/ file, byte for byte` passes) (U).
- `grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/json; echo "exit: $?"` and `grep -rnE "DateTime\.now\(|Stopwatch\(|Timer\(|Timer\.periodic\(|scheduleMicrotask\(|Future\.delayed\(|Future\.microtask\(|Random\(|Zone\." packages/nidana_dart_contracts/lib; echo "exit: $?"` (expected: no line, `exit: 1`, from each) (C).
- `git diff --name-status <base> HEAD -- packages/nidana_dart_contracts` (expected: five lines, `M` for `lib/src/json/codec.dart`, `A` for `test/src/json_support.dart`, `test/json_encode_test.dart`, `test/json_decode_test.dart` and `test/json_reject_test.dart`).
- `git status --short pubspec.lock` and `git diff --stat <base> HEAD -- packages/nidana_dart_contracts/pubspec.yaml packages/nidana_dart_contracts/lib/topology_ir.dart` (expected: no output from either).

- [ ] **Step 3: Write `hsdd/verify/nidana.model.13.verification.md` at spot-check depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.13 - JSON form` (a spaced hyphen; no em-dash anywhere in the file). Short: commands, expected output, what to eyeball, Learnings.

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate as Step 1 ran it, saying that it replays topic-model@v1 and topology-dsl@v2 unrestricted (topology-dsl@v2's recording suite through `topology_builder_test.dart`, its live suite being bus-api@v2's to bind and nidana.runtime's to replay), and topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets in full, the schema set validating `valid/` and `invalid/` against `hsdd/contract/schema/topology-ir.schema.json`, and its `behavior` set through `nidana_dart_contracts_test.dart` restricted to G2, G4 to G6, G8 to G12 and G19 to G21, whose G19 and G20 cases check the codec's real output with `expectMatchesSchema`; the checklist commands of Step 2.
- **Expected output:** the gate's exit code and lines of Step 1; the checklist's expected results of Step 2.
- **Observed:** dated, with the gate's start and end times, the branch and commit, and Dart 3.13.5 through `fvm`; the gate's exit code and its lines as they appeared; then a checklist of `- [x]` lines, each with its result, to eyeball:
  - every `invalid/` document fails the decoder with a `FormatException` and nothing else: the suite's `G21 every invalid/ file fails the schema and ...` and the 38 package tests `G21 invalid/{name}.json is rejected with a FormatException at the place it breaks a rule`;
  - each sample's encoding matches the schema and equals its `valid/` file: the suite's `G19 the encoding of every sample graph ...` and the package's `G20 every valid/ file decodes, and JsonRenderer renders the graph back byte for byte`;
  - the gate's topology-ir@v1 replay, 26 of 26 against 17 before this phase, its schema set's 46 documents, and the unrestricted count (41 of 43), naming G22's JSON case, which passes ahead of its phase, and the two G22 cases that wait for nidana.model.14;
  - what the gate's replay leaves open, pinned by the package's tests: key order and the rendered bytes, each rejection's place, a dedup on a replay read, an empty `typeName`, a claim's repeated topic, whole-number doubles, and the property tests' seeds (500 each);
  - no `UnimplementedError` remains under `lib/src/json/`, no D6 token under `lib/`, the export lists are unchanged (`exports_test.dart` passes), `purity_test.dart` passes over `codec.dart` with its `dart:convert` import (topic-model@v1 G25, G26), and the lockfile, `pubspec.yaml` and `topology_ir.dart` are unchanged.
- **Outstanding:** `None.`, unless a Step 1 or Step 2 command could not run here; then say what it takes to run it.
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Planning found the three below; write each that still holds, and any the gate finds:
  - `- topology-ir@v1's schema states no upper bound for durationMicros or an input's edge, and package:json_schema 5.2.2 validates 1e30 for either, while the Dart IR holds a Duration and an int, so the decoder rejects a whole number of 2^63 or more with a FormatException that no decoder rule of The JSON form names; the text "an integer" also leaves whole-number doubles such as 5000.0 implicit, which the schema accepts and this decoder reads as the integer they equal (S146 dry run, F2 and F3). Disposition: dropped (reported to hsdd-contract as a low contract gap by S146)`;
  - `- No invalid/ file of topology-ir@v1 holds an empty typeName, a dedup on a replay read or a claim that lists one topic twice, so a decoder that accepts any of them passes every replay of this node, nidana.model.14's unrestricted one included (S146 dry run, seeded defects D8, D10 and D11); this phase's package tests pin all three. Disposition: dropped (reported to hsdd-contract as a low contract gap by S146)`;
  - one sizing line: the phase scope's estimate of about 420 lines in about 4 files against the measured product diff (Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint).
- **Metrics:** one line: the product diff, `git diff --stat <base> HEAD -- packages/`, in files and lines, the library and the tests apart, beside the estimate of about 420 lines in about 4 files, tests included; the task count, 4 of the allowed 6.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.13.verification.md
git commit -m "docs(verify): nidana.model.13 verification" -m "<the co-author trailer your harness gives>"
```
