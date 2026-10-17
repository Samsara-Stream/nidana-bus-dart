// covers: G1
// A deep link is impossible by construction after resolution (Spec Appendix
// A.6; Guide §3.4): no declaration that takes or yields a resolved intent
// accepts a DeepLink.
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

void misuse(Uri uri, NavigationRouter router, DateTime now) {
  // expect-diagnostic: invalid_assignment
  final ResolvedNavIntent r = DeepLink(uri);
  // expect-diagnostic: argument_type_not_assignable
  router.perform(const <RouterCall>[PopRoute()], DeepLink(uri));
  RouteTransition(
      from: RouteState.initial,
      to: RouteState.initial,
      // expect-diagnostic: argument_type_not_assignable
      intent: DeepLink(uri),
      timestamp: now);
  // expect-diagnostic: return_of_invalid_type_from_closure
  final DeepLinkResolver resolver = (Uri u) => DeepLink(u);
  // expect-diagnostic: argument_type_not_assignable
  planNavigation(const <NavigationEntry>[], DeepLink(uri), supportsPopUntil: true);
  print(<Object?>[r, resolver]);
}

String kind(ResolvedNavIntent i) => switch (i) {
      // expect-diagnostic: pattern_never_matches_value_type
      DeepLink() => 'deep link',
      ResolvedNavIntent() => 'resolved',
    };
