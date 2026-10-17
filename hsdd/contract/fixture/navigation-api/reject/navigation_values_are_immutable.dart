// covers: G4
// Navigation values are immutable: none of their fields can be assigned.
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

void misuse(NavRoute<int> route, RouteState state, RouteTransition t,
    NavigationEntry entry, RouteConfirmation c, RouteAccessPolicy p, DateTime now) {
  // expect-diagnostic: assignment_to_final
  route.path = 'elsewhere';
  // expect-diagnostic: assignment_to_final
  state.args = 1;
  // expect-diagnostic: assignment_to_final
  t.timestamp = now;
  // expect-diagnostic: assignment_to_final
  entry.modal = true;
  // expect-diagnostic: assignment_to_final
  c.intent = const Back();
  // expect-diagnostic: assignment_to_final
  p.fallback = const PublicAccess();
}
