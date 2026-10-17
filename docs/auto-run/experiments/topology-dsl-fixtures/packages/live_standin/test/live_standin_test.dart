// Stand-in binding of topology-dsl@v1's live suite (experiment only): binds
// the conformance library by relative path, as a consumer's stand-in does
// (ADR-001 item 11), to the bus in lib/live_standin.dart.
import 'package:live_standin/live_standin.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

import '../../../hsdd/contract/fixture/topology-dsl/behavior/live_conformance.dart';

final class StandinHarness implements LiveTopologyHarness {
  final List<StandinRun> runs = <StandinRun>[];

  @override
  LiveRun start(List<Topology> topologies) {
    final run = StandinRun(StandinBus(VirtualScheduler()));
    for (final t in topologies) {
      run.activate(t);
    }
    runs.add(run);
    return run;
  }

  @override
  Future<void> settle() async {
    for (final r in runs) {
      await r.bus.scheduler.settle();
    }
  }
}

final class StandinRun implements LiveRun {
  StandinRun(this.bus);
  final StandinBus bus;
  final Map<Topology, Activation> _active = <Topology, Activation>{};

  @override
  final List<MessageEnvelope<Object?>> deliveries = <MessageEnvelope<Object?>>[];

  @override
  void publish<T>(Topic<T> topic, T value) =>
      bus.zone.run(() => bus.shellPublish(topic, value));

  @override
  List<MessageEnvelope<T>> watch<T>(Topic<T> topic) {
    final list = <MessageEnvelope<T>>[];
    bus.watch(topic, (MessageEnvelope<T> e) {
      list.add(e);
      deliveries.add(e);
    });
    return list;
  }

  @override
  T current<T>(StateTopic<T> topic) => bus.current(topic);

  @override
  void advance(Duration duration) => bus.scheduler.advanceTimeBy(duration);

  @override
  void activate(Topology topology) => _active[topology] = bus.activate(topology);

  @override
  void deactivate(Topology topology) => _active.remove(topology)!.deactivate();
}

void main() {
  for (final c in liveConformance) {
    test(c.name, () => c.body(StandinHarness()));
  }
}
