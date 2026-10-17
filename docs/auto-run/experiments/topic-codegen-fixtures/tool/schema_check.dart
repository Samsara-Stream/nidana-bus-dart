// Prototype of the replay tool's schema set for topic-codegen@v1
// (ADR-001 items 5 and 9) on package:json_schema 5.2.2: every valid/ file
// validates, no invalid/ file does. It also validates, as YAML read into
// its JSON data model, the file replay's input/topics.yaml and every
// rejected/ document that parses, which the schema accepts and only the
// generator rejects. Usage: dart run tool/schema_check.dart {fixture dir} {schema}
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:yaml/yaml.dart';

Object? plain(Object? node) => switch (node) {
  YamlMap m => {for (final e in m.entries) '${e.key}': plain(e.value)},
  YamlList l => [for (final v in l) plain(v)],
  _ => node,
};

void main(List<String> args) {
  final dir = args[0];
  final schema = JsonSchema.create(
    jsonDecode(File(args[1]).readAsStringSync()),
    schemaVersion: SchemaVersion.draft2020_12,
  );
  var failures = 0;
  void check(String label, Object? instance, {required bool valid}) {
    final result = schema.validate(instance);
    final ok = result.isValid == valid;
    if (!ok) failures++;
    final why = result.isValid
        ? ''
        : ' at ${result.errors.map((e) => e.instancePath.isEmpty ? '/' : e.instancePath).toSet().join(', ')}';
    print('${ok ? 'PASS' : 'FAIL'} $label: ${result.isValid ? 'valid' : 'invalid'}${valid ? '' : why}');
  }

  List<File> files(String sub) =>
      Directory('$dir/$sub').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in files('valid')) {
    check('valid/${f.uri.pathSegments.last}', jsonDecode(f.readAsStringSync()), valid: true);
  }
  for (final f in files('invalid')) {
    check('invalid/${f.uri.pathSegments.last}', jsonDecode(f.readAsStringSync()), valid: false);
  }
  check('input/topics.yaml', plain(loadYaml(File('$dir/input/topics.yaml').readAsStringSync())), valid: true);
  for (final f in files('rejected')) {
    final name = 'rejected/${f.uri.pathSegments.last}';
    Object? doc;
    try {
      doc = plain(loadYaml(f.readAsStringSync()));
    } on YamlException catch (e) {
      print('SKIP $name: not one YAML document (${e.message})');
      continue;
    }
    check(name, doc, valid: true);
  }
  print('schema check: $failures failure(s)');
  exitCode = failures == 0 ? 0 : 1;
}
