// Conformance library for bus-testing@v1 (ADR-001 item 4): the virtual
// scheduler, the TestBus, the envelope recorder and the ordering probe of
// package:nidana_dart_runtime/testing.dart. Its cases are values; a binding
// registers them with a test runner. It imports neither package:test nor
// package:flutter_test.
//
// The implementation under test is testing.dart's own declarations, which
// the cases construct and call directly: they are final and have no second
// implementation to stand in for them, so the harness carries no factory,
// only the settle step ADR-001 requires. The cases that settle, or that let
// real time pass, need a real event loop (ADR-003 item 6), so this suite is
// bound under `dart test`, never under `testWidgets`. Whether a TestBus is a
// conforming bus is bus-api@v1's suite, bound to a TestBus in
// hsdd/contract/fixture/bus-api/behavior/.
import 'dart:async';

import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

/// What a binding supplies.
abstract interface class BusTestingHarness {
  /// Brings the implementation to quiescence. Every case drives the
  /// schedulers it constructs through their own operations, so a binding has
  /// nothing left to run.
  Future<void> settle();
}

// ------------------------------------------------------------ topics

const EventTopic<int> _e = EventTopic<int>(name: 'testing.e');
const EventTopic<int> _out = EventTopic<int>(name: 'testing.out');
const StateTopic<int> _s = StateTopic<int>(name: 'testing.s', initial: 1);
const StateTopic<int> _derived =
    StateTopic<int>(name: 'testing.derived', initial: 0);
// Read by the topology under test; its owner in an application would be an
// APPLICATION topology the test does not activate.
const StateTopic<int> _auth = StateTopic<int>(name: 'testing.auth', initial: 0);
const ReplayTopic<int> _r = ReplayTopic<int>(name: 'testing.r', bufferSize: 2);
const EventTopic<String> _secret =
    EventTopic<String>(name: 'testing.secret', sensitive: true);
const EventTopic<int> _untraced =
    EventTopic<int>(name: 'testing.untraced', tracing: Tracing.disabled);

// ------------------------------------------------------------ helpers

const ServiceSource _svc = ServiceSource('conformance');
const Duration _ms10 = Duration(milliseconds: 10);
const Duration _ms100 = Duration(milliseconds: 100);
const Duration _s1 = Duration(seconds: 1);
const Set<ObserverCapability> _all = <ObserverCapability>{
  ObserverCapability.observeAll,
  ObserverCapability.observeSensitive,
};

int _double(int v) => v * 2;

Topology _t(String id, void Function(TopologyBuilder b) body) =>
    topology(id, Scope.module, body);

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

  MessageEnvelope<Object?> on(Topic<Object?> topic) =>
      seen.firstWhere((s) => s.topic == topic.ref).envelope;

  @override
  void onPublish(TopicRef topic, MessageEnvelope<Object?> envelope,
      ObserveContext context) {
    seen.add((topic: topic, envelope: envelope));
    onCall?.call();
  }
}

/// The record a fresh TestBus makes of one publish to [topic].
RecordedEnvelope _recordOne<T>(MultiWriterTopic<T> topic, T value) {
  final TestBus bus = TestBus();
  bus.start();
  bus.input.publish(topic, value);
  return bus.recorder.envelopes.single;
}

