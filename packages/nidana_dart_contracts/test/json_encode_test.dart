// topology-ir@v1's encoder and JsonRenderer (The JSON form; G19, and G22's
// JSON rendering), beyond the G19 cases of the conformance suite, which
// compare maps without their key order: the order of every key, which keys an
// edge and an input carry, durations, function references, claims, and the
// text JsonRenderer writes.
import 'dart:convert';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:test/test.dart';

import 'src/json_support.dart';

Never called(String what) => throw StateError('the encoder called $what');

int inc(int v) => called('inc');
int add(int a, int b) => called('add');
int reduceCount(int state, int event) => called('reduceCount');

const StateTopic<int> formsState = StateTopic<int>(
  name: 'forms.state',
  initial: 0,
);
const EventTopic<int> formsEvent = EventTopic<int>(name: 'forms.event');
const EventTopic<int> formsOut = EventTopic<int>(name: 'forms.out');
const StateTopic<int> formsTotal = StateTopic<int>(
  name: 'forms.total',
  initial: 0,
);
const StateTopic<int> formsClaimed = StateTopic<int>(
  name: 'forms.claimed',
  initial: 0,
);

/// The forms sample of topology-ir@v1's conformance library, recorded.
TopologyGraph formsGraph() => TopologyGraph(
  topologies: <TopologyDefinition>[
    topology('forms', Scope.page, (TopologyBuilder b) {
      final TopicStream<int> state = b.read(formsState, dedup: Dedup.none);
      final TopicStream<int> event = b.read(formsEvent);
      final TopicStream<int> mapped = event.map(inc);
      final TopicStream<int> latest = mapped.withLatestFrom(state, add);
      final TopicStream<int> merged = b.merge(<TopicStream<int>>[
        latest,
        event,
      ]);
      b.write(formsOut, merged.debounce(const Duration(milliseconds: 5)));
      b.reduceInto(formsTotal, event, reduceCount);
    }).buildDefinition(),
  ],
  claims: <ShellClaim>[
    ShellClaim(
      source: const ServiceSource('forms'),
      writes: <TopicRef>{formsClaimed.ref},
    ),
  ],
);

const TopicRef stateA = TopicRef(
  name: 'enc.a',
  variant: TopicVariant.state,
  typeName: 'int',
);
const TopicRef stateB = TopicRef(
  name: 'enc.b',
  variant: TopicVariant.state,
  typeName: 'int',
);
const TopicRef eventE = TopicRef(
  name: 'enc.e',
  variant: TopicVariant.event,
  typeName: 'int',
);
const TopicRef replayR = TopicRef(
  name: 'enc.r',
  variant: TopicVariant.replay,
  typeName: 'int',
);

final FunctionRef f = FunctionRef.named('f');

TransformEdge one(CombinatorKind kind, int input, {Duration? duration}) =>
    TransformEdge.stage(kind, <EdgeInput>[
      StageInput(input),
    ], duration: duration);

