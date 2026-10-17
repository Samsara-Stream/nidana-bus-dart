// Surface fixture for flutter-binding@v1 (ADR-001 item 4): the bus provider,
// the topic widgets and the page scope, used with the types the Interface
// states, in the shape of an app's page.
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

abstract final class CartTopics {
  static const StateTopic<int> count = StateTopic<int>(name: 'cart.count', initial: 0);
  static const ReplayTopic<String> recent = ReplayTopic<String>(name: 'cart.recent', bufferSize: 5);
  static const EventTopic<String> added = EventTopic<String>(name: 'cart.added');
  static const StateTopic<String> draft = StateTopic<String>(name: 'cart.draft', initial: '');
}

final Topology cartPage = topology('cart-page', Scope.page,
    (TopologyBuilder b) => b.write(CartTopics.recent, b.read(CartTopics.added)));

/// The app root: the owning provider ends the coordination domain with it.
Widget app(Bus bus, Widget home) {
  final BusProvider owning = BusProvider(bus: bus, child: home);
  final BusProvider shared = BusProvider.value(bus: bus, child: home);
  final Bus provided = owning.bus;
  final Widget child = shared.child;
  final bool owns = owning.ownsBus && !shared.ownsBus;
  return owns && identical(provided, bus) ? owning : BusProvider.value(bus: bus, child: child);
}

final class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Bus bus = BusProvider.of(context);
    final Bus? maybe = BusProvider.maybeOf(context);
    final PageScope scope = PageScope(
      route: 'cart',
      topologies: <Topology>[cartPage],
      writes: <StateTopic<Object?>>{CartTopics.draft},
      child: Column(children: <Widget>[
        StateTopicBuilder<int>(
          topic: CartTopics.count,
          builder: (BuildContext context, int count) => Text('$count items'),
        ),
        ReplayTopicBuilder<String>(
          topic: CartTopics.recent,
          builder: (BuildContext context, List<String> recent) => Text(recent.join(', ')),
        ),
        Builder(builder: (BuildContext context) {
          final Publisher page = PageScope.publisherOf(context);
          final StateWriter<String> draft = page.writer(CartTopics.draft);
          return GestureDetector(
            onTap: () {
              page.publish(CartTopics.added, 'item');
              draft.publish('');
            },
            child: const Text('add'),
          );
        }),
      ]),
    );
    final String? route = scope.route;
    final List<Topology> topologies = scope.topologies;
    final Set<StateTopic<Object?>> writes = scope.writes;
    final Widget child = scope.child;
    return identical(bus, maybe) && route != null && topologies.isNotEmpty && writes.isNotEmpty
        ? scope
        : child;
  }
}

/// A state builder's and a replay builder's fields.
void fields(StateTopicBuilder<int> state, ReplayTopicBuilder<String> replay, BuildContext context) {
  final StateTopic<int> topic = state.topic;
  final Widget Function(BuildContext context, int value) build = state.builder;
  final ReplayTopic<String> buffered = replay.topic;
  final Widget Function(BuildContext context, List<String> values) buildAll = replay.builder;
  print(<Object>[topic, build(context, 1), buffered, buildAll(context, <String>['a'])]);
}
