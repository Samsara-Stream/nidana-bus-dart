// Surface fixture for navigation-api@v1 (ADR-001 item 4): the access policy,
// principals and redirects, the pure functions, the nav-resolver template
// and result matching, used with the types the Interface states. Exhaustive
// switches over RouteAccessRequirement and AccessPrincipal fail this set
// when a variant is added.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';

enum AuthState { initializing, signedOut, signedIn }

const StateTopic<AuthState> authState =
    StateTopic<AuthState>(name: 'auth.state', initial: AuthState.initializing, sensitive: true);

const NavRoute<void> home = NavRoute<void>('app/home');
const NavRoute<int> account = NavRoute<int>('app/account');
const NavRoute<ResolvedNavIntent> login = NavRoute<ResolvedNavIntent>('auth/login');

AccessPrincipal principalOf(AuthState state) => switch (state) {
      AuthState.initializing => const PendingPrincipal(),
      AuthState.signedOut => const AnonymousPrincipal(),
      AuthState.signedIn => AuthenticatedPrincipal(roles: <String>{'customer'}),
    };

ResolvedNavIntent toLogin(ResolvedNavIntent attempted) => login.go(attempted);

ResolvedNavIntent resolveUri(Uri uri) => home.go();

bool onboarded(AccessPrincipal principal) => principal is AuthenticatedPrincipal;

String requirement(RouteAccessRequirement r) => switch (r) {
      PublicAccess() => 'public',
      AuthenticatedAccess() => 'authenticated',
      RoleAccess(:final Set<String> roles) => 'roles $roles',
      CustomAccess(:final bool Function(AccessPrincipal) test) => 'custom $test',
    };

String principal(AccessPrincipal p) => switch (p) {
      PendingPrincipal() => 'pending',
      AnonymousPrincipal() => 'anonymous',
      AuthenticatedPrincipal(:final Set<String> roles) => 'authenticated $roles',
    };

final RouteAccessPolicy policy = RouteAccessPolicy(
  <NavRoute<Object?>, RouteAccessRequirement>{
    home: const PublicAccess(),
    account: RoleAccess(<String>{'customer'}),
    login: const CustomAccess(onboarded),
  },
  fallback: const AuthenticatedAccess(),
);

const AccessRedirects redirects = AccessRedirects(
  unauthenticated: toLogin,
  forbidden: toLogin,
  pending: toLogin,
);

void access() {
  const RouteAccessPolicy empty = RouteAccessPolicy.empty;
  final Map<NavRoute<Object?>, RouteAccessRequirement> listed = policy.requirements;
  final RouteAccessRequirement fallback = policy.fallback;
  final RouteAccessRequirement forAccount = policy.requirementFor(account);
  final Set<String> roles = RoleAccess(<String>{'admin'}).roles;
  final bool Function(AccessPrincipal) test = const CustomAccess(onboarded).test;
  final Set<String> held = AuthenticatedPrincipal().roles;
  final AccessRedirect unauthenticated = redirects.unauthenticated;
  final AccessRedirect forbidden = redirects.forbidden;
  final AccessRedirect pending = redirects.pending;
  const AccessRedirects twoOnly = AccessRedirects(unauthenticated: toLogin, forbidden: toLogin);
  print(<Object?>[
    empty, listed, fallback, forAccount, roles, test, held, unauthenticated,
    forbidden, pending, twoOnly,
  ]);
}

void functions() {
  const DeepLinkResolver resolver = resolveUri;
  final ResolvedNavIntent r = resolveDeepLinks(DeepLink(Uri.parse('app://home')), resolver);
  final ResolvedNavIntent g =
      applyAuthGuard(r, principalOf(AuthState.signedIn), policy, redirects);
  print(<Object?>[r, g]);
}

final Topology reactive = navResolver<AuthState>(
  authState: authState,
  principalOf: principalOf,
  redirects: redirects,
  resolveDeepLink: resolveUri,
);

final Topology fixed = navResolver<AuthState>(
  authState: authState,
  principalOf: principalOf,
  redirects: redirects,
  resolveDeepLink: resolveUri,
  policy: policy,
);

final class PickRequest {
  const PickRequest(this.id);
  final int id;
}

final class PickResult {
  const PickResult(this.requestId);
  final int requestId;
}

const EventTopic<PickRequest> pickRequested = EventTopic<PickRequest>(name: 'profile.pick-requested');
const EventTopic<PickResult> pickResult = EventTopic<PickResult>(name: 'media.picker-result');
const EventTopic<PickResult> selected = EventTopic<PickResult>(name: 'profile.photo-selected');

bool answers(PickRequest request, PickResult result) => result.requestId == request.id;

final Topology editor = topology('profile-editor', Scope.page, (TopologyBuilder b) {
  final TopicStream<PickResult> mine =
      resultsFor<PickRequest, PickResult>(b.read(pickResult), b.read(pickRequested), answers);
  b.write(selected, mine);
});
