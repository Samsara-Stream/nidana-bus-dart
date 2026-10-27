# nidana.model.12 Analyses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the six analyses of topology-ir@v1 in `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart`: `findTopologyCycles` (G13), `findSelfReferences` (G14), `findWriterConflicts` (G15), `findScopeViolations` (G16), `analyzeTopologyGraph` (G17) and `findTopicNameCollisions` (G18), the single implementation of the checks of Spec §3.8, §3.11 and §7.2 "Scope compatibility" that activation and the workspace scan both run through `analyzeTopologyGraph`, and of Spec §4.3's name uniqueness that the workspace scan calls. Each returns an unmodifiable list of distinct findings (G3, G7, G23), and property tests over seeded generated graphs check cycles against a brute-force reachability check, G17's removal property and order independence. The gate's topology-ir@v1 replay, restricted to G2, G3, G5 to G18 and G23, then passes 31 of 31 cases (19 today).

**Architecture:** Bodies and private helpers in one library, `lib/src/analysis/analyses.dart` (nidana.model D4), which `topology_ir.dart` already exports by name; no public declaration changes. Each analysis is a pure function over the immutable graphs and definitions nidana.model.10 and .11 delivered, and relies on their orders: topologies by id with distinct ids, claims in canonical order with equal claims kept, `topics`, `reads` and `writes` in canonical order. Cycles come from an iterative Tarjan search over write-then-read arcs between distinct topologies; self-references from one forward and one backward pass over a definition's edges, which are in dependency order already; writer conflicts and scope violations from one owner list per state topic; `analyzeTopologyGraph` concatenates the four. Tasks run leaves first, one analysis family each, the property tests in the task whose analysis they check; the last task runs the gate and writes the verification doc.

**Tech Stack:** Dart 3.13.5 through `fvm dart`; `package:meta` 1.19.0, the package's only dependency; `package:test` for the package's tests, with `dart:math`'s `Random` seeded inside the tests for generated graphs; the replay tool `nidana_contract_check` with its `behavior` set (nidana.model.6).

**Spec:** `hsdd-context/superpowers/nidana.model.12.md` (the derivative; the phase context with topic-model@v1's, topology-dsl@v2's and topology-ir@v1's whole Interface and Guarantees sits between its markers). The Analyses section of topology-ir@v1 (`hsdd/contract/topology-ir.md`, lines 353 to 439, carried whole in the derivative) is the rule each analysis follows. Governance it relies on but does not inline: `hsdd/spec/nidana.model.md` D3 (line 102), D4 (line 112: under `lib/src/analysis/`, "the findings and declarations in one library, the analyses in another"), D5 (line 128: the gate; this phase runs beside nidana.model.13 and restricts to its own closure) and D6 (line 135: `test/purity_test.dart` scans every library under `lib/` for `DateTime.now(`, `Stopwatch(`, `Timer(`, `Timer.periodic(`, `scheduleMicrotask(`, `Future.delayed(`, `Future.microtask(`, `Random(` and `Zone.`, as substrings, comments included). The fixtures the gate replays: `hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart` through `nidana_dart_contracts_test.dart`; its `findings` sample is at lines 335 to 355 and 435 to 446. Evidence: `docs/auto-run/experiments/analyses-plan/` (`run.sh`, `output.txt`, `variants.py`, `defects.py`, `facts/`, `draft/`), a dry run of this plan's tasks in a temporary copy of HEAD `58ac350`; labels such as S1, T1.2, F1, X, G, U, C, A and D3 below name the steps of its `output.txt`. `draft/` is evidence, not code to copy: the test blocks below are the source, each formatter-stable (X), and `variants.py` derives each task's `analyses.dart` from `draft/analyses.src.dart`.

## Global Constraints

1. Every plan task except the last starts with a step that writes a failing
   test and records its failing output. Implementation follows.
2. The last task writes the verification doc, and it is the only task without
   a failing-test step.
3. The plan has at most 6 tasks: the phase is sized to one review sitting.
4. Before the last task, run the gate `fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee G2,G3,G5,G6,G7,G8,G9,G10,G11,G12,G13,G14,G15,G16,G17,G18,G23` and keep its output for
   the verification doc's Observed section.
5. The last task writes hsdd/verify/nidana.model.12.verification.md from
   hsdd/templates/verification.md at full-review depth, fills every section
   the template asks for at that depth, writes "- none" or dispositioned
   entries under Learnings, and leaves Sign-off for a human reviewer.
6. Nothing under hsdd/ changes except that verification doc. Contracts, ADRs,
   specs and conventions change only through hsdd-contract, hsdd-adr and
   hsdd-reconcile.
7. Build against the Interface and Guarantees in the Contracts section below
   (if any), never against another node's internals.
8. Review tier full-review: design rationale for every non-obvious choice; full verification doc.

Project-wide requirements from the spec and the run, which every task's requirements include:

- **Toolchain:** `fvm dart` only, every command from the repository root, no global tooling. No dependency changes: no `pubspec.yaml` is edited and `pubspec.lock` stays byte-identical.
- **Files:** under `lib/` this phase edits `lib/src/analysis/analyses.dart` alone (Tasks 1 to 4). `lib/src/analysis/findings.dart`, which nidana.model.10 delivered, and every other library stay as they are, and so do the three public libraries' export lists, which `test/exports_test.dart` pins. `lib/src/json/` is nidana.model.13's, which runs beside this phase (D5), and `lib/src/render/` nidana.model.14's. Under `test/` this phase creates `test/src/analysis_support.dart` (Task 1) and one test file per code task, and edits no existing test. `README.md`, `CHANGELOG.md` and `LICENSE` stay as they are (D4). Nothing under `hsdd/` changes except the verification doc of Task 5.
- **Interface:** the six public signatures stay exactly as nidana.model.5 landed them, `analyzeTopologyGraph`'s dartdoc included; no public declaration is added, and every helper is private to `analyses.dart`. Each of the five functions the Interface leaves without dartdoc gets a `//` comment above it naming its rule and guarantee, not dartdoc (decision 12); each private helper gets a `//` comment saying what it computes.
- **Results:** every analysis returns `List<...>.unmodifiable(...)` of what it found, an empty result included (G3; routed item 2). Where the contract implies distinct elements, the analysis passes distinct values to the finding constructors, which sort and keep repeats (G23; routed item 1): a cycle's ids and topics, a self-reference's edges. Each returned list holds distinct findings; only a writer conflict's `writers` repeat, one per equal claim, as the Interface states.
- **Graph orders as delivered (routed item 3):** the analyses take `TopologyGraph`'s invariants as given and re-sort nothing the graph already orders: `topologies` by `topologyId` with distinct ids, so an index into it is graph order and an id names one topology; `claims` in canonical order with equal claims kept; `topics`, and a definition's `reads` and `writes`, in canonical order. They handle no duplicate topology id and throw nothing.
- **Purity:** no word of `lib/` may contain a D6 token, in code or comment (substrings: no `Zone.`, no `Random(`). The analyses read no clock, create no timer and schedule nothing (topic-model@v1 G25; topology-ir@v1 G22, whose case first replays at nidana.model.14).
- **Prose:** no em-dash character in any comment, dartdoc, Markdown or commit message, and not the phrase the run rules ban.
- **Const collections:** topic references, sources, IR values and findings override `==`, so a non-empty const set of, or a const map keyed by, any of them does not compile; no test of this phase writes one (const lists are fine, and the tests use some). The fixture libraries under every slug's `surface/`, `reject/` and `behavior/` report the same 3143 diagnostics, in 70 of them, before and after this phase (B, A).
- **Analyzer:** `fvm dart analyze --fatal-infos` at the root reports nothing after every task (T1.4 to T4.4); each task's `analyses.dart` imports exactly what it uses, because an unused import is a warning.
- **Tests:** run from the root as `fvm dart test packages/nidana_dart_contracts`. Each task's failing step also replays the conformance cases of its guarantees with `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee {ids}`, which runs the committed binding under `dart test`; no step and no test of this phase starts `flutter`. Property tests draw from `dart:math`'s `Random(seed)` inside `test/` only, `seeds` (500) seeds each, as `test/lineage_property_test.dart` does, every expectation's `reason` naming the seed; each also asserts a floor on what the seeds reach, so that a generator change cannot make it vacuous (F2). The package's tests do not repeat the suite's cases; they pin what the suite leaves open. Add a test beyond the plan's wherever a rule you implement would otherwise go unpinned. No test pins a hash value or uses a `test` API newer than 1.31.1. The 235 package tests of HEAD, topic-model@v1's replay (41 cases) and topology-dsl@v2's (24 cases) pass today and stay green through every task (S1).
- **Contract gaps (ADR-001 item 8):** the dry run passes every fixture the gate replays (G), and the unrestricted topology-ir@v1 `behavior` set passes 31 of 43 cases, the 12 others calling the codec (nidana.model.13) or the renderers (nidana.model.14) (U). One gap found while planning does not block (decision 8). Any fixture that fails against code that follows this plan is a contract gap: stop at the task boundary, change nothing under `hsdd/`, and report BLOCKED with the case, what it reports, the guarantee, and the fix you would propose.
- **Formatting and commits:** run `fvm dart format packages/nidana_dart_contracts` before each commit (the blocks below are its output). Stage explicit paths; conventional subjects; the commit body is the co-author trailer your own harness's attribution instructions give, naming the model that wrote the commit: in the commit steps below, `<the co-author trailer your harness gives>` stands for that line, for example `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` for an Opus implementer.

## Plan check

The derivative's Plan check, run after self-review: the Global Constraints above contain its constraints 1 to 8 verbatim; every `### Task N:` but the last starts with a failing-test step; Task 5 writes `hsdd/verify/nidana.model.12.verification.md`; the plan has 5 tasks of the allowed 6; it is saved as `docs/superpowers/plans/nidana.model.12.md`. `node docs/auto-run/tools/impl-gate.mjs code-plan nidana.model.12` checks the same mechanically and exits 0 on this plan.

## Review Focus

The input classes the spec implies but the conformance suite does not exercise, most likely to bite first; each has its test in the owning task.

1. **A large active set or catalog, or a long chain of topologies:** a workspace scan over thousands of topologies, or a pipeline of topologies each feeding the next, gives the cycle search a path as deep as the chain. Expected: one finding per cycle, no `StackOverflowError`, time linear in topologies and arcs. A recursive search overflows the stack at a ring of 10000 topologies under `dart test` and still passes the gate's replay; the iterative search finds a ring of 300000 in under a second (F1). Test: `G13 a ring of 20000 topologies, deeper than a recursive search can go, is one cycle of every id and every topic` (Task 1).
2. **A self-read written the ways applications write it:** a read with a `dedup` argument (`b.read(t, dedup: Dedup.none)`) feeding a write of `t`, and a `debounce(Duration.zero)` or `delay(Duration.zero)` between the read and the write. Expected: a self-reference; a dedup argument does not change which topic is read, and a zero duration bears no state (G10). The dry run's D4 (a read matched by `TopicInput` equality, dedup included) passes the gate's replay. Tests: `G14 a read with a dedup argument is a read of its topic` and `G14 every stage that bears no state leaves a path unmediated, debounce, delay, sample and buffer with a zero duration included` (Task 2).
3. **Fan-out and fan-in inside one topology:** one read handle feeding its own topic's write and another topic's write, and a merge joining the self-read with an unrelated read. Expected: only the edges on a path from a read of the topic to a write of it, each listed once. The dry run's D3 (every edge a read reaches) fails one G14 case but passes the other and the G17 sample. Tests: `G14 an edge a read of the topic reaches is not listed when it leads only to a write of another topic`, `G14 an edge that reaches the write is not listed when no read of the topic reaches it`, `G14 self-references come in canonical topic order, and an edge on several paths is listed once`, and the walk of every path over generated definitions (Task 2).
4. **One shell source claiming in two scopes, and claims repeated:** a service whose publisher is constructed once unbound and once bound to a module, or a page that claims twice. Expected: a writer conflict lists every claim; scope violations come by owner rendering and then owner scope, one per distinct owner and reader. The dry run's D7 (owners in graph order) passes the gate's replay. Tests: `G15 a reduceInto makes its topology a writer, and two claims of one source in two scopes are two writers` and `G16 violations come by topic, then owner by its rendering and then its scope, then reader in graph order; equal owners count once` (Task 3).
5. **Topic declarations as a scanner hands them over:** a lazy iterable, the same declaration found twice, names in mixed case. Expected: the argument read once, a repeat counted once, names in `String.compareTo` order (`'Z.b'` before `'a.b'`). The dry run's D11 (names in first-seen order) passes the gate's replay. Tests: `G18 collisions come in name order as String.compareTo orders names, and a repeated declaration counts once` and `G18 findTopicNameCollisions reads its argument once, and later changes to the argument do not reach its result` (Task 4).

## Design decisions

The rationale for each non-obvious choice. Each is a decision in `docs/auto-run/steps/S143.json` with its options and evidence.

1. **One library, private helpers.** All six analyses and their helpers live in `lib/src/analysis/analyses.dart`, the library nidana.model.5 declared and `topology_ir.dart` exports by name (D4: "the findings and declarations in one library, the analyses in another"). Helpers stay private, so the export lists and `exports_test.dart` do not move. The library grows from 21 to 278 lines (C).
2. **Cycles by an iterative Tarjan search.** G13 names strongly connected sets; Tarjan's algorithm finds them in one depth-first pass, linear in topologies and arcs. The search keeps its path in two lists, the topologies on the path and how many arcs each has followed, instead of recursing: the recursive form overflows the stack at a ring of 10000 topologies under `dart test` (F1), a depth a long catalog chain can reach, and no conformance case comes near it. Warshall's reachability closure was the alternative, simpler to read but cubic; it is the property test's oracle (Task 1), and implementing it as well would make that test compare an algorithm with itself.
3. **Arcs.** An arc runs from topology i to topology j, j not i, when j's `reads` hold a topic of i's `writes`, of any variant (Analyses, Cycles), built from one index of the topologies that read each topic, in graph order. Claims take no part. No arc runs from a topology to itself, so a self-read is not a cycle of one, and components of one member are dropped.
4. **The topics of a cycle:** each topic one member writes and a different member reads ("the topics one member writes and another reads"). A member's own self-read is not one unless another member reads it too, and a topic between a member and an outsider is not one. They are collected in a set before the constructor, which keeps repeats (routed item 1); member ids are distinct because graph ids are.
5. **Cycles sorted by first id after the search.** Tarjan's search completes components in reverse topological order, not in id order: Task 1's first test builds a graph where the search from the first topology completes the later-named cycle first. The cycles are sorted by `compareTopologyIds` of their first, smallest, id, a total order because components are disjoint. The dry run's D1 (no sort) passes the gate's replay (D).
6. **Self-references by two passes.** A stage input names an earlier edge (G6), so a definition's edges are in dependency order. One forward pass marks the edges that a read of the topic reaches through edges bearing no state (`isStateBearing`, G10); one backward pass marks the edges that reach a write of the topic through such edges; an edge is on an unmediated path exactly when both passes mark it. Both passes are linear in edges and inputs. A read matches by `TopicInput.topic`, whatever its `dedup` (Review Focus 2); a write of the topic is an edge bearing no state whose `output` is the topic, and a reduceInto bears state, so it ends no unmediated path. Task 2's property test compares the passes with a walk of every path.
7. **One owner list for conflicts and violations.** `_owners(graph, topic)` lists a state topic's owners: each topology whose `writes` hold it, as `TopologySource(topologyId)` with the topology's scope, in graph order, then each claim whose `writes` hold it, one entry per claim, with the claim's source and scope; none for an event or replay topic (Spec §3.11). A writer conflict is a state topic of `graph.topics` with two or more owners, its writers their sources, which the constructor sorts. A topology writes a state topic at most once (G6), so only claims repeat.
8. **The order of scope violations, and a contract gap.** By topic in canonical order (`graph.topics`), then owner, then reader in graph order, as the Analyses section says. An owner is a source with a scope, and two owners can share a source: one service claiming unbound and bound to a module. The Interface orders sources by rendering and leaves that tie open; this plan breaks it by scope (application, module, page), as the claim order does after the source. Recorded as a low contract gap in `docs/auto-run/steps/S143.json`: an analysis's result order is in topology-ir@v1's Breaking list, so its text should name the tie-break, for example "then owner, by its source's rendering and then its scope". Equal owners, such as the G16 case's two equal `page:form` claims, give equal violations, which a `Set` literal drops while keeping iteration order (distinct findings; the dry run's D6 fails the G16 case).
9. **Collisions.** One pass groups the declarations by `topic.name` into a map of sets, where a repeated `TopicDeclaration`, a value, is one element (G18 "counts a repeated declaration once"); each name with two or more declarations, in `String.compareTo` order (the order the canonical topic order uses for names), gives a `TopicNameCollision`, whose constructor orders its declarations. The argument is iterated once, since a scanner may hand over a lazy iterable (Review Focus 5).
10. **Unmodifiable results everywhere.** Every analysis wraps its result in `List<...>.unmodifiable`, an empty one included: G3's case calls `clear()` on `analyzeTopologyGraph`'s result, and every analysis gives its callers the same guarantee. The findings' own lists are already unmodifiable (nidana.model.10). The dry run's D8 (`findScopeViolations` growable) passes the gate's replay and fails Task 3's G3 test.
11. **Property tests over one seeded generator.** `test/src/analysis_support.dart` draws from `Random(seed)` up to five topologies, `t0` to `t4` in any scope, each of one to three chains (a pool read through up to three stages, half of the stage kinds bearing state, a merge joining a pool read or an earlier stage) with one sink per chain and sometimes a second, never two sinks on a state topic; and up to two claims; over a pool of four state topics, two event topics and one replay topic. The oracles differ from the implementations: Warshall's closure for cycles (Task 1), a walk of every path for self-references (Task 2). G17's removal property runs over clean graphs grown greedily from the generated parts, because most generated graphs have a finding (F2: 90 of the 500 grown graphs keep three parts or more). Each floor sits near half of what the 500 seeds reach (F2), so it holds for these seeds and fails if a change to the generator makes a property vacuous. The whole package suite takes about 2 s (F3).
12. **`//` comments on the five functions the Interface leaves without dartdoc.** The public documentation stays the Interface's, as nidana.model.5 landed it; the comment states the rule and cites the guarantee, as the `==` comments of nidana.model.10 and .11 do.
13. **Five tasks, the property tests inside them.** One task per analysis family, leaves first: cycles, self-references, ownership (conflicts and violations share the owner list), then the composition with the collisions. A separate property-test task could not start with a failing test, because the analyses would already pass it; each property test joins the task whose analysis it checks, where it fails first because the stub throws.

