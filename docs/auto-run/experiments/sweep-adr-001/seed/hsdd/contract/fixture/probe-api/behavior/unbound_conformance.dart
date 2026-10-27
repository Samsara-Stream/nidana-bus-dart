import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';

abstract interface class ProbeHarness {
  Future<void> settle();
}

final List<ConformanceCase<ProbeHarness>> unboundConformance =
    <ConformanceCase<ProbeHarness>>[
  (
    name: 'G2 a case no binding runs',
    body: (ProbeHarness h) async {
      expect(1, 2);
    },
  ),
];
