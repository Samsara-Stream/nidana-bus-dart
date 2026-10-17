import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

final class SessionToken {
  const SessionToken();
}

abstract final class SessionTopics {
  // Raised to error.
  static const StateTopic<SessionToken> token =
      StateTopic<SessionToken>(name: 'session.token', initial: SessionToken());
  static const EventTopic<int> ping = EventTopic<int>(name: 'session.ping');
}

// Lowered to info.
final Bus appBus = Bus();

// Suppressed for this line.
// ignore: nidana_dart_lint/global_bus_accessor
final Bus otherBus = Bus();

void ping(Bus bus) {
  // Disabled.
  bus.observe(EventTopic<int>(name: 'session.raw'));
  // Default severity.
  bus.publish<num, int>(SessionTopics.ping, 1);
}