## Routed items

Each item `docs/auto-run/impl-execution-plan.md` ("Routed to later phases") routes to this phase, with its disposition:

1. (S135's final review) The finding constructors keep repeated elements (G23); where the contract implies distinct elements (a cycle's ids and topics, a self-reference's edges), the analyses pass distinct values themselves: taken. Task 1 collects a cycle's topics in a set and its ids from one component (decision 4), and Task 2's two passes mark each edge once (decision 6). Tests: `G13 a cycle lists each topic one member writes and another member reads, of every variant, once; ...` (Task 1), `G14 self-references come in canonical topic order, and an edge on several paths is listed once` (Task 2) and `G23 every finding of a generated graph holds distinct findings, distinct ids, topics and edges, and equals itself rebuilt in reverse` (Task 4). The dry run's D14 (a cycle's topics with repeats) passes the gate's replay and fails the first and the last.
2. (S141's final review) The analyses return unmodifiable lists (G3's case calls `findings.clear()`): taken, in every code task (decision 10), with one G3 test per analysis.
3. (S141's final review) The graph's orders as delivered: `graph.topologies` sorted by id with distinct ids, `graph.claims` canonical with equal claims kept, `graph.topics` canonical: taken as invariants and not re-checked (Global Constraints, Graph orders as delivered). Graph order is id order, so cycle members and readers come in it; iterating `graph.claims` gives G15's "one entry per claim" (Task 3; the suite's G15 case catches the dry run's D9); conflicts and violations iterate `graph.topics` without sorting.

## Which task turns which failing case green

The gate's topology-ir@v1 replay, restricted to G2, G3, G5 to G18 and G23, runs 31 cases and passes 19 today (S1): G2; `G3 the IR copies the lists it is given; ...`; the three G5 cases; both G6 cases; `G7 IR values are equal, ...`; the three G8 cases; the three G9 cases; G10; the three G11 cases; G12. They stay green. The 12 it fails call the analyses; each turns green in one task:

| Task | Cases turned green (lines of `topology_ir_conformance.dart`) | Replay |
|------|---------------------------------------------------------------|--------|
| 1 | `G13 findTopologyCycles reports each strongly connected set of two or more topologies, with the topics between them` (1077), `G13 shell claims take no part in cycles, and a graph without feedback has none` (1096) | `--guarantee G13` from 0 passed, 2 failed to 2 passed (T1.2, T1.4) |
| 2 | `G14 findSelfReferences reports a self-written topic read through no state-bearing edge, with every edge on such a path` (1112), `G14 a self-read mediated by scan, reduceInto or a positive time stage, or never reaching its write, is not reported` (1130) | `--guarantee G14` from 0 passed, 2 failed to 2 passed (T2.2, T2.4) |
| 3 | `G15 findWriterConflicts reports each state topic with two or more writers, topologies and claims alike` (1150), `G16 findScopeViolations reports each owner of a state topic that a longer-lived topology reads` (1175) | `--guarantee G15,G16` from 0 passed, 2 failed to 2 passed (T3.2, T3.4) |
| 4 | `G3 every collection the IR, graphs, claims and findings expose is unmodifiable` (508), `G7 graphs, claims, declarations and findings are equal, with equal hash codes, exactly when their fields are` (821), `G17 analyzeTopologyGraph lists cycles, then self-references by topology, then writer conflicts, then scope violations` (1216), `G17 a graph with no finding stays without one when topologies or claims are removed` (1243), `G18 findTopicNameCollisions reports each name with two or more distinct declarations, whatever their types` (1262), `G23 finding and collision constructors put the lists they are given in the orders the Interface names` (1508) | `--guarantee G3,G7,G17,G18,G23` from 2 passed, 6 failed to 8 passed; the gate's restriction then passes 31 of 31 (T4.2, T4.4) |

The six cases of Task 4 call `analyzeTopologyGraph`, which composes the analyses of Tasks 1 to 3, or `findTopicNameCollisions`. After Task 4 the topology-ir@v1 `behavior` set, unrestricted, passes 31 of 43; the 12 it fails are G4 and the G19 to G22 cases, which call the codec (nidana.model.13) or the renderers (nidana.model.14) (U).

**The phase's Verification line**, and where each part is checked: the `findings` sample reports its cycle, self-references, writer conflicts and scope violations in the documented order (the suite's `G17 analyzeTopologyGraph lists cycles, ...` and `G23 finding and collision constructors ...`, Task 4); a self-read through `scan`, `reduceInto` or a positive time stage is no self-reference (the suite's `G14 a self-read mediated by ...`, and Task 2's `G14 scan, reduceInto, and debounce, delay, sample and buffer with the smallest positive duration mediate every path`, against `G14 every stage that bears no state leaves a path unmediated, ...` at a zero duration); a cycle across topologies is reported whatever its stages (Task 1's `G13 a cycle is reported whatever stages its members pass values through: reduceInto, scan and positive time stages included`).

## File Structure

All paths are from the repository root. `{pkg}` is `packages/nidana_dart_contracts`.

| File | Task | Responsibility |
|------|------|----------------|
| `{pkg}/lib/src/analysis/analyses.dart` | 1 to 4 | `findTopologyCycles` with `_readers`, `_arcs`, `_components` and `_cycle` (1); `findSelfReferences` with `_unmediated` (2); `findWriterConflicts` and `findScopeViolations` with `_Owner`, `_owners` and `_byOwner` (3); `analyzeTopologyGraph` and `findTopicNameCollisions` (4) |
| `{pkg}/test/src/analysis_support.dart` | 1 | Create: topic and definition helpers, and the seeded graph generator the property tests share |
| `{pkg}/test/topology_cycles_test.dart` | 1 | Create: cycle order, the topics between members, arcs through any stage, a deep ring, G3, the reachability property |
| `{pkg}/test/self_references_test.dart` | 2 | Create: paths only, every stage kind on either side of the line, dedup reads, topic order, G3, the walk-of-every-path property |
| `{pkg}/test/ownership_test.dart` | 3 | Create: writers and conflict order, every pair of scopes, violation order, owners that never violate, G3 |
| `{pkg}/test/analyze_graph_test.dart` | 4 | Create: self-references by topology, collisions, G3, and the removal, composition, order and distinctness properties |
| `hsdd/verify/nidana.model.12.verification.md` | 5 | Create: the verification doc |

---

### Task 1: findTopologyCycles and the generated graphs

You are filling in `findTopologyCycles`, which nidana.model.5 declared throwing `UnimplementedError`, in `lib/src/analysis/analyses.dart`, and creating the test support the later tasks share. Run every command from the repository root with `fvm dart`. Change no public declaration and leave the other five stubs as they are. This task turns the suite's two G13 cases green.

**Files:**
- Create: `packages/nidana_dart_contracts/test/src/analysis_support.dart`
- Create: `packages/nidana_dart_contracts/test/topology_cycles_test.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart` (the imports, lines 1 to 3; the `findTopologyCycles` stub, lines 5 and 6)

**Interfaces:**
- Consumes (landed by nidana.model.10 and .11): `TopologyGraph.topologies` (`List<TopologyDefinition>`, by `topologyId`, distinct ids, unmodifiable); `TopologyDefinition.topologyId`, `.reads` and `.writes` (`Set<TopicRef>`, canonical order); `TopologyCycle({required List<String> topologyIds, required List<TopicRef> topics})`, whose constructor sorts both lists and keeps repeats; `int compareTopologyIds(String a, String b)` in `lib/src/ir/canonical_order.dart`. The tests also use `TopologyDefinition(...)`, `TransformEdge.stage`, `.write` and `.reduceInto`, `TopicInput`, `StageInput`, `FunctionRef.named`, `ShellClaim(...)`, `topology(...)` and `buildDefinition()`.
- Produces: the body of `List<TopologyCycle> findTopologyCycles(TopologyGraph graph)`, and the private helpers `Map<TopicRef, List<int>> _readers(List<TopologyDefinition> topologies)`, `List<List<int>> _arcs(List<TopologyDefinition> topologies, Map<TopicRef, List<int>> readers)`, `List<List<int>> _components(List<List<int>> arcs)` and `TopologyCycle _cycle(List<TopologyDefinition> topologies, Set<int> members, Map<TopicRef, List<int>> readers)`. In `test/src/analysis_support.dart`, which Tasks 2 to 4 import as `src/analysis_support.dart`: `const int seeds = 500`; `TopicRef state(String name, [String type = 'int'])`, `TopicRef event(String name)`, `TopicRef replay(String name)`; `final FunctionRef f`; `TopologyDefinition define(String id, List<TransformEdge> transforms, {Scope scope = Scope.page})`; `TransformEdge map(EdgeInput input)`; `TopologyDefinition rw(String id, List<TopicRef> reads, List<TopicRef> writes, {Scope scope = Scope.page})`, a merge of the reads written to each of the writes; `typedef GraphParts = ({List<TopologyDefinition> topologies, List<ShellClaim> claims})`; `GraphParts generatedParts(int seed)`; `TopologyGraph graphOf(GraphParts parts)`; `TopologyGraph generatedGraph(int seed)`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/src/analysis_support.dart` with exactly this content. The generator's every call on `random` is part of what each seed produces, so the property tests' floors hold only for this text:

```dart
// What the tests of topology-ir@v1's analyses share: topic references and
// definitions written in one line, and graphs generated from a seed with
// dart:math for the property tests (nidana.model.12 Scope), so that a failure
// names the seed that reproduces it and the package takes no dependency
// beyond test (ADR-002 item 3).
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

/// How many seeds each property runs.
const int seeds = 500;

TopicRef state(String name, [String type = 'int']) =>
    TopicRef(name: name, variant: TopicVariant.state, typeName: type);

TopicRef event(String name) =>
    TopicRef(name: name, variant: TopicVariant.event, typeName: 'int');

TopicRef replay(String name) =>
    TopicRef(name: name, variant: TopicVariant.replay, typeName: 'int');

final FunctionRef f = FunctionRef.named('f');

TopologyDefinition define(
  String id,
  List<TransformEdge> transforms, {
  Scope scope = Scope.page,
}) => TopologyDefinition(topologyId: id, scope: scope, transforms: transforms);

/// A map stage of [input].
TransformEdge map(EdgeInput input) =>
    TransformEdge.stage(CombinatorKind.map, <EdgeInput>[input], transformer: f);

/// A topology that reads each of [reads] into one merge and writes each of
/// [writes] from it.
TopologyDefinition rw(
  String id,
  List<TopicRef> reads,
  List<TopicRef> writes, {
  Scope scope = Scope.page,
}) => define(id, <TransformEdge>[
  TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
    for (final TopicRef read in reads) TopicInput(read),
  ]),
  for (final TopicRef write in writes)
    TransformEdge.write(write, const StageInput(0)),
], scope: scope);

/// The topics a generated graph draws from: four state topics, two event
/// topics and one replay topic.
final List<TopicRef> topicPool = <TopicRef>[
  state('gen.a'),
  state('gen.b'),
  state('gen.c'),
  state('gen.d'),
  event('gen.e'),
  event('gen.f'),
  replay('gen.r'),
];

/// The sources a generated claim draws from.
const List<MessageSource> claimSources = <MessageSource>[
  ServiceSource('sync'),
  ServiceSource('cache'),
  PageSource('form'),
  ExecutorSource('nav'),
];

T _pick<T>(Random random, List<T> from) => from[random.nextInt(from.length)];

/// A read of a pool topic; a state topic's read sometimes with a dedup
/// argument.
TopicInput _read(Random random) {
  final TopicRef topic = _pick(random, topicPool);
  return topic.variant == TopicVariant.state && random.nextInt(4) == 0
      ? TopicInput(topic, dedup: _pick(random, Dedup.values))
      : TopicInput(topic);
}

/// A stage edge of [input], [index] being the index it takes: half of the
/// kinds bear state, and a merge also takes a pool read or an earlier stage.
TransformEdge _stage(Random random, EdgeInput input, int index) =>
    switch (random.nextInt(8)) {
      0 => map(input),
      1 => TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[
        input,
      ], duration: Duration.zero),
      2 => TransformEdge.stage(CombinatorKind.throttle, <EdgeInput>[
        input,
      ], duration: const Duration(milliseconds: 10)),
      3 => TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        input,
        if (index > 0 && random.nextBool())
          StageInput(random.nextInt(index))
        else
          _read(random),
      ]),
      4 => TransformEdge.stage(CombinatorKind.scan, <EdgeInput>[
        input,
      ], transformer: f),
      5 => TransformEdge.stage(CombinatorKind.delay, <EdgeInput>[
        input,
      ], duration: const Duration(milliseconds: 10)),
      6 => TransformEdge.stage(CombinatorKind.sample, <EdgeInput>[
        input,
      ], duration: const Duration(microseconds: 1)),
      _ => TransformEdge.stage(CombinatorKind.buffer, <EdgeInput>[
        input,
      ], duration: const Duration(seconds: 1)),
    };

