// Conformance library for the executor protocol of navigation-api@v1
// (Guide §3.2, §3.4, §3.5; Spec §3.11, §3.13, Appendix A.6): the router port
// a platform implements, and NavigationExecutor driving it on a bus. Its
// cases are values; a binding registers them with a test runner. It imports
// neither package:test nor package:flutter_test and names no bus-testing@v2
// type: a binding supplies a bus and the implementation under test through
// NavigationExecutorHarness, so one suite binds on the VM (a TestBus and the
// in-memory router, in_memory_router_test.dart) and under testWidgets (a
// production-provider bus and a Flutter router, bound by flutter-binding@v2).
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

/// One implementation under test: the executor and the router it drives.
typedef NavigationRun = ({NavigationExecutor executor, NavigationRouter router});

/// What a binding supplies.
abstract interface class NavigationExecutorHarness {
  /// A fresh bus built from [config], not started. On the VM a bus on a
  /// virtual provider; under testWidgets a production-provider bus built in
  /// the test body, which the binding shuts down before the body ends.
  Bus bus([BusConfig config = const BusConfig()]);

  /// The implementation under test on [bus]: a router whose stack is
  /// [initial] alone, not modal, and a NavigationExecutor over it named
  /// [name], constructed before this returns. Called at most once per case.
  Future<NavigationRun> executor(Bus bus, RouteState initial,
      {String name = 'navigation'});

  /// The platform's own back action on [router], such as a system back
  /// button, followed by settling.
  Future<void> platformBack(NavigationRouter router);

  /// Moves the clock of every bus of this harness forward by [duration],
  /// running what falls due.
  Future<void> elapse(Duration duration);

  /// Brings every bus and router of this harness to quiescence: queued
  /// microtasks run and pending confirmations are delivered.
  Future<void> settle();
}

// ------------------------------------------------------------ routes

const NavRoute<void> _home = NavRoute<void>('suite/home');
const NavRoute<int> _detail = NavRoute<int>('suite/detail');
const NavRoute<void> _settings = NavRoute<void>('suite/settings');
const NavRoute<String> _sheet = NavRoute<String>('suite/sheet');
const NavRoute<void> _absent = NavRoute<void>('suite/absent');
const NavRoute<ResolvedNavIntent> _login =
    NavRoute<ResolvedNavIntent>('suite/login');

final RouteState _homeState = RouteState(route: _home);

RouteState _at(NavRoute<Object?> route, [Object? args]) =>
    RouteState(route: route, args: args);

NavigationEntry _entry(NavRoute<Object?> route, [Object? args]) =>
    NavigationEntry(_at(route, args));

// ------------------------------------------------------------ topics

const StateTopic<bool> _signedIn =
    StateTopic<bool>(name: 'suite.signed-in', initial: true);
const StateTopic<bool> _signedOut =
    StateTopic<bool>(name: 'suite.signed-out', initial: false);
const EventTopic<RouteState> _rival =
    EventTopic<RouteState>(name: 'suite.rival-route');

// ------------------------------------------------------------ helpers

const ServiceSource _pages = ServiceSource('suite-pages');

void _discard(BusDiagnostic diagnostic) {}

const BusConfig _quiet = BusConfig(diagnostics: _discard);

/// A bus with [config] and the implementation under test on it, at home,
/// started and settled; and a publisher standing in for pages.
Future<(Bus, NavigationRun, Publisher)> _started(NavigationExecutorHarness h,
    [BusConfig config = _quiet]) async {
  final Bus bus = h.bus(config);
  final NavigationRun run = await h.executor(bus, _homeState);
  bus.start();
  await h.settle();
  return (bus, run, bus.publisher(_pages));
}

Future<void> _navigate(
    NavigationExecutorHarness h, Publisher pages, ResolvedNavIntent intent) async {
  pages.publish(NavigationTopics.resolvedIntent, intent);
  await h.settle();
}

List<RouteState> _states(NavigationRouter router) =>
    <RouteState>[for (final NavigationEntry e in router.stack) e.state];

RouteState _current(Bus bus) => bus.getCurrentValue(NavigationTopics.currentRoute);

List<RouteTransition> _history(Bus bus) =>
    bus.getBufferedValues(NavigationTopics.history);

