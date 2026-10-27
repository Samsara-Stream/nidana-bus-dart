// What the declarations of topology-ir@v1's topology_ir.dart fix before any
// body computes (nidana.model D3). Every expectation here holds as well once
// the phases that deliver value equality and the sorted finding lists land.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

const TopicRef cart = TopicRef(
  name: 'checkout.cart',
  variant: TopicVariant.state,
  typeName: 'Cart',
);
const TopicRef total = TopicRef(
  name: 'checkout.total',
  variant: TopicVariant.state,
  typeName: 'int',
);

/// The variant [f] is, by an exhaustive switch.
String variantOf(TopologyFinding f) => switch (f) {
  TopologyCycle() => 'cycle',
  SelfReference() => 'self-reference',
  WriterConflict() => 'writer conflict',
  ScopeViolation() => 'scope violation',
};

/// A renderer an application writes.
final class ClaimCount implements GraphRenderer {
  const ClaimCount();

  @override
  String render(TopologyGraph graph) => '${graph.claims.length}';
}

void main() {
  test('findings keep the lists they are given in the orders the '
      'Interface names, equal writers repeated', () {
    const ServiceSource history = ServiceSource('search-history');
    final TopologyCycle cycle = TopologyCycle(
      topologyIds: <String>['cart', 'pricing'],
      topics: <TopicRef>[cart, total],
    );
    final SelfReference self = SelfReference(
      topologyId: 'pricing',
      topic: total,
      edges: <int>[0, 2],
    );
    final WriterConflict conflict = WriterConflict(
      topic: cart,
      writers: <MessageSource>[history, history, const TopologySource('cart')],
    );
    expect(cycle.topologyIds, <String>['cart', 'pricing']);
    expect(cycle.topics, <TopicRef>[cart, total]);
    expect(self.topologyId, 'pricing');
    expect(self.topic, total);
    expect(self.edges, <int>[0, 2]);
    expect(conflict.topic, cart);
    expect(conflict.writers, <MessageSource>[
      history,
      history,
      const TopologySource('cart'),
    ]);
  });

  test('a ScopeViolation is const and keeps its five fields', () {
    const ScopeViolation violation = ScopeViolation(
      topic: cart,
      owner: TopologySource('cart'),
      ownerScope: Scope.page,
      readerId: 'summary',
      readerScope: Scope.application,
    );
    expect(violation.topic, cart);
    expect(violation.owner, const TopologySource('cart'));
    expect(violation.ownerScope, Scope.page);
    expect(violation.readerId, 'summary');
    expect(violation.readerScope, Scope.application);
  });

  test('a TopicDeclaration is const and keeps its topic and site; a '
      'TopicNameCollision keeps its name and its declarations by site', () {
    const TopicDeclaration first = TopicDeclaration(
      topic: cart,
      site: 'lib/a_topics.dart:3',
    );
    const TopicDeclaration second = TopicDeclaration(
      topic: TopicRef(
        name: 'checkout.cart',
        variant: TopicVariant.event,
        typeName: 'Cart',
      ),
      site: 'lib/b_topics.dart:9',
    );
    final TopicNameCollision collision = TopicNameCollision(
      name: 'checkout.cart',
      declarations: <TopicDeclaration>[first, second],
    );
    expect(first.topic, cart);
    expect(first.site, 'lib/a_topics.dart:3');
    expect(collision.name, 'checkout.cart');
    expect(collision.declarations, <TopicDeclaration>[first, second]);
  });

  test('a switch over TopologyFinding tells its four variants apart', () {
    final List<TopologyFinding> findings = <TopologyFinding>[
      TopologyCycle(topologyIds: <String>['a', 'b'], topics: <TopicRef>[cart]),
      SelfReference(topologyId: 'a', topic: cart, edges: <int>[0]),
      WriterConflict(
        topic: cart,
        writers: <MessageSource>[
          const PageSource('cart'),
          const ServiceSource('cart'),
        ],
      ),
      const ScopeViolation(
        topic: cart,
        owner: TopologySource('a'),
        ownerScope: Scope.page,
        readerId: 'b',
        readerScope: Scope.module,
      ),
    ];
    expect(findings.map(variantOf), <String>[
      'cycle',
      'self-reference',
      'writer conflict',
      'scope violation',
    ]);
  });

  test('the three renderers are const GraphRenderers, beside one an '
      'application writes', () {
    const List<GraphRenderer> renderers = <GraphRenderer>[
      MermaidRenderer(),
      GraphvizRenderer(),
      JsonRenderer(),
      ClaimCount(),
    ];
    expect(renderers.map((GraphRenderer r) => r.runtimeType), <Type>[
      MermaidRenderer,
      GraphvizRenderer,
      JsonRenderer,
      ClaimCount,
    ]);
  });
}
