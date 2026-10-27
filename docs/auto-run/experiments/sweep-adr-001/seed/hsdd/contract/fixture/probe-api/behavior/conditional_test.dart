// The second URI of the first directive is a configuration's, and names a
// package the workspace lacks.
import 'package:path/path.dart'
    if (dart.library.io) 'package:absent_pkg/absent.dart'
    as unused;
import 'package:test/test.dart';

import 'conditional_conformance.dart';

final class _Harness implements ProbeHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in conditionalConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