List<RouteConfirmation> _confirmed(NavigationRouter router) {
  final List<RouteConfirmation> got = <RouteConfirmation>[];
  router.confirmations.listen(got.add);
  return got;
}

bool _within(DateTime t, DateTime from, DateTime to) =>
    !t.isBefore(from) && !t.isAfter(to);

ResolvedNavIntent _resolveSuiteLink(Uri uri) => switch (uri.pathSegments) {
      <String>['detail', final String id] => _detail.go(int.parse(id)),
      _ => _home.go(),
    };

AccessPrincipal _principal(bool signedIn) =>
    signedIn ? AuthenticatedPrincipal() : const AnonymousPrincipal();

ResolvedNavIntent _toLogin(ResolvedNavIntent attempted) => _login.go(attempted);

Topology _resolver(StateTopic<bool> auth) => navResolver<bool>(
      authState: auth,
      principalOf: _principal,
      redirects: const AccessRedirects(unauthenticated: _toLogin, forbidden: _toLogin),
      resolveDeepLink: _resolveSuiteLink,
      policy: RouteAccessPolicy(
          <NavRoute<Object?>, RouteAccessRequirement>{_detail: const AuthenticatedAccess()}),
    );

/// Records the topic of every envelope the bus delivers, in delivery order.
final class _Order implements BusObserver {
  final List<String> topics = <String>[];

  @override
  Set<ObserverCapability> get capabilities =>
      const <ObserverCapability>{ObserverCapability.observeAll};

  @override
  void onPublish(TopicRef topic, MessageEnvelope<Object?> envelope,
          ObserveContext context) =>
      topics.add(topic.name);
}

