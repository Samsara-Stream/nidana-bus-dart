// The FormatException utf8.decode throws for the bytes the plan's tests seed.
import 'dart:convert';

void main() {
  for (final List<int> bytes in <List<int>>[
    <int>[0x2f, 0x2f, 0x20, 0xff, 0x0a],
    <int>[0xff],
  ]) {
    try {
      utf8.decode(bytes, allowMalformed: false);
      print('$bytes: decoded');
    } on FormatException catch (error) {
      print('$bytes: message "${error.message}", offset ${error.offset}');
    }
  }
}
