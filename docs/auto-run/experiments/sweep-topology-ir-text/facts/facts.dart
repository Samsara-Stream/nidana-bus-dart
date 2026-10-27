// Runtime facts behind S153, the end-of-nidana.model governance sweep of
// topology-ir@v1 (text, Interface, schema, invalid/ and surface), read off the
// shipped package (packages/nidana_dart_contracts) rather than a stand-in.
// run.sh runs it from the repository root, so the workspace's package
// configuration resolves the package imports, package:json_schema included
// (nidana_contract_check's schema set validates with it).
//
//   E: FunctionRef.of over the extension and extension-type forms (S134, the
//      G9 derivation table).
//   P: two state topics of one name whose value types render alike (S132,
//      the closing sentence of "From a plan").
//   R: graphs built by hand whose encoding the decoder rejects, and the plan
//      side of the same values (S135, G20).
//   I: integers in the JSON form: whole-number doubles, the bound of 2^63,
//      and what a schema `maximum` or `exclusiveMaximum` would decide
//      (S146, S147).
//   W: the three would-be invalid/ documents (S146): the schema's verdict and
//      the decoder's FormatException.
//   O: the order of scope violations by owner (S143, S144, line 436).
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';

import 'elsewhere.dart' as elsewhere;

final class Cart {
  const Cart();
}

extension Ext on int {
  int triple() => this * 3;
  static int helper(int v) => v + 1;
}

extension type ET(int value) {
  ET.named(int v) : value = v * 10;
  int plus(int v) => value + v;
  static int make(int v) => v - 1;
}

const String schemaPath = 'hsdd/contract/schema/topology-ir.schema.json';

String attempt(Object? Function() body) {
  try {
    return 'returns ${body()}';
  } on FormatException catch (e) {
    return 'throws FormatException: ${e.message}';
  } on ArgumentError catch (e) {
    return 'throws ArgumentError(${e.name}): ${e.message}';
  } on Object catch (e) {
    return 'throws ${e.runtimeType}';
  }
}

Map<String, Object?> schemaMap() =>
    jsonDecode(File(schemaPath).readAsStringSync()) as Map<String, Object?>;

String verdict(JsonSchema schema, Object? doc) {
  final ValidationResults r = schema.validate(doc);
  return r.isValid ? 'valid' : 'invalid (${r.errors.length} errors)';
}

Object? copy(Object? json) => jsonDecode(jsonEncode(json));

