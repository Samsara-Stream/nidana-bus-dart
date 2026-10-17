// Surface of bus-testing@v1, the envelope recorder and the ordering probe:
// every declaration used with the types the Interface states. Passes when
// `fvm dart analyze --fatal-infos` reports nothing (ADR-001 item 4).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const StateTopic<int> count = StateTopic<int>(name: 'surface.count', initial: 0);
const EventTopic<String> secret =
    EventTopic<String>(name: 'surface.secret', sensitive: true);

void record(Bus bus, TestBus testBus) {
  final EnvelopeRecorder attached = EnvelopeRecorder.attach(bus);
  final EnvelopeRecorder own = testBus.recorder;
  final List<RecordedEnvelope> all = own.envelopes;
  final RecordedEnvelope first = all.first;
  final TopicRef topic = first.topic;
  final MessageEnvelope<Object?> shown = first.envelope;
  final MessageEnvelope<Object?> raw = first.unredacted;
  final bool same = first == all.last;
  final int hash = first.hashCode;
  final String rendered = first.toString();
  final List<MessageEnvelope<int>> counts = own.envelopesOf(count);
  final List<int> countPayloads = own.payloadsOf(count);
  final List<MessageEnvelope<String>> secrets =
      own.envelopesOf(secret, unredacted: true);
  final List<String> secretPayloads = own.payloadsOf(secret, unredacted: true);
  print(<Object?>[
    attached, topic, shown, raw, same, hash, rendered, counts, countPayloads,
    secrets, secretPayloads,
  ]);
}

void probe(Bus bus) {
  final OrderingProbe<int> defaults = OrderingProbe.attach(bus, count);
  final OrderingProbe<int> probe =
      OrderingProbe<int>.attach(bus, count, subscriptions: 5);
  final Topic<int> topic = probe.topic;
  final List<List<int>> received = probe.received;
  final bool consistent = probe.isConsistent;
  probe.cancel();
  defaults.cancel();
  print(<Object?>[topic, received, consistent]);
}
