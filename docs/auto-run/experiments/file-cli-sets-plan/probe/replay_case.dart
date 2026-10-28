// A prototype of the plan's cli set for one recorded invocation, experiment
// only:
//
//   dart replay_case.dart <workspace root> <slug> <case>
//
// It runs the case as the plan's Task 7 does: the first line of `args` names
// the command; `dart` runs as the running dart; `{package}:{executable}` runs
// as `{dart} --packages={root}/.dart_tool/package_config.json
// {package root}/bin/{executable}.dart`, the package root read from the
// package configuration; `files/`, when present, is the working directory,
// else the root; an argument `{output}` becomes `{t}/output` for a fresh
// temporary directory `{t}`. Then it compares the exit code, and stdout and
// stderr when recorded, after replacing the paths of `{output}`, `files/` and
// the root, the longer of each pair's given and resolved forms first; and the
// tree at `{output}`, formatted, with `expected/`, or that nothing is there.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final Directory root = Directory(args[0]);
  final String slug = args[1];
  final String name = args[2];
  final String dart = Platform.resolvedExecutable;
  final String caseDir = '${root.path}/hsdd/contract/fixture/$slug/invocation/$name';
  final List<String> lines = File('$caseDir/args').readAsStringSync().split('\n');
  if (lines.last.isEmpty) lines.removeLast();
  final Directory files = Directory('$caseDir/files');
  final String cwd = files.existsSync() ? files.path : root.path;
  final Directory t = Directory.systemTemp.createTempSync('ncc_cli_');
  final String output = '${t.path}/output';
  final List<String> arguments = <String>[
    for (final String a in lines.skip(1)) a == '{output}' ? output : a,
  ];
  final String config = '${root.path}/.dart_tool/package_config.json';
  final (String executable, List<String> prefix) = switch (lines.first) {
    'dart' => (dart, const <String>[]),
    final String command => _packageCommand(command, dart, config),
  };
  final ProcessResult r = await Process.run(
    executable,
    <String>[...prefix, ...arguments],
    workingDirectory: cwd,
    stdoutEncoding: const Utf8Codec(allowMalformed: true),
    stderrEncoding: const Utf8Codec(allowMalformed: true),
  );
  final List<(String, String, String)> forms = <(String, String, String)>[
    (output, '${t.resolveSymbolicLinksSync()}/output', '{output}'),
    if (files.existsSync()) (files.path, files.resolveSymbolicLinksSync(), '{files}'),
    (root.path, root.resolveSymbolicLinksSync(), '{root}'),
  ];
  String placeholders(String text) => forms.fold(text, (String acc, (String, String, String) f) {
    final (String given, String resolved, String placeholder) = f;
    final List<String> pair = <String>[given, resolved]..sort((String a, String b) => b.length - a.length);
    return pair.fold(acc, (String s, String form) => s.replaceAll(form, placeholder));
  });
  final List<String> problems = <String>[];
  final int recordedExit = int.parse(File('$caseDir/exit_code').readAsStringSync().trim());
  if (r.exitCode != recordedExit) problems.add('exit (exited ${r.exitCode}, expected $recordedExit)');
  for (final (String stream, Object? actual) in <(String, Object?)>[('stdout', r.stdout), ('stderr', r.stderr)]) {
    final File recorded = File('$caseDir/$stream');
    if (recorded.existsSync() && recorded.readAsStringSync() != placeholders(actual! as String)) {
      problems.add('$stream (recorded ${jsonEncode(recorded.readAsStringSync())}, got ${jsonEncode(placeholders(actual as String))})');
    }
  }
  final Directory expected = Directory('$caseDir/expected');
  final FileSystemEntityType at = FileSystemEntity.typeSync(output, followLinks: false);
  if (lines.contains('{output}')) {
    if (expected.existsSync()) {
      if (at != FileSystemEntityType.directory) {
        problems.add('output (nothing at {output}, or not a directory)');
      } else {
        await Process.run(dart, <String>['format', output], workingDirectory: root.path);
        final Map<String, List<int>> want = _tree(expected);
        final Map<String, List<int>> got = _tree(Directory(output));
        if (want.keys.join(' ') != got.keys.join(' ') ||
            want.keys.any((String k) => base64Encode(want[k]!) != base64Encode(got[k]!))) {
          problems.add('tree (expected ${want.keys.join(' ')}, got ${got.keys.join(' ')}, or bytes differ)');
        }
      }
    } else if (at != FileSystemEntityType.notFound) {
      problems.add('output ({output} exists after the run, expected nothing there)');
    }
  }
  t.deleteSync(recursive: true);
  stdout.writeln(problems.isEmpty ? 'PASS $name' : 'FAIL $name: ${problems.join('; ')}');
}

(String, List<String>) _packageCommand(String command, String dart, String config) {
  final [String package, String executable] = command.split(':');
  final List<Object?> packages =
      (jsonDecode(File(config).readAsStringSync()) as Map<String, Object?>)['packages']! as List<Object?>;
  final Map<String, Object?> entry = packages
      .cast<Map<String, Object?>>()
      .firstWhere((Map<String, Object?> p) => p['name'] == package);
  final String rootUri = entry['rootUri']! as String;
  final Uri packageRoot = Uri.file(config).resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/');
  final String script = packageRoot.resolve('bin/$executable.dart').toFilePath();
  return (dart, <String>['--packages=$config', script]);
}

Map<String, List<int>> _tree(Directory d) {
  final List<File> all = d.listSync(recursive: true, followLinks: false).whereType<File>().toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  return <String, List<int>>{for (final File f in all) f.path.substring(d.path.length + 1): f.readAsBytesSync()};
}
