// Conformance library for topic-model@v1 (ADR-001 item 4). Its cases are
// values; a binding registers them with a test runner. It imports neither
// package:test nor package:flutter_test.
//
// The implementation under test is the library's own declarations, which the
// cases call directly: a value type has no second implementation to stand in
// for it, so the harness carries no factory, only the settle step ADR-001
// requires (a no-op for pure values).
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

/// What a binding supplies.
abstract interface class TopicModelHarness {
  /// Brings the implementation to quiescence; pure values are always there.
  Future<void> settle();
}

final DateTime _at = DateTime.utc(2026, 10, 17, 12);

MessageEnvelope<String> _envelope({
  String id = 'e-1',
  String payload = 'p',
  String correlationId = 'c-1',
  String? causationId,
  List<String> parents = const <String>[],
  MessageSource source = const ServiceSource('test'),
  bool sensitive = false,
}) =>
    MessageEnvelope<String>(
      id: id,
      payload: payload,
      correlationId: correlationId,
      causationId: causationId,
      parentCorrelationIds: parents,
      timestamp: _at,
      source: source,
      sensitive: sensitive,
    );

/// A minting function that counts how often it is called.
final class _Minter {
  _Minter(this.prefix);
  final String prefix;
  int calls = 0;
  String call() => '$prefix-${++calls}';
}

/// A payload whose hash code and rendering the cases control.
final class _Secret {
  const _Secret(this.code);
  final int code;
  @override
  bool operator ==(Object other) => other is _Secret && other.code == code;
  @override
  int get hashCode => code;
  @override
  String toString() => 'SECRET-PAYLOAD-$code';
}

/// A payload of a second type, whose hash code a [_Secret] of the same code
/// shares.
final class _Twin {
  const _Twin(this.code);
  final int code;
  @override
  bool operator ==(Object other) => other is _Twin && other.code == code;
  @override
  int get hashCode => code;
}

