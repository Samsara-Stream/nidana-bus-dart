import 'dart:io';

import 'package:test/test.dart';

import 'support/sample.dart';
import 'support/seed.dart';

const String s = 'hsdd/contract/fixture/sample/';
const List<String> cleanLines = <String>[
  'PASS structure hsdd/contract/sample.md',
  'PASS structure hsdd/contract/fixture/sample/',
  'PASS structure hsdd/contract/fixture/sample/behavior/sample_conformance.dart',
  'PASS structure hsdd/contract/fixture/sample/behavior/sample_impl_test.dart',
  'PASS structure hsdd/contract/fixture/sample/reject/sample_is_closed.dart',
  'PASS structure hsdd/contract/fixture/sample/surface/use.dart',
  '6 fixtures: 6 passed, 0 failed',
];

List<String> lines(ProcessResult r) =>
    (r.stdout as String).trimRight().split('\n');
String all(ProcessResult r) => '${r.stdout}${r.stderr}';

void main() {
  test('a clean slug passes with one line per fixture', () async {
    final ProcessResult r = await runTool(<String>[
      'sample',
      '--set',
      'structure',
    ], workingDirectory: seed(sampleFiles));
    expect(r.exitCode, 0, reason: all(r));
    expect(lines(r), cleanLines);
  });
  test('--all replays every slug in ascending order', () async {
    final ProcessResult r = await runTool(<String>[
      '--all',
      '--set',
      'structure',
    ], workingDirectory: seed(<String, String>{...sampleFiles, ...toolFiles}));
    expect(r.exitCode, 0, reason: all(r));
    expect(lines(r), <String>[
      ...cleanLines.take(6),
      'PASS structure hsdd/contract/tool.md',
      'PASS structure hsdd/contract/fixture/tool/',
      '8 fixtures: 8 passed, 0 failed',
    ]);
  });
  group('each seeded defect names the fixture and the rule, and exits 1', () {
    final String use = sampleFiles['${s}surface/use.dart']!;
    for (final (String name, Map<String, String?> change, String line)
        in <(String, Map<String, String?>, String)>[
          (
            'an unlisted directory',
            <String, String?>{'${s}extra/notes.txt': 'notes\n'},
            'FAIL structure ${s}extra/: layout (extra is neither a set directory of kind api nor a data directory listed in ## Validation)',
          ),
          (
            'a reject file without a covers header',
            <String, String?>{
              '${s}reject/sample_is_closed.dart': sampleReject.replaceFirst(
                '// covers: G1\n',
                '',
              ),
            },
            'FAIL structure ${s}reject/sample_is_closed.dart: covers-header (no // covers: header)',
          ),
          (
            'an uncovered guarantee',
            <String, String?>{
              'hsdd/contract/sample.md': sampleContract.replaceFirst(
                '- **G4**',
                '- **G5** uncovered.\n- **G4**',
              ),
            },
            'FAIL structure $s: coverage (G5 uncovered)',
          ),
          (
            'a listed binding that is absent',
            <String, String?>{'${s}behavior/sample_impl_test.dart': null},
            'FAIL structure ${s}behavior/sample_impl_test.dart: binding (listed in ## Validation, absent)',
          ),
          (
            'a src/ import',
            <String, String?>{
              '${s}surface/use.dart':
                  "import 'package:sample/src/sample_base.dart';\n$use",
            },
            'FAIL structure ${s}surface/use.dart: src-import (package:sample/src/sample_base.dart)',
          ),
        ]) {
      test(name, () async {
        final ProcessResult r = await runTool(<String>[
          '--all',
          '--set',
          'structure',
        ], workingDirectory: seed(changed(sampleFiles, change)));
        expect(r.exitCode, 1, reason: all(r));
        expect(lines(r), contains(line));
      });
    }
  });
  test(
    'a set this version does not implement is an environment error (2)',
    () async {
      final ProcessResult r = await runTool(<String>[
        'sample',
      ], workingDirectory: seed(sampleFiles));
      expect(r.exitCode, 2, reason: all(r));
      expect(lines(r), contains('PASS structure hsdd/contract/sample.md'));
      expect(
        r.stderr as String,
        contains(
          'ERROR surface sample: this version of nidana_contract_check does not implement the surface set',
        ),
      );
    },
  );
  test('usage errors exit 64 and print the usage', () async {
    final Directory root = seed(<String, String>{...sampleFiles, ...toolFiles});
    final ProcessResult unknown = await runTool(<String>[
      'nosuch',
    ], workingDirectory: root);
    expect(unknown.exitCode, 64, reason: all(unknown));
    expect(
      unknown.stderr as String,
      allOf(contains("unknown slug 'nosuch'"), contains('usage: ')),
    );
    final ProcessResult bare = await runTool(<String>[
      'sample',
      'tool',
      '--guarantee',
      'G1',
    ], workingDirectory: root);
    expect(bare.exitCode, 64, reason: all(bare));
    expect(bare.stderr as String, contains("bare id 'G1'"));
  });
  test('no workspace root is an environment error (2)', () async {
    final ProcessResult r = await runTool(<String>[
      '--all',
    ], workingDirectory: seed(const <String, String>{'readme.txt': 'x\n'}));
    expect(r.exitCode, 2, reason: all(r));
    expect(r.stderr as String, contains('no ancestor of'));
  });
  test(
    'from a subdirectory the root is found and paths stay relative to it',
    () async {
      final Directory root = seed(sampleFiles);
      final ProcessResult r = await runTool(
        <String>['sample', '--set', 'structure'],
        workingDirectory: Directory(
          '${root.path}/hsdd/contract/fixture/sample/behavior',
        ),
      );
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r), cleanLines);
    },
  );
  test('hidden entries such as .DS_Store are not part of a snapshot', () async {
    final ProcessResult r = await runTool(
      <String>['sample', '--set', 'structure'],
      workingDirectory: seed(<String, String>{
        ...sampleFiles,
        '$s.DS_Store': 'x',
        '${s}reject/.DS_Store': 'x',
      }),
    );
    expect(r.exitCode, 0, reason: all(r));
    expect(lines(r), cleanLines);
  });
}
