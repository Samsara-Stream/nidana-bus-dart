// topology-ir@v1's decoder on everything that is not a graph document or
// breaks a decoder rule (The JSON form; G21), beyond the G21 cases of the
// conformance suite, which stop at the first file that fails: each invalid/
// file rejected for its own reason, the rules the schema cannot state, the
// values the IR's constructors accept and the schema does not, repeats that a
// Set or the graph would collapse, Dart values that are no JSON value, and
// generated values that either decode or are rejected with a FormatException
// and nothing else.
import 'dart:convert';
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/json_support.dart';

/// What the decoder says about each file under invalid/: the JSONPath of
/// the place that breaks a rule, then the rule.
final Map<String, String> invalidMessages = <String, String>{
  'claim_event_topic':
      r'$.claims[0]: writes: names a topic that is not a state topic',
  'claim_scope_missing': r'$.claims[0].scope: is missing',
  'claim_topology_source': r'$.claims[0].source: must be "service:", "page:" or "executor:" followed by a name',
  'claim_unknown_source': r'$.claims[0].source: must be "service:", "page:" or "executor:" followed by a name',
  'claim_without_writes': r'$.claims[0]: writes: must not be empty',
  'claims_missing': r'$.claims: is missing',
  'combinator_unknown': r'$.topologies[0].transforms[0].combinator: must be one of map, filter, combine, withLatestFrom, merge, switchMap, scan, pairwise, distinctUntilChanged, debounce, throttle, delay, sample, buffer, timeout, catchError, rawEngine, reduceInto',
  'dedup_on_event_read': r'$.topologies[0].transforms[2].inputs[1].dedup: may be given only on a read of a state topic',
  'dedup_unknown': r'$.topologies[0].transforms[1].inputs[1].dedup: must be one of equality, none',
  'duration_fractional': r'$.topologies[0].transforms[3].durationMicros: must be a non-negative integer',
  'duration_negative': r'$.topologies[0].transforms[3].durationMicros: must be a non-negative integer',
  'format_missing': r'$.format: is missing',
  'format_v2': r'$.format: must be "topology-ir@v1"',
  'function_ref_empty_name': r'$.topologies[0].transforms[0].transformer.name: must be a non-empty string or null',
  'function_ref_missing_name':
      r'$.topologies[0].transforms[0].transformer.name: is missing',
  'input_edge_negative': r'$.topologies[0].transforms[3].inputs[0].edge: must be a non-negative integer',
  'input_topic_and_edge':
      r'$.topologies[0].transforms[0].inputs[0]: must not have the key "topic"',
  'map_with_two_inputs': r'$.topologies[0].transforms[0]: inputs: a map edge takes exactly 1 input',
  'map_without_transformer':
      r'$.topologies[0].transforms[0]: transformer: a map edge needs one',
  'merge_with_transformer':
      r'$.topologies[0].transforms[2]: transformer: a merge edge holds none',
  'merge_without_inputs': r'$.topologies[0].transforms[2]: inputs: a merge edge takes at least 1 input',
  'reads_repeat_topic':
      r'$.topologies[0].reads[2]: repeats $.topologies[0].reads[0]',
  'reduce_into_event_output': r'$.topologies[0].transforms[5]: topic: is not a state topic, and a reduceInto writes one',
  'reduce_into_without_transformer':
      r'$.topologies[0].transforms[5].transformer: is missing',
  'retry_on_map':
      r'$.topologies[0].transforms[0]: retry: a map edge holds none',
  'scope_unknown':
      r'$.topologies[0].scope: must be one of application, module, page',
  'stage_with_output':
      r'$.topologies[0].transforms[0]: must not have the key "output"',
  'time_stage_without_duration':
      r'$.topologies[0].transforms[3]: duration: a debounce edge needs one',
  'topic_ref_extra_key':
      r'$.topologies[0].reads[0]: must not have the key "sensitive"',
  'topic_ref_without_type_name':
      r'$.topologies[0].reads[0].typeName: is missing',
  'topic_variant_unknown':
      r'$.topologies[0].reads[0].variant: must be one of state, event, replay',
  'topologies_repeat':
      r'$.topologies[1].topologyId: repeats the id of $.topologies[0]',
  'topology_id_empty': r'$.topologies[0]: topologyId: must not be empty',
  'unknown_top_level_key': r'$: must not have the key "generatedAt"',
  'with_latest_from_five_inputs': r'$.topologies[0].transforms[1]: inputs: a withLatestFrom edge takes 2 to 4 inputs',
  'with_latest_from_one_input': r'$.topologies[0].transforms[1]: inputs: a withLatestFrom edge takes 2 to 4 inputs',
  'write_with_transformer':
      r'$.topologies[0].transforms[4]: must not have the key "transformer"',
  'write_without_output': r'$.topologies[0].transforms[4].output: is missing',
};

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

