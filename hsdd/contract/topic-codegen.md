---
id: topic-codegen
version: v1
status: draft
kind: file
owner: nidana.tooling
compatibility: versioned
produced_by: [nidana.tooling]
consumers: [nidana.integration]
external_consumers: [app builds running build_runner over lib/topics.yaml, app CI publishing topics.md and the topology graph page, CI tools reading topology-graph.json]
phase_ids: provisional
---

# Contract: topic-codegen

- **Governed by:** [ADR-001, ADR-002]

The build-time artifacts of `nidana_dart_codegen` (Spec §4.5, §4.6, §6.5; Guide C.2 to C.4): the `topics.yaml` format an app writes, the typed registry library generated from it, the build_runner builder and the `generate` command that both write that library, the topic catalog `topics.md`, the static topology graph page `topology-graph.html`, and the topology graph document `topology-graph.json` with the `catalog` command that writes it. A file here is either input an app writes or output the tooling writes; this contract fixes both byte for byte where a fixture can replay them, and by rule where it cannot.

## Boundary

| Concern | Contract |
|---------|----------|
| The topics document (`topics.yaml`) and its schema; the registry library `topics.g.dart`; the builder `nidana_dart_codegen:topics`; the `generate` command; `topics.md`; `topology-graph.html`; the path, content rule, writer and exit codes of `topology-graph.json` and the `catalog` command | topic-codegen@v1 |
| How `catalog` obtains the topologies of a package (OQ-T1); how the workspace scan recognizes shell claims and topic declarations; the static checks, their diagnostics and the workspace scan command | nidana.tooling's decomposition; nidana-checks@v1 |
| `StateTopic`, `EventTopic`, `ReplayTopic`, `Dedup`, `Tracing`, their constructors and defaults, `isWellFormedTopicName` | topic-model@v1 |
| `Topology.buildDefinition()` | topology-dsl@v1 |
| The graph document's form and schema, `TopologyGraph`, `ShellClaim`, `decodeTopologyGraph`, `JsonRenderer`, `MermaidRenderer` | topology-ir@v1 |

- **Refinement 1.** One registry library per schema file. Guide C.3 shows one Dart file per domain (`auth_topics.dart`). A build_runner builder's outputs are fixed by its input's path before the input is read, so no builder can name a file after a domain declared inside `topics.yaml`. The generated library holds one registry class per domain instead, so app code reads `AuthTopics.state` as Spec §4.2 and Guide C.3 show. Marked for upstreaming: Guide C.3's Dart row.
- **Refinement 2.** Two commands. `generate` is pure over two files, `topics.yaml` and an optional graph document, and is what the file replay runs. `catalog` loads and records the app's topologies on the Dart VM and scans its sources for shell claims, so it writes the graph document that `generate` reads. The graph document (topology-ir@v1's form) is the seam: `topics.md`, `topology-graph.html` and any check that reads `topology-graph.json` see one graph, whatever mechanism the decomposition gives `catalog`.
- **Refinement 3.** Settings only the Dart generator reads sit under a `dart` key, so the schema file stays the single source for every platform's generator (Spec §4.5, Guide C.3) and a later platform takes a key of its own.
- **Refinement 4.** The registry carries topics only (Spec §4.6, Guide C.5): no topology identifier, `TopologyRef` or topology reaches a generated library. `topics.md`, `topology-graph.html` and `topology-graph.json` name topologies, and are build output for people and CI tools, never an importable library.

Not here: `routes.yaml` and `policies.yaml` (Guide C.3), which root D1 does not schedule; generators for other platforms (root D1); the static checks (nidana-checks@v1), the topic name uniqueness check among them, which reads a generated registry like a hand-written one.

## Interface

