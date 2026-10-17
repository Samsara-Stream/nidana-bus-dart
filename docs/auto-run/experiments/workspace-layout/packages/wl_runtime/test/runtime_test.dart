import 'package:test/test.dart';
import 'package:wl_runtime/wl_runtime.dart';

void main() => test('seeded subject starts at a.b', () => expect(seeded().value.value, 'a.b'));
