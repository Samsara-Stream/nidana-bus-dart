// Prototype of binding selection: for each *_test.dart binding under the
// given behavior directories, pick the runner from its imports
// (package:flutter_test means `flutter test`) and mark it PENDING when it
// imports a package the workspace's package_config does not list.
import 'dart:convert';
import 'dart:io';

final _pkgImport = RegExp(r'''^import\s+'package:([a-z0-9_]+)/''', multiLine: true);

void main(List<String> dirs) {
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
      as Map<String, Object?>;
  final known = {
    for (final p in (config['packages'] as List).cast<Map<String, Object?>>()) p['name'] as String,
  };
  for (final d in dirs) {
    final bindings = Directory(d).listSync().whereType<File>()
        .where((f) => f.path.endsWith('_test.dart')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final b in bindings) {
      final imports = _pkgImport.allMatches(b.readAsStringSync()).map((m) => m[1]!).toSet();
      final missing = imports.difference(known);
      final runner = imports.contains('flutter_test') ? 'flutter test' : 'dart test';
      print('${b.uri.pathSegments.last}: runner=$runner '
          '${missing.isEmpty ? 'READY' : 'PENDING missing=${missing.join(',')}'}');
    }
  }
}
