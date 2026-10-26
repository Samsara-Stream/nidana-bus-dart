// packages/nidana_contract_check/test/ids_test.dart
import 'package:nidana_contract_check/src/ids.dart';
import 'package:test/test.dart';

void main() {
  group('parseIdList', () {
    test('reads ids and ranges separated by ", " and " and "', () {
      expect(parseIdList('G1'), <int>{1});
      expect(parseIdList('G19, G20'), <int>{19, 20});
      expect(parseIdList('G1, G3 to G7'), <int>{1, 3, 4, 5, 6, 7});
      expect(parseIdList('G3 to G8, G12, G13 and G15 to G18'),
          <int>{3, 4, 5, 6, 7, 8, 12, 13, 15, 16, 17, 18});
    });
    test('is null for anything else', () {
      for (final String text in <String>[
        '', 'the closed families', 'G0', 'G01', 'g1', 'G1,G2', 'G1 , G2',
        'G1.', 'G5 to G5', 'G7 to G3', 'G1, ', 'G1 and', 'topic-model/G1',
      ]) {
        expect(parseIdList(text), isNull, reason: text);
      }
    });
  });
  test('parseGuaranteeId reads exactly one id', () {
    expect(parseGuaranteeId('G12'), 12);
    for (final String text in <String>['G0', 'G', 'G1a', ' G1', 'topic-model/G1', 'G1 to G2']) {
      expect(parseGuaranteeId(text), isNull, reason: text);
    }
  });
  test('formatIds lists ids in ascending order', () {
    expect(formatIds(<int>{5, 1, 3}), 'G1, G3, G5');
  });
}
