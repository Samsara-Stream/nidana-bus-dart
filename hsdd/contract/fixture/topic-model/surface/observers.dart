// Surface fixture for topic-model@v1: the observer seam (Spec §3.7, §9.1),
// implemented the way an application observer and a sink implement it.
// Passes when `fvm dart analyze --fatal-infos` reports nothing on it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

/// Spec §9.1's logging observer: sees non-sensitive topics only.
final class LoggingObserver implements BusObserver {
  @override
  Set<ObserverCapability> get capabilities => const <ObserverCapability>{
        ObserverCapability.observeAll,
      };

  @override
  void onPublish(
    TopicRef topic,
    MessageEnvelope<Object?> envelope,
    ObserveContext context,
  ) {
    context.log(
      LogLevel.info,
      'topic publish',
      fields: <String, Object?>{
        'topic': topic.name,
        'id': envelope.id,
        'correlation': envelope.correlationId,
        'causation': envelope.causationId,
        'source': envelope.source.toString(),
      },
    );
    context.metric(
      'nidana.publish',
      1,
      tags: <String, String>{'topic': topic.name},
    );
    final String? cause = envelope.causationId;
    final SpanHandle span = context.span(
      topic.name,
      attributes: <String, Object?>{'id': envelope.id},
      links: <String>[if (cause != null) cause],
    );
    span.setAttribute('source', envelope.source.toString());
    span.end();
  }
}

/// A sensitive-capable observer redacts before forwarding (Spec §9.2).
final class AuditObserver implements BusObserver {
  @override
  Set<ObserverCapability> get capabilities => const <ObserverCapability>{
        ObserverCapability.observeAll,
        ObserverCapability.observeSensitive,
      };

  @override
  void onPublish(
    TopicRef topic,
    MessageEnvelope<Object?> envelope,
    ObserveContext context,
  ) {
    final MessageEnvelope<Object?> safe = envelope.redacted();
    context.log(LogLevel.debug, safe.toString());
    context.log(LogLevel.warning, topic.typeName);
    context.log(LogLevel.error, topic.variant.name);
  }
}

/// A sink an application or a test could put behind an ObserveContext.
final class RecordingSpan implements SpanHandle {
  final Map<String, Object?> attributes = <String, Object?>{};
  bool ended = false;

  @override
  void setAttribute(String key, Object? value) => attributes[key] = value;

  @override
  void end() => ended = true;
}

final class RecordingContext implements ObserveContext {
  final List<String> lines = <String>[];

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) =>
      lines.add('${level.name} $message $fields');

  @override
  void metric(
    String name,
    double value, {
    Map<String, String> tags = const <String, String>{},
  }) =>
      lines.add('$name $value $tags');

  @override
  SpanHandle span(
    String name, {
    Map<String, Object?> attributes = const <String, Object?>{},
    List<String> links = const <String>[],
  }) {
    final RecordingSpan span = RecordingSpan();
    attributes.forEach(span.setAttribute);
    lines.add('span $name linked to $links');
    return span;
  }
}

String levelLabel(LogLevel level) => switch (level) {
      LogLevel.debug => 'debug',
      LogLevel.info => 'info',
      LogLevel.warning => 'warning',
      LogLevel.error => 'error',
    };

String capabilityLabel(ObserverCapability capability) => switch (capability) {
      ObserverCapability.observeAll => 'all',
      ObserverCapability.observeSensitive => 'sensitive',
    };

/// The gate a bus applies before calling an observer (G23).
bool delivers(BusObserver observer, MessageEnvelope<Object?> envelope) =>
    ObserverCapability.permits(
      observer.capabilities,
      sensitive: envelope.sensitive,
    );
