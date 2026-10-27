import '../graph/graph.dart';
import '../ir/definition.dart';
import '../ir/function_ref.dart';
import '../topic/topic.dart';

final class MermaidRenderer implements GraphRenderer {
  const MermaidRenderer();

  // The graph as a Mermaid flowchart (topology-ir@v1, Mermaid and Graphviz
  // rules): the header, the topics, each topology as a subgraph holding its
  // edges, the claims, then the arrows.
  @override
  String render(TopologyGraph graph) => _text(<String>[
    'flowchart LR',
    for (final (int i, TopicRef topic) in graph.topics.indexed)
      '  t$i(["${_mermaidLabel(_topicLabel(topic))}"])',
    for (final (int j, TopologyDefinition definition)
        in graph.topologies.indexed) ...<String>[
      '  subgraph p$j["${_mermaidLabel(_topologyLabel(definition))}"]',
      for (final (int k, TransformEdge edge) in definition.transforms.indexed)
        '    p${j}e$k["${_mermaidLabel(_edgeLabel(edge))}"]',
      '  end',
    ],
    for (final (int m, ShellClaim claim) in graph.claims.indexed)
      '  s$m["${_mermaidLabel(_claimLabel(claim))}"]',
    for (final _Arrow arrow in _arrows(graph))
      switch (arrow.dedup) {
        null => '  ${arrow.from} --> ${arrow.to}',
        final Dedup dedup =>
          '  ${arrow.from} -->|dedup ${dedup.name}| ${arrow.to}',
      },
  ]);
}

final class GraphvizRenderer implements GraphRenderer {
  const GraphvizRenderer();

  @override
  String render(TopologyGraph graph) => throw UnimplementedError();
}

// The text of [lines]: each line followed by a newline.
String _text(List<String> lines) =>
    lines.map((String line) => '$line\n').join();

// A topic's label lines: its name; its variant and type name.
List<String> _topicLabel(TopicRef topic) => <String>[
  topic.name,
  '${topic.variant.name} ${topic.typeName}',
];

// A topology's label lines: its id; its scope.
List<String> _topologyLabel(TopologyDefinition definition) => <String>[
  definition.topologyId,
  definition.scope.name,
];

// An edge's label lines: the combinator's name, or write for a write, with
// the duration after one space when the edge has one; the transformer's
// name when it has one; retry and the retry's name when it has one.
List<String> _edgeLabel(TransformEdge edge) {
  final String name = edge.combinator?.name ?? 'write';
  return <String>[
    switch (edge.duration) {
      null => name,
      final Duration duration => '$name ${_duration(duration)}',
    },
    if (edge.transformer case final FunctionRef transformer)
      _functionName(transformer),
    if (edge.retry case final FunctionRef retry)
      'retry ${_functionName(retry)}',
  ];
}

// A claim's label lines: its source's rendering; its scope.
List<String> _claimLabel(ShellClaim claim) => <String>[
  claim.source.toString(),
  claim.scope.name,
];

// A function reference's name, (anonymous) for an anonymous one.
String _functionName(FunctionRef function) => function.name ?? '(anonymous)';

// Whole seconds when [duration] is a multiple of a second, else whole
// milliseconds when it is a multiple of a millisecond, else microseconds.
String _duration(Duration duration) {
  final int micros = duration.inMicroseconds;
  if (micros % Duration.microsecondsPerSecond == 0) {
    return '${micros ~/ Duration.microsecondsPerSecond}s';
  }
  if (micros % Duration.microsecondsPerMillisecond == 0) {
    return '${micros ~/ Duration.microsecondsPerMillisecond}ms';
  }
  return '${micros}us';
}

// A Mermaid label: each line escaped, the lines joined by <br/>. The '#'
// goes first, so that the escapes the other replacements write stay as
// written.
String _mermaidLabel(List<String> lines) => lines
    .map(
      (String line) => line
          .replaceAll('#', '#35;')
          .replaceAll('"', '#quot;')
          .replaceAll('<', '#lt;')
          .replaceAll('>', '#gt;')
          .replaceAll('\n', '#10;'),
    )
    .join('<br/>');

// One arrow: the ids of the nodes it runs from and to, and the dedup the
// read gave when it runs from a read's topic.
typedef _Arrow = ({String from, String to, Dedup? dedup});

// Every arrow of [graph] in the rules' order: per topology in graph order,
// per edge in order, one from each input in input order, then for a sink
// edge one to its output topic; then per claim, one to each claimed topic in
// canonical order. Every topic an edge or a claim names is one of
// graph.topics (topology-ir@v1 G11).
List<_Arrow> _arrows(TopologyGraph graph) {
  final Map<TopicRef, String> topicIds = <TopicRef, String>{
    for (final (int i, TopicRef topic) in graph.topics.indexed) topic: 't$i',
  };
  return <_Arrow>[
    for (final (int j, TopologyDefinition definition)
        in graph.topologies.indexed)
      for (final (int k, TransformEdge edge)
          in definition.transforms.indexed) ...<_Arrow>[
        for (final EdgeInput input in edge.inputs)
          switch (input) {
            TopicInput(:final TopicRef topic, :final Dedup? dedup) => (
              from: topicIds[topic]!,
              to: 'p${j}e$k',
              dedup: dedup,
            ),
            StageInput(edge: final int index) => (
              from: 'p${j}e$index',
              to: 'p${j}e$k',
              dedup: null,
            ),
          },
        if (edge.output case final TopicRef output)
          (from: 'p${j}e$k', to: topicIds[output]!, dedup: null),
      ],
    for (final (int m, ShellClaim claim) in graph.claims.indexed)
      for (final TopicRef topic in claim.writes)
        (from: 's$m', to: topicIds[topic]!, dedup: null),
  ];
}
