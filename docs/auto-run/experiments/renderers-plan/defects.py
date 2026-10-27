"""Seed one defect into the final draft's renderers.dart, in place.

usage: python3 -I defects.py <renderers.dart> <defect id>
Each defect is a list of exact replacements, each of which must apply
exactly once.
"""
import sys

DEFECTS = {
    # escaping
    "D1": [(  # Mermaid escapes '#' last, so it escapes its own escapes again
        "          .replaceAll('#', '#35;')\n"
        "          .replaceAll('\"', '#quot;')\n"
        "          .replaceAll('<', '#lt;')\n"
        "          .replaceAll('>', '#gt;')\n"
        "          .replaceAll('\\n', '#10;'),\n",
        "          .replaceAll('\"', '#quot;')\n"
        "          .replaceAll('<', '#lt;')\n"
        "          .replaceAll('>', '#gt;')\n"
        "          .replaceAll('\\n', '#10;')\n"
        "          .replaceAll('#', '#35;'),\n")],
    "D2": [(  # Graphviz escapes the backslash last
        "          .replaceAll(r'\\', r'\\\\')\n"
        "          .replaceAll('\"', r'\\\"')\n"
        "          .replaceAll('\\n', r'\\n'),\n",
        "          .replaceAll('\"', r'\\\"')\n"
        "          .replaceAll('\\n', r'\\n')\n"
        "          .replaceAll(r'\\', r'\\\\'),\n")],
    "D3": [(  # Mermaid escapes the joined label, its <br/> breaks included
        "String _mermaidLabel(List<String> lines) => lines\n"
        "    .map(\n",
        "String _mermaidLabel(List<String> lines) => <String>[lines.join('<br/>')]\n"
        "    .map(\n"),
        ("    .join('<br/>');\n", "    .single;\n")],
    "D4": [(  # Mermaid also escapes '&', which the rule leaves as it is
        "          .replaceAll('#', '#35;')\n",
        "          .replaceAll('#', '#35;')\n"
        "          .replaceAll('&', '#38;')\n")],
    "D5": [(  # Graphviz also escapes '{', '}' and '|', as for a record label
        "          .replaceAll('\"', r'\\\"')\n",
        "          .replaceAll('\"', r'\\\"')\n"
        "          .replaceAll('{', r'\\{')\n"
        "          .replaceAll('}', r'\\}')\n"
        "          .replaceAll('|', r'\\|')\n")],
    # labels
    "D6": [(  # an anonymous retry renders as 'retry null'
        "      'retry ${_functionName(retry)}',\n",
        "      'retry ${retry.name}',\n")],
    "D7": [(  # a duration of a second or more renders in whole seconds
        "  if (micros % Duration.microsecondsPerSecond == 0) {\n",
        "  if (micros == 0 || micros >= Duration.microsecondsPerSecond) {\n")],
    "D8": [(  # a duration of a millisecond or more renders in whole milliseconds
        "  if (micros % Duration.microsecondsPerMillisecond == 0) {\n",
        "  if (micros >= Duration.microsecondsPerMillisecond) {\n")],
    "D9": [(  # the duration goes on a line of its own
        "    switch (edge.duration) {\n"
        "      null => name,\n"
        "      final Duration duration => '$name ${_duration(duration)}',\n"
        "    },\n",
        "    name,\n"
        "    if (edge.duration case final Duration duration) _duration(duration),\n")],
    "D10": [(  # the retry line comes before the transformer line
        "    if (edge.transformer case final FunctionRef transformer)\n"
        "      _functionName(transformer),\n"
        "    if (edge.retry case final FunctionRef retry)\n"
        "      'retry ${_functionName(retry)}',\n",
        "    if (edge.retry case final FunctionRef retry)\n"
        "      'retry ${_functionName(retry)}',\n"
        "    if (edge.transformer case final FunctionRef transformer)\n"
        "      _functionName(transformer),\n")],
    "D11": [(  # a scope renders as Scope.page
        "  definition.scope.name,\n", "  '${definition.scope}',\n")],
    # arrows and ids
    "D12": [(  # repeated arrows collapse into one
        "  return <_Arrow>[\n", "  return <_Arrow>{\n"),
        ("        (from: 's$m', to: topicIds[topic]!, dedup: null),\n  ];\n",
         "        (from: 's$m', to: topicIds[topic]!, dedup: null),\n  }.toList();\n")],
    "D13": [(  # topic ids keyed by name, so one name of two variants shares an id
        "  final Map<TopicRef, String> topicIds = <TopicRef, String>{\n"
        "    for (final (int i, TopicRef topic) in graph.topics.indexed) topic: 't$i',\n"
        "  };\n",
        "  final Map<String, String> byName = <String, String>{\n"
        "    for (final (int i, TopicRef topic) in graph.topics.indexed)\n"
        "      topic.name: 't$i',\n"
        "  };\n"
        "  final Map<TopicRef, String> topicIds = <TopicRef, String>{\n"
        "    for (final TopicRef topic in graph.topics) topic: byName[topic.name]!,\n"
        "  };\n")],
    "D14": [(  # the sink output arrows come after every input arrow of the graph
        "        if (edge.output case final TopicRef output)\n"
        "          (from: 'p${j}e$k', to: topicIds[output]!, dedup: null),\n"
        "      ],\n",
        "      ],\n"
        "    for (final (int j, TopologyDefinition definition)\n"
        "        in graph.topologies.indexed)\n"
        "      for (final (int k, TransformEdge edge)\n"
        "          in definition.transforms.indexed)\n"
        "        if (edge.output case final TopicRef output)\n"
        "          (from: 'p${j}e$k', to: topicIds[output]!, dedup: null),\n")],
    "D15": [(  # no newline after the last line
        "    lines.map((String line) => '$line\\n').join();\n",
        "    lines.join('\\n');\n")],
    "D16": [(  # Mermaid labels a dedup arrow with the enum's toString
        "          '  ${arrow.from} -->|dedup ${dedup.name}| ${arrow.to}',\n",
        "          '  ${arrow.from} -->|dedup $dedup| ${arrow.to}',\n")],
}

path, defect = sys.argv[1], sys.argv[2]
text = open(path).read()
for old, new in DEFECTS[defect]:
    n = text.count(old)
    if n != 1:
        sys.exit(f"{defect}: expected one occurrence, found {n}: {old[:60]!r}")
    text = text.replace(old, new)
open(path, "w").write(text)
