// F4 and F5: what flutter-binding@v1's topic widgets and WidgetTestBus.stub
// meet once bus-api@v1 G41 (amended in S31) lets a widened reference put a
// value of another type into a topic: the subscription's conversion of an
// off-type value fails into the provider zone's handler and that subscription
// skips it, while getCurrentValue and getBufferedValues at the value type
// throw TypeError at the call.
//
// F4 compares, for StateTopicBuilder and ReplayTopicBuilder, the stand-in's
// typed subscription (it observes at the widget's T and skips its first
// values by count) with a widened subscription (it observes at Object?, so no
// conversion can fail, and counts its first values from
// getBufferedValues<Object?>). Every build reads at T in both.
//
// F5 checks WidgetTestBus.stub for one topic at two type arguments: the
// stand-in caches one writer per topic and casts it; the per-type-argument
// form keeps one publisher per topic and returns its writer per type
// argument (bus-api@v1 G20), as bus-testing@v1 G18 now states for TestBus.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';
import 'package:nidana_dart_runtime_flutter/testing.dart';

const StateTopic<int> _n = StateTopic<int>(name: 'o.n', initial: 0);
const ReplayTopic<int> _r = ReplayTopic<int>(name: 'o.r', bufferSize: 3);
const ServiceSource _src = ServiceSource('o');

void _discard(BusDiagnostic d) {}

// ---------------------------------------------------------------- widened variants

final class _WidenedState<T> extends StatefulWidget {
  const _WidenedState({required this.topic, required this.builder});
  final StateTopic<T> topic;
  final Widget Function(BuildContext, T) builder;
  @override
  State<_WidenedState<T>> createState() => _WidenedStateState<T>();
}

