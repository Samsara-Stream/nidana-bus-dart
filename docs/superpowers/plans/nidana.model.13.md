# nidana.model.13 JSON Form Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver topology-ir@v1's JSON form in `packages/nidana_dart_contracts/lib/src/json/codec.dart`: `encodeTopologyGraph` and `encodeTopologyDefinition` (keys in the schema's order, lists in the canonical orders the graph and the definition already hold, `durationMicros`, an input's `dedup` only when the read gave one; G19), `JsonRenderer` (`JsonEncoder.withIndent('  ')` of the encoding, then a newline), and `decodeTopologyGraph` and `decodeTopologyDefinition`, which accept topologies, claims, reads, writes and claimed topics in any order and throw `FormatException`, and no other error, for every value that is not a graph document of this version or breaks a decoder rule (G4, G20, G21), with property tests over seeded generated graphs and mutated documents. The gate's topology-ir@v1 replay, restricted to G2, G4 to G6, G8 to G12 and G19 to G21, then passes 26 of 26 cases (17 today) beside its 46 schema documents.

**Architecture:** One library, `lib/src/json/codec.dart` (nidana.model D4), which nidana.model.5 declared with stubs and `topology_ir.dart` exports by name; no public declaration changes. The encoder is a set of pure functions from the IR to fresh map and list literals, keys inserted in the schema's order, iterating the orders `TopologyGraph`, `TopologyDefinition` and `ShellClaim` already keep; it sorts nothing. The decoder is a set of private functions, one per object of the form, each taking the JSON value and its JSONPath (`$`, `$.topologies[0].transforms[3]`), checking shape with `is` tests (never a cast that can fail), building through the IR's, the claim's and the graph's own factories, and turning the `ArgumentError` those factories throw into a `FormatException` at the path of the object they were building. What no factory checks (a non-negative index before `StageInput` asserts it, a non-empty `typeName`, a dedup only on a state read, the claim source's kind, repeats that a `Set` or the graph would collapse, `reads` and `writes` against the edges, distinct topology ids) the decoder checks itself. Tasks: the encoder with `JsonRenderer`; the decoder reading every document of the right shape; the decoder's rules; the gate and the verification doc.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `dart:convert` (`JsonEncoder.withIndent`, `jsonEncode`) in the library, which topology-ir@v1's Libraries line allows; `package:meta` 1.19.0, the package's only dependency; `package:test` for the package's tests, with `dart:math`'s `Random` seeded inside the tests for generated values; the replay tool `nidana_contract_check` with its `behavior` and `schema` sets.

**Spec:** `hsdd-context/superpowers/nidana.model.13.md` (the derivative; the phase context with topic-model@v1's, topology-dsl@v2's and topology-ir@v1's whole Interface and Guarantees sits between its markers). topology-ir@v1's The JSON form (`hsdd/contract/topology-ir.md`, lines 289 to 351, carried whole in the derivative) and its schema `hsdd/contract/schema/topology-ir.schema.json` are the rules the codec follows. Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D3 (line 102: the declarations stay as nidana.model.5 landed them, getters as final fields), D4 (line 112: the codec and `JsonRenderer` under `lib/src/json/`), D5 (line 128: the gate; this phase runs beside nidana.model.12 and restricts to its own closure, so G3 and G7 stay out of it) and D6 (line 135: `test/purity_test.dart` scans every library under `lib/` for `DateTime.now(`, `Stopwatch(`, `Timer(`, `Timer.periodic(`, `scheduleMicrotask(`, `Future.delayed(`, `Future.microtask(`, `Random(` and `Zone.`, as substrings, comments included, and allows any `dart:` library but `dart:io`, `dart:isolate`, `dart:ffi` and `dart:html`). The fixtures the gate replays: `hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart` through `nidana_dart_contracts_test.dart` (the nine cases of this phase are at lines 566, 1279, 1291, 1304, 1317, 1327, 1353, 1366 and 1422), the 7 files under `valid/`, the 38 under `invalid/` (each `valid/forms.json` with one schema rule broken) and the schema. Evidence: `docs/auto-run/experiments/json-form-plan/` (`run.sh`, `output.txt`, `variants.py`, `defects.py`, `fill_plan.py`, `facts/`, `draft/`), a dry run of this plan's tasks in a temporary copy of HEAD `ec540de`; labels such as S1, F3, T1.2, T3.4, I, X, G, U, C and D7 below name the steps of its `output.txt`. `draft/` is evidence: the test blocks below are the source, each formatter-stable (X), and `variants.py` derives Task 1's and Task 2's `codec.dart` from `draft/lib/src/json/codec.dart`, which is Task 3's.

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 6 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee G2,G4,G5,G6,G8,G9,G10,G11,G12,G19,G20,G21` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.13.verification.md from
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
// What the tests of topology-ir@v1's JSON form share: the files under
// hsdd/contract/fixture/topology-ir/, the Interface's example, and graphs
// generated from a seed with dart:math for the property tests (nidana.model.13
// Scope), so that a failure names the seed that reproduces it and the package
// takes no dependency beyond test (ADR-002 item 3).
import 'dart:convert';
import 'dart:io';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

import 'package_files.dart';

/// The text of [relative], a path under hsdd/contract/fixture/topology-ir/.
String fixtureText(String relative) =>
    File('${workspaceRoot().path}/hsdd/contract/fixture/topology-ir/$relative')
        .readAsStringSync();

/// The JSON value of [relative], a path under
/// hsdd/contract/fixture/topology-ir/.
Object? fixtureJson(String relative) => jsonDecode(fixtureText(relative));

/// topology-ir@v1's example graph document (the Interface, The JSON form),
/// laid out compactly as the contract shows it.
const String interfaceExample = '''
{
  "format": "topology-ir@v1",
  "topologies": [
    {
      "topologyId": "search",
      "scope": "page",
      "reads": [{ "name": "search.query", "variant": "state", "typeName": "String" }],
      "writes": [{ "name": "search.results", "variant": "state", "typeName": "Results" }],
      "transforms": [
        {
          "combinator": "debounce",
          "inputs": [{ "topic": { "name": "search.query", "variant": "state", "typeName": "String" }, "dedup": "none" }],
          "durationMicros": 300000
        },
        {
          "combinator": "switchMap",
          "inputs": [{ "edge": 0 }],
          "transformer": { "name": "searchApi" },
          "retry": { "name": null }
        },
        {
          "inputs": [{ "edge": 1 }],
          "output": { "name": "search.results", "variant": "state", "typeName": "Results" }
        }
      ]
    }
  ],
  "claims": [
    {
      "source": "service:search-history",
      "scope": "application",
      "writes": [{ "name": "search.history", "variant": "state", "typeName": "History" }]
    }
  ]
}
''';

/// The graph [interfaceExample] describes, built from IR values.
TopologyGraph interfaceExampleGraph() {
  const TopicRef query = TopicRef(
    name: 'search.query',
    variant: TopicVariant.state,
    typeName: 'String',
  );
  const TopicRef results = TopicRef(
    name: 'search.results',
    variant: TopicVariant.state,
    typeName: 'Results',
  );
  const TopicRef history = TopicRef(
    name: 'search.history',
    variant: TopicVariant.state,
    typeName: 'History',
  );
  return TopologyGraph(
    topologies: <TopologyDefinition>[
      TopologyDefinition(
        topologyId: 'search',
        scope: Scope.page,
        transforms: <TransformEdge>[
          TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[
            const TopicInput(query, dedup: Dedup.none),
          ], duration: const Duration(milliseconds: 300)),
          TransformEdge.stage(
            CombinatorKind.switchMap,
            <EdgeInput>[const StageInput(0)],
            transformer: FunctionRef.named('searchApi'),
            retry: const FunctionRef.anonymous(),
          ),
          TransformEdge.write(results, const StageInput(1)),
        ],
      ),
    ],
    claims: <ShellClaim>[
      ShellClaim(
        source: const ServiceSource('search-history'),
        writes: <TopicRef>{history},
      ),
    ],
  );
}
```

Create `packages/nidana_dart_contracts/test/json_encode_test.dart` with exactly this content:

```dart
// topology-ir@v1's encoder and JsonRenderer (The JSON form; G19, and G22's
// JSON rendering), beyond the G19 cases of the conformance suite, which
// compare maps without their key order: the order of every key, which keys an
// edge and an input carry, durations, function references, claims, and the
// text JsonRenderer writes.
import 'dart:convert';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/json_support.dart';

Never called(String what) => throw StateError('the encoder called $what');

int inc(int v) => called('inc');
int add(int a, int b) => called('add');
int reduceCount(int state, int event) => called('reduceCount');

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
const StateTopic<int> formsClaimed = StateTopic<int>(
  name: 'forms.claimed',
  initial: 0,
);

/// The forms sample of topology-ir@v1's conformance library, recorded.
TopologyGraph formsGraph() => TopologyGraph(
  topologies: <TopologyDefinition>[
    topology('forms', Scope.page, (TopologyBuilder b) {
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
    }).buildDefinition(),
  ],
  claims: <ShellClaim>[
    ShellClaim(
      source: const ServiceSource('forms'),
      writes: <TopicRef>{formsClaimed.ref},
    ),
  ],
);

const TopicRef stateA = TopicRef(
  name: 'enc.a',
  variant: TopicVariant.state,
  typeName: 'int',
);
const TopicRef stateB = TopicRef(
  name: 'enc.b',
  variant: TopicVariant.state,
  typeName: 'int',
);
const TopicRef eventE = TopicRef(
  name: 'enc.e',
  variant: TopicVariant.event,
  typeName: 'int',
);
const TopicRef replayR = TopicRef(
  name: 'enc.r',
  variant: TopicVariant.replay,
  typeName: 'int',
);

final FunctionRef f = FunctionRef.named('f');

TransformEdge one(CombinatorKind kind, int input, {Duration? duration}) =>
    TransformEdge.stage(kind, <EdgeInput>[
      StageInput(input),
    ], duration: duration);

/// One edge of every form: the seventeen stage kinds in CombinatorKind
/// order, a switchMap without a retry and one with, a write and a
/// reduceInto.
TopologyDefinition everyForm() => TopologyDefinition(
  topologyId: 'every-form',
  scope: Scope.module,
  transforms: <TransformEdge>[
    TransformEdge.stage(CombinatorKind.map, <EdgeInput>[
      const TopicInput(eventE),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.filter, <EdgeInput>[
      const StageInput(0),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.combine, <EdgeInput>[
      const StageInput(1),
      const TopicInput(stateA),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.withLatestFrom, <EdgeInput>[
      const StageInput(2),
      const TopicInput(stateA, dedup: Dedup.equality),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
      const StageInput(3),
      const TopicInput(replayR),
    ]),
    TransformEdge.stage(CombinatorKind.switchMap, <EdgeInput>[
      const StageInput(4),
    ], transformer: f),
    TransformEdge.stage(
      CombinatorKind.switchMap,
      <EdgeInput>[const StageInput(5)],
      transformer: f,
      retry: const FunctionRef.anonymous(),
    ),
    TransformEdge.stage(CombinatorKind.scan, <EdgeInput>[
      const StageInput(6),
    ], transformer: f),
    one(CombinatorKind.pairwise, 7),
    one(CombinatorKind.distinctUntilChanged, 8),
    one(
      CombinatorKind.debounce,
      9,
      duration: const Duration(milliseconds: 300),
    ),
    one(CombinatorKind.throttle, 10, duration: const Duration(seconds: 1)),
    one(CombinatorKind.delay, 11, duration: Duration.zero),
    one(
      CombinatorKind.sample,
      12,
      duration: const Duration(microseconds: 1500),
    ),
    one(CombinatorKind.buffer, 13, duration: const Duration(seconds: 2)),
    one(CombinatorKind.timeout, 14, duration: const Duration(days: 365000)),
    TransformEdge.stage(CombinatorKind.catchError, <EdgeInput>[
      const StageInput(15),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.rawEngine, <EdgeInput>[
      const StageInput(16),
    ], transformer: f),
    TransformEdge.write(eventE, const StageInput(17)),
    TransformEdge.reduceInto(
      stateB,
      const TopicInput(eventE),
      const FunctionRef.anonymous(),
    ),
  ],
);

List<Map<String, Object?>> edgesOf(Map<String, Object?> definition) =>
    (definition['transforms']! as List<Object?>).cast<Map<String, Object?>>();

void main() {
  test('G19 the forms sample encodes to valid/forms.json, every key in the '
      "schema's order", () {
    expect(
      jsonEncode(encodeTopologyGraph(formsGraph())),
      jsonEncode(fixtureJson('valid/forms.json')),
    );
  });

  test("G19 the Interface's example graph encodes to the document the "
      'contract shows, every key in order', () {
    expect(
      jsonEncode(encodeTopologyGraph(interfaceExampleGraph())),
      jsonEncode(jsonDecode(interfaceExample)),
    );
  });

  test('G19 an edge carries combinator, inputs, output, transformer, '
      'durationMicros and retry in that order, each only where it has one; '
      'a combinator is its CombinatorKind name', () {
    final List<Map<String, Object?>> edges = edgesOf(
      encodeTopologyDefinition(everyForm()),
    );
    const List<String> stage = <String>['combinator', 'inputs'];
    const List<String> withFunction = <String>[...stage, 'transformer'];
    const List<String> timed = <String>[...stage, 'durationMicros'];
    expect(
      <List<String>>[
        for (final Map<String, Object?> e in edges) e.keys.toList(),
      ],
      <List<String>>[
        withFunction, // map
        withFunction, // filter
        withFunction, // combine
        withFunction, // withLatestFrom
        stage, // merge
        withFunction, // switchMap
        <String>[...withFunction, 'retry'], // switchMap with a retry
        withFunction, // scan
        stage, // pairwise
        stage, // distinctUntilChanged
        timed, timed, timed, timed, timed, timed, // the six time stages
        withFunction, // catchError
        withFunction, // rawEngine
        <String>['inputs', 'output'], // write
        <String>['combinator', 'inputs', 'output', 'transformer'], // reduceInto
      ],
    );
    expect(
      <Object?>[for (final Map<String, Object?> e in edges) e['combinator']],
      <Object?>[
        'map', 'filter', 'combine', 'withLatestFrom', 'merge', 'switchMap', //
        'switchMap', 'scan', 'pairwise', 'distinctUntilChanged', 'debounce', //
        'throttle', 'delay', 'sample', 'buffer', 'timeout', 'catchError', //
        'rawEngine', null, 'reduceInto',
      ],
    );
  });

  test('G19 an input is {topic} with dedup only when the read gave one, '
      'Dedup.equality included, or {edge}', () {
    final List<Map<String, Object?>> edges = edgesOf(
      encodeTopologyDefinition(everyForm()),
    );
    expect(edges[0]['inputs'], <Object?>[
      <String, Object?>{
        'topic': <String, Object?>{
          'name': 'enc.e',
          'variant': 'event',
          'typeName': 'int',
        },
      },
    ]);
    expect(
      jsonEncode(edges[3]['inputs']),
      '[{"edge":2},{"topic":{"name":"enc.a","variant":"state","typeName":"int"},'
      '"dedup":"equality"}]',
    );
    expect(
      jsonEncode(
        encodeTopologyDefinition(
          interfaceExampleGraph().topologies.single,
        )['transforms'],
      ),
      contains('"dedup":"none"'),
    );
  });

  test('G19 a duration is durationMicros, a whole number of microseconds '
      'written as an int', () {
    final List<Map<String, Object?>> edges = edgesOf(
      encodeTopologyDefinition(everyForm()),
    );
    final List<Object?> micros = <Object?>[
      for (final Map<String, Object?> e in edges.sublist(10, 16))
        e['durationMicros'],
    ];
    expect(micros, <Object?>[
      300000,
      1000000,
      0,
      1500,
      2000000,
      31536000000000000,
    ]);
    expect(micros, everyElement(isA<int>()));
  });

  test('G19 a function reference is {"name": name}, null when anonymous', () {
    final List<Map<String, Object?>> edges = edgesOf(
      encodeTopologyDefinition(everyForm()),
    );
    expect(edges[0]['transformer'], <String, Object?>{'name': 'f'});
    expect(edges[6]['retry'], <String, Object?>{'name': null});
    expect(jsonEncode(edges[19]), contains('"transformer":{"name":null}'));
  });

  test("G19 a claim is its source's rendering, its scope by name and its "
      'writes in canonical order, given in any order', () {
    final ShellClaim claim = ShellClaim(
      source: const ExecutorSource('a:b'),
      scope: Scope.module,
      writes: <TopicRef>{stateB, stateA},
    );
    expect(
      jsonEncode(
        (encodeTopologyGraph(
                  TopologyGraph(claims: <ShellClaim>[claim]),
                )['claims']!
                as List<Object?>)
            .single,
      ),
      '{"source":"executor:a:b","scope":"module","writes":['
      '{"name":"enc.a","variant":"state","typeName":"int"},'
      '{"name":"enc.b","variant":"state","typeName":"int"}]}',
    );
  });

  test('G19 a graph built from its parts in any order encodes the same, '
      'topologies by id and claims in canonical order', () {
    final TopologyGraph forms = formsGraph();
    final TopologyDefinition every = everyForm();
    final ShellClaim page = ShellClaim(
      source: const PageSource('p'),
      writes: <TopicRef>{stateA},
    );
    final TopologyGraph ordered = TopologyGraph(
      topologies: <TopologyDefinition>[every, ...forms.topologies],
      claims: <ShellClaim>[page, ...forms.claims],
    );
    final TopologyGraph reversed = TopologyGraph(
      topologies: <TopologyDefinition>[...forms.topologies, every],
      claims: <ShellClaim>[...forms.claims, page],
    );
    final Map<String, Object?> doc = encodeTopologyGraph(reversed);
    expect(jsonEncode(doc), jsonEncode(encodeTopologyGraph(ordered)));
    expect(
      <Object?>[
        for (final Object? t in doc['topologies']! as List<Object?>)
          (t! as Map<String, Object?>)['topologyId'],
      ],
      <Object?>['every-form', 'forms'],
    );
    expect(
      <Object?>[
        for (final Object? c in doc['claims']! as List<Object?>)
          (c! as Map<String, Object?>)['source'],
      ],
      <Object?>['page:p', 'service:forms'],
    );
  });

  test('G19 the encoding is a JSON value: JSON text gives it back equal, and '
      'each call returns a new value', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[everyForm(), ...formsGraph().topologies],
      claims: formsGraph().claims,
    );
    final Map<String, Object?> doc = encodeTopologyGraph(g);
    expect(jsonDecode(jsonEncode(doc)), doc);
    (doc['topologies']! as List<Object?>).clear();
    expect(encodeTopologyGraph(g)['topologies'], hasLength(2));
  });

  test('G22 JsonRenderer writes the encoding indented by two spaces, then a '
      'newline, and the forms sample as valid/forms.json byte for byte', () {
    expect(
      const JsonRenderer().render(TopologyGraph()),
      '{\n'
      '  "format": "topology-ir@v1",\n'
      '  "topologies": [],\n'
      '  "claims": []\n'
      '}\n',
    );
    expect(
      const JsonRenderer().render(formsGraph()),
      fixtureText('valid/forms.json'),
    );
    expect(
      formsGraph().render(const JsonRenderer()),
      '${const JsonEncoder.withIndent('  ').convert(encodeTopologyGraph(formsGraph()))}\n',
    );
  });
}
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
// ------------------------------------------------------------ generated

/// How many seeds each property runs.
const int seeds = 500;

/// The `.json` files of [set], valid or invalid, by name without extension,
/// in name order.
List<String> fixtureNames(String set) => <String>[
  for (final FileSystemEntity f in Directory(
    '${workspaceRoot().path}/hsdd/contract/fixture/topology-ir/$set',
  ).listSync())
    if (f is File && f.path.endsWith('.json'))
      f.uri.pathSegments.last.replaceAll('.json', ''),
]..sort();

/// The topics a generated graph draws from: every variant, one name under
/// two variants and two types, an empty name, names and type names the
/// escaping sample uses. No type name is empty (the schema's minLength).
const List<TopicRef> generatedTopics = <TopicRef>[
  TopicRef(name: 'gen.a', variant: TopicVariant.state, typeName: 'int'),
  TopicRef(name: 'gen.a', variant: TopicVariant.state, typeName: 'String'),
  TopicRef(name: 'gen.a', variant: TopicVariant.event, typeName: 'int'),
  TopicRef(name: '', variant: TopicVariant.state, typeName: 'int?'),
  TopicRef(name: 'gen.s', variant: TopicVariant.state, typeName: 'bool'),
  TopicRef(
    name: 'odd "q" #1 <t> café\nline',
    variant: TopicVariant.replay,
    typeName: 'List<Map<String, int>>',
  ),
  TopicRef(
    name: r'odd.back\slash',
    variant: TopicVariant.event,
    typeName: '({int a, String b})',
  ),
  TopicRef(name: 'gen.r', variant: TopicVariant.replay, typeName: 'int'),
];

/// The function references a generated edge draws from: anonymous, and
/// names as the VM renders them, private and constructor tear-offs included.
final List<FunctionRef> generatedFunctions = <FunctionRef>[
  const FunctionRef.anonymous(),
  FunctionRef.named('f'),
  FunctionRef.named(r'to$Label'),
  FunctionRef.named('_reduce@22518013'),
  FunctionRef.named('Box.'),
  FunctionRef.named('naïve "q"'),
];

/// The durations a generated time stage draws from, zero included.
const List<Duration> generatedDurations = <Duration>[
  Duration.zero,
  Duration(microseconds: 1),
  Duration(microseconds: 1500),
  Duration(milliseconds: 300),
  Duration(seconds: 2),
  Duration(days: 365000),
];

/// The sources a generated claim draws from, one of each shell kind.
const List<MessageSource> generatedSources = <MessageSource>[
  ServiceSource('sync'),
  PageSource('checkout/cart?step="2"'),
  ExecutorSource('a:b'),
];

/// The topology ids a generated graph draws from.
const List<String> generatedIds = <String>['t0', 't1', ' ', 'odd "id"', 'é'];

T _pick<T>(Random random, List<T> from) => from[random.nextInt(from.length)];

/// A read of a pool topic, with a dedup half the time when the topic is a
/// state topic and never otherwise (the schema allows none there).
TopicInput _read(Random random) {
  final TopicRef topic = _pick(random, generatedTopics);
  return topic.variant == TopicVariant.state && random.nextBool()
      ? TopicInput(topic, dedup: _pick(random, Dedup.values))
      : TopicInput(topic);
}

/// An input of the stage edge at [index]: an earlier stage or a read.
EdgeInput _inputOf(Random random, int index) => index > 0 && random.nextBool()
    ? StageInput(random.nextInt(index))
    : _read(random);

/// A stage edge at [index] of any kind but reduceInto, with the inputs,
/// transformer, duration and retry its kind takes.
TransformEdge _stage(Random random, int index) {
  final CombinatorKind kind = _pick(
    random,
    CombinatorKind.values
        .where((CombinatorKind k) => k != CombinatorKind.reduceInto)
        .toList(),
  );
  final int count = switch (kind) {
    CombinatorKind.combine || CombinatorKind.merge => 1 + random.nextInt(4),
    CombinatorKind.withLatestFrom => 2 + random.nextInt(3),
    _ => 1,
  };
  final List<EdgeInput> inputs = <EdgeInput>[
    for (int i = 0; i < count; i++) _inputOf(random, index),
  ];
  return switch (kind) {
    CombinatorKind.merge ||
    CombinatorKind.pairwise ||
    CombinatorKind.distinctUntilChanged => TransformEdge.stage(kind, inputs),
    CombinatorKind.debounce ||
    CombinatorKind.throttle ||
    CombinatorKind.delay ||
    CombinatorKind.sample ||
    CombinatorKind.buffer ||
    CombinatorKind.timeout => TransformEdge.stage(
      kind,
      inputs,
      duration: _pick(random, generatedDurations),
    ),
    CombinatorKind.switchMap => TransformEdge.stage(
      kind,
      inputs,
      transformer: _pick(random, generatedFunctions),
      retry: random.nextBool() ? _pick(random, generatedFunctions) : null,
    ),
    _ => TransformEdge.stage(
      kind,
      inputs,
      transformer: _pick(random, generatedFunctions),
    ),
  };
}

/// A generated definition: up to six stage edges, then one sink for each
/// stage edge no later edge consumes and up to two more, each a write of a
/// pool topic or a reduceInto of a state topic, never two sinks on one state
/// topic.
TopologyDefinition generatedDefinition(Random random, String id) {
  final List<TransformEdge> stages = <TransformEdge>[
    for (int i = 0, n = random.nextInt(7); i < n; i++) _stage(random, i),
  ];
  final Set<int> consumed = <int>{
    for (final TransformEdge stage in stages)
      for (final EdgeInput input in stage.inputs)
        if (input is StageInput) input.edge,
  };
  final List<EdgeInput> ends = <EdgeInput>[
    for (int i = 0; i < stages.length; i++)
      if (!consumed.contains(i)) StageInput(i),
    for (int i = 0, n = random.nextInt(3); i < n; i++)
      _inputOf(random, stages.length),
  ];
  final Set<TopicRef> sunk = <TopicRef>{};
  final List<TransformEdge> sinks = <TransformEdge>[];
  for (final EdgeInput end in ends) {
    final TopicRef topic = _pick(random, <TopicRef>[
      for (final TopicRef t in generatedTopics)
        if (!sunk.contains(t)) t,
    ]);
    if (topic.variant == TopicVariant.state) {
      sunk.add(topic);
    }
    sinks.add(
      topic.variant == TopicVariant.state && random.nextBool()
          ? TransformEdge.reduceInto(
              topic,
              end,
              _pick(random, generatedFunctions),
            )
          : TransformEdge.write(topic, end),
    );
  }
  return TopologyDefinition(
    topologyId: id,
    scope: _pick(random, Scope.values),
    transforms: <TransformEdge>[...stages, ...sinks],
  );
}

/// A generated claim: a pool source, any scope, one to three pool state
/// topics.
ShellClaim generatedClaim(Random random) => ShellClaim(
  source: _pick(random, generatedSources),
  scope: _pick(random, Scope.values),
  writes: <TopicRef>{
    for (int i = 0, n = 1 + random.nextInt(3); i < n; i++)
      _pick(random, <TopicRef>[
        for (final TopicRef t in generatedTopics)
          if (t.variant == TopicVariant.state) t,
      ]),
  },
);

/// The graph [seed] generates: up to four topologies with distinct pool ids,
/// up to three claims.
TopologyGraph generatedGraph(int seed) {
  final Random random = Random(seed);
  final List<String> ids = List<String>.of(generatedIds)..shuffle(random);
  return TopologyGraph(
    topologies: <TopologyDefinition>[
      for (int i = 0, n = random.nextInt(5); i < n; i++)
        generatedDefinition(random, ids[i]),
    ],
    claims: <ShellClaim>[
      for (int i = 0, n = random.nextInt(4); i < n; i++) generatedClaim(random),
    ],
  );
}
```

Create `packages/nidana_dart_contracts/test/json_decode_test.dart` with exactly this content:

```dart
// topology-ir@v1's decoder on graph documents (The JSON form; G4, G20), and
// on values of the wrong shape (G21), beyond the conformance suite's cases:
// every valid/ file rendered back byte for byte, what the schema allows that
// no sample holds, Dart maps and lists that are not jsonDecode's, the
// FormatException's message, round trips and any list order over generated
// graphs, and that nothing here schedules work (G22).
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/json_support.dart';

/// [document] with [edit] applied to a deep copy.
Map<String, Object?> edited(
  Object? document,
  void Function(Map<String, Object?> doc) edit,
) {
  final Map<String, Object?> copy =
      jsonDecode(jsonEncode(document)) as Map<String, Object?>;
  edit(copy);
  return copy;
}

Map<String, Object?> topologyOf(Map<String, Object?> doc, [int i = 0]) =>
    (doc['topologies']! as List<Object?>)[i]! as Map<String, Object?>;

Map<String, Object?> edgeOf(Map<String, Object?> doc, int e) =>
    (topologyOf(doc)['transforms']! as List<Object?>)[e]!
        as Map<String, Object?>;

Map<String, Object?> claimOf(Map<String, Object?> doc) =>
    (doc['claims']! as List<Object?>)[0]! as Map<String, Object?>;

/// The message of the FormatException [decode] throws for [value]; any
/// other error propagates and fails the test.
String rejection(
  Object? value, [
  Object? Function(Object?) decode = decodeTopologyGraph,
]) {
  try {
    decode(value);
  } on FormatException catch (e) {
    return e.message;
  }
  fail('decoded a value the decoder must reject');
}

/// [list] in an order [random] draws.
List<Object?> shuffled(Object? list, Random random) =>
    List<Object?>.of(list! as List<Object?>)..shuffle(random);

void main() {
  test('G20 every valid/ file decodes, and JsonRenderer renders the graph '
      'back byte for byte', () {
    final List<String> names = fixtureNames('valid');
    expect(names, hasLength(7));
    for (final String name in names) {
      final String text = fixtureText('valid/$name.json');
      expect(
        const JsonRenderer().render(decodeTopologyGraph(jsonDecode(text))),
        text,
        reason: name,
      );
    }
  });

  test("G20 the Interface's example decodes to the graph it describes", () {
    expect(
      decodeTopologyGraph(jsonDecode(interfaceExample)),
      interfaceExampleGraph(),
    );
    expect(
      decodeTopologyDefinition(
        ((jsonDecode(interfaceExample) as Map<String, Object?>)['topologies']!
                as List<Object?>)
            .single,
      ),
      interfaceExampleGraph().topologies.single,
    );
  });

  test('G20 the decoder accepts what the schema allows and no sample holds: '
      'an empty topic name, a zero duration and index, a whole-number double, '
      'two equal claims, a source name holding a colon', () {
    final Object? forms = fixtureJson('valid/forms.json');
    final Map<String, Object?> doc = edited(forms, (Map<String, Object?> d) {
      edgeOf(d, 3)['durationMicros'] = 5000.0;
      final Map<String, Object?> claim = claimOf(d);
      claim['source'] = 'service:a:b';
      ((claim['writes']! as List<Object?>)[0]!
              as Map<String, Object?>)['name'] =
          '';
      (d['claims']! as List<Object?>).add(jsonDecode(jsonEncode(claim)));
    });
    final TopologyGraph g = decodeTopologyGraph(doc);
    expect(
      g.topologies.single.transforms[3].duration,
      const Duration(milliseconds: 5),
    );
    expect(g.claims, hasLength(2));
    expect(g.claims.first, g.claims.last);
    expect(g.claims.first.source, const ServiceSource('a:b'));
    expect(g.claims.first.writes.single.name, '');
    final Map<String, Object?> zero = edited(forms, (Map<String, Object?> d) {
      edgeOf(d, 3)['durationMicros'] = 0;
    });
    expect(
      decodeTopologyGraph(zero).topologies.single.transforms[3].duration,
      Duration.zero,
    );
  });

  test('G20 the decoder reads Dart maps and lists that jsonDecode does not '
      'make: Object? keys and unmodifiable collections', () {
    expect(
      decodeTopologyGraph(<Object?, Object?>{
        'format': 'topology-ir@v1',
        'topologies': const <Object?>[],
        'claims': List<Object?>.unmodifiable(<Object?>[]),
      }),
      TopologyGraph(),
    );
    expect(
      decodeTopologyGraph(
        Map<String, Object?>.unmodifiable(<String, Object?>{
          'format': 'topology-ir@v1',
          'topologies': <Object?>[],
          'claims': <Object?>[
            <String, Object?>{
              'source': 'service:s',
              'scope': 'module',
              'writes': <Object?>[
                <String, String>{
                  'name': 'n',
                  'variant': 'state',
                  'typeName': 'int',
                },
              ],
            },
          ],
        }),
      ).claims.single.scope,
      Scope.module,
    );
  });

  test('G21 a value of the wrong shape is rejected with a FormatException '
      'that names its JSONPath and what must be there', () {
    final Object? forms = fixtureJson('valid/forms.json');
    expect(rejection(null), r'$: must be an object');
    expect(rejection(<Object?>[]), r'$: must be an object');
    expect(rejection(<Object?, Object?>{1: 2}), r'$: must be an object');
    expect(
      rejection(edited(forms, (Map<String, Object?> d) => d.remove('claims'))),
      r'$.claims: is missing',
    );
    expect(
      rejection(edited(forms, (Map<String, Object?> d) => d['x'] = 1)),
      r'$: must not have the key "x"',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => d['format'] = 'topology-ir@v2',
        ),
      ),
      r'$.format: must be "topology-ir@v1"',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => d['topologies'] = <String, Object?>{},
        ),
      ),
      r'$.topologies: must be an array',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => topologyOf(d)['topologyId'] = 7,
        ),
      ),
      r'$.topologies[0].topologyId: must be a string',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => topologyOf(d)['scope'] = 'session',
        ),
      ),
      r'$.topologies[0].scope: must be one of application, module, page',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => edgeOf(d, 0)['combinator'] = null,
        ),
      ),
      startsWith(
        r'$.topologies[0].transforms[0].combinator: must be one of map, filter, ',
      ),
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> inputs = edgeOf(d, 4)['inputs']! as List<Object?>;
          inputs.add(inputs.first);
        }),
      ),
      r'$.topologies[0].transforms[4].inputs: must hold exactly one input',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          ((edgeOf(d, 1)['inputs']! as List<Object?>)[1]!
                  as Map<String, Object?>)['dedup'] =
              'always';
        }),
      ),
      r'$.topologies[0].transforms[1].inputs[1].dedup: must be one of equality, none',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) =>
              edgeOf(d, 0)['transformer'] = <String, Object?>{'name': 3},
        ),
      ),
      startsWith(r'$.topologies[0].transforms[0].transformer.name: must be '),
    );
    expect(
      rejection(<String, Object?>{'topologyId': 'x'}, decodeTopologyDefinition),
      r'$.scope: is missing',
    );
    expect(
      rejection(<String, Object?>{
        'topologyId': 'x',
        'scope': 'page',
        'reads': <Object?>[],
        'writes': <Object?>[],
        'transforms': <Object?>[
          <String, Object?>{
            'inputs': <Object?>[
              <String, Object?>{'edge': '0'},
            ],
            'output': <String, Object?>{
              'name': 'n',
              'variant': 'event',
              'typeName': 'int',
            },
          },
        ],
      }, decodeTopologyDefinition),
      startsWith(r'$.transforms[0].inputs[0].edge: must be '),
    );
  });

  test('G20 a generated graph decodes from its JSON text equal, and its '
      'encoding is that text again', () {
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      final String text = const JsonRenderer().render(g);
      final TopologyGraph decoded = decodeTopologyGraph(jsonDecode(text));
      expect(decoded, g, reason: 'seed $seed');
      expect(const JsonRenderer().render(decoded), text, reason: 'seed $seed');
    }
  });

  test(
    'G4 G20 every generated definition decodes from its JSON text equal',
    () {
      for (int seed = 0; seed < seeds; seed++) {
        for (final TopologyDefinition d in generatedGraph(seed).topologies) {
          expect(
            decodeTopologyDefinition(
              jsonDecode(jsonEncode(encodeTopologyDefinition(d))),
            ),
            d,
            reason: 'seed $seed, ${d.topologyId}',
          );
        }
      }
    },
  );

  test('G20 the decoder accepts the topologies, claims, reads, writes and '
      "claimed topics of a generated graph's document in any order", () {
    for (int seed = 0; seed < seeds; seed++) {
      final Random random = Random(seed);
      final TopologyGraph g = generatedGraph(seed);
      final Map<String, Object?> doc = edited(encodeTopologyGraph(g), (
        Map<String, Object?> d,
      ) {
        d['topologies'] = shuffled(d['topologies'], random);
        d['claims'] = shuffled(d['claims'], random);
        for (final Object? t in d['topologies']! as List<Object?>) {
          final Map<String, Object?> m = t! as Map<String, Object?>;
          m['reads'] = shuffled(m['reads'], random);
          m['writes'] = shuffled(m['writes'], random);
        }
        for (final Object? c in d['claims']! as List<Object?>) {
          final Map<String, Object?> m = c! as Map<String, Object?>;
          m['writes'] = shuffled(m['writes'], random);
        }
      });
      final TopologyGraph decoded = decodeTopologyGraph(doc);
      expect(decoded, g, reason: 'seed $seed');
      expect(
        jsonEncode(encodeTopologyGraph(decoded)),
        jsonEncode(encodeTopologyGraph(g)),
        reason: 'seed $seed',
      );
    }
  });

  test('G20 the generated graphs reach every combinator, input form, '
      'function form, variant, scope and source kind', () {
    final Set<Object?> kinds = <Object?>{};
    final Set<Object> forms = <Object>{};
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      for (final TopologyDefinition d in g.topologies) {
        forms.add(d.scope);
        for (final TransformEdge e in d.transforms) {
          kinds.add(e.combinator);
          if (e.retry != null) {
            forms.add('retry');
          }
          if (e.transformer case FunctionRef(name: null)) {
            forms.add('anonymous');
          }
          if (e.duration == Duration.zero) {
            forms.add('zero duration');
          }
          for (final EdgeInput input in e.inputs) {
            switch (input) {
              case TopicInput(:final TopicRef topic, :final Dedup? dedup):
                forms.add(topic.variant);
                if (dedup != null) {
                  forms.add(dedup);
                }
                if (topic.name.isEmpty) {
                  forms.add('empty name');
                }
              case StageInput():
                forms.add('stage input');
            }
          }
        }
      }
      for (final ShellClaim c in g.claims) {
        forms.add(c.source.runtimeType);
      }
    }
    expect(kinds, <Object?>{...CombinatorKind.values, null});
    expect(
      forms,
      containsAll(<Object>[
        ...Scope.values,
        ...TopicVariant.values,
        ...Dedup.values,
        'retry',
        'anonymous',
        'zero duration',
        'empty name',
        'stage input',
        ServiceSource,
        PageSource,
        ExecutorSource,
      ]),
    );
  });

  test('G22 encoding, decoding and rendering create no timer and schedule no '
      'microtask', () {
    var scheduled = 0;
    runZoned(
      () {
        for (int seed = 0; seed < 20; seed++) {
          final TopologyGraph g = generatedGraph(seed);
          decodeTopologyGraph(jsonDecode(const JsonRenderer().render(g)));
          for (final TopologyDefinition d in g.topologies) {
            decodeTopologyDefinition(encodeTopologyDefinition(d));
          }
        }
      },
      zoneSpecification: ZoneSpecification(
        createTimer:
            (
              Zone self,
              ZoneDelegate parent,
              Zone zone,
              Duration d,
              void Function() f,
            ) {
              scheduled++;
              return parent.createTimer(zone, d, f);
            },
        createPeriodicTimer:
            (
              Zone self,
              ZoneDelegate parent,
              Zone zone,
              Duration d,
              void Function(Timer t) f,
            ) {
              scheduled++;
              return parent.createPeriodicTimer(zone, d, f);
            },
        scheduleMicrotask:
            (Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
              scheduled++;
              parent.scheduleMicrotask(zone, f);
            },
      ),
    );
    expect(scheduled, 0);
  });
}
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
// [json] as an integer: an int, or a double with no fraction whose
// magnitude is below 2^63, which JSON Schema also counts as an integer.
int _integer(Object? json, String path) => switch (json) {
  final int n => n,
  final double d when d.abs() < _twoTo63 && d == d.truncateToDouble() =>
    d.toInt(),
  _ => _reject(path, 'must be an integer'),
};

// 2^63, the first double above every int.
const double _twoTo63 = 9223372036854775808.0;
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
// topology-ir@v1's decoder on everything that is not a graph document or
// breaks a decoder rule (The JSON form; G21), beyond the G21 cases of the
// conformance suite, which stop at the first file that fails: each invalid/
// file rejected for its own reason, the rules the schema cannot state, the
// values the IR's constructors accept and the schema does not, repeats that a
// Set or the graph would collapse, Dart values that are no JSON value, and
// generated values that either decode or are rejected with a FormatException
// and nothing else.
import 'dart:convert';
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/json_support.dart';

/// What the decoder says about each file under invalid/: the JSONPath of
/// the place that breaks a rule, then the rule.
final Map<String, String> invalidMessages = <String, String>{
  'claim_event_topic':
      r'$.claims[0]: writes: names a topic that is not a state topic',
  'claim_scope_missing': r'$.claims[0].scope: is missing',
  'claim_topology_source': r'$.claims[0].source: must be "service:", "page:" or "executor:" followed by a name',
  'claim_unknown_source': r'$.claims[0].source: must be "service:", "page:" or "executor:" followed by a name',
  'claim_without_writes': r'$.claims[0]: writes: must not be empty',
  'claims_missing': r'$.claims: is missing',
  'combinator_unknown': r'$.topologies[0].transforms[0].combinator: must be one of map, filter, combine, withLatestFrom, merge, switchMap, scan, pairwise, distinctUntilChanged, debounce, throttle, delay, sample, buffer, timeout, catchError, rawEngine, reduceInto',
  'dedup_on_event_read': r'$.topologies[0].transforms[2].inputs[1].dedup: may be given only on a read of a state topic',
  'dedup_unknown': r'$.topologies[0].transforms[1].inputs[1].dedup: must be one of equality, none',
  'duration_fractional': r'$.topologies[0].transforms[3].durationMicros: must be a non-negative integer',
  'duration_negative': r'$.topologies[0].transforms[3].durationMicros: must be a non-negative integer',
  'format_missing': r'$.format: is missing',
  'format_v2': r'$.format: must be "topology-ir@v1"',
  'function_ref_empty_name': r'$.topologies[0].transforms[0].transformer.name: must be a non-empty string or null',
  'function_ref_missing_name':
      r'$.topologies[0].transforms[0].transformer.name: is missing',
  'input_edge_negative': r'$.topologies[0].transforms[3].inputs[0].edge: must be a non-negative integer',
  'input_topic_and_edge':
      r'$.topologies[0].transforms[0].inputs[0]: must not have the key "topic"',
  'map_with_two_inputs': r'$.topologies[0].transforms[0]: inputs: a map edge takes exactly 1 input',
  'map_without_transformer':
      r'$.topologies[0].transforms[0]: transformer: a map edge needs one',
  'merge_with_transformer':
      r'$.topologies[0].transforms[2]: transformer: a merge edge holds none',
  'merge_without_inputs': r'$.topologies[0].transforms[2]: inputs: a merge edge takes at least 1 input',
  'reads_repeat_topic':
      r'$.topologies[0].reads[2]: repeats $.topologies[0].reads[0]',
  'reduce_into_event_output': r'$.topologies[0].transforms[5]: topic: is not a state topic, and a reduceInto writes one',
  'reduce_into_without_transformer':
      r'$.topologies[0].transforms[5].transformer: is missing',
  'retry_on_map':
      r'$.topologies[0].transforms[0]: retry: a map edge holds none',
  'scope_unknown':
      r'$.topologies[0].scope: must be one of application, module, page',
  'stage_with_output':
      r'$.topologies[0].transforms[0]: must not have the key "output"',
  'time_stage_without_duration':
      r'$.topologies[0].transforms[3]: duration: a debounce edge needs one',
  'topic_ref_extra_key':
      r'$.topologies[0].reads[0]: must not have the key "sensitive"',
  'topic_ref_without_type_name':
      r'$.topologies[0].reads[0].typeName: is missing',
  'topic_variant_unknown':
      r'$.topologies[0].reads[0].variant: must be one of state, event, replay',
  'topologies_repeat':
      r'$.topologies[1].topologyId: repeats the id of $.topologies[0]',
  'topology_id_empty': r'$.topologies[0]: topologyId: must not be empty',
  'unknown_top_level_key': r'$: must not have the key "generatedAt"',
  'with_latest_from_five_inputs': r'$.topologies[0].transforms[1]: inputs: a withLatestFrom edge takes 2 to 4 inputs',
  'with_latest_from_one_input': r'$.topologies[0].transforms[1]: inputs: a withLatestFrom edge takes 2 to 4 inputs',
  'write_with_transformer':
      r'$.topologies[0].transforms[4]: must not have the key "transformer"',
  'write_without_output': r'$.topologies[0].transforms[4].output: is missing',
};

/// [document] with [edit] applied to a deep copy.
Map<String, Object?> edited(
  Object? document,
  void Function(Map<String, Object?> doc) edit,
) {
  final Map<String, Object?> copy =
      jsonDecode(jsonEncode(document)) as Map<String, Object?>;
  edit(copy);
  return copy;
}

Map<String, Object?> topologyOf(Map<String, Object?> doc) =>
    (doc['topologies']! as List<Object?>)[0]! as Map<String, Object?>;

Map<String, Object?> edgeOf(Map<String, Object?> doc, int e) =>
    (topologyOf(doc)['transforms']! as List<Object?>)[e]!
        as Map<String, Object?>;

Map<String, Object?> inputOf(Map<String, Object?> doc, int e, int i) =>
    (edgeOf(doc, e)['inputs']! as List<Object?>)[i]! as Map<String, Object?>;

Map<String, Object?> claimOf(Map<String, Object?> doc) =>
    (doc['claims']! as List<Object?>)[0]! as Map<String, Object?>;

/// The message of the FormatException [decode] throws for [value]; any
/// other error propagates and fails the test.
String rejection(
  Object? value, [
  Object? Function(Object?) decode = decodeTopologyGraph,
]) {
  try {
    decode(value);
  } on FormatException catch (e) {
    return e.message;
  }
  fail('decoded a value the decoder must reject');
}

/// What decoding [value] gives: a graph, a FormatException, or the other
/// error it threw.
Object decodeOutcome(Object? value, Object Function(Object?) decode) {
  try {
    return decode(value);
  } on Object catch (error) {
    return error;
  }
}

/// The values a mutation writes, scalars of every JSON type and the names
/// the document form uses.
const List<Object?> scalars = <Object?>[
  null, true, -1, 0, 1, 2, 1.5, 2.0, 1e30, '', 'state', 'event', 'replay', //
  'none', 'equality', 'map', 'merge', 'reduceInto', 'service:x', //
  'topology:x', 'page', 'topology-ir@v1',
];

/// The keys a mutation adds, the document form's and one it does not know.
const List<String> keys = <String>[
  'format', 'topologies', 'claims', 'topologyId', 'scope', 'reads', //
  'writes', 'transforms', 'combinator', 'inputs', 'output', 'transformer', //
  'durationMicros', 'retry', 'topic', 'dedup', 'edge', 'name', 'variant', //
  'typeName', 'source', 'x',
];

/// Every object and array of [value], [value] itself first.
List<Object> containersOf(Object? value) => <Object>[
  if (value is Map<String, Object?>) ...<Object>[
    value,
    for (final Object? child in value.values) ...containersOf(child),
  ] else if (value is List<Object?>) ...<Object>[
    value,
    for (final Object? child in value) ...containersOf(child),
  ],
];

/// A value to write: a scalar, an empty container, or a copy of a container
/// of [doc].
Object? replacement(Random random, Object? doc) => switch (random.nextInt(4)) {
  0 => <Object?>[],
  1 => <String, Object?>{},
  2 => jsonDecode(
    jsonEncode(containersOf(doc)[random.nextInt(containersOf(doc).length)]),
  ),
  _ => scalars[random.nextInt(scalars.length)],
};

/// [doc], a JSON value it owns, changed in place by one mutation [random]
/// draws at one of its objects or arrays: a key removed, added or given
/// another value; an element removed, repeated, swapped or replaced.
void mutate(Random random, Object? doc) {
  final List<Object> containers = containersOf(doc);
  final Object target = containers[random.nextInt(containers.length)];
  if (target is Map<String, Object?>) {
    final List<String> present = target.keys.toList();
    switch (random.nextInt(3)) {
      case 0 when present.isNotEmpty:
        target.remove(present[random.nextInt(present.length)]);
      case 1 when present.isNotEmpty:
        target[present[random.nextInt(present.length)]] = replacement(
          random,
          doc,
        );
      default:
        target[keys[random.nextInt(keys.length)]] = replacement(random, doc);
    }
  } else if (target is List<Object?>) {
    switch (random.nextInt(4)) {
      case 0 when target.isNotEmpty:
        target.removeAt(random.nextInt(target.length));
      case 1 when target.isNotEmpty:
        target.add(
          jsonDecode(jsonEncode(target[random.nextInt(target.length)])),
        );
      case 2 when target.length > 1:
        final int i = random.nextInt(target.length);
        final int j = random.nextInt(target.length);
        final Object? t = target[i];
        target[i] = target[j];
        target[j] = t;
      default:
        target.add(replacement(random, doc));
    }
  }
}

/// A JSON value of up to [depth] levels, keyed and filled from the pools.
Object? arbitrary(Random random, int depth) =>
    switch (depth == 0 ? 0 : random.nextInt(3)) {
      0 => scalars[random.nextInt(scalars.length)],
      1 => <Object?>[
        for (int i = 0, n = random.nextInt(3); i < n; i++)
          arbitrary(random, depth - 1),
      ],
      _ => <String, Object?>{
        for (int i = 0, n = random.nextInt(4); i < n; i++)
          keys[random.nextInt(keys.length)]: arbitrary(random, depth - 1),
      },
    };

void main() {
  test(
    'G21 invalid/ holds exactly the files whose messages this test pins',
    () {
      expect(fixtureNames('invalid'), invalidMessages.keys.toList()..sort());
    },
  );

  for (final MapEntry<String, String> file in invalidMessages.entries) {
    test('G21 invalid/${file.key}.json is rejected with a FormatException at '
        'the place it breaks a rule', () {
      expect(rejection(fixtureJson('invalid/${file.key}.json')), file.value);
    });
  }

  test('G21 a schema-valid document that breaks a rule the schema cannot '
      'state is rejected at the definition that breaks it', () {
    final Object? forms = fixtureJson('valid/forms.json');
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          (topologyOf(d)['reads']! as List<Object?>).add(<String, Object?>{
            'name': 'forms.extra',
            'variant': 'event',
            'typeName': 'int',
          });
        }),
      ),
      r'$.topologies[0].reads: must list each topic the edges read, once',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          (topologyOf(d)['writes']! as List<Object?>).removeAt(0);
        }),
      ),
      r'$.topologies[0].writes: must list each topic the sink edges write, once',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          inputOf(d, 1, 0)['edge'] = 1;
        }),
      ),
      r'$.topologies[0]: transforms: edge 1 takes the output of edge 1, which '
      'is not an earlier edge',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          inputOf(d, 2, 0)['edge'] = 99;
        }),
      ),
      r'$.topologies[0]: transforms: edge 2 takes the output of edge 99, which '
      'is not an earlier edge',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          edgeOf(d, 4)['output'] = edgeOf(d, 5)['output'];
          (topologyOf(d)['writes']! as List<Object?>).removeAt(0);
        }),
      ),
      startsWith(
        r'$.topologies[0]: transforms: edge 5 is a second sink edge on this '
        'state topic',
      ),
    );
  });

  test('G21 an edge index below zero is rejected before StageInput would '
      'assert it', () {
    expect(
      rejection(
        edited(fixtureJson('valid/forms.json'), (Map<String, Object?> d) {
          inputOf(d, 3, 0)['edge'] = -5;
        }),
      ),
      r'$.topologies[0].transforms[3].inputs[0].edge: must be a non-negative '
      'integer',
    );
    expect(
      rejection(
        topologyOf(
          edited(fixtureJson('valid/forms.json'), (Map<String, Object?> d) {
            inputOf(d, 3, 0)['edge'] = -1.0;
          }),
        ),
        decodeTopologyDefinition,
      ),
      r'$.transforms[3].inputs[0].edge: must be a non-negative integer',
    );
  });

  test('G21 a dedup on an event or a replay read and an empty typeName are '
      'rejected, although TopicInput and TopicRef accept them', () {
    const TopicRef blank = TopicRef(
      name: 'n',
      variant: TopicVariant.replay,
      typeName: '',
    );
    expect(const TopicInput(blank, dedup: Dedup.none).dedup, Dedup.none);
    final Object? forms = fixtureJson('valid/forms.json');
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final Map<String, Object?> input = inputOf(d, 0, 0);
          (input['topic']! as Map<String, Object?>)['variant'] = 'replay';
          input['dedup'] = 'equality';
        }),
      ),
      r'$.topologies[0].transforms[0].inputs[0].dedup: may be given only on a '
      'read of a state topic',
    );
    for (final (String place, void Function(Map<String, Object?>) blankIt)
        in <(String, void Function(Map<String, Object?>))>[
          (
            r'$.topologies[0].reads[1].typeName',
            (Map<String, Object?> d) =>
                ((topologyOf(d)['reads']! as List<Object?>)[1]!
                        as Map<String, Object?>)['typeName'] =
                    '',
          ),
          (
            r'$.topologies[0].transforms[0].inputs[0].topic.typeName',
            (Map<String, Object?> d) =>
                (inputOf(d, 0, 0)['topic']!
                        as Map<String, Object?>)['typeName'] =
                    '',
          ),
          (
            r'$.topologies[0].transforms[4].output.typeName',
            (Map<String, Object?> d) =>
                (edgeOf(d, 4)['output']! as Map<String, Object?>)['typeName'] =
                    '',
          ),
          (
            r'$.claims[0].writes[0].typeName',
            (Map<String, Object?> d) =>
                ((claimOf(d)['writes']! as List<Object?>)[0]!
                        as Map<String, Object?>)['typeName'] =
                    '',
          ),
        ]) {
      expect(
        rejection(edited(forms, blankIt)),
        '$place: must not be empty',
        reason: place,
      );
    }
  });

  test('G21 a repeated topic in reads, writes or a claim, and a repeated '
      'topology id, are rejected before a Set or the graph collapses them', () {
    final Object? forms = fixtureJson('valid/forms.json');
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> writes =
              topologyOf(d)['writes']! as List<Object?>;
          writes.add(writes.first);
        }),
      ),
      r'$.topologies[0].writes[2]: repeats $.topologies[0].writes[0]',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> writes = claimOf(d)['writes']! as List<Object?>;
          writes.add(writes.first);
        }),
      ),
      r'$.claims[0].writes[1]: repeats $.claims[0].writes[0]',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> topologies = d['topologies']! as List<Object?>;
          topologies.add(<String, Object?>{
            ...topologyOf(d),
            'scope': 'module',
          });
        }),
      ),
      r'$.topologies[1].topologyId: repeats the id of $.topologies[0]',
    );
  });

  test('G21 a Dart value that is no JSON value of the form is rejected with a '
      'FormatException, one that contains itself included', () {
    final Object? forms = fixtureJson('valid/forms.json');
    final List<Object?> loop = <Object?>[];
    loop.add(loop);
    final Map<String, Object?> self = <String, Object?>{};
    self['topologyId'] = self;
    expect(
      rejection(<String, Object?>{
        'format': 'topology-ir@v1',
        'topologies': loop,
        'claims': <Object?>[],
      }),
      r'$.topologies[0]: must be an object',
    );
    expect(
      rejection(<String, Object?>{
        'format': 'topology-ir@v1',
        'topologies': <Object?>[self],
        'claims': <Object?>[],
      }),
      r'$.topologies[0].scope: is missing',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          d['topologies'] = <Object?>{};
        }),
      ),
      r'$.topologies: must be an array',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          d['format'] = DateTime.utc(2026);
        }),
      ),
      r'$.format: must be "topology-ir@v1"',
    );
    for (final Object? micros in <Object?>[
      double.nan,
      double.infinity,
      1e30,
      -0.5,
      '5',
    ]) {
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            edgeOf(d, 3)['durationMicros'] = micros;
          }),
        ),
        r'$.topologies[0].transforms[3].durationMicros: must be a non-negative '
        'integer',
        reason: '$micros',
      );
    }
  });

  test(
    'G21 a mutated graph document, or definition object, decodes and then '
    'round-trips, or is rejected with a FormatException, and nothing else',
    () {
      int decoded = 0;
      int rejected = 0;
      for (int seed = 0; seed < seeds; seed++) {
        final Random random = Random(seed);
        final TopologyGraph g = generatedGraph(seed);
        final Object? doc = jsonDecode(jsonEncode(encodeTopologyGraph(g)));
        for (int i = 0, n = 1 + random.nextInt(3); i < n; i++) {
          mutate(random, doc);
        }
        final Object outcome = decodeOutcome(doc, decodeTopologyGraph);
        expect(
          outcome,
          anyOf(isA<TopologyGraph>(), isA<FormatException>()),
          reason: 'seed $seed',
        );
        if (outcome is TopologyGraph) {
          decoded++;
          expect(
            decodeTopologyGraph(encodeTopologyGraph(outcome)),
            outcome,
            reason: 'seed $seed',
          );
        } else {
          rejected++;
        }
        for (final TopologyDefinition d in g.topologies) {
          final Object? object = jsonDecode(
            jsonEncode(encodeTopologyDefinition(d)),
          );
          mutate(random, object);
          expect(
            decodeOutcome(object, decodeTopologyDefinition),
            anyOf(isA<TopologyDefinition>(), isA<FormatException>()),
            reason: 'seed $seed, ${d.topologyId}',
          );
        }
      }
      // Floors near half of what the 500 seeds reach (json-form-plan F4: 19
      // documents decode and 481 are rejected), so that a generator change
      // cannot make either half of the property vacuous.
      expect(decoded, greaterThanOrEqualTo(10));
      expect(rejected, greaterThanOrEqualTo(240));
    },
  );

  test('G21 an arbitrary JSON value of up to four levels, keyed and filled '
      'with the names of the form, is rejected with a FormatException', () {
    for (int seed = 0; seed < seeds; seed++) {
      final Object? value = arbitrary(Random(seed), 4);
      expect(
        decodeOutcome(value, decodeTopologyGraph),
        isA<FormatException>(),
        reason: 'seed $seed',
      );
      expect(
        decodeOutcome(value, decodeTopologyDefinition),
        isA<FormatException>(),
        reason: 'seed $seed',
      );
    }
  });
}
```

- [ ] **Step 2: Run the test and the G21 replay to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/json_reject_test.dart`
Expected: `+19 -27: Some tests failed.`; the failures show the factories' `ArgumentError`, an `AssertionError` for `invalid/input_edge_negative.json`, documents accepted that must be rejected, and the Task 2 messages Task 3 changes (T3.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G21; echo "exit: $?"`
Expected: `cases (1 passed, 2 failed, 0 skipped under dart test, restricted to topology-ir G21)`, `exit: 1` (T3.2).

- [ ] **Step 3: Add the rules to the decoder in `lib/src/json/codec.dart`**

Every factory call of the decoder goes through `_build` at the path of the object it builds (the graph at `$`, a definition, an edge, a claim); read every member before it, so that only the factory runs inside the closure:

```dart
// What [build] returns: the ArgumentError an IR, claim or graph factory
// throws becomes a FormatException at [path] that names the argument and
// keeps the factory's message.
T _build<T>(String path, T Function() build) {
  try {
    return build();
  } on ArgumentError catch (error) {
    _reject(path, '${error.name}: ${error.message}');
  }
}
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
// [json] as a non-negative integer, the schema's only integers: an int, or a
// double with no fraction below 2^63, which JSON Schema also counts as an
// integer.
int _integer(Object? json, String path) => switch (json) {
  final int n when n >= 0 => n,
  final double d when d >= 0 && d < _twoTo63 && d == d.truncateToDouble() =>
    d.toInt(),
  _ => _reject(path, 'must be a non-negative integer'),
};
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
