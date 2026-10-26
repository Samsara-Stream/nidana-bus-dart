// package:package_config 2.2.0 facts (question P1): parse the workspace's
// package configuration without I/O, and what malformed input does.
import 'dart:io';

import 'package:package_config/package_config.dart';

void main(List<String> args) {
  final String path = args.single;
  final String text = File(path).readAsStringSync();
  final PackageConfig config = PackageConfig.parseString(text, Uri.file(path));
  final List<String> names = config.packages.map((Package p) => p.name).toList()..sort();
  print('packages (${names.length}): ${names.join(', ')}');
  for (final String bad in <String>['', '{}', '{"configVersion": 2}', '{"configVersion": 2, "packages": [{"name": "a"}]}', 'not json',
      '{"configVersion": 2, "packages": [{"name": "a", "rootUri": "/nowhere/a/"}]}']) {
    try {
      final PackageConfig c = PackageConfig.parseString(bad, Uri.file(path));
      print('  ${bad.isEmpty ? '(empty)' : bad}: parsed, ${c.packages.length} packages');
    } on Object catch (e) {
      print('  ${bad.isEmpty ? '(empty)' : bad}: ${e.runtimeType}: ${e.toString().split('\n').first}');
    }
  }
  var errors = <Object>[];
  final PackageConfig lenient = PackageConfig.parseString('{"configVersion": 2, "packages": [{"name": "a"}]}', Uri.file(path),
      onError: (Object e) => errors.add(e));
  print('  with onError: ${lenient.packages.length} packages, ${errors.length} errors: ${errors.map((Object e) => e.toString().split('\n').first)}');
}
