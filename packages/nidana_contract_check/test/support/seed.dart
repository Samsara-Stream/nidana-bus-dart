/// Seeded workspaces for the shell's tests: files written into a temporary
/// directory, and the tool's bin script run over them as a separate process.
/// A seeded fixture is a string, never a `.dart` file in the package (D2
/// item 5).
library;

import 'dart:io';

import 'package:nidana_contract_check/src/workspace.dart';
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

/// The skip reason of a test that denies itself access with `chmod 000`: the superuser reads and
/// lists what mode 000 denies, so such a test cannot see what it pins. Null for any other user.
final String? skipAsSuperuser =
    switch ((Process.runSync('id', <String>['-u']).stdout as String).trim()) {
      '0' => 'chmod 000 denies the superuser nothing',
      _ => null,
    };

/// Runs the bin script with [arguments] from [workingDirectory], with [environment] over the test
/// run's own.
///
/// Its flutter is the real one beside the running dart, so it never replays
/// a Flutter binding that is not PENDING (see `seedWorkspace`).
Future<ProcessResult> runTool(
  List<String> arguments, {
  required Directory workingDirectory,
  Map<String, String>? environment,
}) => Process.run(
  Platform.resolvedExecutable,
  <String>[_bin, ...arguments],
  workingDirectory: workingDirectory.path,
  environment: environment,
);

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
