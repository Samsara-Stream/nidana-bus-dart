import 'package:json_schema/json_schema.dart';
import 'package:matcher/expect.dart';

typedef ConformanceCase<H> = ({String name, Future<void> Function(H harness) body});

void expectMatchesSchema(Object? json, String schemaSource) {
  final schema = JsonSchema.create(schemaSource);
  expect(schema.validate(json).isValid, isTrue);
}
