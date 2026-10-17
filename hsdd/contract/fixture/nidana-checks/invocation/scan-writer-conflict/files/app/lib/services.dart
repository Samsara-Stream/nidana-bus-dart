import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

import 'topics.dart';

/// Claims cart.items, which the topology cart-reducer writes.
Publisher cartSync(Bus bus) => bus.publisher(const ServiceSource('cart-sync'), writes: {CartTopics.items});

/// Claims checkout.draft at page scope, as the checkout page does.
Publisher draftRestore(Bus bus) =>
    bus.publisher(const ServiceSource('draft-restore'), writes: {CartTopics.draft}, scope: Scope.page);

/// Two claims whose sources are not statically known: each stands in as
/// the claim site.
Publisher profileFrom(Bus bus, MessageSource source) => bus.publisher(source, writes: {ProfileTopics.current});

Publisher profileNamed(Bus bus, String name) =>
    bus.publisher(ServiceSource(name), writes: {ProfileTopics.current});