Map<String, Object?> topologyOf(Map<String, Object?> doc) =>
    (doc['topologies']! as List<Object?>)[0]! as Map<String, Object?>;

Map<String, Object?> edgeOf(Map<String, Object?> doc, int e) =>
    (topologyOf(doc)['transforms']! as List<Object?>)[e]!
        as Map<String, Object?>;

Map<String, Object?> inputOf(Map<String, Object?> doc, int e, int i) =>
    (edgeOf(doc, e)['inputs']! as List<Object?>)[i]! as Map<String, Object?>;

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

/// What decoding [value] gives: a graph, a FormatException, or the other
/// error it threw.
Object decodeOutcome(Object? value, Object Function(Object?) decode) {
  try {
    return decode(value);
  } on Object catch (error) {
    return error;
  }
}

/// The values a mutation writes, scalars of every JSON type and the names
/// the document form uses.
const List<Object?> scalars = <Object?>[
  null, true, -1, 0, 1, 2, 1.5, 2.0, 1e30, '', 'state', 'event', 'replay', //
  'none', 'equality', 'map', 'merge', 'reduceInto', 'service:x', //
  'topology:x', 'page', 'topology-ir@v1',
];

/// The keys a mutation adds, the document form's and one it does not know.
const List<String> keys = <String>[
  'format', 'topologies', 'claims', 'topologyId', 'scope', 'reads', //
  'writes', 'transforms', 'combinator', 'inputs', 'output', 'transformer', //
  'durationMicros', 'retry', 'topic', 'dedup', 'edge', 'name', 'variant', //
  'typeName', 'source', 'x',
];

/// Every object and array of [value], [value] itself first.
List<Object> containersOf(Object? value) => <Object>[
  if (value is Map<String, Object?>) ...<Object>[
    value,
    for (final Object? child in value.values) ...containersOf(child),
  ] else if (value is List<Object?>) ...<Object>[
    value,
    for (final Object? child in value) ...containersOf(child),
  ],
];

/// A value to write: a scalar, an empty container, or a copy of a container
/// of [doc].
Object? replacement(Random random, Object? doc) => switch (random.nextInt(4)) {
  0 => <Object?>[],
  1 => <String, Object?>{},
  2 => jsonDecode(
    jsonEncode(containersOf(doc)[random.nextInt(containersOf(doc).length)]),
  ),
  _ => scalars[random.nextInt(scalars.length)],
};

