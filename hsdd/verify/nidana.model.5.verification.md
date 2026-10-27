# Verification: nidana.model.5 - topology-ir@v1 declarations

## Commands to run

Every command runs from the repository root, with `fvm`, never a bare `dart`.

One-time setup on a fresh checkout:

```sh
fvm install            # reads .fvmrc: Flutter 3.47.7, which bundles Dart 3.13.5
fvm dart pub get       # resolves the whole workspace into the committed root pubspec.lock
```

The gate, which replays the `structure`, `surface`, `reject` and `schema` sets of topic-model@v1, topology-dsl@v2 and topology-ir@v1 against the real package:

```sh
fvm dart pub get --enforce-lockfile && fvm dart analyze --fatal-infos && fvm dart run nidana_contract_check --all --set structure && fvm dart test packages/nidana_dart_contracts && fvm dart run nidana_contract_check topic-model topology-dsl topology-ir --set structure,surface,reject,schema
```

The `schema` set validates every `valid/` document and no `invalid/` one against `hsdd/contract/schema/topology-ir.schema.json`. The producer's own encoding is checked against that schema by the behavior set once nidana.model.13 delivers the codec (G19, `expectMatchesSchema`).

The checklist, where `<base>` is the parent of Task 1's commit (`36ead77`):

```sh
git diff --name-status <base> HEAD -- packages/nidana_dart_contracts/lib
grep -n '^export' packages/nidana_dart_contracts/lib/topology_ir.dart
grep -rn "nidana_dart_contracts/src/" packages hsdd/contract/fixture --include='*.dart' | grep -v '^packages/nidana_dart_contracts/'; echo "exit: $?"
grep -rnE "operator ==|hashCode|toString\(\)" packages/nidana_dart_contracts/lib/src/graph packages/nidana_dart_contracts/lib/src/analysis packages/nidana_dart_contracts/lib/src/json packages/nidana_dart_contracts/lib/src/render; echo "exit: $?"
git status --short pubspec.lock
fvm dart run nidana_contract_check topology-ir --set surface,reject; echo "exit: $?"
```

The last command is the routed baseline command, which Task 1 ran as the phase's failing replay; the gate's last command replays the same sets among its 117 fixtures.

## Expected output

- The gate exits 0 and its output holds, in order: `Got dependencies!`, `No issues found!`, `102 fixtures: 102 passed, 0 failed, 0 pending`, `+38: All tests passed!` and `117 fixtures: 117 passed, 0 failed, 0 pending`. No `FAIL`, `ERROR` or `PENDING` fixture line appears.
- The checklist prints, in order: six `A` lines for `packages/nidana_dart_contracts/lib/` (`src/analysis/analyses.dart`, `src/analysis/findings.dart`, `src/graph/graph.dart`, `src/json/codec.dart`, `src/render/renderers.dart`, `topology_ir.dart`) and no `M` line; five `export 'src/...'` lines, none naming `nidana_dart_contracts.dart`; no line and `exit: 1` for each of the two `grep -r` commands; nothing for the lockfile; and `14 fixtures: 14 passed, 0 failed, 0 pending` with `exit: 0` for the `topology-ir` run.

## Observed

Run on 2026-10-27 (`date -u +%Y-%m-%d`). The gate started at 2026-10-27T02:30:06Z and ended at 02:30:10Z, on branch `impl/nidana.model.5` at `3b45707` (phase base `36ead77`), Dart 3.13.5 through `fvm`. The checklist ran at 2026-10-27T02:30:23Z, and the `topology-ir` run at 02:30:28Z.

- The gate exited 0. Its five lines, as they appeared, in order:
  - `Got dependencies!`
  - `No issues found!`
  - `102 fixtures: 102 passed, 0 failed, 0 pending`
  - `00:00 +38: All tests passed!`
  - `117 fixtures: 117 passed, 0 failed, 0 pending` (42 `PASS structure`, 7 `PASS surface`, 22 `PASS reject` and 46 `PASS schema` lines; no `FAIL`, `ERROR` or `PENDING` line)
