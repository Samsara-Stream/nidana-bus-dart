// Conformance library for topology-dsl@v2, recording side (ADR-001 item 4):
// what recording a declaration produces (G9 to G17 and G30). Its cases are
// values; a binding registers them with a test runner. It imports neither
// package:test nor package:flutter_test.
//
// The implementation under test is the package's own recording builder,
// which the cases reach through planOf and buildDefinition: recording has
// one implementation by design (TopologyBuilder is final), so the harness
// carries no factory, only the settle step ADR-001 requires (a no-op, since
// recording is synchronous and pure).
import 'dart:async';

import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';

/// What a binding supplies.
abstract interface class RecordingHarness {
  /// Brings the implementation to quiescence; recording is always there.
  Future<void> settle();
}

// ------------------------------------------------------------ topics

const StateTopic<int> _count = StateTopic<int>(name: 'rec.count', initial: 0);
const StateTopic<int> _total = StateTopic<int>(name: 'rec.total', initial: 0);
const StateTopic<String> _label =
    StateTopic<String>(name: 'rec.label', initial: '');
const StateTopic<bool> _flag = StateTopic<bool>(name: 'rec.flag', initial: false);
const EventTopic<int> _taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<int> _out = EventTopic<int>(name: 'rec.out');
const ReplayTopic<int> _log = ReplayTopic<int>(name: 'rec.log', bufferSize: 3);
const EventTopic<Object?> _any = EventTopic<Object?>(name: 'rec.any');

// ------------------------------------------------------------ helpers

/// Counts declare() runs of the topologies built by [_counted].
int _declarations = 0;

final class _Counted extends Topology {
  const _Counted();

  @override
  String get topologyId => 'rec-counted';

  @override
  Scope get scope => Scope.module;

  @override
  void declare(TopologyBuilder b) {
    _declarations++;
    b.write(_out, b.read(_taps));
  }
}

final class _Unnamed extends Topology {
  const _Unnamed();

  @override
  String get topologyId => '';

  @override
  Scope get scope => Scope.page;

  @override
  void declare(TopologyBuilder b) {}
}

Never _called(String what) => throw StateError('recording called $what');

int _transform(int v) => _called('a transformer');
bool _test(int v) => _called('a predicate');
int _combine2(int a, int b) => _called('a combiner');
int _combine3(int a, int b, int c) => _called('a combiner');
int _combine4(int a, int b, int c, int d) => _called('a combiner');
int _combineAll(List<int> values) => _called('a combiner');
int _latest1(int v, int a) => _called('a combiner');
int _latest2(int v, int a, int b) => _called('a combiner');
int _latest3(int v, int a, int b, int c) => _called('a combiner');
Stream<int> _toStream(int v) => _called('a stream factory');
Duration? _retry(Object error, int attempt) => _called('a retry policy');
int _accumulate(int acc, int v) => _called('an accumulator');
int _recover(Object error, StackTrace stackTrace) => _called('a recover function');
int _reduce(int state, int event) => _called('a reducer');
Stream<PipelineValue<int>> _raw(
  Stream<PipelineValue<int>> values,
  String Function() freshCorrelationId,
) =>
    _called('a raw operator');

/// The handles and arguments of [_everyCombinator]'s last declaration.
final class _Captured {
  late TopicStream<int> count;
  late TopicStream<int> taps;
  late TopicStream<bool> flag;
  late TopicStream<int> mapped;
  late TopicStream<int> filtered;
  late TopicStream<int> c2;
  late TopicStream<int> c3;
  late TopicStream<int> c4;
  late TopicStream<int> cAll;
  late TopicStream<int> w1;
  late TopicStream<int> w2;
  late TopicStream<int> w3;
  late TopicStream<int> merged;
  late TopicStream<int> switched;
  late TopicStream<int> retried;
  late TopicStream<int> scanned;
  late TopicStream<({int previous, int current})> pairs;
  late TopicStream<int> distinct;
  late TopicStream<int> debounced;
  late TopicStream<int> throttled;
  late TopicStream<int> delayed;
  late TopicStream<int> sampled;
  late TopicStream<List<int>> buffered;
  late TopicStream<int> timed;
  late TopicStream<int> caught;
  late TopicStream<int> raw;
}

