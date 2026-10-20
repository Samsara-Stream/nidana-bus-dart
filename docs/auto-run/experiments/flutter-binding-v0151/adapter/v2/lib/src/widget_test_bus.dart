// Stand-in for flutter-binding@v1's widget-test library (experiment only).
// Patched in flutter-reconcile-amends: stub keeps one publisher per topic and
// returns its writer per type argument (G17 as amended, nidana.flutter D8).
// It imports neither package:test nor package:flutter_test.
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

import 'bus_provider.dart';

/// The bus of one widget test (ADR-003 item 7).
final class WidgetTestBus {
  WidgetTestBus._(this.bus) : recorder = EnvelopeRecorder.attach(bus);

  factory WidgetTestBus([BusConfig config = const BusConfig()]) {
    if (config.scheduler is VirtualSchedulerProvider) {
      throw ArgumentError.value(config.scheduler, 'config.scheduler',
          'a widget test runs the production provider');
    }
    return WidgetTestBus._(Bus(config));
  }

  static const ServiceSource testSource = ServiceSource('test');

  final Bus bus;
  final EnvelopeRecorder recorder;
  Publisher? _input;
  final Map<StateTopic<Object?>, Publisher> _stubs = <StateTopic<Object?>, Publisher>{};

  Publisher get input => _input ??= bus.publisher(testSource);

  /// One publisher per topic, its writer per type argument (bus-api@v1 G20,
  /// G41); a rejected claim throws ClaimRejected and caches nothing.
  StateWriter<T> stub<T>(StateTopic<T> topic) =>
      (_stubs[topic] ??= bus.publisher(testSource, writes: <StateTopic<Object?>>{topic}))
          .writer<T>(topic);

  Widget wrap(Widget child) => BusProvider(bus: bus, child: child);
}
