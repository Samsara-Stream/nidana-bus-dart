// GENERATED CODE - DO NOT MODIFY BY HAND.
// nidana_dart_codegen from topics.yaml (topic-codegen@v1).

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

/// Topics of the `cart` domain, owned by payments-team.
abstract final class CartTopics {
  static final StateTopic<int> items = StateTopic<int>(name: 'cart.items', initial: 0);

  static final EventTopic<String> checkout = EventTopic<String>(name: 'cart.checkout');
}
