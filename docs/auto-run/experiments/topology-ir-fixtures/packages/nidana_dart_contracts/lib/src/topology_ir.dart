/// Stand-in for the topology-ir@v1 value types of `nidana_dart_contracts`'
/// main library: `TopologyDefinition`, `TransformEdge`, `EdgeInput`,
/// `TopicInput`, `StageInput`, `CombinatorKind`, `FunctionRef`.
///
/// Throwaway experiment code: it implements the Interface of
/// hsdd/contract/topology-ir.md as directly as possible so that the
/// contract's fixtures can be replayed before the real package exists.
library;

import 'package:meta/meta.dart';

import 'topic_model.dart';

/// One value per stage class of topology-dsl@v1 other than ReadStage, and
/// one for the reduceInto sink, in topology-dsl@v1's combinator-table order.
enum CombinatorKind {
  map,
  filter,
  combine,
  withLatestFrom,
  merge,
  switchMap,
  scan,
  pairwise,
  distinctUntilChanged,
  debounce,
  throttle,
  delay,
  sample,
  buffer,
  timeout,
  catchError,
  rawEngine,
  reduceInto,
}

final RegExp _vmName = RegExp(r"from Function '([^']*)'");

/// A serializable reference to a transformer (Spec §6.5): its name, or
/// anonymous. Holds no function.
@immutable
final class FunctionRef {
  FunctionRef.named(String this.name) {
    if (name!.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
  }

  const FunctionRef.anonymous() : name = null;

  /// The name the Dart VM renders in [function]'s toString(); anonymous when
  /// it renders none (OQ-M1).
  factory FunctionRef.of(Function function) {
    final String? found = _vmName.firstMatch(function.toString())?.group(1);
    return found == null || found.isEmpty
        ? const FunctionRef.anonymous()
        : FunctionRef.named(found);
  }

  final String? name;

  @override
  bool operator ==(Object other) => other is FunctionRef && other.name == name;

  @override
  int get hashCode => Object.hash(FunctionRef, name);

  @override
  String toString() => name == null ? 'FunctionRef.anonymous()' : 'FunctionRef($name)';
}

/// What a transform edge consumes (Spec §6.5 `inputs`).
@immutable
sealed class EdgeInput {
  const EdgeInput._();
}

/// The values a read of [topic] delivers: one ReadStage of the plan.
final class TopicInput extends EdgeInput {
  const TopicInput(this.topic, {this.dedup}) : super._();
  final TopicRef topic;
  final Dedup? dedup;

  @override
  bool operator ==(Object other) =>
      other is TopicInput && other.topic == topic && other.dedup == dedup;

  @override
  int get hashCode => Object.hash(TopicInput, topic, dedup);

  @override
  String toString() =>
      'TopicInput(${topic.name}${dedup == null ? '' : ', ${dedup!.name}'})';
}

/// The values the stage edge at index [edge] of the same definition emits.
final class StageInput extends EdgeInput {
  const StageInput(this.edge)
      : assert(edge >= 0),
        super._();
  final int edge;

  @override
  bool operator ==(Object other) => other is StageInput && other.edge == edge;

  @override
  int get hashCode => Object.hash(StageInput, edge);

  @override
  String toString() => 'StageInput($edge)';
}

const Set<CombinatorKind> _timeKinds = <CombinatorKind>{
  CombinatorKind.debounce,
  CombinatorKind.throttle,
  CombinatorKind.delay,
  CombinatorKind.sample,
  CombinatorKind.buffer,
  CombinatorKind.timeout,
};

const Set<CombinatorKind> _functionKinds = <CombinatorKind>{
  CombinatorKind.map,
  CombinatorKind.filter,
  CombinatorKind.combine,
  CombinatorKind.withLatestFrom,
  CombinatorKind.switchMap,
  CombinatorKind.scan,
  CombinatorKind.catchError,
  CombinatorKind.rawEngine,
};

({int min, int max}) _arity(CombinatorKind kind) => switch (kind) {
      CombinatorKind.combine || CombinatorKind.merge => (min: 1, max: 1 << 30),
      CombinatorKind.withLatestFrom => (min: 2, max: 4),
      _ => (min: 1, max: 1),
    };

/// One element of a topology's wiring other than a read (Spec §6.5).
@immutable
final class TransformEdge {
  TransformEdge._(
    this.combinator,
    List<EdgeInput> inputs,
    this.output,
    this.transformer,
    this.duration,
    this.retry,
  ) : inputs = List<EdgeInput>.unmodifiable(inputs);

