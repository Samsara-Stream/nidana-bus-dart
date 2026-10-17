// Binding to an implementation whose package does not exist yet.
import 'package:not_yet/not_yet.dart';
import 'package:test/test.dart';

import '../../demo-api/behavior/executor_conformance.dart';

void main() {
  for (final c in executorConformance) {
    test(c.name, () => c.body(notYetHarness()));
  }
}
