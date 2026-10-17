// Reject fixture for topic-model@v1 G12: an envelope is constructed with its
// id, payload, correlation id, timestamp, source and sensitive flag; the
// package defaults none of them, the id and the timestamp above all
// (ADR-003 item 8).
// covers: G12
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final DateTime at = DateTime.utc(2026);

// expect-diagnostic: missing_required_argument
final MessageEnvelope<int> noId = MessageEnvelope<int>(payload: 1, correlationId: 'c-1', timestamp: at, source: const UnknownSource(), sensitive: false);

// expect-diagnostic: missing_required_argument
final MessageEnvelope<int> noTimestamp = MessageEnvelope<int>(id: 'e-1', payload: 1, correlationId: 'c-1', source: const UnknownSource(), sensitive: false);

// expect-diagnostic: missing_required_argument
final MessageEnvelope<int> noPayload = MessageEnvelope<int>(id: 'e-1', correlationId: 'c-1', timestamp: at, source: const UnknownSource(), sensitive: false);

// expect-diagnostic: missing_required_argument
final MessageEnvelope<int> noCorrelation = MessageEnvelope<int>(id: 'e-1', payload: 1, timestamp: at, source: const UnknownSource(), sensitive: false);

// expect-diagnostic: missing_required_argument
final MessageEnvelope<int> noSource = MessageEnvelope<int>(id: 'e-1', payload: 1, correlationId: 'c-1', timestamp: at, sensitive: false);

// expect-diagnostic: missing_required_argument
final MessageEnvelope<int> noSensitive = MessageEnvelope<int>(id: 'e-1', payload: 1, correlationId: 'c-1', timestamp: at, source: const UnknownSource());

// expect-diagnostic: missing_required_argument
final MessageEnvelope<int> publishedWithoutId = MessageEnvelope<int>.publishedTo(const EventTopic<int>(name: 'a.tapped'), payload: 1, lineage: const Lineage.root(), freshCorrelationId: () => 'c-1', timestamp: at, source: const UnknownSource());

// expect-diagnostic: missing_required_argument
final MessageEnvelope<int> publishedWithoutTime = MessageEnvelope<int>.publishedTo(const EventTopic<int>(name: 'a.tapped'), id: 'e-1', payload: 1, lineage: const Lineage.root(), freshCorrelationId: () => 'c-1', source: const UnknownSource());
