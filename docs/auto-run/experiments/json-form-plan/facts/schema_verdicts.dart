// F3 of json-form-plan: what the replay tool's validator (package:json_schema
// 5.2.2, the one expectMatchesSchema uses) says about documents the
// governance does not settle in words. run.sh copies this file into the
// temporary workspace's packages/nidana_contract_check/tool/ and runs it from
// the workspace root, so that it resolves package:json_schema through the
// workspace.
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart' show JsonSchema;
import 'package:nidana_contract_check/src/json_document.dart';

const String fixtures = 'hsdd/contract/fixture/topology-ir';

Object? forms() =>
    jsonDecode(File('$fixtures/valid/forms.json').readAsStringSync());

Map<String, Object?> topology(Object? doc) =>
    ((doc! as Map<String, Object?>)['topologies']! as List<Object?>)[0]!
        as Map<String, Object?>;

List<Object?> transforms(Object? doc) =>
    topology(doc)['transforms']! as List<Object?>;

Map<String, Object?> edge(Object? doc, int i) =>
    transforms(doc)[i]! as Map<String, Object?>;

Map<String, Object?> claim(Object? doc) =>
    ((doc! as Map<String, Object?>)['claims']! as List<Object?>)[0]!
        as Map<String, Object?>;

Object? edited(void Function(Object? doc) edit) {
  final Object? doc = forms();
  edit(doc);
  return doc;
}

void main() {
  final JsonSchema schema = switch (compileSchema(
    File('hsdd/contract/schema/topology-ir.schema.json').readAsBytesSync(),
  )) {
    CompiledSchema(:final JsonSchema schema) => schema,
    SchemaProblem(:final String reason) => throw StateError(reason),
  };
  final Map<String, Object? Function()> cases = <String, Object? Function()>{
    'forms as it is': forms,
    'durationMicros 5000.0 (a double)': () =>
        edited((Object? d) => edge(d, 3)['durationMicros'] = 5000.0),
    'durationMicros 1e30 (a double)': () =>
        edited((Object? d) => edge(d, 3)['durationMicros'] = 1e30),
    'durationMicros 0': () =>
        edited((Object? d) => edge(d, 3)['durationMicros'] = 0),
    'edge 1.0 (a double)': () => edited(
      (Object? d) =>
          ((edge(d, 2)['inputs']! as List<Object?>)[0]!
                  as Map<String, Object?>)['edge'] =
              1.0,
    ),
    'a topic name that is empty': () => edited((Object? d) {
      final Map<String, Object?> c = claim(d);
      ((c['writes']! as List<Object?>)[0]! as Map<String, Object?>)['name'] =
          '';
    }),
    'a typeName of one space': () => edited((Object? d) {
      final Map<String, Object?> c = claim(d);
      ((c['writes']! as List<Object?>)[0]! as Map<String, Object?>)['typeName'] =
          ' ';
    }),
    'a claim listing one topic twice': () => edited((Object? d) {
      final List<Object?> w = claim(d)['writes']! as List<Object?>;
      w.add(jsonDecode(jsonEncode(w[0])));
    }),
    'two equal claims': () => edited((Object? d) {
      final List<Object?> c = (d! as Map<String, Object?>)['claims']!
          as List<Object?>;
      c.add(jsonDecode(jsonEncode(c[0])));
    }),
    'a claim source "service:a:b"': () =>
        edited((Object? d) => claim(d)['source'] = 'service:a:b'),
    'a claim source "service:"': () =>
        edited((Object? d) => claim(d)['source'] = 'service:'),
    'a claim source "Service:x"': () =>
        edited((Object? d) => claim(d)['source'] = 'Service:x'),
    'a dedup on a replay read': () => edited((Object? d) {
      final Map<String, Object?> input =
          (edge(d, 0)['inputs']! as List<Object?>)[0]! as Map<String, Object?>;
      (input['topic']! as Map<String, Object?>)['variant'] = 'replay';
      input['dedup'] = 'none';
    }),
    'a reduceInto whose combinator is absent (a write with a transformer)':
        () => edited((Object? d) => edge(d, 5).remove('combinator')),
    'a write with "combinator": null': () =>
        edited((Object? d) => edge(d, 4)['combinator'] = null),
    'a topologyId of one space': () =>
        edited((Object? d) => topology(d)['topologyId'] = ' '),
    'an input edge index beyond the transforms': () => edited(
      (Object? d) =>
          ((edge(d, 2)['inputs']! as List<Object?>)[0]!
                  as Map<String, Object?>)['edge'] =
              99,
    ),
  };
  for (final MapEntry<String, Object? Function()> c in cases.entries) {
    final List<String> errors = schemaErrors(schema, c.value());
    print(
      '${errors.isEmpty ? 'VALID  ' : 'INVALID'} ${c.key}'
      '${errors.isEmpty ? '' : ': ${errors.first}'}',
    );
  }
}
