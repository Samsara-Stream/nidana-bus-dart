// topology-ir@v1's findTopologyCycles (G13), beyond the two G13 cases of its
// conformance suite, which the gate replays: cycles ordered by their first
// id whatever order a search meets them in, the topics between members only
// and each once, arcs of every variant and through any stage, a long ring,
// an unmodifiable result (G3), and the cycles of generated graphs against a
// brute-force reachability check.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/analysis_support.dart';

const EventTopic<int> clicks = EventTopic<int>(name: 'loop.clicks');
const StateTopic<int> total = StateTopic<int>(name: 'loop.total', initial: 0);

int add(int a, int b) => a + b;

/// The cycles of [graph] by brute force: one topology reaches another when a
/// chain of one or more arcs leads there (Warshall's closure over the arcs
/// between distinct topologies), and two belong to one cycle when each
/// reaches the other. Graph order is id order, so each cycle is met at its
/// first id, and the cycles come in the order of their first ids.
List<TopologyCycle> reachabilityCycles(TopologyGraph graph) {
  final List<TopologyDefinition> ts = graph.topologies;
  final int n = ts.length;
  final List<List<bool>> reach = <List<bool>>[
    for (int i = 0; i < n; i++)
      <bool>[
        for (int j = 0; j < n; j++)
          i != j && ts[i].writes.any(ts[j].reads.contains),
      ],
  ];
  for (int k = 0; k < n; k++) {
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        reach[i][j] = reach[i][j] || (reach[i][k] && reach[k][j]);
      }
    }
  }
  final Set<int> placed = <int>{};
  final List<TopologyCycle> cycles = <TopologyCycle>[];
  for (int i = 0; i < n; i++) {
    if (placed.contains(i)) {
      continue;
    }
    final List<int> members = <int>[
      i,
      for (int j = 0; j < n; j++)
        if (j != i && reach[i][j] && reach[j][i]) j,
    ];
    placed.addAll(members);
    if (members.length > 1) {
      cycles.add(
        TopologyCycle(
          topologyIds: <String>[for (final int m in members) ts[m].topologyId],
          topics: <TopicRef>{
            for (final int a in members)
              for (final int b in members)
                if (a != b) ...ts[a].writes.where(ts[b].reads.contains),
          }.toList(),
        ),
      );
    }
  }
  return cycles;
}