/// A generated definition: one to three chains, each a pool read through up
/// to three stages, then one sink per chain and a second sink on the last
/// chain's end half of the time: a write of a pool topic, or a reduceInto
/// of a state topic, never two sinks on one state topic.
TopologyDefinition generatedTopology(Random random, String id) {
  final Scope scope = _pick(random, Scope.values);
  final List<TransformEdge> stages = <TransformEdge>[];
  final List<EdgeInput> ends = <EdgeInput>[];
  for (int chain = 0, chains = 1 + random.nextInt(3); chain < chains; chain++) {
    EdgeInput end = _read(random);
    for (int s = 0, length = random.nextInt(4); s < length; s++) {
      stages.add(_stage(random, end, stages.length));
      end = StageInput(stages.length - 1);
    }
    ends.add(end);
  }
  if (random.nextBool()) {
    ends.add(ends.last);
  }
  final Set<TopicRef> sunk = <TopicRef>{};
  final List<TransformEdge> sinks = <TransformEdge>[];
  for (final EdgeInput end in ends) {
    final List<TopicRef> open = <TopicRef>[
      for (final TopicRef topic in topicPool)
        if (!sunk.contains(topic)) topic,
    ];
    final TopicRef topic = _pick(random, open);
    if (topic.variant == TopicVariant.state) {
      sunk.add(topic);
    }
    sinks.add(
      topic.variant == TopicVariant.state && random.nextInt(4) == 0
          ? TransformEdge.reduceInto(topic, end, f)
          : TransformEdge.write(topic, end),
    );
  }
  return define(id, <TransformEdge>[...stages, ...sinks], scope: scope);
}

/// A generated claim: a pool source, any scope, one or two pool state
/// topics.
ShellClaim generatedClaim(Random random) {
  final MessageSource source = _pick(random, claimSources);
  final Scope scope = _pick(random, Scope.values);
  final List<TopicRef> states = <TopicRef>[
    for (final TopicRef topic in topicPool)
      if (topic.variant == TopicVariant.state) topic,
  ];
  return ShellClaim(
    source: source,
    scope: scope,
    writes: <TopicRef>{
      for (int i = 0, n = 1 + random.nextInt(2); i < n; i++)
        _pick(random, states),
    },
  );
}

/// The topologies and claims a seed generates, in generation order.
typedef GraphParts = ({
  List<TopologyDefinition> topologies,
  List<ShellClaim> claims,
});

/// Up to five topologies with the ids t0 to t4 and up to two claims.
GraphParts generatedParts(int seed) {
  final Random random = Random(seed);
  final List<TopologyDefinition> topologies = <TopologyDefinition>[
    for (int i = 0, n = random.nextInt(6); i < n; i++)
      generatedTopology(random, 't$i'),
  ];
  final List<ShellClaim> claims = <ShellClaim>[
    for (int i = 0, n = random.nextInt(3); i < n; i++) generatedClaim(random),
  ];
  return (topologies: topologies, claims: claims);
}

TopologyGraph graphOf(GraphParts parts) =>
    TopologyGraph(topologies: parts.topologies, claims: parts.claims);

TopologyGraph generatedGraph(int seed) => graphOf(generatedParts(seed));
```

Create `packages/nidana_dart_contracts/test/topology_cycles_test.dart` with exactly this content:

```dart
// topology-ir@v1's findTopologyCycles (G13), beyond the two G13 cases of its
// conformance suite, which the gate replays: cycles ordered by their first
// id whatever order a search meets them in, the topics between members only
// and each once, arcs of every variant and through any stage, a long ring,
// an unmodifiable result (G3), and the cycles of generated graphs against a
// brute-force reachability check.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/analysis_support.dart';

const EventTopic<int> clicks = EventTopic<int>(name: 'loop.clicks');
const StateTopic<int> total = StateTopic<int>(name: 'loop.total', initial: 0);

int add(int a, int b) => a + b;

