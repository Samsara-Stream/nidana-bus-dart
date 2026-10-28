// topology-ir@v1's From a plan, beyond the G8 cases of its conformance suite
// and topology-dsl@v2's G9, G10 and G12 cases of its recording suite, which
// the gate replays: the contracts' example topologies the suites do not
// project, the combiner of every arity form, a read written as it is, and
// two state topics whose value types render alike.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

import 'src/cart_elsewhere.dart' as elsewhere;

final class Results {
  const Results();
}

final class Cart {
  const Cart();
}

Never called(String what) => throw StateError('the projection called $what');

Stream<Results> searchApi(String query) => called('searchApi');
int inc(int v) => called('inc');
int add(int a, int b) => called('add');
int reduceCount(int state, int event) => called('reduceCount');
int pair(int a, int b) => called('pair');
int triple(int a, int b, int c) => called('triple');
int quadruple(int a, int b, int c, int d) => called('quadruple');
int total(List<int> values) => called('total');
int latest1(int v, int a) => called('latest1');
int latest2(int v, int a, int b) => called('latest2');
int latest3(int v, int a, int b, int c) => called('latest3');

// topology-ir@v1's JSON example (the Interface, The JSON form).
const StateTopic<String> query = StateTopic<String>(
  name: 'search.query',
  initial: '',
);
const StateTopic<Results> results = StateTopic<Results>(
  name: 'search.results',
  initial: Results(),
);

// The forms sample of topology-ir@v1's conformance library.
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

// The quiet topology of the findings sample.
const StateTopic<int> quiet = StateTopic<int>(name: 'quiet.value', initial: 0);

