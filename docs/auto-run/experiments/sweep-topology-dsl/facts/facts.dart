// Runtime facts behind S152, the end-of-nidana.model governance sweep of
// topology-dsl@v2, read off the shipped package
// (packages/nidana_dart_contracts) rather than a stand-in. run.sh runs it
// from the repository root, so the workspace's package configuration
// resolves the package imports.
//
//   C: a closed builder or handle given a bad argument as well (item 2).
//   A: apply given a list of the wrong length, or a value of another type
//      (item 3).
//   R: a call that throws, caught by the declaration (item 1, stages left
//      behind).
//   S: a second sink on a state topic built apart (item 1, the one-sink
//      check).
//   N: a handle of a declaration still running, passed to a nested planOf.
//   T: a declaration that throws, then its builder and handle used.
//   L: the input lists a stage holds, and the list combineAll hands its
//      combiner.
//   V: the type arguments visitStage and visitSink bind (item 1, the
//      visitors).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';

const StateTopic<int> _count = StateTopic<int>(name: 'f.count', initial: 0);
const EventTopic<int> _taps = EventTopic<int>(name: 'f.taps');
const EventTopic<int> _out = EventTopic<int>(name: 'f.out');
const EventTopic<String> _words = EventTopic<String>(name: 'f.words');
const StateTopic<String> _label = StateTopic<String>(name: 'f.label', initial: '');
const StateTopic<bool> _flag = StateTopic<bool>(name: 'f.flag', initial: false);
const EventTopic<Object?> _any = EventTopic<Object?>(name: 'f.any');
const Duration _negative = Duration(microseconds: -1);

String _attempt(Object? Function() body) {
  try {
    return 'returns ${body()}';
  } on Object catch (e) {
    return 'throws ${e.runtimeType}';
  }
}

Topology _single(void Function(TopologyBuilder b) body) =>
    topology('f-single', Scope.page, body);

final class _Failed implements Exception {
  const _Failed();
}

