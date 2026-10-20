// Conformance library for navigation-api@v1 (Guide §3; Spec Appendix A.6):
// routes, intents, route state and transitions, the access policy and
// principals, the navigation topics, the pure functions resolveDeepLinks,
// applyAuthGuard and planNavigation, the nav-resolver template recorded and
// live, result matching, and the in-memory router. Its cases are values; a
// binding registers them with a test runner. It imports neither
// package:test nor package:flutter_test. The declarations have one
// implementation, the producer's, so the cases construct them directly and
// run live topologies on bus-testing@v2's TestBus, asserting on its
// recorder; the harness only settles. The executor protocol, which has an
// implementation per platform, is navigation_executor_conformance.dart.
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_contracts/topology_plan.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_navigation/testing.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

/// What a binding supplies.
abstract interface class NavigationHarness {
  /// Brings the implementation to quiescence; the cases drive their own
  /// TestBus synchronously, so a binding has nothing left to run.
  Future<void> settle();
}

// ------------------------------------------------------------ routes

const NavRoute<void> _home = NavRoute<void>('suite/home');
const NavRoute<int> _detail = NavRoute<int>('suite/detail');
const NavRoute<String> _detailOfString = NavRoute<String>('suite/detail');
const NavRoute<void> _settings = NavRoute<void>('suite/settings');
const NavRoute<String> _sheet = NavRoute<String>('suite/sheet');
const NavRoute<void> _absent = NavRoute<void>('suite/absent');
const NavRoute<ResolvedNavIntent> _login =
    NavRoute<ResolvedNavIntent>('suite/login');
const NavRoute<ResolvedNavIntent> _denied =
    NavRoute<ResolvedNavIntent>('suite/denied');
const NavRoute<ResolvedNavIntent> _splash =
    NavRoute<ResolvedNavIntent>('suite/splash');

RouteState _at(NavRoute<Object?> route, [Object? args]) =>
    RouteState(route: route, args: args);

NavigationEntry _entry(NavRoute<Object?> route, [Object? args]) =>
    NavigationEntry(_at(route, args));

final Uri _link = Uri.parse('suite://app/detail/9');

// ------------------------------------------------------------ the app's auth

enum _Auth { initializing, anonymous, user, admin }

const StateTopic<_Auth> _auth =
    StateTopic<_Auth>(name: 'suite.auth', initial: _Auth.initializing);

AccessPrincipal _principalOf(_Auth auth) => switch (auth) {
      _Auth.initializing => const PendingPrincipal(),
      _Auth.anonymous => const AnonymousPrincipal(),
      _Auth.user => AuthenticatedPrincipal(roles: <String>{'user'}),
      _Auth.admin => AuthenticatedPrincipal(roles: <String>{'user', 'admin'}),
    };

ResolvedNavIntent _toLogin(ResolvedNavIntent attempted) => _login.go(attempted);
ResolvedNavIntent _toDenied(ResolvedNavIntent attempted) => _denied.go(attempted);
ResolvedNavIntent _toSplash(ResolvedNavIntent attempted) => _splash.go(attempted);

const AccessRedirects _redirects = AccessRedirects(
    unauthenticated: _toLogin, forbidden: _toDenied, pending: _toSplash);

ResolvedNavIntent _resolveLink(Uri uri) => switch (uri.pathSegments) {
      <String>['detail', final String id] => _detail.go(int.parse(id)),
      _ => _home.go(),
    };

final RouteAccessPolicy _guarded = RouteAccessPolicy(
    <NavRoute<Object?>, RouteAccessRequirement>{_detail: const AuthenticatedAccess()});

Topology _reactiveResolver() => navResolver<_Auth>(
      authState: _auth,
      principalOf: _principalOf,
      redirects: _redirects,
      resolveDeepLink: _resolveLink,
    );

Topology _staticResolver(RouteAccessPolicy policy) => navResolver<_Auth>(
      authState: _auth,
      principalOf: _principalOf,
      redirects: _redirects,
      resolveDeepLink: _resolveLink,
      policy: policy,
    );

/// A started TestBus with the reactive resolver active and the app's auth
/// and the access policy stubbed.
(TestBus, StateWriter<_Auth>, StateWriter<RouteAccessPolicy>) _resolving() {
  final TestBus bus = TestBus();
  bus.activate(_reactiveResolver());
  final StateWriter<_Auth> auth = bus.stub(_auth);
  final StateWriter<RouteAccessPolicy> policy =
      bus.stub(NavigationTopics.accessPolicy);
  bus.start();
  bus.scheduler.triggerActions();
  return (bus, auth, policy);
}

void _intent(TestBus bus, NavIntent intent) {
  bus.input.publish(NavigationTopics.intent, intent);
  bus.scheduler.triggerActions();
}

List<ResolvedNavIntent> _resolved(TestBus bus) =>
    bus.recorder.payloadsOf(NavigationTopics.resolvedIntent);

// ------------------------------------------------------------ result topics

final class _PickRequest {
  const _PickRequest(this.id);
  final int id;
}

final class _PickResult {
  const _PickResult(this.requestId, this.photo);
  final int requestId;
  final String photo;

  @override
  bool operator ==(Object other) =>
      other is _PickResult && other.requestId == requestId && other.photo == photo;

  @override
  int get hashCode => Object.hash(requestId, photo);
}

const EventTopic<_PickRequest> _pickRequested =
    EventTopic<_PickRequest>(name: 'suite.pick-requested');
const EventTopic<_PickResult> _pickResult =
    EventTopic<_PickResult>(name: 'suite.pick-result');
