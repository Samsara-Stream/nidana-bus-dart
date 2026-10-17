// covers: G1
// The widget-test library exports WidgetTestBus only: a test that imports it
// alone reaches neither the adapter's main library nor nidana_dart_runtime's
// libraries.
import 'package:nidana_dart_runtime_flutter/testing.dart';

final WidgetTestBus t = WidgetTestBus();

// expect-diagnostic: undefined_class
BusProvider? provider;

// expect-diagnostic: undefined_class
Bus? bus;

// expect-diagnostic: undefined_class
EnvelopeRecorder? recorder;