void main() {
  // ---------------------------------------------------------------- C
  late final TopologyBuilder closed;
  late final TopicStream<int> kept;
  planOf(_single((TopologyBuilder b) {
    closed = b;
    kept = b.read(_taps);
    b.write(_count, kept);
  }));
  late final TopicStream<int> foreign;
  planOf(_single((TopologyBuilder b) {
    foreign = b.read(_taps);
    b.write(_out, foreign);
  }));
  print('C1 closed builder, foreign handle: '
      '${_attempt(() => closed.write(_out, foreign))}');
  print('C2 closed builder, second sink on its state topic: '
      '${_attempt(() => closed.write(_count, kept))}');
  print('C3 closed builder, dedup on an event read: '
      '${_attempt(() => closed.read(_taps, dedup: Dedup.none))}');
  print('C4 closed builder, empty merge: '
      '${_attempt(() => closed.merge(<TopicStream<int>>[]))}');
  print('C5 closed builder, empty combineAll: '
      '${_attempt(() => closed.combineAll(<TopicStream<int>>[], (List<int> xs) => 0))}');
  print('C6 closed handle, negative debounce: '
      '${_attempt(() => kept.debounce(_negative))}');
  print('C7 closed handle, negative timeout: '
      '${_attempt(() => kept.timeout(_negative))}');
  print('C8 closed handle, foreign withLatestFrom: '
      '${_attempt(() => kept.withLatestFrom(foreign, (int v, int o) => v))}');
  print('C9 open builder, closed handle (a foreign one): '
      '${_attempt(() => planOf(_single((TopologyBuilder b) => b.write(_out, kept))))}');

  // ---------------------------------------------------------------- A
  int calls = 0;
  late final CombineStage<int> c2;
  late final CombineStage<int> all;
  late final WithLatestFromStage<int, int> w2;
  planOf(_single((TopologyBuilder b) {
    final TopicStream<int> a = b.read(_count);
    final TopicStream<int> t = b.read(_taps);
    c2 = b.combine2(a, t, (int x, int y) => ++calls) as CombineStage<int>;
    all = b.combineAll(<TopicStream<int>>[a, t], (List<int> xs) => ++calls)
        as CombineStage<int>;
    w2 = a.withLatestFrom2(t, a, (int v, int x, int y) => ++calls)
        as WithLatestFromStage<int, int>;
    b.write(_out, b.merge(<TopicStream<int>>[c2, all, w2]));
  }));
  for (final List<Object?> values in <List<Object?>>[
    <Object?>[1],
    <Object?>[1, 2, 3],
    <Object?>['x', 2],
  ]) {
    print('A1 combine2.apply($values): ${_attempt(() => c2.apply(values))}');
    print('A2 combineAll.apply($values): ${_attempt(() => all.apply(values))}');
    print('A3 withLatestFrom2.apply(0, $values): '
        '${_attempt(() => w2.apply(0, values))}');
  }
  print('A4 combiner calls after the nine calls above: $calls');
  print('A5 RangeError is an ArgumentError: ${RangeError('x') is ArgumentError}');
  print('A6 combine2.apply([1, 2]): ${_attempt(() => c2.apply(<Object?>[1, 2]))}');

  // ---------------------------------------------------------------- R
  final List<String> rejected = <String>[];
  final TopologyPlan caught = planOf(_single((TopologyBuilder b) {
    final TopicStream<int> taps = b.read(_taps);
    void reject(String label, void Function() call) {
      rejected.add('$label ${_attempt(() {
        call();
        return null;
      })}');
    }

    reject('negative debounce', () => taps.debounce(_negative));
    reject('empty merge', () => b.merge(<TopicStream<int>>[]));
    reject('dedup on an event read', () => b.read(_out, dedup: Dedup.none));
    reject('foreign write to a state topic', () => b.write(_count, foreign));
    b.write(_count, taps);
    reject('second sink', () => b.write(_count, taps));
  }));
  for (final String line in rejected) {
    print('R1 $line');
  }
  print('R2 plan after the caught calls: ${caught.stages.length} stage(s), '
      '${caught.sinks.length} sink(s)');
  print('R3 a stage passed only to a rejected second sink: '
      '${_attempt(() => planOf(_single((TopologyBuilder b) {
            b.write(_count, b.read(_taps));
            final TopicStream<int> orphan = b.read(_taps);
            try {
              b.write(_count, orphan);
            } on ArgumentError {
              // caught: the declaration goes on
            }
          })))}');

  // ---------------------------------------------------------------- S
  final String name = _count.name;
  final StateTopic<int> apart = StateTopic<int>(name: name, initial: 5);
  print('S1 built apart: identical ${identical(apart, _count)}, '
      'equal ${apart == _count}');
  print('S2 write, then write to the topic built apart: '
      '${_attempt(() => planOf(_single((TopologyBuilder b) {
            b.write(_count, b.read(_taps));
            b.write(apart, b.read(_taps));
          })))}');

  // ---------------------------------------------------------------- N
  String nested = 'not run';
  planOf(_single((TopologyBuilder b) {
    final TopicStream<int> outer = b.read(_taps);
    nested = _attempt(() => planOf(topology('f-nested', Scope.page,
        (TopologyBuilder inner) => inner.write(_out, outer))));
    b.write(_out, outer);
  }));
  print('N1 a nested planOf given a handle of the running declaration: $nested');

  // ---------------------------------------------------------------- T
  TopologyBuilder? thrownBuilder;
  TopicStream<int>? thrownHandle;
  print('T1 planOf of a declaration that throws: '
      '${_attempt(() => planOf(_single((TopologyBuilder b) {
            thrownBuilder = b;
            thrownHandle = b.read(_taps);
            throw const _Failed();
          })))}');
  print('T2 its builder after: ${_attempt(() => thrownBuilder!.read(_taps))}');
  print('T3 its handle after: '
      '${_attempt(() => thrownHandle!.map((int v) => v))}');

  // ---------------------------------------------------------------- L
  late final List<TopicStream<int>> given;
  late final MergeStage<int> merged;
  late final CombineStage<int> combined;
  late final WithLatestFromStage<int, int> latest;
  planOf(_single((TopologyBuilder b) {
    final TopicStream<int> first = b.read(_taps);
    given = <TopicStream<int>>[first];
    merged = b.merge(given) as MergeStage<int>;
    combined = b.combineAll(given, (List<int> xs) {
      xs.add(0);
      return xs.length;
    }) as CombineStage<int>;
    latest = first.withLatestFrom(merged, (int v, int m) => v)
        as WithLatestFromStage<int, int>;
    given.clear();
    b.write(_out, combined);
    b.write(_out, latest);
  }));
  print('L1 merge inputs after the caller cleared its list: '
      '${merged.inputs.length}');
  print('L2 combineAll inputs after the caller cleared its list: '
      '${combined.inputs.length}');
  print('L3 merge inputs add: ${_attempt(() {
    merged.inputs.add(merged);
    return null;
  })}');
  print('L4 withLatestFrom latest add: ${_attempt(() {
    latest.latest.add(merged);
    return null;
  })}');
  print('L5 combineAll combiner adding to its list: '
      '${_attempt(() => combined.apply(<Object?>[1]))}');

  // ---------------------------------------------------------------- V
  final TopologyPlan typed = planOf(_single((TopologyBuilder b) {
    final TopicStream<int> t = b.read(_taps);
    final TopicStream<String> w = b.read(_words);
    final TopicStream<String> s = t.map((int v) => '$v');
    b.write(_label, s.filter((String v) => v.isEmpty));
    b.reduceInto(_count, w, (int n, String x) => n);
    b.write(_flag, b.combine2(t, w, (int v, String x) => true));
    b.write(_any, t);
  }));
  print('V1 stages: ${<String>[
    for (final TopicStream<Object?> s in typed.stages) visitStage(s, const _Types()),
  ]}');
  print('V2 sinks: ${<String>[
    for (final PlanSink s in typed.sinks) visitSink(s, const _SinkTypes()),
  ]}');
}

