// Locates this package's files from the workspace root, so that tests run
// from the root as `fvm dart test packages/nidana_dart_contracts`
// (nidana.model D5, D6).
import 'dart:io';

/// The workspace root: the nearest ancestor of the working directory that
/// holds `hsdd/contract/`.
Directory workspaceRoot() {
  for (Directory d = Directory.current.absolute; ; d = d.parent) {
    if (Directory('${d.path}/hsdd/contract').existsSync()) {
      return d;
    }
    if (d.parent.path == d.path) {
      throw StateError(
        'no ancestor of ${Directory.current.path} holds hsdd/contract/',
      );
    }
  }
}

/// This package's directory.
Directory packageDirectory() =>
    Directory('${workspaceRoot().path}/packages/nidana_dart_contracts');
