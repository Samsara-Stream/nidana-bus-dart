// packages/nidana_contract_check/test/dart_library_test.dart
import 'package:nidana_contract_check/src/dart_library.dart';
import 'package:nidana_contract_check/src/dart_scanner.dart';
import 'package:test/test.dart';

const List<String> rejectLines = <String>[
  '// Reject fixture for sample@v1 G1: the sample type is closed.', // 1
  '// covers: G1, G2', // 2
  "import 'package:sample/sample.dart';", // 3
  '', // 4
  '// expect-diagnostic: invalid_use_of_type_outside_library', // 5
  'final class Local extends Sample {}', // 6
  '', // 7
  'void f(Sample s) {', // 8
  '  // expect-diagnostic: undefined_method', // 9
  '  s.publish(); // expect-diagnostic: trailing', // 10
  '// expect-diagnostic: Bad_Code', // 11
  'int x = 1;', // 12
  '// expect-diagnostic: unused_local', // 13
  '', // 14
  '// covers: G3', // 15
  '}', // 16
  '// expect-diagnostic: at_the_end', // 17
];

const String conformance = r"""
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart' show ConformanceCase;
import 'package:sample/sample.dart' as s;

abstract interface class SampleHarness {
  Future<void> settle();
}

const s.Topic _t = s.Topic(name: 'G8 a top-level topic, not a case');

final List<ConformanceCase<SampleHarness>> sampleConformance =
    <ConformanceCase<SampleHarness>>[
  // name: 'G9 a commented-out case'
  (
    name: 'G1 reads http://example.com/a ) ] } and \'quotes\'',
    body: (SampleHarness h) async {
      const s.Topic t = s.Topic(name: 'G9 a topic inside a body');
      expect('${t.name} } ]', isNotEmpty);
    },
  ),
  (
    body: (SampleHarness h) async {},
    name: 'G2 adjacent ' "strings",
  ),
  (name: 'G3 interpolates $x', body: (SampleHarness h) async {}),
  (name: r'G4 raw \n', body: (SampleHarness h) async {}),
  (name: '''G5 triple''', body: (SampleHarness h) async {}),
  ...otherCases,
  (body: (SampleHarness h) async {}),
];

final List<ConformanceCase<SampleHarness>> _privateCases = <ConformanceCase<SampleHarness>>[
  (name: 'G7 private', body: (SampleHarness h) async {}),
];
""";

void expectConformance(DartLibrary d) {
  expect(d.caseLists.map((CaseList l) => l.name), <String>[
    'sampleConformance',
  ]);
  final CaseList l = d.caseLists.single;
  expect(l.cases.map((CaseName c) => c.name), <String?>[
    "G1 reads http://example.com/a ) ] } and 'quotes'",
    'G2 adjacent strings',
    null,
    r'G4 raw \n',
    'G5 triple',
  ]);
  expect(l.cases.first.line, 15);
  expect(l.problems, hasLength(2));
  expect(
    l.problems[0],
    allOf(
      startsWith('line 28: '),
      endsWith('an element of sampleConformance is not a record literal'),
    ),
  );
  expect(
    l.problems[1],
    allOf(
      startsWith('line 29: '),
      endsWith('a record of sampleConformance has no name field'),
    ),
  );
}

void main() {
  test('scanDart skips comments and keeps strings whole', () {
    final List<Token> t = scanDart(r"""a // b 'c'
'x//y' /* /* n */ */ r'\n' "${'}'}" b2""");
    expect(t.map((Token x) => x.kind), <TokenKind>[
      TokenKind.identifier,
      TokenKind.string,
      TokenKind.string,
      TokenKind.string,
      TokenKind.identifier,
    ]);
    expect(t.map((Token x) => x.value), <String?>[
      null,
      'x//y',
      r'\n',
      null,
      null,
    ]);
    expect(t.map((Token x) => x.line), <int>[1, 2, 2, 2, 2]);
  });
  test('directives: import and export URIs in order, prefixes and combinators ignored', () {
    final DartLibrary d = readDartLibrary(r"""
// covers: G1
library;

import 'package:a/a.dart' as a show B;
export 'package:b/src/c.dart';
import "../../x/behavior/y_conformance.dart";

void f() { final String s = 'import'; }
""");
    expect(d.directives, <String>[
      'package:a/a.dart',
      'package:b/src/c.dart',
      '../../x/behavior/y_conformance.dart',
    ]);
  });
  test('the covers header is read from the leading comment block only', () {
    final DartLibrary d = readDartLibrary(rejectLines.join('\n'));
    expect(
      d.coversHeaders.map((CoversHeader h) => (h.line, h.text)),
      <(int, String)>[(2, 'G1, G2')],
    );
    expect(d.coversHeaders.single.ids, <int>{1, 2});
  });
  test('markers: code on its own line, and what follows it', () {
    final DartLibrary d = readDartLibrary(rejectLines.join('\n'));
    expect(
      d.markers.map((Marker m) => (m.line, m.code, m.followedByCode)),
      <(int, String?, bool)>[
        (5, 'invalid_use_of_type_outside_library', true),
        (9, 'undefined_method', true),
        (10, null, false),
        (11, null, true),
        (13, 'unused_local', false),
        (17, 'at_the_end', false),
      ],
    );
  });
  test('case names are the name fields of the exported list, nothing else', () {
    expectConformance(readDartLibrary(conformance));
  });
  test('CRLF sources read as LF sources', () {
    expectConformance(readDartLibrary(conformance.replaceAll('\n', '\r\n')));
    final DartLibrary d = readDartLibrary(rejectLines.join('\r\n'));
    expect(d.coversHeaders.single.ids, <int>{1, 2});
    expect(d.markers.map((Marker m) => m.code), <String?>[
      'invalid_use_of_type_outside_library',
      'undefined_method',
      null,
      null,
      'unused_local',
      'at_the_end',
    ]);
  });
  test(
    'the typed-literal form is a case list; a list from elsewhere is a problem',
    () {
      final DartLibrary d = readDartLibrary(r"""
final sampleConformance = <ConformanceCase<H>>[
  (name: 'G1 inferred', body: (H h) async {}),
];
final List<ConformanceCase<H>> fromElsewhere = otherCases;
""");
      expect(d.caseLists.map((CaseList l) => l.name), <String>[
        'sampleConformance',
        'fromElsewhere',
      ]);
      expect(d.caseLists[0].cases.map((CaseName c) => c.name), <String>[
        'G1 inferred',
      ]);
      expect(d.caseLists[1].problems, <String>[
        'fromElsewhere is not initialized by a list literal',
      ]);
    },
  );
}
