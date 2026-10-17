// covers: G1
// testing.dart exports its own declarations only: a test that imports it
// alone reaches neither the main library of nidana_dart_runtime nor
// nidana_dart_contracts.
import 'package:nidana_dart_runtime/testing.dart';

final TestBus bus = TestBus();

// expect-diagnostic: undefined_class
Bus? asBus;

// expect-diagnostic: undefined_class
BusConfig? config;

// expect-diagnostic: undefined_class
MessageEnvelope<int>? envelope;
