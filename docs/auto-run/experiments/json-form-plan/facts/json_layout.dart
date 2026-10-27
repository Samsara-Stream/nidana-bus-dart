// F1 and F2 of json-form-plan: what dart:convert does on the pinned SDK with
// the values the codec writes and reads. Run: fvm dart run json_layout.dart
import 'dart:convert';

void show(String label, Object? value) => print('$label: ${jsonEncode(value)}');

void main() {
  const JsonEncoder indented = JsonEncoder.withIndent('  ');

  print('F1.1 layout of nested maps and lists, empty ones included:');
  print(indented.convert(<String, Object?>{
    'format': 'topology-ir@v1',
    'topologies': <Object?>[],
    'claims': <Object?>[
      <String, Object?>{
        'a': <String, Object?>{},
        'b': <Object?>[1, null, true],
        'c': <String, Object?>{'name': null},
      },
    ],
  }));
  print('F1.2 the output ends without a newline: '
      '${indented.convert(<Object?>[]).endsWith('\n')}');
  print('F1.3 escapes: ${indented.convert(<String>[
        'odd "quoted" #1 <tag> back\\slash café',
        'odd.café\nline',
        r'to$Label',
        '\u0000\u001f\u007f ',
      ])}');
  print('F1.4 keys keep insertion order: '
      '${jsonEncode(<String, Object?>{'z': 1, 'a': 2, 'm': 3})}');
  print('F1.5 a map literal is a LinkedHashMap: '
      '${<String, Object?>{}.runtimeType}');

  print('F2.1 numbers the encoder can meet:');
  show('  Duration(microseconds: 1500).inMicroseconds',
      const Duration(microseconds: 1500).inMicroseconds);
  show('  Duration(seconds: 2).inMicroseconds',
      const Duration(seconds: 2).inMicroseconds);
  show('  Duration(days: 365000).inMicroseconds',
      const Duration(days: 365000).inMicroseconds);
  show('  Duration(microseconds: 9223372036854775807).inMicroseconds',
      const Duration(microseconds: 9223372036854775807).inMicroseconds);
  show('  5000.0 (a double)', 5000.0);
  print('  (Duration.inMicroseconds is ${const Duration().inMicroseconds.runtimeType})');

  print('F2.2 what jsonDecode returns for the number forms a document can hold:');
  for (final String text in <String>[
    '5000',
    '5000.0',
    '5e3',
    '-1',
    '1.5',
    '-0',
    '-0.0',
    '9223372036854775807',
    '9223372036854775808',
    '123456789012345678901234567890',
    '1e400',
  ]) {
    final Object? v = jsonDecode(text);
    print('  $text -> ${v.runtimeType} $v');
  }

  print('F2.3 a double that is a whole number, turned into an int:');
  for (final double d in <double>[5000.0, 1e18, 9.3e18, 1e30]) {
    String r;
    try {
      r = '${d.toInt()}';
    } on Object catch (e) {
      r = 'throws ${e.runtimeType}';
    }
    print('  $d: truncateToDouble()==d ${d.truncateToDouble() == d}, toInt() $r');
  }

  print('F2.4 what an enum lookup by an unknown name does:');
  try {
    Severity.values.byName('session');
  } on Object catch (e) {
    print('  values.byName throws ${e.runtimeType}');
  }
  print('  values.asNameMap()["session"] is ${Severity.values.asNameMap()['session']}');

  print('F2.5 jsonDecode types: ${jsonDecode('{"a":[1]}').runtimeType}, '
      '${(jsonDecode('{"a":[1]}') as Map<String, Object?>)['a'].runtimeType}; '
      'is Map<String, Object?>: ${jsonDecode('{}') is Map<String, Object?>}');
  print('  <Object?, Object?>{"a": 1} is Map<String, Object?>: '
      '${<Object?, Object?>{'a': 1} is Map<String, Object?>}');
  print('  <String, int>{"a": 1} is Map<String, Object?>: '
      '${<String, int>{'a': 1} is Map<String, Object?>}');

  print('F2.6 what ArgumentError.value renders as:');
  print('  ${ArgumentError.value(2, 'inputs', 'a map edge takes exactly 1 input')}');
  print('  message: ${ArgumentError.value(2, 'inputs', 'm').message}, name: '
      '${ArgumentError.value(2, 'inputs', 'm').name}');
  print('F2.7 FormatException renders as: ${const FormatException(r'$.topologies[0].scope: is "session", not one of application, module, page')}');
}

enum Severity { low, high }
