/// The pure core's input: what the shell reads from the workspace for one
/// slug, its contract text, its schema file and its fixture tree (ADR-001
/// item 2), with each Dart source decoded from its bytes by [decodeSource].
library;

import 'dart:convert';

/// What the shell reads for one slug: the pure core's whole input.
final class SlugSnapshot {
  const SlugSnapshot({
    required this.slug,
    required this.contractText,
    required this.schemaBytes,
    required this.directories,
    required this.files,
    required this.documents,
    this.undecodable = const <String, String>{},
  });

  /// The slug: the name of its fixture directory and of its contract text.
  final String slug;

  /// The text of `hsdd/contract/{slug}.md`; null when it is absent.
  final String? contractText;

  /// [schemaPath] of [slug] as read; null when it is absent.
  final List<int>? schemaBytes;

  /// Whether [schemaPath] of [slug] exists.
  bool get hasSchemaFile => schemaBytes != null;

  /// The directories below `hsdd/contract/fixture/{slug}/`, each as a
  /// relative `/`-separated path with no trailing slash.
  final Set<String> directories;

  /// The files below `hsdd/contract/fixture/{slug}/`, each by its relative
  /// `/`-separated path: its source when [holdsSource] says so and its bytes
  /// are UTF-8, else null.
  final Map<String, String?> files;

  /// Each file [holdsSource] accepts whose bytes are not UTF-8, by its relative `/`-separated
  /// path, with the reason [decodeSource] gives; its entry in [files] is null.
  final Map<String, String> undecodable;

  /// Each file [holdsDocument] accepts, by its relative `/`-separated path,
  /// as read.
  final Map<String, List<int>> documents;
}

/// A Dart source's bytes read as UTF-8: [SourceText], or [SourceNotUtf8] with the reason.
sealed class SourceDecoding {
  const SourceDecoding();
}

/// The bytes are UTF-8 and decode to [text].
final class SourceText extends SourceDecoding {
  const SourceText(this.text);

  /// The decoded source.
  final String text;
}

/// The bytes are not UTF-8.
final class SourceNotUtf8 extends SourceDecoding {
  const SourceNotUtf8(this.reason);

  /// Why, as `not UTF-8: {message} (at offset {offset})`, or
  /// `not UTF-8: {message}` without an offset.
  final String reason;
}

/// [bytes] decoded as UTF-8, malformed bytes rejected; the reason reads
/// `not UTF-8: {message} (at offset {offset})`, or `not UTF-8: {message}` without an offset.
///
/// The reason is the exception's message and offset, worded as the schema
/// set words a document that is not UTF-8.
SourceDecoding decodeSource(List<int> bytes) {
  try {
    return SourceText(utf8.decode(bytes, allowMalformed: false));
  } on FormatException catch (error) {
    return SourceNotUtf8(switch (error.offset) {
      final int offset => 'not UTF-8: ${error.message} (at offset $offset)',
      null => 'not UTF-8: ${error.message}',
    });
  }
}

/// Whether the shell reads a file's source: a `.dart` file below `surface/`,
/// `reject/` or `behavior/`, the only fixtures a set analyzes or reads as
/// Dart (ADR-001 item 2).
bool holdsSource(String relativePath) =>
    relativePath.endsWith('.dart') &&
    _sourceDirectories.contains(relativePath.split('/').first);

/// Whether a file is a binding: a `behavior/{name}_test.dart` directly under
/// `behavior/`, by its `/`-separated path relative to its slug's fixture
/// directory (ADR-001 item 4).
bool isBindingPath(String relativePath) => _bindingPath.hasMatch(relativePath);

/// Whether a file is a conformance library: a
/// `behavior/{name}_conformance.dart` directly under `behavior/`, by its
/// `/`-separated path relative to its slug's fixture directory (ADR-001
/// item 4).
bool isConformancePath(String relativePath) =>
    _conformancePath.hasMatch(relativePath);

/// Whether a file is a document the schema set judges: any file below
/// `valid/` or `invalid/`, whatever its name, nested ones included (ADR-001
/// item 5).
bool holdsDocument(String relativePath) => switch (relativePath.split('/')) {
  [final String first, _, ...] => _documentDirectories.contains(first),
  _ => false,
};

/// The path of [slug]'s contract text from the workspace root.
String contractPath(String slug) => 'hsdd/contract/$slug.md';

/// The path of [slug]'s schema file from the workspace root (ADR-001 item 2).
String schemaPath(String slug) => 'hsdd/contract/schema/$slug.schema.json';

/// The path of [slug]'s fixture directory from the workspace root, with its
/// trailing slash.
String fixtureDirectory(String slug) => 'hsdd/contract/fixture/$slug/';

const Set<String> _sourceDirectories = <String>{
  'surface',
  'reject',
  'behavior',
};

const Set<String> _documentDirectories = <String>{'valid', 'invalid'};

final RegExp _bindingPath = RegExp(r'^behavior/[^/]+_test\.dart$');

final RegExp _conformancePath = RegExp(r'^behavior/[^/]+_conformance\.dart$');
