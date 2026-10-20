// ignore_for_file: depend_on_referenced_packages
// runtime-topic-storage probe: what an observed subscription and a topology
// read receive first, on the runtime swapped into the stand-in package, and
// what one delivery costs. Run against each runtime:
//   fvm dart run probe/first_delivery.dart
//
// P1 (bus-api@v2 G17): a subscription made after start() to a state topic,
//     with a publish between listen and the first bus microtask, and one
//     whose callback publishes while it receives its first values.
// P2 (G34 step 2): a subscription made during bootstrap.
// P3 (G34 step 1): a reader activated before its input's writer.
// P4: the cost of one delivery to three observed subscriptions and one
//     topology read, on a production-provider bus in the root zone.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const StateTopic<int> _s = StateTopic<int>(name: 'p.s', initial: 1);
const StateTopic<int> _x = StateTopic<int>(name: 'p.x', initial: 0);
const StateTopic<int> _y = StateTopic<int>(name: 'p.y', initial: 0);
const ReplayTopic<int> _r = ReplayTopic<int>(name: 'p.r', bufferSize: 2);
const EventTopic<int> _e = EventTopic<int>(name: 'p.e');
const StateTopic<int> _never = StateTopic<int>(name: 'p.never', initial: 0);

const ServiceSource _svc = ServiceSource('probe');

int _times10(int v) => v * 10;
int _plus1(int v) => v + 1;
bool _negative(int v) => v < 0;

void p1() {
  print('== P1 a subscription made after start (G17)');
  final TestBus bus = TestBus(const BusConfig(devMode: false));
  bus.start();
  final Publisher p = bus.publisher(_svc, writes: <StateTopic<Object?>>{_s});
  final StateWriter<int> w = p.writer(_s);
  final List<int> got = <int>[];
  bus.observe(_s).listen(got.add);
  w.publish(2);
  print('after listen and publish(2), before the microtask: $got');
  bus.scheduler.triggerActions();
  print('after triggerActions: $got');
  w.publish(3);
  print('after publish(3): $got');

  // A callback that publishes to a replay topic while it receives its first
  // value; a second subscription to that topic, made after start, reports
  // what it receives and in which order.
  final List<int> fromCallback = <int>[];
  bus.observe(_r).listen(fromCallback.add);
  bus.observe(_s).listen((int v) {
    if (v == 3) p.publish(_r, 30);
  });
  p.publish(_r, 20);
  bus.scheduler.triggerActions();
  print('replay subscriber, its own first values then a publish another '
      'subscriber made from its first value: $fromCallback');
  final List<int> events = <int>[];
  bus.observe(_e).listen(events.add);
  p.publish(_e, 7);
  print('event subscriber, at once: $events');
  bus.shutdown();
}

void p2() {
  print('== P2 a subscription made during bootstrap (G34 step 2)');
  final TestBus bus = TestBus(const BusConfig(devMode: false));
  final StateWriter<int> w =
      bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s);
  final List<int> got = <int>[];
  bus.observe(_s).listen(got.add);
  w.publish(5);
  bus.scheduler.triggerActions();
  print('before start, after triggerActions: $got');
  bus.start();
  print('start() returned: $got');
  bus.scheduler.triggerActions();
  print('after triggerActions: $got');
  bus.shutdown();
}

void p3() {
  print('== P3 a reader activated before its input writer (G34 step 1)');
  final TestBus bus = TestBus(const BusConfig(devMode: false));
  bus.activate(topology('reader', Scope.application,
      (TopologyBuilder b) => b.write(_y, b.read(_x).map(_times10))));
  bus.activate(topology('writer', Scope.application,
      (TopologyBuilder b) => b.write(_x, b.read(_s).map(_plus1))));
  bus.start();
  print('start() returned: x=${bus.getCurrentValue(_x)} '
      'y=${bus.getCurrentValue(_y)}; recorder: ${<String>[
    for (final RecordedEnvelope r in bus.recorder.envelopes)
      '${r.topic.name}=${r.envelope.payload}',
  ]}');
  bus.shutdown();
}

void p4() {
  print('== P4 cost of one delivery to three subscriptions and one read');
  final Bus bus = Bus(const BusConfig(devMode: false));
  bus.activate(topology('sink', Scope.application,
      (TopologyBuilder b) => b.write(_never, b.read(_s).filter(_negative))));
  bus.start();
  final StateWriter<int> w =
      bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s);
  var n = 0;
  for (var i = 0; i < 3; i++) {
    bus.observe(_s).listen((int _) => n++);
  }
  // The first values arrive in a root-zone microtask; publish after them.
  Future<void>.delayed(Duration.zero, () {
    const warm = 200000;
    const runs = 1000000;
    for (var i = 0; i < warm; i++) {
      w.publish(i + 2);
    }
    final Stopwatch sw = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      w.publish(warm + i + 2);
    }
    sw.stop();
    final double ns = sw.elapsedMicroseconds * 1000 / runs;
    print('ns per publish: ${ns.toStringAsFixed(0)} '
        '(subscriber calls: ${n == 3 * (warm + runs + 1) ? 'all' : n})');
    bus.shutdown();
  });
}

void main(List<String> args) {
  if (args.contains('--cost')) {
    p4();
    return;
  }
  p1();
  p2();
  p3();
}
