final class CartItems {
  const CartItems();
  static const CartItems empty = CartItems();
}

final class CartItem {
  const CartItem();
}

final class CheckoutDraft {
  const CheckoutDraft();
  static const CheckoutDraft empty = CheckoutDraft();
}

enum Connectivity { unknown, online, offline }
