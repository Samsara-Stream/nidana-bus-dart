// topology-dsl@v2's single-input handle calls, beyond the cases of its
// recording suite: each adds one stage holding the receiver and the very
// arguments it was given, a negative duration fails at the call, and a
// closed declaration's handle records nothing.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

const EventTopic<int> taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<Object?> any = EventTopic<Object?>(name: 'rec.any');

/// One closure of each function type a single-input handle call takes, held
/// in lists so that each test reads the very object it passed.
final List<String Function(int)> transforms = <String Function(int)>[
  (int v) => '$v',
];
final List<bool Function(int)> tests = <bool Function(int)>[(int v) => v > 0];
final List<Stream<String> Function(int)> factories =
    <Stream<String> Function(int)>[(int v) => Stream<String>.value('$v')];
final List<RetryPolicy> retries = <RetryPolicy>[
  (Object error, int attempt) => null,
];
final List<List<int> Function(List<int>, int)> accumulators =
    <List<int> Function(List<int>, int)>[
      (List<int> acc, int v) => <int>[...acc, v],
    ];
final List<int Function(Object, StackTrace)> recovers =
    <int Function(Object, StackTrace)>[(Object e, StackTrace s) => -1];
final List<RawOperator<int, String>> operators = <RawOperator<int, String>>[
  (Stream<PipelineValue<int>> values, String Function() fresh) =>
      const Stream<PipelineValue<String>>.empty(),
];

/// Durations built at run time, so that only the passed object is identical.
final List<Duration> durations = <Duration>[
  for (int i = 1; i <= 6; i++) Duration(milliseconds: <int>[i].single),
];

Topology declared(void Function(TopologyBuilder b) body) =>
    topology('rec-handle', Scope.page, body);

