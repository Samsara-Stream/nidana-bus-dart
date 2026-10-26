/// JSON documents and draft 2020-12 schemas as the replay tool reads them:
/// bytes decoded as UTF-8 JSON, a schema compiled from its bytes, and the
/// validation errors of an instance as report text. Pure: it reads no file
/// (nidana.model D2 item 5); its callers hand it bytes.
library;

import 'dart:convert';

import 'package:json_schema/json_schema.dart';

/// Bytes read as UTF-8 JSON: a [JsonValue], or [NotJson] with the reason.
sealed class JsonDecoding {
  const JsonDecoding();
}

/// The bytes are UTF-8 JSON text that decodes to [value].
final class JsonValue extends JsonDecoding {
  const JsonValue(this.value);

  /// The decoded value: null, a bool, a num, a String, a List or a Map with
  /// String keys, as `jsonDecode` builds it.
  final Object? value;
}

/// The bytes are not UTF-8, or their text is not JSON.
final class NotJson extends JsonDecoding {
  const NotJson(this.reason);

  /// Why, as `not UTF-8: {message} (at offset {offset})` or
  /// `not JSON: {message} (at offset {offset})`.
  final String reason;
}

/// [bytes] decoded as UTF-8, malformed bytes rejected, then as JSON.
///
/// A reason never quotes the text: it is built from the exception's message
/// and offset, because `toString()` of `jsonDecode`'s exception prints the
/// source.
JsonDecoding decodeJson(List<int> bytes) {
  final String text;
  try {
    text = utf8.decode(bytes, allowMalformed: false);
  } on FormatException catch (error) {
    return NotJson(_reason('not UTF-8', error));
  }
  try {
    return JsonValue(jsonDecode(text));
  } on FormatException catch (error) {
    return NotJson(_reason('not JSON', error));
  }
}

/// A schema compiled under draft 2020-12, or [SchemaProblem] with the reason it does not compile.
sealed class SchemaCompilation {
  const SchemaCompilation();
}

/// The schema compiled under draft 2020-12.
final class CompiledSchema extends SchemaCompilation {
  const CompiledSchema(this.schema);

  /// The compiled schema, which [schemaErrors] validates against.
  final JsonSchema schema;
}

/// The schema does not compile.
final class SchemaProblem extends SchemaCompilation {
  const SchemaProblem(this.reason);

  /// Why: a [NotJson] reason, or `does not compile under draft 2020-12:
  /// {message}`.
  final String reason;
}

/// The schema in [bytes], compiled under draft 2020-12.
///
/// A schema that declares no `$schema` is read under draft 2020-12; one that
/// declares another draft is read by that draft's keywords, as
/// `JsonSchema.create` does. Only a JSON object or a boolean reaches
/// `create`: given a String, it would decode the text a second time.
/// `create` is synchronous, so no remote reference is fetched: one is a
/// reason the schema does not compile.
SchemaCompilation compileSchema(List<int> bytes) => switch (decodeJson(bytes)) {
  NotJson(:final String reason) => SchemaProblem(reason),
  JsonValue(value: final Map<String, Object?> schema) => _compile(schema),
  JsonValue(value: final bool schema) => _compile(schema),
  JsonValue() => const SchemaProblem(
    '$_doesNotCompile: a schema is a JSON object or a boolean',
  ),
};

/// Every validation error of [instance], each `{instance path, or # (root)}: {message}`, in the
/// order package:json_schema reports them; empty when [instance] validates.
List<String> schemaErrors(JsonSchema schema, Object? instance) =>
    List<String>.unmodifiable(
      schema
          .validate(instance)
          .errors
          .map((ValidationError error) => error.toString()),
    );

/// The prefix of every reason a decoded schema does not compile.
const String _doesNotCompile = 'does not compile under draft 2020-12';

/// [schema], a decoded JSON object or boolean, compiled under draft 2020-12.
SchemaCompilation _compile(Object schema) {
  try {
    return CompiledSchema(
      JsonSchema.create(schema, schemaVersion: SchemaVersion.draft2020_12),
    );
  } on FormatException catch (error) {
    return SchemaProblem('$_doesNotCompile: ${error.message}');
  } on ArgumentError catch (error) {
    return SchemaProblem('$_doesNotCompile: ${error.message}');
  }
}

/// `{what}: {message} (at offset {offset})` for [error], without the
/// parenthesis when it has no offset.
String _reason(String what, FormatException error) => switch (error.offset) {
  final int offset => '$what: ${error.message} (at offset $offset)',
  null => '$what: ${error.message}',
};