/// [doc], a JSON value it owns, changed in place by one mutation [random]
/// draws at one of its objects or arrays: a key removed, added or given
/// another value; an element removed, repeated, swapped or replaced.
void mutate(Random random, Object? doc) {
  final List<Object> containers = containersOf(doc);
  final Object target = containers[random.nextInt(containers.length)];
  if (target is Map<String, Object?>) {
    final List<String> present = target.keys.toList();
    switch (random.nextInt(3)) {
      case 0 when present.isNotEmpty:
        target.remove(present[random.nextInt(present.length)]);
      case 1 when present.isNotEmpty:
        target[present[random.nextInt(present.length)]] = replacement(
          random,
          doc,
        );
      default:
        target[keys[random.nextInt(keys.length)]] = replacement(random, doc);
    }
  } else if (target is List<Object?>) {
    switch (random.nextInt(4)) {
      case 0 when target.isNotEmpty:
        target.removeAt(random.nextInt(target.length));
      case 1 when target.isNotEmpty:
        target.add(
          jsonDecode(jsonEncode(target[random.nextInt(target.length)])),
        );
      case 2 when target.length > 1:
        final int i = random.nextInt(target.length);
        final int j = random.nextInt(target.length);
        final Object? t = target[i];
        target[i] = target[j];
        target[j] = t;
      default:
        target.add(replacement(random, doc));
    }
  }
}

/// A JSON value of up to [depth] levels, keyed and filled from the pools.
Object? arbitrary(Random random, int depth) =>
    switch (depth == 0 ? 0 : random.nextInt(3)) {
      0 => scalars[random.nextInt(scalars.length)],
      1 => <Object?>[
        for (int i = 0, n = random.nextInt(3); i < n; i++)
          arbitrary(random, depth - 1),
      ],
      _ => <String, Object?>{
        for (int i = 0, n = random.nextInt(4); i < n; i++)
          keys[random.nextInt(keys.length)]: arbitrary(random, depth - 1),
      },
    };

