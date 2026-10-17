// P1: what the amended publish signature, publish<T, V extends T>(
// MultiWriterTopic<T> topic, V value), accepts and rejects, and which
// diagnostic code each rejected call reports. Each line is tagged; T5 of
// run.sh prints the (line, code) pairs, and a tagged line with no pair
// compiles.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const EventTopic<int> ints = EventTopic<int>(name: 'probe.ints');
const EventTopic<num> nums = EventTopic<num>(name: 'probe.nums');
const EventTopic<int?> maybe = EventTopic<int?>(name: 'probe.maybe');
const ReplayTopic<String> log = ReplayTopic<String>(name: 'probe.log', bufferSize: 2);
const StateTopic<int> state = StateTopic<int>(name: 'probe.state', initial: 0);

void forward<T>(Bus bus, MultiWriterTopic<T> topic, T value) =>
    bus.publish(topic, value); // P01 generic forwarding

void probe(Bus bus, Publisher p, Object o, Uri uri, RouteState s, num n) {
  bus.publish(ints, 1); // P02 well typed
  bus.publish(log, 'entry'); // P03 well typed
  bus.publish(nums, 1); // P04 a subtype value
  bus.publish(maybe, null); // P05 null on a nullable topic
  bus.publish(ints, 'one'); // P06 wrong value type
  p.publish(ints, 'one'); // P07 wrong value type, publisher
  bus.publish(ints, 1.5); // P08 a wider value
  bus.publish(ints, null); // P09 null on a non-nullable topic
  bus.publish(ints, o); // P10 an Object value
  bus.publish(state, 1); // P11 a state topic
  bus.publish<int, int>(state, 1); // P12 a state topic, explicit arguments
  p.publish(state, 1); // P13 a state topic, publisher
  bus.publish<int>(log, 'x'); // P14 one explicit type argument
  bus.publish<String, String>(log, 'entry'); // P15 two explicit, well typed
  bus.publish<num, double>(ints, 1.5); // P16 explicit widening of the topic type
  bus.publish(NavigationTopics.currentRoute, s); // P17 navigation-api reject line
  p.publish(NavigationTopics.currentRoute, s); // P18 navigation-api reject line
  p.publish(NavigationTopics.resolvedIntent, DeepLink(uri)); // P19 S12 W1
  bus.publish(NavigationTopics.intent, DeepLink(uri)); // P20 well typed intent
  final void Function(EventTopic<int>, int) tearOff = bus.publish; // P21 tear-off
  tearOff(ints, 1);
  p.publish<String, String>(log, 'entry'); // P22 two explicit, publisher
  p.publish<int>(log, 'x'); // P23 one explicit, publisher
  bus.publish<int, String>(ints, 'one'); // P24 explicit arguments that disagree
  p.publish(ints, n); // P25 a supertype value
  p.publish<num, num>(ints, n); // P26 explicit widening, publisher
}
