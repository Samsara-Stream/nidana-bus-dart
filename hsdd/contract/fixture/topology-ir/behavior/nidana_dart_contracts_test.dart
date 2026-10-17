// Binding: runs the topology-ir@v1 conformance suite against the producer's
// own declarations in package:nidana_dart_contracts, under `dart test`, from
// the workspace root.
//
// The package import names the implementation, so the replay tool reports
// this binding as PENDING until the package exists (ADR-001 item 9).
// ignore: unused_import
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'topology_ir_conformance.dart';

final class _Harness implements TopologyIrHarness {
  const _Harness();

  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in topologyIrConformance) {
    test(c.name, () => c.body(const _Harness()));
  }
}
