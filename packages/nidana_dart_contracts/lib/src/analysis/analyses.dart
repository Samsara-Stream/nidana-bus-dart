import '../graph/graph.dart';
import '../ir/canonical_order.dart';
import '../ir/definition.dart';
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

List<SelfReference> findSelfReferences(TopologyDefinition definition) =>
    throw UnimplementedError();
List<WriterConflict> findWriterConflicts(TopologyGraph graph) =>
    throw UnimplementedError();
List<ScopeViolation> findScopeViolations(TopologyGraph graph) =>
    throw UnimplementedError();

/// Every finding: cycles, then the self-references of each topology in graph
/// order, then writer conflicts, then scope violations.
List<TopologyFinding> analyzeTopologyGraph(TopologyGraph graph) =>
    throw UnimplementedError();

List<TopicNameCollision> findTopicNameCollisions(
  Iterable<TopicDeclaration> declarations,
) => throw UnimplementedError();
