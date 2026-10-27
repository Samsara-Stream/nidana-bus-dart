import '../graph/graph.dart';
import '../ir/canonical_order.dart';
import '../ir/definition.dart';
import '../topic/message_source.dart';
import '../topic/scope.dart';
import '../topic/topic.dart';
import 'findings.dart';

// One cycle per strongly connected set of two or more topologies of the
// graph's arcs (G13), each with its members' ids and the topics between
// them, ordered by the first of its ids.
List<TopologyCycle> findTopologyCycles(TopologyGraph graph) {
  final List<TopologyDefinition> topologies = graph.topologies;
  final Map<TopicRef, List<int>> readers = _readers(topologies);
  final List<TopologyCycle> cycles = <TopologyCycle>[
    for (final List<int> component in _components(_arcs(topologies, readers)))
      if (component.length > 1) _cycle(topologies, component.toSet(), readers),
  ];
  cycles.sort(
    (TopologyCycle a, TopologyCycle b) =>
        compareTopologyIds(a.topologyIds.first, b.topologyIds.first),
  );
  return List<TopologyCycle>.unmodifiable(cycles);
}

// Every topic the topologies read, with the indices of the topologies that
// read it, ascending.
Map<TopicRef, List<int>> _readers(List<TopologyDefinition> topologies) {
  final Map<TopicRef, List<int>> readers = <TopicRef, List<int>>{};
  for (int i = 0; i < topologies.length; i++) {
    for (final TopicRef topic in topologies[i].reads) {
      (readers[topic] ??= <int>[]).add(i);
    }
  }
  return readers;
}

// The arcs of [topologies], by index: from each topology to every other one
// that reads a topic it writes, of any variant, ascending. A topology that
// reads its own write has no arc to itself (G13).
List<List<int>> _arcs(
  List<TopologyDefinition> topologies,
  Map<TopicRef, List<int>> readers,
) => <List<int>>[
  for (int i = 0; i < topologies.length; i++)
    <int>{
      for (final TopicRef topic in topologies[i].writes)
        for (final int reader in readers[topic] ?? const <int>[])
          if (reader != i) reader,
    }.toList()..sort(),
];

// The strongly connected components of the graph whose arcs [arcs] lists,
// each as the indices of its members, by Tarjan's algorithm. The depth-first
// search keeps its path in a list rather than on the call stack, so a chain
// of arcs of any length is searched without a StackOverflowError.
List<List<int>> _components(List<List<int>> arcs) {
  final List<int?> order = List<int?>.filled(arcs.length, null);
  final List<int> low = List<int>.filled(arcs.length, 0);
  final List<bool> open = List<bool>.filled(arcs.length, false);
  final List<int> stack = <int>[];
  final List<int> path = <int>[];
  final List<int> followed = <int>[];
  final List<List<int>> components = <List<int>>[];
  int visited = 0;
  void enter(int v) {
    order[v] = low[v] = visited++;
    stack.add(v);
    open[v] = true;
    path.add(v);
    followed.add(0);
  }

  for (int root = 0; root < arcs.length; root++) {
    if (order[root] != null) {
      continue;
    }
    enter(root);
    while (path.isNotEmpty) {
      final int v = path.last;
      final int next = followed.last;
      if (next < arcs[v].length) {
        followed.last = next + 1;
        final int w = arcs[v][next];
        if (order[w] == null) {
          enter(w);
        } else if (open[w] && order[w]! < low[v]) {
          low[v] = order[w]!;
        }
        continue;
      }
      path.removeLast();
      followed.removeLast();
      if (path.isNotEmpty && low[v] < low[path.last]) {
        low[path.last] = low[v];
      }
      if (low[v] == order[v]) {
        final List<int> component = <int>[];
        int w;
        do {
          w = stack.removeLast();
          open[w] = false;
          component.add(w);
        } while (w != v);
        components.add(component);
      }
    }
  }
  return components;
}

// The cycle of the topologies at [members]: their ids, and each topic that
// one member writes and another member reads, once (G13). The constructor
// sorts both lists and keeps repeated elements (G23), so the topics are
// collected in a set.
TopologyCycle _cycle(
  List<TopologyDefinition> topologies,
  Set<int> members,
  Map<TopicRef, List<int>> readers,
) => TopologyCycle(
  topologyIds: <String>[
    for (final int member in members) topologies[member].topologyId,
  ],
  topics: <TopicRef>{
    for (final int writer in members)
      for (final TopicRef topic in topologies[writer].writes)
        if ((readers[topic] ?? const <int>[]).any(
          (int reader) => reader != writer && members.contains(reader),
        ))
          topic,
  }.toList(),
);

// One self-reference per topic that [definition] both reads and writes, in
// canonical order, with an unmediated path from a read of it to a write of
// it, listing every edge on such a path (G14).
List<SelfReference> findSelfReferences(TopologyDefinition definition) =>
    List<SelfReference>.unmodifiable(<SelfReference>[
      for (final TopicRef topic in definition.reads)
        if (definition.writes.contains(topic))
          if (_unmediated(definition.transforms, topic)
              case final List<int> edges when edges.isNotEmpty)
            SelfReference(
              topologyId: definition.topologyId,
              topic: topic,
              edges: edges,
            ),
    ]);

