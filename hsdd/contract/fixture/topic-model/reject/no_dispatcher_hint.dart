// Reject fixture for topic-model@v1 G5: no topic declaration takes a
// dispatcher hint (Spec §3.6, §11.1; decides OQ-M3).
// covers: G5
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

// expect-diagnostic: undefined_named_parameter
final StateTopic<int> state = StateTopic<int>(name: 'ui.count', initial: 0, dispatcher: 'main');

// expect-diagnostic: undefined_named_parameter
final EventTopic<int> event = EventTopic<int>(name: 'ui.tapped', dispatcher: 'main');

// expect-diagnostic: undefined_named_parameter
final ReplayTopic<int> replay = ReplayTopic<int>(name: 'ui.log', bufferSize: 1, dispatcher: 'main');
