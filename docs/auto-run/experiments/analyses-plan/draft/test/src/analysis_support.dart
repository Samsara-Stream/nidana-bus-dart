// What the tests of topology-ir@v1's analyses share: topic references and
// definitions written in one line, and graphs generated from a seed with
// dart:math for the property tests (nidana.model.12 Scope), so that a failure
// names the seed that reproduces it and the package takes no dependency
// beyond test (ADR-002 item 3).
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

/// How many seeds each property runs.
const int seeds = 500;

TopicRef state(String name, [String type = 'int']) =>
    TopicRef(name: name, variant: TopicVariant.state, typeName: type);

TopicRef event(String name) =>
    TopicRef(name: name, variant: TopicVariant.event, typeName: 'int');

TopicRef replay(String name) =>
    TopicRef(name: name, variant: TopicVariant.replay, typeName: 'int');

final FunctionRef f = FunctionRef.named('f');

TopologyDefinition define(
  String id,
  List<TransformEdge> transforms, {
  Scope scope = Scope.page,
}) => TopologyDefinition(topologyId: id, scope: scope, transforms: transforms);

/// A map stage of [input].
TransformEdge map(EdgeInput input) =>
    TransformEdge.stage(CombinatorKind.map, <EdgeInput>[input], transformer: f);

/// A topology that reads each of [reads] into one merge and writes each of
/// [writes] from it.
TopologyDefinition rw(
  String id,
  List<TopicRef> reads,
  List<TopicRef> writes, {
  Scope scope = Scope.page,
}) => define(id, <TransformEdge>[
  TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
    for (final TopicRef read in reads) TopicInput(read),
  ]),
  for (final TopicRef write in writes)
    TransformEdge.write(write, const StageInput(0)),
], scope: scope);

/// The topics a generated graph draws from: four state topics, two event
/// topics and one replay topic.
final List<TopicRef> topicPool = <TopicRef>[
  state('gen.a'),
  state('gen.b'),
  state('gen.c'),
  state('gen.d'),
  event('gen.e'),
  event('gen.f'),
  replay('gen.r'),
];

/// The sources a generated claim draws from.
const List<MessageSource> claimSources = <MessageSource>[
  ServiceSource('sync'),
  ServiceSource('cache'),
  PageSource('form'),
  ExecutorSource('nav'),
];

T _pick<T>(Random random, List<T> from) => from[random.nextInt(from.length)];

/// A read of a pool topic; a state topic's read sometimes with a dedup
/// argument.
TopicInput _read(Random random) {
  final TopicRef topic = _pick(random, topicPool);
  return topic.variant == TopicVariant.state && random.nextInt(4) == 0
      ? TopicInput(topic, dedup: _pick(random, Dedup.values))
      : TopicInput(topic);
}

/// A stage edge of [input], [index] being the index it takes: half of the
/// kinds bear state, and a merge also takes a pool read or an earlier stage.
TransformEdge _stage(Random random, EdgeInput input, int index) =>
    switch (random.nextInt(8)) {
      0 => map(input),
      1 => TransformEdge.stage(CombinatorKind.debounce, <EdgeInput>[
        input,
      ], duration: Duration.zero),
      2 => TransformEdge.stage(CombinatorKind.throttle, <EdgeInput>[
        input,
      ], duration: const Duration(milliseconds: 10)),
      3 => TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        input,
        if (index > 0 && random.nextBool())
          StageInput(random.nextInt(index))
        else
          _read(random),
      ]),
      4 => TransformEdge.stage(CombinatorKind.scan, <EdgeInput>[
        input,
      ], transformer: f),
      5 => TransformEdge.stage(CombinatorKind.delay, <EdgeInput>[
        input,
      ], duration: const Duration(milliseconds: 10)),
      6 => TransformEdge.stage(CombinatorKind.sample, <EdgeInput>[
        input,
      ], duration: const Duration(microseconds: 1)),
      _ => TransformEdge.stage(CombinatorKind.buffer, <EdgeInput>[
        input,
      ], duration: const Duration(seconds: 1)),
    };

/// A generated definition: one to three chains, each a pool read through up
/// to three stages, then one sink per chain and a second sink on the last
/// chain's end half of the time: a write of a pool topic, or a reduceInto
/// of a state topic, never two sinks on one state topic.
TopologyDefinition generatedTopology(Random random, String id) {
  final Scope scope = _pick(random, Scope.values);
  final List<TransformEdge> stages = <TransformEdge>[];
  final List<EdgeInput> ends = <EdgeInput>[];
  for (int chain = 0, chains = 1 + random.nextInt(3); chain < chains; chain++) {
    EdgeInput end = _read(random);
    for (int s = 0, length = random.nextInt(4); s < length; s++) {
      stages.add(_stage(random, end, stages.length));
      end = StageInput(stages.length - 1);
    }
    ends.add(end);
  }
  if (random.nextBool()) {
    ends.add(ends.last);
  }
  final Set<TopicRef> sunk = <TopicRef>{};
  final List<TransformEdge> sinks = <TransformEdge>[];
  for (final EdgeInput end in ends) {
    final List<TopicRef> open = <TopicRef>[
      for (final TopicRef topic in topicPool)
        if (!sunk.contains(topic)) topic,
    ];
    final TopicRef topic = _pick(random, open);
    if (topic.variant == TopicVariant.state) {
      sunk.add(topic);
    }
    sinks.add(
      topic.variant == TopicVariant.state && random.nextInt(4) == 0
          ? TransformEdge.reduceInto(topic, end, f)
          : TransformEdge.write(topic, end),
    );
  }
  return define(id, <TransformEdge>[...stages, ...sinks], scope: scope);
}

/// A generated claim: a pool source, any scope, one or two pool state
/// topics.
ShellClaim generatedClaim(Random random) {
  final MessageSource source = _pick(random, claimSources);
  final Scope scope = _pick(random, Scope.values);
  final List<TopicRef> states = <TopicRef>[
    for (final TopicRef topic in topicPool)
      if (topic.variant == TopicVariant.state) topic,
  ];
  return ShellClaim(
    source: source,
    scope: scope,
    writes: <TopicRef>{
      for (int i = 0, n = 1 + random.nextInt(2); i < n; i++)
        _pick(random, states),
    },
  );
}

/// The topologies and claims a seed generates, in generation order.
typedef GraphParts = ({
  List<TopologyDefinition> topologies,
  List<ShellClaim> claims,
});

/// Up to five topologies with the ids t0 to t4 and up to two claims.
GraphParts generatedParts(int seed) {
  final Random random = Random(seed);
  final List<TopologyDefinition> topologies = <TopologyDefinition>[
    for (int i = 0, n = random.nextInt(6); i < n; i++)
      generatedTopology(random, 't$i'),
  ];
  final List<ShellClaim> claims = <ShellClaim>[
    for (int i = 0, n = random.nextInt(3); i < n; i++) generatedClaim(random),
  ];
  return (topologies: topologies, claims: claims);
}

TopologyGraph graphOf(GraphParts parts) =>
    TopologyGraph(topologies: parts.topologies, claims: parts.claims);

TopologyGraph generatedGraph(int seed) => graphOf(generatedParts(seed));
