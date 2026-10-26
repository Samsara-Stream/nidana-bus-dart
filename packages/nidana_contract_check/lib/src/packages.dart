/// The workspace's packages (ADR-001 item 9): the names its package
/// configuration holds, and the packages a fixture library names that it
/// lacks. A fixture that names an absent package is `Pending`.
///
/// The shell reads [packageConfigPath]; this library only reads its text.
library;

import 'package:package_config/package_config_types.dart';

import 'dart_library.dart';

/// The workspace's package configuration, from the workspace root.
const String packageConfigPath = '.dart_tool/package_config.json';

/// The names of the packages [packageConfigJson] configures; null when it is no package configuration.
///
/// The text is no package configuration when [PackageConfig.parseString]
/// reports any error through `onError`, or throws a [FormatException] (for a
/// `rootUri` that is no URI): the parser's repair of a malformed
/// configuration is not trusted.
Set<String>? packageNamesOf(String packageConfigJson) {
  try {
    return Set<String>.unmodifiable(
      PackageConfig.parseString(
        packageConfigJson,
        _configurationUri,
        onError: _reject,
      ).packages.map((Package package) => package.name),
    );
  } on _Rejected {
    return null;
  } on FormatException {
    return null;
  }
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

/// Where the configuration would be read from; it only resolves relative
/// `rootUri`s, and no file is read.
final Uri _configurationUri = Uri.parse('file:///workspace/$packageConfigPath');

/// A `package:` URI, its package name in group 1.
final RegExp _packageUri = RegExp(r'^package:([^/]+)/');

/// The package [uri] names; null when it names none.
String? _packageNamedBy(String uri) => _packageUri.firstMatch(uri)?.group(1);

/// The `onError` of [PackageConfig.parseString]: the first error it reports
/// ends the parse.
Never _reject(Object error) => throw const _Rejected();

/// The parse of a package configuration ended on an error it reported.
final class _Rejected implements Exception {
  const _Rejected();
}