- Checklist:
  - [x] This is the first replay of topology-ir@v1's 2 surface and 3 reject libraries against the real package, and all 5 passed, beside topic-model@v1's and topology-dsl@v2's (22 reject libraries in all: 10, 9 and 3). Every reject code the stand-ins confirmed holds, none differs, and no line carries two codes, since a reject library passes only when its reported (line, code) pairs equal its one-code markers. The routed baseline command went from `14 fixtures: 11 passed, 3 failed, 0 pending` (Task 1's first run) to `14 fixtures: 14 passed, 0 failed, 0 pending`, `exit: 0`.
  - [x] `topology_ir.dart` exports exactly the 24 declarations of topology-ir@v1's Graphs, Renderers, The JSON form and Analyses, and the main library none of them (`exports_test.dart` passes: the main library 40, `topology_plan.dart` 27, `topology_ir.dart` 24). It does not re-export the main library: the `grep` printed five `export 'src/...'` lines and none names `nidana_dart_contracts.dart`. No code outside the package imports its `src/`: the `grep -r` printed no line and `exit: 1`.
  - [x] No IR value, graph, claim or finding can be assigned to (`reject/ir_values_are_immutable.dart` passes), the families are closed (`reject/ir_families_are_closed.dart` passes), and a `FunctionRef` cannot be called (`reject/ir_holds_no_function.dart` passes).
  - [x] The phase created `topology_ir.dart` and its four areas and edited no file nidana.model.4 wrote under `lib/`: `git diff --name-status 36ead77 HEAD -- packages/nidana_dart_contracts/lib` printed six `A` lines and no `M` line. No new class overrides `==`, `hashCode` or `toString`: the `grep -r` printed no line and `exit: 1`. `purity_test.dart` holds the package to `meta` and `test` and to no clock, timer, microtask, id or I/O over the new libraries (G25, G26) and passes. The lockfile is unchanged: `git status --short pubspec.lock` printed nothing.

With this phase every declaration of topic-model@v1, topology-dsl@v2 and topology-ir@v1 resolves: this is the end of the types band, the point the phase consumers' first phases compile against (root D10).

## Outstanding

None.

## Learnings

- ADR-001 item 4's marker form names one diagnostic per marked line, and all 22 reject libraries of topic-model@v1, topology-dsl@v2 and topology-ir@v1 report one code per line, so the form held for nidana.model's three contracts. Disposition: dropped (the reject sets of bus-api, bus-testing, navigation-api and flutter-binding meet it at their producers' first gates)
- topology-ir@v1's surface fixtures never use `ScopeViolation` or `TopicDeclaration` in a const context, so a non-const constructor would pass the replay; this phase's package test pins it, and the plan's dry run seeded the defect. Disposition: dropped (the package test covers it; a compatible hsdd-contract touch in the end-of-node governance sweep can add a const use to the surface fixture)
- nidana.model D3's final field behind every getter leaves the private constructors of `ShellClaim` and `TopologyGraph` unused beside their throwing factories, so the package carries two more `// ignore: unused_element` lines, above `ShellClaim._` and `TopologyGraph._`, until nidana.model.11 constructs through them. Disposition: dropped (temporary; nidana.model.11 removes them)
- topology-ir@v1's Interface prose says every value type is annotated `@immutable`, while its Graphs and Analyses code blocks, like its IR blocks, show no annotation; the declarations follow the prose, the sealed `TopologyFinding` included. Disposition: dropped (already routed to the governance sweep at the end of nidana.model; no fixture depends on it)
- The phase scope estimated about 260 lines in about 8 files; the product diff is 416 insertions and 3 deletions in 8 files (see Metrics). Disposition: dropped (sizing is the owner's to revisit at a checkpoint)

## Metrics

- Product diff, `git diff --stat 36ead77 HEAD -- packages/`, where `36ead77` is the parent of Task 1's commit: 8 files changed, 416 insertions, 3 deletions, of which the library is 6 files and 249 lines and the tests 2 files, 167 insertions and 3 deletions, beside the estimate of about 260 lines in about 8 files; the task count is 3 of the allowed 4 (this doc is Task 3's one file).

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
