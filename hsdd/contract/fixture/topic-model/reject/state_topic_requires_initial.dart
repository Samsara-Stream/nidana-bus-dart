// Reject fixture for topic-model@v1 G3: a state topic is declared with its
// initial value, a T for the default constructor and a T Function() for
// StateTopic.computed (Spec §2.5).
// covers: G3
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

// expect-diagnostic: missing_required_argument
final StateTopic<int> noInitial = StateTopic<int>(name: 'cart.count');

// expect-diagnostic: missing_required_argument
final StateTopic<int> noComputedInitial = StateTopic<int>.computed(name: 'cart.count');

// expect-diagnostic: argument_type_not_assignable
final StateTopic<int> valueForFactory = StateTopic<int>.computed(name: 'cart.count', initial: 0);

// expect-diagnostic: argument_type_not_assignable
final StateTopic<int> factoryForValue = StateTopic<int>(name: 'cart.count', initial: () => 0);
