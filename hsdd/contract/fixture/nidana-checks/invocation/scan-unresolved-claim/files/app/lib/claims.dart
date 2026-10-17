import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';

import 'topics.dart';

final Set<StateTopic<Object?>> owned = {CartTopics.items};

void claims(Bus bus, bool flag, Scope scope) {
  // Unresolved write sets: a variable, a spread, a collection if, a call, a
  // local variable.
  bus.publisher(const ServiceSource('a'), writes: owned);
  bus.publisher(const ServiceSource('b'), writes: {...owned, CartTopics.draft});
  bus.publisher(const ServiceSource('c'), writes: {if (flag) CartTopics.items});
  bus.publisher(const ServiceSource('d'), writes: {topicFor('items')});
  final StateTopic<int> local = CartTopics.draft;
  bus.publisher(const ServiceSource('e'), writes: {local});
  // An unresolved scope.
  bus.publisher(const ServiceSource('f'), writes: {CartTopics.items}, scope: scope);
  // No claim at all: nothing to resolve, nothing reported.
  bus.publisher(const ServiceSource('g'));
  bus.publisher(const ServiceSource('h'), writes: const <StateTopic<Object?>>{});
}

Widget page() => PageScope(writes: owned, child: const SizedBox());
