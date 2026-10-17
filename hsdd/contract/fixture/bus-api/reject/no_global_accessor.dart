// covers: G1
// A bus is reached by explicit reference only (Spec §3.1): Bus declares no
// static member that returns a bus.
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

void lookUp(Bus bus) {
  // expect-diagnostic: undefined_getter
  Bus.instance;
  // expect-diagnostic: undefined_getter
  Bus.current;
  // expect-diagnostic: undefined_method
  Bus.of(bus);
}
