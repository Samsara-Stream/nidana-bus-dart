import 'package:meta/meta.dart';

import 'lineage.dart';
import 'message_source.dart';
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
    this.parentCorrelationIds = const <String>[], // copied, unmodifiable
    required this.timestamp,
    required this.source,
    required this.sensitive,
  });

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
  }) => throw UnimplementedError();

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
  MessageEnvelope<Object?> redacted() => throw UnimplementedError();
}
