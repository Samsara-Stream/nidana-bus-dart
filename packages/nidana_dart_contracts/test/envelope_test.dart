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

  test('G14 a lineage with a correlation id keeps it and never calls '
      'freshCorrelationId, a lineage without one calls it exactly once', () {
    int calls = 0;
    String fresh() {
      calls++;
      return 'fresh-$calls';
    }

    MessageEnvelope<int> publish(Lineage lineage) =>
        MessageEnvelope<int>.publishedTo(
          const EventTopic<int>(name: 'a.out'),
          id: 'e-2',
          payload: 2,
          lineage: lineage,
          freshCorrelationId: fresh,
          timestamp: at,
          source: const TopologySource('flow'),
        );

    final MessageEnvelope<int> kept = publish(
      Lineage.causedBy(envelope<String>('shoes')),
    );
    expect(kept.correlationId, 'c-1');
    expect(kept.causationId, 'e-1');
    expect(calls, 0);

    final MessageEnvelope<int> started = publish(const Lineage.root());
    expect(started.correlationId, 'fresh-1');
    expect(started.causationId, isNull);
    expect(started.parentCorrelationIds, isEmpty);
    expect(calls, 1);
  });

  test('G14 a published envelope takes sensitive from the topic, whatever '
      'the lineage says', () {
    MessageEnvelope<int> publish(Topic<int> topic, Lineage lineage) =>
        MessageEnvelope<int>.publishedTo(
          topic,
          id: 'e-2',
          payload: 2,
          lineage: lineage,
          freshCorrelationId: () => 'fresh',
          timestamp: at,
          source: const TopologySource('flow'),
        );

    const Topic<int> open = EventTopic<int>(name: 'a.out');
    const Topic<int> secret = EventTopic<int>(name: 'a.out', sensitive: true);
    const Lineage tainted = Lineage.root(sensitive: true);
    expect(publish(open, tainted).sensitive, isFalse);
    expect(publish(secret, const Lineage.root()).sensitive, isTrue);
    expect(publish(secret, tainted).sensitive, isTrue);
  });

  test('G14 a published envelope carries the id, payload, timestamp and '
      'source it is given', () {
    final MessageEnvelope<int> out = MessageEnvelope<int>.publishedTo(
      const EventTopic<int>(name: 'a.out'),
      id: 'e-2',
      payload: 2,
      lineage: const Lineage.root(correlationId: 'c-9'),
      freshCorrelationId: () => 'fresh',
      timestamp: at,
      source: const TopologySource('flow'),
    );
    expect(
      out,
      MessageEnvelope<int>(
        id: 'e-2',
        payload: 2,
        correlationId: 'c-9',
        timestamp: at,
        source: const TopologySource('flow'),
        sensitive: false,
      ),
    );
  });

  test('G13 envelopes built apart are equal and hash alike, parents '
      'compared element-wise', () {
    final MessageEnvelope<String> a = envelope<String>('shoes');
    final MessageEnvelope<String> b = envelope<String>('shoes');
    expect(a.parentCorrelationIds, isNot(same(b.parentCorrelationIds)));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(<MessageEnvelope<String>, int>{a: 1}[b], 1);
  });

  test('G13 envelopes differing in any one of the eight fields are not '
      'equal', () {
    MessageEnvelope<String> variant({
      String id = 'e-1',
      String payload = 'shoes',
      String correlationId = 'c-1',
      String? causationId = 'e-0',
      List<String> parents = const <String>['p-1', 'p-2'],
      DateTime? timestamp,
      MessageSource source = const PageSource('search'),
      bool sensitive = false,
    }) => MessageEnvelope<String>(
      id: id,
      payload: payload,
      correlationId: correlationId,
      causationId: causationId,
      parentCorrelationIds: parents,
      timestamp: timestamp ?? at,
      source: source,
      sensitive: sensitive,
    );

    final MessageEnvelope<String> base = variant();
    expect(base, variant());
    final List<MessageEnvelope<String>> others = <MessageEnvelope<String>>[
      variant(id: 'e-2'),
      variant(payload: 'boots'),
      variant(correlationId: 'c-2'),
      variant(causationId: null),
      variant(parents: <String>['p-1']),
      variant(parents: <String>['p-2', 'p-1']),
      variant(timestamp: at.add(const Duration(seconds: 1))),
      variant(source: const PageSource('cart')),
      variant(sensitive: true),
    ];
    for (final MessageEnvelope<String> other in others) {
      expect(other, isNot(base));
    }
  });

  test('G15 redacted() on a sensitive envelope replaces the payload and '
      'keeps the other seven fields, with unmodifiable parents', () {
    final MessageEnvelope<Card> secret = envelope<Card>(
      const Card('4242-4242'),
      sensitive: true,
    );
    final MessageEnvelope<Object?> redacted = secret.redacted();
    expect(redacted.payload, RedactedPayload.of(const Card('4242-4242')));
    expect(redacted.id, secret.id);
    expect(redacted.correlationId, secret.correlationId);
    expect(redacted.causationId, secret.causationId);
    expect(redacted.parentCorrelationIds, secret.parentCorrelationIds);
    expect(redacted.timestamp, secret.timestamp);
    expect(redacted.source, secret.source);
    expect(redacted.sensitive, isTrue);
    expect(
      () => redacted.parentCorrelationIds.add('p-3'),
      throwsUnsupportedError,
    );
  });

  test('G15 redacted() on an envelope that is not sensitive returns that '
      'envelope itself', () {
    final MessageEnvelope<String> open = envelope<String>('shoes');
    expect(identical(open.redacted(), open), isTrue);
  });
}
