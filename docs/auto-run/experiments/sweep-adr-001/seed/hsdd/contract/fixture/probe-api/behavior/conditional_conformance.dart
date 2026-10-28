// Each directive's second URI is a configuration's: package:test, which item 4
// bans from a conformance library, and a src/ library, which item 2 bans.
import 'package:matcher/expect.dart'
    if (dart.library.io) 'package:test/test.dart';
import 'package:nidana_contract_check/fixture.dart'
    if (dart.library.io) 'package:nidana_dart_contracts/src/topic/topic.dart'
    as unused;
import 'package:nidana_contract_check/fixture.dart';

abstract interface class ProbeHarness {
  Future<void> settle();
}

final List<ConformanceCase<ProbeHarness>> conditionalConformance =
    <ConformanceCase<ProbeHarness>>[
  (
    name: 'G4 a case of a library with conditional imports',
    body: (ProbeHarness h) async {
      expect(1, 1);
    },
  ),
];
