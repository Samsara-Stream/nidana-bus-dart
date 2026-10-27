// topology-ir@v1's TopologyDefinition, beyond the G6 cases of its
// conformance suite, which the gate replays: reads and writes over repeated
// topics, the argument each rejection names, a negative stage input built
// without assertions, two value types that render alike, unmodifiable copies
// (G3) and value equality (G7), which join the gate at nidana.model.11.
import 'dart:io';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

import 'src/cart_elsewhere.dart' as elsewhere;
import 'src/package_files.dart';

final class Cart {
  const Cart();
}

TopicRef ref(String name, [TopicVariant variant = TopicVariant.event]) =>
    TopicRef(name: name, variant: variant, typeName: 'int');

final FunctionRef f = FunctionRef.named('f');

TransformEdge map(EdgeInput input) =>
    TransformEdge.stage(CombinatorKind.map, <EdgeInput>[input], transformer: f);

TopologyDefinition define(
  List<TransformEdge> transforms, {
  String id = 'def',
  Scope scope = Scope.page,
}) => TopologyDefinition(topologyId: id, scope: scope, transforms: transforms);

/// Throws an ArgumentError whose name is [argument].
Matcher rejects(String argument) => throwsA(
  isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', argument),
);

/// Run without assertions, so that StageInput's assertion cannot stop a
/// negative index before TopologyDefinition sees it.
const String negativeStageInput = '''
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

void main() {
  final StageInput input = StageInput(int.parse('-1'));
  print('StageInput(\${input.edge})');
  try {
    TopologyDefinition(
      topologyId: 'negative',
      scope: Scope.page,
      transforms: <TransformEdge>[
        TransformEdge.write(
          const TopicRef(name: 'a.b', variant: TopicVariant.event, typeName: 'int'),
          input,
        ),
      ],
    );
    print('accepted');
  } on ArgumentError catch (e) {
    print('ArgumentError(\${e.name})');
  }
}
''';

