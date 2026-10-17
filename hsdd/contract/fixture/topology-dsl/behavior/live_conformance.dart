// Conformance library for topology-dsl@v1, live side (ADR-001 item 4): what a
// live implementation does with a topology's plan (G18 to G29). Its cases are
// values; a binding registers them with a test runner. It imports neither
// package:test nor package:flutter_test, and names no bus type: a binding
// adapts its implementation to LiveTopologyHarness and LiveRun. This
// contract's own directory holds no binding of this suite; the live
// implementation's binding lives with the contract that declares it
// (ADR-001 item 4), hsdd/contract/fixture/bus-api/behavior/.
import 'dart:async';

import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

/// What a live binding supplies.
abstract interface class LiveTopologyHarness {
  /// A fresh live implementation on a clock only [LiveRun.advance] moves:
  /// [topologies] are activated in order, then the implementation is started
  /// (Spec §3.13). Nothing else is active on it.
  LiveRun start(List<Topology> topologies);

  /// Brings every run of this harness to quiescence, including work that
  /// starts outside the implementation's zone.
  Future<void> settle();
}

/// One live implementation, as shell code sees it.
abstract interface class LiveRun {
  /// Publishes [value] to [topic] as shell code that starts a new flow
  /// (Lineage.root()); a state topic through a writer that claims it, so only
  /// a state topic no active topology writes.
  void publish<T>(Topic<T> topic, T value);

  /// Subscribes to [topic] now, as a shell subscriber reading with the
  /// topic's own dedup policy, and returns the list that subscription appends
  /// each delivered envelope to; what the topic replays at subscription is
  /// not appended.
  List<MessageEnvelope<T>> watch<T>(Topic<T> topic);

  /// Every envelope appended to any list [watch] returned, in delivery order.
  List<MessageEnvelope<Object?>> get deliveries;

  /// The current value of [topic] on this implementation.
  T current<T>(StateTopic<T> topic);

  /// Moves the clock forward by [duration] and runs everything due by then
  /// before returning; Duration.zero runs everything due now. Synchronous.
  void advance(Duration duration);

  /// Activates [topology] on this run, after start.
  void activate(Topology topology);

  /// Deactivates [topology], which this run activated.
  void deactivate(Topology topology);
}

// ------------------------------------------------------------ topics

const EventTopic<int> _in = EventTopic<int>(name: 'live.in');
const EventTopic<int> _inB = EventTopic<int>(name: 'live.in-b');
const EventTopic<int> _inC = EventTopic<int>(name: 'live.in-c');
const EventTopic<int> _out = EventTopic<int>(name: 'live.out');
const EventTopic<int> _outB = EventTopic<int>(name: 'live.out-b');
const EventTopic<String> _text = EventTopic<String>(name: 'live.text');
const EventTopic<int> _untraced =
    EventTopic<int>(name: 'live.untraced', tracing: Tracing.disabled);
const StateTopic<int> _level = StateTopic<int>(name: 'live.level', initial: 1);
const StateTopic<int> _derived =
    StateTopic<int>(name: 'live.derived', initial: 0);
const StateTopic<int> _total = StateTopic<int>(name: 'live.total', initial: 5);
const ReplayTopic<int> _history =
    ReplayTopic<int>(name: 'live.history', bufferSize: 2);

// ------------------------------------------------------------ helpers

List<Object?> _payloads<T>(List<MessageEnvelope<T>> envelopes) =>
    <Object?>[for (final MessageEnvelope<T> e in envelopes) e.payload];

Topology _t(String id, void Function(TopologyBuilder b) body) =>
    topology(id, Scope.module, body);

const Duration _ms1 = Duration(milliseconds: 1);
const Duration _ms100 = Duration(milliseconds: 100);
const Duration _s1 = Duration(seconds: 1);

/// An inner stream the case controls: synchronous, single-subscription, and
/// whose cancel future never completes, so an implementation that waits for
/// it never listens to the next inner stream.
final class _Inner {
  _Inner() {
    controller = StreamController<int>(
      sync: true,
      onListen: () => listens++,
      onCancel: () {
        cancels++;
        return Completer<void>().future;
      },
    );
  }

  late final StreamController<int> controller;
  int listens = 0;
  int cancels = 0;

  Stream<int> get stream => controller.stream;

  void add(int value) => controller.add(value);
}

