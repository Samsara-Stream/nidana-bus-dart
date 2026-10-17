// Stand-in app types for the topic-codegen@v1 fixture (experiment only).
final class CartEvent {
  const CartEvent(this.sku);
  final String sku;
}

final class CartItems {
  const CartItems._(this.skus);
  static const CartItems empty = CartItems._(<String>[]);
  final List<String> skus;
}

final class SubmitOrder {
  const SubmitOrder();
}

final class CheckoutUi {
  const CheckoutUi.idle();
}

final class OrderSummary {
  const OrderSummary(this.id);
  final String id;
}
