// topic-model@v1's envelopes, beyond the cases of its conformance suite,
// which the gate replays (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

final DateTime at = DateTime.utc(2026, 10, 27, 12);

/// A payload whose own rendering a test can look for.
final class Card {
  const Card(this.number);
  final String number;
  @override
  String toString() => 'Card($number)';
}

MessageEnvelope<T> envelope<T>(T payload, {bool sensitive = false}) =>
    MessageEnvelope<T>(
      id: 'e-1',
      payload: payload,
      correlationId: 'c-1',
      causationId: 'e-0',
      parentCorrelationIds: <String>['p-1', 'p-2'],
      timestamp: at,
      source: const PageSource('search'),
      sensitive: sensitive,
    );

void main() {
  test('an envelope renders its eight fields, a payload that is not '
      'sensitive as its own rendering', () {
    expect(
      envelope<String>('shoes').toString(),
      'MessageEnvelope(id: e-1, payload: shoes, correlationId: c-1, '
      'causationId: e-0, parentCorrelationIds: [p-1, p-2], '
      'timestamp: 2026-10-27 12:00:00.000Z, source: page:search, '
      'sensitive: false)',
    );
  });

  test('G15 a sensitive envelope, and its redacted() envelope, never render '
      'the payload, whatever the payload', () {
    for (final Object? payload in <Object?>[
      const Card('4242-4242'),
      'card 4242-4242',
      <String>['4242-4242'],
      <String, Object?>{'card': '4242-4242'},
    ]) {
      final MessageEnvelope<Object?> secret = envelope<Object?>(
        payload,
        sensitive: true,
      );
      expect(secret.toString(), isNot(contains('4242-4242')));
      expect(
        secret.toString(),
        contains('payload: ${RedactedPayload.of(payload)},'),
      );
      expect(secret.redacted().toString(), isNot(contains('4242-4242')));
    }
  });

  test('G13 envelopes of different type arguments are equal when their '
      'eight fields are, and one set element', () {
    final MessageEnvelope<String> typed = envelope<String>('shoes');
    final MessageEnvelope<Object?> widened = envelope<Object?>('shoes');
    expect(widened, typed);
    expect(widened.hashCode, typed.hashCode);
    expect(<MessageEnvelope<Object?>>{typed, widened}, hasLength(1));
  });

  test('G4 G14 a published envelope keeps an unmodifiable copy of its '
      'lineage parents', () {
    final MessageEnvelope<int> out = MessageEnvelope<int>.publishedTo(
      const EventTopic<int>(name: 'a.out'),
      id: 'e-2',
      payload: 2,
      lineage: Lineage.causedBy(envelope<String>('shoes')),
      freshCorrelationId: () => 'fresh',
      timestamp: at,
      source: const TopologySource('flow'),
    );
    expect(out.parentCorrelationIds, <String>['p-1', 'p-2']);
    expect(() => out.parentCorrelationIds.add('p-3'), throwsUnsupportedError);
  });
}
