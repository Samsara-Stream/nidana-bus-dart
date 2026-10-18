// A pure domain module: topics and two topologies, one with a zero-argument
// constructor and one built by a factory that takes its dependencies.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

abstract final class CartTopics {
  static const EventTopic<int> added = EventTopic<int>(name: 'cart.added');
  static const StateTopic<int> count = StateTopic<int>(name: 'cart.count', initial: 0);
  static const StateTopic<int> price = StateTopic<int>(name: 'cart.price', initial: 0);
}

int countAdded(int count, int added) => count + added;

/// Zero-argument constructor: a convention scan could construct it.
final class CartTopology extends Topology {
  const CartTopology();

  @override
  String get topologyId => 'cart';

  @override
  Scope get scope => Scope.application;

  @override
  void declare(TopologyBuilder b) {
    b.reduceInto(CartTopics.count, b.read(CartTopics.added), countAdded);
  }
}

/// A topology with a dependency: its pricing rule. The rule's name is part
/// of the recorded definition (a FunctionRef), so the catalog must be given
/// the same rule the app's bootstrap passes.
Topology pricingTopology(int Function(int count) rule) => topology(
      'pricing',
      Scope.application,
      (b) => b.write(CartTopics.price, b.read(CartTopics.count).map(rule)),
    );

int flatRate(int count) => count * 100;
