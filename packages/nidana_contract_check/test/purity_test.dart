// packages/nidana_contract_check/test/purity_test.dart
import 'dart:io';

import 'package:nidana_contract_check/src/dart_library.dart';
import 'package:nidana_contract_check/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// packages/nidana_contract_check/lib/ of the workspace that holds the test run.
final String lib = p.join(
  findWorkspaceRoot(Directory.current)!.path,
  'packages',
  'nidana_contract_check',
  'lib',
);

List<String> directivesOf(String path) =>
    readDartLibrary(File(path).readAsStringSync()).directives;

/// The `/`-separated paths, relative to [lib], of the libraries the directives of the library at
/// [path] name with no scheme, each resolved against [path]'s directory.
Set<String> relativeTargetsOf(String path) => <String>{
  for (final String uri in directivesOf(
    p.joinAll(<String>[lib, ...p.posix.split(path)]),
  ))
    if (!Uri.parse(uri).hasScheme)
      p.posix.normalize(p.posix.join(p.posix.dirname(path), uri)),
};

/// The paths, relative to [lib], of every library reached from `lib/{from}` through directives
/// that have no scheme, each resolved against its importer's directory, [from] itself excluded.
Set<String> relativeClosure(String from) {
  Set<String> reach(Set<String> reached, String path) =>
      relativeTargetsOf(path)
          .where((String target) => target != from)
          .fold(
            reached,
            (Set<String> sofar, String target) => sofar.contains(target)
                ? sofar
                : reach(<String>{...sofar, target}, target),
          );
  return reach(const <String>{}, from);
}

void main() {
  test('no library under lib/src/ but runners.dart, shell.dart and workspace.dart imports dart:io', () {
    final List<String> importing = <String>[
      for (final FileSystemEntity f in Directory(p.join(lib, 'src')).listSync())
        if (f is File && directivesOf(f.path).contains('dart:io'))
          p.basename(f.path),
    ]..sort();
    expect(importing, <String>['runners.dart', 'shell.dart', 'workspace.dart']);
  });
  test('fixture.dart, which every conformance library imports, reaches json_document.dart and workspace.dart alone', () {
    expect(relativeClosure('fixture.dart'), <String>{
      'src/json_document.dart',
      'src/workspace.dart',
    });
  });

  // Beyond the brief: the closure helper itself, so a pass above is not a
  // helper that reaches nothing.
  test('relativeClosure follows relative directives transitively', () {
    expect(
      relativeClosure('src/shell.dart'),
      containsAll(<String>[
        'src/analysis.dart',
        'src/dart_library.dart',
        'src/dart_scanner.dart',
        'src/workspace.dart',
      ]),
    );
    expect(
      relativeClosure('src/shell.dart'),
      isNot(contains('src/shell.dart')),
    );
  });
}
