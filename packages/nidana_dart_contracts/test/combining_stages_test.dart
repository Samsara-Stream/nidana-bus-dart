// topology-dsl@v2's multi-input calls and reduceInto, beyond the cases of
// its recording suite: inputs held in order as unmodifiable copies, apply at
// the declaration's own types, the misuse checks of G14 and G15 at the call
// that commits them, and G10: recording every combinator calls nothing and
// schedules nothing.
import 'dart:async';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

const StateTopic<int> count = StateTopic<int>(name: 'rec.count', initial: 0);
const StateTopic<String> label = StateTopic<String>(
  name: 'rec.label',
  initial: '',
);
const EventTopic<int> taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<String> words = EventTopic<String>(name: 'rec.words');
const EventTopic<Object?> any = EventTopic<Object?>(name: 'rec.any');

/// One combiner of each arity, held in lists so that each test reads the
/// very object it passed.
final List<String Function(int, String)> pairs = <String Function(int, String)>[
  (int a, String b) => '$a$b',
];
final List<String Function(int, String, bool)> triples =
    <String Function(int, String, bool)>[(int a, String b, bool c) => '$a$b$c'];
final List<String Function(List<int>)> joins = <String Function(List<int>)>[
  (List<int> values) => values.join(','),
];

Topology declared(void Function(TopologyBuilder b) body) =>
    topology('rec-combining', Scope.page, body);

/// An ArgumentError that is not a RangeError: the length check of apply
/// rejected the call, rather than a read past the end of the value list.
final Matcher rejectedByLengthCheck = throwsA(
  allOf(isA<ArgumentError>(), isNot(isA<RangeError>())),
);

/// How many timers, periodic timers and microtasks [body] makes.
int scheduledBy(void Function() body) {
  int scheduled = 0;
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, f) {
        scheduled++;
        return parent.createTimer(zone, duration, f);
      },
      createPeriodicTimer: (self, parent, zone, period, f) {
        scheduled++;
        return parent.createPeriodicTimer(zone, period, f);
      },
      scheduleMicrotask: (self, parent, zone, f) {
        scheduled++;
        parent.scheduleMicrotask(zone, f);
      },
    ),
  );
  return scheduled;
}

/// A call wired from fresh reads: `inputs` of them, taken from `input`.
typedef _Wiring = ({
  int inputs,
  void Function(TopologyBuilder b, TopicStream<int> Function() input) wire,
});

/// A call given a handle of the builder and a handle another builder made.
typedef _Misuse = Object? Function(
  TopologyBuilder b,
  TopicStream<int> own,
  TopicStream<int> foreign,
);

Never _called(String what) => throw StateError('recording called $what');

