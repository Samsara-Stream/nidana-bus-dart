// Reads `dart analyze --format=json` stdout on stdin and prints, per
// diagnostic, `file|line|column|severity|type|code|message` (question A1).
// Prints any text before the JSON document as `prefix`.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final String all = await stdin.transform(utf8.decoder).join();
  final int start = all.indexOf('{');
  if (start != 0) print('prefix ($start chars): ${jsonEncode(start < 0 ? all : all.substring(0, start))}');
  if (start < 0) return;
  final Map<String, Object?> json = jsonDecode(all.substring(start)) as Map<String, Object?>;
  print('keys: ${json.keys.toList()} version: ${json['version']}');
  final List<Object?> diagnostics = json['diagnostics']! as List<Object?>;
  print('diagnostics: ${diagnostics.length}');
  for (final Object? d in diagnostics) {
    final Map<String, Object?> m = d! as Map<String, Object?>;
    final Map<String, Object?> loc = m['location']! as Map<String, Object?>;
    final Map<String, Object?> range = loc['range']! as Map<String, Object?>;
    final Map<String, Object?> start = range['start']! as Map<String, Object?>;
    print('${loc['file']}|${start['line']}|${start['column']}|${m['severity']}|${m['type']}|${m['code']}|${m['problemMessage']}');
  }
  if (diagnostics.isNotEmpty) {
    final Map<String, Object?> first = diagnostics.first! as Map<String, Object?>;
    print('first diagnostic keys: ${first.keys.toList()}');
    print('first location keys: ${(first['location']! as Map<String, Object?>).keys.toList()}');
  }
}
