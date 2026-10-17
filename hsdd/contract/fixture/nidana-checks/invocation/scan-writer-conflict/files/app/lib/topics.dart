import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class CartItems {
  const CartItems();
}

final class CheckoutDraft {
  const CheckoutDraft();
}

abstract final class CartTopics {
  static const StateTopic<CartItems> items = StateTopic<CartItems>(name: 'cart.items', initial: CartItems());
  static const StateTopic<CheckoutDraft> draft =
      StateTopic<CheckoutDraft>(name: 'checkout.draft', initial: CheckoutDraft());
}

abstract final class ProfileTopics {
  static const StateTopic<String> current = StateTopic<String>(name: 'profile.current', initial: '');
}
