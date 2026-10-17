import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

import 'topics.dart';

/// A page owns checkout.draft, which the MODULE topology checkout-flow reads.
Widget checkoutPage() => PageScope(route: 'checkout', writes: {CheckoutTopics.draft}, child: const SizedBox());

/// A MODULE-bound service owns session.state, which the APPLICATION topology
/// session-banner reads.
Publisher session(Bus bus) =>
    bus.publisher(const ServiceSource('session'), writes: {SessionTopics.state}, scope: Scope.module);