void main() {
  test(
    'G21 invalid/ holds exactly the files whose messages this test pins',
    () {
      expect(fixtureNames('invalid'), invalidMessages.keys.toList()..sort());
    },
  );

  for (final MapEntry<String, String> file in invalidMessages.entries) {
    test('G21 invalid/${file.key}.json is rejected with a FormatException at '
        'the place it breaks a rule', () {
      expect(rejection(fixtureJson('invalid/${file.key}.json')), file.value);
    });
  }

  test('G21 a schema-valid document that breaks a rule the schema cannot '
      'state is rejected at the definition that breaks it', () {
    final Object? forms = fixtureJson('valid/forms.json');
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          (topologyOf(d)['reads']! as List<Object?>).add(<String, Object?>{
            'name': 'forms.extra',
            'variant': 'event',
            'typeName': 'int',
          });
        }),
      ),
      r'$.topologies[0].reads: must list each topic the edges read, once',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          (topologyOf(d)['writes']! as List<Object?>).removeAt(0);
        }),
      ),
      r'$.topologies[0].writes: must list each topic the sink edges write, once',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          inputOf(d, 1, 0)['edge'] = 1;
        }),
      ),
      r'$.topologies[0]: transforms: edge 1 takes the output of edge 1, which '
      'is not an earlier edge',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          inputOf(d, 2, 0)['edge'] = 99;
        }),
      ),
      r'$.topologies[0]: transforms: edge 2 takes the output of edge 99, which '
      'is not an earlier edge',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          edgeOf(d, 4)['output'] = edgeOf(d, 5)['output'];
          (topologyOf(d)['writes']! as List<Object?>).removeAt(0);
        }),
      ),
      startsWith(
        r'$.topologies[0]: transforms: edge 5 is a second sink edge on this '
        'state topic',
      ),
    );
  });

  test('G21 an edge index below zero is rejected before StageInput would '
      'assert it', () {
    expect(
      rejection(
        edited(fixtureJson('valid/forms.json'), (Map<String, Object?> d) {
          inputOf(d, 3, 0)['edge'] = -5;
        }),
      ),
      r'$.topologies[0].transforms[3].inputs[0].edge: must be a non-negative '
      'integer',
    );
    expect(
      rejection(
        topologyOf(
          edited(fixtureJson('valid/forms.json'), (Map<String, Object?> d) {
            inputOf(d, 3, 0)['edge'] = -1.0;
          }),
        ),
        decodeTopologyDefinition,
      ),
      r'$.transforms[3].inputs[0].edge: must be a non-negative integer',
    );
  });

  test('G21 a dedup on an event or a replay read and an empty typeName are '
      'rejected, although TopicInput and TopicRef accept them', () {
    const TopicRef blank = TopicRef(
      name: 'n',
      variant: TopicVariant.replay,
      typeName: '',
    );
    expect(const TopicInput(blank, dedup: Dedup.none).dedup, Dedup.none);
    final Object? forms = fixtureJson('valid/forms.json');
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final Map<String, Object?> input = inputOf(d, 0, 0);
          (input['topic']! as Map<String, Object?>)['variant'] = 'replay';
          input['dedup'] = 'equality';
        }),
      ),
      r'$.topologies[0].transforms[0].inputs[0].dedup: may be given only on a '
      'read of a state topic',
    );
    for (final (String place, void Function(Map<String, Object?>) blankIt)
        in <(String, void Function(Map<String, Object?>))>[
          (
            r'$.topologies[0].reads[1].typeName',
            (Map<String, Object?> d) =>
                ((topologyOf(d)['reads']! as List<Object?>)[1]!
                        as Map<String, Object?>)['typeName'] =
                    '',
          ),
          (
            r'$.topologies[0].transforms[0].inputs[0].topic.typeName',
            (Map<String, Object?> d) =>
                (inputOf(d, 0, 0)['topic']!
                        as Map<String, Object?>)['typeName'] =
                    '',
          ),
          (
            r'$.topologies[0].transforms[4].output.typeName',
            (Map<String, Object?> d) =>
                (edgeOf(d, 4)['output']! as Map<String, Object?>)['typeName'] =
                    '',
          ),
          (
            r'$.claims[0].writes[0].typeName',
            (Map<String, Object?> d) =>
                ((claimOf(d)['writes']! as List<Object?>)[0]!
                        as Map<String, Object?>)['typeName'] =
                    '',
          ),
        ]) {
      expect(
        rejection(edited(forms, blankIt)),
        '$place: must not be empty',
        reason: place,
      );
    }
  });

  test('G21 a repeated topic in reads, writes or a claim, and a repeated '
      'topology id, are rejected before a Set or the graph collapses them', () {
    final Object? forms = fixtureJson('valid/forms.json');
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> writes =
              topologyOf(d)['writes']! as List<Object?>;
          writes.add(writes.first);
        }),
      ),
      r'$.topologies[0].writes[2]: repeats $.topologies[0].writes[0]',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> writes = claimOf(d)['writes']! as List<Object?>;
          writes.add(writes.first);
        }),
      ),
      r'$.claims[0].writes[1]: repeats $.claims[0].writes[0]',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> topologies = d['topologies']! as List<Object?>;
          topologies.add(<String, Object?>{
            ...topologyOf(d),
            'scope': 'module',
          });
        }),
      ),
      r'$.topologies[1].topologyId: repeats the id of $.topologies[0]',
    );
  });

  test('G21 a Dart value that is no JSON value of the form is rejected with a '
      'FormatException, one that contains itself included', () {
    final Object? forms = fixtureJson('valid/forms.json');
    final List<Object?> loop = <Object?>[];
    loop.add(loop);
    final Map<String, Object?> self = <String, Object?>{};
    self['topologyId'] = self;
    expect(
      rejection(<String, Object?>{
        'format': 'topology-ir@v1',
        'topologies': loop,
        'claims': <Object?>[],
      }),
      r'$.topologies[0]: must be an object',
    );
    expect(
      rejection(<String, Object?>{
        'format': 'topology-ir@v1',
        'topologies': <Object?>[self],
        'claims': <Object?>[],
      }),
      r'$.topologies[0].scope: is missing',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          d['topologies'] = <Object?>{};
        }),
      ),
      r'$.topologies: must be an array',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          d['format'] = DateTime.utc(2026);
        }),
      ),
      r'$.format: must be "topology-ir@v1"',
    );
    for (final Object? micros in <Object?>[
      double.nan,
      double.infinity,
      1e30,
      -0.5,
      '5',
    ]) {
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            edgeOf(d, 3)['durationMicros'] = micros;
          }),
        ),
        r'$.topologies[0].transforms[3].durationMicros: must be a non-negative '
        'integer',
        reason: '$micros',
      );
    }
  });

  test(
    'G21 a mutated graph document, or definition object, decodes and then '
    'round-trips, or is rejected with a FormatException, and nothing else',
    () {
      int decoded = 0;
      int rejected = 0;
      for (int seed = 0; seed < seeds; seed++) {
        final Random random = Random(seed);
        final TopologyGraph g = generatedGraph(seed);
        final Object? doc = jsonDecode(jsonEncode(encodeTopologyGraph(g)));
        for (int i = 0, n = 1 + random.nextInt(3); i < n; i++) {
          mutate(random, doc);
        }
        final Object outcome = decodeOutcome(doc, decodeTopologyGraph);
        expect(
          outcome,
          anyOf(isA<TopologyGraph>(), isA<FormatException>()),
          reason: 'seed $seed',
        );
        if (outcome is TopologyGraph) {
          decoded++;
          expect(
            decodeTopologyGraph(encodeTopologyGraph(outcome)),
            outcome,
            reason: 'seed $seed',
          );
        } else {
          rejected++;
        }
        for (final TopologyDefinition d in g.topologies) {
          final Object? object = jsonDecode(
            jsonEncode(encodeTopologyDefinition(d)),
          );
          mutate(random, object);
          expect(
            decodeOutcome(object, decodeTopologyDefinition),
            anyOf(isA<TopologyDefinition>(), isA<FormatException>()),
            reason: 'seed $seed, ${d.topologyId}',
          );
        }
      }
      // Floors near half of what the 500 seeds reach (json-form-plan F4: 19
      // documents decode and 481 are rejected), so that a generator change
      // cannot make either half of the property vacuous.
      expect(decoded, greaterThanOrEqualTo(10));
      expect(rejected, greaterThanOrEqualTo(240));
    },
  );

  test('G21 an arbitrary JSON value of up to four levels, keyed and filled '
      'with the names of the form, is rejected with a FormatException', () {
    for (int seed = 0; seed < seeds; seed++) {
      final Object? value = arbitrary(Random(seed), 4);
      expect(
        decodeOutcome(value, decodeTopologyGraph),
        isA<FormatException>(),
        reason: 'seed $seed',
      );
      expect(
        decodeOutcome(value, decodeTopologyDefinition),
        isA<FormatException>(),
        reason: 'seed $seed',
      );
    }
  });

  test('G21 a topology listed twice is rejected at its id although the two '
      'are equal, after every topology is read and before the claims', () {
    final Object? forms = fixtureJson('valid/forms.json');
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> topologies = d['topologies']! as List<Object?>;
          topologies.add(jsonDecode(jsonEncode(topologies.first)));
        }),
      ),
      r'$.topologies[1].topologyId: repeats the id of $.topologies[0]',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> topologies = d['topologies']! as List<Object?>;
          topologies.add(jsonDecode(jsonEncode(topologies.first)));
          topologies.add(<String, Object?>{});
        }),
      ),
      r'$.topologies[2].topologyId: is missing',
    );
    expect(
      rejection(
        edited(forms, (Map<String, Object?> d) {
          final List<Object?> topologies = d['topologies']! as List<Object?>;
          topologies.add(jsonDecode(jsonEncode(topologies.first)));
          d['claims'] = <Object?>[1];
        }),
      ),
      r'$.topologies[1].topologyId: repeats the id of $.topologies[0]',
    );
  });

  test('G21 reads and writes that are not the topics the edges read and the '
      'sink edges write are rejected whether longer, shorter or as long', () {
    final Object? forms = fixtureJson('valid/forms.json');
    Map<String, Object?> definition(void Function(Map<String, Object?>) edit) =>
        edited(topologyOf(edited(forms, (Map<String, Object?> d) {})), edit);
    final Map<String, Object?> other = <String, Object?>{
      'name': 'forms.other',
      'variant': 'state',
      'typeName': 'int',
    };
    for (final (String key, void Function(List<Object?>) edit)
        in <(String, void Function(List<Object?>))>[
          ('reads', (List<Object?> topics) => topics.removeAt(0)),
          ('reads', (List<Object?> topics) => topics[1] = other),
          ('reads', (List<Object?> topics) => topics.add(other)),
          ('writes', (List<Object?> topics) => topics.removeLast()),
          ('writes', (List<Object?> topics) => topics[0] = other),
          ('writes', (List<Object?> topics) => topics.add(other)),
        ]) {
      expect(
        rejection(
          definition((Map<String, Object?> d) {
            edit(d[key]! as List<Object?>);
          }),
          decodeTopologyDefinition,
        ),
        key == 'reads'
            ? r'$.reads: must list each topic the edges read, once'
            : r'$.writes: must list each topic the sink edges write, once',
        reason: key,
      );
    }
  });

  test('G21 a topic repeats an earlier one only when name, variant and '
      'typeName are all equal', () {
    final Object? forms = fixtureJson('valid/forms.json');
    Map<String, Object?> definition(void Function(List<Object?>) edit) =>
        edited(topologyOf(edited(forms, (Map<String, Object?> d) {})), (
          Map<String, Object?> d,
        ) {
          edit(d['reads']! as List<Object?>);
        });
    expect(
      rejection(
        definition((List<Object?> reads) => reads.add(reads.first)),
        decodeTopologyDefinition,
      ),
      r'$.reads[2]: repeats $.reads[0]',
    );
    for (final (String key, String value) in <(String, String)>[
      ('variant', 'state'),
      ('typeName', 'String'),
    ]) {
      expect(
        rejection(
          definition(
            (List<Object?> reads) => reads.add(<String, Object?>{
              ...reads.first! as Map<String, Object?>,
              key: value,
            }),
          ),
          decodeTopologyDefinition,
        ),
        r'$.reads: must list each topic the edges read, once',
        reason: key,
      );
    }
  });

  test('G21 a function name must be a non-empty string or null, in a '
      'reducer as in a transformer', () {
    final Object? forms = fixtureJson('valid/forms.json');
    for (final Object? name in <Object?>['', 3, true, <Object?>[]]) {
      expect(
        rejection(
          edited(forms, (Map<String, Object?> d) {
            (edgeOf(d, 5)['transformer']! as Map<String, Object?>)['name'] =
                name;
          }),
        ),
        r'$.topologies[0].transforms[5].transformer.name: must be a '
        'non-empty string or null',
        reason: '$name',
      );
    }
    final TopologyGraph anonymous = decodeTopologyGraph(
      edited(forms, (Map<String, Object?> d) {
        (edgeOf(d, 5)['transformer']! as Map<String, Object?>)['name'] = null;
      }),
    );
    expect(
      anonymous.topologies.single.transforms[5].transformer,
      const FunctionRef.anonymous(),
    );
  });

  test('G21 a dedup is read before the variant of its read decides whether '
      'one may be given', () {
    expect(
      rejection(
        edited(fixtureJson('valid/forms.json'), (Map<String, Object?> d) {
          inputOf(d, 2, 1)['dedup'] = 'sometimes';
        }),
      ),
      r'$.topologies[0].transforms[2].inputs[1].dedup: must be one of '
      'equality, none',
    );
  });

  test('G21 a negative zero is the integer zero, no negative number', () {
    final Object? forms = fixtureJson('valid/forms.json');
    for (final Object? zero in <Object?>[
      -0.0,
      jsonDecode('-0'),
      jsonDecode('-0.0'),
    ]) {
      expect(
        decodeTopologyGraph(
          edited(forms, (Map<String, Object?> d) {
            edgeOf(d, 3)['durationMicros'] = zero;
          }),
        ).topologies.single.transforms[3].duration,
        Duration.zero,
        reason: '$zero',
      );
    }
  });
}
