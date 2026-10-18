---
id: nidana-checks
version: v1
status: draft
kind: cli
owner: nidana.tooling
compatibility: versioned
produced_by: [nidana.tooling.lint.1, nidana.tooling.lint.2, nidana.tooling.lint.3, nidana.tooling.lint.4, nidana.tooling.codegen.7, nidana.tooling.codegen.8, nidana.tooling.codegen.9, nidana.tooling.codegen.11]
consumers: [nidana.integration]
external_consumers: [app CI running fvm dart analyze with nidana_dart_lint enabled, app CI running the workspace scan, IDEs showing nidana_dart_lint diagnostics through the analysis server]
phase_ids: provisional
---

# Contract: nidana-checks

- **Governed by:** [ADR-001, ADR-002]

The v1 static checks (root D1; Spec §3.1, §3.8, §3.11, §4.2 to §4.4, §7.2, §9.2; Guide §5.2, C.1, C.5), which move single-writer, uniqueness, cycle, scope, raw-string, global-accessor and sensitivity failures from first run to merge. They have two hosts (ADR-002 items 7 and 8): the analysis server plugin `nidana_dart_lint`, whose rules decide one library at a time and report under `dart analyze` and in the IDE, and the workspace scan, the command `scan` of `nidana_dart_codegen`, which runs every check over more than one library or over the IR. This contract fixes, for both hosts, what is reported, with which code, severity and message, in which output form, with which exit code.

## Boundary

| Concern | Contract |
|---------|----------|
| The plugin's rules, codes, default severities, messages and configuration; the scan's invocation, inputs, claim recognition, diagnostics, output lines and exit codes; which check runs in which host | nidana-checks@v1 |
| `topics.yaml`, the registry library, `generate`, `catalog` and the path and content rule of `topology-graph.json` | topic-codegen@v1 |
| `TopologyGraph`, `ShellClaim`, `TopicDeclaration`, the analyses `analyzeTopologyGraph` and `findTopicNameCollisions`, `decodeTopologyGraph` and the graph document's form | topology-ir@v1 |
| `Bus`, `Publisher` and `Bus.publisher` | bus-api@v1 |
| `TestBus` | bus-testing@v1 |
| `StateTopic`, `EventTopic`, `ReplayTopic`, `TopicRef`, `ServiceSource`, `PageSource`, `ExecutorSource`, `Scope` | topic-model@v1 |
| `TopologyBuilder.write` and `TopologyBuilder.reduceInto` | topology-dsl@v1 |
| `NavigationExecutor` and `NavigationTopics.currentRoute` | navigation-api@v1 |
| `PageScope` and `FlutterNavigationExecutor` | flutter-binding@v1 |
| How `catalog` obtains the topologies of a package | topic-codegen@v1 (nidana.tooling.codegen D1) |
| How nidana.tooling's children divide the two hosts | nidana.tooling D1 and D2 |

