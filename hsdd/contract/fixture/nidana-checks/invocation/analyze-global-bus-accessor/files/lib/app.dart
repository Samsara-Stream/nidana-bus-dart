import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

// Reported: a top-level variable of type Bus.
final Bus appBus = Bus();

// Reported: nullable and late are still global.
late Bus? lateBus;

// Reported: a subtype of Bus.
final TestBus sharedTestBus = TestBus();

// Reported: a top-level getter.
Bus get currentBus => appBus;

abstract final class Services {
  // Reported: a static field.
  static Bus? bus;

  // Reported: a static getter.
  static Bus get instance => appBus;
}

// Accepted: the bus is held by an instance and passed explicitly.
final class CheckoutService {
  CheckoutService(this.bus);
  final Bus bus;
  Bus get owner => bus;
}

// Accepted: a function makes a bus; it does not hold one.
Bus createBus() => Bus();

// Accepted: a local variable and a parameter.
void run(Bus bus) {
  final Bus other = createBus();
  other.start();
  bus.start();
}