**Package:** `nidana_dart_codegen` at `packages/nidana_dart_codegen/` (ADR-002 item 3). It declares the builder in its `build.yaml` and the two executables under `bin/`, run from the workspace root as `fvm dart run nidana_dart_codegen:{executable}` (ADR-002 item 8). Its Dart libraries are not part of this contract: consumers use the builder, the commands and the files. **Code owner:** nidana.tooling, through the phases its decomposition assigns. **Validation artifacts:** `hsdd/contract/schema/topic-codegen.schema.json` and `hsdd/contract/fixture/topic-codegen/`, owned by hsdd-contract (ADR-001 item 8).

| Artifact | Written by | Where | Read by |
|----------|------------|-------|---------|
| topics document | the app | `lib/topics.yaml` of the package that holds the registry | the builder, `generate` |
| registry library | the builder; `generate` | `lib/topics.g.dart` beside the document; `{output}/topics.g.dart` | app code, the workspace scan |
| topology graph document | `catalog` | `{output}/topology-graph.json` | `generate`, nidana-checks@v1, CI tools |
| topic catalog | `generate` | `{output}/topics.md` | people |
| topology graph page | `generate`, given a graph | `{output}/topology-graph.html` | people |

An app build runs the three in order: `fvm dart run build_runner build` in the package (ADR-002 Consequences), then `catalog` over the packages of the coordination domain, then `generate` with `--graph` on what `catalog` wrote. Because `generate` writes the registry library with the builder's bytes (G11), a CI step can compare `{output}/topics.g.dart` with the committed `lib/topics.g.dart` to catch a stale registry.

### The topics document

A YAML file holding one document. Every value below is checked; no other key is allowed anywhere, so a misspelled key such as `sensitve` is an error rather than a silent default. `hsdd/contract/schema/topic-codegen.schema.json` (draft 2020-12) states the document's data model exactly.

| Key | In | Value | Required | Default |
|-----|----|-------|----------|---------|
| `domains` | the document | a mapping with at least one entry, domain key to domain | yes | none |
| domain key | `domains` | one segment, `[a-z][a-z0-9]*(-[a-z0-9]+)*`, the first segment of its topics' names (Spec §4.4) | | |
| `owner` | domain | the owning team (Spec §4.5, Appendix A.9): one non-blank line without surrounding white space | yes | none |
| `dart` | domain | a mapping holding only `imports` | no | none |
| `imports` | `dart` | a list of distinct URIs the registry library imports for this domain's types: `dart:{library}`, or a `package:` or relative URI ending in `.dart`, without white space, quote or backslash | no | empty |
| `topics` | domain | a mapping with at least one entry, topic key to topic | yes | none |
| topic key | `topics` | one segment or two joined by `.`, each as a domain key, so the topic name `{domain}.{key}` has two or three segments | | |
| `type` | topic | the Dart value type, written as the type argument: one non-blank line without surrounding white space | yes | none |
| `variant` | topic | `state`, `event` or `replay` | yes | none |
| `initial` | state topic | the initial value (below) | for a state topic; not allowed otherwise | none |
| `dedup` | state topic | `equality` or `none` | not allowed for event and replay topics | `equality` |
| `buffer-size` | replay topic | an integer of at least 1 | for a replay topic; not allowed otherwise | none |
| `sensitive` | topic | `true` or `false` (Spec §9.2) | no | `false` |
| `tracing` | topic | `enabled` or `disabled` (Guide §8.1) | no | `enabled` |
| `description` | topic | Markdown holding at least one non-blank character | no | none |

**The initial value.** A string holds a Dart expression of the topic's type, copied verbatim into the generated library and evaluated there, with the domain's imports in scope: `const AuthState.initializing()`, `CartItems.empty`, `'text'` (written `"'text'"` in YAML). An integer is written as its decimal literal, a float as Dart's `double.toString()` renders it, a boolean as `true` or `false`, and null (`null`, `~` or an empty value) as `null`. A string must be one non-blank line without surrounding white space. Spec §4.5's example values `Initializing` and `empty` are therefore identifiers the library must have in scope: the Specification's schema is shared across platforms and does not say what `initial` holds, and this tree reads it as a Dart expression (marked for upstreaming).

**Rules the schema cannot state.** The generator also rejects a document when:

