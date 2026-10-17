# nidana.tooling: Build and CI Tooling

- **Kind:** internal
- **Purpose:** the static half of the architecture's enforcement and its build-time artifacts (Guide Appendix C, planned v1 for Dart): topic registry generation and catalog, the topology catalog scan and graph emission, and the CI checks that move runtime failures to merge time
- **Owns:**
  - packages `nidana_dart_codegen` and `nidana_dart_lint` (ADR-002)
  - the `topics.yaml` input format and the registry classes generated from it through build_runner, including sensitivity and owner fields (Spec §4.5, Guide C.3)
  - the topic catalog `topics.md` (Spec §4.5, Guide C.3)
  - `Catalog.scanTopologies` for Dart and `topology-graph.json` (Spec §6.5, Guide C.3), with the registration mechanism the scan needs to instantiate topology classes (Spec §6.5)
  - the build-time topology graph as static HTML (Guide C.4)
  - the v1 checks (root D1): topic name uniqueness across registries (Spec §4.3); the single-writer workspace scan over topology `write(...)` calls and publisher `writes` claims, with unresolvable write sets reported as warnings (Spec §3.11 layer 2); inter-topology cycles and intra-topology self-reference (Spec §3.8); scope compatibility over the aggregated IR (Spec §7.2); raw-string topic use (Spec §4.4); a global bus accessor (Guide C.5); the sensitive flag on known-sensitive types, as a warning (Spec §9.2, Guide C.1)
  - the delivery of those checks: per-library rules in the analysis server plugin `nidana_dart_lint` on the Dart 3.10 plugin API, and the workspace scan, which runs every check over more than one library or over the IR, as a command entry of `nidana_dart_codegen` (ADR-002 items 7 and 8)
- **Does not own:** the analyses' algorithms, which are pure functions in nidana.model that tooling runs over what it scans; runtime enforcement of the same rules (nidana.runtime); the checks D1 defers to v2
- **Consumes:** [topic-model@v1, topology-dsl@v1, topology-ir@v1, bus-api@v1]
- **Produces:** [topic-codegen@v1, nidana-checks@v1]
- **Governed by:** [ADR-001, ADR-002]
- **Sources:**
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_0.md` §3.8, §3.11, §4.3 to §4.6, §6.3, §6.4, §6.5, §7.2, §7.6, §9.2
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-guide-v0_15_0.md` §5.1, §5.2, Appendix C.1 to C.5
- **Decomposes into:** child nodes minted by a later hsdd-spec run on this node
- **Isolation strategy:** analyzer-based checks run over source fixtures resolved in the workspace and never execute a bus; they recognize the bus-api@v1 and topology-dsl@v1 surfaces by library URI and element name; the codegen is tested against golden `input/` and `expected/` trees (topic-codegen@v1 fixtures); catalog and graph checks run over fixture topologies through the model's recorder

## Overview

The runtime catches every single-writer, cycle and scope violation at activation, which is loud but late (Spec §3.11). This node moves the same failures to merge: the same pure analyses run over everything the workspace declares, and per-file rules report misuse in the IDE and in `dart analyze`. It also produces the build artifacts the Specification asks for at scale: generated registries, the topic catalog and the static topology graph.

This node is internal because it spans three mechanisms with different hosts and test styles (build_runner builders, an analyzer plugin, a workspace scan command); its own hsdd-spec step decomposes it.

## Inherited from the root

- The checks ship on the Dart 3.10 analysis server plugin API; no member depends on custom_lint, because custom_lint 0.8.1 pins a shared resolution to analyzer 8.4.0 (ADR-002, `docs/auto-run/experiments/lint-mechanism/`). A one-rule plugin flagging `Bus.instance` already runs under `fvm dart analyze` on the pinned SDK (`output-plugin.txt`).
- `nidana_dart_lint` depends on no nidana package and pins `analyzer` and `analysis_server_plugin` to the lockfile's versions, because the analysis server resolves a plugin outside the workspace; the workspace root's analysis options enable it (ADR-002 item 7). The aggregate checks, which run `nidana_dart_contracts`' analyses, are therefore commands of `nidana_dart_codegen` (ADR-002 item 8).
- Deferred to v2 (root D1): sequencer, unreachable topics, orphan reads, transformer purity, sensitive flag as an error, the Initializing-variant lint, the stream-factory-plus-publish lint of Spec §6.3, binary-module manifests.

## Open questions

| ID | Question | Status | Waits on | Affects |
|----|----------|--------|----------|---------|
| OQ-T1 | How does `Catalog.scanTopologies` obtain every `TopologyDefinition` in Dart, where Flutter builds have no reflection? | OPEN | this node's decomposition | nidana-checks@v1, topic-codegen@v1 |
| OQ-T2 | Where does the single-writer workspace scan run, given that analysis server plugin rules see one library at a time while Spec §3.11 aggregates claims across the workspace? | PARTIAL | this node's decomposition, for what the scan reads; ADR-002 item 8 fixed its host | nidana-checks@v1 |

### OQ-T1: Catalog scan without reflection

Spec §6.5 has the catalog instantiate every topology class and call `buildDefinition()`, with zero-argument constructors or a build-time registration mechanism. Options: a build_runner builder generates a catalog entry point listing every registered topology class, which a command runs on the VM to emit the IR; or the scan extracts reads and writes statically from the AST without running `declare()`. The first reuses the model's recorder, so the static graph and the runtime graph come from one code path (Spec §6.5); the second needs no registration but re-implements the DSL's meaning in the analyzer.

### OQ-T2: Placement of the single-writer scan

Per-library plugin rules can flag a claim, but only an aggregate sees two claimants on one topic. Options: a workspace scan command over `package:analyzer` that collects topology writes and publisher claims; the catalog's IR for topology writes plus an AST scan for publisher claims, since publishers are not topologies; or both, with the plugin rule surfacing the scan's verdict in the IDE.

Partially resolved (2026-10-17) by ADR-002 item 8: the scan is a command entry of `nidana_dart_codegen`, because `nidana_dart_lint` can depend on no nidana package (`docs/auto-run/experiments/workspace-layout/` Q12) and the scan runs `nidana_dart_contracts`' analyses. What the scan reads, among the options above, remains with this node's decomposition; under the third option the plugin would read the scan's output, not run the analyses.
