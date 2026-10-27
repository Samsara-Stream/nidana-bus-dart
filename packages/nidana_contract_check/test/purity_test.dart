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

/// The libraries under lib/src/ that import `dart:io`, the replay tool's
/// imperative shell (nidana.model D2 item 5).
const List<String> shell = <String>[
  'command_runs.dart',
  'processes.dart',
  'runners.dart',
  'shell.dart',
  'workspace.dart',
];

List<String> directivesOf(String path) =>
    readDartLibrary(File(path).readAsStringSync()).directives;

/// The `/`-separated path relative to [lib] that a directive [uri] of the library at [from] names:
/// a URI with no scheme resolved against [from]'s directory, `package:nidana_contract_check/{path}`
/// as `{path}`, any other URI null.
String? targetOf(String uri, String from) {
  const String own = 'package:nidana_contract_check/';
  if (uri.startsWith(own)) {
    return uri.substring(own.length);
  }
  return Uri.parse(uri).hasScheme
      ? null
      : p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
}

/// The `/`-separated paths, relative to [lib], of the libraries the directives of the library at
/// [path] name, each as [targetOf] reads it.
Set<String> relativeTargetsOf(String path) => <String>{
  for (final String uri in directivesOf(
    p.joinAll(<String>[lib, ...p.posix.split(path)]),
  ))
    ?targetOf(uri, path),
};

/// The paths, relative to [lib], of every library reached from `lib/{from}` through directives
/// [targetOf] follows, [from] itself excluded.
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

/// The names of the `.dart` files directly under lib/src/, ascending.
List<String> sourceNames() => <String>[
  for (final FileSystemEntity f in Directory(p.join(lib, 'src')).listSync())
    if (f is File && f.path.endsWith('.dart')) p.basename(f.path),
]..sort();

void main() {
  test('no library under lib/src/ but command_runs.dart, processes.dart, runners.dart, shell.dart and workspace.dart imports dart:io', () {
    final List<String> importing = <String>[
      for (final String name in sourceNames())
        if (directivesOf(p.join(lib, 'src', name)).contains('dart:io')) name,
    ];
    expect(importing, shell);
  });
  test('targetOf follows the package\'s own package: URIs', () {
    expect(
      targetOf('package:nidana_contract_check/src/shell.dart', 'fixture.dart'),
      'src/shell.dart',
    );
    expect(targetOf('b.dart', 'src/a.dart'), 'src/b.dart');
    expect(targetOf('src/a.dart', 'fixture.dart'), 'src/a.dart');
    expect(targetOf('package:path/path.dart', 'fixture.dart'), isNull);
    expect(targetOf('dart:io', 'fixture.dart'), isNull);
  });
  test('no pure library reaches a library that imports dart:io', () {
    final List<String> pure = <String>[
      for (final String name in sourceNames())
        if (!shell.contains(name)) name,
    ];
    // A list that lost its libraries would pass vacuously.
    expect(pure, containsAll(<String>['analysis.dart', 'report.dart']));
    for (final String name in pure) {
      expect(
        relativeClosure('src/$name'),
        isNot(
          anyElement(
            isIn(<String>[for (final String library in shell) 'src/$library']),
          ),
        ),
        reason: 'src/$name',
      );
    }
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
        'src/command_runs.dart',
        'src/dart_library.dart',
        'src/dart_scanner.dart',
        'src/processes.dart',
        'src/workspace.dart',
      ]),
    );
    expect(
      relativeClosure('src/shell.dart'),
      isNot(contains('src/shell.dart')),
    );
  });
  // Beyond the brief: a parent-directory URI resolves, and a package whose
  // name only begins with this package's is another package.
  test('targetOf resolves .. against the importer and leaves other package: URIs unfollowed', () {
    expect(targetOf('../fixture.dart', 'src/a.dart'), 'fixture.dart');
    expect(
      targetOf('package:nidana_contract_check_x/a.dart', 'x.dart'),
      isNull,
    );
  });
}