/// One call of every combinator, then a write, a reduceInto and a second
/// write, so that every stage reaches a sink.
Topology _everyCombinator(_Captured c) => topology(
      'rec-every',
      Scope.module,
      (TopologyBuilder b) {
        c.count = b.read(_count);
        c.taps = b.read(_taps);
        c.flag = b.read(_flag, dedup: Dedup.none);
        c.mapped = c.count.map(_transform);
        c.filtered = c.mapped.filter(_test);
        c.c2 = b.combine2(c.count, c.taps, _combine2);
        c.c3 = b.combine3(c.count, c.taps, c.c2, _combine3);
        c.c4 = b.combine4(c.count, c.taps, c.c2, c.c3, _combine4);
        c.cAll = b.combineAll(<TopicStream<int>>[c.c4, c.c3], _combineAll);
        c.w1 = c.cAll.withLatestFrom(c.count, _latest1);
        c.w2 = c.w1.withLatestFrom2(c.count, c.taps, _latest2);
        c.w3 = c.w2.withLatestFrom3(c.count, c.taps, c.c2, _latest3);
        c.merged = b.merge(<TopicStream<int>>[c.w3, c.filtered]);
        c.switched = c.merged.switchMap(_toStream);
        c.retried = c.merged.switchMap(_toStream, retry: _retry);
        c.scanned = b.combine3(c.switched, c.retried, c.flag,
            (int x, int y, bool on) => on ? x : y).scan(7, _accumulate);
        c.pairs = c.scanned.pairwise();
        c.distinct = c.scanned.distinctUntilChanged();
        c.debounced = c.distinct.debounce(const Duration(milliseconds: 1));
        c.throttled = c.debounced.throttle(const Duration(milliseconds: 2));
        c.delayed = c.throttled.delay(const Duration(milliseconds: 3));
        c.sampled = c.delayed.sample(const Duration(milliseconds: 4));
        c.buffered = c.sampled.buffer(const Duration(milliseconds: 5));
        c.timed = c.sampled.timeout(const Duration(milliseconds: 6));
        c.caught = c.timed.catchError(_recover);
        c.raw = c.caught.rawEngine(_raw);
        b.write(_out, c.raw);
        b.reduceInto(_total, c.taps, _reduce);
        b.write(_log, c.buffered.map((List<int> xs) => xs.length));
        b.write(_label, c.pairs.map((({int previous, int current}) p) => '$p'));
      },
    );

/// Records the stage classes a visitor is called for, and the stages.
final class _Names implements StageVisitor<String> {
  final List<TopicStream<Object?>> seen = <TopicStream<Object?>>[];

  String _saw(TopicStream<Object?> s, String name) {
    seen.add(s);
    return name;
  }

