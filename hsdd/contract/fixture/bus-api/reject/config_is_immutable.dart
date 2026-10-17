// covers: G3
// BusConfig is an immutable value: its fields are final.
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

void mutate(BusConfig config) {
  // expect-diagnostic: assignment_to_final
  config.maxTopics = 10;
  // expect-diagnostic: assignment_to_final
  config.devMode = true;
  // expect-diagnostic: assignment_to_final
  config.scheduler = null;
  // expect-diagnostic: assignment_to_final
  config.moduleScopeGracePeriod = Duration.zero;
}
