// a's report from inside a test, under `dart test` (the VM in JIT mode, with
// the test runner's libraries loaded too).
import 'package:probe/fns.dart';
import 'package:probe/report.dart';
import 'package:test/test.dart';

void main() {
  test('report', () => report('test', probeFunctions()));
}