void main() {
  test('G11 combine, withLatestFrom and merge stages hold their inputs in '
      'order and their combiner', () {
    late TopicStream<int> t;
    late TopicStream<String> w;
    late TopicStream<bool> f;
    late TopicStream<String> c2;
    late TopicStream<String> w2;
    late TopicStream<int> m;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        t = b.read(taps);
        w = b.read(words);
        f = t.map((int v) => v > 0);
        c2 = b.combine2(t, w, pairs[0]);
        w2 = t.withLatestFrom2(w, f, triples[0]);
        m = b.merge(<TopicStream<int>>[t, t]);
        b.write(words, b.merge(<TopicStream<String>>[c2, w2]));
        b.write(taps, m);
      }),
    );
    expect(plan.stages, hasLength(7));
    final CombineStage<String> combine = c2 as CombineStage<String>;
    expect(combine.inputs, hasLength(2));
    expect(identical(combine.inputs[0], t), isTrue);
    expect(identical(combine.inputs[1], w), isTrue);
    expect(identical(combine.combiner, pairs[0]), isTrue);
    final WithLatestFromStage<int, String> latest =
        w2 as WithLatestFromStage<int, String>;
    expect(identical(latest.primary, t), isTrue);
    expect(identical(latest.latest[0], w), isTrue);
    expect(identical(latest.latest[1], f), isTrue);
    expect(identical(latest.combiner, triples[0]), isTrue);
    final MergeStage<int> merge = m as MergeStage<int>;
    expect(identical(merge.inputs[0], t), isTrue);
    expect(identical(merge.inputs[1], t), isTrue);
    expect(() => combine.inputs.add(t), throwsUnsupportedError);
    expect(() => latest.latest.clear(), throwsUnsupportedError);
    expect(() => merge.inputs.add(t), throwsUnsupportedError);
  });

  test(
    'G11 combineAll and merge copy the input list the declaration passed',
    () {
      late TopicStream<int> first;
      late TopicStream<String> all;
      late TopicStream<int> merged;
      planOf(
        declared((TopologyBuilder b) {
          first = b.read(taps);
          final List<TopicStream<int>> inputs = <TopicStream<int>>[first];
          all = b.combineAll(inputs, joins[0]);
          merged = b.merge(inputs);
          inputs.add(first);
          b.write(words, all);
          b.write(taps, merged);
        }),
      );
      final CombineStage<String> combine = all as CombineStage<String>;
      expect(combine.inputs, hasLength(1));
      expect(identical(combine.inputs.single, first), isTrue);
      expect(identical(combine.combiner, joins[0]), isTrue);
      expect((merged as MergeStage<int>).inputs, hasLength(1));
    },
  );

  test('G11 apply calls the combiner at its own types with the values in '
      'input order', () {
    late TopicStream<String> c2;
    late TopicStream<String> all;
    late TopicStream<String> w2;
    List<int>? seen;
    planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        c2 = b.combine2(t, w, pairs[0]);
        all = b.combineAll(<TopicStream<int>>[t, t, t], (List<int> values) {
          seen = values;
          return values.join(',');
        });
        w2 = t.withLatestFrom2(w, t.map((int v) => v.isEven), triples[0]);
        b.write(words, b.merge(<TopicStream<String>>[c2, all, w2]));
      }),
    );
    expect((c2 as CombineStage<String>).apply(<Object?>[1, 'a']), '1a');
    expect((all as CombineStage<String>).apply(<Object?>[3, 1, 2]), '3,1,2');
    expect(seen, isA<List<int>>());
    expect(() => seen!.add(4), throwsUnsupportedError);
    expect(
      (w2 as WithLatestFromStage<int, String>).apply(7, <Object?>['b', true]),
      '7btrue',
    );
  });

  test('G11 apply throws ArgumentError for a value list whose length is not '
      'the number of inputs, and TypeError for a value of another type', () {
    late TopicStream<String> c2;
    late TopicStream<String> all;
    late TopicStream<String> w1;
    planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        c2 = b.combine2(t, w, pairs[0]);
        all = b.combineAll(<TopicStream<int>>[t, t], joins[0]);
        w1 = t.withLatestFrom(w, (int v, String s) => '$v$s');
        b.write(words, b.merge(<TopicStream<String>>[c2, all, w1]));
      }),
    );
    final CombineStage<String> combine = c2 as CombineStage<String>;
    expect(() => combine.apply(<Object?>[1]), throwsArgumentError);
    expect(() => combine.apply(<Object?>[1, 'a', 2]), throwsArgumentError);
    expect(
      () => (all as CombineStage<String>).apply(<Object?>[1, 2, 3]),
      throwsArgumentError,
    );
    expect(
      () => (w1 as WithLatestFromStage<int, String>).apply(1, <Object?>[
        'a',
        'b',
      ]),
      throwsArgumentError,
    );
    expect(() => combine.apply(<Object?>['a', 1]), throwsA(isA<TypeError>()));
    // Too few values are rejected by the length check itself.
    expect(() => combine.apply(<Object?>[1]), rejectedByLengthCheck);
    expect(
      () => (all as CombineStage<String>).apply(<Object?>[1]),
      rejectedByLengthCheck,
    );
    expect(
      () => (w1 as WithLatestFromStage<int, String>).apply(1, <Object?>[]),
      rejectedByLengthCheck,
    );
    // The right length applies the combiner at its declared types.
    expect(
      (w1 as WithLatestFromStage<int, String>).apply(1, <Object?>['a']),
      '1a',
    );
  });

  test('G14 an empty input list throws ArgumentError at the call and adds no '
      'stage', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        expect(
          () => b.combineAll(<TopicStream<int>>[], joins[0]),
          throwsArgumentError,
        );
        expect(() => b.merge(<TopicStream<int>>[]), throwsArgumentError);
        b.write(taps, b.read(taps));
      }),
    );
    expect(plan.stages, hasLength(1));
  });

  test('G14 a handle another declaration made throws ArgumentError in any '
      'input position, and the call adds no stage', () {
    late TopicStream<int> foreign;
    planOf(
      declared((TopologyBuilder b) => b.write(taps, foreign = b.read(taps))),
    );
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        expect(
          () => b.combine3(t, w, foreign, (int a, String b, int c) => a),
          throwsArgumentError,
        );
        expect(
          () => b.combine4(t, t, t, foreign, (int a, int b, int c, int d) => a),
          throwsArgumentError,
        );
        expect(
          () => b.combineAll(<TopicStream<int>>[t, foreign], joins[0]),
          throwsArgumentError,
        );
        expect(
          () => b.merge(<TopicStream<int>>[t, t, foreign]),
          throwsArgumentError,
        );
        expect(
          () => t.withLatestFrom3(
            w,
            t,
            foreign,
            (int v, String a, int b, int c) => v,
          ),
          throwsArgumentError,
        );
        expect(
          () => b.reduceInto(label, foreign, (String s, int e) => s),
          throwsArgumentError,
        );
        b.write(taps, t);
        b.reduceInto(label, w, (String s, String e) => e);
      }),
    );
    expect(plan.stages, hasLength(2));
    expect(plan.sinks, hasLength(2));
  });

  test('G14 a write and a reduceInto on one state topic throw ArgumentError '
      'at the second call, in either order', () {
    for (final bool reduceFirst in <bool>[true, false]) {
      final TopologyPlan plan = planOf(
        declared((TopologyBuilder b) {
          final TopicStream<int> t = b.read(taps);
          void reduce() => b.reduceInto(count, t, (int s, int e) => s + e);
          void write() => b.write(count, t);
          (reduceFirst ? reduce : write)();
          expect(reduceFirst ? write : reduce, throwsArgumentError);
          expect(reduceFirst ? reduce : write, throwsArgumentError);
        }),
      );
      expect(plan.sinks, hasLength(1), reason: 'reduceFirst: $reduceFirst');
    }
  });

  test('G15 every multi-input call and reduceInto throws StateError once its '
      'declaration has returned', () {
    late TopologyBuilder closed;
    late TopicStream<int> kept;
    planOf(
      declared((TopologyBuilder b) {
        closed = b;
        b.write(taps, kept = b.read(taps));
      }),
    );
    final List<Object? Function()> calls = <Object? Function()>[
      () => closed.combine2(kept, kept, (int a, int b) => a),
      () => closed.combine3(kept, kept, kept, (int a, int b, int c) => a),
      () => closed.combine4(
        kept,
        kept,
        kept,
        kept,
        (int a, int b, int c, int d) => a,
      ),
      () => closed.combineAll(<TopicStream<int>>[kept], joins[0]),
      () => closed.combineAll(<TopicStream<int>>[], joins[0]),
      () => closed.merge(<TopicStream<int>>[kept]),
      () => closed.reduceInto(count, kept, (int s, int e) => s),
      () => kept.withLatestFrom(kept, (int a, int b) => a),
      () => kept.withLatestFrom2(kept, kept, (int a, int b, int c) => a),
      () => kept.withLatestFrom3(
        kept,
        kept,
        kept,
        (int a, int b, int c, int d) => a,
      ),
    ];
    for (int i = 0; i < calls.length; i++) {
      expect(calls[i], throwsStateError, reason: '$i');
    }
  });

  test('G10 recording every combinator calls none of its functions, nor a '
      'computed initial value, and creates no timer or microtask', () {
    final StateTopic<int> computed = StateTopic<int>.computed(
      name: 'rec.computed',
      initial: () => _called('a computed initial value'),
    );
    Topology every() => declared((TopologyBuilder b) {
      final TopicStream<int> t = b.read(taps);
      final TopicStream<int> c = b.read(computed, dedup: Dedup.none);
      final TopicStream<int> c2 = b.combine2(
        t,
        c,
        (int a, int b) => _called('a combiner'),
      );
      final TopicStream<int> c3 = b.combine3(
        t,
        c,
        c2,
        (int a, int b, int d) => _called('a combiner'),
      );
      final TopicStream<int> c4 = b.combine4(
        t,
        c,
        c2,
        c3,
        (int a, int b, int d, int e) => _called('a combiner'),
      );
      final TopicStream<int> all = b.combineAll(<TopicStream<int>>[
        c4,
        c3,
      ], (List<int> v) => _called('a combiner'));
      final TopicStream<int> w = all
          .withLatestFrom<int, int>(t, (int v, int a) => _called('a combiner'))
          .withLatestFrom2<int, int, int>(
            t,
            c,
            (int v, int a, int b) => _called('a combiner'),
          )
          .withLatestFrom3<int, int, int, int>(
            t,
            c,
            c2,
            (int v, int a, int b, int d) => _called('a combiner'),
          );
      final TopicStream<int> s = b
          .merge(<TopicStream<int>>[w, t])
          .map<int>((int v) => _called('a transformer'))
          .filter((int v) => _called('a predicate'))
          .switchMap<int>(
            (int v) => _called('a stream factory'),
            retry: (Object e, int n) => _called('a retry policy'),
          )
          .scan<int>(0, (int acc, int v) => _called('an accumulator'))
          .distinctUntilChanged()
          .debounce(const Duration(milliseconds: 1))
          .throttle(const Duration(milliseconds: 1))
          .delay(const Duration(milliseconds: 1))
          .sample(const Duration(milliseconds: 1))
          .timeout(const Duration(milliseconds: 1))
          .catchError(
            (Object e, StackTrace st) => _called('a recover function'),
          )
          .rawEngine<int>(
            (Stream<PipelineValue<int>> v, String Function() fresh) =>
                _called('a raw operator'),
          );
      b.write(any, s.pairwise());
      b.write(any, s.buffer(const Duration(milliseconds: 1)));
      b.reduceInto(count, s, (int st, int e) => _called('a reducer'));
      b.reduceInto(computed, t, (int st, int e) => _called('a reducer'));
    });
    // The counter counts: a timer and a microtask made in its zone.
    expect(
      scheduledBy(() {
        Timer(Duration.zero, () {}).cancel();
        scheduleMicrotask(() {});
      }),
      2,
    );
    late TopologyPlan plan;
    expect(scheduledBy(() => plan = planOf(every())), 0);
    expect(plan.stages, hasLength(24));
    expect(plan.sinks, hasLength(4));
  });

  test('G11 every multi-input call and reduceInto marks each of its inputs '
      'consumed', () {
    for (int i = 0; i < _consuming.length; i++) {
      int reads = 0;
      final TopologyPlan plan = planOf(
        declared((TopologyBuilder b) {
          _consuming[i].wire(b, () {
            reads++;
            return b.read(taps);
          });
        }),
      );
      expect(reads, _consuming[i].inputs, reason: '$i');
      expect(plan.stages.whereType<ReadStage<int>>(), hasLength(reads));
    }
  });

  test('G11 a reduceInto sink holds the topic, the events handle and the '
      'reducer it was given', () {
    final List<int Function(int, int)> reducers = <int Function(int, int)>[
      (int s, int e) => s + e,
    ];
    late TopicStream<int> events;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        events = b.read(taps);
        b.reduceInto(count, events, reducers[0]);
      }),
    );
    final ReduceIntoSink<int, int> sink =
        plan.sinks.single as ReduceIntoSink<int, int>;
    expect(identical(sink.topic, count), isTrue);
    expect(identical(sink.events, events), isTrue);
    expect(identical(sink.reducer, reducers[0]), isTrue);
    expect(plan.stages, hasLength(1));
  });

  test('G11 apply of the three and four input forms reads each value at its '
      'own position and type', () {
    late TopicStream<String> c3;
    late TopicStream<String> c4;
    late TopicStream<String> w3;
    planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        final TopicStream<bool> f = t.map((int v) => v > 0);
        final TopicStream<double> d = t.map((int v) => v / 2);
        c3 = b.combine3(t, w, f, (int a, String s, bool c) => '$a$s$c');
        c4 = b.combine4(
          t,
          w,
          f,
          d,
          (int a, String s, bool c, double e) => '$a$s$c$e',
        );
        w3 = t.withLatestFrom3(
          w,
          f,
          d,
          (int v, String s, bool c, double e) => '$v$s$c$e',
        );
        b.write(words, b.merge(<TopicStream<String>>[c3, c4, w3]));
      }),
    );
    final CombineStage<String> three = c3 as CombineStage<String>;
    final CombineStage<String> four = c4 as CombineStage<String>;
    final WithLatestFromStage<int, String> latest3 =
        w3 as WithLatestFromStage<int, String>;
    expect(three.apply(<Object?>[1, 'a', true]), '1atrue');
    expect(four.apply(<Object?>[1, 'a', true, 2.5]), '1atrue2.5');
    expect(latest3.apply(1, <Object?>['a', true, 2.5]), '1atrue2.5');
    expect(
      () => three.apply(<Object?>[1, 'a', 'x']),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => four.apply(<Object?>[1, 'a', true, 'x']),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => latest3.apply(1, <Object?>['a', true, 'x']),
      throwsA(isA<TypeError>()),
    );
    expect(() => three.apply(<Object?>[1, 'a']), throwsArgumentError);
    expect(() => four.apply(<Object?>[1, 'a', true]), throwsArgumentError);
    expect(
      () => latest3.apply(1, <Object?>['a', true, 2.5, 3]),
      throwsArgumentError,
    );
  });

  test('G11 combineAll hands its combiner a fresh unmodifiable list on each '
      'apply, and rejects a value of another type before calling it', () {
    final List<List<int>> seen = <List<int>>[];
    late TopicStream<String> all;
    planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        all = b.combineAll(<TopicStream<int>>[t, t], (List<int> values) {
          seen.add(values);
          return values.join(',');
        });
        b.write(words, all);
      }),
    );
    final CombineStage<String> stage = all as CombineStage<String>;
    final List<Object?> input = <Object?>[1, 2];
    expect(stage.apply(input), '1,2');
    input[0] = 9;
    expect(stage.apply(input), '9,2');
    expect(seen, hasLength(2));
    expect(identical(seen[0], seen[1]), isFalse);
    expect(seen[0], <int>[1, 2]);
    expect(seen[1], <int>[9, 2]);
    expect(() => seen[0].add(3), throwsUnsupportedError);
    expect(() => seen[1].add(3), throwsUnsupportedError);
    expect(() => stage.apply(<Object?>['a', 2]), throwsA(isA<TypeError>()));
    expect(seen, hasLength(2));
  });

  test('G14 a handle another declaration made throws ArgumentError at each '
      'input position of each call, and the declaration goes on', () {
    late TopicStream<int> foreign;
    planOf(
      declared((TopologyBuilder b) => b.write(taps, foreign = b.read(taps))),
    );
    for (int i = 0; i < _misuses.length; i++) {
      final TopologyPlan plan = planOf(
        declared((TopologyBuilder b) {
          final TopicStream<int> own = b.read(taps);
          expect(
            () => _misuses[i](b, own, foreign),
            throwsArgumentError,
            reason: '$i',
          );
          b.write(taps, own);
        }),
      );
      expect(plan.stages, hasLength(1), reason: '$i');
      expect(plan.sinks, hasLength(1), reason: '$i');
    }
  });

  test('G14 a handle of a declaration still running is another builder\'s at '
      'each input position of each call', () {
    planOf(
      topology('rec-outer', Scope.page, (TopologyBuilder outer) {
        final TopicStream<int> mine = outer.read(taps);
        final TopologyPlan inner = planOf(
          topology('rec-inner', Scope.page, (TopologyBuilder inner) {
            final TopicStream<int> theirs = inner.read(taps);
            for (int i = 0; i < _misuses.length; i++) {
              expect(
                () => _misuses[i](inner, theirs, mine),
                throwsArgumentError,
                reason: '$i',
              );
            }
            inner.write(taps, theirs);
          }),
        );
        expect(inner.stages, hasLength(1));
        outer.write(taps, mine);
      }),
    );
  });

  test('G14 reduceInto on a state topic built apart from one a sink already '
      'writes throws ArgumentError at the call; another value type is '
      'another topic', () {
    final String name = <String>['rec.total'].single;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        b.reduceInto(
          StateTopic<int>(name: name, initial: 0),
          t,
          (int s, int e) => s + e,
        );
        expect(
          () => b.reduceInto(
            StateTopic<int>(name: name, initial: 9, dedup: Dedup.none),
            t,
            (int s, int e) => s,
          ),
          throwsArgumentError,
        );
        expect(
          () => b.write(StateTopic<int>(name: name, initial: 0), t),
          throwsArgumentError,
        );
        b.reduceInto(
          StateTopic<num>(name: name, initial: 0),
          t,
          (num s, int e) => s + e,
        );
      }),
    );
    expect(plan.sinks, hasLength(2));
  });

  test('G15 the closed check comes before the argument checks of every '
      'multi-input call and reduceInto', () {
    late TopologyBuilder closed;
    late TopicStream<int> kept;
    late TopicStream<int> foreign;
    planOf(
      declared((TopologyBuilder b) {
        closed = b;
        b.write(count, kept = b.read(taps));
      }),
    );
    planOf(
      declared((TopologyBuilder b) => b.write(taps, foreign = b.read(taps))),
    );
    for (int i = 0; i < _misuses.length; i++) {
      expect(
        () => _misuses[i](closed, kept, foreign),
        throwsStateError,
        reason: '$i',
      );
    }
    expect(() => closed.merge(<TopicStream<int>>[]), throwsStateError);
    // count already has a sink: a second one is an ArgumentError while open.
    expect(
      () => closed.reduceInto(count, kept, (int s, int e) => s),
      throwsStateError,
    );
  });

  test('G10 the counter counts a periodic timer and nothing else', () {
    expect(scheduledBy(() {}), 0);
    expect(
      scheduledBy(
        () => Timer.periodic(const Duration(seconds: 1), (Timer t) {}).cancel(),
      ),
      1,
    );
  });
}

