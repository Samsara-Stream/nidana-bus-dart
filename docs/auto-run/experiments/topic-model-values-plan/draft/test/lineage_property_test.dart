// Property tests of topic-model@v1's Lineage.combine and
// Lineage.withLatestFrom (G4, G19, G20) over lineages generated from fixed
// seeds with dart:math, so that a failure names the seed that reproduces it
// and the package takes no dependency beyond test (ADR-002 item 3).
import 'dart:math';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:test/test.dart';

/// How many seeds each property runs.
const int seeds = 500;

/// The correlations a generated lineage draws from; null is a root lineage
/// with no correlation.
const List<String?> correlations = <String?>[null, 'c-a', 'c-b', 'c-c'];

/// The parent correlation ids a generated envelope draws from.
const List<String> parentPool = <String>['p-1', 'p-2', 'p-3', 'p-4'];

/// One generated lineage: a root lineage, with or without a correlation,
/// or one caused by an envelope with up to four distinct parents in random
/// order; sensitive or not.
Lineage lineage(Random random, String id) {
  final String? correlation = correlations[random.nextInt(4)];
  final bool sensitive = random.nextBool();
  if (correlation == null || random.nextInt(4) == 0) {
    return Lineage.root(correlationId: correlation, sensitive: sensitive);
  }
  final List<String> parents = (List<String>.of(
    parentPool,
  )..shuffle(random)).sublist(0, random.nextInt(parentPool.length + 1));
  return Lineage.causedBy(
    MessageEnvelope<int>(
      id: id,
      payload: 0,
      correlationId: correlation,
      parentCorrelationIds: parents,
      timestamp: DateTime.utc(2026, 10, 27),
      source: const UnknownSource(),
      sensitive: sensitive,
    ),
  );
}

/// One to five generated inputs.
List<Lineage> inputs(Random random) => <Lineage>[
  for (int i = 0, n = 1 + random.nextInt(5); i < n; i++)
    lineage(random, 'e-$i'),
];

/// The distinct correlation ids of [lineages], in input order.
List<String> distinctCorrelations(List<Lineage> lineages) => <String>[
  ...<String>{for (final Lineage l in lineages) ?l.correlationId},
];

/// Whether [ids] lists each element of [lists], taken in order and
/// flattened, exactly once, at its first occurrence's position.
bool listsFirstOccurrences(List<String> ids, Iterable<List<String>> lists) {
  final List<String> flat = <String>[for (final List<String> l in lists) ...l];
  final List<int> firsts = <int>[for (final String id in ids) flat.indexOf(id)];
  return ids.toSet().length == ids.length &&
      ids.toSet().containsAll(flat) &&
      !firsts.contains(-1) &&
      <int>[for (int i = 1; i < firsts.length; i++) firsts[i] - firsts[i - 1]]
          .every((int step) => step > 0);
}

/// A combine over generated inputs, and the fresh correlation ids it took.
typedef Combination = ({
  List<Lineage> inputs,
  int trigger,
  Lineage out,
  List<String> minted,
});

Combination combined(int seed) {
  final Random random = Random(seed);
  final List<Lineage> ins = inputs(random);
  final int trigger = random.nextInt(ins.length);
  final List<String> minted = <String>[];
  final Lineage out = Lineage.combine(
    ins,
    trigger: trigger,
    freshCorrelationId: () {
      minted.add('fresh-$seed-${minted.length}');
      return minted.last;
    },
  );
  return (inputs: ins, trigger: trigger, out: out, minted: minted);
}

void main() {
  test('G19 combine calls freshCorrelationId exactly once when the '
      'correlated inputs differ, and never otherwise', () {
    for (int seed = 0; seed < seeds; seed++) {
      final Combination c = combined(seed);
      final int distinct = distinctCorrelations(c.inputs).length;
      expect(c.minted, hasLength(distinct > 1 ? 1 : 0), reason: 'seed $seed');
    }
  });

  test('G19 combine takes the causation from the trigger and is sensitive '
      'exactly when an input is', () {
    for (int seed = 0; seed < seeds; seed++) {
      final Combination c = combined(seed);
      expect(
        c.out.causationId,
        c.inputs[c.trigger].causationId,
        reason: 'seed $seed',
      );
      expect(
        c.out.sensitive,
        c.inputs.any((Lineage l) => l.sensitive),
        reason: 'seed $seed',
      );
    }
  });

  test('G4 G19 combine keeps one shared correlation with its inputs\' '
      'parents united in input order, takes a fresh one over the distinct '
      'input correlations in input order, and carries none over none', () {
    final List<int> byDistinct = <int>[0, 0, 0];
    for (int seed = 0; seed < seeds; seed++) {
      final Combination c = combined(seed);
      final List<String> distinct = distinctCorrelations(c.inputs);
      final List<String> parents = c.out.parentCorrelationIds;
      byDistinct[min(distinct.length, 2)]++;
      switch (distinct.length) {
        case 0:
          expect(c.out.correlationId, isNull, reason: 'seed $seed');
          expect(parents, isEmpty, reason: 'seed $seed');
        case 1:
          expect(c.out.correlationId, distinct.single, reason: 'seed $seed');
          expect(
            listsFirstOccurrences(parents, <List<String>>[
              for (final Lineage l in c.inputs)
                if (l.correlationId != null) l.parentCorrelationIds,
            ]),
            isTrue,
            reason: 'seed $seed: $parents',
          );
        default:
          expect(c.out.correlationId, c.minted.single, reason: 'seed $seed');
          expect(
            listsFirstOccurrences(parents, <List<String>>[
              for (final Lineage l in c.inputs)
                if (l.correlationId case final String id) <String>[id],
            ]),
            isTrue,
            reason: 'seed $seed: $parents',
          );
      }
      expect(() => parents.add('x'), throwsUnsupportedError);
    }
    // The seeds reach every branch: no, one and several correlations.
    expect(byDistinct, everyElement(greaterThan(10)));
  });

  test('G20 withLatestFrom keeps the primary causation, correlation and '
      'parents and is sensitive exactly when an input is', () {
    for (int seed = 0; seed < seeds; seed++) {
      final Random random = Random(seed);
      final Lineage primary = lineage(random, 'e-primary');
      final List<Lineage> latest = inputs(random).sublist(1);
      final Lineage out = Lineage.withLatestFrom(primary, latest);
      expect(out.causationId, primary.causationId, reason: 'seed $seed');
      expect(out.correlationId, primary.correlationId, reason: 'seed $seed');
      expect(
        out.parentCorrelationIds,
        primary.parentCorrelationIds,
        reason: 'seed $seed',
      );
      expect(
        out.sensitive,
        primary.sensitive || latest.any((Lineage l) => l.sensitive),
        reason: 'seed $seed',
      );
    }
  });
}
