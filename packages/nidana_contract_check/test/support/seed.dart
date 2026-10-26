/// Seeded workspaces for the shell's tests: files written into a temporary
/// directory, and the tool's bin script run over them as a separate process.
/// A seeded fixture is a string, never a `.dart` file in the package (D2
/// item 5).
library;

import 'dart:io';

import 'package:nidana_contract_check/src/shell.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Writes [files], keyed by `/`-separated paths, into a fresh temporary directory deleted after the test.
Directory seed(Map<String, String> files) {
  final Directory root = Directory.systemTemp.createTempSync('ncc_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final MapEntry<String, String> entry in files.entries) {
    File(p.joinAll(<String>[root.path, ...p.posix.split(entry.key)]))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  return root;
}

/// Runs the bin script with [arguments] from [workingDirectory].
Future<ProcessResult> runTool(
  List<String> arguments, {
  required Directory workingDirectory,
}) => Process.run(Platform.resolvedExecutable, <String>[
  _bin,
  ...arguments,
], workingDirectory: workingDirectory.path);

/// The bin script, by absolute path under the workspace that holds the test
/// run: run from any working directory, it still resolves its packages
/// through the workspace's package configuration.
final String _bin = p.join(
  (findWorkspaceRoot(Directory.current) ??
          (throw StateError(
            'no ancestor of ${Directory.current.path} holds hsdd/contract/',
          )))
      .path,
  'packages',
  'nidana_contract_check',
  'bin',
  'nidana_contract_check.dart',
);
