// packages/nidana_contract_check/test/schema_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/run.dart';
import 'package:nidana_contract_check/src/schema.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String d = 'hsdd/contract/fixture/doc/';
const String schemaFile = 'hsdd/contract/schema/doc.schema.json';

List<FixtureOutcome> check(
  Map<String, String?> changes, {
  Map<String, List<int>> bytes = const <String, List<int>>{},
}) => checkSchema(snapshotOf('doc', changed(docFiles, changes), bytes: bytes));

/// The problems at [path] as 'rule (detail)'; empty when it passed or has no outcome.
List<String> at(List<FixtureOutcome> outcomes, String path) => <String>[
  for (final FixtureOutcome o in outcomes)
    if (o is Failed && o.path == path)
      for (final Problem p in o.problems) '${p.rule.label} (${p.detail})',
];

void main() {
  test(
    'the clean doc slug passes: the schema file, then each document by path',
    () {
      final List<FixtureOutcome> o = check(const <String, String?>{});
      expect(o.map((FixtureOutcome x) => x.path), <String>[
        schemaFile,
        '${d}invalid/extra-property.json',
        '${d}invalid/negative-count.json',
        '${d}valid/minimal.json',
      ]);
      expect(o, everyElement(isA<Passed>()));
    },
  );
  test('a valid/ document that does not validate lists every error', () {
    expect(
      at(
        check(<String, String?>{
          '${d}valid/minimal.json': '{"name": 1, "count": -1, "extra": true}',
        }),
        '${d}valid/minimal.json',
      ),
      <String>[
        'valid (does not validate: /name: type: wanted [string] got 1; /count: minimum violated (-1 < 0); # (root): unallowed additional property extra)',
      ],
    );
  });
  test('an invalid/ document that validates', () {
    expect(
      at(
        check(<String, String?>{
          '${d}invalid/negative-count.json': '{"name": "a", "count": 1}',
        }),
        '${d}invalid/negative-count.json',
      ),
      <String>[
        'invalid (validates against hsdd/contract/schema/doc.schema.json)',
      ],
    );
  });
  test(
    'an empty, non-JSON or non-UTF-8 document is a defect of that document',
    () {
      final List<FixtureOutcome> o = check(
        <String, String?>{
          '${d}valid/empty.json': '',
          '${d}valid/notes.md': 'notes\n',
        },
        bytes: <String, List<int>>{
          '${d}invalid/latin1.json': <int>[0x7b, 0xff, 0x7d],
        },
      );
      expect(at(o, '${d}valid/empty.json'), <String>[
        'document (not JSON: Unexpected end of input (at offset 0))',
      ]);
      expect(at(o, '${d}valid/notes.md'), <String>[
        'document (not JSON: Unexpected character (at offset 0))',
      ]);
      expect(at(o, '${d}invalid/latin1.json'), <String>[
        'document (not UTF-8: Invalid UTF-8 byte (at offset 1))',
      ]);
    },
  );
  test('every file below valid/ and invalid/ is a document, nested ones included, and nothing else is', () {
    final List<FixtureOutcome> o = check(<String, String?>{
      '${d}valid/nested/deep.json': '{"name": "b", "count": 2}',
    });
    expect(
      o.map((FixtureOutcome x) => x.path),
      contains('${d}valid/nested/deep.json'),
    );
    expect(o, everyElement(isA<Passed>()));
    for (final String path in <String>[
      'valid/a.json',
      'invalid/x/y.json',
      'valid/notes.md',
    ]) {
      expect(holdsDocument(path), isTrue, reason: path);
    }
    for (final String path in <String>[
      'expected/topics.g.dart',
      'input/topics.yaml',
      'render/checkout.mmd',
      'rejected/two-documents.yaml',
      'surface/use.dart',
      'validx/a.json',
    ]) {
      expect(holdsDocument(path), isFalse, reason: path);
    }
  });
  test('without the schema file the slug keeps the set, which fails at the schema path alone', () {
    final Map<String, String> files = changed(docFiles, <String, String?>{
      schemaFile: null,
    });
    expect(setsOf(snapshotOf('doc', files)), contains(CheckSet.schema));
    final List<FixtureOutcome> o = checkSchema(snapshotOf('doc', files));
    expect(o.map((FixtureOutcome x) => x.path), <String>[schemaFile]);
    expect(at(o, schemaFile), <String>['schema-file (absent)']);
  });
  test('a schema that is not JSON or does not compile fails alone', () {
    final List<FixtureOutcome> notJson = check(<String, String?>{
      schemaFile: '{',
    });
    expect(notJson.map((FixtureOutcome x) => x.path), <String>[schemaFile]);
    expect(at(notJson, schemaFile), <String>[
      'schema-file (not JSON: Unexpected end of input (at offset 1))',
    ]);
    expect(
      at(check(<String, String?>{schemaFile: '{"type": 5}'}), schemaFile),
      <String>[
        'schema-file (does not compile under draft 2020-12: type must be string or array: int)',
      ],
    );
  });

  // Beyond the brief: rules that would otherwise go unpinned.
  test('a file named valid or invalid directly under the fixture directory is no document', () {
    for (final String path in <String>['valid', 'invalid']) {
      expect(holdsDocument(path), isFalse, reason: path);
    }
  });
  test('a schema that compiles but cycles at validation fails alone, naming each document it cannot validate', () {
    final List<FixtureOutcome> o = check(<String, String?>{
      schemaFile: r'{"$ref": "#"}',
    });
    expect(o.map((FixtureOutcome x) => x.path), <String>[schemaFile]);
    expect(at(o, schemaFile), <String>[
      'schema-file (cannot validate ${d}invalid/extra-property.json: Cycle detected at path: "#")',
      'schema-file (cannot validate ${d}invalid/negative-count.json: Cycle detected at path: "#")',
      'schema-file (cannot validate ${d}valid/minimal.json: Cycle detected at path: "#")',
    ]);
  });
  test('a schema whose validation recurses without bound fails alone, and a document it validates is not named', () {
    final List<FixtureOutcome> o = check(<String, String?>{
      schemaFile: r'{"anyOf": [{"type": "object"}, {"$ref": "#"}]}',
      '${d}valid/minimal.json': '"a string"',
    });
    expect(o.map((FixtureOutcome x) => x.path), <String>[schemaFile]);
    expect(at(o, schemaFile), <String>[
      'schema-file (cannot validate ${d}valid/minimal.json: Stack Overflow)',
    ]);
  });
  test('a document that is not JSON is not validated, so it never reaches a schema that cannot validate it', () {
    final List<FixtureOutcome> o = check(<String, String?>{
      schemaFile: r'{"$ref": "#"}',
      '${d}invalid/extra-property.json': null,
      '${d}invalid/negative-count.json': null,
      '${d}valid/minimal.json': 'not json',
    });
    expect(o.map((FixtureOutcome x) => x.path), <String>[
      schemaFile,
      '${d}valid/minimal.json',
    ]);
    expect(o.first, isA<Passed>());
    expect(at(o, '${d}valid/minimal.json'), <String>[
      'document (not JSON: Unexpected character (at offset 0))',
    ]);
  });
}
