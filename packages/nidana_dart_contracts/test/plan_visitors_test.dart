// topology-dsl@v2's visitors, beyond the cases of its recording suite:
// visitStage and visitSink bind each stage's and sink's own type arguments,
// so an interpreter reads and calls a stage's functions at their types.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

const StateTopic<int> count = StateTopic<int>(name: 'rec.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<String> words = EventTopic<String>(name: 'rec.words');
const EventTopic<Object?> any = EventTopic<Object?>(name: 'rec.any');

/// What a visitor saw: the stage's class with the type arguments it
/// received, and for map, filter and scan what an interpreter builds, a
/// function over Object? that calls the stage's own function at its types.
typedef Bound = ({String types, Object? Function(Object?)? call});

final class Bind implements StageVisitor<Bound> {
  const Bind();

  Bound _named(String types) => (types: types, call: null);

  @override
  Bound read<T>(ReadStage<T> stage) => _named('read<$T>');
  @override
  Bound map<T, R>(MapStage<T, R> stage) =>
      (types: 'map<$T, $R>', call: (Object? v) => stage.transform(v as T));
  @override
  Bound filter<T>(FilterStage<T> stage) =>
      (types: 'filter<$T>', call: (Object? v) => stage.test(v as T));
  @override
  Bound combine<R>(CombineStage<R> stage) => _named('combine<$R>');
  @override
  Bound withLatestFrom<T, R>(WithLatestFromStage<T, R> stage) =>
      _named('withLatestFrom<$T, $R>');
  @override
  Bound merge<T>(MergeStage<T> stage) => _named('merge<$T>');
  @override
  Bound switchMap<T, R>(SwitchMapStage<T, R> stage) =>
      _named('switchMap<$T, $R>');
  @override
  Bound scan<T, S>(ScanStage<T, S> stage) => (
    types: 'scan<$T, $S>',
    call: (Object? v) => stage.accumulator(stage.initial, v as T),
  );
  @override
  Bound pairwise<T>(PairwiseStage<T> stage) => _named('pairwise<$T>');
  @override
  Bound distinctUntilChanged<T>(DistinctUntilChangedStage<T> stage) =>
      _named('distinctUntilChanged<$T>');
  @override
  Bound debounce<T>(DebounceStage<T> stage) => _named('debounce<$T>');
  @override
  Bound throttle<T>(ThrottleStage<T> stage) => _named('throttle<$T>');
  @override
  Bound delay<T>(DelayStage<T> stage) => _named('delay<$T>');
  @override
  Bound sample<T>(SampleStage<T> stage) => _named('sample<$T>');
  @override
  Bound buffer<T>(BufferStage<T> stage) => _named('buffer<$T>');
  @override
  Bound timeout<T>(TimeoutStage<T> stage) => _named('timeout<$T>');
  @override
  Bound catchError<T>(CatchErrorStage<T> stage) => _named('catchError<$T>');
  @override
  Bound rawEngine<T, R>(RawEngineStage<T, R> stage) =>
      _named('rawEngine<$T, $R>');
}

final class BindSink implements SinkVisitor<String> {
  const BindSink();

  @override
  String write<T>(WriteSink<T> sink) => 'write<$T>';
  @override
  String reduceInto<S, E>(ReduceIntoSink<S, E> sink) => 'reduceInto<$S, $E>';
}

Topology declared(void Function(TopologyBuilder b) body) =>
    topology('rec-visit', Scope.page, body);

void main() {
  test('G16 visitStage passes each stage to the method of its class with '
      'the stage\'s own type arguments', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        final TopicStream<String> w = b.read(words);
        final TopicStream<String> s = t.map((int v) => '$v');
        final TopicStream<List<String>> batches = b
            .merge(<TopicStream<String>>[
              s.filter((String v) => v.isNotEmpty),
              b.combine2(t, w, (int a, String c) => '$a$c'),
              t.withLatestFrom(w, (int v, String c) => c),
            ])
            .switchMap((String v) => Stream<double>.value(1.5))
            .scan(
              <double>[],
              (List<double> acc, double v) => <double>[...acc, v],
            )
            .map((List<double> v) => v.length)
            .distinctUntilChanged()
            .debounce(Duration.zero)
            .throttle(Duration.zero)
            .delay(Duration.zero)
            .sample(Duration.zero)
            .timeout(Duration.zero)
            .catchError((Object e, StackTrace st) => 0)
            .rawEngine<String>(
              (Stream<PipelineValue<int>> v, String Function() fresh) =>
                  const Stream<PipelineValue<String>>.empty(),
            )
            .buffer(Duration.zero);
        b.write(any, batches.pairwise());
      }),
    );
    expect(
      <String>[
        for (final TopicStream<Object?> stage in plan.stages)
          visitStage(stage, const Bind()).types,
      ],
      <String>[
        'read<int>',
        'read<String>',
        'map<int, String>',
        'filter<String>',
        'combine<String>',
        'withLatestFrom<int, String>',
        'merge<String>',
        'switchMap<String, double>',
        'scan<double, List<double>>',
        'map<List<double>, int>',
        'distinctUntilChanged<int>',
        'debounce<int>',
        'throttle<int>',
        'delay<int>',
        'sample<int>',
        'timeout<int>',
        'catchError<int>',
        'rawEngine<int, String>',
        'buffer<String>',
        'pairwise<List<String>>',
      ],
    );
  });

  test('G16 visitSink passes each sink to the method of its class with the '
      'sink\'s own type arguments', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        b.write(any, t);
        b.reduceInto(count, b.read(words), (int s, String w) => s + w.length);
        b.write(taps, t);
      }),
    );
    expect(
      <String>[
        for (final PlanSink sink in plan.sinks)
          visitSink(sink, const BindSink()),
      ],
      <String>['write<Object?>', 'reduceInto<int, String>', 'write<int>'],
    );
  });

  test('G16 through visitStage an interpreter calls a stage\'s functions at '
      'their own types', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        b.write(
          words,
          b
              .read(taps)
              .filter((int v) => v.isEven)
              .scan(1, (int acc, int v) => acc * v)
              .map((int v) => 'x$v'),
        );
      }),
    );
    final List<Object? Function(Object?)> call = <Object? Function(Object?)>[
      for (final TopicStream<Object?> stage in plan.stages.skip(1))
        visitStage(stage, const Bind()).call!,
    ];
    expect(call[0](4), isTrue);
    expect(call[1](6), 6);
    expect(call[2](6), 'x6');
    expect(() => call[2]('six'), throwsA(isA<TypeError>()));
  });
}
