// Reject fixture for demo-api G1: an event topic has no current value.
// covers: G1
import 'package:demo_contracts/demo_contracts.dart';

Object misuse(EventTopic<int> topic) {
  // expect-diagnostic: undefined_getter
  return topic.initial;
}
