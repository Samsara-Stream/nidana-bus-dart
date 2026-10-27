import 'dart:convert';
import 'dart:io';

import 'package:nidana_contract_check/src/command_runs.dart';
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
    test('a directory the generator leaves unreadable fails the replay, and the {t} that cannot be deleted stays behind', () async {
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
      expect(
        out.toString(),
        contains(
          'FAIL file ${g}expected/: unreadable-file (locked in output: Directory listing failed: Permission denied); '
          'extra-file (locked); missing-file (notes.txt); missing-file (out.dart)\n',
        ),
      );
      expect(Directory(output).existsSync(), isTrue);
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
        'gone': 'unreadable: Cannot resolve symbolic links: No such file or directory',
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
        'loop1': 'unreadable: Cannot resolve symbolic links: Too many levels of symbolic links',
        'loop2': 'unreadable: Cannot resolve symbolic links: Too many levels of symbolic links',
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
        'secret': 'unreadable: Cannot open file: Permission denied',
      });
    });
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
            'locked': 'unreadable: Directory listing failed: Permission denied',
          },
        );
        expect(
          shown(readTree(Directory('${root.path}/tree/locked'))),
          <String, Object>{
            '.': 'unreadable: Directory listing failed: Permission denied',
          },
        );
      },
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
