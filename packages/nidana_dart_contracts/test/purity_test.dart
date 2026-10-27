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

/// A string literal, in single or double quotes, triple-quoted or not. A raw
/// literal ends at its first closing quote; any other ends at the first
/// closing quote that no backslash escapes.
final RegExp stringLiteral = RegExp(
  r'''r'{3}[\s\S]*?'{3}|r"{3}[\s\S]*?"{3}|r'[^'\n]*'|r"[^"\n]*"'''
  r'''|'{3}(?:[^\\]|\\[\s\S])*?'{3}|"{3}(?:[^\\]|\\[\s\S])*?"{3}'''
  r'''|'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"''',
);

/// Adjacent string literals, which Dart reads as one string.
final RegExp adjacentLiterals = RegExp(
  '(?:${stringLiteral.pattern})(?:\\s*(?:${stringLiteral.pattern}))*',
);

/// A comment or a string literal, whichever starts first.
final RegExp commentOrLiteral = RegExp(
  '${stringLiteral.pattern}|//[^\\n]*|/\\*[\\s\\S]*?\\*/',
);

/// A string literal or a semicolon, whichever starts first.
final RegExp literalOrSemicolon = RegExp('${stringLiteral.pattern}|;');

/// The keyword that starts an import, export or part directive: at a line
/// start, once comments are white space, and followed by a string literal. A
/// name, a receiver or a named argument that happens to spell `part`,
/// `import` or `export` is no directive.
final RegExp directiveKeyword = RegExp(
  r'''^\s*(?:import|export|part(?:\s+of)?)\s*(?=r?['"])''',
  multiLine: true,
);

/// The string a [literal] spells, apart from escapes. Dart drops the first
/// line of a triple-quoted literal when it holds nothing but white space.
String literalBody(String literal) {
  final String quoted = literal.startsWith('r')
      ? literal.substring(1)
      : literal;
  final bool triple = quoted.startsWith("'''") || quoted.startsWith('"""');
  final int quotes = triple ? 3 : 1;
  final String body = quoted.substring(quotes, quoted.length - quotes);
  return triple
      ? body.replaceFirst(RegExp(r'^[ \t]*(?:\r\n|\n|\r)'), '')
      : body;
}

/// [source] with each comment read as Dart reads it, as white space: a
/// space, and the comment's line breaks. A `//` or `/*` inside a string
/// literal starts no comment.
String withoutComments(String source) => source.replaceAllMapped(
  commentOrLiteral,
  (Match m) => m[0]!.startsWith('/')
      ? ' ${m[0]!.replaceAll(RegExp(r'[^\n]'), '')}'
      : m[0]!,
);

/// The text of every import, export and part directive in [code], a source
/// without comments: from the keyword to the first `;` outside a string
/// literal.
List<String> directives(String code) => <String>[
  for (final Match keyword in directiveKeyword.allMatches(code))
    code.substring(
      keyword.start,
      literalOrSemicolon
              .allMatches(code, keyword.end)
              .where((Match m) => m[0] == ';')
              .map((Match m) => m.end)
              .firstOrNull ??
          code.length,
    ),
];

/// The URIs of every import, export and part directive in [source], read
/// from the directive's keyword to its `;` outside a string literal: every
/// URI of a conditional import, each run of adjacent literals joined into
/// one, comments read as white space.
List<String> directiveUris(String source) => <String>[
  for (final String directive in directives(withoutComments(source)))
    for (final Match run in adjacentLiterals.allMatches(directive))
      stringLiteral
          .allMatches(run[0]!)
          .map((Match literal) => literalBody(literal[0]!))
          .join(),
];

