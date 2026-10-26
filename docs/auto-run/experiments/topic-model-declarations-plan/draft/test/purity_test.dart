// G25 and G26 of topic-model@v1, which its Validation leaves to
// nidana.model's gates (nidana.model D6). A text search misses an aliased
// import; review covers that.
import 'dart:io';

import 'package:test/test.dart';

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

/// The names under the top-level key [section] of the pubspec [text]: the
/// keys indented by exactly two spaces, up to the next line that starts in
/// column zero.
Set<String> sectionKeys(String text, String section) {
  final Set<String> keys = <String>{};
  bool inside = false;
  for (final String line in text.split('\n')) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
      continue;
    }
    if (!line.startsWith(' ')) {
      inside = line.startsWith('$section:');
      continue;
    }
    final Match? key = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (inside && key != null) {
      keys.add(key.group(1)!);
    }
  }
  return keys;
}

/// The URI of every import and export directive in [source].
List<String> directiveUris(String source) => <String>[
  for (final Match m in RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  ).allMatches(source))
    m.group(1)!,
];

/// Whether a library under `lib/` may name [uri] (G25, G26).
bool allowedUri(String uri) {
  if (uri.startsWith('dart:')) {
    return !<String>{
      'dart:io',
      'dart:isolate',
      'dart:ffi',
      'dart:html',
    }.contains(uri);
  }
  if (uri.startsWith('package:')) {
    return uri.startsWith('package:meta/') ||
        uri.startsWith('package:nidana_dart_contracts/');
  }
  return true;
}

/// Every Dart library under this package's `lib/`.
List<File> libraries() =>
    Directory('${packageDirectory().path}/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();

const List<String> effects = <String>[
  'DateTime.now(',
  'Stopwatch(',
  'Timer(',
  'Timer.periodic(',
  'scheduleMicrotask(',
  'Future.delayed(',
  'Future.microtask(',
  'Random(',
  'Zone.',
];

void main() {
  test('G26 depends on meta alone, with test its only dev dependency', () {
    final String pubspec = File('${packageDirectory().path}/pubspec.yaml')
        .readAsStringSync();
    expect(sectionKeys(pubspec, 'dependencies'), <String>{'meta'});
    expect(sectionKeys(pubspec, 'dev_dependencies'), <String>{'test'});
  });

  test('G25 G26 no library imports dart:io, dart:isolate, dart:ffi, '
      'dart:html or a package other than meta and its own', () {
    final List<File> found = libraries();
    expect(found, isNotEmpty);
    for (final File library in found) {
      for (final String uri in directiveUris(library.readAsStringSync())) {
        expect(allowedUri(uri), isTrue, reason: '${library.path} names $uri');
      }
    }
  });

  test('G25 no library reads a clock, schedules work, '
      'generates an id or reaches a zone', () {
    final List<File> found = libraries();
    expect(found, isNotEmpty);
    for (final File library in found) {
      final String source = library.readAsStringSync();
      for (final String effect in effects) {
        expect(
          source.contains(effect),
          isFalse,
          reason: '${library.path} contains $effect',
        );
      }
    }
  });

  test('the readers see every directive form and pubspec section', () {
    expect(
      directiveUris(
        "import 'dart:io';\nimport \"dart:async\" as a;\n"
        "  export 'package:x/y.dart' show Z;\nimport 'src/a.dart';\n",
      ),
      <String>['dart:io', 'dart:async', 'package:x/y.dart', 'src/a.dart'],
    );
    expect(allowedUri('dart:io'), isFalse);
    expect(allowedUri('dart:async'), isTrue);
    expect(allowedUri('package:meta/meta.dart'), isTrue);
    expect(allowedUri('package:collection/collection.dart'), isFalse);
    expect(allowedUri('src/topic/topic.dart'), isTrue);
    expect(
      sectionKeys(
        'name: x\ndependencies:\n  meta: ^1.19.0\n\n  # a comment\n'
            '  flutter:\n    sdk: flutter\ndev_dependencies:\n  test: any\n',
        'dependencies',
      ),
      <String>{'meta', 'flutter'},
    );
  });
}
