// Stand-in for flutter-binding@v1's topic widgets (experiment only).
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
      _subscription.listen(bus, widget.topic, 1, _changed);
    }
  }

  @override
  void didUpdateWidget(StateTopicBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic != widget.topic) {
      _subscription.listen(_bus!, widget.topic, 1, _changed);
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

  void _listen() => _subscription.listen(
      _bus!, widget.topic, _bus!.getBufferedValues(widget.topic).length, _changed);

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

/// One observed subscription that ignores its first [skip] values, which
/// bus-api@v1 G17 delivers as what was current when it listened.
final class _Subscription {
  StreamSubscription<Object?>? _current;

  void listen<T>(Bus bus, Topic<T> topic, int skip, void Function() changed) {
    cancel();
    var remaining = skip;
    _current = bus.observe<T>(topic).listen(
      (T _) {
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