/// One call of each multi-input form and reduceInto, wired from `inputs`
/// fresh reads that nothing else consumes.
final List<_Wiring> _consuming = <_Wiring>[
  (
    inputs: 2,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) =>
        b.write(any, b.combine2(input(), input(), (int x, int y) => x)),
  ),
  (
    inputs: 3,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) => b.write(
      any,
      b.combine3(input(), input(), input(), (int x, int y, int z) => x),
    ),
  ),
  (
    inputs: 4,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) => b.write(
      any,
      b.combine4(
        input(),
        input(),
        input(),
        input(),
        (int x, int y, int z, int w) => x,
      ),
    ),
  ),
  (
    inputs: 2,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) => b.write(
      any,
      b.combineAll(<TopicStream<int>>[input(), input()], joins[0]),
    ),
  ),
  (
    inputs: 2,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) =>
        b.write(any, b.merge(<TopicStream<int>>[input(), input()])),
  ),
  (
    inputs: 2,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) =>
        b.write(any, input().withLatestFrom(input(), (int v, int x) => v)),
  ),
  (
    inputs: 3,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) => b.write(
      any,
      input().withLatestFrom2(input(), input(), (int v, int x, int y) => v),
    ),
  ),
  (
    inputs: 4,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) => b.write(
      any,
      input().withLatestFrom3(
        input(),
        input(),
        input(),
        (int v, int x, int y, int z) => v,
      ),
    ),
  ),
  (
    inputs: 1,
    wire: (TopologyBuilder b, TopicStream<int> Function() input) =>
        b.reduceInto(count, input(), (int s, int e) => s + e),
  ),
];

