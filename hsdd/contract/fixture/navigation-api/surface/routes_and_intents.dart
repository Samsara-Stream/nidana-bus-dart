// Surface fixture for navigation-api@v1 (ADR-001 item 4): every declaration
// of routes, intents, route state and the navigation topics, used with the
// types the Interface states. Exhaustive switches over NavIntent and
// ResolvedNavIntent fail this set when a variant is added.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

abstract final class CheckoutRoutes {
  static const NavRoute<void> cart = NavRoute<void>('checkout/cart');
  static const NavRoute<int> order = NavRoute<int>('checkout/order');
  static const NavRoute<String> picker = NavRoute<String>('checkout/picker');
}

final RouteRegistry registry = RouteRegistry(<NavRoute<Object?>>[
      CheckoutRoutes.cart,
      CheckoutRoutes.order,
    ]) +
    RouteRegistry(<NavRoute<Object?>>[CheckoutRoutes.picker]);

String describe(NavIntent intent) => switch (intent) {
      DeepLink(:final Uri uri) => 'deep link $uri',
      ResolvedNavIntent() => resolved(intent),
    };

String resolved(ResolvedNavIntent intent) => switch (intent) {
      GoTo(:final NavRoute<Object?> route, :final Object? args) => 'go $route $args',
      Replace(:final NavRoute<Object?> route, :final Object? args) => 'replace $route $args',
      Back() => 'back',
      BackTo(:final NavRoute<Object?> route) => 'back to $route',
      ShowModal(:final NavRoute<Object?> route, :final Object? args) => 'modal $route $args',
      DismissModal() => 'dismiss',
    };

String everyVariant(NavIntent intent) => switch (intent) {
      DeepLink() => 'deep link',
      GoTo() => 'go',
      Replace() => 'replace',
      Back() => 'back',
      BackTo() => 'back to',
      ShowModal() => 'modal',
      DismissModal() => 'dismiss',
    };

void routes() {
  const NavRoute<int> order = CheckoutRoutes.order;
  final String path = order.path;
  final Type args = order.argsType;
  const NavRoute<void> none = NavRoute.none;
  final GoTo go = order.go(7);
  final GoTo goNoArgs = CheckoutRoutes.cart.go();
  final Replace replace = order.replace(8);
  final ShowModal modal = CheckoutRoutes.picker.showModal('photo');
  final BackTo backTo = CheckoutRoutes.cart.backTo();
  const BackTo literal = BackTo(CheckoutRoutes.cart);
  const Back back = Back();
  const DismissModal dismiss = DismissModal();
  final DeepLink link = DeepLink(Uri.parse('app://checkout/order/7'));
  final NavRoute<Object?> goRoute = go.route;
  final Object? goArgs = go.args;
  final NavRoute<Object?> replaceRoute = replace.route;
  final Object? replaceArgs = replace.args;
  final NavRoute<Object?> modalRoute = modal.route;
  final Object? modalArgs = modal.args;
  final NavRoute<Object?> backToRoute = backTo.route;
  final NavRoute<Object?>? target = goNoArgs.targetRoute;
  final NavRoute<Object?>? none2 = back.targetRoute;
  final Uri uri = link.uri;
  final NavRoute<Object?>? found = registry.lookup('checkout/order');
  final List<NavRoute<Object?>> all = registry.routes;
  final bool same = order == const NavRoute<int>('checkout/order');
  final int hash = order.hashCode;
  print(<Object?>[
    path, args, none, literal, dismiss, goRoute, goArgs, replaceRoute, replaceArgs,
    modalRoute, modalArgs, backToRoute, target, none2, uri, found, all, same, hash,
  ]);
}

void states(DateTime now) {
  final RouteState state = RouteState(
    route: CheckoutRoutes.order,
    args: 7,
    pathParams: const <String, String>{'id': '7'},
    queryParams: const <String, String>{'ref': 'push'},
  );
  const RouteState initial = RouteState.initial;
  final NavRoute<Object?> route = state.route;
  final Object? args = state.args;
  final Map<String, String> path = state.pathParams;
  final Map<String, String> query = state.queryParams;
  final int? id = CheckoutRoutes.order.argsOf(state);
  final RouteTransition t = RouteTransition(
      from: initial, to: state, intent: CheckoutRoutes.order.go(7), timestamp: now);
  final RouteState from = t.from;
  final RouteState to = t.to;
  final ResolvedNavIntent intent = t.intent;
  final DateTime at = t.timestamp;
  print(<Object?>[route, args, path, query, id, from, to, intent, at]);
}

void topics() {
  const EventTopic<NavIntent> intent = NavigationTopics.intent;
  const EventTopic<ResolvedNavIntent> resolved = NavigationTopics.resolvedIntent;
  const StateTopic<RouteState> current = NavigationTopics.currentRoute;
  const ReplayTopic<RouteTransition> history = NavigationTopics.history;
  const StateTopic<RouteAccessPolicy> policy = NavigationTopics.accessPolicy;
  const List<Topic<Object?>> all = <Topic<Object?>>[intent, resolved, current, history, policy];
  print(all);
}
