// topology-ir@v1's findSelfReferences (G14), beyond the two G14 cases of its
// conformance suite, which the gate replays: only the edges on a path from a
// read of the topic to a write of it, each once; every stage that bears no
// state, a zero duration included, against the smallest positive duration;
// a read with a dedup argument; the canonical order of topics; an
// unmodifiable result (G3); and the self-references of generated
// definitions against a walk of every path.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/analysis_support.dart';

/// The self-references of [definition] by brute force: every path is
/// walked, from each edge that takes a read of the topic, through each
/// later edge that takes the one before, stopping at a state-bearing edge,
/// and a path that ends at a write of the topic gives its edges.
List<SelfReference> walkedSelfReferences(TopologyDefinition definition) {
  final List<TransformEdge> edges = definition.transforms;
  final List<SelfReference> found = <SelfReference>[];
  for (final TopicRef topic in definition.reads) {
    if (!definition.writes.contains(topic)) {
      continue;
    }
    final Set<int> onPaths = <int>{};
    void walk(List<int> path) {
      final TransformEdge last = edges[path.last];
      if (last.isStateBearing) {
        return;
      }
      if (last.output == topic) {
        onPaths.addAll(path);
      }
      for (int next = path.last + 1; next < edges.length; next++) {
        if (edges[next].inputs.any(
          (EdgeInput input) => input is StageInput && input.edge == path.last,
        )) {
          walk(<int>[...path, next]);
        }
      }
    }

    for (int first = 0; first < edges.length; first++) {
      if (edges[first].inputs.any(
        (EdgeInput input) => input is TopicInput && input.topic == topic,
      )) {
        walk(<int>[first]);
      }
    }
    if (onPaths.isNotEmpty) {
      found.add(
        SelfReference(
          topologyId: definition.topologyId,
          topic: topic,
          edges: onPaths.toList(),
        ),
      );
    }
  }
  return found;
}

/// A stage edge of [kind] over one read of [topic] (two for withLatestFrom),
/// holding the transformer or duration its kind needs.
TransformEdge stageOf(CombinatorKind kind, TopicRef topic, Duration? d) =>
    TransformEdge.stage(
      kind,
      <EdgeInput>[
        TopicInput(topic),
        if (kind == CombinatorKind.withLatestFrom) TopicInput(topic),
      ],
      transformer: d == null && !_bare.contains(kind) ? f : null,
      duration: d,
    );

/// The kinds whose stage edge holds no transformer.
const List<CombinatorKind> _bare = <CombinatorKind>[
  CombinatorKind.merge,
  CombinatorKind.pairwise,
  CombinatorKind.distinctUntilChanged,
];

/// Each kind that bears no state, with the duration it is given: every
/// stage kind but scan and the four time stages that bear state, and those
/// four with a zero duration.
const List<(CombinatorKind, Duration?)> unmediating =
    <(CombinatorKind, Duration?)>[
      (CombinatorKind.map, null),
      (CombinatorKind.filter, null),
      (CombinatorKind.combine, null),
      (CombinatorKind.withLatestFrom, null),
      (CombinatorKind.merge, null),
      (CombinatorKind.switchMap, null),
      (CombinatorKind.pairwise, null),
      (CombinatorKind.distinctUntilChanged, null),
      (CombinatorKind.debounce, Duration.zero),
      (CombinatorKind.throttle, Duration(seconds: 1)),
      (CombinatorKind.delay, Duration.zero),
      (CombinatorKind.sample, Duration.zero),
      (CombinatorKind.buffer, Duration.zero),
      (CombinatorKind.timeout, Duration(seconds: 1)),
      (CombinatorKind.catchError, null),
      (CombinatorKind.rawEngine, null),
    ];

