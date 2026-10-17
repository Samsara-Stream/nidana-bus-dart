// covers: G5, G6
// A state builder takes a state topic only and a replay builder a replay
// topic only (Spec §2.5: no current value on an event topic), and the value a
// builder renders is typed by its topic.
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

const StateTopic<int> count = StateTopic<int>(name: 'reject.count', initial: 0);
const EventTopic<int> taps = EventTopic<int>(name: 'reject.taps');
const ReplayTopic<int> recent = ReplayTopic<int>(name: 'reject.recent', bufferSize: 3);

Widget show(int v) => Text('$v');

List<Widget> misuse() => <Widget>[
      // expect-diagnostic: argument_type_not_assignable
      StateTopicBuilder<int>(topic: taps, builder: (BuildContext c, int v) => show(v)),
      // expect-diagnostic: argument_type_not_assignable
      StateTopicBuilder<int>(topic: recent, builder: (BuildContext c, int v) => show(v)),
      // expect-diagnostic: argument_type_not_assignable
      ReplayTopicBuilder<int>(topic: count, builder: (BuildContext c, List<int> v) => show(v.length)),
      // expect-diagnostic: argument_type_not_assignable
      ReplayTopicBuilder<int>(topic: taps, builder: (BuildContext c, List<int> v) => show(v.length)),
      // expect-diagnostic: argument_type_not_assignable
      StateTopicBuilder<int>(topic: count, builder: (BuildContext c, String v) => Text(v)),
      // expect-diagnostic: argument_type_not_assignable
      StateTopicBuilder(topic: count, builder: (BuildContext c, v) => Text(v)),
    ];