/// One call of each multi-input form and reduceInto per input position, with
/// the third argument, a handle another builder made, at that position and
/// the second argument, a handle of the builder, at the others.
final List<_Misuse> _misuses = <_Misuse>[
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine2(f, o, (int x, int y) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine2(o, f, (int x, int y) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine3(f, o, o, (int x, int y, int z) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine3(o, f, o, (int x, int y, int z) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine3(o, o, f, (int x, int y, int z) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine4(f, o, o, o, (int x, int y, int z, int w) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine4(o, f, o, o, (int x, int y, int z, int w) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine4(o, o, f, o, (int x, int y, int z, int w) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combine4(o, o, o, f, (int x, int y, int z, int w) => x),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combineAll(<TopicStream<int>>[f, o], joins[0]),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.combineAll(<TopicStream<int>>[o, f], joins[0]),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.merge(<TopicStream<int>>[f, o]),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.merge(<TopicStream<int>>[o, f]),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      o.withLatestFrom(f, (int v, int x) => v),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      o.withLatestFrom2(f, o, (int v, int x, int y) => v),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      o.withLatestFrom2(o, f, (int v, int x, int y) => v),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      o.withLatestFrom3(f, o, o, (int v, int x, int y, int z) => v),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      o.withLatestFrom3(o, f, o, (int v, int x, int y, int z) => v),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      o.withLatestFrom3(o, o, f, (int v, int x, int y, int z) => v),
  (TopologyBuilder b, TopicStream<int> o, TopicStream<int> f) =>
      b.reduceInto(count, f, (int s, int e) => s + e),
];
