// covers: G1
import 'package:demo_contracts/demo_contracts.dart';

Object misuse(EventTopic<int> topic) {
  final int unused = 'not an int';
  // expect-diagnostic: undefined_getter
  return topic.initial;
}
