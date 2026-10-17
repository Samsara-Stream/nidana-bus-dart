// Binding: runs navigation-api@v1's navigation conformance suite against the
// producer's declarations in package:nidana_dart_navigation, under
// `dart test`. The suite constructs the declarations directly and drives its
// own TestBus instances (bus-testing@v1), so the harness only settles, which
// has nothing left to run.
//
// The package import names the implementation, so the replay tool reports
// this binding as PENDING until nidana_dart_navigation exists (ADR-001
// item 9).
// ignore: unused_import
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:test/test.dart';

import 'navigation_conformance.dart';

final class _Harness implements NavigationHarness {
  const _Harness();

  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in navigationConformance) {
    test(c.name, () => c.body(const _Harness()));
  }
}
