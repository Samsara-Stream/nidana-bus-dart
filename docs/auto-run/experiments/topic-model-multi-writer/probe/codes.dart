// Probe, analyzed once before the fixtures were written: which diagnostic
// each candidate misuse of MultiWriterTopic reports on the pinned SDK, and
// whether any line reports more than one.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

void publishTo<T>(MultiWriterTopic<T> topic, T value) {}

void misuse(StateTopic<int> state, Topic<int> topic) {
  publishTo<int>(state, 1); // A explicit type argument, state topic
  publishTo(state, 1); // B inferred type argument, state topic
  publishTo<int>(topic, 1); // C a Topic<int> of unknown variant
  final MultiWriterTopic<int> asMultiWriter = state; // D assignment
  asMultiWriter.name;
  <MultiWriterTopic<int>>[state]; // E list element
  <MultiWriterTopic<int>>{state}; // F set element
}

final class CustomMultiWriterTopic implements MultiWriterTopic<int> { // G implements
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

sealed class LocalSealed implements MultiWriterTopic<int> {} // H sealed implements

final class LocalEvent extends EventTopic<int> { // I extends a final subtype
  const LocalEvent() : super(name: 'a.tapped');
}

String onlyEvent(MultiWriterTopic<int> topic) => switch (topic) { // J omits replay
      EventTopic<int>() => 'event',
    };

String withState(MultiWriterTopic<int> topic) => switch (topic) { // K names a state topic
      StateTopic<int>() => 'state',
      EventTopic<int>() => 'event',
      ReplayTopic<int>() => 'replay',
    };

String byWriters(Topic<int> topic) => switch (topic) { // L exhaustive by the sealed supertype
      StateTopic<int>() => 'one',
      MultiWriterTopic<int>() => 'many',
    };

String byLeaves(Topic<int> topic) => switch (topic) { // M exhaustive by the three leaves
      StateTopic<int>() => 'state',
      EventTopic<int>() => 'event',
      ReplayTopic<int>() => 'replay',
    };

String overlap(Topic<int> topic) => switch (topic) { // N supertype then a leaf it covers
      MultiWriterTopic<int>() => 'many',
      EventTopic<int>() => 'event',
      StateTopic<int>() => 'state',
    };