void main() {
  test('G6 reads hold each topic read once, whatever its dedup argument and '
      'the edge that reads it, and writes each sink topic once, both in '
      'canonical order', () {
    final TopologyDefinition d = define(<TransformEdge>[
      map(TopicInput(ref('x.a', TopicVariant.replay))),
      TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        TopicInput(ref('x.a', TopicVariant.state), dedup: Dedup.none),
        const StageInput(0),
        TopicInput(ref('x.a', TopicVariant.state)),
      ]),
      TransformEdge.write(ref('y.e'), const StageInput(1)),
      TransformEdge.write(
        ref('y.e'),
        TopicInput(ref('x.a', TopicVariant.state)),
      ),
      TransformEdge.write(ref('y.e', TopicVariant.replay), const StageInput(1)),
      TransformEdge.reduceInto(
        ref('y.d', TopicVariant.state),
        const StageInput(1),
        f,
      ),
    ]);
    expect(d.reads.toList(), <TopicRef>[
      ref('x.a', TopicVariant.state),
      ref('x.a', TopicVariant.replay),
    ]);
    expect(d.writes.toList(), <TopicRef>[
      ref('y.d', TopicVariant.state),
      ref('y.e'),
      ref('y.e', TopicVariant.replay),
    ]);
  });

  test('G6 one stage edge may feed several later edges, and one edge may '
      'take a stage twice', () {
    final TopologyDefinition d = define(<TransformEdge>[
      map(TopicInput(ref('a'))),
      TransformEdge.stage(CombinatorKind.combine, const <EdgeInput>[
        StageInput(0),
        StageInput(0),
      ], transformer: f),
      TransformEdge.write(ref('b'), const StageInput(0)),
      TransformEdge.write(ref('c'), const StageInput(1)),
    ]);
    expect(d.transforms, hasLength(4));
    expect(d.writes.toList(), <TopicRef>[ref('b'), ref('c')]);
  });

  test('G6 a state topic and an event topic of one name are two topics, each '
      'with its sink', () {
    final TopologyDefinition d = define(<TransformEdge>[
      TransformEdge.write(ref('n', TopicVariant.state), TopicInput(ref('a'))),
      TransformEdge.write(ref('n'), TopicInput(ref('a'))),
    ]);
    expect(d.writes.toList(), <TopicRef>[
      ref('n', TopicVariant.state),
      ref('n'),
    ]);
  });

  test('G6 two state topics whose value types render alike are one topic to '
      'the IR, so a sink on each throws', () {
    const StateTopic<Cart> mine = StateTopic<Cart>(
      name: 'shop.cart',
      initial: Cart(),
    );
    const StateTopic<elsewhere.Cart> theirs = StateTopic<elsewhere.Cart>(
      name: 'shop.cart',
      initial: elsewhere.Cart(),
    );
    expect(mine, isNot(theirs));
    expect(mine.ref, theirs.ref);
    expect(
      () => define(<TransformEdge>[
        TransformEdge.write(mine.ref, TopicInput(ref('a'))),
        TransformEdge.write(theirs.ref, TopicInput(ref('b'))),
      ]),
      rejects('transforms'),
    );
  });

  test('G6 an empty id names the topologyId and an ill-formed edge list names '
      'the transforms', () {
    expect(
      () => define(const <TransformEdge>[], id: ''),
      rejects('topologyId'),
    );
    expect(
      () => define(<TransformEdge>[
        TransformEdge.write(ref('b'), const StageInput(0)),
      ]),
      rejects('transforms'),
    );
    expect(
      () => define(<TransformEdge>[
        map(TopicInput(ref('a'))),
        map(const StageInput(0)),
        TransformEdge.write(ref('b'), const StageInput(0)),
      ]),
      rejects('transforms'),
    );
  });

  test('G6 every rule of a well-formed definition names the transforms when '
      'broken, and a replay topic takes any number of sinks', () {
    final Map<String, List<TransformEdge>> broken =
        <String, List<TransformEdge>>{
          'a stage input naming a later edge': <TransformEdge>[
            map(const StageInput(1)),
            map(TopicInput(ref('a'))),
            TransformEdge.write(ref('b'), const StageInput(0)),
          ],
          'a stage input naming its own edge': <TransformEdge>[
            map(const StageInput(0)),
            TransformEdge.write(ref('b'), const StageInput(0)),
          ],
          'a stage input beyond the edges': <TransformEdge>[
            TransformEdge.write(ref('b'), const StageInput(5)),
          ],
          'a stage input naming a sink edge': <TransformEdge>[
            TransformEdge.write(ref('b'), TopicInput(ref('a'))),
            TransformEdge.write(ref('c'), const StageInput(0)),
          ],
          'a stage edge after a sink edge': <TransformEdge>[
            map(TopicInput(ref('a'))),
            TransformEdge.write(ref('b'), const StageInput(0)),
            map(TopicInput(ref('c'))),
            TransformEdge.write(ref('d'), const StageInput(2)),
          ],
          'a stage edge no later edge consumes': <TransformEdge>[
            map(TopicInput(ref('a'))),
            map(TopicInput(ref('c'))),
            TransformEdge.write(ref('b'), const StageInput(0)),
          ],
          'a second sink edge on one state topic': <TransformEdge>[
            TransformEdge.write(
              ref('s', TopicVariant.state),
              TopicInput(ref('a')),
            ),
            TransformEdge.reduceInto(
              ref('s', TopicVariant.state),
              TopicInput(ref('b')),
              f,
            ),
          ],
        };
    for (final MapEntry<String, List<TransformEdge>> entry in broken.entries) {
      expect(
        () => define(entry.value),
        rejects('transforms'),
        reason: entry.key,
      );
    }
    final TopologyDefinition d = define(<TransformEdge>[
      TransformEdge.write(ref('r', TopicVariant.replay), TopicInput(ref('a'))),
      TransformEdge.write(ref('r', TopicVariant.replay), TopicInput(ref('b'))),
    ]);
    expect(d.writes.toList(), <TopicRef>[ref('r', TopicVariant.replay)]);
  });

  test('G6 a negative stage input, which only code run without assertions '
      'can build, is rejected', () async {
    final Directory temp = Directory.systemTemp.createTempSync('ir_negative');
    addTearDown(() => temp.deleteSync(recursive: true));
    final File script = File('${temp.path}/negative.dart')
      ..writeAsStringSync(negativeStageInput);
    final ProcessResult result = await Process.run(
      Platform.resolvedExecutable,
      <String>[
        '--packages=${workspaceRoot().path}/.dart_tool/package_config.json',
        script.path,
      ],
    );
    expect(result.stderr, '');
    expect(result.stdout, 'StageInput(-1)\nArgumentError(transforms)\n');
    expect(result.exitCode, 0);
  });

  test('G3 a definition keeps an unmodifiable copy of its edges, and its reads '
      'and writes are unmodifiable', () {
    final List<TransformEdge> given = <TransformEdge>[
      TransformEdge.write(ref('b'), TopicInput(ref('a'))),
    ];
    final TopologyDefinition d = define(given);
    given.add(TransformEdge.write(ref('c'), TopicInput(ref('a'))));
    expect(d.transforms, hasLength(1));
    expect(d.writes.toList(), <TopicRef>[ref('b')]);
    expect(() => d.transforms.clear(), throwsUnsupportedError);
    expect(() => d.reads.add(ref('z')), throwsUnsupportedError);
    expect(() => d.writes.remove(ref('b')), throwsUnsupportedError);
  });

  test('G7 definitions are equal, with equal hash codes, exactly when their '
      'id, scope and edges, element by element, are', () {
    List<TransformEdge> edges() => <TransformEdge>[
      map(TopicInput(ref('a'))),
      TransformEdge.write(ref('b'), const StageInput(0)),
      TransformEdge.write(ref('c'), const StageInput(0)),
    ];
    expect(define(edges()), define(edges()));
    expect(define(edges()).hashCode, define(edges()).hashCode);
    expect(<TopologyDefinition>{
      define(edges()),
      define(edges()),
    }, hasLength(1));
    expect(define(edges(), id: 'other'), isNot(define(edges())));
    expect(define(edges(), scope: Scope.module), isNot(define(edges())));
    final List<TransformEdge> swapped = edges();
    swapped.insert(1, swapped.removeAt(2));
    expect(define(swapped).writes, define(edges()).writes);
    expect(define(swapped), isNot(define(edges())));
  });
}
