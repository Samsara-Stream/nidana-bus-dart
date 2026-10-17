// covers: G8
// getCurrentValue is defined on a StateTopic only and getBufferedValues on a
// ReplayTopic only (Spec §2.5): any other variant does not compile.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const StateTopic<int> state = StateTopic<int>(name: 'reject.state', initial: 0);
const EventTopic<int> event = EventTopic<int>(name: 'reject.event');
const ReplayTopic<int> replay =
    ReplayTopic<int>(name: 'reject.replay', bufferSize: 2);

void read(Bus bus) {
  // expect-diagnostic: argument_type_not_assignable
  bus.getCurrentValue<int>(event);
  // expect-diagnostic: argument_type_not_assignable
  bus.getCurrentValue<int>(replay);
  // expect-diagnostic: argument_type_not_assignable
  bus.getBufferedValues<int>(state);
  // expect-diagnostic: argument_type_not_assignable
  bus.getBufferedValues<int>(event);
}
