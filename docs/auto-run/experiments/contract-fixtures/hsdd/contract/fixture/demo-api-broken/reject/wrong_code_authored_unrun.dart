// Reject fixture for demo-api G4: StateTopic cannot be subclassed outside
// its library.
// covers: G4
import 'package:demo_contracts/demo_contracts.dart';

// expect-diagnostic: final_class_extended_outside_of_library
final class MyTopic extends StateTopic<int> {
  const MyTopic() : super('demo.mine', 0);
}
