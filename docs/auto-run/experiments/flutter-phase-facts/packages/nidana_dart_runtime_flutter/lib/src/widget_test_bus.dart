// Stand-in for flutter-binding@v1's widget-test library (experiment only).
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
  final Map<StateTopic<Object?>, Object> _stubs = <StateTopic<Object?>, Object>{};

  Publisher get input => _input ??= bus.publisher(testSource);

  StateWriter<T> stub<T>(StateTopic<T> topic) {
    final Object? existing = _stubs[topic];
    if (existing != null) return existing as StateWriter<T>;
    final StateWriter<T> writer =
        bus.publisher(testSource, writes: <StateTopic<Object?>>{topic}).writer(topic);
    _stubs[topic] = writer;
    return writer;
  }

  Widget wrap(Widget child) => BusProvider(bus: bus, child: child);
}
