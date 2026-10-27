// G25 and G26 of topic-model@v1, which its Validation leaves to
// nidana.model's gates (nidana.model D6). A text search misses an aliased
// import; review covers that.
import 'dart:io';

import 'package:test/test.dart';

import 'src/package_files.dart';

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

/// A string literal, raw or not, in single or double quotes: its body is
/// group 1 or group 2.
final RegExp stringLiteral = RegExp(r'''r?'([^'\n]*)'|r?"([^"\n]*)"''');

/// Adjacent string literals, which Dart reads as one string.
final RegExp adjacentLiterals = RegExp(
  r'''(?:r?'[^'\n]*'|r?"[^"\n]*")(?:\s*(?:r?'[^'\n]*'|r?"[^"\n]*"))*''',
);

/// The URIs of every import, export and part directive in [source], read
/// from the directive's keyword to its `;`: every URI of a conditional
/// import, each run of adjacent literals joined into one.
List<String> directiveUris(String source) => <String>[
  for (final Match directive in RegExp(
    r'^\s*(?:import|export|part)\b[^;]*;',
    multiLine: true,
  ).allMatches(source))
    for (final Match run in adjacentLiterals.allMatches(directive[0]!))
      stringLiteral
          .allMatches(run[0]!)
          .map((Match literal) => literal[1] ?? literal[2]!)
          .join(),
];

/// Whether the library at [path], in a package whose libraries are under
/// [lib], may name [uri] (G25, G26): a `dart:` library other than dart:io,
/// dart:isolate, dart:ffi and dart:html, `package:meta`, this package, or a
/// relative URI that resolves inside [lib]. A URI with a backslash is never
/// allowed, because an escape can spell any URI.
bool allowedUri(String uri, {required String path, required String lib}) {
  if (uri.contains(r'\')) {
    return false;
  }
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
  if (RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(uri)) {
    return false;
  }
  return Uri.file(path).resolve(uri).toFilePath().startsWith('$lib/');
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

/// The tokens of [effects] that [source] contains, in the list's order.
List<String> effectsIn(String source) => <String>[
  for (final String effect in effects)
    if (source.contains(effect)) effect,
];

void main() {
  test('G26 depends on meta alone, with test its only dev dependency', () {
    final String pubspec = File('${packageDirectory().path}/pubspec.yaml')
        .readAsStringSync();
    expect(sectionKeys(pubspec, 'dependencies'), <String>{'meta'});
    expect(sectionKeys(pubspec, 'dev_dependencies'), <String>{'test'});
  });

  test('G25 G26 no library imports dart:io, dart:isolate, dart:ffi, '
      'dart:html, a package other than meta and its own, or a file '
      'outside lib/', () {
    final String lib = '${packageDirectory().path}/lib';
    final List<File> found = libraries();
    expect(found, isNotEmpty);
    for (final File library in found) {
      for (final String uri in directiveUris(library.readAsStringSync())) {
        expect(
          allowedUri(uri, path: library.path, lib: lib),
          isTrue,
          reason: '${library.path} names $uri',
        );
      }
    }
  });

  test('G25 no library reads a clock, schedules work, '
      'generates an id or reaches a zone', () {
    final List<File> found = libraries();
    expect(found, isNotEmpty);
    for (final File library in found) {
      expect(
        effectsIn(library.readAsStringSync()),
        isEmpty,
        reason: library.path,
      );
    }
  });

  test('the directive reader reads every URI of every directive form', () {
    expect(
      directiveUris(
        "import 'dart:io';\nimport \"dart:async\" as a;\n"
        "  export 'package:x/y.dart' show Z;\nimport 'src/a.dart';\n"
        "import 'a.dart'\n    if (dart.library.io) 'dart:io'\n"
        "    if (dart.library.js_interop) 'b.dart';\n"
        "import r'dart:ffi';\nimport 'dart:' \"isolate\";\n"
        "part 'p.dart';\npart of 'l.dart';\n"
        "// import 'dart:html'; in a comment is no directive\n",
      ),
      <String>[
        'dart:io',
        'dart:async',
        'package:x/y.dart',
        'src/a.dart',
        'a.dart',
        'dart:io',
        'b.dart',
        'dart:ffi',
        'dart:isolate',
        'p.dart',
        'l.dart',
      ],
    );
  });

  test('allowedUri admits the SDK but four libraries, meta, this package '
      'and lib/, and nothing else', () {
    bool allowed(String uri) => allowedUri(
      uri,
      path: '/w/lib/src/topology/topology.dart',
      lib: '/w/lib',
    );
    expect(allowed('dart:async'), isTrue);
    expect(allowed('dart:io'), isFalse);
    expect(allowed('dart:isolate'), isFalse);
    expect(allowed('dart:ffi'), isFalse);
    expect(allowed('dart:html'), isFalse);
    expect(allowed(r'dart:\x69o'), isFalse);
    expect(allowed('package:meta/meta.dart'), isTrue);
    expect(allowed('package:nidana_dart_contracts/topology_plan.dart'), isTrue);
    expect(allowed('package:collection/collection.dart'), isFalse);
    expect(allowed('builder.dart'), isTrue);
    expect(allowed('../topic/topic.dart'), isTrue);
    expect(allowed('../../topology_plan.dart'), isTrue);
    expect(allowed('../../../test/purity_test.dart'), isFalse);
    expect(allowed('../../../lib_other/a.dart'), isFalse);
    expect(allowed('file:///w/lib/src/topic/topic.dart'), isFalse);
  });

  test('the effects scan finds every listed token, in a comment too', () {
    expect(effectsIn('const int answer = 42;\n'), isEmpty);
    expect(
      effectsIn('final Timer t = Timer.periodic(d, f);\n// DateTime.now( \n'),
      <String>['DateTime.now(', 'Timer.periodic('],
    );
    expect(effectsIn(effects.join('\n')), effects);
  });

  test('the pubspec reader sees every key of a section', () {
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
