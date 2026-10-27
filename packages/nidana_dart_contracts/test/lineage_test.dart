// topic-model@v1's lineage values, beyond the cases of its conformance
// suite, which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/src/topic/list_equality.dart';
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

  test('an envelope keeps its own unmodifiable copy of the parents it was '
      'given, and its default is empty', () {
    final List<String> given = <String>['p-1'];
    final MessageEnvelope<int> built = envelope(parents: given);
    given
      ..add('p-2')
      ..[0] = 'changed';
    expect(built.parentCorrelationIds, <String>['p-1']);
    expect(() => built.parentCorrelationIds.add('p-3'), throwsUnsupportedError);
    expect(() => built.parentCorrelationIds.clear(), throwsUnsupportedError);
    expect(envelope().parentCorrelationIds, isEmpty);
  });

  test('a lineage caused by an envelope is unaffected by later changes to '
      'the list the envelope was built from', () {
    final List<String> given = <String>['p-1', 'p-2'];
    final Lineage lineage = Lineage.causedBy(envelope(parents: given));
    given.removeLast();
    expect(lineage.parentCorrelationIds, <String>['p-1', 'p-2']);
  });

  test('a lineage caused by an envelope takes the envelope id as causation, '
      'and the correlation and sensitivity of the envelope', () {
    final Lineage lineage = Lineage.causedBy(
      envelope(id: 'e-5', correlationId: 'flow-7', sensitive: true),
    );
    expect(lineage.causationId, 'e-5');
    expect(lineage.correlationId, 'flow-7');
    expect(lineage.sensitive, isTrue);
    expect(lineage.parentCorrelationIds, isEmpty);
  });

  test('a root lineage differs from a caused one in causation, and from '
      'another root in correlation or sensitivity', () {
    const Lineage root = Lineage.root();
    expect(root, const Lineage.root());
    expect(root.hashCode, const Lineage.root().hashCode);
    expect(root == const Lineage.root(correlationId: 'c-1'), isFalse);
    expect(root == const Lineage.root(sensitive: true), isFalse);
    expect(root == Lineage.causedBy(envelope()), isFalse);
    expect(
      const Lineage.root(correlationId: 'c-1') ==
          Lineage.causedBy(envelope(correlationId: 'c-1')),
      isFalse,
    );
  });

  test('equal lineages built apart are one map key', () {
    final Map<Lineage, String> byLineage = <Lineage, String>{
      Lineage.causedBy(envelope(parents: <String>['p-1'])): 'first',
    };
    byLineage[Lineage.causedBy(envelope(parents: <String>['p-1']))] = 'second';
    expect(byLineage, hasLength(1));
    expect(byLineage.values.single, 'second');
  });

  test('withLatestFrom over no latest values is its primary, and over '
      'latest values never takes their causation, correlation or parents', () {
    final Lineage primary = Lineage.causedBy(
      envelope(id: 'e-9', correlationId: 'order-1', parents: <String>['p-1']),
    );
    final Lineage other = Lineage.causedBy(
      envelope(id: 'e-3', correlationId: 'c-9', parents: <String>['p-9']),
    );
    expect(Lineage.withLatestFrom(primary, <Lineage>[]), primary);
    expect(Lineage.withLatestFrom(primary, <Lineage>[other]), primary);
  });

  test('withLatestFrom keeps a sensitive primary sensitive whatever the '
      'latest values are', () {
    final Lineage secret = Lineage.causedBy(envelope(sensitive: true));
    final Lineage plain = Lineage.causedBy(envelope(id: 'e-2'));
    expect(Lineage.withLatestFrom(secret, <Lineage>[]).sensitive, isTrue);
    expect(Lineage.withLatestFrom(secret, <Lineage>[plain]).sensitive, isTrue);
    expect(Lineage.withLatestFrom(plain, <Lineage>[secret]).sensitive, isTrue);
    expect(Lineage.withLatestFrom(plain, <Lineage>[plain]).sensitive, isFalse);
  });

  test('withLatestFrom over a root primary keeps a null correlation', () {
    final Lineage out = Lineage.withLatestFrom(const Lineage.root(), <Lineage>[
      Lineage.causedBy(envelope()),
    ]);
    expect(out.causationId, isNull);
    expect(out.correlationId, isNull);
    expect(out.parentCorrelationIds, isEmpty);
  });

  test('the lineage withLatestFrom returns has unmodifiable parents', () {
    final Lineage out = Lineage.withLatestFrom(
      Lineage.causedBy(envelope(parents: <String>['p-1'])),
      <Lineage>[],
    );
    expect(() => out.parentCorrelationIds.add('p-2'), throwsUnsupportedError);
  });

  group('elementsEqual', () {
    test('is true for two lists with the same elements in the same order '
        'that are different objects', () {
      expect(elementsEqual(<String>['a', 'b'], <String>['a', 'b']), isTrue);
      expect(elementsEqual(<String>[], <String>[]), isTrue);
    });

    test('is false when the lengths, the order or an element differ', () {
      expect(elementsEqual(<String>['a'], <String>['a', 'b']), isFalse);
      expect(elementsEqual(<String>['a', 'b'], <String>['a']), isFalse);
      expect(elementsEqual(<String>['a', 'b'], <String>['b', 'a']), isFalse);
      expect(elementsEqual(<String>['a', 'b'], <String>['a', 'c']), isFalse);
    });

    test('compares elements with == and takes null elements', () {
      expect(elementsEqual(<Object?>[1, null], <Object?>[1, null]), isTrue);
      expect(elementsEqual(<Object?>[1, null], <Object?>[1, 2]), isFalse);
      expect(elementsEqual(<Object?>[null], <Object?>[]), isFalse);
    });
  });
}