final List<ConformanceCase<LiveTopologyHarness>> liveConformance =
    <ConformanceCase<LiveTopologyHarness>>[
  // ------------------------------------------------------------ G18
  (
    name: 'G18 activation runs declare once and a sink publishes with the topology as its source',
    body: (LiveTopologyHarness h) async {
      int runs = 0;
      final Topology t = _t('live-source', (TopologyBuilder b) {
        runs++;
        b.write(_out, b.read(_in).map((int v) => v * 2));
      });
      final LiveRun run = h.start(<Topology>[t]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 21);
      await h.settle();
      expect(runs, 1);
      expect(_payloads(out), <Object?>[42]);
      expect(out.single.source, const TopologySource('live-source'));
      run.deactivate(t);
      run.activate(t);
      await h.settle();
      expect(runs, 2);
    },
  ),
  // ------------------------------------------------------------ G19
  (
    name: 'G19 a state topic read delivers the current value at activation, then each later value',
    body: (LiveTopologyHarness h) async {
      final Topology t = _t('live-current', (TopologyBuilder b) {
        b.write(_derived, b.read(_level).map((int v) => v * 10));
      });
      final LiveRun run = h.start(<Topology>[t]);
      await h.settle();
      expect(run.current(_derived), 10);
      run.publish(_level, 2);
      await h.settle();
      expect(run.current(_derived), 20);
    },
  ),
  (
    name: 'G19 a default read skips a value equal to the previous one it delivered; a Dedup.none read delivers every publish',
    body: (LiveTopologyHarness h) async {
      final Topology t = _t('live-dedup', (TopologyBuilder b) {
        b.write(_out, b.read(_level).map((int v) => v));
        b.write(_outB, b.read(_level, dedup: Dedup.none).map((int v) => v));
      });
      final LiveRun run = h.start(<Topology>[t]);
      await h.settle();
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      for (final int v in <int>[1, 5, 5, 6]) {
        run.publish(_level, v);
        await h.settle();
      }
      expect(_payloads(out), <Object?>[5, 6]);
      expect(_payloads(outB), <Object?>[1, 5, 5, 6]);
    },
  ),
  (
    name: 'G19 a replay topic read delivers the buffer at activation; an event topic read delivers later values only',
    body: (LiveTopologyHarness h) async {
      final Topology t = _t('live-replay', (TopologyBuilder b) {
        b.write(_out, b.read(_history));
        b.write(_outB, b.read(_in));
      });
      final LiveRun run = h.start(const <Topology>[]);
      for (final int v in <int>[1, 2, 3]) {
        run.publish(_history, v);
      }
      run.publish(_in, 9);
      await h.settle();
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      run.activate(t);
      await h.settle();
      expect(_payloads(out), <Object?>[2, 3]);
      expect(outB, isEmpty);
      run.publish(_history, 4);
      run.publish(_in, 10);
      await h.settle();
      expect(_payloads(out), <Object?>[2, 3, 4]);
      expect(_payloads(outB), <Object?>[10]);
    },
  ),
  // ------------------------------------------------------------ G20
  (
    name: 'G20 map transforms and filter passes the values its test accepts',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-map', (TopologyBuilder b) {
          b.write(_out,
              b.read(_in).map((int v) => v + 1).filter((int v) => v.isEven));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      for (final int v in <int>[1, 2, 3]) {
        run.publish(_in, v);
      }
      await h.settle();
      expect(_payloads(out), <Object?>[2, 4]);
    },
  ),
  (
    name: 'G20 scan emits each accumulated value and never its seed',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-scan', (TopologyBuilder b) {
          b.write(_out, b.read(_in).scan(10, (int acc, int v) => acc + v));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.publish(_in, 2);
      await h.settle();
      expect(_payloads(out), <Object?>[11, 13]);
    },
  ),
  (
    name: 'G20 pairwise emits each value with the one before it, from the second value on',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-pairwise', (TopologyBuilder b) {
          b.write(
              _text,
              b.read(_in).pairwise().map((({int previous, int current}) p) =>
                  '${p.previous}>${p.current}'));
        }),
      ]);
      final List<MessageEnvelope<String>> text = run.watch(_text);
      for (final int v in <int>[1, 2, 3]) {
        run.publish(_in, v);
      }
      await h.settle();
      expect(_payloads(text), <Object?>['1>2', '2>3']);
    },
  ),
  (
    name: 'G20 distinctUntilChanged drops a value equal to the one before it',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-distinct', (TopologyBuilder b) {
          b.write(_out, b.read(_in).distinctUntilChanged());
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      for (final int v in <int>[1, 1, 2, 2, 1]) {
        run.publish(_in, v);
      }
      await h.settle();
      expect(_payloads(out), <Object?>[1, 2, 1]);
    },
  ),
  // ------------------------------------------------------------ G21
  (
    name: 'G21 combine emits once every input has a value, then on each input value',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-combine', (TopologyBuilder b) {
          b.write(_out,
              b.combine2(b.read(_in), b.read(_inB), (int a, int c) => a * 10 + c));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      await h.settle();
      expect(out, isEmpty);
      run.publish(_inB, 2);
      run.publish(_in, 3);
      run.publish(_inB, 4);
      await h.settle();
      expect(_payloads(out), <Object?>[12, 32, 34]);
    },
  ),
  (
    name: 'G21 the combine forms pass the latest values in input order',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-combine-n', (TopologyBuilder b) {
          final TopicStream<int> a = b.read(_in);
          final TopicStream<int> c = b.read(_inB);
          final TopicStream<int> d = b.read(_inC);
          b.write(_text, b.combine3(a, c, d, (int x, int y, int z) => '$x$y$z'));
          b.write(
              _out,
              b.combineAll(<TopicStream<int>>[d, c, a],
                  (List<int> xs) => int.parse(xs.join())));
          b.write(
              _outB,
              b.combine4(a, c, d, a,
                  (int w, int x, int y, int z) => w * 1000 + x * 100 + y * 10 + z));
        }),
      ]);
      final List<MessageEnvelope<String>> text = run.watch(_text);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      run.publish(_in, 1);
      run.publish(_inB, 2);
      run.publish(_inC, 3);
      await h.settle();
      expect(_payloads(text), <Object?>['123']);
      expect(_payloads(out), <Object?>[321]);
      expect(_payloads(outB), <Object?>[1231]);
    },
  ),
  (
    name: 'G21 withLatestFrom emits only on a primary value, once every latest input has a value',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-latest', (TopologyBuilder b) {
          b.write(
              _out,
              b
                  .read(_in)
                  .withLatestFrom(b.read(_inB), (int p, int l) => p * 10 + l));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      for (final (Topic<int>, int) step in <(Topic<int>, int)>[
        (_in, 1),
        (_inB, 2),
        (_in, 3),
        (_inB, 4),
        (_in, 5),
      ]) {
        run.publish(step.$1, step.$2);
        await h.settle();
      }
      expect(_payloads(out), <Object?>[32, 54]);
    },
  ),
  (
    name: 'G21 withLatestFrom2 combines the primary with a state topic and an event topic',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-latest-2', (TopologyBuilder b) {
          b.write(
              _out,
              b.read(_in).withLatestFrom2(b.read(_level), b.read(_inB),
                  (int p, int l, int x) => p * 100 + l * 10 + x));
        }),
      ]);
      await h.settle();
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      await h.settle();
      expect(out, isEmpty);
      run.publish(_inB, 7);
      run.publish(_in, 2);
      await h.settle();
      expect(_payloads(out), <Object?>[217]);
    },
  ),
  (
    name: 'G21 merge emits the values of every input in arrival order',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-merge', (TopologyBuilder b) {
          b.write(
              _out,
              b.merge(<TopicStream<int>>[
                b.read(_in),
                b.read(_inB).map((int v) => -v),
              ]));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.publish(_inB, 2);
      run.publish(_in, 3);
      await h.settle();
      expect(_payloads(out), <Object?>[1, -2, 3]);
    },
  ),
  // ------------------------------------------------------------ G22
  (
    name: 'G22 switchMap listens to the next inner stream within the outer delivery, without waiting for the previous cancel',
    body: (LiveTopologyHarness h) async {
      final _Inner first = _Inner();
      final _Inner second = _Inner();
      final LiveRun run = h.start(<Topology>[
        _t('live-switch', (TopologyBuilder b) {
          b.write(
              _out,
              b.read(_in).switchMap(
                  (int v) => v == 1 ? first.stream : second.stream));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.advance(Duration.zero);
      expect(first.listens, 1);
      first.add(10);
      run.advance(Duration.zero);
      expect(_payloads(out), <Object?>[10]);
      run.publish(_in, 2);
      run.advance(Duration.zero);
      // No real event-loop turn has passed, and the first cancel future never
      // completes (ADR-003 item 3).
      expect(first.cancels, 1);
      expect(second.listens, 1);
      second.add(20);
      run.advance(Duration.zero);
      expect(_payloads(out), <Object?>[10, 20]);
    },
  ),
  (
    name: 'G22 switchMap calls toStream once per outer value and delivers the current inner values',
    body: (LiveTopologyHarness h) async {
      int calls = 0;
      final LiveRun run = h.start(<Topology>[
        _t('live-switch-calls', (TopologyBuilder b) {
          b.write(
              _out,
              b.read(_in).switchMap((int v) {
                calls++;
                return Stream<int>.fromIterable(<int>[v, v * 2]);
              }));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      await h.settle();
      run.publish(_in, 3);
      await h.settle();
      expect(calls, 2);
      expect(_payloads(out), <Object?>[1, 2, 3, 6]);
    },
  ),
  (
    name: 'G22 a retry policy calls toStream again after its delay on the run clock, numbering the attempts',
    body: (LiveTopologyHarness h) async {
      int calls = 0;
      final List<int> attempts = <int>[];
      final LiveRun run = h.start(<Topology>[
        _t('live-retry', (TopologyBuilder b) {
          b.write(
              _out,
              b.read(_in).switchMap(
                (int v) {
                  calls++;
                  return calls <= 2
                      ? Stream<int>.error(StateError('flaky'))
                      : Stream<int>.value(v);
                },
                retry: (Object error, int attempt) {
                  attempts.add(attempt);
                  return _ms100;
                },
              ));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 7);
      run.advance(Duration.zero);
      expect(calls, 1);
      run.advance(_ms100 - _ms1);
      expect(calls, 1);
      run.advance(_ms1);
      expect(calls, 2);
      run.advance(_ms100);
      expect(calls, 3);
      await h.settle();
      expect(_payloads(out), <Object?>[7]);
      expect(attempts, <int>[1, 2]);
    },
  ),
  (
    name: 'G22 without a retry policy, or when the policy returns null, an inner error goes downstream',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-no-retry', (TopologyBuilder b) {
          final TopicStream<int> x = b.read(_in);
          b.write(
              _out,
              x
                  .switchMap((int v) => Stream<int>.error(StateError('down')))
                  .catchError((Object e, StackTrace s) => -1));
          b.write(
              _outB,
              x
                  .switchMap((int v) => Stream<int>.error(StateError('down')),
                      retry: (Object e, int attempt) => null)
                  .catchError((Object e, StackTrace s) => -2));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      run.publish(_in, 1);
      await h.settle();
      expect(_payloads(out), <Object?>[-1]);
      expect(_payloads(outB), <Object?>[-2]);
    },
  ),
  // ------------------------------------------------------------ G23
  (
    name: 'G23 debounce emits a value once its duration passes without a newer value',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-debounce', (TopologyBuilder b) {
          b.write(_out, b.read(_in).debounce(const Duration(milliseconds: 300)));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.advance(_ms100);
      run.publish(_in, 2);
      run.advance(const Duration(milliseconds: 299));
      expect(out, isEmpty);
      run.advance(_ms1);
      expect(_payloads(out), <Object?>[2]);
    },
  ),
  (
    name: 'G23 throttle emits a value and drops the values that follow it within its duration',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-throttle', (TopologyBuilder b) {
          b.write(_out, b.read(_in).throttle(_ms100));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.advance(Duration.zero);
      expect(_payloads(out), <Object?>[1]);
      run.advance(const Duration(milliseconds: 50));
      run.publish(_in, 2);
      run.advance(const Duration(milliseconds: 50));
      run.publish(_in, 3);
      run.advance(Duration.zero);
      expect(_payloads(out), <Object?>[1, 3]);
    },
  ),
  (
    name: 'G23 delay shifts each value by its duration',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-delay', (TopologyBuilder b) {
          b.write(_out, b.read(_in).delay(_ms100));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.advance(_ms100 - _ms1);
      expect(out, isEmpty);
      run.advance(_ms1);
      expect(_payloads(out), <Object?>[1]);
    },
  ),
  (
    name: 'G23 sample emits the most recent value once per period that received one, counting from the first value',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-sample', (TopologyBuilder b) {
          b.write(_out, b.read(_in).sample(_s1));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.publish(_in, 2);
      run.advance(_s1);
      expect(_payloads(out), <Object?>[2]);
      run.advance(_s1);
      expect(_payloads(out), <Object?>[2]);
      run.publish(_in, 3);
      run.advance(_s1);
      expect(_payloads(out), <Object?>[2, 3]);
    },
  ),
  (
    name: 'G23 buffer emits the values of each period as one batch, counting from the first value, and never an empty batch',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-buffer', (TopologyBuilder b) {
          b.write(_text,
              b.read(_in).buffer(_s1).map((List<int> xs) => xs.join(',')));
        }),
      ]);
      final List<MessageEnvelope<String>> text = run.watch(_text);
      run.publish(_in, 1);
      run.publish(_in, 2);
      run.advance(_s1);
      expect(_payloads(text), <Object?>['1,2']);
      run.advance(_s1);
      expect(_payloads(text), <Object?>['1,2']);
      run.publish(_in, 3);
      run.advance(_s1);
      expect(_payloads(text), <Object?>['1,2', '3']);
    },
  ),
  (
    name: 'G23 timeout raises one TimeoutException per silence of its duration, counted from activation or the last value',
    body: (LiveTopologyHarness h) async {
      final List<Object> errors = <Object>[];
      final LiveRun run = h.start(<Topology>[
        _t('live-timeout', (TopologyBuilder b) {
          b.write(
              _out,
              b.read(_in).timeout(_s1).catchError((Object e, StackTrace s) {
                errors.add(e);
                return -1;
              }));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.advance(_s1);
      expect(_payloads(out), <Object?>[-1]);
      run.advance(_s1);
      expect(_payloads(out), <Object?>[-1]);
      run.publish(_in, 5);
      run.advance(_s1 - _ms1);
      expect(_payloads(out), <Object?>[-1, 5]);
      run.advance(_ms1);
      expect(_payloads(out), <Object?>[-1, 5, -1]);
      expect(errors, everyElement(isA<TimeoutException>()));
    },
  ),
  // ------------------------------------------------------------ G24
  (
    name: 'G24 reduceInto seeds its fold with the current value and publishes nothing at activation',
    body: (LiveTopologyHarness h) async {
      final Topology t = _t('live-reduce', (TopologyBuilder b) {
        b.reduceInto(_total, b.read(_in), (int s, int e) => s + e);
      });
      final LiveRun run = h.start(const <Topology>[]);
      final List<MessageEnvelope<int>> total = run.watch(_total);
      run.activate(t);
      await h.settle();
      expect(total, isEmpty);
      expect(run.current(_total), 5);
      run.publish(_in, 1);
      run.publish(_in, 2);
      await h.settle();
      expect(_payloads(total), <Object?>[6, 8]);
      expect(run.current(_total), 8);
    },
  ),
  (
    name: 'G24 after re-activation reduceInto resumes from the retained value',
    body: (LiveTopologyHarness h) async {
      final Topology t = _t('live-retain', (TopologyBuilder b) {
        b.reduceInto(_total, b.read(_in), (int s, int e) => s + e);
      });
      final LiveRun run = h.start(<Topology>[t]);
      run.publish(_in, 1);
      await h.settle();
      expect(run.current(_total), 6);
      run.deactivate(t);
      run.publish(_in, 10);
      await h.settle();
      expect(run.current(_total), 6);
      run.activate(t);
      await h.settle();
      run.publish(_in, 1);
      await h.settle();
      expect(run.current(_total), 7);
    },
  ),
  // ------------------------------------------------------------ G25
  (
    name: 'G25 a single-input stage passes its input lineage: the input envelope is the cause, correlation and parents are kept',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-map', (TopologyBuilder b) {
          b.write(_out, b.read(_in).map((int v) => v + 1).filter((int v) => true));
        }),
      ]);
      final List<MessageEnvelope<int>> input = run.watch(_in);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      await h.settle();
      expect(out.single.causationId, input.single.id);
      expect(out.single.correlationId, input.single.correlationId);
      expect(out.single.parentCorrelationIds, isEmpty);
    },
  ),
  (
    name: 'G25 combine takes the trigger as cause and keeps a shared correlation',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-same', (TopologyBuilder b) {
          final TopicStream<int> x = b.read(_in);
          b.write(_out,
              b.combine2(x.map((int v) => v), x.map((int v) => v * 2),
                  (int a, int c) => a + c));
        }),
      ]);
      final List<MessageEnvelope<int>> input = run.watch(_in);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      await h.settle();
      expect(_payloads(out), <Object?>[3]);
      expect(out.single.causationId, input.single.id);
      expect(out.single.correlationId, input.single.correlationId);
      expect(out.single.parentCorrelationIds, isEmpty);
    },
  ),
  (
    name: 'G25 combine of different correlations takes a fresh one and records the inputs as parents',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-cross', (TopologyBuilder b) {
          b.write(_out,
              b.combine2(b.read(_in), b.read(_inB), (int a, int c) => a + c));
        }),
      ]);
      final List<MessageEnvelope<int>> a = run.watch(_in);
      final List<MessageEnvelope<int>> c = run.watch(_inB);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.publish(_inB, 2);
      await h.settle();
      final MessageEnvelope<int> e = out.single;
      expect(e.causationId, c.single.id);
      expect(e.parentCorrelationIds,
          <String>[a.single.correlationId, c.single.correlationId]);
      expect(e.correlationId,
          isNot(anyOf(a.single.correlationId, c.single.correlationId)));
    },
  ),
  (
    name: 'G25 withLatestFrom keeps the lineage of the primary value',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-latest', (TopologyBuilder b) {
          b.write(_out,
              b.read(_in).withLatestFrom(b.read(_inB), (int p, int l) => p + l));
        }),
      ]);
      final List<MessageEnvelope<int>> primary = run.watch(_in);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_inB, 2);
      run.publish(_in, 1);
      await h.settle();
      expect(out.single.causationId, primary.single.id);
      expect(out.single.correlationId, primary.single.correlationId);
      expect(out.single.parentCorrelationIds, isEmpty);
    },
  ),
  (
    name: 'G25 switchMap inner values carry the lineage of the outer value that created them',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-switch', (TopologyBuilder b) {
          b.write(_out,
              b.read(_in).switchMap((int v) => Stream<int>.value(v * 3)));
        }),
      ]);
      final List<MessageEnvelope<int>> outer = run.watch(_in);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      await h.settle();
      expect(_payloads(out), <Object?>[3]);
      expect(out.single.causationId, outer.single.id);
      expect(out.single.correlationId, outer.single.correlationId);
    },
  ),
  (
    name: 'G25 debounce passes the lineage of the value that survives, buffer that of the last value of its batch',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-time', (TopologyBuilder b) {
          b.write(_out, b.read(_in).debounce(_ms100));
          b.write(_text,
              b.read(_inB).buffer(_s1).map((List<int> xs) => xs.join(',')));
        }),
      ]);
      final List<MessageEnvelope<int>> input = run.watch(_in);
      final List<MessageEnvelope<int>> inputB = run.watch(_inB);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<String>> text = run.watch(_text);
      run.publish(_in, 1);
      run.publish(_in, 2);
      run.publish(_inB, 3);
      run.publish(_inB, 4);
      run.advance(_s1);
      expect(_payloads(out), <Object?>[2]);
      expect(out.single.causationId, input[1].id);
      expect(_payloads(text), <Object?>['3,4']);
      expect(text.single.causationId, inputB[1].id);
    },
  ),
  (
    name: 'G25 scan and reduceInto pass the lineage of the input that triggered them',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-fold', (TopologyBuilder b) {
          b.write(_out, b.read(_in).scan(0, (int acc, int v) => acc + v));
          b.reduceInto(_total, b.read(_inB), (int s, int e) => s + e);
        }),
      ]);
      final List<MessageEnvelope<int>> input = run.watch(_in);
      final List<MessageEnvelope<int>> inputB = run.watch(_inB);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> total = run.watch(_total);
      run.publish(_in, 1);
      run.publish(_in, 2);
      run.publish(_inB, 3);
      await h.settle();
      expect(out[1].causationId, input[1].id);
      expect(total.single.causationId, inputB.single.id);
      expect(total.single.correlationId, inputB.single.correlationId);
    },
  ),
  (
    name: 'G25 merge passes the lineage of each input value',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-merge', (TopologyBuilder b) {
          b.write(_out, b.merge(<TopicStream<int>>[b.read(_in), b.read(_inB)]));
        }),
      ]);
      final List<MessageEnvelope<int>> a = run.watch(_in);
      final List<MessageEnvelope<int>> c = run.watch(_inB);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.publish(_inB, 2);
      await h.settle();
      expect(out[0].causationId, a.single.id);
      expect(out[1].causationId, c.single.id);
    },
  ),
  (
    name: 'G25 an untraced read and the initial value of a state topic start a new flow',
    body: (LiveTopologyHarness h) async {
      final Topology t = _t('live-lineage-root', (TopologyBuilder b) {
        b.write(_out, b.read(_untraced).map((int v) => v));
        b.write(_outB, b.read(_level).map((int v) => v));
      });
      final LiveRun run = h.start(const <Topology>[]);
      final List<MessageEnvelope<int>> input = run.watch(_untraced);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      run.activate(t);
      await h.settle();
      expect(outB.single.payload, 1);
      expect(outB.single.causationId, isNull);
      run.publish(_untraced, 4);
      await h.settle();
      expect(out.single.causationId, isNull);
      expect(out.single.correlationId, isNot(input.single.correlationId));
      expect(out.single.parentCorrelationIds, isEmpty);
    },
  ),
  (
    name: 'G25 a catchError value carries the lineage the failing stage would have passed; a timeout recovers as a new flow',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-lineage-error', (TopologyBuilder b) {
          b.write(
              _out,
              b
                  .read(_in)
                  .switchMap((int v) => Stream<int>.error(StateError('down')))
                  .catchError((Object e, StackTrace s) => -1));
          b.write(
              _outB,
              b
                  .read(_inB)
                  .map((int v) => v == 0 ? throw StateError('zero') : v)
                  .catchError((Object e, StackTrace s) => -2));
          b.write(
              _text,
              b
                  .read(_inC)
                  .timeout(_s1)
                  .map((int v) => '$v')
                  .catchError((Object e, StackTrace s) => 'late'));
        }),
      ]);
      final List<MessageEnvelope<int>> outer = run.watch(_in);
      final List<MessageEnvelope<int>> inputB = run.watch(_inB);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      final List<MessageEnvelope<String>> text = run.watch(_text);
      run.publish(_in, 1);
      run.publish(_inB, 0);
      await h.settle();
      expect(_payloads(out), <Object?>[-1]);
      expect(out.single.causationId, outer.single.id);
      expect(_payloads(outB), <Object?>[-2]);
      expect(outB.single.causationId, inputB.single.id);
      run.advance(_s1);
      expect(_payloads(text), <Object?>['late']);
      expect(text.single.causationId, isNull);
    },
  ),
  // ------------------------------------------------------------ G26
  (
    name: 'G26 catchError replaces an error with a value and the pipeline goes on',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-catch', (TopologyBuilder b) {
          b.write(
              _out,
              b
                  .read(_in)
                  .switchMap((int v) => v.isOdd
                      ? Stream<int>.error(StateError('odd'))
                      : Stream<int>.value(v))
                  .catchError((Object e, StackTrace s) => -1));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      for (final int v in <int>[1, 2, 3]) {
        run.publish(_in, v);
        await h.settle();
      }
      expect(_payloads(out), <Object?>[-1, 2, -1]);
    },
  ),
  (
    name: 'G26 an error that reaches a sink ends that sink for the activation, and the other sinks go on',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-error', (TopologyBuilder b) {
          final TopicStream<int> x = b.read(_in);
          b.write(_out,
              x.map((int v) => v == 2 ? throw StateError('transformer threw') : v));
          b.write(_outB, x.map((int v) => v));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      for (final int v in <int>[1, 2, 3]) {
        run.publish(_in, v);
        await h.settle();
      }
      expect(_payloads(out), <Object?>[1]);
      expect(_payloads(outB), <Object?>[1, 2, 3]);
    },
  ),
  (
    name: 'G26 a reducer that throws ends its reduceInto and the state keeps its last value',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-reduce-error', (TopologyBuilder b) {
          b.reduceInto(_total, b.read(_in),
              (int s, int e) => e < 0 ? throw StateError('negative') : s + e);
        }),
      ]);
      for (final int v in <int>[1, -1, 2]) {
        run.publish(_in, v);
        await h.settle();
      }
      expect(run.current(_total), 6);
    },
  ),
  // ------------------------------------------------------------ G27
  (
    name: 'G27 a stage that feeds several consumers runs once per input value',
    body: (LiveTopologyHarness h) async {
      int maps = 0;
      int calls = 0;
      final LiveRun run = h.start(<Topology>[
        _t('live-share', (TopologyBuilder b) {
          final TopicStream<int> m = b.read(_in).map((int v) {
            maps++;
            return v + 1;
          });
          final TopicStream<int> s = m.switchMap((int v) {
            calls++;
            return Stream<int>.value(v);
          });
          b.write(_out, s);
          b.write(_outB, s.map((int v) => v * 2));
          b.write(_text, m.map((int v) => '$v'));
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      final List<MessageEnvelope<String>> text = run.watch(_text);
      run.publish(_in, 1);
      await h.settle();
      expect(maps, 1);
      expect(calls, 1);
      expect(_payloads(out), <Object?>[2]);
      expect(_payloads(outB), <Object?>[4]);
      expect(_payloads(text), <Object?>['2']);
    },
  ),
  (
    name: 'G27 one value written by several sinks is delivered in sink declaration order',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-fanout', (TopologyBuilder b) {
          final TopicStream<int> x = b.read(_in).map((int v) => v);
          b.write(_outB, x);
          b.write(_out, x);
        }),
      ]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      run.publish(_in, 1);
      await h.settle();
      expect(run.deliveries.map((MessageEnvelope<Object?> e) => e.id),
          <String>[outB.single.id, out.single.id]);
    },
  ),
  // ------------------------------------------------------------ G28
  (
    name: 'G28 the raw operator is called once per activation and its values and lineages go downstream',
    body: (LiveTopologyHarness h) async {
      int calls = 0;
      final LiveRun run = h.start(<Topology>[
        _t('live-raw', (TopologyBuilder b) {
          b.write(
              _out,
              b.read(_in).rawEngine<int>(
                  (Stream<PipelineValue<int>> values, String Function() fresh) {
                calls++;
                return values.map((PipelineValue<int> v) =>
                    (payload: v.payload * 3, lineage: v.lineage));
              }));
        }),
      ]);
      final List<MessageEnvelope<int>> input = run.watch(_in);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      run.publish(_in, 2);
      await h.settle();
      expect(calls, 1);
      expect(_payloads(out), <Object?>[3, 6]);
      expect(out[0].causationId, input[0].id);
    },
  ),
  (
    name: 'G28 a raw operator that builds a lineage, with the fresh correlation it is given, has it published',
    body: (LiveTopologyHarness h) async {
      final LiveRun run = h.start(<Topology>[
        _t('live-raw-lineage', (TopologyBuilder b) {
          b.write(
              _out,
              b.read(_in).rawEngine<int>(
                  (Stream<PipelineValue<int>> values, String Function() fresh) =>
                      values.map((PipelineValue<int> v) => (
                            payload: v.payload,
                            lineage: Lineage.combine(
                              <Lineage>[
                                v.lineage,
                                const Lineage.root(correlationId: 'side-flow'),
                              ],
                              trigger: 0,
                              freshCorrelationId: fresh,
                            ),
                          ))));
        }),
      ]);
      final List<MessageEnvelope<int>> input = run.watch(_in);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      run.publish(_in, 1);
      await h.settle();
      expect(out.single.causationId, input.single.id);
      expect(out.single.parentCorrelationIds,
          <String>[input.single.correlationId, 'side-flow']);
      expect(out.single.correlationId,
          isNot(anyOf(input.single.correlationId, 'side-flow')));
    },
  ),
  // ------------------------------------------------------------ G29
  (
    name: 'G29 a deactivated topology publishes nothing and has cancelled its inner subscriptions and timers',
    body: (LiveTopologyHarness h) async {
      final _Inner inner = _Inner();
      final Topology t = _t('live-deactivate', (TopologyBuilder b) {
        b.write(_out, b.read(_in).debounce(_ms100));
        b.write(_outB, b.read(_inB).switchMap((int v) => inner.stream));
      });
      final LiveRun run = h.start(<Topology>[t]);
      final List<MessageEnvelope<int>> out = run.watch(_out);
      final List<MessageEnvelope<int>> outB = run.watch(_outB);
      run.publish(_inB, 1);
      run.advance(Duration.zero);
      expect(inner.listens, 1);
      run.publish(_in, 1);
      run.deactivate(t);
      expect(inner.cancels, 1);
      run.advance(_ms100 * 2);
      run.publish(_in, 2);
      run.advance(_ms100 * 2);
      await h.settle();
      expect(out, isEmpty);
      expect(outB, isEmpty);
    },
  ),
];
