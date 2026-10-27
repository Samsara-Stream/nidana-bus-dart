import 'package:meta/meta.dart';

import 'lineage.dart';
import 'list_equality.dart';
import 'message_source.dart';
import 'redacted_payload.dart';
import 'topic.dart';

/// The carrier of every value published to a topic (Spec §2.4). The fields
/// are the Spec's; source is typed.
@immutable
final class MessageEnvelope<T> {
  MessageEnvelope({
    required this.id,
    required this.payload,
    required this.correlationId,
    this.causationId, // null for a root message
    // copied, unmodifiable
    List<String> parentCorrelationIds = const <String>[],
    required this.timestamp,
    required this.source,
    required this.sensitive,
  }) : parentCorrelationIds = List<String>.unmodifiable(parentCorrelationIds);

  /// The envelope a stage publishes to [topic]: causation and parents from
  /// [lineage]; correlation from [lineage], or freshCorrelationId() when the
  /// lineage has none; sensitive is topic.sensitive (G14).
  factory MessageEnvelope.publishedTo(
    Topic<T> topic, {
    required String id,
    required T payload,
    required Lineage lineage,
    required String Function() freshCorrelationId,
    required DateTime timestamp,
    required MessageSource source,
  }) => MessageEnvelope<T>(
    id: id,
    payload: payload,
    correlationId: lineage.correlationId ?? freshCorrelationId(),
    causationId: lineage.causationId,
    parentCorrelationIds: lineage.parentCorrelationIds,
    timestamp: timestamp,
    source: source,
    sensitive: topic.sensitive,
  );

  final String id;
  final T payload;
  final String correlationId;
  final String? causationId;
  final List<String> parentCorrelationIds;
  final DateTime timestamp;
  final MessageSource source;
  final bool sensitive;

  /// This envelope with a sensitive payload replaced by
  /// RedactedPayload.of(payload); this envelope itself when not sensitive.
  MessageEnvelope<Object?> redacted() => sensitive
      ? MessageEnvelope<Object?>(
          id: id,
          payload: RedactedPayload.of(payload),
          correlationId: correlationId,
          causationId: causationId,
          parentCorrelationIds: parentCorrelationIds,
          timestamp: timestamp,
          source: source,
          sensitive: sensitive,
        )
      : this;

  // all eight fields; parents element-wise
  @override
  bool operator ==(Object other) =>
      other is MessageEnvelope<Object?> &&
      other.id == id &&
      other.payload == payload &&
      other.correlationId == correlationId &&
      other.causationId == causationId &&
      elementsEqual(other.parentCorrelationIds, parentCorrelationIds) &&
      other.timestamp == timestamp &&
      other.source == source &&
      other.sensitive == sensitive;

  @override
  int get hashCode => Object.hash(
    id,
    payload,
    correlationId,
    causationId,
    Object.hashAll(parentCorrelationIds),
    timestamp,
    source,
    sensitive,
  );

  /// Renders a sensitive payload redacted (G15).
  @override
  String toString() =>
      'MessageEnvelope(id: $id, '
      'payload: ${sensitive ? RedactedPayload.of(payload) : payload}, '
      'correlationId: $correlationId, causationId: $causationId, '
      'parentCorrelationIds: $parentCorrelationIds, timestamp: $timestamp, '
      'source: $source, sensitive: $sensitive)';
}