void main() {
  test('G14 an edge a read of the topic reaches is not listed when it leads '
      'only to a write of another topic', () {
    final TopologyDefinition d = define('fork', <TransformEdge>[
      map(TopicInput(state('fork.t'))),
      TransformEdge.write(state('fork.t'), const StageInput(0)),
      TransformEdge.write(event('fork.u'), const StageInput(0)),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(
        topologyId: 'fork',
        topic: state('fork.t'),
        edges: <int>[0, 1],
      ),
    ]);
  });

  test('G14 an edge that reaches the write is not listed when no read of the '
      'topic reaches it', () {
    final TopologyDefinition d = define('join', <TransformEdge>[
      map(TopicInput(event('join.other'))),
      TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        const StageInput(0),
        TopicInput(state('join.t')),
      ]),
      TransformEdge.write(state('join.t'), const StageInput(1)),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(
        topologyId: 'join',
        topic: state('join.t'),
        edges: <int>[1, 2],
      ),
    ]);
  });

  test('G14 every stage that bears no state leaves a path unmediated, '
      'debounce, delay, sample and buffer with a zero duration included', () {
    final TopicRef open = event('open.e');
    final TopologyDefinition d = define('open', <TransformEdge>[
      for (final (CombinatorKind kind, Duration? duration) in unmediating)
        stageOf(kind, open, duration),
      for (int i = 0; i < unmediating.length; i++)
        TransformEdge.write(open, StageInput(i)),
      TransformEdge.write(open, TopicInput(open)),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(
        topologyId: 'open',
        topic: open,
        edges: <int>[for (int i = 0; i <= 2 * unmediating.length; i++) i],
      ),
    ]);
  });

  test('G14 scan, reduceInto, and debounce, delay, sample and buffer with the '
      'smallest positive duration mediate every path', () {
    final TopicRef shut = event('shut.e');
    const Duration tick = Duration(microseconds: 1);
    final TopologyDefinition d = define('shut', <TransformEdge>[
      stageOf(CombinatorKind.scan, shut, null),
      stageOf(CombinatorKind.debounce, shut, tick),
      stageOf(CombinatorKind.delay, shut, tick),
      stageOf(CombinatorKind.sample, shut, tick),
      stageOf(CombinatorKind.buffer, shut, tick),
      for (int i = 0; i < 5; i++) TransformEdge.write(shut, StageInput(i)),
      TransformEdge.reduceInto(state('shut.s'), TopicInput(state('shut.s')), f),
    ]);
    expect(findSelfReferences(d), isEmpty);
  });

  test('G14 a read with a dedup argument is a read of its topic', () {
    final TopologyDefinition d = define('dedup', <TransformEdge>[
      TransformEdge.write(
        state('dedup.t'),
        TopicInput(state('dedup.t'), dedup: Dedup.none),
      ),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(
        topologyId: 'dedup',
        topic: state('dedup.t'),
        edges: <int>[0],
      ),
    ]);
  });

  test('G14 self-references come in canonical topic order, and an edge on '
      'several paths is listed once', () {
    final TopologyDefinition d = define('ord', <TransformEdge>[
      map(TopicInput(state('ord.b'))),
      map(const StageInput(0)),
      TransformEdge.stage(CombinatorKind.filter, <EdgeInput>[
        const StageInput(0),
      ], transformer: f),
      TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        const StageInput(1),
        const StageInput(2),
      ]),
      TransformEdge.write(state('ord.b'), const StageInput(3)),
      TransformEdge.write(event('ord.a'), TopicInput(event('ord.a'))),
      TransformEdge.write(state('ord.a'), TopicInput(state('ord.a'))),
    ]);
    expect(findSelfReferences(d), <SelfReference>[
      SelfReference(topologyId: 'ord', topic: state('ord.a'), edges: <int>[6]),
      SelfReference(topologyId: 'ord', topic: event('ord.a'), edges: <int>[5]),
      SelfReference(
        topologyId: 'ord',
        topic: state('ord.b'),
        edges: <int>[0, 1, 2, 3, 4],
      ),
    ]);
  });

  test('G3 findSelfReferences returns an unmodifiable list, empty or not', () {
    final List<SelfReference> none = findSelfReferences(
      define('none', <TransformEdge>[
        TransformEdge.write(event('none.out'), TopicInput(event('none.in'))),
      ]),
    );
    final List<SelfReference> one = findSelfReferences(
      define('one', <TransformEdge>[
        TransformEdge.write(event('one.e'), TopicInput(event('one.e'))),
      ]),
    );
    expect(none, isEmpty);
    expect(one, hasLength(1));
    expect(() => none.add(one.first), throwsUnsupportedError);
    expect(() => one.clear(), throwsUnsupportedError);
  });

  test('G14 the self-references of generated definitions list exactly the '
      'edges a walk of every path from a read to a write finds', () {
    int found = 0;
    int mediated = 0;
    for (int seed = 0; seed < seeds; seed++) {
      for (final TopologyDefinition d in generatedGraph(seed).topologies) {
        final List<SelfReference> expected = walkedSelfReferences(d);
        expect(
          findSelfReferences(d),
          expected,
          reason: 'seed $seed, ${d.topologyId}',
        );
        found += expected.length;
        mediated += d.reads.where(d.writes.contains).length - expected.length;
      }
    }
    // The seeds reach self-reads with an unmediated path and without one.
    expect(found, greaterThan(90));
    expect(mediated, greaterThan(350));
  });
}