/// One edge of every form: the seventeen stage kinds in CombinatorKind
/// order, a switchMap without a retry and one with, a write and a
/// reduceInto.
TopologyDefinition everyForm() => TopologyDefinition(
  topologyId: 'every-form',
  scope: Scope.module,
  transforms: <TransformEdge>[
    TransformEdge.stage(CombinatorKind.map, <EdgeInput>[
      const TopicInput(eventE),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.filter, <EdgeInput>[
      const StageInput(0),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.combine, <EdgeInput>[
      const StageInput(1),
      const TopicInput(stateA),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.withLatestFrom, <EdgeInput>[
      const StageInput(2),
      const TopicInput(stateA, dedup: Dedup.equality),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
      const StageInput(3),
      const TopicInput(replayR),
    ]),
    TransformEdge.stage(CombinatorKind.switchMap, <EdgeInput>[
      const StageInput(4),
    ], transformer: f),
    TransformEdge.stage(
      CombinatorKind.switchMap,
      <EdgeInput>[const StageInput(5)],
      transformer: f,
      retry: const FunctionRef.anonymous(),
    ),
    TransformEdge.stage(CombinatorKind.scan, <EdgeInput>[
      const StageInput(6),
    ], transformer: f),
    one(CombinatorKind.pairwise, 7),
    one(CombinatorKind.distinctUntilChanged, 8),
    one(
      CombinatorKind.debounce,
      9,
      duration: const Duration(milliseconds: 300),
    ),
    one(CombinatorKind.throttle, 10, duration: const Duration(seconds: 1)),
    one(CombinatorKind.delay, 11, duration: Duration.zero),
    one(
      CombinatorKind.sample,
      12,
      duration: const Duration(microseconds: 1500),
    ),
    one(CombinatorKind.buffer, 13, duration: const Duration(seconds: 2)),
    one(CombinatorKind.timeout, 14, duration: const Duration(days: 365000)),
    TransformEdge.stage(CombinatorKind.catchError, <EdgeInput>[
      const StageInput(15),
    ], transformer: f),
    TransformEdge.stage(CombinatorKind.rawEngine, <EdgeInput>[
      const StageInput(16),
    ], transformer: f),
    TransformEdge.write(eventE, const StageInput(17)),
    TransformEdge.reduceInto(
      stateB,
      const TopicInput(eventE),
      const FunctionRef.anonymous(),
    ),
  ],
);

List<Map<String, Object?>> edgesOf(Map<String, Object?> definition) =>
    (definition['transforms']! as List<Object?>).cast<Map<String, Object?>>();

/// Every map and list in [json], [json] included, at any depth.
List<Object> containersOf(Object? json) => <Object>[
  if (json is Map<String, Object?>) ...<Object>[
    json,
    for (final Object? member in json.values) ...containersOf(member),
  ],
  if (json is List<Object?>) ...<Object>[
    json,
    for (final Object? element in json) ...containersOf(element),
  ],
];

void main() {
  test('G19 the forms sample encodes to valid/forms.json, every key in the '
      "schema's order", () {
    expect(
      jsonEncode(encodeTopologyGraph(formsGraph())),
      jsonEncode(fixtureJson('valid/forms.json')),
    );
  });

  test("G19 the Interface's example graph encodes to the document the "
      'contract shows, every key in order', () {
    expect(
      jsonEncode(encodeTopologyGraph(interfaceExampleGraph())),
      jsonEncode(jsonDecode(interfaceExample)),
    );
  });

  test('G19 an edge carries combinator, inputs, output, transformer, '
      'durationMicros and retry in that order, each only where it has one; '
      'a combinator is its CombinatorKind name', () {
    final List<Map<String, Object?>> edges = edgesOf(
      encodeTopologyDefinition(everyForm()),
    );
    const List<String> stage = <String>['combinator', 'inputs'];
    const List<String> withFunction = <String>[...stage, 'transformer'];
    const List<String> timed = <String>[...stage, 'durationMicros'];
    expect(
      <List<String>>[
        for (final Map<String, Object?> e in edges) e.keys.toList(),
      ],
      <List<String>>[
        withFunction, // map
        withFunction, // filter
        withFunction, // combine
        withFunction, // withLatestFrom
        stage, // merge
        withFunction, // switchMap
        <String>[...withFunction, 'retry'], // switchMap with a retry
        withFunction, // scan
        stage, // pairwise
        stage, // distinctUntilChanged
        timed, timed, timed, timed, timed, timed, // the six time stages
        withFunction, // catchError
        withFunction, // rawEngine
        <String>['inputs', 'output'], // write
        <String>['combinator', 'inputs', 'output', 'transformer'], // reduceInto
      ],
    );
    expect(
      <Object?>[for (final Map<String, Object?> e in edges) e['combinator']],
      <Object?>[
        'map', 'filter', 'combine', 'withLatestFrom', 'merge', 'switchMap', //
        'switchMap', 'scan', 'pairwise', 'distinctUntilChanged', 'debounce', //
        'throttle', 'delay', 'sample', 'buffer', 'timeout', 'catchError', //
        'rawEngine', null, 'reduceInto',
      ],
    );
  });

  test('G19 an input is {topic} with dedup only when the read gave one, '
      'Dedup.equality included, or {edge}', () {
    final List<Map<String, Object?>> edges = edgesOf(
      encodeTopologyDefinition(everyForm()),
    );
    expect(edges[0]['inputs'], <Object?>[
      <String, Object?>{
        'topic': <String, Object?>{
          'name': 'enc.e',
          'variant': 'event',
          'typeName': 'int',
        },
      },
    ]);
    expect(
      jsonEncode(edges[3]['inputs']),
      '[{"edge":2},{"topic":{"name":"enc.a","variant":"state","typeName":"int"},'
      '"dedup":"equality"}]',
    );
    expect(
      jsonEncode(
        encodeTopologyDefinition(
          interfaceExampleGraph().topologies.single,
        )['transforms'],
      ),
      contains('"dedup":"none"'),
    );
  });

  test('G19 a duration is durationMicros, a whole number of microseconds '
      'written as an int', () {
    final List<Map<String, Object?>> edges = edgesOf(
      encodeTopologyDefinition(everyForm()),
    );
    final List<Object?> micros = <Object?>[
      for (final Map<String, Object?> e in edges.sublist(10, 16))
        e['durationMicros'],
    ];
    expect(micros, <Object?>[
      300000,
      1000000,
      0,
      1500,
      2000000,
      31536000000000000,
    ]);
    expect(micros, everyElement(isA<int>()));
  });

  test('G19 a function reference is {"name": name}, null when anonymous', () {
    final List<Map<String, Object?>> edges = edgesOf(
      encodeTopologyDefinition(everyForm()),
    );
    expect(edges[0]['transformer'], <String, Object?>{'name': 'f'});
    expect(edges[6]['retry'], <String, Object?>{'name': null});
    expect(jsonEncode(edges[19]), contains('"transformer":{"name":null}'));
  });

  test("G19 a claim is its source's rendering, its scope by name and its "
      'writes in canonical order, given in any order', () {
    final ShellClaim claim = ShellClaim(
      source: const ExecutorSource('a:b'),
      scope: Scope.module,
      writes: <TopicRef>{stateB, stateA},
    );
    expect(
      jsonEncode(
        (encodeTopologyGraph(
                  TopologyGraph(claims: <ShellClaim>[claim]),
                )['claims']!
                as List<Object?>)
            .single,
      ),
      '{"source":"executor:a:b","scope":"module","writes":['
      '{"name":"enc.a","variant":"state","typeName":"int"},'
      '{"name":"enc.b","variant":"state","typeName":"int"}]}',
    );
  });

  test('G19 a graph built from its parts in any order encodes the same, '
      'topologies by id and claims in canonical order', () {
    final TopologyGraph forms = formsGraph();
    final TopologyDefinition every = everyForm();
    final ShellClaim page = ShellClaim(
      source: const PageSource('p'),
      writes: <TopicRef>{stateA},
    );
    final TopologyGraph ordered = TopologyGraph(
      topologies: <TopologyDefinition>[every, ...forms.topologies],
      claims: <ShellClaim>[page, ...forms.claims],
    );
    final TopologyGraph reversed = TopologyGraph(
      topologies: <TopologyDefinition>[...forms.topologies, every],
      claims: <ShellClaim>[...forms.claims, page],
    );
    final Map<String, Object?> doc = encodeTopologyGraph(reversed);
    expect(jsonEncode(doc), jsonEncode(encodeTopologyGraph(ordered)));
    expect(
      <Object?>[
        for (final Object? t in doc['topologies']! as List<Object?>)
          (t! as Map<String, Object?>)['topologyId'],
      ],
      <Object?>['every-form', 'forms'],
    );
    expect(
      <Object?>[
        for (final Object? c in doc['claims']! as List<Object?>)
          (c! as Map<String, Object?>)['source'],
      ],
      <Object?>['page:p', 'service:forms'],
    );
  });

  test('G19 the encoding is a JSON value: JSON text gives it back equal, and '
      'each call returns a new value', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[everyForm(), ...formsGraph().topologies],
      claims: formsGraph().claims,
    );
    final Map<String, Object?> doc = encodeTopologyGraph(g);
    expect(jsonDecode(jsonEncode(doc)), doc);
    (doc['topologies']! as List<Object?>).clear();
    expect(encodeTopologyGraph(g)['topologies'], hasLength(2));
  });

  test('G22 JsonRenderer writes the encoding indented by two spaces, then a '
      'newline, and the forms sample as valid/forms.json byte for byte', () {
    expect(
      const JsonRenderer().render(TopologyGraph()),
      '{\n'
      '  "format": "topology-ir@v1",\n'
      '  "topologies": [],\n'
      '  "claims": []\n'
      '}\n',
    );
    expect(
      const JsonRenderer().render(formsGraph()),
      fixtureText('valid/forms.json'),
    );
    expect(
      formsGraph().render(const JsonRenderer()),
      const JsonRenderer().render(formsGraph()),
    );
  });

  test('G19 a definition lists its reads and writes in canonical order, not '
      'the order its edges give them, and a definition without edges lists '
      'three empty arrays', () {
    final Map<String, Object?> every = encodeTopologyDefinition(everyForm());
    List<Object?> namesOf(String key) => <Object?>[
      for (final Object? t in every[key]! as List<Object?>)
        (t! as Map<String, Object?>)['name'],
    ];
    expect(namesOf('reads'), <Object?>['enc.a', 'enc.e', 'enc.r']);
    expect(namesOf('writes'), <Object?>['enc.b', 'enc.e']);
    expect(
      jsonEncode(
        encodeTopologyDefinition(
          TopologyDefinition(
            topologyId: 'empty',
            scope: Scope.page,
            transforms: const <TransformEdge>[],
          ),
        ),
      ),
      '{"topologyId":"empty","scope":"page","reads":[],"writes":[],'
      '"transforms":[]}',
    );
  });

  test('G19 two encodings of one graph share no map and no list, nested ones '
      'included', () {
    final TopologyGraph g = TopologyGraph(
      topologies: <TopologyDefinition>[everyForm(), ...formsGraph().topologies],
      claims: formsGraph().claims,
    );
    final List<Object> first = containersOf(encodeTopologyGraph(g));
    final Set<Object> seen = Set<Object>.identity()..addAll(first);
    final List<Object> second = containersOf(encodeTopologyGraph(g));
    expect(first.length, greaterThan(100));
    expect(second.length, first.length);
    expect(seen.length, first.length);
    expect(second.where(seen.contains), isEmpty);
  });
}
