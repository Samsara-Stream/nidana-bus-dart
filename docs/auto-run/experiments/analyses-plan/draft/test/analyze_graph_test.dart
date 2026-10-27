// topology-ir@v1's analyzeTopologyGraph (G17) and findTopicNameCollisions
// (G18), beyond the G17, G18 and G23 cases of its conformance suite, which
// the gate replays: self-references by topology in graph order, collisions
// in name order with repeats counted once and the argument read once,
// unmodifiable results (G3), and over generated graphs the removal property
// of G17, the composition of the four analyses, findings that do not depend
// on the order of their arguments (G7), and findings whose lists hold
// distinct elements and keep their order when rebuilt (G23).
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/analysis_support.dart';

/// A clean graph grown from [parts]: each topology, then each claim, in
/// generation order, kept when the graph with it still has no finding.
TopologyGraph cleanGraph(GraphParts parts) {
  List<TopologyDefinition> topologies = <TopologyDefinition>[];
  List<ShellClaim> claims = <ShellClaim>[];
  bool clean(List<TopologyDefinition> ts, List<ShellClaim> cs) =>
      analyzeTopologyGraph(TopologyGraph(topologies: ts, claims: cs)).isEmpty;
  for (final TopologyDefinition t in parts.topologies) {
    final List<TopologyDefinition> more = <TopologyDefinition>[
      ...topologies,
      t,
    ];
    if (clean(more, claims)) {
      topologies = more;
    }
  }
  for (final ShellClaim c in parts.claims) {
    final List<ShellClaim> more = <ShellClaim>[...claims, c];
    if (clean(topologies, more)) {
      claims = more;
    }
  }
  return TopologyGraph(topologies: topologies, claims: claims);
}

/// [items] in an order drawn from [random].
List<T> shuffled<T>(List<T> items, Random random) =>
    List<T>.of(items)..shuffle(random);

/// The sites and topics generated declarations draw from: two names, each
/// in two variants, at three sites.
final List<TopicDeclaration> declarationPool = <TopicDeclaration>[
  for (final String site in <String>[
    'lib/a.dart:1',
    'lib/b.dart:2',
    'lib/c.dart:3',
  ])
    for (final TopicRef topic in <TopicRef>[
      state('gen.x'),
      event('gen.x'),
      state('gen.y'),
      event('gen.y'),
    ])
      TopicDeclaration(topic: topic, site: site),
];

