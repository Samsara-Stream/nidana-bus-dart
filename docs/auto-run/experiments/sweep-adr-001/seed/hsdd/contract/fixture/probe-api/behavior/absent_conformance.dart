import 'package:absent_pkg/absent.dart';
import 'package:nidana_contract_check/fixture.dart';

abstract interface class ProbeHarness {
  Future<void> settle();
}

final List<ConformanceCase<ProbeHarness>> absentConformance =
    <ConformanceCase<ProbeHarness>>[
  (
    name: 'G3 a case of a library that imports an absent package',
    body: (ProbeHarness h) async {
      absent();
    },
  ),
];
