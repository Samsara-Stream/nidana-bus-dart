// topic-model@v1's lineage values, beyond the cases of its conformance
// suite, which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

MessageEnvelope<int> envelope({
  String id = 'e-1',
  String correlationId = 'c-1',
  List<String> parents = const <String>[],
  bool sensitive = false,
}) => MessageEnvelope<int>(
  id: id,
  payload: 1,
  correlationId: correlationId,
  parentCorrelationIds: parents,
  timestamp: DateTime.utc(2026, 10, 27, 12),
  source: const UnknownSource(),
  sensitive: sensitive,
);

void main() {
  test('G4 G18 a lineage caused by an envelope exposes unmodifiable '
      'parents', () {
    final Lineage lineage = Lineage.causedBy(
      envelope(parents: <String>['p-1']),
    );
    expect(lineage.parentCorrelationIds, <String>['p-1']);
    expect(
      () => lineage.parentCorrelationIds.add('p-2'),
      throwsUnsupportedError,
    );
  });

  test('lineages built apart are equal exactly when all four fields are, '
      'parents in order, and equal ones are one set element', () {
    final Lineage a = Lineage.causedBy(
      envelope(parents: <String>['p-1', 'p-2']),
    );
    final Lineage b = Lineage.causedBy(
      envelope(parents: <String>['p-1', 'p-2']),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(<Lineage>{a, b}, hasLength(1));
    for (final Lineage other in <Lineage>[
      Lineage.causedBy(envelope(id: 'e-2', parents: <String>['p-1', 'p-2'])),
      Lineage.causedBy(
        envelope(correlationId: 'c-2', parents: <String>['p-1', 'p-2']),
      ),
      Lineage.causedBy(envelope(parents: <String>['p-2', 'p-1'])),
      Lineage.causedBy(
        envelope(parents: <String>['p-1', 'p-2'], sensitive: true),
      ),
    ]) {
      expect(a == other, isFalse, reason: '${other.causationId}');
    }
    final String flow = <String>['c-1'].single;
    expect(
      Lineage.root(correlationId: flow),
      const Lineage.root(correlationId: 'c-1'),
    );
  });

  test('G20 withLatestFrom over several latest values is sensitive when '
      'any is, and keeps the primary causation, correlation and parents', () {
    final Lineage primary = Lineage.causedBy(
      envelope(id: 'e-9', correlationId: 'order-1', parents: <String>['p-1']),
    );
    final Lineage plain = Lineage.causedBy(envelope(correlationId: 'c-2'));
    final Lineage secret = Lineage.causedBy(
      envelope(correlationId: 'c-3', sensitive: true),
    );
    final Lineage out = Lineage.withLatestFrom(primary, <Lineage>[
      plain,
      plain,
      secret,
    ]);
    expect(out.causationId, 'e-9');
    expect(out.correlationId, 'order-1');
    expect(out.parentCorrelationIds, <String>['p-1']);
    expect(out.sensitive, isTrue);
    expect(Lineage.withLatestFrom(primary, <Lineage>[plain, plain]), primary);
  });
}
