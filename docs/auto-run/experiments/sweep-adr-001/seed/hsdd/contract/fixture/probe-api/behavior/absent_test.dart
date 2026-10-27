import 'package:test/test.dart';

import 'absent_conformance.dart';

final class _Harness implements ProbeHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in absentConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
