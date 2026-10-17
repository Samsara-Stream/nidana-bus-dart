// covers: G2
// An intent's arguments are typed by its route: GoTo, Replace and ShowModal
// are made only by the route, whose argument parameter is the route's own
// type, so an argument of another type does not compile.
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

const NavRoute<int> order = NavRoute<int>('checkout/order');

void misuse(RouteState state) {
  // expect-diagnostic: argument_type_not_assignable
  order.go('seven');
  // expect-diagnostic: argument_type_not_assignable
  order.replace('seven');
  // expect-diagnostic: argument_type_not_assignable
  order.showModal(7.5);
  // expect-diagnostic: new_with_undefined_constructor_default
  GoTo(order, 7);
  // expect-diagnostic: new_with_undefined_constructor_default
  Replace(order, 7);
  // expect-diagnostic: new_with_undefined_constructor_default
  ShowModal(order, 7);
  // expect-diagnostic: invalid_assignment
  final String id = order.argsOf(state);
  print(id);
}
