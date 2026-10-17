// Reject fixture for demo-api G4: StateTopic cannot be subclassed outside
// its library.
// covers: G4
import 'package:demo_contracts/demo_contracts.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class MyTopic extends StateTopic<int> {
  const MyTopic() : super('demo.mine', 0);
}