- **Refinement 1. Which check runs where.** A check that one library's resolved AST decides is a plugin rule: raw-string topic use (Spec §4.4), a global bus accessor (Spec §3.1, Guide C.5), the sensitive flag on known-sensitive types (Spec §9.2, Guide C.1), and explicit type arguments on a topic sink (Refinement 4). Every check over more than one library or over the IR is the scan's: topic name uniqueness across registries (Spec §4.3), single-writer (Spec §3.11 layer 2), inter-topology cycles and intra-topology self-reference (Spec §3.8), scope compatibility (Spec §7.2). The scan reports what topology-ir@v1's analyses find; it implements none of them (root D4).
- **Refinement 2. What the scan reads** (decides OQ-T2's residual). Spec §3.11 has the AST scan collect topology `write(...)` calls; on Dart the scan takes topology reads and writes from the IR instead, the `buildDefinition()` of every topology, which records `write` and `reduceInto` exactly and carries the state-bearing edges and scopes the cycle, self-reference and scope checks need. It reads them from a graph document, the `topology-graph.json` that topic-codegen@v1's `catalog` writes (Guide C.3's "CI lint manifest"), so the scan depends on no registration mechanism (topic-codegen@v1). Shell claims and topic declarations are not in the IR, so the scan resolves them from source itself, with the one recognizer that `catalog` also uses to put claims in the document (Spec §3.11: single-writer enforcement and graph generation share infrastructure). The scan reads only the document's topologies, never its claims, so no claim counts twice.
- **Refinement 3. Severities mean blocking or not.** Root D1 and Spec §3.11 call some reports warnings: they inform and do not fail the build. On the plugin, the blocking rules report at the analyzer's WARNING severity, which fails `dart analyze` by default, and the non-blocking one at INFO, which fails it only under `--fatal-infos`. On the scan, blocking reports are `error` lines, which set exit code 1, and non-blocking ones are `warning` lines, which do not.
- **Refinement 4. Explicit type arguments on a topic sink.** bus-api@v1 G40 leaves one gap in Spec §4.2's compile-time type check: explicit type arguments widen a topic's type through Dart's covariant generics, so `bus.publish<num, double>(intEvents, 1.5)` compiles and fails at run time. topology-dsl@v1's `write` and `reduceInto` have the same gap. The rule `explicit_topic_type_arguments` closes it statically, so Spec §4.2 holds for every call the plugin passes. Root D1 lists it since 2026-10-18; it enforces a rule the Specification states (Spec §4.2), as root's first success criterion asks of every such rule.

Not here: the v2 checks root D1 defers (sequencer, unreachable topics, orphan reads, transformer purity, the sensitive flag as an error by default, the Initializing-variant lint, the stream-factory-plus-publish lint of Spec §6.3), binary-module manifests (root D1), and duplicate topology ids across modules, which `catalog` rejects (topic-codegen@v1 G21) and the graph document's decoder rejects (topology-ir@v1 G21), so a graph the scan reads never holds two.

## Interface

**Packages:** the plugin is `nidana_dart_lint` at `packages/nidana_dart_lint/`, entry point `lib/main.dart` with the top-level `plugin` (ADR-002 items 3 and 7); it depends on `analysis_server_plugin` 0.3.18 and `analyzer` 13.3.0, pinned, and on no nidana package, so an app outside this repository enables it by path without resolving any other nidana package (ADR-002 Consequences). The scan is the executable `scan` of `nidana_dart_codegen` at `packages/nidana_dart_codegen/`, run as `fvm dart run nidana_dart_codegen:scan` (ADR-002 item 8); it calls `nidana_dart_contracts`' analyses. Neither package's Dart libraries are part of this contract. **Code owner:** nidana.tooling, through its children: nidana.tooling.lint for the plugin, nidana.tooling.codegen for the scan (nidana.tooling D1 and D2; Delivery, below). **Validation artifacts:** `hsdd/contract/fixture/nidana-checks/`, owned by hsdd-contract (ADR-001 item 8).

**Delivery**, by the phases `produced_by` names, host by host (nidana.tooling D2). The plugin: nidana.tooling.lint.1 creates `nidana_dart_lint`, enables it in the root analysis options and registers the four rules with their codes, default severities and messages, reporting nothing yet, so G1's registration holds from it; nidana.tooling.lint.2 and nidana.tooling.lint.3, side by side, land the rules' decisions and report nothing; nidana.tooling.lint.4 makes the rules report and delivers G2, G3 for the plugin and G4 to G8, which with G1 make the plugin's whole share. Every `analyze-*` case covers an id among G2 to G8, so none replays before nidana.tooling.lint.4, whose gate replays `--guarantee G1,G2,G3,G4,G5,G6,G7,G8`, every `analyze-*` case; the gates of nidana.tooling.lint.1 to nidana.tooling.lint.3 replay `--guarantee G1`, which admits no case. A `hard` edge on the plugin waits on nidana.tooling.lint.4 (nidana.integration). From nidana.tooling.lint.1 on, every root `fvm dart analyze` loads the plugin, and from nidana.tooling.lint.4 on its rules report over every member (The plugin). The scan: nidana.tooling.codegen.7 and nidana.tooling.codegen.8 land the recognizer (application code, recognition, topic declarations, the claim sites with their resolution rules), whose guarantees replay from nidana.tooling.codegen.9 on, once the scan command exists; their gates run `--set structure`, since no scan guarantee is observable before it. nidana.tooling.codegen.9 delivers G3 for the scan and G9 to G17: its gate replays `--guarantee G3,G9,G10,G11,G12,G13,G14,G15,G16,G17`, every `scan-*` case. nidana.tooling.codegen.11 delivers G18 with `catalog` (topic-codegen@v1), checked by its gate, which compares `catalog`'s claims and warnings with the scan's over the scan cases' packages, and replays the scan's whole share, `--guarantee G3,G9,G10,G11,G12,G13,G14,G15,G16,G17,G18`. Every `scan-*` case covers ids within that share and every `analyze-*` case ids within the plugin's, so each producer's last gate runs its own cases and nidana.integration's `--all` runs both (ADR-001 item 10). A `hard` edge on the scan waits on nidana.tooling.codegen.11 (nidana.integration).

### Terms both hosts use

- **Application code** is every Dart library of a package outside the package's test directories, `test/`, `integration_test/`, `test_driver/` and `testing/` under its root: the directories the analyzer's `RuleContext.isInTestDirectory` names. Test code claims topics and declares ad hoc topics on purpose (bus-testing@v1, flutter-binding@v1 G17); neither host reads it.
- **Recognition.** An element is nidana's `X` of package `P` when its name is `X` and it is declared in a library whose URI is `package:P/...`, `lib/src/` included (bus-api@v1 For static analysis). Neither host matches a library path or an import, and a declaration of the same name in another package is not recognized. `Bus` matches the class and every subclass, `TestBus` included.
- **A topic creation** is an instance creation of `StateTopic` (either constructor), `EventTopic` or `ReplayTopic` of package `nidana_dart_contracts`. Its **value type** is the created type's type argument, written or inferred.
- **A string literal** is a simple, adjacent or interpolated string literal.
- **A site** is a place in source, rendered `{path}:{line}:{column}`, 1-based, where `{path}` is the file's path relative to the working directory with `/` separators, or its absolute path when the file is not below the working directory.

### The plugin

Enabled in the `plugins:` section of the analysis options at a workspace or package root (ADR-002 item 7). Every rule is a warning rule, enabled whenever the plugin is, and has one diagnostic code, the rule's name.

| Code | Default severity | Reports | Problem message | Correction message |
|------|------------------|---------|-----------------|--------------------|
| `raw_string_topic` | WARNING | a topic creation whose `name` argument is a string literal and which is not the whole initializer of a static field; at the literal | `Topic name {0} is a string literal outside a registry.` | `Declare the topic once as a static field of a registry class, and refer to that field.` |
| `global_bus_accessor` | WARNING | a top-level variable, a static field, a top-level getter or a static getter whose type is `Bus` of `nidana_dart_runtime` or a subclass, nullable or not; at its name | `'{0}' makes a bus reachable without an explicit reference.` | `Pass the Bus explicitly: as a constructor or function argument, or through BusProvider.of(context).` |
| `explicit_topic_type_arguments` | WARNING | an invocation with explicit type arguments of `publish` on `Bus` or `Publisher` of `nidana_dart_runtime`, or of `write` or `reduceInto` on `TopologyBuilder` of `nidana_dart_contracts`; at the type argument list | `Explicit type arguments on '{0}' can widen the topic's value type.` | `Remove the type arguments, so that the topic's type decides the value's type.` |
| `unflagged_sensitive_topic` | INFO | a topic creation whose value type contains a known-sensitive type and whose `sensitive` argument is absent or the literal `false`; at the constructor name with its type arguments | `The topic type '{0}' contains the known-sensitive type '{1}', but the topic is not flagged sensitive.` | `Add 'sensitive: true' to the topic's declaration, or to its entry in topics.yaml.` |

Placeholders: for `raw_string_topic`, `{0}` is the literal as written, quotes included (`'cart.items'`, `'cart.$user'`); for `global_bus_accessor`, the variable's or getter's name; for `explicit_topic_type_arguments`, the method's name; for `unflagged_sensitive_topic`, `{0}` is the value type as the analyzer displays it (`DartType.getDisplayString()`, under which an alias shows as the type it names) and `{1}` the name of the known-sensitive type found. When the value type contains more than one, `{1}` names the first a depth-first search meets: the alias a type is written through, the type itself, then its type arguments in order, or a record's positional fields in order and then its named fields by name.

**Rule details.**

- `raw_string_topic` (Spec §4.2, §4.4: application code never names a topic by string). A registry declares each topic once as the whole initializer of a static field, as hand-written registries, `NavigationTopics` and topic-codegen@v1's generated registries do. A static field is, as in G4, any field declared `static`, in a class, mixin, enum, extension or extension type, whether `const`, `final`, `late` or none of these. Every other creation with a literal name is reported: an argument, a local variable, a top-level variable, a static field whose initializer only contains the creation. A name that is not a string literal is not reported, because it names no topic at the creation site. `TopicRef` constructions, object patterns and comparisons with `topic.name` are not topic creations and are not reported.
- `global_bus_accessor` (Spec §3.1; Guide C.5). A bus held by an instance field, a local variable or a parameter is not reported, nor is a function that returns a new bus. This is bus-api@v1 For static analysis's definition of a global bus accessor, getters included.
- `explicit_topic_type_arguments` (Refinement 4). Inferred calls are never reported; nor are explicit type arguments on reads (`observe`, `getCurrentValue`, `getBufferedValues`, `read`), which widen nothing a topic receives.
- `unflagged_sensitive_topic` (Spec §9.2; Guide C.1, v1 as a warning). A type is **known-sensitive** when its name, or the name of the type alias it is written through, ends in `Token`, `Credential`, `Credentials` or `PaymentInfo`, or when its declaration, or that alias, carries an annotation whose value is an instance of a class named `Sensitive`, from any library. The value type **contains** a known-sensitive type when it is one, or when one of its type arguments or record fields contains one, at any depth; nullability is ignored and function types are not searched. Spec §9.2's "configurable list" is the annotation: an app marks its own types, and marks a type it cannot annotate through an annotated alias (`@Sensitive() typedef AccountHolder = ThirdPartyUser;`). A `sensitive` argument that is not a literal is not reported. Topics a generated registry declares are reported in `topics.g.dart`; the fix is in `topics.yaml` (topic-codegen@v1).

**Configuration and suppression** are the analysis server's (`docs/auto-run/experiments/nidana-checks-fixtures/`, case `analyze-configuration`):

```yaml
plugins:
  nidana_dart_lint:
    path: packages/nidana_dart_lint      # or a version, once published
    diagnostics:
      unflagged_sensitive_topic: error   # Guide C.1's configurable error
      global_bus_accessor: info          # error, warning, info; false disables
```

A diagnostic is suppressed on one line by `// ignore: nidana_dart_lint/{code}` on the line before it, and in one file by `// ignore_for_file: nidana_dart_lint/{code}`.

**Running it.** `fvm dart analyze` reports the plugin's diagnostics beside the analyzer's own, with the analyzer's exit codes: 3 when any diagnostic is an ERROR, else 2 when any is a WARNING, else 1 under `--fatal-infos` when any is an INFO, else 0. The plugin reports when `dart analyze` runs on the root whose options enable it, or on files below it; run on a directory below that root, such as `lib`, it reports nothing, without any error (`docs/auto-run/experiments/nidana-checks-fixtures/`, probe P2). App CI therefore runs `dart analyze` at the package or workspace root. The analysis server resolves the plugin into a synthetic package under `~/.dartServer/.plugin_manager/` on first use, which needs the plugin's dependencies from the pub cache or pub.dev; a plugin that does not load fails `dart analyze` with exit 3 or 4 (ADR-002 Context).

Over this repository's own members the rules report nothing that the members' contracts declare: registries are static fields, buses are held by instances and parameters, and nidana's own sinks are called without explicit type arguments. Because the workspace root enables the plugin (ADR-002 item 7), every gate that analyzes the workspace with `--fatal-infos` also checks that.

### The workspace scan

```text
fvm dart run nidana_dart_codegen:scan [--graph <graph>] <package>...
```

- Each `<package>` is the root directory of a package, a directory holding `pubspec.yaml`, resolved through the package configuration the analyzer finds for it. The scan reads the application code of each package: the Dart files the analyzer analyzes under that root, as its analysis options' `exclude` decides, outside its test directories. A file reached through two arguments is read once.
- `--graph <graph>` names a graph document of topology-ir@v1's form, normally what `catalog` wrote over the same packages. The scan takes the document's topologies and ignores its claims (Refinement 2). Without `--graph` the analysis graph has no topologies, so only claims are checked against claims, and the cycle, self-reference and topology-owner scope checks have nothing to report.
- The scan resolves libraries statically and runs none of them, so a library that imports Flutter is read like any other.
- The scan reads resolved syntax as the analyzer gives it. An element that does not resolve, such as a name from an import of a package the configuration lacks, or a misspelt name, is declared in no library, so it is not nidana's (Recognition), and a construct written against it is neither a topic creation nor a claim site. The scan reports no compile error: `dart analyze` reports them, and In CI runs it before the scan.
- The scan writes no file. It prints its report on stdout; a usage error or an unreadable input is described on stderr.

**Topic declarations.** Each top-level variable or static field, in application code, whose initializer is a topic creation is a declaration, at the site of the variable's name. With a string-literal name without interpolation, it becomes `TopicDeclaration(topic: TopicRef(name: {the literal's value}, variant: {its variant}, typeName: {its value type}), site: {its site})`. Its `typeName` is the value type rendered as the Dart VM renders `'$T'` (topic-model@v1 `TopicRef`): the analyzer's display string, except for a function type, which the VM renders as `({parameters}) => {return}` (`docs/auto-run/experiments/nidana-checks-fixtures/`, probe P1). Any other name is reported `unresolved_topic_name` and left out; the bus's own check covers it (bus-api@v1 G7). Generated registries are declarations like hand-written ones.

**Claim sites.** Four constructs in application code claim state topics:

| Claim site | Source | Scope | Write set |
|------------|--------|-------|-----------|
| an invocation of `publisher` on `Bus` of `nidana_dart_runtime` (bus-api@v1) | the first positional argument | the `scope` argument; `application` when absent | the `writes` argument |
| a creation of `PageScope` of `nidana_dart_runtime_flutter` (flutter-binding@v1 G7) | `PageSource({route})` from the `route` argument | `page` | the `writes` argument |
| a creation of `NavigationExecutor` of `nidana_dart_navigation` (navigation-api@v1 G19) | `ExecutorSource({name})` from the `name` argument, `navigation` when absent | `application` | `nav.current-route`, a state topic of `RouteState` |
| a creation of `FlutterNavigationExecutor` of `nidana_dart_runtime_flutter` (flutter-binding@v1 G14) | as for `NavigationExecutor`, `flutter-navigation` when absent | `application` | as for `NavigationExecutor` |

A claim site whose write set is absent or an empty set literal claims nothing and is not reported. A site is at the method name of a `publisher` invocation and at the constructor name of a creation.

- **The write set resolves** when it is a set literal, `const` or not, whose every element is an identifier, a prefixed identifier or a property access (with or without an import prefix) naming a top-level variable or a static field whose initializer is a `StateTopic` creation with a string-literal name without interpolation, in any library the package resolves. Each element becomes `TopicRef(name: {that name}, variant: state, typeName: {its value type, rendered as for declarations})`. Anything else does not resolve: a variable or call holding a set, a spread, a collection `if` or `for`, an element that is a local variable, a call or a field whose initializer is not such a creation.
- **The scope resolves** when it is absent or a reference to a value of `Scope` of `nidana_dart_contracts`.
- **The source resolves** when it is a creation of `ServiceSource`, `PageSource` or `ExecutorSource` of `nidana_dart_contracts` whose one argument is a non-empty string literal without interpolation, or a reference to a `const` or `final` top-level variable or static field whose initializer is one; for `PageScope` and the executors, when the `route` or `name` argument is such a literal or the executor's default applies. A source that does not resolve stands in as the site: the source variant the site fixes (`page` for `PageScope`, `executor` for the executors, for `publisher` the variant of a source creation whose argument is not a literal, else `service`), named by the site itself, such as `page:app/lib/cart_page.dart:42:10`. A claim's source only labels its writer, so a stand-in keeps the claim in every check.
- A claim site whose write set and scope resolve is one `ShellClaim(source: {source}, scope: {scope}, writes: {write set})`. Otherwise it is reported `unresolved_claim` and left out of the graph: the runtime's first-claim check covers it (Spec §3.11: "reported as a warning and left to Layer 1"; bus-api@v1 G20).
- topic-codegen@v1's `catalog` uses this recognizer: the claims its document holds are exactly the claims the scan resolves in the same packages, stand-in sources included, and the claim sites it leaves out are the ones the scan reports `unresolved_claim`.

**The analysis graph** is `TopologyGraph(topologies: {the document's topologies, or none}, claims: {every resolved claim})`. The scan reports one error line per finding of `analyzeTopologyGraph` over it, in that function's order (topology-ir@v1 G17), and one per `TopicNameCollision` of `findTopicNameCollisions` over the declarations, ordered by name (topology-ir@v1 G18). A claim and a topology that write one topic meet only when their `TopicRef`s are equal, which is why claims and declarations render `typeName` as the VM does.

**Output.** One line per report, `{severity}|{code}|{location}|{message}`, where each field writes `\` as `\\`, `|` as `\|` and a line break as `\n`. Error lines come first, the topic name collisions by name, then the graph's findings in `analyzeTopologyGraph`'s order; then warning lines, ordered by site path, then line, then column. A scan that finds nothing prints nothing.

| Code | Severity | Location | Message |
|------|----------|----------|---------|
| `topic_name_collision` | `error` | the first declaration's site | `Topic name '{name}' is declared {n} times: {declarations}.` |
| `topology_cycle` | `error` | empty | `Topologies {ids} form a cycle through {topics}.` |
| `self_reference` | `error` | empty | `Topology '{id}' reads '{topic}', which it writes, through no state-bearing edge (edges {indices}).` |
| `writer_conflict` | `error` | empty | `State topic '{topic}' has {n} writers: {writers}.` |
| `scope_violation` | `error` | empty | `State topic '{topic}' is owned by {owner} with scope {owner scope} and read by topology:{reader} with scope {reader scope}; an owner's scope must be at least as long as its readers'.` |
| `unresolved_claim` | `warning` | the claim site | `This claim's write set is not statically resolvable; the runtime check covers it.`, or, when the write set resolves and the scope does not, `This claim's scope is not statically resolvable; the runtime check covers it.` |
| `unresolved_topic_name` | `warning` | the declaration's site | `This topic's name is not a string literal; the runtime check covers it.` |

In the messages: `{declarations}` lists each declaration of the collision in its order as `{site} ({Class}<{typeName}>)`, `{Class}` being `StateTopic`, `EventTopic` or `ReplayTopic`; `{ids}` are the cycle's topology ids in order; `{topics}` the names of its topics, each once, in order; `{indices}` the self-reference's edge indices, and `(edges {indices})` reads `(edge {index})` for one edge; scopes are written by enum name; topics by name; `{n} writers` reads `1 writer` for one. A writer or owner that is a topology renders `topology:{id}`; one that is a claim renders `{source} at {site}`, or `{source}` alone when the source stands in as that site; claims with equal sources are matched to their sites in site order. Every list is joined by `, `.

**Exit codes.**

| Code | When | stdout |
|------|------|--------|
| 0 | no error line, warning lines or none | the report |
| 1 | at least one error line | the report |
| 2 | usage: no `<package>`, an unknown option, `--graph` without a value or given twice, a `<package>` that holds no `pubspec.yaml`; or the graph cannot be read, is not JSON, or does not decode (`decodeTopologyGraph` throws `FormatException`, topology-ir@v1 G21) | nothing |

On exit 2, stderr names the problem and, for a usage error, prints the usage line; its text is not part of this contract.

### In CI

An app's CI step runs, from its root, in this order: `fvm dart run build_runner build` where it generates registries (topic-codegen@v1), `fvm dart analyze --fatal-infos` (or without `--fatal-infos`, to keep the sensitivity rule informative), which also reports the compile errors the scan does not, `fvm dart run nidana_dart_codegen:catalog <package>... build/`, then `fvm dart run nidana_dart_codegen:scan --graph build/topology-graph.json <package>...`, the same packages for both. nidana.integration's gate runs the same steps over `packages/nidana_integration`, and replays this contract's recorded invocations, whose seeded violations are the failing half of root's success criterion.

## Guarantees / invariants

- **G1** `nidana_dart_lint` registers exactly the four rules of the table, each a warning rule with the one diagnostic code of its name and the default severity the table gives, so that, with no other diagnostic, `fvm dart analyze` exits 2 when it reports `raw_string_topic`, `global_bus_accessor` or `explicit_topic_type_arguments`, and, when it reports only `unflagged_sensitive_topic`, exits 0, or 1 under `--fatal-infos`.
- **G2** Each plugin diagnostic carries the table's problem message and correction message with its placeholders filled as stated, and is reported at the node the table names.
- **G3** Both hosts read application code only, and recognize nidana API by package and element name only: a library in a test directory is never reported on nor read, and a same-named declaration of another package is never taken for nidana's.
- **G4** `raw_string_topic` reports exactly the topic creations whose `name` is a string literal and that are not the whole initializer of a static field.
- **G5** `global_bus_accessor` reports exactly the top-level variables, static fields, top-level getters and static getters whose type is `Bus` or a subclass, nullable or not.
- **G6** `explicit_topic_type_arguments` reports exactly the invocations, with explicit type arguments, of `publish` on `Bus` or `Publisher` and of `write` or `reduceInto` on `TopologyBuilder`.
- **G7** `unflagged_sensitive_topic` reports exactly the topic creations whose value type contains a known-sensitive type, by name suffix or by a `Sensitive` annotation on the type or its alias, at any depth of type arguments and record fields, and whose `sensitive` argument is absent or the literal `false`.
- **G8** The plugin's `diagnostics` section sets each code's severity (`error`, `warning`, `info`) or disables it (`false`), and `// ignore: nidana_dart_lint/{code}` and `// ignore_for_file: nidana_dart_lint/{code}` suppress it.
- **G9** `scan [--graph <graph>] <package>...` reads the application code of each package and, with `--graph`, the topologies of the graph document and never its claims; it writes no file.
- **G10** Each top-level variable or static field whose initializer is a topic creation is a declaration at its name's site: with a string-literal name, a `TopicDeclaration` whose `TopicRef` carries that name, the creation's variant and the value type as the VM renders it; otherwise an `unresolved_topic_name` warning. Generated registries are read like hand-written ones.
- **G11** The four claim sites of the table, and no other construct, claim; a claim site with a resolvable write set and scope is one `ShellClaim` with the source, scope and write set the resolution rules give, a source that does not resolve standing in as the site.
- **G12** A claim site whose write set or scope does not resolve is reported `unresolved_claim`, with the message for what did not resolve, and takes no part in any check; a claim site with no write set or an empty set literal is neither a claim nor reported.
- **G13** The scan reports one `topic_name_collision` error per name that two or more declarations share, whatever their variants and types, listing every declaration (Spec §4.3; topology-ir@v1 G18).
- **G14** The scan reports one error per finding of `analyzeTopologyGraph` over `TopologyGraph(topologies: {the document's}, claims: {the resolved claims})`, with the codes `topology_cycle`, `self_reference`, `writer_conflict` and `scope_violation` (Spec §3.8, §3.11, §7.2; topology-ir@v1 G13 to G17).
- **G15** The report is one line per error, then per warning, in the order and the line form the Output section states, each message as its table states; a scan that finds nothing prints nothing.
- **G16** The scan exits 0 with no error line, 1 with one or more, and 2 for a usage error or an unreadable or undecodable graph, printing nothing on stdout then.
- **G17** The report depends on the contents of the files read and on the arguments as given, never on the time or the environment; every site path is relative to the working directory when the file is below it.
- **G18** `catalog` (topic-codegen@v1) resolves claims with the scan's recognizer: over the same packages, its document's claims are the claims the scan resolves, and the claim sites it leaves out are those the scan reports `unresolved_claim`.

## Versioning

- v1 current, `compatibility: versioned`. A breaking change creates v2 with a migration note here; v1 stays until every consumer migrates.
- Breaking for this contract: removing or renaming a rule, a code, the executable, an option or an argument; reporting more than v1 reports, by a new default-enabled rule or scan check, a wider rule, a new claim site, or a write set or name that newly resolves, because code that passes v1 can then fail; raising a default severity; changing a scan severity, an exit code's meaning, the line form, the order of lines or the rendering of a site, a writer or a location.
- Compatible: reporting less, by narrowing a rule to a case it reported in error, in the same change as its recordings; a new rule registered as a lint rule, disabled until an app enables it; a new scan option whose absence leaves every output unchanged; a change of message wording, made with every recording in the same change, because messages are for people and tools match on codes; a new guarantee that existing recordings still pass.
- The plugin cases record `dart analyze`'s own output forms, machine and default, which belong to the Dart SDK. A change of the `.fvmrc` pin that changes those forms, and nothing nidana reports, is re-recorded through hsdd-contract within v1.
- Amended within v1, from nidana.tooling.lint's phase plan, drained by hsdd-reconcile on 2026-10-18: (a) the `global_bus_accessor` rule detail cites bus-api@v1 For static analysis, which since that contract's amendment (f) defines a global bus accessor exactly as G5 reports it, where the detail had extended the earlier definition to getters; (b) Refinement 4 says root D1 lists `explicit_topic_type_arguments`, as it does since 2026-10-18; (c) the `raw_string_topic` rule detail reads as G4: the whole initializer of any field declared `static`, of any declaration kind, `const`, `final`, `late` or none of these, where the detail had named only `static const` and `static final` fields of a class; (d) the Placeholders paragraph fixes `unflagged_sensitive_topic`'s `{1}` for a value type that contains more than one known-sensitive type: the first a depth-first search meets, alias first; (e) the Interface's code-owner sentence names nidana.tooling's children, and the Delivery paragraph states which phase of nidana.tooling.lint delivers which guarantee. Compatible: (a), (b) and (e) change no rule, code, message or case; (c) reports no more than G4 states, and the detail's narrower wording would have reported static fields that G4 accepts, so the change narrows a rule to cases it would have reported in error; (d) gives a placeholder one value where the earlier wording had none for such a type, a message change made with its recordings. `analyze-raw-string-topic` now records accepted static fields of every declaration kind, its stdout unchanged, and `analyze-sensitive-fatal-infos` four value types that contain two known-sensitive types; every case passes against the stand-in plugin before and after the change, and stand-ins seeded with the narrower readings of (c) or with other search orders for (d) fail the amended cases while passing the committed ones (`docs/auto-run/experiments/lint-reconcile-amends/`).
- Amended within v1, from nidana.tooling.codegen's phase plan, drained by hsdd-reconcile on 2026-10-18: (f) the Boundary row that left how `catalog` obtains topologies (OQ-T1, now resolved) and the division of the hosts to nidana.tooling's decomposition becomes two rows, pointing at topic-codegen@v1 (nidana.tooling.codegen D1) and at nidana.tooling D1 and D2, and Refinement 2 cites topic-codegen@v1 where it cited OQ-T1; (g) The workspace scan states what the scan does with code that does not resolve: an element that does not resolve is declared in no library, so it is not nidana's, and a construct written against it is neither a topic creation nor a claim site; the scan reports no compile error, and In CI's `dart analyze`, which runs first, reports them; (h) the Delivery paragraph states which phase of nidana.tooling.codegen delivers which of the scan's guarantees, and the scan's not-executable lines name its gates. Compatible: (f) and (h) change no rule, code, message or case; (g) follows from Recognition, reports no more than v1 reports, and leaves the report of code that compiles unchanged. `scan-unresolved-claim` gains `lib/unresolved.dart` (a prefixed topic creation and a `Bus` from a package the configuration lacks, and a misspelt `Buss`), its stdout unchanged, and covers G3 as well; every case passes against the stand-in scan before and after the change, and a stand-in seeded to take a `publisher` invocation that does not resolve for `Bus.publisher` fails the amended case while passing every committed one (`docs/auto-run/experiments/codegen-reconcile-amends/`, B1 to B3).
- Not in v1, each a candidate for a later version: a JSON report or `--format` option for the scan; a `--fatal-warnings` option; the plugin surfacing the scan's verdicts in the IDE (OQ-T2's third option); a configurable keyword list for the sensitivity rule, should analysis_server_plugin gain plugin options; a `Sensitive` annotation declared by nidana (topic-model@v1) rather than by each app; raw-string comparisons with `topic.name` and object patterns over `TopicRef`; accessors that hold a bus inside a collection; the v2 checks of root D1 and Guide C.5's v2 lints.

## Validation

- fixture: `hsdd/contract/fixture/nidana-checks/`, replayed with `fvm dart run nidana_contract_check nidana-checks` (set `cli`, ADR-001 items 7 and 9). No schema: the graph documents the scan reads are topology-ir@v1's, validated by its schema (`hsdd/contract/schema/topology-ir.schema.json`), and the report is a line format.
- invocations: one directory per case under `hsdd/contract/fixture/nidana-checks/invocation/`, seventeen cases, each `args`, `exit_code` and `stdout`, all but one with `files/`. A case without `files/` runs from the workspace root. stderr is not recorded: its text is not part of this contract.
- The plugin cases' `files/` is a package root: `pubspec.yaml`, never resolved by pub (imports resolve through the workspace's package configuration), so that `test/` is a test directory, and `analysis_options.yaml` enabling the plugin as `path: ../../../../../../../packages/nidana_dart_lint`, seven levels up from `files/` to the workspace root (ADR-001 item 7). They run `dart analyze` on `.`, because a directory below the enabling root reports no plugin diagnostic (probe P2). `--format=machine` prints absolute paths, which the replay writes `{files}`.
- The scan cases' `files/` holds one or two packages (`app/`, `shared/`), each with its own `pubspec.yaml` and `analysis_options.yaml`, and, where the case reads one, `topology-graph.json`. `files/` itself holds no `pubspec.yaml`, so that `dart run` from it finds the workspace's package configuration and resolves nothing in place.

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `analyze-clean` | `dart analyze --fatal-infos --format=machine .` | 0 | G1, G3 to G7: every accepted form, a `test/` with a violation of every rule, a local `Bus` and `EventTopic` |
| `analyze-raw-string-topic` | `dart analyze --format=machine .` | 2 | G1, G2, G4: accepted static fields of every declaration kind, `const`, `final`, `late` or none of these |
| `analyze-global-bus-accessor` | `dart analyze --format=machine .` | 2 | G1, G2, G5 |
| `analyze-explicit-topic-type-arguments` | `dart analyze --format=machine .` | 2 | G1, G2, G6 |
| `analyze-unflagged-sensitive-topic` | `dart analyze --format=machine .` | 0 | G1, G2, G7 |
| `analyze-sensitive-fatal-infos` | `dart analyze --fatal-infos --format=machine .` | 1 | G1, G2, G7: four value types that contain two known-sensitive types, for `{1}`'s search order |
| `analyze-configuration` | `dart analyze --format=machine .` | 3 | G8 |
| `analyze-human` | `dart analyze .` | 2 | G1, G2: every code and correction message |
| `scan-clean` | `nidana_dart_codegen:scan --graph topology-graph.json app` | 0 | G3, G9, G11, G14 to G16: a claim of each kind but `FlutterNavigationExecutor`, a graph whose claims would count twice if read, a `test/` with a conflicting claim and a colliding declaration |
| `scan-topic-name-collision` | `nidana_dart_codegen:scan app shared` | 1 | G3, G9, G10, G13, G15 to G17 |
| `scan-writer-conflict` | `nidana_dart_codegen:scan --graph topology-graph.json app` | 1 | G10, G11, G14, G15: topology against claim, claim against claim, three writers of `nav.current-route`, two stand-in sources |
| `scan-scope-violation` | `nidana_dart_codegen:scan --graph topology-graph.json app` | 1 | G11, G14, G15: a page claim, a module-bound publisher and a page topology as owners |
| `scan-cycles` | `nidana_dart_codegen:scan --graph topology-graph.json app` | 1 | G14, G15: a cycle, a self-reference, a self-read through `scan` not reported |
| `scan-unresolved-claim` | `nidana_dart_codegen:scan app` | 0 | G3, G12, G15, G16: `lib/unresolved.dart`, code that does not resolve, reported by none |
| `scan-usage-no-package` | `nidana_dart_codegen:scan` | 2 | G16 |
| `scan-not-a-package` | `nidana_dart_codegen:scan app` | 2 | G16 |
| `scan-graph-undecodable` | `nidana_dart_codegen:scan --graph topology-graph.json app` | 2 | G16 |

