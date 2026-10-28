// topology-dsl@v2's recording core, beyond the cases of its recording suite,
// which the gate replays (hsdd/contract/fixture/topology-dsl/behavior/):
// planOf, the builder form, reads and writes with their misuse checks, and
// topology references.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:test/test.dart';

const StateTopic<int> count = StateTopic<int>(name: 'rec.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'rec.taps');
const EventTopic<int> out = EventTopic<int>(name: 'rec.out');
const ReplayTopic<int> log = ReplayTopic<int>(name: 'rec.log', bufferSize: 2);

Topology declared(void Function(TopologyBuilder b) body) =>
    topology('rec-core', Scope.page, body);

/// A class-form topology with an empty id, whose declare must never run.
final class Unnamed extends Topology {
  const Unnamed();

  @override
  String get topologyId => '';

  @override
  Scope get scope => Scope.page;

  @override
  void declare(TopologyBuilder b) =>
      throw UnsupportedError('declare ran for an empty topology id');
}

void main() {
  test('G9 planOf runs declare once per call against a fresh builder and '
      'carries the id and scope', () {
    final List<TopologyBuilder> builders = <TopologyBuilder>[];
    final Topology t = topology('rec-form', Scope.module, (TopologyBuilder b) {
      builders.add(b);
      b.write(out, b.read(taps));
    });
    expect(builders, isEmpty);
    final TopologyPlan first = planOf(t);
    final TopologyPlan second = planOf(t);
    expect(builders, hasLength(2));
    expect(identical(builders[0], builders[1]), isFalse);
    expect(first.topologyId, 'rec-form');
    expect(first.scope, Scope.module);
    expect(identical(first.stages.single, second.stages.single), isFalse);
  });

  test('G9 an empty declaration records an empty plan', () {
    final TopologyPlan plan = planOf(declared((TopologyBuilder b) {}));
    expect(plan.stages, isEmpty);
    expect(plan.sinks, isEmpty);
  });

  test('G11 a read and a write hold the topic, dedup and handle they were '
      'given', () {
    late TopicStream<int> read;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        read = b.read(count, dedup: Dedup.none);
        b.write(out, read);
      }),
    );
    final ReadStage<int> stage = plan.stages.single as ReadStage<int>;
    expect(identical(stage, read), isTrue);
    expect(identical(stage.topic, count), isTrue);
    expect(stage.dedup, Dedup.none);
    final WriteSink<int> sink = plan.sinks.single as WriteSink<int>;
    expect(identical(sink.topic, out), isTrue);
    expect(identical(sink.input, read), isTrue);
  });

  test('G13 a dedup argument on an event or replay read throws ArgumentError '
      'at the call and adds no stage', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        expect(() => b.read(taps, dedup: Dedup.none), throwsArgumentError);
        expect(() => b.read(log, dedup: Dedup.equality), throwsArgumentError);
        b.write(out, b.read(count, dedup: Dedup.equality));
      }),
    );
    expect(plan.stages, hasLength(1));
  });

  test('G14 a second sink on a state topic built apart throws ArgumentError '
      'at the call; another value type is another topic', () {
    final String name = <String>['rec.total'].single;
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        b.write(StateTopic<int>(name: name, initial: 0), t);
        expect(
          () => b.write(
            StateTopic<int>(name: name, initial: 9, dedup: Dedup.none),
            t,
          ),
          throwsArgumentError,
        );
        b.write(StateTopic<num>(name: name, initial: 0), t);
      }),
    );
    expect(plan.sinks, hasLength(2));
  });

  test('G14 a handle of a declaration still running is another builder\'s', () {
    planOf(
      topology('rec-outer', Scope.page, (TopologyBuilder outer) {
        final TopicStream<int> mine = outer.read(taps);
        expect(
          () => planOf(
            topology(
              'rec-inner',
              Scope.page,
              (TopologyBuilder inner) => inner.write(out, mine),
            ),
          ),
          throwsArgumentError,
        );
        outer.write(out, mine);
      }),
    );
  });

  test('G15 a builder and its handles throw StateError once declare has '
      'returned, by throwing as well', () {
    late TopologyBuilder kept;
    late TopicStream<int> handle;
    expect(
      () => planOf(
        declared((TopologyBuilder b) {
          kept = b;
          handle = b.read(taps);
          throw const FormatException('declare failed');
        }),
      ),
      throwsFormatException,
    );
    expect(() => kept.read(taps), throwsStateError);
    expect(() => kept.write(out, handle), throwsStateError);
  });

  test('G15 an empty topology id fails before any declare runs', () {
    expect(() => planOf(const Unnamed()), throwsStateError);
    expect(() => const Unnamed().buildDefinition(), throwsStateError);
    expect(
      () => topology('', Scope.page, (TopologyBuilder b) {}),
      throwsArgumentError,
    );
  });

  test('G15 a read that reaches no sink fails planOf with StateError', () {
    expect(
      () => planOf(
        declared((TopologyBuilder b) {
          b.write(out, b.read(taps));
          b.read(count);
        }),
      ),
      throwsStateError,
    );
  });

  test('G17 topology references built apart are one set element and one '
      'map key', () {
    final String id = <String>['checkout-flow'].single;
    final Set<TopologyRef> refs = <TopologyRef>{
      TopologyRef(id),
      const TopologyRef('checkout-flow'),
      const TopologyRef('checkout-cart'),
    };
    expect(refs, hasLength(2));
    final Map<TopologyRef, int> owners = <TopologyRef, int>{TopologyRef(id): 1};
    owners[const TopologyRef('checkout-flow')] = 2;
    expect(owners, hasLength(1));
    expect(owners[TopologyRef(id)], 2);
  });

  // Beyond the plan's tests: the order and the effect of a rejected call.

  test('G11 a stream of a subtype is written to a wider topic, which the sink '
      'holds', () {
    const EventTopic<num> wide = EventTopic<num>(name: 'rec.wide');
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) => b.write(wide, b.read(taps))),
    );
    final WriteSink<num> sink = plan.sinks.single as WriteSink<num>;
    expect(identical(sink.topic, wide), isTrue);
  });

  test('G13 a read without a dedup argument records null, for a state, an '
      'event and a replay topic', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        b.write(out, b.read(count));
        b.write(out, b.read(taps));
        b.write(out, b.read(log));
      }),
    );
    expect(plan.stages, hasLength(3));
    for (final TopicStream<Object?> stage in plan.stages) {
      expect((stage as ReadStage<Object?>).dedup, isNull);
    }
  });

  test('G14 a rejected write claims no state topic', () {
    late TopicStream<int> foreign;
    planOf(
      declared((TopologyBuilder b) {
        foreign = b.read(taps);
        b.write(out, foreign);
      }),
    );
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> mine = b.read(taps);
        expect(() => b.write(count, foreign), throwsArgumentError);
        b.write(count, mine);
      }),
    );
    expect(plan.sinks, hasLength(1));
  });

  test('G14 a rejected second sink consumes no handle: the handle it named '
      'still reaches no sink', () {
    expect(
      () => planOf(
        declared((TopologyBuilder b) {
          final TopicStream<int> first = b.read(taps);
          final TopicStream<int> second = b.read(taps);
          b.write(count, first);
          expect(() => b.write(count, second), throwsArgumentError);
        }),
      ),
      throwsStateError,
    );
  });

  test('G14 an event or replay topic takes any number of sinks, and reading '
      'a state topic claims nothing', () {
    final TopologyPlan plan = planOf(
      declared((TopologyBuilder b) {
        final TopicStream<int> t = b.read(taps);
        b.write(out, t);
        b.write(out, t);
        b.write(log, t);
        b.write(log, b.read(count));
        b.write(count, t);
      }),
    );
    expect(plan.sinks, hasLength(5));
  });

  test('G14 a handle from an earlier planOf call of one topology is another '
      'builder\'s, and the declaration goes on after the rejection', () {
    final List<TopicStream<int>> made = <TopicStream<int>>[];
    int rejected = 0;
    final Topology t = declared((TopologyBuilder b) {
      final TopicStream<int> mine = b.read(taps);
      for (final TopicStream<int> earlier in made) {
        try {
          b.write(out, earlier);
        } on ArgumentError {
          rejected++;
        }
      }
      made.add(mine);
      b.write(out, mine);
    });
    planOf(t);
    planOf(t);
    planOf(t);
    expect(rejected, 3);
  });

  test('G15 the open check comes before every argument check', () {
    late TopologyBuilder kept;
    late TopicStream<int> mine;
    planOf(
      declared((TopologyBuilder b) {
        kept = b;
        mine = b.read(taps);
        b.write(count, mine);
      }),
    );
    late TopicStream<int> foreign;
    planOf(
      declared((TopologyBuilder b) {
        foreign = b.read(taps);
        b.write(out, foreign);
      }),
    );
    expect(() => kept.read(taps, dedup: Dedup.none), throwsStateError);
    expect(() => kept.write(out, foreign), throwsStateError);
    expect(() => kept.write(count, mine), throwsStateError);
  });

  test('G15 buildDefinition plans first: a stage that reaches no sink fails '
      'with StateError', () {
    expect(
      () => declared((TopologyBuilder b) => b.read(taps)).buildDefinition(),
      throwsStateError,
    );
  });

  test('G17 a topology reference is not equal to its id string or to a '
      'reference of another id', () {
    const TopologyRef ref = TopologyRef('checkout-flow');
    expect(ref, isNot(equals('checkout-flow')));
    expect(ref, isNot(equals(const TopologyRef('checkout-cart'))));
    expect(
      ref.hashCode,
      TopologyRef(<String>['checkout-flow'].single).hashCode,
    );
  });
}
