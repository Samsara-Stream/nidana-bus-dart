// packages/nidana_contract_check/test/structure_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
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
        hasSchemaFile: clean.hasSchemaFile,
        directories: <String>{...clean.directories, 'valid'},
        files: <String, String?>{
          ...clean.files,
          'valid/a.json': '{}',
          'valid/gen.dart': 'void main() {}\n',
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
        'validation-form (malformed Case cell: G2: an unknown option)',
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
        'validation-form (malformed Case cell: G1: a row without its backticks)',
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