- The graph documents are `JsonRenderer` output of `buildDefinition()` over stand-in topologies (`tool/graphs.dart` in the experiment); every one but `scan-graph-undecodable`'s validates against topology-ir@v1's schema and decodes.
- not executable: G9's "writes no file", ADR-001 item 7 compares streams and exit codes only; checked by nidana.tooling.codegen's gates
- not executable: G17's independence from the time and the environment beyond what one machine's replays show; checked by nidana.tooling.codegen's gates, which run the scan twice over one tree and compare
- not executable: G18, `catalog` is topic-codegen@v1's and its claims are not replayable there (topic-codegen@v1 G20); checked by nidana.tooling.codegen's gates, which run `catalog` over the scan cases' packages and compare its document's claims with the scan's, and exercised by nidana.integration
- Consumers' stand-ins: none. nidana.integration's edge to nidana.tooling is `hard` (root DAG): it runs the real plugin and the real scan.
- The fixtures are forward references, written before either package exists. In `docs/auto-run/experiments/nidana-checks-fixtures/` (`run.sh`, `output.txt`) a stand-in `nidana_dart_lint` on the pinned analyzer 13.3.0 and analysis_server_plugin 0.3.18 and a stand-in `nidana_dart_codegen` scan, over the stand-in nidana packages of `docs/auto-run/experiments/flutter-binding-fixtures/`, replayed every case as ADR-001 item 7 lays it out (T1); the stand-in members analyzed clean under the root lint set, the strict modes and the plugin with `--fatal-infos` (T0); the graph documents validated and decoded (T2); a machine-format run holds the absolute `files/` path that the recording writes `{files}` (T3); the whole workspace moved to another absolute path replayed unchanged (T4); and five seeded defects in the stand-ins (rules reporting in `test/`, the sensitivity rule at WARNING, the scan reading the document's claims, the scan reading `test/`, `PageScope` unrecognized) each failed the cases of the guarantee they break (T5). The first replay against the real packages, once nidana.model's first phase lands the replay tool, is their first verification (ADR-001 Consequences).
- The two cases changed within v1 by (c) and (d) (Versioning) were replayed again, with every other case, against the same stand-in plugin in `docs/auto-run/experiments/lint-reconcile-amends/` (`run.sh`, `output.txt`), and `scan-unresolved-claim` as changed by (g), with every other case, against the same stand-in scan in `docs/auto-run/experiments/codegen-reconcile-amends/` (`run.sh`, `output.txt`).