final class _WidenedStateState<T> extends State<_WidenedState<T>> {
  StreamSubscription<Object?>? _s;
  Bus? _bus;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Bus bus = BusProvider.of(context);
    if (!identical(bus, _bus)) {
      _bus = bus;
      unawaited(_s?.cancel());
      var skip = 1;
      _s = bus.observe<Object?>(widget.topic).listen((Object? _) {
        if (skip > 0) {
          skip--;
          return;
        }
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    unawaited(_s?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _bus!.getCurrentValue(widget.topic));
}

final class _WidenedReplay<T> extends StatefulWidget {
  const _WidenedReplay({required this.topic, required this.builder});
  final ReplayTopic<T> topic;
  final Widget Function(BuildContext, List<T>) builder;
  @override
  State<_WidenedReplay<T>> createState() => _WidenedReplayState<T>();
}

final class _WidenedReplayState<T> extends State<_WidenedReplay<T>> {
  StreamSubscription<Object?>? _s;
  Bus? _bus;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Bus bus = BusProvider.of(context);
    if (!identical(bus, _bus)) {
      _bus = bus;
      unawaited(_s?.cancel());
      var skip = bus.getBufferedValues<Object?>(widget.topic).length;
      _s = bus.observe<Object?>(widget.topic).listen((Object? _) {
        if (skip > 0) {
          skip--;
          return;
        }
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    unawaited(_s?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _bus!.getBufferedValues(widget.topic));
}

// ---------------------------------------------------------------- helpers

Widget _app(Bus bus, Widget child) =>
    BusProvider.value(bus: bus, child: Directionality(textDirection: TextDirection.ltr, child: child));

Widget _stateWidget(String variant) => variant == 'typed'
    ? StateTopicBuilder<int>(topic: _n, builder: (BuildContext _, int v) => Text('v=$v'))
    : _WidenedState<int>(topic: _n, builder: (BuildContext _, int v) => Text('v=$v'));

Widget _replayWidget(String variant) => variant == 'typed'
    ? ReplayTopicBuilder<int>(topic: _r, builder: (BuildContext _, List<int> v) => Text('v=$v'))
    : _WidenedReplay<int>(topic: _r, builder: (BuildContext _, List<int> v) => Text('v=$v'));

String _shown(WidgetTester tester) {
  final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
  return texts.isEmpty ? '(no Text: ErrorWidget)' : texts.single.data!;
}

String _ex(Object? e) => e == null ? 'none' : e.runtimeType.toString().replaceAll(RegExp(r'^_'), '');

/// A bus built in an error zone forked inside the test body, so the provider
/// zone's uncaught errors are counted and tester.pump still drives its timers.
(Bus, List<Object>) _bus() {
  final List<Object> zoneErrors = <Object>[];
  late Bus bus;
  runZonedGuarded(() {
    bus = Bus(const BusConfig(diagnostics: _discard));
  }, (Object e, StackTrace _) => zoneErrors.add(e));
  return (bus, zoneErrors);
}

void _log(String line) {
  // ignore: avoid_print
  print(line);
}

void main() {
  for (final String variant in <String>['typed', 'widened']) {
    testWidgets('F4a $variant state builder: the current value is off-type at mount, then an on-type value arrives',
        (WidgetTester tester) async {
      final (Bus bus, List<Object> zoneErrors) = _bus();
      final StateTopic<Object?> wide = _n;
      final Publisher p = bus.publisher(_src, writes: <StateTopic<Object?>>{_n});
      bus.start();
      p.writer<Object?>(wide).publish('x');
      await tester.pumpWidget(_app(bus, _stateWidget(variant)));
      final String mountEx = _ex(tester.takeException());
      await tester.pump();
      final int afterFirst = zoneErrors.length;
      p.writer<int>(_n).publish(5);
      await tester.pump();
      _log('F4a $variant: build at mount threw $mountEx; provider-zone errors after the first value: $afterFirst; '
          'after an on-type 5: shows "${_shown(tester)}", build exception ${_ex(tester.takeException())}');
      bus.shutdown();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('F4b $variant state builder: an off-type value is published after mount, then an on-type value',
        (WidgetTester tester) async {
      final (Bus bus, List<Object> zoneErrors) = _bus();
      final StateTopic<Object?> wide = _n;
      final Publisher p = bus.publisher(_src, writes: <StateTopic<Object?>>{_n});
      bus.start();
      await tester.pumpWidget(_app(bus, _stateWidget(variant)));
      await tester.pump();
      final String before = _shown(tester);
      p.writer<Object?>(wide).publish('x');
      await tester.pump();
      final String offShown = _shown(tester);
      final String offEx = _ex(tester.takeException());
      final int offZone = zoneErrors.length;
      p.writer<int>(_n).publish(5);
      await tester.pump();
      _log('F4b $variant: before "$before"; after off-type "x": shows "$offShown", build exception $offEx, '
          'provider-zone errors $offZone; after an on-type 5: shows "${_shown(tester)}", build exception ${_ex(tester.takeException())}');
      bus.shutdown();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('F4c $variant replay builder: the buffer holds an off-type value at mount, then on-type values push it out',
        (WidgetTester tester) async {
      final (Bus bus, List<Object> zoneErrors) = _bus();
      final ReplayTopic<Object?> wide = _r;
      final Publisher p = bus.publisher(_src);
      bus.start();
      p.publish(_r, 1);
      p.publish(wide, 'x');
      await tester.pumpWidget(_app(bus, _replayWidget(variant)));
      final String mountEx = _ex(tester.takeException());
      await tester.pump();
      final int afterFirst = zoneErrors.length;
      for (final int v in <int>[2, 3, 4]) {
        p.publish(_r, v);
        await tester.pump();
        tester.takeException();
      }
      _log('F4c $variant: mount threw $mountEx; provider-zone errors after the first values: $afterFirst; '
          'after 2, 3, 4 push "x" out: shows "${_shown(tester)}", build exception ${_ex(tester.takeException())}');
      bus.shutdown();
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('F5 WidgetTestBus.stub for one topic at two type arguments', (WidgetTester tester) async {
    final StateTopic<Object?> wide = _n;
    final WidgetTestBus t = WidgetTestBus(const BusConfig(diagnostics: _discard));
    t.stub<Object?>(wide);
    Object? standIn;
    try {
      t.stub<int>(_n);
    } on Object catch (e) {
      standIn = e;
    }
    // The per-type-argument form: one publisher per topic, its writer per type argument.
    final Bus bus = Bus(const BusConfig(diagnostics: _discard));
    final Map<StateTopic<Object?>, Publisher> publishers = <StateTopic<Object?>, Publisher>{};
    StateWriter<T> stub<T>(StateTopic<T> topic) => publishers
        .putIfAbsent(topic, () => bus.publisher(WidgetTestBus.testSource, writes: <StateTopic<Object?>>{topic}))
        .writer<T>(topic);
    final StateWriter<Object?> a = stub<Object?>(wide);
    final StateWriter<int> b = stub<int>(_n);
    final bool sameEach = identical(a, stub<Object?>(wide)) && identical(b, stub<int>(_n));
    bus.start();
    b.publish(7);
    _log('F5 stand-in stub<int> after stub<Object?>: ${standIn == null ? 'returned' : 'threw ${_ex(standIn)}'}; '
        'per-type-argument form: claims ${bus.toGraph().claims.length}, the same writer per type argument: $sameEach, '
        'current value after the int writer published 7: ${bus.getCurrentValue(_n)}');
    t.bus.shutdown();
    bus.shutdown();
  });
}
