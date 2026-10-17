// Conformance library for bus-api@v1 (ADR-001 item 4): the Bus Runtime
// Contract (Spec §3), lifecycle (Spec §7), observation (Spec §9), the error
// model (Spec §10.2) and runtime operations (Spec §11) as a bus delivers
// them. Its cases are values; a binding registers them with a test runner.
// It imports neither package:test nor package:flutter_test, and names no
// bus-testing@v1 type: a binding supplies buses on a virtual clock through
// BusApiHarness. The live semantics of each combinator are topology-dsl@v1's
// suite, bound in this directory by bus_activation_test.dart.
import 'dart:async';

import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

/// What a binding supplies.
abstract interface class BusApiHarness {
  /// A fresh bus built from [config], whose scheduler provider must be left
  /// unset: the binding gives the bus a virtual provider (Spec §3.6), so its
  /// clock moves only through [advance], and the microtasks and timers it
  /// schedules run only through [flush] and [advance]. Nothing is active on
  /// it and it is not started.
  Bus bus([BusConfig config = const BusConfig()]);

  /// Runs every microtask queued and every timer due on [bus]'s provider,
  /// synchronously, without moving its clock (Spec §3.6 triggerActions).
  void flush(Bus bus);

  /// Moves [bus]'s clock forward by [duration], running everything that
  /// falls due on the way, synchronously (Spec §3.6 advanceTimeBy).
  void advance(Bus bus, Duration duration);

  /// How many timers are pending on [bus]'s provider.
  int pendingTimers(Bus bus);

  /// Brings every bus of this harness to quiescence, including work that
  /// starts outside a bus zone.
  Future<void> settle();
}

// ------------------------------------------------------------ topics

const EventTopic<int> _e = EventTopic<int>(name: 'bus.e');
const EventTopic<int> _e2 = EventTopic<int>(name: 'bus.e-two');
const EventTopic<int> _out = EventTopic<int>(name: 'bus.out');
const EventTopic<int> _outB = EventTopic<int>(name: 'bus.out-b');
const StateTopic<int> _s = StateTopic<int>(name: 'bus.s', initial: 1);
const StateTopic<int> _s2 = StateTopic<int>(name: 'bus.s-two', initial: 0);
const StateTopic<int> _noDedup =
    StateTopic<int>(name: 'bus.no-dedup', initial: 0, dedup: Dedup.none);
const ReplayTopic<int> _r = ReplayTopic<int>(name: 'bus.r', bufferSize: 2);
const EventTopic<String> _secret =
    EventTopic<String>(name: 'bus.secret', sensitive: true);
const EventTopic<int> _untraced =
    EventTopic<int>(name: 'bus.untraced', tracing: Tracing.disabled);

// ------------------------------------------------------------ helpers

const ServiceSource _svc = ServiceSource('conformance');
const Duration _ms1 = Duration(milliseconds: 1);
const Duration _ms100 = Duration(milliseconds: 100);
const Duration _s1 = Duration(seconds: 1);
const Set<ObserverCapability> _all = <ObserverCapability>{
  ObserverCapability.observeAll,
  ObserverCapability.observeSensitive,
};

int _double(int v) => v * 2;
int _sum(int a, int b) => a + b;

Topology _t(String id, void Function(TopologyBuilder b) body,
        [Scope scope = Scope.module]) =>
    topology(id, scope, body);

/// Subscribes to [topic] and returns the list each delivered payload is
/// appended to.
List<T> _listen<T>(Bus bus, Topic<T> topic) {
  final List<T> got = <T>[];
  bus.observe(topic).listen(got.add);
  return got;
}

final class _Observer implements BusObserver {
  _Observer({
    this.capabilities = const <ObserverCapability>{ObserverCapability.observeAll},
    this.onCall,
  });

  @override
  final Set<ObserverCapability> capabilities;
  final void Function()? onCall;
  final List<({TopicRef topic, MessageEnvelope<Object?> envelope})> seen =
      <({TopicRef topic, MessageEnvelope<Object?> envelope})>[];
  ObserveContext? context;

  List<Object?> get payloads =>
      <Object?>[for (final s in seen) s.envelope.payload];

  List<String> get trace =>
      <String>[for (final s in seen) '${s.topic.name}:${s.envelope.payload}'];

  MessageEnvelope<Object?> on(Topic<Object?> topic) =>
      seen.firstWhere((s) => s.topic == topic.ref).envelope;

  @override
  void onPublish(TopicRef topic, MessageEnvelope<Object?> envelope,
      ObserveContext context) {
    seen.add((topic: topic, envelope: envelope));
    this.context = context;
    onCall?.call();
  }
}

final class _ActivationLog implements ActivationObserver {
  final List<String> activations = <String>[];

  @override
  Set<ObserverCapability> get capabilities =>
      const <ObserverCapability>{ObserverCapability.observeAll};

  @override
  void onPublish(TopicRef topic, MessageEnvelope<Object?> envelope,
      ObserveContext context) {}

  @override
  void onActivate(String topologyId, Scope scope, ObserveContext context) =>
      activations.add('$topologyId:${scope.name}');
}

typedef _Span = ({
  String name,
  Map<String, Object?> attributes,
  List<String> links,
});

final class _Context implements ObserveContext {
  final List<String> logs = <String>[];
  final List<_Span> spans = <_Span>[];
  int ended = 0;

  @override
  void log(LogLevel level, String message,
          {Map<String, Object?> fields = const <String, Object?>{}}) =>
      logs.add(message);

  @override
  void metric(String name, double value,
      {Map<String, String> tags = const <String, String>{}}) {}

  @override
  SpanHandle span(String name,
      {Map<String, Object?> attributes = const <String, Object?>{},
      List<String> links = const <String>[]}) {
    spans.add((name: name, attributes: attributes, links: links));
    return _SpanHandle(this);
  }
}

final class _SpanHandle implements SpanHandle {
  _SpanHandle(this._context);
  final _Context _context;

  @override
  void setAttribute(String key, Object? value) {}

  @override
  void end() => _context.ended++;
}

final class _ShellNote extends ShellDiagnostic {
  const _ShellNote();

  @override
  String get origin => 'conformance';
}

BusConfig _dev(List<BusDiagnostic> into,
        {int maxTopics = 1000,
        int maxReentrancyDepth = 10,
        Duration startupWindow = const Duration(seconds: 5)}) =>
    BusConfig(
      devMode: true,
      diagnostics: into.add,
      maxTopics: maxTopics,
      maxReentrancyDepth: maxReentrancyDepth,
      startupWindow: startupWindow,
    );

