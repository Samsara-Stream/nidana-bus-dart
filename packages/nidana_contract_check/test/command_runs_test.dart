import 'dart:convert';
import 'dart:io';

import 'package:nidana_contract_check/src/cli_set.dart';
import 'package:nidana_contract_check/src/command.dart';
import 'package:nidana_contract_check/src/command_runs.dart';
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/shell.dart';
import 'package:nidana_contract_check/src/tree.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/generator.dart';
import 'support/runners.dart';
import 'support/sample.dart';
import 'support/seed.dart';
import 'support/workspace.dart';

List<String> lines(ProcessResult r) =>
    (r.stdout as String).trimRight().split('\n');
String all(ProcessResult r) => '${r.stdout}${r.stderr}';

/// The lines of [r]'s stderr; empty when it printed none.
List<String> errLines(ProcessResult r) =>
    switch ((r.stderr as String).trimRight()) {
      '' => const <String>[],
      final String text => text.split('\n'),
    };

const String g = 'hsdd/contract/fixture/gen/';
const List<String> genStructure = <String>[
  'PASS structure hsdd/contract/gen.md',
  'PASS structure hsdd/contract/fixture/gen/',
];

/// The `gen` slug with [changes] in a seeded workspace whose one member is the stand-in
/// generator package `gen`.
Future<Directory> genWorkspace([
  Map<String, String?> changes = const <String, String?>{},
]) =>
    seedWorkspace(changed(genFiles, changes), standIn: false, generator: true);

/// [tree] shown for comparison: each file's bytes, or `unreadable: {reason}`.
Map<String, Object> shown(FileTree tree) => <String, Object>{
  for (final MapEntry<String, FileEntry>(:String key, :FileEntry value)
      in tree.entries)
    key: switch (value) {
      FileBytes(:final List<int> bytes) => bytes,
      FileUnreadable(:final String reason) => 'unreadable: $reason',
    },
};

/// An executable shell script named `dart` in a fresh temporary directory, its lines [body]
/// after `#!/bin/sh`.
String scriptDart(List<String> body) {
  final String dart = p.join(seed(const <String, String>{}).path, 'dart');
  File(dart).writeAsStringSync(<String>['#!/bin/sh', ...body, ''].join('\n'));
  final ProcessResult chmod = Process.runSync('chmod', <String>['+x', dart]);
  expect(chmod.exitCode, 0, reason: all(chmod));
  return dart;
}

/// [text] single-quoted for `sh`.
String quoted(String text) => "'${text.replaceAll("'", r"'\''")}'";

/// Runs `chmod {mode} {path}` and expects it to pass.
void chmod(String mode, String path) {
  final ProcessResult r = Process.runSync('chmod', <String>[mode, path]);
  expect(r.exitCode, 0, reason: all(r));
}

