// Binding: runs the same suite against FlutterExecutor under testWidgets.
import 'package:demo_contracts/demo_contracts.dart';
import 'package:demo_flutter/demo_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'executor_conformance.dart';

final class _Harness implements ExecutorHarness {
  _Harness(this.tester, this.impl);
  final WidgetTester tester;
  final FlutterExecutor impl;

  @override
  Executor get executor => impl;

  @override
  Future<void> settle() => tester.pumpAndSettle();
}

void main() {
  for (final c in executorConformance) {
    testWidgets(c.name, (tester) async {
      final impl = FlutterExecutor();
      await tester.pumpWidget(impl.app());
      await c.body(_Harness(tester, impl));
    });
  }
}
