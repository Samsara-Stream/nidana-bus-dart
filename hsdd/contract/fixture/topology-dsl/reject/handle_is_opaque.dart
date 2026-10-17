// Reject fixture for topology-dsl@v1 G1: the read handle is opaque (Spec §6.1).
// It has no synchronous value accessor, so reading a current value to decide
// wiring does not compile, and it is not a Stream, so engine operators and
// combinators cannot be applied to it (root D6).
// covers: G1
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class CartItems {
  const CartItems();
}

sealed class AuthState {
  const AuthState();
}

final class Initializing extends AuthState {
  const Initializing();
}

final class Authenticated extends AuthState {
  const Authenticated();
}

final class CheckoutUi {
  const CheckoutUi();
}

const StateTopic<CartItems> cartItems =
    StateTopic<CartItems>(name: 'checkout.cart-items', initial: CartItems());
const StateTopic<AuthState> authState =
    StateTopic<AuthState>(name: 'auth.state', initial: Initializing());
const StateTopic<CheckoutUi> checkoutUi =
    StateTopic<CheckoutUi>(name: 'checkout.ui-state', initial: CheckoutUi());

CheckoutUi buildCheckoutUi(CartItems cart, AuthState auth) => const CheckoutUi();

/// The signature of RxDart's Rx.combineLatest2, restated so that this fixture
/// imports no engine.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combiner,
) =>
    const Stream<Never>.empty();

void inspect(Object? value) {}

Stream<AuthState>? escaped;

void declareCheckout(TopologyBuilder b) {
  final TopicStream<CartItems> cart = b.read(cartItems);
  final TopicStream<AuthState> auth = b.read(authState);

  // Reading a current value to decide which streams to wire.
  // expect-diagnostic: undefined_getter
  if (auth.value is Authenticated) {
    b.write(checkoutUi, b.combine2(cart, auth, buildCheckoutUi));
  }
  // expect-diagnostic: undefined_getter
  inspect(auth.valueOrNull);
  // expect-diagnostic: undefined_getter
  inspect(auth.first);

  // A handle is not a Stream.
  // expect-diagnostic: undefined_method
  auth.listen((AuthState s) {});
  // expect-diagnostic: invalid_assignment
  escaped = auth;
  combineLatest2(
    // expect-diagnostic: argument_type_not_assignable
    cart,
    // expect-diagnostic: argument_type_not_assignable
    auth,
    buildCheckoutUi,
  );
}
