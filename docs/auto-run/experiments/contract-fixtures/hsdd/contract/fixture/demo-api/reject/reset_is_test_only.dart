// Reject fixture for demo-api G5: reset() is test-only (a warning-severity
// diagnostic from package:meta, not a compile error).
// covers: G5
import 'package:demo_contracts/demo_contracts.dart';

void misuse(InMemoryExecutor executor) {
  // expect-diagnostic: invalid_use_of_visible_for_testing_member
  executor.reset();
}
