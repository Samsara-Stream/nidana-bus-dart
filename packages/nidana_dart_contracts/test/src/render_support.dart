// What the tests of topology-ir@v1's Mermaid and Graphviz renderers share:
// the seven sample graphs, read back from their valid/ files, and graphs
// built edge by edge for the rendering rules that no sample shows
// (nidana.model.14 Scope).
import 'dart:async';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

import 'json_support.dart';

/// The names of the sample graphs: one per file under valid/, and one pair
/// of files under render/ each.
List<String> sampleNames() => fixtureNames('valid');

/// The sample graph [name], decoded from valid/[name].json, which the
/// decoder gives back as the sample (topology-ir@v1 G20).
TopologyGraph sampleGraph(String name) =>
    decodeTopologyGraph(fixtureJson('valid/$name.json'));

TopicRef stateRef(String name, [String typeName = 'int']) =>
    TopicRef(name: name, variant: TopicVariant.state, typeName: typeName);

TopicRef eventRef(String name, [String typeName = 'int']) =>
    TopicRef(name: name, variant: TopicVariant.event, typeName: typeName);

TopicRef replayRef(String name, [String typeName = 'int']) =>
    TopicRef(name: name, variant: TopicVariant.replay, typeName: typeName);

/// Each duration beside the text an edge label gives it: whole seconds,
/// else whole milliseconds, else microseconds.
const List<(Duration, String)> durationTexts = <(Duration, String)>[
  (Duration.zero, '0s'),
  (Duration(microseconds: 1), '1us'),
  (Duration(microseconds: 999), '999us'),
  (Duration(microseconds: 1000), '1ms'),
  (Duration(microseconds: 1001), '1001us'),
  (Duration(microseconds: 1500), '1500us'),
  (Duration(milliseconds: 999), '999ms'),
  (Duration(milliseconds: 1000), '1s'),
  (Duration(milliseconds: 1001), '1001ms'),
  (Duration(seconds: 1, microseconds: 1), '1000001us'),
  (Duration(minutes: 2), '120s'),
  (Duration(hours: 25), '90000s'),
  (Duration(days: 365000), '31536000000s'),
];

/// One delay of [duration] between a read and a write.
TopologyGraph delayGraph(Duration duration) => TopologyGraph(
  topologies: <TopologyDefinition>[
    TopologyDefinition(
      topologyId: 'timed',
      scope: Scope.page,
      transforms: <TransformEdge>[
        TransformEdge.stage(CombinatorKind.delay, <EdgeInput>[
          TopicInput(eventRef('t.in')),
        ], duration: duration),
        TransformEdge.write(eventRef('t.out'), const StageInput(0)),
      ],
    ),
  ],
);

/// The six time stages in a chain, each with its duration.
TopologyGraph timeStagesGraph() => TopologyGraph(
  topologies: <TopologyDefinition>[
    TopologyDefinition(
      topologyId: 'timed',
      scope: Scope.page,
      transforms: <TransformEdge>[
        TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[
          TopicInput(eventRef('t.in')),
        ], duration: const Duration(milliseconds: 1001)),
        TransformEdge.stage(CombinatorKind.throttle, <EdgeInput>[
          const StageInput(0),
        ], duration: const Duration(minutes: 2)),
        TransformEdge.stage(CombinatorKind.delay, <EdgeInput>[
          const StageInput(1),
        ], duration: Duration.zero),
        TransformEdge.stage(CombinatorKind.sample, <EdgeInput>[
          const StageInput(2),
        ], duration: const Duration(seconds: 1, microseconds: 1)),
        TransformEdge.stage(CombinatorKind.buffer, <EdgeInput>[
          const StageInput(3),
        ], duration: const Duration(milliseconds: 1)),
        TransformEdge.stage(CombinatorKind.timeout, <EdgeInput>[
          const StageInput(4),
        ], duration: const Duration(microseconds: 1)),
        TransformEdge.write(eventRef('t.out'), const StageInput(5)),
      ],
    ),
  ],
);

/// Named and anonymous transformers and retries, a private name with its
/// key, an edge with no function, and a reduceInto.
TopologyGraph functionsGraph() => TopologyGraph(
  topologies: <TopologyDefinition>[
    TopologyDefinition(
      topologyId: 'calls',
      scope: Scope.module,
      transforms: <TransformEdge>[
        TransformEdge.stage(
          CombinatorKind.switchMap,
          <EdgeInput>[TopicInput(stateRef('c.query', 'String'))],
          transformer: FunctionRef.named('search'),
          retry: const FunctionRef.anonymous(),
        ),
        TransformEdge.stage(
          CombinatorKind.switchMap,
          <EdgeInput>[const StageInput(0)],
          transformer: const FunctionRef.anonymous(),
          retry: FunctionRef.named('backoff'),
        ),
        TransformEdge.stage(CombinatorKind.switchMap, <EdgeInput>[
          const StageInput(1),
        ], transformer: FunctionRef.named('search')),
        TransformEdge.stage(CombinatorKind.scan, <EdgeInput>[
          const StageInput(2),
        ], transformer: FunctionRef.named('_add@22518013')),
        TransformEdge.stage(CombinatorKind.pairwise, <EdgeInput>[
          const StageInput(3),
        ]),
        TransformEdge.write(
          stateRef('c.results', 'Results'),
          const StageInput(4),
        ),
        TransformEdge.reduceInto(
          stateRef('c.total'),
          TopicInput(stateRef('c.query', 'String')),
          const FunctionRef.anonymous(),
        ),
      ],
    ),
  ],
);

