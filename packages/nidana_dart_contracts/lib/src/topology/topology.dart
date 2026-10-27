import 'package:meta/meta.dart';

import '../ir/definition.dart';
import '../topic/lineage.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';

part 'builder.dart';
part 'handle.dart';
part 'plan.dart';
part 'sinks.dart';
part 'stages.dart';

/// A topology in class form (Spec §6.1, Guide §6.3). Applications extend it;
/// a subclass is final, base or sealed. Annotated @immutable: a topology is
/// inert data (Spec §2.2).
@immutable
abstract base class Topology {
  const Topology();

  /// Module-local (Spec §4.6); non-empty.
  String get topologyId;

  /// Declared explicitly (Spec §7.2).
  Scope get scope;

  /// Pure wiring (Spec §6.1): builder and handle calls only. Runs once per
  /// planOf call, never at construction.
  void declare(TopologyBuilder b);

  /// The IR (Spec §6.5): planOf(this).definition.
  @nonVirtual
  TopologyDefinition buildDefinition() => throw UnimplementedError();
}

/// The builder shorthand (Spec §6.1). Throws ArgumentError for an empty
/// [topologyId]; [declare] runs on each planOf call.
Topology topology(
  String topologyId,
  Scope scope,
  void Function(TopologyBuilder b) declare,
) => throw UnimplementedError();

/// A typed, module-local topology identifier (Spec §4.6). Equal by id.
@immutable
final class TopologyRef {
  const TopologyRef(this.id);

  final String id;
}

/// A value inside a live pipeline (Spec §3.5): its payload and the lineage
/// its next published envelope will carry (topic-model@v1 Lineage).
typedef PipelineValue<T> = ({T payload, Lineage lineage});

/// switchMap's retry: the delay before toStream(value) is called again after
/// the inner stream's [attempt]-th error for the current outer value
/// (1-based), or null to let the error through.
typedef RetryPolicy = Duration? Function(Object error, int attempt);

/// The raw operator: given the stage input's values, and a source of fresh
/// correlation ids for Lineage.combine, it returns the stage's values. The
/// author applies the lineage rules (Spec §3.5).
typedef RawOperator<T, R> = Stream<PipelineValue<R>> Function(
  Stream<PipelineValue<T>> values,
  String Function() freshCorrelationId,
);