  /// A non-read stage of a plan.
  factory TransformEdge.stage(
    CombinatorKind combinator,
    List<EdgeInput> inputs, {
    FunctionRef? transformer,
    Duration? duration,
    FunctionRef? retry,
  }) {
    if (combinator == CombinatorKind.reduceInto) {
      throw ArgumentError.value(combinator, 'combinator',
          'reduceInto is a sink; use TransformEdge.reduceInto');
    }
    final arity = _arity(combinator);
    if (inputs.length < arity.min || inputs.length > arity.max) {
      throw ArgumentError.value(inputs, 'inputs',
          '${combinator.name} takes ${arity.min == arity.max ? arity.min : '${arity.min} or more'} input(s)'
              '${combinator == CombinatorKind.withLatestFrom ? ', at most 4' : ''}');
    }
    if (_functionKinds.contains(combinator) != (transformer != null)) {
      throw ArgumentError.value(transformer, 'transformer',
          '${combinator.name} ${_functionKinds.contains(combinator) ? 'requires' : 'takes no'} transformer');
    }
    if (_timeKinds.contains(combinator) != (duration != null)) {
      throw ArgumentError.value(duration, 'duration',
          '${combinator.name} ${_timeKinds.contains(combinator) ? 'requires' : 'takes no'} duration');
    }
    if (duration != null && duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    if (retry != null && combinator != CombinatorKind.switchMap) {
      throw ArgumentError.value(retry, 'retry', 'only switchMap takes a retry');
    }
    return TransformEdge._(
        combinator, inputs, null, transformer, duration, retry);
  }

  /// A write sink: [input]'s values published to [topic] unchanged.
  factory TransformEdge.write(TopicRef topic, EdgeInput input) =>
      TransformEdge._(null, <EdgeInput>[input], topic, null, null, null);

  /// A reduceInto sink folding [events] into the state topic [topic].
  factory TransformEdge.reduceInto(
    TopicRef topic,
    EdgeInput events,
    FunctionRef reducer,
  ) {
    if (topic.variant != TopicVariant.state) {
      throw ArgumentError.value(topic, 'topic', 'must be a state topic');
    }
    return TransformEdge._(CombinatorKind.reduceInto, <EdgeInput>[events],
        topic, reducer, null, null);
  }

  final CombinatorKind? combinator;
  final List<EdgeInput> inputs;
  final TopicRef? output;
  final FunctionRef? transformer;
  final Duration? duration;
  final FunctionRef? retry;

  bool get isSink => output != null;

  /// Spec §3.8, topology-dsl@v1's Self-reference column.
  bool get isStateBearing => switch (combinator) {
        CombinatorKind.scan || CombinatorKind.reduceInto => true,
        CombinatorKind.debounce ||
        CombinatorKind.delay ||
        CombinatorKind.sample ||
        CombinatorKind.buffer =>
          duration! > Duration.zero,
        _ => false,
      };

  @override
  bool operator ==(Object other) {
    if (other is! TransformEdge) return false;
    if (other.combinator != combinator ||
        other.output != output ||
        other.transformer != transformer ||
        other.duration != duration ||
        other.retry != retry ||
        other.inputs.length != inputs.length) {
      return false;
    }
    for (var i = 0; i < inputs.length; i++) {
      if (other.inputs[i] != inputs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(combinator, Object.hashAll(inputs), output,
      transformer, duration, retry);

  @override
  String toString() => 'TransformEdge(${combinator?.name ?? 'write'}, $inputs'
      '${output == null ? '' : ' -> ${output!.name}'})';
}

/// Canonical order of topic references: name, then variant, then type name.
int compareTopicRefs(TopicRef a, TopicRef b) {
  final byName = a.name.compareTo(b.name);
  if (byName != 0) return byName;
  final byVariant = a.variant.index.compareTo(b.variant.index);
  if (byVariant != 0) return byVariant;
  return a.typeName.compareTo(b.typeName);
}

Set<TopicRef> _sorted(Iterable<TopicRef> refs) => Set<TopicRef>.unmodifiable(
    <TopicRef>{...refs}.toList()..sort(compareTopicRefs));

/// The IR of one topology (Spec §6.5, Appendix A.4).
@immutable
final class TopologyDefinition {
  factory TopologyDefinition({
    required String topologyId,
    required Scope scope,
    required List<TransformEdge> transforms,
  }) {
    if (topologyId.isEmpty) {
      throw ArgumentError.value(topologyId, 'topologyId', 'must not be empty');
    }
    var sinkSeen = false;
    final consumed = <int>{};
    final stateSinks = <TopicRef>{};
    for (var i = 0; i < transforms.length; i++) {
      final e = transforms[i];
      if (e.isSink) {
        sinkSeen = true;
        final out = e.output!;
        if (out.variant == TopicVariant.state && !stateSinks.add(out)) {
          throw ArgumentError.value(transforms, 'transforms',
              'edge $i is a second sink on the state topic ${out.name}');
        }
      } else if (sinkSeen) {
        throw ArgumentError.value(
            transforms, 'transforms', 'stage edge $i follows a sink edge');
      }
      for (final input in e.inputs) {
        if (input is StageInput) {
          if (input.edge < 0 || input.edge >= i) {
            throw ArgumentError.value(transforms, 'transforms',
                'edge $i consumes edge ${input.edge}, which does not precede it');
          }
          if (transforms[input.edge].isSink) {
            throw ArgumentError.value(transforms, 'transforms',
                'edge $i consumes edge ${input.edge}, which is a sink');
          }
          consumed.add(input.edge);
        }
      }
    }
    for (var i = 0; i < transforms.length; i++) {
      if (!transforms[i].isSink && !consumed.contains(i)) {
        throw ArgumentError.value(
            transforms, 'transforms', 'stage edge $i is consumed by no edge');
      }
    }
    return TopologyDefinition._(
      topologyId,
      scope,
      _sorted(<TopicRef>[
        for (final e in transforms)
          for (final input in e.inputs)
            if (input is TopicInput) input.topic,
      ]),
      _sorted(<TopicRef>[
        for (final e in transforms)
          if (e.output case final TopicRef out) out,
      ]),
      List<TransformEdge>.unmodifiable(transforms),
    );
  }

  const TopologyDefinition._(
      this.topologyId, this.scope, this.reads, this.writes, this.transforms);

  final String topologyId;
  final Scope scope;
  final Set<TopicRef> reads;
  final Set<TopicRef> writes;
  final List<TransformEdge> transforms;

  @override
  bool operator ==(Object other) {
    if (other is! TopologyDefinition) return false;
    if (other.topologyId != topologyId ||
        other.scope != scope ||
        other.transforms.length != transforms.length) {
      return false;
    }
    for (var i = 0; i < transforms.length; i++) {
      if (other.transforms[i] != transforms[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(topologyId, scope, Object.hashAll(transforms));

  @override
  String toString() => 'TopologyDefinition($topologyId, ${scope.name}, '
      '${transforms.length} edges)';
}
