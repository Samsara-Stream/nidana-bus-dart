// P1: which navigation-api@v1 names collide with what a Flutter page
// imports. The Guide's and the Specification's own name, `Route`, is
// declared here as a stand-in library (probe/guide_names.dart).
import 'package:flutter/material.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_navigation/testing.dart';

import 'guide_names.dart';

void useNames(
  NavRoute<void> a, RouteRegistry b, NavIntent c, ResolvedNavIntent d,
  GoTo e, Replace f, Back g, BackTo h, ShowModal i, DismissModal j, DeepLink k,
  RouteState l, RouteTransition m, RouteAccessRequirement n, PublicAccess o,
  AuthenticatedAccess p, RoleAccess q, CustomAccess r, RouteAccessPolicy s,
  AccessPrincipal t, PendingPrincipal u, AnonymousPrincipal v,
  AuthenticatedPrincipal w, AccessRedirects x, NavigationEntry y, RouterCall z,
  PushRoute a1, ReplaceRoute b1, PopRoute c1, PopUntilRoute d1,
  RouteConfirmation e1, NavigationPlan f1, PerformCalls g1, RefuseIntent h1,
  NavigationRefusal i1, NavigationRouter j1, NavigationExecutor k1,
  NavigationRefused l1, LateExecutorConstruction m1,
) {}

// The top-level declarations and the testing library, beside Flutter's.
void useFunctions(AccessRedirect a, DeepLinkResolver b, InMemoryRouter c) {
  print(<Object?>[
    NavigationTopics.intent, navResolver, resultsFor, planNavigation,
    applyAuthGuard, resolveDeepLinks,
  ]);
}

// The Guide's spelling of the route type, beside Flutter's widgets library.
void guideRoute(Route<void> route) {}
