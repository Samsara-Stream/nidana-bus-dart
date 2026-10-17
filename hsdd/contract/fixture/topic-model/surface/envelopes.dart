// Surface fixture for topic-model@v1: message sources, envelopes, lineage
// and redaction, used the way the runtime, a recorder and a test use them.
// Passes when `fvm dart analyze --fatal-infos` reports nothing on it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

const EventTopic<String> searchQuery = EventTopic<String>(name: 'search.query');
const StateTopic<String> searchResult = StateTopic<String>(
  name: 'search.result',
  initial: '',
  sensitive: true,
);

/// Matching on the closed source family needs no default case (G16).
String sourceKind(MessageSource source) => switch (source) {
      TopologySource(topologyId: final String id) => 'topology $id',
      ServiceSource(name: final String name) => 'service $name',
      PageSource(route: final String route) => 'page $route',
      ExecutorSource(name: final String name) => 'executor $name',
      UnknownSource() => 'unknown',
    };

const List<MessageSource> sources = <MessageSource>[
  TopologySource('checkout-flow'),
  ServiceSource('payment-gateway'),
  PageSource('checkout/cart'),
  ExecutorSource('flutter-navigation'),
  UnknownSource(),
];

final MessageSource? parsed = MessageSource.tryParse('service:payment-gateway');

/// A shell publish: the caller supplies the id, the correlation and the time.
MessageEnvelope<String> rootPublish(String id, String correlationId, DateTime at) =>
    MessageEnvelope<String>(
      id: id,
      payload: 'shoes',
      correlationId: correlationId,
      timestamp: at,
      source: const PageSource('search'),
      sensitive: searchQuery.sensitive,
    );

/// Every field, written out with its type.
List<Object?> readEnvelope(MessageEnvelope<String> envelope) {
  final String id = envelope.id;
  final String payload = envelope.payload;
  final String correlationId = envelope.correlationId;
  final String? causationId = envelope.causationId;
  final List<String> parents = envelope.parentCorrelationIds;
  final DateTime timestamp = envelope.timestamp;
  final MessageSource source = envelope.source;
  final bool sensitive = envelope.sensitive;
  final MessageEnvelope<Object?> widened = envelope;
  final MessageEnvelope<Object?> shown = envelope.redacted();
  return <Object?>[
    id,
    payload,
    correlationId,
    causationId,
    parents,
    timestamp,
    source,
    sensitive,
    widened,
    shown,
    envelope == widened,
    envelope.hashCode,
  ];
}

/// A pipeline stage: lineage enters from a published envelope, combines,
/// and leaves as a new published envelope.
MessageEnvelope<String> derive(
  MessageEnvelope<String> query,
  MessageEnvelope<String> filter,
  String Function() newId,
  DateTime at,
) {
  final Lineage fromQuery = Lineage.causedBy(query);
  final Lineage fromFilter = Lineage.causedBy(filter);
  final Lineage combined = Lineage.combine(
    <Lineage>[fromQuery, fromFilter],
    trigger: 0,
    freshCorrelationId: newId,
  );
  final Lineage latest = Lineage.withLatestFrom(combined, <Lineage>[fromFilter]);
  const Lineage untraced = Lineage.root();
  const Lineage started = Lineage.root(correlationId: 'flow-1', sensitive: true);
  final String? causationId = latest.causationId;
  final String? correlationId = latest.correlationId;
  final List<String> parents = latest.parentCorrelationIds;
  final bool sensitive = latest.sensitive;
  final bool same = untraced == started || latest.hashCode == 0;
  return MessageEnvelope<String>.publishedTo(
    searchResult,
    id: newId(),
    payload: '$causationId $correlationId $parents $sensitive $same',
    lineage: latest,
    freshCorrelationId: newId,
    timestamp: at,
    source: const TopologySource('search-flow'),
  );
}

/// What a recorder keeps for a sensitive payload (Spec §9.2 item 2).
String redact(Object? payload) {
  final RedactedPayload redacted = RedactedPayload.of(payload);
  final String typeName = redacted.typeName;
  final String hash = redacted.hash;
  return '$typeName $hash $redacted ${redacted == RedactedPayload.of(payload)}';
}
