// Reject fixture for topic-model@v1 G4: no field of a topic, a topic
// reference, an envelope, a lineage, a source or a redacted payload can be
// assigned (Spec §2.1, §8).
// covers: G4
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

void misuse(
  StateTopic<int> topic,
  TopicRef ref,
  MessageEnvelope<int> envelope,
  Lineage lineage,
  ServiceSource source,
  RedactedPayload redacted,
) {
  // expect-diagnostic: assignment_to_final
  topic.name = 'other.name';
  // expect-diagnostic: assignment_to_final
  topic.sensitive = true;
  // expect-diagnostic: assignment_to_final
  ref.typeName = 'String';
  // expect-diagnostic: assignment_to_final
  envelope.payload = 2;
  // expect-diagnostic: assignment_to_final
  envelope.parentCorrelationIds = <String>[];
  // expect-diagnostic: assignment_to_final
  lineage.correlationId = 'c-2';
  // expect-diagnostic: assignment_to_final
  source.name = 'other';
  // expect-diagnostic: assignment_to_final
  redacted.hash = '00000000';
}
