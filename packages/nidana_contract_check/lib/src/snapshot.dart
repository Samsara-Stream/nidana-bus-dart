/// The pure core's input: what the shell reads from the workspace for one
/// slug, its contract text and its fixture tree (ADR-001 item 2).
library;

/// What the shell reads for one slug: the pure core's whole input.
final class SlugSnapshot {
  const SlugSnapshot({
    required this.slug,
    required this.contractText,
    required this.hasSchemaFile,
    required this.directories,
    required this.files,
  });

  /// The slug: the name of its fixture directory and of its contract text.
  final String slug;

  /// The text of `hsdd/contract/{slug}.md`; null when it is absent.
  final String? contractText;

  /// Whether `hsdd/contract/schema/{slug}.schema.json` exists.
  final bool hasSchemaFile;

  /// The directories below `hsdd/contract/fixture/{slug}/`, each as a
  /// relative `/`-separated path with no trailing slash.
  final Set<String> directories;

  /// The files below `hsdd/contract/fixture/{slug}/`, each by its relative
  /// `/`-separated path: its source when [holdsSource] says so, else null.
  final Map<String, String?> files;
}

/// Whether the shell reads a file's source: a `.dart` file below `surface/`,
/// `reject/` or `behavior/`, the only fixtures a set analyzes or reads as
/// Dart (ADR-001 item 2).
bool holdsSource(String relativePath) =>
    relativePath.endsWith('.dart') &&
    _sourceDirectories.contains(relativePath.split('/').first);

/// The path of [slug]'s contract text from the workspace root.
String contractPath(String slug) => 'hsdd/contract/$slug.md';

/// The path of [slug]'s fixture directory from the workspace root, with its
/// trailing slash.
String fixtureDirectory(String slug) => 'hsdd/contract/fixture/$slug/';

const Set<String> _sourceDirectories = <String>{
  'surface',
  'reject',
  'behavior',
};