const StateTopic<int> count = StateTopic<int>(name: 'proj.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'proj.taps');
const EventTopic<int> out = EventTopic<int>(name: 'proj.out');
const ReplayTopic<int> log = ReplayTopic<int>(name: 'proj.log', bufferSize: 2);

TopicInput read(Topic<Object?> topic, {Dedup? dedup}) =>
    TopicInput(topic.ref, dedup: dedup);

FunctionRef named(String name) => FunctionRef.named(name);

TransformEdge one(
  CombinatorKind kind,
  EdgeInput input, {
  FunctionRef? f,
  Duration? d,
}) =>
    TransformEdge.stage(kind, <EdgeInput>[input], transformer: f, duration: d);

TopologyDefinition define(
  String id,
  Scope scope,
  List<TransformEdge> transforms,
) => TopologyDefinition(topologyId: id, scope: scope, transforms: transforms);

void main() {
  test('G8 the search topology of topology-ir@v1\'s JSON example projects to '
      'its debounce, switchMap and write', () {
    final TopologyDefinition d = topology(
      'search',
      Scope.page,
      (TopologyBuilder b) => b.write(
        results,
        b
            .read(query, dedup: Dedup.none)
            .debounce(const Duration(milliseconds: 300))
            .switchMap(searchApi, retry: (Object error, int attempt) => null),
      ),
    ).buildDefinition();
    expect(
      d,
      define('search', Scope.page, <TransformEdge>[
        one(
          CombinatorKind.debounce,
          read(query, dedup: Dedup.none),
          d: const Duration(milliseconds: 300),
        ),
        TransformEdge.stage(
          CombinatorKind.switchMap,
          const <EdgeInput>[StageInput(0)],
          transformer: named('searchApi'),
          retry: const FunctionRef.anonymous(),
        ),
        TransformEdge.write(results.ref, const StageInput(1)),
      ]),
    );
    expect(d.reads.toList(), <TopicRef>[
      const TopicRef(
        name: 'search.query',
        variant: TopicVariant.state,
        typeName: 'String',
      ),
    ]);
    expect(d.writes.toList(), <TopicRef>[
      const TopicRef(
        name: 'search.results',
        variant: TopicVariant.state,
        typeName: 'Results',
      ),
    ]);
  });

  test('G8 G12 the forms sample projects to the edges of its valid/ '
      'document: one read handle feeds a map, a merge and a reduceInto', () {
    final TopologyDefinition d = topology('forms', Scope.page, (
      TopologyBuilder b,
    ) {
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
    }).buildDefinition();
    expect(
      d,
      define('forms', Scope.page, <TransformEdge>[
        one(CombinatorKind.map, read(formsEvent), f: named('inc')),
        TransformEdge.stage(CombinatorKind.withLatestFrom, <EdgeInput>[
          const StageInput(0),
          read(formsState, dedup: Dedup.none),
        ], transformer: named('add')),
        TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
          const StageInput(1),
          read(formsEvent),
        ]),
        one(
          CombinatorKind.debounce,
          const StageInput(2),
          d: const Duration(milliseconds: 5),
        ),
        TransformEdge.write(formsOut.ref, const StageInput(3)),
        TransformEdge.reduceInto(
          formsTotal.ref,
          read(formsEvent),
          named('reduceCount'),
        ),
      ]),
    );
    expect(d.reads.toList(), <TopicRef>[formsEvent.ref, formsState.ref]);
    expect(d.writes.toList(), <TopicRef>[formsOut.ref, formsTotal.ref]);
  });

  test('G8 the quiet topology of the findings sample: one read feeds two '
      'stages, whose edges a merge takes by index', () {
    final TopologyDefinition d = topology('quiet', Scope.module, (
      TopologyBuilder b,
    ) {
      final TopicStream<int> v = b.read(quiet);
      b.write(
        quiet,
        b.merge(<TopicStream<int>>[
          v.debounce(Duration.zero),
          v.delay(const Duration(milliseconds: 10)),
        ]),
      );
    }).buildDefinition();
    expect(d.transforms, <TransformEdge>[
      one(CombinatorKind.debounce, read(quiet), d: Duration.zero),
      one(
        CombinatorKind.delay,
        read(quiet),
        d: const Duration(milliseconds: 10),
      ),
      TransformEdge.stage(CombinatorKind.merge, const <EdgeInput>[
        StageInput(0),
        StageInput(1),
      ]),
      TransformEdge.write(quiet.ref, const StageInput(2)),
    ]);
  });

  test('G8 every arity form of combine and withLatestFrom names the combiner '
      'the declaration passed, its inputs in input order', () {
    final TopologyDefinition d = topology('arity', Scope.page, (
      TopologyBuilder b,
    ) {
      final TopicStream<int> c = b.read(count);
      final TopicStream<int> t = b.read(taps);
      final TopicStream<int> l = b.read(log);
      b.write(
        out,
        b.merge(<TopicStream<int>>[
          b.combine2(c, t, pair),
          b.combine3(t, c, l, triple),
          b.combine4(l, t, c, l, quadruple),
          b.combineAll(<TopicStream<int>>[t, l], total),
          t.withLatestFrom(c, latest1),
          l.withLatestFrom2(t, c, latest2),
          c.withLatestFrom3(l, t, c, latest3),
        ]),
      );
    }).buildDefinition();
    TransformEdge combine(List<EdgeInput> inputs, String f) =>
        TransformEdge.stage(
          CombinatorKind.combine,
          inputs,
          transformer: named(f),
        );
    TransformEdge latest(List<EdgeInput> inputs, String f) =>
        TransformEdge.stage(
          CombinatorKind.withLatestFrom,
          inputs,
          transformer: named(f),
        );
    expect(d.transforms.sublist(0, 7), <TransformEdge>[
      combine(<EdgeInput>[read(count), read(taps)], 'pair'),
      combine(<EdgeInput>[read(taps), read(count), read(log)], 'triple'),
      combine(<EdgeInput>[
        read(log),
        read(taps),
        read(count),
        read(log),
      ], 'quadruple'),
      combine(<EdgeInput>[read(taps), read(log)], 'total'),
      latest(<EdgeInput>[read(taps), read(count)], 'latest1'),
      latest(<EdgeInput>[read(log), read(taps), read(count)], 'latest2'),
      latest(<EdgeInput>[
        read(count),
        read(log),
        read(taps),
        read(count),
      ], 'latest3'),
    ]);
    expect(
      d.transforms[7],
      TransformEdge.stage(CombinatorKind.merge, <EdgeInput>[
        for (int i = 0; i < 7; i++) StageInput(i),
      ]),
    );
    expect(d.transforms, hasLength(9));
  });

  test('G8 a read written as it is projects to a write of a topic input with '
      'the read\'s dedup argument, and an inline closure is anonymous', () {
    final TopologyDefinition d = topology('direct', Scope.application, (
      TopologyBuilder b,
    ) {
      b.write(out, b.read(taps));
      b.write(count, b.read(count, dedup: Dedup.equality));
      b.write(log, b.read(taps).filter((int v) => v > 0));
    }).buildDefinition();
    expect(
      d,
      define('direct', Scope.application, <TransformEdge>[
        one(
          CombinatorKind.filter,
          read(taps),
          f: const FunctionRef.anonymous(),
        ),
        TransformEdge.write(out.ref, read(taps)),
        TransformEdge.write(count.ref, read(count, dedup: Dedup.equality)),
        TransformEdge.write(log.ref, const StageInput(0)),
      ]),
    );
    expect(d.reads.toList(), <TopicRef>[count.ref, taps.ref]);
    expect(d.writes.toList(), <TopicRef>[count.ref, log.ref, out.ref]);
  });

  test('G9 a plan projects again at each read of its definition, equal each '
      'time and equal to buildDefinition', () {
    final Topology t = topology(
      'again',
      Scope.module,
      (TopologyBuilder b) => b.write(out, b.read(taps).map((int v) => v + 1)),
    );
    final TopologyPlan plan = planOf(t);
    expect(plan.definition, plan.definition);
    expect(plan.definition.hashCode, plan.definition.hashCode);
    expect(t.buildDefinition(), plan.definition);
  });

  test('G8 two state topics whose value types render alike pass planOf, and '
      'definition and buildDefinition throw TopologyDefinition\'s '
      'ArgumentError naming the transforms', () {
    const StateTopic<Cart> mine = StateTopic<Cart>(
      name: 'shop.cart',
      initial: Cart(),
    );
    const StateTopic<elsewhere.Cart> theirs = StateTopic<elsewhere.Cart>(
      name: 'shop.cart',
      initial: elsewhere.Cart(),
    );
    final Topology t = topology('alike', Scope.page, (TopologyBuilder b) {
      b.write(mine, b.read(taps).map((int v) => const Cart()));
      b.write(theirs, b.read(taps).map((int v) => const elsewhere.Cart()));
    });
    final TopologyPlan plan = planOf(t);
    expect(plan.sinks, hasLength(2));
    final Matcher rejected = throwsA(
      isA<ArgumentError>().having(
        (ArgumentError e) => e.name,
        'name',
        'transforms',
      ),
    );
    expect(() => plan.definition, rejected);
    expect(t.buildDefinition, rejected);
  });
}
