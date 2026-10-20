// navigation-api-v0151 probe P1 to P4: what the nav-resolver and the
// executor see at bootstrap under Spec v0.15.1 §3.13 (bus-api@v2 G34, G14),
// for the facts navigation-api restates in Refinement 8 and in the
// nav.access-policy paragraph. Run against each runtime:
//   fvm dart run probe/bootstrap_probe.dart
//
// The app here: auth is a state topic whose value is an authenticated user
// without the admin role; the deep link resolves to detail(5). Under the
// empty policy detail(5) passes; under the locked policy, which requires the
// admin role for detail, it is redirected to denied(detail(5)). So the
// resolved intent shows which policy guarded the deep link.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_navigation/testing.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const NavRoute<void> _home = NavRoute<void>('p/home');
const NavRoute<int> _detail = NavRoute<int>('p/detail');
const NavRoute<ResolvedNavIntent> _login = NavRoute<ResolvedNavIntent>('p/login');
const NavRoute<ResolvedNavIntent> _denied = NavRoute<ResolvedNavIntent>('p/denied');

const StateTopic<bool> _signedIn = StateTopic<bool>(name: 'p.signed-in', initial: true);
const StateTopic<bool> _locked = StateTopic<bool>(name: 'p.locked', initial: true);
const EventTopic<bool> _lockEvent = EventTopic<bool>(name: 'p.lock-event');
const StateTopic<int> _startAt = StateTopic<int>(name: 'p.start-at', initial: 3);

AccessPrincipal _principal(bool signedIn) => signedIn
    ? AuthenticatedPrincipal(roles: <String>{'user'})
    : const AnonymousPrincipal();
ResolvedNavIntent _toLogin(ResolvedNavIntent a) => _login.go(a);
ResolvedNavIntent _toDenied(ResolvedNavIntent a) => _denied.go(a);
ResolvedNavIntent _resolve(Uri uri) => switch (uri.pathSegments) {
      <String>['detail', final String id] => _detail.go(int.parse(id)),
      _ => _home.go(),
    };

final RouteAccessPolicy _lockedPolicy = RouteAccessPolicy(
    <NavRoute<Object?>, RouteAccessRequirement>{_detail: RoleAccess(<String>{'admin'})});

RouteAccessPolicy _policyOf(bool locked) =>
    locked ? _lockedPolicy : RouteAccessPolicy.empty;

Topology _reactiveResolver() => navResolver<bool>(
      authState: _signedIn,
      principalOf: _principal,
      redirects: const AccessRedirects(unauthenticated: _toLogin, forbidden: _toDenied),
      resolveDeepLink: _resolve,
    );

/// Owns nav.access-policy, computed from a state topic at its connection.
Topology _policyFromState() => topology('p-policy', Scope.application,
    (TopologyBuilder b) => b.write(NavigationTopics.accessPolicy, b.read(_locked).map(_policyOf)));

/// Owns nav.access-policy, computed from each lock event.
Topology _policyFromEvent() => topology('p-policy', Scope.application,
    (TopologyBuilder b) =>
        b.write(NavigationTopics.accessPolicy, b.read(_lockEvent).map(_policyOf)));

NavIntent _startIntent(int id) => _detail.go(id);
ResolvedNavIntent _startResolved(int id) => _detail.go(id);

/// Publishes an intent to nav.intent from a state topic, so once at its
/// connection.
Topology _startsAtConnection() => topology('p-start', Scope.application,
    (TopologyBuilder b) => b.write(NavigationTopics.intent, b.read(_startAt).map(_startIntent)));

/// An app's own resolver (Refinement 2) that publishes a resolved intent at
/// its connection.
Topology _ownResolverAtConnection() => topology('p-own-resolver', Scope.application,
    (TopologyBuilder b) =>
        b.write(NavigationTopics.resolvedIntent, b.read(_startAt).map(_startResolved)));

final Uri _link = Uri.parse('p://app/detail/5');
const ServiceSource _boot = ServiceSource('p-bootstrap');
const BusConfig _quiet = BusConfig(devMode: false);

