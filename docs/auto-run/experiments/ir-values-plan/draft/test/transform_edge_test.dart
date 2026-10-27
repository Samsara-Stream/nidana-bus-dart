// topology-ir@v1's edges and edge inputs, beyond the G5 and G10 cases of its
// conformance suite, which the gate replays: the whole stage-edge table, the
// argument each rejection names, sinks of every variant, unmodifiable copies
// (G3) and value equality (G7), which join the gate at nidana.model.11.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

TopicRef ref(String name, [TopicVariant variant = TopicVariant.event]) =>
    TopicRef(name: name, variant: variant, typeName: 'int');

final FunctionRef f = FunctionRef.named('f');
const Duration ms = Duration(milliseconds: 1);

/// What topology-ir@v1's stage-edge table allows for each combinator but
/// reduceInto: the input counts accepted among 0 to 5, and whether a
/// transformer, a duration and a retry are taken.
final Map<CombinatorKind, (List<int>, bool, bool, bool)> table =
    <CombinatorKind, (List<int>, bool, bool, bool)>{
      CombinatorKind.map: (<int>[1], true, false, false),
      CombinatorKind.filter: (<int>[1], true, false, false),
      CombinatorKind.combine: (<int>[1, 2, 3, 4, 5], true, false, false),
      CombinatorKind.withLatestFrom: (<int>[2, 3, 4], true, false, false),
      CombinatorKind.merge: (<int>[1, 2, 3, 4, 5], false, false, false),
      CombinatorKind.switchMap: (<int>[1], true, false, true),
      CombinatorKind.scan: (<int>[1], true, false, false),
      CombinatorKind.pairwise: (<int>[1], false, false, false),
      CombinatorKind.distinctUntilChanged: (<int>[1], false, false, false),
      CombinatorKind.debounce: (<int>[1], false, true, false),
      CombinatorKind.throttle: (<int>[1], false, true, false),
      CombinatorKind.delay: (<int>[1], false, true, false),
      CombinatorKind.sample: (<int>[1], false, true, false),
      CombinatorKind.buffer: (<int>[1], false, true, false),
      CombinatorKind.timeout: (<int>[1], false, true, false),
      CombinatorKind.catchError: (<int>[1], true, false, false),
      CombinatorKind.rawEngine: (<int>[1], true, false, false),
    };

List<EdgeInput> inputs(int count) => <EdgeInput>[
  for (int i = 0; i < count; i++) TopicInput(ref('t.$i')),
];

/// Throws an ArgumentError whose name is [argument].
Matcher rejects(String argument) => throwsA(
  isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', argument),
);