/// Two topologies and two claims given out of their graph order, an input
/// repeated, a stage read by two edges, one topic name of two variants, and
/// a claim of three topics.
TopologyGraph arrowsGraph() => TopologyGraph(
  topologies: <TopologyDefinition>[
    TopologyDefinition(
      topologyId: 'arrows',
      scope: Scope.module,
      transforms: <TransformEdge>[
        TransformEdge.stage(CombinatorKind.combine, <EdgeInput>[
          TopicInput(stateRef('a.y'), dedup: Dedup.none),
          TopicInput(eventRef('a.x')),
          TopicInput(eventRef('a.x')),
        ], transformer: FunctionRef.named('sum')),
        TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
          const StageInput(0),
          const StageInput(0),
          TopicInput(replayRef('a.z')),
        ]),
        TransformEdge.write(eventRef('a.out'), const StageInput(1)),
        TransformEdge.write(eventRef('a.out'), const StageInput(0)),
      ],
    ),
    TopologyDefinition(
      topologyId: 'alpha',
      scope: Scope.application,
      transforms: <TransformEdge>[
        TransformEdge.stage(CombinatorKind.map, <EdgeInput>[
          TopicInput(eventRef('a.out')),
        ], transformer: FunctionRef.named('f')),
        TransformEdge.write(eventRef('b.out'), const StageInput(0)),
      ],
    ),
  ],
  claims: <ShellClaim>[
    ShellClaim(
      source: const ServiceSource('zeta'),
      writes: <TopicRef>{stateRef('a.y'), stateRef('a.w'), stateRef('a.x')},
    ),
    ShellClaim(
      source: const PageSource('home'),
      scope: Scope.page,
      writes: <TopicRef>{stateRef('a.y')},
    ),
  ],
);

/// One topic name and variant of two type names, String read by a stage and
/// int written by a write, so that a topic's node is its type name's too.
TopologyGraph typeNamesGraph() => TopologyGraph(
  topologies: <TopologyDefinition>[
    TopologyDefinition(
      topologyId: 'typed',
      scope: Scope.module,
      transforms: <TransformEdge>[
        TransformEdge.stage(CombinatorKind.map, <EdgeInput>[
          TopicInput(eventRef('a.x', 'String')),
        ], transformer: FunctionRef.named('f')),
        TransformEdge.write(eventRef('a.x'), const StageInput(0)),
      ],
    ),
  ],
);

/// Every character either renderer escapes, in every kind of label, beside
/// characters neither escapes: a topic name holding an escape's own text,
/// quotes and a newline, a backslash before a quote, a backslash before n.
TopologyGraph escapesGraph() => TopologyGraph(
  topologies: <TopologyDefinition>[
    TopologyDefinition(
      topologyId: r"a&b|c{d}e[f]g'h$i",
      scope: Scope.page,
      transforms: <TransformEdge>[
        TransformEdge.stage(CombinatorKind.map, <EdgeInput>[
          TopicInput(eventRef('esc.#quot;', 'Map<String, int>')),
        ], transformer: FunctionRef.named(r'f"#<>\x')),
        TransformEdge.stage(
          CombinatorKind.switchMap,
          <EdgeInput>[const StageInput(0)],
          transformer: FunctionRef.named('g'),
          retry: FunctionRef.named('r\nq'),
        ),
        TransformEdge.write(eventRef(r'esc.\"'), const StageInput(1)),
        TransformEdge.write(
          eventRef(r'esc.\n'),
          TopicInput(stateRef('esc."a"\nb', r'C:\path'), dedup: Dedup.equality),
        ),
      ],
    ),
  ],
  claims: <ShellClaim>[
    ShellClaim(
      source: const ServiceSource('a"b#c'),
      scope: Scope.module,
      writes: <TopicRef>{stateRef('esc."a"\nb', r'C:\path')},
    ),
  ],
);

/// The graphs above and every sample, for the checks that hold of any
/// rendering.
List<TopologyGraph> everyGraph() => <TopologyGraph>[
  TopologyGraph(),
  for (final (Duration duration, String _) in durationTexts)
    delayGraph(duration),
  timeStagesGraph(),
  functionsGraph(),
  arrowsGraph(),
  typeNamesGraph(),
  escapesGraph(),
  for (final String name in sampleNames()) sampleGraph(name),
];

/// What [render] returns, and how many timers, periodic timers and
/// microtasks it created or scheduled.
(List<String>, int) countingScheduled(List<String> Function() render) {
  var scheduled = 0;
  final List<String> texts = runZoned(
    render,
    zoneSpecification: ZoneSpecification(
      createTimer:
          (
            Zone self,
            ZoneDelegate parent,
            Zone zone,
            Duration duration,
            void Function() f,
          ) {
            scheduled++;
            return parent.createTimer(zone, duration, f);
          },
      createPeriodicTimer:
          (
            Zone self,
            ZoneDelegate parent,
            Zone zone,
            Duration period,
            void Function(Timer timer) f,
          ) {
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
  return (texts, scheduled);
}
