// P2 at run time: what the stand-in bus does when bus-api@v1's publish
// signature lets a DeepLink through to nav.resolved-intent.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/testing.dart';

void main() {
  print(const NavRoute<void>('probe/x').argsType); // X3
  print(const NavRoute<void>('probe/x') == const NavRoute<Null>('probe/x')); // X4
  final TestBus bus = TestBus();
  bus.start();
  final List<ResolvedNavIntent> seen = <ResolvedNavIntent>[];
  bus.observe(NavigationTopics.resolvedIntent).listen(seen.add);
  bus.scheduler.triggerActions();
  try {
    bus.input.publish(NavigationTopics.resolvedIntent, DeepLink(Uri.parse('probe://x')));
    print('published; delivered: $seen');
  } catch (e) {
    print('publish threw ${e.runtimeType}: ${e.toString().split('\n').first}');
  }
  bus.scheduler.triggerActions();
  print('observer saw: $seen');
  final TestBus queued = TestBus();
  queued.input.publish(NavigationTopics.resolvedIntent, DeepLink(Uri.parse('probe://y')));
  print('queued before start without error');
  try {
    queued.start();
    print('start delivered it');
  } catch (e) {
    print('start threw ${e.runtimeType}');
  }
}
