// Probe: candidate reject-fixture misuses for topology-dsl@v1, analyzed once
// to learn each code and which lines report more than one diagnostic. Each
// probe line carries a tag `// P{n}`.
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';

final class CartItems {
  const CartItems();
}

final class AuthState {
  const AuthState();
}

final class Ui {
  const Ui();
}

sealed class Animal {
  const Animal();
}

final class Cat extends Animal {
  const Cat();
}

final class Ev {
  const Ev();
}

Ui buildUi(CartItems c, AuthState a) => const Ui();
AuthState reduceAuth(AuthState s, Ev e) => s;
CartItems reduceCart(CartItems s, Ev e) => s;

const StateTopic<CartItems> cartT = StateTopic<CartItems>(name: 'c.items', initial: CartItems());
const StateTopic<AuthState> authT = StateTopic<AuthState>(name: 'a.state', initial: AuthState());
const StateTopic<Ui> uiT = StateTopic<Ui>(name: 'c.ui', initial: Ui());
const StateTopic<Cat> catT = StateTopic<Cat>(name: 'h.cat', initial: Cat());
const EventTopic<Ev> evT = EventTopic<Ev>(name: 'a.events');
const EventTopic<AuthState> authEventsT = EventTopic<AuthState>(name: 'a.changes');
const ReplayTopic<AuthState> authLogT = ReplayTopic<AuthState>(name: 'a.log', bufferSize: 2);

Stream<R> combineLatest2<A, B, R>(Stream<A> a, Stream<B> b, R Function(A a, B b) f) => const Stream.empty();
void takesStream(Stream<Object?> s) {}

void body(TopologyBuilder b, TopicStream<Animal> animals) {
  final TopicStream<CartItems> cart = b.read(cartT);
  final TopicStream<AuthState> auth = b.read(authT);
  final TopicStream<Ev> events = b.read(evT);
  // G1
  final Object? v1 = auth.value; // P1
  final Object? v2 = auth.valueOrNull; // P2
  final Object? v3 = auth.current; // P3
  auth.listen((AuthState s) {}); // P4
  final Stream<AuthState> s1 = auth; // P5
  takesStream(auth); // P6
  final Object? v4 = auth.first; // P7
  final Stream<Ui> u1 = combineLatest2(cart, auth, buildUi); // P8
  final Stream<Ui> u2 = combineLatest2( // P9
      cart, // P10
      auth, // P11
      buildUi);
  // G3
  b.write(uiT, cart); // P12
  b.write(catT, animals); // P13
  // G4
  b.reduceInto(authEventsT, events, reduceAuth); // P14
  b.reduceInto(authLogT, events, reduceAuth); // P15
  b.reduceInto<CartItems, Ev>(cartT, events, reduceAuth); // P16
  b.reduceInto<AuthState, Ev>(authT, cart, reduceAuth); // P17
  b.reduceInto(cartT, events, reduceAuth); // P18
  // G5
  cart.map((MessageEnvelope<CartItems> e) => e.id); // P19
  cart.filter((MessageEnvelope<CartItems> e) => true); // P20
  b.combine2(cart, auth, (MessageEnvelope<CartItems> c, AuthState a) => 1); // P21
  cart.withLatestFrom(auth, (AuthState a, CartItems c) => 1); // P22
  cart.map(buildUi); // P23
  final TopicStream<int> n1 = cart.map((CartItems c) => 'x'); // P24
  cart.scan(0, (int acc, Lineage l) => acc); // P25
  b.combine2<CartItems, AuthState, Ui>(cart, auth, (MessageEnvelope<CartItems> c, AuthState a) => const Ui()); // P26
  // G6
  cart.debounce(300); // P27
  cart.debounce(const Duration(milliseconds: 300), scheduler: 'virtual'); // P28
  cart.throttle(Duration.zero, Zone.current); // P29
  cart.delay(const Duration(milliseconds: 1), Zone.current); // P30
  // G2
  TopologyBuilder(); // P31
  ReadStage<int>(); // P32
}

abstract final class FakeStream implements TopicStream<int> {} // P33
abstract final class FakeBuilder implements TopologyBuilder {} // P34
abstract final class FakeMap implements MapStage<int, int> {} // P35
abstract final class FakeSink implements PlanSink {} // P36
abstract final class FakePlan implements TopologyPlan {} // P37
abstract final class FakeVisitorOk implements StageVisitor<int> {} // P38 (expected ok: an interface)

// G7
final Topology t1 = topology('x', Scope.page); // P39
final Topology t2 = topology('x', (TopologyBuilder b) {}); // P40
final class NoScope extends Topology { // P41
  @override
  String get topologyId => 'x';
  @override
  void declare(TopologyBuilder b) {}
}
final class NoDeclare extends Topology { // P42
  @override
  String get topologyId => 'x';
  @override
  Scope get scope => Scope.page;
}
final TopologyRef r1 = TopologyRef(1); // P43

// G8
final class Faked extends Topology {
  @override
  String get topologyId => 'x';
  @override
  Scope get scope => Scope.page;
  @override
  void declare(TopologyBuilder b) {}
  @override
  TopologyDefinition buildDefinition() => throw UnimplementedError(); // P44
}
abstract final class Pretender implements Topology {} // P45
class Plain extends Topology { // P46
  @override
  String get topologyId => 'x';
  @override
  Scope get scope => Scope.page;
  @override
  void declare(TopologyBuilder b) {}
}
final class Mutable extends Topology { // P47
  int count = 0;
  @override
  String get topologyId => 'x';
  @override
  Scope get scope => Scope.page;
  @override
  void declare(TopologyBuilder b) {}
}
@immutable
final class Unused {}