void main() {
  test('G17 self-references come by topology in graph order, then by topic '
      'in canonical order', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw(
          'zeta',
          <TopicRef>[state('z.s')],
          <TopicRef>[state('z.s')],
          scope: Scope.application,
        ),
        rw(
          'alpha',
          <TopicRef>[state('a.s'), event('a.e')],
          <TopicRef>[state('a.s'), event('a.e')],
          scope: Scope.application,
        ),
      ],
    );
    expect(analyzeTopologyGraph(g), <TopologyFinding>[
      SelfReference(
        topologyId: 'alpha',
        topic: event('a.e'),
        edges: <int>[0, 2],
      ),
      SelfReference(
        topologyId: 'alpha',
        topic: state('a.s'),
        edges: <int>[0, 1],
      ),
      SelfReference(
        topologyId: 'zeta',
        topic: state('z.s'),
        edges: <int>[0, 1],
      ),
    ]);
  });

  test(
    'G3 analyzeTopologyGraph returns an unmodifiable list, empty or not',
    () {
      final List<TopologyFinding> none = analyzeTopologyGraph(TopologyGraph());
      final List<TopologyFinding> one = analyzeTopologyGraph(
        rw(
          'one',
          <TopicRef>[event('one.e')],
          <TopicRef>[event('one.e')],
        ).toGraph(),
      );
      expect(none, isEmpty);
      expect(one, hasLength(1));
      expect(() => none.add(one.first), throwsUnsupportedError);
      expect(() => one.clear(), throwsUnsupportedError);
    },
  );

  test('G18 collisions come in name order as String.compareTo orders names, '
      'and a repeated declaration counts once', () {
    final TopicDeclaration lowerState = TopicDeclaration(
      topic: state('a.b'),
      site: 'lib/x.dart:1',
    );
    final TopicDeclaration lowerEvent = TopicDeclaration(
      topic: event('a.b'),
      site: 'lib/x.dart:2',
    );
    final TopicDeclaration upperInt = TopicDeclaration(
      topic: state('Z.b'),
      site: 'lib/y.dart:1',
    );
    final TopicDeclaration upperOther = TopicDeclaration(
      topic: state('Z.b', 'Other'),
      site: 'lib/y.dart:1',
    );
    final TopicDeclaration lone = TopicDeclaration(
      topic: state('m.n'),
      site: 'lib/z.dart:1',
    );
    final List<TopicNameCollision> found = findTopicNameCollisions(
      <TopicDeclaration>[
        lowerEvent,
        lone,
        upperInt,
        lone,
        lowerState,
        upperOther,
        lowerEvent,
      ],
    );
    expect(found, <TopicNameCollision>[
      TopicNameCollision(
        name: 'Z.b',
        declarations: <TopicDeclaration>[upperOther, upperInt],
      ),
      TopicNameCollision(
        name: 'a.b',
        declarations: <TopicDeclaration>[lowerState, lowerEvent],
      ),
    ]);
    expect(found.first.declarations, <TopicDeclaration>[upperOther, upperInt]);
  });

  test('G18 findTopicNameCollisions reads its argument once, and later '
      'changes to the argument do not reach its result', () {
    final List<TopicDeclaration> given = <TopicDeclaration>[
      TopicDeclaration(topic: state('once.t'), site: 'lib/a.dart:1'),
      TopicDeclaration(topic: event('once.t'), site: 'lib/b.dart:1'),
    ];
    int reads = 0;
    final Iterable<TopicDeclaration> lazy = Iterable<int>.generate(1)
        .expand((int _) {
          reads++;
          return given;
        });
    final List<TopicNameCollision> found = findTopicNameCollisions(lazy);
    given.add(TopicDeclaration(topic: state('once.t'), site: 'lib/c.dart:1'));
    expect(reads, 1);
    expect(found.single.declarations, hasLength(2));
  });

  test(
    'G3 findTopicNameCollisions returns an unmodifiable list, empty or not',
    () {
      final List<TopicNameCollision> none = findTopicNameCollisions(
        const <TopicDeclaration>[],
      );
      final List<TopicNameCollision> one = findTopicNameCollisions(
        <TopicDeclaration>[
          TopicDeclaration(topic: state('u.t'), site: 'lib/a.dart:1'),
          TopicDeclaration(topic: state('u.t'), site: 'lib/b.dart:1'),
        ],
      );
      expect(none, isEmpty);
      expect(one, hasLength(1));
      expect(() => none.add(one.first), throwsUnsupportedError);
      expect(() => one.clear(), throwsUnsupportedError);
    },
  );

  test('G17 a clean graph grown from generated parts has no finding after '
      'any one of its topologies or claims is removed', () {
    int sizable = 0;
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = cleanGraph(generatedParts(seed));
      expect(analyzeTopologyGraph(g), isEmpty, reason: 'seed $seed');
      for (int i = 0; i < g.topologies.length; i++) {
        final TopologyGraph less = TopologyGraph(
          topologies: <TopologyDefinition>[...g.topologies]..removeAt(i),
          claims: g.claims,
        );
        expect(analyzeTopologyGraph(less), isEmpty, reason: 'seed $seed, -$i');
      }
      for (int i = 0; i < g.claims.length; i++) {
        final TopologyGraph less = TopologyGraph(
          topologies: g.topologies,
          claims: <ShellClaim>[...g.claims]..removeAt(i),
        );
        expect(analyzeTopologyGraph(less), isEmpty, reason: 'seed $seed, -c$i');
      }
      sizable += g.topologies.length + g.claims.length >= 3 ? 1 : 0;
    }
    // The seeds reach clean graphs of three or more topologies and claims.
    expect(sizable, greaterThan(45));
  });

  test('G17 the findings of a generated graph are its cycles, then each '
      'topology\'s self-references in graph order, then its writer conflicts, '
      'then its scope violations, every kind reached', () {
    final List<int> kinds = <int>[0, 0, 0, 0];
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      final List<TopologyCycle> cycles = findTopologyCycles(g);
      final List<SelfReference> selfReferences = <SelfReference>[
        for (final TopologyDefinition d in g.topologies)
          ...findSelfReferences(d),
      ];
      final List<WriterConflict> conflicts = findWriterConflicts(g);
      final List<ScopeViolation> violations = findScopeViolations(g);
      expect(analyzeTopologyGraph(g), <TopologyFinding>[
        ...cycles,
        ...selfReferences,
        ...conflicts,
        ...violations,
      ], reason: 'seed $seed');
      kinds[0] += cycles.length;
      kinds[1] += selfReferences.length;
      kinds[2] += conflicts.length;
      kinds[3] += violations.length;
    }
    expect(kinds, everyElement(greaterThan(90)));
  });

  test('G7 the findings of a generated graph, and the collisions of generated '
      'declarations, do not depend on the order their arguments came in', () {
    for (int seed = 0; seed < seeds; seed++) {
      final GraphParts parts = generatedParts(seed);
      final Random random = Random(seed);
      final TopologyGraph given = graphOf(parts);
      final TopologyGraph reordered = TopologyGraph(
        topologies: shuffled(parts.topologies, random),
        claims: shuffled(parts.claims, random),
      );
      expect(
        analyzeTopologyGraph(reordered),
        analyzeTopologyGraph(given),
        reason: 'seed $seed',
      );
      final List<TopicDeclaration> declarations = <TopicDeclaration>[
        for (int i = 0, n = random.nextInt(8); i < n; i++)
          declarationPool[random.nextInt(declarationPool.length)],
      ];
      expect(
        findTopicNameCollisions(shuffled(declarations, random)),
        findTopicNameCollisions(declarations),
        reason: 'seed $seed',
      );
      expect(
        findTopicNameCollisions(<TopicDeclaration>[
          ...declarations,
          ...declarations,
        ]),
        findTopicNameCollisions(declarations),
        reason: 'seed $seed, repeated',
      );
    }
  });

  test(
    'G23 every finding of a generated graph holds distinct findings, '
    'distinct ids, topics and edges, and equals itself rebuilt in reverse',
    () {
      for (int seed = 0; seed < seeds; seed++) {
        final List<TopologyFinding> findings = analyzeTopologyGraph(
          generatedGraph(seed),
        );
        expect(
          findings.toSet(),
          hasLength(findings.length),
          reason: 'seed $seed',
        );
        for (final TopologyFinding finding in findings) {
          final TopologyFinding rebuilt = switch (finding) {
            TopologyCycle(
              :final List<String> topologyIds,
              :final List<TopicRef> topics,
            ) =>
              TopologyCycle(
                topologyIds: topologyIds.reversed.toList(),
                topics: topics.reversed.toList(),
              ),
            SelfReference(
              :final String topologyId,
              :final TopicRef topic,
              :final List<int> edges,
            ) =>
              SelfReference(
                topologyId: topologyId,
                topic: topic,
                edges: edges.reversed.toList(),
              ),
            WriterConflict(
              :final TopicRef topic,
              :final List<MessageSource> writers,
            ) =>
              WriterConflict(topic: topic, writers: writers.reversed.toList()),
            ScopeViolation() => finding,
          };
          expect(rebuilt, finding, reason: 'seed $seed');
          switch (finding) {
            case TopologyCycle(
              :final List<String> topologyIds,
              :final List<TopicRef> topics,
            ):
              expect(
                topologyIds.toSet(),
                hasLength(topologyIds.length),
                reason: 'seed $seed',
              );
              expect(
                topics.toSet(),
                hasLength(topics.length),
                reason: 'seed $seed',
              );
            case SelfReference(:final List<int> edges):
              expect(
                edges.toSet(),
                hasLength(edges.length),
                reason: 'seed $seed',
              );
            case WriterConflict() || ScopeViolation():
              break;
          }
        }
      }
    },
  );
}