// The indices, ascending and each once, of the edges on an unmediated path
// from a read of [topic] to a write of it (G14): the edges that bear no
// state, that a read of [topic] reaches through edges bearing none, and that
// reach a write of [topic] through edges bearing none. A stage input names
// an earlier edge (G6), so one pass forward and one backward decide both. A
// read matches by its topic, whatever its dedup argument, and a reduceInto
// bears state, so it ends no unmediated path.
List<int> _unmediated(List<TransformEdge> edges, TopicRef topic) {
  final List<bool> fromRead = <bool>[];
  for (final TransformEdge edge in edges) {
    fromRead.add(
      !edge.isStateBearing &&
          edge.inputs.any(
            (EdgeInput input) => switch (input) {
              TopicInput(topic: final TopicRef read) => read == topic,
              StageInput(edge: final int stage) => fromRead[stage],
            },
          ),
    );
  }
  final List<bool> toWrite = List<bool>.filled(edges.length, false);
  final List<bool> feedsWrite = List<bool>.filled(edges.length, false);
  for (int i = edges.length - 1; i >= 0; i--) {
    final TransformEdge edge = edges[i];
    toWrite[i] =
        !edge.isStateBearing && (edge.output == topic || feedsWrite[i]);
    if (toWrite[i]) {
      for (final EdgeInput input in edge.inputs) {
        if (input case StageInput(edge: final int stage)) {
          feedsWrite[stage] = true;
        }
      }
    }
  }
  return <int>[
    for (int i = 0; i < edges.length; i++)
      if (fromRead[i] && toWrite[i]) i,
  ];
}

// One writer conflict per state topic of the graph, in canonical order, with
// two or more owners: every topology that writes it, as its topology source,
// and every claim that claims it, one entry per claim (G15).
List<WriterConflict> findWriterConflicts(TopologyGraph graph) =>
    List<WriterConflict>.unmodifiable(<WriterConflict>[
      for (final TopicRef topic in graph.topics)
        if (_owners(graph, topic) case final List<_Owner> owners
            when owners.length > 1)
          WriterConflict(
            topic: topic,
            writers: <MessageSource>[
              for (final _Owner owner in owners) owner.source,
            ],
          ),
    ]);

// One scope violation per state topic, owner and reading topology where the
// owner's scope is not at least as long as the reader's (G16): by topic in
// canonical order, then owner by its source's rendering and then its scope,
// then reader in graph order. Equal owners, such as two equal claims, give
// one violation per reader, so the set keeps each once, in that order.
List<ScopeViolation> findScopeViolations(TopologyGraph graph) =>
    List<ScopeViolation>.unmodifiable(<ScopeViolation>{
      for (final TopicRef topic in graph.topics)
        for (final _Owner owner in _owners(graph, topic)..sort(_byOwner))
          for (final TopologyDefinition reader in graph.topologies)
            if (reader.reads.contains(topic) &&
                !owner.scope.isAtLeastAsLongAs(reader.scope))
              ScopeViolation(
                topic: topic,
                owner: owner.source,
                ownerScope: owner.scope,
                readerId: reader.topologyId,
                readerScope: reader.scope,
              ),
    });

// A writer of a state topic with the scope it owns it in (Spec §3.11, §7.2).
typedef _Owner = ({MessageSource source, Scope scope});

// The owners of [topic] when it is a state topic: the topologies whose
// writes hold it, as their topology sources with their scopes, in graph
// order, then the claims whose writes hold it, one entry per claim, in graph
// order. None for an event or replay topic, which has no owner (Spec §3.11).
List<_Owner> _owners(TopologyGraph graph, TopicRef topic) => <_Owner>[
  if (topic.variant == TopicVariant.state) ...<_Owner>[
    for (final TopologyDefinition topology in graph.topologies)
      if (topology.writes.contains(topic))
        (source: TopologySource(topology.topologyId), scope: topology.scope),
    for (final ShellClaim claim in graph.claims)
      if (claim.writes.contains(topic))
        (source: claim.source, scope: claim.scope),
  ],
];

// The order of owners in scope violations: by the source's rendering, then
// by scope (application, module, page).
int _byOwner(_Owner a, _Owner b) {
  final int bySource = compareMessageSources(a.source, b.source);
  return bySource != 0 ? bySource : a.scope.index.compareTo(b.scope.index);
}

/// Every finding: cycles, then the self-references of each topology in graph
/// order, then writer conflicts, then scope violations.
List<TopologyFinding> analyzeTopologyGraph(TopologyGraph graph) =>
    throw UnimplementedError();

List<TopicNameCollision> findTopicNameCollisions(
  Iterable<TopicDeclaration> declarations,
) => throw UnimplementedError();
