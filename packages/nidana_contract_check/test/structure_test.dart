// packages/nidana_contract_check/test/structure_test.dart
import 'dart:convert';

import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/structure.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String t = 'hsdd/contract/fixture/tool/';

List<FixtureOutcome> check(
  Map<String, String?> changes, {
  String slug = 'sample',
  Map<String, String> base = sampleFiles,
}) => checkStructure(snapshotOf(slug, changed(base, changes)));

/// The problems at [path] as 'rule (detail)'; empty when it passed or has no outcome.
List<String> at(List<FixtureOutcome> outcomes, String path) => <String>[
  for (final FixtureOutcome o in outcomes)
    if (o is Failed && o.path == path)
      for (final Problem p in o.problems) '${p.rule.label} (${p.detail})',
];

String contractWith(String from, String to) =>
    sampleContract.replaceFirst(from, to);

String toolContractWith(String from, String to) =>
    toolFiles['hsdd/contract/tool.md']!.replaceFirst(from, to);

String conformanceWith(String from, String to) =>
    sampleFiles['${s}behavior/sample_conformance.dart']!.replaceFirst(from, to);

/// A `tool` contract text with every problem the contract text can have. Its
/// lines run in another order than the checks, so only the order of the
/// checks gives the order of the problems.
const String toolContractWithEveryProblem = r'''
---
id: other
version: v1
status: stable
kind: widget
---

# tool@v1

## Guarantees / invariants

- **G1** generate writes the expected tree.
- **G2** generate exits 2 on an unknown option.
- **G2** again.
- G3 without its bold id.

## Validation

- not executable: G2, an option no case passes
- not executable: the rest; checked by nidana.model's gates
- not executable: G8, a property of the pubspec; checked by nidana.model's gates
- not executable: G7's last clause, on a value no case builds; checked by nidana.model's gates
- binding: `hsdd/contract/fixture/other/behavior/other_test.dart` binds another slug's suite.
- schema: `hsdd/contract/schema/tool.schema.json`, the data model; covers G1.
- schema: a bullet that covers G2, then wraps
- file: `hsdd/contract/fixture/tool/input/` holds `in.txt`. The file set covers the tree.

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `generate-usage` | `tool:generate --frob` | 2 | two |
| generate-help | `tool:generate --help` | 0 | G1: a row without its backticks |
''';

/// A `reject/` library with a malformed header and malformed markers only.
const String rejectWithMalformedHeader = r'''
// covers: the closed family
import 'package:sample/src/sample_base.dart';

// expect-diagnostic: Bad_Code
final class Local extends Sample {}
''';

/// A `reject/` library whose markers break the rules in line order 4, 5, 7,
/// which is not the order of the checks.
const String rejectWithMalformedMarkers = r'''
// covers: G1, G7
import 'package:sample/src/sample_base.dart';

// expect-diagnostic: unused_import
// expect-diagnostic: Bad_Code
final class Local extends Sample {}
// expect-diagnostic: unused_local
''';

/// A conformance library with every case-name problem, in another line order
/// than the order of the checks.
const String conformanceWithEveryProblem = r'''
import 'package:sample/src/sample_base.dart';

final List<ConformanceCase<SampleHarness>> sampleConformance =
    <ConformanceCase<SampleHarness>>[
  (name: 'G2 a sample value round-trips', body: run),
  (name: 'g3 a sample value is redacted', body: run),
  (name: 'G3 ${topic.name}', body: run),
  otherCases,
  (body: run),
  (name: 'G7 an undeclared id', body: run),
  (name: 'G8 another undeclared id', body: run),
];

final List<ConformanceCase<SampleHarness>> moreCases =
    <ConformanceCase<SampleHarness>>[];
''';

