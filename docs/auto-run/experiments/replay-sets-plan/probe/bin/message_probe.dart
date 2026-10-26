// Exact messages the plan's tests pin (question M1): json_schema errors for
// type, minimum, additionalProperties and required; dart:convert's
// FormatException for invalid UTF-8 and for text that is not JSON.
import 'dart:convert';

import 'package:json_schema/json_schema.dart';

void main() {
  final JsonSchema s = JsonSchema.create(<String, Object?>{
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'type': 'object',
    'properties': <String, Object?>{
      'name': <String, Object?>{'type': 'string'},
      'count': <String, Object?>{'type': 'integer', 'minimum': 0},
    },
    'required': <String>['name', 'count'],
    'additionalProperties': false,
  }, schemaVersion: SchemaVersion.draft2020_12);
  for (final Object? instance in <Object?>[
    <String, Object?>{'name': 'a', 'count': 1},
    <String, Object?>{'name': 1, 'count': -1, 'extra': true},
    <String, Object?>{'count': 1},
    <Object?>[],
  ]) {
    final ValidationResults r = s.validate(instance);
    print('${jsonEncode(instance)}: valid ${r.isValid}');
    for (final ValidationError e in r.errors) print('  $e');
  }
  for (final List<int> bytes in <List<int>>[<int>[0xff], <int>[0x7b, 0xc3], <int>[0x7b, 0xff, 0x7d]]) {
    try {
      utf8.decode(bytes);
    } on FormatException catch (e) {
      print('utf8.decode($bytes): message "${e.message}" offset ${e.offset} toString "$e"');
    }
  }
  for (final String text in <String>['', '{', '{"a": 1,}', 'nul', 'notes\n', '\uFEFF{}']) {
    try {
      jsonDecode(text);
    } on FormatException catch (e) {
      print('jsonDecode(${jsonEncode(text)}): message "${e.message}" offset ${e.offset}');
    }
  }
  try {
    JsonSchema.create(<String, Object?>{'type': 5}, schemaVersion: SchemaVersion.draft2020_12);
  } on FormatException catch (e) {
    print('create type 5: message "${e.message}"');
  }
  try {
    JsonSchema.create(<Object?>[1], schemaVersion: SchemaVersion.draft2020_12);
  } on ArgumentError catch (e) {
    print('create [1]: ArgumentError message "${e.message}"');
  }
  print('create true (a boolean schema): ${JsonSchema.create(true, schemaVersion: SchemaVersion.draft2020_12).validate(1).isValid}');
}
