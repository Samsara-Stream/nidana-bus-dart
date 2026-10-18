// F2 and F3: what a package test of a Flutter member sees under
// `fvm flutter test`, run from the workspace root by path and from inside the
// member: the working directory, whether Isolate.resolvePackageUri resolves
// the package's own library, and whether an ancestor search finds the
// workspace root (the nearest ancestor whose pubspec.yaml declares
// `workspace:`) and from it the member's pubspec and lib/.
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

Directory? _workspaceRoot() {
  Directory d = Directory.current.absolute;
  while (true) {
    final File p = File('${d.path}/pubspec.yaml');
    if (p.existsSync() && p.readAsLinesSync().any((String l) => l.startsWith('workspace:'))) {
      return d;
    }
    final Directory parent = d.parent;
    if (parent.path == d.path) return null;
    d = parent;
  }
}

void main() {
  test('F3 locating the package from a package test', () async {
    // ignore: avoid_print
    print('F3 cwd ends with: ${Directory.current.path.split('/').reversed.take(3).toList().reversed.join('/')}');
    Uri? resolved;
    Object? error;
    try {
      resolved = await Isolate.resolvePackageUri(
          Uri.parse('package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart'));
    } on Object catch (e) {
      error = e;
    }
    // ignore: avoid_print
    print('F3 Isolate.resolvePackageUri: ${resolved == null ? 'null' : 'a ${resolved.scheme} uri ending ${resolved.pathSegments.reversed.take(3).toList().reversed.join('/')}'}'
        '${error == null ? '' : ', threw ${error.runtimeType}'}');
    final Directory? root = _workspaceRoot();
    // ignore: avoid_print
    print('F3 workspace root found by ancestor search: ${root != null}');
    final File pubspec = File('${root!.path}/packages/nidana_dart_runtime_flutter/pubspec.yaml');
    final Directory lib = Directory('${root.path}/packages/nidana_dart_runtime_flutter/lib');
    // ignore: avoid_print
    print('F3 member pubspec readable: ${pubspec.existsSync()}; lib files: '
        '${lib.listSync(recursive: true).whereType<File>().where((File f) => f.path.endsWith('.dart')).length}');
    expect(pubspec.existsSync(), isTrue);
  });
}
