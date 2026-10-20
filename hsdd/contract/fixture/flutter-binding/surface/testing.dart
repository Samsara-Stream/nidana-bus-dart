// Surface fixture for flutter-binding@v2 (ADR-001 item 4): the widget-test
// library, used with the types the Interface states, as a widget test's
// body uses it. It needs no test framework itself, as the library does not.
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';
import 'package:nidana_dart_runtime_flutter/testing.dart';

const EventTopic<int> taps = EventTopic<int>(name: 'test.taps');
const StateTopic<int> count = StateTopic<int>(name: 'test.count', initial: 0);

/// What a testWidgets body does with it: build, stub, start, wrap, publish,
/// assert. start() comes before the tree mounts, because a page or module
/// scope activates only after it (bus-api@v2 G42).
Widget body(Widget page) {
  final WidgetTestBus t = WidgetTestBus(const BusConfig(devMode: true));
  final WidgetTestBus plain = WidgetTestBus();
  final ServiceSource source = WidgetTestBus.testSource;
  final Bus bus = t.bus;
  final EnvelopeRecorder recorder = t.recorder;
  final Publisher input = t.input;
  final StateWriter<int> stub = t.stub(count);
  stub.publish(2);
  bus.start();
  final Widget root = t.wrap(page);
  input.publish(taps, 1);
  final List<int> seen = recorder.payloadsOf(taps);
  print(<Object>[plain, source, seen]);
  return root;
}
