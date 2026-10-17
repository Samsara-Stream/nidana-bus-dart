import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

import 'topics.dart';

/// The one writer of network.connectivity: a shell claim (Spec §3.11).
final class ConnectivityMonitor {
  ConnectivityMonitor(Bus bus)
      : publisher = bus.publisher(const ServiceSource('connectivity'), writes: {NetworkTopics.connectivity});
  final Publisher publisher;
}

/// The one writer of checkout.draft: the checkout page, at page scope.
Widget checkoutPage() => PageScope(route: 'checkout', writes: {CartTopics.draft}, child: const SizedBox());

/// The one writer of nav.current-route: the navigation executor.
NavigationExecutor navigation(Bus bus, NavigationRouter router) => NavigationExecutor(bus, router);
