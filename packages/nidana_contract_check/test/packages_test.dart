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
