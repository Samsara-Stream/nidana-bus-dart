// Reject fixture for topic-model@v1 G2: only a state topic carries an initial
// value and a dedup policy, and no other variant stands in where a state topic
// is required (the parameter type of getCurrentValue, Spec §2.5).
// covers: G2
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

T currentValue<T>(StateTopic<T> topic) => topic.createInitial();

void misuse(EventTopic<int> event, ReplayTopic<int> replay) {
  // expect-diagnostic: undefined_method
  event.createInitial();
  // expect-diagnostic: undefined_method
  replay.createInitial();
  // expect-diagnostic: undefined_getter
  event.dedup;
  // expect-diagnostic: undefined_getter
  replay.dedup;
  // expect-diagnostic: argument_type_not_assignable
  currentValue<int>(event);
  // expect-diagnostic: invalid_assignment
  final StateTopic<int> asState = replay;
  asState.createInitial();
}

// expect-diagnostic: undefined_named_parameter
final EventTopic<int> dedupedEvent = EventTopic<int>(name: 'a.tapped', dedup: Dedup.none);

// expect-diagnostic: undefined_named_parameter
final ReplayTopic<int> dedupedReplay = ReplayTopic<int>(name: 'a.log', bufferSize: 1, dedup: Dedup.none);
