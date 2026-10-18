// Writes {package}/.dart_tool/package_config.json for a fixture package in a
// temporary directory: every package of the workspace's configuration with
// an absolute root, plus the fixture package itself.
// Usage: dart tool/synthesize_config.dart <workspace config> <package root> <package name>
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final config = File(args[0]).absolute;
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  final base = config.uri;
  final packages = [
    for (final p in (json['packages']! as List).cast<Map<String, Object?>>())
      {...p, 'rootUri': base.resolve(p['rootUri']! as String).toString()},
    {
      'name': args[2],
      'rootUri': Directory(args[1]).absolute.uri.toString(),
      'packageUri': 'lib/',
      'languageVersion': '3.13',
    },
  ];
  final out = File('${args[1]}/.dart_tool/package_config.json')..createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'configVersion': 2,
    'packages': packages,
    'generator': 'codegen-plan-facts',
  }));
}
