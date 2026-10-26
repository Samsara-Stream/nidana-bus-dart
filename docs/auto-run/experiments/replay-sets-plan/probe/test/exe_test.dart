// Prints the dart running a test under `dart test` (question X1).
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('resolvedExecutable under dart test', () {
    print('under dart test, Platform.resolvedExecutable: ${Platform.resolvedExecutable}');
    expect(File(Platform.resolvedExecutable).existsSync(), isTrue);
  });
}
