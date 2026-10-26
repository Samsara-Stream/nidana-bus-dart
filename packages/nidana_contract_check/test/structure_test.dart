// packages/nidana_contract_check/test/structure_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
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
}
