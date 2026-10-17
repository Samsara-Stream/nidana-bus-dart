// Reject fixture for topic-model@v1 G27: a state topic is not a multi-writer
// topic, so a publish path typed over MultiWriterTopic, as bus-api@v1's
// publisher-less publish and Publisher.publish are, does not take one.
// covers: G27
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

/// The shape of a publish path that takes no ownership claim.
void publishTo<T>(MultiWriterTopic<T> topic, T value) {}

void misuse(StateTopic<int> state, Topic<int> topic) {
  // expect-diagnostic: argument_type_not_assignable
  publishTo<int>(state, 1);
  // expect-diagnostic: argument_type_not_assignable
  publishTo(state, 1);
  // expect-diagnostic: argument_type_not_assignable
  publishTo<int>(topic, 1);
  // expect-diagnostic: invalid_assignment
  final MultiWriterTopic<int> asMultiWriter = state;
  asMultiWriter.name;
}

// expect-diagnostic: set_element_type_not_assignable
final Set<MultiWriterTopic<int>> writable = <MultiWriterTopic<int>>{const StateTopic<int>(name: 'a.count', initial: 0)};
