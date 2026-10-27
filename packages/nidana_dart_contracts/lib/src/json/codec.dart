import 'dart:convert';

import '../graph/graph.dart';
import '../ir/definition.dart';
import '../ir/function_ref.dart';
import '../topic/topic.dart';

/// The graph document of [graph] as a JSON value (maps, lists, strings,
/// integers, booleans and null), keys in the order the schema lists them.
Map<String, Object?> encodeTopologyGraph(TopologyGraph graph) =>
    <String, Object?>{
      'format': _format,
      'topologies': <Object?>[
        for (final TopologyDefinition definition in graph.topologies)
          encodeTopologyDefinition(definition),
      ],
      'claims': <Object?>[
        for (final ShellClaim claim in graph.claims) _encodeClaim(claim),
      ],
    };

/// The graph a graph document describes. Throws FormatException, and no
/// other error, for any value that is not a graph document of this version
/// or breaks a rule of the decoder.
TopologyGraph decodeTopologyGraph(Object? json) => throw UnimplementedError();

/// The object a graph document lists for [definition], and its inverse.
Map<String, Object?> encodeTopologyDefinition(
  TopologyDefinition definition,
) => <String, Object?>{
  'topologyId': definition.topologyId,
  'scope': definition.scope.name,
  'reads': <Object?>[
    for (final TopicRef topic in definition.reads) _encodeTopic(topic),
  ],
  'writes': <Object?>[
    for (final TopicRef topic in definition.writes) _encodeTopic(topic),
  ],
  'transforms': <Object?>[
    for (final TransformEdge edge in definition.transforms) _encodeEdge(edge),
  ],
};
TopologyDefinition decodeTopologyDefinition(Object? json) =>
    throw UnimplementedError();

/// The graph document as JSON text (The JSON form).
final class JsonRenderer implements GraphRenderer {
  const JsonRenderer();

  // The graph document of graph as JSON text: its encoding indented by two
  // spaces, a newline at the end.
  @override
  String render(TopologyGraph graph) =>
      '${_indented.convert(encodeTopologyGraph(graph))}\n';
}

// The value of a graph document's "format" member, which the encoder writes
// and the decoder compares a document's "format" with.
const String _format = 'topology-ir@v1';

// The encoder behind JsonRenderer.render: two-space indentation, keys in the
// order of the map it is given.
const JsonEncoder _indented = JsonEncoder.withIndent('  ');

// The object a graph document lists for edge: combinator (not for a write),
// inputs, then output, transformer, durationMicros and retry, each only where
// the edge holds one.
Map<String, Object?> _encodeEdge(TransformEdge edge) => <String, Object?>{
  if (edge.combinator case final CombinatorKind combinator)
    'combinator': combinator.name,
  'inputs': <Object?>[
    for (final EdgeInput input in edge.inputs) _encodeInput(input),
  ],
  if (edge.output case final TopicRef output) 'output': _encodeTopic(output),
  if (edge.transformer case final FunctionRef transformer)
    'transformer': _encodeFunction(transformer),
  if (edge.duration case final Duration duration)
    'durationMicros': duration.inMicroseconds,
  if (edge.retry case final FunctionRef retry) 'retry': _encodeFunction(retry),
};

// The object a graph document lists for input: {topic} with dedup after it
// when the read gave one, or {edge}.
Map<String, Object?> _encodeInput(EdgeInput input) => switch (input) {
  TopicInput(:final TopicRef topic, :final Dedup? dedup) => <String, Object?>{
    'topic': _encodeTopic(topic),
    if (dedup != null) 'dedup': dedup.name,
  },
  StageInput(:final int edge) => <String, Object?>{'edge': edge},
};

// The object a graph document lists for topic: name, variant by name and
// typeName.
Map<String, Object?> _encodeTopic(TopicRef topic) => <String, Object?>{
  'name': topic.name,
  'variant': topic.variant.name,
  'typeName': topic.typeName,
};

// The object a graph document lists for function: its name, null when it is
// anonymous.
Map<String, Object?> _encodeFunction(FunctionRef function) => <String, Object?>{
  'name': function.name,
};

// The object a graph document lists for claim: its source as the source
// renders, its scope by name and its writes in the claim's canonical order.
Map<String, Object?> _encodeClaim(ShellClaim claim) => <String, Object?>{
  'source': claim.source.toString(),
  'scope': claim.scope.name,
  'writes': <Object?>[
    for (final TopicRef topic in claim.writes) _encodeTopic(topic),
  ],
};