/// Whether the library at [path], in a package whose libraries are under
/// [lib], may name [uri] (G25, G26): a `dart:` library, spelled as a name of
/// lower-case letters and underscores, other than dart:io, dart:isolate,
/// dart:ffi and dart:html, `package:meta`, this package, or a relative URI
/// inside [lib] with no authority, query or fragment. A URI with a backslash
/// or a percent sign is never allowed, because a string escape or a percent
/// encoding can spell any URI.
bool allowedUri(String uri, {required String path, required String lib}) {
  if (uri.contains(r'\') || uri.contains('%')) {
    return false;
  }
  if (uri.startsWith('dart:')) {
    return RegExp(r'^dart:[a-z_]+$').hasMatch(uri) &&
        !<String>{
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
  final Uri resolved = Uri.file(path).resolve(uri);
  return resolved.host.isEmpty &&
      !resolved.hasQuery &&
      !resolved.hasFragment &&
      resolved.toFilePath().startsWith('$lib/');
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

  test('the directive reader sees through comments inside a directive', () {
    expect(
      directiveUris(
        "import 'dart:' /* c */ 'io';\n"
        "import 'dart:' // c\n    'isolate';\n"
        "import /* ; */ 'dart:ffi';\n"
        "import /* it's */ 'dart:html';\n"
        "import 'a.dart' /* \"c\" */ if (dart.library.io) /* ' */ 'b.dart';\n",
      ),
      <String>[
        'dart:io',
        'dart:isolate',
        'dart:ffi',
        'dart:html',
        'a.dart',
        'b.dart',
      ],
    );
  });

  test('the directive reader keeps comment marks inside a string and skips '
      'a directive inside a comment', () {
    expect(
      directiveUris(
        "import 'package:x//y.dart';\nimport 'a/*b.dart';\n"
        "import 'c.dart'; /* tail */\n"
        "/*\n  import 'dart:io';\n*/\n"
        "  // import 'dart:ffi';\n",
      ),
      <String>['package:x//y.dart', 'a/*b.dart', 'c.dart'],
    );
  });

  test('the directive reader reads a triple-quoted URI, whose first line '
      'break Dart drops', () {
    expect(
      directiveUris(
        "import '''\ndart:io''' as a;\nimport \"\"\"dart:ffi\"\"\";\n"
        "import '''dart:''' 'isolate';\nimport '''  \t\ndart:html''';\n",
      ),
      <String>['dart:io', 'dart:ffi', 'dart:isolate', 'dart:html'],
    );
  });

  test('the directive reader keeps a string with an escaped quote whole, so '
      'a comment mark in it opens no comment', () {
    expect(
      directiveUris(
        "@Deprecated('a\\' /*')\nlibrary;\n\nimport 'dart:io';\n\n// */\n"
        "@Deprecated(\"a\\\" /*\")\nimport 'dart:ffi';\n// */\n"
        "const s = '''a\\''' /*''';\nimport 'dart:isolate';\n// */\n"
        "const r = r'a\\'; /*\nimport 'dart:html';\n// */\nimport 'dart:async';\n",
      ),
      <String>['dart:io', 'dart:ffi', 'dart:isolate', 'dart:async'],
    );
  });

  test('the directive reader ends a directive at a semicolon outside a '
      'string', () {
    expect(
      directiveUris(
        "import 'b.dart'\n    if (dart.library.html == 'x;') 'b.dart'\n"
        "    if (dart.library.io) 'dart:io'\n    as io;\n"
        "export 'a.dart' if (p == \"q;r\") 'dart:ffi' show Z;\n"
        "import 'c.dart';\n",
      ),
      <String>[
        'b.dart',
        'x;',
        'b.dart',
        'dart:io',
        'a.dart',
        'q;r',
        'dart:ffi',
        'c.dart',
      ],
    );
  });

  test('the directive reader skips a directive word that no string literal '
      'follows', () {
    expect(
      directiveUris(
        "final escaped = <String>[\n  for (final part in parts)\n    part\n"
        "        .replaceAll('#', '#35;')\n"
        "        .replaceAll('\\n', '#10;'),\n];\n"
        "f(\n  part: 'https://example.com/a',\n  import: 'dart:io',\n"
        "  export: \"dart:ffi\",\n);\n"
        "part of my.library;\nimportant 'x';\nimport 'dart:async';\n",
      ),
      <String>['dart:async'],
    );
  });

  test('the directive reader reads a directive word that a string literal '
      'follows on the same line or the next', () {
    expect(
      directiveUris(
        "import'dart:io';\nexport\n    'dart:ffi';\npart\n\n  r'p.dart';\n"
        "part  of\t\"l.dart\";\n",
      ),
      <String>['dart:io', 'dart:ffi', 'p.dart', 'l.dart'],
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
    expect(allowed('dart:typed_data'), isTrue);
    expect(allowed('dart:./io'), isFalse);
    expect(allowed('dart:./././io'), isFalse);
    expect(allowed('dart:./isolate'), isFalse);
    expect(allowed('dart:io/'), isFalse);
    expect(allowed('dart:IO'), isFalse);
    expect(allowed('dart:'), isFalse);
    expect(allowed('dart:io'), isFalse);
    expect(allowed('dart:isolate'), isFalse);
    expect(allowed('dart:ffi'), isFalse);
    expect(allowed('dart:html'), isFalse);
    expect(allowed(r'dart:\x69o'), isFalse);
    expect(allowed('dart:%69o'), isFalse);
    expect(allowed('dart:i%73olate'), isFalse);
    expect(allowed('dart:%66fi'), isFalse);
    expect(allowed('dart:ht%6dl'), isFalse);
    expect(allowed('../%2e%2e/test/purity_test.dart'), isFalse);
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

  test('allowedUri refuses a relative URI with a query, a fragment or an '
      'authority, and does not throw', () {
    bool allowed(String uri) => allowedUri(
      uri,
      path: '/w/lib/src/topology/topology.dart',
      lib: '/w/lib',
    );
    expect(allowed('builder.dart?x=1'), isFalse);
    expect(allowed('builder.dart#part'), isFalse);
    expect(allowed('../topic/topic.dart?v=1#s'), isFalse);
    expect(allowed('//host/w/lib/builder.dart'), isFalse);
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
