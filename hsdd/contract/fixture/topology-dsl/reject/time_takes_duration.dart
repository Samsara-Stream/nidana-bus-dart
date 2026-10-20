// Reject fixture for topology-dsl@v2 G6: time-dependent combinators take a
// Duration and no scheduler argument (Spec §3.6; ADR-003 item 4). Time is the
// live implementation's provider clock, never a parameter of the declaration.
// covers: G6
import 'dart:async';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

const StateTopic<String> query =
    StateTopic<String>(name: 'search.query', initial: '');

void declare(TopologyBuilder b) {
  final TopicStream<String> q = b.read(query);

  // expect-diagnostic: argument_type_not_assignable
  q.debounce(300);
  // expect-diagnostic: undefined_named_parameter
  q.debounce(const Duration(milliseconds: 300), scheduler: Zone.current);
  // expect-diagnostic: extra_positional_arguments
  q.throttle(const Duration(milliseconds: 100), Zone.current);
  // expect-diagnostic: extra_positional_arguments
  q.delay(Duration.zero, Zone.current);
  // expect-diagnostic: undefined_named_parameter
  q.sample(const Duration(seconds: 1), scheduler: Zone.current);
  // expect-diagnostic: argument_type_not_assignable
  q.buffer(2000);
  // expect-diagnostic: undefined_named_parameter
  q.timeout(const Duration(seconds: 5), scheduler: Zone.current);
}
