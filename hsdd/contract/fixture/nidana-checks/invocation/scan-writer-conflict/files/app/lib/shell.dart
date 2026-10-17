import 'package:flutter/widgets.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

import 'topics.dart';

/// Claims checkout.draft at page scope.
Widget checkoutPage() => PageScope(route: 'checkout', writes: {CartTopics.draft}, child: const SizedBox());

/// Two executors claim nav.current-route, which the topology route-mirror
/// also writes.
NavigationExecutor navigation(Bus bus, NavigationRouter router) => NavigationExecutor(bus, router);

FlutterNavigationExecutor flutterNavigation(Bus bus, RouteState initial, NavigationRouteBuilder pages) =>
    FlutterNavigationExecutor(bus, initial: initial, routeBuilder: pages);
