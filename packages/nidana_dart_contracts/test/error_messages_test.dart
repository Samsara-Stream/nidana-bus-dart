// What the recording builder's and the IR's rejections say: the argument a
// foreign handle was passed as, the variant of a read that takes no dedup,
// the input count an edge takes, and why two state topics whose value types
// render alike make a second sink edge (topology-dsl@v2 G13 and G14;
// topology-ir@v1 G5 and G6).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

import 'src/cart_elsewhere.dart' as elsewhere;

final class Cart {
  const Cart();
}

const StateTopic<int> count = StateTopic<int>(name: 'msg.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'msg.taps');
const EventTopic<int> out = EventTopic<int>(name: 'msg.out');
const ReplayTopic<int> log = ReplayTopic<int>(name: 'msg.log', bufferSize: 2);

/// An ArgumentError whose name is [name] and whose message holds [parts].
Matcher rejects(String name, [List<String> parts = const <String>[]]) =>
    throwsA(
      isA<ArgumentError>()
          .having((ArgumentError e) => e.name, 'name', name)
          .having(
            (ArgumentError e) => '${e.message}',
            'message',
            allOf(<Matcher>[for (final String p in parts) contains(p)]),
          ),
    );

/// The plan of a declaration that [body] makes, where [foreign] is a handle
/// an earlier declaration made.
TopologyPlan plan(
  void Function(TopologyBuilder b, TopicStream<int> foreign) body,
) {
  late TopicStream<int> foreign;
  planOf(
    topology('msg-earlier', Scope.page, (TopologyBuilder b) {
      foreign = b.read(taps);
      b.write(out, foreign);
    }),
  );
  return planOf(
    topology('msg', Scope.page, (TopologyBuilder b) => body(b, foreign)),
  );
}

int first(int a, [int? b, int? c, int? d]) => a;

void main() {
  test('G14 a foreign handle is named by the parameter it was passed as, or '
      'by its index in a list', () {
    final Map<String, void Function(TopologyBuilder b, TopicStream<int> f)>
    uses = <String, void Function(TopologyBuilder b, TopicStream<int> f)>{
      'stream': (TopologyBuilder b, TopicStream<int> f) => b.write(out, f),
      'events': (TopologyBuilder b, TopicStream<int> f) =>
          b.reduceInto(count, f, (int s, int e) => s),
      'b': (TopologyBuilder b, TopicStream<int> f) =>
          b.write(out, b.combine2(b.read(taps), f, first)),
      'c': (TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, b.combine3(t, t, f, first));
      },
      'd': (TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, b.combine4(t, t, t, f, first));
      },
      'inputs[1]': (TopologyBuilder b, TopicStream<int> f) => b.write(
        out,
        b.combineAll(<TopicStream<int>>[b.read(taps), f], (List<int> v) => 0),
      ),
      'inputs[2]': (TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, b.merge(<TopicStream<int>>[t, t, f]));
      },
      'latest': (TopologyBuilder b, TopicStream<int> f) =>
          b.write(out, b.read(taps).withLatestFrom(f, first)),
    };
    for (final MapEntry<
          String,
          void Function(TopologyBuilder b, TopicStream<int> f)
        >
        use
        in uses.entries) {
      expect(
        () => plan(use.value),
        rejects(use.key, <String>['another builder']),
        reason: use.key,
      );
    }
    expect(
      () => plan((TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, t.withLatestFrom2(t, f, first));
      }),
      rejects('c'),
    );
    expect(
      () => plan((TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, t.withLatestFrom3(f, t, t, first));
      }),
      rejects('b'),
    );
    expect(
      () => plan((TopologyBuilder b, TopicStream<int> f) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, t.withLatestFrom3(t, t, f, first));
      }),
      rejects('d'),
    );
  });

  test('G13 a dedup argument on an event or replay read names the read\'s '
      'variant with its article', () {
    expect(
      () => plan(
        (TopologyBuilder b, TopicStream<int> f) =>
            b.write(out, b.read(taps, dedup: Dedup.none)),
      ),
      rejects('dedup', <String>['msg.taps is an event topic']),
    );
    expect(
      () => plan(
        (TopologyBuilder b, TopicStream<int> f) =>
            b.write(out, b.read(log, dedup: Dedup.equality)),
      ),
      rejects('dedup', <String>['msg.log is a replay topic']),
    );
  });

  test('G5 an edge given the wrong number of inputs says how many its '
      'combinator takes', () {
    final FunctionRef f = FunctionRef.named('f');
    final TopicInput a = TopicInput(taps.ref);
    Matcher says(String message) => throwsA(
      isA<ArgumentError>()
          .having((ArgumentError e) => e.name, 'name', 'inputs')
          .having((ArgumentError e) => e.message, 'message', message),
    );
    expect(
      () => TransformEdge.stage(CombinatorKind.map, <EdgeInput>[
        a,
        a,
      ], transformer: f),
      says('a map edge takes exactly 1 input'),
    );
    expect(
      () => TransformEdge.stage(CombinatorKind.merge, const <EdgeInput>[]),
      says('a merge edge takes at least 1 input'),
    );
    expect(
      () => TransformEdge.stage(CombinatorKind.withLatestFrom, <EdgeInput>[
        a,
      ], transformer: f),
      says('a withLatestFrom edge takes 2 to 4 inputs'),
    );
  });

  test('G6 a second sink edge on a state topic names the topic and its type, '
      'and says that value types rendering alike are one topic', () {
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
    expect(
      t.buildDefinition,
      rejects('transforms', <String>[
        'second sink edge',
        'Cart',
        'render alike',
      ]),
    );
    expect(
      t.buildDefinition,
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.invalidValue,
          'invalidValue',
          'shop.cart',
        ),
      ),
    );
  });

  // The tests below pin what the plan's four leave open: every position of
  // every call, the full text of the dedup rejection, every combinator's input
  // count, and the second-sink message for a genuinely repeated topic.

  test('G14 every call names the parameter at each position, and the first '
      'foreign handle when several are foreign', () {
    // Each call shape: the parameter names of its handles, in order, and a
    // call that passes [h] in that order.
    final Map<
      String,
      ({
        List<String> names,
        void Function(TopologyBuilder b, List<TopicStream<int>> h) call,
      })
    >
    shapes =
        <
          String,
          ({
            List<String> names,
            void Function(TopologyBuilder b, List<TopicStream<int>> h) call,
          })
        >{
          'write': (
            names: <String>['stream'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.write(out, h[0]),
          ),
          'reduceInto': (
            names: <String>['events'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.reduceInto(count, h[0], (int s, int e) => s),
          ),
          'combine2': (
            names: <String>['a', 'b'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.write(out, b.combine2(h[0], h[1], first)),
          ),
          'combine3': (
            names: <String>['a', 'b', 'c'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.write(out, b.combine3(h[0], h[1], h[2], first)),
          ),
          'combine4': (
            names: <String>['a', 'b', 'c', 'd'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.write(out, b.combine4(h[0], h[1], h[2], h[3], first)),
          ),
          'combineAll': (
            names: <String>['inputs[0]', 'inputs[1]', 'inputs[2]'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.write(out, b.combineAll(h, (List<int> v) => 0)),
          ),
          'merge': (
            names: <String>['inputs[0]', 'inputs[1]', 'inputs[2]'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.write(out, b.merge(h)),
          ),
          'withLatestFrom': (
            names: <String>['latest'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.write(out, b.read(taps).withLatestFrom(h[0], first)),
          ),
          'withLatestFrom2': (
            names: <String>['b', 'c'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) =>
                b.write(out, b.read(taps).withLatestFrom2(h[0], h[1], first)),
          ),
          'withLatestFrom3': (
            names: <String>['b', 'c', 'd'],
            call: (TopologyBuilder b, List<TopicStream<int>> h) => b.write(
              out,
              b.read(taps).withLatestFrom3(h[0], h[1], h[2], first),
            ),
          ),
        };
    for (final MapEntry<
          String,
          ({
            List<String> names,
            void Function(TopologyBuilder b, List<TopicStream<int>> h) call,
          })
        >
        shape
        in shapes.entries) {
      final List<String> names = shape.value.names;
      for (int i = 0; i < names.length; i++) {
        // Only the handle at i is foreign, then it and every one after it.
        for (final bool restForeign in <bool>[false, true]) {
          expect(
            () => plan((TopologyBuilder b, TopicStream<int> f) {
              final TopicStream<int> own = b.read(taps);
              shape.value.call(b, <TopicStream<int>>[
                for (int j = 0; j < names.length; j++)
                  j == i || (restForeign && j > i) ? f : own,
              ]);
            }),
            rejects(names[i], <String>['another builder']),
            reason: '${shape.key} at $i, the rest foreign: $restForeign',
          );
        }
      }
    }
  });

  test('G13 the dedup rejection reads as one sentence for each variant', () {
    expect(
      () => plan(
        (TopologyBuilder b, TopicStream<int> f) =>
            b.write(out, b.read(taps, dedup: Dedup.none)),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.message,
          'message',
          'applies to a state topic read only, and msg.taps is an event '
              'topic',
        ),
      ),
    );
    expect(
      () => plan(
        (TopologyBuilder b, TopicStream<int> f) =>
            b.write(out, b.read(log, dedup: Dedup.equality)),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.message,
          'message',
          'applies to a state topic read only, and msg.log is a replay '
              'topic',
        ),
      ),
    );
  });

  test('G5 every combinator that takes a count of inputs says it with the '
      'noun that count needs', () {
    const Set<CombinatorKind> exactlyOne = <CombinatorKind>{
      CombinatorKind.map,
      CombinatorKind.filter,
      CombinatorKind.scan,
      CombinatorKind.catchError,
      CombinatorKind.rawEngine,
      CombinatorKind.switchMap,
      CombinatorKind.pairwise,
      CombinatorKind.distinctUntilChanged,
      CombinatorKind.debounce,
      CombinatorKind.throttle,
      CombinatorKind.delay,
      CombinatorKind.sample,
      CombinatorKind.buffer,
      CombinatorKind.timeout,
    };
    const Set<CombinatorKind> atLeastOne = <CombinatorKind>{
      CombinatorKind.combine,
      CombinatorKind.merge,
    };
    // A new combinator is placed in a group, or has its own expectation.
    expect(<CombinatorKind>{
      ...exactlyOne,
      ...atLeastOne,
      CombinatorKind.withLatestFrom,
      CombinatorKind.reduceInto,
    }, CombinatorKind.values.toSet());
    final TopicInput a = TopicInput(taps.ref);
    String messageOf(CombinatorKind k, int n) {
      try {
        TransformEdge.stage(k, <EdgeInput>[for (int i = 0; i < n; i++) a]);
      } on ArgumentError catch (e) {
        expect(e.name, 'inputs', reason: '${k.name} with $n inputs');
        expect(e.invalidValue, n, reason: '${k.name} with $n inputs');
        return '${e.message}';
      }
      fail('${k.name} accepted $n inputs');
    }

    for (final CombinatorKind k in exactlyOne) {
      for (final int n in <int>[0, 2]) {
        expect(
          messageOf(k, n),
          'a ${k.name} edge takes exactly 1 input',
          reason: '${k.name} with $n inputs',
        );
      }
    }
    for (final CombinatorKind k in atLeastOne) {
      expect(messageOf(k, 0), 'a ${k.name} edge takes at least 1 input');
    }
    for (final int n in <int>[0, 1, 5]) {
      expect(
        messageOf(CombinatorKind.withLatestFrom, n),
        'a withLatestFrom edge takes 2 to 4 inputs',
        reason: 'withLatestFrom with $n inputs',
      );
    }
  });

  test('G6 a state topic repeated as the same topic says the same: the '
      'topic, the edge and the type', () {
    final TopicRef cart = TopicRef(
      name: 'shop.cart',
      variant: TopicVariant.state,
      typeName: 'Cart',
    );
    final FunctionRef f = FunctionRef.named('f');
    expect(
      () => TopologyDefinition(
        topologyId: 'twice',
        scope: Scope.page,
        transforms: <TransformEdge>[
          TransformEdge.write(cart, TopicInput(taps.ref)),
          TransformEdge.reduceInto(cart, TopicInput(taps.ref), f),
        ],
      ),
      throwsA(
        isA<ArgumentError>()
            .having((ArgumentError e) => e.name, 'name', 'transforms')
            .having(
              (ArgumentError e) => e.invalidValue,
              'invalidValue',
              'shop.cart',
            )
            .having(
              (ArgumentError e) => '${e.message}',
              'message',
              startsWith(
                'edge 1 is a second sink edge on this state topic, of type '
                'Cart; ',
              ),
            ),
      ),
    );
  });
}