void main() {
  group('the file set', () {
    test('readTree reads every file below a directory, hidden ones included, and nothing for a path that is no directory', () {
      final Directory root = seed(const <String, String>{
        'a.txt': 'a',
        'sub/.hidden': 'h',
        '.dot/b.txt': 'b',
      });
      final FileTree tree = readTree(root);
      expect(shown(tree), <String, Object>{
        'a.txt': utf8.encode('a'),
        'sub/.hidden': utf8.encode('h'),
        '.dot/b.txt': utf8.encode('b'),
      });
      expect(readTree(Directory('${root.path}/a.txt')), isEmpty);
      expect(readTree(Directory('${root.path}/absent')), isEmpty);
      // Beyond the brief: the tree is a value, built once.
      expect(
        () => tree['c.txt'] = const FileBytes(<int>[]),
        throwsUnsupportedError,
      );
    });
    test('the generator\'s tree, formatted, equals expected/', () async {
      final ProcessResult r = await runTool(<String>[
        'gen',
        '--set',
        'file',
      ], workingDirectory: await genWorkspace());
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r), <String>[
        ...genStructure,
        'PASS file ${g}expected/',
        '3 fixtures: 3 passed, 0 failed, 0 pending',
      ]);
      expect(errLines(r), <String>[
        'running dart pub get --enforce-lockfile',
        'running file ${g}expected/',
      ]);
    });
    test('one changed byte fails it', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'file'],
        workingDirectory: await genWorkspace(<String, String?>{
          '${g}expected/notes.txt': 'from Hello\n',
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL file ${g}expected/: changed-file (notes.txt: first difference at byte 5)',
        ),
      );
    });
    test('a missing file fails it', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'file'],
        workingDirectory: await genWorkspace(<String, String?>{
          '${g}expected/more.txt': 'more\n',
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains('FAIL file ${g}expected/: missing-file (more.txt)'),
      );
    });
    test('an extra file fails it', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'file'],
        workingDirectory: await genWorkspace(<String, String?>{
          '${g}expected/notes.txt': null,
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains('FAIL file ${g}expected/: extra-file (notes.txt)'),
      );
    });
    test('a hidden file in expected/ is part of the comparison', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'file'],
        workingDirectory: await genWorkspace(<String, String?>{
          '${g}expected/.keep': '',
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains('FAIL file ${g}expected/: missing-file (.keep)'),
      );
    });
    test('a generator that exits non-zero fails it, even when its tree is right', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'file'],
        workingDirectory: await genWorkspace(<String, String?>{
          'hsdd/contract/gen.md': genContract.replaceFirst(
            'gen:generate {input}',
            'gen:generate --write-then-fail {input}',
          ),
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL file ${g}expected/: exit (the generator exited 1: failed after writing)',
        ),
      );
    });
    test('a generator package the workspace lacks is PENDING, and nothing runs', () async {
      final ProcessResult r = await runTool(<String>[
        'gen',
        '--set',
        'file',
      ], workingDirectory: await seedWorkspace(genFiles, standIn: false));
      expect(r.exitCode, 1, reason: all(r));
      expect(lines(r), <String>[
        ...genStructure,
        'PENDING file ${g}expected/: package gen is absent from .dart_tool/package_config.json',
        '3 fixtures: 2 passed, 0 failed, 1 pending',
      ]);
      expect(errLines(r), <String>['running dart pub get --enforce-lockfile']);
    });
    test('the restriction admits it only when every id it covers is restricted', () async {
      final Directory root = await genWorkspace();
      final ProcessResult admitted = await runTool(<String>[
        'gen',
        '--set',
        'file',
        '--guarantee',
        'G1',
      ], workingDirectory: root);
      expect(admitted.exitCode, 0, reason: all(admitted));
      expect(lines(admitted), <String>[
        ...genStructure,
        'PASS file ${g}expected/',
        '3 fixtures: 3 passed, 0 failed, 0 pending',
      ]);
      expect(errLines(admitted), <String>[
        'running dart pub get --enforce-lockfile',
        'running file ${g}expected/',
      ]);
      final ProcessResult unadmitted = await runTool(<String>[
        'gen',
        '--set',
        'file',
        '--guarantee',
        'G2',
      ], workingDirectory: root);
      expect(unadmitted.exitCode, 0, reason: all(unadmitted));
      expect(
        lines(unadmitted),
        contains(
          'PASS file ${g}expected/: not run: the restriction does not admit all of G1',
        ),
      );
      // pub get still runs: the restriction admits no file replay, and the
      // replay holds the set.
      expect(errLines(unadmitted), <String>[
        'running dart pub get --enforce-lockfile',
      ]);
    });

    // Beyond the brief: the processes the replay starts, and where.
    test('the generator writes into a fresh, empty {t}/output from the root, dart format formats it from the root, and {t} is deleted after', () async {
      final Directory root = await genWorkspace();
      final String dart = scriptDart(<String>[
        r'''printf '%s|%s\n' "$(pwd -P)" "$*" >> "$0.calls"''',
        r'if [ "$1" = run ]; then',
        r'  for last; do :; done',
        r'''  if [ -d "$last" ] && [ -z "$(ls -A "$last")" ]; then echo "$last is an empty directory"; else echo "$last is no empty directory"; fi >> "$0.calls"''',
        'fi',
        'exec ${quoted(Platform.resolvedExecutable)} "\$@"',
      ]);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'file'],
          workingDirectory: root,
          out: out,
          err: err,
          dart: dart,
        ),
        0,
        reason: '$out$err',
      );
      expect(out.toString(), contains('PASS file ${g}expected/\n'));
      final String resolvedRoot = root.resolveSymbolicLinksSync();
      final List<String> calls = File('$dart.calls').readAsLinesSync();
      expect(calls, hasLength(4), reason: calls.join('\n'));
      expect(calls[0], '$resolvedRoot|pub get --enforce-lockfile');
      final RegExpMatch? generator = RegExp(
        r'^(.*)\|run gen:generate (\S+) (\S+)$',
      ).firstMatch(calls[1]);
      expect(generator, isNotNull, reason: calls[1]);
      expect(generator![1], resolvedRoot);
      expect(generator[2], '${root.path}/${g}input/word.txt');
      final String output = generator[3]!;
      expect(p.basename(output), 'output');
      expect(
        p.basename(p.dirname(output)),
        startsWith('ncc_file_'),
        reason: output,
      );
      expect(p.dirname(p.dirname(output)), Directory.systemTemp.path);
      expect(calls[2], '$output is an empty directory');
      expect(calls[3], '$resolvedRoot|format $output');
      expect(Directory(p.dirname(output)).existsSync(), isFalse);
    });
    test('a generator that writes Dart that does not parse fails on dart format, beside the trees', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'file'],
        workingDirectory: await genWorkspace(<String, String?>{
          '${g}input/word.txt': "it's\n",
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL file ${g}expected/: format (dart format exited 65: Could not format because the source could not be parsed:); '
          'changed-file (notes.txt: first difference at byte 5); '
          'changed-file (out.dart: first difference at byte 5)',
        ),
      );
    });
    test('a generator that cannot start makes the slug\'s file set unavailable (2)', () async {
      final Directory root = await genWorkspace();
      // pub get passes and removes the script, so the generator cannot start.
      final String dart = scriptDart(<String>[
        r'[ "$1" = pub ] && { rm -f "$0"; exit 0; }',
        'exit 3',
      ]);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'file'],
          workingDirectory: root,
          out: out,
          err: err,
          dart: dart,
        ),
        2,
        reason: '$out$err',
      );
      expect(
        err.toString(),
        allOf(
          contains('running file ${g}expected/\n'),
          contains('ERROR file gen: could not run $dart: '),
        ),
      );
      expect(out.toString().trimRight().split('\n'), <String>[
        ...genStructure,
        '2 fixtures: 2 passed, 0 failed, 0 pending',
      ]);
    });
    test('pub get runs, and its failure makes the file set unavailable (2), even when the restriction admits no file replay', () async {
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'file', '--guarantee', 'G2'],
          workingDirectory: seed(genFiles),
          out: out,
          err: err,
          dart: recordingDart(pubFails: true).dart,
        ),
        2,
        reason: '$out$err',
      );
      expect(
        err.toString(),
        allOf(
          startsWith('running dart pub get --enforce-lockfile\n'),
          contains(
            'ERROR file gen: dart pub get --enforce-lockfile exited 65: Unable to satisfy `pubspec.yaml` using `pubspec.lock`.',
          ),
          isNot(contains('running file ')),
        ),
      );
    });
    test('a directory the generator leaves unreadable fails the replay, and the {t} that cannot be deleted stays behind, a progress line', () async {
      final Directory root = await genWorkspace();
      final String dart = scriptDart(<String>[
        r'if [ "$1" = run ]; then',
        r'  for last; do :; done',
        r'''  mkdir "$last/locked" && echo x > "$last/locked/x" && chmod 000 "$last/locked"''',
        r'''  echo "$last" >> "$0.outputs"''',
        'fi',
        'exit 0',
      ]);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      final int code = await runCli(
        <String>['gen', '--set', 'file'],
        workingDirectory: root,
        out: out,
        err: err,
        dart: dart,
      );
      final String output = File('$dart.outputs').readAsStringSync().trim();
      addTearDown(() {
        chmod('755', '$output/locked');
        Directory(p.dirname(output)).deleteSync(recursive: true);
      });
      expect(code, 1, reason: '$out$err');
      // The OS words the reason: pinned by its prefix.
      expect(
        out.toString(),
        matches(
          RegExp(
            '^FAIL file ${RegExp.escape(g)}expected/: '
            r'unreadable-file \(locked in output: Directory listing failed: [^;]+\); '
            r'extra-file \(locked\); missing-file \(notes\.txt\); missing-file \(out\.dart\)$',
            multiLine: true,
          ),
        ),
      );
      expect(
        err.toString().trimRight().split('\n'),
        contains(startsWith('could not delete ${p.dirname(output)}: ')),
      );
      expect(Directory(output).existsSync(), isTrue);
    }, skip: skipAsSuperuser);
    test('a qualified id {slug}/G{n} admits it as the bare id does', () async {
      final ProcessResult r = await runTool(<String>[
        'gen',
        '--set',
        'file',
        '--guarantee',
        'gen/G1',
      ], workingDirectory: await genWorkspace());
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r), <String>[
        ...genStructure,
        'PASS file ${g}expected/',
        '3 fixtures: 3 passed, 0 failed, 0 pending',
      ]);
      expect(errLines(r), <String>[
        'running dart pub get --enforce-lockfile',
        'running file ${g}expected/',
      ]);
    });
  });
  group('the cli set', () {
    const String i = '${g}invocation/';
    const String absentGen =
        'package gen is absent from .dart_tool/package_config.json';
    const List<String> passes = <String>[
      'PASS cli ${i}analyze-lib/',
      'PASS cli ${i}generate-from-files/',
      'PASS cli ${i}generate-tree/',
      'PASS cli ${i}generate-usage/',
    ];
    const List<String> clean = <String>[
      ...genStructure,
      ...passes,
      '6 fixtures: 6 passed, 0 failed, 0 pending',
    ];
    const List<String> running = <String>[
      'running dart pub get --enforce-lockfile',
      'running cli ${i}analyze-lib/',
      'running cli ${i}generate-from-files/',
      'running cli ${i}generate-tree/',
      'running cli ${i}generate-usage/',
    ];

    /// A row of the Case table.
    String row(String name, String command, int exit, String covers) =>
        '| `$name` | `$command` | $exit | $covers |';

    /// [genContract] with [rows] appended to its Case table, which ends the text.
    String withRows(List<String> rows) =>
        '$genContract${rows.map((String row) => '$row\n').join()}';

    test('the clean cases pass: exit codes, streams with {output}, {files} and {root}, and the trees at {output}', () async {
      final ProcessResult r = await runTool(<String>[
        'gen',
        '--set',
        'cli',
      ], workingDirectory: await genWorkspace());
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r), clean);
      expect(errLines(r), running);
    });
    test('a wrong exit code fails the case', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'cli'],
        workingDirectory: await genWorkspace(<String, String?>{
          '${i}generate-usage/exit_code': '0\n',
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains('FAIL cli ${i}generate-usage/: exit (exited 2, expected 0)'),
      );
    });
    test('output left at {output} fails a case without expected/', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'cli'],
        workingDirectory: await genWorkspace(<String, String?>{
          'hsdd/contract/gen.md': withRows(<String>[
            row(
              'generate-leaves-output',
              'gen:generate --write-then-fail hsdd/contract/fixture/gen/input/word.txt {output}',
              1,
              'G2',
            ),
          ]),
          '${i}generate-leaves-output/args': 'gen:generate\n--write-then-fail\nhsdd/contract/fixture/gen/input/word.txt\n{output}\n',
          '${i}generate-leaves-output/exit_code': '1\n',
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL cli ${i}generate-leaves-output/: output ({output} exists after the run, expected nothing there: notes.txt, out.dart)',
        ),
      );
    });
    test('a stream that differs fails the case at its first differing line', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'cli'],
        workingDirectory: await genWorkspace(<String, String?>{
          '${i}generate-tree/stdout':
              'wrote {output}\ncwd {files}\nresolved {output}\n',
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL cli ${i}generate-tree/: stdout (line 2: expected "cwd {files}", got "cwd {root}")',
        ),
      );
    });
    test('the tree at {output} is compared with expected/ as the file set compares', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'cli'],
        workingDirectory: await genWorkspace(<String, String?>{
          '${i}generate-tree/expected/notes.txt': 'from Hello\n',
        }),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(
        lines(r),
        contains(
          'FAIL cli ${i}generate-tree/: changed-file (notes.txt: first difference at byte 5)',
        ),
      );
    });
    test('a package the command runs, a plugin included, that the workspace lacks is PENDING, and the rest runs', () async {
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'cli'],
        workingDirectory: await seedWorkspace(
          changed(genFiles, <String, String?>{
            'hsdd/contract/gen.md': withRows(<String>[
              row('analyze-plugin', 'dart analyze .', 0, 'G5'),
            ]),
            '${i}analyze-plugin/args': 'dart\nanalyze\n.\n',
            '${i}analyze-plugin/exit_code': '0\n',
            '${i}analyze-plugin/files/analysis_options.yaml':
                'plugins:\n  absent_lint:\n    path: ../absent_lint\n',
          }),
          standIn: false,
        ),
      );
      expect(r.exitCode, 1, reason: all(r));
      expect(lines(r), <String>[
        ...genStructure,
        'PASS cli ${i}analyze-lib/',
        'PENDING cli ${i}analyze-plugin/: package absent_lint is absent from .dart_tool/package_config.json',
        'PENDING cli ${i}generate-from-files/: $absentGen',
        'PENDING cli ${i}generate-tree/: $absentGen',
        'PENDING cli ${i}generate-usage/: $absentGen',
        '7 fixtures: 3 passed, 0 failed, 4 pending',
      ]);
      expect(errLines(r), <String>[
        'running dart pub get --enforce-lockfile',
        'running cli ${i}analyze-lib/',
      ]);
    });
    test('the restriction runs a case only when every id it covers is restricted', () async {
      final ProcessResult r = await runTool(<String>[
        'gen',
        '--set',
        'cli',
        '--guarantee',
        'G2',
      ], workingDirectory: await genWorkspace());
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r), <String>[
        ...genStructure,
        'PASS cli ${i}analyze-lib/: not run: the restriction does not admit all of G5',
        'PASS cli ${i}generate-from-files/: not run: the restriction does not admit all of G4',
        'PASS cli ${i}generate-tree/: not run: the restriction does not admit all of G1, G3',
        'PASS cli ${i}generate-usage/',
        '6 fixtures: 6 passed, 0 failed, 0 pending',
      ]);
      expect(errLines(r), <String>[
        'running dart pub get --enforce-lockfile',
        'running cli ${i}generate-usage/',
      ]);
    });
    test('flutter runs as the flutter beside the running dart, and its absence is an environment error', () async {
      final Directory root = await genWorkspace(<String, String?>{
        'hsdd/contract/gen.md': withRows(<String>[
          row('flutter-version', 'flutter --version', 64, 'G5'),
        ]),
        '${i}flutter-version/args': 'flutter\n--version\n',
        '${i}flutter-version/exit_code': '64\n',
        '${i}flutter-version/stderr':
            'stand-in flutter: expected test --no-pub\n',
      });
      final ({String dart, File flutterCalls}) sdk = standInSdk();
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'cli'],
          workingDirectory: root,
          out: out,
          err: err,
          dart: sdk.dart,
        ),
        0,
        reason: '$out$err',
      );
      expect(out.toString(), contains('PASS cli ${i}flutter-version/\n'));
      expect(sdk.flutterCalls.readAsLinesSync(), <String>['--version']);

      final String dart = plainDart();
      final StringBuffer plainOut = StringBuffer();
      final StringBuffer plainErr = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'cli'],
          workingDirectory: root,
          out: plainOut,
          err: plainErr,
          dart: dart,
        ),
        2,
        reason: '$plainOut$plainErr',
      );
      expect(
        plainErr.toString(),
        allOf(
          contains(
            'ERROR cli gen: no flutter in the Flutter SDK of $dart; ${i}flutter-version/ runs flutter\n',
          ),
          isNot(contains('running cli ')),
        ),
      );
    });
    test(
      'a workspace whose resolution reads stale still runs every case',
      () async {
        final Directory root = await genWorkspace();
        File(
          '${root.path}/packages/gen/pubspec.yaml',
        ).setLastModifiedSync(DateTime.now().add(const Duration(seconds: 10)));
        final ProcessResult r = await runTool(<String>[
          'gen',
          '--set',
          'cli',
        ], workingDirectory: root);
        expect(r.exitCode, 0, reason: all(r));
        expect(lines(r), clean);
        // Beyond the brief: the workspace still reads stale after the replay's
        // pub get, so dart run from files/ fails as decision 1 says (K2, Q5).
        final ProcessResult run = await Process.run(
          Platform.resolvedExecutable,
          <String>[
            'run',
            'gen:generate',
            'word.txt',
            '${seed(const <String, String>{}).path}/output',
          ],
          workingDirectory: '${root.path}/${i}generate-from-files/files',
        );
        expect(run.exitCode, 255, reason: all(run));
      },
    );
    test('from a symbolic link to the workspace root, the placeholders still apply', () async {
      final Directory root = await genWorkspace();
      final Link link = Link('${seed(const <String, String>{}).path}/linked')
        ..createSync(root.path);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'cli'],
          workingDirectory: Directory(link.path),
          out: out,
          err: err,
        ),
        0,
        reason: '$out$err',
      );
      expect(out.toString().trimRight().split('\n'), containsAll(passes));
    });

    // Beyond the brief: the placeholders' order, the processes the set
    // starts and where, the set's environment errors, what may be at
    // {output}, and the {t} that cannot be deleted.
    test('a root whose given path its resolved path holds, as /var/... in /private/var/...: the longer form goes first', () async {
      final Directory root = await genWorkspace();
      final String base = seed(const <String, String>{}).path;
      // Resolved, the root is {base}/private{base}/ws, which ends with the
      // path it is given by, {base}/ws: whatever the system temporary
      // directory, the given form of the root, of files/ and of the
      // working directory lies inside the resolved one.
      final String real = '$base/private$base/ws';
      Directory(p.dirname(real)).createSync(recursive: true);
      root.renameSync(real);
      addTearDown(() => Directory(real).renameSync(root.path));
      final Link link = Link('$base/ws')..createSync(real);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'cli'],
          workingDirectory: Directory(link.path),
          out: out,
          err: err,
        ),
        0,
        reason: '$out$err',
      );
      expect(out.toString().trimRight().split('\n'), clean);
    });
    test('an {output} below the root, through a symbolic link, reads as {output}: {output} is replaced first, in both its forms', () async {
      final Directory root = await genWorkspace();
      // The system temporary directory of the tool is {root}/tmp-link, a
      // link to {root}/tmp: {output} is given below the one and resolves
      // below the other, both below the root as the tool finds it.
      final String resolved = root.resolveSymbolicLinksSync();
      final Directory temporary = Directory('$resolved/tmp')..createSync();
      final Link link = Link('$resolved/tmp-link')..createSync(temporary.path);
      final ProcessResult r = await runTool(
        <String>['gen', '--set', 'cli'],
        workingDirectory: root,
        environment: <String, String>{'TMPDIR': link.path},
      );
      expect(r.exitCode, 0, reason: all(r));
      expect(lines(r), clean);
      expect(temporary.listSync(), isEmpty);
    });
    test('each case runs from its files/ or the root, {package}:{executable} as its script under the running dart, {output} absent when it starts; dart format runs from the root for a case with expected/; each {t} is deleted after', () async {
      final Directory root = await genWorkspace();
      final String dart = scriptDart(<String>[
        r'''printf '%s|%s\n' "$(pwd -P)" "$*" >> "$0.calls"''',
        r'case "$1" in --packages=*)',
        r'  for last; do :; done',
        r'''  if [ -e "$last" ] || [ -L "$last" ]; then echo "$last exists"; else echo "$last is absent"; fi >> "$0.calls" ;;''',
        'esac',
        'exec ${quoted(Platform.resolvedExecutable)} "\$@"',
      ]);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'cli'],
          workingDirectory: root,
          out: out,
          err: err,
          dart: dart,
        ),
        0,
        reason: '$out$err',
      );
      final String resolved = root.resolveSymbolicLinksSync();
      final String script =
          '--packages=${root.path}/.dart_tool/package_config.json '
          '${root.path}/packages/gen/bin/generate.dart';
      final List<String> calls = File('$dart.calls').readAsLinesSync();
      final List<String> outputs = <String>[
        for (final String call in calls)
          if (RegExp(r'^(\S+) is absent$').firstMatch(call) case final match?)
            match[1]!,
      ];
      expect(outputs, hasLength(3), reason: calls.join('\n'));
      for (final String output in outputs) {
        expect(p.basename(output), 'output');
        expect(
          p.basename(p.dirname(output)),
          startsWith('ncc_cli_'),
          reason: output,
        );
        expect(p.dirname(p.dirname(output)), Directory.systemTemp.path);
        expect(Directory(p.dirname(output)).existsSync(), isFalse);
      }
      expect(calls, <String>[
        '$resolved|pub get --enforce-lockfile',
        '$resolved/${i}analyze-lib/files|analyze --format=machine .',
        '$resolved/${i}generate-from-files/files|$script word.txt ${outputs[0]}',
        '${outputs[0]} is absent',
        '$resolved|format ${outputs[0]}',
        '$resolved|$script --echo hsdd/contract/fixture/gen/input/word.txt ${outputs[1]}',
        '${outputs[1]} is absent',
        '$resolved|format ${outputs[1]}',
        '$resolved|$script --frob ${outputs[2]}',
        '${outputs[2]} is absent',
      ]);
    });
    test('what is at {output} after the run: a file or a link is a file, and nothing is nothing', () async {
      final Directory root = await genWorkspace(<String, String?>{
        'hsdd/contract/gen.md': withRows(<String>[
          row('write-file', 'dart write-file {output}', 0, 'G2'),
          row('write-link', 'dart write-link {output}', 0, 'G2'),
          row('write-nothing', 'dart write-nothing {output}', 0, 'G1'),
        ]),
        '${i}write-file/args': 'dart\nwrite-file\n{output}\n',
        '${i}write-file/exit_code': '0\n',
        '${i}write-link/args': 'dart\nwrite-link\n{output}\n',
        '${i}write-link/exit_code': '0\n',
        '${i}write-nothing/args': 'dart\nwrite-nothing\n{output}\n',
        '${i}write-nothing/exit_code': '0\n',
        '${i}write-nothing/expected/out.dart': genOutDart,
      });
      final String dart = scriptDart(<String>[
        r'case "$1" in',
        r'  write-file) echo x > "$2"; exit 0 ;;',
        r'  write-link) ln -s "$PWD" "$2"; exit 0 ;;',
        '  write-nothing) exit 0 ;;',
        'esac',
        'exec ${quoted(Platform.resolvedExecutable)} "\$@"',
      ]);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'cli'],
          workingDirectory: root,
          out: out,
          err: err,
          dart: dart,
        ),
        1,
        reason: '$out$err',
      );
      expect(out.toString().trimRight().split('\n'), <String>[
        ...genStructure,
        ...passes,
        'FAIL cli ${i}write-file/: output ({output} is a file, expected nothing there)',
        'FAIL cli ${i}write-link/: output ({output} is a file, expected nothing there)',
        'FAIL cli ${i}write-nothing/: output (nothing at {output}, expected the tree of expected/)',
        '9 fixtures: 6 passed, 3 failed, 0 pending',
      ]);
    });
    test('a command that cannot start makes the slug\'s cli set unavailable (2), and no case after it starts', () async {
      final Directory root = await genWorkspace();
      // pub get passes and removes the script, so no case can start.
      final String dart = scriptDart(<String>[
        r'[ "$1" = pub ] && { rm -f "$0"; exit 0; }',
        'exit 3',
      ]);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'cli'],
          workingDirectory: root,
          out: out,
          err: err,
          dart: dart,
        ),
        2,
        reason: '$out$err',
      );
      final List<String> errors = err.toString().trimRight().split('\n');
      expect(errors, hasLength(3), reason: '$err');
      expect(errors.take(2), <String>[
        'running dart pub get --enforce-lockfile',
        'running cli ${i}analyze-lib/',
      ]);
      expect(errors.last, startsWith('ERROR cli gen: could not run $dart: '));
      expect(out.toString().trimRight().split('\n'), <String>[
        ...genStructure,
        '2 fixtures: 2 passed, 0 failed, 0 pending',
      ]);
    });
    test('pub get runs, and its failure makes the cli set unavailable (2), even when the restriction admits no case', () async {
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      expect(
        await runCli(
          <String>['gen', '--set', 'cli', '--guarantee', 'G1'],
          workingDirectory: seed(genFiles),
          out: out,
          err: err,
          dart: recordingDart(pubFails: true).dart,
        ),
        2,
        reason: '$out$err',
      );
      expect(
        err.toString(),
        allOf(
          startsWith('running dart pub get --enforce-lockfile\n'),
          contains(
            'ERROR cli gen: dart pub get --enforce-lockfile exited 65: Unable to satisfy `pubspec.yaml` using `pubspec.lock`.',
          ),
          isNot(contains('running cli ')),
        ),
      );
    });
    test(
      'a qualified id {slug}/G{n} admits a case as the bare id does',
      () async {
        final ProcessResult r = await runTool(<String>[
          'gen',
          '--set',
          'cli',
          '--guarantee',
          'gen/G2',
        ], workingDirectory: await genWorkspace());
        expect(r.exitCode, 0, reason: all(r));
        expect(lines(r), contains('PASS cli ${i}generate-usage/'));
        expect(errLines(r), <String>[
          'running dart pub get --enforce-lockfile',
          'running cli ${i}generate-usage/',
        ]);
      },
    );
    test('a directory a command leaves at {output} that cannot be listed fails the case, and the {t} that cannot be deleted is a progress line', () async {
      final Directory root = await genWorkspace(<String, String?>{
        'hsdd/contract/gen.md': withRows(<String>[
          row('lock-output', 'dart lock {output}', 0, 'G2'),
        ]),
        '${i}lock-output/args': 'dart\nlock\n{output}\n',
        '${i}lock-output/exit_code': '0\n',
      });
      final String dart = scriptDart(<String>[
        r'if [ "$1" = lock ]; then',
        r'''  mkdir -p "$2/locked" && echo x > "$2/locked/x" && chmod 000 "$2/locked"''',
        r'''  echo "$2" >> "$0.outputs"''',
        '  exit 0',
        'fi',
        'exec ${quoted(Platform.resolvedExecutable)} "\$@"',
      ]);
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      final int code = await runCli(
        <String>['gen', '--set', 'cli'],
        workingDirectory: root,
        out: out,
        err: err,
        dart: dart,
      );
      final String output = File('$dart.outputs').readAsStringSync().trim();
      addTearDown(() {
        chmod('755', '$output/locked');
        Directory(p.dirname(output)).deleteSync(recursive: true);
      });
      expect(code, 1, reason: '$out$err');
      expect(
        out.toString(),
        contains(
          'FAIL cli ${i}lock-output/: output ({output} exists after the run, expected nothing there: locked)\n',
        ),
      );
      expect(
        err.toString().trimRight().split('\n'),
        contains(startsWith('could not delete ${p.dirname(output)}: ')),
      );
      expect(Directory(output).existsSync(), isTrue);
    }, skip: skipAsSuperuser);
    test('runCliSet starts no case when a run cannot be resolved to its process', () async {
      final StringBuffer progress = StringBuffer();
      final SetRun run = await runCliSet(
        'gen',
        <InvocationPlan>[
          const InvocationSettled(Passed('${i}a/')),
          const InvocationRun(
            path: '${i}b/',
            command: DartCommand(<String>['--version']),
            files: null,
            expected: null,
            exitCode: 0,
            stdout: null,
            stderr: null,
          ),
          const InvocationRun(
            path: '${i}c/',
            command: PackageCommand('other', 'tool', <String>[]),
            files: null,
            expected: null,
            exitCode: 0,
            stdout: null,
            stderr: null,
          ),
          const InvocationRun(
            path: '${i}d/',
            command: FlutterCommand(<String>['--version']),
            files: null,
            expected: null,
            exitCode: 0,
            stdout: null,
            stderr: null,
          ),
        ],
        root: seed(const <String, String>{}),
        dart: '/sdk/bin/dart',
        flutter: null,
        roots: const <String, Uri>{},
        progress: progress,
      );
      expect(
        run,
        isA<SetUnavailable>()
            .having((SetUnavailable run) => run.set, 'set', CheckSet.cli)
            .having((SetUnavailable run) => run.slug, 'slug', 'gen')
            .having(
              (SetUnavailable run) => run.reason,
              'reason',
              'package other is absent from .dart_tool/package_config.json; ${i}c/ runs other:tool',
            ),
      );
      expect(progress.toString(), isEmpty);
    });
  });
  group('readTree', () {
    test('reads a symbolic link through: a link to a file is its bytes, a link to a directory holds the files below it', () {
      final Directory root = seed(const <String, String>{
        'tree/a.txt': 'a',
        'outside/b.txt': 'b',
        'outside/deep/c.txt': 'c',
      });
      Link('${root.path}/tree/file').createSync('${root.path}/outside/b.txt');
      Link('${root.path}/tree/dir').createSync('${root.path}/outside');
      final Map<String, Object> expected = <String, Object>{
        'a.txt': utf8.encode('a'),
        'file': utf8.encode('b'),
        'dir/b.txt': utf8.encode('b'),
        'dir/deep/c.txt': utf8.encode('c'),
      };
      expect(shown(readTree(Directory('${root.path}/tree'))), expected);
      // The tree's own directory may be a link.
      Link('${root.path}/linked').createSync('${root.path}/tree');
      expect(shown(readTree(Directory('${root.path}/linked'))), expected);
    });
    test('records a dangling link as unreadable', () {
      final Directory root = seed(const <String, String>{'tree/a.txt': 'a'});
      Link('${root.path}/tree/gone').createSync('${root.path}/nowhere');
      expect(shown(readTree(Directory('${root.path}/tree'))), <String, Object>{
        'a.txt': utf8.encode('a'),
        'gone': startsWith('unreadable: Cannot resolve symbolic links: '),
      });
    });
    test('records a link cycle as unreadable: links that resolve to each other, and a link to a directory above it', () {
      final Directory root = seed(const <String, String>{
        'tree/sub/a.txt': 'a',
      });
      Link('${root.path}/tree/loop1').createSync('${root.path}/tree/loop2');
      Link('${root.path}/tree/loop2').createSync('${root.path}/tree/loop1');
      Link('${root.path}/tree/sub/up').createSync('${root.path}/tree');
      expect(shown(readTree(Directory('${root.path}/tree'))), <String, Object>{
        'loop1': startsWith('unreadable: Cannot resolve symbolic links: '),
        'loop2': startsWith('unreadable: Cannot resolve symbolic links: '),
        'sub/a.txt': utf8.encode('a'),
        'sub/up':
            'unreadable: a symbolic link to a directory above it, a cycle',
      });
    });
    test('records a file it cannot open as unreadable', () {
      final Directory root = seed(const <String, String>{
        'tree/a.txt': 'a',
        'tree/secret': 's',
      });
      chmod('000', '${root.path}/tree/secret');
      addTearDown(() => chmod('644', '${root.path}/tree/secret'));
      expect(shown(readTree(Directory('${root.path}/tree'))), <String, Object>{
        'a.txt': utf8.encode('a'),
        'secret': startsWith('unreadable: Cannot open file: '),
      });
    }, skip: skipAsSuperuser);
    test(
      'records a directory it cannot list as unreadable, the tree\'s own as .',
      () {
        final Directory root = seed(const <String, String>{
          'tree/a.txt': 'a',
          'tree/locked/x': 'x',
        });
        chmod('000', '${root.path}/tree/locked');
        addTearDown(() => chmod('755', '${root.path}/tree/locked'));
        expect(
          shown(readTree(Directory('${root.path}/tree'))),
          <String, Object>{
            'a.txt': utf8.encode('a'),
            'locked': startsWith('unreadable: Directory listing failed: '),
          },
        );
        expect(
          shown(readTree(Directory('${root.path}/tree/locked'))),
          <String, Object>{
            '.': startsWith('unreadable: Directory listing failed: '),
          },
        );
      },
      skip: skipAsSuperuser,
    );
    test('records a named pipe as unreadable, never opening it', () {
      final Directory root = seed(const <String, String>{'tree/a.txt': 'a'});
      final ProcessResult mkfifo = Process.runSync('mkfifo', <String>[
        '${root.path}/tree/pipe',
      ]);
      expect(mkfifo.exitCode, 0, reason: all(mkfifo));
      expect(shown(readTree(Directory('${root.path}/tree'))), <String, Object>{
        'a.txt': utf8.encode('a'),
        'pipe': 'unreadable: a named pipe, not a file',
      });
    });
    test('records a link to a device as unreadable, never opening it', () {
      final Directory root = seed(const <String, String>{'tree/a.txt': 'a'});
      Link('${root.path}/tree/null').createSync('/dev/null');
      expect(shown(readTree(Directory('${root.path}/tree'))), <String, Object>{
        'a.txt': utf8.encode('a'),
        'null': 'unreadable: neither a file nor a directory',
      });
    });
    test('records a socket as unreadable', () async {
      final Directory root = seed(const <String, String>{'tree/a.txt': 'a'});
      final ServerSocket socket = await ServerSocket.bind(
        InternetAddress(
          '${root.path}/tree/sock',
          type: InternetAddressType.unix,
        ),
        0,
      );
      addTearDown(socket.close);
      expect(shown(readTree(Directory('${root.path}/tree'))), <String, Object>{
        'a.txt': utf8.encode('a'),
        'sock': 'unreadable: a socket, not a file',
      });
    });
  });
}
