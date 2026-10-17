// Reject fixture for topic-model@v1 G10: a const replay topic declaration
// with a buffer smaller than one value does not compile.
// covers: G10
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

// expect-diagnostic: const_eval_throws_exception
const ReplayTopic<int> empty = ReplayTopic<int>(name: 'chat.messages', bufferSize: 0);
