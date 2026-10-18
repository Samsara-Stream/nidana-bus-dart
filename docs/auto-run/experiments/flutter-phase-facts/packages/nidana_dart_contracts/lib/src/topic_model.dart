/// Stand-in for the topic-model@v1 part of `nidana_dart_contracts`, copied
/// from docs/auto-run/experiments/topic-model-fixtures/.
///
/// Throwaway experiment code: it implements the Interface of
/// hsdd/contract/topic-model.md as directly as possible so that the contract's
/// surface, reject and behavior fixtures can be replayed before the real
/// package exists. It is not the real package and nothing should depend on it.
library;

import 'package:meta/meta.dart';

// ---------------------------------------------------------------- topics

/// The three topic variants (Spec §2.1).
enum TopicVariant { state, event, replay }

/// Whether a state topic suppresses a publish equal to its current value
/// (Spec §3.12).
enum Dedup { equality, none }

/// Whether the bus attaches envelope metadata to a topic's publishes
/// (Guide §8.1).
enum Tracing { enabled, disabled }

/// A typed reference to a named channel on a bus (Spec §2.1, §4.2).
@immutable
sealed class Topic<T> {
  const Topic._({
    required this.name,
    required this.sensitive,
    required this.tracing,
  });

  final String name;
  final bool sensitive;
  final Tracing tracing;

  TopicVariant get variant;

  Type get valueType => T;

  TopicRef get ref => TopicRef(name: name, variant: variant, typeName: '$T');

  @override
  bool operator ==(Object other) =>
      other is Topic<Object?> &&
      other.variant == variant &&
      other.name == name &&
      other.valueType == valueType;

  @override
  int get hashCode => Object.hash(variant, name, T);

  @override
  String toString() => '${runtimeType.toString().split('<').first}<$T>($name)';
}

final class StateTopic<T> extends Topic<T> {
  const StateTopic({
    required super.name,
    required T initial,
    this.dedup = Dedup.equality,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  })  : // A named parameter cannot be a private initializing formal.
        // ignore: prefer_initializing_formals
        _initial = initial,
        _compute = null,
        super._();

  const StateTopic.computed({
    required super.name,
    required T Function() initial,
    this.dedup = Dedup.equality,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  })  : _initial = null,
        _compute = initial,
        super._();

  final Dedup dedup;
  final T? _initial;
  final T Function()? _compute;

  @override
  TopicVariant get variant => TopicVariant.state;

  T createInitial() {
    final compute = _compute;
    return compute == null ? _initial as T : compute();
  }
}

/// The topics any number of writers may publish to (Spec §2.1): the event
/// and replay variants. Sealed. PROPOSED AMENDMENT of topic-model@v1, which
/// bus-api@v1 needs so that a publisher-less publish and a publisher's
/// publish cannot name a state topic (bus-api@v1 G11, G19).
sealed class MultiWriterTopic<T> extends Topic<T> {
  const MultiWriterTopic._({
    required super.name,
    required super.sensitive,
    required super.tracing,
  }) : super._();
}

