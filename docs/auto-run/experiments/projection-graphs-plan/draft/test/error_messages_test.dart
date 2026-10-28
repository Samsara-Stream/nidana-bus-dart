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
}
