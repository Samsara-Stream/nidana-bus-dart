// Binding: runs flutter-binding@v2's conformance suite against the producer's
// package:nidana_dart_runtime_flutter, under testWidgets (ADR-001 item 4).
// Each case builds its buses in the test body on the production provider, so
// tester.pump drives their clocks and timers (ADR-003 item 7); the binding
// shuts every bus the harness built down, unmounts the tree and resets the
// platform's initial route before the body ends. A WidgetTestBus a case
// builds itself is shut down by the case, through the owning provider its
// wrap returns.
//
// The package import names the implementation, so the replay tool reports
// this binding as PENDING until nidana_dart_runtime_flutter exists (ADR-001
// item 9).
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
// ignore: unused_import
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

import 'flutter_binding_conformance.dart';

final class _Harness implements FlutterBindingHarness {
  _Harness(this.tester);

  final WidgetTester tester;
  final List<Bus> buses = <Bus>[];

  Future<void> _navigation(MethodCall call) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(call),
      (ByteData? _) {},
    );
  }

  @override
  Bus bus([BusConfig config = const BusConfig()]) {
    final Bus bus = Bus(config); // production provider: this zone and clock
    buses.add(bus);
    return bus;
  }

  @override
  Future<void> pumpWidget(Widget widget) => tester.pumpWidget(widget);

  @override
  Future<void> pump([Duration duration = Duration.zero]) => tester.pump(duration);

  @override
  Future<void> pumpAndSettle() => tester.pumpAndSettle();

  @override
  Future<void> platformBack() async {
    await _navigation(const MethodCall('popRoute'));
    await tester.pumpAndSettle();
  }

  @override
  Future<void> platformPushRoute(String location) async {
    await _navigation(MethodCall('pushRouteInformation',
        <String, Object?>{'location': location, 'state': null}));
    await tester.pumpAndSettle();
  }

  @override
  void setPlatformInitialRoute(String name) =>
      tester.binding.platformDispatcher.defaultRouteNameTestValue = name;

  @override
  Object? takeException() => tester.takeException();
}

void main() {
  for (final c in flutterBindingConformance) {
    testWidgets(c.name, (WidgetTester tester) async {
      final _Harness h = _Harness(tester);
      try {
        await c.body(h);
      } finally {
        // No bus timer may outlive the body (ADR-003 item 7).
        for (final Bus bus in h.buses) {
          bus.shutdown();
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
      }
    });
  }
}
