// What the tests of topology-ir@v1's JSON form share: the files under
// hsdd/contract/fixture/topology-ir/, the Interface's example, and graphs
// generated from a seed with dart:math for the property tests (nidana.model.13
// Scope), so that a failure names the seed that reproduces it and the package
// takes no dependency beyond test (ADR-002 item 3).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

import 'package_files.dart';

/// The text of [relative], a path under hsdd/contract/fixture/topology-ir/.
String fixtureText(String relative) =>
    File('${workspaceRoot().path}/hsdd/contract/fixture/topology-ir/$relative')
        .readAsStringSync();

/// The JSON value of [relative], a path under
/// hsdd/contract/fixture/topology-ir/.
Object? fixtureJson(String relative) => jsonDecode(fixtureText(relative));

/// topology-ir@v1's example graph document (the Interface, The JSON form),
/// laid out compactly as the contract shows it.
const String interfaceExample = '''
{
  "format": "topology-ir@v1",
  "topologies": [
    {
      "topologyId": "search",
      "scope": "page",
      "reads": [{ "name": "search.query", "variant": "state", "typeName": "String" }],
      "writes": [{ "name": "search.results", "variant": "state", "typeName": "Results" }],
      "transforms": [
        {
          "combinator": "debounce",
          "inputs": [{ "topic": { "name": "search.query", "variant": "state", "typeName": "String" }, "dedup": "none" }],
          "durationMicros": 300000
        },
        {
          "combinator": "switchMap",
          "inputs": [{ "edge": 0 }],
          "transformer": { "name": "searchApi" },
          "retry": { "name": null }
        },
        {
          "inputs": [{ "edge": 1 }],
          "output": { "name": "search.results", "variant": "state", "typeName": "Results" }
        }
      ]
    }
  ],
  "claims": [
    {
      "source": "service:search-history",
      "scope": "application",
      "writes": [{ "name": "search.history", "variant": "state", "typeName": "History" }]
    }
  ]
}
''';

/// The graph [interfaceExample] describes, built from IR values.
TopologyGraph interfaceExampleGraph() {
  const TopicRef query = TopicRef(
    name: 'search.query',
    variant: TopicVariant.state,
    typeName: 'String',
  );
  const TopicRef results = TopicRef(
    name: 'search.results',
    variant: TopicVariant.state,
    typeName: 'Results',
  );
  const TopicRef history = TopicRef(
    name: 'search.history',
    variant: TopicVariant.state,
    typeName: 'History',
  );
  return TopologyGraph(
    topologies: <TopologyDefinition>[
      TopologyDefinition(
        topologyId: 'search',
        scope: Scope.page,
        transforms: <TransformEdge>[
          TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[
            const TopicInput(query, dedup: Dedup.none),
          ], duration: const Duration(milliseconds: 300)),
          TransformEdge.stage(
            CombinatorKind.switchMap,
            <EdgeInput>[const StageInput(0)],
            transformer: FunctionRef.named('searchApi'),
            retry: const FunctionRef.anonymous(),
          ),
          TransformEdge.write(results, const StageInput(1)),
        ],
      ),
    ],
    claims: <ShellClaim>[
      ShellClaim(
        source: const ServiceSource('search-history'),
        writes: <TopicRef>{history},
      ),
    ],
  );
}

// ------------------------------------------------------------ generated

/// How many seeds each property runs.
const int seeds = 500;

/// The `.json` files of [set], valid or invalid, by name without extension,
/// in name order.
List<String> fixtureNames(String set) => <String>[
  for (final FileSystemEntity f in Directory(
    '${workspaceRoot().path}/hsdd/contract/fixture/topology-ir/$set',
  ).listSync())
    if (f is File && f.path.endsWith('.json'))
      f.uri.pathSegments.last.replaceAll('.json', ''),
]..sort();

/// The topics a generated graph draws from: every variant, one name under
/// two variants and two types, an empty name, names and type names the
/// escaping sample uses. No type name is empty (the schema's minLength).
const List<TopicRef> generatedTopics = <TopicRef>[
  TopicRef(name: 'gen.a', variant: TopicVariant.state, typeName: 'int'),
  TopicRef(name: 'gen.a', variant: TopicVariant.state, typeName: 'String'),
  TopicRef(name: 'gen.a', variant: TopicVariant.event, typeName: 'int'),
  TopicRef(name: '', variant: TopicVariant.state, typeName: 'int?'),
  TopicRef(name: 'gen.s', variant: TopicVariant.state, typeName: 'bool'),
  TopicRef(
    name: 'odd "q" #1 <t> café\nline',
    variant: TopicVariant.replay,
    typeName: 'List<Map<String, int>>',
  ),
  TopicRef(
    name: r'odd.back\slash',
    variant: TopicVariant.event,
    typeName: '({int a, String b})',
  ),
  TopicRef(name: 'gen.r', variant: TopicVariant.replay, typeName: 'int'),
];

/// The function references a generated edge draws from: anonymous, and
/// names as the VM renders them, private and constructor tear-offs included.
final List<FunctionRef> generatedFunctions = <FunctionRef>[
  const FunctionRef.anonymous(),
  FunctionRef.named('f'),
  FunctionRef.named(r'to$Label'),
  FunctionRef.named('_reduce@22518013'),
  FunctionRef.named('Box.'),
  FunctionRef.named('naïve "q"'),
];

/// The durations a generated time stage draws from, zero included.
const List<Duration> generatedDurations = <Duration>[
  Duration.zero,
  Duration(microseconds: 1),
  Duration(microseconds: 1500),
  Duration(milliseconds: 300),
  Duration(seconds: 2),
  Duration(days: 365000),
];

