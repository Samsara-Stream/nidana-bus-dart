"""Seed one defect into a copy of the shipped nidana_dart_contracts (S154).

usage: python3 -I defects.py <package root> <defect id>
       python3 -I defects.py --list
Each defect is a file under lib/src/ and a list of exact replacements, each
of which must apply exactly once, or, for A15, a function replaced whole.
The ids follow the experiments the routed items cite: I5 and I11 are
ir-values-plan's D5 and D11, A1 to A14 analyses-plan's D1 to D14 written
against the shipped analyses, R4 to R13 renderers-plan's D4 to D13; the
other ids are S154's.
"""
import pathlib
import sys

COMBINE = (
    "  CombinatorKind.combine => (\n"
    "    minInputs: 1,\n"
    "    maxInputs: null,\n"
    "    transformer: true,\n"
    "    duration: false,\n"
    "    retry: {},\n"
)
WITH_LATEST = (
    "  CombinatorKind.withLatestFrom => (\n"
    "    minInputs: 2,\n"
    "    maxInputs: 4,\n"
    "    transformer: true,\n"
    "    duration: false,\n"
    "    retry: {},\n"
)
MERGE = (
    "  CombinatorKind.merge => (\n"
    "    minInputs: 1,\n"
    "    maxInputs: null,\n"
    "    transformer: false,\n"
    "    duration: false,\n"
    "    retry: {},\n"
)
PLAIN = (
    "  CombinatorKind.pairwise || CombinatorKind.distinctUntilChanged => (\n"
    "    minInputs: 1,\n"
    "    maxInputs: 1,\n"
    "    transformer: false,\n"
    "    duration: false,\n"
    "    retry: {},\n"
)
TIMED = (
    "  CombinatorKind.timeout => (\n"
    "    minInputs: 1,\n"
    "    maxInputs: 1,\n"
    "    transformer: false,\n"
    "    duration: true,\n"
    "    retry: {},\n"
)
FUNCTION_GROUP = (
    "  CombinatorKind.map ||\n"
    "  CombinatorKind.filter ||\n"
    "  CombinatorKind.scan ||\n"
    "  CombinatorKind.catchError ||\n"
    "  CombinatorKind.rawEngine => (\n"
    "    minInputs: 1,\n"
    "    maxInputs: 1,\n"
    "    transformer: true,\n"
    "    duration: false,\n"
    "    retry: false,\n"
    "  ),\n"
)
MAP_ALONE = (
    "  CombinatorKind.map => (\n"
    "    minInputs: 1,\n"
    "    maxInputs: 1,\n"
    "    transformer: true,\n"
    "    duration: false,\n"
    "    retry: false,\n"
    "  ),\n"
    "  CombinatorKind.filter ||\n"
    "  CombinatorKind.scan ||\n"
    "  CombinatorKind.catchError ||\n"
    "  CombinatorKind.rawEngine => (\n"
    "    minInputs: 1,\n"
    "    maxInputs: 1,\n"
    "    transformer: true,\n"
    "    duration: false,\n"
    "    retry: true,\n"
    "  ),\n"
)


def retry_allowed(rule):
    return [(rule.format("false"), rule.format("true"))]


DEF = "ir/definition.dart"
ORDER = "ir/canonical_order.dart"
ANALYSES = "analysis/analyses.dart"
RENDER = "render/renderers.dart"
FREF = "ir/function_ref.dart"
CODEC = "json/codec.dart"

RECURSIVE_COMPONENTS = """List<List<int>> _components(List<List<int>> arcs) {
  final List<int?> order = List<int?>.filled(arcs.length, null);
  final List<int> low = List<int>.filled(arcs.length, 0);
  final List<bool> open = List<bool>.filled(arcs.length, false);
  final List<int> stack = <int>[];
  final List<List<int>> components = <List<int>>[];
  int visited = 0;
  void search(int v) {
    order[v] = low[v] = visited++;
    stack.add(v);
    open[v] = true;
    for (final int w in arcs[v]) {
      if (order[w] == null) {
        search(w);
        if (low[w] < low[v]) {
          low[v] = low[w];
        }
      } else if (open[w] && order[w]! < low[v]) {
        low[v] = order[w]!;
      }
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

  for (int root = 0; root < arcs.length; root++) {
    if (order[root] == null) {
      search(root);
    }
  }
  return components;
}
"""

