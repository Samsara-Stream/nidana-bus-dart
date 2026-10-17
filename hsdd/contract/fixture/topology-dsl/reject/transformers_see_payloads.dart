// Reject fixture for topology-dsl@v1 G5: every function a combinator takes,
// other than the raw-engine operator, is typed over payload types (Spec §2.4,
// §3.5, §6.2). A transformer over the envelope or the lineage, or one whose
// types do not fit the handles, does not compile.
// covers: G5
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class CartItems {
  const CartItems();
}

final class AuthState {
  const AuthState();
}

final class CheckoutUi {
  const CheckoutUi();
}

CheckoutUi buildCheckoutUi(CartItems cart, AuthState auth) => const CheckoutUi();

const StateTopic<CartItems> cartItems =
    StateTopic<CartItems>(name: 'checkout.cart-items', initial: CartItems());
const StateTopic<AuthState> authState =
    StateTopic<AuthState>(name: 'auth.state', initial: AuthState());

void declare(TopologyBuilder b) {
  final TopicStream<CartItems> cart = b.read(cartItems);
  final TopicStream<AuthState> auth = b.read(authState);

  // expect-diagnostic: argument_type_not_assignable
  cart.map<String>((MessageEnvelope<CartItems> envelope) => envelope.id);
  // expect-diagnostic: argument_type_not_assignable
  cart.filter((MessageEnvelope<CartItems> envelope) => envelope.sensitive);
  // expect-diagnostic: argument_type_not_assignable
  cart.scan(0, (int count, Lineage lineage) => count + 1);
  // expect-diagnostic: argument_type_not_assignable
  b.combine2<CartItems, AuthState, CheckoutUi>(cart, auth, (MessageEnvelope<CartItems> c, AuthState a) => const CheckoutUi());
  // Arguments in the wrong order.
  // expect-diagnostic: argument_type_not_assignable
  cart.withLatestFrom<AuthState, CheckoutUi>(auth, (AuthState a, CartItems c) => const CheckoutUi());
  // A binary transformer where a unary one is required.
  // expect-diagnostic: argument_type_not_assignable
  cart.map<CheckoutUi>(buildCheckoutUi);
}
