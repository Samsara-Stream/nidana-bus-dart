// covers: G3
// The access, principal, router-call and plan families are sealed with final
// variants, the values and the executor are final, and a switch that omits
// a variant does not compile.
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnRequirement extends RouteAccessRequirement {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnPrincipal extends AccessPrincipal {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnCall extends RouterCall {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnPlan extends NavigationPlan {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnExecutor implements NavigationExecutor {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnRoute extends NavRoute<int> {
  const OwnRoute() : super('own');
}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnState implements RouteState {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnPolicy implements RouteAccessPolicy {}

// expect-diagnostic: non_exhaustive_switch_expression
String requirement(RouteAccessRequirement r) => switch (r) {
      PublicAccess() => 'public',
      AuthenticatedAccess() => 'authenticated',
      RoleAccess() => 'role',
    };

// expect-diagnostic: non_exhaustive_switch_expression
String principal(AccessPrincipal p) => switch (p) {
      AnonymousPrincipal() => 'anonymous',
      AuthenticatedPrincipal() => 'authenticated',
    };

// expect-diagnostic: non_exhaustive_switch_expression
String call(RouterCall c) => switch (c) {
      PushRoute() => 'push',
      ReplaceRoute() => 'replace',
      PopRoute() => 'pop',
    };

// expect-diagnostic: non_exhaustive_switch_expression
String plan(NavigationPlan p) => switch (p) {
      PerformCalls() => 'perform',
    };
