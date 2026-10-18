import 'dart:io';

import 'package:mgc_pure/mgc_pure.dart';
import 'package:test/test.dart';

void main() {
  test('twice doubles', () => expect(twice(2), 4));
  test('cwd is reported', () => print('cwd=${Directory.current.path}'));
}