/// The cycles of [graph] by brute force: one topology reaches another when a
/// chain of one or more arcs leads there (Warshall's closure over the arcs
/// between distinct topologies), and two belong to one cycle when each
/// reaches the other. Graph order is id order, so each cycle is met at its
/// first id, and the cycles come in the order of their first ids.
List<TopologyCycle> reachabilityCycles(TopologyGraph graph) {
  final List<TopologyDefinition> ts = graph.topologies;
  final int n = ts.length;
  final List<List<bool>> reach = <List<bool>>[
    for (int i = 0; i < n; i++)
      <bool>[
        for (int j = 0; j < n; j++)
          i != j && ts[i].writes.any(ts[j].reads.contains),
      ],
  ];
  for (int k = 0; k < n; k++) {
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        reach[i][j] = reach[i][j] || (reach[i][k] && reach[k][j]);
      }
    }
  }
  final Set<int> placed = <int>{};
  final List<TopologyCycle> cycles = <TopologyCycle>[];
  for (int i = 0; i < n; i++) {
    if (placed.contains(i)) {
      continue;
    }
    final List<int> members = <int>[
      i,
      for (int j = 0; j < n; j++)
        if (j != i && reach[i][j] && reach[j][i]) j,
    ];
    placed.addAll(members);
    if (members.length > 1) {
      cycles.add(
        TopologyCycle(
          topologyIds: <String>[for (final int m in members) ts[m].topologyId],
          topics: <TopicRef>{
            for (final int a in members)
              for (final int b in members)
                if (a != b) ...ts[a].writes.where(ts[b].reads.contains),
          }.toList(),
        ),
      );
    }
  }
  return cycles;
}

