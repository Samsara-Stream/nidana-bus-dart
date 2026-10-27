# defects.py: seeds one defect into lib/src/analysis/analyses.dart of the
# temporary tree, for run.sh's step D.
#   python3 -I defects.py <analyses.dart> <label>
# Each defect is a list of (old, new) replacements, each old text found once.
import sys

path, label = sys.argv[1:3]

DEFECTS = {
    "d1": [  # cycles in the order the search completes them
        (
            "  cycles.sort(\n"
            "    (TopologyCycle a, TopologyCycle b) =>\n"
            "        compareTopologyIds(a.topologyIds.first, b.topologyIds.first),\n"
            "  );\n",
            "",
        ),
    ],
    "d2": [  # a cycle's topics include a member's own self-read
        (
            "          (int reader) => reader != writer && members.contains(reader),",
            "          (int reader) => members.contains(reader),",
        ),
    ],
    "d3": [  # self-reference edges: every edge a read reaches, when a write is reachable at all
        (
            "      if (fromRead[i] && toWrite[i]) i,",
            "      if (fromRead[i] && toWrite.contains(true)) i,",
        ),
    ],
    "d4": [  # a read matches only when it has no dedup argument
        (
            "TopicInput(topic: final TopicRef read) => read == topic,",
            "TopicInput() => input == TopicInput(topic),",
        ),
    ],
    "d5": [  # every time stage mediates, whatever its duration
        (
            "      !edge.isStateBearing &&\n          edge.inputs.any(",
            "      !(edge.isStateBearing || edge.duration != null) &&\n          edge.inputs.any(",
        ),
    ],
    "d6": [  # scope violations keep equal owners' repeats
        (
            "    List<ScopeViolation>.unmodifiable(<ScopeViolation>{",
            "    List<ScopeViolation>.unmodifiable(<ScopeViolation>[",
        ),
        (
            "                readerScope: reader.scope,\n              ),\n    });",
            "                readerScope: reader.scope,\n              ),\n    ]);",
        ),
    ],
    "d7": [  # scope violations by owner in graph order: topologies, then claims
        (
            "_owners(graph, topic)..sort(_byOwner))",
            "_owners(graph, topic))",
        ),
    ],
    "d8": [  # findScopeViolations returns a growable list
        (
            "    List<ScopeViolation>.unmodifiable(<ScopeViolation>{",
            "    List<ScopeViolation>.of(<ScopeViolation>{",
        ),
    ],
    "d9": [  # writer conflicts count equal claims once
        (
            "            writers: <MessageSource>[\n"
            "              for (final _Owner owner in owners) owner.source,\n"
            "            ],",
            "            writers: <MessageSource>{\n"
            "              for (final _Owner owner in owners) owner.source,\n"
            "            }.toList(),",
        ),
    ],
    "d10": [  # collisions count a repeated declaration twice
        (
            "  final Map<String, Set<TopicDeclaration>> byName =\n"
            "      <String, Set<TopicDeclaration>>{};",
            "  final Map<String, List<TopicDeclaration>> byName =\n"
            "      <String, List<TopicDeclaration>>{};",
        ),
        (
            "(byName[declaration.topic.name] ??= <TopicDeclaration>{})",
            "(byName[declaration.topic.name] ??= <TopicDeclaration>[])",
        ),
    ],
    "d11": [  # collisions in the order their names were first met
        (
            "    for (final String name in byName.keys.toList()..sort())",
            "    for (final String name in byName.keys.toList())",
        ),
    ],
    "d12": [  # self-references by topology in reverse graph order
        (
            "      for (final TopologyDefinition topology in graph.topologies)\n"
            "        ...findSelfReferences(topology),",
            "      for (final TopologyDefinition topology in graph.topologies.reversed)\n"
            "        ...findSelfReferences(topology),",
        ),
    ],
    "d13": [  # arcs only through state topics
        (
            "      for (final TopicRef topic in topologies[i].writes)\n"
            "        for (final int reader in readers[topic] ?? const <int>[])",
            "      for (final TopicRef topic in topologies[i].writes)\n"
            "        if (topic.variant == TopicVariant.state)\n"
            "        for (final int reader in readers[topic] ?? const <int>[])",
        ),
    ],
    "d14": [  # a cycle's topics passed with repeats, one per writer and reader pair
        (
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
        ),
    ],
}

s = open(path).read()
for old, new in DEFECTS[label]:
    assert s.count(old) == 1, f"{label}: seed text not found once: {old[:60]!r}"
    s = s.replace(old, new)
open(path, "w").write(s)
