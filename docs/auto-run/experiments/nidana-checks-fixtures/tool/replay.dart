// Stand-in for the `cli` set of nidana_contract_check (ADR-001 items 7 and
// 9), experiment only. Run from the workspace root:
//
//   fvm dart run tool/replay.dart [--record] <invocation-dir> [<case>...]
//
// For each `{case}/` under <invocation-dir>: the first line of `args` is the
// command (`dart`, `flutter` or `{package}:{executable}`), the rest one
// argument per line; `files/`, when present, is the working directory, else
// the workspace root. stdout and stderr are compared exactly, when recorded,
// after the absolute paths of `files/` and of the workspace root are replaced
// by `{files}` and `{root}`; `exit_code` always. `--record` writes what ran
// instead of comparing (used once, then every line reviewed by hand).
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
    final List<String> args = File('${c.path}/args').readAsLinesSync().where((String l) => l.isNotEmpty).toList();
    final Directory files = Directory('${c.path}/files');
    final String cwd = files.existsSync() ? files.absolute.path : root;
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
    if (record) {
      File('${c.path}/exit_code').writeAsStringSync('${r.exitCode}\n');
      File('${c.path}/stdout').writeAsStringSync(stdoutText);
      stdout.writeln('RECORDED $name: exit ${r.exitCode}, ${stdoutText.split('\n').where((String l) => l.isNotEmpty).length} stdout lines');
      if (stderrText.isNotEmpty) stdout.writeln('  stderr: ${stderrText.trim().replaceAll('\n', ' / ')}');
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
    if (problems.isEmpty) {
      stdout.writeln('PASS $name');
    } else {
      failures++;
      stdout.writeln('FAIL $name: ${problems.join('; ')}');
    }
  }
  if (!record) stdout.writeln('${cases.length - failures} of ${cases.length} invocations pass');
  exit(failures == 0 ? 0 : 1);
}

String _base(String path) => path.split('/').where((String s) => s.isNotEmpty).last;
