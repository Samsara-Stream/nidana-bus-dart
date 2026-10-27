// What the declarations of topology-ir@v1's The IR and Function references
// fix before any body computes (nidana.model D3): the combinator order, the
// arguments the inputs and references keep, and the edge index assertion.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

const TopicRef taps = TopicRef(
  name: 'demo.taps',
  variant: TopicVariant.event,
  typeName: 'int',
);

void main() {
  test('CombinatorKind has eighteen values, in combinator-table order', () {
    expect(CombinatorKind.values.map((CombinatorKind k) => k.name), <String>[
      'map',
      'filter',
      'combine',
      'withLatestFrom',
      'merge',
      'switchMap',
      'scan',
      'pairwise',
      'distinctUntilChanged',
      'debounce',
      'throttle',
      'delay',
      'sample',
      'buffer',
      'timeout',
      'catchError',
      'rawEngine',
      'reduceInto',
    ]);
  });

  test('a TopicInput keeps its topic, and its dedup, null by default', () {
    const TopicInput kept = TopicInput(taps);
    const TopicInput overridden = TopicInput(taps, dedup: Dedup.none);
    expect(kept.topic, same(taps));
    expect(kept.dedup, isNull);
    expect(overridden.dedup, Dedup.none);
  });

  test('a StageInput keeps its index; a negative one fails an assertion', () {
    expect(const StageInput(0).edge, 0);
    expect(const StageInput(3).edge, 3);
    int index = -1;
    expect(() => StageInput(index), throwsA(isA<AssertionError>()));
    index = -7;
    expect(() => StageInput(index), throwsA(isA<AssertionError>()));
  });

  test('FunctionRef.named keeps its name, and an anonymous one has none', () {
    expect(FunctionRef.named('buildTotal').name, 'buildTotal');
    expect(const FunctionRef.anonymous().name, isNull);
  });
}
