// Stand-in for the build-time topology graph page of topic-codegen@v1
// (Guide C.4): the Mermaid rendering of topology-ir@v1, in static HTML.
import 'package:nidana_dart_contracts/topology_ir.dart';

const mermaidModule =
    'https://cdn.jsdelivr.net/npm/mermaid@11.12.0/dist/mermaid.esm.min.mjs';

String htmlEscape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// topology-graph.html for [graph].
String renderGraphHtml(TopologyGraph graph) {
  final mermaid = const MermaidRenderer().render(graph);
  return '<!DOCTYPE html>\n'
      '<!-- GENERATED CODE - DO NOT MODIFY BY HAND. -->\n'
      '<!-- nidana_dart_codegen from topology-graph.json (topic-codegen@v1). -->\n'
      '<html lang="en">\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<title>Topology graph</title>\n'
      '<script type="module">\n'
      'import mermaid from "$mermaidModule";\n'
      'mermaid.initialize({ startOnLoad: true });\n'
      '</script>\n'
      '</head>\n'
      '<body>\n'
      '<h1>Topology graph</h1>\n'
      '<p>${_count(graph.topologies.length, 'topology', 'topologies')}, '
      '${_count(graph.claims.length, 'shell claim', 'shell claims')}, '
      '${_count(graph.topics.length, 'topic', 'topics')}.</p>\n'
      '<pre class="mermaid">\n'
      '${htmlEscape(mermaid)}</pre>\n'
      '</body>\n'
      '</html>\n';
}
