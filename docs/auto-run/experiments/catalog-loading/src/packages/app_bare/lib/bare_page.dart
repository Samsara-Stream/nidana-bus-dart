// A Flutter package with no flutter_test dev dependency.
import 'package:flutter/foundation.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

abstract final class BareTopics {
  static const EventTopic<int> taps = EventTopic<int>(name: 'bare.taps');
  static const StateTopic<int> total = StateTopic<int>(name: 'bare.total', initial: 0);
}

int addTap(int total, int tap) => kDebugMode ? total + tap : total + tap;

final Topology bareTopology = topology(
  'bare',
  Scope.page,
  (b) => b.reduceInto(BareTopics.total, b.read(BareTopics.taps), addTap),
);
