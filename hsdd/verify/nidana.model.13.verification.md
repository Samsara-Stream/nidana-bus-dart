# Verification: nidana.model.13 - JSON form

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`. None of them starts `flutter`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate. It replays topic-model@v1 and topology-dsl@v2 unrestricted: topology-dsl@v2's recording suite through `topology_builder_test.dart`, its live suite being bus-api@v2's to bind and nidana.runtime's to replay. It replays topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets in full, the schema set validating the `valid/` and `invalid/` documents against `hsdd/contract/schema/topology-ir.schema.json`, and its `behavior` set through the binding `nidana_dart_contracts_test.dart` under `dart test`, restricted to G2, G4 to G6, G8 to G12 and G19 to G21. The G19 and G20 cases of that restriction check the codec's real output with `expectMatchesSchema`:

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee G2,G4,G5,G6,G8,G9,G10,G11,G12,G19,G20,G21
```

The checklist, where `78e1861` is the parent of Task 1's commit (the phase base). The first two commands print by name the cases and tests that the gate reports only as counts; the third shows what the restriction leaves out; the next two are searches that must find nothing; the last three show the file set and that no dependency moved:

```sh
fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G(4|19|20|21) ' -r expanded
fvm dart test packages/nidana_dart_contracts/test/json_encode_test.dart packages/nidana_dart_contracts/test/json_decode_test.dart packages/nidana_dart_contracts/test/json_reject_test.dart -j 1 -r expanded
fvm dart run nidana_contract_check topology-ir --set behavior; echo "exit: $?"
grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/json; echo "exit: $?"
grep -rnE "DateTime\.now\(|Stopwatch\(|Timer\(|Timer\.periodic\(|scheduleMicrotask\(|Future\.delayed\(|Future\.microtask\(|Random\(|Zone\." packages/nidana_dart_contracts/lib; echo "exit: $?"
git diff --name-status 78e1861 HEAD -- packages/nidana_dart_contracts
git status --short pubspec.lock
git diff --stat 78e1861 HEAD -- packages/nidana_dart_contracts/pubspec.yaml packages/nidana_dart_contracts/lib/topology_ir.dart
```

