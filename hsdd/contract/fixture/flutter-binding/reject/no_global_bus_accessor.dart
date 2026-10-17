// covers: G3
// The bus is reached by explicit reference through the widget tree (Spec
// §3.1; Guide §6.4): BusProvider declares no static member that yields a bus
// without a BuildContext.
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

void lookUp() {
  // expect-diagnostic: undefined_getter
  BusProvider.instance;
  // expect-diagnostic: undefined_getter
  BusProvider.current;
  // expect-diagnostic: static_access_to_instance_member
  BusProvider.bus;
  // expect-diagnostic: not_enough_positional_arguments
  BusProvider.of();
}
