import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

import '../lib/model.dart';
import '../lib/topics.dart';

// Test code is not application code: neither the second claim on cart.items
// nor the second declaration of cart.items is read.
final StateTopic<CartItems> stubItems = StateTopic<CartItems>(name: 'cart.items', initial: CartItems.empty);

Publisher stubCart(Bus bus) => bus.publisher(const ServiceSource('test'), writes: {CartTopics.items});
