// topology-ir@v1's decoder on graph documents (The JSON form; G4, G20), and
// on values of the wrong shape (G21), beyond the conformance suite's cases:
// every valid/ file rendered back byte for byte, what the schema allows that
// no sample holds, Dart maps and lists that are not jsonDecode's, the
// FormatException's message, round trips and any list order over generated
// graphs, and that nothing here schedules work (G22).
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/json_support.dart';

/// [document] with [edit] applied to a deep copy.
Map<String, Object?> edited(
  Object? document,
  void Function(Map<String, Object?> doc) edit,
) {
  final Map<String, Object?> copy =
      jsonDecode(jsonEncode(document)) as Map<String, Object?>;
  edit(copy);
  return copy;
}

Map<String, Object?> topologyOf(Map<String, Object?> doc, [int i = 0]) =>
    (doc['topologies']! as List<Object?>)[i]! as Map<String, Object?>;

Map<String, Object?> edgeOf(Map<String, Object?> doc, int e) =>
    (topologyOf(doc)['transforms']! as List<Object?>)[e]!
        as Map<String, Object?>;

Map<String, Object?> claimOf(Map<String, Object?> doc) =>
    (doc['claims']! as List<Object?>)[0]! as Map<String, Object?>;

/// The message of the FormatException [decode] throws for [value]; any
/// other error propagates and fails the test.
String rejection(
  Object? value, [
  Object? Function(Object?) decode = decodeTopologyGraph,
]) {
  try {
    decode(value);
  } on FormatException catch (e) {
    return e.message;
  }
  fail('decoded a value the decoder must reject');
}

/// [list] in an order [random] draws.
List<Object?> shuffled(Object? list, Random random) =>
    List<Object?>.of(list! as List<Object?>)..shuffle(random);

Map<String, Object?> inputOf(Map<String, Object?> doc, int e, int i) =>
    (edgeOf(doc, e)['inputs']! as List<Object?>)[i]! as Map<String, Object?>;

/// A topic reference object, a new one on each call.
Map<String, Object?> topicDoc() => <String, Object?>{
  'name': 'n',
  'variant': 'state',
  'typeName': 'int',
};

/// A definition object with no reads or writes, holding [edges].
Map<String, Object?> definitionDoc(List<Object?> edges) => <String, Object?>{
  'topologyId': 't',
  'scope': 'page',
  'reads': <Object?>[],
  'writes': <Object?>[],
  'transforms': edges,
};

/// The message of the FormatException the definition decoder throws for a
/// definition object holding [edge] alone.
String edgeRejection(Object? edge) =>
    rejection(definitionDoc(<Object?>[edge]), decodeTopologyDefinition);

/// A graph document holding [claims] alone.
Map<String, Object?> claimsDoc(List<Object?> claims) => <String, Object?>{
  'format': 'topology-ir@v1',
  'topologies': <Object?>[],
  'claims': claims,
};

/// [value] with the keys of every object in an order [random] draws.
Object? withShuffledKeys(Object? value, Random random) => switch (value) {
  Map<String, Object?>() => <String, Object?>{
    for (final String key in value.keys.toList()..shuffle(random))
      key: withShuffledKeys(value[key], random),
  },
  List<Object?>() => <Object?>[
    for (final Object? element in value) withShuffledKeys(element, random),
  ],
  _ => value,
};

/// [value] with every object an unmodifiable `Map<Object?, Object?>` and every
/// array an unmodifiable `List<Object?>`, as a Dart caller may build them.
Object? withForeignCollections(Object? value) => switch (value) {
  Map<String, Object?>() => Map<Object?, Object?>.unmodifiable(
    <Object?, Object?>{
      for (final MapEntry<String, Object?> e in value.entries)
        e.key: withForeignCollections(e.value),
    },
  ),
  List<Object?>() => List<Object?>.unmodifiable(<Object?>[
    for (final Object? element in value) withForeignCollections(element),
  ]),
  _ => value,
};

