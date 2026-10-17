// Negative compile fixture.
// expect-diagnostic: undefined_method
import 'package:exp_a/exp_a.dart';

void misuse() {
  const e = EventTopicX<int>('a.e');
  e.currentValue();
}
