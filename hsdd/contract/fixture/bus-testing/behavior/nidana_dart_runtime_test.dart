// Binding: runs the bus-testing@v1 conformance suite against the producer's
// testing library, package:nidana_dart_runtime/testing.dart, under
// `dart test`. The suite constructs the library's own declarations, so the
// harness only settles, which has nothing left to run.
//
// The package import names the implementation, so the replay tool reports
// this binding as PENDING until the package exists (ADR-001 item 9).
// ignore: unused_import
import 'package:nidana_dart_runtime/testing.dart';
import 'package:test/test.dart';

import 'bus_testing_conformance.dart';

final class _Harness implements BusTestingHarness {
  const _Harness();

  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in busTestingConformance) {
    test(c.name, () => c.body(const _Harness()));
  }
}
