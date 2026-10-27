import 'dart:convert';
import 'dart:io';

import 'package:nidana_contract_check/src/request.dart' show usage;
import 'package:nidana_contract_check/src/shell.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:test/test.dart';

import 'support/runners.dart';
import 'support/sample.dart';
import 'support/seed.dart';
import 'support/workspace.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String t = 'hsdd/contract/fixture/tool/';
const String h = 'hsdd/contract/fixture/host/';
const List<String> cleanLines = <String>[
  'PASS structure hsdd/contract/sample.md',
  'PASS structure hsdd/contract/fixture/sample/',
  'PASS structure hsdd/contract/fixture/sample/behavior/sample_conformance.dart',
  'PASS structure hsdd/contract/fixture/sample/behavior/sample_impl_test.dart',
  'PASS structure hsdd/contract/fixture/sample/reject/sample_is_closed.dart',
  'PASS structure hsdd/contract/fixture/sample/surface/use.dart',
  '6 fixtures: 6 passed, 0 failed, 0 pending',
];

List<String> lines(ProcessResult r) =>
    (r.stdout as String).trimRight().split('\n');
String all(ProcessResult r) => '${r.stdout}${r.stderr}';

/// A package configuration that configures `sample` alone, for a replay
/// whose `dart` is [fakeDart] and that needs no `pub get`.
const String sampleConfiguration =
    '{"configVersion": 2, "packages": [{"name": "sample", '
    '"rootUri": "../packages/sample/", "packageUri": "lib/"}]}\n';

