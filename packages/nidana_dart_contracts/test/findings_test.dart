// The value semantics of topology-ir@v1's findings, declarations and
// collisions: constructors that put their lists in the orders the Interface
// names (G23), unmodifiable copies (G3) and value equality (G7). G23's
// conformance case also runs the analyses, so it joins the gate at
// nidana.model.12, and these tests check it until then.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

TopicRef ref(String name, [TopicVariant variant = TopicVariant.event]) =>
    TopicRef(name: name, variant: variant, typeName: 'int');

TopicRef state(String name) => ref(name, TopicVariant.state);

void main() {
  test('G23 a cycle sorts its ids and its topics in canonical order, '
      'repeated elements kept', () {
    final TopologyCycle c = TopologyCycle(
      topologyIds: <String>['b', 'a', 'B', 'a'],
      topics: <TopicRef>[ref('y'), ref('x', TopicVariant.replay), state('x')],
    );
    expect(c.topologyIds, <String>['B', 'a', 'a', 'b']);
    expect(c.topics, <TopicRef>[
      state('x'),
      ref('x', TopicVariant.replay),
      ref('y'),
    ]);
  });

  test('G23 a self-reference sorts its edges ascending, repeated indices '
      'kept', () {
    expect(
      SelfReference(
        topologyId: 't',
        topic: state('s'),
        edges: <int>[10, 2, 2, 0],
      ).edges,
      <int>[0, 2, 2, 10],
    );
  });

  test('G23 a writer conflict sorts its writers by rendering, equal sources '
      'repeated', () {
    expect(
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[
          TopologySource('t'),
          ServiceSource('s'),
          PageSource('/p'),
          ServiceSource('s'),
          ExecutorSource('e'),
        ],
      ).writers,
      const <MessageSource>[
        ExecutorSource('e'),
        PageSource('/p'),
        ServiceSource('s'),
        ServiceSource('s'),
        TopologySource('t'),
      ],
    );
  });

  test('G23 a collision sorts its declarations by site, then topic in '
      'canonical order, repeated declarations kept', () {
    const TopicDeclaration bState = TopicDeclaration(
      topic: TopicRef(name: 'n', variant: TopicVariant.state, typeName: 'int'),
      site: 'lib/b.dart:1',
    );
    const TopicDeclaration aEvent = TopicDeclaration(
      topic: TopicRef(name: 'n', variant: TopicVariant.event, typeName: 'int'),
      site: 'lib/a.dart:1',
    );
    const TopicDeclaration aState = TopicDeclaration(
      topic: TopicRef(name: 'n', variant: TopicVariant.state, typeName: 'int'),
      site: 'lib/a.dart:1',
    );
    expect(
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[bState, aEvent, aState, bState],
      ).declarations,
      <TopicDeclaration>[aState, aEvent, bState, bState],
    );
  });

  test('G23 findings and collisions built in any order are equal, with '
      'equal hash codes', () {
    final List<(Object, Object)> pairs = <(Object, Object)>[
      (
        TopologyCycle(
          topologyIds: <String>['a', 'b'],
          topics: <TopicRef>[ref('x'), ref('y')],
        ),
        TopologyCycle(
          topologyIds: <String>['b', 'a'],
          topics: <TopicRef>[ref('y'), ref('x')],
        ),
      ),
      (
        SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0, 1]),
        SelfReference(topologyId: 't', topic: state('s'), edges: <int>[1, 0]),
      ),
      (
        WriterConflict(
          topic: state('w'),
          writers: const <MessageSource>[ServiceSource('a'), PageSource('b')],
        ),
        WriterConflict(
          topic: state('w'),
          writers: const <MessageSource>[PageSource('b'), ServiceSource('a')],
        ),
      ),
      (
        TopicNameCollision(
          name: 'n',
          declarations: <TopicDeclaration>[
            TopicDeclaration(topic: ref('n'), site: 'a'),
            TopicDeclaration(topic: state('n'), site: 'b'),
          ],
        ),
        TopicNameCollision(
          name: 'n',
          declarations: <TopicDeclaration>[
            TopicDeclaration(topic: state('n'), site: 'b'),
            TopicDeclaration(topic: ref('n'), site: 'a'),
          ],
        ),
      ),
    ];
    for (final (Object sorted, Object shuffled) in pairs) {
      expect(shuffled, sorted);
      expect(shuffled.hashCode, sorted.hashCode);
    }
  });

  test('G7 findings, declarations and collisions are unequal when any field '
      'the Interface names differs', () {
    ScopeViolation violation({
      TopicRef? topic,
      MessageSource owner = const TopologySource('o'),
      Scope ownerScope = Scope.page,
      String readerId = 'r',
      Scope readerScope = Scope.module,
    }) => ScopeViolation(
      topic: topic ?? state('t'),
      owner: owner,
      ownerScope: ownerScope,
      readerId: readerId,
      readerScope: readerScope,
    );
    expect(violation(), violation());
    expect(violation().hashCode, violation().hashCode);
    expect(violation(topic: state('u')), isNot(violation()));
    expect(violation(owner: const ServiceSource('o')), isNot(violation()));
    expect(violation(ownerScope: Scope.module), isNot(violation()));
    expect(violation(readerId: 's'), isNot(violation()));
    expect(violation(readerScope: Scope.application), isNot(violation()));
    expect(
      TopologyCycle(topologyIds: <String>['a', 'b'], topics: <TopicRef>[]),
      isNot(
        TopologyCycle(topologyIds: <String>['a', 'c'], topics: <TopicRef>[]),
      ),
    );
    expect(
      TopologyCycle(topologyIds: <String>['a'], topics: <TopicRef>[ref('x')]),
      isNot(
        TopologyCycle(topologyIds: <String>['a'], topics: <TopicRef>[ref('y')]),
      ),
    );
    expect(
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0]),
      isNot(SelfReference(topologyId: 'u', topic: state('s'), edges: <int>[0])),
    );
    expect(
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0]),
      isNot(SelfReference(topologyId: 't', topic: state('r'), edges: <int>[0])),
    );
    expect(
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0]),
      isNot(
        SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0, 0]),
      ),
    );
    expect(
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[ServiceSource('a')],
      ),
      isNot(
        WriterConflict(
          topic: state('v'),
          writers: const <MessageSource>[ServiceSource('a')],
        ),
      ),
    );
    expect(
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[ServiceSource('a')],
      ),
      isNot(
        WriterConflict(
          topic: state('w'),
          writers: const <MessageSource>[
            ServiceSource('a'),
            ServiceSource('a'),
          ],
        ),
      ),
    );
    expect(
      TopicDeclaration(topic: ref('a'), site: 'x'),
      TopicDeclaration(topic: ref('a'), site: 'x'),
    );
    expect(
      TopicDeclaration(topic: ref('a'), site: 'x').hashCode,
      TopicDeclaration(topic: ref('a'), site: 'x').hashCode,
    );
    expect(
      TopicDeclaration(topic: ref('a'), site: 'x'),
      isNot(TopicDeclaration(topic: state('a'), site: 'x')),
    );
    expect(
      TopicNameCollision(name: 'n', declarations: <TopicDeclaration>[]),
      isNot(TopicNameCollision(name: 'm', declarations: <TopicDeclaration>[])),
    );
    expect(
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[
          TopicDeclaration(topic: ref('n'), site: 'a'),
        ],
      ),
      isNot(TopicNameCollision(name: 'n', declarations: <TopicDeclaration>[])),
    );
  });

  test('G3 findings and collisions keep unmodifiable copies of their '
      'lists', () {
    final List<String> ids = <String>['a', 'b'];
    final List<TopicRef> topics = <TopicRef>[ref('x')];
    final List<int> edges = <int>[0];
    final List<MessageSource> writers = <MessageSource>[
      const ServiceSource('s'),
    ];
    final List<TopicDeclaration> declarations = <TopicDeclaration>[
      TopicDeclaration(topic: ref('n'), site: 'a'),
    ];
    final TopologyCycle cycle = TopologyCycle(topologyIds: ids, topics: topics);
    final SelfReference self = SelfReference(
      topologyId: 't',
      topic: state('s'),
      edges: edges,
    );
    final WriterConflict conflict = WriterConflict(
      topic: state('w'),
      writers: writers,
    );
    final TopicNameCollision collision = TopicNameCollision(
      name: 'n',
      declarations: declarations,
    );
    ids.add('c');
    topics.clear();
    edges.add(1);
    writers.clear();
    declarations.clear();
    expect(cycle.topologyIds, <String>['a', 'b']);
    expect(cycle.topics, <TopicRef>[ref('x')]);
    expect(self.edges, <int>[0]);
    expect(conflict.writers, const <MessageSource>[ServiceSource('s')]);
    expect(collision.declarations, hasLength(1));
    expect(() => cycle.topologyIds.add('z'), throwsUnsupportedError);
    expect(() => cycle.topics.clear(), throwsUnsupportedError);
    expect(() => self.edges.add(2), throwsUnsupportedError);
    expect(() => conflict.writers.clear(), throwsUnsupportedError);
    expect(() => collision.declarations.clear(), throwsUnsupportedError);
  });

  test('G7 findings of two variants are never equal', () {
    final List<TopologyFinding> findings = <TopologyFinding>[
      TopologyCycle(topologyIds: <String>['t'], topics: <TopicRef>[state('s')]),
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[]),
      WriterConflict(topic: state('s'), writers: const <MessageSource>[]),
      ScopeViolation(
        topic: state('s'),
        owner: const TopologySource('t'),
        ownerScope: Scope.page,
        readerId: 't',
        readerScope: Scope.page,
      ),
    ];
    for (int i = 0; i < findings.length; i++) {
      for (int j = 0; j < findings.length; j++) {
        expect(findings[i] == findings[j], i == j, reason: '$i against $j');
      }
    }
  });

  test('G7 lists of one length that differ in an element are unequal', () {
    expect(
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0]),
      isNot(SelfReference(topologyId: 't', topic: state('s'), edges: <int>[1])),
    );
    expect(
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[ServiceSource('a')],
      ),
      isNot(
        WriterConflict(
          topic: state('w'),
          writers: const <MessageSource>[ServiceSource('b')],
        ),
      ),
    );
    expect(
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[ServiceSource('a')],
      ),
      isNot(
        WriterConflict(
          topic: state('w'),
          writers: const <MessageSource>[PageSource('a')],
        ),
      ),
    );
    expect(
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[
          TopicDeclaration(topic: ref('n'), site: 'a'),
        ],
      ),
      isNot(
        TopicNameCollision(
          name: 'n',
          declarations: <TopicDeclaration>[
            TopicDeclaration(topic: ref('n'), site: 'b'),
          ],
        ),
      ),
    );
    expect(
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[
          TopicDeclaration(topic: ref('n'), site: 'a'),
        ],
      ),
      isNot(
        TopicNameCollision(
          name: 'n',
          declarations: <TopicDeclaration>[
            TopicDeclaration(topic: state('n'), site: 'a'),
          ],
        ),
      ),
    );
  });

  test('G7 declarations with another site are unequal', () {
    expect(
      TopicDeclaration(topic: ref('a'), site: 'x'),
      isNot(TopicDeclaration(topic: ref('a'), site: 'y')),
    );
  });

  test('G23 declarations order by site as code units, so a site is not '
      'compared as a number or without its case', () {
    final TopicDeclaration upper = TopicDeclaration(
      topic: ref('n'),
      site: 'lib/B.dart:2',
    );
    final TopicDeclaration lower = TopicDeclaration(
      topic: ref('n'),
      site: 'lib/a.dart:10',
    );
    final TopicDeclaration shorter = TopicDeclaration(
      topic: ref('n'),
      site: 'lib/a.dart:2',
    );
    expect(
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[shorter, lower, upper],
      ).declarations,
      <TopicDeclaration>[upper, lower, shorter],
    );
  });

  test('G23 a constructor sorts its own copy and leaves the list it was '
      'given in the order it came', () {
    final List<String> ids = <String>['b', 'a'];
    final List<TopicRef> topics = <TopicRef>[ref('y'), ref('x')];
    final List<int> edges = <int>[2, 1];
    final List<MessageSource> writers = <MessageSource>[
      const ServiceSource('b'),
      const ServiceSource('a'),
    ];
    final List<TopicDeclaration> declarations = <TopicDeclaration>[
      TopicDeclaration(topic: ref('n'), site: 'b'),
      TopicDeclaration(topic: ref('n'), site: 'a'),
    ];
    TopologyCycle(topologyIds: ids, topics: topics);
    SelfReference(topologyId: 't', topic: state('s'), edges: edges);
    WriterConflict(topic: state('w'), writers: writers);
    TopicNameCollision(name: 'n', declarations: declarations);
    expect(ids, <String>['b', 'a']);
    expect(topics, <TopicRef>[ref('y'), ref('x')]);
    expect(edges, <int>[2, 1]);
    expect(writers, const <MessageSource>[
      ServiceSource('b'),
      ServiceSource('a'),
    ]);
    expect(declarations.map((TopicDeclaration d) => d.site), <String>[
      'b',
      'a',
    ]);
  });

  test('G7 equal findings built apart are one element of a Set, and unequal '
      'ones are two', () {
    final Set<TopologyFinding> findings = <TopologyFinding>{
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[ServiceSource('a'), PageSource('b')],
      ),
      WriterConflict(
        topic: state('w'),
        writers: const <MessageSource>[PageSource('b'), ServiceSource('a')],
      ),
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0, 1]),
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[1, 0]),
      SelfReference(topologyId: 't', topic: state('s'), edges: <int>[0]),
    };
    expect(findings, hasLength(3));
    final Set<TopicNameCollision> collisions = <TopicNameCollision>{
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[
          TopicDeclaration(topic: ref('n'), site: 'a'),
          TopicDeclaration(topic: ref('n'), site: 'b'),
        ],
      ),
      TopicNameCollision(
        name: 'n',
        declarations: <TopicDeclaration>[
          TopicDeclaration(topic: ref('n'), site: 'b'),
          TopicDeclaration(topic: ref('n'), site: 'a'),
        ],
      ),
    };
    expect(collisions, hasLength(1));
  });
}
