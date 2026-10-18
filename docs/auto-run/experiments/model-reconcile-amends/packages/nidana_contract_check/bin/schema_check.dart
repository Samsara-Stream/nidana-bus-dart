// Prototype of the replay tool's `schema` set (ADR-001 items 5 and 9) for
// one slug: the schema compiles under draft 2020-12, every file under
// valid/ validates and no file under invalid/ does. Run from the experiment
// root: schema_check {slug}.
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';

void main(List<String> args) {
  final slug = args.single;
  final schema = JsonSchema.create(
      jsonDecode(File('hsdd/contract/schema/$slug.schema.json').readAsStringSync()) as Object,
      schemaVersion: SchemaVersion.draft2020_12);
  var failures = 0;
  for (final set in <String>['valid', 'invalid']) {
    final files = Directory('hsdd/contract/fixture/$slug/$set')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final results = schema.validate(jsonDecode(f.readAsStringSync()));
      final ok = results.isValid == (set == 'valid');
      if (!ok) failures++;
      final why = results.errors.isEmpty
          ? ''
          : ' (${results.errors.first.instancePath}: ${results.errors.first.message})';
      print('${ok ? 'PASS' : 'FAIL'} $set/${f.uri.pathSegments.last}$why');
    }
  }
  exit(failures == 0 ? 0 : 1);
}
