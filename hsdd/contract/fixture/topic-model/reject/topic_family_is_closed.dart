// Reject fixture for topic-model@v1 G1: the topic family is closed. No type
// outside the library extends or implements a topic, and a switch that omits
// a variant does not compile.
// covers: G1
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class LocalStateTopic extends StateTopic<int> {
  const LocalStateTopic() : super(name: 'local.count', initial: 0);
}

// expect-diagnostic: invalid_use_of_type_outside_library
final class CustomTopic implements Topic<int> {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// expect-diagnostic: non_exhaustive_switch_expression
String describe(Topic<int> topic) => switch (topic) {
      StateTopic<int>() => 'state',
      EventTopic<int>() => 'event',
    };