  @override
  String read<T>(ReadStage<T> s) => _saw(s, 'read');
  @override
  String map<T, R>(MapStage<T, R> s) => _saw(s, 'map');
  @override
  String filter<T>(FilterStage<T> s) => _saw(s, 'filter');
  @override
  String combine<R>(CombineStage<R> s) => _saw(s, 'combine');
  @override
  String withLatestFrom<T, R>(WithLatestFromStage<T, R> s) =>
      _saw(s, 'withLatestFrom');
  @override
  String merge<T>(MergeStage<T> s) => _saw(s, 'merge');
  @override
  String switchMap<T, R>(SwitchMapStage<T, R> s) => _saw(s, 'switchMap');
  @override
  String scan<T, S>(ScanStage<T, S> s) => _saw(s, 'scan');
  @override
  String pairwise<T>(PairwiseStage<T> s) => _saw(s, 'pairwise');
  @override
  String distinctUntilChanged<T>(DistinctUntilChangedStage<T> s) =>
      _saw(s, 'distinctUntilChanged');
  @override
  String debounce<T>(DebounceStage<T> s) => _saw(s, 'debounce');
  @override
  String throttle<T>(ThrottleStage<T> s) => _saw(s, 'throttle');
  @override
  String delay<T>(DelayStage<T> s) => _saw(s, 'delay');
  @override
  String sample<T>(SampleStage<T> s) => _saw(s, 'sample');
  @override
  String buffer<T>(BufferStage<T> s) => _saw(s, 'buffer');
  @override
  String timeout<T>(TimeoutStage<T> s) => _saw(s, 'timeout');
  @override
  String catchError<T>(CatchErrorStage<T> s) => _saw(s, 'catchError');
  @override
  String rawEngine<T, R>(RawEngineStage<T, R> s) => _saw(s, 'rawEngine');
}

final class _SinkNames implements SinkVisitor<String> {
  final List<PlanSink> seen = <PlanSink>[];

  @override
  String write<T>(WriteSink<T> sink) {
    seen.add(sink);
    return 'write';
  }

  @override
  String reduceInto<S, E>(ReduceIntoSink<S, E> sink) {
    seen.add(sink);
    return 'reduceInto';
  }
}

const List<String> _everyStageInOrder = <String>[
  'read', 'read', 'read', 'map', 'filter', //
  'combine', 'combine', 'combine', 'combine', //
  'withLatestFrom', 'withLatestFrom', 'withLatestFrom', 'merge', //
  'switchMap', 'switchMap', 'combine', 'scan', 'pairwise', //
  'distinctUntilChanged', 'debounce', 'throttle', 'delay', 'sample', //
  'buffer', 'timeout', 'catchError', 'rawEngine', 'map', 'map',
];

/// A handle made by one declaration, kept for use in another.
TopicStream<int>? _stashed;
TopologyBuilder? _stashedBuilder;

Topology _stashing() => topology('rec-stash', Scope.page, (TopologyBuilder b) {
      final TopicStream<int> taps = b.read(_taps);
      _stashed = taps;
      _stashedBuilder = b;
      b.write(_out, taps);
    });

/// A declaration that hands [_stashed] to [use].
Topology _foreign(void Function(TopologyBuilder b, TopicStream<int> foreign) use) =>
    topology('rec-foreign', Scope.page, (TopologyBuilder b) {
      use(b, _stashed!);
    });

void _primeStash() {
  planOf(_stashing());
}

Topology _single(void Function(TopologyBuilder b) body) =>
    topology('rec-single', Scope.page, body);

