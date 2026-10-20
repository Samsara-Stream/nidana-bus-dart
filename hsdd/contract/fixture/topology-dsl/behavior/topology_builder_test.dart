// Binding: runs the topology-dsl@v2 recording suite against the producer's
// own recording builder in package:nidana_dart_contracts, under `dart test`.
//
// The package import names the implementation, so the replay tool reports
// this binding as PENDING until the package exists (ADR-001 item 9).
// ignore: unused_import
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

import 'recording_conformance.dart';

final class _Harness implements RecordingHarness {
  const _Harness();

  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in recordingConformance) {
    test(c.name, () => c.body(const _Harness()));
  }
}
