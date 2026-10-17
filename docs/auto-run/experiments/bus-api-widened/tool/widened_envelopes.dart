// P2 and P3 of bus-api-widened (not a fixture). Run from the experiment root
// on the patched runtime: fvm dart run tool/widened_envelopes.dart
//
// P2: the envelope of a publish made through a widened reference is built by
// MessageEnvelope.publishedTo at the call's type argument, so it is a
// MessageEnvelope<Object?>, not a MessageEnvelope<int>; what that does to
// bus-testing@v1's recorder, whose envelopesOf is typed by the topic and
// returns the delivered envelopes themselves (its G16).
// P3: what generic code can learn about a topic's value type from
// topic-model@v1's public API: Topic.valueType is a Type, which compares
// with ==, so a call can tell whether its own type argument is the value
// type, but it offers no `is` test and nothing to instantiate.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const EventTopic<int> taps = EventTopic<int>(name: 'probe.taps');
const StateTopic<List<int>> rows =
    StateTopic<List<int>>(name: 'probe.rows', initial: <int>[]);

void publishAny(Bus bus, MultiWriterTopic<Object?> topic, Object? value) =>
    bus.publish(topic, value);

bool isValueType<T>(Topic<T> topic) => T == topic.valueType;

void attempt(String label, Object? Function() body) {
  try {
    print('$label: ${body()}');
  } on TypeError catch (e) {
    print('$label: TypeError: $e');
  }
}

void main() {
  final TestBus bus = TestBus(const BusConfig(devMode: false));
  bus.start();
  final List<int> typed = <int>[];
  bus.observe(taps).listen(typed.add);
  bus.publish(taps, 1);
  publishAny(bus, taps, 2);
  print('P2 typed subscription received: $typed');
  final List<RecordedEnvelope> records = bus.recorder.envelopes;
  for (final RecordedEnvelope r in records) {
    final MessageEnvelope<Object?> e = r.envelope;
    print('P2 payload ${e.payload}: is MessageEnvelope<int> ${e is MessageEnvelope<int>}, '
        'runtimeType ${e.runtimeType}, topic ${r.topic.typeName}');
  }
  attempt('P2 recorder.envelopesOf(taps)', () => bus.recorder.envelopesOf(taps).length);
  attempt('P2 recorder.payloadsOf(taps)', () => bus.recorder.payloadsOf(taps));
  bus.shutdown();

  print('P3 isValueType<int>(taps): ${isValueType<int>(taps)}');
  print('P3 isValueType<Object?>(taps): ${isValueType<Object?>(taps)}');
  print('P3 isValueType<List<int>>(rows): ${isValueType<List<int>>(rows)}');
  print('P3 isValueType<Object?>(rows): ${isValueType<Object?>(rows)}');
}
