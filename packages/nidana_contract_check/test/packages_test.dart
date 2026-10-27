// packages/nidana_contract_check/test/packages_test.dart
import 'package:nidana_contract_check/src/dart_library.dart';
import 'package:nidana_contract_check/src/packages.dart';
import 'package:test/test.dart';

const String config = '''
{
  "configVersion": 2,
  "packages": [
    {"name": "matcher", "rootUri": "file:///cache/matcher-0.12.20", "packageUri": "lib/", "languageVersion": "3.4"},
    {"name": "sample", "rootUri": "../packages/sample", "packageUri": "lib/", "languageVersion": "3.13"}
  ],
  "generator": "pub"
}
''';

void main() {
  test('packageNamesOf reads the names of the configured packages', () {
    expect(packageNamesOf(config), <String>{'matcher', 'sample'});
    expect(packageConfigPath, '.dart_tool/package_config.json');
  });
  test('packageNamesOf is null for text that is no package configuration', () {
    for (final String text in <String>[
      '',
      'not json',
      '{}',
      '{"configVersion": 2}',
      '{"configVersion": 2, "packages": [{"name": "a"}]}',
    ]) {
      expect(packageNamesOf(text), isNull, reason: text);
    }
  });
  test('packageNamesOf is empty for a configuration of no packages', () {
    expect(packageNamesOf('{"configVersion": 2, "packages": []}'), isEmpty);
  });
  test('packageNamesOf is null for a configuration the parser rejects past the JSON', () {
    for (final String packages in <String>[
      // Two packages of one name: reported through onError.
      '{"name": "a", "rootUri": "file:///a/"}, {"name": "a", "rootUri": "file:///b/"}',
      // A rootUri that is no URI: Uri.parse throws past onError.
      '{"name": "a", "rootUri": "file://[x/"}',
    ]) {
      expect(
        packageNamesOf('{"configVersion": 2, "packages": [$packages]}'),
        isNull,
        reason: packages,
      );
    }
  });
  test('packageRootsOf resolves each root against the configuration', () {
    expect(
      packageRootsOf(
        '{"configVersion": 2, "packages": [{"name": "sample", "rootUri": "../packages/sample", "packageUri": "lib/"}, {"name": "path", "rootUri": "file:///cache/path-1.9.1/", "packageUri": "lib/"}]}',
        Uri.parse('file:///w/.dart_tool/package_config.json'),
      ),
      <String, Uri>{
        'sample': Uri.parse('file:///w/packages/sample/'),
        'path': Uri.parse('file:///cache/path-1.9.1/'),
      },
    );
    expect(
      packageRootsOf(
        'not json',
        Uri.parse('file:///w/.dart_tool/package_config.json'),
      ),
      isNull,
    );
  });
  // Beyond the brief: packageNamesOf is the key set of packageRootsOf, so
  // every text one rejects the other rejects too.
  test('packageRootsOf is null for every text packageNamesOf rejects', () {
    for (final String text in <String>[
      '',
      '{}',
      '{"configVersion": 2, "packages": [{"name": "a"}]}',
      '{"configVersion": 2, "packages": [{"name": "a", "rootUri": "file:///a/"}, {"name": "a", "rootUri": "file:///b/"}]}',
      '{"configVersion": 2, "packages": [{"name": "a", "rootUri": "file://[x/"}]}',
    ]) {
      expect(packageNamesOf(text), isNull, reason: text);
      expect(
        packageRootsOf(text, Uri.parse('file:///w/$packageConfigPath')),
        isNull,
        reason: text,
      );
    }
  });
  // Routed: a root that is no plain file: URI names no directory a process
  // can start in, and Uri.toFilePath throws on it. The parser accepts every
  // one of these, so the configuration is refused here, by both readers.
  test('a configuration with a root that is no plain file: URI is no package configuration', () {
    for (final String root in <String>[
      'http://cache.example/a/',
      'data:,a/',
      'file://host/a/',
      'file://user@/a/',
      'file:///a%2Fb/',
    ]) {
      final String text =
          '{"configVersion": 2, "packages": [{"name": "ok", "rootUri": "file:///ok/"}, {"name": "a", "rootUri": "$root"}]}';
      expect(packageNamesOf(text), isNull, reason: root);
      expect(
        packageRootsOf(text, Uri.parse('file:///w/$packageConfigPath')),
        isNull,
        reason: root,
      );
    }
    expect(
      packageRootsOf(
        '{"configVersion": 2, "packages": [{"name": "a", "rootUri": "file:/a"}, {"name": "b", "rootUri": "b%20c/"}]}',
        Uri.parse('file:///w/$packageConfigPath'),
      ),
      <String, Uri>{
        'a': Uri.parse('file:///a/'),
        'b': Uri.parse('file:///w/.dart_tool/b%20c/'),
      },
    );
  });
  test('absentPackages names each package an import or export names that the configuration lacks', () {
    final DartLibrary library = readDartLibrary('''
import 'dart:async';
import 'package:zeta/zeta.dart';
import 'package:sample/sample.dart' as s;
export 'package:alpha/src/hidden.dart';
import 'package:zeta/other.dart';
import '../other.dart';
''');
    expect(absentPackages(library, <String>{'sample'}), <String>[
      'alpha',
      'zeta',
    ]);
    expect(
      absentPackages(library, <String>{'alpha', 'sample', 'zeta'}),
      isEmpty,
    );
  });
  test('a package: URI without a name followed by / names no package', () {
    final DartLibrary library = readDartLibrary('''
import 'package:solo';
import 'package:/nameless.dart';
// import 'package:commented/out.dart';
''');
    expect(absentPackages(library, const <String>{}), isEmpty);
  });
}
