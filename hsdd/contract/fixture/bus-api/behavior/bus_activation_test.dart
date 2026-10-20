// Binding: runs topology-dsl@v2's live conformance suite against the live
// interpretation that Bus.activate performs in package:nidana_dart_runtime,
// under `dart test` (ADR-001 item 4: the binding lives with the contract
// whose Interface declares the implementation).
//
// Each run is a fresh TestBus (bus-testing@v2, package:nidana_dart_runtime/
// testing.dart). `start` activates the topologies it is given, which the
// suite declares APPLICATION-scoped, then calls start(), which connects them
// (bus-api@v2 G34); a topology the suite activates only after the start is
// MODULE-scoped, or an APPLICATION one activated again, whose
// LateApplicationActivation report the discarding sink drops (G22, G42).
// A watched list is a view of the TestBus's envelope recorder from the
// moment of the watch, filtered to the topic and read with the topic's own
// dedup policy, because observers do not see a Tracing.disabled topic
// (bus-api@v2 G30) and the suite watches one. The bus-testing@v2 names this
// binding uses are listed in bus-api@v2's ## Validation section; the replay
// tool reports it as PENDING until the package exists (ADR-001 item 9).
import 'dart:collection';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';
import 'package:test/test.dart';

import '../../topology-dsl/behavior/live_conformance.dart';

void _discard(BusDiagnostic diagnostic) {}

final class _Harness implements LiveTopologyHarness {
  final List<_Run> _runs = <_Run>[];

  @override
  LiveRun start(List<Topology> topologies) {
    final _Run run = _Run(TestBus(const BusConfig(diagnostics: _discard)));
    for (final Topology t in topologies) {
      run.activate(t);
    }
    run.bus.start();
    _runs.add(run);
    return run;
  }

  @override
  Future<void> settle() async {
    for (final _Run run in _runs) {
      await run.bus.scheduler.settle();
    }
  }
}

final class _Run implements LiveRun {
  _Run(this.bus);

  final TestBus bus;
  final Map<Topology, TopologyHandle> _handles = <Topology, TopologyHandle>{};
  final Map<String, Publisher> _owners = <String, Publisher>{};
  late final Publisher _events = bus.publisher(const ServiceSource('live-run'));
  final List<_Watch<Object?>> _watches = <_Watch<Object?>>[];

  @override
  void publish<T>(Topic<T> topic, T value) {
    switch (topic) {
      case StateTopic<T>():
        _owners
            .putIfAbsent(
                topic.name,
                () => bus.publisher(ServiceSource('live-run-${topic.name}'),
                    writes: <StateTopic<Object?>>{topic}))
            .writer(topic)
            .publish(value);
      case MultiWriterTopic<T>():
        _events.publish(topic, value);
    }
  }

  @override
  List<MessageEnvelope<T>> watch<T>(Topic<T> topic) {
    bus.observe(topic);
    final _Watch<T> w = _Watch<T>(
      this,
      topic,
      bus.recorder.envelopes.length,
      topic is StateTopic<T> && topic.dedup == Dedup.equality,
      topic is StateTopic<T> ? bus.getCurrentValue(topic) : null,
    );
    _watches.add(w);
    return w;
  }

  @override
  List<MessageEnvelope<Object?>> get deliveries {
    final List<Set<int>> accepted = <Set<int>>[
      for (final _Watch<Object?> w in _watches) w.accepted(),
    ];
    final List<RecordedEnvelope> all = bus.recorder.envelopes;
    return <MessageEnvelope<Object?>>[
      for (var i = 0; i < all.length; i++)
        for (final Set<int> a in accepted)
          if (a.contains(i)) all[i].envelope,
    ];
  }

  @override
  T current<T>(StateTopic<T> topic) => bus.getCurrentValue(topic);

  @override
  void advance(Duration duration) => bus.scheduler.advanceTimeBy(duration);

  @override
  void activate(Topology topology) => _handles[topology] = bus.activate(topology);

  @override
  void deactivate(Topology topology) => _handles.remove(topology)!.deactivate();
}

/// The envelopes delivered on one topic from the moment of the watch, as a
/// subscriber reading with the topic's own dedup policy receives them; the
/// value current at the watch is that subscriber's first, never appended.
final class _Watch<T> extends ListBase<MessageEnvelope<T>> {
  _Watch(this._run, this._topic, this._from, this._dedup, this._seed);

  final _Run _run;
  final Topic<T> _topic;
  final int _from;
  final bool _dedup;
  final T? _seed;

  Set<int> accepted() {
    final List<RecordedEnvelope> all = _run.bus.recorder.envelopes;
    final Set<int> out = <int>{};
    var has = _dedup;
    T? last = _seed;
    for (var i = _from; i < all.length; i++) {
      if (all[i].topic != _topic.ref) continue;
      final T payload = all[i].envelope.payload as T;
      if (_dedup && has && last == payload) continue;
      has = true;
      last = payload;
      out.add(i);
    }
    return out;
  }

  List<MessageEnvelope<T>> get _items {
    final List<RecordedEnvelope> all = _run.bus.recorder.envelopes;
    return <MessageEnvelope<T>>[
      for (final int i in accepted()) all[i].envelope as MessageEnvelope<T>,
    ];
  }

  @override
  int get length => _items.length;

  @override
  set length(int value) => throw UnsupportedError('a watched list is read-only');

  @override
  MessageEnvelope<T> operator [](int index) => _items[index];

  @override
  void operator []=(int index, MessageEnvelope<T> value) =>
      throw UnsupportedError('a watched list is read-only');
}

void main() {
  for (final c in liveConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
