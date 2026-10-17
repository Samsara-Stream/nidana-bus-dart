// covers: G7
// A page publisher claims state topics only (Spec §2.4, §3.11): a page
// publishes events freely and claims nothing else.
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

const EventTopic<int> taps = EventTopic<int>(name: 'reject.taps');
const ReplayTopic<int> recent = ReplayTopic<int>(name: 'reject.recent', bufferSize: 3);

List<Widget> misuse() => <Widget>[
      // expect-diagnostic: set_element_type_not_assignable
      PageScope(route: 'p', writes: {taps}, child: const SizedBox()),
      // expect-diagnostic: set_element_type_not_assignable
      PageScope(route: 'p', writes: {recent}, child: const SizedBox()),
    ];