final class EventTopic<T> extends MultiWriterTopic<T> {
  const EventTopic({
    required super.name,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : super._();

  @override
  TopicVariant get variant => TopicVariant.event;
}

final class ReplayTopic<T> extends MultiWriterTopic<T> {
  const ReplayTopic({
    required super.name,
    required this.bufferSize,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  })  : assert(bufferSize > 0, 'bufferSize must be at least 1'),
        super._();

  final int bufferSize;

  @override
  TopicVariant get variant => TopicVariant.replay;
}

/// A serializable reference to a topic (Spec Appendix A.4).
@immutable
final class TopicRef {
  const TopicRef({
    required this.name,
    required this.variant,
    required this.typeName,
  });

  final String name;
  final TopicVariant variant;
  final String typeName;

  @override
  bool operator ==(Object other) =>
      other is TopicRef &&
      other.name == name &&
      other.variant == variant &&
      other.typeName == typeName;

  @override
  int get hashCode => Object.hash(name, variant, typeName);

  @override
  String toString() => 'TopicRef(${variant.name} $name: $typeName)';
}

final RegExp _segment = RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$');

/// Whether [name] follows `domain.entity` or `domain.entity.action`
/// (Spec §4.4).
bool isWellFormedTopicName(String name) {
  final segments = name.split('.');
  return segments.length >= 2 &&
      segments.length <= 3 &&
      segments.every(_segment.hasMatch);
}

// ---------------------------------------------------------------- sources

/// Who produced a message (Spec §2.4 `source`).
@immutable
sealed class MessageSource {
  const MessageSource._();

  static MessageSource? tryParse(String text) {
    if (text == 'unknown') return const UnknownSource();
    final colon = text.indexOf(':');
    if (colon <= 0 || colon == text.length - 1) return null;
    final kind = text.substring(0, colon);
    final rest = text.substring(colon + 1);
    return switch (kind) {
      'topology' => TopologySource(rest),
      'service' => ServiceSource(rest),
      'page' => PageSource(rest),
      'executor' => ExecutorSource(rest),
      _ => null,
    };
  }
}

final class TopologySource extends MessageSource {
  const TopologySource(this.topologyId)
      : assert(topologyId != ''),
        super._();
  final String topologyId;
  @override
  bool operator ==(Object other) =>
      other is TopologySource && other.topologyId == topologyId;
  @override
  int get hashCode => Object.hash(TopologySource, topologyId);
  @override
  String toString() => 'topology:$topologyId';
}

final class ServiceSource extends MessageSource {
  const ServiceSource(this.name)
      : assert(name != ''),
        super._();
  final String name;
  @override
  bool operator ==(Object other) => other is ServiceSource && other.name == name;
  @override
  int get hashCode => Object.hash(ServiceSource, name);
  @override
  String toString() => 'service:$name';
}

final class PageSource extends MessageSource {
  const PageSource(this.route)
      : assert(route != ''),
        super._();
  final String route;
  @override
  bool operator ==(Object other) => other is PageSource && other.route == route;
  @override
  int get hashCode => Object.hash(PageSource, route);
  @override
  String toString() => 'page:$route';
}

final class ExecutorSource extends MessageSource {
  const ExecutorSource(this.name)
      : assert(name != ''),
        super._();
  final String name;
  @override
  bool operator ==(Object other) =>
      other is ExecutorSource && other.name == name;
  @override
  int get hashCode => Object.hash(ExecutorSource, name);
  @override
  String toString() => 'executor:$name';
}

final class UnknownSource extends MessageSource {
  const UnknownSource() : super._();
  @override
  bool operator ==(Object other) => other is UnknownSource;
  @override
  int get hashCode => (UnknownSource).hashCode;
  @override
  String toString() => 'unknown';
}

// ---------------------------------------------------------------- envelope

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The carrier of every value published to a topic (Spec §2.4).
@immutable
final class MessageEnvelope<T> {
  MessageEnvelope({
    required this.id,
    required this.payload,
    required this.correlationId,
    this.causationId,
    List<String> parentCorrelationIds = const <String>[],
    required this.timestamp,
    required this.source,
    required this.sensitive,
  }) : parentCorrelationIds = List<String>.unmodifiable(parentCorrelationIds);

  factory MessageEnvelope.publishedTo(
    Topic<T> topic, {
    required String id,
    required T payload,
    required Lineage lineage,
    required String Function() freshCorrelationId,
    required DateTime timestamp,
    required MessageSource source,
  }) =>
      MessageEnvelope<T>(
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

  @override
  bool operator ==(Object other) =>
      other is MessageEnvelope<Object?> &&
      other.id == id &&
      other.payload == payload &&
      other.correlationId == correlationId &&
      other.causationId == causationId &&
      _sameList(other.parentCorrelationIds, parentCorrelationIds) &&
      other.timestamp == timestamp &&
      other.source == source &&
      other.sensitive == sensitive;

  @override
  int get hashCode => Object.hash(id, payload, correlationId, causationId,
      Object.hashAll(parentCorrelationIds), timestamp, source, sensitive);

  @override
  String toString() {
    final shown = sensitive ? RedactedPayload.of(payload) : payload;
    return 'MessageEnvelope(id: $id, payload: $shown, '
        'correlationId: $correlationId, causationId: $causationId, '
        'parentCorrelationIds: $parentCorrelationIds, timestamp: $timestamp, '
        'source: $source, sensitive: $sensitive)';
  }
}

// ---------------------------------------------------------------- lineage

/// The lineage fields of a pipeline value (Spec §2.4, §3.5), computed per
/// published message.
@immutable
final class Lineage {
  const Lineage.root({this.correlationId, this.sensitive = false})
      : causationId = null,
        parentCorrelationIds = const <String>[];

  Lineage.causedBy(MessageEnvelope<Object?> cause)
      : causationId = cause.id,
        correlationId = cause.correlationId,
        parentCorrelationIds = cause.parentCorrelationIds,
        sensitive = cause.sensitive;

  Lineage._({
    required this.causationId,
    required this.correlationId,
    required List<String> parentCorrelationIds,
    required this.sensitive,
  }) : parentCorrelationIds = List<String>.unmodifiable(parentCorrelationIds);

  final String? causationId;
  final String? correlationId;
  final List<String> parentCorrelationIds;
  final bool sensitive;

  static Lineage combine(
    List<Lineage> inputs, {
    required int trigger,
    required String Function() freshCorrelationId,
  }) {
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
    }
    RangeError.checkValidIndex(trigger, inputs, 'trigger');
    final correlations = <String>[];
    for (final input in inputs) {
      final c = input.correlationId;
      if (c != null && !correlations.contains(c)) correlations.add(c);
    }
    final sensitive = inputs.any((i) => i.sensitive);
    final causation = inputs[trigger].causationId;
    if (correlations.isEmpty) {
      return Lineage._(
          causationId: causation,
          correlationId: null,
          parentCorrelationIds: const <String>[],
          sensitive: sensitive);
    }
    if (correlations.length == 1) {
      final parents = <String>[];
      for (final input in inputs) {
        for (final p in input.parentCorrelationIds) {
          if (!parents.contains(p)) parents.add(p);
        }
      }
      return Lineage._(
          causationId: causation,
          correlationId: correlations.single,
          parentCorrelationIds: parents,
          sensitive: sensitive);
    }
    return Lineage._(
        causationId: causation,
        correlationId: freshCorrelationId(),
        parentCorrelationIds: correlations,
        sensitive: sensitive);
  }

  static Lineage withLatestFrom(Lineage primary, List<Lineage> latest) =>
      Lineage._(
          causationId: primary.causationId,
          correlationId: primary.correlationId,
          parentCorrelationIds: primary.parentCorrelationIds,
          sensitive: primary.sensitive || latest.any((l) => l.sensitive));

  @override
  bool operator ==(Object other) =>
      other is Lineage &&
      other.causationId == causationId &&
      other.correlationId == correlationId &&
      _sameList(other.parentCorrelationIds, parentCorrelationIds) &&
      other.sensitive == sensitive;

  @override
  int get hashCode => Object.hash(causationId, correlationId,
      Object.hashAll(parentCorrelationIds), sensitive);

  @override
  String toString() => 'Lineage(causationId: $causationId, '
      'correlationId: $correlationId, parents: $parentCorrelationIds, '
      'sensitive: $sensitive)';
}

// ---------------------------------------------------------------- scope

/// A topology's lifetime (Spec §7.1).
enum Scope {
  application,
  module,
  page;

  bool isAtLeastAsLongAs(Scope other) => index <= other.index;
}

// ---------------------------------------------------------------- observers

enum ObserverCapability {
  observeAll,
  observeSensitive;

  static bool permits(
    Set<ObserverCapability> capabilities, {
    required bool sensitive,
  }) =>
      capabilities.contains(sensitive ? observeSensitive : observeAll);
}

enum LogLevel { debug, info, warning, error }

abstract interface class SpanHandle {
  void setAttribute(String key, Object? value);
  void end();
}

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

  SpanHandle span(
    String name, {
    Map<String, Object?> attributes = const <String, Object?>{},
    List<String> links = const <String>[],
  });
}

abstract interface class BusObserver {
  Set<ObserverCapability> get capabilities;

  void onPublish(
    TopicRef topic,
    MessageEnvelope<Object?> envelope,
    ObserveContext context,
  );
}

// ---------------------------------------------------------------- redaction

/// A sensitive payload as diagnostics show it: its type and a truncated hash
/// (Spec §9.2 item 2).
@immutable
final class RedactedPayload {
  const RedactedPayload._(this.typeName, this.hash);

  factory RedactedPayload.of(Object? payload) => RedactedPayload._(
        payload.runtimeType.toString(),
        (payload.hashCode & 0xffffffff).toRadixString(16).padLeft(8, '0'),
      );

  final String typeName;
  final String hash;

  @override
  bool operator ==(Object other) =>
      other is RedactedPayload &&
      other.typeName == typeName &&
      other.hash == hash;

  @override
  int get hashCode => Object.hash(typeName, hash);

  @override
  String toString() => '<redacted $typeName #$hash>';
}
