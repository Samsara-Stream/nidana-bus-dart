// IOOverrides facts (question O1): does Directory.current inside
// IOOverrides.runZoned return the override, for `absolute` too; and what
// matcher's fail throws outside a test.
import 'dart:io';

import 'package:matcher/expect.dart';

void main(List<String> args) {
  final Directory fake = Directory(args.single);
  IOOverrides.runZoned(() {
    print('inside: Directory.current = ${Directory.current.path}');
    print('inside: Directory("x").absolute = ${Directory('x').absolute.path}');
    print('inside: File("y").existsSync() relative = ${File('y').existsSync()}');
  }, getCurrentDirectory: () => fake);
  print('outside: Directory.current = ${Directory.current.path}');
  try {
    fail('message\nsecond line');
  } on Object catch (e) {
    print('fail throws ${e.runtimeType}: ${e.toString().replaceAll('\n', r'\n')}');
  }
}
