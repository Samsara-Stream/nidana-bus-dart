// Checks the graph documents of the scan invocations: each validates against
// topology-ir@v1's schema (package:json_schema 5.2.2, draft 2020-12) and
// decodes with the stand-in decoder, except the undecodable one, which the
// scan must reject. Usage: dart run tool/graph_check.dart {invocation dir} {schema}
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

void main(List<String> args) {
  final JsonSchema schema = JsonSchema.create(
    jsonDecode(File(args[1]).readAsStringSync()),
    schemaVersion: SchemaVersion.draft2020_12,
  );
  final List<File> graphs = Directory(args[0])
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('/files/topology-graph.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File f in graphs) {
    final String name = f.path.substring(args[0].length + 1);
    final Object? json = jsonDecode(f.readAsStringSync());
    final bool valid = schema.validate(json).isValid;
    String decoded;
    try {
      final TopologyGraph g = decodeTopologyGraph(json);
      decoded = 'decodes (${g.topologies.length} topologies, ${g.claims.length} claims)';
    } on FormatException catch (e) {
      decoded = 'FormatException: ${e.message}';
    }
    print('$name: ${valid ? 'schema-valid' : 'schema-invalid'}, $decoded');
  }
}