void main() {
  test('G5 every combinator but reduceInto takes the input counts, '
      'transformer, duration and retry the table allows, and rejects the '
      'others naming the argument', () {
    expect(table.keys, hasLength(CombinatorKind.values.length - 1));
    for (final MapEntry<CombinatorKind, (List<int>, bool, bool, bool)> row
        in table.entries) {
      final CombinatorKind k = row.key;
      final (List<int> counts, bool fn, bool time, bool retry) = row.value;
      final FunctionRef? t = fn ? f : null;
      final Duration? d = time ? ms : null;
      for (int n = 0; n <= 5; n++) {
        if (counts.contains(n)) {
          expect(
            TransformEdge.stage(
              k,
              inputs(n),
              transformer: t,
              duration: d,
            ).inputs,
            hasLength(n),
            reason: '${k.name} with $n inputs',
          );
        } else {
          expect(
            () =>
                TransformEdge.stage(k, inputs(n), transformer: t, duration: d),
            rejects('inputs'),
            reason: '${k.name} with $n inputs',
          );
        }
      }
      final List<EdgeInput> some = inputs(counts.first);
      expect(
        () => TransformEdge.stage(
          k,
          some,
          transformer: fn ? null : f,
          duration: d,
        ),
        rejects('transformer'),
        reason: k.name,
      );
      expect(
        () => TransformEdge.stage(
          k,
          some,
          transformer: t,
          duration: time ? null : ms,
        ),
        rejects('duration'),
        reason: k.name,
      );
      if (retry) {
        expect(
          TransformEdge.stage(k, some, transformer: t, retry: f).retry,
          f,
          reason: k.name,
        );
      } else {
        expect(
          () => TransformEdge.stage(
            k,
            some,
            transformer: t,
            duration: d,
            retry: f,
          ),
          rejects('retry'),
          reason: k.name,
        );
      }
    }
  });

  test('G5 a negative duration names the duration and reduceInto names the '
      'combinator', () {
    expect(
      () => TransformEdge.stage(
        CombinatorKind.timeout,
        inputs(1),
        duration: const Duration(microseconds: -1),
      ),
      rejects('duration'),
    );
    expect(
      () => TransformEdge.stage(
        CombinatorKind.reduceInto,
        inputs(1),
        transformer: f,
      ),
      rejects('combinator'),
    );
  });

  test('G5 a stage edge holds what it was given and no output', () {
    final TransformEdge e = TransformEdge.stage(
      CombinatorKind.switchMap,
      inputs(1),
      transformer: f,
      retry: FunctionRef.named('r'),
    );
    expect(e.combinator, CombinatorKind.switchMap);
    expect(e.inputs, inputs(1));
    expect(e.transformer, f);
    expect(e.duration, isNull);
    expect(e.retry, FunctionRef.named('r'));
    expect(e.output, isNull);
    expect(e.isSink, isFalse);
  });

  test('G5 a write takes a topic of any variant; a reduceInto holds its '
      'reducer and nothing else', () {
    for (final TopicVariant v in TopicVariant.values) {
      final TransformEdge w = TransformEdge.write(
        ref('w', v),
        const StageInput(0),
      );
      expect(w.output, ref('w', v));
      expect(w.isSink, isTrue);
      expect(w.isStateBearing, isFalse);
    }
    final TransformEdge r = TransformEdge.reduceInto(
      ref('s', TopicVariant.state),
      const StageInput(2),
      f,
    );
    expect(r.inputs, <EdgeInput>[const StageInput(2)]);
    expect(r.duration, isNull);
    expect(r.retry, isNull);
    expect(
      () => TransformEdge.reduceInto(ref('e'), const StageInput(0), f),
      rejects('topic'),
    );
  });

  test('G3 an edge keeps an unmodifiable copy of its inputs', () {
    final List<EdgeInput> given = inputs(2);
    final TransformEdge e = TransformEdge.stage(CombinatorKind.merge, given);
    given.add(TopicInput(ref('late')));
    expect(e.inputs, inputs(2));
    expect(() => e.inputs.add(const StageInput(0)), throwsUnsupportedError);
    expect(
      () => TransformEdge.write(ref('w'), const StageInput(0)).inputs.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => TransformEdge.reduceInto(
        ref('s', TopicVariant.state),
        const StageInput(0),
        f,
      ).inputs.clear(),
      throwsUnsupportedError,
    );
  });

  test('G7 edge inputs are equal, with equal hash codes, exactly when their '
      'fields are', () {
    expect(TopicInput(ref('a')), TopicInput(ref('a')));
    expect(TopicInput(ref('a')).hashCode, TopicInput(ref('a')).hashCode);
    expect(
      TopicInput(ref('a'), dedup: Dedup.none),
      TopicInput(ref('a'), dedup: Dedup.none),
    );
    expect(
      TopicInput(ref('a'), dedup: Dedup.none),
      isNot(TopicInput(ref('a'), dedup: Dedup.equality)),
    );
    expect(TopicInput(ref('a')), isNot(TopicInput(ref('b'))));
    expect(StageInput(<int>[1].single), const StageInput(1));
    expect(StageInput(<int>[1].single).hashCode, const StageInput(1).hashCode);
    expect(const StageInput(1), isNot(TopicInput(ref('a'))));
  });

  test('G7 edges are equal, with equal hash codes, exactly when all six '
      'fields are, inputs element by element', () {
    TransformEdge make({
      CombinatorKind k = CombinatorKind.debounce,
      List<EdgeInput>? given,
      Duration d = ms,
    }) => TransformEdge.stage(k, given ?? inputs(1), duration: d);
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(<TransformEdge>{make(), make()}, hasLength(1));
    expect(make(k: CombinatorKind.delay), isNot(make()));
    expect(make(given: <EdgeInput>[TopicInput(ref('x'))]), isNot(make()));
    expect(make(d: const Duration(microseconds: 1001)), isNot(make()));
    expect(
      TransformEdge.stage(CombinatorKind.merge, inputs(2)),
      isNot(
        TransformEdge.stage(CombinatorKind.merge, inputs(2).reversed.toList()),
      ),
    );
    expect(
      TransformEdge.stage(CombinatorKind.map, inputs(1), transformer: f),
      isNot(
        TransformEdge.stage(
          CombinatorKind.map,
          inputs(1),
          transformer: const FunctionRef.anonymous(),
        ),
      ),
    );
    final TopicRef s = ref('s', TopicVariant.state);
    expect(
      TransformEdge.write(s, const StageInput(0)),
      TransformEdge.write(s, const StageInput(0)),
    );
    expect(
      TransformEdge.write(s, const StageInput(0)),
      isNot(TransformEdge.reduceInto(s, const StageInput(0), f)),
    );
    expect(
      TransformEdge.write(s, const StageInput(0)),
      isNot(TransformEdge.write(ref('s'), const StageInput(0))),
    );
  });
}
