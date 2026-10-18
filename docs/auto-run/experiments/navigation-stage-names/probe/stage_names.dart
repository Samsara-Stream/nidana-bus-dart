// S1: the FunctionRefs the recorded nav-resolver carries, for both forms,
// with the stand-in's resolver as it is (closures) or as patched by run.sh
// (method tear-offs of private stage classes). The app's projection is a
// top-level function, so its own name is expected on the auth map.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

enum Auth { initializing, anonymous, user }

const StateTopic<Auth> authState =
    StateTopic<Auth>(name: 'probe.auth', initial: Auth.initializing);

AccessPrincipal principalOf(Auth auth) => switch (auth) {
      Auth.initializing => const PendingPrincipal(),
      Auth.anonymous => const AnonymousPrincipal(),
      Auth.user => AuthenticatedPrincipal(roles: <String>{'user'}),
    };

const NavRoute<void> home = NavRoute<void>('probe/home');
const NavRoute<ResolvedNavIntent> login = NavRoute<ResolvedNavIntent>('probe/login');

ResolvedNavIntent toLogin(ResolvedNavIntent attempted) => login.go(attempted);
ResolvedNavIntent resolveLink(Uri uri) => home.go();

const AccessRedirects redirects =
    AccessRedirects(unauthenticated: toLogin, forbidden: toLogin);

void show(String label, Topology t) {
  final TopologyDefinition d = t.buildDefinition();
  print('-- $label');
  for (final TransformEdge e in d.transforms) {
    print('  ${e.combinator?.name ?? 'write'} transformer=${e.transformer}');
  }
}

void main() {
  Topology reactive() => navResolver<Auth>(
      authState: authState,
      principalOf: principalOf,
      redirects: redirects,
      resolveDeepLink: resolveLink);
  Topology fixed() => navResolver<Auth>(
      authState: authState,
      principalOf: principalOf,
      redirects: redirects,
      resolveDeepLink: resolveLink,
      policy: RouteAccessPolicy.empty);
  show('reactive form', reactive());
  show('static form', fixed());
  print('two reactive resolvers record equal definitions: '
      '${reactive().buildDefinition() == reactive().buildDefinition()}');
  print('two static resolvers record equal definitions: '
      '${fixed().buildDefinition() == fixed().buildDefinition()}');
}
