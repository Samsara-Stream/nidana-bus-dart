// covers: G17
// A widget test runs the production provider and tester.pump drives its time
// (ADR-003 item 7): the widget-test bus exposes no virtual scheduler and no
// settle operation, and its bus is a plain Bus, not a TestBus.
import 'package:nidana_dart_runtime/testing.dart';
import 'package:nidana_dart_runtime_flutter/testing.dart';

void misuse(WidgetTestBus t) {
  // expect-diagnostic: undefined_getter
  t.scheduler;
  // expect-diagnostic: undefined_method
  t.settle();
  // expect-diagnostic: invalid_assignment
  final TestBus bus = t.bus;
  print(bus);
}
