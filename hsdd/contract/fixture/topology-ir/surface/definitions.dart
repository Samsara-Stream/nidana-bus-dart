// Surface fixture for topology-ir@v1: the IR value types of the main
// library, used the way a reader of buildDefinition() and a decoder's caller
// use them. Every constructor and member appears with the types the
// Interface states; the switches over EdgeInput and CombinatorKind are
// exhaustive. Passes when `fvm dart analyze --fatal-infos` reports nothing
// on it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

int total(int a, int b) => a + b;

const TopicRef count =
    TopicRef(name: 'demo.count', variant: TopicVariant.state, typeName: 'int');
const TopicRef taps =
    TopicRef(name: 'demo.taps', variant: TopicVariant.event, typeName: 'int');
const TopicRef out =
    TopicRef(name: 'demo.out', variant: TopicVariant.event, typeName: 'int');

/// A definition written out by hand, as a decoder or a test builds one.
final TopologyDefinition byHand = TopologyDefinition(
  topologyId: 'demo',
  scope: Scope.page,
  transforms: <TransformEdge>[
    TransformEdge.stage(
      CombinatorKind.withLatestFrom,
      <EdgeInput>[const TopicInput(taps), const TopicInput(count, dedup: Dedup.none)],
      transformer: FunctionRef.of(total),
    ),
    TransformEdge.stage(
      CombinatorKind.debounce,
      <EdgeInput>[const StageInput(0)],
      duration: const Duration(milliseconds: 300),
    ),
    TransformEdge.stage(
      CombinatorKind.switchMap,
      <EdgeInput>[const StageInput(1)],
      transformer: FunctionRef.named('search'),
      retry: const FunctionRef.anonymous(),
    ),
    TransformEdge.write(out, const StageInput(2)),
    TransformEdge.reduceInto(count, const TopicInput(taps), FunctionRef.named('reduce')),
  ],
);

/// Every member of a definition and its edges, with its type.
List<String> describe(TopologyDefinition d) {
  final String id = d.topologyId;
  final Scope scope = d.scope;
  final Set<TopicRef> reads = d.reads;
  final Set<TopicRef> writes = d.writes;
  final List<TransformEdge> transforms = d.transforms;
  return <String>[
    '$id ${scope.name} ${reads.length} ${writes.length}',
    for (final TransformEdge e in transforms) edge(e),
  ];
}

String edge(TransformEdge e) {
  final CombinatorKind? combinator = e.combinator;
  final List<EdgeInput> inputs = e.inputs;
  final TopicRef? output = e.output;
  final FunctionRef? transformer = e.transformer;
  final Duration? duration = e.duration;
  final FunctionRef? retry = e.retry;
  final bool sink = e.isSink;
  final bool stateBearing = e.isStateBearing;
  return '${combinator == null ? 'write' : kind(combinator)} '
      '${inputs.map(input).join(',')} ${output?.name} ${transformer?.name} '
      '$duration ${retry?.name} $sink $stateBearing';
}

String input(EdgeInput i) => switch (i) {
      TopicInput(:final TopicRef topic, :final Dedup? dedup) =>
        '${topic.name}${dedup == null ? '' : ' ${dedup.name}'}',
      StageInput(:final int edge) => '#$edge',
    };

String kind(CombinatorKind k) => switch (k) {
      CombinatorKind.map => 'map',
      CombinatorKind.filter => 'filter',
      CombinatorKind.combine => 'combine',
      CombinatorKind.withLatestFrom => 'withLatestFrom',
      CombinatorKind.merge => 'merge',
      CombinatorKind.switchMap => 'switchMap',
      CombinatorKind.scan => 'scan',
      CombinatorKind.pairwise => 'pairwise',
      CombinatorKind.distinctUntilChanged => 'distinctUntilChanged',
      CombinatorKind.debounce => 'debounce',
      CombinatorKind.throttle => 'throttle',
      CombinatorKind.delay => 'delay',
      CombinatorKind.sample => 'sample',
      CombinatorKind.buffer => 'buffer',
      CombinatorKind.timeout => 'timeout',
      CombinatorKind.catchError => 'catchError',
      CombinatorKind.rawEngine => 'rawEngine',
      CombinatorKind.reduceInto => 'reduceInto',
    };

/// A function reference: a name, or none.
final String? derived = FunctionRef.of(total).name;
const FunctionRef anonymous = FunctionRef.anonymous();
final bool sameRef = FunctionRef.named('total') == FunctionRef.of(total);

/// What a recorded topology yields (topology-dsl@v1 buildDefinition()).
final TopologyDefinition recorded = topology('recorded', Scope.module,
    (TopologyBuilder b) => b.write(const EventTopic<int>(name: 'demo.out'),
        b.read(const EventTopic<int>(name: 'demo.taps')))).buildDefinition();
