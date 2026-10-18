// A minimal example app: one registry and one service that claims the state
// topic it owns, written as nidana-checks@v1 Claim sites resolve them (a
// literal source and a set literal of registry fields).
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

/// The example's topics.
abstract final class PaymentTopics {
  static const EventTopic<int> request =
      EventTopic<int>(name: 'payment.request', sensitive: true);
  static const StateTopic<int> result =
      StateTopic<int>(name: 'payment.result', initial: 0, sensitive: true);
}

/// The service that owns `payment.result` (Spec §3.11, shell-owned state).
final class PaymentService {
  PaymentService(Bus bus)
      : _publisher = bus.publisher(
          const ServiceSource('payment'),
          writes: <StateTopic<Object?>>{PaymentTopics.result},
        );

  final Publisher _publisher;

  void settle(int amount) =>
      _publisher.writer(PaymentTopics.result).publish(amount);
}
