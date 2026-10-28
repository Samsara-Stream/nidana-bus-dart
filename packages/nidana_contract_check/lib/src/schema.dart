/// The `schema` set (ADR-001 items 5 and 9): the schema at
/// `hsdd/contract/schema/{slug}.schema.json` compiles under draft 2020-12,
/// every document below `valid/` validates against it and no document below
/// `invalid/` does.
///
/// It reads one [SlugSnapshot]'s schema bytes and documents and nothing
/// else, so an input or expected tree and a data directory are never read.
library;

import 'package:json_schema/json_schema.dart' show JsonSchema;

import 'json_document.dart';
import 'outcome.dart';
import 'snapshot.dart';

/// The rules of the `schema` set.
enum SchemaRule implements Rule {
  /// The schema file is present, is JSON, compiles under draft 2020-12 and
  /// validates every document that is JSON without throwing.
  schemaFile('schema-file'),

  /// A document is UTF-8 JSON text.
  document('document'),

  /// A document below `valid/` validates.
  valid('valid'),

  /// A document below `invalid/` does not validate.
  invalid('invalid');

  const SchemaRule(this.label);

  @override
  final String label;
}

/// The `schema` set's outcomes for [snapshot].
///
/// The schema file comes first, by [schemaPath], then every document, by its
/// path from the workspace root, ascending. When the schema file is absent,
/// is not JSON or does not compile, no document can be judged, so the schema
/// file's [Failed] is the set's only outcome. The same holds when the
/// compiled schema throws while validating a document that is JSON, as a
/// schema whose `$ref` cycles does: the schema file's [Failed] names each
/// such document with the reason, and is the set's only outcome.
List<FixtureOutcome> checkSchema(SlugSnapshot snapshot) {
  final String file = schemaPath(snapshot.slug);
  return switch (snapshot.schemaBytes) {
    null => _schemaFails(file, const <String>['absent']),
    final List<int> bytes => switch (compileSchema(bytes)) {
      SchemaProblem(:final String reason) => _schemaFails(file, <String>[
        reason,
      ]),
      CompiledSchema(:final JsonSchema schema) => _judgeAll(
        file,
        schema,
        _documentsOf(snapshot),
      ),
    },
  };
}

/// One document of the set: its [path] from the workspace root, whether it
/// lies [belowValid] (else below `invalid/`), and its bytes decoded.
typedef _Document = ({String path, bool belowValid, JsonDecoding decoding});

/// What the set makes of one document: its outcome, or the reason the
/// compiled schema could not validate it.
sealed class _Judgement {
  const _Judgement();
}

/// The document's outcome.
final class _Judged extends _Judgement {
  const _Judged(this.outcome);

  final FixtureOutcome outcome;
}

/// The compiled schema threw while validating the document at [path].
final class _ValidationThrew extends _Judgement {
  const _ValidationThrew(this.path, this.reason);

  final String path;

  /// The thrown error's message.
  final String reason;
}

/// [snapshot]'s documents, ascending by path, each decoded.
List<_Document> _documentsOf(SlugSnapshot snapshot) {
  final String directory = fixtureDirectory(snapshot.slug);
  final Map<String, List<int>> documents = snapshot.documents;
  return List<_Document>.unmodifiable(<_Document>[
    for (final String relative in documents.keys.toList()..sort())
      (
        path: '$directory$relative',
        belowValid: relative.split('/').first == 'valid',
        decoding: decodeJson(documents[relative]!),
      ),
  ]);
}

/// The schema file at [file] passed, then each of [documents] judged against
/// [schema]; or the schema file's [Failed] alone when [schema] could not
/// validate one of them.
List<FixtureOutcome> _judgeAll(
  String file,
  JsonSchema schema,
  List<_Document> documents,
) {
  final List<_Judgement> judgements = <_Judgement>[
    for (final _Document document in documents) _judge(file, schema, document),
  ];
  final List<String> threw = <String>[
    for (final _Judgement judgement in judgements)
      if (judgement case _ValidationThrew(
        :final String path,
        :final String reason,
      ))
        'cannot validate $path: $reason',
  ];
  return threw.isNotEmpty
      ? _schemaFails(file, threw)
      : List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[
          Passed(file),
          for (final _Judgement judgement in judgements)
            if (judgement case _Judged(:final FixtureOutcome outcome)) outcome,
        ]);
}

/// [document] judged against [schema], the schema at [file]: a document that
/// is not JSON fails [SchemaRule.document] without being validated.
_Judgement _judge(String file, JsonSchema schema, _Document document) =>
    switch (document.decoding) {
      NotJson(:final String reason) => _Judged(
        _failed(document.path, SchemaRule.document, reason),
      ),
      JsonValue(:final Object? value) => _validated(
        file,
        schema,
        document,
        value,
      ),
    };

/// [document]'s decoded [value] validated against [schema], the schema at
/// [file].
///
/// package:json_schema throws a `FormatException` when it detects a `$ref`
/// cycle at validation, as for `{"$ref": "#"}`, and overflows the stack on a
/// recursion its cycle check misses, as for
/// `{"anyOf": [{"type": "object"}, {"$ref": "#"}]}` and an instance that is
/// no object. Each is the schema's defect, never the document's, so it is
/// [_ValidationThrew].
_Judgement _validated(
  String file,
  JsonSchema schema,
  _Document document,
  Object? value,
) {
  final List<String> errors;
  try {
    errors = schemaErrors(schema, value);
  } on FormatException catch (error) {
    return _ValidationThrew(document.path, error.message);
  } on StackOverflowError catch (error) {
    return _ValidationThrew(document.path, '$error');
  }
  return _Judged(switch ((document.belowValid, errors.isEmpty)) {
    (true, false) => _failed(
      document.path,
      SchemaRule.valid,
      'does not validate: ${errors.join('; ')}',
    ),
    (false, true) => _failed(
      document.path,
      SchemaRule.invalid,
      'validates against $file',
    ),
    (true, true) || (false, false) => Passed(document.path),
  });
}

/// The schema file at [file] failing [SchemaRule.schemaFile] once per
/// reason, as the set's only outcome.
List<FixtureOutcome> _schemaFails(String file, List<String> reasons) =>
    List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[
      Failed(
        file,
        List<Problem>.unmodifiable(<Problem>[
          for (final String reason in reasons)
            Problem(SchemaRule.schemaFile, reason),
        ]),
      ),
    ]);

/// [path] failing [rule] for [detail].
Failed _failed(String path, SchemaRule rule, String detail) =>
    Failed(path, List<Problem>.unmodifiable(<Problem>[Problem(rule, detail)]));
