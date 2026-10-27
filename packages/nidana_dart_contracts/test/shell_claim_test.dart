// topology-ir@v1's ShellClaim, beyond the G12 case of its conformance suite,
// which the gate replays: the argument each rejection names, the canonical
// order of a claim's writes, its unmodifiable copy (G3) and value equality
// (G7), whose graph and claim cases first replay at nidana.model.12.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

TopicRef state(String name, [String type = 'int']) =>
    TopicRef(name: name, variant: TopicVariant.state, typeName: type);

TopicRef event(String name) =>
    TopicRef(name: name, variant: TopicVariant.event, typeName: 'int');

/// Throws an ArgumentError whose name is [argument].
Matcher rejects(String argument) => throwsA(
  isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', argument),
);

void main() {
  test('G12 a claim takes a service, page or executor source at any scope, '
      'and rejects a topology or unknown source naming the source', () {
    final Set<TopicRef> writes = <TopicRef>{state('a.b')};
    for (final MessageSource source in <MessageSource>[
      const ServiceSource('s'),
      const PageSource('p'),
      const ExecutorSource('e'),
    ]) {
      for (final Scope scope in Scope.values) {
        final ShellClaim claim = ShellClaim(
          source: source,
          scope: scope,
          writes: writes,
        );
        expect(claim.source, source);
        expect(claim.scope, scope);
      }
      expect(
        ShellClaim(source: source, writes: writes).scope,
        Scope.application,
      );
    }
    expect(
      () => ShellClaim(source: const TopologySource('t'), writes: writes),
      rejects('source'),
    );
    expect(
      () => ShellClaim(source: const UnknownSource(), writes: writes),
      rejects('source'),
    );
  });

  test('G12 a claim rejects an empty set, and a set with any topic that is '
      'not a state topic, naming the writes', () {
    const ServiceSource s = ServiceSource('s');
    expect(
      () => ShellClaim(source: s, writes: <TopicRef>{}),
      rejects('writes'),
    );
    expect(
      () =>
          ShellClaim(source: s, writes: <TopicRef>{state('a.b'), event('a.c')}),
      rejects('writes'),
    );
    expect(
      () => ShellClaim(
        source: s,
        writes: <TopicRef>{
          const TopicRef(
            name: 'a.d',
            variant: TopicVariant.replay,
            typeName: 'int',
          ),
          state('a.b'),
        },
      ),
      rejects('writes'),
    );
  });

  test('G12 a claim checks its source before its writes, and names the '
      'source or the first topic that is not a state topic as the invalid '
      'value', () {
    const TopologySource topology = TopologySource('t');
    expect(
      () => ShellClaim(source: topology, writes: <TopicRef>{}),
      rejects('source'),
    );
    expect(
      () => ShellClaim(source: topology, writes: <TopicRef>{event('a.c')}),
      rejects('source'),
    );
    expect(
      () => ShellClaim(source: const UnknownSource(), writes: <TopicRef>{}),
      rejects('source'),
    );
    expect(
      () => ShellClaim(source: topology, writes: <TopicRef>{state('a.b')}),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.invalidValue,
          'invalidValue',
          topology,
        ),
      ),
    );
    expect(
      () => ShellClaim(
        source: const ServiceSource('s'),
        writes: <TopicRef>{state('a.b'), event('a.c'), event('a.d')},
      ),
      throwsA(
        isA<ArgumentError>()
            .having((ArgumentError e) => e.name, 'name', 'writes')
            .having((ArgumentError e) => e.invalidValue, 'invalidValue', 'a.c'),
      ),
    );
  });

  test('G3 a claim keeps an unmodifiable copy of its writes, in canonical '
      'order, whatever order they were given in', () {
    final Set<TopicRef> given = <TopicRef>{
      state('b.a'),
      state('a.b', 'String'),
      state('a.b', 'Cart'),
    };
    final ShellClaim claim = ShellClaim(
      source: const ServiceSource('s'),
      writes: given,
    );
    given.add(state('c.c'));
    expect(claim.writes.toList(), <TopicRef>[
      state('a.b', 'Cart'),
      state('a.b', 'String'),
      state('b.a'),
    ]);
    expect(() => claim.writes.add(state('d.d')), throwsUnsupportedError);
    expect(() => claim.writes.clear(), throwsUnsupportedError);
  });

  test('G7 claims are equal, with equal hash codes, exactly when their '
      'source, scope and writes are', () {
    ShellClaim claim(
      MessageSource source,
      Iterable<TopicRef> writes, [
      Scope scope = Scope.application,
    ]) => ShellClaim(source: source, scope: scope, writes: writes.toSet());
    final ShellClaim a = claim(const ServiceSource('s'), <TopicRef>[
      state('a.a'),
      state('a.b'),
    ]);
    final ShellClaim same = claim(
      ServiceSource(<String>['s'].single),
      <TopicRef>[state('a.b'), state('a.a')],
    );
    expect(a, same);
    expect(a.hashCode, same.hashCode);
    expect(
      a,
      isNot(
        claim(const PageSource('s'), <TopicRef>[state('a.a'), state('a.b')]),
      ),
    );
    expect(
      a,
      isNot(
        claim(const ServiceSource('s'), <TopicRef>[
          state('a.a'),
          state('a.b'),
        ], Scope.module),
      ),
    );
    expect(a, isNot(claim(const ServiceSource('s'), <TopicRef>[state('a.a')])));
    expect(
      a,
      isNot(
        claim(const ServiceSource('s'), <TopicRef>[
          state('a.a'),
          state('a.b', 'String'),
        ]),
      ),
    );
    expect(<ShellClaim>{a, same}, hasLength(1));
    expect(a, isNot(a.writes));
  });
}
