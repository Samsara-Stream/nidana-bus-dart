/// The workspace root and the platform paths below it: the file-system
/// helpers the shell and `fixture.dart` share. It is one of the libraries
/// under `lib/src/` that import `dart:io` (nidana.model D2 item 5), which
/// `test/purity_test.dart` lists, and a conformance library, which imports
/// `fixture.dart`, compiles this rather than the shell.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The nearest ancestor of [start], [start] included, that holds hsdd/contract/; null when none does.
Directory? findWorkspaceRoot(Directory start) =>
    _selfAndAncestors(absoluteDirectory(start))
        .where(_holdsContracts)
        .firstOrNull;

/// The platform path of the `/`-separated [path] from [root].
String workspacePath(Directory root, String path) =>
    p.joinAll(<String>[root.path, ...p.posix.split(path)]);

/// [directory] as an absolute, normalized path, as [findWorkspaceRoot] starts from it.
Directory absoluteDirectory(Directory directory) =>
    Directory(p.normalize(directory.absolute.path));

/// [directory] followed by each of its ancestors up to the file system root.
Iterable<Directory> _selfAndAncestors(Directory directory) sync* {
  yield directory;
  final Directory parent = directory.parent;
  if (parent.path != directory.path) {
    yield* _selfAndAncestors(parent);
  }
}

/// Whether [directory] holds `hsdd/contract/`.
bool _holdsContracts(Directory directory) =>
    Directory(workspacePath(directory, 'hsdd/contract/')).existsSync();
