import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

import 'model.dart';

abstract final class CartTopics {
  static final StateTopic<CartItems> items = StateTopic<CartItems>(name: 'cart.items', initial: CartItems.empty);
  static final EventTopic<CartItem> added = EventTopic<CartItem>(name: 'cart.added');
  static final StateTopic<int> badge = StateTopic<int>(name: 'cart.badge', initial: 0);
  static final StateTopic<CheckoutDraft> draft =
      StateTopic<CheckoutDraft>(name: 'checkout.draft', initial: CheckoutDraft.empty);
  static final StateTopic<int> total = StateTopic<int>(name: 'checkout.total', initial: 0);
}

abstract final class NetworkTopics {
  static const StateTopic<Connectivity> connectivity =
      StateTopic<Connectivity>(name: 'network.connectivity', initial: Connectivity.unknown);
}
