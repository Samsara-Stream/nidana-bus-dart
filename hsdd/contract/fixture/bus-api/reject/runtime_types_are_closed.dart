// covers: G2
// The bus and the handles it hands out are made only by the runtime and
// cannot be extended, implemented or constructed outside it; the error
// family is sealed.
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnBus extends Bus {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeBus implements Bus {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakePublisher implements Publisher {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeWriter implements StateWriter<int> {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeHandle implements TopologyHandle {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeModule implements ModuleScope {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeReference implements ModuleReference {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnConfig extends BusConfig {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnTelemetry extends TelemetryObserver {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnError extends BusError {}

void construct() {
  // expect-diagnostic: new_with_undefined_constructor_default
  Publisher();
  // expect-diagnostic: new_with_undefined_constructor_default
  StateWriter<int>();
  // expect-diagnostic: new_with_undefined_constructor_default
  TopologyHandle();
  // expect-diagnostic: new_with_undefined_constructor_default
  ModuleScope();
  // expect-diagnostic: new_with_undefined_constructor_default
  ModuleReference();
}
