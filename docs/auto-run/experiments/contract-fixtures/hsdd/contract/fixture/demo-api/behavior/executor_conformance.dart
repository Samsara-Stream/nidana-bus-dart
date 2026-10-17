// Conformance library for the Executor interface of demo-api. Cases are
// values; a binding registers them with its own test runner. No import of
// package:test or package:flutter_test, so one suite binds under both.
import 'package:demo_contracts/demo_contracts.dart';
import 'package:matcher/expect.dart';

/// What a binding supplies for one implementation.
abstract interface class ExecutorHarness {
  Executor get executor;

  /// Lets the implementation reach quiescence (no-op for a pure one,
  /// pumpAndSettle under testWidgets).
  Future<void> settle();
}

typedef ConformanceCase<H> = ({String name, Future<void> Function(H) body});

final List<ConformanceCase<ExecutorHarness>> executorConformance = [
  (
    name: 'G2 a fresh executor is at the root route',
    body: (h) async {
      expect(h.executor.current, '/');
    },
  ),
  (
    name: 'G3 go then settle moves to the route',
    body: (h) async {
      await h.executor.go('/a');
      await h.settle();
      expect(h.executor.current, '/a');
    },
  ),
];
