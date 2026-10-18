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

/// Accepted: the whole initializer of a static field of any declaration kind,
/// whether const, final, late or none of these (G4).
mixin CartMixinTopics {
  static final EventTopic<String> cleared = EventTopic<String>(name: 'cart.cleared');
}

enum CartMode {
  quick;

  static const EventTopic<String> changed = EventTopic<String>(name: 'cart.mode');
}

extension CartTopicNames on String {
  static final EventTopic<String> typed = EventTopic<String>(name: 'cart.typed');
}

extension type CartKey(String value) {
  static final EventTopic<String> picked = EventTopic<String>(name: 'cart.picked');
}

abstract final class CartLateTopics {
  static late final EventTopic<String> opened = EventTopic<String>(name: 'cart.opened');
  static EventTopic<String> closed = EventTopic<String>(name: 'cart.closed');
}
