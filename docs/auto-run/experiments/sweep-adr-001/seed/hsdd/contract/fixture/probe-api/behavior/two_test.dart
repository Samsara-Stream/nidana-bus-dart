import 'package:test/test.dart';

import 'absent_conformance.dart';
import 'bound_conformance.dart';

final class _Harness implements ProbeHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in <ConformanceCase<ProbeHarness>>[...boundConformance, ...absentConformance]) {
    test(c.name, () => c.body(_Harness()));
  }
}
