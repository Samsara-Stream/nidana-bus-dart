import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

/// Accepted: the whole initializer of a static field.
abstract final class CartTopics {
  static final StateTopic<int> count = StateTopic<int>(name: 'cart.count', initial: 0);
  static const EventTopic<String> added = EventTopic<String>(name: 'cart.added');

  /// Reported: a static field whose initializer is not the creation itself.
  static final EventTopic<String> removed =
      _legacy ? EventTopic<String>(name: 'cart.removed-v1') : EventTopic<String>(name: 'cart.removed');
}

const bool _legacy = false;

/// Reported: a top-level variable is not a registry.
final ReplayTopic<String> recent = ReplayTopic<String>(name: 'cart.recent', bufferSize: 3);

void watch(Bus bus, String user) {
  // Reported: a topic named at the use site.
  bus.observe(EventTopic<String>(name: 'cart.added'));
  // Reported: a local variable.
  final StateTopic<int> local = StateTopic<int>.computed(name: 'cart' '.count', initial: zero);
  bus.observe(local);
  // Reported: an interpolated name is a string literal too.
  bus.observe(EventTopic<String>(name: 'cart.$user'));
  // Accepted: a name that is not a string literal.
  bus.observe(EventTopic<String>(name: CartTopics.added.name));
}

int zero() => 0;
