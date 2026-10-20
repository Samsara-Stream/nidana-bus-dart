// chain_probe: what the stand-in runtime in place does when a write chain
// ends, and when a bootstrap activation connects. Run with `fvm dart run
// tool/chain_probe.dart` against each runtime (run.sh swaps them in).
//
// P1 a chain ends while a debounce timer of that chain is pending: how many
//    timers stay pending, how many PipelineTerminated reports are made, and
//    whether a function upstream of the error runs for a later value.
// P2 a shared stage: the chain that ends and the one that goes on.
// P3 a bootstrap activation: is its map called before start(), and is a
//    MODULE activation before start() accepted?
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const EventTopic<int> _in = EventTopic<int>(name: 'p.in');
const EventTopic<int> _inB = EventTopic<int>(name: 'p.in-b');
const EventTopic<int> _out = EventTopic<int>(name: 'p.out');
const EventTopic<int> _outB = EventTopic<int>(name: 'p.out-b');
const StateTopic<int> _level = StateTopic<int>(name: 'p.level', initial: 1);
const StateTopic<int> _derived = StateTopic<int>(name: 'p.derived', initial: 0);

void main() {
  // ------------------------------------------------------------------ P1
  {
    final List<BusDiagnostic> reports = <BusDiagnostic>[];
    final TestBus bus = TestBus(BusConfig(devMode: true, diagnostics: reports.add));
    int upstream = 0;
    bus.activate(topology('p1', Scope.application, (TopologyBuilder b) {
      b.write(
          _out,
          b.merge(<TopicStream<int>>[
            b.read(_in).map((int v) {
              upstream++;
              return v;
            }).debounce(const Duration(milliseconds: 100)),
            b.read(_inB).map((int v) => v == 0 ? throw StateError('chain') : v),
          ]));
    }));
    bus.start();
    final Publisher p = bus.publisher(const ServiceSource('probe'));
    p.publish(_in, 1);
    bus.scheduler.triggerActions();
    print('P1 pending timers with a debounce pending: ${bus.scheduler.pendingTimerCount}');
    p.publish(_inB, 0);
    bus.scheduler.triggerActions();
    print('P1 pending timers after the error ended the chain: ${bus.scheduler.pendingTimerCount}');
    p.publish(_in, 2);
    bus.scheduler.advanceTimeBy(const Duration(milliseconds: 200));
    print('P1 upstream map calls after a later value (1 means not called again): $upstream');
    print('P1 PipelineTerminated reports: ${reports.whereType<PipelineTerminated>().length}');
    bus.shutdown();
  }
  // ------------------------------------------------------------------ P2
  {
    final List<BusDiagnostic> reports = <BusDiagnostic>[];
    final TestBus bus = TestBus(BusConfig(devMode: true, diagnostics: reports.add));
    int shared = 0;
    int after = 0;
    bus.activate(topology('p2', Scope.application, (TopologyBuilder b) {
      final TopicStream<int> m = b.read(_in).map((int v) {
        shared++;
        return v;
      });
      b.write(
          _out,
          m.map((int v) {
            after++;
            return v;
          }).map((int v) => v == 2 ? throw StateError('chain') : v));
      b.write(_outB, m);
    }));
    bus.start();
    final Publisher p = bus.publisher(const ServiceSource('probe'));
    for (final int v in <int>[1, 2, 3]) {
      p.publish(_in, v);
      bus.scheduler.triggerActions();
    }
    print('P2 shared map calls: $shared; calls of the map only the ended chain had: $after; '
        'reports: ${reports.whereType<PipelineTerminated>().length}');
    bus.shutdown();
  }
  // ------------------------------------------------------------------ P3
  {
    final TestBus bus = TestBus(const BusConfig(diagnostics: _discard));
    int calls = 0;
    bus.activate(topology('p3', Scope.application, (TopologyBuilder b) {
      b.write(
          _derived,
          b.read(_level).map((int v) {
            calls++;
            return v * 10;
          }));
    }));
    bus.scheduler.triggerActions();
    print('P3 map calls of a bootstrap activation before start(): $calls');
    try {
      bus.activate(topology('p3-module', Scope.module, (TopologyBuilder b) {
        b.write(_out, b.read(_in));
      }));
      print('P3 a MODULE activation before start(): accepted');
    } on Object catch (e) {
      print('P3 a MODULE activation before start(): ${e.runtimeType}: $e');
    }
    bus.start();
    bus.scheduler.triggerActions();
    print('P3 map calls after start(): $calls; derived: ${bus.getCurrentValue(_derived)}');
    bus.shutdown();
  }
}

void _discard(BusDiagnostic d) {}