Map<String, Object?> forms() =>
    jsonDecode(
          File(
            'hsdd/contract/fixture/topology-ir/valid/forms.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;

Map<String, Object?> debounceOf(Map<String, Object?> doc) =>
    (((doc['topologies']! as List<Object?>)[0]!
                as Map<String, Object?>)['transforms']!
            as List<Object?>)[3]!
        as Map<String, Object?>;

void main() {
  bool assertions = false;
  assert(assertions = true);
  print('assertions enabled: $assertions (dart run enables none)');
  print('');
  print('### E FunctionRef.of over extension forms (the package, JIT)');
  int Function() instance = 4.triple;
  final ET et = ET(7);
  int Function(int) typeInstance = et.plus;
  for (final (String label, Function f) in <(String, Function)>[
    ('named extension, instance method 4.triple', instance),
    ('named extension, static method Ext.helper', Ext.helper),
    ('extension type, constructor ET.new', ET.new),
    ('extension type, named constructor ET.named', ET.named),
    ('extension type, instance method et.plus', typeInstance),
    ('extension type, static method ET.make', ET.make),
  ]) {
    print('$label: ${FunctionRef.of(f).name ?? '(anonymous)'}');
  }

  print('');
  print('### P two state topics of one name whose value types render alike');
  const EventTopic<int> taps = EventTopic<int>(name: 'shop.taps');
  const StateTopic<Cart> mine = StateTopic<Cart>(
    name: 'shop.cart',
    initial: Cart(),
  );
  const StateTopic<elsewhere.Cart> theirs = StateTopic<elsewhere.Cart>(
    name: 'shop.cart',
    initial: elsewhere.Cart(),
  );
  print('Topic equality: ${mine == theirs}; refs equal: '
      '${mine.ref == theirs.ref} (typeName ${mine.ref.typeName} and '
      '${theirs.ref.typeName})');
  final Topology alike = topology('alike', Scope.page, (TopologyBuilder b) {
    b.write(mine, b.read(taps).map((int v) => const Cart()));
    b.write(theirs, b.read(taps).map((int v) => const elsewhere.Cart()));
  });
  print('planOf: ${attempt(() => '${planOf(alike).sinks.length} sinks')}');
  print('plan.definition: ${attempt(() => planOf(alike).definition)}');
  print('buildDefinition(): ${attempt(alike.buildDefinition)}');
  final List<TopicNameCollision> collisions = findTopicNameCollisions(
    <TopicDeclaration>[
      TopicDeclaration(topic: mine.ref, site: 'lib/mine.dart:1'),
      TopicDeclaration(topic: theirs.ref, site: 'lib/theirs.dart:1'),
    ],
  );
  print('findTopicNameCollisions over their declarations: '
      '${collisions.length} collision, ${collisions.single.name}, '
      '${collisions.single.declarations.length} declarations');

  print('');
  print('### R graphs built by hand whose encoding the decoder rejects');
  const TopicRef event = TopicRef(
    name: 'r.in',
    variant: TopicVariant.event,
    typeName: 'int',
  );
  const TopicRef replay = TopicRef(
    name: 'r.log',
    variant: TopicVariant.replay,
    typeName: 'int',
  );
  const TopicRef blank = TopicRef(
    name: 'r.blank',
    variant: TopicVariant.event,
    typeName: '',
  );
  const TopicRef out = TopicRef(
    name: 'r.out',
    variant: TopicVariant.event,
    typeName: 'int',
  );
  const TopicRef claimedBlank = TopicRef(
    name: 'r.claimed',
    variant: TopicVariant.state,
    typeName: '',
  );
  TopologyGraph writing(TopicInput input) => TopologyGraph(
    topologies: <TopologyDefinition>[
      TopologyDefinition(
        topologyId: 'r',
        scope: Scope.page,
        transforms: <TransformEdge>[TransformEdge.write(out, input)],
      ),
    ],
  );
  for (final (String label, TopologyGraph graph) in <(String, TopologyGraph)>[
    (
      'a dedup on an event read',
      writing(const TopicInput(event, dedup: Dedup.none)),
    ),
    (
      'a dedup on a replay read',
      writing(const TopicInput(replay, dedup: Dedup.equality)),
    ),
    ('a read with an empty typeName', writing(const TopicInput(blank))),
    (
      'a claim with an empty typeName',
      TopologyGraph(
        claims: <ShellClaim>[
          ShellClaim(
            source: const ServiceSource('r'),
            writes: <TopicRef>{claimedBlank},
          ),
        ],
      ),
    ),
    (
      'a claim whose source has an empty name (no assertions)',
      TopologyGraph(
        claims: <ShellClaim>[
          ShellClaim(
            // ignore: prefer_const_constructors
            source: ServiceSource(''),
            writes: <TopicRef>{
              const TopicRef(
                name: 'r.claimed',
                variant: TopicVariant.state,
                typeName: 'int',
              ),
            },
          ),
        ],
      ),
    ),
  ]) {
    print('$label: built; decode(encode): '
        '${attempt(() => decodeTopologyGraph(encodeTopologyGraph(graph)))}');
  }
  const EventTopic<int> inTopic = EventTopic<int>(name: 'r.in');
  const ReplayTopic<int> logTopic = ReplayTopic<int>(
    name: 'r.log',
    bufferSize: 4,
  );
  const EventTopic<int> outTopic = EventTopic<int>(name: 'r.out');
  for (final (String label, Topic<int> topic) in <(String, Topic<int>)>[
    ('event', inTopic),
    ('replay', logTopic),
  ]) {
    print('plan side, read of an $label topic with a dedup: '
        '${attempt(() => planOf(topology('p', Scope.page, (TopologyBuilder b) {
              b.write(outTopic, b.read(topic, dedup: Dedup.none));
            })))}');
  }
  print("plan side, a Topic's typeName is '\$T': "
      "${<String>[inTopic.ref.typeName, const StateTopic<()>(name: 'r.unit', initial: ()).ref.typeName, const EventTopic<Object?>(name: 'r.any').ref.typeName].join(', ')}");

  print('');
  print('### I integers in the JSON form');
  final JsonSchema committed = JsonSchema.create(schemaMap());
  for (final String text in <String>[
    '5000',
    '5000.0',
    '5e3',
    '9223372036854775807',
    '9223372036854775808',
    '1e30',
  ]) {
    final Object? value = jsonDecode(text);
    final Map<String, Object?> doc = forms();
    debounceOf(doc)['durationMicros'] = value;
    final String decoded = attempt(() {
      final TopologyGraph g = decodeTopologyGraph(doc);
      return 'duration ${g.topologies.single.transforms[3].duration!.inMicroseconds}us';
    });
    print('durationMicros $text (jsonDecode gives ${value.runtimeType} '
        '$value): schema ${verdict(committed, doc)}; decoder $decoded');
  }
  print('Duration(microseconds: 9223372036854775807).inMicroseconds: '
      '${const Duration(microseconds: 9223372036854775807).inMicroseconds}');
  // What a schema bound would decide. The schema is JSON text, so its bound
  // is read through jsonDecode as the document is: 2^63 - 1 is an int,
  // 2^63 a double.
  for (final (String keyword, String bound) in <(String, String)>[
    ('maximum', '9223372036854775807'),
    ('exclusiveMaximum', '9223372036854775808'),
  ]) {
    final Map<String, Object?> variant = schemaMap();
    final Map<String, Object?> timeStage =
        ((variant[r'$defs']! as Map<String, Object?>)['timeStage']!
            as Map<String, Object?>);
    ((timeStage['properties']! as Map<String, Object?>)['durationMicros']!
            as Map<String, Object?>)[keyword] =
        jsonDecode(bound);
    final JsonSchema bounded = JsonSchema.create(variant);
    final List<String> verdicts = <String>[
      for (final String text in <String>[
        '9223372036854775807',
        '9223372036854775808',
        '1e30',
      ])
        '$text ${verdict(bounded, () {
          final Map<String, Object?> doc = forms();
          debounceOf(doc)['durationMicros'] = jsonDecode(text);
          return doc;
        }())}',
    ];
    print('with durationMicros $keyword $bound: ${verdicts.join('; ')}');
  }

  print('');
  print('### W the would-be invalid/ documents');
  for (final FileSystemEntity f
      in Directory(
          'docs/auto-run/experiments/sweep-topology-ir-text/would-be-invalid',
        ).listSync().toList()
        ..sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path))) {
    if (f is! File || !f.path.endsWith('.json')) {
      continue;
    }
    final Object? doc = jsonDecode(f.readAsStringSync());
    final ValidationResults r = committed.validate(doc);
    print('${f.uri.pathSegments.last}: schema '
        '${r.isValid ? 'valid' : 'invalid: ${r.errors.map((ValidationError e) => e.instancePath).toSet().join(', ')}'}; '
        'decoder ${attempt(() => decodeTopologyGraph(doc))}');
  }

  print('');
  print('### O scope violations by owner');
  const TopicRef t = TopicRef(
    name: 'o.t',
    variant: TopicVariant.state,
    typeName: 'int',
  );
  const TopicRef sink = TopicRef(
    name: 'o.sink',
    variant: TopicVariant.event,
    typeName: 'int',
  );
  final TopologyGraph g = TopologyGraph(
    topologies: <TopologyDefinition>[
      TopologyDefinition(
        topologyId: 'a',
        scope: Scope.page,
        transforms: <TransformEdge>[
          TransformEdge.write(t, const TopicInput(sink)),
        ],
      ),
      TopologyDefinition(
        topologyId: 'reader',
        scope: Scope.application,
        transforms: <TransformEdge>[
          TransformEdge.write(sink, const TopicInput(t)),
        ],
      ),
    ],
    claims: <ShellClaim>[
      ShellClaim(
        source: const ServiceSource('s'),
        scope: Scope.page,
        writes: <TopicRef>{t},
      ),
      ShellClaim(
        source: const ServiceSource('s'),
        scope: Scope.module,
        writes: <TopicRef>{t},
      ),
      ShellClaim(
        source: const PageSource('p'),
        scope: Scope.page,
        writes: <TopicRef>{t},
      ),
      ShellClaim(
        source: const PageSource('p'),
        scope: Scope.page,
        writes: <TopicRef>{t},
      ),
    ],
  );
  print('graph order of owners: topologies '
      '${g.topologies.where((TopologyDefinition d) => d.writes.contains(t)).map((TopologyDefinition d) => 'topology:${d.topologyId}/${d.scope.name}').join(', ')}, '
      'then claims ${g.claims.map((ShellClaim c) => '${c.source}/${c.scope.name}').join(', ')}');
  print('findScopeViolations: ${findScopeViolations(g).map((ScopeViolation v) => '${v.owner}/${v.ownerScope.name}->${v.readerId}').join(', ')}');
}
