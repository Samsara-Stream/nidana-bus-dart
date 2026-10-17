// Probe: which diagnostic code does each candidate misuse report?
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class A extends StateTopic<int> {
  const A() : super(name: 'a.b', initial: 0);
}

final class B implements Topic<int> {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

final class C extends MessageSource {
  C() : super._();
}

final class D implements MessageSource {}

int exhaustive(Topic<int> t) => switch (t) {
      StateTopic<int>() => 1,
      EventTopic<int>() => 2,
    };

T current<T>(StateTopic<T> topic) => topic.createInitial();

void misuse(EventTopic<int> e, ReplayTopic<int> r, StateTopic<int> s, ObserveContext ctx, MessageEnvelope<int> env, TopicRef ref) {
  e.createInitial();
  r.createInitial();
  e.dedup;
  current(e);
  final StateTopic<int> x = e;
  s.name = 'x';
  env.payload = 2;
  env.parentCorrelationIds = <String>[];
  ctx.publish(ref, 1);
  ctx.bus;
  env.publish();
  ref.publish(1);
  print(x);
}

const StateTopic<int> noInitial = StateTopic<int>(name: 'a.b');
const EventTopic<int> withDedup = EventTopic<int>(name: 'a.b', dedup: Dedup.none);
const StateTopic<int> withDispatcher = StateTopic<int>(name: 'a.b', initial: 0, dispatcher: 'main');
const ReplayTopic<int> zero = ReplayTopic<int>(name: 'a.b', bufferSize: 0);
final ReplayTopic<int> zeroFinal = ReplayTopic<int>(name: 'a.b', bufferSize: 0);
const StateTopic<int> computedWrong = StateTopic<int>.computed(name: 'a.b', initial: 0);

final MessageEnvelope<int> noIdNoTime = MessageEnvelope<int>(payload: 1, correlationId: 'c', source: const UnknownSource(), sensitive: false);

String source(MessageSource s) => switch (s) {
      TopologySource() => 't',
      ServiceSource() => 's',
      PageSource() => 'p',
      ExecutorSource() => 'e',
    };

String scope(Scope s) => switch (s) {
      Scope.application => 'a',
      Scope.module => 'm',
    };