- **R1** the file is not exactly one YAML document, or any mapping repeats a key, so two topics never share a name (Spec §4.3, §4.5: codegen makes duplicates structurally impossible);
- **R2** two domains derive the same registry class name, or two topics of one domain the same member name (identifier rules below), such as `token.refresh` and `token-refresh`;
- **R3** a member name is one of Dart's 33 reserved words or `hashCode`, `runtimeType`, `toString` or `noSuchMethod`, which a static member beside `Object`'s instance members cannot take (`docs/auto-run/experiments/topic-codegen-fixtures/probe/names/output.txt`; Dart's built-in and contextual identifiers, `get` or `await` among them, compile and stay allowed);
- **R4** a number `initial` is not finite (YAML `.inf` and `.nan`).

**Identifiers.** The registry class of domain `d` is `d` split at `-`, each part with its first letter upper-cased, joined, then `Topics`: `auth` gives `AuthTopics`, `user-profile` gives `UserProfileTopics`. The member of topic key `k` is `k` split at `.` and `-`, the first part as it is and every later part with its first letter upper-cased, joined: `login-event` gives `loginEvent`, `token.refresh` gives `tokenRefresh`. Both pass the root lint set's naming rules by construction.

### The registry library

`topics.g.dart`, the same bytes from the builder and from `generate` (G11), laid out in this order:

1. Two header lines: `// GENERATED CODE - DO NOT MODIFY BY HAND.` and `// nidana_dart_codegen from topics.yaml (topic-codegen@v1).`
2. The imports: `package:nidana_dart_contracts/nidana_dart_contracts.dart` and every `dart.imports` URI of every domain, each once, as `import '{uri}';`, in three groups (`dart:` URIs, then `package:` URIs, then relative URIs), each group sorted by `String.compareTo`, the groups separated by a blank line. A relative URI resolves against the library's own location, which for the builder is the directory of `topics.yaml`.
3. One registry class per domain, in document order: the doc comment ``/// Topics of the `{domain}` domain, owned by {owner}.``, then `abstract final class {Class} {`, its members, `}`.
4. One member per topic of the domain, in document order, separated by blank lines: the description, when there is one, as doc comment lines, then the declaration

   ```dart
   static final {Variant}<{type}> {member} = {Variant}<{type}>(name: '{domain}.{key}', ...);
   ```

   where `{Variant}` is `StateTopic`, `EventTopic` or `ReplayTopic`. The arguments, in this order: `name`; `initial: {expression}` for a state topic, `bufferSize: {n}` for a replay topic; then only those that differ from topic-model@v1's defaults (G6 there): `dedup: Dedup.none`, `sensitive: true`, `tracing: Tracing.disabled`.
5. Nothing else: no constructor, no collection of topics, no top-level declaration, no topology identifier, `TopologyRef` or topology (Spec §4.6).

The whole text is formatted with `package:dart_style`'s `DartFormatter` at language version 3.13, the workspace's SDK floor (ADR-002 item 5), so `fvm dart format` leaves it unchanged (G9) and a committed registry passes a format check.

Every member is `static final`: an `initial` expression need not be constant, Guide C.3 shows the form, and topics compare by value (topic-model@v1 G7), so nothing depends on identity. Every type is written out, on the field and as the constructor's type argument, so no type in the library is inferred; the least upper bound of event and replay topics, which topic-model@v1's `MultiWriterTopic` amendment changed, never reaches generated code.

**Doc comment and Markdown text.** A description is split into lines after trailing white space is removed from it and from each line; a line is written `/// {line}`, an empty one `///`. In descriptions and owners, every `<` and `>` outside a code span and not already backslash-escaped is written `\<` and `\>`, here and in `topics.md`, so author text never reads as HTML; `unintended_html_in_doc_comment` reports raw angle brackets and accepts code spans and escapes (`probe/doc/output.txt` in the experiment). Code spans are written as given.

An excerpt of `expected/topics.g.dart`, the `loginEvent` member left out:

```dart
/// Topics of the `auth` domain, owned by platform-team.
abstract final class AuthTopics {
  /// Current authentication state.
  static final StateTopic<AuthState> state = StateTopic<AuthState>(
    name: 'auth.state',
    initial: const AuthState.initializing(),
    sensitive: true,
  );

  static final EventTopic<TokenRefresh> tokenRefresh = EventTopic<TokenRefresh>(
    name: 'auth.token.refresh',
    tracing: Tracing.disabled,
  );
}
```

### The builder

`nidana_dart_codegen`'s `build.yaml` declares the builder `topics`, so its key is `nidana_dart_codegen:topics`:

```yaml
builders:
  topics:
    import: "package:nidana_dart_codegen/builder.dart"
    builder_factories: ["topicsBuilder"]
    build_extensions: {"^lib/topics.yaml": ["lib/topics.g.dart"]}
    auto_apply: dependents
    build_to: source
```

A package that depends on `nidana_dart_codegen` (as a dev dependency) and holds `lib/topics.yaml` gets `lib/topics.g.dart` from `fvm dart run build_runner build` run in that package; no other path is an input. The builder takes no options. For a rejected document it logs each diagnostic of `generate`'s format at severe level, fails the build and writes nothing; build_runner then deletes the `lib/topics.g.dart` an earlier build wrote (build_runner 2.16.1, as the experiment below observed), so a broken document surfaces as compile errors at every use of the registry. It calls the pure function `generate` calls for the registry, so the two write identical bytes (ADR-002 item 8).

### The generate command

```text
fvm dart run nidana_dart_codegen:generate [--graph <graph>] <topics> <output>
```

- `<topics>` is a topics document, `<output>` a directory, created with its parents when absent, and `--graph` a graph document of topology-ir@v1's form, usually what `catalog` wrote.
- It writes `<output>/topics.g.dart`, `<output>/topics.md` and, with `--graph`, `<output>/topology-graph.html`, replacing files of those names and touching nothing else in `<output>`.
- Exit codes:

  | Code | When | Writes |
  |------|------|--------|
  | 0 | the outputs are written | the outputs |
  | 1 | the topics document is rejected (schema or R1 to R4), or the graph document does not decode (`decodeTopologyGraph` throws `FormatException`, topology-ir@v1 G21) | nothing |
  | 2 | usage: not exactly two positional arguments, an unknown option, a missing input file, an output that is a file or cannot be written | nothing |

- On exit 1, stderr holds one diagnostic per line: `{path}:{line}:{column}: {message}` for the topics document, with the 1-based position of the offending YAML node and `{path}` as given on the command line, and `{path}: {message}` for the graph. On exit 2, stderr names the problem and prints the usage line. Message texts and anything on stdout are not part of this contract.
- The outputs depend on the bytes of the two input files only, never on their paths, the working directory, the time or the environment.

### The topic catalog

`topics.md`, Markdown with LF line endings, a final newline and no trailing white space; one blank line separates blocks. It lists what Spec Appendix A.9 asks of a topic catalog: every topic, its type, sensitivity and owning team, and the topologies that read and write it, derived from the graph (Guide §5.2 item 5).

1. Two HTML comment lines: `<!-- GENERATED CODE - DO NOT MODIFY BY HAND. -->`, then `<!-- nidana_dart_codegen from topics.yaml and topology-graph.json (topic-codegen@v1). -->`, or without a graph `<!-- nidana_dart_codegen from topics.yaml (topic-codegen@v1). -->`.
2. `# Topic catalog`, then one summary line: ``{n} topics in {m} domains, from `topics.yaml`.``, followed by ``Readers and writers from `topology-graph.json`: {k} topologies, {j} shell claims.`` with a graph, or `No topology graph was given, so readers and writers are not listed.` without one. Every count reads singular for one (`1 topic`, `1 shell claim`).
3. A table `| Domain | Owner | Registry | Topics |` with one row per domain in document order.
4. Per domain, in document order, the heading `## Domain` followed by the domain key, and the line `Owner: {owner}. Registry: {Class}.`; per topic, in document order, the heading `###` followed by its name, its description lines when it has one, then a table `| Property | Value |` with the rows, in order: `Member` (`{Class}.{member}`), `Variant`, `Type`, `Initial` and `Dedup` for a state topic, `Buffer size` for a replay topic, `Sensitive` (`yes` or `no`), `Tracing`, and with a graph `Written by` and `Read by`.
5. With a graph, three more sections, each a table, or the line `None.` when it has no row: `## Topologies` (`| Topology | Scope | Reads | Writes |`, one row per topology in graph order), `## Shell claims` (`| Source | Scope | Writes |`, one row per claim in graph order) and `## Topics outside topics.yaml` (`| Topic | Variant | Type | Written by | Read by |`, one row per topic of the graph, in graph order, whose name the document does not declare: hand-written registries such as `NavigationTopics`).

**Cross references.** A graph topic matches a document topic by name only, because a graph records the type as the runtime renders it (topology-ir@v1 `TopicRef.typeName`) and the document as the author wrote it. `Written by` lists, for a topic name, every topology whose `writes` hold it, in graph order, then every claim whose `writes` hold it, in graph order; `Read by` lists every topology whose `reads` hold it. Each entry is the writer's or reader's source rendering (topic-model@v1 G17: `topology:{id}`, `service:{name}` and so on) as a code span, then its scope in parentheses; entries are joined by `, `, and an empty list reads `none`. `Reads` and `Writes` in the graph sections list topic names in canonical order, joined the same way.

**Rendering.** Domain keys, class and member names, topic names, types, initial expressions, topology ids, sources and type names are code spans: line breaks become spaces, the fence is one backtick longer than the longest run of backticks in the text, and one space pads each side inside the fence when the text begins or ends with a backtick, or begins and ends with a space. In a table cell every `|` is written `\|` and every line break as a space. Owners and descriptions get the angle-bracket escape above; descriptions are otherwise written as given, as Markdown.

### The topology graph page

`topology-graph.html` (Guide C.4, root D1): a static page showing the graph through topology-ir@v1's Mermaid rendering. It is this text with LF line endings, where `{counts}` reads `{k} topologies, {j} shell claims, {t} topics.` (singular for one) and `{diagram}` is `const MermaidRenderer().render(graph)` of the decoded graph with `&`, `<` and `>` written `&amp;`, `&lt;` and `&gt;`:

```html
<!DOCTYPE html>
<!-- GENERATED CODE - DO NOT MODIFY BY HAND. -->
<!-- nidana_dart_codegen from topology-graph.json (topic-codegen@v1). -->
<html lang="en">
<head>
<meta charset="utf-8">
<title>Topology graph</title>
<script type="module">
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11.12.0/dist/mermaid.esm.min.mjs";
mermaid.initialize({ startOnLoad: true });
</script>
</head>
<body>
<h1>Topology graph</h1>
<p>{counts}</p>
<pre class="mermaid">
{diagram}</pre>
</body>
</html>
```

The page loads Mermaid 11.12.0, the version topology-ir@v1's Mermaid goldens were parsed with, from jsDelivr when it is opened. Opened without network it shows the diagram's text, which is readable on its own; the build itself needs no network. The text a browser reads from the `<pre>` element is the Mermaid rendering exactly (G15).

### The topology graph document and the catalog command

```text
fvm dart run nidana_dart_codegen:catalog <package>... <output>
```

- Each `<package>` is the root directory of a package of the coordination domain (Spec §6.5 `Catalog.scanTopologies(packages = [...])`); `<output>` is a directory, created when absent.
- It writes `<output>/topology-graph.json`: `const JsonRenderer().render(graph)` (topology-ir@v1: two-space indentation, canonical order, a final newline), where `graph` is `TopologyGraph(topologies: definitions, claims: claims)`.
- `definitions` are `buildDefinition()` of every topology the packages register, called on the Dart VM in JIT mode, never in an AOT build with `--obfuscate`, whose function names come out obfuscated (topology-ir@v1's function reference table). The static graph is thereby the one activation checks (Spec §6.5: the graph and the running system are structurally identical).
- `claims` are the shell claims the workspace scan resolves in the packages' sources, the scan nidana-checks@v1 defines, one `ShellClaim` per claim site. A claim whose write set the scan cannot resolve statically is left out and reported on stderr as a warning (Spec §3.11), and the exit code stays 0.
- Exit codes: 0, the document is written; 1, no graph can be formed: a registered topology cannot be loaded, constructed or recorded, or two unequal definitions share a `topologyId` (topology-ir@v1 G11), each cause on stderr, nothing written; 2, usage, as for `generate`.
- Left to nidana.tooling's decomposition (OQ-T1): how a package registers its topologies (a convention the scan applies to declarations, an annotation, or a list the app writes) and the build-time configuration that supplies constructor arguments (Spec §6.5); how `catalog` loads libraries that import Flutter, which `dart run` cannot load because it lacks `dart:ui` while the Flutter tester can (`probe/flutter-vm/` in the experiment); whether a builder writes a catalog entry point, which would join this contract as a file layout by amendment; how the claim scan is shared with nidana-checks@v1. None of these changes the document's content rule above.

## Guarantees / invariants

- **G1** The schema states the topics document's data model: every file under `valid/` validates against `topic-codegen.schema.json`, and no file under `invalid/` does.
- **G2** The generator accepts a topics document exactly when its data model validates against the schema and it keeps R1 to R4: it accepts every `valid/` document and the file replay's `input/topics.yaml`, and rejects every `invalid/` and every `rejected/` document, the builder by failing the build and `generate` with exit 1, writing nothing.
- **G3** `generate --graph {input}/topology-graph.json {input}/topics.yaml {output}`, run over the fixture's `input/` into an empty directory, writes exactly the files of `expected/`, byte for byte once its Dart is formatted with `fvm dart format`.
- **G4** The registry library is one file, `topics.g.dart`, laid out as The registry library states: the two header lines; the nidana import and every domain import once, grouped and sorted; one `abstract final class` per domain in document order; one `static final` member per topic in document order; and no other declaration.
- **G5** Each member is declared with its variant's class and its type written out on the field and as the constructor's type argument, the name `{domain}.{key}`, the initial expression or the buffer size, and the `dedup`, `sensitive` and `tracing` arguments exactly when they differ from topic-model@v1's defaults; no type in the library is inferred and no member is `const`.
- **G6** Registry class and member names follow the identifier rules.
- **G7** Every generated topic name is `{domain}.{key}` and satisfies `isWellFormedTopicName` (topic-model@v1 G11), and no two topics of an accepted document share a name (R1, Spec §4.3).
- **G8** The registry library carries topic types, names, references and sensitivity only, never a topology identifier, `TopologyRef`, topology or topology registry (Spec §4.6, Guide C.5).
- **G9** The generator's own Dart output is formatted: `fvm dart format` changes no byte of what the builder or `generate` writes.
- **G10** The registry library compiles against `nidana_dart_contracts` and reports no diagnostic under the workspace root's lint set, strict modes and `--fatal-infos` (ADR-002 item 2), whenever every `type` is a Dart type and every `initial` an expression of that type in scope through the domain's imports.
- **G11** The builder `nidana_dart_codegen:topics` applies to every package that depends on `nidana_dart_codegen` directly, reads `lib/topics.yaml` only, writes `lib/topics.g.dart` into the source tree, and writes the same bytes `generate` writes for the same document.
- **G12** `topics.md` follows The topic catalog's structure and rendering rules: header, summary, domain table, one section per domain and per topic in document order with its property rows, and with a graph the topology, claim and outside sections.
- **G13** With a graph, `Written by` and `Read by` list for each topic name exactly the topologies and claims the graph records as writing and reading a topic of that name, in graph order, each with its scope, and `## Topics outside topics.yaml` lists exactly the graph's topics whose names the document does not declare.
- **G14** Without `--graph`, `topics.md` carries the no-graph summary, no `Written by` or `Read by` row and none of the three graph sections, `generate` writes no `topology-graph.html`, and `topics.g.dart` is the same bytes as with a graph.
- **G15** `topology-graph.html` is the page template with the graph's counts and its HTML-escaped Mermaid rendering, so the text of its `<pre class="mermaid">` element is `const MermaidRenderer().render(graph)` of the decoded graph exactly.
- **G16** Author text never reads as HTML: in doc comments and in `topics.md`, every `<` and `>` of an owner or a description outside a code span is backslash-escaped, and code spans are kept.
- **G17** The outputs depend on the bytes of the input files only: they hold no timestamp, path or environment value, and every run over the same inputs writes the same bytes.
- **G18** `generate` takes `[--graph <graph>] <topics> <output>`, creates `<output>` when absent, and writes `topics.g.dart`, `topics.md` and, given a graph, `topology-graph.html` into it.
- **G19** `generate` exits 1 for a rejected topics document or an undecodable graph and 2 for a usage error, writes nothing either way, and prints each diagnostic of a rejected document as `{path}:{line}:{column}: {message}`.
- **G20** `topology-graph.json` is `const JsonRenderer().render(TopologyGraph(topologies: definitions, claims: claims))` with the definitions `buildDefinition()` returns for every topology the packages register, recorded on the Dart VM without obfuscation, and the claims the workspace scan resolves; it therefore validates against topology-ir@v1's schema and decodes (topology-ir@v1 G19, G20).
- **G21** `catalog` takes `<package>... <output>`, exits 0 having written `topology-graph.json`, 1 when no graph can be formed and 2 for a usage error, writing nothing on 1 and 2, and reports each unresolvable claim as a warning while still exiting 0.

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates.
- Breaking for this contract: rejecting a document v1 accepts; changing the class or member name of a topic, a member's declared type, variant or arguments, or the library's import set for an accepted document; changing a path (`lib/topics.yaml`, `lib/topics.g.dart`, an output file name), the builder key, an executable name, an argument or an exit code's meaning; changing `topology-graph.json`'s content rule.
- Compatible: accepting more documents through a new optional key whose absence leaves every output unchanged; a new output file or option; a change to how `topics.md` or `topology-graph.html` presents the same information, the Mermaid version the page loads included, made with its fixtures in the same change, because both are documents for people; a new guarantee that existing fixtures still pass.
- Not in v1, each a candidate for a later version: a factory initial value generating `StateTopic.computed` (topic-model@v1); `routes.yaml` and `policies.yaml` (Guide C.3); other platforms' generators (root D1); import prefixes and `show` or `hide` clauses; a page that renders offline; one catalog over several schema files; a `--check` mode that compares instead of writing.

## Validation

- schema: `hsdd/contract/schema/topic-codegen.schema.json`, JSON Schema draft 2020-12, the topics document's data model; replayed by the `schema` set (ADR-001 item 5); covers G1.
- fixture: `hsdd/contract/fixture/topic-codegen/`, replayed with `fvm dart run nidana_contract_check topic-codegen`.
- valid: `hsdd/contract/fixture/topic-codegen/valid/`, four documents: `minimal.json`, `every-field.json` (every key in every position it may take, `initial` as a string, an integer, a float, a boolean and null), `spec-section-4-5.json` and `guide-c-3.json` (the examples of Spec §4.5 and Guide C.3, as written). The cases use JSON syntax, which YAML reads as the same document, so the generator's tests feed them unchanged and the replay tool needs no YAML parser.
- invalid: `hsdd/contract/fixture/topic-codegen/invalid/`, 53 documents, each `valid/every-field.json` with one schema rule broken, named after the rule.
- file: `hsdd/contract/fixture/topic-codegen/input/` holds `topics.yaml` (five domains, nineteen topics, every variant, key and kind of initial value, the nidana import listed by a domain, which the library imports once, a relative import, a description with an escaped `>`) and `topology-graph.json` (a copy of topology-ir@v1's `valid/checkout.json`: four topologies, two claims, two topics outside the document). `hsdd/contract/fixture/topic-codegen/expected/` holds `topics.g.dart`, `topics.md` and `topology-graph.html`. The replay (ADR-001 item 6) runs, from the workspace root into an empty directory, `fvm dart run nidana_dart_codegen:generate --graph {input}/topology-graph.json {input}/topics.yaml {output}`, formats the Dart in `{output}` with `fvm dart format`, and compares `{output}` with `expected/` byte for byte, the file set included. The file set covers G3 to G8, G12, G13 and G15 to G18.
- rejected: `hsdd/contract/fixture/topic-codegen/rejected/`, ten YAML documents the generator rejects under R1 to R4 though their data model, where they have one, validates: repeated domain, topic and field keys, two documents, a syntax error, a class collision, a member collision, a reserved word, an `Object` member name and `.inf`. No replay set reads them; they are the inputs of G2's rejections.
- `expected/topics.g.dart` is compared, never analyzed: its imports name the types of a stand-in app (`package:example_app/...`), so no fixture analyzes `expected/`.
- not executable: G2, ADR-001 item 6 replays one input tree and has no form for a generator's rejection; checked by nidana.tooling's gates, which run the generator over `valid/`, `invalid/` and `rejected/`
- not executable: G9, the replay formats before it compares; checked by nidana.tooling's gates
- not executable: G10, the replay compares bytes and compiles nothing; checked by nidana.tooling's gates over generated libraries with resolvable types, and exercised by nidana.integration, whose example app compiles its own generated registry
- not executable: G11, the replay runs the command, not build_runner; checked by nidana.tooling's gates, and exercised by nidana.integration's gate comparing its committed `lib/topics.g.dart` with `generate`'s output
- not executable: G14, the replay's one input tree carries a graph; checked by nidana.tooling's gates
- not executable: G19, ADR-001 item 6 has no form for a failing generator; checked by nidana.tooling's gates
- not executable: G20, the registration form `catalog` reads is nidana.tooling's decomposition's (OQ-T1) and the claim scan is nidana-checks@v1's; checked by nidana.tooling's gates, which decode and schema-check the document `catalog` writes over fixture topologies
- not executable: G21, as for G20; checked by nidana.tooling's gates
- Consumers' stand-ins: none. nidana.integration's edge to nidana.tooling is `hard` (root DAG): it runs the real builder and commands.
- The fixtures are forward references, written before the package exists. In `docs/auto-run/experiments/topic-codegen-fixtures/` (`run.sh`, `output.txt`) a stand-in `nidana_dart_codegen` (a pure generator, the `generate` command and the builder, on the pinned build 4.0.11, build_runner 2.16.1, dart_style 3.1.14 and yaml 3.1.4) over the stand-in `nidana_dart_contracts` of `docs/auto-run/experiments/flutter-binding-fixtures/` reproduced `expected/` from `input/` byte for byte, with and without `fvm dart format`, from absolute paths into another directory; the generated library compiled in a stand-in app and analyzed clean under the root lint set, strict modes and `--fatal-infos`; build_runner wrote the same bytes, applied to `lib/topics.yaml` and not to `lib/extra/topics.yaml`, and failed on a rejected document; the schema cases validated as marked under `package:json_schema` 5.2.2 and Ajv; the generator accepted every `valid/` document and rejected every `invalid/` and `rejected/` one with exit 1 and no output; without a graph it wrote the same registry and a catalog with no graph rows; the page's diagram text equalled topology-ir@v1's `render/checkout.mmd` and Mermaid 11.12.0 parsed it; usage errors exited 2 and an undecodable graph 1, writing nothing; a library that imports Flutter loaded under the Flutter tester and not under `dart run`. `probe/` there holds the runtime facts R1, R3 and the escape rule rest on (`probe/README.txt`). The first replay against the real package, once nidana.model's first phase lands the replay tool, is their first verification (ADR-001 Consequences).