/// A stand-in for `dart` in a fresh temporary directory: a shell script that
/// prints [report] and appends its arguments, one line per call, to the
/// returned `calls` file.
({String path, File calls}) fakeDart(String report) {
  final String path = '${seed(const <String, String>{}).path}/dart';
  File(path).writeAsStringSync(
    <String>[
      '#!/bin/sh',
      r'''printf '%s\n' "$*" >> "$0.calls"''',
      "cat <<'REPORT'",
      report,
      'REPORT',
      '',
    ].join('\n'),
  );
  final ProcessResult chmod = Process.runSync('chmod', <String>['+x', path]);
  expect(chmod.exitCode, 0, reason: all(chmod));
  return (path: path, calls: File('$path.calls'));
}

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
      '8 fixtures: 8 passed, 0 failed, 0 pending',
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
          (
            'a conformance library that imports package:test',
            <String, String?>{
              '${s}behavior/sample_conformance.dart':
                  "import 'package:test/test.dart';\n"
                  '${sampleFiles['${s}behavior/sample_conformance.dart']!}',
            },
            'FAIL structure ${s}behavior/sample_conformance.dart: conformance-import (package:test/test.dart)',
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
  test('a Dart fixture that is not UTF-8 fails structure (1), never an environment error', () async {
    final Directory root = seed(sampleFiles);
    File('${root.path}/${s}reject/latin1.dart')
        .writeAsBytesSync(<int>[0x2f, 0x2f, 0x20, 0xff, 0x0a]);
    final ProcessResult r = await runTool(<String>[
      'sample',
      '--set',
      'structure',
    ], workingDirectory: root);
    expect(r.exitCode, 1, reason: all(r));
    expect(
      lines(r),
      contains(
        'FAIL structure ${s}reject/latin1.dart: encoding (not UTF-8: Invalid UTF-8 byte (at offset 3))',
      ),
    );
    expect(r.stderr as String, isEmpty);
  });
  test("readSnapshot keeps the bytes of a recorded invocation's files and no other's", () {
    final Directory root = seed(<String, String>{
      ...toolFiles,
      '${t}invocation/generate-usage/stdout': 'out\n',
      '${t}invocation/generate-usage/stderr': 'err\n',
      '${t}invocation/generate-usage/files/analysis_options.yaml': 'plugins:\n',
      '${t}invocation/generate-usage/files/in.txt': 'x\n',
      '${t}invocation/generate-usage/expected/out.txt': 'y\n',
    });
    final Map<String, List<int>> records = readSnapshot(root, 'tool').records;
    expect(records.keys.toSet(), <String>{
      'invocation/generate-usage/args',
      'invocation/generate-usage/exit_code',
      'invocation/generate-usage/stdout',
      'invocation/generate-usage/stderr',
      'invocation/generate-usage/files/analysis_options.yaml',
    });
    expect(
      utf8.decode(records['invocation/generate-usage/args']!),
      'tool:generate\n--frob\n',
    );
  });
  test('a record is read through a link, a dangling one throws, and a hidden case holds none', () {
    const String c = '${t}invocation/generate-usage/';
    final Directory root = seed(<String, String>{
      ...toolFiles,
      'elsewhere/stdout': 'linked\n',
      '${t}invocation/.hidden/args': 'dart\n',
    });
    Link('${root.path}/${c}stdout').createSync('${root.path}/elsewhere/stdout');
    final Map<String, List<int>> records = readSnapshot(root, 'tool').records;
    expect(records.keys.toSet(), <String>{
      'invocation/generate-usage/args',
      'invocation/generate-usage/exit_code',
      'invocation/generate-usage/stdout',
    });
    expect(
      utf8.decode(records['invocation/generate-usage/stdout']!),
      'linked\n',
    );
    Link('${root.path}/${c}stderr').createSync('${root.path}/nowhere');
    expect(
      () => readSnapshot(root, 'tool'),
      throwsA(
        isA<FileSystemException>().having(
          (FileSystemException e) => e.path,
          'path',
          endsWith('${c}stderr'),
        ),
      ),
    );
  });
  test('snapshotOf reads the contract text and the records as readSnapshot reads them', () {
    final Map<String, String> files = <String, String>{
      ...toolFiles,
      '${t}invocation/generate-usage/stdout': 'out\n',
      '${t}invocation/generate-usage/files/analysis_options.yaml': 'plugins:\n',
      '${t}invocation/generate-usage/files/in.txt': 'x\n',
    };
    final Directory root = seed(files);
    File('${root.path}/hsdd/contract/tool.md')
        .writeAsBytesSync(const <int>[0x23, 0xff]);
    final SlugSnapshot read = readSnapshot(root, 'tool');
    final SlugSnapshot seeded = snapshotOf(
      'tool',
      files,
      bytes: const <String, List<int>>{
        'hsdd/contract/tool.md': <int>[0x23, 0xff],
      },
    );
    expect(read.contractText, isNull);
    expect(
      read.contractUndecodable,
      'not UTF-8: Invalid UTF-8 byte (at offset 1)',
    );
    expect(seeded.contractText, read.contractText);
    expect(seeded.contractUndecodable, read.contractUndecodable);
    expect(seeded.records, read.records);
  });
  test('a contract text that is not UTF-8 fails structure (1), and a restriction still reads its ids', () async {
    final Directory root = seed(sampleFiles);
    File('${root.path}/hsdd/contract/sample.md')
        .writeAsBytesSync(<int>[0xff, ...utf8.encode(sampleContract)]);
    for (final List<String> arguments in <List<String>>[
      <String>['sample', '--set', 'structure'],
      <String>['sample', '--set', 'structure', '--guarantee', 'G1'],
    ]) {
      final ProcessResult r = await runTool(arguments, workingDirectory: root);
      expect(r.exitCode, 1, reason: '$arguments\n${all(r)}');
      expect(lines(r), <String>[
        'FAIL structure hsdd/contract/sample.md: contract-text (not UTF-8: Invalid UTF-8 byte (at offset 0))',
        '1 fixture: 0 passed, 1 failed, 0 pending',
      ], reason: '$arguments');
    }
  });
  test("a read defect in another slug's tree outside its suite stops no binding's replay", () async {
    final Directory root = await seedWorkspace(<String, String>{
      ...behaviorFiles,
      ...hostFiles,
    });
    Link('${root.path}/hsdd/contract/fixture/sample/surface/broken.dart')
        .createSync('${root.path}/nowhere.dart');
    final ProcessResult r = await runTool(<String>[
      'host',
      '--set',
      'behavior',
    ], workingDirectory: root);
    expect(r.exitCode, 1, reason: all(r));
    expect(r.stderr as String, isNot(contains('error:')));
    expect(
      lines(r),
      contains(
        'PENDING behavior ${h}behavior/host_impl_test.dart: packages matcher, nidana_contract_check, test are absent from .dart_tool/package_config.json',
      ),
    );
  });
  test('a suite file that is a dangling link fails its binding, not the replay', () async {
    final Directory root = await seedWorkspace(<String, String>{
      ...behaviorFiles,
      ...hostFiles,
    });
    const String suite =
        'hsdd/contract/fixture/sample/behavior/sample_conformance.dart';
    File('${root.path}/$suite').deleteSync();
    Link('${root.path}/$suite').createSync('${root.path}/nowhere.dart');
    final ProcessResult r = await runTool(<String>[
      'host',
      '--set',
      'behavior',
    ], workingDirectory: root);
    expect(r.exitCode, 1, reason: all(r));
    expect(
      lines(r),
      contains(
        'FAIL behavior ${h}behavior/host_impl_test.dart: suite ($suite does not exist)',
      ),
    );
  });
  group('the surface and reject sets over a seeded workspace, one dart analyze', () {
    late ProcessResult r;
    setUpAll(() async {
      r = await runTool(<String>[
        'sample',
        '--set',
        'surface,reject',
      ], workingDirectory: await seedWorkspace(analysisFiles));
    });
    test('exits 1 and counts every outcome', () {
      expect(r.exitCode, 1, reason: all(r));
      expect(lines(r).last, '20 fixtures: 15 passed, 4 failed, 1 pending');
      expect(r.stderr as String, isEmpty);
    });
    test(
      'a clean surface library and reject libraries whose markers match pass',
      () {
        expect(
          lines(r),
          containsAll(<String>[
            'PASS surface ${s}surface/use.dart',
            'PASS reject ${s}reject/sample_is_closed.dart',
            'PASS reject ${s}reject/assigns_final.dart',
          ]),
        );
      },
    );
    test('a warning fails a surface library', () {
      expect(
        lines(r),
        contains(
          "FAIL surface ${s}surface/dirty.dart: diagnostic (line 1: WARNING unused_import: Unused import: 'dart:async'.)",
        ),
      );
    });
    test('a marker on the wrong line fails a reject library', () {
      expect(
        lines(r),
        contains(
          "FAIL reject ${s}reject/wrong_line.dart: missing-diagnostic (line 5: invalid_use_of_type_outside_library, named by the marker on line 4, not reported); unexpected-diagnostic (line 6: ERROR invalid_use_of_type_outside_library: The class 'Sample' can't be extended outside of its library because it's a final class.)",
        ),
      );
    });
    test('a wrong code fails a reject library', () {
      expect(
        lines(r),
        contains(
          "FAIL reject ${s}reject/wrong_code.dart: missing-diagnostic (line 5: undefined_class, named by the marker on line 4, not reported); unexpected-diagnostic (line 5: ERROR invalid_use_of_type_outside_library: The class 'Sample' can't be extended outside of its library because it's a final class.)",
        ),
      );
    });
    test('an extra warning fails a reject library', () {
      expect(
        lines(r),
        contains(
          "FAIL reject ${s}reject/extra_warning.dart: unexpected-diagnostic (line 8: WARNING unused_local_variable: The value of the local variable 'unused' isn't used.)",
        ),
      );
    });
    test('a library that imports an absent package is PENDING', () {
      expect(
        lines(r),
        contains(
          'PENDING surface ${s}surface/pending.dart: package producer is absent from .dart_tool/package_config.json',
        ),
      );
    });
  });
  test('a contract whose producer is absent prints PENDING per fixture and exits 1, starting no analysis', () async {
    final ProcessResult r = await runTool(<String>[
      'sample',
      '--set',
      'surface,reject',
    ], workingDirectory: await seedWorkspace(sampleFiles, standIn: false));
    expect(r.exitCode, 1, reason: all(r));
    expect(lines(r), <String>[
      ...cleanLines.take(6),
      'PENDING surface ${s}surface/use.dart: package sample is absent from .dart_tool/package_config.json',
      'PENDING reject ${s}reject/sample_is_closed.dart: package sample is absent from .dart_tool/package_config.json',
      '8 fixtures: 6 passed, 0 failed, 2 pending',
    ]);
    expect(r.stderr as String, isEmpty);
  });
  test('through a symbolic link to the workspace root, diagnostics still reach their fixtures', () async {
    final Directory root = await seedWorkspace(analysisFiles);
    final Link link = Link('${seed(const <String, String>{}).path}/linked')
      ..createSync(root.path);
    final StringBuffer out = StringBuffer();
    expect(
      await runCli(
        <String>['sample', '--set', 'surface'],
        workingDirectory: Directory(link.path),
        out: out,
        err: StringBuffer(),
      ),
      1,
    );
    expect(
      out.toString(),
      contains(
        "FAIL surface ${s}surface/dirty.dart: diagnostic (line 1: WARNING unused_import: Unused import: 'dart:async'.)",
      ),
    );
  });
  group('environment errors exit 2 and name the reason', () {
    test(
      'no package configuration is a reason for every set that reads it',
      () async {
        final ProcessResult r = await runTool(<String>[
          'sample',
        ], workingDirectory: seed(sampleFiles));
        expect(r.exitCode, 2, reason: all(r));
        expect(lines(r), contains('PASS structure hsdd/contract/sample.md'));
        expect(
          r.stderr as String,
          allOf(
            contains(
              'ERROR surface sample: no package configuration at .dart_tool/package_config.json; run fvm dart pub get',
            ),
            contains(
              'ERROR reject sample: no package configuration at .dart_tool/package_config.json; run fvm dart pub get',
            ),
            contains(
              'ERROR behavior sample: no package configuration at .dart_tool/package_config.json; run fvm dart pub get',
            ),
          ),
        );
      },
    );
    test(
      'a dart that cannot start, and a dart analyze that prints no report',
      () async {
        final Directory root = await seedWorkspace(analysisFiles);
        final String missing = '${root.path}/no-such-dart';
        final StringBuffer err = StringBuffer();
        expect(
          await runCli(
            <String>['sample', '--set', 'surface'],
            workingDirectory: root,
            out: StringBuffer(),
            err: err,
            dart: missing,
          ),
          2,
        );
        expect(
          err.toString(),
          contains('ERROR surface sample: could not run $missing: '),
        );
        final StringBuffer echoed = StringBuffer();
        expect(
          await runCli(
            <String>['sample', '--set', 'surface'],
            workingDirectory: root,
            out: StringBuffer(),
            err: echoed,
            dart: '/bin/echo',
          ),
          2,
        );
        expect(
          echoed.toString(),
          contains(
            'ERROR surface sample: dart analyze exited 0 without a JSON report',
          ),
        );
      },
    );
    test('--all with no slug directory', () async {
      final ProcessResult r = await runTool(
        <String>['--all'],
        workingDirectory: seed(const <String, String>{
          'hsdd/contract/readme.md': 'x\n',
        }),
      );
      expect(r.exitCode, 2, reason: all(r));
      expect(
        r.stderr as String,
        contains('error: no slug directory under hsdd/contract/fixture/'),
      );
    });
    test('a symbolic link where a slug directory belongs', () async {
      final Directory root = seed(sampleFiles);
      Link('${root.path}/hsdd/contract/fixture/linked')
          .createSync('${root.path}/hsdd/contract/fixture/sample');
      final ProcessResult r = await runTool(<String>[
        '--all',
        '--set',
        'structure',
      ], workingDirectory: root);
      expect(r.exitCode, 2, reason: all(r));
      expect(
        r.stderr as String,
        contains("error: a slug's fixture directory is a symbolic link: "),
      );
    });
  });
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
  test('a usage error exits 64 even when no slug directory exists; --all then exits 2', () async {
    final Directory root = seed(const <String, String>{
      'hsdd/contract/readme.md': 'x\n',
    });
    final ProcessResult named = await runTool(<String>[
      'sample',
    ], workingDirectory: root);
    expect(named.exitCode, 64, reason: all(named));
    expect(named.stderr as String, contains("unknown slug 'sample'"));
    final ProcessResult every = await runTool(<String>[
      '--all',
    ], workingDirectory: root);
    expect(every.exitCode, 2, reason: all(every));
    expect(
      every.stderr as String,
      'error: no slug directory under hsdd/contract/fixture/\n',
    );
  });
  test('the usage text follows the message, exactly', () async {
    final ProcessResult r = await runTool(<String>[
      'nosuch',
    ], workingDirectory: seed(sampleFiles));
    expect(r.exitCode, 64, reason: all(r));
    expect(
      r.stderr as String,
      "error: unknown slug 'nosuch': no directory hsdd/contract/fixture/nosuch/\n$usage\n",
    );
    expect(usage, '''
usage: fvm dart run nidana_contract_check {slug}... [--set {set},...] [--guarantee {id},...]
       fvm dart run nidana_contract_check --all [--set {set},...] [--guarantee {id},...]
sets: structure, surface, reject, behavior, schema, file, cli
ids: G{n} for the one slug named, or {slug}/G{n}''');
  });
  test('an id its slug does not declare is a usage error (64); a qualified id is checked against its own slug', () async {
    final Directory root = seed(<String, String>{...sampleFiles, ...toolFiles});
    final ProcessResult bare = await runTool(<String>[
      'sample',
      '--set',
      'structure',
      '--guarantee',
      'G9',
    ], workingDirectory: root);
    expect(bare.exitCode, 64, reason: all(bare));
    expect(
      bare.stderr as String,
      allOf(
        contains(
          "error: unknown guarantee 'sample/G9': hsdd/contract/sample.md declares no G9",
        ),
        contains('usage: '),
      ),
    );
    final ProcessResult other = await runTool(<String>[
      'sample',
      '--set',
      'structure',
      '--guarantee',
      'tool/G2',
    ], workingDirectory: root);
    expect(other.exitCode, 0, reason: all(other));
    final ProcessResult unknown = await runTool(<String>[
      'sample',
      '--set',
      'structure',
      '--guarantee',
      'tool/G3',
    ], workingDirectory: root);
    expect(unknown.exitCode, 64, reason: all(unknown));
    expect(
      unknown.stderr as String,
      contains(
        "unknown guarantee 'tool/G3': hsdd/contract/tool.md declares no G3",
      ),
    );
  });
  test('a package configuration that is not UTF-8 is not a package configuration (2)', () async {
    final Directory root = seed(sampleFiles);
    File('${root.path}/.dart_tool/package_config.json')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(<int>[0xff]);
    final StringBuffer err = StringBuffer();
    expect(
      await runCli(
        <String>['sample', '--set', 'surface'],
        workingDirectory: root,
        out: StringBuffer(),
        err: err,
      ),
      2,
    );
    expect(
      err.toString(),
      contains(
        'ERROR surface sample: .dart_tool/package_config.json is not a package configuration',
      ),
    );
  });

  // Beyond the brief: rules of the restriction's check that would otherwise
  // go unpinned.
  test('a slug the restriction names without a contract text declares nothing (64)', () async {
    final StringBuffer out = StringBuffer();
    final StringBuffer err = StringBuffer();
    expect(
      await runCli(
        <String>['sample', '--set', 'structure', '--guarantee', 'G1'],
        workingDirectory: seed(
          changed(sampleFiles, <String, String?>{
            'hsdd/contract/sample.md': null,
          }),
        ),
        out: out,
        err: err,
      ),
      64,
    );
    expect(
      err.toString(),
      "error: unknown guarantee 'sample/G1': no contract text at hsdd/contract/sample.md\n$usage\n",
    );
    expect(out.toString(), isEmpty);
  });
  test('the restriction is checked before any snapshot is read', () async {
    const String d = 'hsdd/contract/fixture/doc/';
    final Directory root = seed(docFiles);
    Link('${root.path}/${d}valid/gone.json').createSync('${root.path}/gone');
    Future<(int, String)> replay(String id) async {
      final StringBuffer err = StringBuffer();
      final int code = await runCli(
        <String>['doc', '--guarantee', id],
        workingDirectory: root,
        out: StringBuffer(),
        err: err,
      );
      return (code, err.toString());
    }

    final (int undeclared, String undeclaredErr) = await replay('G2');
    expect(undeclared, 64, reason: undeclaredErr);
    expect(
      undeclaredErr,
      contains(
        "error: unknown guarantee 'doc/G2': hsdd/contract/doc.md declares no G2",
      ),
    );
    final (int declared, String declaredErr) = await replay('G1');
    expect(declared, 2, reason: declaredErr);
    expect(declaredErr, contains('${d}valid/gone.json'));
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
  group('a symbolic link is a file of the snapshot', () {
    test('a top-level link to a directory fails the layout', () async {
      final Directory root = seed(sampleFiles);
      Link('${root.path}/${s}linked').createSync('${root.path}/${s}reject');
      final ProcessResult r = await runTool(<String>[
        'sample',
        '--set',
        'structure',
      ], workingDirectory: root);
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL structure ${s}linked: layout (linked is neither a set directory of kind api nor a data directory listed in ## Validation)',
        ),
      );
    });
    test('a linked reject library is read through the link', () async {
      final Directory root = seed(<String, String>{
        ...sampleFiles,
        'elsewhere/no_header.dart': sampleReject.replaceFirst(
          '// covers: G1\n',
          '',
        ),
      });
      Link('${root.path}/${s}reject/linked.dart')
          .createSync('${root.path}/elsewhere/no_header.dart');
      final ProcessResult r = await runTool(<String>[
        'sample',
        '--set',
        'structure',
      ], workingDirectory: root);
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL structure ${s}reject/linked.dart: covers-header (no // covers: header)',
        ),
      );
    });
  });
  group('the schema set', () {
    const String d = 'hsdd/contract/fixture/doc/';
    test('a clean doc slug passes with one line per fixture', () async {
      final ProcessResult r = await runTool(<String>[
        'doc',
      ], workingDirectory: seed(docFiles));
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r), <String>[
        'PASS structure hsdd/contract/doc.md',
        'PASS structure $d',
        'PASS schema hsdd/contract/schema/doc.schema.json',
        'PASS schema ${d}invalid/extra-property.json',
        'PASS schema ${d}invalid/negative-count.json',
        'PASS schema ${d}valid/minimal.json',
        '6 fixtures: 6 passed, 0 failed, 0 pending',
      ]);
    });
    test('a document that is not UTF-8 fails as a fixture, not as an environment error', () async {
      final Directory root = seed(docFiles);
      File('${root.path}/${d}valid/latin1.json')
          .writeAsBytesSync(<int>[0x7b, 0xff, 0x7d]);
      final ProcessResult r = await runTool(<String>[
        'doc',
        '--set',
        'schema',
      ], workingDirectory: root);
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL schema ${d}valid/latin1.json: document (not UTF-8: Invalid UTF-8 byte (at offset 1))',
        ),
      );
    });
    test("a structure failure does not stop the slug's other sets", () async {
      final ProcessResult r = await runTool(
        <String>['doc'],
        workingDirectory: seed(
          changed(docFiles, <String, String?>{
            'hsdd/contract/doc.md': docContract.replaceFirst(
              '- **G1**',
              '- **G2** uncovered.\n- **G1**',
            ),
          }),
        ),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        containsAll(<String>[
          'FAIL structure $d: coverage (G2 uncovered)',
          'PASS schema ${d}valid/minimal.json',
        ]),
      );
    });

    // Beyond the brief: rules of readSnapshot that would otherwise go unpinned.
    test('a hidden entry below valid/ is no document', () async {
      final ProcessResult r = await runTool(
        <String>['doc'],
        workingDirectory: seed(<String, String>{
          ...docFiles,
          '${d}valid/.DS_Store': 'x',
          '${d}invalid/.hidden/a.json': 'x',
        }),
      );
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r).last, '6 fixtures: 6 passed, 0 failed, 0 pending');
    });
    test('a file in a data directory is never read', () async {
      final Directory root = seed(<String, String>{
        ...docFiles,
        'hsdd/contract/doc.md': docContract.replaceFirst(
          '- invalid: ',
          '- render: `${d}render/`, renderings a conformance case reads.\n'
              '- invalid: ',
        ),
      });
      Directory('${root.path}/${d}render').createSync();
      Link('${root.path}/${d}render/gone.json').createSync('${root.path}/gone');
      final ProcessResult r = await runTool(<String>[
        'doc',
      ], workingDirectory: root);
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r).last, '6 fixtures: 6 passed, 0 failed, 0 pending');
    });
    test(
      'a dangling link below valid/ is read, so it is an environment error (2)',
      () async {
        final Directory root = seed(docFiles);
        Link('${root.path}/${d}valid/gone.json')
            .createSync('${root.path}/gone');
        final ProcessResult r = await runTool(<String>[
          'doc',
        ], workingDirectory: root);
        expect(r.exitCode, 2, reason: all(r));
        expect(r.stderr as String, contains('${d}valid/gone.json'));
      },
    );
    test('a linked document is read through the link', () async {
      final Directory root = seed(<String, String>{
        ...docFiles,
        'elsewhere/negative.json': '{"name": "a", "count": -1}\n',
      });
      Link('${root.path}/${d}valid/linked.json')
          .createSync('${root.path}/elsewhere/negative.json');
      final ProcessResult r = await runTool(<String>[
        'doc',
        '--set',
        'schema',
      ], workingDirectory: root);
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL schema ${d}valid/linked.json: valid (does not validate: /count: minimum violated (-1 < 0))',
        ),
      );
    });
  });

  // Beyond the brief: rules of the shell's one analysis that would otherwise
  // go unpinned.
  group('the one analysis of a replay', () {
    test('one dart analyze covers every slug of the request, its libraries ascending, PENDING ones left out', () async {
      final Directory root = seed(<String, String>{
        ...sampleFiles,
        '${s}surface/pending.dart': analysisFiles['${s}surface/pending.dart']!,
        for (final MapEntry<String, String> entry in sampleFiles.entries)
          entry.key.replaceFirst('sample', 'other'): entry.value,
        '.dart_tool/package_config.json': sampleConfiguration,
      });
      final ({String path, File calls}) dart = fakeDart(
        '{"version":1,"diagnostics":[]}',
      );
      final StringBuffer out = StringBuffer();
      expect(
        await runCli(
          <String>['sample', 'other', '--set', 'surface,reject'],
          workingDirectory: root,
          out: out,
          err: StringBuffer(),
          dart: dart.path,
        ),
        1,
      );
      expect(dart.calls.readAsLinesSync(), <String>[
        <String>[
          'analyze',
          '--fatal-infos',
          '--format=json',
          for (final String slug in <String>['other', 'sample'])
            for (final String library in <String>[
              'reject/sample_is_closed.dart',
              'surface/use.dart',
            ])
              '${root.path}/hsdd/contract/fixture/$slug/$library',
        ].join(' '),
      ]);
      expect(
        out.toString(),
        allOf(
          contains('PASS surface hsdd/contract/fixture/other/surface/use.dart'),
          contains('PASS surface ${s}surface/use.dart'),
        ),
      );
    });
    test(
      'bytes dart analyze prints that are not UTF-8 stop no replay',
      () async {
        final Directory root = seed(<String, String>{
          ...sampleFiles,
          '.dart_tool/package_config.json': sampleConfiguration,
        });
        final String dart = '${seed(const <String, String>{}).path}/dart';
        File(dart).writeAsStringSync(
          <String>[
            '#!/bin/sh',
            r"printf '\377\n'",
            r"printf '\377\n' >&2",
            """echo '{"version":1,"diagnostics":[]}'""",
            '',
          ].join('\n'),
        );
        final ProcessResult chmod = Process.runSync('chmod', <String>[
          '+x',
          dart,
        ]);
        expect(chmod.exitCode, 0, reason: all(chmod));
        final StringBuffer out = StringBuffer();
        final StringBuffer err = StringBuffer();
        expect(
          await runCli(
            <String>['sample', '--set', 'surface'],
            workingDirectory: root,
            out: out,
            err: err,
            dart: dart,
          ),
          0,
          reason: '$out$err',
        );
        expect(out.toString(), contains('PASS surface ${s}surface/use.dart\n'));
      },
    );
    test('a reported file no fixture claims is an environment error (2), never dropped', () async {
      final Directory root = seed(<String, String>{
        ...sampleFiles,
        '.dart_tool/package_config.json': sampleConfiguration,
      });
      final ({String path, File calls}) dart = fakeDart(
        '{"version":1,"diagnostics":[{"code":"unused_import","severity":"WARNING",'
        '"location":{"file":"/elsewhere/stray.dart","range":{"start":{"line":1}}},'
        '"problemMessage":"Unused import."}]}',
      );
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['sample', '--set', 'surface,reject'],
          workingDirectory: root,
          out: out,
          err: err,
          dart: dart.path,
        ),
        2,
      );
      expect(
        err.toString(),
        allOf(
          contains(
            'ERROR surface sample: dart analyze reported /elsewhere/stray.dart, which the replay did not ask it to analyze',
          ),
          contains(
            'ERROR reject sample: dart analyze reported /elsewhere/stray.dart, which the replay did not ask it to analyze',
          ),
        ),
      );
      expect(
        out.toString(),
        allOf(isNot(contains('PASS surface')), isNot(contains('PASS reject'))),
      );
    });
    test('a package configuration that is not one is a reason, and a replay without surface or reject never reads it', () async {
      final Directory root = seed(<String, String>{
        ...sampleFiles,
        '.dart_tool/package_config.json': 'not a package configuration\n',
      });
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['sample', '--set', 'surface,reject'],
          workingDirectory: root,
          out: StringBuffer(),
          err: err,
        ),
        2,
      );
      expect(
        err.toString(),
        allOf(
          contains(
            'ERROR surface sample: .dart_tool/package_config.json is not a package configuration',
          ),
          contains(
            'ERROR reject sample: .dart_tool/package_config.json is not a package configuration',
          ),
        ),
      );
      File('${root.path}/.dart_tool/package_config.json')
          .writeAsBytesSync(<int>[0xff]);
      final StringBuffer out = StringBuffer();
      expect(
        await runCli(
          <String>['sample', '--set', 'structure'],
          workingDirectory: root,
          out: out,
          err: StringBuffer(),
        ),
        0,
        reason: '$out',
      );
    });
    test('a library linked to another library gets its diagnostics; one linked outside the fixtures refuses the analysis (2)', () async {
      final String dirty = analysisFiles['${s}surface/dirty.dart']!;
      final Directory root = await seedWorkspace(<String, String>{
        ...sampleFiles,
        '${s}surface/dirty.dart': dirty,
        'elsewhere/outside.dart': dirty,
      });
      Link('${root.path}/${s}surface/shared.dart')
          .createSync('${root.path}/${s}surface/dirty.dart');
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['sample', '--set', 'surface'],
          workingDirectory: root,
          out: out,
          err: err,
        ),
        1,
        reason: '$out$err',
      );
      expect(
        out.toString().trimRight().split('\n'),
        containsAll(<String>[
          for (final String library in <String>['dirty', 'shared'])
            "FAIL surface ${s}surface/$library.dart: diagnostic (line 1: WARNING unused_import: Unused import: 'dart:async'.)",
          'PASS surface ${s}surface/use.dart',
        ]),
      );
      expect(err.toString(), isEmpty);
      Link('${root.path}/${s}surface/outside.dart')
          .createSync('${root.path}/elsewhere/outside.dart');
      final StringBuffer refusedOut = StringBuffer();
      final StringBuffer refused = StringBuffer();
      expect(
        await runCli(
          <String>['sample', '--set', 'surface'],
          workingDirectory: root,
          out: refusedOut,
          err: refused,
        ),
        2,
        reason: '$refusedOut$refused',
      );
      expect(
        refused.toString(),
        contains(
          'ERROR surface sample: ${s}surface/outside.dart is a symbolic link to '
          '${File('${root.path}/elsewhere/outside.dart').resolveSymbolicLinksSync()}, '
          'outside hsdd/contract/fixture/, so dart analyze does not apply the fixture analysis options',
        ),
      );
      expect(
        refusedOut.toString(),
        isNot(contains('surface ${s}surface/outside.dart')),
      );
    });
    test(
      'a hidden link directly under fixture/ is not part of the replay',
      () async {
        final Directory root = seed(sampleFiles);
        Link('${root.path}/hsdd/contract/fixture/.linked')
            .createSync('${root.path}/hsdd/contract/fixture/sample');
        final StringBuffer out = StringBuffer();
        expect(
          await runCli(
            <String>['--all', '--set', 'structure'],
            workingDirectory: root,
            out: out,
            err: StringBuffer(),
          ),
          0,
        );
        expect(out.toString().trimRight().split('\n'), cleanLines);
      },
    );
  });
  group('the one pub get of a replay', () {
    /// The lines of [calls], none when it was never written.
    List<String> callsOf(File calls) =>
        calls.existsSync() ? calls.readAsLinesSync() : const <String>[];
    const String unsatisfied =
        'dart pub get --enforce-lockfile exited 65: Unable to satisfy `pubspec.yaml` using `pubspec.lock`.';

    test('one dart pub get --enforce-lockfile runs at the root before the file or cli set, and never for the other sets', () async {
      final Directory root = await seedWorkspace(<String, String>{
        ...sampleFiles,
        ...toolFiles,
      }, standIn: false);
      final ({String dart, File calls}) rec = recordingDart();
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      await runCli(
        <String>['--all'],
        workingDirectory: root,
        out: out,
        err: err,
        dart: rec.dart,
      );
      final List<String> calls = callsOf(rec.calls);
      expect(calls.where((String line) => line.startsWith('pub ')), <String>[
        'pub get --enforce-lockfile',
      ]);
      expect(calls.first, 'pub get --enforce-lockfile');
      expect(
        err.toString().split('\n').first,
        'running dart pub get --enforce-lockfile',
      );
      // Beyond the brief: once pub get passed, the file set plans its replay
      // and the cli set its recorded invocation, each PENDING on tool's
      // absent generator, and the progress line is written once.
      expect(
        out.toString(),
        allOf(
          contains(
            'PENDING file hsdd/contract/fixture/tool/expected/: package tool is absent from .dart_tool/package_config.json\n',
          ),
          contains(
            'PENDING cli hsdd/contract/fixture/tool/invocation/generate-usage/: package tool is absent from .dart_tool/package_config.json\n',
          ),
        ),
      );
      expect(
        err.toString(),
        allOf(isNot(contains('ERROR file ')), isNot(contains('ERROR cli '))),
      );
      expect(
        'running dart pub get'.allMatches(err.toString()),
        hasLength(1),
        reason: '$err',
      );

      final ({String dart, File calls}) other = recordingDart();
      final StringBuffer otherErr = StringBuffer();
      await runCli(
        <String>['--all', '--set', 'structure,surface,reject,behavior,schema'],
        workingDirectory: root,
        out: StringBuffer(),
        err: otherErr,
        dart: other.dart,
      );
      expect(
        callsOf(other.calls).where((String line) => line.startsWith('pub ')),
        isEmpty,
      );
      expect(otherErr.toString(), isNot(contains('running dart pub get')));
    });
    test('a failing pub get makes every file and cli set unavailable with its reason (2), and the other sets still print', () async {
      final Directory root = seed(<String, String>{
        ...sampleFiles,
        ...toolFiles,
      });
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['tool'],
          workingDirectory: root,
          out: out,
          err: err,
          dart: recordingDart(pubFails: true).dart,
        ),
        2,
      );
      expect(
        err.toString(),
        allOf(
          contains('ERROR file tool: $unsatisfied'),
          contains('ERROR cli tool: $unsatisfied'),
        ),
      );
      expect(out.toString(), contains('PASS structure hsdd/contract/tool.md'));
    });
    test(
      'without a lockfile the real pub get fails, and the replay exits 2',
      () async {
        final Directory root = await seedWorkspace(toolFiles, standIn: false);
        File('${root.path}/pubspec.lock').deleteSync();
        final ProcessResult r = await runTool(<String>[
          'tool',
          '--set',
          'file',
        ], workingDirectory: root);
        expect(r.exitCode, 2, reason: all(r));
        expect(
          r.stderr as String,
          contains(
            'ERROR file tool: dart pub get --enforce-lockfile exited 1: Retrieving dependencies failed.',
          ),
        );
      },
    );

    // Beyond the brief: a dart that cannot start is the reason of every
    // command set, and one pub get serves every slug of the replay.
    test(
      'a pub get that cannot start is the reason of every file and cli set (2)',
      () async {
        final Directory root = seed(<String, String>{
          ...sampleFiles,
          ...toolFiles,
        });
        final String missing = '${root.path}/no-such-dart';
        final StringBuffer out = StringBuffer();
        final StringBuffer err = StringBuffer();
        expect(
          await runCli(
            <String>['tool'],
            workingDirectory: root,
            out: out,
            err: err,
            dart: missing,
          ),
          2,
        );
        expect(
          err.toString(),
          allOf(
            startsWith('running dart pub get --enforce-lockfile\n'),
            contains('ERROR file tool: could not run $missing: '),
            contains('ERROR cli tool: could not run $missing: '),
          ),
        );
        expect(
          out.toString(),
          contains('PASS structure hsdd/contract/tool.md'),
        );
      },
    );
    test(
      'one pub get serves every slug whose file or cli set the replay runs',
      () async {
        final Directory root = seed(<String, String>{
          ...toolFiles,
          for (final MapEntry<String, String>(:String key, :String value)
              in toolFiles.entries)
            key.replaceFirst('tool', 'other'): value.replaceAll(
              'tool',
              'other',
            ),
        });
        final ({String dart, File calls}) rec = recordingDart(pubFails: true);
        final StringBuffer err = StringBuffer();
        expect(
          await runCli(
            <String>['--all', '--set', 'cli'],
            workingDirectory: root,
            out: StringBuffer(),
            err: err,
            dart: rec.dart,
          ),
          2,
        );
        expect(callsOf(rec.calls), <String>['pub get --enforce-lockfile']);
        expect(
          err.toString(),
          allOf(
            contains('ERROR cli other: $unsatisfied'),
            contains('ERROR cli tool: $unsatisfied'),
            isNot(contains('ERROR file ')),
          ),
        );
      },
    );
    test('a package configuration with a root that is no plain file: URI is no package configuration (2)', () async {
      final Directory root = seed(<String, String>{
        ...sampleFiles,
        '.dart_tool/package_config.json':
            '{"configVersion": 2, "packages": [{"name": "sample", '
            '"rootUri": "http://cache.example/sample/", "packageUri": "lib/"}]}\n',
      });
      final ProcessResult r = await runTool(<String>[
        'sample',
        '--set',
        'behavior',
      ], workingDirectory: root);
      expect(r.exitCode, 2, reason: all(r));
      expect(
        r.stderr as String,
        contains(
          'ERROR behavior sample: .dart_tool/package_config.json is not a package configuration',
        ),
      );
    });
  });
}