void main() {
  test('G13 cycles come in the order of their first ids, whichever cycle a '
      'search from the first topology completes first', () {
    // b reaches m through y, so a search from b completes {m, z} first.
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('m', <TopicRef>[event('m.in')], <TopicRef>[event('z.in')]),
        rw('z', <TopicRef>[event('z.in')], <TopicRef>[event('m.in')]),
        rw(
          'y',
          <TopicRef>[event('y.in')],
          <TopicRef>[event('b.in'), event('m.in')],
        ),
        rw('b', <TopicRef>[event('b.in')], <TopicRef>[event('y.in')]),
      ],
    );
    expect(findTopologyCycles(g), <TopologyCycle>[
      TopologyCycle(
        topologyIds: <String>['b', 'y'],
        topics: <TopicRef>[event('b.in'), event('y.in')],
      ),
      TopologyCycle(
        topologyIds: <String>['m', 'z'],
        topics: <TopicRef>[event('m.in'), event('z.in')],
      ),
    ]);
  });

  test('G13 a cycle lists each topic one member writes and another member '
      'reads, of every variant, once; not a member\'s own self-read, nor a '
      'topic between a member and an outsider', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw(
          'a',
          <TopicRef>[
            state('cyc.s'),
            state('cyc.s2'),
            event('cyc.own'),
            event('cyc.ext'),
          ],
          <TopicRef>[event('cyc.x'), replay('cyc.r'), event('cyc.own')],
        ),
        rw(
          'b',
          <TopicRef>[event('cyc.x'), replay('cyc.r')],
          <TopicRef>[state('cyc.s')],
        ),
        rw('c', <TopicRef>[event('cyc.x')], <TopicRef>[state('cyc.s2')]),
        rw('d', <TopicRef>[event('cyc.x')], <TopicRef>[event('cyc.out')]),
        rw('e', <TopicRef>[event('cyc.in')], <TopicRef>[event('cyc.ext')]),
      ],
    );
    expect(findTopologyCycles(g), <TopologyCycle>[
      TopologyCycle(
        topologyIds: <String>['a', 'b', 'c'],
        topics: <TopicRef>[
          replay('cyc.r'),
          state('cyc.s'),
          state('cyc.s2'),
          event('cyc.x'),
        ],
      ),
    ]);
  });

  test('G13 a cycle is reported whatever stages its members pass values '
      'through: reduceInto, scan and positive time stages included', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        topology(
          'fold',
          Scope.module,
          (TopologyBuilder b) => b.reduceInto(total, b.read(clicks), add),
        ).buildDefinition(),
        topology(
          'echo-back',
          Scope.module,
          (TopologyBuilder b) => b.write(
            clicks,
            b
                .read(total)
                .scan(0, add)
                .debounce(const Duration(milliseconds: 300))
                .delay(const Duration(seconds: 1)),
          ),
        ).buildDefinition(),
      ],
    );
    expect(findTopologyCycles(g), <TopologyCycle>[
      TopologyCycle(
        topologyIds: <String>['echo-back', 'fold'],
        topics: <TopicRef>[clicks.ref, total.ref],
      ),
    ]);
  });

  test('G13 a ring of 20000 topologies, deeper than a recursive search can '
      'go, is one cycle of every id and every topic', () {
    const int n = 20000;
    String id(int i) => 'r${i.toString().padLeft(5, '0')}';
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        for (int i = 0; i < n; i++)
          rw(
            id(i),
            <TopicRef>[event('ring.${id(i)}')],
            <TopicRef>[event('ring.${id((i + 1) % n)}')],
          ),
      ],
    );
    final List<TopologyCycle> cycles = findTopologyCycles(g);
    expect(cycles, hasLength(1));
    expect(cycles.single.topologyIds, <String>[
      for (int i = 0; i < n; i++) id(i),
    ]);
    expect(cycles.single.topics, <TopicRef>[
      for (int i = 0; i < n; i++) event('ring.${id(i)}'),
    ]);
  });

  test('G3 findTopologyCycles returns an unmodifiable list, empty or not', () {
    final List<TopologyCycle> none = findTopologyCycles(TopologyGraph());
    final List<TopologyCycle> one = findTopologyCycles(
      TopologyGraph(
        topologies: <TopologyDefinition>[
          rw('p', <TopicRef>[event('p.in')], <TopicRef>[event('q.in')]),
          rw('q', <TopicRef>[event('q.in')], <TopicRef>[event('p.in')]),
        ],
      ),
    );
    expect(none, isEmpty);
    expect(one, hasLength(1));
    expect(() => none.add(one.first), throwsUnsupportedError);
    expect(() => one.clear(), throwsUnsupportedError);
  });

  test('G13 the cycles of generated graphs are the strongly connected sets a '
      'brute-force reachability check finds, with or without their claims', () {
    int withCycle = 0;
    int withThree = 0;
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      final List<TopologyCycle> expected = reachabilityCycles(g);
      expect(findTopologyCycles(g), expected, reason: 'seed $seed');
      expect(
        findTopologyCycles(TopologyGraph(topologies: g.topologies)),
        expected,
        reason: 'seed $seed without claims',
      );
      withCycle += expected.isEmpty ? 0 : 1;
      withThree += expected.any((TopologyCycle c) => c.topologyIds.length > 2)
          ? 1
          : 0;
    }
    // The seeds reach graphs with a cycle, and cycles of three or more.
    expect(withCycle, greaterThan(110));
    expect(withThree, greaterThan(75));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/topology_cycles_test.dart`
Expected: `+0 -6: Some tests failed.`, each of the six on `UnimplementedError` (T1.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G13; echo "exit: $?"`
Expected: `FAIL behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: cases (0 passed, 2 failed, 0 skipped under dart test, restricted to topology-ir G13)`, `10 fixtures: 9 passed, 1 failed, 0 pending`, `exit: 1` (T1.2).

- [ ] **Step 3: Implement `findTopologyCycles` in `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart`**

- Imports, in this order: `../graph/graph.dart`, `../ir/canonical_order.dart` (new), `../ir/definition.dart`, `../topic/topic.dart` (new), `findings.dart`.
- `findTopologyCycles(TopologyGraph graph)`, replacing the stub: `_readers(graph.topologies)`; `_components(_arcs(topologies, readers))`; each component of two or more members becomes `_cycle(topologies, component.toSet(), readers)`; sort the cycles by `compareTopologyIds(a.topologyIds.first, b.topologyIds.first)` (decision 5); return `List<TopologyCycle>.unmodifiable(cycles)`. Its comment: `// One cycle per strongly connected set of two or more topologies of the graph's arcs (G13), each with its members' ids and the topics between them, ordered by the first of its ids.`
- `_readers`: for each topology index `i`, in graph order, add `i` to the list of each topic of its `reads` (`readers[topic] ??= <int>[]`).
- `_arcs`: for each index `i`, a set literal of the readers of each topic of `topologies[i].writes`, `reader != i`, turned into a sorted list (decision 3).
- `_components`: Tarjan's algorithm without recursion (decision 2), with this body; `followed.last = ...` uses `List.last`'s setter:

```dart
// The strongly connected components of the graph whose arcs [arcs] lists,
// each as the indices of its members, by Tarjan's algorithm. The depth-first
// search keeps its path in a list rather than on the call stack, so a chain
// of arcs of any length is searched without a StackOverflowError.
List<List<int>> _components(List<List<int>> arcs) {
  final List<int?> order = List<int?>.filled(arcs.length, null);
  final List<int> low = List<int>.filled(arcs.length, 0);
  final List<bool> open = List<bool>.filled(arcs.length, false);
  final List<int> stack = <int>[];
  final List<int> path = <int>[];
  final List<int> followed = <int>[];
  final List<List<int>> components = <List<int>>[];
  int visited = 0;
  void enter(int v) {
    order[v] = low[v] = visited++;
    stack.add(v);
    open[v] = true;
    path.add(v);
    followed.add(0);
  }

  for (int root = 0; root < arcs.length; root++) {
    if (order[root] != null) {
      continue;
    }
    enter(root);
    while (path.isNotEmpty) {
      final int v = path.last;
      final int next = followed.last;
      if (next < arcs[v].length) {
        followed.last = next + 1;
        final int w = arcs[v][next];
        if (order[w] == null) {
          enter(w);
        } else if (open[w] && order[w]! < low[v]) {
          low[v] = order[w]!;
        }
        continue;
      }
      path.removeLast();
      followed.removeLast();
      if (path.isNotEmpty && low[v] < low[path.last]) {
        low[path.last] = low[v];
      }
      if (low[v] == order[v]) {
        final List<int> component = <int>[];
        int w;
        do {
          w = stack.removeLast();
          open[w] = false;
          component.add(w);
        } while (w != v);
        components.add(component);
      }
    }
  }
  return components;
}
```

- `_cycle`: `topologyIds` the members' ids; `topics` a set literal of each topic a member writes whose readers include a member other than that writer, `.toList()` (decision 4).

Place the helpers after `findTopologyCycles`, before the next stub, in the order above.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G13`
Expected: `+241: All tests passed!`, `No issues found!`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 2 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G13` and `10 fixtures: 10 passed, 0 failed, 0 pending` (T1.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/analysis/analyses.dart packages/nidana_dart_contracts/test/src/analysis_support.dart packages/nidana_dart_contracts/test/topology_cycles_test.dart
git commit -m "feat(dart_contracts): find topology cycles as strongly connected sets" -m "<the co-author trailer your harness gives>"
```

### Task 2: findSelfReferences

You are filling in `findSelfReferences` in `lib/src/analysis/analyses.dart`. Run every command from the repository root with `fvm dart`. Change no public declaration and leave the four remaining stubs as they are. This task turns the suite's two G14 cases green.

**Files:**
- Create: `packages/nidana_dart_contracts/test/self_references_test.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart` (the `findSelfReferences` stub)

**Interfaces:**
- Consumes: from Task 1's `test/src/analysis_support.dart`, `seeds`, `state`, `event`, `f`, `define`, `map` and `generatedGraph`; `TopologyDefinition.topologyId`, `.reads`, `.writes` and `.transforms` (`List<TransformEdge>`); `TransformEdge.inputs` (`List<EdgeInput>`), `.output` (`TopicRef?`, a sink's topic) and `.isStateBearing` (G10); the sealed `EdgeInput` with `TopicInput.topic` and `.dedup` and `StageInput.edge`; `SelfReference({required String topologyId, required TopicRef topic, required List<int> edges})`, whose constructor sorts `edges` ascending and keeps repeats.
- Produces: the body of `List<SelfReference> findSelfReferences(TopologyDefinition definition)` and the private helper `List<int> _unmediated(List<TransformEdge> edges, TopicRef topic)`. Task 4's `analyzeTopologyGraph` calls `findSelfReferences` once per topology.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/self_references_test.dart` with exactly this content:

```dart
// topology-ir@v1's findSelfReferences (G14), beyond the two G14 cases of its
// conformance suite, which the gate replays: only the edges on a path from a
// read of the topic to a write of it, each once; every stage that bears no
// state, a zero duration included, against the smallest positive duration;
// a read with a dedup argument; the canonical order of topics; an
// unmodifiable result (G3); and the self-references of generated
// definitions against a walk of every path.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/analysis_support.dart';

/// The self-references of [definition] by brute force: every path is
/// walked, from each edge that takes a read of the topic, through each
/// later edge that takes the one before, stopping at a state-bearing edge,
/// and a path that ends at a write of the topic gives its edges.
List<SelfReference> walkedSelfReferences(TopologyDefinition definition) {
  final List<TransformEdge> edges = definition.transforms;
  final List<SelfReference> found = <SelfReference>[];
  for (final TopicRef topic in definition.reads) {
    if (!definition.writes.contains(topic)) {
      continue;
    }
    final Set<int> onPaths = <int>{};
    void walk(List<int> path) {
      final TransformEdge last = edges[path.last];
      if (last.isStateBearing) {
        return;
      }
      if (last.output == topic) {
        onPaths.addAll(path);
      }
      for (int next = path.last + 1; next < edges.length; next++) {
        if (edges[next].inputs.any(
          (EdgeInput input) => input is StageInput && input.edge == path.last,
        )) {
          walk(<int>[...path, next]);
        }
      }
    }

    for (int first = 0; first < edges.length; first++) {
      if (edges[first].inputs.any(
        (EdgeInput input) => input is TopicInput && input.topic == topic,
      )) {
        walk(<int>[first]);
      }
    }
    if (onPaths.isNotEmpty) {
      found.add(
        SelfReference(
          topologyId: definition.topologyId,
          topic: topic,
          edges: onPaths.toList(),
        ),
      );
    }
  }
  return found;
}

/// A stage edge of [kind] over one read of [topic] (two for withLatestFrom),
/// holding the transformer or duration its kind needs.
TransformEdge stageOf(CombinatorKind kind, TopicRef topic, Duration? d) =>
    TransformEdge.stage(
      kind,
      <EdgeInput>[
        TopicInput(topic),
        if (kind == CombinatorKind.withLatestFrom) TopicInput(topic),
      ],
      transformer: d == null && !_bare.contains(kind) ? f : null,
      duration: d,
    );

/// The kinds whose stage edge holds no transformer.
const List<CombinatorKind> _bare = <CombinatorKind>[
  CombinatorKind.merge,
  CombinatorKind.pairwise,
  CombinatorKind.distinctUntilChanged,
];

/// Each kind that bears no state, with the duration it is given: every
/// stage kind but scan and the four time stages that bear state, and those
/// four with a zero duration.
const List<(CombinatorKind, Duration?)> unmediating =
    <(CombinatorKind, Duration?)>[
      (CombinatorKind.map, null),
      (CombinatorKind.filter, null),
      (CombinatorKind.combine, null),
      (CombinatorKind.withLatestFrom, null),
      (CombinatorKind.merge, null),
      (CombinatorKind.switchMap, null),
      (CombinatorKind.pairwise, null),
      (CombinatorKind.distinctUntilChanged, null),
      (CombinatorKind.debounce, Duration.zero),
      (CombinatorKind.throttle, Duration(seconds: 1)),
      (CombinatorKind.delay, Duration.zero),
      (CombinatorKind.sample, Duration.zero),
      (CombinatorKind.buffer, Duration.zero),
      (CombinatorKind.timeout, Duration(seconds: 1)),
      (CombinatorKind.catchError, null),
      (CombinatorKind.rawEngine, null),
    ];

void main() {
  test('G14 an edge a read of the topic reaches is not listed when it leads '
      'only to a write of another topic', () {
    final TopologyDefinition d = define('fork', <TransformEdge>[
      map(TopicInput(state('fork.t'))),
      TransformEdge.write(state('fork.t'), const StageInput(0)),
      TransformEdge.write(event('fork.u'), const StageInput(0)),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(
        topologyId: 'fork',
        topic: state('fork.t'),
        edges: <int>[0, 1],
      ),
    ]);
  });

  test('G14 an edge that reaches the write is not listed when no read of the '
      'topic reaches it', () {
    final TopologyDefinition d = define('join', <TransformEdge>[
      map(TopicInput(event('join.other'))),
      TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        const StageInput(0),
        TopicInput(state('join.t')),
      ]),
      TransformEdge.write(state('join.t'), const StageInput(1)),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(
        topologyId: 'join',
        topic: state('join.t'),
        edges: <int>[1, 2],
      ),
    ]);
  });

  test('G14 every stage that bears no state leaves a path unmediated, '
      'debounce, delay, sample and buffer with a zero duration included', () {
    final TopicRef open = event('open.e');
    final TopologyDefinition d = define('open', <TransformEdge>[
      for (final (CombinatorKind kind, Duration? duration) in unmediating)
        stageOf(kind, open, duration),
      for (int i = 0; i < unmediating.length; i++)
        TransformEdge.write(open, StageInput(i)),
      TransformEdge.write(open, TopicInput(open)),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(
        topologyId: 'open',
        topic: open,
        edges: <int>[for (int i = 0; i <= 2 * unmediating.length; i++) i],
      ),
    ]);
  });

  test('G14 scan, reduceInto, and debounce, delay, sample and buffer with the '
      'smallest positive duration mediate every path', () {
    final TopicRef shut = event('shut.e');
    const Duration tick = Duration(microseconds: 1);
    final TopologyDefinition d = define('shut', <TransformEdge>[
      stageOf(CombinatorKind.scan, shut, null),
      stageOf(CombinatorKind.debounce, shut, tick),
      stageOf(CombinatorKind.delay, shut, tick),
      stageOf(CombinatorKind.sample, shut, tick),
      stageOf(CombinatorKind.buffer, shut, tick),
      for (int i = 0; i < 5; i++) TransformEdge.write(shut, StageInput(i)),
      TransformEdge.reduceInto(state('shut.s'), TopicInput(state('shut.s')), f),
    ]);
    expect(findSelfReferences(d), isEmpty);
  });

  test('G14 a read with a dedup argument is a read of its topic', () {
    final TopologyDefinition d = define('dedup', <TransformEdge>[
      TransformEdge.write(
        state('dedup.t'),
        TopicInput(state('dedup.t'), dedup: Dedup.none),
      ),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(
        topologyId: 'dedup',
        topic: state('dedup.t'),
        edges: <int>[0],
      ),
    ]);
  });

  test('G14 self-references come in canonical topic order, and an edge on '
      'several paths is listed once', () {
    final TopologyDefinition d = define('ord', <TransformEdge>[
      map(TopicInput(state('ord.b'))),
      map(const StageInput(0)),
      TransformEdge.stage(CombinatorKind.filter, <EdgeInput>[
        const StageInput(0),
      ], transformer: f),
      TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        const StageInput(1),
        const StageInput(2),
      ]),
      TransformEdge.write(state('ord.b'), const StageInput(3)),
      TransformEdge.write(event('ord.a'), TopicInput(event('ord.a'))),
      TransformEdge.write(state('ord.a'), TopicInput(state('ord.a'))),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(topologyId: 'ord', topic: state('ord.a'), edges: <int>[6]),
      SelfReference(topologyId: 'ord', topic: event('ord.a'), edges: <int>[5]),
      SelfReference(
        topologyId: 'ord',
        topic: state('ord.b'),
        edges: <int>[0, 1, 2, 3, 4],
      ),
    ]);
  });

  test('G3 findSelfReferences returns an unmodifiable list, empty or not', () {
    final List<SelfReference> none = findSelfReferences(
      define('none', <TransformEdge>[
        TransformEdge.write(event('none.out'), TopicInput(event('none.in'))),
      ]),
    );
    final List<SelfReference> one = findSelfReferences(
      define('one', <TransformEdge>[
        TransformEdge.write(event('one.e'), TopicInput(event('one.e'))),
      ]),
    );
    expect(none, isEmpty);
    expect(one, hasLength(1));
    expect(() => none.add(one.first), throwsUnsupportedError);
    expect(() => one.clear(), throwsUnsupportedError);
  });

  test('G14 the self-references of generated definitions list exactly the '
      'edges a walk of every path from a read to a write finds', () {
    int found = 0;
    int mediated = 0;
    for (int seed = 0; seed < seeds; seed++) {
      for (final TopologyDefinition d in generatedGraph(seed).topologies) {
        final List<SelfReference> expected = walkedSelfReferences(d);
        expect(
          findSelfReferences(d),
          expected,
          reason: 'seed $seed, ${d.topologyId}',
        );
        found += expected.length;
        mediated += d.reads.where(d.writes.contains).length - expected.length;
      }
    }
    // The seeds reach self-reads with an unmediated path and without one.
    expect(found, greaterThan(90));
    expect(mediated, greaterThan(350));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/self_references_test.dart`
Expected: `+0 -8: Some tests failed.`, each of the eight on `UnimplementedError` (T2.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G14; echo "exit: $?"`
Expected: `cases (0 passed, 2 failed, 0 skipped under dart test, restricted to topology-ir G14)`, `exit: 1` (T2.2).

- [ ] **Step 3: Implement `findSelfReferences` in `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart`**

No import changes: `definition.dart` and `topic.dart` hold every type.
- `findSelfReferences(TopologyDefinition definition)`, replacing the stub: for each topic of `definition.reads` (canonical order) that `definition.writes` contains, `_unmediated(definition.transforms, topic)`; a non-empty result gives `SelfReference(topologyId: definition.topologyId, topic: topic, edges: edges)`; return `List<SelfReference>.unmodifiable(...)`. Its comment: `// One self-reference per topic that [definition] both reads and writes, in canonical order, with an unmediated path from a read of it to a write of it, listing every edge on such a path (G14).`
- `_unmediated(edges, topic)` (decision 6), placed after it: a forward pass in index order sets `fromRead[i]` when edge `i` bears no state and one of its inputs is a read of the topic or a stage input of an edge with `fromRead`, matched by an exhaustive `switch` over `EdgeInput`: `TopicInput(topic: final TopicRef read) => read == topic`, `StageInput(edge: final int stage) => fromRead[stage]`. A backward pass in descending order sets `toWrite[i]` when edge `i` bears no state and its `output` is the topic or a later edge with `toWrite` takes it; to keep the pass linear, mark the stage inputs of each edge found `toWrite` in a second list `feedsWrite` as you go, and read `feedsWrite[i]` when you reach `i`. Return the indices with both marks, ascending, each once.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G14`
Expected: `+249: All tests passed!`, `No issues found!`, `PASS behavior ...: 2 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G14` (T2.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/analysis/analyses.dart packages/nidana_dart_contracts/test/self_references_test.dart
git commit -m "feat(dart_contracts): find self-references read through no state-bearing edge" -m "<the co-author trailer your harness gives>"
```

### Task 3: findWriterConflicts and findScopeViolations

You are filling in `findWriterConflicts` and `findScopeViolations` in `lib/src/analysis/analyses.dart`, over one owner list per state topic. Run every command from the repository root with `fvm dart`. Change no public declaration and leave the two remaining stubs as they are. This task turns the suite's G15 and G16 cases green.

**Files:**
- Create: `packages/nidana_dart_contracts/test/ownership_test.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart` (the imports; the `findWriterConflicts` and `findScopeViolations` stubs)

**Interfaces:**
- Consumes: from Task 1's support, `state`, `event`, `replay`, `f`, `define` and `rw`; `TopologyGraph.topics` (`List<TopicRef>`, canonical order), `.topologies` and `.claims` (`List<ShellClaim>`, canonical order, equal claims kept); `ShellClaim.source`, `.scope` and `.writes`; `TopologyDefinition.scope`; `TopicRef.variant` and `TopicVariant.state`; `TopologySource(String topologyId)`; `bool Scope.isAtLeastAsLongAs(Scope other)`; `int compareMessageSources(MessageSource a, MessageSource b)` in `lib/src/ir/canonical_order.dart`; `WriterConflict({required TopicRef topic, required List<MessageSource> writers})`, which sorts `writers` and keeps repeats; `ScopeViolation({required TopicRef topic, required MessageSource owner, required Scope ownerScope, required String readerId, required Scope readerScope})`.
- Produces: the bodies of `List<WriterConflict> findWriterConflicts(TopologyGraph graph)` and `List<ScopeViolation> findScopeViolations(TopologyGraph graph)`, and the private `typedef _Owner = ({MessageSource source, Scope scope})`, `List<_Owner> _owners(TopologyGraph graph, TopicRef topic)` and `int _byOwner(_Owner a, _Owner b)`.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/ownership_test.dart` with exactly this content:

```dart
// topology-ir@v1's findWriterConflicts (G15) and findScopeViolations (G16),
// beyond the G15 and G16 cases of its conformance suite, which the gate
// replays: a reduceInto as a writer, claims of one source in two scopes,
// the canonical order of topics, every pair of scopes, the order of owners
// by rendering and then scope with equal owners counted once, the owners
// that never violate, and unmodifiable results (G3).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/analysis_support.dart';

/// The owner and reader scopes of Spec §7.2 that violate: an owner that
/// lives shorter than its reader.
const List<(Scope, Scope)> violating = <(Scope, Scope)>[
  (Scope.module, Scope.application),
  (Scope.page, Scope.application),
  (Scope.page, Scope.module),
];

ScopeViolation violation(
  TopicRef topic,
  MessageSource owner,
  Scope ownerScope,
  String readerId,
  Scope readerScope,
) => ScopeViolation(
  topic: topic,
  owner: owner,
  ownerScope: ownerScope,
  readerId: readerId,
  readerScope: readerScope,
);

void main() {
  test('G15 a reduceInto makes its topology a writer, and two claims of one '
      'source in two scopes are two writers', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        define('fold', <TransformEdge>[
          TransformEdge.reduceInto(
            state('own.s'),
            TopicInput(event('own.in')),
            f,
          ),
        ]),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ServiceSource('svc'),
          writes: <TopicRef>{state('own.s')},
        ),
        ShellClaim(
          source: const ServiceSource('svc'),
          scope: Scope.page,
          writes: <TopicRef>{state('own.s')},
        ),
      ],
    );
    expect(findWriterConflicts(g), <WriterConflict>[
      WriterConflict(
        topic: state('own.s'),
        writers: const <MessageSource>[
          ServiceSource('svc'),
          ServiceSource('svc'),
          TopologySource('fold'),
        ],
      ),
    ]);
  });

  test('G15 conflicts come in canonical topic order, by name, then variant, '
      'then type, and a replay topic has none', () {
    final List<TopicRef> written = <TopicRef>[
      state('cfl.b', 'A'),
      replay('cfl.a'),
      state('cfl.a', 'B'),
      state('cfl.a', 'A'),
    ];
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('t1', <TopicRef>[event('cfl.in')], written),
        rw('t2', <TopicRef>[event('cfl.in')], written),
      ],
    );
    const List<MessageSource> both = <MessageSource>[
      TopologySource('t1'),
      TopologySource('t2'),
    ];
    expect(findWriterConflicts(g), <WriterConflict>[
      WriterConflict(topic: state('cfl.a', 'A'), writers: both),
      WriterConflict(topic: state('cfl.a', 'B'), writers: both),
      WriterConflict(topic: state('cfl.b', 'A'), writers: both),
    ]);
  });

  test('G16 an owner violates exactly when it lives shorter than its reader, '
      'for every pair of scopes', () {
    for (final Scope ownerScope in Scope.values) {
      for (final Scope readerScope in Scope.values) {
        final TopologyGraph g = TopologyGraph(
          topologies: <TopologyDefinition>[
            rw(
              'owner',
              <TopicRef>[event('pair.in')],
              <TopicRef>[state('pair.s')],
              scope: ownerScope,
            ),
            rw(
              'reader',
              <TopicRef>[state('pair.s')],
              <TopicRef>[event('pair.out')],
              scope: readerScope,
            ),
          ],
        );
        expect(
          findScopeViolations(g),
          violating.contains((ownerScope, readerScope))
              ? <ScopeViolation>[
                  violation(
                    state('pair.s'),
                    const TopologySource('owner'),
                    ownerScope,
                    'reader',
                    readerScope,
                  ),
                ]
              : isEmpty,
          reason: 'a ${ownerScope.name} owner, a ${readerScope.name} reader',
        );
      }
    }
  });

  test('G16 violations come by topic, then owner by its rendering and then '
      'its scope, then reader in graph order; equal owners count once', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('w', <TopicRef>[event('ord.in')], <TopicRef>[state('ord.b')]),
        rw(
          'r2',
          <TopicRef>[state('ord.a'), state('ord.b')],
          <TopicRef>[event('ord.o2')],
          scope: Scope.module,
        ),
        rw(
          'r1',
          <TopicRef>[state('ord.a'), state('ord.b')],
          <TopicRef>[event('ord.o1')],
          scope: Scope.application,
        ),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ServiceSource('svc'),
          scope: Scope.page,
          writes: <TopicRef>{state('ord.a')},
        ),
        ShellClaim(
          source: const ServiceSource('svc'),
          scope: Scope.module,
          writes: <TopicRef>{state('ord.a'), state('ord.b')},
        ),
        ShellClaim(
          source: const PageSource('form'),
          scope: Scope.page,
          writes: <TopicRef>{state('ord.b')},
        ),
        ShellClaim(
          source: const PageSource('form'),
          scope: Scope.page,
          writes: <TopicRef>{state('ord.b'), state('ord.a')},
        ),
      ],
    );
    const MessageSource form = PageSource('form');
    const MessageSource svc = ServiceSource('svc');
    const MessageSource w = TopologySource('w');
    const Scope app = Scope.application;
    const Scope mod = Scope.module;
    const Scope page = Scope.page;
    final TopicRef a = state('ord.a');
    final TopicRef b = state('ord.b');
    expect(findScopeViolations(g), <ScopeViolation>[
      violation(a, form, page, 'r1', app),
      violation(a, form, page, 'r2', mod),
      violation(a, svc, mod, 'r1', app),
      violation(a, svc, page, 'r1', app),
      violation(a, svc, page, 'r2', mod),
      violation(b, form, page, 'r1', app),
      violation(b, form, page, 'r2', mod),
      violation(b, svc, mod, 'r1', app),
      violation(b, w, page, 'r1', app),
      violation(b, w, page, 'r2', mod),
    ]);
  });

  test('G16 a topology reading the topic it owns, an application claim, and '
      'an event or replay topic never violate', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('self', <TopicRef>[state('safe.s')], <TopicRef>[state('safe.s')]),
        rw(
          'short',
          <TopicRef>[event('safe.in')],
          <TopicRef>[event('safe.e'), replay('safe.r')],
        ),
        rw(
          'long',
          <TopicRef>[state('safe.c'), event('safe.e'), replay('safe.r')],
          <TopicRef>[event('safe.out')],
          scope: Scope.application,
        ),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ExecutorSource('nav'),
          writes: <TopicRef>{state('safe.c')},
        ),
      ],
    );
    expect(findScopeViolations(g), isEmpty);
  });

  test('G3 findWriterConflicts and findScopeViolations return unmodifiable '
      'lists, empty or not', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('o', <TopicRef>[event('u.in')], <TopicRef>[state('u.s')]),
        rw(
          'r',
          <TopicRef>[state('u.s')],
          <TopicRef>[event('u.out')],
          scope: Scope.application,
        ),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ServiceSource('u'),
          writes: <TopicRef>{state('u.s')},
        ),
      ],
    );
    final List<WriterConflict> conflicts = findWriterConflicts(g);
    final List<ScopeViolation> violations = findScopeViolations(g);
    final List<WriterConflict> noConflicts = findWriterConflicts(
      TopologyGraph(),
    );
    final List<ScopeViolation> noViolations = findScopeViolations(
      TopologyGraph(),
    );
    expect(conflicts, hasLength(1));
    expect(violations, hasLength(1));
    expect(() => conflicts.clear(), throwsUnsupportedError);
    expect(() => violations.clear(), throwsUnsupportedError);
    expect(() => noConflicts.add(conflicts.first), throwsUnsupportedError);
    expect(() => noViolations.add(violations.first), throwsUnsupportedError);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/ownership_test.dart`
Expected: `+0 -6: Some tests failed.`, each of the six on `UnimplementedError` (T3.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G15,G16; echo "exit: $?"`
Expected: `cases (0 passed, 2 failed, 0 skipped under dart test, restricted to topology-ir G15, G16)`, `exit: 1` (T3.2).

