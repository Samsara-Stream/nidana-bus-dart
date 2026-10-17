// Probe: what the amendment changes for type inference. Before it, the least
// upper bound of EventTopic<int> and ReplayTopic<int> is Topic<int>; after
// it, MultiWriterTopic<int>. Each line below is analyzed against both
// stand-ins (run.sh P2).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

const EventTopic<int> event = EventTopic<int>(name: 'a.tapped');
const ReplayTopic<int> replay = ReplayTopic<int>(name: 'a.log', bufferSize: 1);
const StateTopic<int> state = StateTopic<int>(name: 'a.count', initial: 0);

// The inferred element type of a list of an event and a replay topic.
final mixed = [event, replay];
final String mixedType = mixed.runtimeType.toString();

void grow(bool flag) {
  // Compiles before the amendment, where mixed is a List<Topic<int>>.
  mixed.add(state);
  var either = flag ? event : replay;
  // Compiles before the amendment, where either is a Topic<int>.
  either = state;
  either.name;
}
