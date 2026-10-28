import '../graph/graph.dart';

final class MermaidRenderer implements GraphRenderer {
  const MermaidRenderer();

  @override
  String render(TopologyGraph graph) => throw UnimplementedError();
}

final class GraphvizRenderer implements GraphRenderer {
  const GraphvizRenderer();

  @override
  String render(TopologyGraph graph) => throw UnimplementedError();
}
