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
}