void main() {
  test('G11 each handle call adds one stage of its class holding the receiver '
      'and the arguments it was given', () {
    late TopicStream<int> t;
    final List<TopicStream<Object?>> made = <TopicStream<Object?>>[];
    final List<int> initial = <int>[];
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        t = b.read(taps);
        made.addAll(<TopicStream<Object?>>[
          t.map<String>(transforms[0]),
          t.filter(tests[0]),
          t.switchMap<String>(factories[0]),
          t.switchMap<String>(factories[0], retry: retries[0]),
          t.scan<List<int>>(initial, accumulators[0]),
          t.pairwise(),
          t.distinctUntilChanged(),
          t.debounce(durations[0]),
          t.throttle(durations[1]),
          t.delay(durations[2]),
          t.sample(durations[3]),
          t.buffer(durations[4]),
          t.timeout(durations[5]),
          t.catchError(recovers[0]),
          t.rawEngine<String>(operators[0]),
        ]);
        for (final TopicStream<Object?> s in made) {
          b.write(any, s);
        }
      }),
    );
    expect(plan.stages, hasLength(16));
    for (int i = 0; i < made.length; i++) {
      expect(identical(plan.stages[i + 1], made[i]), isTrue, reason: '$i');
    }
    final MapStage<int, String> map = made[0] as MapStage<int, String>;
    expect(identical(map.input, t), isTrue);
    expect(identical(map.transform, transforms[0]), isTrue);
    final FilterStage<int> filter = made[1] as FilterStage<int>;
    expect(identical(filter.input, t), isTrue);
    expect(identical(filter.test, tests[0]), isTrue);
    final SwitchMapStage<int, String> plain =
        made[2] as SwitchMapStage<int, String>;
    expect(identical(plain.toStream, factories[0]), isTrue);
    expect(plain.retry, isNull);
    final SwitchMapStage<int, String> retried =
        made[3] as SwitchMapStage<int, String>;
    expect(identical(retried.retry, retries[0]), isTrue);
    final ScanStage<int, List<int>> scan = made[4] as ScanStage<int, List<int>>;
    expect(identical(scan.initial, initial), isTrue);
    expect(identical(scan.accumulator, accumulators[0]), isTrue);
    expect(identical((made[5] as PairwiseStage<int>).input, t), isTrue);
    expect(
      identical((made[6] as DistinctUntilChangedStage<int>).input, t),
      isTrue,
    );
    final List<Duration> held = <Duration>[
      (made[7] as DebounceStage<int>).duration,
      (made[8] as ThrottleStage<int>).duration,
      (made[9] as DelayStage<int>).duration,
      (made[10] as SampleStage<int>).duration,
      (made[11] as BufferStage<int>).duration,
      (made[12] as TimeoutStage<int>).duration,
    ];
    for (int i = 0; i < held.length; i++) {
      expect(identical(held[i], durations[i]), isTrue, reason: '$i');
    }
    expect(
      identical((made[13] as CatchErrorStage<int>).recover, recovers[0]),
      isTrue,
    );
    final RawEngineStage<int, String> raw =
        made[14] as RawEngineStage<int, String>;
    expect(identical(raw.input, t), isTrue);
    expect(identical(raw.operator, operators[0]), isTrue);
  });

  test('G14 a negative duration throws ArgumentError at the call and adds no '
      'stage; a zero duration is accepted', () {
    const Duration negative = Duration(microseconds: -1);
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        expect(() => t.debounce(negative), throwsArgumentError);
        expect(() => t.throttle(negative), throwsArgumentError);
        expect(() => t.delay(negative), throwsArgumentError);
        expect(() => t.sample(negative), throwsArgumentError);
        expect(() => t.buffer(negative), throwsArgumentError);
        expect(() => t.timeout(negative), throwsArgumentError);
        b.write(taps, t.throttle(Duration.zero));
      }),
    );
    expect(plan.stages, hasLength(2));
    expect((plan.stages[1] as ThrottleStage<int>).duration, Duration.zero);
  });

  test('G15 every single-input handle call throws StateError once its '
      'declaration has returned', () {
    late TopicStream<int> kept;
    planOf(declared((TopologyBuilder b) => b.write(taps, kept = b.read(taps))));
    final List<Object? Function()> calls = <Object? Function()>[
      () => kept.map(transforms[0]),
      () => kept.filter(tests[0]),
      () => kept.switchMap(factories[0]),
      () => kept.scan(0, (int acc, int v) => acc),
      () => kept.pairwise(),
      () => kept.distinctUntilChanged(),
      () => kept.debounce(Duration.zero),
      () => kept.throttle(Duration.zero),
      () => kept.delay(Duration.zero),
      () => kept.sample(Duration.zero),
      () => kept.buffer(Duration.zero),
      () => kept.timeout(Duration.zero),
      () => kept.catchError(recovers[0]),
      () => kept.rawEngine(operators[0]),
    ];
    for (int i = 0; i < calls.length; i++) {
      expect(calls[i], throwsStateError, reason: '$i');
    }
  });

  test('G15 a closed handle given a negative duration throws StateError', () {
    late TopicStream<int> kept;
    planOf(declared((TopologyBuilder b) => b.write(taps, kept = b.read(taps))));
    expect(
      () => kept.debounce(const Duration(microseconds: -1)),
      throwsStateError,
    );
  });

  test('G15 a handle call whose stage reaches no sink fails planOf with '
      'StateError', () {
    expect(
      () => planOf(
        declared((TopologyBuilder b) {
          final TopicStream<int> t = b.read(taps);
          b.write(taps, t);
          t.pairwise().map((({int previous, int current}) p) => p.current);
        }),
      ),
      throwsStateError,
    );
  });

  test('G11 every single-input call takes the receiver as its input, so the '
      'receiver reaches a sink through the stage alone', () {
    for (int i = 0; i < calls.length; i++) {
      final TopologyPlan plan = planOf(
        declared((TopologyBuilder b) => b.write(any, calls[i](b.read(taps)))),
      );
      expect(plan.stages, hasLength(2), reason: '$i');
      expect(plan.sinks, hasLength(1), reason: '$i');
    }
  });

  test('G11 a call on a derived handle takes that stage as its input and the '
      'plan keeps call order', () {
    late TopicStream<String> mapped;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        mapped = b.read(taps).map<String>(transforms[0]);
        b.write(any, mapped.distinctUntilChanged());
      }),
    );
    expect(plan.stages, hasLength(3));
    expect(plan.stages[0], isA<ReadStage<int>>());
    expect(identical(plan.stages[1], mapped), isTrue);
    final DistinctUntilChangedStage<String> last =
        plan.stages[2] as DistinctUntilChangedStage<String>;
    expect(identical(last.input, mapped), isTrue);
  });

  test('G14 a zero duration is accepted by every time call', () {
    for (int i = 0; i < timed.length; i++) {
      final TopologyPlan plan = planOf(
        declared(
          (TopologyBuilder b) =>
              b.write(any, timed[i](b.read(taps), Duration.zero)),
        ),
      );
      expect(plan.stages, hasLength(2), reason: '$i');
    }
  });

  test('G14 a rejected negative duration consumes no handle: the receiver '
      'still reaches no sink, whichever time call was rejected', () {
    for (int i = 0; i < timed.length; i++) {
      expect(
        () => planOf(
          declared((TopologyBuilder b) {
            final TopicStream<int> t = b.read(taps);
            expect(
              () => timed[i](t, const Duration(microseconds: -1)),
              throwsArgumentError,
            );
          }),
        ),
        throwsStateError,
        reason: '$i',
      );
    }
  });

  test('G14 a declaration that catches a negative duration and goes on plans '
      'as if the call never happened', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        TopicStream<int> shaped;
        try {
          shaped = t.delay(const Duration(microseconds: -1));
        } on ArgumentError {
          shaped = t;
        }
        b.write(any, shaped);
      }),
    );
    expect(plan.stages, hasLength(1));
    expect(plan.stages.single, isA<ReadStage<int>>());
  });

  test('G15 the closed check comes before the duration check in every time '
      'call', () {
    late TopicStream<int> kept;
    planOf(declared((TopologyBuilder b) => b.write(taps, kept = b.read(taps))));
    for (int i = 0; i < timed.length; i++) {
      expect(
        () => timed[i](kept, const Duration(microseconds: -1)),
        throwsStateError,
        reason: '$i',
      );
    }
  });

  test('G15 a handle kept from a declaration that threw throws StateError', () {
    late TopicStream<int> kept;
    expect(
      () => planOf(
        declared((TopologyBuilder b) {
          kept = b.read(taps);
          throw const FormatException('the declaration stops here');
        }),
      ),
      throwsFormatException,
    );
    expect(() => kept.pairwise(), throwsStateError);
  });
}

