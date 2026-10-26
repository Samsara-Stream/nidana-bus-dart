// packages/nidana_contract_check/test/ids_test.dart
import 'package:nidana_contract_check/src/ids.dart';
import 'package:test/test.dart';

void main() {
  group('parseIdList', () {
    test('reads ids and ranges separated by ", " and " and "', () {
      expect(parseIdList('G1'), <int>{1});
      expect(parseIdList('G19, G20'), <int>{19, 20});
      expect(parseIdList('G1, G3 to G7'), <int>{1, 3, 4, 5, 6, 7});
      expect(parseIdList('G3 to G8, G12, G13 and G15 to G18'), <int>{
        3,
        4,
        5,
        6,
        7,
        8,
        12,
        13,
        15,
        16,
        17,
        18,
      });
    });
    test('is null for anything else', () {
      for (final String text in <String>[
        '',
        'the closed families',
        'G0',
        'G01',
        'g1',
        'G1,G2',
        'G1 , G2',
        'G1.',
        'G5 to G5',
        'G7 to G3',
        'G1, ',
        'G1 and',
        'topic-model/G1',
      ]) {
        expect(parseIdList(text), isNull, reason: text);
      }
    });
  });
  test('parseGuaranteeId reads exactly one id', () {
    expect(parseGuaranteeId('G12'), 12);
    for (final String text in <String>[
      'G0',
      'G',
      'G1a',
      ' G1',
      'topic-model/G1',
      'G1 to G2',
    ]) {
      expect(parseGuaranteeId(text), isNull, reason: text);
    }
  });
  test('formatIds lists ids in ascending order', () {
    expect(formatIds(<int>{5, 1, 3}), 'G1, G3, G5');
  });
  test(
    'a range spans fewer than 1000 ids; a wider one is no list, at once',
    () {
      expect(parseIdList('G1 to G1000'), hasLength(1000));
      expect(parseIdList('G1 to G1001'), isNull);
      expect(parseIdList('G3, G1 to G100000000'), isNull);
    },
  );
  test('formatIds writes a run of three or more ids as a range', () {
    expect(formatIds(<int>{1, 2}), 'G1, G2');
    expect(
      formatIds(<int>{10, 1, 2, 3, 5, 7, 8, 9}),
      'G1 to G3, G5, G7 to G10',
    );
    expect(parseIdList(formatIds(<int>{10, 1, 2, 3, 5, 7, 8, 9})), <int>{
      1,
      2,
      3,
      5,
      7,
      8,
      9,
      10,
    });
  });
  test('the bound is per range; a run of more than 1000 ids prints as several ranges', () {
    expect(parseIdList('G1 to G1000, G1001 to G2000'), hasLength(2000));
    final Set<int> run = <int>{for (int id = 1; id <= 2002; id++) id};
    expect(formatIds(run), 'G1 to G1000, G1001 to G2000, G2001, G2002');
    expect(parseIdList(formatIds(run)), run);
    expect(formatIds(<int>[3, 1, 2, 2]), 'G1 to G3');
  });
}