- [ ] **Step 3: Implement both in `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart`**

- Imports: add `../topic/message_source.dart` and `../topic/scope.dart`, keeping the list in path order (`../graph/graph.dart`, `../ir/canonical_order.dart`, `../ir/definition.dart`, `../topic/message_source.dart`, `../topic/scope.dart`, `../topic/topic.dart`, `findings.dart`).
- `findWriterConflicts(graph)`, replacing its stub: for each topic of `graph.topics`, the topic's `_owners`; two or more give `WriterConflict(topic: topic, writers: [each owner's source])`; return `List<WriterConflict>.unmodifiable(...)` (decision 7). Its comment: `// One writer conflict per state topic of the graph, in canonical order, with two or more owners: every topology that writes it, as its topology source, and every claim that claims it, one entry per claim (G15).`
- `findScopeViolations(graph)`, replacing its stub: for each topic of `graph.topics`, for each owner of `_owners(graph, topic)..sort(_byOwner)`, for each topology of `graph.topologies` whose `reads` hold the topic and whose scope the owner's does not outlive (`!owner.scope.isAtLeastAsLongAs(reader.scope)`), a `ScopeViolation(topic: topic, owner: owner.source, ownerScope: owner.scope, readerId: reader.topologyId, readerScope: reader.scope)`, collected in a `Set` literal, which drops the violations of equal owners in order, and returned as `List<ScopeViolation>.unmodifiable(...)` (decision 8). Its comment: `// One scope violation per state topic, owner and reading topology where the owner's scope is not at least as long as the reader's (G16): by topic in canonical order, then owner by its source's rendering and then its scope, then reader in graph order. Equal owners, such as two equal claims, give one violation per reader, so the set keeps each once, in that order.`
- `typedef _Owner = ({MessageSource source, Scope scope});`, commented `// A writer of a state topic with the scope it owns it in (Spec §3.11, §7.2).`
- `_owners(graph, topic)`: empty unless `topic.variant == TopicVariant.state`; otherwise `(source: TopologySource(t.topologyId), scope: t.scope)` for each topology `t` of `graph.topologies` whose `writes` hold the topic, then `(source: c.source, scope: c.scope)` for each claim `c` of `graph.claims` whose `writes` hold it (decision 7).
- `_byOwner(a, b)`: `compareMessageSources(a.source, b.source)`, then `a.scope.index.compareTo(b.scope.index)` (decision 8).

