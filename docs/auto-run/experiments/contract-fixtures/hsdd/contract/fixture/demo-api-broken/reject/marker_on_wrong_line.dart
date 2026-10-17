// covers: G1
import 'package:demo_contracts/demo_contracts.dart';

// expect-diagnostic: undefined_getter
Object misuse(EventTopic<int> topic) {
  return topic.initial;
}
