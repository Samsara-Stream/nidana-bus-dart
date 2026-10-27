import '../graph/graph.dart';
import '../ir/definition.dart';

/// The graph document of [graph] as a JSON value (maps, lists, strings,
/// integers, booleans and null), keys in the order the schema lists them.
Map<String, Object?> encodeTopologyGraph(TopologyGraph graph) =>
    throw UnimplementedError();

/// The graph a graph document describes. Throws FormatException, and no
/// other error, for any value that is not a graph document of this version
/// or breaks a rule of the decoder.
TopologyGraph decodeTopologyGraph(Object? json) => throw UnimplementedError();

/// The object a graph document lists for [definition], and its inverse.
Map<String, Object?> encodeTopologyDefinition(TopologyDefinition definition) =>
    throw UnimplementedError();
TopologyDefinition decodeTopologyDefinition(Object? json) =>
    throw UnimplementedError();

/// The graph document as JSON text (The JSON form).
final class JsonRenderer implements GraphRenderer {
  const JsonRenderer();

  @override
  String render(TopologyGraph graph) => throw UnimplementedError();
}
