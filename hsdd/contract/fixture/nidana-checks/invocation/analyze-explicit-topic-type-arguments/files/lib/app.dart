import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

abstract final class CounterTopics {
  static const EventTopic<int> increment = EventTopic<int>(name: 'counter.increment');
  static const ReplayTopic<int> history = ReplayTopic<int>(name: 'counter.history', bufferSize: 10);
  static const StateTopic<int> value = StateTopic<int>(name: 'counter.value', initial: 0);
  static const StateTopic<int> doubled = StateTopic<int>(name: 'counter.doubled', initial: 0);
}

void publish(Bus bus, Publisher publisher) {
  // Reported: explicit type arguments can widen the topic's type.
  bus.publish<num, int>(CounterTopics.increment, 1);
  publisher.publish<Object?, int>(CounterTopics.history, 2);
  // Accepted: the topic's type decides.
  bus.publish(CounterTopics.increment, 3);
  publisher.publish(CounterTopics.history, 4);
  // Accepted: type arguments on reads widen nothing.
  bus.observe<int>(CounterTopics.value);
}

final class CounterTopology extends Topology {
  const CounterTopology();

  @override
  String get topologyId => 'counter';

  @override
  Scope get scope => Scope.application;

  @override
  void declare(TopologyBuilder b) {
    // Reported: write and reduceInto with explicit type arguments.
    b.write<num, int>(CounterTopics.doubled, b.read(CounterTopics.value).map(twice));
    b.reduceInto<int, int>(CounterTopics.value, b.read(CounterTopics.increment), add);
  }
}

final class QuietTopology extends Topology {
  const QuietTopology();

  @override
  String get topologyId => 'quiet';

  @override
  Scope get scope => Scope.application;

  @override
  void declare(TopologyBuilder b) {
    // Accepted: inferred.
    b.write(CounterTopics.doubled, b.read(CounterTopics.value).map(twice));
    b.reduceInto(CounterTopics.value, b.read(CounterTopics.increment), add);
  }
}

int twice(int v) => v * 2;

int add(int total, int step) => total + step;
