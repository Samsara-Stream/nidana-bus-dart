// topology-ir@v1's TopologyGraph, beyond the G11 cases of its conformance
// suite, which the gate replays: the canonical orders on inputs the suite
// does not build, unequal definitions with one id in any order, topics read
// in several places, unmodifiable copies (G3) and value equality that
// ignores the order of the arguments (G7), whose graph and claim cases
// first replay at nidana.model.12, toGraph() and render.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

TopicRef ref(
  String name, [
  TopicVariant variant = TopicVariant.event,
  String type = 'int',
]) => TopicRef(name: name, variant: variant, typeName: type);

TopicRef state(String name, [String type = 'int']) =>
    ref(name, TopicVariant.state, type);

/// A topology that merges [reads] and writes the merge to each of [writes].
TopologyDefinition rw(
  String id,
  List<TopicRef> reads,
  List<TopicRef> writes, [
  Scope scope = Scope.page,
]) => TopologyDefinition(
  topologyId: id,
  scope: scope,
  transforms: <TransformEdge>[
    TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
      for (final TopicRef r in reads) TopicInput(r),
    ]),
    for (final TopicRef w in writes)
      TransformEdge.write(w, const StageInput(0)),
  ],
);

ShellClaim claim(
  MessageSource source,
  List<TopicRef> writes, [
  Scope scope = Scope.application,
]) => ShellClaim(source: source, scope: scope, writes: writes.toSet());

/// Throws an ArgumentError whose name is [argument].
Matcher rejects(String argument) => throwsA(
  isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', argument),
);

/// An iterable that counts how often it is iterated.
final class Counted<T> extends Iterable<T> {
  Counted(this._elements);

  final List<T> _elements;
  int iterations = 0;

  @override
  Iterator<T> get iterator {
    iterations++;
    return _elements.iterator;
  }
}

/// A renderer that keeps every graph it is given.
final class Keeping implements GraphRenderer {
  final List<TopologyGraph> seen = <TopologyGraph>[];

  @override
  String render(TopologyGraph graph) {
    seen.add(graph);
    return 'rendered ${graph.topologies.length}';
  }
}

