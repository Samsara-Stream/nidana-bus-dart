// P4: when an activation's connection reaches its reads, relative to a value
// published right after activate returns (bus-api@v1 G22) and to the queue
// start() delivers (bus-api@v1 G34). A withLatestFrom over a state read
// drops every primary value that arrives before the state's first value.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/testing.dart';

const StateTopic<int> s = StateTopic<int>(name: 'probe.s', initial: 1);
const EventTopic<int> e = EventTopic<int>(name: 'probe.e');
const EventTopic<int> out = EventTopic<int>(name: 'probe.out');

Topology gate() => topology('probe-gate', Scope.application,
    (TopologyBuilder b) => b.write(out, b.read(e).withLatestFrom(b.read(s), (int v, int w) => v * 10 + w)));

void main() {
  final TestBus a = TestBus();
  a.start();
  a.activate(gate());
  a.input.publish(e, 4);
  a.scheduler.triggerActions();
  print('G22, published right after activate:   ${a.recorder.payloadsOf(out)} (41 when the connection comes first)');

  final TestBus b = TestBus();
  b.input.publish(e, 4);
  b.activate(gate());
  b.start();
  b.scheduler.triggerActions();
  print('G34, queued, start() right after activate: ${b.recorder.payloadsOf(out)} (41 when the connection comes first)');

  final TestBus c = TestBus();
  c.input.publish(e, 4);
  c.activate(gate());
  c.scheduler.triggerActions();
  c.start();
  c.scheduler.triggerActions();
  print('G34, queued, microtasks run before start(): ${c.recorder.payloadsOf(out)}');
}