final List<ConformanceCase<NavigationExecutorHarness>>
    navigationExecutorConformance = <ConformanceCase<NavigationExecutorHarness>>[
  // ------------------------------------------------------------ G18
  (
    name: 'G18 a router\'s stack starts as the initial entry alone, not modal, and reflects each perform as soon as it returns',
    body: (NavigationExecutorHarness h) async {
      final Bus bus = h.bus(_quiet);
      final NavigationRun run = await h.executor(bus, _homeState);
      final NavigationRouter r = run.router;
      expect(r.stack, <NavigationEntry>[NavigationEntry(_homeState)]);
      bus.start();
      await h.settle();
      final NavigationEntry d1 = _entry(_detail, 1);
      final NavigationEntry sheet = NavigationEntry(_at(_sheet, 's'), modal: true);
      r.perform(<RouterCall>[PushRoute(d1), PushRoute(sheet)], _sheet.showModal('s'));
      expect(r.stack, <NavigationEntry>[NavigationEntry(_homeState), d1, sheet]);
      r.perform(<RouterCall>[ReplaceRoute(_entry(_settings))], _settings.replace());
      expect(r.stack,
          <NavigationEntry>[NavigationEntry(_homeState), d1, _entry(_settings)]);
      r.perform(const <RouterCall>[PopRoute()], const Back());
      expect(r.stack, <NavigationEntry>[NavigationEntry(_homeState), d1]);
      expect(() => r.stack.add(d1), throwsUnsupportedError);
      await h.settle();
    },
  ),
  (
    name: 'G18 a router confirms each perform once, after its calls complete, with the stack they leave and the intent it was given',
    body: (NavigationExecutorHarness h) async {
      final (Bus _, NavigationRun run, Publisher _) = await _started(h);
      final List<RouteConfirmation> got = _confirmed(run.router);
      final GoTo intent = _detail.go(1);
      run.router.perform(<RouterCall>[
        PushRoute(_entry(_detail, 1)),
        PushRoute(_entry(_settings)),
        const PopRoute(),
      ], intent);
      await h.settle();
      expect(got, <RouteConfirmation>[
        RouteConfirmation(
            stack: <NavigationEntry>[NavigationEntry(_homeState), _entry(_detail, 1)],
            intent: intent),
      ]);
    },
  ),
  (
    name: 'G18 PopUntilRoute pops to the nearest entry of its route on a router that supports it, and is refused with StateError on one that does not',
    body: (NavigationExecutorHarness h) async {
      final (Bus _, NavigationRun run, Publisher _) = await _started(h);
      final NavigationRouter r = run.router;
      r.perform(<RouterCall>[
        PushRoute(_entry(_settings)),
        PushRoute(_entry(_detail, 1)),
        PushRoute(_entry(_settings)),
        PushRoute(_entry(_detail, 2)),
      ], _detail.go(2));
      await h.settle();
      if (r.supportsPopUntil) {
        r.perform(<RouterCall>[const PopUntilRoute(_settings)], _settings.backTo());
        expect(_states(r), <RouteState>[
          _homeState, _at(_settings), _at(_detail, 1), _at(_settings),
        ]);
      } else {
        expect(
            () => r.perform(
                <RouterCall>[const PopUntilRoute(_settings)], _settings.backTo()),
            throwsStateError);
        expect(r.stack, hasLength(5));
      }
      await h.settle();
    },
  ),
  (
    name: 'G18 a perform with no calls, or one that would empty the stack or pop to a route not on it, throws and changes and confirms nothing',
    body: (NavigationExecutorHarness h) async {
      final (Bus _, NavigationRun run, Publisher _) = await _started(h);
      final NavigationRouter r = run.router;
      final List<RouteConfirmation> got = _confirmed(r);
      expect(() => r.perform(const <RouterCall>[], const Back()), throwsArgumentError);
      expect(() => r.perform(const <RouterCall>[PopRoute()], const Back()),
          throwsStateError);
      expect(
          () => r.perform(<RouterCall>[
                PushRoute(_entry(_detail, 1)),
                const PopRoute(),
                const PopRoute(),
              ], const Back()),
          throwsStateError);
      if (r.supportsPopUntil) {
        expect(
            () => r.perform(<RouterCall>[const PopUntilRoute(_absent)], _absent.backTo()),
            throwsStateError);
      }
      await h.settle();
      expect(r.stack, <NavigationEntry>[NavigationEntry(_homeState)]);
      expect(got, isEmpty);
    },
  ),
  (
    name: 'G18 a platform back pops the top entry and is confirmed once with Back; at the root it changes and confirms nothing',
    body: (NavigationExecutorHarness h) async {
      final (Bus _, NavigationRun run, Publisher pages) = await _started(h);
      final NavigationRouter r = run.router;
      final List<RouteConfirmation> got = _confirmed(r);
      await h.platformBack(r);
      expect(r.stack, <NavigationEntry>[NavigationEntry(_homeState)]);
      expect(got, isEmpty);
      await _navigate(h, pages, _detail.go(1));
      got.clear();
      await h.platformBack(r);
      expect(r.stack, <NavigationEntry>[NavigationEntry(_homeState)]);
      expect(got, <RouteConfirmation>[
        RouteConfirmation(
            stack: <NavigationEntry>[NavigationEntry(_homeState)], intent: const Back()),
      ]);
    },
  ),
  // ------------------------------------------------------------ G19
  (
    name: 'G19 constructing an executor claims nav.current-route for ExecutorSource(name)',
    body: (NavigationExecutorHarness h) async {
      final Bus bus = h.bus(_quiet);
      final NavigationRun run =
          await h.executor(bus, _homeState, name: 'suite-executor');
      expect(run.executor.source, const ExecutorSource('suite-executor'));
      expect(run.executor.router, same(run.router));
      expect(run.executor.isDisposed, isFalse);
      expect(bus.toGraph().claims, <ShellClaim>[
        ShellClaim(
            source: const ExecutorSource('suite-executor'),
            writes: <TopicRef>{NavigationTopics.currentRoute.ref}),
      ]);
    },
  ),
  (
    name: 'G19 a second claimant of nav.current-route is rejected: another executor or publisher throws ClaimRejected, and a topology writing it is not activated',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher _) = await _started(h);
      expect(() => NavigationExecutor(bus, run.router, name: 'rival'),
          throwsA(isA<ClaimRejected>()));
      expect(
          () => bus.publisher(const ServiceSource('rival'),
              writes: <StateTopic<Object?>>{NavigationTopics.currentRoute}),
          throwsA(isA<ClaimRejected>()));
      expect(
          () => bus.activate(topology('suite-rival', Scope.application,
              (TopologyBuilder b) => b.write(NavigationTopics.currentRoute, b.read(_rival)))),
          throwsA(isA<ActivationRejected>()));
      expect(bus.toGraph().claims, hasLength(1));
      expect(bus.toGraph().claims.single.source, const ExecutorSource('navigation'));
    },
  ),
  (
    name: 'G19 at construction the executor writes the router\'s top entry to nav.current-route, delivered at start(), and nothing to nav.history',
    body: (NavigationExecutorHarness h) async {
      final Bus bus = h.bus(_quiet);
      await h.executor(bus, _homeState);
      expect(_current(bus), RouteState.initial);
      bus.start();
      await h.settle();
      expect(_current(bus), _homeState);
      expect(_history(bus), isEmpty);
    },
  ),
  (
    name: 'G19 in dev mode an executor constructed after start() is reported as LateExecutorConstruction, and works',
    body: (NavigationExecutorHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final Bus bus = h.bus(BusConfig(devMode: true, diagnostics: d.add));
      bus.start();
      final NavigationRun run = await h.executor(bus, _homeState, name: 'late');
      await h.settle();
      expect(d, hasLength(1));
      expect(d.single, isA<LateExecutorConstruction>());
      expect((d.single as LateExecutorConstruction).origin, 'executor:late');
      expect(_current(bus), _homeState);
      await _navigate(h, bus.publisher(_pages), _detail.go(1));
      expect(_states(run.router), <RouteState>[_homeState, _at(_detail, 1)]);
    },
  ),
  // ------------------------------------------------------------ G20
  (
    name: 'G20 GoTo pushes its route with its arguments',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      await _navigate(h, pages, _detail.go(7));
      expect(run.router.stack,
          <NavigationEntry>[NavigationEntry(_homeState), _entry(_detail, 7)]);
      expect(_current(bus), _at(_detail, 7));
      expect(_detail.argsOf(_current(bus)), 7);
    },
  ),
  (
    name: 'G20 Replace replaces the top entry',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      await _navigate(h, pages, _detail.go(1));
      await _navigate(h, pages, _settings.replace());
      expect(_states(run.router), <RouteState>[_homeState, _at(_settings)]);
      expect(_current(bus), _at(_settings));
    },
  ),
  (
    name: 'G20 ShowModal pushes a modal entry and DismissModal pops it',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      await _navigate(h, pages, _sheet.showModal('pick'));
      expect(run.router.stack.last,
          NavigationEntry(_at(_sheet, 'pick'), modal: true));
      expect(_current(bus), _at(_sheet, 'pick'));
      await _navigate(h, pages, const DismissModal());
      expect(run.router.stack, <NavigationEntry>[NavigationEntry(_homeState)]);
      expect(_current(bus), _homeState);
    },
  ),
  (
    name: 'G20 Back pops the top entry',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      await _navigate(h, pages, _detail.go(1));
      await _navigate(h, pages, _settings.go());
      await _navigate(h, pages, const Back());
      expect(_states(run.router), <RouteState>[_homeState, _at(_detail, 1)]);
      expect(_current(bus), _at(_detail, 1));
    },
  ),
  (
    name: 'G20 BackTo pops to the nearest entry of its route as one transition, whether or not the router pops until natively',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      await _navigate(h, pages, _settings.go());
      await _navigate(h, pages, _detail.go(1));
      await _navigate(h, pages, _settings.go());
      await _navigate(h, pages, _detail.go(2));
      final int before = _history(bus).length;
      await _navigate(h, pages, _settings.backTo());
      expect(_states(run.router), <RouteState>[
        _homeState, _at(_settings), _at(_detail, 1), _at(_settings),
      ]);
      expect(_history(bus), hasLength(before + 1));
      expect(_history(bus).last.from, _at(_detail, 2));
      expect(_history(bus).last.to, _at(_settings));
      expect(_history(bus).last.intent, _settings.backTo());
      expect(_current(bus), _at(_settings));
    },
  ),
  (
    name: 'G20 BackTo the route on top changes nothing and writes nothing',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      await _navigate(h, pages, _detail.go(1));
      await _navigate(h, pages, _detail.backTo());
      expect(_states(run.router), <RouteState>[_homeState, _at(_detail, 1)]);
      expect(_history(bus), hasLength(1));
    },
  ),
  (
    name: 'G20 an intent the stack does not admit is refused: nothing navigates or is written, and dev mode reports NavigationRefused with its reason',
    body: (NavigationExecutorHarness h) async {
      final List<BusDiagnostic> d = <BusDiagnostic>[];
      final (Bus bus, NavigationRun run, Publisher pages) =
          await _started(h, BusConfig(devMode: true, diagnostics: d.add));
      await _navigate(h, pages, const Back());
      await _navigate(h, pages, _absent.backTo());
      await _navigate(h, pages, const DismissModal());
      await _navigate(h, pages, _detail.go(1));
      await _navigate(h, pages, const DismissModal());
      final List<NavigationRefused> refused = d.whereType<NavigationRefused>().toList();
      expect(<(NavigationRefusal, NavRoute<Object?>?)>[
        for (final NavigationRefused r in refused) (r.reason, r.route),
      ], <(NavigationRefusal, NavRoute<Object?>?)>[
        (NavigationRefusal.backAtRoot, null),
        (NavigationRefusal.targetNotOnStack, _absent),
        (NavigationRefusal.noModalToDismiss, null),
        (NavigationRefusal.noModalToDismiss, null),
      ]);
      expect(refused.map((NavigationRefused r) => r.origin).toSet(),
          <String>{'executor:navigation'});
      expect(_states(run.router), <RouteState>[_homeState, _at(_detail, 1)]);
      expect(_history(bus), hasLength(1));
    },
  ),
  (
    name: 'G20 resolved intents are performed in the order they are delivered',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      pages.publish(NavigationTopics.resolvedIntent, _detail.go(1));
      pages.publish(NavigationTopics.resolvedIntent, _settings.go());
      pages.publish(NavigationTopics.resolvedIntent, const Back());
      await h.settle();
      expect(_states(run.router), <RouteState>[_homeState, _at(_detail, 1)]);
      expect(_history(bus).map((RouteTransition t) => t.intent),
          <ResolvedNavIntent>[_detail.go(1), _settings.go(), const Back()]);
    },
  ),
  (
    name: 'G20 the executor acts on nav.resolved-intent only: an intent on nav.intent with no resolver active navigates nothing',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      pages.publish(NavigationTopics.intent, _detail.go(1));
      await h.settle();
      expect(_states(run.router), <RouteState>[_homeState]);
      expect(_history(bus), isEmpty);
    },
  ),
  // ------------------------------------------------------------ G21
  (
    name: 'G21 each confirmed transition writes nav.current-route and then nav.history, with no delivery between them',
    body: (NavigationExecutorHarness h) async {
      final _Order order = _Order();
      final Bus bus = h.bus(_quiet);
      bus.addObserver(order);
      final NavigationRun run = await h.executor(bus, _homeState);
      bus.start();
      await h.settle();
      final Publisher pages = bus.publisher(_pages);
      await _navigate(h, pages, _detail.go(1));
      await _navigate(h, pages, _sheet.showModal('s'));
      await h.platformBack(run.router);
      await _navigate(h, pages, _home.backTo());
      final List<String> written = order.topics
          .where((String t) => t == 'nav.current-route' || t == 'nav.history')
          .toList();
      expect(written, <String>[
        'nav.current-route',
        for (var i = 0; i < 4; i++) ...<String>['nav.current-route', 'nav.history'],
      ]);
      for (var i = 0; i < order.topics.length; i++) {
        if (order.topics[i] == 'nav.history') {
          expect(order.topics[i - 1], 'nav.current-route');
        }
      }
    },
  ),
  (
    name: 'G21 a transition runs from the previously confirmed route to the new top with the intent the router confirmed, and the history ends at nav.current-route',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      await _navigate(h, pages, _detail.go(1));
      await _navigate(h, pages, _sheet.showModal('s'));
      await h.platformBack(run.router);
      await _navigate(h, pages, _settings.replace());
      await _navigate(h, pages, _home.backTo());
      final List<RouteTransition> hist = _history(bus);
      expect(<(RouteState, RouteState, ResolvedNavIntent)>[
        for (final RouteTransition t in hist) (t.from, t.to, t.intent),
      ], <(RouteState, RouteState, ResolvedNavIntent)>[
        (_homeState, _at(_detail, 1), _detail.go(1)),
        (_at(_detail, 1), _at(_sheet, 's'), _sheet.showModal('s')),
        (_at(_sheet, 's'), _at(_detail, 1), const Back()),
        (_at(_detail, 1), _at(_settings), _settings.replace()),
        (_at(_settings), _homeState, _home.backTo()),
      ]);
      for (var i = 1; i < hist.length; i++) {
        expect(hist[i].from, hist[i - 1].to);
      }
      expect(hist.last.to, _current(bus));
      expect(_current(bus), run.router.stack.last.state);
    },
  ),
  (
    name: 'G21 transitions confirmed before the earlier ones are delivered still run each from the previous one',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun _, Publisher pages) = await _started(h);
      pages.publish(NavigationTopics.resolvedIntent, _detail.go(1));
      pages.publish(NavigationTopics.resolvedIntent, _settings.go());
      pages.publish(NavigationTopics.resolvedIntent, const Back());
      await h.settle();
      expect(<(RouteState, RouteState)>[
        for (final RouteTransition t in _history(bus)) (t.from, t.to),
      ], <(RouteState, RouteState)>[
        (_homeState, _at(_detail, 1)),
        (_at(_detail, 1), _at(_settings)),
        (_at(_settings), _at(_detail, 1)),
      ]);
    },
  ),
  // ------------------------------------------------------------ G22
  (
    name: 'G22 a transition is stamped with the bus clock at its confirmation',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun _, Publisher pages) = await _started(h);
      final DateTime t0 = bus.clock.now();
      await _navigate(h, pages, _detail.go(1));
      final DateTime t1 = bus.clock.now();
      await h.elapse(const Duration(seconds: 5));
      final DateTime t2 = bus.clock.now();
      await _navigate(h, pages, const Back());
      final DateTime t3 = bus.clock.now();
      final List<RouteTransition> hist = _history(bus);
      expect(_within(hist[0].timestamp, t0, t1), isTrue);
      expect(_within(hist[1].timestamp, t2, t3), isTrue);
      expect(hist[1].timestamp.difference(hist[0].timestamp) >= const Duration(seconds: 5),
          isTrue);
    },
  ),
  // ------------------------------------------------------------ G23
  (
    name: 'G23 dispose is idempotent, releases the claim and stops the executor: later intents and confirmations write nothing',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher pages) = await _started(h);
      await _navigate(h, pages, _detail.go(1));
      run.executor.dispose();
      run.executor.dispose();
      expect(run.executor.isDisposed, isTrue);
      expect(bus.toGraph().claims, isEmpty);
      await _navigate(h, pages, _settings.go());
      expect(_states(run.router), <RouteState>[_homeState, _at(_detail, 1)]);
      await h.platformBack(run.router);
      expect(_current(bus), _at(_detail, 1));
      expect(_history(bus), hasLength(1));
      final NavigationExecutor again = NavigationExecutor(bus, run.router);
      await h.settle();
      expect(again.isDisposed, isFalse);
      expect(bus.toGraph().claims, hasLength(1));
      expect(_current(bus), _homeState);
    },
  ),
  (
    name: 'G23 shutting the bus down disposes the executor',
    body: (NavigationExecutorHarness h) async {
      final (Bus bus, NavigationRun run, Publisher _) = await _started(h);
      bus.shutdown();
      expect(run.executor.isDisposed, isTrue);
    },
  ),
  // ------------------------------------------------------------ G24
  (
    name: 'G24 a deep link published before start(), with the resolver activated and the executor constructed before start(), is resolved and executed once the bus starts',
    body: (NavigationExecutorHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus
          .publisher(const ServiceSource('suite-bootstrap'))
          .publish(NavigationTopics.intent, DeepLink(Uri.parse('suite://app/detail/5')));
      bus.activate(_resolver(_signedIn));
      final NavigationRun run = await h.executor(bus, _homeState);
      bus.start();
      await h.settle();
      expect(_states(run.router), <RouteState>[_homeState, _at(_detail, 5)]);
      expect(_history(bus).single.intent, _detail.go(5));
      expect(analyzeTopologyGraph(bus.toGraph()), isEmpty);
    },
  ),
  (
    name: 'G24 a deep link to a guarded route at bootstrap is guarded after it is resolved',
    body: (NavigationExecutorHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus
          .publisher(const ServiceSource('suite-bootstrap'))
          .publish(NavigationTopics.intent, DeepLink(Uri.parse('suite://app/detail/5')));
      bus.activate(_resolver(_signedOut));
      final NavigationRun run = await h.executor(bus, _homeState);
      bus.start();
      await h.settle();
      expect(_states(run.router),
          <RouteState>[_homeState, _at(_login, _detail.go(5))]);
    },
  ),
];
