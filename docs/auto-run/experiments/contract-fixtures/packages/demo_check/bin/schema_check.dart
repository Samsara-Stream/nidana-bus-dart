// Validates every valid/ and invalid/ file of a schema fixture set with
// package:json_schema, against a draft 2020-12 schema.
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';

void main(List<String> args) {
  final schemaPath = args[0];
  final fixtureDir = args[1];
  final schema = JsonSchema.create(
    File(schemaPath).readAsStringSync(),
    schemaVersion: SchemaVersion.draft2020_12,
  );
  var failures = 0;
  for (final kind in ['valid', 'invalid']) {
    final files = Directory('$fixtureDir/$kind').listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final result = schema.validate(jsonDecode(f.readAsStringSync()));
      final ok = (kind == 'valid') == result.isValid;
      if (!ok) failures++;
      final name = f.uri.pathSegments.last;
      print('${ok ? 'PASS' : 'FAIL'} $kind/$name isValid=${result.isValid}'
          '${result.errors.isEmpty ? '' : ' errors=${result.errors.map((e) => e.message).join('; ')}'}');
    }
  }
  print('schema version reported: ${schema.schemaVersion}');
  exit(failures == 0 ? 0 : 1);
}