void main() {
  final TopologyDefinition a = rw(
    'a',
    <TopicRef>[ref('t.a')],
    <TopicRef>[ref('t.b')],
  );
  final TopologyDefinition b = rw(
    'b',
    <TopicRef>[ref('t.b')],
    <TopicRef>[state('t.c')],
  );
  final TopologyDefinition c = rw(
    'c',
    <TopicRef>[state('t.c')],
    <TopicRef>[ref('t.d')],
  );

  test('G11 a graph lists its topologies by id, each equal definition '
      'counted once however often and in whatever order it comes', () {
    final TopologyDefinition aAgain = rw(
      'a',
      <TopicRef>[ref('t.a')],
      <TopicRef>[ref('t.b')],
    );
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[c, a, b, aAgain, c, a],
    );
    expect(g.topologies, <TopologyDefinition>[a, b, c]);
    expect(
      TopologyGraph(topologies: <TopologyDefinition>[a, a]).topologies,
      <TopologyDefinition>[a],
    );
  });

  test('G11 two unequal definitions with one id throw ArgumentError naming '
      'the topologies, in either order and beside an equal copy', () {
    final TopologyDefinition other = rw(
      'a',
      <TopicRef>[ref('t.a')],
      <TopicRef>[ref('t.b')],
      Scope.module,
    );
    for (final List<TopologyDefinition> given in <List<TopologyDefinition>>[
      <TopologyDefinition>[a, other],
      <TopologyDefinition>[other, a],
      <TopologyDefinition>[a, a, other],
      <TopologyDefinition>[b, other, c, a],
    ]) {
      expect(() => TopologyGraph(topologies: given), rejects('topologies'));
    }
  });

  test('G11 claims sort by source rendering, then scope, then writes element '
      'by element, a prefix first, with equal claims kept', () {
    final TopologyGraph g = TopologyGraph(
      claims: <ShellClaim>[
        claim(const ServiceSource('s'), <TopicRef>[state('t.b')]),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a'), state('t.b')]),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a')], Scope.page),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a')]),
        claim(const PageSource('s'), <TopicRef>[state('t.z')]),
        claim(const ExecutorSource('s'), <TopicRef>[state('t.z')]),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a')], Scope.module),
        claim(const ServiceSource('s'), <TopicRef>[state('t.a')]),
      ],
    );
    expect(g.claims, <ShellClaim>[
      claim(const ExecutorSource('s'), <TopicRef>[state('t.z')]),
      claim(const PageSource('s'), <TopicRef>[state('t.z')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a'), state('t.b')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.b')]),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a')], Scope.module),
      claim(const ServiceSource('s'), <TopicRef>[state('t.a')], Scope.page),
    ]);
  });

  test('G11 topics are every topic read, written or claimed, each once, in '
      'canonical order', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw(
          'x',
          <TopicRef>[ref('n.a'), state('n.a')],
          <TopicRef>[ref('n.a', TopicVariant.replay)],
        ),
        rw(
          'y',
          <TopicRef>[ref('n.a', TopicVariant.replay)],
          <TopicRef>[state('n.a', 'String')],
        ),
      ],
      claims: <ShellClaim>[
        claim(const ServiceSource('s'), <TopicRef>[state('n.a'), state('m.z')]),
      ],
    );
    expect(g.topics, <TopicRef>[
      state('m.z'),
      state('n.a', 'String'),
      state('n.a'),
      ref('n.a'),
      ref('n.a', TopicVariant.replay),
    ]);
  });

  test('G3 a graph keeps unmodifiable copies of its lists; later changes to '
      'its arguments do not reach it', () {
    final List<TopologyDefinition> topologies = <TopologyDefinition>[b, a];
    final List<ShellClaim> claims = <ShellClaim>[
      claim(const ServiceSource('s'), <TopicRef>[state('t.s')]),
    ];
    final TopologyGraph g = TopologyGraph(
      topologies: topologies,
      claims: claims,
    );
    topologies
      ..clear()
      ..add(c);
    claims.clear();
    expect(g.topologies, <TopologyDefinition>[a, b]);
    expect(g.claims, hasLength(1));
    expect(g.topics, hasLength(4));
    expect(() => g.topologies.add(c), throwsUnsupportedError);
    expect(() => g.claims.clear(), throwsUnsupportedError);
    expect(() => g.topics.removeLast(), throwsUnsupportedError);
    expect(() => TopologyGraph().topologies.add(a), throwsUnsupportedError);
  });

  test('G7 a graph built from lazy iterables equals one built from lists, '
      'and reads each argument once', () {
    final List<ShellClaim> claims = <ShellClaim>[
      claim(const ServiceSource('s'), <TopicRef>[state('t.s')]),
      claim(const PageSource('p'), <TopicRef>[state('t.p')]),
    ];
    final Counted<TopologyDefinition> topologies = Counted<TopologyDefinition>(
      <TopologyDefinition>[c, b, a],
    );
    final Counted<ShellClaim> counted = Counted<ShellClaim>(claims);
    final TopologyGraph g = TopologyGraph(
      topologies: topologies,
      claims: counted,
    );
    expect(topologies.iterations, 1);
    expect(counted.iterations, 1);
    final TopologyGraph lists = TopologyGraph(
      topologies: <TopologyDefinition>[a, b, c],
      claims: claims,
    );
    expect(g, lists);
    expect(
      TopologyGraph(
        topologies: <TopologyDefinition>[a, b, c].reversed,
        claims: claims.where((ShellClaim each) => true),
      ),
      lists,
    );
  });

  test('G7 graphs are equal, with equal hash codes, exactly when their '
      'topologies and claims are, whatever order the arguments came in', () {
    final ShellClaim s = claim(const ServiceSource('s'), <TopicRef>[
      state('t.s'),
    ]);
    final ShellClaim p = claim(const PageSource('p'), <TopicRef>[state('t.p')]);
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[a, b],
      claims: <ShellClaim>[s, p],
    );
    final TopologyGraph same = TopologyGraph(
      topologies: <TopologyDefinition>[b, a, b],
      claims: <ShellClaim>[p, s],
    );
    expect(g, same);
    expect(g.hashCode, same.hashCode);
    expect(<TopologyGraph>{g, same}, hasLength(1));
    expect(
      g,
      isNot(
        TopologyGraph(
          topologies: <TopologyDefinition>[a, b],
          claims: <ShellClaim>[s, p, s],
        ),
      ),
    );
    expect(
      g,
      isNot(
        TopologyGraph(
          topologies: <TopologyDefinition>[a, b, c],
          claims: <ShellClaim>[s, p],
        ),
      ),
    );
    expect(
      g,
      isNot(
        TopologyGraph(
          topologies: <TopologyDefinition>[a, b],
          claims: <ShellClaim>[s],
        ),
      ),
    );
    expect(TopologyGraph(), TopologyGraph(topologies: <TopologyDefinition>[]));
    expect(
      TopologyGraph().hashCode,
      TopologyGraph(claims: <ShellClaim>[]).hashCode,
    );
    expect(TopologyGraph(), isNot(g));
  });

  test('G11 toGraph is the graph of the one definition; render passes the '
      'graph itself to the renderer and returns its text', () {
    final TopologyGraph g = a.toGraph();
    expect(g, TopologyGraph(topologies: <TopologyDefinition>[a]));
    expect(g.topologies.single, a);
    expect(g.claims, isEmpty);
    expect(g.topics, <TopicRef>[ref('t.a'), ref('t.b')]);
    final Keeping renderer = Keeping();
    expect(g.render(renderer), 'rendered 1');
    expect(identical(renderer.seen.single, g), isTrue);
  });
}
