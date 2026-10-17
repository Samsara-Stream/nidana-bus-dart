// Stand-in for the `cli` set of nidana_contract_check as amended ADR-001
// item 7 would read, experiment only. It extends the prototype of
// ../nidana-checks-fixtures/tool/replay.dart with an output tree:
//
//   fvm dart run tool/replay.dart [--record] <invocation-dir> [<case>...]
//
// For each `{case}/` under <invocation-dir>: the first line of `args` is the
// command (`dart`, `flutter` or `{package}:{executable}`), the rest one
// argument per line; `files/`, when present, is the working directory, else
// the workspace root. An argument `{output}` is replaced by a path inside a
// fresh temporary directory, at which nothing exists when the command starts.
// After the run, a case with `expected/` passes only when the tree at
// `{output}` equals `expected/` byte for byte, file set included, once its
// Dart files are formatted with `fvm dart format` (ADR-001 item 6's
// comparison); a case without `expected/` whose args name `{output}` passes
// only when nothing exists at `{output}`. stdout and stderr are compared
// exactly, when recorded, after the absolute paths of `{output}`, `files/` and
// the workspace root are replaced by `{output}`, `{files}` and `{root}`;
// `exit_code` always. `--record` writes exit_code (and expected/, for a case
// whose args name `{output}` and whose run wrote it) instead of comparing.
import 'dart:io';

Future<void> main(List<String> argv) async {
  final bool record = argv.contains('--record');
  final List<String> rest = argv.where((String a) => a != '--record').toList();
  final Directory dir = Directory(rest.first);
  final Set<String> only = rest.skip(1).toSet();
  final String root = Directory.current.absolute.path;
  final List<Directory> cases = dir
      .listSync()
      .whereType<Directory>()
      .where((Directory d) => only.isEmpty || only.contains(_base(d.path)))
      .toList()
    ..sort((Directory a, Directory b) => a.path.compareTo(b.path));
  int failures = 0;
  for (final Directory c in cases) {
    final String name = _base(c.path);
    final List<String> raw = File('${c.path}/args').readAsLinesSync().where((String l) => l.isNotEmpty).toList();
    final Directory files = Directory('${c.path}/files');
    final String cwd = files.existsSync() ? files.absolute.path : root;
    final Directory tmp = Directory.systemTemp.createTempSync('replay-');
    final String output = '${tmp.resolveSymbolicLinksSync()}/output';
    final bool namesOutput = raw.contains('{output}');
    final List<String> args = raw.map((String a) => a == '{output}' ? output : a).toList();
    final String command = args.first;
    final List<String> cmd = switch (command) {
      'dart' => <String>['fvm', 'dart', ...args.skip(1)],
      'flutter' => <String>['fvm', 'flutter', ...args.skip(1)],
      _ => <String>['fvm', 'dart', 'run', command, ...args.skip(1)],
    };
    final ProcessResult r = await Process.run(cmd.first, cmd.skip(1).toList(), workingDirectory: cwd);
    String clean(Object? s) {
      String out = s as String;
      final List<(String, String)> replacements = <(String, String)>[
        (output, '{output}'),
        if (files.existsSync()) (files.absolute.resolveSymbolicLinksSync(), '{files}'),
        if (files.existsSync()) (files.absolute.path, '{files}'),
        (Directory(root).resolveSymbolicLinksSync(), '{root}'),
        (root, '{root}'),
      ];
      for (final (String from, String to) in replacements) {
        out = out.replaceAll(from, to);
      }
      return out;
    }

    final String stdoutText = clean(r.stdout);
    final String stderrText = clean(r.stderr);
    final Directory expectedTree = Directory('${c.path}/expected');
    final bool outputExists = FileSystemEntity.typeSync(output) != FileSystemEntityType.notFound;
    if (record) {
      File('${c.path}/exit_code').writeAsStringSync('${r.exitCode}\n');
      if (namesOutput && outputExists) {
        await _format(output, root);
        Process.runSync('cp', <String>['-R', output, expectedTree.path]);
      }
      stdout.writeln('RECORDED $name: exit ${r.exitCode}, output ${outputExists ? _tree(output).keys.join(' ') : 'none'}');
      if (stderrText.isNotEmpty) stdout.writeln('  stderr: ${stderrText.trim().replaceAll('\n', ' / ')}');
      tmp.deleteSync(recursive: true);
      continue;
    }
    final List<String> problems = <String>[];
    final int expectedExit = int.parse(File('${c.path}/exit_code').readAsStringSync().trim());
    if (r.exitCode != expectedExit) problems.add('exit ${r.exitCode}, expected $expectedExit');
    for (final (String stream, String actual) in <(String, String)>[('stdout', stdoutText), ('stderr', stderrText)]) {
      final File expected = File('${c.path}/$stream');
      if (expected.existsSync() && expected.readAsStringSync() != actual) {
        problems.add('$stream differs:\n--- expected\n${expected.readAsStringSync()}--- actual\n$actual---');
      }
    }
    if (expectedTree.existsSync()) {
      if (!outputExists) {
        problems.add('nothing at {output}, expected ${_tree(expectedTree.path).keys.join(' ')}');
      } else if (!FileSystemEntity.isDirectorySync(output)) {
        problems.add('{output} is a file, expected a directory');
      } else {
        await _format(output, root);
        final Map<String, List<int>> want = _tree(expectedTree.path);
        final Map<String, List<int>> got = _tree(output);
        if (want.keys.join(' ') != got.keys.join(' ')) {
          problems.add('file set at {output} is ${got.keys.join(' ')}, expected ${want.keys.join(' ')}');
        }
        for (final String f in want.keys.where(got.containsKey)) {
          if (!_same(want[f]!, got[f]!)) problems.add('{output}/$f differs from expected/$f');
        }
      }
    } else if (namesOutput && outputExists) {
      problems.add('{output} exists after the run, expected nothing: ${FileSystemEntity.isDirectorySync(output) ? _tree(output).keys.join(' ') : 'a file'}');
    }
    if (problems.isEmpty) {
      stdout.writeln('PASS $name');
    } else {
      failures++;
      stdout.writeln('FAIL $name: ${problems.join('; ')}');
    }
    tmp.deleteSync(recursive: true);
  }
  if (!record) stdout.writeln('${cases.length - failures} of ${cases.length} invocations pass');
  exit(failures == 0 ? 0 : 1);
}

Future<void> _format(String path, String root) async {
  final List<String> dartFiles = _tree(path).keys.where((String f) => f.endsWith('.dart')).map((String f) => '$path/$f').toList();
  if (dartFiles.isEmpty) return;
  await Process.run('fvm', <String>['dart', 'format', ...dartFiles], workingDirectory: root);
}

Map<String, List<int>> _tree(String path) {
  final Directory d = Directory(path);
  final List<File> all = d.listSync(recursive: true).whereType<File>().toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  return <String, List<int>>{for (final File f in all) f.path.substring(d.path.length + 1): f.readAsBytesSync()};
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _base(String path) => path.split('/').where((String s) => s.isNotEmpty).last;
