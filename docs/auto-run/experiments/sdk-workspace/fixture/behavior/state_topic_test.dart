// Behavior fixture: a package:test library run from the workspace root.
import 'package:exp_a/exp_a.dart';
import 'package:test/test.dart';

void main() {
  test('a state topic starts at its declared initial value', () {
    expect(const StateTopicX<int>('a.b', 7).currentValue(), 7);
  });
}
