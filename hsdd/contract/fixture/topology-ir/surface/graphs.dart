// Surface fixture for topology-ir@v1: the library topology_ir.dart, used the
// way the runtime's activation checks and bus.toGraph(), and the tooling's
// catalog, checks and emitters use it. Every declaration appears with the
// types the Interface states; the switch over TopologyFinding is exhaustive
// and GraphRenderer is implemented. Passes when
// `fvm dart analyze --fatal-infos` reports nothing on it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';

const StateTopic<int> route = StateTopic<int>(name: 'nav.depth', initial: 0);

/// A shell publisher's claim, as the bus or a workspace scan states it.
final ShellClaim navigator = ShellClaim(
  source: const ExecutorSource('flutter-navigation'),
  writes: <TopicRef>{route.ref},
);
final ShellClaim page = ShellClaim(
  source: const PageSource('settings/profile'),
  scope: Scope.page,
  writes: <TopicRef>{route.ref},
);

TopologyGraph graphOf(List<Topology> topologies) {
  final TopologyGraph graph = TopologyGraph(
    topologies: <TopologyDefinition>[
      for (final Topology t in topologies) t.buildDefinition(),
    ],
    claims: <ShellClaim>[navigator, page],
  );
  final List<TopologyDefinition> definitions = graph.topologies;
  final List<ShellClaim> claims = graph.claims;
  final List<TopicRef> topics = graph.topics;
  final MessageSource source = claims.first.source;
  final Scope scope = claims.first.scope;
  final Set<TopicRef> writes = claims.first.writes;
  return definitions.isEmpty && topics.isEmpty && writes.isEmpty && '$source $scope'.isEmpty
      ? TopologyGraph()
      : graph;
}

final TopologyGraph single = topology('single', Scope.page, (TopologyBuilder b) {
  b.write(const EventTopic<int>(name: 'demo.out'), b.read(const EventTopic<int>(name: 'demo.in')));
}).buildDefinition().toGraph();

/// The renderers, and one an application writes.
final class EdgeCount implements GraphRenderer {
  const EdgeCount();

  @override
  String render(TopologyGraph graph) =>
      '${graph.topologies.fold<int>(0, (int n, TopologyDefinition d) => n + d.transforms.length)}';
}

final List<String> renderings = <String>[
  single.render(const MermaidRenderer()),
  single.render(const GraphvizRenderer()),
  single.render(const JsonRenderer()),
  single.render(const EdgeCount()),
  const MermaidRenderer().render(single),
];

/// The JSON form: a graph document and the definition objects it lists.
final Map<String, Object?> document = encodeTopologyGraph(single);
final TopologyGraph decoded = decodeTopologyGraph(document);
final Map<String, Object?> definitionObject = encodeTopologyDefinition(single.topologies.single);
final TopologyDefinition decodedDefinition = decodeTopologyDefinition(definitionObject);

/// The analyses, and every finding's fields with their types.
List<String> check(TopologyGraph graph) {
  final List<TopologyCycle> cycles = findTopologyCycles(graph);
  final List<SelfReference> selfReferences = <SelfReference>[
    for (final TopologyDefinition d in graph.topologies) ...findSelfReferences(d),
  ];
  final List<WriterConflict> conflicts = findWriterConflicts(graph);
  final List<ScopeViolation> violations = findScopeViolations(graph);
  final List<TopologyFinding> all = analyzeTopologyGraph(graph);
  return <String>[
    '${cycles.length} ${selfReferences.length} ${conflicts.length} ${violations.length}',
    for (final TopologyFinding f in all) describe(f),
  ];
}

String describe(TopologyFinding f) => switch (f) {
      TopologyCycle(:final List<String> topologyIds, :final List<TopicRef> topics) =>
        'cycle $topologyIds ${topics.length}',
      SelfReference(:final String topologyId, :final TopicRef topic, :final List<int> edges) =>
        'self $topologyId ${topic.name} $edges',
      WriterConflict(:final TopicRef topic, :final List<MessageSource> writers) =>
        'writers ${topic.name} $writers',
      ScopeViolation(
        :final TopicRef topic,
        :final MessageSource owner,
        :final Scope ownerScope,
        :final String readerId,
        :final Scope readerScope,
      ) =>
        'scope ${topic.name} $owner ${ownerScope.name} $readerId ${readerScope.name}',
    };

/// Findings are values a test or a diagnostic mapper can construct.
final List<TopologyFinding> constructed = <TopologyFinding>[
  TopologyCycle(topologyIds: <String>['a', 'b'], topics: <TopicRef>[route.ref]),
  SelfReference(topologyId: 'a', topic: route.ref, edges: <int>[0]),
  WriterConflict(topic: route.ref, writers: <MessageSource>[navigator.source, page.source]),
  ScopeViolation(
    topic: route.ref,
    owner: const TopologySource('a'),
    ownerScope: Scope.page,
    readerId: 'b',
    readerScope: Scope.application,
  ),
  pageOwned,
];

/// A finding built as a constant, as a diagnostic mapper's table may hold
/// one: ScopeViolation's constructor is const.
const ScopeViolation pageOwned = ScopeViolation(
  topic: TopicRef(name: 'nav.depth', variant: TopicVariant.state, typeName: 'int'),
  owner: PageSource('settings/profile'),
  ownerScope: Scope.page,
  readerId: 'b',
  readerScope: Scope.application,
);

/// Topic name uniqueness over declarations a scan found.
List<String> collisions(List<TopicDeclaration> declarations) => <String>[
      for (final TopicNameCollision c in findTopicNameCollisions(declarations))
        '${c.name}: ${c.declarations.map((TopicDeclaration d) => '${d.topic.typeName} at ${d.site}').join(', ')}',
    ];

final List<String> found = collisions(<TopicDeclaration>[
  TopicDeclaration(topic: route.ref, site: 'lib/nav_topics.dart:3'),
  const TopicDeclaration(
      topic: TopicRef(name: 'nav.depth', variant: TopicVariant.event, typeName: 'int'),
      site: 'lib/other_topics.dart:9'),
]);