void main() {
  test('G20 every valid/ file decodes, and JsonRenderer renders the graph '
      'back byte for byte', () {
    final List<String> names = fixtureNames('valid');
    expect(names, hasLength(7));
    for (final String name in names) {
      final String text = fixtureText('valid/$name.json');
      expect(
        const JsonRenderer().render(decodeTopologyGraph(jsonDecode(text))),
        text,
        reason: name,
      );
    }
  });

  test("G20 the Interface's example decodes to the graph it describes", () {
    expect(
      decodeTopologyGraph(jsonDecode(interfaceExample)),
      interfaceExampleGraph(),
    );
    expect(
      decodeTopologyDefinition(
        ((jsonDecode(interfaceExample) as Map<String, Object?>)['topologies']!
                as List<Object?>)
            .single,
      ),
      interfaceExampleGraph().topologies.single,
    );
  });

  test('G20 the decoder accepts what the schema allows and no sample holds: '
      'an empty topic name, a zero duration and index, a whole-number double, '
      'two equal claims, a source name holding a colon', () {
    final Object? forms = fixtureJson('valid/forms.json');
    final Map<String, Object?> doc = edited(forms, (Map<String, Object?> d) {
      edgeOf(d, 3)['durationMicros'] = 5000.0;
      final Map<String, Object?> claim = claimOf(d);
      claim['source'] = 'service:a:b';
      ((claim['writes']! as List<Object?>)[0]!
              as Map<String, Object?>)['name'] =
          '';
      (d['claims']! as List<Object?>).add(jsonDecode(jsonEncode(claim)));
    });
    final TopologyGraph g = decodeTopologyGraph(doc);
    expect(
      g.topologies.single.transforms[3].duration,
      const Duration(milliseconds: 5),
    );
    expect(g.claims, hasLength(2));
    expect(g.claims.first, g.claims.last);
    expect(g.claims.first.source, const ServiceSource('a:b'));
    expect(g.claims.first.writes.single.name, '');
    final Map<String, Object?> zero = edited(forms, (Map<String, Object?> d) {
      edgeOf(d, 3)['durationMicros'] = 0;
    });
    expect(
      decodeTopologyGraph(zero).topologies.single.transforms[3].duration,
      Duration.zero,
    );
  });

  test('G20 the decoder reads Dart maps and lists that jsonDecode does not '
      'make: Object? keys and unmodifiable collections', () {
    expect(
      decodeTopologyGraph(<Object?, Object?>{
        'format': 'topology-ir@v1',
        'topologies': const <Object?>[],
        'claims': List<Object?>.unmodifiable(<Object?>[]),
      }),
      TopologyGraph(),
    );
    expect(
      decodeTopologyGraph(
        Map<String, Object?>.unmodifiable(<String, Object?>{
          'format': 'topology-ir@v1',
          'topologies': <Object?>[],
          'claims': <Object?>[
            <String, Object?>{
              'source': 'service:s',
              'scope': 'module',
              'writes': <Object?>[
                <String, String>{
                  'name': 'n',
                  'variant': 'state',
                  'typeName': 'int',
                },
              ],
            },
          ],
        }),
      ).claims.single.scope,
      Scope.module,
    );
  });

  test('G21 a value of the wrong shape is rejected with a FormatException '
      'that names its JSONPath and what must be there', () {
    final Object? forms = fixtureJson('valid/forms.json');
    expect(rejection(null), r'$: must be an object');
    expect(rejection(<Object?>[]), r'$: must be an object');
    expect(rejection(<Object?, Object?>{1: 2}), r'$: must be an object');
    expect(
      rejection(edited(forms, (Map<String, Object?> d) => d.remove('claims'))),
      r'$.claims: is missing',
    );
    expect(
      rejection(edited(forms, (Map<String, Object?> d) => d['x'] = 1)),
      r'$: must not have the key "x"',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => d['format'] = 'topology-ir@v2',
        ),
      ),
      r'$.format: must be "topology-ir@v1"',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => d['topologies'] = <String, Object?>{},
        ),
      ),
      r'$.topologies: must be an array',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => topologyOf(d)['topologyId'] = 7,
        ),
      ),
      r'$.topologies[0].topologyId: must be a string',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => topologyOf(d)['scope'] = 'session',
        ),
      ),
      r'$.topologies[0].scope: must be one of application, module, page',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) => edgeOf(d, 0)['combinator'] = null,
        ),
      ),
      startsWith(
        r'$.topologies[0].transforms[0].combinator: must be one of map, filter, ',
      ),
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> inputs = edgeOf(d, 4)['inputs']! as List<Object?>;
          inputs.add(inputs.first);
        }),
      ),
      r'$.topologies[0].transforms[4].inputs: must hold exactly one input',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          ((edgeOf(d, 1)['inputs']! as List<Object?>)[1]!
                  as Map<String, Object?>)['dedup'] =
              'always';
        }),
      ),
      r'$.topologies[0].transforms[1].inputs[1].dedup: must be one of equality, none',
    );
    expect(
      rejection(
        edited(
          forms,
          (Map<String, Object?> d) =>
              edgeOf(d, 0)['transformer'] = <String, Object?>{'name': 3},
        ),
      ),
      startsWith(r'$.topologies[0].transforms[0].transformer.name: must be '),
    );
    expect(
      rejection(<String, Object?>{'topologyId': 'x'}, decodeTopologyDefinition),
      r'$.scope: is missing',
    );
    expect(
      rejection(<String, Object?>{
        'topologyId': 'x',
        'scope': 'page',
        'reads': <Object?>[],
        'writes': <Object?>[],
        'transforms': <Object?>[
          <String, Object?>{
            'inputs': <Object?>[
              <String, Object?>{'edge': '0'},
            ],
            'output': <String, Object?>{
              'name': 'n',
              'variant': 'event',
              'typeName': 'int',
            },
          },
        ],
      }, decodeTopologyDefinition),
      startsWith(r'$.transforms[0].inputs[0].edge: must be '),
    );
  });

  test('G20 a generated graph decodes from its JSON text equal, and its '
      'encoding is that text again', () {
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      final String text = const JsonRenderer().render(g);
      final TopologyGraph decoded = decodeTopologyGraph(jsonDecode(text));
      expect(decoded, g, reason: 'seed $seed');
      expect(const JsonRenderer().render(decoded), text, reason: 'seed $seed');
    }
  });

  test(
    'G4 G20 every generated definition decodes from its JSON text equal',
    () {
      for (int seed = 0; seed < seeds; seed++) {
        for (final TopologyDefinition d in generatedGraph(seed).topologies) {
          expect(
            decodeTopologyDefinition(
              jsonDecode(jsonEncode(encodeTopologyDefinition(d))),
            ),
            d,
            reason: 'seed $seed, ${d.topologyId}',
          );
        }
      }
    },
  );

  test('G20 the decoder accepts the topologies, claims, reads, writes and '
      "claimed topics of a generated graph's document in any order", () {
    for (int seed = 0; seed < seeds; seed++) {
      final Random random = Random(seed);
      final TopologyGraph g = generatedGraph(seed);
      final Map<String, Object?> doc = edited(encodeTopologyGraph(g), (
        Map<String, Object?> d,
      ) {
        d['topologies'] = shuffled(d['topologies'], random);
        d['claims'] = shuffled(d['claims'], random);
        for (final Object? t in d['topologies']! as List<Object?>) {
          final Map<String, Object?> m = t! as Map<String, Object?>;
          m['reads'] = shuffled(m['reads'], random);
          m['writes'] = shuffled(m['writes'], random);
        }
        for (final Object? c in d['claims']! as List<Object?>) {
          final Map<String, Object?> m = c! as Map<String, Object?>;
          m['writes'] = shuffled(m['writes'], random);
        }
      });
      final TopologyGraph decoded = decodeTopologyGraph(doc);
      expect(decoded, g, reason: 'seed $seed');
      expect(
        jsonEncode(encodeTopologyGraph(decoded)),
        jsonEncode(encodeTopologyGraph(g)),
        reason: 'seed $seed',
      );
    }
  });

  test('G20 the generated graphs reach every combinator, input form, '
      'function form, variant, scope and source kind', () {
    final Set<Object?> kinds = <Object?>{};
    final Set<Object> forms = <Object>{};
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      for (final TopologyDefinition d in g.topologies) {
        forms.add(d.scope);
        for (final TransformEdge e in d.transforms) {
          kinds.add(e.combinator);
          if (e.retry != null) {
            forms.add('retry');
          }
          if (e.transformer case FunctionRef(name: null)) {
            forms.add('anonymous');
          }
          if (e.duration == Duration.zero) {
            forms.add('zero duration');
          }
          for (final EdgeInput input in e.inputs) {
            switch (input) {
              case TopicInput(:final TopicRef topic, :final Dedup? dedup):
                forms.add(topic.variant);
                if (dedup != null) {
                  forms.add(dedup);
                }
                if (topic.name.isEmpty) {
                  forms.add('empty name');
                }
              case StageInput():
                forms.add('stage input');
            }
          }
        }
      }
      for (final ShellClaim c in g.claims) {
        forms.add(c.source.runtimeType);
      }
    }
    expect(kinds, <Object?>{...CombinatorKind.values, null});
    expect(
      forms,
      containsAll(<Object>[
        ...Scope.values,
        ...TopicVariant.values,
        ...Dedup.values,
        'retry',
        'anonymous',
        'zero duration',
        'empty name',
        'stage input',
        ServiceSource,
        PageSource,
        ExecutorSource,
      ]),
    );
  });

  test('G22 encoding, decoding and rendering create no timer and schedule no '
      'microtask', () {
    var scheduled = 0;
    runZoned(
      () {
        for (int seed = 0; seed < 20; seed++) {
          final TopologyGraph g = generatedGraph(seed);
          decodeTopologyGraph(jsonDecode(const JsonRenderer().render(g)));
          for (final TopologyDefinition d in g.topologies) {
            decodeTopologyDefinition(encodeTopologyDefinition(d));
          }
        }
      },
      zoneSpecification: ZoneSpecification(
        createTimer:
            (
              Zone self,
              ZoneDelegate parent,
              Zone zone,
              Duration d,
              void Function() f,
            ) {
              scheduled++;
              return parent.createTimer(zone, d, f);
            },
        createPeriodicTimer:
            (
              Zone self,
              ZoneDelegate parent,
              Zone zone,
              Duration d,
              void Function(Timer t) f,
            ) {
              scheduled++;
              return parent.createPeriodicTimer(zone, d, f);
            },
        scheduleMicrotask:
            (Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
              scheduled++;
              parent.scheduleMicrotask(zone, f);
            },
      ),
    );
    expect(scheduled, 0);
  });

  test('G21 the decoder reports the first missing key in the schema\'s order, '
      'then the first unexpected key in the document\'s order, and quotes '
      'that key', () {
    expect(
      rejection(<String, Object?>{'format': 'topology-ir@v1'}),
      r'$.topologies: is missing',
    );
    expect(
      rejection(<String, Object?>{'x': 1, 'format': 'topology-ir@v1'}),
      r'$.topologies: is missing',
    );
    expect(
      rejection(<String, Object?>{
        'y': 1,
        'x': 1,
        'format': 'topology-ir@v1',
        'topologies': <Object?>[],
        'claims': <Object?>[],
      }),
      r'$: must not have the key "y"',
    );
    expect(
      rejection(<String, Object?>{
        'format': 'topology-ir@v1',
        'topologies': <Object?>[],
        'claims': <Object?>[],
        'a"b\nc': 1,
      }),
      r'$: must not have the key "a\"b\nc"',
    );
  });

  test('G21 the decoder reads the format, then the topologies, then the '
      'claims, each one a document of this version', () {
    for (final Object? format in <Object?>[
      null,
      1,
      'Topology-IR@v1',
      'topology-ir@v1 ',
      'topology-ir',
    ]) {
      expect(
        rejection(<String, Object?>{
          'format': format,
          'topologies': 1,
          'claims': 1,
        }),
        r'$.format: must be "topology-ir@v1"',
        reason: '$format',
      );
    }
    expect(
      rejection(<String, Object?>{
        'format': 'topology-ir@v1',
        'topologies': 1,
        'claims': 1,
      }),
      r'$.topologies: must be an array',
    );
    expect(
      rejection(<String, Object?>{
        'format': 'topology-ir@v1',
        'topologies': <Object?>[],
        'claims': 1,
      }),
      r'$.claims: must be an array',
    );
    final Object? forms = fixtureJson('valid/forms.json');
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          (d['topologies']! as List<Object?>).add(5);
          (d['claims']! as List<Object?>).add(5);
        }),
      ),
      r'$.topologies[1]: must be an object',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          (d['claims']! as List<Object?>).add(<String, Object?>{
            'source': 'service:b',
            'scope': 'x',
            'writes': <Object?>[],
          });
        }),
      ),
      r'$.claims[1].scope: must be one of application, module, page',
    );
  });

  test('G21 the decoder reads a definition, an edge, an input and a topic '
      'member by member in the schema\'s order, so that the first one that '
      'is wrong names the place', () {
    final Map<String, Object?> definition = <String, Object?>{
      'topologyId': 1,
      'scope': 'x',
      'reads': 1,
      'writes': 1,
      'transforms': 1,
    };
    String definitionProblem() =>
        rejection(definition, decodeTopologyDefinition);
    expect(definitionProblem(), r'$.topologyId: must be a string');
    definition['topologyId'] = 't';
    expect(
      definitionProblem(),
      r'$.scope: must be one of application, module, page',
    );
    definition['scope'] = 'page';
    expect(definitionProblem(), r'$.reads: must be an array');
    definition['reads'] = <Object?>[1];
    expect(definitionProblem(), r'$.reads[0]: must be an object');
    definition['reads'] = <Object?>[];
    expect(definitionProblem(), r'$.writes: must be an array');
    definition['writes'] = <Object?>[
      <String, Object?>{'name': 'n', 'variant': 'state', 'typeName': 3},
    ];
    expect(definitionProblem(), r'$.writes[0].typeName: must be a string');
    definition['writes'] = <Object?>[];
    expect(definitionProblem(), r'$.transforms: must be an array');

    final Map<String, Object?> stage = <String, Object?>{
      'combinator': 'map',
      'inputs': 1,
      'transformer': 1,
      'durationMicros': 'x',
      'retry': 1,
    };
    expect(edgeRejection(stage), r'$.transforms[0].inputs: must be an array');
    stage['inputs'] = <Object?>[];
    expect(
      edgeRejection(stage),
      r'$.transforms[0].transformer: must be an object',
    );
    stage['transformer'] = <String, Object?>{'name': 'f'};
    expect(
      edgeRejection(stage),
      startsWith(r'$.transforms[0].durationMicros: must be '),
    );
    stage['durationMicros'] = 5;
    expect(edgeRejection(stage), r'$.transforms[0].retry: must be an object');

    final Map<String, Object?> write = <String, Object?>{
      'inputs': 1,
      'output': 1,
    };
    expect(edgeRejection(write), r'$.transforms[0].inputs: must be an array');
    write['inputs'] = <Object?>[];
    expect(
      edgeRejection(write),
      r'$.transforms[0].inputs: must hold exactly one input',
    );
    write['inputs'] = <Object?>[
      <String, Object?>{'edge': 0},
      <String, Object?>{'edge': 1},
    ];
    expect(
      edgeRejection(write),
      r'$.transforms[0].inputs: must hold exactly one input',
    );
    write['inputs'] = <Object?>[
      <String, Object?>{'edge': 0},
    ];
    expect(edgeRejection(write), r'$.transforms[0].output: must be an object');

    final Map<String, Object?> reduce = <String, Object?>{
      'combinator': 'reduceInto',
      'inputs': 1,
      'output': 1,
      'transformer': 1,
    };
    expect(edgeRejection(reduce), r'$.transforms[0].inputs: must be an array');
    reduce['inputs'] = <Object?>[
      <String, Object?>{'edge': 0},
    ];
    expect(edgeRejection(reduce), r'$.transforms[0].output: must be an object');
    reduce['output'] = topicDoc();
    expect(
      edgeRejection(reduce),
      r'$.transforms[0].transformer: must be an object',
    );

    const String input = r'$.transforms[0].inputs[0]';
    Map<String, Object?> writeOf(Object? read) => <String, Object?>{
      'inputs': <Object?>[read],
      'output': topicDoc(),
    };
    expect(edgeRejection(writeOf(5)), '$input: must be an object');
    expect(
      edgeRejection(writeOf(<String, Object?>{})),
      '$input.topic: is missing',
    );
    expect(
      edgeRejection(writeOf(<String, Object?>{'dedup': 'none'})),
      '$input.topic: is missing',
    );
    expect(
      edgeRejection(writeOf(<String, Object?>{'topic': 1, 'dedup': 'x'})),
      '$input.topic: must be an object',
    );
    for (final Object? dedup in <Object?>[null, 'x', 1, 'None']) {
      expect(
        edgeRejection(
          writeOf(<String, Object?>{'topic': topicDoc(), 'dedup': dedup}),
        ),
        '$input.dedup: must be one of equality, none',
        reason: '$dedup',
      );
    }
    expect(
      edgeRejection(writeOf(<String, Object?>{'topic': topicDoc(), 'x': 1})),
      '$input: must not have the key "x"',
    );
    expect(
      edgeRejection(writeOf(<String, Object?>{'edge': 0, 'dedup': 'none'})),
      '$input: must not have the key "dedup"',
    );
    expect(
      edgeRejection(writeOf(<String, Object?>{'edge': 'x'})),
      startsWith('$input.edge: must be '),
    );

    final Map<String, Object?> topic = <String, Object?>{
      'name': 1,
      'variant': 1,
      'typeName': 1,
    };
    String topicProblem() => edgeRejection(<String, Object?>{
      'inputs': <Object?>[
        <String, Object?>{'edge': 0},
      ],
      'output': topic,
    });
    expect(topicProblem(), r'$.transforms[0].output.name: must be a string');
    topic['name'] = 'n';
    expect(
      topicProblem(),
      r'$.transforms[0].output.variant: must be one of state, event, replay',
    );
    topic['variant'] = 'event';
    expect(
      topicProblem(),
      r'$.transforms[0].output.typeName: must be a string',
    );
    topic.remove('name');
    expect(topicProblem(), r'$.transforms[0].output.name: is missing');

    expect(
      edgeRejection(<String, Object?>{
        'combinator': 'map',
        'inputs': <Object?>[],
        'transformer': <String, Object?>{'name': 'f', 'x': 1},
      }),
      r'$.transforms[0].transformer: must not have the key "x"',
    );
  });

  test('G21 each form of edge takes its own keys: a write has no combinator, '
      'and an edge without one is read as a write', () {
    final Object? forms = fixtureJson('valid/forms.json');
    const String edges = r'$.topologies[0].transforms';
    for (final (int e, String key, Object? value) in <(int, String, Object?)>[
      (5, 'durationMicros', 0),
      (5, 'retry', <String, Object?>{'name': null}),
      (4, 'durationMicros', 0),
      (4, 'retry', <String, Object?>{'name': null}),
    ]) {
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            edgeOf(d, e)[key] = value;
          }),
        ),
        '$edges[$e]: must not have the key "$key"',
        reason: '$e $key',
      );
    }
    for (final (int e, List<String> remove, String missing)
        in <(int, List<String>, String)>[
          (4, <String>['output', 'inputs'], 'inputs'),
          (4, <String>['inputs'], 'inputs'),
          (5, <String>['transformer', 'inputs'], 'inputs'),
          (5, <String>['transformer', 'output'], 'output'),
          (3, <String>['inputs'], 'inputs'),
          (3, <String>['combinator'], 'output'),
        ]) {
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            remove.forEach(edgeOf(d, e).remove);
          }),
        ),
        '$edges[$e].$missing: is missing',
        reason: '$e $remove',
      );
    }
    for (final Object? edge in <Object?>[
      null,
      5,
      'map',
      <Object?>[],
      <Object?, Object?>{'combinator': 'map', 1: 2},
      <Object?, Object?>{'inputs': <Object?>[], 1: 2},
    ]) {
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            ((topologyOf(d)['transforms']!) as List<Object?>)[0] = edge;
          }),
        ),
        '$edges[0]: must be an object',
        reason: '$edge',
      );
    }
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          edgeOf(d, 0)['transformer'] = null;
        }),
      ),
      '$edges[0].transformer: must be an object',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          edgeOf(d, 3)['retry'] = null;
        }),
      ),
      '$edges[3].retry: must be an object',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          edgeOf(d, 3)['durationMicros'] = null;
        }),
      ),
      startsWith('$edges[3].durationMicros: must be '),
    );
  });

  test('G20 G21 an index and a duration are integers, whole-number doubles '
      'below 2^63 included, and nothing else', () {
    final Object? forms = fixtureJson('valid/forms.json');
    final TopologyGraph graph = decodeTopologyGraph(forms);
    for (final Object? whole in <Object?>[
      2.0,
      jsonDecode('2e0'),
      jsonDecode('20e-1'),
    ]) {
      expect(
        decodeTopologyGraph(
          edited(forms, (Map<String, Object?> d) {
            inputOf(d, 3, 0)['edge'] = whole;
          }),
        ),
        graph,
        reason: 'index $whole',
      );
    }
    for (final Object? whole in <Object?>[
      5000.0,
      jsonDecode('5e3'),
      jsonDecode('50e2'),
    ]) {
      expect(
        decodeTopologyGraph(
          edited(forms, (Map<String, Object?> d) {
            edgeOf(d, 3)['durationMicros'] = whole;
          }),
        ),
        graph,
        reason: 'duration $whole',
      );
    }
    expect(
      decodeTopologyGraph(
        edited(forms, (Map<String, Object?> d) {
          edgeOf(d, 3)['durationMicros'] = 9223372036854774784.0;
        }),
      ).topologies.single.transforms[3].duration!.inMicroseconds,
      9223372036854774784,
    );
    for (final Object? notInteger in <Object?>[
      1.5,
      double.nan,
      double.infinity,
      double.negativeInfinity,
      1e19,
      9223372036854775808.0,
      -9223372036854775808.0,
      '2',
      true,
      <Object?>[2],
      <String, Object?>{},
      null,
    ]) {
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            inputOf(d, 3, 0)['edge'] = notInteger;
          }),
        ),
        startsWith(r'$.topologies[0].transforms[3].inputs[0].edge: must be '),
        reason: 'index $notInteger',
      );
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            edgeOf(d, 3)['durationMicros'] = notInteger;
          }),
        ),
        startsWith(r'$.topologies[0].transforms[3].durationMicros: must be '),
        reason: 'duration $notInteger',
      );
    }
  });

  test('G21 a claim is read as source, scope and writes; its source must be '
      'the rendering of a source, and its writes an array of topics', () {
    const String claim = r'$.claims[0]';
    for (final String text in <String>[
      '',
      'bogus',
      'service',
      'service:',
      'page:',
      'executor:',
      'Service:x',
      ' service:x',
      ':x',
    ]) {
      expect(
        rejection(
          claimsDoc(<Object?>[
            <String, Object?>{
              'source': text,
              'scope': 'page',
              'writes': <Object?>[topicDoc()],
            },
          ]),
        ),
        '$claim.source: must be "service:", "page:" or "executor:" followed '
        'by a name',
        reason: text,
      );
    }
    for (final Object? source in <Object?>[
      null,
      5,
      <Object?>['service:x'],
    ]) {
      expect(
        rejection(
          claimsDoc(<Object?>[
            <String, Object?>{
              'source': source,
              'scope': 'page',
              'writes': <Object?>[topicDoc()],
            },
          ]),
        ),
        '$claim.source: must be a string',
        reason: '$source',
      );
    }
    final TopologyGraph g = decodeTopologyGraph(
      claimsDoc(<Object?>[
        <String, Object?>{
          'source': 'page:/cart?step=1',
          'scope': 'page',
          'writes': <Object?>[topicDoc()],
        },
        <String, Object?>{
          'source': 'executor:x:y',
          'scope': 'module',
          'writes': <Object?>[topicDoc()],
        },
      ]),
    );
    expect(
      g.claims.map((ShellClaim c) => c.source),
      containsAll(<MessageSource>[
        const PageSource('/cart?step=1'),
        const ExecutorSource('x:y'),
      ]),
    );

    final Map<String, Object?> raw = <String, Object?>{
      'source': 1,
      'scope': 1,
      'writes': 1,
    };
    String problem() => rejection(claimsDoc(<Object?>[raw]));
    expect(problem(), '$claim.source: must be a string');
    raw['source'] = 'service:x';
    expect(problem(), '$claim.scope: must be one of application, module, page');
    raw['scope'] = 'module';
    expect(problem(), '$claim.writes: must be an array');
    raw['writes'] = <Object?>[1];
    expect(problem(), '$claim.writes[0]: must be an object');
    raw['writes'] = <Object?>[topicDoc(), <String, Object?>{}];
    expect(problem(), '$claim.writes[1].name: is missing');
    raw['x'] = 1;
    raw['writes'] = <Object?>[topicDoc()];
    expect(problem(), '$claim: must not have the key "x"');
    raw
      ..remove('x')
      ..remove('writes');
    expect(problem(), '$claim.writes: is missing');
    expect(rejection(claimsDoc(<Object?>[null])), '$claim: must be an object');
  });

  test('G21 a definition object is no graph document, a graph document is no '
      'definition object, and a Set, an Iterable, a String or a number is '
      'no array', () {
    expect(
      rejection(encodeTopologyGraph(TopologyGraph()), decodeTopologyDefinition),
      r'$.topologyId: is missing',
    );
    expect(
      rejection(encodeTopologyDefinition(generatedDefinition(Random(1), 't0'))),
      r'$.format: is missing',
    );
    final Object? forms = fixtureJson('valid/forms.json');
    final Iterable<Object?> iterable = <Object?>[].map((Object? e) => e);
    for (final (String key, Object? value) in <(String, Object?)>[
      ('reads', <Object?>{}),
      ('reads', iterable),
      ('writes', 'abc'),
      ('transforms', 5),
      ('transforms', <Object?, Object?>{}),
    ]) {
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            topologyOf(d)[key] = value;
          }),
        ),
        '\$.topologies[0].$key: must be an array',
        reason: key,
      );
    }
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          topologyOf(d)['reads'] = <Object?>[
            <Object?, Object?>{...topicDoc(), 5: 1},
          ];
        }),
      ),
      r'$.topologies[0].reads[0]: must be an object',
    );
  });

  test('G20 the decoder accepts the keys of every object of a generated '
      'document in any order', () {
    int reordered = 0;
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      final Map<String, Object?> doc = encodeTopologyGraph(g);
      final Object? shuffledDoc = withShuffledKeys(doc, Random(seed));
      if (jsonEncode(shuffledDoc) != jsonEncode(doc)) {
        reordered++;
      }
      expect(decodeTopologyGraph(shuffledDoc), g, reason: 'seed $seed');
      for (final TopologyDefinition d in g.topologies) {
        expect(
          decodeTopologyDefinition(
            withShuffledKeys(encodeTopologyDefinition(d), Random(seed)),
          ),
          d,
          reason: 'seed $seed, ${d.topologyId}',
        );
      }
    }
    expect(reordered, greaterThanOrEqualTo(seeds ~/ 2));
  });

  test('G20 the decoder reads a generated document whose objects are '
      'unmodifiable Map<Object?, Object?> and whose arrays are unmodifiable '
      'lists', () {
    for (int seed = 0; seed < seeds; seed++) {
      final TopologyGraph g = generatedGraph(seed);
      expect(
        decodeTopologyGraph(withForeignCollections(encodeTopologyGraph(g))),
        g,
        reason: 'seed $seed',
      );
      for (final TopologyDefinition d in g.topologies) {
        expect(
          decodeTopologyDefinition(
            withForeignCollections(encodeTopologyDefinition(d)),
          ),
          d,
          reason: 'seed $seed, ${d.topologyId}',
        );
      }
    }
  });
}
