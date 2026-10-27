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

  test('G11 a name with too few segments, an empty segment or a malformed '
      'segment is not well formed', () {
    for (final String name in <String>[
      '',
      '.',
      'auth',
      'auth.',
      '.state',
      'auth..state',
      'auth.state.',
      'auth.state..login',
      '1auth.state',
      'auth.2state',
      'auth.state-',
      'auth.-state',
      'auth.st--ate',
      'auth.st_ate',
      'auth\n.state',
      'auth.state\nauth.state',
    ]) {
      expect(isWellFormedTopicName(name), isFalse, reason: name);
    }
    for (final String name in <String>[
      'auth.state',
      'auth.state.login',
      'a-b.c-d-e.f-g',
      'a0.b0.c0',
      'auth.state2',
    ]) {
      expect(isWellFormedTopicName(name), isTrue, reason: name);
    }
  });

  test('G7 a topic ignores its initial value, dedup, sensitive flag, tracing '
      'and buffer size when it compares and hashes', () {
    final String name = <String>['a.count'].single;
    final List<Topic<int>> states = <Topic<int>>[
      StateTopic<int>(name: name, initial: 0),
      StateTopic<int>(name: name, initial: 7, dedup: Dedup.none),
      StateTopic<int>(
        name: name,
        initial: 0,
        sensitive: true,
        tracing: Tracing.disabled,
      ),
      StateTopic<int>.computed(name: name, initial: () => 3),
    ];
    for (final Topic<int> topic in states) {
      expect(topic, states.first);
      expect(topic.hashCode, states.first.hashCode);
    }
    final ReplayTopic<int> small = ReplayTopic<int>(name: name, bufferSize: 1);
    final ReplayTopic<int> large = ReplayTopic<int>(
      name: name,
      bufferSize: 5,
      sensitive: true,
      tracing: Tracing.disabled,
    );
    expect(small, large);
    expect(small.hashCode, large.hashCode);
  });

  test('G7 a topic differs in its variant, its name or its value type, and '
      'from a value that is not a topic', () {
    final String name = <String>['a.count'].single;
    final Topic<int> state = StateTopic<int>(name: name, initial: 0);
    expect(state, isNot(EventTopic<int>(name: name)));
    expect(
      EventTopic<int>(name: name),
      isNot(ReplayTopic<int>(name: name, bufferSize: 1)),
    );
    expect(state, isNot(StateTopic<int>(name: 'a.total', initial: 0)));
    expect(state, isNot(StateTopic<num>(name: name, initial: 0)));
    expect(state, isNot(StateTopic<int?>(name: name, initial: 0)));
    final Object text = name;
    final Object reference = state.ref;
    expect(state == text, isFalse);
    expect(state == reference, isFalse);
  });

  test('G8 a reference differs in each of its three fields, and equal '
      'references hash alike', () {
    final String name = <String>['a.count'].single;
    final TopicRef ref = TopicRef(
      name: name,
      variant: TopicVariant.state,
      typeName: 'int',
    );
    final TopicRef twin = TopicRef(
      name: name,
      variant: TopicVariant.state,
      typeName: 'int',
    );
    expect(twin, ref);
    expect(twin.hashCode, ref.hashCode);
    expect(
      TopicRef(name: 'a.total', variant: TopicVariant.state, typeName: 'int'),
      isNot(ref),
    );
    expect(
      TopicRef(name: name, variant: TopicVariant.event, typeName: 'int'),
      isNot(ref),
    );
    expect(
      TopicRef(name: name, variant: TopicVariant.state, typeName: 'num'),
      isNot(ref),
    );
    final Object text = name;
    expect(ref == text, isFalse);
  });

  test('G9 a computed initial value is made afresh for each call, and a '
      'constant one is the declared object', () {
    int calls = 0;
    final StateTopic<List<int>> computed = StateTopic<List<int>>.computed(
      name: 'a.items',
      initial: () {
        calls += 1;
        return <int>[calls];
      },
    );
    expect(calls, 0);
    final List<int> first = computed.createInitial();
    final List<int> second = computed.createInitial();
    expect(calls, 2);
    expect(first, <int>[1]);
    expect(second, <int>[2]);
    expect(identical(first, second), isFalse);

    final List<int> declared = <int>[1, 2];
    final StateTopic<List<int>> constant = StateTopic<List<int>>(
      name: 'a.items',
      initial: declared,
    );
    expect(identical(constant.createInitial(), declared), isTrue);
    expect(identical(constant.createInitial(), declared), isTrue);
  });
}