DEFECTS = {
    # ---------------------------------------------------- S134: the IR values
    "I5": ("combine takes a retry (ir-values-plan D5)", DEF, retry_allowed(COMBINE)),
    "I5b": ("withLatestFrom takes a retry", DEF, retry_allowed(WITH_LATEST)),
    "I5c": ("merge takes a retry", DEF, retry_allowed(MERGE)),
    "I5d": ("pairwise and distinctUntilChanged take a retry", DEF, retry_allowed(PLAIN)),
    "I5e": ("the six time stages take a retry", DEF, retry_allowed(TIMED)),
    "I5f": ("filter, scan, catchError and rawEngine take a retry; map does not", DEF,
            [(FUNCTION_GROUP, MAP_ALONE)]),
    "I11": ("a definition's equality ignores the order of its edges (ir-values-plan D11)", DEF, [(
        "      elementsEqual(other.transforms, transforms);",
        "      other.transforms.toSet().containsAll(transforms) &&\n"
        "      other.transforms.length == transforms.length;",
    )]),
    "I11b": ("an edge's equality ignores the order of its inputs", DEF, [(
        "      elementsEqual(other.inputs, inputs) &&",
        "      other.inputs.toSet().containsAll(inputs) &&\n"
        "      other.inputs.length == inputs.length &&",
    )]),
    # ---------------------------------------------------- S140: the claim order
    "C1": ("claims that tie on source and scope keep the order they came in", ORDER, [
        ("  for (int i = 0; i < left.length && i < right.length; i++) {",
         "  for (int i = 0; i < 0; i++) {"),
        ("  return left.length.compareTo(right.length);", "  return 0;"),
    ]),
    "C2": ("a longer list of writes first when one is a prefix of the other", ORDER, [
        ("  return left.length.compareTo(right.length);",
         "  return right.length.compareTo(left.length);"),
    ]),
    "C3": ("claims that tie on source and scope compare the number of their writes first", ORDER, [
        ("  for (int i = 0; i < left.length && i < right.length; i++) {",
         "  if (left.length != right.length) {\n"
         "    return left.length.compareTo(right.length);\n"
         "  }\n"
         "  for (int i = 0; i < left.length && i < right.length; i++) {"),
    ]),
    # ---------------------------------------------------- S143, S144: the analyses
    "A1": ("cycles in the order the search completes them, not by first id", ANALYSES, [(
        "  cycles.sort(\n"
        "    (TopologyCycle a, TopologyCycle b) =>\n"
        "        compareTopologyIds(a.topologyIds.first, b.topologyIds.first),\n"
        "  );\n",
        "",
    )]),
    "A2": ("a cycle's topics include a member's own self-read", ANALYSES, [(
        "          (int reader) => reader != writer && members.contains(reader),",
        "          (int reader) => members.contains(reader),",
    )]),
    "A4": ("a self-read matches only a read with no dedup argument", ANALYSES, [(
        "              TopicInput(topic: final TopicRef read) => read == topic,",
        "              TopicInput() => input == TopicInput(topic),",
    )]),
    "A7": ("scope violations by owner in graph order: topologies, then claims", ANALYSES, [(
        "    ]..sort(_byOwner))", "    ])",
    )]),
    "A8": ("findScopeViolations returns a growable list", ANALYSES, [(
        ") => List<ScopeViolation>.unmodifiable(<ScopeViolation>{",
        ") => List<ScopeViolation>.of(<ScopeViolation>{",
    )]),
    "A8b": ("findTopologyCycles returns a growable list", ANALYSES, [(
        "  return List<TopologyCycle>.unmodifiable(cycles);", "  return cycles;",
    )]),
    "A8c": ("findSelfReferences returns a growable list", ANALYSES, [(
        "    List<SelfReference>.unmodifiable(<SelfReference>[",
        "    List<SelfReference>.of(<SelfReference>[",
    )]),
    "A8d": ("findWriterConflicts returns a growable list", ANALYSES, [(
        ") => List<WriterConflict>.unmodifiable(<WriterConflict>[",
        ") => List<WriterConflict>.of(<WriterConflict>[",
    )]),
    "A8e": ("findTopicNameCollisions returns a growable list", ANALYSES, [(
        "  return List<TopicNameCollision>.unmodifiable(<TopicNameCollision>[",
        "  return List<TopicNameCollision>.of(<TopicNameCollision>[",
    )]),
    "A11": ("collisions in the order their names were first met", ANALYSES, [(
        "    for (final String name in byName.keys.toList()..sort())",
        "    for (final String name in byName.keys.toList())",
    )]),
    "A14": ("a cycle's topics passed with repeats, one per writer and reader pair", ANALYSES, [(
        "  topics: <TopicRef>{\n"
        "    for (final int writer in members)\n"
        "      for (final TopicRef topic in topologies[writer].writes)\n"
        "        if ((readers[topic] ?? const <int>[]).any(\n"
        "          (int reader) => reader != writer && members.contains(reader),\n"
        "        ))\n"
        "          topic,\n"
        "  }.toList(),",
        "  topics: <TopicRef>[\n"
        "    for (final int writer in members)\n"
        "      for (final TopicRef topic in topologies[writer].writes)\n"
        "        for (final int reader in readers[topic] ?? const <int>[])\n"
        "          if (reader != writer && members.contains(reader)) topic,\n"
        "  ],",
    )]),
    "A15": ("the cycle search recurses, one call per topology on the path", ANALYSES, "components"),
    # ---------------------------------------------------- S149, S150: the renderers
    "R4": ("Mermaid also escapes &, which the rule leaves as it is", RENDER, [(
        "          .replaceAll('#', '#35;')\n",
        "          .replaceAll('#', '#35;')\n"
        "          .replaceAll('&', '#38;')\n",
    )]),
    "R4b": ("Graphviz also escapes |, [ and ], as for a record label", RENDER, [(
        "          .replaceAll('\"', r'\\\"')\n",
        "          .replaceAll('\"', r'\\\"')\n"
        "          .replaceAll('|', r'\\|')\n"
        "          .replaceAll('[', r'\\[')\n"
        "          .replaceAll(']', r'\\]')\n",
    )]),
    "R4c": ("Mermaid also escapes the single quote", RENDER, [(
        "          .replaceAll('#', '#35;')\n",
        "          .replaceAll('#', '#35;')\n"
        "          .replaceAll(\"'\", '#39;')\n",
    )]),
    "R6": ("an anonymous retry renders as 'retry null'", RENDER, [(
        "      'retry ${_functionName(retry)}',\n",
        "      'retry ${retry.name}',\n",
    )]),
    "R7": ("a duration of a second or more renders in whole seconds", RENDER, [(
        "  if (micros % Duration.microsecondsPerSecond == 0) {\n",
        "  if (micros == 0 || micros >= Duration.microsecondsPerSecond) {\n",
    )]),
    "R12": ("repeated arrows collapse into one", RENDER, [
        ("  return <_Arrow>[\n", "  return <_Arrow>{\n"),
        ("        (from: 's$m', to: topicIds[topic]!, dedup: null),\n  ];\n",
         "        (from: 's$m', to: topicIds[topic]!, dedup: null),\n  }.toList();\n"),
    ]),
    "R13": ("topic ids keyed by name, so one name of two variants shares an id", RENDER, [(
        "  final Map<TopicRef, String> topicIds = <TopicRef, String>{\n"
        "    for (final (int i, TopicRef topic) in graph.topics.indexed) topic: 't$i',\n"
        "  };\n",
        "  final Map<String, String> byName = <String, String>{\n"
        "    for (final (int i, TopicRef topic) in graph.topics.indexed)\n"
        "      topic.name: 't$i',\n"
        "  };\n"
        "  final Map<TopicRef, String> topicIds = <TopicRef, String>{\n"
        "    for (final TopicRef topic in graph.topics) topic: byName[topic.name]!,\n"
        "  };\n",
    )]),
    "R17": ("topic ids keyed by name and variant, so two type names share an id", RENDER, [(
        "  final Map<TopicRef, String> topicIds = <TopicRef, String>{\n"
        "    for (final (int i, TopicRef topic) in graph.topics.indexed) topic: 't$i',\n"
        "  };\n",
        "  final Map<(String, TopicVariant), String> byKey =\n"
        "      <(String, TopicVariant), String>{\n"
        "    for (final (int i, TopicRef topic) in graph.topics.indexed)\n"
        "      (topic.name, topic.variant): 't$i',\n"
        "  };\n"
        "  final Map<TopicRef, String> topicIds = <TopicRef, String>{\n"
        "    for (final TopicRef topic in graph.topics)\n"
        "      topic: byKey[(topic.name, topic.variant)]!,\n"
        "  };\n",
    )]),
    # ---------------------------------------------------- optional pins: G9, G20, G21
    "F1": ("FunctionRef.of keeps the text after the last |", FREF, [(
        "    return FunctionRef.named(rendering.substring(start, end));",
        "    return FunctionRef.named(rendering.substring(start, end).split('|').last);",
    )]),
    "F2": ("FunctionRef.of is anonymous for a constructor tear-off", FREF, [(
        "    if (end <= start) {",
        "    if (end <= start || rendering[end - 1] == '.') {",
    )]),
    "J1": ("the decoder takes any whole double, 2^63 and above clamped by toInt", CODEC, [(
        "  final double d when d >= 0 && d < _twoTo63 && d == d.truncateToDouble() =>",
        "  final double d when d >= 0 && d == d.truncateToDouble() && _twoTo63 > 0 =>",
    )]),
    "J2": ("the decoder takes only a Dart int as an integer", CODEC, [(
        "  final double d when d >= 0 && d < _twoTo63 && d == d.truncateToDouble() =>\n"
        "    d.toInt(),\n",
        "",
    )]),
}


def main():
    if sys.argv[1] == "--list":
        for key, (label, file, _) in DEFECTS.items():
            print(f"{key}\t{file}\t{label}")
        return
    root, key = pathlib.Path(sys.argv[1]), sys.argv[2]
    label, file, edits = DEFECTS[key]
    path = root / "lib" / "src" / file
    text = path.read_text(encoding="utf-8")
    if edits == "components":
        start = text.index("List<List<int>> _components(List<List<int>> arcs) {")
        end = text.index("  return components;\n}\n", start) + len("  return components;\n}\n")
        text = text[:start] + RECURSIVE_COMPONENTS + text[end:]
    else:
        for old, new in edits:
            n = text.count(old)
            if n != 1:
                sys.exit(f"{key}: expected one occurrence, found {n}: {old[:70]!r}")
            text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
