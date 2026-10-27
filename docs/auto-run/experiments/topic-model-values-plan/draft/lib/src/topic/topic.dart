import 'package:meta/meta.dart';

/// The three topic variants (Spec §2.1).
enum TopicVariant { state, event, replay }

/// Whether a state topic suppresses a publish equal to its current value
/// (Spec §3.12). Equality is Dart's `==` (Spec §3.12 table).
enum Dedup {
  equality, // the default: a publish `==` to the current value is a no-op
  none, // every publish notifies
}

/// Whether the bus attaches envelope metadata to a topic's publishes
/// (Guide §8.1; Spec §3.5 "Cost"). What the bus and its observers do with an
/// untraced topic is bus-api@v2's; here it only fixes how an untraced value
/// enters lineage (Lineage.root).
enum Tracing { enabled, disabled }

/// A typed reference to a named channel on a bus (Spec §2.1, §4.2). A pure
/// value, shared across bus instances; it holds no subject.
@immutable
sealed class Topic<T> {
  const Topic._({
    required this.name,
    required this.sensitive,
    required this.tracing,
  });

  final String name;
  final bool sensitive; // Spec §9.2
  final Tracing tracing; // Guide §8.1
  TopicVariant get variant;
  Type get valueType => T; // T
  // TopicRef(name, variant, typeName: '$T')
  TopicRef get ref => TopicRef(name: name, variant: variant, typeName: '$T');

  // same variant, name and valueType (G7)
  @override
  bool operator ==(Object other) =>
      other is Topic<Object?> &&
      other.variant == variant &&
      other.name == name &&
      other.valueType == valueType;

  @override
  int get hashCode => Object.hash(variant, name, valueType);
}

final class StateTopic<T> extends Topic<T> {
  /// A constant initial value (Spec §2.5 "Allowed: constant").
  const StateTopic({
    required super.name,
    required T initial,
    this.dedup = Dedup.equality,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : _constant = initial,
       _factory = null,
       super._();

  /// A pure factory (Spec §2.5 "Allowed: pure factory"), never called at
  /// construction. When the bus calls createInitial() is bus-api@v2's.
  const StateTopic.computed({
    required super.name,
    required T Function() initial,
    this.dedup = Dedup.equality,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : _constant = null,
       _factory = initial,
       super._();

  final Dedup dedup;

  // The declared constant, when _factory is null.
  final T? _constant;
  final T Function()? _factory;

  @override
  TopicVariant get variant => TopicVariant.state;

  /// The declared value, or the factory's result for this call (G9).
  T createInitial() {
    final T Function()? factory = _factory;
    return factory == null ? _constant as T : factory();
  }
}

/// The topics any number of writers may publish to (Spec §2.1, §3.11): the
/// event and replay variants, and no other (G1). The parameter type of a
/// publish path that takes no ownership claim, so a state topic does not
/// fit one (G27).
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
  /// Buffers the [bufferSize] most recent values (Spec §2.1), at least one.
  const ReplayTopic({
    required super.name,
    required this.bufferSize,
    super.sensitive = false,
    super.tracing = Tracing.enabled,
  }) : assert(bufferSize >= 1, 'bufferSize must be at least 1'),
       super._();

  final int bufferSize;

  @override
  TopicVariant get variant => TopicVariant.replay;
}

/// A serializable reference to a topic (Spec Appendix A.4): what the IR
/// records for reads and writes and what an observer receives.
@immutable
final class TopicRef {
  const TopicRef({
    required this.name,
    required this.variant,
    required this.typeName, // the value type's toString(), as '$T' renders it
  });

  final String name;
  final TopicVariant variant;
  final String typeName;

  // all three fields
  @override
  bool operator ==(Object other) =>
      other is TopicRef &&
      other.name == name &&
      other.variant == variant &&
      other.typeName == typeName;

  @override
  int get hashCode => Object.hash(name, variant, typeName);
}

/// Whether [name] follows `domain.entity` or `domain.entity.action`
/// (Spec §4.4): two or three segments separated by '.', each segment
/// lowercase kebab case, `[a-z][a-z0-9]*(-[a-z0-9]+)*`.
bool isWellFormedTopicName(String name) {
  final List<String> segments = name.split('.');
  return segments.length >= 2 &&
      segments.length <= 3 &&
      segments.every(_segment.hasMatch);
}

final RegExp _segment = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$');
