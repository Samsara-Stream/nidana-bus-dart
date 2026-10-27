import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';

abstract interface class ProbeHarness {
  Future<void> settle();
}

final List<ConformanceCase<ProbeHarness>> boundConformance =
    <ConformanceCase<ProbeHarness>>[
  (
    name: 'G1 a case of a bound conformance library',
    body: (ProbeHarness h) async {
      expect(1, 1);
    },
  ),
];
