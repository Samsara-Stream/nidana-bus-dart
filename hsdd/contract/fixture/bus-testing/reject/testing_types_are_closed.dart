// covers: G2
// The testing types are made only by the runtime: none can be extended or
// implemented outside it, and the recorder, its records and the ordering
// probe have no public constructor of their own.
import 'package:nidana_dart_runtime/testing.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnTestBus extends TestBus {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeTestBus implements TestBus {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeScheduler implements VirtualScheduler {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeVirtualProvider implements VirtualSchedulerProvider {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeRecorder implements EnvelopeRecorder {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeRecord implements RecordedEnvelope {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeProbe implements OrderingProbe<int> {}

void construct() {
  // expect-diagnostic: new_with_undefined_constructor_default
  EnvelopeRecorder();
  // expect-diagnostic: new_with_undefined_constructor_default
  RecordedEnvelope();
  // expect-diagnostic: new_with_undefined_constructor_default
  OrderingProbe<int>();
}
