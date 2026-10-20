// Reject fixture for topology-dsl@v2 G4: reduceInto folds into a StateTopic
// only (Spec §6.3, §7.2), with a reducer over that topic's value type and the
// events' value type.
// covers: G4
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

final class AuthEvent {
  const AuthEvent();
}

AuthState reduceAuth(AuthState state, AuthEvent event) => state;

const StateTopic<AuthState> authState =
    StateTopic<AuthState>(name: 'auth.state', initial: Initializing());
const StateTopic<CartItems> cartItems =
    StateTopic<CartItems>(name: 'checkout.cart-items', initial: CartItems());
const EventTopic<AuthState> authChanges =
    EventTopic<AuthState>(name: 'auth.changes');
const ReplayTopic<AuthState> authLog =
    ReplayTopic<AuthState>(name: 'auth.log', bufferSize: 5);
const EventTopic<AuthEvent> authEvents =
    EventTopic<AuthEvent>(name: 'auth.events');

void declare(TopologyBuilder b) {
  final TopicStream<AuthEvent> events = b.read(authEvents);
  final TopicStream<CartItems> cart = b.read(cartItems);

  // expect-diagnostic: argument_type_not_assignable
  b.reduceInto(authChanges, events, reduceAuth);
  // expect-diagnostic: argument_type_not_assignable
  b.reduceInto(authLog, events, reduceAuth);
  // A reducer over another state type.
  // expect-diagnostic: argument_type_not_assignable
  b.reduceInto<CartItems, AuthEvent>(cartItems, events, reduceAuth);
  // Events of another type.
  // expect-diagnostic: argument_type_not_assignable
  b.reduceInto<AuthState, AuthEvent>(authState, cart, reduceAuth);
}
