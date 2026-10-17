// The pure core of the stand-in generator: file contents in, file contents
// or violations out. The builder and the command both call these.
import 'dart:convert';

import 'package:nidana_dart_contracts/topology_ir.dart';

import 'catalog.dart';
import 'graph_html.dart';
import 'registry.dart';
import 'topics_document.dart';

/// What `generate` writes, by file name, or the diagnostics that stop it.
final class GenerateResult {
  const GenerateResult._(this.outputs, this.diagnostics);
  final Map<String, String> outputs;
  final List<String> diagnostics;
  bool get ok => diagnostics.isEmpty;
}

/// topics.g.dart alone, for the builder: the same bytes `generate` writes.
({String? registry, List<String> diagnostics}) generateRegistry(
  String topicsSource,
  String topicsPath,
) {
  final read = readTopicsDocument(topicsSource);
  if (read.document == null) {
    return (
      registry: null,
      diagnostics: [for (final v in read.violations) v.render(topicsPath)],
    );
  }
  return (registry: renderRegistry(read.document!), diagnostics: const []);
}

GenerateResult generate({
  required String topicsSource,
  required String topicsPath,
  String? graphSource,
  String? graphPath,
}) {
  final diagnostics = <String>[];
  final read = readTopicsDocument(topicsSource);
  diagnostics.addAll(read.violations.map((v) => v.render(topicsPath)));
  TopologyGraph? graph;
  if (graphSource != null) {
    try {
      graph = decodeTopologyGraph(jsonDecode(graphSource));
    } on FormatException catch (e) {
      diagnostics.add('$graphPath: ${e.message}');
    }
  }
  if (diagnostics.isNotEmpty) return GenerateResult._(const {}, diagnostics);
  final doc = read.document!;
  return GenerateResult._({
    'topics.g.dart': renderRegistry(doc),
    'topics.md': renderCatalog(doc, graph),
    if (graph != null) 'topology-graph.html': renderGraphHtml(graph),
  }, const []);
}