final List<ConformanceCase<TopicModelHarness>> topicModelConformance =
    <ConformanceCase<TopicModelHarness>>[
  // ------------------------------------------------------------ G4
  (
    name: 'G4 an envelope keeps an unmodifiable copy of its parent correlation ids',
    body: (TopicModelHarness h) async {
      final List<String> parents = <String>['p-1'];
      final MessageEnvelope<String> envelope = _envelope(parents: parents);
      parents.add('p-2');
      await h.settle();
      expect(envelope.parentCorrelationIds, equals(<String>['p-1']));
      expect(() => envelope.parentCorrelationIds.add('p-3'),
          throwsUnsupportedError);
    },
  ),
  (
    name: 'G4 a lineage keeps unmodifiable parent correlation ids',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('fresh');
      final Lineage combined = Lineage.combine(
        <Lineage>[
          Lineage.causedBy(_envelope(id: 'e-1', correlationId: 'c-1')),
          Lineage.causedBy(_envelope(id: 'e-2', correlationId: 'c-2')),
        ],
        trigger: 0,
        freshCorrelationId: mint.call,
      );
      await h.settle();
      expect(() => combined.parentCorrelationIds.add('x'),
          throwsUnsupportedError);
      expect(() => const Lineage.root().parentCorrelationIds.add('x'),
          throwsUnsupportedError);
    },
  ),
  // ------------------------------------------------------------ G6
  (
    name: 'G6 a state topic defaults to equality dedup, not sensitive, traced',
    body: (TopicModelHarness h) async {
      final StateTopic<int> topic = StateTopic<int>(name: 'a.count', initial: 0);
      await h.settle();
      expect(topic.dedup, Dedup.equality);
      expect(topic.sensitive, isFalse);
      expect(topic.tracing, Tracing.enabled);
      expect(topic.variant, TopicVariant.state);
    },
  ),
  (
    name: 'G6 event and replay topics default to not sensitive and traced',
    body: (TopicModelHarness h) async {
      final EventTopic<int> event = EventTopic<int>(name: 'a.tapped');
      final ReplayTopic<int> replay =
          ReplayTopic<int>(name: 'a.log', bufferSize: 3);
      await h.settle();
      expect(event.variant, TopicVariant.event);
      expect(event.sensitive, isFalse);
      expect(event.tracing, Tracing.enabled);
      expect(replay.variant, TopicVariant.replay);
      expect(replay.sensitive, isFalse);
      expect(replay.tracing, Tracing.enabled);
      expect(replay.bufferSize, 3);
    },
  ),
  // ------------------------------------------------------------ G7
  (
    name: 'G7 topics with the same variant, name and value type are equal',
    body: (TopicModelHarness h) async {
      final StateTopic<int> a = StateTopic<int>(name: 'a.count', initial: 0);
      final StateTopic<int> b = StateTopic<int>(
        name: 'a.count',
        initial: 1,
        dedup: Dedup.none,
        sensitive: true,
        tracing: Tracing.disabled,
      );
      final ReplayTopic<int> c = ReplayTopic<int>(name: 'a.log', bufferSize: 1);
      final ReplayTopic<int> d = ReplayTopic<int>(name: 'a.log', bufferSize: 9);
      await h.settle();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(c, equals(d));
      expect(c.hashCode, d.hashCode);
      expect(a.valueType, int);
    },
  ),
  (
    name: 'G7 topics differing in variant, name or value type are not equal',
    body: (TopicModelHarness h) async {
      final StateTopic<int> state = StateTopic<int>(name: 'a.value', initial: 0);
      final EventTopic<int> event = EventTopic<int>(name: 'a.value');
      final ReplayTopic<int> replay =
          ReplayTopic<int>(name: 'a.value', bufferSize: 1);
      final StateTopic<String> otherType =
          StateTopic<String>(name: 'a.value', initial: '');
      final StateTopic<int> otherName = StateTopic<int>(name: 'b.value', initial: 0);
      await h.settle();
      expect(state == event, isFalse);
      expect(event == replay, isFalse);
      expect(state == otherType, isFalse);
      expect(state == otherName, isFalse);
    },
  ),
  // ------------------------------------------------------------ G8
  (
    name: 'G8 a topic reference carries the name, the variant and the type name',
    body: (TopicModelHarness h) async {
      final StateTopic<List<int>> topic =
          StateTopic<List<int>>(name: 'a.items', initial: const <int>[]);
      final EventTopic<String?> event = EventTopic<String?>(name: 'a.tapped');
      await h.settle();
      expect(
        topic.ref,
        equals(const TopicRef(
          name: 'a.items',
          variant: TopicVariant.state,
          typeName: 'List<int>',
        )),
      );
      expect(event.ref.typeName, '${event.valueType}');
      expect(event.ref.variant, TopicVariant.event);
    },
  ),
  (
    name: 'G8 topic references are equal exactly when all three fields are',
    body: (TopicModelHarness h) async {
      const TopicRef ref =
          TopicRef(name: 'a.b', variant: TopicVariant.event, typeName: 'int');
      await h.settle();
      expect(
          ref,
          equals(TopicRef(
              name: 'a.b', variant: TopicVariant.event, typeName: 'int')));
      expect(
          ref.hashCode,
          TopicRef(name: 'a.b', variant: TopicVariant.event, typeName: 'int')
              .hashCode);
      expect(
          ref ==
              const TopicRef(
                  name: 'a.c', variant: TopicVariant.event, typeName: 'int'),
          isFalse);
      expect(
          ref ==
              const TopicRef(
                  name: 'a.b', variant: TopicVariant.state, typeName: 'int'),
          isFalse);
      expect(
          ref ==
              const TopicRef(
                  name: 'a.b', variant: TopicVariant.event, typeName: 'num'),
          isFalse);
    },
  ),
  // ------------------------------------------------------------ G9
  (
    name: 'G9 a constant initial value is returned as declared',
    body: (TopicModelHarness h) async {
      final List<int> value = <int>[1, 2];
      final StateTopic<List<int>> topic =
          StateTopic<List<int>>(name: 'a.items', initial: value);
      await h.settle();
      expect(identical(topic.createInitial(), value), isTrue);
      expect(identical(topic.createInitial(), value), isTrue);
    },
  ),
  (
    name: 'G9 a computed initial value is computed on each createInitial call, never at construction',
    body: (TopicModelHarness h) async {
      int calls = 0;
      final StateTopic<int> topic = StateTopic<int>.computed(
        name: 'a.session',
        initial: () => ++calls,
      );
      await h.settle();
      expect(calls, 0);
      expect(topic.createInitial(), 1);
      expect(topic.createInitial(), 2);
      expect(calls, 2);
    },
  ),
  // ------------------------------------------------------------ G10
  (
    name: 'G10 a replay topic with a buffer smaller than one value fails an assertion',
    body: (TopicModelHarness h) async {
      final int zero = <int>[0].single;
      await h.settle();
      expect(
        () => ReplayTopic<int>(name: 'a.log', bufferSize: zero),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ReplayTopic<int>(name: 'a.log', bufferSize: zero - 1),
        throwsA(isA<AssertionError>()),
      );
      expect(ReplayTopic<int>(name: 'a.log', bufferSize: zero + 1).bufferSize, 1);
    },
  ),
  // ------------------------------------------------------------ G11
  (
    name: 'G11 well-formed topic names have two or three lowercase kebab segments',
    body: (TopicModelHarness h) async {
      await h.settle();
      for (final String name in <String>[
        'auth.state',
        'checkout.cart-items',
        'checkout.submit-order',
        'auth.token.refresh',
        'nav.current-route',
        'error.app',
        'payments.v2-state',
      ]) {
        expect(isWellFormedTopicName(name), isTrue, reason: name);
      }
    },
  ),
  (
    name: 'G11 other names are not well formed',
    body: (TopicModelHarness h) async {
      await h.settle();
      for (final String name in <String>[
        '',
        'auth',
        'Auth.state',
        'auth.State',
        'auth..state',
        '.auth.state',
        'auth.state.',
        'auth.token.refresh.extra',
        'auth.cart_items',
        'auth.-items',
        'auth.items-',
        'auth.cart--items',
        '1auth.state',
        'auth.state ',
        'auth/state',
      ]) {
        expect(isWellFormedTopicName(name), isFalse, reason: name);
      }
    },
  ),
  (
    name: 'G11 topic constructors accept any name',
    body: (TopicModelHarness h) async {
      final EventTopic<int> topic = EventTopic<int>(name: 'Not A Pattern');
      await h.settle();
      expect(topic.name, 'Not A Pattern');
    },
  ),
  // ------------------------------------------------------------ G13
  (
    name: 'G13 envelopes with equal fields are equal and hash alike',
    body: (TopicModelHarness h) async {
      final MessageEnvelope<String> a =
          _envelope(causationId: 'e-0', parents: <String>['p-1', 'p-2']);
      final MessageEnvelope<String> b =
          _envelope(causationId: 'e-0', parents: <String>['p-1', 'p-2']);
      await h.settle();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    },
  ),
  (
    name: 'G13 envelopes differing in any field are not equal',
    body: (TopicModelHarness h) async {
      final MessageEnvelope<String> base =
          _envelope(parents: <String>['p-1', 'p-2']);
      await h.settle();
      for (final MessageEnvelope<String> other in <MessageEnvelope<String>>[
        _envelope(id: 'e-2', parents: <String>['p-1', 'p-2']),
        _envelope(payload: 'q', parents: <String>['p-1', 'p-2']),
        _envelope(correlationId: 'c-2', parents: <String>['p-1', 'p-2']),
        _envelope(causationId: 'e-0', parents: <String>['p-1', 'p-2']),
        _envelope(parents: <String>['p-2', 'p-1']),
        _envelope(
            source: const ServiceSource('other'), parents: <String>['p-1', 'p-2']),
        _envelope(sensitive: true, parents: <String>['p-1', 'p-2']),
      ]) {
        expect(base == other, isFalse, reason: '$other');
      }
      final MessageEnvelope<String> later = MessageEnvelope<String>(
        id: base.id,
        payload: base.payload,
        correlationId: base.correlationId,
        parentCorrelationIds: base.parentCorrelationIds,
        timestamp: _at.add(const Duration(milliseconds: 1)),
        source: base.source,
        sensitive: base.sensitive,
      );
      expect(base == later, isFalse);
    },
  ),
  (
    name: 'G13 an envelope whose payload is not equal to itself is not equal to itself',
    body: (TopicModelHarness h) async {
      final MessageEnvelope<double> envelope = MessageEnvelope<double>(
        id: 'e-1',
        payload: double.nan,
        correlationId: 'c-1',
        timestamp: _at,
        source: const ServiceSource('test'),
        sensitive: false,
      );
      await h.settle();
      expect(envelope.payload.isNaN, isTrue);
      expect(envelope == envelope, isFalse);
      expect(<MessageEnvelope<double>>{envelope}.contains(envelope), isFalse);
    },
  ),
  // ------------------------------------------------------------ G14
  (
    name: 'G14 a published envelope mirrors the destination topic sensitive flag',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('c');
      const StateTopic<String> secret =
          StateTopic<String>(name: 'a.secret', initial: '', sensitive: true);
      const StateTopic<String> plain = StateTopic<String>(name: 'a.plain', initial: '');
      final MessageEnvelope<String> intoSecret = MessageEnvelope<String>.publishedTo(
        secret,
        id: 'e-9',
        payload: 'v',
        lineage: const Lineage.root(correlationId: 'c-1'),
        freshCorrelationId: mint.call,
        timestamp: _at,
        source: const TopologySource('t'),
      );
      final MessageEnvelope<String> intoPlain = MessageEnvelope<String>.publishedTo(
        plain,
        id: 'e-10',
        payload: 'v',
        lineage: const Lineage.root(correlationId: 'c-1', sensitive: true),
        freshCorrelationId: mint.call,
        timestamp: _at,
        source: const TopologySource('t'),
      );
      await h.settle();
      expect(intoSecret.sensitive, isTrue);
      expect(intoPlain.sensitive, isFalse);
    },
  ),
  (
    name: 'G14 a published envelope takes its metadata from its arguments and its lineage',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('fresh');
      const EventTopic<String> topic = EventTopic<String>(name: 'a.out');
      final Lineage lineage = Lineage.causedBy(
          _envelope(id: 'e-1', correlationId: 'c-7', parents: <String>['p-1']));
      final MessageEnvelope<String> out = MessageEnvelope<String>.publishedTo(
        topic,
        id: 'e-2',
        payload: 'result',
        lineage: lineage,
        freshCorrelationId: mint.call,
        timestamp: _at,
        source: const TopologySource('flow'),
      );
      await h.settle();
      expect(out.id, 'e-2');
      expect(out.payload, 'result');
      expect(out.causationId, 'e-1');
      expect(out.correlationId, 'c-7');
      expect(out.parentCorrelationIds, equals(<String>['p-1']));
      expect(out.timestamp, _at);
      expect(out.source, const TopologySource('flow'));
      expect(mint.calls, 0);
    },
  ),
  (
    name: 'G14 a lineage without a correlation id takes exactly one fresh id at publish',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('fresh');
      final MessageEnvelope<int> out = MessageEnvelope<int>.publishedTo(
        const EventTopic<int>(name: 'a.out'),
        id: 'e-1',
        payload: 1,
        lineage: const Lineage.root(),
        freshCorrelationId: mint.call,
        timestamp: _at,
        source: const UnknownSource(),
      );
      await h.settle();
      expect(out.correlationId, 'fresh-1');
      expect(out.causationId, isNull);
      expect(out.parentCorrelationIds, isEmpty);
      expect(mint.calls, 1);
    },
  ),
  // ------------------------------------------------------------ G15
  (
    name: 'G15 a sensitive envelope renders its payload redacted',
    body: (TopicModelHarness h) async {
      final MessageEnvelope<_Secret> envelope = MessageEnvelope<_Secret>(
        id: 'e-1',
        payload: const _Secret(0x1234abcd),
        correlationId: 'c-1',
        timestamp: _at,
        source: const ServiceSource('auth'),
        sensitive: true,
      );
      await h.settle();
      expect(envelope.toString(), isNot(contains('SECRET-PAYLOAD')));
      expect(envelope.toString(),
          contains(RedactedPayload.of(envelope.payload).toString()));
    },
  ),
  (
    name: 'G15 redacted() replaces a sensitive payload and keeps every other field',
    body: (TopicModelHarness h) async {
      final MessageEnvelope<_Secret> envelope = MessageEnvelope<_Secret>(
        id: 'e-1',
        payload: const _Secret(7),
        correlationId: 'c-1',
        causationId: 'e-0',
        parentCorrelationIds: const <String>['p-1'],
        timestamp: _at,
        source: const ServiceSource('auth'),
        sensitive: true,
      );
      final MessageEnvelope<Object?> shown = envelope.redacted();
      await h.settle();
      expect(shown.payload, RedactedPayload.of(const _Secret(7)));
      expect(shown.id, envelope.id);
      expect(shown.correlationId, envelope.correlationId);
      expect(shown.causationId, envelope.causationId);
      expect(shown.parentCorrelationIds, envelope.parentCorrelationIds);
      expect(shown.timestamp, envelope.timestamp);
      expect(shown.source, envelope.source);
      expect(shown.sensitive, isTrue);
    },
  ),
  (
    name: 'G15 redacted() leaves a non-sensitive envelope equal to itself',
    body: (TopicModelHarness h) async {
      final MessageEnvelope<String> envelope = _envelope(payload: 'visible');
      await h.settle();
      expect(envelope.redacted(), equals(envelope));
      expect(envelope.redacted().payload, 'visible');
    },
  ),
  (
    name: 'G15 an envelope that redacted() returned is redacted again',
    body: (TopicModelHarness h) async {
      final MessageEnvelope<_Secret> envelope = MessageEnvelope<_Secret>(
        id: 'e-1',
        payload: const _Secret(7),
        correlationId: 'c-1',
        timestamp: _at,
        source: const ServiceSource('auth'),
        sensitive: true,
      );
      final MessageEnvelope<Object?> once = envelope.redacted();
      final MessageEnvelope<Object?> twice = once.redacted();
      await h.settle();
      final RedactedPayload inner = RedactedPayload.of(const _Secret(7));
      final RedactedPayload outer = RedactedPayload.of(inner);
      expect(once.payload, inner);
      expect(once.sensitive, isTrue);
      expect(twice.payload, outer);
      expect(outer.typeName, 'RedactedPayload');
      expect(once.toString(), contains(outer.toString()));
      expect(once.toString(), isNot(contains(inner.toString())));
      expect(envelope.toString(), contains(inner.toString()));
    },
  ),
  // ------------------------------------------------------------ G17
  (
    name: 'G17 a source renders in the Spec 2.4 format',
    body: (TopicModelHarness h) async {
      await h.settle();
      expect(const TopologySource('checkout-flow').toString(),
          'topology:checkout-flow');
      expect(const ServiceSource('payment-gateway').toString(),
          'service:payment-gateway');
      expect(const PageSource('checkout/cart').toString(), 'page:checkout/cart');
      expect(const ExecutorSource('flutter-navigation').toString(),
          'executor:flutter-navigation');
      expect(const UnknownSource().toString(), 'unknown');
    },
  ),
  (
    name: 'G17 tryParse reads back every rendered source',
    body: (TopicModelHarness h) async {
      await h.settle();
      for (final MessageSource source in const <MessageSource>[
        TopologySource('checkout-flow'),
        ServiceSource('payment-gateway'),
        PageSource('/users/:id'),
        ExecutorSource('flutter-navigation'),
        UnknownSource(),
      ]) {
        expect(MessageSource.tryParse(source.toString()), equals(source));
      }
    },
  ),
  (
    name: 'G17 tryParse returns null for text that is not a source',
    body: (TopicModelHarness h) async {
      await h.settle();
      for (final String text in <String>[
        '',
        'service',
        'service:',
        ':payment',
        'job:nightly',
        'Service:payment',
        'unknown:x',
      ]) {
        expect(MessageSource.tryParse(text), isNull, reason: text);
      }
    },
  ),
  (
    name: 'G17 sources are equal exactly when variant and name are',
    body: (TopicModelHarness h) async {
      await h.settle();
      expect(const ServiceSource('a'), equals(const ServiceSource('a')));
      expect(
          const ServiceSource('a').hashCode, const ServiceSource('a').hashCode);
      expect(const ServiceSource('a') == const ServiceSource('b'), isFalse);
      expect(const ServiceSource('a') == const ExecutorSource('a'), isFalse);
      expect(const UnknownSource(), equals(const UnknownSource()));
    },
  ),
  // ------------------------------------------------------------ G18
  (
    name: 'G18 a lineage caused by an envelope points at it and keeps its flow',
    body: (TopicModelHarness h) async {
      final Lineage lineage = Lineage.causedBy(_envelope(
        id: 'msg-001',
        correlationId: 'ord-123',
        parents: <String>['p-1'],
        sensitive: true,
      ));
      await h.settle();
      expect(lineage.causationId, 'msg-001');
      expect(lineage.correlationId, 'ord-123');
      expect(lineage.parentCorrelationIds, equals(<String>['p-1']));
      expect(lineage.sensitive, isTrue);
    },
  ),
  (
    name: 'G18 a root lineage has no cause and no parents',
    body: (TopicModelHarness h) async {
      const Lineage untraced = Lineage.root();
      const Lineage started = Lineage.root(correlationId: 'ord-1', sensitive: true);
      await h.settle();
      expect(untraced.causationId, isNull);
      expect(untraced.correlationId, isNull);
      expect(untraced.parentCorrelationIds, isEmpty);
      expect(untraced.sensitive, isFalse);
      expect(started.causationId, isNull);
      expect(started.correlationId, 'ord-1');
      expect(started.parentCorrelationIds, isEmpty);
      expect(started.sensitive, isTrue);
      expect(untraced == started, isFalse);
      expect(untraced, equals(const Lineage.root()));
    },
  ),
  // ------------------------------------------------------------ G19
  (
    name: 'G19 a same-correlation combine keeps the correlation and takes the trigger as cause',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('derived');
      final Lineage cart =
          Lineage.causedBy(_envelope(id: 'e-01', correlationId: 'sess-42'));
      final Lineage auth =
          Lineage.causedBy(_envelope(id: 'e-02', correlationId: 'sess-42'));
      final Lineage out = Lineage.combine(<Lineage>[cart, auth],
          trigger: 1, freshCorrelationId: mint.call);
      await h.settle();
      expect(out.causationId, 'e-02');
      expect(out.correlationId, 'sess-42');
      expect(out.parentCorrelationIds, isEmpty);
      expect(mint.calls, 0);
    },
  ),
  (
    name: 'G19 a cross-correlation combine takes one fresh correlation and records the inputs',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('derived');
      final Lineage prefs =
          Lineage.causedBy(_envelope(id: 'e-10', correlationId: 'pref-update-5'));
      final Lineage price =
          Lineage.causedBy(_envelope(id: 'e-11', correlationId: 'market-feed-9'));
      final Lineage out = Lineage.combine(<Lineage>[prefs, price],
          trigger: 1, freshCorrelationId: mint.call);
      await h.settle();
      expect(out.causationId, 'e-11');
      expect(out.correlationId, 'derived-1');
      expect(out.parentCorrelationIds,
          equals(<String>['pref-update-5', 'market-feed-9']));
      expect(mint.calls, 1);
    },
  ),
  (
    name: 'G19 a cross-correlation combine records each distinct input correlation once, in input order',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('derived');
      final Lineage out = Lineage.combine(
        <Lineage>[
          Lineage.causedBy(_envelope(id: 'e-1', correlationId: 'b')),
          Lineage.causedBy(_envelope(id: 'e-2', correlationId: 'a')),
          Lineage.causedBy(_envelope(id: 'e-3', correlationId: 'b')),
        ],
        trigger: 0,
        freshCorrelationId: mint.call,
      );
      await h.settle();
      expect(out.causationId, 'e-1');
      expect(out.parentCorrelationIds, equals(<String>['b', 'a']));
      expect(mint.calls, 1);
    },
  ),
  (
    name: 'G19 a same-correlation combine unites the inputs parent correlation ids in input order',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('derived');
      final Lineage out = Lineage.combine(
        <Lineage>[
          Lineage.causedBy(_envelope(
              id: 'e-1', correlationId: 'c', parents: <String>['p-1', 'p-2'])),
          Lineage.causedBy(_envelope(
              id: 'e-2', correlationId: 'c', parents: <String>['p-2', 'p-3'])),
        ],
        trigger: 1,
        freshCorrelationId: mint.call,
      );
      await h.settle();
      expect(out.correlationId, 'c');
      expect(out.parentCorrelationIds, equals(<String>['p-1', 'p-2', 'p-3']));
      expect(mint.calls, 0);
    },
  ),
  (
    name: 'G19 inputs without a correlation id contribute none',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('derived');
      final Lineage traced =
          Lineage.causedBy(_envelope(id: 'e-1', correlationId: 'c-1'));
      final Lineage withUntraced = Lineage.combine(
          <Lineage>[const Lineage.root(), traced],
          trigger: 0,
          freshCorrelationId: mint.call);
      final Lineage allUntraced = Lineage.combine(
          <Lineage>[const Lineage.root(), const Lineage.root()],
          trigger: 1,
          freshCorrelationId: mint.call);
      await h.settle();
      expect(withUntraced.causationId, isNull);
      expect(withUntraced.correlationId, 'c-1');
      expect(allUntraced.causationId, isNull);
      expect(allUntraced.correlationId, isNull);
      expect(allUntraced.parentCorrelationIds, isEmpty);
      expect(mint.calls, 0);
    },
  ),
  (
    name: 'G19 a combine is sensitive when any input is',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('derived');
      final Lineage plain =
          Lineage.causedBy(_envelope(id: 'e-1', correlationId: 'c'));
      final Lineage secret = Lineage.causedBy(
          _envelope(id: 'e-2', correlationId: 'c', sensitive: true));
      await h.settle();
      expect(
          Lineage.combine(<Lineage>[plain, secret],
                  trigger: 0, freshCorrelationId: mint.call)
              .sensitive,
          isTrue);
      expect(
          Lineage.combine(<Lineage>[plain, plain],
                  trigger: 0, freshCorrelationId: mint.call)
              .sensitive,
          isFalse);
    },
  ),
  (
    name: 'G19 a combine rejects an empty input list and a trigger out of range',
    body: (TopicModelHarness h) async {
      final _Minter mint = _Minter('derived');
      final Lineage one = Lineage.causedBy(_envelope());
      await h.settle();
      expect(
          () => Lineage.combine(<Lineage>[],
              trigger: 0, freshCorrelationId: mint.call),
          throwsArgumentError);
      expect(
          () => Lineage.combine(<Lineage>[one],
              trigger: 1, freshCorrelationId: mint.call),
          throwsArgumentError);
      expect(
          () => Lineage.combine(<Lineage>[one],
              trigger: -1, freshCorrelationId: mint.call),
          throwsArgumentError);
      expect(mint.calls, 0);
    },
  ),
  // ------------------------------------------------------------ G20
  (
    name: 'G20 withLatestFrom keeps the primary cause and flow and unites sensitivity',
    body: (TopicModelHarness h) async {
      final Lineage submit = Lineage.causedBy(_envelope(
          id: 'e-1', correlationId: 'order-1', parents: <String>['p-1']));
      final Lineage cart = Lineage.causedBy(
          _envelope(id: 'e-2', correlationId: 'session-9', sensitive: true));
      final Lineage out = Lineage.withLatestFrom(submit, <Lineage>[cart]);
      final Lineage alone = Lineage.withLatestFrom(submit, <Lineage>[]);
      await h.settle();
      expect(out.causationId, 'e-1');
      expect(out.correlationId, 'order-1');
      expect(out.parentCorrelationIds, equals(<String>['p-1']));
      expect(out.sensitive, isTrue);
      expect(alone, equals(submit));
    },
  ),
  // ------------------------------------------------------------ G21
  (
    name: 'G21 scopes are ordered application, module, page by lifetime',
    body: (TopicModelHarness h) async {
      await h.settle();
      expect(Scope.values,
          equals(<Scope>[Scope.application, Scope.module, Scope.page]));
      for (final Scope reader in Scope.values) {
        expect(Scope.application.isAtLeastAsLongAs(reader), isTrue);
        expect(reader.isAtLeastAsLongAs(reader), isTrue);
      }
      expect(Scope.module.isAtLeastAsLongAs(Scope.page), isTrue);
      expect(Scope.module.isAtLeastAsLongAs(Scope.application), isFalse);
      expect(Scope.page.isAtLeastAsLongAs(Scope.module), isFalse);
      expect(Scope.page.isAtLeastAsLongAs(Scope.application), isFalse);
    },
  ),
  // ------------------------------------------------------------ G23
  (
    name: 'G23 observeAll admits non-sensitive envelopes only, observeSensitive sensitive ones only',
    body: (TopicModelHarness h) async {
      const Set<ObserverCapability> none = <ObserverCapability>{};
      const Set<ObserverCapability> all = <ObserverCapability>{
        ObserverCapability.observeAll,
      };
      const Set<ObserverCapability> sensitiveOnly = <ObserverCapability>{
        ObserverCapability.observeSensitive,
      };
      const Set<ObserverCapability> both = <ObserverCapability>{
        ObserverCapability.observeAll,
        ObserverCapability.observeSensitive,
      };
      await h.settle();
      expect(ObserverCapability.permits(none, sensitive: false), isFalse);
      expect(ObserverCapability.permits(none, sensitive: true), isFalse);
      expect(ObserverCapability.permits(all, sensitive: false), isTrue);
      expect(ObserverCapability.permits(all, sensitive: true), isFalse);
      expect(ObserverCapability.permits(sensitiveOnly, sensitive: false), isFalse);
      expect(ObserverCapability.permits(sensitiveOnly, sensitive: true), isTrue);
      expect(ObserverCapability.permits(both, sensitive: false), isTrue);
      expect(ObserverCapability.permits(both, sensitive: true), isTrue);
    },
  ),
  // ------------------------------------------------------------ G24
  (
    name: 'G24 a redacted payload shows the runtime type and eight hex digits of the hash code',
    body: (TopicModelHarness h) async {
      const _Secret secret = _Secret(0x1234abcd);
      const _Secret negative = _Secret(-1);
      final RedactedPayload redacted = RedactedPayload.of(secret);
      await h.settle();
      expect(redacted.typeName, secret.runtimeType.toString());
      expect(redacted.hash, '1234abcd');
      expect(RedactedPayload.of(negative).hash, 'ffffffff');
      expect(RedactedPayload.of(const _Secret(0xab)).hash, '000000ab');
      expect(redacted.toString(),
          '<redacted ${secret.runtimeType} #1234abcd>');
      expect(redacted.toString(), isNot(contains('SECRET-PAYLOAD')));
      expect(RedactedPayload.of(null).typeName, 'Null');
    },
  ),
  (
    name: 'G24 equal payloads redact to equal values',
    body: (TopicModelHarness h) async {
      await h.settle();
      expect(RedactedPayload.of(const _Secret(42)),
          equals(RedactedPayload.of(const _Secret(42))));
      expect(RedactedPayload.of(const _Secret(42)).hashCode,
          RedactedPayload.of(const _Secret(42)).hashCode);
      expect(RedactedPayload.of(const _Secret(42)) ==
              RedactedPayload.of(const _Secret(43)),
          isFalse);
    },
  ),
  (
    name: 'G24 equal payloads of two runtime types redact apart',
    body: (TopicModelHarness h) async {
      const Object one = 1;
      const Object onePointZero = 1.0;
      await h.settle();
      expect(RedactedPayload.of(const _Twin(5)).hash,
          RedactedPayload.of(const _Secret(5)).hash);
      expect(RedactedPayload.of(const _Twin(5)) ==
              RedactedPayload.of(const _Secret(5)),
          isFalse);
      expect(one == onePointZero, isTrue);
      expect(RedactedPayload.of(one) == RedactedPayload.of(onePointZero),
          one.runtimeType == onePointZero.runtimeType);
    },
  ),
  // ------------------------------------------------------------ G27
  (
    name: 'G27 event and replay topics are multi-writer topics and a state topic is not',
    body: (TopicModelHarness h) async {
      final List<Topic<int>> topics = <Topic<int>>[
        StateTopic<int>(name: 'a.count', initial: 0),
        EventTopic<int>(name: 'a.tapped'),
        ReplayTopic<int>(name: 'a.log', bufferSize: 1),
      ];
      await h.settle();
      expect(
        topics.map((Topic<int> t) => t is MultiWriterTopic<int>).toList(),
        equals(<bool>[false, true, true]),
      );
      expect(
        topics
            .map((Topic<int> t) => switch (t) {
                  StateTopic<int>() => 'one owner',
                  MultiWriterTopic<int>() => 'any writer',
                })
            .toList(),
        equals(<String>['one owner', 'any writer', 'any writer']),
      );
    },
  ),
];
