// P2: how bus-api@v1's publish signature and a generic intent constructor
// infer their type arguments.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const EventTopic<int> ints = EventTopic<int>(name: 'probe.ints');

// The exact form: the value's type is bounded by the topic's.
void publishExact<T, V extends T>(MultiWriterTopic<T> topic, V value) {}

// A generic constructor form of GoTo, as the Guide writes it.
final class GenericGoTo<A> {
  const GenericGoTo(this.route, [this.args]);
  final NavRoute<A> route;
  final A? args;
}

const NavRoute<int> detail = NavRoute<int>('probe/detail');

void probe(Bus bus, Publisher p, Uri uri) {
  p.publish(NavigationTopics.resolvedIntent, DeepLink(uri)); // W1
  bus.publish(ints, 'one'); // W2
  publishExact(NavigationTopics.resolvedIntent, DeepLink(uri)); // W3
  publishExact(ints, 'one'); // W4
  publishExact(NavigationTopics.resolvedIntent, detail.go(1)); // W5 (well typed)
  final g = GenericGoTo(detail, 'one'); // W6
  final GenericGoTo<int> h = GenericGoTo(detail, 'one'); // W6b
  detail.go('one'); // W7
  // ignore: unused_local_variable
  final Object? x = (g, h);
}
