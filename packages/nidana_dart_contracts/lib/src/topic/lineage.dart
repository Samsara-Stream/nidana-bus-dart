import 'package:meta/meta.dart';

import 'envelope.dart';
import 'list_equality.dart';

/// The lineage fields of a pipeline value (Spec §2.4, §3.5): what the next
/// published envelope's causationId, correlationId and parentCorrelationIds
/// will be, and whether the value derives from a sensitive input.
@immutable
final class Lineage {
  /// No traced message caused this value: a shell publish starting a flow,
  /// or a value read from a Tracing.disabled topic. A null correlation means
  /// the publish starts a new flow (MessageEnvelope.publishedTo).
  const Lineage.root({this.correlationId, this.sensitive = false})
    : causationId = null,
      parentCorrelationIds = const <String>[];

  /// Caused by [cause], a published envelope: causationId is cause.id;
  /// correlationId, parentCorrelationIds and sensitive are cause's.
  Lineage.causedBy(MessageEnvelope<Object?> cause)
    : causationId = cause.id,
      correlationId = cause.correlationId,
      parentCorrelationIds = cause.parentCorrelationIds,
      sensitive = cause.sensitive;

  // combine and withLatestFrom; parentCorrelationIds is unmodifiable.
  const Lineage._({
    required this.causationId,
    required this.correlationId,
    required this.parentCorrelationIds,
    required this.sensitive,
  });

  final String? causationId;
  final String? correlationId;
  final List<String> parentCorrelationIds; // unmodifiable
  final bool sensitive;

  /// combine and combineLatest (Spec §2.4 table). [trigger] indexes the
  /// input whose new emission fired the operator. causationId is the
  /// trigger's; sensitive is the or of all inputs. Over the inputs that carry
  /// a correlationId: none, the result carries none and no parents; one
  /// distinct value, it is kept and parents are the union of those inputs'
  /// parents in input order; several, the result takes freshCorrelationId(),
  /// called exactly once, and parents are the distinct input correlation ids
  /// in input order. Throws ArgumentError when [inputs] is empty or
  /// [trigger] is out of range.
  static Lineage combine(
    List<Lineage> inputs, {
    required int trigger,
    required String Function() freshCorrelationId,
  }) {
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
    }
    RangeError.checkValidIndex(trigger, inputs, 'trigger');
    final Set<String> distinct = <String>{
      for (final Lineage input in inputs) ?input.correlationId,
    };
    final String? causationId = inputs[trigger].causationId;
    final bool sensitive = inputs.any((Lineage input) => input.sensitive);
    return switch (distinct.length) {
      0 => Lineage._(
        causationId: causationId,
        correlationId: null,
        parentCorrelationIds: const <String>[],
        sensitive: sensitive,
      ),
      1 => Lineage._(
        causationId: causationId,
        correlationId: distinct.single,
        parentCorrelationIds: List<String>.unmodifiable(<String>{
          for (final Lineage input in inputs)
            if (input.correlationId != null) ...input.parentCorrelationIds,
        }),
        sensitive: sensitive,
      ),
      _ => Lineage._(
        causationId: causationId,
        correlationId: freshCorrelationId(),
        parentCorrelationIds: List<String>.unmodifiable(distinct),
        sensitive: sensitive,
      ),
    };
  }

  /// withLatestFrom (Spec §2.4 table): causation, correlation and parents
  /// from [primary]; sensitive is the or of [primary] and [latest].
  static Lineage withLatestFrom(Lineage primary, List<Lineage> latest) =>
      Lineage._(
        causationId: primary.causationId,
        correlationId: primary.correlationId,
        parentCorrelationIds: primary.parentCorrelationIds,
        sensitive: primary.sensitive || latest.any((Lineage l) => l.sensitive),
      );

  // all four fields; parents element-wise
  @override
  bool operator ==(Object other) =>
      other is Lineage &&
      other.causationId == causationId &&
      other.correlationId == correlationId &&
      elementsEqual(other.parentCorrelationIds, parentCorrelationIds) &&
      other.sensitive == sensitive;

  @override
  int get hashCode => Object.hash(
    causationId,
    correlationId,
    Object.hashAll(parentCorrelationIds),
    sensitive,
  );
}
