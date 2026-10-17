// covers: G5
// Exactly two scheduler providers exist (ADR-003 item 1): applications
// cannot define another.
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnProvider extends SchedulerProvider {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeProvider implements SchedulerProvider {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnProduction extends ProductionSchedulerProvider {}
