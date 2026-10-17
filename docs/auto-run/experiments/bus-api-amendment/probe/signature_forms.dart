// P2: which signature forms reject a value of the wrong type while a state
// topic still reports argument_type_not_assignable alone, as the reject
// fixtures of bus-api@v1 and navigation-api@v1 expect. Each form is a
// top-level function standing in for Bus.publish; the probe lines call each
// with the same arguments. T5 of run.sh prints the (line, code) pairs.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

const EventTopic<int> ints = EventTopic<int>(name: 'probe.ints');
const StateTopic<int> state = StateTopic<int>(name: 'probe.state', initial: 0);

// F0, bus-api@v1 as written: the value's type takes part in inferring T.
void f0<T>(MultiWriterTopic<T> topic, T value) {}
// F1, the form the step names: V bounded by T, T unbounded.
void f1<T, V extends T>(MultiWriterTopic<T> topic, V value) {}
// F2: as F1, with T bounded by Object? so a failed inference falls back to
// Object? rather than dynamic.
void f2<T extends Object?, V extends T>(MultiWriterTopic<T> topic, V value) {}

void forward<T>(MultiWriterTopic<T> topic, T value) {
  f2(topic, value); // L01 F2 generic forwarding
}

void probe(Object o) {
  f0(ints, 'one'); // L02 F0 wrong value type
  f0(state, 1); // L03 F0 state topic
  f1(ints, 'one'); // L04 F1 wrong value type
  f1(state, 1); // L05 F1 state topic
  f2(ints, 'one'); // L06 F2 wrong value type
  f2(state, 1); // L07 F2 state topic
  f2<int, int>(state, 1); // L08 F2 state topic, explicit
  f2(ints, 1); // L09 F2 well typed
  f2(ints, 1.5); // L10 F2 wider value
  f2(ints, null); // L11 F2 null
  f2(ints, o); // L12 F2 an Object value
  f2<num, double>(ints, 1.5); // L13 F2 explicit widening
  f2<int>(ints, 1); // L14 F2 one explicit type argument
}
