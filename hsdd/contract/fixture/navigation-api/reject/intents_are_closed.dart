// covers: G1
// The intent families are closed: NavIntent and ResolvedNavIntent are
// sealed, their variants final, and a switch that omits a variant does not
// compile (Guide §3.2, §3.4; Spec Appendix A.6).
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnIntent extends NavIntent {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnResolved implements ResolvedNavIntent {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnBack extends Back {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnLink implements DeepLink {}

// expect-diagnostic: non_exhaustive_switch_expression
String noDismiss(ResolvedNavIntent i) => switch (i) {
      GoTo() => 'go',
      Replace() => 'replace',
      Back() => 'back',
      BackTo() => 'back to',
      ShowModal() => 'modal',
    };

// expect-diagnostic: non_exhaustive_switch_expression
String noDeepLink(NavIntent i) => switch (i) {
      ResolvedNavIntent() => 'resolved',
    };
