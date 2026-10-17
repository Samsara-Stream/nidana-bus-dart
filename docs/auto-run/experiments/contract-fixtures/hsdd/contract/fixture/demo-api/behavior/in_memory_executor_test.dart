// Binding: runs the Executor conformance suite against InMemoryExecutor.
import 'package:demo_contracts/demo_contracts.dart';
import 'package:test/test.dart';

import 'executor_conformance.dart';

final class _Harness implements ExecutorHarness {
  @override
  final Executor executor = InMemoryExecutor();

  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in executorConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
