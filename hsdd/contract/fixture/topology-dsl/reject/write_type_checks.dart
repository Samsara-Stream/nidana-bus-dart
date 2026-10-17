// Reject fixture for topology-dsl@v1 G3: a write type-checks against its topic
// (Spec §4.2). write(topic, stream) compiles only when the stream's value type
// is the topic's value type or a subtype of it; inference does not widen the
// topic's type to admit the stream.
// covers: G3
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class CartItems {
  const CartItems();
}

final class CheckoutUi {
  const CheckoutUi();
}

sealed class Pet {
  const Pet();
}

final class Cat extends Pet {
  const Cat();
}

const StateTopic<CartItems> cartItems =
    StateTopic<CartItems>(name: 'checkout.cart-items', initial: CartItems());
const StateTopic<CheckoutUi> checkoutUi =
    StateTopic<CheckoutUi>(name: 'checkout.ui-state', initial: CheckoutUi());
const StateTopic<Pet> pet = StateTopic<Pet>(name: 'home.pet', initial: Cat());
const StateTopic<Cat> cat = StateTopic<Cat>(name: 'home.cat', initial: Cat());
const EventTopic<String> labels = EventTopic<String>(name: 'home.labels');

void declare(TopologyBuilder b) {
  final TopicStream<CartItems> cart = b.read(cartItems);
  final TopicStream<Pet> pets = b.read(pet);

  // An unrelated value type.
  // expect-diagnostic: could_not_infer
  b.write(checkoutUi, cart);
  // expect-diagnostic: could_not_infer
  b.write(labels, cart);
  // A supertype into a topic of its subtype.
  // expect-diagnostic: could_not_infer
  b.write(cat, pets);
}
