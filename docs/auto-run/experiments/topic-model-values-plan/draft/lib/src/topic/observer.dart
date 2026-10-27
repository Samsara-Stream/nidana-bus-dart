import 'envelope.dart';
import 'topic.dart';

/// Observer visibility (Spec §3.7, §9.2).
enum ObserverCapability {
  observeAll, // sees envelopes of non-sensitive topics
  observeSensitive; // sees envelopes of sensitive topics; an explicit grant

  /// Whether an observer holding [capabilities] may receive an envelope
  /// whose sensitive flag is [sensitive] (G23).
  static bool permits(
    Set<ObserverCapability> capabilities, {
    required bool sensitive,
  }) => capabilities.contains(sensitive ? observeSensitive : observeAll);
}

enum LogLevel { debug, info, warning, error }

/// A span opened through ObserveContext.span. Implemented by the sink.
abstract interface class SpanHandle {
  void setAttribute(String key, Object? value);
  void end();
}

/// The only sinks an observer can reach (Spec §3.7): no publish, no bus.
abstract interface class ObserveContext {
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  });
  void metric(
    String name,
    double value, {
    Map<String, String> tags = const <String, String>{},
  });

  /// [links] are ids of published envelopes whose spans this span links to,
  /// the causation link of Guide §8.2; the sink maps an id to its span.
  SpanHandle span(
    String name, {
    Map<String, Object?> attributes = const <String, Object?>{},
    List<String> links = const <String>[],
  });
}

/// A bus-level observer (Spec §3.7, §9.1). Implemented by applications and
/// by the runtime's telemetry observer.
abstract interface class BusObserver {
  Set<ObserverCapability> get capabilities;
  void onPublish(
    TopicRef topic,
    MessageEnvelope<Object?> envelope,
    ObserveContext context,
  );
}
