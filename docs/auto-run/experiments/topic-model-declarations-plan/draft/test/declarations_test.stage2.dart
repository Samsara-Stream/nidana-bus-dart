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
}