final List<ConformanceCase<BusTestingHarness>> busTestingConformance =
    <ConformanceCase<BusTestingHarness>>[
  // ------------------------------------------------------------ G3
  (
    name: 'G3 a TestBus left without a provider runs on a fresh virtual scheduler built in the zone current at its construction, and keeps the config it was given',
    body: (BusTestingHarness h) async {
      final List<Object> errors = <Object>[];
      late final TestBus bus;
      runZonedGuarded(
        () => bus = TestBus(const BusConfig(devMode: false)),
        (Object e, StackTrace s) => errors.add(e),
        zoneValues: <Object?, Object?>{#testing: 'construction'},
      );
      expect(bus.config.scheduler, isNull);
      expect(bus.config.devMode, isFalse);
      expect(bus.scheduler.run(() => Zone.current[#testing]), 'construction');
      expect(bus.scheduler.clock.now(), VirtualScheduler.defaultInitialTime);
      expect(bus.clock.now(), bus.scheduler.clock.now());
      bus.start();
      bus.observe(_e).listen((int v) => throw StateError('subscriber $v'));
      bus.input.publish(_e, 1);
      bus.scheduler.triggerActions();
      expect(errors, <Object?>[isA<StateError>()]);
      expect(TestBus().scheduler, isNot(same(bus.scheduler)));
    },
  ),
  (
    name: 'G3 a TestBus runs on the virtual provider its config names, and rejects the production provider with ArgumentError',
    body: (BusTestingHarness h) async {
      final VirtualScheduler scheduler = VirtualScheduler();
      final VirtualSchedulerProvider provider =
          VirtualSchedulerProvider(scheduler);
      final TestBus bus = TestBus(BusConfig(scheduler: provider));
      expect(provider.scheduler, same(scheduler));
      expect(bus.scheduler, same(scheduler));
      expect(bus.config.scheduler, same(provider));
      expect(
          () => TestBus(
              const BusConfig(scheduler: ProductionSchedulerProvider())),
          throwsArgumentError);
    },
  ),
  (
    name: 'G3 a new TestBus is a bus that is bootstrapping, with nothing active, claimed, recorded or pending',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      final Bus asBus = bus;
      expect(asBus.lifecycle, BusLifecycle.bootstrapping);
      expect(asBus.toGraph().topologies, isEmpty);
      expect(asBus.toGraph().claims, isEmpty);
      expect(bus.recorder.envelopes, isEmpty);
      expect(bus.scheduler.pendingMicrotaskCount, 0);
      expect(bus.scheduler.pendingTimerCount, 0);
    },
  ),
  // ------------------------------------------------------------ G4
  (
    name: 'G4 a bus on a virtual provider, TestBus or not, reads the scheduler clock and runs what it schedules only inside scheduler operations',
    body: (BusTestingHarness h) async {
      final VirtualScheduler scheduler = VirtualScheduler();
      final Bus bus =
          Bus(BusConfig(scheduler: VirtualSchedulerProvider(scheduler)));
      bus.activate(_t('debounced',
          (TopologyBuilder t) => t.write(_out, t.read(_e).debounce(_ms100))));
      bus.start();
      final List<int> out = _listen(bus, _out);
      final _Observer o = _Observer();
      bus.addObserver(o);
      bus.publisher(_svc).publish(_e, 1);
      expect(bus.clock.now(), scheduler.clock.now());
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(out, isEmpty);
      expect(scheduler.pendingTimerCount, 1);
      scheduler.advanceTimeBy(_ms100);
      expect(out, <int>[1]);
      expect(o.on(_out).timestamp, VirtualScheduler.defaultInitialTime.add(_ms100));
    },
  ),
  (
    name: 'G4 on a TestBus a reentrant publish and a first value wait for triggerActions, never for a real event-loop turn',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      final List<int> events = <int>[];
      bus.observe(_e).listen((int v) {
        events.add(v);
        if (v == 1) bus.input.publish(_e, 2);
      });
      final List<int> states = _listen(bus, _s);
      bus.input.publish(_e, 1);
      await Future<void>.delayed(Duration.zero);
      expect(events, <int>[1]);
      expect(states, isEmpty);
      expect(bus.scheduler.pendingMicrotaskCount, greaterThan(0));
      bus.scheduler.triggerActions();
      expect(events, <int>[1, 2]);
      expect(states, <int>[1]);
    },
  ),
  (
    name: 'G4 TestBuses sharing one provider share its clock and its queue',
    body: (BusTestingHarness h) async {
      final VirtualSchedulerProvider provider =
          VirtualSchedulerProvider(VirtualScheduler());
      final TestBus a = TestBus(BusConfig(scheduler: provider));
      final TestBus b = TestBus(BusConfig(scheduler: provider));
      expect(b.scheduler, same(a.scheduler));
      final List<ModuleScope> modules = <ModuleScope>[
        for (final TestBus bus in <TestBus>[a, b])
          bus.module('shared', <Topology>[
            _t('shared-a', (TopologyBuilder t) => t.write(_out, t.read(_e))),
          ]),
      ];
      a.start();
      b.start();
      for (final ModuleScope m in modules) {
        m.acquire().release();
      }
      expect(a.scheduler.pendingTimerCount, 2);
      a.scheduler.advanceTimeBy(_ms100);
      expect(<bool>[for (final ModuleScope m in modules) m.isActive],
          <bool>[false, false]);
      expect(b.clock.now(), a.clock.now());
      expect(b.scheduler.pendingTimerCount, 0);
    },
  ),
  // ------------------------------------------------------------ G5
  (
    name: 'G5 virtual time starts at 2000-01-01T00:00:00Z or at the initial time given, and moves only when advanced',
    body: (BusTestingHarness h) async {
      expect(VirtualScheduler.defaultInitialTime, DateTime.utc(2000));
      final VirtualScheduler s = VirtualScheduler();
      expect(s.clock.now(), DateTime.utc(2000));
      expect(s.clock.now().isUtc, isTrue);
      final DateTime given = DateTime.utc(2026, 10, 17, 12);
      expect(VirtualScheduler(initialTime: given).clock.now(), given);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      s.triggerActions();
      expect(s.clock.now(), DateTime.utc(2000));
      s.advanceTimeBy(_s1);
      expect(s.clock.now(), DateTime.utc(2000, 1, 1, 0, 0, 1));
      s.advanceTimeBy(Duration.zero);
      expect(s.clock.now(), DateTime.utc(2000, 1, 1, 0, 0, 1));
    },
  ),
  (
    name: 'G5 package:clock read inside the scheduler zone is the virtual clock, so a production-provider bus built there stamps virtual time',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final Bus inner = s.run(() => Bus());
      expect(inner.clock.now(), s.clock.now());
      s.advanceTimeBy(const Duration(seconds: 3));
      expect(inner.clock.now(), DateTime.utc(2000, 1, 1, 0, 0, 3));
      inner.shutdown();
    },
  ),
  // ------------------------------------------------------------ G6
  (
    name: 'G6 timers, periodic timers and microtasks created in the scheduler zone wait for a scheduler operation and never run in real time',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final List<String> ran = <String>[];
      s.run(() {
        scheduleMicrotask(() => ran.add('microtask'));
        Timer(Duration.zero, () => ran.add('timer'));
        Timer.periodic(const Duration(milliseconds: 1), (Timer _) => ran.add('periodic'));
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ran, isEmpty);
      expect(s.pendingMicrotaskCount, 1);
      expect(s.pendingTimerCount, 2);
      s.triggerActions();
      expect(ran, <String>['microtask', 'timer']);
      s.advanceTimeBy(const Duration(milliseconds: 2));
      expect(ran, <String>['microtask', 'timer', 'periodic', 'periodic']);
    },
  ),
  (
    name: 'G6 a virtual timer reports isActive and tick as a dart:async Timer does, and cancel stops it',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final Timer once = s.run(() => Timer(_ms10, () {}));
      final Timer every = s.run(() => Timer.periodic(_ms10, (Timer _) {}));
      expect(once.isActive, isTrue);
      expect(once.tick, 0);
      s.advanceTimeBy(const Duration(milliseconds: 30));
      expect(once.isActive, isFalse);
      expect(once.tick, 1);
      expect(every.isActive, isTrue);
      expect(every.tick, 3);
      every.cancel();
      every.cancel();
      expect(every.isActive, isFalse);
      expect(s.pendingTimerCount, 0);
      s.advanceTimeBy(const Duration(milliseconds: 30));
      expect(every.tick, 3);
    },
  ),
  (
    name: 'G6 run executes its body in the scheduler zone and returns its result, running nothing queued',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final List<String> ran = <String>[];
      s.run(() => scheduleMicrotask(() => ran.add('queued')));
      final Object? seen = runZoned(
        () => s.run(() => Zone.current[#testing]),
        zoneValues: <Object?, Object?>{#testing: 'caller'},
      );
      expect(seen, isNull);
      expect(s.run(() => 42), 42);
      expect(ran, isEmpty);
      expect(s.pendingMicrotaskCount, 1);
    },
  ),
  // ------------------------------------------------------------ G7
  (
    name: 'G7 triggerActions runs the queued microtasks in order, then each due timer in due-time and creation order, draining the microtasks each one schedules first',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final List<String> trace = <String>[];
      s.run(() {
        Timer(Duration.zero, () {
          trace.add('timer A');
          scheduleMicrotask(() => trace.add('microtask from A'));
        });
        Timer(const Duration(milliseconds: -5), () => trace.add('timer B'));
        scheduleMicrotask(() {
          trace.add('microtask 1');
          scheduleMicrotask(() => trace.add('microtask 2'));
        });
        scheduleMicrotask(() => trace.add('microtask 3'));
      });
      final DateTime before = s.clock.now();
      s.triggerActions();
      expect(trace, <String>[
        'microtask 1',
        'microtask 3',
        'microtask 2',
        'timer A',
        'microtask from A',
        'timer B',
      ]);
      expect(s.clock.now(), before);
    },
  ),
  (
    name: 'G7 triggerActions keeps going until nothing is queued and nothing is due, and leaves later timers pending',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final List<String> trace = <String>[];
      s.run(() {
        scheduleMicrotask(() => Timer(Duration.zero,
            () => scheduleMicrotask(() => trace.add('end of chain'))));
        Timer(_ms10, () => trace.add('later'));
      });
      s.triggerActions();
      expect(trace, <String>['end of chain']);
      expect(s.pendingTimerCount, 1);
      expect(s.nextTimerDue, VirtualScheduler.defaultInitialTime.add(_ms10));
    },
  ),
  // ------------------------------------------------------------ G8
  (
    name: 'G8 advanceTimeBy fires each timer at its due instant, in due-time order, with the clock reading that instant',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final DateTime t0 = s.clock.now();
      final List<String> trace = <String>[];
      void at(int ms) => s.run(() => Timer(Duration(milliseconds: ms),
          () => trace.add('$ms@${s.clock.now().difference(t0).inMilliseconds}')));
      at(30);
      at(10);
      at(20);
      s.advanceTimeBy(const Duration(milliseconds: 25));
      expect(trace, <String>['10@10', '20@20']);
      expect(s.clock.now(), t0.add(const Duration(milliseconds: 25)));
      s.advanceTimeBy(const Duration(milliseconds: 5));
      expect(trace, <String>['10@10', '20@20', '30@30']);
    },
  ),
  (
    name: 'G8 a periodic timer fires once for each period crossed, and a timer created during an advance and due within it fires within it',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final DateTime t0 = s.clock.now();
      int elapsed() => s.clock.now().difference(t0).inMilliseconds;
      final List<String> trace = <String>[];
      s.run(() {
        Timer.periodic(const Duration(milliseconds: 300),
            (Timer _) => trace.add('periodic@${elapsed()}'));
        Timer(_ms100, () => Timer(const Duration(milliseconds: 250),
            () => trace.add('nested@${elapsed()}')));
      });
      s.advanceTimeBy(_s1);
      expect(trace, <String>[
        'periodic@300',
        'nested@350',
        'periodic@600',
        'periodic@900',
      ]);
      expect(elapsed(), 1000);
    },
  ),
  (
    name: 'G8 advanceTimeTo moves to the instant given; an earlier instant or a negative duration throws ArgumentError and runs nothing',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final List<String> ran = <String>[];
      s.run(() => Timer(const Duration(seconds: 2), () => ran.add('due')));
      s.advanceTimeTo(DateTime.utc(2000, 1, 1, 0, 0, 2));
      expect(ran, <String>['due']);
      expect(s.clock.now(), DateTime.utc(2000, 1, 1, 0, 0, 2));
      s.run(() => scheduleMicrotask(() => ran.add('queued')));
      expect(() => s.advanceTimeTo(DateTime.utc(2000)), throwsArgumentError);
      expect(() => s.advanceTimeBy(const Duration(milliseconds: -1)),
          throwsArgumentError);
      expect(ran, <String>['due']);
      expect(s.pendingMicrotaskCount, 1);
      expect(s.clock.now(), DateTime.utc(2000, 1, 1, 0, 0, 2));
      s.advanceTimeTo(s.clock.now());
      expect(ran, <String>['due', 'queued']);
    },
  ),
  // ------------------------------------------------------------ G9
  (
    name: 'G9 when an operation returns nothing is queued or due, and the scheduler reports the pending timers and the next due instant',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final DateTime t0 = s.clock.now();
      expect(s.nextTimerDue, isNull);
      s.run(() {
        scheduleMicrotask(() {});
        Timer(const Duration(milliseconds: 50), () {});
        Timer(const Duration(milliseconds: 80), () {});
        Timer.periodic(const Duration(milliseconds: 200), (Timer _) {});
      });
      expect(s.pendingMicrotaskCount, 1);
      s.triggerActions();
      expect(s.pendingMicrotaskCount, 0);
      expect(s.pendingTimerCount, 3);
      expect(s.nextTimerDue, t0.add(const Duration(milliseconds: 50)));
      s.advanceTimeBy(const Duration(milliseconds: 250));
      expect(s.pendingMicrotaskCount, 0);
      expect(s.pendingTimerCount, 1);
      expect(s.nextTimerDue, t0.add(const Duration(milliseconds: 400)));
    },
  ),
  (
    name: 'G9 a bus timer that is cancelled is no longer pending, so a test can assert the cancellation',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      final ModuleScope m = bus.module('grace', <Topology>[
        _t('grace-a', (TopologyBuilder t) => t.write(_out, t.read(_e))),
      ]);
      bus.start();
      m.acquire().release();
      expect(bus.scheduler.pendingTimerCount, 1);
      expect(bus.scheduler.nextTimerDue, bus.clock.now().add(_ms100));
      final ModuleReference again = m.acquire();
      expect(bus.scheduler.pendingTimerCount, 0);
      expect(bus.scheduler.nextTimerDue, isNull);
      expect(m.isActive, isTrue);
      again.release();
      bus.shutdown();
      expect(bus.scheduler.pendingTimerCount, 0);
    },
  ),
  // ------------------------------------------------------------ G10
  (
    name: 'G10 a scheduler operation called from inside work the scheduler runs throws StateError',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final List<Object> caught = <Object>[];
      void attempt(void Function() operation) {
        try {
          operation();
        } on StateError catch (e) {
          caught.add(e);
        }
      }

      s.run(() => scheduleMicrotask(() {
            attempt(s.triggerActions);
            attempt(() => s.advanceTimeBy(_ms10));
            attempt(() => s.advanceTimeTo(s.clock.now()));
            attempt(() {
              s.settle();
            });
          }));
      s.triggerActions();
      expect(caught, hasLength(4));
      expect(s.clock.now(), VirtualScheduler.defaultInitialTime);
    },
  ),
  (
    name: 'G10 an operation that runs more than maxActions actions throws StateError, leaving the rest queued and time where it had reached',
    body: (BusTestingHarness h) async {
      final VirtualScheduler loops = VirtualScheduler(maxActions: 50);
      // A microtask loop, cut off at 1000 so that an implementation that let
      // it escape the zone fails this case instead of hanging the run.
      var iterations = 0;
      void loop() {
        if (++iterations < 1000) scheduleMicrotask(loop);
      }

      loops.run(loop);
      expect(loops.triggerActions, throwsStateError);
      expect(loops.pendingMicrotaskCount, 1);
      final VirtualScheduler spins = VirtualScheduler(maxActions: 50);
      final DateTime t0 = spins.clock.now();
      late final Timer spin;
      spins.run(() =>
          Timer(_ms10, () => spin = Timer.periodic(Duration.zero, (Timer _) {})));
      expect(() => spins.advanceTimeBy(_s1), throwsStateError);
      expect(spins.clock.now(), t0.add(_ms10));
      spin.cancel();
      spins.advanceTimeBy(_s1);
      expect(spins.clock.now(), t0.add(_ms10).add(_s1));
    },
  ),
  (
    name: 'G10 a bound below one throws ArgumentError',
    body: (BusTestingHarness h) async {
      expect(() => VirtualScheduler(maxActions: 0), throwsArgumentError);
      expect(() => VirtualScheduler(maxSettleTurns: 0), throwsArgumentError);
    },
  ),
  // ------------------------------------------------------------ G11
  (
    name: 'G11 an exception thrown by scheduled work goes to the error zone the scheduler was built in, and the operation goes on',
    body: (BusTestingHarness h) async {
      final List<Object> errors = <Object>[];
      late final VirtualScheduler s;
      runZonedGuarded(
          () => s = VirtualScheduler(), (Object e, StackTrace st) => errors.add(e));
      final List<String> ran = <String>[];
      s.run(() {
        scheduleMicrotask(() => throw StateError('microtask'));
        Timer(Duration.zero, () => throw StateError('timer'));
        scheduleMicrotask(() => ran.add('after'));
      });
      s.triggerActions();
      expect(ran, <String>['after']);
      expect(errors, <Object?>[isA<StateError>(), isA<StateError>()]);
    },
  ),
  // ------------------------------------------------------------ G12
  (
    name: 'G12 settle delivers work a test completes outside the bus zone, alternating triggerActions with real event-loop turns',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.activate(_t('doubler',
          (TopologyBuilder t) => t.write(_out, t.read(_e).map(_double))));
      bus.start();
      final Completer<int> reply = Completer<int>();
      unawaited(reply.future.then((int v) => bus.input.publish(_e, v)));
      reply.complete(7);
      bus.scheduler.triggerActions();
      expect(bus.recorder.payloadsOf(_e), isEmpty);
      await bus.scheduler.settle();
      expect(bus.recorder.payloadsOf(_e), <int>[7]);
      expect(bus.recorder.payloadsOf(_out), <int>[14]);
    },
  ),
  (
    name: 'G12 settle completes once the scheduler stays quiescent across a real turn, and moves neither time nor later timers',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final List<String> ran = <String>[];
      s.run(() {
        scheduleMicrotask(() => ran.add('now'));
        Timer(_s1, () => ran.add('later'));
      });
      await s.settle();
      expect(ran, <String>['now']);
      expect(s.clock.now(), VirtualScheduler.defaultInitialTime);
      expect(s.pendingTimerCount, 1);
    },
  ),
  (
    name: 'G12 settle fails with StateError when work keeps arriving past maxSettleTurns, and throws StateError when called inside the scheduler zone',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler(maxSettleTurns: 3);
      final Timer feeder = Timer.periodic(
          Duration.zero, (Timer _) => s.run(() => scheduleMicrotask(() {})));
      try {
        await expectLater(s.settle(), throwsStateError);
      } finally {
        feeder.cancel();
      }
      await s.settle();
      expect(() => s.run(() => s.settle()), throwsStateError);
    },
  ),
  // ------------------------------------------------------------ G13
  (
    name: 'G13 a TestBus numbers its envelope ids e1, e2 and on, and its fresh correlation ids c1, c2 and on, in the order it generates them',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.activate(_t('doubler',
          (TopologyBuilder t) => t.write(_out, t.read(_e).map(_double))));
      bus.start();
      bus.input.publish(_e, 1);
      bus.scheduler.triggerActions();
      bus.input.publish(_e, 2);
      bus.scheduler.triggerActions();
      final List<MessageEnvelope<Object?>> all = <MessageEnvelope<Object?>>[
        for (final RecordedEnvelope r in bus.recorder.envelopes) r.envelope,
      ];
      expect(<String>[for (final e in all) e.id], <String>['e1', 'e2', 'e3', 'e4']);
      expect(<String>[for (final e in all) e.correlationId],
          <String>['c1', 'c1', 'c2', 'c2']);
      expect(<String?>[for (final e in all) e.causationId],
          <String?>[null, 'e1', null, 'e3']);
    },
  ),
  (
    name: 'G13 two TestBuses driven by the same operations record equal envelopes, timestamps included',
    body: (BusTestingHarness h) async {
      List<RecordedEnvelope> drive() {
        final TestBus bus = TestBus();
        bus.activate(_t('debounced',
            (TopologyBuilder t) => t.write(_out, t.read(_e).debounce(_ms100))));
        bus.start();
        bus.input.publish(_e, 1);
        bus.scheduler.advanceTimeBy(_ms10);
        bus.input.publish(_e, 2);
        bus.scheduler.advanceTimeBy(_s1);
        bus.stub(_s).publish(5);
        bus.input.publish(_secret, 'pin');
        return bus.recorder.envelopes;
      }

      final List<RecordedEnvelope> a = drive();
      final List<RecordedEnvelope> b = drive();
      expect(a, hasLength(5));
      expect(b, a);
      expect(<DateTime>{for (final RecordedEnvelope r in a) r.envelope.timestamp},
          hasLength(4));
    },
  ),
  // ------------------------------------------------------------ G14
  (
    name: 'G14 the recorder holds every delivery in delivery order, recorded before the observers see it, untraced and sensitive topics included',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      final List<int> recordedAtObserver = <int>[];
      bus.addObserver(_Observer(
          capabilities: _all,
          onCall: () => recordedAtObserver.add(bus.recorder.envelopes.length)));
      bus.input.publish(_e, 1);
      bus.input.publish(_untraced, 2);
      bus.input.publish(_secret, 'pin');
      bus.input.publish(_r, 3);
      expect(<TopicRef>[for (final RecordedEnvelope r in bus.recorder.envelopes) r.topic],
          <TopicRef>[_e.ref, _untraced.ref, _secret.ref, _r.ref]);
      expect(recordedAtObserver, <int>[1, 3, 4]);
    },
  ),
  (
    name: 'G14 publishes queued before start are recorded when start delivers them, and a publish never delivered is not recorded',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.input.publish(_e, 1);
      expect(bus.recorder.envelopes, isEmpty);
      bus.start();
      expect(bus.recorder.payloadsOf(_e), <int>[1]);
      final Publisher doomed = bus.publisher(_svc);
      bus.observe(_e).listen((int v) {
        if (v == 2) doomed.publish(_out, 9);
      });
      bus.input.publish(_e, 2);
      doomed.dispose();
      bus.scheduler.triggerActions();
      expect(bus.recorder.payloadsOf(_out), isEmpty);
      final TestBus never = TestBus();
      never.input.publish(_e, 1);
      never.shutdown();
      expect(never.recorder.envelopes, isEmpty);
    },
  ),
  (
    name: 'G14 a state publish equal to the current value is recorded, while a subscription first value is not a delivery and is not recorded',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      final List<int> got = _listen(bus, _s);
      bus.scheduler.triggerActions();
      expect(got, <int>[1]);
      expect(bus.recorder.envelopes, isEmpty);
      bus.stub(_s).publish(1);
      expect(got, <int>[1]);
      expect(bus.recorder.payloadsOf(_s), <int>[1]);
    },
  ),
  (
    name: 'G14 the deliveries of the shutdown drain are recorded, and the records stay readable after shutdown',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      bus.observe(_e).listen((int v) {
        if (v == 1) bus.input.publish(_e, 2);
      });
      bus.input.publish(_e, 1);
      bus.shutdown();
      expect(bus.recorder.payloadsOf(_e), <int>[1, 2]);
      expect(bus.recorder.envelopes, hasLength(2));
    },
  ),
  // ------------------------------------------------------------ G15
  (
    name: 'G15 a sensitive envelope is recorded redacted with its delivered form only behind unredacted, and a non-sensitive one is recorded as delivered',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      final _Observer o = _Observer(capabilities: _all);
      bus.addObserver(o);
      bus.input.publish(_secret, 'pin');
      bus.input.publish(_e, 1);
      final RecordedEnvelope secret = bus.recorder.envelopes.first;
      final RecordedEnvelope plain = bus.recorder.envelopes.last;
      expect(secret.unredacted, same(o.on(_secret)));
      expect(secret.envelope.payload, RedactedPayload.of('pin'));
      expect(secret.envelope, secret.unredacted.redacted());
      expect(secret.toString(), isNot(contains('pin')));
      expect(bus.recorder.envelopes.toString(), isNot(contains('pin')));
      expect(plain.envelope, same(o.on(_e)));
      expect(plain.unredacted, same(plain.envelope));
    },
  ),
  (
    name: 'G15 typed queries on a sensitive topic throw ArgumentError unless unredacted is asked for',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      bus.input.publish(_secret, 'pin');
      expect(() => bus.recorder.payloadsOf(_secret), throwsArgumentError);
      expect(() => bus.recorder.envelopesOf(_secret), throwsArgumentError);
      expect(bus.recorder.payloadsOf(_secret, unredacted: true), <String>['pin']);
      expect(bus.recorder.envelopesOf(_secret, unredacted: true).single.payload,
          'pin');
    },
  ),
  // ------------------------------------------------------------ G16
  (
    name: 'G16 envelopesOf and payloadsOf return the delivered envelopes and payloads of one topic, in delivery order, typed',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      final _Observer o = _Observer();
      bus.addObserver(o);
      bus.input.publish(_e, 1);
      bus.input.publish(_r, 10);
      bus.input.publish(_e, 2);
      final List<MessageEnvelope<int>> events = bus.recorder.envelopesOf(_e);
      expect(events, hasLength(2));
      expect(events[0], same(o.seen[0].envelope));
      expect(events[1], same(o.seen[2].envelope));
      final List<int> payloads = bus.recorder.payloadsOf(_e);
      expect(payloads, <int>[1, 2]);
      expect(bus.recorder.payloadsOf(_r), <int>[10]);
      expect(bus.recorder.payloadsOf(_out), isEmpty);
    },
  ),
  (
    name: 'G16 every list the recorder returns is an unmodifiable snapshot that later recording leaves unchanged',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      bus.input.publish(_e, 1);
      final List<RecordedEnvelope> all = bus.recorder.envelopes;
      final List<MessageEnvelope<int>> events = bus.recorder.envelopesOf(_e);
      final List<int> payloads = bus.recorder.payloadsOf(_e);
      bus.input.publish(_e, 2);
      expect(all, hasLength(1));
      expect(events, hasLength(1));
      expect(payloads, <int>[1]);
      expect(() => all.add(all.first), throwsUnsupportedError);
      expect(events.clear, throwsUnsupportedError);
      expect(() => payloads[0] = 3, throwsUnsupportedError);
      expect(bus.recorder.envelopes, hasLength(2));
    },
  ),
  (
    name: 'G16 two records are equal exactly when their topics and delivered envelopes are equal',
    body: (BusTestingHarness h) async {
      final RecordedEnvelope a = _recordOne(_e, 1);
      final RecordedEnvelope b = _recordOne(_e, 1);
      final RecordedEnvelope otherPayload = _recordOne(_e, 2);
      final RecordedEnvelope otherTopic = _recordOne(_out, 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == otherPayload, isFalse);
      expect(a.envelope, otherTopic.envelope);
      expect(a == otherTopic, isFalse);
    },
  ),
  // ------------------------------------------------------------ G17
  (
    name: 'G17 a recorder attached to a production-provider bus records its deliveries from the attachment on',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      // Constructed inside the scheduler zone, so the production provider
      // captures it and the case stays deterministic.
      final Bus bus = s.run(() => Bus());
      expect(bus.config.scheduler, isNull);
      bus.start();
      final Publisher p = bus.publisher(_svc);
      p.publish(_e, 1);
      final EnvelopeRecorder recorder = EnvelopeRecorder.attach(bus);
      bus.observe(_e).listen((int v) {
        if (v == 2) p.publish(_e, 3);
      });
      p.publish(_e, 2);
      s.triggerActions();
      expect(recorder.payloadsOf(_e), <int>[2, 3]);
      bus.shutdown();
      expect(recorder.payloadsOf(_e), <int>[2, 3]);
    },
  ),
  (
    name: 'G17 several recorders on one bus each record from their own attachment, before the observers, and count against no observer limit',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus(const BusConfig(maxObservers: 1));
      bus.start();
      bus.input.publish(_e, 1);
      final EnvelopeRecorder second = EnvelopeRecorder.attach(bus);
      final EnvelopeRecorder third = EnvelopeRecorder.attach(bus);
      final List<int> recordedAtObserver = <int>[];
      bus.addObserver(
          _Observer(onCall: () => recordedAtObserver.add(third.envelopes.length)));
      bus.input.publish(_e, 2);
      expect(bus.recorder.payloadsOf(_e), <int>[1, 2]);
      expect(second.payloadsOf(_e), <int>[2]);
      expect(third.payloadsOf(_e), <int>[2]);
      expect(recordedAtObserver, <int>[1]);
    },
  ),
  (
    name: 'G17 attaching a recorder leaves no pending work, and attaching to a shut-down bus throws StateError',
    body: (BusTestingHarness h) async {
      final VirtualScheduler s = VirtualScheduler();
      final Bus bus = Bus(BusConfig(scheduler: VirtualSchedulerProvider(s)));
      EnvelopeRecorder.attach(bus);
      expect(s.pendingMicrotaskCount, 0);
      expect(s.pendingTimerCount, 0);
      bus.shutdown();
      expect(() => EnvelopeRecorder.attach(bus), throwsStateError);
      final TestBus closed = TestBus();
      closed.shutdown();
      expect(() => EnvelopeRecorder.attach(closed), throwsStateError);
    },
  ),
  // ------------------------------------------------------------ G18
  (
    name: 'G18 a test activates only the topologies under test and stands in for an absent owner through stub (decides OQ-R2)',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.activate(_t('derive',
          (TopologyBuilder t) => t.write(_derived, t.read(_auth).map(_double))));
      final StateWriter<int> auth = bus.stub(_auth);
      expect(bus.stub(_auth), same(auth));
      bus.start();
      auth.publish(21);
      bus.scheduler.triggerActions();
      expect(bus.getCurrentValue(_derived), 42);
      expect(<String>[
        for (final TopologyDefinition d in bus.toGraph().topologies) d.topologyId,
      ], <String>['derive']);
      final ShellClaim claim = bus.toGraph().claims.single;
      expect(claim.source, TestBus.testSource);
      expect(claim.scope, Scope.application);
      expect(claim.writes, <TopicRef>{_auth.ref});
      expect(bus.recorder.envelopesOf(_auth).single.source, TestBus.testSource);
    },
  ),
  (
    name: 'G18 input publishes event and replay values as the test source, with no claim',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      expect(TestBus.testSource, const ServiceSource('test'));
      expect(bus.input, same(bus.input));
      expect(bus.input.source, TestBus.testSource);
      expect(bus.input.writes, isEmpty);
      bus.input.publish(_e, 1);
      bus.input.publish(_r, 2);
      expect(<MessageSource>[
        for (final RecordedEnvelope r in bus.recorder.envelopes) r.envelope.source,
      ], <MessageSource>[TestBus.testSource, TestBus.testSource]);
      expect(bus.toGraph().claims, isEmpty);
    },
  ),
  (
    name: 'G18 stub rejects a topic another owner holds with ClaimRejected, and after shutdown the helpers throw StateError',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.activate(_t('owner', (TopologyBuilder t) => t.write(_s, t.read(_e))));
      expect(() => bus.stub(_s), throwsA(isA<ClaimRejected>()));
      final Publisher input = bus.input;
      bus.shutdown();
      expect(() => bus.stub(_derived), throwsStateError);
      expect(() => input.publish(_e, 1), throwsStateError);
      final TestBus closed = TestBus();
      closed.shutdown();
      expect(() => closed.input, throwsStateError);
    },
  ),
  // ------------------------------------------------------------ G19
  (
    name: 'G19 an ordering probe reports one sequence for every subscription under reentrant publishes, the per-topic ordering regression test of Guide §6.5',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.activate(_t('echo',
          (TopologyBuilder t) => t.write(_e, t.read(_out).map(_double))));
      bus.start();
      final OrderingProbe<int> probe =
          OrderingProbe.attach(bus, _e, subscriptions: 4);
      bus.observe(_e).listen((int v) {
        if (v.isOdd && v < 10) bus.input.publish(_e, v + 10);
        if (v == 2) bus.input.publish(_out, 50);
      });
      for (var i = 0; i < 6; i++) {
        bus.input.publish(_e, i);
      }
      bus.scheduler.triggerActions();
      expect(probe.received, hasLength(4));
      expect(probe.isConsistent, isTrue);
      expect(probe.received.first, hasLength(10));
      expect(probe.received.first, bus.recorder.payloadsOf(_e));
    },
  ),
  (
    name: 'G19 a probe of a state topic starts every sequence with the value current at attachment',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      final StateWriter<int> w = bus.stub(_s);
      w.publish(5);
      final OrderingProbe<int> probe = OrderingProbe.attach(bus, _s);
      w.publish(6);
      bus.scheduler.triggerActions();
      expect(probe.topic, _s);
      expect(probe.received, <List<int>>[
        <int>[5, 6],
        <int>[5, 6],
        <int>[5, 6],
      ]);
      expect(probe.isConsistent, isTrue);
    },
  ),
  (
    name: 'G19 cancel stops a probe and is idempotent, and fewer than two subscriptions throws ArgumentError',
    body: (BusTestingHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      expect(() => OrderingProbe.attach(bus, _e, subscriptions: 1),
          throwsArgumentError);
      final OrderingProbe<int> probe = OrderingProbe.attach(bus, _e);
      bus.input.publish(_e, 1);
      probe.cancel();
      probe.cancel();
      bus.input.publish(_e, 2);
      bus.scheduler.triggerActions();
      expect(probe.received, <List<int>>[
        <int>[1],
        <int>[1],
        <int>[1],
      ]);
    },
  ),
];
