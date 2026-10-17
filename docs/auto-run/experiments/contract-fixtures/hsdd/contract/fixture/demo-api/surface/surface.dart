// Surface fixture: uses every declaration the Interface lists, with the
// types it states. Must analyze with no diagnostic at all.
import 'package:demo_contracts/demo_contracts.dart';

const StateTopic<int> count = StateTopic<int>('demo.count', 0);
const EventTopic<String> tapped = EventTopic<String>('demo.tapped');

Future<String> useSurface(Executor executor) async {
  final String name = tapped.name;
  final int initial = count.initial;
  await executor.go('/next');
  return '$name $initial ${executor.current}';
}

Executor makeExecutor() => InMemoryExecutor();