String _resolved(TestBus bus) =>
    bus.recorder.payloadsOf(NavigationTopics.resolvedIntent).join(', ');

void p1(bool resolverFirst) {
  final TestBus bus = TestBus(_quiet);
  bus.publisher(_boot).publish(NavigationTopics.intent, DeepLink(_link));
  if (resolverFirst) {
    bus.activate(_reactiveResolver());
    bus.activate(_policyFromState());
  } else {
    bus.activate(_policyFromState());
    bus.activate(_reactiveResolver());
  }
  bus.start();
  bus.scheduler.triggerActions();
  print('P1 policy topology from a state topic, '
      '${resolverFirst ? 'resolver activated first' : 'policy topology activated first'}: '
      'resolved [${_resolved(bus)}]');
}

void p2() {
  final TestBus bus = TestBus(_quiet);
  final Publisher boot = bus.publisher(_boot);
  boot.publish(_lockEvent, true);
  boot.publish(NavigationTopics.intent, DeepLink(_link));
  bus.activate(_reactiveResolver());
  bus.activate(_policyFromEvent());
  bus.start();
  final String atStartReturn = _resolved(bus);
  final RouteAccessPolicy policyAtReturn = bus.getCurrentValue(NavigationTopics.accessPolicy);
  bus.scheduler.triggerActions();
  print('P2 policy topology from a lock event queued before the deep link: '
      'resolved [${_resolved(bus)}]; when start() returned: resolved [$atStartReturn], '
      'policy locked: ${policyAtReturn == _lockedPolicy}; delivery order: '
      '${bus.recorder.envelopes.map((RecordedEnvelope r) => r.topic.name).join(', ')}');
}

void p3(bool policyFirst) {
  final TestBus bus = TestBus(_quiet);
  final Publisher boot = bus.publisher(_boot);
  final Publisher owner =
      bus.publisher(const ServiceSource('p-policy-owner'), writes: <StateTopic<Object?>>{
    NavigationTopics.accessPolicy,
  });
  if (policyFirst) owner.writer(NavigationTopics.accessPolicy).publish(_lockedPolicy);
  boot.publish(NavigationTopics.intent, DeepLink(_link));
  if (!policyFirst) owner.writer(NavigationTopics.accessPolicy).publish(_lockedPolicy);
  bus.activate(_reactiveResolver());
  bus.start();
  bus.scheduler.triggerActions();
  print('P3 claimed publisher, policy published '
      '${policyFirst ? 'before' : 'after'} the deep link, both before start(): '
      'resolved [${_resolved(bus)}]');
}

void p4() {
  final TestBus bus = TestBus(_quiet);
  bus.activate(_reactiveResolver());
  bus.activate(_startsAtConnection());
  final InMemoryRouter router = InMemoryRouter(RouteState(route: _home));
  NavigationExecutor(bus, router);
  bus.start();
  bus.scheduler.triggerActions();
  print('P4a a topology publishing to nav.intent at its connection: '
      'nav.intent delivered [${bus.recorder.payloadsOf(NavigationTopics.intent).join(', ')}], '
      'resolved [${_resolved(bus)}], router stack '
      '[${router.stack.map((NavigationEntry e) => e.state.route.path).join(', ')}]');

  final TestBus own = TestBus(_quiet);
  own.activate(_ownResolverAtConnection());
  final InMemoryRouter ownRouter = InMemoryRouter(RouteState(route: _home));
  NavigationExecutor(own, ownRouter);
  own.start();
  own.scheduler.triggerActions();
  print('P4b an own resolver publishing to nav.resolved-intent at its connection, '
      'executor constructed before start(): resolved delivered [${_resolved(own)}], router stack '
      '[${ownRouter.stack.map((NavigationEntry e) => e.state.route.path).join(', ')}]');
}

void main() {
  p1(true);
  p1(false);
  p2();
  p3(true);
  p3(false);
  p4();
}