final List<ConformanceCase<RecordingHarness>> recordingConformance =
    <ConformanceCase<RecordingHarness>>[
  // ------------------------------------------------------------ G9
  (
    name: 'G9 planOf runs declare once against a fresh builder and carries the id and scope',
    body: (RecordingHarness h) async {
      const Topology t = _Counted();
      final int before = _declarations;
      final TopologyPlan first = planOf(t);
      expect(_declarations, before + 1);
      final TopologyPlan second = planOf(t);
      await h.settle();
      expect(_declarations, before + 2);
      expect(first.topologyId, 'rec-counted');
      expect(first.scope, Scope.module);
      expect(identical(first.stages.first, second.stages.first), isFalse);
    },
  ),
  (
    name: 'G9 buildDefinition runs declare once and equals the definition of a fresh plan',
    body: (RecordingHarness h) async {
      const Topology t = _Counted();
      final int before = _declarations;
      final TopologyDefinition definition = t.buildDefinition();
      expect(_declarations, before + 1);
      await h.settle();
      expect(definition, equals(planOf(t).definition));
      expect(definition, equals(t.buildDefinition()));
    },
  ),
  (
    name: 'G9 the builder form runs its body on each planOf call and never at construction',
    body: (RecordingHarness h) async {
      int runs = 0;
      final Topology t = topology('rec-form', Scope.application,
          (TopologyBuilder b) {
        runs++;
        b.write(_out, b.read(_taps));
      });
      expect(runs, 0);
      expect(t.topologyId, 'rec-form');
      expect(t.scope, Scope.application);
      planOf(t);
      planOf(t);
      await h.settle();
      expect(runs, 2);
    },
  ),
  // ------------------------------------------------------------ G10
  (
    name: 'G10 recording calls none of the functions a declaration passes',
    body: (RecordingHarness h) async {
      final _Captured c = _Captured();
      final TopologyPlan plan = planOf(_everyCombinator(c));
      final TopologyDefinition definition = _everyCombinator(c).buildDefinition();
      await h.settle();
      expect(plan.stages, hasLength(_everyStageInOrder.length));
      expect(definition.topologyId, 'rec-every');
    },
  ),
  (
    name: 'G10 recording creates no timer and schedules no microtask',
    body: (RecordingHarness h) async {
      int scheduled = 0;
      runZoned(
        () {
          planOf(_everyCombinator(_Captured()));
          _everyCombinator(_Captured()).buildDefinition();
        },
        zoneSpecification: ZoneSpecification(
          createTimer: (Zone self, ZoneDelegate parent, Zone zone,
              Duration duration, void Function() f) {
            scheduled++;
            return parent.createTimer(zone, duration, f);
          },
          createPeriodicTimer: (Zone self, ZoneDelegate parent, Zone zone,
              Duration period, void Function(Timer timer) f) {
            scheduled++;
            return parent.createPeriodicTimer(zone, period, f);
          },
          scheduleMicrotask:
              (Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
            scheduled++;
            parent.scheduleMicrotask(zone, f);
          },
        ),
      );
      await h.settle();
      expect(scheduled, 0);
    },
  ),
  // ------------------------------------------------------------ G11
  (
    name: 'G11 each combinator call adds one stage, in call order, of its combinator class',
    body: (RecordingHarness h) async {
      final TopologyPlan plan = planOf(_everyCombinator(_Captured()));
      final _Names names = _Names();
      final List<String> kinds = <String>[
        for (final TopicStream<Object?> s in plan.stages) visitStage(s, names),
      ];
      await h.settle();
      expect(kinds, equals(_everyStageInOrder));
      expect(plan.stages[0], isA<ReadStage<int>>());
      expect(plan.stages[3], isA<MapStage<int, int>>());
      expect(plan.stages[5], isA<CombineStage<int>>());
      expect(plan.stages[9], isA<WithLatestFromStage<int, int>>());
      expect(plan.stages[13], isA<SwitchMapStage<int, int>>());
      expect(plan.stages[15], isA<CombineStage<int>>());
      expect(plan.stages[16], isA<ScanStage<int, int>>());
      expect(plan.stages[17], isA<PairwiseStage<int>>());
      expect(plan.stages[23], isA<BufferStage<int>>());
      expect(plan.stages[26], isA<RawEngineStage<int, int>>());
    },
  ),
  (
    name: 'G11 a stage holds the handles, functions and durations it was given',
    body: (RecordingHarness h) async {
      final _Captured c = _Captured();
      planOf(_everyCombinator(c));
      await h.settle();
      final ReadStage<int> count = c.count as ReadStage<int>;
      expect(count.topic, equals(_count));
      final MapStage<int, int> mapped = c.mapped as MapStage<int, int>;
      expect(identical(mapped.input, c.count), isTrue);
      expect(mapped.transform, same(_transform));
      final FilterStage<int> filtered = c.filtered as FilterStage<int>;
      expect(identical(filtered.input, c.mapped), isTrue);
      expect(filtered.test, same(_test));
      final CombineStage<int> c3 = c.c3 as CombineStage<int>;
      expect(c3.inputs, hasLength(3));
      expect(identical(c3.inputs[0], c.count), isTrue);
      expect(identical(c3.inputs[1], c.taps), isTrue);
      expect(identical(c3.inputs[2], c.c2), isTrue);
      expect(c3.combiner, same(_combine3));
      final CombineStage<int> all = c.cAll as CombineStage<int>;
      expect(identical(all.inputs[0], c.c4), isTrue);
      expect(all.combiner, same(_combineAll));
      final WithLatestFromStage<int, int> w2 =
          c.w2 as WithLatestFromStage<int, int>;
      expect(identical(w2.primary, c.w1), isTrue);
      expect(w2.latest, hasLength(2));
      expect(identical(w2.latest[1], c.taps), isTrue);
      expect(w2.combiner, same(_latest2));
      final MergeStage<int> merged = c.merged as MergeStage<int>;
      expect(identical(merged.inputs[1], c.filtered), isTrue);
      final SwitchMapStage<int, int> switched =
          c.switched as SwitchMapStage<int, int>;
      expect(switched.toStream, same(_toStream));
      expect(switched.retry, isNull);
      expect((c.retried as SwitchMapStage<int, int>).retry, same(_retry));
      final ScanStage<int, int> scanned = c.scanned as ScanStage<int, int>;
      expect(scanned.initial, 7);
      expect(scanned.accumulator, same(_accumulate));
      expect((c.debounced as DebounceStage<int>).duration,
          const Duration(milliseconds: 1));
      expect((c.throttled as ThrottleStage<int>).duration,
          const Duration(milliseconds: 2));
      expect((c.delayed as DelayStage<int>).duration,
          const Duration(milliseconds: 3));
      expect((c.sampled as SampleStage<int>).duration,
          const Duration(milliseconds: 4));
      expect((c.buffered as BufferStage<int>).duration,
          const Duration(milliseconds: 5));
      expect((c.timed as TimeoutStage<int>).duration,
          const Duration(milliseconds: 6));
      expect((c.caught as CatchErrorStage<int>).recover, same(_recover));
      expect((c.raw as RawEngineStage<int, int>).operator, same(_raw));
    },
  ),
  (
    name: 'G11 sinks list the write and reduceInto calls in call order with their topics and inputs',
    body: (RecordingHarness h) async {
      final _Captured c = _Captured();
      final TopologyPlan plan = planOf(_everyCombinator(c));
      final _SinkNames names = _SinkNames();
      final List<String> kinds = <String>[
        for (final PlanSink s in plan.sinks) visitSink(s, names),
      ];
      await h.settle();
      expect(kinds, equals(<String>['write', 'reduceInto', 'write', 'write']));
      expect(plan.sinks.map((PlanSink s) => s.topic),
          equals(<Topic<Object?>>[_out, _total, _log, _label]));
      final WriteSink<int> first = plan.sinks[0] as WriteSink<int>;
      expect(identical(first.input, c.raw), isTrue);
      final ReduceIntoSink<int, int> fold =
          plan.sinks[1] as ReduceIntoSink<int, int>;
      expect(identical(fold.events, c.taps), isTrue);
      expect(fold.reducer, same(_reduce));
    },
  ),
  (
    name: 'G11 the arity forms of combine and withLatestFrom apply the transformer to values in input order',
    body: (RecordingHarness h) async {
      late TopicStream<String> c2;
      late TopicStream<String> c4;
      late TopicStream<String> all;
      late TopicStream<String> w3;
      planOf(_single((TopologyBuilder b) {
        final TopicStream<int> a = b.read(_count);
        final TopicStream<int> t = b.read(_taps);
        c2 = b.combine2(a, t, (int x, int y) => '$x$y');
        c4 = b.combine4(a, t, a, t, (int w, int x, int y, int z) => '$w$x$y$z');
        all = b.combineAll(<TopicStream<int>>[a, t, a],
            (List<int> xs) => xs.join());
        w3 = a.withLatestFrom3(
            t, a, t, (int v, int x, int y, int z) => '$v$x$y$z');
        b.write(_label, b.merge(<TopicStream<String>>[c2, c4, all, w3]));
      }));
      await h.settle();
      expect((c2 as CombineStage<String>).apply(<Object?>[1, 2]), '12');
      expect((c4 as CombineStage<String>).apply(<Object?>[1, 2, 3, 4]), '1234');
      expect((all as CombineStage<String>).apply(<Object?>[5, 6, 7]), '567');
      expect(
          (w3 as WithLatestFromStage<int, String>).apply(9, <Object?>[1, 2, 3]),
          '9123');
    },
  ),
  (
    name: 'G11 the stage and sink lists of a plan are unmodifiable',
    body: (RecordingHarness h) async {
      final TopologyPlan plan = planOf(const _Counted());
      await h.settle();
      expect(() => plan.stages.add(plan.stages.first), throwsUnsupportedError);
      expect(() => plan.sinks.clear(), throwsUnsupportedError);
    },
  ),
  // ------------------------------------------------------------ G12
  (
    name: 'G12 the definition reads the topics of the read stages and writes the topics of the sinks',
    body: (RecordingHarness h) async {
      final TopologyDefinition d =
          _everyCombinator(_Captured()).buildDefinition();
      await h.settle();
      expect(d.topologyId, 'rec-every');
      expect(d.scope, Scope.module);
      expect(d.reads, equals(<TopicRef>{_count.ref, _taps.ref, _flag.ref}));
      expect(d.writes,
          equals(<TopicRef>{_out.ref, _total.ref, _log.ref, _label.ref}));
    },
  ),
  (
    name: 'G12 a topic read twice is read once, and a declaration with no stages reads and writes nothing',
    body: (RecordingHarness h) async {
      final TopologyDefinition twice = _single((TopologyBuilder b) {
        b.write(_out, b.merge(<TopicStream<int>>[b.read(_taps), b.read(_taps)]));
      }).buildDefinition();
      final TopologyDefinition empty =
          topology('rec-empty', Scope.page, (TopologyBuilder b) {})
              .buildDefinition();
      await h.settle();
      expect(twice.reads, equals(<TopicRef>{_taps.ref}));
      expect(empty.reads, isEmpty);
      expect(empty.writes, isEmpty);
    },
  ),
  // ------------------------------------------------------------ G13
  (
    name: 'G13 a read records its dedup argument, null when none is given',
    body: (RecordingHarness h) async {
      final _Captured c = _Captured();
      planOf(_everyCombinator(c));
      await h.settle();
      expect((c.count as ReadStage<int>).dedup, isNull);
      expect((c.flag as ReadStage<bool>).dedup, Dedup.none);
    },
  ),
  (
    name: 'G13 a dedup argument on an event or replay topic read throws ArgumentError',
    body: (RecordingHarness h) async {
      await h.settle();
      expect(
          () => planOf(_single((TopologyBuilder b) =>
              b.write(_out, b.read(_taps, dedup: Dedup.none)))),
          throwsArgumentError);
      expect(
          () => planOf(_single((TopologyBuilder b) =>
              b.write(_out, b.read(_log, dedup: Dedup.equality)))),
          throwsArgumentError);
      expect(
          planOf(_single((TopologyBuilder b) =>
                  b.write(_out, b.read(_count, dedup: Dedup.equality))))
              .stages,
          hasLength(1));
    },
  ),
  // ------------------------------------------------------------ G14
  (
    name: 'G14 a handle made by another declaration throws ArgumentError wherever it is passed',
    body: (RecordingHarness h) async {
      _primeStash();
      await h.settle();
      final List<void Function(TopologyBuilder b, TopicStream<int> f)> uses =
          <void Function(TopologyBuilder b, TopicStream<int> f)>[
        (TopologyBuilder b, TopicStream<int> f) => b.write(_out, f),
        (TopologyBuilder b, TopicStream<int> f) =>
            b.reduceInto(_total, f, (int s, int e) => s),
        (TopologyBuilder b, TopicStream<int> f) =>
            b.combine2(b.read(_taps), f, (int x, int y) => x),
        (TopologyBuilder b, TopicStream<int> f) =>
            b.combineAll(<TopicStream<int>>[f], (List<int> xs) => 0),
        (TopologyBuilder b, TopicStream<int> f) =>
            b.merge(<TopicStream<int>>[b.read(_taps), f]),
        (TopologyBuilder b, TopicStream<int> f) =>
            b.read(_taps).withLatestFrom(f, (int x, int y) => x),
      ];
      for (final void Function(TopologyBuilder b, TopicStream<int> f) use
          in uses) {
        expect(() => planOf(_foreign(use)), throwsArgumentError);
      }
    },
  ),
  (
    name: 'G14 a second sink on one StateTopic throws ArgumentError; event and replay topics take any number',
    body: (RecordingHarness h) async {
      await h.settle();
      expect(
          () => planOf(_single((TopologyBuilder b) {
                b.write(_count, b.read(_taps));
                b.write(_count, b.read(_taps));
              })),
          throwsArgumentError);
      expect(
          () => planOf(_single((TopologyBuilder b) {
                b.reduceInto(_count, b.read(_taps), (int s, int e) => s + e);
                b.write(_count, b.read(_taps));
              })),
          throwsArgumentError);
      final TopologyPlan many = planOf(_single((TopologyBuilder b) {
        b.write(_out, b.read(_taps));
        b.write(_out, b.read(_taps));
        b.write(_log, b.read(_taps));
        b.write(_log, b.read(_taps));
      }));
      expect(many.sinks, hasLength(4));
    },
  ),
  (
    name: 'G14 a negative duration throws ArgumentError and a zero duration is accepted',
    body: (RecordingHarness h) async {
      await h.settle();
      const Duration negative = Duration(microseconds: -1);
      final List<TopicStream<Object?> Function(TopicStream<int> s)> timed =
          <TopicStream<Object?> Function(TopicStream<int> s)>[
        (TopicStream<int> s) => s.debounce(negative),
        (TopicStream<int> s) => s.throttle(negative),
        (TopicStream<int> s) => s.delay(negative),
        (TopicStream<int> s) => s.sample(negative),
        (TopicStream<int> s) => s.buffer(negative),
        (TopicStream<int> s) => s.timeout(negative),
      ];
      for (final TopicStream<Object?> Function(TopicStream<int> s) f in timed) {
        expect(
            () => planOf(_single(
                (TopologyBuilder b) => b.write(_any, f(b.read(_taps))))),
            throwsArgumentError);
      }
      expect(
          planOf(_single((TopologyBuilder b) =>
                  b.write(_out, b.read(_taps).debounce(Duration.zero))))
              .stages,
          hasLength(2));
    },
  ),
  (
    name: 'G14 an empty input list throws ArgumentError',
    body: (RecordingHarness h) async {
      await h.settle();
      expect(
          () => planOf(_single((TopologyBuilder b) => b.write(
              _out,
              b.combineAll(<TopicStream<int>>[], (List<int> xs) => 0)))),
          throwsArgumentError);
      expect(
          () => planOf(_single((TopologyBuilder b) =>
              b.write(_out, b.merge(<TopicStream<int>>[])))),
          throwsArgumentError);
    },
  ),
  // ------------------------------------------------------------ G15
  (
    name: 'G15 planOf throws StateError when a stage reaches no sink',
    body: (RecordingHarness h) async {
      await h.settle();
      expect(
          () => planOf(_single((TopologyBuilder b) {
                b.read(_taps);
              })),
          throwsStateError);
      expect(
          () => planOf(_single((TopologyBuilder b) {
                final TopicStream<int> taps = b.read(_taps);
                taps.map((int v) => v + 1);
                b.write(_out, taps);
              })),
          throwsStateError);
    },
  ),
  (
    name: 'G15 an empty topology id fails: ArgumentError from topology(), StateError from planOf',
    body: (RecordingHarness h) async {
      await h.settle();
      expect(() => topology('', Scope.page, (TopologyBuilder b) {}),
          throwsArgumentError);
      expect(() => planOf(const _Unnamed()), throwsStateError);
      expect(() => const _Unnamed().buildDefinition(), throwsStateError);
    },
  ),
  (
    name: 'G15 a builder or a handle used after declare returned throws StateError',
    body: (RecordingHarness h) async {
      _primeStash();
      await h.settle();
      final TopicStream<int> kept = _stashed!;
      final TopologyBuilder closed = _stashedBuilder!;
      expect(() => kept.map((int v) => v), throwsStateError);
      expect(() => kept.debounce(Duration.zero), throwsStateError);
      expect(() => closed.read(_taps), throwsStateError);
      expect(() => closed.write(_out, kept), throwsStateError);
      expect(() => closed.merge(<TopicStream<int>>[kept]), throwsStateError);
    },
  ),
  // ------------------------------------------------------------ G16
  (
    name: 'G16 visitStage and visitSink pass each stage and sink to the method of its class',
    body: (RecordingHarness h) async {
      final TopologyPlan plan = planOf(_everyCombinator(_Captured()));
      final _Names names = _Names();
      final _SinkNames sinkNames = _SinkNames();
      for (final TopicStream<Object?> s in plan.stages) {
        visitStage(s, names);
      }
      for (final PlanSink s in plan.sinks) {
        visitSink(s, sinkNames);
      }
      await h.settle();
      expect(names.seen, hasLength(plan.stages.length));
      for (int i = 0; i < plan.stages.length; i++) {
        expect(identical(names.seen[i], plan.stages[i]), isTrue);
      }
      for (int i = 0; i < plan.sinks.length; i++) {
        expect(identical(sinkNames.seen[i], plan.sinks[i]), isTrue);
      }
    },
  ),
  // ------------------------------------------------------------ G17
  (
    name: 'G17 topology references are equal, with equal hash codes, exactly when their ids are',
    body: (RecordingHarness h) async {
      const TopologyRef a = TopologyRef('checkout-flow');
      await h.settle();
      expect(a, equals(TopologyRef('checkout-flow')));
      expect(a.hashCode, TopologyRef('checkout-flow').hashCode);
      expect(a == const TopologyRef('checkout-cart'), isFalse);
      expect(a.id, 'checkout-flow');
    },
  ),
  // ------------------------------------------------------------ G30
  (
    name: 'G30 stages, sinks, builders and plans are equal only when identical, with identity hash codes',
    body: (RecordingHarness h) async {
      final List<TopologyBuilder> builders = <TopologyBuilder>[];
      final Topology t = topology('rec-identity', Scope.page, (TopologyBuilder b) {
        builders.add(b);
        final TopicStream<int> first = b.read(_taps);
        final TopicStream<int> second = b.read(_taps);
        b.write(_out, first);
        b.write(_out, first);
        b.write(_out, second);
      });
      final TopologyPlan plan = planOf(t);
      final TopologyPlan again = planOf(t);
      await h.settle();
      expect(plan.stages, hasLength(2));
      expect(plan.stages[0] == plan.stages[1], isFalse);
      expect(plan.sinks, hasLength(3));
      expect(plan.sinks[0] == plan.sinks[1], isFalse);
      expect(plan == again, isFalse);
      expect(builders, hasLength(2));
      expect(builders[0] == builders[1], isFalse);
      for (final Object o in <Object>[...plan.stages, ...plan.sinks, plan, builders.first]) {
        expect(o.hashCode, identityHashCode(o));
      }
    },
  ),
];
