// covers: G1
// The adapter's main library exports its own declarations only: a page that
// imports it alone reaches neither nidana_dart_runtime, nidana_dart_navigation
// nor nidana_dart_contracts, nor the adapter's widget-test library.
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

BusProvider? provider;

// expect-diagnostic: undefined_class
Bus? bus;

// expect-diagnostic: undefined_class
NavigationExecutor? executor;

// expect-diagnostic: undefined_class
RouteState? state;

// expect-diagnostic: undefined_class
Topology? page;

// expect-diagnostic: undefined_class
WidgetTestBus? test;