/// The sources a generated claim draws from, one of each shell kind.
const List<MessageSource> generatedSources = <MessageSource>[
  ServiceSource('sync'),
  PageSource('checkout/cart?step="2"'),
  ExecutorSource('a:b'),
];

/// The topology ids a generated graph draws from.
const List<String> generatedIds = <String>['t0', 't1', ' ', 'odd "id"', 'é'];

T _pick<T>(Random random, List<T> from) => from[random.nextInt(from.length)];

/// A read of a pool topic, with a dedup half the time when the topic is a
/// state topic and never otherwise (the schema allows none there).
TopicInput _read(Random random) {
  final TopicRef topic = _pick(random, generatedTopics);
  return topic.variant == TopicVariant.state && random.nextBool()
      ? TopicInput(topic, dedup: _pick(random, Dedup.values))
      : TopicInput(topic);
}

/// An input of the stage edge at [index]: an earlier stage or a read.
EdgeInput _inputOf(Random random, int index) => index > 0 && random.nextBool()
    ? StageInput(random.nextInt(index))
    : _read(random);

/// A stage edge at [index] of any kind but reduceInto, with the inputs,
/// transformer, duration and retry its kind takes.
TransformEdge _stage(Random random, int index) {
  final CombinatorKind kind = _pick(
    random,
    CombinatorKind.values
        .where((CombinatorKind k) => k != CombinatorKind.reduceInto)
        .toList(),
  );
  final int count = switch (kind) {
    CombinatorKind.combine || CombinatorKind.merge => 1 + random.nextInt(4),
    CombinatorKind.withLatestFrom => 2 + random.nextInt(3),
    _ => 1,
  };
  final List<EdgeInput> inputs = <EdgeInput>[
    for (int i = 0; i < count; i++) _inputOf(random, index),
  ];
  return switch (kind) {
    CombinatorKind.merge ||
    CombinatorKind.pairwise ||
    CombinatorKind.distinctUntilChanged => TransformEdge.stage(kind, inputs),
    CombinatorKind.debounce ||
    CombinatorKind.throttle ||
    CombinatorKind.delay ||
    CombinatorKind.sample ||
    CombinatorKind.buffer ||
    CombinatorKind.timeout => TransformEdge.stage(
      kind,
      inputs,
      duration: _pick(random, generatedDurations),
    ),
    CombinatorKind.switchMap => TransformEdge.stage(
      kind,
      inputs,
      transformer: _pick(random, generatedFunctions),
      retry: random.nextBool() ? _pick(random, generatedFunctions) : null,
    ),
    _ => TransformEdge.stage(
      kind,
      inputs,
      transformer: _pick(random, generatedFunctions),
    ),
  };
}

/// A generated definition: up to six stage edges, then one sink for each
/// stage edge no later edge consumes and up to two more, each a write of a
/// pool topic or a reduceInto of a state topic, never two sinks on one state
/// topic.
TopologyDefinition generatedDefinition(Random random, String id) {
  final List<TransformEdge> stages = <TransformEdge>[
    for (int i = 0, n = random.nextInt(7); i < n; i++) _stage(random, i),
  ];
  final Set<int> consumed = <int>{
    for (final TransformEdge stage in stages)
      for (final EdgeInput input in stage.inputs)
        if (input is StageInput) input.edge,
  };
  final List<EdgeInput> ends = <EdgeInput>[
    for (int i = 0; i < stages.length; i++)
      if (!consumed.contains(i)) StageInput(i),
    for (int i = 0, n = random.nextInt(3); i < n; i++)
      _inputOf(random, stages.length),
  ];
  final Set<TopicRef> sunk = <TopicRef>{};
  final List<TransformEdge> sinks = <TransformEdge>[];
  for (final EdgeInput end in ends) {
    final TopicRef topic = _pick(random, <TopicRef>[
      for (final TopicRef t in generatedTopics)
        if (!sunk.contains(t)) t,
    ]);
    if (topic.variant == TopicVariant.state) {
      sunk.add(topic);
    }
    sinks.add(
      topic.variant == TopicVariant.state && random.nextBool()
          ? TransformEdge.reduceInto(
              topic,
              end,
              _pick(random, generatedFunctions),
            )
          : TransformEdge.write(topic, end),
    );
  }
  return TopologyDefinition(
    topologyId: id,
    scope: _pick(random, Scope.values),
    transforms: <TransformEdge>[...stages, ...sinks],
  );
}

/// A generated claim: a pool source, any scope, one to three pool state
/// topics.
ShellClaim generatedClaim(Random random) => ShellClaim(
  source: _pick(random, generatedSources),
  scope: _pick(random, Scope.values),
  writes: <TopicRef>{
    for (int i = 0, n = 1 + random.nextInt(3); i < n; i++)
      _pick(random, <TopicRef>[
        for (final TopicRef t in generatedTopics)
          if (t.variant == TopicVariant.state) t,
      ]),
  },
);

/// The graph [seed] generates: up to four topologies with distinct pool ids,
/// up to three claims.
TopologyGraph generatedGraph(int seed) {
  final Random random = Random(seed);
  final List<String> ids = List<String>.of(generatedIds)..shuffle(random);
  return TopologyGraph(
    topologies: <TopologyDefinition>[
      for (int i = 0, n = random.nextInt(5); i < n; i++)
        generatedDefinition(random, ids[i]),
    ],
    claims: <ShellClaim>[
      for (int i = 0, n = random.nextInt(4); i < n; i++) generatedClaim(random),
    ],
  );
}
