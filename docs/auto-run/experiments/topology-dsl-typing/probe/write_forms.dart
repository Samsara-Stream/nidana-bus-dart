// Probe: each line writes or folds a handle of one value type into a topic of
// another. The run records which lines the analyzer reports and with which
// code (see ../run.sh and ../output.txt).
import 'package:topology_dsl_typing/forms.dart';

final class CartItems {
  const CartItems();
}

final class UiState {
  const UiState();
}

sealed class Animal {
  const Animal();
}

final class Cat extends Animal {
  const Cat();
}

final class AuthEvent {
  const AuthEvent();
}

UiState reduceUi(UiState s, AuthEvent e) => s;
String combineToString(CartItems c, UiState u) => '';

const StateTopic<UiState> uiState = StateTopic<UiState>('checkout.ui-state', UiState());
const StateTopic<Animal> pet = StateTopic<Animal>('home.pet', Cat());
const StateTopic<Cat> cat = StateTopic<Cat>('home.cat', Cat());
const EventTopic<AuthEvent> authEvents = EventTopic<AuthEvent>('auth.events');

void probe(Builder b, InvBuilder ib) {
  final Handle<String> strings = Handle<String>.make();
  final Handle<Cat> cats = Handle<Cat>.make();
  final Handle<Animal> animals = Handle<Animal>.make();
  final Handle<AuthEvent> events = Handle<AuthEvent>.make();
  final InvHandle<String> invStrings = Inv.make<String>();
  final InvHandle<Cat> invCats = Inv.make<Cat>();

  // F1: unrelated types (Spec §4.2's case)
  b.write(uiState, strings); // line A1
  // F1: a subtype stream into a supertype topic (sound)
  b.write(pet, cats); // line A2
  // F1: a supertype stream into a subtype topic (unsound)
  b.write(cat, animals); // line A3

  // F2
  b.write2(uiState, strings); // line B1
  b.write2(pet, cats); // line B2
  b.write2(cat, animals); // line B3

  // F3
  strings.writeTo(uiState); // line C1
  cats.writeTo(pet); // line C2
  animals.writeTo(cat); // line C3

  // F4
  b.writeCurried(uiState).from(strings); // line D1
  b.writeCurried(pet).from(cats); // line D2
  b.writeCurried(cat).from(animals); // line D3

  // F5
  ib.write(uiState, invStrings); // line E1
  ib.write(pet, invCats); // line E2

  // F6
  b.writeLazy(uiState, () => strings); // line F1
  b.writeLazy(pet, () => cats); // line F2
  b.writeLazy(cat, () => animals); // line F3

  // F9
  uiState.writeFrom(b, strings); // line G1
  pet.writeFrom(b, cats); // line G2
  cat.writeFrom(b, animals); // line G3

  // reduceInto
  b.reduceInto(uiState, events, reduceUi); // line H1 (well typed)
  b.reduceInto(pet, events, reduceUi); // line H2 (reducer of another state type)
  b.reduceInto(uiState, strings, reduceUi); // line H3 (events of another type)
  // ignore: unused_local_variable
  final Handle<int> wrongCombine = b.combine2(Handle<CartItems>.make(), Handle<UiState>.make(), combineToString); // line H4
}
