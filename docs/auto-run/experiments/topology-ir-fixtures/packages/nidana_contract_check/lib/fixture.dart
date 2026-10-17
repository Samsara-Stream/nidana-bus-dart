/// Stand-in for `package:nidana_contract_check/fixture.dart` (ADR-001 item 4).
library;

import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:matcher/expect.dart';

/// One conformance case: a name beginning with its guarantee id, and a body
/// that runs against the harness an implementation supplies.
typedef ConformanceCase<H> = ({String name, Future<void> Function(H harness) body});

/// The workspace root: the nearest ancestor of the current directory, the
/// directory itself included, that holds `hsdd/contract/`.
Directory _workspaceRoot() {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/hsdd/contract').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('no ancestor of ${Directory.current.path} holds hsdd/contract/');
    }
    dir = parent;
  }
  return dir;
}

final Map<String, JsonSchema> _schemas = <String, JsonSchema>{};

/// Fails the current test, as `expect` does, unless the JSON value
/// [instance] validates against the JSON Schema (draft 2020-12) at
/// [schemaPath], a path relative to the workspace root, listing every
/// validation error.
void expectMatchesSchema(Object? instance, String schemaPath) {
  final schema = _schemas.putIfAbsent(schemaPath, () {
    final file = File('${_workspaceRoot().path}/$schemaPath');
    return JsonSchema.create(jsonDecode(file.readAsStringSync()) as Object,
        schemaVersion: SchemaVersion.draft2020_12);
  });
  final results = schema.validate(instance);
  if (!results.isValid) {
    fail('does not match $schemaPath:\n'
        '${results.errors.map((e) => '  ${e.instancePath}: ${e.message}').join('\n')}');
  }
}