Place them after `findSelfReferences`'s helper: the two functions, then `_Owner`, `_owners` and `_byOwner`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G15,G16`
Expected: `+255: All tests passed!`, `No issues found!`, `PASS behavior ...: 2 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G15, G16` (T3.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/analysis/analyses.dart packages/nidana_dart_contracts/test/ownership_test.dart
git commit -m "feat(dart_contracts): find writer conflicts and scope violations over state topic owners" -m "<the co-author trailer your harness gives>"
```

### Task 4: analyzeTopologyGraph and findTopicNameCollisions

You are filling in the last two stubs of `lib/src/analysis/analyses.dart`. Run every command from the repository root with `fvm dart`. Change no public declaration; `analyzeTopologyGraph` keeps its dartdoc as it stands. This task turns the suite's six remaining cases green, and with them the gate's restricted replay.

**Files:**
- Create: `packages/nidana_dart_contracts/test/analyze_graph_test.dart`
- Modify: `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart` (the `analyzeTopologyGraph` and `findTopicNameCollisions` stubs)

**Interfaces:**
- Consumes: Tasks 1 to 3's analyses; from Task 1's support, `seeds`, `state`, `event`, `rw`, `GraphParts`, `generatedParts`, `graphOf` and `generatedGraph`; `TopicDeclaration.topic` and `.site`; `TopicNameCollision({required String name, required List<TopicDeclaration> declarations})`, whose constructor orders the declarations by site, then topic in canonical order; `toGraph()`.
- Produces: the bodies of `List<TopologyFinding> analyzeTopologyGraph(TopologyGraph graph)` and `List<TopicNameCollision> findTopicNameCollisions(Iterable<TopicDeclaration> declarations)`. Nothing later in this plan calls them; bus-api@v2's activation and nidana-checks@v1's workspace scan do.

- [ ] **Step 1: Write the failing test**

Create `packages/nidana_dart_contracts/test/analyze_graph_test.dart` with exactly this content:

```dart
// topology-ir@v1's analyzeTopologyGraph (G17) and findTopicNameCollisions
// (G18), beyond the G17, G18 and G23 cases of its conformance suite, which
// the gate replays: self-references by topology in graph order, collisions
// in name order with repeats counted once and the argument read once,
// unmodifiable results (G3), and over generated graphs the removal property
// of G17, the composition of the four analyses, findings that do not depend
// on the order of their arguments (G7), and findings whose lists hold
// distinct elements and keep their order when rebuilt (G23).
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/analysis_support.dart';

/// A clean graph grown from [parts]: each topology, then each claim, in
/// generation order, kept when the graph with it still has no finding.
TopologyGraph cleanGraph(GraphParts parts) {
  List<TopologyDefinition> topologies = <TopologyDefinition>[];
  List<ShellClaim> claims = <ShellClaim>[];
  bool clean(List<TopologyDefinition> ts, List<ShellClaim> cs) =>
      analyzeTopologyGraph(TopologyGraph(topologies: ts, claims: cs)).isEmpty;
  for (final TopologyDefinition t in parts.topologies) {
    final List<TopologyDefinition> more = <TopologyDefinition>[
      ...topologies,
      t,
    ];
    if (clean(more, claims)) {
      topologies = more;
    }
  }
  for (final ShellClaim c in parts.claims) {
    final List<ShellClaim> more = <ShellClaim>[...claims, c];
    if (clean(topologies, more)) {
      claims = more;
    }
  }
  return TopologyGraph(topologies: topologies, claims: claims);
}

/// [items] in an order drawn from [random].
List<T> shuffled<T>(List<T> items, Random random) =>
    List<T>.of(items)..shuffle(random);

/// The sites and topics generated declarations draw from: two names, each
/// in two variants, at three sites.
final List<TopicDeclaration> declarationPool = <TopicDeclaration>[
  for (final String site in <String>[
    'lib/a.dart:1',
    'lib/b.dart:2',
    'lib/c.dart:3',
  ])
    for (final TopicRef topic in <TopicRef>[
      state('gen.x'),
      event('gen.x'),
      state('gen.y'),
      event('gen.y'),
    ])
      TopicDeclaration(topic: topic, site: site),
];

void main() {
  test('G17 self-references come by topology in graph order, then by topic '
      'in canonical order', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw(
          'zeta',
          <TopicRef>[state('z.s')],
          <TopicRef>[state('z.s')],
          scope: Scope.application,
        ),
        rw(
          'alpha',
          <TopicRef>[state('a.s'), event('a.e')],
          <TopicRef>[state('a.s'), event('a.e')],
          scope: Scope.application,
        ),
      ],
    );
    expect(analyzeTopologyGraph(g), <TopologyFinding>[
      SelfReference(
        topologyId: 'alpha',
        topic: event('a.e'),
        edges: <int>[0, 2],
      ),
      SelfReference(
        topologyId: 'alpha',
        topic: state('a.s'),
        edges: <int>[0, 1],
      ),
      SelfReference(
        topologyId: 'zeta',
        topic: state('z.s'),
        edges: <int>[0, 1],
      ),
    ]);
  });

  test(
    'G3 analyzeTopologyGraph returns an unmodifiable list, empty or not',
    () {
      final List<TopologyFinding> none = analyzeTopologyGraph(TopologyGraph());
      final List<TopologyFinding> one = analyzeTopologyGraph(
        rw(
          'one',
          <TopicRef>[event('one.e')],
          <TopicRef>[event('one.e')],
        ).toGraph(),
      );
      expect(none, isEmpty);
      expect(one, hasLength(1));
      expect(() => none.add(one.first), throwsUnsupportedError);
      expect(() => one.clear(), throwsUnsupportedError);
    },
  );

  test('G18 collisions come in name order as String.compareTo orders names, '
      'and a repeated declaration counts once', () {
    final TopicDeclaration lowerState = TopicDeclaration(
      topic: state('a.b'),
      site: 'lib/x.dart:1',
    );
    final TopicDeclaration lowerEvent = TopicDeclaration(
      topic: event('a.b'),
      site: 'lib/x.dart:2',
    );
    final TopicDeclaration upperInt = TopicDeclaration(
      topic: state('Z.b'),
      site: 'lib/y.dart:1',
    );
    final TopicDeclaration upperOther = TopicDeclaration(
      topic: state('Z.b', 'Other'),
      site: 'lib/y.dart:1',
    );
    final TopicDeclaration lone = TopicDeclaration(
      topic: state('m.n'),
      site: 'lib/z.dart:1',
    );
    final List<TopicNameCollision> found = findTopicNameCollisions(
      <TopicDeclaration>[
        lowerEvent,
        lone,
        upperInt,
        lone,
        lowerState,
        upperOther,
        lowerEvent,
      ],
    );
    expect(found, <TopicNameCollision>[
      TopicNameCollision(
        name: 'Z.b',
        declarations: <TopicDeclaration>[upperOther, upperInt],
      ),
      TopicNameCollision(
        name: 'a.b',
        declarations: <TopicDeclaration>[lowerState, lowerEvent],
      ),
    ]);
    expect(found.first.declarations, <TopicDeclaration>[upperOther, upperInt]);
  });

  test('G18 findTopicNameCollisions reads its argument once, and later '
      'changes to the argument do not reach its result', () {
    final List<TopicDeclaration> given = <TopicDeclaration>[
      TopicDeclaration(topic: state('once.t'), site: 'lib/a.dart:1'),
      TopicDeclaration(topic: event('once.t'), site: 'lib/b.dart:1'),
    ];
    int reads = 0;
    final Iterable<TopicDeclaration> lazy = Iterable<int>.generate(1)
        .expand((int _) {
          reads++;
          return given;
        });
    final List<TopicNameCollision> found = findTopicNameCollisions(lazy);
    given.add(TopicDeclaration(topic: state('once.t'), site: 'lib/c.dart:1'));
    expect(reads, 1);
    expect(found.single.declarations, hasLength(2));
  });

  test(
    'G3 findTopicNameCollisions returns an unmodifiable list, empty or not',
    () {
      final List<TopicNameCollision> none = findTopicNameCollisions(
        const <TopicDeclaration>[],
      );
      final List<TopicNameCollision> one = findTopicNameCollisions(
        <TopicDeclaration>[
          TopicDeclaration(topic: state('u.t'), site: 'lib/a.dart:1'),
          TopicDeclaration(topic: state('u.t'), site: 'lib/b.dart:1'),
        ],
      );
      expect(none, isEmpty);
      expect(one, hasLength(1));
      expect(() => none.add(one.first), throwsUnsupportedError);
      expect(() => one.clear(), throwsUnsupportedError);
    },
  );

  test('G17 a clean graph grown from generated parts has no finding after '
      'any one of its topologies or claims is removed', () {
    int sizable = 0;
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = cleanGraph(generatedParts(seed));
      expect(analyzeTopologyGraph(g), isEmpty, reason: 'seed $seed');
      for (int i = 0; i < g.topologies.length; i++) {
        final TopologyGraph less = TopologyGraph(
          topologies: <TopologyDefinition>[...g.topologies]..removeAt(i),
          claims: g.claims,
        );
        expect(analyzeTopologyGraph(less), isEmpty, reason: 'seed $seed, -$i');
      }
      for (int i = 0; i < g.claims.length; i++) {
        final TopologyGraph less = TopologyGraph(
          topologies: g.topologies,
          claims: <ShellClaim>[...g.claims]..removeAt(i),
        );
        expect(analyzeTopologyGraph(less), isEmpty, reason: 'seed $seed, -c$i');
      }
      sizable += g.topologies.length + g.claims.length >= 3 ? 1 : 0;
    }
    // The seeds reach clean graphs of three or more topologies and claims.
    expect(sizable, greaterThan(45));
  });

  test('G17 the findings of a generated graph are its cycles, then each '
      'topology\'s self-references in graph order, then its writer conflicts, '
      'then its scope violations, every kind reached', () {
    final List<int> kinds = <int>[0, 0, 0, 0];
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      final List<TopologyCycle> cycles = findTopologyCycles(g);
      final List<SelfReference> selfReferences = <SelfReference>[
        for (final TopologyDefinition d in g.topologies)
          ...findSelfReferences(d),
      ];
      final List<WriterConflict> conflicts = findWriterConflicts(g);
      final List<ScopeViolation> violations = findScopeViolations(g);
      expect(analyzeTopologyGraph(g), <TopologyFinding>[
        ...cycles,
        ...selfReferences,
        ...conflicts,
        ...violations,
      ], reason: 'seed $seed');
      kinds[0] += cycles.length;
      kinds[1] += selfReferences.length;
      kinds[2] += conflicts.length;
      kinds[3] += violations.length;
    }
    expect(kinds, everyElement(greaterThan(90)));
  });

  test('G7 the findings of a generated graph, and the collisions of generated '
      'declarations, do not depend on the order their arguments came in', () {
    for (int seed = 0; seed < seeds; seed++) {
      final GraphParts parts = generatedParts(seed);
      final Random random = Random(seed);
      final TopologyGraph given = graphOf(parts);
      final TopologyGraph reordered = TopologyGraph(
        topologies: shuffled(parts.topologies, random),
        claims: shuffled(parts.claims, random),
      );
      expect(
        analyzeTopologyGraph(reordered),
        analyzeTopologyGraph(given),
        reason: 'seed $seed',
      );
      final List<TopicDeclaration> declarations = <TopicDeclaration>[
        for (int i = 0, n = random.nextInt(8); i < n; i++)
          declarationPool[random.nextInt(declarationPool.length)],
      ];
      expect(
        findTopicNameCollisions(shuffled(declarations, random)),
        findTopicNameCollisions(declarations),
        reason: 'seed $seed',
      );
      expect(
        findTopicNameCollisions(<TopicDeclaration>[
          ...declarations,
          ...declarations,
        ]),
        findTopicNameCollisions(declarations),
        reason: 'seed $seed, repeated',
      );
    }
  });

  test(
    'G23 every finding of a generated graph holds distinct findings, '
    'distinct ids, topics and edges, and equals itself rebuilt in reverse',
    () {
      for (int seed = 0; seed < seeds; seed++) {
        final List<TopologyFinding> findings = analyzeTopologyGraph(
          generatedGraph(seed),
        );
        expect(
          findings.toSet(),
          hasLength(findings.length),
          reason: 'seed $seed',
        );
        for (final TopologyFinding finding in findings) {
          final TopologyFinding rebuilt = switch (finding) {
            TopologyCycle(
              :final List<String> topologyIds,
              :final List<TopicRef> topics,
            ) =>
              TopologyCycle(
                topologyIds: topologyIds.reversed.toList(),
                topics: topics.reversed.toList(),
              ),
            SelfReference(
              :final String topologyId,
              :final TopicRef topic,
              :final List<int> edges,
            ) =>
              SelfReference(
                topologyId: topologyId,
                topic: topic,
                edges: edges.reversed.toList(),
              ),
            WriterConflict(
              :final TopicRef topic,
              :final List<MessageSource> writers,
            ) =>
              WriterConflict(topic: topic, writers: writers.reversed.toList()),
            ScopeViolation() => finding,
          };
          expect(rebuilt, finding, reason: 'seed $seed');
          switch (finding) {
            case TopologyCycle(
              :final List<String> topologyIds,
              :final List<TopicRef> topics,
            ):
              expect(
                topologyIds.toSet(),
                hasLength(topologyIds.length),
                reason: 'seed $seed',
              );
              expect(
                topics.toSet(),
                hasLength(topics.length),
                reason: 'seed $seed',
              );
            case SelfReference(:final List<int> edges):
              expect(
                edges.toSet(),
                hasLength(edges.length),
                reason: 'seed $seed',
              );
            case WriterConflict() || ScopeViolation():
              break;
          }
        }
      }
    },
  );
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm dart test packages/nidana_dart_contracts/test/analyze_graph_test.dart`
Expected: `+0 -9: Some tests failed.`, each of the nine on `UnimplementedError` (T4.2).

Run: `fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G3,G7,G17,G18,G23; echo "exit: $?"`
Expected: `cases (2 passed, 6 failed, 0 skipped under dart test, restricted to topology-ir G3, G7, G17, G18, G23)`, the six of Task 4's row above failing, `exit: 1` (T4.2).

- [ ] **Step 3: Implement both in `packages/nidana_dart_contracts/lib/src/analysis/analyses.dart`**

No import changes.
- `analyzeTopologyGraph(graph)`, replacing its stub under the dartdoc it has: `List<TopologyFinding>.unmodifiable(<TopologyFinding>[...findTopologyCycles(graph), for (final TopologyDefinition topology in graph.topologies) ...findSelfReferences(topology), ...findWriterConflicts(graph), ...findScopeViolations(graph)])` (G17).
- `findTopicNameCollisions(declarations)`, replacing its stub (decision 9): one `for` over `declarations` into a `Map<String, Set<TopicDeclaration>>` keyed by `declaration.topic.name` (`byName[name] ??= <TopicDeclaration>{}`); then, for each name of `byName.keys.toList()..sort()` whose set holds two or more, `TopicNameCollision(name: name, declarations: set.toList())`; return `List<TopicNameCollision>.unmodifiable(...)`. Its comment: `// One collision per name with two or more distinct declarations, whatever their variants and types, ordered by name as String.compareTo orders it (G18). [declarations] is read once, and a repeated declaration counts once.`

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm dart format packages/nidana_dart_contracts && fvm dart test packages/nidana_dart_contracts && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check topology-ir --set behavior --guarantee G3,G7,G17,G18,G23 && fvm dart run nidana_contract_check topology-ir --guarantee G2,G3,G5,G6,G7,G8,G9,G10,G11,G12,G13,G14,G15,G16,G17,G18,G23`
Expected: `+264: All tests passed!`, `No issues found!`, `PASS behavior ...: 8 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G3, G7, G17, G18, G23`, then `PASS behavior ...: 31 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G3, G5 to G18, G23` and `61 fixtures: 61 passed, 0 failed, 0 pending`. No `throw UnimplementedError()` is left in `analyses.dart` (T4.4).

- [ ] **Step 5: Commit**

```bash
git add packages/nidana_dart_contracts/lib/src/analysis/analyses.dart packages/nidana_dart_contracts/test/analyze_graph_test.dart
git commit -m "feat(dart_contracts): analyze topology graphs and find topic name collisions" -m "<the co-author trailer your harness gives>"
```

### Task 5: Gate and verification doc

You write the phase's verification doc. Run every command from the repository root with `fvm dart`. This task changes one file, `hsdd/verify/nidana.model.12.verification.md`; nothing else under `hsdd/` changes.

**Files:**
- Create: `hsdd/verify/nidana.model.12.verification.md` (from `hsdd/templates/verification.md`)

**Interfaces:**
- Consumes: the package of Tasks 1 to 4; the gate output; this plan's Design decisions, Routed items and Review Focus; `docs/auto-run/experiments/analyses-plan/output.txt` (F1, F2, D); `hsdd/verify/nidana.model.11.verification.md` (the layout of a verification doc in this node).
- Produces: the verification doc.

- [ ] **Step 1: Run the gate and keep its output**

Take the time with `date -u +%Y-%m-%dT%H:%M:%SZ`, then run: `(fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl && fvm dart run nidana_contract_check topology-ir --guarantee G2,G3,G5,G6,G7,G8,G9,G10,G11,G12,G13,G14,G15,G16,G17,G18,G23) > "${TMPDIR:-/tmp}/nidana.model.12-gate.txt" 2>&1; echo "exit: $?"`, take the time again, and read the file.
Expected: `exit: 0`; the file holds, in order, `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+264: All tests passed!` (more if the implementers added tests), `PASS behavior hsdd/contract/fixture/topic-model/behavior/nidana_dart_contracts_test.dart: 41 passed, 0 failed, 0 skipped under dart test`, `PASS behavior hsdd/contract/fixture/topology-dsl/behavior/topology_builder_test.dart: 24 passed, 0 failed, 0 skipped under dart test`, `59 fixtures: 59 passed, 0 failed, 0 pending`, `PASS behavior hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart: 31 passed, 0 failed, 0 skipped under dart test, restricted to topology-ir G2, G3, G5 to G18, G23` and `61 fixtures: 61 passed, 0 failed, 0 pending`, with no `FAIL`, `ERROR` or `PENDING` line (G). A failure stops here: it is fixed in the task that owns the code, never by editing `hsdd/`.

- [ ] **Step 2: Run the checklist and keep its output**

With `{base}` the parent of Task 1's commit (the phase base):

```sh
fvm dart test hsdd/contract/fixture/topology-ir/behavior/nidana_dart_contracts_test.dart --name '^G(3|7|13|14|15|16|17|18|23) ' -r expanded
fvm dart test packages/nidana_dart_contracts/test/topology_cycles_test.dart packages/nidana_dart_contracts/test/self_references_test.dart packages/nidana_dart_contracts/test/ownership_test.dart packages/nidana_dart_contracts/test/analyze_graph_test.dart -j 1 -r expanded
fvm dart run nidana_contract_check topology-ir --set behavior; echo "exit: $?"
grep -rn "UnimplementedError" packages/nidana_dart_contracts/lib/src/analysis; echo "exit: $?"
git diff --name-status {base} HEAD -- packages/nidana_dart_contracts
git status --short pubspec.lock
git diff --stat {base} HEAD -- packages/nidana_dart_contracts/pubspec.yaml
```

Expected (C): the 14 case names of G3, G7, G13 to G18 and G23, then `+14: All tests passed!`; the 29 test names of the four new files, then `+29: All tests passed!` (more if the implementers added tests); for the unrestricted replay `FAIL behavior` with `cases (31 passed, 12 failed, 0 skipped under dart test)`, the 12 being G4 and the G19 to G22 cases, then `10 fixtures: 9 passed, 1 failed, 0 pending` and `exit: 1`, by design until nidana.model.14; no line and `exit: 1` for the search; six lines of `git diff --name-status`, `M` for `lib/src/analysis/analyses.dart` and `A` for `test/src/analysis_support.dart` and the four test files; nothing from the last two.

- [ ] **Step 3: Write `hsdd/verify/nidana.model.12.verification.md` at full-review depth**

Copy `hsdd/templates/verification.md`, keep its headings in their order, replace every `<...>` placeholder with content, and drop the opening blockquote (instructions to the writer). The first line is exactly `# Verification: nidana.model.12 - Analyses` (a spaced hyphen; no em-dash anywhere in the file).

