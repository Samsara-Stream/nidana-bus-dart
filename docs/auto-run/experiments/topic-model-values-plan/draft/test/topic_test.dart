// topic-model@v1's topics, topic references and topic names, beyond the
// cases of its conformance suite, which the gate replays
// (hsdd/contract/fixture/topic-model/behavior/).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('non-default dedup, sensitive and tracing reach their fields', () {
    final List<Topic<int>> topics = <Topic<int>>[
      const StateTopic<int>(
        name: 'a.count',
        initial: 0,
        dedup: Dedup.none,
        sensitive: true,
        tracing: Tracing.disabled,
      ),
      StateTopic<int>.computed(
        name: 'a.count',
        initial: () => 0,
        dedup: Dedup.none,
        sensitive: true,
        tracing: Tracing.disabled,
      ),
      const EventTopic<int>(
        name: 'a.tapped',
        sensitive: true,
        tracing: Tracing.disabled,
      ),
      const ReplayTopic<int>(
        name: 'a.log',
        bufferSize: 2,
        sensitive: true,
        tracing: Tracing.disabled,
      ),
    ];
    for (final Topic<int> topic in topics) {
      expect(topic.sensitive, isTrue);
      expect(topic.tracing, Tracing.disabled);
      if (topic is StateTopic<int>) {
        expect(topic.dedup, Dedup.none);
      }
    }
  });

  test('G9 a nullable value type keeps a null initial value, constant or '
      'computed', () {
    const StateTopic<String?> constant = StateTopic<String?>(
      name: 'a.draft',
      initial: null,
    );
    final StateTopic<String?> computed = StateTopic<String?>.computed(
      name: 'a.draft',
      initial: () => null,
    );
    expect(constant.createInitial(), isNull);
    expect(computed.createInitial(), isNull);
  });

  test('G7 G8 equal topics and references built apart are one set element '
      'and one map key', () {
    final String name = <String>['a.count'].single;
    final Set<Topic<Object?>> topics = <Topic<Object?>>{
      StateTopic<int>(name: name, initial: 0),
      StateTopic<int>(name: name, initial: 1, dedup: Dedup.none),
      StateTopic<int?>(name: name, initial: 0),
      EventTopic<int>(name: name),
    };
    expect(topics, hasLength(3));
    final Map<TopicRef, String> owners = <TopicRef, String>{
      StateTopic<int>(name: name, initial: 0).ref: 'first',
    };
    owners[StateTopic<int>(name: name, initial: 2, sensitive: true).ref] =
        'second';
    expect(owners, <TopicRef, String>{
      TopicRef(name: name, variant: TopicVariant.state, typeName: 'int'):
          'second',
    });
  });

  test('G8 a reference names a nested value type as its type argument '
      'reads', () {
    final StateTopic<Map<String, List<int>?>> index =
        StateTopic<Map<String, List<int>?>>(
          name: 'a.index',
          initial: const <String, List<int>?>{},
        );
    expect(index.ref.typeName, 'Map<String, List<int>?>');
    expect(index.ref.typeName, '${index.valueType}');
  });

  test('G11 a name with a trailing newline, a non-ASCII letter or inner '
      'white space is not well formed', () {
    for (final String name in <String>[
      'auth.state\n',
      'auth.state\t',
      'auth.ståte',
      'auth.st ate',
      ' auth.state',
      'auth.STATE',
      'auth.-',
      'a.b.c.d',
    ]) {
      expect(isWellFormedTopicName(name), isFalse, reason: name);
    }
    for (final String name in <String>[
      'a.b',
      'a.b.c',
      'a1.b2-c3',
      'auth.v-2',
    ]) {
      expect(isWellFormedTopicName(name), isTrue, reason: name);
    }
  });
}
