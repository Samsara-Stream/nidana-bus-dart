/// The library contract fixtures import as
/// `package:nidana_contract_check/fixture.dart` (ADR-001 items 4 and 9): the
/// [ConformanceCase] record a conformance library exports its cases as, and
/// [expectMatchesSchema], which a serialized form's conformance cases call on
/// the producer's real output. It is the replay tool's one public library,
/// and it reads the schema file itself.
library;

import 'dart:io';

import 'package:json_schema/json_schema.dart' show JsonSchema;
import 'package:matcher/expect.dart' show fail;
import 'package:path/path.dart' as p;

import 'src/json_document.dart';
import 'src/shell.dart' show findWorkspaceRoot;

/// One case of a conformance library (ADR-001 item 4): its `name` is a string
/// literal that begins with the guarantee id, `'G{n} ...'`, and its `body`
/// runs the case against the harness `H` an implementation supplies.
typedef ConformanceCase<H> = ({
  String name,
  Future<void> Function(H harness) body,
});

/// Fails the current test as `expect` does, listing every validation error,
/// unless the JSON value [instance] validates against the draft 2020-12
/// schema at [schemaPath], a path relative to the workspace root, the nearest
/// ancestor of the current directory that holds `hsdd/contract/`.
///
/// A validation error is the producer's failure and reads as one. A missing
/// workspace root, a missing schema file and a schema that does not compile
/// are defects of the environment or the fixture, so each throws a
/// [StateError] instead. The schema is read and compiled on every call.
void expectMatchesSchema(Object? instance, String schemaPath) {
  final Directory root =
      findWorkspaceRoot(Directory.current) ??
      (throw StateError(
        'no ancestor of ${Directory.current.path} holds hsdd/contract/',
      ));
  final File file = File(
    p.joinAll(<String>[root.path, ...p.posix.split(schemaPath)]),
  );
  if (!file.existsSync()) {
    throw StateError('no schema at $schemaPath under ${root.path}');
  }
  switch (compileSchema(file.readAsBytesSync())) {
    case SchemaProblem(:final String reason):
      throw StateError('$schemaPath: $reason');
    case CompiledSchema(:final JsonSchema schema):
      final List<String> errors = schemaErrors(schema, instance);
      if (errors.isNotEmpty) {
        fail(
          <String>[
            'does not match $schemaPath:',
            for (final String error in errors) '  $error',
          ].join('\n'),
        );
      }
  }
}