- **Commands to run:** one-time setup on a fresh checkout (`fvm install` reads `.fvmrc`; `fvm dart pub get`); the gate of Step 1, saying what it replays: topic-model@v1 and topology-dsl@v2 unrestricted (topology-dsl@v2's recording suite; its live suite is bus-api@v2's to bind and nidana.runtime's to replay), topology-ir@v1's `structure`, `surface`, `reject` and `schema` sets in full and its `behavior` set through `nidana_dart_contracts_test.dart` under `dart test`, restricted to G2, G3, G5 to G18 and G23, which validates this phase's real output, the analyses' findings, against the suite; the commands of Step 2, with `{base}` written out.
- **Expected output:** the gate's lines as Step 1 lists them, with the package's test count as it stands and the reason it differs from the plan's 264 if it does; the checklist's output as Step 2 lists it, naming the 12 cases the unrestricted replay fails and the phases that deliver them.
- **Observed:** dated (`date -u`), with the branch, the HEAD and the phase base; the gate's exit code and lines as they appeared; the test count by file; the Step 2 outputs; a checklist of the phase's Verification line, each part with the cases and tests that show it (this plan's "The phase's Verification line"); that the restricted replay passed 31 of 31 against 19 at the phase base, the 12 turned green as this plan's table says; the design rationale for every non-obvious choice, one line per Design decision 2 to 11 (the iterative search and F1's depths, the arcs, the topics between members, the sort by first id, the two passes, the owner list, the order of violations and its tie-break, the collisions, unmodifiable results, the generator, its oracles and its floors with F2's counts); each Routed item and its disposition; every deviation from this plan, each with the ruling and the test that pins it; the choices where the plan left room.
- **Outstanding:** `None.`, unless something could not be verified here; G22's clause that the analyses create no timer and schedule no microtask first replays at nidana.model.14, which is not an Outstanding item of this phase (D6's `purity_test.dart` checks `lib/` today).
- **Learnings:** gate-time findings about the tree, one line each, beginning `- ` and ending with exactly one disposition (`spec-updated`, `contract-bumped (id@v)`, `adr-proposed (ADR-nnn)` or `dropped (reason)`, with no `)` inside the reason). Candidates, each kept only if the gate still shows it: topology-ir@v1 orders scope violations by owner without saying how two owners with one source and two scopes order, and this phase breaks the tie by scope (decision 8; proposed `dropped (routed as contract gap S143 to hsdd-contract for topology-ir@v1)` unless the orchestrator has routed it otherwise); no conformance case is deep enough to reject a recursive cycle search, which overflows the stack at a ring of 10000 topologies under `dart test` (F1), so the suite would pass an implementation that fails G13 on a long catalog chain (proposed `dropped (routed to the end-of-node governance sweep for topology-ir@v1)`); the phase's size against its estimate of about 380 lines in about 4 files (proposed `dropped (sizing is the owner's to revisit at a checkpoint)`). Write `- none` only when nothing applies; never leave the section empty.
- **Metrics:** gate failures before green; fix rounds after task review and after the final review; wall-clock from the start of the implementation step to the gate; the product diff in lines, `git diff --stat {base} HEAD -- packages/` by part (library, tests), beside the estimate of about 380 lines in about 4 files, tests included (the dry run's came to 278 library lines and 1296 test lines in 6 files, C); the task count, 5 of the allowed 6; package tests 235 at the phase base and the count now.
- **Sign-off:** the template's four bullets exactly as the template writes them, nothing filled in (`- Reviewer / date:` stays empty), and its closing blockquote; the owner signs.

- [ ] **Step 4: Commit**

```bash
git add hsdd/verify/nidana.model.12.verification.md
git commit -m "docs(verify): nidana.model.12 verification" -m "<the co-author trailer your harness gives>"
```
