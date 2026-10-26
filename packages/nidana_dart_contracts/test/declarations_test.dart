// What the declarations of topic-model@v1 fix before any body computes
// (nidana.model D3): defaults, the members that are constants of a
// declaration, and the asserts of non-const construction.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('G6 defaults: not sensitive, traced, deduplicated by equality', () {
    const StateTopic<int> state = StateTopic<int>(name: 'a.count', initial: 0);
    final StateTopic<int> computed = StateTopic<int>.computed(
      name: 'a.count',
      initial: () => 0,
    );
    const EventTopic<int> event = EventTopic<int>(name: 'a.tapped');
    const ReplayTopic<int> replay = ReplayTopic<int>(
      name: 'a.log',
      bufferSize: 1,
    );
    for (final Topic<int> topic in <Topic<int>>[
      state,
      computed,
      event,
      replay,
    ]) {
      expect(topic.sensitive, isFalse);
      expect(topic.tracing, Tracing.enabled);
    }
    expect(state.dedup, Dedup.equality);
    expect(computed.dedup, Dedup.equality);
  });

  test('G6 G7 variant names the class and valueType is T', () {
    final List<Topic<Object?>> topics = <Topic<Object?>>[
      const StateTopic<int>(name: 'a.count', initial: 0),
      const EventTopic<String>(name: 'a.tapped'),
      const ReplayTopic<bool>(name: 'a.log', bufferSize: 2),
    ];
    expect(topics.map((Topic<Object?> t) => t.variant), <TopicVariant>[
      TopicVariant.state,
      TopicVariant.event,
      TopicVariant.replay,
    ]);
    expect(topics.map((Topic<Object?> t) => t.valueType), <Type>[
      int,
      String,
      bool,
    ]);
  });

  test('G9 constructing a computed state topic never calls its factory', () {
    expect(
      () => StateTopic<int>.computed(
        name: 'a.count',
        initial: () => throw StateError('called at construction'),
      ),
      returnsNormally,
    );
  });

  test('G10 a non-const replay topic below one value fails an assertion', () {
    int size = 0;
    expect(
      () => ReplayTopic<int>(name: 'a.log', bufferSize: size),
      throwsA(isA<AssertionError>()),
    );
    size = -1;
    expect(
      () => ReplayTopic<int>(name: 'a.log', bufferSize: size),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a source with an empty field fails an assertion', () {
    String empty = '';
    expect(() => TopologySource(empty), throwsA(isA<AssertionError>()));
    expect(() => ServiceSource(empty), throwsA(isA<AssertionError>()));
    expect(() => PageSource(empty), throwsA(isA<AssertionError>()));
    expect(() => ExecutorSource(empty), throwsA(isA<AssertionError>()));
    empty = 'x';
    expect(() => ServiceSource(empty), returnsNormally);
  });

  test('an envelope keeps the fields it is given, with no causation and no '
      'parents by default', () {
    final DateTime at = DateTime.utc(2026);
    const MessageSource source = ServiceSource('s');
    final MessageEnvelope<int> envelope = MessageEnvelope<int>(
      id: 'e-1',
      payload: 1,
      correlationId: 'c-1',
      timestamp: at,
      source: source,
      sensitive: true,
    );
    expect(envelope.id, 'e-1');
    expect(envelope.payload, 1);
    expect(envelope.correlationId, 'c-1');
    expect(envelope.causationId, isNull);
    expect(envelope.parentCorrelationIds, isEmpty);
    expect(envelope.timestamp, at);
    expect(envelope.source, same(source));
    expect(envelope.sensitive, isTrue);
  });

  test('G18 Lineage.root has no causation and no parents, and the '
      'correlation and sensitivity it is given, null and false by default', () {
    const Lineage root = Lineage.root();
    expect(root.causationId, isNull);
    expect(root.correlationId, isNull);
    expect(root.parentCorrelationIds, isEmpty);
    expect(root.sensitive, isFalse);
    const Lineage started = Lineage.root(correlationId: 'f-1', sensitive: true);
    expect(started.causationId, isNull);
    expect(started.correlationId, 'f-1');
    expect(started.parentCorrelationIds, isEmpty);
    expect(started.sensitive, isTrue);
  });
}