void main() {
  test('the sample passes: one outcome per subject, in order', () {
    final List<FixtureOutcome> o = check(const <String, String?>{});
    expect(o.map((FixtureOutcome x) => x.path), <String>[
      'hsdd/contract/sample.md',
      s,
      '${s}behavior/sample_conformance.dart',
      '${s}behavior/sample_impl_test.dart',
      '${s}reject/sample_is_closed.dart',
      '${s}surface/use.dart',
    ]);
    expect(o, everyElement(isA<Passed>()));
  });
  test('the tool sample passes', () {
    final List<FixtureOutcome> o = check(
      const <String, String?>{},
      slug: 'tool',
      base: toolFiles,
    );
    expect(o.map((FixtureOutcome x) => x.path), <String>[
      'hsdd/contract/tool.md',
      t,
    ]);
    expect(o, everyElement(isA<Passed>()));
  });
  test('a source at a path holdsSource rejects is no Dart library', () {
    final SlugSnapshot clean = snapshotOf('sample', sampleFiles);
    final List<FixtureOutcome> o = checkStructure(
      SlugSnapshot(
        slug: clean.slug,
        contractText: clean.contractText,
        schemaBytes: clean.schemaBytes,
        directories: <String>{...clean.directories, 'valid'},
        files: <String, String?>{
          ...clean.files,
          'valid/a.json': '{}',
          'valid/gen.dart': 'void main() {}\n',
        },
        documents: clean.documents,
      ),
    );
    expect(o.map((FixtureOutcome x) => x.path), <String>[
      'hsdd/contract/sample.md',
      s,
      '${s}behavior/sample_conformance.dart',
      '${s}behavior/sample_impl_test.dart',
      '${s}reject/sample_is_closed.dart',
      '${s}surface/use.dart',
    ]);
    expect(o, everyElement(isA<Passed>()));
  });
  group('layout', () {
    test('an unlisted directory or file', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}extra/a.txt': 'a',
        '${s}notes.txt': 'n',
      });
      expect(at(o, '${s}extra/'), <String>[
        'layout (extra is neither a set directory of kind api nor a data directory listed in ## Validation)',
      ]);
      expect(at(o, '${s}notes.txt'), <String>[
        'layout (notes.txt is neither a set directory of kind api nor a data directory listed in ## Validation)',
      ]);
    });
    test('a listed data directory that is absent', () {
      expect(
        at(
          check(<String, String?>{'${s}goldens/sample.txt': null}),
          '${s}goldens/',
        ),
        <String>['layout (listed in ## Validation, absent)'],
      );
    });
    test('a listed set directory that is absent', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}surface/use.dart': null,
      });
      expect(at(o, '${s}surface/'), <String>[
        'layout (listed in ## Validation, absent)',
      ]);
      expect(at(o, 'hsdd/contract/sample.md'), isEmpty);
      expect(at(o, s), isEmpty);
    });
    test('a shared-model contract has no valid/ directory', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': contractWith(
          'kind: api',
          'kind: shared-model',
        ),
        '${s}valid/a.json': '{}',
      });
      expect(at(o, '${s}valid/'), <String>[
        'layout (valid is neither a set directory of kind shared-model nor a data directory listed in ## Validation)',
      ]);
    });
  });
  group('headers and markers', () {
    test('a reject file without a covers header', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}reject/sample_is_closed.dart': sampleReject.replaceFirst(
          '// covers: G1\n',
          '',
        ),
      });
      expect(at(o, '${s}reject/sample_is_closed.dart'), <String>[
        'covers-header (no // covers: header)',
      ]);
      expect(at(o, s), <String>['coverage (G1 uncovered)']);
    });
    test('a malformed or repeated covers header', () {
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart': sampleReject.replaceFirst(
              'G1\n',
              'the closed family\n',
            ),
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>['covers-header (malformed // covers: the closed family)'],
      );
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart': '// covers: G2\n$sampleReject',
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>['covers-header (more than one // covers: header)'],
      );
    });
    test('a covers header that names an undeclared id', () {
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart': sampleReject.replaceFirst(
              'G1\n',
              'G1, G7\n',
            ),
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>['unknown-id (G7 is not a guarantee of sample)'],
      );
    });
    test('no marker, a malformed marker, a marker with no code after it', () {
      const String noMarker =
          '// covers: G1\nfinal class Local extends Sample {}\n';
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart': noMarker,
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>['marker (no // expect-diagnostic: marker)'],
      );
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart':
                '$sampleReject// expect-diagnostic: Bad_Code\nint x = 1;\n',
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>[
          'marker (line 7: not a marker of the form // expect-diagnostic: {code})',
        ],
      );
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart':
                '$sampleReject// expect-diagnostic: unused_local\n',
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>['marker (line 7: not followed by a line of code)'],
      );
    });
  });
  group('coverage and case names', () {
    test('a guarantee nothing covers', () {
      expect(
        at(
          check(<String, String?>{
            'hsdd/contract/sample.md': contractWith(
              '- **G4**',
              '- **G5** uncovered.\n- **G4**',
            ),
          }),
          s,
        ),
        <String>['coverage (G5 uncovered)'],
      );
    });
    test('a case name that does not begin with its id', () {
      final String conformance =
          sampleFiles['${s}behavior/sample_conformance.dart']!;
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformance.replaceFirst(
          "'G2 a",
          "'g2 a",
        ),
      });
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
        'case-name (line 12: case name does not begin with G{n} and a space: g2 a sample value round-trips)',
      ]);
      expect(at(o, s), <String>['coverage (G2 uncovered)']);
    });
    test('a conformance library without one public case list', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart':
            'abstract interface class SampleHarness {}\n',
      });
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
        'case-name (0 public List<ConformanceCase> declarations, expected one)',
      ]);
      expect(at(o, s), <String>['coverage (G2, G3 uncovered)']);
    });
  });
  group('bindings and imports', () {
    test('a listed binding that is absent, a binding that is not listed', () {
      expect(
        at(
          check(<String, String?>{'${s}behavior/sample_impl_test.dart': null}),
          '${s}behavior/sample_impl_test.dart',
        ),
        <String>['binding (listed in ## Validation, absent)'],
      );
      expect(
        at(
          check(<String, String?>{
            '${s}behavior/extra_test.dart': 'void main() {}\n',
          }),
          '${s}behavior/extra_test.dart',
        ),
        <String>['binding (not listed in ## Validation)'],
      );
    });
    test('isBindingPath accepts behavior/{name}_test.dart directly under behavior/ alone', () {
      for (final String path in <String>[
        'behavior/sample_impl_test.dart',
        'behavior/a_test.dart',
      ]) {
        expect(isBindingPath(path), isTrue, reason: path);
      }
      for (final String path in <String>[
        'behavior/nested/sample_impl_test.dart',
        'behavior/sample_impl_test.json',
        'behavior/sample_impl_test.dart.orig',
        'behavior/_test.dart',
        'behavior/sample_impl_tests.dart',
        'behavior/sample_impltest.dart',
        'behavior/sample_conformance.dart',
        'surface/sample_impl_test.dart',
        'sample_impl_test.dart',
      ]) {
        expect(isBindingPath(path), isFalse, reason: path);
      }
    });
    test('holdsRecord accepts a recorded invocation\'s four files and its files/analysis_options.yaml alone', () {
      for (final String path in <String>[
        'invocation/c/args',
        'invocation/c/exit_code',
        'invocation/c/stdout',
        'invocation/c/stderr',
        'invocation/c/files/analysis_options.yaml',
      ]) {
        expect(holdsRecord(path), isTrue, reason: path);
      }
      for (final String path in <String>[
        'invocation/args',
        'invocation/c/args.txt',
        'invocation/c/files/args',
        'invocation/c/expected/stdout',
        'invocation/c/files/lib/analysis_options.yaml',
        'input/args',
      ]) {
        expect(holdsRecord(path), isFalse, reason: path);
      }
    });
    test('a contract text that is not UTF-8 fails at its path, alone', () {
      final List<FixtureOutcome> o = checkStructure(
        snapshotOf(
          'sample',
          sampleFiles,
          bytes: <String, List<int>>{
            'hsdd/contract/sample.md': <int>[
              0xff,
              ...utf8.encode(sampleContract),
            ],
          },
        ),
      );
      expect(
        o.map((FixtureOutcome x) => outcomeLine(CheckSet.structure, x)),
        <String>[
          'FAIL structure hsdd/contract/sample.md: contract-text (not UTF-8: Invalid UTF-8 byte (at offset 0))',
        ],
      );
    });
    test('isConformancePath accepts behavior/{name}_conformance.dart directly under behavior/ alone', () {
      for (final String path in <String>[
        'behavior/sample_conformance.dart',
        'behavior/a_conformance.dart',
      ]) {
        expect(isConformancePath(path), isTrue, reason: path);
      }
      for (final String path in <String>[
        'behavior/nested/sample_conformance.dart',
        'behavior/sample_conformance.json',
        'behavior/sample_conformance.dart.orig',
        'behavior/_conformance.dart',
        'behavior/sample_conformances.dart',
        'behavior/sampleconformance.dart',
        'behavior/sample_impl_test.dart',
        'surface/sample_conformance.dart',
        'sample_conformance.dart',
      ]) {
        expect(isConformancePath(path), isFalse, reason: path);
      }
    });
    test('a src/ import or export', () {
      final String use = sampleFiles['${s}surface/use.dart']!;
      expect(
        at(
          check(<String, String?>{
            '${s}surface/use.dart':
                "import 'package:sample/src/sample_base.dart';\n$use",
          }),
          '${s}surface/use.dart',
        ),
        <String>['src-import (package:sample/src/sample_base.dart)'],
      );
      expect(
        at(
          check(<String, String?>{
            '${s}surface/use.dart':
                "export 'package:sample/src/sample_base.dart';\n$use",
          }),
          '${s}surface/use.dart',
        ),
        <String>['src-import (package:sample/src/sample_base.dart)'],
      );
    });
  });
  group('Dart sources that are not UTF-8', () {
    test('decodeSource reads UTF-8 and names the first malformed byte', () {
      expect(
        (decodeSource(utf8.encode('// é\n')) as SourceText).text,
        '// é\n',
      );
      expect(
        (decodeSource(<int>[
          0x2f,
          0x2f,
          0x20,
          0xff,
          0x0a,
        ]) as SourceNotUtf8).reason,
        'not UTF-8: Invalid UTF-8 byte (at offset 3)',
      );
    });
    test(
      'one fails structure at its path with the reason, and is no library',
      () {
        final SlugSnapshot snapshot = snapshotOf(
          'sample',
          sampleFiles,
          bytes: <String, List<int>>{
            '${s}reject/latin1.dart': <int>[0x2f, 0x2f, 0x20, 0xff, 0x0a],
          },
        );
        expect(snapshot.files['reject/latin1.dart'], isNull);
        expect(snapshot.undecodable, <String, String>{
          'reject/latin1.dart': 'not UTF-8: Invalid UTF-8 byte (at offset 3)',
        });
        expect(at(checkStructure(snapshot), '${s}reject/latin1.dart'), <String>[
          'encoding (not UTF-8: Invalid UTF-8 byte (at offset 3))',
        ]);
      },
    );
    test('a listed binding that is not UTF-8 is present, sorts among the paths, and fails on its encoding alone', () {
      final List<FixtureOutcome> o = checkStructure(
        snapshotOf(
          'sample',
          sampleFiles,
          bytes: <String, List<int>>{
            '${s}behavior/sample_impl_test.dart': <int>[0x2f, 0x2f, 0xc3, 0x28],
          },
        ),
      );
      expect(o.map((FixtureOutcome x) => x.path), <String>[
        'hsdd/contract/sample.md',
        s,
        '${s}behavior/sample_conformance.dart',
        '${s}behavior/sample_impl_test.dart',
        '${s}reject/sample_is_closed.dart',
        '${s}surface/use.dart',
      ]);
      expect(at(o, '${s}behavior/sample_impl_test.dart'), <String>[
        'encoding (not UTF-8: Missing extension byte (at offset 3))',
      ]);
      expect(
        o.where(
          (FixtureOutcome x) => x.path != '${s}behavior/sample_impl_test.dart',
        ),
        everyElement(isA<Passed>()),
      );
    });
    test('a conformance library that is not UTF-8 cites nothing', () {
      final List<FixtureOutcome> o = checkStructure(
        snapshotOf(
          'sample',
          sampleFiles,
          bytes: <String, List<int>>{
            '${s}behavior/sample_conformance.dart': <int>[0xff],
          },
        ),
      );
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
        'encoding (not UTF-8: Invalid UTF-8 byte (at offset 0))',
      ]);
      expect(at(o, s), <String>['coverage (G2, G3 uncovered)']);
    });
  });
  group('conformance-import', () {
    test('a conformance library that imports package:test or exports package:flutter_test fails', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformanceWith(
          "import 'package:matcher/expect.dart';\n",
          "import 'package:matcher/expect.dart';\n"
              "import 'package:test/test.dart';\n"
              "export 'package:flutter_test/flutter_test.dart';\n",
        ),
      });
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
        'conformance-import (package:test/test.dart)',
        'conformance-import (package:flutter_test/flutter_test.dart)',
      ]);
    });
    test('a binding may import them, and package:test_api is neither', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformanceWith(
          "import 'package:matcher/expect.dart';\n",
          "import 'package:matcher/expect.dart';\nimport 'package:test_api/scaffolding.dart';\n",
        ),
      });
      expect(o, everyElement(isA<Passed>()));
    });
    test('a package whose name only begins with test or flutter_test is neither, and no other library is a conformance library', () {
      final String use = sampleFiles['${s}surface/use.dart']!;
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformanceWith(
          "import 'package:matcher/expect.dart';\n",
          "import 'package:matcher/expect.dart';\n"
              "import 'package:testing/testing.dart';\n"
              "import 'package:flutter_test_extras/extras.dart';\n",
        ),
        '${s}surface/use.dart': "import 'package:test/test.dart';\n$use",
        '${s}behavior/nested/more_conformance.dart':
            "import 'package:flutter_test/flutter_test.dart';\n",
      });
      expect(o, everyElement(isA<Passed>()));
    });
    test('after the src-import and case-name problems, in directive order', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformanceWith(
          "import 'package:matcher/expect.dart';\n",
          "export 'package:flutter_test/flutter_test.dart';\n"
              "import 'package:sample/src/sample_base.dart';\n"
              "import 'package:test/test.dart';\n",
        ).replaceFirst("'G3 a", "'g3 a"),
      });
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
        'src-import (package:sample/src/sample_base.dart)',
        'case-name (line 20: case name does not begin with G{n} and a space: g3 a sample value is redacted)',
        'conformance-import (package:flutter_test/flutter_test.dart)',
        'conformance-import (package:test/test.dart)',
      ]);
    });
  });
  group('Validation forms', () {
    test('a whole not-executable line must name its node, and covers nothing without it', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': contractWith(
          "pubspec; checked by nidana.model's gates",
          'pubspec',
        ),
      });
      expect(at(o, 'hsdd/contract/sample.md'), <String>[
        "validation-form (G4's not-executable line names no node: ; checked by {node}'s gates)",
      ]);
      expect(at(o, s), <String>['coverage (G4 uncovered)']);
    });
    test('a partial not-executable line must name its node too', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': contractWith(
          "build; checked by nidana.model's gates",
          'build',
        ),
      });
      expect(at(o, 'hsdd/contract/sample.md'), <String>[
        "validation-form (G3's not-executable line names no node: ; checked by {node}'s gates)",
      ]);
      expect(at(o, s), isEmpty);
    });
    test('invocation directories against the Case table', () {
      expect(
        at(
          check(
            <String, String?>{'${t}invocation/extra/args': 'tool:generate\n'},
            slug: 'tool',
            base: toolFiles,
          ),
          '${t}invocation/extra/',
        ),
        <String>['invocation-row (no row in the Case table)'],
      );
      expect(
        at(
          check(
            <String, String?>{
              '${t}invocation/generate-usage/args': null,
              '${t}invocation/generate-usage/exit_code': null,
            },
            slug: 'tool',
            base: toolFiles,
          ),
          '${t}invocation/generate-usage/',
        ),
        <String>['invocation-row (a row of the Case table, absent)'],
      );
    });
    test('a malformed Covers cell or covers clause', () {
      final String tool = toolFiles['hsdd/contract/tool.md']!;
      List<FixtureOutcome> withTool(String from, String to) => check(
        <String, String?>{'hsdd/contract/tool.md': tool.replaceFirst(from, to)},
        slug: 'tool',
        base: toolFiles,
      );
      final List<FixtureOutcome> cell = withTool(
        '| G2: an unknown option |',
        '| two |',
      );
      expect(at(cell, 'hsdd/contract/tool.md'), <String>[
        'validation-form (malformed Covers cell of generate-usage: two)',
      ]);
      expect(at(cell, t), <String>['coverage (G2 uncovered)']);
      final List<FixtureOutcome> clause = withTool(
        'covers G1.',
        'covers the tree.',
      );
      expect(at(clause, 'hsdd/contract/tool.md'), <String>[
        'validation-form (malformed covers clause: covers the tree.)',
      ]);
      expect(at(clause, t), <String>['coverage (G1 uncovered)']);
    });
    test('a covers clause whose set is absent covers nothing', () {
      final String tool = toolFiles['hsdd/contract/tool.md']!;
      final List<FixtureOutcome> o = check(
        <String, String?>{
          'hsdd/contract/tool.md': tool
              .substring(0, tool.indexOf('- invocations:'))
              .replaceFirst(
                '- file:',
                '- schema: `hsdd/contract/schema/tool.schema.json`, '
                    'the data model; covers G2.\n- file:',
              ),
          '${t}input/in.txt': null,
          '${t}expected/out.txt': null,
          '${t}invocation/generate-usage/args': null,
          '${t}invocation/generate-usage/exit_code': null,
        },
        slug: 'tool',
        base: toolFiles,
      );
      expect(at(o, 'hsdd/contract/tool.md'), <String>[
        'validation-form (covers clause of the schema bullet names a set that is absent: no hsdd/contract/schema/tool.schema.json)',
        'validation-form (covers clause of the file bullet names a set that is absent: no input/ and expected/)',
      ]);
      expect(at(o, t), <String>['coverage (G1, G2 uncovered)']);
    });
    test('a file covers clause needs both input/ and expected/', () {
      List<FixtureOutcome> without(String path) =>
          check(<String, String?>{path: null}, slug: 'tool', base: toolFiles);
      final List<FixtureOutcome> noInput = without('${t}input/in.txt');
      expect(at(noInput, 'hsdd/contract/tool.md'), <String>[
        'validation-form (covers clause of the file bullet names a set that is absent: no input/)',
      ]);
      expect(at(noInput, t), <String>['coverage (G1 uncovered)']);
      final List<FixtureOutcome> noExpected = without('${t}expected/out.txt');
      expect(at(noExpected, 'hsdd/contract/tool.md'), <String>[
        'validation-form (covers clause of the file bullet names a set that is absent: no expected/)',
      ]);
      expect(at(noExpected, t), <String>['coverage (G1 uncovered)']);
    });
    test('a schema covers clause covers when the schema file exists', () {
      final String tool = toolFiles['hsdd/contract/tool.md']!;
      final List<FixtureOutcome> o = check(
        <String, String?>{
          'hsdd/contract/tool.md': tool
              .replaceFirst(
                '| `generate-usage` | `tool:generate --frob` | 2 | G2: an unknown option |\n',
                '',
              )
              .replaceFirst(
                '- file:',
                '- schema: `hsdd/contract/schema/tool.schema.json`, '
                    'the data model; covers G2.\n- file:',
              ),
          '${t}invocation/generate-usage/args': null,
          '${t}invocation/generate-usage/exit_code': null,
          'hsdd/contract/schema/tool.schema.json': '{}',
        },
        slug: 'tool',
        base: toolFiles,
      );
      expect(o, everyElement(isA<Passed>()));
    });
  });
  group('the contract text', () {
    test('absent: one outcome', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': null,
      });
      expect(o.map((FixtureOutcome x) => x.path), <String>[
        'hsdd/contract/sample.md',
      ]);
      expect(at(o, 'hsdd/contract/sample.md'), <String>[
        'contract-text (no contract text at hsdd/contract/sample.md)',
      ]);
    });
    test('a wrong id, an unknown kind, a repeated guarantee', () {
      expect(
        at(
          check(<String, String?>{
            'hsdd/contract/sample.md': contractWith('id: sample', 'id: other'),
          }),
          'hsdd/contract/sample.md',
        ),
        <String>['contract-text (frontmatter id is other, expected sample)'],
      );
      expect(
        at(
          check(<String, String?>{
            'hsdd/contract/sample.md': contractWith(
              'kind: api',
              'kind: widget',
            ),
          }),
          'hsdd/contract/sample.md',
        ),
        <String>['contract-text (unknown kind widget)'],
      );
      expect(
        at(
          check(<String, String?>{
            'hsdd/contract/sample.md': contractWith(
              '- **G4**',
              '- **G2** again.\n- **G4**',
            ),
          }),
          'hsdd/contract/sample.md',
        ),
        <String>['contract-text (G2 repeats)'],
      );
    });
  });
  group('each rule and its detail', () {
    test('a guarantee entry without its bold id', () {
      expect(
        at(
          check(<String, String?>{
            'hsdd/contract/sample.md': contractWith(
              '- **G4**',
              '- G5 without its bold id.\n- **G4**',
            ),
          }),
          'hsdd/contract/sample.md',
        ),
        <String>[
          'contract-text (guarantee entry does not begin with - **G{n}**: - G5 without its bold id.)',
        ],
      );
    });
    test('a listed binding outside this slug\'s behavior/', () {
      final List<FixtureOutcome> other = check(<String, String?>{
        'hsdd/contract/sample.md': contractWith(
          'fixture/sample/behavior/sample_impl_test.dart',
          'fixture/other/behavior/sample_impl_test.dart',
        ),
      });
      expect(at(other, 'hsdd/contract/sample.md'), <String>[
        'binding (listed binding hsdd/contract/fixture/other/behavior/sample_impl_test.dart is not in ${s}behavior/)',
      ]);
      expect(at(other, '${s}behavior/sample_impl_test.dart'), <String>[
        'binding (not listed in ## Validation)',
      ]);
      expect(
        at(
          check(<String, String?>{
            'hsdd/contract/sample.md': contractWith(
              'behavior/sample_impl_test.dart',
              'behavior/nested/sample_impl_test.dart',
            ),
          }),
          'hsdd/contract/sample.md',
        ),
        <String>[
          'binding (listed binding ${s}behavior/nested/sample_impl_test.dart is not in ${s}behavior/)',
        ],
      );
    });
    test('a Case cell without its backticks names no invocation and covers nothing', () {
      final List<FixtureOutcome> o = check(
        <String, String?>{
          'hsdd/contract/tool.md': toolContractWith(
            '| `generate-usage` |',
            '| generate-usage |',
          ),
        },
        slug: 'tool',
        base: toolFiles,
      );
      expect(at(o, 'hsdd/contract/tool.md'), <String>[
        'validation-form (malformed Case cell: generate-usage)',
      ]);
      expect(at(o, t), <String>['coverage (G2 uncovered)']);
      expect(at(o, '${t}invocation/generate-usage/'), <String>[
        'invocation-row (no row in the Case table)',
      ]);
    });
    test('a not-executable line that begins with no id', () {
      expect(
        at(
          check(<String, String?>{
            'hsdd/contract/sample.md': contractWith(
              '- not executable: G4',
              "- not executable: the rest, on a value no case builds; checked by nidana.model's gates\n- not executable: G4",
            ),
          }),
          'hsdd/contract/sample.md',
        ),
        <String>[
          "validation-form (not-executable line begins with no G{n}: - not executable: the rest, on a value no case builds; checked by nidana.model's gates)",
        ],
      );
    });
    test(
      'the problems of a case list, and a case name that is no string literal',
      () {
        expect(
          at(
            check(<String, String?>{
              '${s}behavior/sample_conformance.dart': conformanceWith(
                '];',
                '  otherCases,\n  (body: (SampleHarness h) async {}),\n];',
              ),
            }),
            '${s}behavior/sample_conformance.dart',
          ),
          <String>[
            'case-name (line 21: an element of sampleConformance is not a record literal)',
            'case-name (line 22: a record of sampleConformance has no name field)',
          ],
        );
        final List<FixtureOutcome> o = check(<String, String?>{
          '${s}behavior/sample_conformance.dart': conformanceWith(
            "'G3 a sample value is redacted'",
            r"'G3 $redacted'",
          ),
        });
        expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
          'case-name (line 18: case name is not a string literal)',
        ]);
        expect(at(o, s), <String>['coverage (G3 uncovered)']);
      },
    );
    test('several undeclared ids in a covers header', () {
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart': sampleReject.replaceFirst(
              'G1\n',
              'G1, G7 and G8\n',
            ),
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>['unknown-id (G7, G8 are not guarantees of sample)'],
      );
    });
    test('a not-executable line, whole or partial, cites a declared id', () {
      List<String> withLine(String line) => at(
        check(<String, String?>{
          'hsdd/contract/sample.md': contractWith(
            '- not executable: G4',
            '$line\n- not executable: G4',
          ),
        }),
        'hsdd/contract/sample.md',
      );
      expect(
        withLine(
          "- not executable: G8, a property of the pubspec; checked by nidana.model's gates",
        ),
        <String>['unknown-id (G8 is not a guarantee of sample)'],
      );
      expect(
        withLine(
          "- not executable: G7's last clause, on a value no case builds; checked by nidana.model's gates",
        ),
        <String>['unknown-id (G7 is not a guarantee of sample)'],
      );
      expect(
        withLine(
          "- not executable: G7's last clause, on a value no case builds",
        ),
        <String>[
          "validation-form (G7's not-executable line names no node: ; checked by {node}'s gates)",
          'unknown-id (G7 is not a guarantee of sample)',
        ],
      );
    });
    test('a case name cites a declared id', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformanceWith(
          "'G3 a",
          "'G7 a",
        ),
      });
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
        'unknown-id (G7 is not a guarantee of sample)',
      ]);
      expect(at(o, s), <String>['coverage (G3 uncovered)']);
    });
  });
  group('structure-set polish', () {
    test('a covers clause followed by whitespace still covers', () {
      final List<FixtureOutcome> o = check(
        <String, String?>{
          'hsdd/contract/tool.md': toolContractWith(
            'The file set covers G1.',
            'The file set covers G1.  \t',
          ),
        },
        slug: 'tool',
        base: toolFiles,
      );
      expect(o, everyElement(isA<Passed>()));
    });
    test('a covers bullet without its closing clause is a validation-form failure and covers nothing', () {
      final List<FixtureOutcome> o = check(
        <String, String?>{
          'hsdd/contract/tool.md': toolContractWith(
            'The file set covers G1.',
            'The file set covers G1, see below',
          ),
        },
        slug: 'tool',
        base: toolFiles,
      );
      expect(at(o, 'hsdd/contract/tool.md'), <String>[
        'validation-form (bullet holds covers but does not end with covers {ids}.: - file: `hsdd/contract/fixture/tool/input/` holds `in.txt`; the replay runs `fvm dart run tool:generate {input}/in.txt {output}` and compares the tree with `expected/`. The file set covers G1, see below)',
      ]);
      expect(at(o, t), <String>['coverage (G1 uncovered)']);
    });
    test('a covers header with a range wider than 1000 ids (b - a >= 1000) is malformed', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}reject/sample_is_closed.dart': sampleReject.replaceFirst(
          '// covers: G1\n',
          '// covers: G1 to G100000000\n',
        ),
      });
      expect(at(o, '${s}reject/sample_is_closed.dart'), <String>[
        'covers-header (malformed // covers: G1 to G100000000)',
      ]);
      expect(at(o, s), <String>['coverage (G1 uncovered)']);
    });
    test('three or more uncovered ids in a row print as a range', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        'hsdd/contract/sample.md': sampleContract.replaceFirst(
          '- **G4**',
          '- **G5** a.\n- **G6** b.\n- **G7** c.\n- **G4**',
        ),
      });
      expect(at(o, s), <String>['coverage (G5 to G7 uncovered)']);
    });
  });
  group('problems follow the order of the checks, not of the lines', () {
    test('the contract text', () {
      final List<FixtureOutcome> o = check(
        <String, String?>{
          'hsdd/contract/tool.md': toolContractWithEveryProblem,
        },
        slug: 'tool',
        base: toolFiles,
      );
      expect(at(o, 'hsdd/contract/tool.md'), <String>[
        'contract-text (frontmatter id is other, expected tool)',
        'contract-text (unknown kind widget)',
        'contract-text (guarantee entry does not begin with - **G{n}**: - G3 without its bold id.)',
        'contract-text (G2 repeats)',
        'validation-form (malformed covers clause: covers the tree.)',
        'validation-form (bullet holds covers but does not end with covers {ids}.: - schema: a bullet that covers G2, then wraps)',
        'validation-form (covers clause of the schema bullet names a set that is absent: no hsdd/contract/schema/tool.schema.json)',
        'validation-form (malformed Case cell: generate-help)',
        'validation-form (malformed Covers cell of generate-usage: two)',
        "validation-form (not-executable line begins with no G{n}: - not executable: the rest; checked by nidana.model's gates)",
        "validation-form (G2's not-executable line names no node: ; checked by {node}'s gates)",
        'binding (listed binding hsdd/contract/fixture/other/behavior/other_test.dart is not in ${t}behavior/)',
        'unknown-id (G7, G8 are not guarantees of tool)',
      ]);
      expect(at(o, t), <String>['coverage (G1, G2 uncovered)']);
    });
    test('a reject/ library', () {
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart': rejectWithMalformedHeader,
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>[
          'src-import (package:sample/src/sample_base.dart)',
          'covers-header (malformed // covers: the closed family)',
          'marker (line 4: not a marker of the form // expect-diagnostic: {code})',
          'marker (no // expect-diagnostic: marker)',
        ],
      );
      expect(
        at(
          check(<String, String?>{
            '${s}reject/sample_is_closed.dart': rejectWithMalformedMarkers,
          }),
          '${s}reject/sample_is_closed.dart',
        ),
        <String>[
          'src-import (package:sample/src/sample_base.dart)',
          'marker (line 5: not a marker of the form // expect-diagnostic: {code})',
          'marker (line 4: not followed by a line of code)',
          'marker (line 7: not followed by a line of code)',
          'unknown-id (G7 is not a guarantee of sample)',
        ],
      );
    });
    test('a conformance library', () {
      final List<FixtureOutcome> o = check(<String, String?>{
        '${s}behavior/sample_conformance.dart': conformanceWithEveryProblem,
      });
      expect(at(o, '${s}behavior/sample_conformance.dart'), <String>[
        'src-import (package:sample/src/sample_base.dart)',
        'case-name (2 public List<ConformanceCase> declarations, expected one)',
        'case-name (line 8: an element of sampleConformance is not a record literal)',
        'case-name (line 9: a record of sampleConformance has no name field)',
        'case-name (line 7: case name is not a string literal)',
        'case-name (line 6: case name does not begin with G{n} and a space: g3 a sample value is redacted)',
        'unknown-id (G7, G8 are not guarantees of sample)',
      ]);
      expect(at(o, s), <String>['coverage (G3 uncovered)']);
    });
  });
}
