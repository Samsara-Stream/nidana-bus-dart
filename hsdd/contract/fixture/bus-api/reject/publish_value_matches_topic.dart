// covers: G40
// A publish type-checks its value against its topic (Spec §4.2): with the
// type arguments inferred, a value whose static type is not the topic's
// value type or a subtype of it does not compile, on the publisher-less path
// and on a publisher; inference does not widen the topic's type to admit it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const EventTopic<int> event = EventTopic<int>(name: 'reject.event');
const ReplayTopic<int> replay =
    ReplayTopic<int>(name: 'reject.replay', bufferSize: 2);

void misuse(Bus bus, Publisher publisher, num wider, Object anything) {
  // An unrelated value type.
  // expect-diagnostic: could_not_infer
  bus.publish(event, 'one');
  // expect-diagnostic: could_not_infer
  publisher.publish(replay, 'one');
  // A supertype of the topic's value type.
  // expect-diagnostic: could_not_infer
  bus.publish(replay, wider);
  // expect-diagnostic: could_not_infer
  publisher.publish(event, anything);
  // A sibling type under a common supertype.
  // expect-diagnostic: could_not_infer
  publisher.publish(event, 1.5);
  // Null on a topic of a non-nullable type.
  // expect-diagnostic: could_not_infer
  bus.publish(replay, null);
  // Explicit type arguments that disagree with each other.
  // expect-diagnostic: type_argument_not_matching_bounds
  bus.publish<int, String>(event, 'one');
}