final List<ConformanceCase<BusApiHarness>> busApiConformance =
    <ConformanceCase<BusApiHarness>>[
  // ------------------------------------------------------------ G1
  (
    name: 'G1 two buses keep their own subjects, values, claims and observers, sharing only the topic values',
    body: (BusApiHarness h) async {
      final Bus a = h.bus();
      final Bus b = h.bus();
      a.start();
      b.start();
      final StateWriter<int> wa =
          a.publisher(_svc, writes: <StateTopic<Object?>>{_s2}).writer(_s2);
      final StateWriter<int> wb =
          b.publisher(_svc, writes: <StateTopic<Object?>>{_s2}).writer(_s2);
      final _Observer oa = _Observer();
      a.addObserver(oa);
      a.activate(_t('only-on-a', (TopologyBuilder t) => t.write(_out, t.read(_e))));
      wa.publish(5);
      wb.publish(7);
      expect(a.getCurrentValue(_s2), 5);
      expect(b.getCurrentValue(_s2), 7);
      expect(oa.payloads, <Object?>[5]);
      expect(b.toGraph().topologies, isEmpty);
    },
  ),
  // ------------------------------------------------------------ G3
  (
    name: 'G3 BusConfig defaults to the production provider, dev mode from assertions, the default sinks, the Specification limits, a 100 ms grace period and a 5 s startup window',
    body: (BusApiHarness h) async {
      const BusConfig c = BusConfig();
      expect(c.scheduler, isNull);
      expect(c.devMode, isNull);
      expect(c.diagnostics, isNull);
      expect(c.observeContext, isNull);
      expect(c.maxTopics, 1000);
      expect(c.maxActiveTopologies, 200);
      expect(c.maxObservers, 20);
      expect(c.maxReentrancyDepth, 10);
      expect(c.moduleScopeGracePeriod, _ms100);
      expect(c.startupWindow, const Duration(seconds: 5));
      expect(h.bus(c).config, same(c));
    },
  ),
  (
    name: 'G3 constructing a bus with a limit below one or a negative duration throws ArgumentError',
    body: (BusApiHarness h) async {
      for (final BusConfig c in <BusConfig>[
        const BusConfig(maxTopics: 0),
        const BusConfig(maxActiveTopologies: 0),
        const BusConfig(maxObservers: 0),
        const BusConfig(maxReentrancyDepth: 0),
        const BusConfig(moduleScopeGracePeriod: Duration(milliseconds: -1)),
        const BusConfig(startupWindow: Duration(seconds: -1)),
      ]) {
        expect(() => h.bus(c), throwsArgumentError);
      }
    },
  ),
  // ------------------------------------------------------------ G4
  (
    name: 'G4 dev mode is the configured value, or whether assertions are enabled when the config leaves it unset',
    body: (BusApiHarness h) async {
      var asserts = false;
      assert(asserts = true);
      expect(h.bus().devMode, asserts);
      expect(h.bus(const BusConfig(devMode: false)).devMode, isFalse);
      expect(h.bus(const BusConfig(devMode: true)).devMode, isTrue);
    },
  ),
  (
    name: 'G4 in dev mode a diagnostic is a value delivered to the configured sink, never thrown; outside dev mode none is delivered',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> on = <BusDiagnostic>[];
      final List<BusDiagnostic> off = <BusDiagnostic>[];
      final Bus a = h.bus(_dev(on));
      final Bus b = h.bus(BusConfig(devMode: false, diagnostics: off.add));
      for (final Bus bus in <Bus>[a, b]) {
        bus.start();
        bus.publish(_e, 1);
      }
      expect(on, <Object?>[isA<PublisherlessPublish>()]);
      expect(off, isEmpty);
    },
  ),
  (
    name: 'G4 a ShellDiagnostic another package defines reaches the sink through reportDiagnostic, in dev mode only',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> on = <BusDiagnostic>[];
      final List<BusDiagnostic> off = <BusDiagnostic>[];
      h.bus(_dev(on)).reportDiagnostic(const _ShellNote());
      h.bus(BusConfig(devMode: false, diagnostics: off.add))
          .reportDiagnostic(const _ShellNote());
      expect(on, <Object?>[isA<_ShellNote>()]);
      expect(off, isEmpty);
    },
  ),
  // ------------------------------------------------------------ G5
  (
    name: 'G5 an observed stream delivers in the bus zone, whatever zone listens to it or publishes',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final List<Object?> seen = <Object?>[];
      runZoned(
        () => bus.observe(_e).listen((int _) => seen.add(Zone.current[#conformance])),
        zoneValues: <Object?, Object?>{#conformance: 'listener'},
      );
      runZoned(
        () => bus.publisher(_svc).publish(_e, 1),
        zoneValues: <Object?, Object?>{#conformance: 'publisher'},
      );
      h.flush(bus);
      expect(seen, <Object?>[null]);
    },
  ),
  (
    name: 'G5 observers are called in the bus zone',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final List<Object?> seen = <Object?>[];
      bus.addObserver(
          _Observer(onCall: () => seen.add(Zone.current[#conformance])));
      runZoned(
        () => bus.publisher(_svc).publish(_e, 1),
        zoneValues: <Object?, Object?>{#conformance: 'publisher'},
      );
      expect(seen, <Object?>[null]);
    },
  ),
  (
    name: 'G5 a production-provider bus keeps the zone and the clock current where it was constructed',
    body: (BusApiHarness h) async {
      final Bus outer = h.bus();
      outer.start();
      final Publisher p = outer.publisher(_svc);
      Bus? constructed;
      // Constructed inside a delivery, so inside outer's virtual zone.
      outer.observe(_e).listen((int _) => constructed = Bus());
      p.publish(_e, 1);
      final Bus inner = constructed!;
      final DateTime t0 = outer.clock.now();
      expect(inner.clock.now(), t0);
      h.advance(outer, const Duration(seconds: 3));
      expect(inner.clock.now(), t0.add(const Duration(seconds: 3)));
      inner.start();
      final ModuleScope m = inner.module('timers', <Topology>[
        _t('timers-a', (TopologyBuilder b) => b.write(_out, b.read(_e))),
      ]);
      m.acquire().release();
      expect(m.isActive, isTrue);
      h.advance(outer, _ms100);
      expect(m.isActive, isFalse);
    },
  ),
  (
    name: 'G5 the bus clock is the provider clock and stamps every envelope at its publish',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      final Publisher p = bus.publisher(_svc);
      final DateTime t0 = bus.clock.now();
      p.publish(_e, 1);
      h.advance(bus, const Duration(seconds: 2));
      p.publish(_e, 2);
      expect(bus.clock.now(), t0.add(const Duration(seconds: 2)));
      expect(<DateTime>[for (final s in o.seen) s.envelope.timestamp],
          <DateTime>[t0, t0.add(const Duration(seconds: 2))]);
    },
  ),
  // ------------------------------------------------------------ G6
  (
    name: 'G6 a computed initial value is created once, by the first runtime access that creates the subject, and never by a claim',
    body: (BusApiHarness h) async {
      var calls = 0;
      final StateTopic<int> topic = StateTopic<int>.computed(
          name: 'bus.computed', initial: () => ++calls * 7);
      final Bus bus = h.bus();
      bus.publisher(_svc, writes: <StateTopic<Object?>>{topic});
      expect(calls, 0);
      expect(bus.getCurrentValue(topic), 7);
      bus.observe(topic);
      bus.getCurrentValue(topic);
      expect(calls, 1);
    },
  ),
  (
    name: 'G6 activation creates the subjects of the topics a topology reads and writes',
    body: (BusApiHarness h) async {
      var reads = 0;
      var writes = 0;
      final StateTopic<int> input = StateTopic<int>.computed(
          name: 'bus.computed-in', initial: () => ++reads);
      final StateTopic<int> output = StateTopic<int>.computed(
          name: 'bus.computed-out', initial: () => ++writes * 0);
      final Bus bus = h.bus();
      bus.activate(_t('computed',
          (TopologyBuilder b) => b.write(output, b.read(input).map((int v) => v + 1))));
      expect(<int>[reads, writes], <int>[1, 1]);
      bus.start();
      h.flush(bus);
      expect(bus.getCurrentValue(output), 2);
      expect(<int>[reads, writes], <int>[1, 1]);
    },
  ),
  // ------------------------------------------------------------ G7
  (
    name: 'G7 a name already registered with another variant or value type throws TopicCollision',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.observe(_e);
      expect(
          () => bus.getCurrentValue(const StateTopic<int>(name: 'bus.e', initial: 0)),
          throwsA(isA<TopicCollision>()
              .having((TopicCollision c) => c.registered, 'registered', _e)
              .having((TopicCollision c) => c.name, 'name', 'bus.e')));
      expect(() => bus.observe(const EventTopic<String>(name: 'bus.e')),
          throwsA(isA<TopicCollision>()));
    },
  ),
  (
    name: 'G7 equal declarations share one subject, and a declaration that differs in its sensitive flag collides',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final EventTopic<int> a = EventTopic<int>(name: 'bus.same');
      final EventTopic<int> b = EventTopic<int>(name: 'bus.same');
      expect(identical(a, b), isFalse);
      final List<int> got = _listen(bus, b);
      bus.publisher(_svc).publish(a, 3);
      expect(got, <int>[3]);
      expect(() => bus.observe(EventTopic<int>(name: 'bus.same', sensitive: true)),
          throwsA(isA<TopicCollision>()));
    },
  ),
  // ------------------------------------------------------------ G8
  (
    name: 'G8 getCurrentValue is the declared initial value on a fresh bus, then the last value delivered',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      expect(bus.getCurrentValue(_s), 1);
      final StateWriter<int> w =
          bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s);
      bus.start();
      w.publish(4);
      expect(bus.getCurrentValue(_s), 4);
    },
  ),
  (
    name: 'G8 getBufferedValues holds the most recent values up to the buffer size, oldest first, unmodifiable',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      expect(bus.getBufferedValues(_r), isEmpty);
      bus.start();
      final Publisher p = bus.publisher(_svc);
      for (final int v in <int>[1, 2, 3]) {
        p.publish(_r, v);
      }
      final List<int> buffered = bus.getBufferedValues(_r);
      expect(buffered, <int>[2, 3]);
      expect(() => buffered.add(4), throwsUnsupportedError);
    },
  ),
  (
    name: 'G8 getCurrentValue never throws for a topic without a subject, and after shutdown it answers with the last value held',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s).publish(9);
      bus.shutdown();
      expect(bus.getCurrentValue(_s), 9);
      expect(bus.getCurrentValue(_s2), 0);
      expect(bus.getBufferedValues(_r), isEmpty);
    },
  ),
  // ------------------------------------------------------------ G9
  (
    name: 'G9 removeTopic refuses a topic that has subscribers unless forced, and changes nothing when it refuses',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final List<int> got = _listen(bus, _e);
      expect(bus.removeTopic(_e), isFalse);
      bus.publisher(_svc).publish(_e, 1);
      expect(got, <int>[1]);
    },
  ),
  (
    name: 'G9 a forced removal ends every subscription with TopicRemoved and done before it returns, and the next access starts from the initial value',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s).publish(5);
      final List<Object> errors = <Object>[];
      var done = false;
      bus.observe(_s).listen((int _) {}, onError: errors.add, onDone: () => done = true);
      h.flush(bus);
      expect(bus.removeTopic(_s, force: true), isTrue);
      expect(errors, <Object?>[
        isA<TopicRemoved>().having((TopicRemoved e) => e.topic, 'topic', _s.ref),
      ]);
      expect(done, isTrue);
      expect(bus.getCurrentValue(_s), 1);
    },
  ),
  (
    name: 'G9 a forced removal delivers TopicRemoved to the reads of active topologies, which ends their sinks',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(_dev(d));
      bus.start();
      bus.activate(_t('reads-removed', (TopologyBuilder b) => b.write(_out, b.read(_e))));
      expect(bus.removeTopic(_e), isFalse);
      expect(bus.removeTopic(_e, force: true), isTrue);
      final PipelineTerminated t = d.whereType<PipelineTerminated>().single;
      expect(t.topologyId, 'reads-removed');
      expect(t.error, isA<TopicRemoved>());
    },
  ),
  (
    name: 'G9 removing a topic that has no subject, or a subject and no subscriber, succeeds',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      expect(bus.removeTopic(_e2), isTrue);
      bus.observe(_out);
      expect(bus.removeTopic(_out), isTrue);
    },
  ),
  (
    name: 'G9 removeTopic called during a delivery throws StateError',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      Object? error;
      bus.observe(_e).listen((int _) {
        try {
          bus.removeTopic(_e2);
        } catch (e) {
          error = e;
        }
      });
      bus.publisher(_svc).publish(_e, 1);
      expect(error, isA<StateError>());
    },
  ),
  // ------------------------------------------------------------ G10
  (
    name: 'G10 an activation beyond maxActiveTopologies or maxTopics throws BusLimitExceeded and activates nothing',
    body: (BusApiHarness h) async {
      final Bus a = h.bus(const BusConfig(maxActiveTopologies: 1));
      a.activate(_t('limit-a', (TopologyBuilder b) => b.write(_out, b.read(_e))));
      expect(
          () => a.activate(_t('limit-b', (TopologyBuilder b) => b.write(_outB, b.read(_e2)))),
          throwsA(isA<BusLimitExceeded>()
              .having((BusLimitExceeded e) => e.limit, 'limit', BusLimit.activeTopologies)
              .having((BusLimitExceeded e) => e.max, 'max', 1)));
      final Bus b = h.bus(const BusConfig(maxTopics: 3));
      b.activate(_t('limit-c', (TopologyBuilder t) => t.write(_out, t.read(_e))));
      expect(
          () => b.activate(_t('limit-d', (TopologyBuilder t) => t.write(_outB, t.read(_e2)))),
          throwsA(isA<BusLimitExceeded>()
              .having((BusLimitExceeded e) => e.limit, 'limit', BusLimit.topics)));
      expect(<String>[for (final d in b.toGraph().topologies) d.topologyId],
          <String>['limit-c']);
    },
  ),
  (
    name: 'G10 addObserver beyond maxObservers throws BusLimitExceeded',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus(const BusConfig(maxObservers: 1));
      bus.addObserver(_Observer());
      expect(() => bus.addObserver(_Observer()),
          throwsA(isA<BusLimitExceeded>()
              .having((BusLimitExceeded e) => e.limit, 'limit', BusLimit.observers)));
    },
  ),
  (
    name: 'G10 a subject created beyond maxTopics outside activation is created and reported in dev mode',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(_dev(d, maxTopics: 1));
      bus.getCurrentValue(_s);
      expect(bus.getCurrentValue(_s2), 0);
      expect(d, <Object?>[
        isA<TopicLimitExceeded>()
            .having((TopicLimitExceeded x) => x.topic, 'topic', _s2.ref)
            .having((TopicLimitExceeded x) => x.maxTopics, 'maxTopics', 1),
      ]);
    },
  ),
  // ------------------------------------------------------------ G11
  (
    name: 'G11 a publisher-less publish reaches an event or replay topic with the unknown source and is reported in dev mode',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(_dev(d));
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      bus.publish(_e, 1);
      bus.publish(_r, 2);
      expect(<MessageSource>[for (final s in o.seen) s.envelope.source],
          <MessageSource>[const UnknownSource(), const UnknownSource()]);
      expect(d, <Object?>[
        isA<PublisherlessPublish>().having((PublisherlessPublish x) => x.topic, 'topic', _e.ref),
        isA<PublisherlessPublish>().having((PublisherlessPublish x) => x.topic, 'topic', _r.ref),
      ]);
    },
  ),
  // ------------------------------------------------------------ G12
  (
    name: 'G12 a shell publish starts a new flow: fresh id and correlation, no causation or parents, the publisher source and the topic sensitive flag',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer(capabilities: _all);
      bus.addObserver(o);
      final Publisher p = bus.publisher(const PageSource('checkout/cart'));
      p.publish(_e, 1);
      p.publish(_e, 2);
      p.publish(_secret, 'pin');
      final List<MessageEnvelope<Object?>> e = <MessageEnvelope<Object?>>[
        for (final s in o.seen) s.envelope,
      ];
      expect(<String>{for (final x in e) x.id}, hasLength(3));
      expect(<String>{for (final x in e) x.correlationId}, hasLength(3));
      expect(<String?>[for (final x in e) x.causationId], <String?>[null, null, null]);
      expect(<List<String>>[for (final x in e) x.parentCorrelationIds],
          everyElement(isEmpty));
      expect(<MessageSource>{for (final x in e) x.source},
          <MessageSource>{const PageSource('checkout/cart')});
      expect(<bool>[for (final x in e) x.sensitive], <bool>[false, false, true]);
    },
  ),
  // ------------------------------------------------------------ G13
  (
    name: 'G13 every subscriber and observer of a topic receives its deliveries in one order, reentrant publishes included',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc);
      final _Observer o = _Observer();
      bus.addObserver(o);
      final List<int> s1 = <int>[];
      bus.observe(_e).listen((int v) {
        s1.add(v);
        if (v.isEven && v < 20) p.publish(_e, v + 101);
      });
      final List<int> s2 = _listen(bus, _e);
      final List<int> s3 = _listen(bus, _e);
      for (var i = 0; i < 10; i++) {
        p.publish(_e, i);
      }
      h.flush(bus);
      expect(s1, hasLength(15));
      expect(s2, s1);
      expect(s3, s1);
      expect(o.payloads, s1);
    },
  ),
  (
    name: 'G13 after start a publish made outside any delivery reaches the established subscribers before publish returns',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc, writes: <StateTopic<Object?>>{_s});
      final List<int> events = _listen(bus, _e);
      final List<int> states = _listen(bus, _s);
      h.flush(bus);
      p.publish(_e, 1);
      p.writer(_s).publish(2);
      expect(events, <int>[1]);
      expect(states, <int>[1, 2]);
    },
  ),
  // ------------------------------------------------------------ G14
  (
    name: 'G14 a publish made during a delivery is delivered after that delivery completes, in the next bus microtask, in the order made',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc);
      final List<String> log = <String>[];
      bus.observe(_e).listen((int v) {
        log.add('e1:$v');
        p.publish(_out, v * 10);
        p.publish(_outB, v * 100);
      });
      bus.observe(_e).listen((int v) => log.add('e2:$v'));
      bus.observe(_out).listen((int v) => log.add('out:$v'));
      bus.observe(_outB).listen((int v) => log.add('out-b:$v'));
      p.publish(_e, 1);
      expect(log, <String>['e1:1', 'e2:1']);
      h.flush(bus);
      expect(log, <String>['e1:1', 'e2:1', 'out:10', 'out-b:100']);
    },
  ),
  (
    name: 'G14 a subscriber that publishes to the topic it is receiving does not fail, and its publish follows the current delivery',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc);
      final List<String> log = <String>[];
      bus.observe(_e).listen((int v) {
        log.add('a:$v');
        if (v == 1) p.publish(_e, 2);
      });
      bus.observe(_e).listen((int v) => log.add('b:$v'));
      p.publish(_e, 1);
      h.flush(bus);
      expect(log, <String>['a:1', 'b:1', 'a:2', 'b:2']);
    },
  ),
  (
    name: 'G14 a topology publish a delivery causes is reentrant, and one value written by several sinks is delivered consecutively in sink declaration order',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final _Observer o = _Observer();
      bus.addObserver(o);
      bus.start();
      bus.activate(_t('fan-out', (TopologyBuilder b) {
        final TopicStream<int> x = b.read(_e).map((int v) => v);
        b.write(_outB, x);
        b.write(_out, x);
      }));
      h.flush(bus);
      final Publisher p = bus.publisher(_svc);
      p.publish(_e, 1);
      p.publish(_e, 2);
      expect(o.trace, <String>['bus.e:1', 'bus.e:2']);
      h.flush(bus);
      expect(o.trace, <String>[
        'bus.e:1', 'bus.e:2', 'bus.out-b:1', 'bus.out:1', 'bus.out-b:2', 'bus.out:2',
      ]);
    },
  ),
  // ------------------------------------------------------------ G15
  (
    name: 'G15 a reentrant chain deeper than maxReentrancyDepth is reported once in dev mode with its topics, and delivery goes on',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(_dev(d, maxReentrancyDepth: 2));
      bus.start();
      final Publisher p = bus.publisher(_svc);
      final List<int> got = <int>[];
      bus.observe(_e).listen((int v) {
        got.add(v);
        if (v < 5) p.publish(_e, v + 1);
      });
      p.publish(_e, 0);
      h.flush(bus);
      expect(got, <int>[0, 1, 2, 3, 4, 5]);
      expect(d, hasLength(1));
      expect((d.single as ReentrancyDepthExceeded).chain,
          List<TopicRef>.filled(4, _e.ref));
    },
  ),
  // ------------------------------------------------------------ G16
  (
    name: 'G16 a subscription to a state topic skips a value equal to the last it received; a Dedup.none topic delivers every publish',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p =
          bus.publisher(_svc, writes: <StateTopic<Object?>>{_s, _noDedup});
      final List<int> deduped = _listen(bus, _s);
      final List<int> every = _listen(bus, _noDedup);
      h.flush(bus);
      for (final int v in <int>[1, 2, 2, 3, 1]) {
        p.writer(_s).publish(v);
        p.writer(_noDedup).publish(v);
      }
      expect(deduped, <int>[1, 2, 3, 1]);
      expect(every, <int>[0, 1, 2, 2, 3, 1]);
    },
  ),
  (
    name: 'G16 observers, the current value and a Dedup.none read see a publish that dedup suppresses for default subscribers (decides OQ-R3)',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      final StateWriter<int> w =
          bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s);
      bus.activate(_t('dedup-none',
          (TopologyBuilder b) => b.write(_out, b.read(_s, dedup: Dedup.none))));
      final List<int> deduped = _listen(bus, _s);
      final List<int> outs = _listen(bus, _out);
      h.flush(bus);
      o.seen.clear();
      outs.clear();
      w.publish(1);
      h.flush(bus);
      expect(deduped, <int>[1]);
      expect(o.trace, <String>['bus.s:1', 'bus.out:1']);
      expect(outs, <int>[1]);
      expect(bus.getCurrentValue(_s), 1);
    },
  ),
  (
    name: 'G16 event and replay topics never deduplicate',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc);
      final List<int> events = _listen(bus, _e);
      final List<int> replays = _listen(bus, _r);
      h.flush(bus);
      for (var i = 0; i < 2; i++) {
        p.publish(_e, 1);
        p.publish(_r, 1);
      }
      expect(events, <int>[1, 1]);
      expect(replays, <int>[1, 1]);
    },
  ),
  // ------------------------------------------------------------ G17
  (
    name: 'G17 a state topic subscription receives the value current when it listened in the first bus microtask, then the values delivered meanwhile, in order (decides OQ-R1)',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final StateWriter<int> w =
          bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s);
      final List<int> got = _listen(bus, _s);
      expect(got, isEmpty);
      w.publish(2);
      expect(got, isEmpty);
      h.flush(bus);
      expect(got, <int>[1, 2]);
      w.publish(3);
      expect(got, <int>[1, 2, 3]);
    },
  ),
  (
    name: 'G17 a replay topic subscription receives its buffer first, in the first bus microtask; an event topic subscription receives only what is published after it listened, at once',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc);
      for (final int v in <int>[1, 2, 3]) {
        p.publish(_r, v);
      }
      p.publish(_e, 9);
      final List<int> replays = _listen(bus, _r);
      final List<int> events = _listen(bus, _e);
      p.publish(_e, 10);
      expect(events, <int>[10]);
      expect(replays, isEmpty);
      h.flush(bus);
      expect(replays, <int>[2, 3]);
      p.publish(_r, 4);
      expect(replays, <int>[2, 3, 4]);
    },
  ),
  // ------------------------------------------------------------ G18
  (
    name: 'G18 an observed stream is a broadcast stream, each listen a subscription with its own first value',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final StateWriter<int> w =
          bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s);
      final Stream<int> stream = bus.observe(_s);
      expect(stream.isBroadcast, isTrue);
      final List<int> a = <int>[];
      stream.listen(a.add);
      h.flush(bus);
      w.publish(2);
      final List<int> b = <int>[];
      stream.listen(b.add);
      h.flush(bus);
      expect(a, <int>[1, 2]);
      expect(b, <int>[2]);
    },
  ),
  (
    name: 'G18 a subscriber that throws does not stop delivery to the others, and its error reaches the zone the bus was built in',
    body: (BusApiHarness h) async {
      final List<Object> errors = <Object>[];
      late final Bus bus;
      runZonedGuarded(() => bus = h.bus(), (Object e, StackTrace s) => errors.add(e));
      bus.start();
      final Publisher p = bus.publisher(_svc);
      bus.observe(_e).listen((int v) => throw StateError('subscriber $v'));
      final List<int> got = _listen(bus, _e);
      p.publish(_e, 1);
      p.publish(_e, 2);
      h.flush(bus);
      expect(got, <int>[1, 2]);
      expect(errors, <Object?>[isA<StateError>(), isA<StateError>()]);
    },
  ),
  (
    name: 'G18 a cancelled subscription receives nothing more; shutdown ends every subscription before it returns, and observe then throws StateError',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc);
      final List<int> got = <int>[];
      final StreamSubscription<int> sub = bus.observe(_e).listen(got.add);
      var done = false;
      bus.observe(_e).listen((int _) {}, onDone: () => done = true);
      final Stream<int> early = bus.observe(_e);
      p.publish(_e, 1);
      unawaited(sub.cancel());
      p.publish(_e, 2);
      expect(got, <int>[1]);
      bus.shutdown();
      expect(done, isTrue);
      expect(() => bus.observe(_e), throwsStateError);
      final List<String> late = <String>[];
      early.listen((int v) => late.add('$v'), onDone: () => late.add('done'));
      h.flush(bus);
      expect(late, <String>['done']);
    },
  ),
  // ------------------------------------------------------------ G19
  (
    name: 'G19 a publisher takes a service, page or executor source; a topology or unknown source throws ArgumentError',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      for (final MessageSource s in <MessageSource>[
        const ServiceSource('a'),
        const PageSource('b'),
        const ExecutorSource('c'),
      ]) {
        expect(bus.publisher(s).source, s);
      }
      expect(() => bus.publisher(const TopologySource('t')), throwsArgumentError);
      expect(() => bus.publisher(const UnknownSource()), throwsArgumentError);
    },
  ),
  (
    name: 'G19 a publisher publishes to event and replay topics with its own source, and is bound to the application scope unless given another',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      final Publisher p = bus.publisher(const ExecutorSource('nav'));
      expect(p.scope, Scope.application);
      expect(p.writes, isEmpty);
      p.publish(_e, 1);
      p.publish(_r, 2);
      expect(<MessageSource>[for (final s in o.seen) s.envelope.source],
          <MessageSource>[const ExecutorSource('nav'), const ExecutorSource('nav')]);
      expect(bus.publisher(_svc, scope: Scope.page).scope, Scope.page);
    },
  ),
  // ------------------------------------------------------------ G20
  (
    name: 'G20 a claim on a state topic that a live publisher or an active topology owns is rejected with ClaimRejected naming the owner',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.publisher(const ServiceSource('first'), writes: <StateTopic<Object?>>{_s});
      expect(
          () => bus.publisher(const ServiceSource('second'),
              writes: <StateTopic<Object?>>{_s}),
          throwsA(isA<ClaimRejected>()
              .having((ClaimRejected e) => e.source, 'source', const ServiceSource('second'))
              .having((ClaimRejected e) => e.findings, 'findings', <Object?>[
            isA<WriterConflict>().having((WriterConflict c) => c.writers, 'writers',
                containsAll(<MessageSource>[
                  const ServiceSource('first'),
                  const ServiceSource('second'),
                ])),
          ])));
      bus.activate(_t('owner', (TopologyBuilder b) => b.write(_s2, b.read(_e))));
      expect(
          () => bus.publisher(const ServiceSource('third'),
              writes: <StateTopic<Object?>>{_s2}),
          throwsA(isA<ClaimRejected>().having((ClaimRejected e) => e.findings, 'findings',
              <Object?>[
            isA<WriterConflict>().having((WriterConflict c) => c.writers, 'writers',
                contains(const TopologySource('owner'))),
          ])));
    },
  ),
  (
    name: 'G20 a claim bound to a shorter scope than a topology that reads the topic is rejected with ClaimRejected',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.activate(_t('reader', (TopologyBuilder b) => b.write(_out, b.read(_s)),
          Scope.application));
      expect(
          () => bus.publisher(const PageSource('p'),
              writes: <StateTopic<Object?>>{_s}, scope: Scope.page),
          throwsA(isA<ClaimRejected>().having((ClaimRejected e) => e.findings,
              'findings', <Object?>[isA<ScopeViolation>()])));
    },
  ),
  (
    name: 'G20 a writer exists only for a claimed topic, is the same handle on every call, and publishes with the publisher source',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      final Publisher p = bus.publisher(const ServiceSource('connectivity'),
          writes: <StateTopic<Object?>>{_s});
      final StateWriter<int> w = p.writer(_s);
      expect(identical(p.writer(_s), w), isTrue);
      expect(w.topic, _s);
      expect(() => p.writer(_s2), throwsArgumentError);
      expect(p.writes, <StateTopic<Object?>>{_s});
      expect(() => p.writes.add(_s2), throwsUnsupportedError);
      w.publish(3);
      expect(bus.getCurrentValue(_s), 3);
      expect(o.seen.single.envelope.source, const ServiceSource('connectivity'));
    },
  ),
  // ------------------------------------------------------------ G21
  (
    name: 'G21 disposing a publisher releases its claims, and the publisher and its writers then throw StateError',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc, writes: <StateTopic<Object?>>{_s});
      final StateWriter<int> w = p.writer(_s);
      p.dispose();
      p.dispose();
      expect(p.isDisposed, isTrue);
      expect(() => w.publish(1), throwsStateError);
      expect(() => p.publish(_e, 1), throwsStateError);
      expect(
          bus.publisher(const ServiceSource('next'), writes: <StateTopic<Object?>>{_s})
              .writes,
          <StateTopic<Object?>>{_s});
    },
  ),
  (
    name: 'G21 a publish not yet delivered when its publisher is disposed is discarded',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final _Observer o = _Observer();
      bus.addObserver(o);
      final Publisher gone = bus.publisher(const ServiceSource('gone'));
      final Publisher kept = bus.publisher(const ServiceSource('kept'));
      gone.publish(_e, 1);
      kept.publish(_e, 2);
      gone.dispose();
      bus.start();
      expect(o.payloads, <Object?>[2]);
      final Publisher inner = bus.publisher(const ServiceSource('inner'));
      bus.observe(_e2).listen((int _) {
        inner.publish(_out, 1);
        inner.dispose();
      });
      kept.publish(_e2, 0);
      h.flush(bus);
      expect(o.trace, <String>['bus.e:2', 'bus.e-two:0']);
    },
  ),
  (
    name: 'G21 deactivating a topology releases its writes, so another claimant can take them',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final TopologyHandle handle =
          bus.activate(_t('releases', (TopologyBuilder b) => b.write(_s2, b.read(_e))));
      expect(() => bus.publisher(_svc, writes: <StateTopic<Object?>>{_s2}),
          throwsA(isA<ClaimRejected>()));
      handle.deactivate();
      expect(bus.publisher(_svc, writes: <StateTopic<Object?>>{_s2}).writes,
          <StateTopic<Object?>>{_s2});
    },
  ),
  // ------------------------------------------------------------ G22
  (
    name: 'G22 activation interprets the topology, and its sinks publish on the bus with the topology source, observed like any publish',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      bus.activate(_t('doubles',
          (TopologyBuilder b) => b.write(_out, b.read(_e).map(_double))));
      final List<int> got = _listen(bus, _out);
      bus.publisher(_svc).publish(_e, 21);
      h.flush(bus);
      expect(got, <int>[42]);
      expect(o.on(_out).source, const TopologySource('doubles'));
      expect(o.on(_out).causationId, o.on(_e).id);
    },
  ),
  (
    name: 'G22 the outputs of an activation connection are delivered once the bus microtasks queued by activate have run',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      bus.publisher(_svc, writes: <StateTopic<Object?>>{_s}).writer(_s).publish(4);
      bus.activate(_t('connect',
          (TopologyBuilder b) => b.write(_s2, b.read(_s).map((int v) => v + 1))));
      h.flush(bus);
      expect(bus.getCurrentValue(_s2), 5);
    },
  ),
  (
    name: 'G22 an APPLICATION topology activated after start is reported in dev mode; one activated before start is not',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(_dev(d));
      bus.activate(_t('early', (TopologyBuilder b) => b.write(_out, b.read(_e)),
          Scope.application));
      bus.start();
      bus.activate(_t('late', (TopologyBuilder b) => b.write(_outB, b.read(_e2)),
          Scope.application));
      bus.activate(_t('module-late', (TopologyBuilder b) => b.write(_s2, b.read(_e2))));
      expect(d, <Object?>[
        isA<LateApplicationActivation>()
            .having((LateApplicationActivation x) => x.topologyId, 'topologyId', 'late'),
      ]);
    },
  ),
  // ------------------------------------------------------------ G23
  (
    name: 'G23 activating an equal definition under an active id returns the same handle, running declare once more for the check',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      var runs = 0;
      Topology make() => _t('same', (TopologyBuilder b) {
            runs++;
            b.write(_out, b.read(_e).map(_double));
          });
      final TopologyHandle first = bus.activate(make());
      final TopologyHandle second = bus.activate(make());
      expect(identical(first, second), isTrue);
      expect(runs, 2);
      bus.start();
      final List<int> got = _listen(bus, _out);
      bus.publisher(_svc).publish(_e, 1);
      h.flush(bus);
      expect(got, <int>[2]);
    },
  ),
  (
    name: 'G23 activating a different definition or scope under an active id throws TopologyConflict',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.activate(_t('clash', (TopologyBuilder b) => b.write(_out, b.read(_e))));
      expect(() => bus.activate(_t('clash', (TopologyBuilder b) => b.write(_outB, b.read(_e)))),
          throwsA(isA<TopologyConflict>()
              .having((TopologyConflict e) => e.topologyId, 'topologyId', 'clash')));
      expect(
          () => bus.activate(
              _t('clash', (TopologyBuilder b) => b.write(_out, b.read(_e)), Scope.page)),
          throwsA(isA<TopologyConflict>()));
    },
  ),
  (
    name: 'G23 after deactivation the same topology activates again with a fresh handle',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final Topology t = _t('again', (TopologyBuilder b) => b.write(_out, b.read(_e)));
      final TopologyHandle a = bus.activate(t);
      a.deactivate();
      final TopologyHandle b = bus.activate(t);
      expect(identical(a, b), isFalse);
      expect(<bool>[a.isActive, b.isActive], <bool>[false, true]);
      expect(b.topologyId, 'again');
      expect(b.scope, Scope.module);
      expect(b.definition, t.buildDefinition());
    },
  ),
  (
    name: 'G23 two declarations with equal definitions count as one, even when they differ where a definition does not look',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final TopologyHandle a = bus.activate(_t('seeded',
          (TopologyBuilder b) => b.write(_out, b.read(_e).scan(0, _sum))));
      final TopologyHandle b = bus.activate(_t('seeded',
          (TopologyBuilder b) => b.write(_out, b.read(_e).scan(100, _sum))));
      expect(identical(a, b), isTrue);
    },
  ),
  // ------------------------------------------------------------ G24
  (
    name: 'G24 an activation that would close an inter-topology cycle is rejected with ActivationRejected, and nothing of it is activated',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.activate(_t('ping', (TopologyBuilder b) => b.write(_outB, b.read(_out))));
      expect(() => bus.activate(_t('pong', (TopologyBuilder b) => b.write(_out, b.read(_outB)))),
          throwsA(isA<ActivationRejected>()
              .having((ActivationRejected e) => e.topologyId, 'topologyId', 'pong')
              .having((ActivationRejected e) => e.findings, 'findings',
                  <Object?>[isA<TopologyCycle>()])));
      expect(<String>[for (final d in bus.toGraph().topologies) d.topologyId],
          <String>['ping']);
    },
  ),
  (
    name: 'G24 a second writer of a state topic is rejected at activation, whether the owner is a topology or a claim',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.activate(_t('w1', (TopologyBuilder b) => b.write(_s2, b.read(_e))));
      expect(() => bus.activate(_t('w2', (TopologyBuilder b) => b.write(_s2, b.read(_e2)))),
          throwsA(isA<ActivationRejected>().having((ActivationRejected e) => e.findings,
              'findings', <Object?>[isA<WriterConflict>()])));
      bus.publisher(_svc, writes: <StateTopic<Object?>>{_s});
      expect(() => bus.activate(_t('w3', (TopologyBuilder b) => b.write(_s, b.read(_e2)))),
          throwsA(isA<ActivationRejected>().having((ActivationRejected e) => e.findings,
              'findings', <Object?>[isA<WriterConflict>()])));
    },
  ),
  (
    name: 'G24 a state topic owner with a shorter scope than a topology reading it is rejected at activation',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.activate(_t('page-owner', (TopologyBuilder b) => b.write(_s2, b.read(_e)),
          Scope.page));
      expect(
          () => bus.activate(_t('app-reader',
              (TopologyBuilder b) => b.write(_out, b.read(_s2)), Scope.application)),
          throwsA(isA<ActivationRejected>().having((ActivationRejected e) => e.findings,
              'findings', <Object?>[isA<ScopeViolation>()])));
    },
  ),
  (
    name: 'G24 a topology reading what it writes through no state-bearing stage is rejected at activation, and one mediated by scan is not',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      expect(
          () => bus.activate(_t('loop',
              (TopologyBuilder b) => b.write(_out, b.read(_out).map((int v) => v + 1)))),
          throwsA(isA<ActivationRejected>().having((ActivationRejected e) => e.findings,
              'findings', <Object?>[isA<SelfReference>()])));
      expect(
          bus
              .activate(_t('mediated',
                  (TopologyBuilder b) => b.write(_outB, b.read(_outB).scan(0, _sum))))
              .isActive,
          isTrue);
    },
  ),
  // ------------------------------------------------------------ G25
  (
    name: 'G25 deactivation is synchronous and idempotent, cancels the pipeline and its timers at once, and discards its publishes not yet delivered',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      final TopologyHandle mapped = bus.activate(
          _t('gone', (TopologyBuilder b) => b.write(_out, b.read(_e).map((int v) => v))));
      final TopologyHandle timed = bus.activate(_t('timed',
          (TopologyBuilder b) => b.write(_outB, b.read(_e2).debounce(_s1))));
      h.flush(bus);
      final Publisher p = bus.publisher(_svc);
      p.publish(_e, 1);
      p.publish(_e2, 1);
      expect(h.pendingTimers(bus), 1);
      mapped.deactivate();
      mapped.deactivate();
      timed.deactivate();
      expect(<bool>[mapped.isActive, timed.isActive], <bool>[false, false]);
      expect(h.pendingTimers(bus), 0);
      h.flush(bus);
      p.publish(_e, 2);
      h.advance(bus, _s1 * 2);
      expect(o.trace, <String>['bus.e:1', 'bus.e-two:1', 'bus.e:2']);
    },
  ),
  // ------------------------------------------------------------ G26
  (
    name: 'G26 a pipeline an error ends is reported in dev mode with its topology, sink and error, and is not restarted',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(_dev(d));
      bus.start();
      final List<int> got = _listen(bus, _out);
      bus.activate(_t('fragile', (TopologyBuilder b) => b.write(
          _out, b.read(_e).map((int v) => v == 2 ? throw StateError('two') : v))));
      final Publisher p = bus.publisher(_svc);
      for (final int v in <int>[1, 2, 3]) {
        p.publish(_e, v);
        h.flush(bus);
      }
      expect(got, <int>[1]);
      final PipelineTerminated t = d.whereType<PipelineTerminated>().single;
      expect(t.topologyId, 'fragile');
      expect(t.sink, _out.ref);
      expect(t.error, isA<StateError>());
    },
  ),
  // ------------------------------------------------------------ G27
  (
    name: 'G27 module returns the one scope declared under an id, rejects another declaration under it, and takes module-scoped topologies only',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final Topology a = _t('m-a', (TopologyBuilder b) => b.write(_out, b.read(_e)));
      final Topology c = _t('m-c', (TopologyBuilder b) => b.write(_outB, b.read(_e2)));
      final ModuleScope m = bus.module('checkout', <Topology>[a]);
      expect(identical(bus.module('checkout', <Topology>[a]), m), isTrue);
      expect(m.moduleId, 'checkout');
      expect(m.topologies, <Topology>[a]);
      expect(m.gracePeriod, _ms100);
      expect(<Object>[m.references, m.isActive], <Object>[0, false]);
      expect(() => bus.module('checkout', <Topology>[a], gracePeriod: Duration.zero),
          throwsArgumentError);
      expect(() => bus.module('checkout', <Topology>[a, c]), throwsArgumentError);
      expect(
          () => bus.module('pages', <Topology>[
                _t('p', (TopologyBuilder b) => b.write(_out, b.read(_e)), Scope.page),
              ]),
          throwsArgumentError);
      expect(bus.module('slow', <Topology>[c], gracePeriod: _s1).gracePeriod, _s1);
    },
  ),
  // ------------------------------------------------------------ G28
  (
    name: 'G28 the first reference activates the module topologies in order, and balanced references never tear them down',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final ModuleScope m = bus.module('mod', <Topology>[
        _t('mod-a', (TopologyBuilder b) => b.write(_out, b.read(_e))),
        _t('mod-b', (TopologyBuilder b) => b.write(_outB, b.read(_e2))),
      ]);
      final ModuleReference r1 = m.acquire();
      expect(<Object>[m.isActive, m.references], <Object>[true, 1]);
      expect(<String>[for (final d in bus.toGraph().topologies) d.topologyId],
          <String>['mod-a', 'mod-b']);
      final ModuleReference r2 = m.acquire();
      r1.release();
      h.advance(bus, _s1);
      expect(<Object>[m.isActive, m.references], <Object>[true, 1]);
      expect(r2.scope, same(m));
    },
  ),
  (
    name: 'G28 the last release starts the grace period; a reference taken before it ends keeps the topologies, and its end deactivates them',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final ModuleScope m = bus.module('grace', <Topology>[
        _t('grace-a', (TopologyBuilder b) => b.write(_out, b.read(_e))),
      ]);
      m.acquire().release();
      h.advance(bus, _ms100 - _ms1);
      expect(m.isActive, isTrue);
      final ModuleReference again = m.acquire();
      h.advance(bus, _s1);
      expect(m.isActive, isTrue);
      again.release();
      h.advance(bus, _ms100 - _ms1);
      expect(m.isActive, isTrue);
      h.advance(bus, _ms1);
      expect(m.isActive, isFalse);
      expect(bus.toGraph().topologies, isEmpty);
    },
  ),
  (
    name: 'G28 with a zero grace period the last release tears the module down synchronously, with no timer',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final ModuleScope m = bus.module('instant', <Topology>[
        _t('instant-a', (TopologyBuilder b) => b.write(_out, b.read(_e))),
      ], gracePeriod: Duration.zero);
      m.acquire().release();
      expect(m.isActive, isFalse);
      expect(h.pendingTimers(bus), 0);
    },
  ),
  (
    name: 'G28 releasing one reference twice counts once',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final ModuleScope m = bus.module('twice', <Topology>[
        _t('twice-a', (TopologyBuilder b) => b.write(_out, b.read(_e))),
      ]);
      final ModuleReference r1 = m.acquire();
      m.acquire();
      r1.release();
      r1.release();
      expect(r1.isReleased, isTrue);
      expect(m.references, 1);
    },
  ),
  (
    name: 'G28 re-entering a module after its teardown activates its topologies again, and their state resumes',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final Publisher p = bus.publisher(_svc);
      final ModuleScope m = bus.module('resume', <Topology>[
        _t('resume-r', (TopologyBuilder b) => b.reduceInto(_s2, b.read(_e), _sum)),
      ], gracePeriod: Duration.zero);
      ModuleReference r = m.acquire();
      p.publish(_e, 5);
      h.flush(bus);
      r.release();
      expect(<Object>[m.isActive, bus.getCurrentValue(_s2)], <Object>[false, 5]);
      r = m.acquire();
      p.publish(_e, 1);
      h.flush(bus);
      expect(bus.getCurrentValue(_s2), 6);
    },
  ),
  (
    name: 'G28 a reference fails as a whole when one of the module topologies cannot activate',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.activate(_t('blocker', (TopologyBuilder b) => b.write(_s2, b.read(_e2))));
      final ModuleScope m = bus.module('blocked', <Topology>[
        _t('blocked-a', (TopologyBuilder b) => b.write(_out, b.read(_e))),
        _t('blocked-b', (TopologyBuilder b) => b.write(_s2, b.read(_e))),
      ]);
      expect(m.acquire, throwsA(isA<ActivationRejected>()));
      expect(<Object>[m.references, m.isActive], <Object>[0, false]);
      expect(<String>[for (final d in bus.toGraph().topologies) d.topologyId],
          <String>['blocker']);
    },
  ),
  // ------------------------------------------------------------ G29
  (
    name: 'G29 observers are called in registration order, before any subscriber, with the topic reference, the envelope and the configured ObserveContext',
    body: (BusApiHarness h) async {
      final _Context context = _Context();
      final Bus bus = h.bus(BusConfig(observeContext: context));
      bus.start();
      final List<String> log = <String>[];
      final _Observer o1 = _Observer(onCall: () => log.add('o1'));
      final _Observer o2 = _Observer(onCall: () => log.add('o2'));
      bus.observe(_e).listen((int _) => log.add('subscriber'));
      bus.addObserver(o1);
      bus.addObserver(o2);
      bus.publisher(_svc).publish(_e, 1);
      expect(log, <String>['o1', 'o2', 'subscriber']);
      expect(o1.seen.single.topic, _e.ref);
      expect(o1.seen.single.envelope.payload, 1);
      expect(o1.context, same(context));
    },
  ),
  (
    name: 'G29 a removed observer is no longer called, and adding the same observer twice throws ArgumentError',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      expect(() => bus.addObserver(o), throwsArgumentError);
      expect(bus.removeObserver(o), isTrue);
      expect(bus.removeObserver(o), isFalse);
      bus.publisher(_svc).publish(_e, 1);
      expect(o.seen, isEmpty);
    },
  ),
  // ------------------------------------------------------------ G30
  (
    name: 'G30 an observer without observeSensitive never receives a sensitive envelope, and one with it does',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer plain = _Observer();
      final _Observer granted = _Observer(capabilities: _all);
      final _Observer sensitiveOnly = _Observer(
          capabilities: const <ObserverCapability>{ObserverCapability.observeSensitive});
      for (final _Observer o in <_Observer>[plain, granted, sensitiveOnly]) {
        bus.addObserver(o);
      }
      final Publisher p = bus.publisher(_svc);
      p.publish(_secret, 'pin');
      p.publish(_e, 1);
      expect(plain.payloads, <Object?>[1]);
      expect(granted.payloads, <Object?>['pin', 1]);
      expect(sensitiveOnly.payloads, <Object?>['pin']);
    },
  ),
  (
    name: 'G30 no observer receives an envelope of a Tracing.disabled topic, while its subscribers receive its values',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer(capabilities: _all);
      bus.addObserver(o);
      final List<int> got = _listen(bus, _untraced);
      bus.publisher(_svc).publish(_untraced, 3);
      expect(o.seen, isEmpty);
      expect(got, <int>[3]);
    },
  ),
  // ------------------------------------------------------------ G31
  (
    name: 'G31 an observer that throws is reported in dev mode, and delivery to later observers and subscribers goes on',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(_dev(d));
      bus.start();
      final _Observer bad = _Observer(onCall: () => throw StateError('observer'));
      final _Observer good = _Observer();
      bus.addObserver(bad);
      bus.addObserver(good);
      final List<int> got = _listen(bus, _e);
      bus.publisher(_svc).publish(_e, 1);
      expect(good.payloads, <Object?>[1]);
      expect(got, <int>[1]);
      final ObserverThrew t = d.whereType<ObserverThrew>().single;
      expect(t.observer, same(bad));
      expect(t.topic, _e.ref);
      expect(t.error, isA<StateError>());
    },
  ),
  // ------------------------------------------------------------ G32
  (
    name: 'G32 an ActivationObserver is told of each new activation with its id and scope, and not of a repeat that returns the same handle',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final _ActivationLog a = _ActivationLog();
      bus.addObserver(a);
      final Topology t = _t('told', (TopologyBuilder b) => b.write(_out, b.read(_e)));
      bus.activate(t);
      bus.activate(t);
      bus.activate(_t('told-page', (TopologyBuilder b) => b.write(_outB, b.read(_e2)),
          Scope.page));
      expect(a.activations, <String>['told:module', 'told-page:page']);
    },
  ),
  // ------------------------------------------------------------ G33
  (
    name: 'G33 the telemetry observer opens and ends one span per publish, named after the topic, with the envelope attributes and a link to its cause',
    body: (BusApiHarness h) async {
      final _Context context = _Context();
      final Bus bus = h.bus(BusConfig(observeContext: context));
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(TelemetryObserver());
      bus.addObserver(o);
      bus.activate(_t('tele', (TopologyBuilder b) => b.write(_out, b.read(_e).map(_double))));
      h.flush(bus);
      context.spans.clear();
      context.ended = 0;
      bus.publisher(const ServiceSource('tele')).publish(_e, 1);
      h.flush(bus);
      final MessageEnvelope<Object?> root = o.on(_e);
      final MessageEnvelope<Object?> derived = o.on(_out);
      expect(<String>[for (final s in context.spans) s.name], <String>['bus.e', 'bus.out']);
      expect(context.spans[0].attributes, <String, Object?>{
        'nidana.id': root.id,
        'nidana.correlation_id': root.correlationId,
        'nidana.source': 'service:tele',
        'nidana.payload_type': 'int',
      });
      expect(context.spans[1].attributes, <String, Object?>{
        'nidana.id': derived.id,
        'nidana.correlation_id': derived.correlationId,
        'nidana.causation_id': root.id,
        'nidana.source': 'topology:tele',
        'nidana.payload_type': 'int',
      });
      expect(context.spans[0].links, isEmpty);
      expect(context.spans[1].links, <String>[root.id]);
      expect(context.ended, 2);
    },
  ),
  (
    name: 'G33 the telemetry observer marks a sensitive envelope, records no payload, and sees sensitive topics only when granted',
    body: (BusApiHarness h) async {
      final _Context granted = _Context();
      final _Context plain = _Context();
      for (final (BusObserver, _Context) setup in <(BusObserver, _Context)>[
        (TelemetryObserver(capabilities: _all), granted),
        (TelemetryObserver(), plain),
      ]) {
        final Bus bus = h.bus(BusConfig(observeContext: setup.$2));
        bus.start();
        bus.addObserver(setup.$1);
        bus.publisher(_svc).publish(_secret, 'pin-1234');
      }
      final Map<String, Object?> a = granted.spans.single.attributes;
      expect(a['nidana.sensitive'], isTrue);
      expect(a['nidana.payload_type'], 'String');
      expect(a.values, isNot(contains('pin-1234')));
      expect(plain.spans, isEmpty);
    },
  ),
  (
    name: 'G33 the telemetry observer opens and ends a span for each new activation, with its topology id and scope',
    body: (BusApiHarness h) async {
      final _Context context = _Context();
      final Bus bus = h.bus(BusConfig(observeContext: context));
      bus.addObserver(TelemetryObserver());
      bus.activate(_t('spanned', (TopologyBuilder b) => b.write(_out, b.read(_e)),
          Scope.page));
      expect(context.spans.single.name, 'nidana.activation');
      expect(context.spans.single.attributes, <String, Object?>{
        'nidana.topology_id': 'spanned',
        'nidana.scope': 'page',
      });
      expect(context.ended, 1);
    },
  ),
  // ------------------------------------------------------------ G34
  (
    name: 'G34 before start every publish is queued, unseen by subscribers, observers and current values, and start delivers the queue in publication order',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final _Observer o = _Observer();
      bus.addObserver(o);
      final List<int> got = _listen(bus, _e);
      final Publisher p = bus.publisher(_svc, writes: <StateTopic<Object?>>{_s});
      p.publish(_e, 1);
      p.writer(_s).publish(5);
      p.publish(_e, 2);
      p.publish(_r, 3);
      h.flush(bus);
      expect(bus.lifecycle, BusLifecycle.bootstrapping);
      expect(<Object>[got, o.seen], <Object>[isEmpty, isEmpty]);
      expect(bus.getCurrentValue(_s), 1);
      expect(bus.getBufferedValues(_r), isEmpty);
      bus.start();
      expect(bus.lifecycle, BusLifecycle.running);
      expect(o.payloads, <Object?>[1, 5, 2, 3]);
      expect(got, <int>[1, 2]);
      expect(bus.getCurrentValue(_s), 5);
    },
  ),
  (
    name: 'G34 topology publishes before start are queued too, so the order of the activations before start does not change what is delivered',
    body: (BusApiHarness h) async {
      List<String> run(bool readerFirst) {
        final Bus bus = h.bus();
        final _Observer o = _Observer();
        bus.addObserver(o);
        final Topology writer = _t('app-writer',
            (TopologyBuilder b) => b.write(_s2, b.read(_e).map((int v) => v)),
            Scope.application);
        final Topology reader = _t('app-reader',
            (TopologyBuilder b) => b.write(_out, b.read(_s2).map((int v) => v * 10)),
            Scope.application);
        final Publisher p = bus.publisher(_svc);
        bus.activate(readerFirst ? reader : writer);
        p.publish(_e, 7);
        bus.activate(readerFirst ? writer : reader);
        h.flush(bus);
        bus.start();
        h.flush(bus);
        return o.trace;
      }

      expect(run(true), run(false));
      expect(run(true), contains('bus.out:70'));
    },
  ),
  (
    name: 'G34 start is idempotent, and after it a publish is delivered at once',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      bus.start();
      expect(bus.lifecycle, BusLifecycle.running);
      final List<int> got = _listen(bus, _e);
      bus.publisher(_svc).publish(_e, 1);
      expect(got, <int>[1]);
    },
  ),
  // ------------------------------------------------------------ G35
  (
    name: 'G35 a publish queued without start within the startup window is reported once in dev mode, and start cancels the window',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus late = h.bus(_dev(d, startupWindow: const Duration(seconds: 2)));
      final Publisher p = late.publisher(_svc);
      p.publish(_e, 1);
      p.publish(_e, 2);
      h.advance(late, const Duration(milliseconds: 1999));
      expect(d, isEmpty);
      h.advance(late, _ms1);
      expect(d, <Object?>[
        isA<StartNotCalled>()
            .having((StartNotCalled x) => x.queued, 'queued', 2)
            .having((StartNotCalled x) => x.window, 'window', const Duration(seconds: 2)),
      ]);
      h.advance(late, const Duration(seconds: 10));
      expect(d, hasLength(1));
      final List<BusDiagnostic> d2 = <BusDiagnostic>[];
      final Bus started = h.bus(_dev(d2));
      started.publisher(_svc).publish(_e, 1);
      h.advance(started, _s1);
      started.start();
      h.advance(started, const Duration(seconds: 10));
      expect(d2, isEmpty);
      expect(h.pendingTimers(started), 0);
    },
  ),
  // ------------------------------------------------------------ G36
  (
    name: 'G36 shutdown delivers the pending reentrant publishes, then deactivates every topology and module, disposes every publisher and leaves no timer pending',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      final Publisher p = bus.publisher(_svc);
      final Publisher claimer =
          bus.publisher(const ServiceSource('claims'), writes: <StateTopic<Object?>>{_s});
      final TopologyHandle handle = bus.activate(
          _t('down-a', (TopologyBuilder b) => b.write(_out, b.read(_e).debounce(_s1))));
      final ModuleScope m = bus.module('down', <Topology>[
        _t('down-m', (TopologyBuilder b) => b.write(_outB, b.read(_e2))),
      ]);
      m.acquire().release();
      bus.observe(_e).listen((int v) => p.publish(_e2, v));
      h.flush(bus);
      p.publish(_e, 1);
      expect(h.pendingTimers(bus), greaterThan(0));
      bus.shutdown();
      expect(o.trace, contains('bus.e-two:1'));
      expect(bus.lifecycle, BusLifecycle.shutDown);
      expect(<bool>[handle.isActive, m.isActive], <bool>[false, false]);
      expect(<bool>[p.isDisposed, claimer.isDisposed], <bool>[true, true]);
      expect(h.pendingTimers(bus), 0);
      expect(bus.toGraph(), TopologyGraph());
    },
  ),
  (
    name: 'G36 after shutdown every new operation throws StateError, while deactivate, release, dispose and shutdown itself do nothing',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final TopologyHandle handle =
          bus.activate(_t('after', (TopologyBuilder b) => b.write(_out, b.read(_e))));
      final ModuleReference r = bus.module('after-m', <Topology>[
        _t('after-m-a', (TopologyBuilder b) => b.write(_outB, b.read(_e2))),
      ]).acquire();
      final Publisher p = bus.publisher(_svc);
      bus.start();
      bus.shutdown();
      for (final void Function() op in <void Function()>[
        () => bus.publish(_e, 1),
        () => bus.observe(_e),
        () => bus.activate(_t('later', (TopologyBuilder b) => b.write(_out, b.read(_e2)))),
        () => bus.publisher(_svc),
        () => bus.module('later-m', <Topology>[
              _t('later-m-a', (TopologyBuilder b) => b.write(_out, b.read(_e2))),
            ]),
        () => bus.addObserver(_Observer()),
        r.scope.acquire,
        () => bus.removeTopic(_e),
        () => bus.onShutdown(() {}),
        bus.start,
        () => p.publish(_e, 1),
      ]) {
        expect(op, throwsStateError);
      }
      handle.deactivate();
      r.release();
      p.dispose();
      bus.shutdown();
    },
  ),
  (
    name: 'G36 shutdown runs the shutdown callbacks in reverse registration order and reports one that throws in dev mode',
    body: (BusApiHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(_dev(d));
      final List<String> log = <String>[];
      bus.onShutdown(() => log.add('first'));
      bus.onShutdown(() => throw StateError('dispose'));
      bus.onShutdown(() => log.add('third'));
      bus.shutdown();
      expect(log, <String>['third', 'first']);
      expect(d.whereType<ShutdownCallbackThrew>(), hasLength(1));
    },
  ),
  // ------------------------------------------------------------ G37
  (
    name: 'G37 toGraph is the graph of the active definitions and the live claims',
    body: (BusApiHarness h) async {
      final Bus bus = h.bus();
      final Topology t = _t('graphed', (TopologyBuilder b) => b.write(_out, b.read(_e)));
      final TopologyHandle handle = bus.activate(t);
      final Publisher p = bus.publisher(const ExecutorSource('nav'),
          writes: <StateTopic<Object?>>{_s});
      expect(
          bus.toGraph(),
          TopologyGraph(
            topologies: <TopologyDefinition>[t.buildDefinition()],
            claims: <ShellClaim>[
              ShellClaim(source: const ExecutorSource('nav'), writes: <TopicRef>{_s.ref}),
            ],
          ));
      handle.deactivate();
      p.dispose();
      expect(bus.toGraph(), TopologyGraph());
    },
  ),
];
