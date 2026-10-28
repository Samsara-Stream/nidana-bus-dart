// I of json-form-plan: the final draft codec against every file under
// hsdd/contract/fixture/topology-ir/valid/ and invalid/, one by one, with
// the replay tool's validator beside it. run.sh copies this file into the
// temporary workspace's packages/nidana_contract_check/tool/ and runs it from
// the workspace root (it needs package:json_schema and the draft package).
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart' show JsonSchema;
import 'package:nidana_contract_check/src/json_document.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

const String fixtures = 'hsdd/contract/fixture/topology-ir';

List<File> files(String set) =>
    Directory('$fixtures/$set')
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.json'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

String name(File f) => f.uri.pathSegments.last;

void main() {
  final JsonSchema schema = switch (compileSchema(
    File('hsdd/contract/schema/topology-ir.schema.json').readAsBytesSync(),
  )) {
    CompiledSchema(:final JsonSchema schema) => schema,
    SchemaProblem(:final String reason) => throw StateError(reason),
  };
  print('I1 valid/: schema verdict; decode; re-render byte for byte');
  for (final File f in files('valid')) {
    final String text = f.readAsStringSync();
    final Object? doc = jsonDecode(text);
    final bool valid = schemaErrors(schema, doc).isEmpty;
    final TopologyGraph g = decodeTopologyGraph(doc);
    final bool bytes = const JsonRenderer().render(g) == text;
    final bool again = decodeTopologyGraph(encodeTopologyGraph(g)) == g;
    print(
      '  ${name(f)}: schema ${valid ? 'valid' : 'INVALID'}; '
      'decoded ${g.topologies.length} topologies, ${g.claims.length} claims; '
      'render == file: $bytes; decode(encode(g)) == g: $again',
    );
  }
  print('I2 invalid/: schema verdict; what the decoder throws');
  int formatExceptions = 0;
  for (final File f in files('invalid')) {
    final Object? doc = jsonDecode(f.readAsStringSync());
    final bool invalid = schemaErrors(schema, doc).isNotEmpty;
    String outcome;
    try {
      decodeTopologyGraph(doc);
      outcome = 'ACCEPTED';
    } on FormatException catch (e) {
      formatExceptions++;
      outcome = 'FormatException: ${e.message}';
    } on Object catch (e) {
      outcome = '${e.runtimeType}: $e';
    }
    print(
      '  ${name(f)}: schema ${invalid ? 'rejects' : 'ACCEPTS'}; $outcome',
    );
  }
  print(
    'I3 ${files('invalid').length} invalid files, '
    '$formatExceptions rejected with a FormatException',
  );
}
