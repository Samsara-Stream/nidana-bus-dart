// Stand-in for flutter-binding@v2's topic widgets (experiment only).
// Patched in flutter-reconcile-amends: the subscription observes at Object?
// (G5 and G6 as amended, nidana.flutter D7). Patched in flutter-binding-v0151:
// a subscription made during bootstrap, which start() connects with the
// value current then (bus-api@v2 G34), counts its first values as changes
// (flutter-binding@v2 G5, G6).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

import 'bus_provider.dart';

/// Renders a state topic: every build reads bus.getCurrentValue, and the
/// observed subscription only marks the widget for rebuild.
final class StateTopicBuilder<T> extends StatefulWidget {
  const StateTopicBuilder({super.key, required this.topic, required this.builder});

  final StateTopic<T> topic;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<StateTopicBuilder<T>> createState() => _StateTopicBuilderState<T>();
}

final class _StateTopicBuilderState<T> extends State<StateTopicBuilder<T>> {
  final _Subscription _subscription = _Subscription();
  Bus? _bus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Bus bus = BusProvider.of(context);
    if (!identical(bus, _bus)) {
      _bus = bus;
      _subscription.listen(bus, widget.topic, _first(bus, 1), _changed);
    }
  }

  @override
  void didUpdateWidget(StateTopicBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic != widget.topic) {
      _subscription.listen(_bus!, widget.topic, _first(_bus!, 1), _changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _bus!.getCurrentValue(widget.topic));
}

/// Renders a replay topic from bus.getBufferedValues, as StateTopicBuilder
/// does a state topic.
final class ReplayTopicBuilder<T> extends StatefulWidget {
  const ReplayTopicBuilder({super.key, required this.topic, required this.builder});

  final ReplayTopic<T> topic;
  final Widget Function(BuildContext context, List<T> values) builder;

  @override
  State<ReplayTopicBuilder<T>> createState() => _ReplayTopicBuilderState<T>();
}

final class _ReplayTopicBuilderState<T> extends State<ReplayTopicBuilder<T>> {
  final _Subscription _subscription = _Subscription();
  Bus? _bus;

  void _listen() => _subscription.listen(_bus!, widget.topic,
      _first(_bus!, _bus!.getBufferedValues<Object?>(widget.topic).length), _changed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Bus bus = BusProvider.of(context);
    if (!identical(bus, _bus)) {
      _bus = bus;
      _listen();
    }
  }

  @override
  void didUpdateWidget(ReplayTopicBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic != widget.topic) _listen();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _bus!.getBufferedValues(widget.topic));
}

/// How many first values a subscription made now skips: [rendered], the
/// values the build already read, after start(); none during bootstrap,
/// because start() gives a bootstrap subscription the values current once it
/// has connected the topologies, which the build did not read (bus-api@v2
/// G34).
int _first(Bus bus, int rendered) =>
    0; // seeded defect: every first value marks the widget

/// One observed subscription that ignores its first [skip] values, which
/// bus-api@v2 G17 delivers as what was current when it listened. It observes
/// through a widened reference, so no conversion of a delivery can fail
/// (flutter-binding@v2 G5 and G6).
final class _Subscription {
  StreamSubscription<Object?>? _current;

  void listen<T>(Bus bus, Topic<T> topic, int skip, void Function() changed) {
    cancel();
    var remaining = skip;
    _current = bus.observe<Object?>(topic).listen(
      (Object? _) {
        if (remaining > 0) {
          remaining--;
          return;
        }
        changed();
      },
      onError: (Object _) => cancel(),
      cancelOnError: true,
    );
  }

  void cancel() {
    final StreamSubscription<Object?>? s = _current;
    _current = null;
    if (s != null) unawaited(s.cancel());
  }
}
