// A consumer's stand-in, bound to the root fixture's conformance library by
// relative path from a member's test directory.
import 'package:demo_contracts/demo_contracts.dart';
import 'package:test/test.dart';

import '../../../hsdd/contract/fixture/demo-api/behavior/executor_conformance.dart';

final class _StandIn implements Executor {
  String _r = '/';
  @override
  String get current => _r;
  @override
  Future<void> go(String route) async => _r = route;
}

final class _H implements ExecutorHarness {
  @override
  final Executor executor = _StandIn();
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in executorConformance) {
    test(c.name, () => c.body(_H()));
  }
}
