// Positive compile fixture: must analyze clean against the producer package.
import 'package:exp_a/exp_a.dart';

int useSurface() {
  const t = StateTopicX<int>('a.b', 0);
  return t.currentValue();
}