final class _Types implements StageVisitor<String> {
  const _Types();
  @override
  String read<T>(ReadStage<T> s) => 'read<$T>';
  @override
  String map<T, R>(MapStage<T, R> s) => 'map<$T, $R>';
  @override
  String filter<T>(FilterStage<T> s) => 'filter<$T>';
  @override
  String combine<R>(CombineStage<R> s) => 'combine<$R>';
  @override
  String withLatestFrom<T, R>(WithLatestFromStage<T, R> s) =>
      'withLatestFrom<$T, $R>';
  @override
  String merge<T>(MergeStage<T> s) => 'merge<$T>';
  @override
  String switchMap<T, R>(SwitchMapStage<T, R> s) => 'switchMap<$T, $R>';
  @override
  String scan<T, S>(ScanStage<T, S> s) => 'scan<$T, $S>';
  @override
  String pairwise<T>(PairwiseStage<T> s) => 'pairwise<$T>';
  @override
  String distinctUntilChanged<T>(DistinctUntilChangedStage<T> s) =>
      'distinctUntilChanged<$T>';
  @override
  String debounce<T>(DebounceStage<T> s) => 'debounce<$T>';
  @override
  String throttle<T>(ThrottleStage<T> s) => 'throttle<$T>';
  @override
  String delay<T>(DelayStage<T> s) => 'delay<$T>';
  @override
  String sample<T>(SampleStage<T> s) => 'sample<$T>';
  @override
  String buffer<T>(BufferStage<T> s) => 'buffer<$T>';
  @override
  String timeout<T>(TimeoutStage<T> s) => 'timeout<$T>';
  @override
  String catchError<T>(CatchErrorStage<T> s) => 'catchError<$T>';
  @override
  String rawEngine<T, R>(RawEngineStage<T, R> s) => 'rawEngine<$T, $R>';
}

final class _SinkTypes implements SinkVisitor<String> {
  const _SinkTypes();
  @override
  String write<T>(WriteSink<T> sink) => 'write<$T>';
  @override
  String reduceInto<S, E>(ReduceIntoSink<S, E> sink) => 'reduceInto<$S, $E>';
}
