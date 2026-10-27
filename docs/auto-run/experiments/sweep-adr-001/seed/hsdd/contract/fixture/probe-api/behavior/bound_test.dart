import 'package:test/test.dart';

import 'bound_conformance.dart';

final class _Harness implements ProbeHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in boundConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
