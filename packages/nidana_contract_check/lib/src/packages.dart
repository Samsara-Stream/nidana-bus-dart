/// The workspace's packages (ADR-001 item 9): the names its package
/// configuration holds and the root of each, and the packages a fixture
/// library names that it lacks. A fixture that names an absent package is
/// `Pending`.
///
/// The shell reads [packageConfigPath]; this library only reads its text.
library;

import 'package:package_config/package_config_types.dart';

import 'dart_library.dart';

/// The workspace's package configuration, from the workspace root.
const String packageConfigPath = '.dart_tool/package_config.json';

/// The names of the packages [packageConfigJson] configures; null when it is no package configuration.
///
/// The names are the keys of [packageRootsOf], so a text is no package
/// configuration here exactly when it is none there.
Set<String>? packageNamesOf(String packageConfigJson) =>
    switch (packageRootsOf(packageConfigJson, _configurationUri)) {
      final Map<String, Uri> roots => Set<String>.unmodifiable(roots.keys),
      null => null,
    };

/// The root of each package [packageConfigJson] configures, absolute and ending in `/`, its
/// relative `rootUri`s resolved against [configurationUri]; null when it is no package
/// configuration, as [packageNamesOf] judges one.
///
/// The text is no package configuration when [PackageConfig.parseString]
/// reports any error through `onError`, or throws a [FormatException] (for a
/// `rootUri` that is no URI): the parser's repair of a malformed
/// configuration is not trusted. Nor is it one when a root is not a `file:`
/// URI with an empty authority whose path segments, decoded, hold no `/`,
/// which the parser accepts (`http:`, `data:`, `file://host/`,
/// `file:///a%2Fb/`): such a root names no directory, [Uri.toFilePath]
/// throws on it, and a configuration pub writes holds none. The whole
/// configuration is refused rather than that package dropped, so the
/// replay ends in an environment error (exit 2) instead of reporting a
/// package it configures as absent. [configurationUri] is an absolute
/// `file:` URI, where the configuration is read from.
Map<String, Uri>? packageRootsOf(
  String packageConfigJson,
  Uri configurationUri,
) {
  final PackageConfig configuration;
  try {
    configuration = PackageConfig.parseString(
      packageConfigJson,
      configurationUri,
      onError: _reject,
    );
  } on _Rejected {
    return null;
  } on FormatException {
    return null;
  }
  final Map<String, Uri> roots = Map<String, Uri>.unmodifiable(<String, Uri>{
    for (final Package package in configuration.packages)
      package.name: package.root,
  });
  return roots.values.every(_namesDirectory) ? roots : null;
}

/// Each package a `package:` URI of [library]'s imports and exports names that [packages] lacks, once, ascending.
///
/// The name of a `package:{name}/...` URI is the text between `package:` and
/// the first `/`. A `dart:` URI, a relative URI and a `package:` URI with no
/// name before a `/` name no package.
List<String> absentPackages(DartLibrary library, Set<String> packages) =>
    List<String>.unmodifiable(
      library.directives
          .map(_packageNamedBy)
          .nonNulls
          .where((String name) => !packages.contains(name))
          .toSet()
          .toList()
        ..sort(),
    );

/// The configuration URI [packageNamesOf] parses against: it only resolves
/// relative `rootUri`s, and no file is read.
final Uri _configurationUri = Uri.parse('file:///workspace/$packageConfigPath');

/// A `package:` URI, its package name in group 1.
final RegExp _packageUri = RegExp(r'^package:([^/]+)/');

/// The package [uri] names; null when it names none.
String? _packageNamedBy(String uri) => _packageUri.firstMatch(uri)?.group(1);

/// Whether [root] names a directory as [Uri.toFilePath] reads one on a platform that is not
/// Windows: a `file:` URI with an empty authority, no path segment of which holds a `/` once
/// decoded.
///
/// The parser has already refused a root with a query or a fragment.
bool _namesDirectory(Uri root) =>
    root.isScheme('file') &&
    root.authority.isEmpty &&
    root.pathSegments.every((String segment) => !segment.contains('/'));

/// The `onError` of [PackageConfig.parseString]: the first error it reports
/// ends the parse.
Never _reject(Object error) => throw const _Rejected();

/// The parse of a package configuration ended on an error it reported.
final class _Rejected implements Exception {
  const _Rejected();
}
