// covers: G11
// There is no publisher-less path to a StateTopic (Spec §2.4): bus.publish
// takes an event or replay topic only.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const StateTopic<int> state = StateTopic<int>(name: 'reject.state', initial: 0);

void publish(Bus bus) {
  // expect-diagnostic: argument_type_not_assignable
  bus.publish(state, 1);
  // expect-diagnostic: argument_type_not_assignable
  bus.publish<int>(state, 1);
}