const EventTopic<_PickResult> _mine = EventTopic<_PickResult>(name: 'suite.mine');

bool _answers(_PickRequest request, _PickResult result) =>
    result.requestId == request.id;

Topology _picker() => topology('suite-picker', Scope.page, (TopologyBuilder b) {
      b.write(_mine,
          resultsFor(b.read(_pickResult), b.read(_pickRequested), _answers));
    });

String _empty() => '';

List<CombinatorKind?> _kinds(TopologyDefinition d) =>
    <CombinatorKind?>[for (final TransformEdge e in d.transforms) e.combinator];

/// The functions one plan of a nav-resolver holds, in G13's edge order: the
/// intent map's transformer, the auth map's, the withLatestFrom's combiner.
List<Function> _stageFunctions(Topology resolver) {
  final TopologyPlan plan = planOf(resolver);
  return <Function>[
    plan.stages.whereType<MapStage<NavIntent, Object?>>().single.transform,
    plan.stages.whereType<MapStage<_Auth, Object?>>().single.transform,
    plan.stages.whereType<WithLatestFromStage<ResolvedNavIntent, Object?>>().single.combiner,
  ];
}

final List<ConformanceCase<NavigationHarness>> navigationConformance =
    <ConformanceCase<NavigationHarness>>[
  // ------------------------------------------------------------ G1
  (
    name: 'G1 a deep link is a NavIntent and never a ResolvedNavIntent; the six other variants are resolved intents',
    body: (NavigationHarness h) async {
      final NavIntent link = DeepLink(_link);
      expect(link, isA<NavIntent>());
      expect(link is ResolvedNavIntent, isFalse);
      for (final NavIntent i in <NavIntent>[
        _home.go(), _home.replace(), const Back(), _home.backTo(),
        _sheet.showModal('s'), const DismissModal(),
      ]) {
        expect(i, isA<ResolvedNavIntent>());
      }
    },
  ),
  // ------------------------------------------------------------ G4
  (
    name: 'G4 lists, maps and sets the values expose are unmodifiable copies of their arguments',
    body: (NavigationHarness h) async {
      final Map<String, String> params = <String, String>{'id': '1'};
      final RouteState s =
          RouteState(route: _detail, args: 1, pathParams: params, queryParams: params);
      params['id'] = '2';
      expect(s.pathParams, <String, String>{'id': '1'});
      expect(s.queryParams, <String, String>{'id': '1'});
      expect(() => s.pathParams['x'] = 'y', throwsUnsupportedError);
      final Map<NavRoute<Object?>, RouteAccessRequirement> reqs =
          <NavRoute<Object?>, RouteAccessRequirement>{_detail: const AuthenticatedAccess()};
      final RouteAccessPolicy p = RouteAccessPolicy(reqs);
      reqs.clear();
      expect(p.requirements, hasLength(1));
      expect(() => p.requirements.clear(), throwsUnsupportedError);
      final Set<String> roles = <String>{'admin'};
      final RoleAccess r = RoleAccess(roles);
      final AuthenticatedPrincipal u = AuthenticatedPrincipal(roles: roles);
      roles.add('ops');
      expect(r.roles, <String>{'admin'});
      expect(u.roles, <String>{'admin'});
      expect(() => r.roles.add('x'), throwsUnsupportedError);
      final List<NavigationEntry> stack = <NavigationEntry>[_entry(_home)];
      final RouteConfirmation c = RouteConfirmation(stack: stack, intent: const Back());
      stack.add(_entry(_settings));
      expect(c.stack, hasLength(1));
      expect(() => c.stack.add(_entry(_home)), throwsUnsupportedError);
      final List<RouterCall> calls = <RouterCall>[const PopRoute()];
      final PerformCalls plan = PerformCalls(calls);
      calls.add(const PopRoute());
      expect(plan.calls, hasLength(1));
      final RouteRegistry reg = RouteRegistry(<NavRoute<Object?>>[_home]);
      expect(() => reg.routes.add(_settings), throwsUnsupportedError);
    },
  ),
  // ------------------------------------------------------------ G5
  (
    name: 'G5 two routes are equal, with equal hash codes, exactly when their paths and argument types are equal',
    body: (NavigationHarness h) async {
      expect(const NavRoute<int>('suite/detail'), _detail);
      expect(NavRoute<int>(_detail.path).hashCode, _detail.hashCode);
      expect(_detail == _detailOfString, isFalse);
      expect(_home == _settings, isFalse);
      expect(_detail.argsType, int);
      expect(_detail.path, 'suite/detail');
      expect(_detail.toString(), 'route:suite/detail');
    },
  ),
  (
    name: 'G5 NavRoute.none has the empty path, and an empty path is otherwise rejected when assertions are enabled',
    body: (NavigationHarness h) async {
      expect(NavRoute.none.path, '');
      var asserts = false;
      assert(asserts = true);
      if (asserts) {
        expect(() => NavRoute<void>(_empty()), throwsA(isA<AssertionError>()));
      }
    },
  ),
  (
    name: 'G5 argsOf is the arguments of a state of the route, typed by the route, and null for a state of another route',
    body: (NavigationHarness h) async {
      final int? id = _detail.argsOf(_at(_detail, 7));
      expect(id, 7);
      expect(_detail.argsOf(_at(_detail)), isNull);
      expect(_detail.argsOf(_at(_settings)), isNull);
      expect(_detail.argsOf(_at(_detailOfString, 'seven')), isNull);
      expect(const NavRoute<int>('suite/count').argsOf(_at(_detail, 7)), isNull);
      expect(_detail.argsOf(RouteState.initial), isNull);
    },
  ),
  // ------------------------------------------------------------ G6
  (
    name: 'G6 a route builds its intents: go, replace and showModal carry the route and the arguments, null when omitted, and backTo is BackTo(route)',
    body: (NavigationHarness h) async {
      final GoTo go = _detail.go(7);
      expect((go.route, go.args), (_detail, 7));
      final Replace replace = _detail.replace(8);
      expect((replace.route, replace.args), (_detail, 8));
      final ShowModal modal = _sheet.showModal('pick');
      expect((modal.route, modal.args), (_sheet, 'pick'));
      expect(_home.go().args, isNull);
      expect(_detail.backTo(), const BackTo(_detail));
    },
  ),
  (
    name: 'G6 intents are equal exactly when their variants and fields are equal',
    body: (NavigationHarness h) async {
      expect(_detail.go(7), _detail.go(7));
      expect(_detail.go(7).hashCode, _detail.go(7).hashCode);
      expect(_detail.go(7) == _detail.go(8), isFalse);
      expect(_detail.go(7) == _detail.replace(7), isFalse);
      expect(_sheet.go('a') == _sheet.showModal('a'), isFalse);
      expect(const Back(), const Back());
      expect(const DismissModal(), const DismissModal());
      expect(const Back() == const DismissModal(), isFalse);
      expect(DeepLink(_link), DeepLink(Uri.parse('suite://app/detail/9')));
      expect(DeepLink(_link) == DeepLink(Uri.parse('suite://app/home')), isFalse);
    },
  ),
  (
    name: 'G6 targetRoute is the route of GoTo, Replace, ShowModal and BackTo, and null for Back and DismissModal',
    body: (NavigationHarness h) async {
      expect(_detail.go(1).targetRoute, _detail);
      expect(_detail.replace(1).targetRoute, _detail);
      expect(_sheet.showModal('s').targetRoute, _sheet);
      expect(_detail.backTo().targetRoute, _detail);
      expect(const Back().targetRoute, isNull);
      expect(const DismissModal().targetRoute, isNull);
    },
  ),
  // ------------------------------------------------------------ G7
  (
    name: 'G7 a registry lists its routes once each in the order given and looks them up by path',
    body: (NavigationHarness h) async {
      final RouteRegistry reg =
          RouteRegistry(<NavRoute<Object?>>[_home, _detail, _home, _settings]);
      expect(reg.routes, <NavRoute<Object?>>[_home, _detail, _settings]);
      expect(reg.lookup('suite/detail'), _detail);
      expect(reg.lookup('suite/absent'), isNull);
      final RouteRegistry more = RouteRegistry(<NavRoute<Object?>>[_sheet, _home]);
      expect((reg + more).routes,
          <NavRoute<Object?>>[_home, _detail, _settings, _sheet]);
      expect(reg, RouteRegistry(<NavRoute<Object?>>[_home, _detail, _settings]));
    },
  ),
  (
    name: 'G7 a registry rejects one path under two argument types, and NavRoute.none, with ArgumentError',
    body: (NavigationHarness h) async {
      expect(() => RouteRegistry(<NavRoute<Object?>>[_detail, _detailOfString]),
          throwsArgumentError);
      expect(() => RouteRegistry(<NavRoute<Object?>>[NavRoute.none]), throwsArgumentError);
      expect(
          () => RouteRegistry(<NavRoute<Object?>>[_detail]) +
              RouteRegistry(<NavRoute<Object?>>[_detailOfString]),
          throwsArgumentError);
    },
  ),
  // ------------------------------------------------------------ G8
  (
    name: 'G8 a route state defaults to no arguments and no parameters, and RouteState.initial is NavRoute.none with nothing',
    body: (NavigationHarness h) async {
      final RouteState s = RouteState(route: _home);
      expect(s.args, isNull);
      expect(s.pathParams, isEmpty);
      expect(s.queryParams, isEmpty);
      expect(RouteState.initial.route, NavRoute.none);
      expect(RouteState.initial.args, isNull);
      expect(RouteState.initial.pathParams, isEmpty);
      expect(RouteState.initial.queryParams, isEmpty);
    },
  ),
  (
    name: 'G8 route states are equal exactly when route, arguments and both parameter maps are equal, maps compared by entries',
    body: (NavigationHarness h) async {
      RouteState s(Map<String, String> p) => RouteState(
          route: _detail, args: 1, pathParams: p, queryParams: const <String, String>{'q': 'x'});
      expect(s(<String, String>{'a': '1', 'b': '2'}), s(<String, String>{'b': '2', 'a': '1'}));
      expect(s(<String, String>{'a': '1'}).hashCode, s(<String, String>{'a': '1'}).hashCode);
      expect(s(<String, String>{'a': '1'}) == s(<String, String>{'a': '2'}), isFalse);
      expect(
          RouteState(route: _detail, queryParams: const <String, String>{'q': '1'}) ==
              RouteState(route: _detail, queryParams: const <String, String>{'q': '2'}),
          isFalse);
      expect(_at(_detail, 1) == _at(_detail, 2), isFalse);
      expect(_at(_detail, 1) == _at(_detailOfString, 1), isFalse);
    },
  ),
  (
    name: 'G8 route transitions are equal exactly when from, to, intent and timestamp are equal',
    body: (NavigationHarness h) async {
      final DateTime t = DateTime.utc(2000);
      RouteTransition tr(DateTime at) => RouteTransition(
          from: _at(_home), to: _at(_detail, 1), intent: _detail.go(1), timestamp: at);
      expect(tr(t), tr(DateTime.utc(2000)));
      expect(tr(t).hashCode, tr(DateTime.utc(2000)).hashCode);
      expect(tr(t) == tr(t.add(const Duration(milliseconds: 1))), isFalse);
      expect(
          tr(t) ==
              RouteTransition(
                  from: _at(_home), to: _at(_detail, 1), intent: _detail.replace(1), timestamp: t),
          isFalse);
    },
  ),
  // ------------------------------------------------------------ G9
  (
    name: 'G9 NavigationTopics declares the five navigation topics with the names, variants, types and initial values of Guide §3.3',
    body: (NavigationHarness h) async {
      expect(NavigationTopics.intent.ref,
          const TopicRef(name: 'nav.intent', variant: TopicVariant.event, typeName: 'NavIntent'));
      expect(
          NavigationTopics.resolvedIntent.ref,
          const TopicRef(
              name: 'nav.resolved-intent', variant: TopicVariant.event, typeName: 'ResolvedNavIntent'));
      expect(
          NavigationTopics.currentRoute.ref,
          const TopicRef(
              name: 'nav.current-route', variant: TopicVariant.state, typeName: 'RouteState'));
      expect(
          NavigationTopics.history.ref,
          const TopicRef(
              name: 'nav.history', variant: TopicVariant.replay, typeName: 'RouteTransition'));
      expect(
          NavigationTopics.accessPolicy.ref,
          const TopicRef(
              name: 'nav.access-policy', variant: TopicVariant.state, typeName: 'RouteAccessPolicy'));
      expect(NavigationTopics.history.bufferSize, 20);
      expect(NavigationTopics.currentRoute.createInitial(), RouteState.initial);
      expect(NavigationTopics.accessPolicy.createInitial(), RouteAccessPolicy.empty);
    },
  ),
  (
    name: 'G9 the navigation topics are not sensitive, are traced, deduplicate state by equality and have well-formed names',
    body: (NavigationHarness h) async {
      final List<Topic<Object?>> all = <Topic<Object?>>[
        NavigationTopics.intent,
        NavigationTopics.resolvedIntent,
        NavigationTopics.currentRoute,
        NavigationTopics.history,
        NavigationTopics.accessPolicy,
      ];
      for (final Topic<Object?> t in all) {
        expect(t.sensitive, isFalse);
        expect(t.tracing, Tracing.enabled);
        expect(isWellFormedTopicName(t.name), isTrue);
      }
      expect(NavigationTopics.currentRoute.dedup, Dedup.equality);
      expect(NavigationTopics.accessPolicy.dedup, Dedup.equality);
    },
  ),
  // ------------------------------------------------------------ G10
  (
    name: 'G10 a policy answers a listed route\'s requirement and its fallback for any other, PublicAccess unless given',
    body: (NavigationHarness h) async {
      expect(_guarded.requirementFor(_detail), const AuthenticatedAccess());
      expect(_guarded.requirementFor(_home), const PublicAccess());
      expect(_guarded.fallback, const PublicAccess());
      final RouteAccessPolicy closed = RouteAccessPolicy(
          <NavRoute<Object?>, RouteAccessRequirement>{_home: const PublicAccess()},
          fallback: const AuthenticatedAccess());
      expect(closed.requirementFor(_home), const PublicAccess());
      expect(closed.requirementFor(_settings), const AuthenticatedAccess());
      expect(RouteAccessPolicy.empty.requirements, isEmpty);
      expect(RouteAccessPolicy.empty.fallback, const PublicAccess());
      expect(RouteAccessPolicy.empty.requirementFor(_detail), const PublicAccess());
    },
  ),
  (
    name: 'G10 policies, requirements and principals are equal exactly when their fields are; RoleAccess rejects an empty set',
    body: (NavigationHarness h) async {
      expect(
          RouteAccessPolicy(<NavRoute<Object?>, RouteAccessRequirement>{
            _detail: const AuthenticatedAccess(),
            _home: const PublicAccess(),
          }),
          RouteAccessPolicy(<NavRoute<Object?>, RouteAccessRequirement>{
            _home: const PublicAccess(),
            _detail: const AuthenticatedAccess(),
          }));
      expect(_guarded == RouteAccessPolicy.empty, isFalse);
      expect(RouteAccessPolicy(<NavRoute<Object?>, RouteAccessRequirement>{}), RouteAccessPolicy.empty);
      expect(RoleAccess(<String>{'a', 'b'}), RoleAccess(<String>{'b', 'a'}));
      expect(RoleAccess(<String>{'a'}) == RoleAccess(<String>{'b'}), isFalse);
      expect(() => RoleAccess(<String>{}), throwsArgumentError);
      bool always(AccessPrincipal p) => true;
      expect(CustomAccess(always), CustomAccess(always));
      expect(AuthenticatedPrincipal(roles: <String>{'a'}),
          AuthenticatedPrincipal(roles: <String>{'a'}));
      expect(AuthenticatedPrincipal() == AuthenticatedPrincipal(roles: <String>{'a'}), isFalse);
      expect(AuthenticatedPrincipal().roles, isEmpty);
      expect(const PendingPrincipal() == const AnonymousPrincipal(), isFalse);
    },
  ),
  (
    name: 'G10 AccessRedirects.pending is the unauthenticated redirect when none is given',
    body: (NavigationHarness h) async {
      const AccessRedirects r =
          AccessRedirects(unauthenticated: _toLogin, forbidden: _toDenied);
      expect(r.pending, _toLogin);
      expect(_redirects.pending, _toSplash);
    },
  ),
  // ------------------------------------------------------------ G11
  (
    name: 'G11 resolveDeepLinks resolves a deep link with one call of the resolver, and returns any other intent itself without calling it',
    body: (NavigationHarness h) async {
      final List<Uri> calls = <Uri>[];
      ResolvedNavIntent resolve(Uri u) {
        calls.add(u);
        return _detail.go(9);
      }

      expect(resolveDeepLinks(DeepLink(_link), resolve), _detail.go(9));
      expect(calls, <Uri>[_link]);
      final GoTo go = _home.go();
      expect(resolveDeepLinks(go, resolve), same(go));
      expect(resolveDeepLinks(const Back(), resolve), const Back());
      expect(calls, hasLength(1));
    },
  ),
  // ------------------------------------------------------------ G12
  (
    name: 'G12 applyAuthGuard passes an intent with no target route, and one whose target is public, for every principal',
    body: (NavigationHarness h) async {
      final RouteAccessPolicy closed = RouteAccessPolicy(
          <NavRoute<Object?>, RouteAccessRequirement>{_home: const PublicAccess()},
          fallback: const AuthenticatedAccess());
      for (final AccessPrincipal p in <AccessPrincipal>[
        const PendingPrincipal(), const AnonymousPrincipal(), AuthenticatedPrincipal(),
      ]) {
        for (final ResolvedNavIntent i in <ResolvedNavIntent>[
          const Back(), const DismissModal(), _home.go(), _home.backTo(),
        ]) {
          expect(applyAuthGuard(i, p, closed, _redirects), same(i));
        }
      }
    },
  ),
  (
    name: 'G12 an authenticated requirement passes an authenticated principal and redirects a pending one to pending and an anonymous one to unauthenticated, with the attempted intent',
    body: (NavigationHarness h) async {
      final GoTo go = _detail.go(1);
      expect(applyAuthGuard(go, AuthenticatedPrincipal(), _guarded, _redirects), same(go));
      expect(applyAuthGuard(go, const PendingPrincipal(), _guarded, _redirects), _splash.go(go));
      expect(applyAuthGuard(go, const AnonymousPrincipal(), _guarded, _redirects), _login.go(go));
      final BackTo back = _detail.backTo();
      expect(applyAuthGuard(back, const AnonymousPrincipal(), _guarded, _redirects), _login.go(back));
      final ShowModal modal = _detail.showModal(1);
      expect(applyAuthGuard(modal, const AnonymousPrincipal(), _guarded, _redirects), _login.go(modal));
    },
  ),
  (
    name: 'G12 a role requirement passes an authenticated principal holding any of its roles and redirects any other authenticated one to forbidden',
    body: (NavigationHarness h) async {
      final RouteAccessPolicy roles = RouteAccessPolicy(
          <NavRoute<Object?>, RouteAccessRequirement>{_detail: RoleAccess(<String>{'admin', 'ops'})});
      final GoTo go = _detail.go(1);
      expect(applyAuthGuard(go, AuthenticatedPrincipal(roles: <String>{'ops'}), roles, _redirects),
          same(go));
      expect(applyAuthGuard(go, AuthenticatedPrincipal(roles: <String>{'user'}), roles, _redirects),
          _denied.go(go));
      expect(applyAuthGuard(go, AuthenticatedPrincipal(), roles, _redirects), _denied.go(go));
      expect(applyAuthGuard(go, const AnonymousPrincipal(), roles, _redirects), _login.go(go));
      expect(applyAuthGuard(go, const PendingPrincipal(), roles, _redirects), _splash.go(go));
    },
  ),
  (
    name: 'G12 a custom requirement passes when its test holds and otherwise redirects by the principal: pending, unauthenticated or forbidden',
    body: (NavigationHarness h) async {
      final List<AccessPrincipal> asked = <AccessPrincipal>[];
      bool never(AccessPrincipal p) {
        asked.add(p);
        return false;
      }

      bool always(AccessPrincipal p) => true;
      final GoTo go = _detail.go(1);
      final RouteAccessPolicy no = RouteAccessPolicy(
          <NavRoute<Object?>, RouteAccessRequirement>{_detail: CustomAccess(never)});
      final RouteAccessPolicy yes = RouteAccessPolicy(
          <NavRoute<Object?>, RouteAccessRequirement>{_detail: CustomAccess(always)});
      expect(applyAuthGuard(go, const AnonymousPrincipal(), yes, _redirects), same(go));
      expect(applyAuthGuard(go, const PendingPrincipal(), no, _redirects), _splash.go(go));
      expect(applyAuthGuard(go, const AnonymousPrincipal(), no, _redirects), _login.go(go));
      expect(applyAuthGuard(go, AuthenticatedPrincipal(), no, _redirects), _denied.go(go));
      expect(asked, <AccessPrincipal>[
        const PendingPrincipal(), const AnonymousPrincipal(), AuthenticatedPrincipal(),
      ]);
    },
  ),
  // ------------------------------------------------------------ G13
  (
    name: 'G13 the reactive nav-resolver is an APPLICATION topology that resolves intents, then guards them with the latest principal and access policy, and writes nav.resolved-intent',
    body: (NavigationHarness h) async {
      final Topology t = _reactiveResolver();
      expect(t.topologyId, 'nav-resolver');
      expect(t.scope, Scope.application);
      final TopologyDefinition d = t.buildDefinition();
      expect(d.reads, <TopicRef>{
        NavigationTopics.intent.ref, _auth.ref, NavigationTopics.accessPolicy.ref,
      });
      expect(d.writes, <TopicRef>{NavigationTopics.resolvedIntent.ref});
      expect(_kinds(d), <CombinatorKind?>[
        CombinatorKind.map, CombinatorKind.map, CombinatorKind.withLatestFrom, null,
      ]);
      expect(d.transforms[0].inputs, <EdgeInput>[TopicInput(NavigationTopics.intent.ref)]);
      expect(d.transforms[1].inputs, <EdgeInput>[TopicInput(_auth.ref)]);
      expect(d.transforms[2].inputs, <EdgeInput>[
        const StageInput(0), const StageInput(1), TopicInput(NavigationTopics.accessPolicy.ref),
      ]);
      expect(d.transforms[3].inputs, <EdgeInput>[const StageInput(2)]);
      expect(d.transforms[3].output, NavigationTopics.resolvedIntent.ref);
    },
  ),
  (
    name: 'G13 given a static policy the nav-resolver does not read nav.access-policy',
    body: (NavigationHarness h) async {
      final TopologyDefinition d = _staticResolver(_guarded).buildDefinition();
      expect(d.reads, <TopicRef>{NavigationTopics.intent.ref, _auth.ref});
      expect(_kinds(d), <CombinatorKind?>[
        CombinatorKind.map, CombinatorKind.map, CombinatorKind.withLatestFrom, null,
      ]);
      expect(d.transforms[2].inputs, <EdgeInput>[const StageInput(0), const StageInput(1)]);
    },
  ),
  (
    name: 'G13 two nav-resolvers built from one configuration record equal definitions',
    body: (NavigationHarness h) async {
      expect(_reactiveResolver().buildDefinition(), _reactiveResolver().buildDefinition());
      expect(_staticResolver(_guarded).buildDefinition(),
          _staticResolver(_guarded).buildDefinition());
    },
  ),
  (
    name: 'G13 both nav-resolver forms name their stage functions: resolveDeepLinks on the intent map, the given projection on the auth map, applyAuthGuard on the withLatestFrom',
    body: (NavigationHarness h) async {
      for (final (String form, TopologyDefinition d) in <(String, TopologyDefinition)>[
        ('reactive', _reactiveResolver().buildDefinition()),
        ('static', _staticResolver(_guarded).buildDefinition()),
      ]) {
        expect(d.transforms[0].transformer, FunctionRef.named('resolveDeepLinks'),
            reason: form);
        expect(d.transforms[1].transformer, FunctionRef.of(_principalOf), reason: form);
        expect(d.transforms[2].transformer, FunctionRef.named('applyAuthGuard'),
            reason: form);
      }
    },
  ),
  (
    name: 'G13 one nav-resolver holds the same stage functions in every plan of it, and another navResolver call holds its own resolution and guard functions',
    body: (NavigationHarness h) async {
      for (final (String form, Topology Function() make) in <(String, Topology Function())>[
        ('reactive', _reactiveResolver),
        ('static', () => _staticResolver(_guarded)),
      ]) {
        final Topology resolver = make();
        final List<Function> first = _stageFunctions(resolver);
        expect(_stageFunctions(resolver), equals(first), reason: form);
        final List<Function> other = _stageFunctions(make());
        expect(other[0], isNot(equals(first[0])), reason: '$form: resolveDeepLinks');
        expect(other[1], equals(first[1]), reason: '$form: the given projection');
        expect(other[2], isNot(equals(first[2])), reason: '$form: applyAuthGuard');
      }
    },
  ),
  // ------------------------------------------------------------ G14
  (
    name: 'G14 the live nav-resolver publishes one resolved intent per intent, in order, guarded with the latest principal and policy',
    body: (NavigationHarness h) async {
      final (TestBus bus, StateWriter<_Auth> auth, StateWriter<RouteAccessPolicy> policy) =
          _resolving();
      policy.publish(_guarded);
      _intent(bus, _home.go());
      _intent(bus, _detail.go(1));
      auth.publish(_Auth.anonymous);
      _intent(bus, _detail.go(2));
      auth.publish(_Auth.user);
      _intent(bus, _detail.go(3));
      policy.publish(RouteAccessPolicy(
          <NavRoute<Object?>, RouteAccessRequirement>{_detail: RoleAccess(<String>{'admin'})}));
      _intent(bus, _detail.go(4));
      _intent(bus, const Back());
      expect(_resolved(bus), <ResolvedNavIntent>[
        _home.go(),
        _splash.go(_detail.go(1)),
        _login.go(_detail.go(2)),
        _detail.go(3),
        _denied.go(_detail.go(4)),
        const Back(),
      ]);
    },
  ),
  (
    name: 'G14 the live nav-resolver resolves a deep link before it guards it',
    body: (NavigationHarness h) async {
      final (TestBus bus, StateWriter<_Auth> auth, StateWriter<RouteAccessPolicy> policy) =
          _resolving();
      policy.publish(_guarded);
      auth.publish(_Auth.anonymous);
      _intent(bus, DeepLink(_link));
      auth.publish(_Auth.user);
      _intent(bus, DeepLink(_link));
      expect(_resolved(bus), <ResolvedNavIntent>[_login.go(_detail.go(9)), _detail.go(9)]);
    },
  ),
  (
    name: 'G14 a nav-resolver with a static policy ignores nav.access-policy',
    body: (NavigationHarness h) async {
      final TestBus bus = TestBus();
      bus.activate(_staticResolver(RouteAccessPolicy.empty));
      final StateWriter<RouteAccessPolicy> policy = bus.stub(NavigationTopics.accessPolicy);
      bus.start();
      policy.publish(_guarded);
      _intent(bus, _detail.go(1));
      expect(_resolved(bus), <ResolvedNavIntent>[_detail.go(1)]);
    },
  ),
  (
    name: 'G14 a resolved intent is published by the nav-resolver, caused by the intent\'s envelope and in its flow',
    body: (NavigationHarness h) async {
      final (TestBus bus, StateWriter<_Auth> _, StateWriter<RouteAccessPolicy> _) = _resolving();
      _intent(bus, _home.go());
      final MessageEnvelope<NavIntent> cause =
          bus.recorder.envelopesOf(NavigationTopics.intent).single;
      final MessageEnvelope<ResolvedNavIntent> out =
          bus.recorder.envelopesOf(NavigationTopics.resolvedIntent).single;
      expect(out.source, const TopologySource('nav-resolver'));
      expect(out.causationId, cause.id);
      expect(out.correlationId, cause.correlationId);
    },
  ),
  // ------------------------------------------------------------ G15
  (
    name: 'G15 the nav-resolver reads nothing an executor writes, and with an executor constructed the live graph has no finding',
    body: (NavigationHarness h) async {
      for (final Topology t in <Topology>[_reactiveResolver(), _staticResolver(_guarded)]) {
        final Set<TopicRef> reads = t.buildDefinition().reads;
        expect(reads.contains(NavigationTopics.currentRoute.ref), isFalse);
        expect(reads.contains(NavigationTopics.history.ref), isFalse);
        expect(reads.contains(NavigationTopics.resolvedIntent.ref), isFalse);
      }
      final TestBus bus = TestBus();
      bus.activate(_reactiveResolver());
      NavigationExecutor(bus, InMemoryRouter(_at(_home)));
      expect(analyzeTopologyGraph(bus.toGraph()), isEmpty);
    },
  ),
  (
    name: 'G15 a topology that feeds resolved intents back into nav.intent forms a cycle with the nav-resolver and is not activated',
    body: (NavigationHarness h) async {
      final TestBus bus = TestBus();
      bus.activate(_reactiveResolver());
      expect(
          () => bus.activate(topology('suite-echo', Scope.application,
              (TopologyBuilder b) =>
                  b.write(NavigationTopics.intent, b.read(NavigationTopics.resolvedIntent)))),
          throwsA(isA<ActivationRejected>().having(
              (ActivationRejected e) => e.findings.single, 'finding', isA<TopologyCycle>())));
    },
  ),
  // ------------------------------------------------------------ G16
  (
    name: 'G16 resultsFor records a withLatestFrom on the requests, a filter and a map, and nothing else',
    body: (NavigationHarness h) async {
      final TopologyDefinition d = _picker().buildDefinition();
      expect(d.reads, <TopicRef>{_pickResult.ref, _pickRequested.ref});
      expect(_kinds(d), <CombinatorKind?>[
        CombinatorKind.withLatestFrom, CombinatorKind.filter, CombinatorKind.map, null,
      ]);
      expect(d.transforms[0].inputs,
          <EdgeInput>[TopicInput(_pickResult.ref), TopicInput(_pickRequested.ref)]);
    },
  ),
  (
    name: 'G16 resultsFor passes exactly the results that answer the latest request, matched on payloads, and drops results that arrive before any request',
    body: (NavigationHarness h) async {
      final TestBus bus = TestBus();
      bus.start();
      bus.activate(_picker());
      bus.scheduler.triggerActions();
      void publish<T>(EventTopic<T> topic, T value) {
        bus.input.publish(topic, value);
        bus.scheduler.triggerActions();
      }

      publish(_pickResult, const _PickResult(1, 'early'));
      publish(_pickRequested, const _PickRequest(1));
      publish(_pickResult, const _PickResult(2, 'other'));
      publish(_pickResult, const _PickResult(1, 'first'));
      publish(_pickRequested, const _PickRequest(2));
      publish(_pickResult, const _PickResult(1, 'stale'));
      publish(_pickResult, const _PickResult(2, 'second'));
      expect(bus.recorder.payloadsOf(_mine),
          <_PickResult>[const _PickResult(1, 'first'), const _PickResult(2, 'second')]);
    },
  ),
  // ------------------------------------------------------------ G17
  (
    name: 'G17 planNavigation pushes for GoTo, pushes a modal entry for ShowModal and replaces the top for Replace',
    body: (NavigationHarness h) async {
      final List<NavigationEntry> stack = <NavigationEntry>[_entry(_home)];
      for (final bool popUntil in <bool>[true, false]) {
        expect(planNavigation(stack, _detail.go(1), supportsPopUntil: popUntil),
            PerformCalls(<RouterCall>[PushRoute(_entry(_detail, 1))]));
        expect(planNavigation(stack, _sheet.showModal('s'), supportsPopUntil: popUntil),
            PerformCalls(<RouterCall>[
              PushRoute(NavigationEntry(_at(_sheet, 's'), modal: true)),
            ]));
        expect(planNavigation(stack, _settings.replace(), supportsPopUntil: popUntil),
            PerformCalls(<RouterCall>[ReplaceRoute(_entry(_settings))]));
      }
    },
  ),
  (
    name: 'G17 planNavigation pops for Back and for DismissModal over a modal entry, and refuses Back at the root and DismissModal with no modal on top',
    body: (NavigationHarness h) async {
      final List<NavigationEntry> root = <NavigationEntry>[_entry(_home)];
      final List<NavigationEntry> two = <NavigationEntry>[_entry(_home), _entry(_detail, 1)];
      final List<NavigationEntry> modal = <NavigationEntry>[
        _entry(_home), NavigationEntry(_at(_sheet, 's'), modal: true),
      ];
      final List<NavigationEntry> modalRoot = <NavigationEntry>[
        NavigationEntry(_at(_sheet, 's'), modal: true),
      ];
      expect(planNavigation(two, const Back(), supportsPopUntil: true),
          PerformCalls(const <RouterCall>[PopRoute()]));
      expect(planNavigation(root, const Back(), supportsPopUntil: true),
          const RefuseIntent(NavigationRefusal.backAtRoot));
      expect(planNavigation(modal, const DismissModal(), supportsPopUntil: true),
          PerformCalls(const <RouterCall>[PopRoute()]));
      expect(planNavigation(two, const DismissModal(), supportsPopUntil: true),
          const RefuseIntent(NavigationRefusal.noModalToDismiss));
      expect(planNavigation(modalRoot, const DismissModal(), supportsPopUntil: true),
          const RefuseIntent(NavigationRefusal.backAtRoot));
    },
  ),
  (
    name: 'G17 planNavigation pops to the nearest entry of a BackTo route, natively or as one pop per entry above it, does nothing when it is on top, and refuses it when it is absent',
    body: (NavigationHarness h) async {
      final List<NavigationEntry> stack = <NavigationEntry>[
        _entry(_home), _entry(_settings), _entry(_detail, 1), _entry(_settings), _entry(_detail, 2),
      ];
      expect(planNavigation(stack, _settings.backTo(), supportsPopUntil: true),
          PerformCalls(const <RouterCall>[PopUntilRoute(_settings)]));
      expect(planNavigation(stack, _settings.backTo(), supportsPopUntil: false),
          PerformCalls(const <RouterCall>[PopRoute()]));
      expect(planNavigation(stack, _home.backTo(), supportsPopUntil: false),
          PerformCalls(const <RouterCall>[PopRoute(), PopRoute(), PopRoute(), PopRoute()]));
      expect(planNavigation(stack, _detail.backTo(), supportsPopUntil: true),
          PerformCalls(const <RouterCall>[]));
      expect(planNavigation(stack, _absent.backTo(), supportsPopUntil: true),
          const RefuseIntent(NavigationRefusal.targetNotOnStack));
    },
  ),
  (
    name: 'G17 planNavigation rejects an empty stack with ArgumentError and leaves the stack it is given unchanged',
    body: (NavigationHarness h) async {
      expect(() => planNavigation(const <NavigationEntry>[], const Back(), supportsPopUntil: true),
          throwsArgumentError);
      final List<NavigationEntry> stack =
          List<NavigationEntry>.unmodifiable(<NavigationEntry>[_entry(_home), _entry(_detail, 1)]);
      expect(planNavigation(stack, _home.backTo(), supportsPopUntil: true),
          planNavigation(stack, _home.backTo(), supportsPopUntil: true));
      expect(stack, hasLength(2));
    },
  ),
  // ------------------------------------------------------------ G25
  (
    name: 'G25 an in-memory router starts at its initial route, pops until natively unless told not to, and confirms each perform before it returns',
    body: (NavigationHarness h) async {
      final InMemoryRouter r = InMemoryRouter(_at(_home));
      expect(r.stack, <NavigationEntry>[_entry(_home)]);
      expect(r.supportsPopUntil, isTrue);
      expect(InMemoryRouter(_at(_home), supportsPopUntil: false).supportsPopUntil, isFalse);
      final List<RouteConfirmation> got = <RouteConfirmation>[];
      r.confirmations.listen(got.add);
      r.perform(<RouterCall>[PushRoute(_entry(_detail, 1))], _detail.go(1));
      expect(got, <RouteConfirmation>[
        RouteConfirmation(
            stack: <NavigationEntry>[_entry(_home), _entry(_detail, 1)], intent: _detail.go(1)),
      ]);
    },
  ),
  (
    name: 'G25 an in-memory router records the calls of every perform it carried out, in order, and platformBack pops and confirms with Back',
    body: (NavigationHarness h) async {
      final InMemoryRouter r = InMemoryRouter(_at(_home), supportsPopUntil: false);
      final List<RouteConfirmation> got = <RouteConfirmation>[];
      r.confirmations.listen(got.add);
      r.perform(<RouterCall>[PushRoute(_entry(_detail, 1)), PushRoute(_entry(_settings))],
          _settings.go());
      expect(() => r.perform(const <RouterCall>[PopUntilRoute(_home)], _home.backTo()),
          throwsStateError);
      r.perform(const <RouterCall>[PopRoute()], const Back());
      expect(r.performed, <List<RouterCall>>[
        <RouterCall>[PushRoute(_entry(_detail, 1)), PushRoute(_entry(_settings))],
        const <RouterCall>[PopRoute()],
      ]);
      got.clear();
      r.platformBack();
      r.platformBack();
      expect(r.stack, <NavigationEntry>[_entry(_home)]);
      expect(got, <RouteConfirmation>[
        RouteConfirmation(stack: <NavigationEntry>[_entry(_home)], intent: const Back()),
      ]);
    },
  ),
];
