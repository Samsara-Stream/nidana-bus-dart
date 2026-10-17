import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

abstract final class CartTopics {
  static const StateTopic<int> items = StateTopic<int>(name: 'cart.items', initial: 0);
  static const StateTopic<int> draft = StateTopic<int>(name: 'checkout.draft', initial: 0);
}

StateTopic<int> topicFor(String key) => CartTopics.items;
