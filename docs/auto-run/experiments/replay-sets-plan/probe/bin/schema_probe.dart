// package:json_schema 5.2.2 facts (questions J1 to J5) and the committed
// schema sets replayed (J6). Run from the repository root.
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';

void main() {
  print('### J1 errors for {} against topology-ir: every error, and how each prints');
  final JsonSchema ir = JsonSchema.create(
      jsonDecode(File('hsdd/contract/schema/topology-ir.schema.json').readAsStringSync()) as Object,
      schemaVersion: SchemaVersion.draft2020_12);
  final ValidationResults empty = ir.validate(<String, Object?>{});
  print('isValid: ${empty.isValid}, errors: ${empty.errors.length}');
  for (final ValidationError e in empty.errors) {
    print('  toString: $e');
    print('  instancePath: "${e.instancePath}" schemaPath: "${e.schemaPath}" message: "${e.message}"');
  }
  print('warnings: ${empty.warnings.length}');
  final ValidationResults two = ir.validate(<String, Object?>{'format': 'x', 'topologies': 3, 'claims': <Object?>[]});
  print('two wrong values: ${two.errors.length} errors');
  for (final ValidationError e in two.errors) print('  $e');

  print('### J2 a schema that does not compile');
  for (final Object schema in <Object>[
    <String, Object?>{'type': 5},
    <String, Object?>{'\$ref': '#/\$defs/missing'},
    <String, Object?>{'minItems': -1},
    'not a schema',
    <Object?>[1, 2],
  ]) {
    try {
      final JsonSchema s = JsonSchema.create(schema, schemaVersion: SchemaVersion.draft2020_12);
      final ValidationResults r = s.validate(<String, Object?>{});
      print('  ${jsonEncode(schema)}: created; validate {} -> isValid ${r.isValid} errors ${r.errors}');
    } on Object catch (e) {
      print('  ${jsonEncode(schema)}: ${e.runtimeType}: ${e.toString().split('\n').first}');
    }
  }

  print('### J3 validate() of an undecoded string and of non-JSON Dart values');
  print('  validate("{}") isValid: ${ir.validate('{}').isValid}');
  final JsonSchema any = JsonSchema.create(<String, Object?>{'type': 'object'}, schemaVersion: SchemaVersion.draft2020_12);
  print('  type object vs 1: ${any.validate(1).errors}');

  print('### J4 \$schema declared draft-07 while schemaVersion says 2020-12');
  final JsonSchema d7 = JsonSchema.create(<String, Object?>{
    '\$schema': 'http://json-schema.org/draft-07/schema#',
    'prefixItems': <Object?>[<String, Object?>{'type': 'string'}],
  }, schemaVersion: SchemaVersion.draft2020_12);
  print('  schemaVersion: ${d7.schemaVersion}; [1] valid: ${d7.validate(<Object?>[1]).isValid}');
  final JsonSchema d2020 = JsonSchema.create(<String, Object?>{
    'prefixItems': <Object?>[<String, Object?>{'type': 'string'}],
  }, schemaVersion: SchemaVersion.draft2020_12);
  print('  no \$schema: schemaVersion: ${d2020.schemaVersion}; [1] valid: ${d2020.validate(<Object?>[1]).isValid}');

  print('### J5 format keyword: annotation or assertion by default');
  final JsonSchema fmt = JsonSchema.create(<String, Object?>{'type': 'string', 'format': 'email'}, schemaVersion: SchemaVersion.draft2020_12);
  print('  "x" against format email: ${fmt.validate('x').isValid}');

  print('### J6 the committed schema sets: every valid/ file validates, no invalid/ file does');
  for (final String slug in <String>['topology-ir', 'topic-codegen']) {
    final JsonSchema schema = JsonSchema.create(
        jsonDecode(File('hsdd/contract/schema/$slug.schema.json').readAsStringSync()) as Object,
        schemaVersion: SchemaVersion.draft2020_12);
    int pass = 0;
    int fail = 0;
    for (final String set in <String>['valid', 'invalid']) {
      final List<File> files = Directory('hsdd/contract/fixture/$slug/$set')
          .listSync(recursive: true).whereType<File>().toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
      for (final File f in files) {
        final ValidationResults r = schema.validate(jsonDecode(utf8.decode(f.readAsBytesSync())));
        final bool ok = r.isValid == (set == 'valid');
        ok ? pass++ : fail++;
        if (!ok || set == 'invalid' && f.path.endsWith('dedup-unknown.json')) {
          print('  ${ok ? 'PASS' : 'FAIL'} $slug $set/${f.uri.pathSegments.last}: ${r.errors.join('; ')}');
        }
      }
    }
    print('  $slug: $pass passed, $fail failed (files: ${pass + fail})');
  }
}
