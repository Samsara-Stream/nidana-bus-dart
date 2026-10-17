import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

// Test code is not application code: none of these is reported.
late TestBus bus;

final StateTopic<String> sessionToken = StateTopic<String>(name: 'test.session', initial: '');

final class AccessToken {
  const AccessToken();
}

void publishInline(Bus target) {
  target.publish<Object?, int>(EventTopic<Object?>(name: 'test.raw'), 1);
  target.observe(EventTopic<AccessToken>(name: 'test.token'));
}
