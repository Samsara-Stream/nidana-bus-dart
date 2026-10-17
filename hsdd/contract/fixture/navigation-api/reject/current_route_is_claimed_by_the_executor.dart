// covers: G19
// Only the executor's claim writes nav.current-route (Spec §3.11; Guide
// §3.4): it is a state topic, so no publisher-less or claimless publish
// reaches it, and the executor exposes neither its publisher nor its writer.
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

void misuse(Bus bus, Publisher pages, NavigationExecutor executor, RouteState s) {
  // expect-diagnostic: argument_type_not_assignable
  bus.publish(NavigationTopics.currentRoute, s);
  // expect-diagnostic: argument_type_not_assignable
  pages.publish(NavigationTopics.currentRoute, s);
  // expect-diagnostic: undefined_getter
  executor.publisher;
  // expect-diagnostic: undefined_getter
  executor.writer;
}
