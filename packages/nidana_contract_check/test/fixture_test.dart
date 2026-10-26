// packages/nidana_contract_check/test/fixture_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_contract_check/src/json_document.dart';
import 'package:test/test.dart';

import 'support/sample.dart';
import 'support/seed.dart';

const String schemaPath = 'hsdd/contract/schema/doc.schema.json';

/// Runs [body] with [directory] as the working directory.
T inDirectory<T>(Directory directory, T Function() body) =>
    IOOverrides.runZoned(body, getCurrentDirectory: () => directory);

/// Throws the [TestFailure] `expect` throws, its message exactly [lines].
Matcher failsWith(List<String> lines) => throwsA(
  isA<TestFailure>().having(
    (TestFailure f) => f.message,
    'message',
    lines.join('\n'),
  ),
);

/// Throws a [StateError] whose message contains [text].
Matcher errsWith(String text) => throwsA(
  isA<StateError>().having(
    (StateError e) => e.message,
    'message',
    contains(text),
  ),
);

void main() {
  test('ConformanceCase is the record of ADR-001 item 4', () async {
    final List<String> ran = <String>[];
    final ConformanceCase<List<String>> c = (
      name: 'G1 a case',
      body: (List<String> harness) async {
        harness.add('ran');
      },
    );
    await c.body(ran);
    expect(c.name, 'G1 a case');
    expect(ran, <String>['ran']);
  });
  group('expectMatchesSchema', () {
    test('a valid instance passes', () {
      inDirectory(
        seed(docFiles),
        () => expectMatchesSchema(<String, Object?>{
          'name': 'a',
          'count': 0,
        }, schemaPath),
      );
    });
    test('an invalid instance fails as expect does, listing every validation error', () {
      final Directory root = seed(docFiles);
      expect(
        () => inDirectory(
          root,
          () => expectMatchesSchema(<String, Object?>{
            'name': 1,
            'count': -1,
            'extra': true,
          }, schemaPath),
        ),
        failsWith(<String>[
          'does not match hsdd/contract/schema/doc.schema.json:',
          '  /name: type: wanted [string] got 1',
          '  /count: minimum violated (-1 < 0)',
          '  # (root): unallowed additional property extra',
        ]),
      );
    });
    test('the path is relative to the nearest ancestor of the working directory that holds hsdd/contract/', () {
      final Directory root = seed(<String, String>{
        ...docFiles,
        'packages/member/lib/member.dart': '\n',
      });
      final Directory member = Directory('${root.path}/packages/member');
      inDirectory(
        member,
        () => expectMatchesSchema(<String, Object?>{
          'name': 'a',
          'count': 0,
        }, schemaPath),
      );
      expect(
        () => inDirectory(
          member,
          () => expectMatchesSchema(<Object?>[], schemaPath),
        ),
        failsWith(<String>[
          'does not match $schemaPath:',
          '  # (root): type: wanted [object] got []',
        ]),
      );
    });
    test('no workspace root, an absent schema and a schema that does not compile are errors', () {
      expect(
        () => inDirectory(
          seed(const <String, String>{'readme.txt': 'x\n'}),
          () => expectMatchesSchema(1, schemaPath),
        ),
        errsWith('holds hsdd/contract/'),
      );
      expect(
        () => inDirectory(
          seed(docFiles),
          () =>
              expectMatchesSchema(1, 'hsdd/contract/schema/nosuch.schema.json'),
        ),
        errsWith('no schema at hsdd/contract/schema/nosuch.schema.json'),
      );
      expect(
        () => inDirectory(
          seed(<String, String>{schemaPath: '{"type": 5}'}),
          () => expectMatchesSchema(1, schemaPath),
        ),
        errsWith(
          '$schemaPath: does not compile under draft 2020-12: type must be string or array: int',
        ),
      );
    });
    test('the errors name the working directory, the workspace root and why the schema is unreadable', () {
      final Directory outside = seed(const <String, String>{
        'readme.txt': 'x\n',
      });
      expect(
        () => inDirectory(outside, () => expectMatchesSchema(1, schemaPath)),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            'no ancestor of ${outside.path} holds hsdd/contract/',
          ),
        ),
      );
      final Directory root = seed(docFiles);
      expect(
        () => inDirectory(
          root,
          () => expectMatchesSchema(1, 'hsdd/contract/schema'),
        ),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            'no schema at hsdd/contract/schema under ${root.path}',
          ),
        ),
      );
      expect(
        () => inDirectory(
          seed(<String, String>{schemaPath: '{"type":'}),
          () => expectMatchesSchema(1, schemaPath),
        ),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            '$schemaPath: not JSON: Unexpected end of input (at offset 8)',
          ),
        ),
      );
    });
    test('the schema is read on every call, never cached', () {
      final Directory root = seed(docFiles);
      inDirectory(
        root,
        () => expectMatchesSchema(<String, Object?>{
          'name': 'a',
          'count': 0,
        }, schemaPath),
      );
      File('${root.path}/$schemaPath').writeAsStringSync('{"type": "string"}');
      expect(
        () => inDirectory(
          root,
          () => expectMatchesSchema(<String, Object?>{
            'name': 'a',
            'count': 0,
          }, schemaPath),
        ),
        failsWith(<String>[
          'does not match $schemaPath:',
          '  # (root): type: wanted [string] got {name: a, count: 0}',
        ]),
      );
    });
  });
  group('json_document', () {
    test('decodeJson reads UTF-8 JSON and names what is neither', () {
      expect(
        (decodeJson(utf8.encode('{"a": [1]}')) as JsonValue).value,
        <String, Object?>{
          'a': <Object?>[1],
        },
      );
      expect(
        (decodeJson(<int>[0x7b, 0xff, 0x7d]) as NotJson).reason,
        'not UTF-8: Invalid UTF-8 byte (at offset 1)',
      );
      expect(
        (decodeJson(<int>[]) as NotJson).reason,
        'not JSON: Unexpected end of input (at offset 0)',
      );
      expect(
        (decodeJson(utf8.encode('notes\n')) as NotJson).reason,
        'not JSON: Unexpected character (at offset 0)',
      );
    });
    test('decodeJson rejects a truncated sequence, drops a leading byte order mark as utf8.decode does, and decodes a bare null', () {
      expect(
        (decodeJson(<int>[0x7b, 0xc3]) as NotJson).reason,
        'not UTF-8: Unfinished UTF-8 octet sequence (at offset 2)',
      );
      expect(
        (decodeJson(<int>[0xef, 0xbb, 0xbf, 0x7b, 0x7d]) as JsonValue).value,
        <String, Object?>{},
      );
      expect(
        (decodeJson(<int>[0x5b, 0xef, 0xbb, 0xbf, 0x5d]) as NotJson).reason,
        'not JSON: Unexpected character (at offset 1)',
      );
      expect(
        decodeJson(utf8.encode('null')),
        isA<JsonValue>().having((JsonValue v) => v.value, 'value', isNull),
      );
    });
    test('compileSchema compiles under draft 2020-12 or names why not', () {
      expect(compileSchema(utf8.encode(docSchema)), isA<CompiledSchema>());
      expect(
        (compileSchema(utf8.encode('{')) as SchemaProblem).reason,
        'not JSON: Unexpected end of input (at offset 1)',
      );
      expect(
        (compileSchema(utf8.encode('{"type": 5}')) as SchemaProblem).reason,
        'does not compile under draft 2020-12: type must be string or array: int',
      );
      for (final String text in <String>['[1]', 'null', '"text"']) {
        expect(
          (compileSchema(utf8.encode(text)) as SchemaProblem).reason,
          'does not compile under draft 2020-12: a schema is a JSON object or a boolean',
          reason: text,
        );
      }
    });
    test('compileSchema passes a NotJson reason through and compiles a boolean schema', () {
      expect(
        (compileSchema(<int>[0xff]) as SchemaProblem).reason,
        'not UTF-8: Invalid UTF-8 byte (at offset 0)',
      );
      final CompiledSchema accepting =
          compileSchema(utf8.encode('true')) as CompiledSchema;
      final CompiledSchema refusing =
          compileSchema(utf8.encode('false')) as CompiledSchema;
      expect(
        schemaErrors(accepting.schema, <String, Object?>{'any': 1}),
        isEmpty,
      );
      expect(
        schemaErrors(refusing.schema, <String, Object?>{'any': 1}),
        isNotEmpty,
      );
    });
    test('compileSchema fetches no remote reference: one is a reason the schema does not compile', () {
      expect(
        (compileSchema(
          utf8.encode(
            '{"\$ref": "https://example.invalid/remote.schema.json"}',
          ),
        ) as SchemaProblem).reason,
        'does not compile under draft 2020-12: When resolving schemas synchronously, all remote refs must be '
        'resolvable via a RefProvider. Found 1 unresolvable request(s): https://example.invalid/remote.schema.json',
      );
    });
    test(
      'compileSchema reads a schema without \$schema under draft 2020-12',
      () {
        final CompiledSchema compiled = compileSchema(
          utf8.encode('{"prefixItems": [{"type": "string"}]}'),
        ) as CompiledSchema;
        expect(schemaErrors(compiled.schema, <Object?>['a']), isEmpty);
        expect(schemaErrors(compiled.schema, <Object?>[1]), <String>[
          '/0: type: wanted [string] got 1',
        ]);
      },
    );
    test('schemaErrors lists every error in order, and nothing for a valid instance', () {
      final CompiledSchema compiled =
          compileSchema(utf8.encode(docSchema)) as CompiledSchema;
      expect(
        schemaErrors(compiled.schema, <String, Object?>{
          'name': 'a',
          'count': 0,
        }),
        isEmpty,
      );
      expect(
        schemaErrors(compiled.schema, <String, Object?>{'count': 1}),
        <String>[
          '# (root): required prop missing: name from {count: 1}',
          '/name: required prop missing: name from {count: 1}',
        ],
      );
    });
  });
}