void main() {
  test('G13 cycles come in the order of their first ids, whichever cycle a '
      'search from the first topology completes first', () {
    // b reaches m through y, so a search from b completes {m, z} first.
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('m', <TopicRef>[event('m.in')], <TopicRef>[event('z.in')]),
        rw('z', <TopicRef>[event('z.in')], <TopicRef>[event('m.in')]),
        rw(
          'y',
          <TopicRef>[event('y.in')],
          <TopicRef>[event('b.in'), event('m.in')],
        ),
        rw('b', <TopicRef>[event('b.in')], <TopicRef>[event('y.in')]),
      ],
    );
    expect(findTopologyCycles(g), <TopologyCycle>[
      TopologyCycle(
        topologyIds: <String>['b', 'y'],
        topics: <TopicRef>[event('b.in'), event('y.in')],
      ),
      TopologyCycle(
        topologyIds: <String>['m', 'z'],
        topics: <TopicRef>[event('m.in'), event('z.in')],
      ),
    ]);
  });

  test('G13 a cycle lists each topic one member writes and another member '
      'reads, of every variant, once; not a member\'s own self-read, nor a '
      'topic between a member and an outsider', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw(
          'a',
          <TopicRef>[
            state('cyc.s'),
            state('cyc.s2'),
            event('cyc.own'),
            event('cyc.ext'),
          ],
          <TopicRef>[event('cyc.x'), replay('cyc.r'), event('cyc.own')],
        ),
        rw(
          'b',
          <TopicRef>[event('cyc.x'), replay('cyc.r')],
          <TopicRef>[state('cyc.s')],
        ),
        rw('c', <TopicRef>[event('cyc.x')], <TopicRef>[state('cyc.s2')]),
        rw('d', <TopicRef>[event('cyc.x')], <TopicRef>[event('cyc.out')]),
        rw('e', <TopicRef>[event('cyc.in')], <TopicRef>[event('cyc.ext')]),
      ],
    );
    expect(findTopologyCycles(g), <TopologyCycle>[
      TopologyCycle(
        topologyIds: <String>['a', 'b', 'c'],
        topics: <TopicRef>[
          replay('cyc.r'),
          state('cyc.s'),
          state('cyc.s2'),
          event('cyc.x'),
        ],
      ),
    ]);
  });

  test('G13 a cycle is reported whatever stages its members pass values '
      'through: reduceInto, scan and positive time stages included', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        topology(
          'fold',
          Scope.module,
          (TopologyBuilder b) => b.reduceInto(total, b.read(clicks), add),
        ).buildDefinition(),
        topology(
          'echo-back',
          Scope.module,
          (TopologyBuilder b) => b.write(
            clicks,
            b
                .read(total)
                .scan(0, add)
                .debounce(const Duration(milliseconds: 300))
                .delay(const Duration(seconds: 1)),
          ),
        ).buildDefinition(),
      ],
    );
    expect(findTopologyCycles(g), <TopologyCycle>[
      TopologyCycle(
        topologyIds: <String>['echo-back', 'fold'],
        topics: <TopicRef>[clicks.ref, total.ref],
      ),
    ]);
  });

  test('G13 a ring of 20000 topologies, deeper than a recursive search can '
      'go, is one cycle of every id and every topic', () {
    const int n = 20000;
    String id(int i) => 'r${i.toString().padLeft(5, '0')}';
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        for (int i = 0; i < n; i++)
          rw(
            id(i),
            <TopicRef>[event('ring.${id(i)}')],
            <TopicRef>[event('ring.${id((i + 1) % n)}')],
          ),
      ],
    );
    final List<TopologyCycle> cycles = findTopologyCycles(g);
    expect(cycles, hasLength(1));
    expect(cycles.single.topologyIds, <String>[
      for (int i = 0; i < n; i++) id(i),
    ]);
    expect(cycles.single.topics, <TopicRef>[
      for (int i = 0; i < n; i++) event('ring.${id(i)}'),
    ]);
  });

  test('G3 findTopologyCycles returns an unmodifiable list, empty or not', () {
    final List<TopologyCycle> none = findTopologyCycles(TopologyGraph());
    final List<TopologyCycle> one = findTopologyCycles(
      TopologyGraph(
        topologies: <TopologyDefinition>[
          rw('p', <TopicRef>[event('p.in')], <TopicRef>[event('q.in')]),
          rw('q', <TopicRef>[event('q.in')], <TopicRef>[event('p.in')]),
        ],
      ),
    );
    expect(none, isEmpty);
    expect(one, hasLength(1));
    expect(() => none.add(one.first), throwsUnsupportedError);
    expect(() => one.clear(), throwsUnsupportedError);
  });

  test('G13 the cycles of generated graphs are the strongly connected sets a '
      'brute-force reachability check finds, with or without their claims', () {
    int withCycle = 0;
    int withThree = 0;
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      final List<TopologyCycle> expected = reachabilityCycles(g);
      expect(findTopologyCycles(g), expected, reason: 'seed $seed');
      expect(
        findTopologyCycles(TopologyGraph(topologies: g.topologies)),
        expected,
        reason: 'seed $seed without claims',
      );
      withCycle += expected.isEmpty ? 0 : 1;
      withThree += expected.any((TopologyCycle c) => c.topologyIds.length > 2)
          ? 1
          : 0;
    }
    // The seeds reach graphs with a cycle, and cycles of three or more.
    expect(withCycle, greaterThan(110));
    expect(withThree, greaterThan(75));
  });

  test('G13 cycles are ordered by their first ids, not by their last ids nor '
      'by the order a search completes them, and a topic from one cycle to '
      'another belongs to neither', () {
    // The search from a follows a.out to b first and completes {b, c}
    // before {a, z}; by last id c comes before z too.
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw(
          'a',
          <TopicRef>[event('a.in')],
          <TopicRef>[event('z.in'), event('a.out')],
        ),
        rw(
          'b',
          <TopicRef>[event('b.in'), event('a.out')],
          <TopicRef>[event('c.in')],
        ),
        rw('c', <TopicRef>[event('c.in')], <TopicRef>[event('b.in')]),
        rw('z', <TopicRef>[event('z.in')], <TopicRef>[event('a.in')]),
      ],
    );
    expect(findTopologyCycles(g), <TopologyCycle>[
      TopologyCycle(
        topologyIds: <String>['a', 'z'],
        topics: <TopicRef>[event('a.in'), event('z.in')],
      ),
      TopologyCycle(
        topologyIds: <String>['b', 'c'],
        topics: <TopicRef>[event('b.in'), event('c.in')],
      ),
    ]);
  });

  test('G13 a topic two members of a cycle write and a third reads is listed '
      'once', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('p', <TopicRef>[event('p.in')], <TopicRef>[event('x')]),
        rw('q', <TopicRef>[event('q.in')], <TopicRef>[event('x')]),
        rw(
          'r',
          <TopicRef>[event('x')],
          <TopicRef>[event('p.in'), event('q.in')],
        ),
      ],
    );
    expect(findTopologyCycles(g), <TopologyCycle>[
      TopologyCycle(
        topologyIds: <String>['p', 'q', 'r'],
        topics: <TopicRef>[event('p.in'), event('q.in'), event('x')],
      ),
    ]);
  });
}
