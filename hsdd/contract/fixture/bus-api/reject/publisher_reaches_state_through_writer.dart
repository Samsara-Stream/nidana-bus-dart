// covers: G19, G20
// A publisher publishes to event and replay topics only, claims state topics
// only, and reaches a state topic only through the typed writer handle a
// claim yields (Spec §2.4, §3.11).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const StateTopic<int> state = StateTopic<int>(name: 'reject.state', initial: 0);
const EventTopic<int> event = EventTopic<int>(name: 'reject.event');
const ReplayTopic<int> replay =
    ReplayTopic<int>(name: 'reject.replay', bufferSize: 2);

void misuse(Bus bus, Publisher publisher) {
  // expect-diagnostic: argument_type_not_assignable
  publisher.publish(state, 1);
  // expect-diagnostic: set_element_type_not_assignable
  bus.publisher(const ServiceSource('reject'), writes: {event});
  // expect-diagnostic: set_element_type_not_assignable
  bus.publisher(const ServiceSource('reject'), writes: {replay});
  // expect-diagnostic: argument_type_not_assignable
  publisher.writer<int>(event);
  final StateWriter<int> writer = publisher.writer(state);
  // expect-diagnostic: argument_type_not_assignable
  writer.publish('one');
}
