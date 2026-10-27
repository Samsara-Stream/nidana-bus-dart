// topology-ir@v1's findWriterConflicts (G15) and findScopeViolations (G16),
// beyond the G15 and G16 cases of its conformance suite, which the gate
// replays: a reduceInto as a writer, claims of one source in two scopes,
// the canonical order of topics, every pair of scopes, the order of owners
// by rendering and then scope with equal owners counted once, in a short
// owner list and a long one, the owners that never violate, a topic of the
// same name but another variant or type, and unmodifiable results (G3).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/analysis_support.dart';

/// The owner and reader scopes of Spec §7.2 that violate: an owner that
/// lives shorter than its reader.
const List<(Scope, Scope)> violating = <(Scope, Scope)>[
  (Scope.module, Scope.application),
  (Scope.page, Scope.application),
  (Scope.page, Scope.module),
];

ScopeViolation violation(
  TopicRef topic,
  MessageSource owner,
  Scope ownerScope,
  String readerId,
  Scope readerScope,
) => ScopeViolation(
  topic: topic,
  owner: owner,
  ownerScope: ownerScope,
  readerId: readerId,
  readerScope: readerScope,
);

void main() {
  test('G15 a reduceInto makes its topology a writer, and two claims of one '
      'source in two scopes are two writers', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        define('fold', <TransformEdge>[
          TransformEdge.reduceInto(
            state('own.s'),
            TopicInput(event('own.in')),
            f,
          ),
        ]),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ServiceSource('svc'),
          writes: <TopicRef>{state('own.s')},
        ),
        ShellClaim(
          source: const ServiceSource('svc'),
          scope: Scope.page,
          writes: <TopicRef>{state('own.s')},
        ),
      ],
    );
    expect(findWriterConflicts(g), <WriterConflict>[
      WriterConflict(
        topic: state('own.s'),
        writers: const <MessageSource>[
          ServiceSource('svc'),
          ServiceSource('svc'),
          TopologySource('fold'),
        ],
      ),
    ]);
  });

  test('G15 conflicts come in canonical topic order, by name, then variant, '
      'then type, and a replay topic has none', () {
    final List<TopicRef> written = <TopicRef>[
      state('cfl.b', 'A'),
      replay('cfl.a'),
      state('cfl.a', 'B'),
      state('cfl.a', 'A'),
    ];
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('t1', <TopicRef>[event('cfl.in')], written),
        rw('t2', <TopicRef>[event('cfl.in')], written),
      ],
    );
    const List<MessageSource> both = <MessageSource>[
      TopologySource('t1'),
      TopologySource('t2'),
    ];
    expect(findWriterConflicts(g), <WriterConflict>[
      WriterConflict(topic: state('cfl.a', 'A'), writers: both),
      WriterConflict(topic: state('cfl.a', 'B'), writers: both),
      WriterConflict(topic: state('cfl.b', 'A'), writers: both),
    ]);
  });

  test('G16 an owner violates exactly when it lives shorter than its reader, '
      'for every pair of scopes', () {
    for (final Scope ownerScope in Scope.values) {
      for (final Scope readerScope in Scope.values) {
        final TopologyGraph g = TopologyGraph(
          topologies: <TopologyDefinition>[
            rw(
              'owner',
              <TopicRef>[event('pair.in')],
              <TopicRef>[state('pair.s')],
              scope: ownerScope,
            ),
            rw(
              'reader',
              <TopicRef>[state('pair.s')],
              <TopicRef>[event('pair.out')],
              scope: readerScope,
            ),
          ],
        );
        expect(
          findScopeViolations(g),
          violating.contains((ownerScope, readerScope))
              ? <ScopeViolation>[
                  violation(
                    state('pair.s'),
                    const TopologySource('owner'),
                    ownerScope,
                    'reader',
                    readerScope,
                  ),
                ]
              : isEmpty,
          reason: 'a ${ownerScope.name} owner, a ${readerScope.name} reader',
        );
      }
    }
  });

  test('G16 violations come by topic, then owner by its rendering and then '
      'its scope, then reader in graph order; equal owners count once', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('w', <TopicRef>[event('ord.in')], <TopicRef>[state('ord.b')]),
        rw(
          'r2',
          <TopicRef>[state('ord.a'), state('ord.b')],
          <TopicRef>[event('ord.o2')],
          scope: Scope.module,
        ),
        rw(
          'r1',
          <TopicRef>[state('ord.a'), state('ord.b')],
          <TopicRef>[event('ord.o1')],
          scope: Scope.application,
        ),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ServiceSource('svc'),
          scope: Scope.page,
          writes: <TopicRef>{state('ord.a')},
        ),
        ShellClaim(
          source: const ServiceSource('svc'),
          scope: Scope.module,
          writes: <TopicRef>{state('ord.a'), state('ord.b')},
        ),
        ShellClaim(
          source: const PageSource('form'),
          scope: Scope.page,
          writes: <TopicRef>{state('ord.b')},
        ),
        ShellClaim(
          source: const PageSource('form'),
          scope: Scope.page,
          writes: <TopicRef>{state('ord.b'), state('ord.a')},
        ),
      ],
    );
    const MessageSource form = PageSource('form');
    const MessageSource svc = ServiceSource('svc');
    const MessageSource w = TopologySource('w');
    const Scope app = Scope.application;
    const Scope mod = Scope.module;
    const Scope page = Scope.page;
    final TopicRef a = state('ord.a');
    final TopicRef b = state('ord.b');
    expect(findScopeViolations(g), <ScopeViolation>[
      violation(a, form, page, 'r1', app),
      violation(a, form, page, 'r2', mod),
      violation(a, svc, mod, 'r1', app),
      violation(a, svc, page, 'r1', app),
      violation(a, svc, page, 'r2', mod),
      violation(b, form, page, 'r1', app),
      violation(b, form, page, 'r2', mod),
      violation(b, svc, mod, 'r1', app),
      violation(b, w, page, 'r1', app),
      violation(b, w, page, 'r2', mod),
    ]);
  });

  test('G16 owners of one source come by scope however many owners a topic '
      'has', () {
    // The graph orders claims by source and then scope, so sorting owners by
    // source alone keeps that order in a short list, which List.sort orders
    // by insertion, and loses it in a list of 80 owners.
    String name(int i) => 'svc${i.toString().padLeft(2, '0')}';
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw(
          'r',
          <TopicRef>[state('long.s')],
          <TopicRef>[event('long.out')],
          scope: Scope.application,
        ),
      ],
      claims: <ShellClaim>[
        for (int i = 0; i < 40; i++)
          for (final Scope scope in <Scope>[Scope.module, Scope.page])
            ShellClaim(
              source: ServiceSource(name(i)),
              scope: scope,
              writes: <TopicRef>{state('long.s')},
            ),
      ],
    );
    expect(findScopeViolations(g), <ScopeViolation>[
      for (int i = 0; i < 40; i++)
        for (final Scope scope in <Scope>[Scope.module, Scope.page])
          violation(
            state('long.s'),
            ServiceSource(name(i)),
            scope,
            'r',
            Scope.application,
          ),
    ]);
  });

  test('G16 a topology reading the topic it owns, an application claim, and '
      'an event or replay topic never violate', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('self', <TopicRef>[state('safe.s')], <TopicRef>[state('safe.s')]),
        rw(
          'short',
          <TopicRef>[event('safe.in')],
          <TopicRef>[event('safe.e'), replay('safe.r')],
        ),
        rw(
          'long',
          <TopicRef>[state('safe.c'), event('safe.e'), replay('safe.r')],
          <TopicRef>[event('safe.out')],
          scope: Scope.application,
        ),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ExecutorSource('nav'),
          writes: <TopicRef>{state('safe.c')},
        ),
      ],
    );
    expect(findScopeViolations(g), isEmpty);
  });

  test('G15 G16 a topic of the same name but another variant or type is '
      'another topic, written, claimed or read', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('a', <TopicRef>[event('same.in')], <TopicRef>[state('same.x')]),
        rw(
          'b',
          <TopicRef>[event('same.in')],
          <TopicRef>[state('same.x', 'String')],
        ),
        rw('c', <TopicRef>[event('same.in')], <TopicRef>[event('same.x')]),
        rw('d', <TopicRef>[event('same.in')], <TopicRef>[replay('same.x')]),
        rw(
          'r',
          <TopicRef>[
            state('same.x', 'String'),
            event('same.x'),
            replay('same.x'),
          ],
          <TopicRef>[event('same.out')],
          scope: Scope.application,
        ),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ServiceSource('svc'),
          scope: Scope.page,
          writes: <TopicRef>{state('same.x', 'bool')},
        ),
      ],
    );
    expect(
      g.topics.where((TopicRef topic) => topic.name == 'same.x'),
      hasLength(5),
      reason: 'five topics share the name same.x',
    );
    expect(findWriterConflicts(g), isEmpty);
    expect(findScopeViolations(g), <ScopeViolation>[
      violation(
        state('same.x', 'String'),
        const TopologySource('b'),
        Scope.page,
        'r',
        Scope.application,
      ),
    ]);
  });

  test('G3 findWriterConflicts and findScopeViolations return unmodifiable '
      'lists, empty or not', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[
        rw('o', <TopicRef>[event('u.in')], <TopicRef>[state('u.s')]),
        rw(
          'r',
          <TopicRef>[state('u.s')],
          <TopicRef>[event('u.out')],
          scope: Scope.application,
        ),
      ],
      claims: <ShellClaim>[
        ShellClaim(
          source: const ServiceSource('u'),
          writes: <TopicRef>{state('u.s')},
        ),
      ],
    );
    final List<WriterConflict> conflicts = findWriterConflicts(g);
    final List<ScopeViolation> violations = findScopeViolations(g);
    final List<WriterConflict> noConflicts = findWriterConflicts(
      TopologyGraph(),
    );
    final List<ScopeViolation> noViolations = findScopeViolations(
      TopologyGraph(),
    );
    expect(conflicts, hasLength(1));
    expect(violations, hasLength(1));
    expect(() => conflicts.clear(), throwsUnsupportedError);
    expect(() => violations.clear(), throwsUnsupportedError);
    expect(() => noConflicts.add(conflicts.first), throwsUnsupportedError);
    expect(() => noViolations.add(violations.first), throwsUnsupportedError);
  });
}
