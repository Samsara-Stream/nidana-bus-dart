// Binding: runs the topic-model@v1 conformance suite against the producer's
// own declarations in package:nidana_dart_contracts, under `dart test`.
//
// The package import names the implementation, so the replay tool reports
// this binding as PENDING until the package exists (ADR-001 item 9).
// ignore: unused_import
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

import 'topic_model_conformance.dart';

final class _Harness implements TopicModelHarness {
  const _Harness();

  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in topicModelConformance) {
    test(c.name, () => c.body(const _Harness()));
  }
}