/// One call of each single-input handle method, on an `int` receiver.
final List<TopicStream<Object?> Function(TopicStream<int>)> calls =
    <TopicStream<Object?> Function(TopicStream<int>)>[
      (TopicStream<int> t) => t.map(transforms[0]),
      (TopicStream<int> t) => t.filter(tests[0]),
      (TopicStream<int> t) => t.switchMap(factories[0]),
      (TopicStream<int> t) => t.scan<int>(0, (int acc, int v) => acc),
      (TopicStream<int> t) => t.pairwise(),
      (TopicStream<int> t) => t.distinctUntilChanged(),
      (TopicStream<int> t) => t.debounce(Duration.zero),
      (TopicStream<int> t) => t.throttle(Duration.zero),
      (TopicStream<int> t) => t.delay(Duration.zero),
      (TopicStream<int> t) => t.sample(Duration.zero),
      (TopicStream<int> t) => t.buffer(Duration.zero),
      (TopicStream<int> t) => t.timeout(Duration.zero),
      (TopicStream<int> t) => t.catchError(recovers[0]),
      (TopicStream<int> t) => t.rawEngine(operators[0]),
    ];

/// The six time calls, each taking its duration as an argument.
final List<TopicStream<Object?> Function(TopicStream<int>, Duration)> timed =
    <TopicStream<Object?> Function(TopicStream<int>, Duration)>[
      (TopicStream<int> t, Duration d) => t.debounce(d),
      (TopicStream<int> t, Duration d) => t.throttle(d),
      (TopicStream<int> t, Duration d) => t.delay(d),
      (TopicStream<int> t, Duration d) => t.sample(d),
      (TopicStream<int> t, Duration d) => t.buffer(d),
      (TopicStream<int> t, Duration d) => t.timeout(d),
    ];