The third command is the unrestricted replay of the `behavior` set. It exits 1 until nidana.model.14, by design (see Observed).

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+353: All tests passed!`, `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test`, `59 fixtures: 59 passed, 0 failed, 0 pending`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 26 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G4 to G6, G8 to G12, G19 to G21`, the 46 `PASS schema` lines of topology-ir@v1 (the schema, 38 `invalid/` and 7 `valid/` documents) and `61 fixtures: 61 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` line appears. The suite count is the package's tests as the implementers left them, 353; the plan's `+336` (270 at the phase base and 66 in three new files) was lower by the 17 tests the implementers added where a rule would otherwise go unpinned, which the Global Constraints allow.
- The checklist prints, in order:
  - the nine case names of G4, G19, G20 and G21 of topology-ir@v1's binding, then `+9: All tests passed!`;
  - 83 test names, 12 from `json_encode_test.dart`, 19 from `json_decode_test.dart` and 52 from `json_reject_test.dart` (`-j 1` runs one file at a time), then `+83: All tests passed!` (the plan's 10, 10 and 46, and the 17 tests the implementers added: 2, 9 and 6);
  - for the unrestricted replay, `exit: 1` and `FAIL behavior` for the binding with `cases (41 passed, 2 failed, 0 skipped under dart test)`, the two failed being `G22 the Mermaid and Graphviz renderings of every sample equal its render/ files` and `G22 render passes the graph to the renderer, and renderers are pure`, which call the renderers nidana.model.14 delivers, then `10 fixtures: 9 passed, 1 failed, 0 pending`; `G22 the JSON rendering of every sample is its valid/ file, byte for byte` passes;
  - no line and `exit: 1` for each of the two searches;
  - five lines of `git diff --name-status`: `M` for `lib/src/json/codec.dart` and `A` for `test/src/json_support.dart`, `test/json_encode_test.dart`, `test/json_decode_test.dart` and `test/json_reject_test.dart`;
  - no output from `git status --short pubspec.lock` and none from `git diff --stat`.

## Observed

Run on 2026-10-27, on branch `impl/nidana.model.13` at `600c791` (phase base `78e1861`), Dart 3.13.5 through `fvm`. The implementation step started at 2026-10-27T20:08:44Z. The gate ran from 2026-10-27T20:53:07Z to 20:53:15Z and the checklist from 20:53:32Z to 20:53:37Z.

- The gate exited 0. Its lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:01 +353: All tests passed!`
  - `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test` (topic-model@v1, unrestricted)
  - `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test` and `59 fixtures: 59 passed, 0 failed, 0 pending` (topology-dsl@v2, unrestricted)
  - `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 26 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G4 to G6, G8 to G12, G19 to G21`, then 46 `PASS schema` lines (the schema, 38 `invalid/` and 7 `valid/` documents) and `61 fixtures: 61 passed, 0 failed, 0 pending` (no `FAIL`, `ERROR` or `PENDING` line anywhere in the output)
- The package counts differ from the plan's for one reason: the suite is 353 tests against 270 at the phase base, not 336; the three new test files hold 83 tests, not 66 (12, 19 and 52, not 10, 10 and 46). The additions are two in `json_encode_test.dart` (reads and writes in canonical order whatever order the edges give them, and no map or list shared between two encodings), nine in `json_decode_test.dart` (the order of missing and unexpected keys, the order of the format, topologies and claims, member-by-member reading, each form of edge, integers and whole-number doubles, claims, a definition object against a graph document, keys of every object in any order, and unmodifiable `Map<Object?, Object?>` collections) and six in `json_reject_test.dart` (a repeated topology id read before the claims, reads and writes that differ from the edges, what makes a topic repeat, a function name, the order of a dedup against its variant, and negative zero).
- Choices the phase settled, with their reasons:
  - One private library. Encoder, decoder and renderer share `lib/src/json/codec.dart`, its helpers private, because the form is one unit whose keys both directions name, and a separate decoder library would add a delegation layer and a second set of src-public names. The library grew from 26 to 493 lines.
  - Fresh containers on each encode. `encodeTopologyGraph` returns new map and list literals on every call, keys inserted in the schema's order (a map literal keeps insertion order and `JsonEncoder` writes in it), so the caller owns the value, and no mutation reaches another encoding.
  - The factories stay the rule book. The decoder builds through `TransformEdge.stage`, `.write` and `.reduceInto`, `TopologyDefinition`, `ShellClaim` and `TopologyGraph`, and `_build` turns their `ArgumentError`, and only that, into a `FormatException` at the path of the object being built. The stage-edge table and the definition rules are not restated, so a rule that changes in the IR changes the decoder with it. The decoder checks itself only what no factory checks: a negative index before `StageInput` asserts it, an empty `typeName`, a dedup on a read of anything but a state topic, the kind of a claim's source, repeats a `Set` or the graph would collapse, `reads` and `writes` against the edges, and distinct topology ids.
  - Messages take the form `$path: problem` and never print the rejected value, which may be large or contain itself, and `ArgumentError.toString()` renders its invalid value, so the factories' messages are rebuilt from `name` and `message`. The one exception is `TopologyDefinition`'s second-sink message, which carries the topic's `typeName` from the document (see the deferred findings).
  - Whole-number doubles below 2^63 count as integers. JSON Schema counts `5000.0` as an integer and package:json_schema 5.2.2 validates it; `jsonDecode` returns a `double` for any number with a fraction part or an exponent; and `double.toInt()` clamps at 2^63, so reading a larger one would change its value silently. A fraction, a negative number, NaN, infinity and a number of 2^63 or more are rejected.
  - Task 2 was deliberately incomplete. Its decoder reads every document of the right shape and lets the factories' `ArgumentError` and the `StageInput` assertion leak, so that Task 3's first failing test shows both and Task 3's `_build` and checks remove them; the Task 2 review did not flag the leaks, by the plan.
  - `_decodeEdge` was split in Task 3 into `_decodeWrite`, `_decodeReduceInto` and `_decodeStage` behind a dispatcher of 12 lines, as the Task 2 review suggested, while the returns were wrapped in `_build`. The behavior is preserved: Task 2's 19 tests pass unedited.
  - Topology ids are checked before the claims are read. `_checkDistinctIds` runs once every topology is read, so a repeated id is reported at its place even when a claim is also malformed. The design said "after every topology is read" and did not place the claims; `G21 a topology listed twice is rejected at its id although the two are equal, after every topology is read and before the claims` pins the order.
- Evidence from the task reviews, from the controller's ledger (not re-run at the gate): Task 1's review rendered all 7 `valid/` files byte for byte from the conformance samples. Task 2's review ran more than 100,000 fuzz calls that gave only `FormatException` plus the two planned leaks, and a round trip exact over 20,000 seeds and hostile strings. Task 3's review ran about 7 million fuzz decode calls, with a negative control against Task 2's codec, and only `FormatException` escaped; over 60,000 mutations the decoder accepted 0 schema-invalid documents; all 38 `invalid/` files were rejected at the planned path with the planned message. No task needed a fix round after review.
- Deferred review findings (all minor, no code change): the last G22 expectation of `json_encode_test.dart` rebuilds its expected text with the implementation's formula; the second-sink message renders the document's `typeName` (a 5000-character name gives a 5266-character message), the only factory message that carries document data; some factory messages name the factory's argument and not the document's key, as the plan's table has it; two first-index loops are near-identical; the `_build` around `TopologyGraph` cannot fire after the id check; and `json_decode_test.dart` (1088 lines) overlaps Task 3's messages in part.
- A probe at the gate (a Dart script in the scratchpad, run with `fvm dart --packages=.dart_tool/package_config.json`, not committed) checked the Learnings below. The schema validates `5000.0`, `1e30` and `9223372036854775808.0` for `durationMicros`, and `0.0` and `1e30` for an input's `edge`; the decoder accepts `5000.0` and `0.0` and rejects `1e30` and 2^63 at the place, with `must be a non-negative integer`. A hand-built definition with an empty `typeName`, and one with a dedup on an event read, encode without error to documents the schema rejects, and the decoder rejects both with a `FormatException`.
- Unrestricted, topology-ir@v1's `behavior` set exits 1 with `cases (41 passed, 2 failed, 0 skipped under dart test)` and `10 fixtures: 9 passed, 1 failed, 0 pending`: 41 of 43. A run of the `^G22 ` cases by name shows `G22 the JSON rendering of every sample is its valid/ file, byte for byte` passing ahead of its phase and the other two failing with `UnimplementedError` from `MermaidRenderer.render`.

Checklist:

- [x] The cases this phase turned green, by name. The first checklist command printed the nine cases and `+9: All tests passed!`: `G4 every definition a plan projects to is pure data: it encodes to JSON and decodes back equal`, `G19 the encoding of every sample graph matches the schema and equals its valid/ file`, `G19 a definition encodes to the object its graph document lists`, the three G20 cases (`every valid/ file decodes and re-encodes to an equal JSON value`, `decoding the encoding of a graph gives the graph back`, `the decoder accepts topologies, claims, reads, writes and claimed topics in any order`) and the three G21 cases (`every invalid/ file fails the schema and the decoder rejects it with a FormatException`, `the decoder rejects a schema-valid document that breaks a rule the schema cannot state`, `the decoder rejects any other value with a FormatException and no other error`). The second command printed the 83 package test names and `+83: All tests passed!`.
- [x] Every `invalid/` document fails the decoder with a `FormatException` and nothing else: the suite's `G21 every invalid/ file fails the schema and the decoder rejects it with a FormatException` passes, and so do the 38 package tests `G21 invalid/{name}.json is rejected with a FormatException at the place it breaks a rule`, one per file, each pinning the JSONPath and the message.
- [x] Each sample's encoding matches the schema and equals its `valid/` file: the suite's `G19 the encoding of every sample graph matches the schema and equals its valid/ file` passes, through `expectMatchesSchema`, and so does the package's `G20 every valid/ file decodes, and JsonRenderer renders the graph back byte for byte`, which compares the bytes.
- [x] The gate's topology-ir@v1 replay passes 26 of 26 against 17 before this phase (the nine cases above turned green, and the 17 are nidana.model.10's and nidana.model.11's); its schema set passes its 46 documents, as it did before; the unrestricted `behavior` set passes 41 of 43, the two others being the G22 renderer cases that wait for nidana.model.14.
- [x] What the gate's replay leaves open is pinned by the package's tests, all passing in the gate's package run: key order and the rendered bytes (`G19 an edge carries combinator, inputs, output, transformer, durationMicros and retry in that order, ...`, `G19 a graph built from its parts in any order encodes the same, ...`, `G22 JsonRenderer writes the encoding indented by two spaces, ...`, because the suite's G19 and G20 cases compare maps, whose `==` ignores key order); each rejection's place and message (the 38 per-file tests and `G21 a value of the wrong shape is rejected with a FormatException that names its JSONPath and what must be there`, because the suite checks only the exception's type); a dedup on an event or replay read, an empty `typeName` and a claim's repeated topic (`G21 a dedup on an event or a replay read and an empty typeName are rejected, ...`, `G21 a repeated topic in reads, writes or a claim, ...`); whole-number doubles (`G20 the decoder accepts what the schema allows and no sample holds: ...`, `G20 G21 an index and a duration are integers, ...`); and the property tests, 500 seeds each with a floor on what the seeds reach (`G20 the generated graphs reach every combinator, ...`). Of the nine seeded defects the S146 dry run found to pass this restricted replay, D2 (an edge's transformer before its output), D3 (no newline) and D4 (four spaces) fail G22's JSON case, which passes today and runs again in nidana.model.14's unrestricted replay; at the gate each of the three was made in `codec.dart` in turn, the case failed each time, and the file was restored (`git status --short packages/` printed nothing). D8, D10 and D11 are the second Learning's, D13 is the first Learning's whole-number doubles, and D7 (a repeat left to the reads comparison) and D16 (a message that renders the value) change only a message, which no guarantee states.
- [x] No `UnimplementedError` remains under `lib/src/json/` (no line, `exit: 1`) and no D6 token appears under `lib/` (no line, `exit: 1`). The export lists are unchanged (`exports_test.dart` passes, four tests), `purity_test.dart` passes over `codec.dart` with its `dart:convert` import (topic-model@v1 G25, G26: `G25 no library reads a clock, schedules work, generates an id or reaches a zone` and `G25 G26 no library imports dart:io, ...`), and the lockfile, `pubspec.yaml` and `topology_ir.dart` are unchanged (`git status --short pubspec.lock` and `git diff --stat` printed nothing). `git diff --name-status` printed the five lines the checklist expects.

## Outstanding

None.

## Learnings

- topology-ir@v1's schema states no upper bound for `durationMicros` or an input's `edge` (`{"type": "integer", "minimum": 0}`), and package:json_schema 5.2.2 validates `1e30` for either, while the Dart IR holds a `Duration` and an `int`, so the decoder rejects a whole number of 2^63 or more with a `FormatException` that no decoder rule of The JSON form names; the text "an integer" also leaves whole-number doubles such as `5000.0` implicit, which the schema accepts and this decoder reads as the integer they equal (S146 dry run, F2 and F3; re-checked at the gate by a probe over the schema and the decoder). Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)
- No `invalid/` file of topology-ir@v1 holds an empty `typeName` (the schema says `minLength` 1), a dedup on a replay read or a claim that lists one topic twice, so a decoder that accepts any of them passes every replay of this node, nidana.model.14's unrestricted one included (S146 dry run, seeded defects D8, D10 and D11); this phase's package tests pin all three. Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)
- The encoder is faithful, not validating: `TopicRef`, `TopicInput` and `TopologyDefinition` accept an empty `typeName` and a dedup on an event or replay read, so hand-built IR holding either encodes to a document the schema rejects (the builder already rejects a dedup on an event or replay read, so only hand-built IR reaches it, and a probe at the gate confirmed both encodings are schema-invalid and that the decoder rejects both); the decoder's rejection is the guard, and no encoder check is added (S135, the same sweep entry as the line above). Disposition: dropped (routed to the end-of-node governance sweep for topology-ir@v1)
- The phase scope estimated about 420 lines in about 4 files, tests included; the product diff is 2977 insertions and 6 deletions in 5 files, of which 473 insertions and 6 deletions in 1 file are library code (see Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint)

## Metrics

- Product diff, `git diff --stat 78e1861 HEAD -- packages/`, where `78e1861` is the parent of Task 1's commit: 5 files changed, 2977 insertions, 6 deletions (HEAD `600c791`; the commit of this doc changes nothing under `packages/`), of which the library (`lib/src/json/codec.dart`) is 1 file, 473 insertions and 6 deletions, and the tests (`test/json_encode_test.dart`, `test/json_decode_test.dart`, `test/json_reject_test.dart` and `test/src/json_support.dart`, all new) 4 files, 2504 insertions, beside the estimate of about 420 lines in about 4 files, tests included; the task count is 4 of the allowed 6 (this doc is Task 4's one file); fix rounds: none after task review; package tests: 270 at the phase base, 353 now.

## Sign-off
- Reviewer / date:
- Review tier applied:
- Disposition of each Outstanding item: verified | waived (reason) |
  deferred to {phase-id}
- Disposition of each Learning: spec-updated | contract-bumped (id@v) |
  adr-proposed (ADR-nnn) | dropped (reason)

> The review gate is not passed while an Outstanding item or a Learning
> lacks a disposition. Dispositions execute at the root through the owning
> skill (hsdd-contract, hsdd-adr, a node-spec edit), by the human running
> the gate.
