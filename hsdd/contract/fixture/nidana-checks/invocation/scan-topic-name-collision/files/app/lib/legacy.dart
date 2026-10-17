import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

/// Hand-written next to the shared registry: auth.state again, as an event.
abstract final class LegacyTopics {
  static const EventTopic<String> authState = EventTopic<String>(name: 'auth.state');
}

/// A top-level declaration counts as a declaration too: cart.items again.
final ReplayTopic<int> cartItems = ReplayTopic<int>(name: 'cart.items', bufferSize: 1);

const String _profileName = 'profile.current';

/// Its name is not a string literal: reported unresolved, left to the runtime.
abstract final class ProfileTopics {
  static const StateTopic<String> current = StateTopic<String>(name: _profileName, initial: '');
}
