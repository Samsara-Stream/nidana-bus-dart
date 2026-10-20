// Conformance library for flutter-binding@v2 (Spec §2.4, §2.5, §3.1, §3.13,
// §7.1 to §7.3, §11.2, Appendix A.8; Guide §3.4, §3.5, §6.3, §6.4;
// Rationale §5.1; ADR-003 item 7): the bus provider, the topic widgets, page
// and module scope binding, the module wrapper widget, the Flutter router and
// executor, platform routes, the bootstrap, and the widget-test bus. Its
// cases are values; a binding registers them under testWidgets. It imports
// neither package:test nor package:flutter_test: the binding supplies the
// widget tester's operations through FlutterBindingHarness, and the cases
// observe the tree through their own widgets and NavigatorObservers, never
// through finders. A case mounts a page or module scope only after start(),
// as bus-api@v2 G42 requires, except the cases that pin that rejection.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';
import 'package:nidana_dart_runtime_flutter/testing.dart';

/// What a binding supplies: the widget tester's operations, and buses.
abstract interface class FlutterBindingHarness {
  /// A fresh production-provider bus built from [config] in the test body,
  /// not started. The binding shuts every such bus down before the body
  /// ends (ADR-003 item 7).
  Bus bus([BusConfig config = const BusConfig()]);

  /// Makes [widget] the root of the tree and pumps a frame.
  Future<void> pumpWidget(Widget widget);

  /// Runs queued microtasks, moves the clock by [duration] firing what falls
  /// due, and pumps a frame.
  Future<void> pump([Duration duration = Duration.zero]);

  /// Pumps frames until none is scheduled.
  Future<void> pumpAndSettle();

  /// The platform's back action: the navigation channel's popRoute message,
  /// then pumpAndSettle.
  Future<void> platformBack();

  /// The platform pushing route information with [location]: the navigation
  /// channel's pushRouteInformation message, then pumpAndSettle.
  Future<void> platformPushRoute(String location);

  /// Sets the platform's initial route name for the rest of the case.
  void setPlatformInitialRoute(String name);

  /// The exception the framework caught since the last call, or null.
  Object? takeException();
}

// ------------------------------------------------------------ topics and routes

const StateTopic<int> _count = StateTopic<int>(name: 'fb.count', initial: 0);
const StateTopic<int> _other = StateTopic<int>(name: 'fb.other', initial: 100);
const ReplayTopic<String> _log = ReplayTopic<String>(name: 'fb.log', bufferSize: 3);
const EventTopic<int> _taps = EventTopic<int>(name: 'fb.taps');
const StateTopic<int> _pageState = StateTopic<int>(name: 'fb.page-state', initial: 0);
const StateTopic<int> _claimed = StateTopic<int>(name: 'fb.claimed', initial: 0);
const EventTopic<int> _moduleTaps = EventTopic<int>(name: 'fb.module-taps');
const StateTopic<bool> _signedIn = StateTopic<bool>(name: 'fb.signed-in', initial: true);
const StateTopic<int> _derived = StateTopic<int>(name: 'fb.derived', initial: -1);
const StateTopic<int> _closureState = StateTopic<int>(name: 'fb.closure-state', initial: 0);

const ServiceSource _owner = ServiceSource('fb-owner');

const NavRoute<void> _home = NavRoute<void>('fb/home');
const NavRoute<int> _detail = NavRoute<int>('fb/detail');
const NavRoute<String> _sheet = NavRoute<String>('fb/sheet');
const NavRoute<void> _orders = NavRoute<void>('fb/orders');

final RouteState _homeState = RouteState(route: _home);

NavigationEntry _entry(NavRoute<Object?> route, [Object? args]) =>
    NavigationEntry(RouteState(route: route, args: args));

Topology _pageTopology([String id = 'fb-page']) => topology(
    id, Scope.page, (TopologyBuilder b) => b.write(_pageState, b.read(_taps)));

int _double(int v) => v * 2;

/// A PAGE topology whose transformer is a top-level function, so every
/// evaluation of its declaration is equal (bus-api@v2 G23; Guide §6.3).
Topology _namedPageTopology() => topology('fb-named-page', Scope.page,
    (TopologyBuilder b) => b.write(_pageState, b.read(_taps).map(_double)));

/// A PAGE topology whose declaration passes an inline closure, which equals
/// no other evaluation (bus-api@v2 G23).
Topology _closurePageTopology() => topology('fb-closure-page', Scope.page,
    (TopologyBuilder b) => b.write(_closureState, b.read(_taps).map((int v) => v * 2)));

int _plusOne(int v) => v + 1;
String _label(int v) => 'n$v';

/// An APPLICATION topology that writes [_derived] from [_count], so its
/// connection at start() sets [_derived] with no publish after it.
Topology _derivedTopology() => topology('fb-derived', Scope.application,
    (TopologyBuilder b) => b.write(_derived, b.read(_count).map(_plusOne)));

/// An APPLICATION topology that appends a label of [_count] to [_log].
Topology _labelTopology() => topology('fb-label', Scope.application,
    (TopologyBuilder b) => b.write(_log, b.read(_count).map(_label)));

/// A MODULE topology owning a state topic of its own, named after [id].
Topology _moduleTopology([String id = 'fb-checkout']) => topology(id, Scope.module,
    (TopologyBuilder b) => b.write(StateTopic<int>(name: 'fb.$id', initial: 0), b.read(_moduleTaps)));

void _discard(BusDiagnostic diagnostic) {}

const BusConfig _quiet = BusConfig(diagnostics: _discard);

Widget _text(String s) => Text(s, textDirection: TextDirection.ltr);

List<String> _active(Bus bus) =>
    <String>[for (final TopologyDefinition d in bus.toGraph().topologies) d.topologyId];

/// A production-provider bus built in the test body inside an error zone of
/// its own, which is then its provider zone (ADR-003), with the errors that
/// reach that zone's handler. The case shuts it down itself.
(Bus, List<Object>) _guardedBus() {
  final List<Object> errors = <Object>[];
  late final Bus bus;
  runZonedGuarded(() => bus = Bus(_quiet), (Object error, StackTrace _) => errors.add(error));
  return (bus, errors);
}

// ------------------------------------------------------------ helper widgets

/// Calls [onDispose] from its own dispose.
final class _DisposeProbe extends StatefulWidget {
  const _DisposeProbe(this.onDispose);
  final void Function() onDispose;
  @override
  State<_DisposeProbe> createState() => _DisposeProbeState();
}

final class _DisposeProbeState extends State<_DisposeProbe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Hands its BuildContext to [onBuild] at every build.
final class _Context extends StatelessWidget {
  const _Context(this.onBuild);
  final void Function(BuildContext context) onBuild;
  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return const SizedBox();
  }
}

/// Mirrors the routes of the Navigator it observes, bottom first.
final class _Mirror extends NavigatorObserver {
  final List<Route<dynamic>> routes = <Route<dynamic>>[];

  List<String?> get paths =>
      <String?>[for (final Route<dynamic> r in routes) ModuleScopeObserver.pathOf(r)];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final int i = routes.indexOf(oldRoute!);
    routes[i] = newRoute!;
  }
}

/// Records every activation's topology id.
final class _Activations implements ActivationObserver {
  final List<String> ids = <String>[];
  @override
  Set<ObserverCapability> get capabilities =>
      const <ObserverCapability>{ObserverCapability.observeAll};
  @override
  void onPublish(TopicRef topic, MessageEnvelope<Object?> envelope, ObserveContext context) {}
  @override
  void onActivate(String topologyId, Scope scope, ObserveContext context) => ids.add(topologyId);
}

Route<dynamic> Function(NavigationEntry, RouteSettings) _pages(
        [Widget Function(NavigationEntry entry)? content]) =>
    (NavigationEntry entry, RouteSettings settings) => PageRouteBuilder<void>(
          settings: settings,
          fullscreenDialog: entry.modal,
          pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
              content == null ? _text(entry.state.route.path) : content(entry),
        );

Route<dynamic> _named(String name, [Widget? child]) => PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
          child ?? _text(name),
    );

/// A WidgetsApp hosting [router], with [observers] beside the router's.
Widget _host(FlutterNavigationRouter router,
        {List<NavigatorObserver> observers = const <NavigatorObserver>[]}) =>
    WidgetsApp(
      navigatorKey: router.navigatorKey,
      navigatorObservers: <NavigatorObserver>[router.observer, ...observers],
      onGenerateInitialRoutes: router.initialRoutes,
      onGenerateRoute: router.generateRoute,
      color: const Color(0xFF000000),
    );

/// A WidgetsApp of plain named routes, starting with [initial].
Widget _namedApp(GlobalKey<NavigatorState> key, List<String> initial,
        List<NavigatorObserver> observers) =>
    WidgetsApp(
      navigatorKey: key,
      navigatorObservers: observers,
      onGenerateInitialRoutes: (String _) =>
          <Route<dynamic>>[for (final String n in initial) _named(n)],
      onGenerateRoute: (RouteSettings s) => _named(s.name!),
      color: const Color(0xFF000000),
    );

Topology _resolver() => navResolver<bool>(
      authState: _signedIn,
      principalOf: (bool s) => s ? AuthenticatedPrincipal() : const AnonymousPrincipal(),
      redirects: AccessRedirects(
          unauthenticated: (ResolvedNavIntent a) => _home.go(),
          forbidden: (ResolvedNavIntent a) => _home.go()),
      resolveDeepLink: (Uri uri) => switch (uri.pathSegments) {
        <String>['fb', 'detail', final String id] => _detail.go(int.parse(id)),
        _ => _home.go(),
      },
      policy: RouteAccessPolicy(<NavRoute<Object?>, RouteAccessRequirement>{}),
    );

final List<ConformanceCase<FlutterBindingHarness>> flutterBindingConformance =
    <ConformanceCase<FlutterBindingHarness>>[
  // ------------------------------------------------------------ G3
  (
    name: 'G3 BusProvider.of is the bus of the nearest enclosing provider; maybeOf is null and of throws FlutterError where there is none',
    body: (FlutterBindingHarness h) async {
      final Bus outer = h.bus(_quiet);
      final Bus inner = h.bus(_quiet);
      late BuildContext above, middle, below;
      await h.pumpWidget(Column(textDirection: TextDirection.ltr, children: <Widget>[
        _Context((BuildContext c) => above = c),
        BusProvider.value(
          bus: outer,
          child: Column(textDirection: TextDirection.ltr, children: <Widget>[
            _Context((BuildContext c) => middle = c),
            BusProvider.value(bus: inner, child: _Context((BuildContext c) => below = c)),
          ]),
        ),
      ]));
      expect(BusProvider.of(middle), same(outer));
      expect(BusProvider.of(below), same(inner));
      expect(BusProvider.maybeOf(below), same(inner));
      expect(BusProvider.maybeOf(above), isNull);
      expect(() => BusProvider.of(above), throwsA(isA<FlutterError>()));
    },
  ),
  (
    name: 'G3 a widget that read the bus rebuilds when its provider provides another bus, and only then',
    body: (FlutterBindingHarness h) async {
      final Bus a = h.bus(_quiet);
      final Bus b = h.bus(_quiet);
      final List<Bus> read = <Bus>[];
      final Widget reader = _Context((BuildContext c) => read.add(BusProvider.of(c)));
      await h.pumpWidget(BusProvider.value(bus: a, child: reader));
      await h.pumpWidget(BusProvider.value(bus: a, child: reader));
      expect(read, <Bus>[a]);
      await h.pumpWidget(BusProvider.value(bus: b, child: reader));
      expect(read, <Bus>[a, b]);
    },
  ),
  // ------------------------------------------------------------ G4
  (
    name: 'G4 an owning provider shuts its bus down when it is disposed, after its descendants are disposed',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      BusLifecycle? atChildDispose;
      final BusProvider provider =
          BusProvider(bus: bus, child: _DisposeProbe(() => atChildDispose = bus.lifecycle));
      expect(provider.ownsBus, isTrue);
      await h.pumpWidget(provider);
      await h.pumpWidget(const SizedBox());
      expect(atChildDispose, BusLifecycle.bootstrapping);
      expect(bus.lifecycle, BusLifecycle.shutDown);
    },
  ),
  (
    name: 'G4 a provider made with value never shuts its bus down',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final BusProvider provider = BusProvider.value(bus: bus, child: const SizedBox());
      expect(provider.ownsBus, isFalse);
      await h.pumpWidget(provider);
      await h.pumpWidget(const SizedBox());
      expect(bus.lifecycle, BusLifecycle.bootstrapping);
    },
  ),
  (
    name: 'G4 an owning provider rebuilt with another bus shuts the previous bus down and provides the new one',
    body: (FlutterBindingHarness h) async {
      final Bus a = h.bus(_quiet);
      final Bus b = h.bus(_quiet);
      final List<Bus> read = <Bus>[];
      final Widget reader = _Context((BuildContext c) => read.add(BusProvider.of(c)));
      await h.pumpWidget(BusProvider(bus: a, child: reader));
      await h.pumpWidget(BusProvider(bus: b, child: reader));
      expect(a.lifecycle, BusLifecycle.shutDown);
      expect(b.lifecycle, BusLifecycle.bootstrapping);
      expect(read, <Bus>[a, b]);
    },
  ),
  // ------------------------------------------------------------ G5
  (
    name: 'G5 the first frame renders getCurrentValue, and the subscription\'s first value causes no rebuild',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final StateWriter<int> count =
          bus.publisher(_owner, writes: <StateTopic<Object?>>{_count}).writer(_count);
      bus.start();
      count.publish(5);
      final List<int> built = <int>[];
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: StateTopicBuilder<int>(
            topic: _count,
            builder: (BuildContext _, int v) {
              built.add(v);
              return _text('$v');
            }),
      ));
      expect(built, <int>[5]);
      await h.pump();
      await h.pumpAndSettle();
      expect(built, <int>[5]);
    },
  ),
  (
    name: 'G5 each later delivery marks the builder for rebuild, and the next frame renders the current value once',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final StateWriter<int> count =
          bus.publisher(_owner, writes: <StateTopic<Object?>>{_count}).writer(_count);
      bus.start();
      final List<int> built = <int>[];
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: StateTopicBuilder<int>(
            topic: _count,
            builder: (BuildContext _, int v) {
              built.add(v);
              return _text('$v');
            }),
      ));
      await h.pump();
      count.publish(6);
      expect(built, <int>[0]);
      await h.pump();
      expect(built, <int>[0, 6]);
      count.publish(7);
      count.publish(8);
      await h.pump();
      expect(built, <int>[0, 6, 8]);
      count.publish(8);
      await h.pump();
      expect(built, <int>[0, 6, 8]);
    },
  ),
  (
    name: 'G5 a builder mounted before start() renders the initial value, then what start() delivers',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final StateWriter<int> count =
          bus.publisher(_owner, writes: <StateTopic<Object?>>{_count}).writer(_count);
      final List<int> built = <int>[];
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: StateTopicBuilder<int>(
            topic: _count,
            builder: (BuildContext _, int v) {
              built.add(v);
              return _text('$v');
            }),
      ));
      count.publish(3);
      await h.pump();
      expect(built, <int>[0]);
      bus.start();
      await h.pump();
      expect(built, <int>[0, 3]);
    },
  ),
  (
    name: 'G5 a builder mounted before start() renders, after start(), the value a topology\'s connection settles with no publish after it',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.activate(_derivedTopology());
      final List<int> built = <int>[];
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: StateTopicBuilder<int>(
            topic: _derived,
            builder: (BuildContext _, int v) {
              built.add(v);
              return _text('$v');
            }),
      ));
      await h.pump();
      expect(built, <int>[-1]);
      bus.start();
      expect(bus.getCurrentValue(_derived), 1);
      await h.pump();
      expect(built, <int>[-1, 1]);
      await h.pumpAndSettle();
      expect(built, <int>[-1, 1]);
    },
  ),
  (
    name: 'G5 a change of topic resubscribes: the new topic renders, its first value causes no rebuild, and the old topic no longer rebuilds',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final Publisher owner =
          bus.publisher(_owner, writes: <StateTopic<Object?>>{_count, _other});
      bus.start();
      final List<int> built = <int>[];
      Widget builder(StateTopic<int> topic) => BusProvider.value(
            bus: bus,
            child: StateTopicBuilder<int>(
                topic: topic,
                builder: (BuildContext _, int v) {
                  built.add(v);
                  return _text('$v');
                }),
          );
      await h.pumpWidget(builder(_count));
      await h.pumpWidget(builder(_other));
      await h.pump();
      expect(built, <int>[0, 100]);
      owner.writer(_count).publish(1);
      await h.pump();
      expect(built, <int>[0, 100]);
      owner.writer(_other).publish(101);
      await h.pump();
      expect(built, <int>[0, 100, 101]);
    },
  ),
  (
    name: 'G5 a change of the provided bus resubscribes to the new bus',
    body: (FlutterBindingHarness h) async {
      final Bus a = h.bus(_quiet);
      final Bus b = h.bus(_quiet);
      final StateWriter<int> onA =
          a.publisher(_owner, writes: <StateTopic<Object?>>{_count}).writer(_count);
      final StateWriter<int> onB =
          b.publisher(_owner, writes: <StateTopic<Object?>>{_count}).writer(_count);
      a.start();
      b.start();
      onB.publish(20);
      final List<int> built = <int>[];
      final Widget child = StateTopicBuilder<int>(
          topic: _count,
          builder: (BuildContext _, int v) {
            built.add(v);
            return _text('$v');
          });
      await h.pumpWidget(BusProvider.value(bus: a, child: child));
      await h.pumpWidget(BusProvider.value(bus: b, child: child));
      await h.pump();
      expect(built, <int>[0, 20]);
      onA.publish(1);
      await h.pump();
      expect(built, <int>[0, 20]);
      onB.publish(21);
      await h.pump();
      expect(built, <int>[0, 20, 21]);
    },
  ),
  (
    name: 'G5 unmounting cancels the subscription, and a forced removal ends rebuilds without an error',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final StateWriter<int> count =
          bus.publisher(_owner, writes: <StateTopic<Object?>>{_count}).writer(_count);
      bus.start();
      final List<int> built = <int>[];
      final Widget tree = BusProvider.value(
        bus: bus,
        child: StateTopicBuilder<int>(
            topic: _count,
            builder: (BuildContext _, int v) {
              built.add(v);
              return _text('$v');
            }),
      );
      await h.pumpWidget(tree);
      await h.pump();
      expect(bus.removeTopic(_count), isFalse);
      expect(bus.removeTopic(_count, force: true), isTrue);
      await h.pump();
      expect(h.takeException(), isNull);
      count.publish(4);
      await h.pump();
      expect(built, <int>[0]);
      await h.pumpWidget(const SizedBox());
      await h.pumpWidget(tree);
      await h.pump();
      await h.pumpWidget(const SizedBox());
      expect(bus.removeTopic(_count), isTrue);
    },
  ),
  (
    name: 'G5 a value of another type, put in through a widened reference, fails the build with TypeError and reaches no zone handler, and the next value of the topic\'s type renders',
    body: (FlutterBindingHarness h) async {
      final (Bus bus, List<Object> zoneErrors) = _guardedBus();
      try {
        final StateTopic<Object?> wide = _count;
        final Publisher owner = bus.publisher(_owner, writes: <StateTopic<Object?>>{_count});
        bus.start();
        owner.writer<Object?>(wide).publish('x');
        final List<int> built = <int>[];
        await h.pumpWidget(BusProvider.value(
          bus: bus,
          child: StateTopicBuilder<int>(
              topic: _count,
              builder: (BuildContext _, int v) {
                built.add(v);
                return _text('$v');
              }),
        ));
        expect(h.takeException(), isA<TypeError>());
        await h.pump();
        owner.writer(_count).publish(5);
        await h.pump();
        expect(h.takeException(), isNull);
        owner.writer<Object?>(wide).publish('y');
        await h.pump();
        expect(h.takeException(), isA<TypeError>());
        owner.writer(_count).publish(6);
        await h.pump();
        expect(h.takeException(), isNull);
        expect(built, <int>[5, 6]);
        expect(zoneErrors, isEmpty);
      } finally {
        bus.shutdown();
      }
    },
  ),
  // ------------------------------------------------------------ G6
  (
    name: 'G6 the first frame renders getBufferedValues, and the replay of the buffer causes no rebuild',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final Publisher pub = bus.publisher(_owner);
      bus.start();
      pub.publish(_log, 'a');
      pub.publish(_log, 'b');
      final List<List<String>> built = <List<String>>[];
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: ReplayTopicBuilder<String>(
            topic: _log,
            builder: (BuildContext _, List<String> v) {
              built.add(v);
              return _text(v.join());
            }),
      ));
      await h.pump();
      await h.pumpAndSettle();
      expect(built, <List<String>>[
        <String>['a', 'b'],
      ]);
    },
  ),
  (
    name: 'G6 each later delivery is rendered in the next frame from getBufferedValues',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final Publisher pub = bus.publisher(_owner);
      bus.start();
      pub.publish(_log, 'a');
      final List<List<String>> built = <List<String>>[];
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: ReplayTopicBuilder<String>(
            topic: _log,
            builder: (BuildContext _, List<String> v) {
              built.add(v);
              return _text(v.join());
            }),
      ));
      await h.pump();
      pub.publish(_log, 'b');
      await h.pump();
      pub.publish(_log, 'c');
      pub.publish(_log, 'd');
      await h.pump();
      expect(built, <List<String>>[
        <String>['a'],
        <String>['a', 'b'],
        <String>['b', 'c', 'd'],
      ]);
    },
  ),
  (
    name: 'G6 a builder mounted before start() renders, after start(), the buffer a topology\'s connection fills with no publish after it',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.activate(_labelTopology());
      final List<List<String>> built = <List<String>>[];
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: ReplayTopicBuilder<String>(
            topic: _log,
            builder: (BuildContext _, List<String> v) {
              built.add(v);
              return _text(v.join());
            }),
      ));
      await h.pump();
      bus.start();
      await h.pump();
      await h.pumpAndSettle();
      expect(built, <List<String>>[
        <String>[],
        <String>['n0'],
      ]);
    },
  ),
  (
    name: 'G6 while the buffer holds a value of another type every build fails with TypeError and no zone handler is reached, and the delivery that pushes it out renders',
    body: (FlutterBindingHarness h) async {
      final (Bus bus, List<Object> zoneErrors) = _guardedBus();
      try {
        final ReplayTopic<Object?> wide = _log;
        final Publisher pub = bus.publisher(_owner);
        bus.start();
        pub.publish(_log, 'a');
        pub.publish(wide, 1);
        final List<List<String>> built = <List<String>>[];
        await h.pumpWidget(BusProvider.value(
          bus: bus,
          child: ReplayTopicBuilder<String>(
              topic: _log,
              builder: (BuildContext _, List<String> v) {
                built.add(v);
                return _text(v.join());
              }),
        ));
        expect(h.takeException(), isA<TypeError>());
        await h.pump();
        for (final String v in <String>['b', 'c']) {
          pub.publish(_log, v);
          await h.pump();
          expect(h.takeException(), isA<TypeError>());
        }
        pub.publish(_log, 'd');
        await h.pump();
        expect(h.takeException(), isNull);
        expect(built, <List<String>>[
          <String>['b', 'c', 'd'],
        ]);
        expect(zoneErrors, isEmpty);
      } finally {
        bus.shutdown();
      }
    },
  ),
  // ------------------------------------------------------------ G7
  (
    name: 'G7 a PageScope under a router route publishes with PageSource of its entry\'s route path, at page scope',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      late BuildContext page;
      final FlutterNavigationRouter router = FlutterNavigationRouter(RouteState(route: _orders),
          routeBuilder: _pages((NavigationEntry e) =>
              PageScope(child: _Context((BuildContext c) => page = c))));
      await h.pumpWidget(BusProvider.value(bus: bus, child: _host(router)));
      final Publisher publisher = PageScope.publisherOf(page);
      expect(publisher.source, const PageSource('fb/orders'));
      expect(publisher.scope, Scope.page);
      expect(publisher.writes, isEmpty);
    },
  ),
  (
    name: 'G7 an explicit route wins, and a named route gives its name without the leading slash',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      late BuildContext derived, explicit;
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: WidgetsApp(
          navigatorKey: key,
          color: const Color(0xFF000000),
          onGenerateInitialRoutes: (String _) => <Route<dynamic>>[
            _named(
                '/settings/profile',
                Column(textDirection: TextDirection.ltr, children: <Widget>[
                  PageScope(child: _Context((BuildContext c) => derived = c)),
                  PageScope(route: 'custom', child: _Context((BuildContext c) => explicit = c)),
                ])),
          ],
          onGenerateRoute: (RouteSettings s) => null,
        ),
      ));
      expect(PageScope.publisherOf(derived).source, const PageSource('settings/profile'));
      expect(PageScope.publisherOf(explicit).source, const PageSource('custom'));
    },
  ),
  (
    name: 'G7 a PageScope with no route to derive its source from fails to mount with StateError, and publisherOf with no PageScope throws StateError',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      late BuildContext outside;
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: Column(textDirection: TextDirection.ltr, children: <Widget>[
          _Context((BuildContext c) => outside = c),
          PageScope(child: const SizedBox()),
        ]),
      ));
      expect(h.takeException(), isA<StateError>());
      expect(() => PageScope.publisherOf(outside), throwsStateError);
    },
  ),
  (
    name: 'G7 the page publisher claims its writes at page scope and is disposed at unmount, releasing them',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      late BuildContext page;
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: PageScope(
            route: 'fb/form',
            writes: <StateTopic<Object?>>{_pageState},
            child: _Context((BuildContext c) => page = c)),
      ));
      final Publisher publisher = PageScope.publisherOf(page);
      expect(bus.toGraph().claims, <ShellClaim>[
        ShellClaim(
            source: const PageSource('fb/form'),
            scope: Scope.page,
            writes: <TopicRef>{_pageState.ref}),
      ]);
      publisher.writer(_pageState).publish(3);
      await h.pumpWidget(BusProvider.value(bus: bus, child: const SizedBox()));
      expect(publisher.isDisposed, isTrue);
      expect(bus.toGraph().claims, isEmpty);
    },
  ),
  (
    name: 'G7 a route named / alone gives the page route /, and an empty route name gives none',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      Widget app(String name, Widget page) => BusProvider.value(
            bus: bus,
            child: WidgetsApp(
              color: const Color(0xFF000000),
              onGenerateInitialRoutes: (String _) => <Route<dynamic>>[_named(name, page)],
              onGenerateRoute: (RouteSettings s) => null,
            ),
          );
      BuildContext? home;
      await h.pumpWidget(app('/', PageScope(child: _Context((BuildContext c) => home = c))));
      expect(h.takeException(), isNull);
      expect(PageScope.publisherOf(home!).source, const PageSource('/'));
      await h.pumpWidget(const SizedBox());
      await h.pumpWidget(app('', PageScope(child: const SizedBox())));
      expect(h.takeException(), isA<StateError>());
    },
  ),
  // ------------------------------------------------------------ G8
  (
    name: 'G8 PageScope rejects a topology that is not PAGE-scoped, and keeps an unmodifiable copy of its arguments',
    body: (FlutterBindingHarness h) async {
      expect(() => PageScope(route: 'p', topologies: <Topology>[_moduleTopology()], child: const SizedBox()),
          throwsArgumentError);
      final List<Topology> given = <Topology>[_pageTopology()];
      final PageScope scope = PageScope(route: 'p', topologies: given, child: const SizedBox());
      given.clear();
      expect(scope.topologies, hasLength(1));
      expect(() => scope.topologies.add(_pageTopology()), throwsUnsupportedError);
      expect(() => scope.writes.add(_count), throwsUnsupportedError);
    },
  ),
  (
    name: 'G8 mounting activates the page topologies, and unmounting deactivates them',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final _Activations activations = _Activations();
      bus.addObserver(activations);
      bus.start();
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: PageScope(route: 'fb/page', topologies: <Topology>[_pageTopology()], child: const SizedBox()),
      ));
      expect(_active(bus), <String>['fb-page']);
      expect(activations.ids, <String>['fb-page']);
      bus.publisher(_owner).publish(_taps, 7);
      await h.pump();
      expect(bus.getCurrentValue(_pageState), 7);
      await h.pumpWidget(BusProvider.value(bus: bus, child: const SizedBox()));
      expect(_active(bus), isEmpty);
    },
  ),
  (
    name: 'G8 a topology two mounted PageScopes name stays active until the last of them unmounts',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.start();
      Widget pages(int n) => BusProvider.value(
            bus: bus,
            child: Column(textDirection: TextDirection.ltr, children: <Widget>[
              for (var i = 0; i < n; i++)
                PageScope(
                    key: ValueKey<int>(i),
                    route: 'fb/page/$i',
                    topologies: <Topology>[_pageTopology()],
                    child: const SizedBox()),
            ]),
          );
      await h.pumpWidget(pages(2));
      expect(_active(bus), <String>['fb-page']);
      await h.pumpWidget(pages(1));
      expect(_active(bus), <String>['fb-page']);
      await h.pumpWidget(pages(0));
      expect(_active(bus), isEmpty);
    },
  ),
  (
    name: 'G8 a claim rejected at mount releases the topologies the mount activated and is rethrown',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.publisher(_owner, writes: <StateTopic<Object?>>{_claimed});
      bus.start();
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: PageScope(
            route: 'fb/page',
            topologies: <Topology>[_pageTopology()],
            writes: <StateTopic<Object?>>{_claimed},
            child: const SizedBox()),
      ));
      expect(h.takeException(), isA<ClaimRejected>());
      expect(_active(bus), isEmpty);
      expect(bus.toGraph().claims, hasLength(1));
    },
  ),
  (
    name: 'G8 a PageScope binds once, at mount: a rebuild with other arguments keeps that binding',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.start();
      late BuildContext page;
      Widget scope(String route, List<Topology> topologies) => BusProvider.value(
            bus: bus,
            child: PageScope(route: route, topologies: topologies, child: _Context((BuildContext c) => page = c)),
          );
      await h.pumpWidget(scope('fb/first', <Topology>[_pageTopology()]));
      final Publisher first = PageScope.publisherOf(page);
      await h.pumpWidget(scope('fb/second', <Topology>[]));
      expect(PageScope.publisherOf(page), same(first));
      expect(first.source, const PageSource('fb/first'));
      expect(_active(bus), <String>['fb-page']);
    },
  ),
  (
    name: 'G8 a PageScope stays bound to the bus it mounted under when its provider provides another bus, until it unmounts',
    body: (FlutterBindingHarness h) async {
      final Bus a = h.bus(_quiet);
      final Bus b = h.bus(_quiet);
      a.start();
      b.start();
      late BuildContext page;
      final Widget scope = PageScope(
          route: 'fb/page',
          topologies: <Topology>[_pageTopology()],
          writes: <StateTopic<Object?>>{_claimed},
          child: _Context((BuildContext c) => page = c));
      await h.pumpWidget(BusProvider.value(bus: a, child: scope));
      final Publisher first = PageScope.publisherOf(page);
      await h.pumpWidget(BusProvider.value(bus: b, child: scope));
      expect(PageScope.publisherOf(page), same(first));
      expect(_active(a), <String>['fb-page']);
      expect(a.toGraph().claims, hasLength(1));
      expect(_active(b), isEmpty);
      expect(b.toGraph().claims, isEmpty);
      await h.pumpWidget(BusProvider.value(bus: b, child: const SizedBox()));
      expect(first.isDisposed, isTrue);
      expect(_active(a), isEmpty);
      expect(a.toGraph().claims, isEmpty);
    },
  ),
  (
    name: 'G8 before start() a PageScope with a topology fails to mount with the StateError of scope timing and activates nothing, while one that only claims mounts',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final _Activations activations = _Activations();
      bus.addObserver(activations);
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: PageScope(route: 'fb/page', topologies: <Topology>[_pageTopology()], child: const SizedBox()),
      ));
      final Object? error = h.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('fb-page'));
      expect(_active(bus), isEmpty);
      expect(activations.ids, isEmpty);
      late BuildContext page;
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: PageScope(
            route: 'fb/form',
            writes: <StateTopic<Object?>>{_claimed},
            child: _Context((BuildContext c) => page = c)),
      ));
      expect(h.takeException(), isNull);
      expect(PageScope.publisherOf(page).writes, <StateTopic<Object?>>{_claimed});
      bus.start();
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: PageScope(
            key: const ValueKey<String>('after start'),
            route: 'fb/page',
            topologies: <Topology>[_pageTopology()],
            child: const SizedBox()),
      ));
      expect(h.takeException(), isNull);
      expect(_active(bus), <String>['fb-page']);
    },
  ),
  (
    name: 'G8 one route pushed twice holds one activation of a page topology equal to its next evaluation, and a page topology that passes a closure fails the second mount with TopologyConflict',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final _Activations activations = _Activations();
      bus.addObserver(activations);
      bus.start();
      Route<dynamic> pageOf(String name, Topology Function() topologyOf) => PageRouteBuilder<void>(
            settings: RouteSettings(name: name),
            pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
                PageScope(topologies: <Topology>[topologyOf()], child: _text(name)),
          );
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(BusProvider.value(bus: bus, child: _namedApp(key, <String>['/home'], <NavigatorObserver>[])));
      final NavigatorState nav = key.currentState!;
      for (var i = 0; i < 2; i++) {
        unawaited(nav.push(pageOf('/fb/named', _namedPageTopology)));
        await h.pumpAndSettle();
      }
      expect(h.takeException(), isNull);
      expect(_active(bus), <String>['fb-named-page']);
      expect(activations.ids, <String>['fb-named-page']);
      nav.pop();
      await h.pumpAndSettle();
      expect(_active(bus), <String>['fb-named-page']);
      nav.pop();
      await h.pumpAndSettle();
      expect(_active(bus), isEmpty);
      unawaited(nav.push(pageOf('/fb/closure', _closurePageTopology)));
      await h.pumpAndSettle();
      expect(h.takeException(), isNull);
      unawaited(nav.push(pageOf('/fb/closure', _closurePageTopology)));
      await h.pumpAndSettle();
      expect(h.takeException(), isA<TopologyConflict>());
      expect(_active(bus), <String>['fb-closure-page']);
      nav.pop();
      await h.pumpAndSettle();
      expect(_active(bus), <String>['fb-closure-page']);
      nav.pop();
      await h.pumpAndSettle();
      expect(_active(bus), isEmpty);
    },
  ),
  // ------------------------------------------------------------ G9
  (
    name: 'G9 a module prefix matches the paths whose segments begin with its segments, whatever the leading slash',
    body: (FlutterBindingHarness h) async {
      final ModuleRoutes m = ModuleRoutes(
          moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]);
      final ModuleRoutes nested = ModuleRoutes(
          moduleId: 'payment', prefix: '/checkout/payment/', topologies: <Topology>[_moduleTopology('fb-payment')]);
      expect(<bool>[
        for (final String p in <String>['checkout', '/checkout', 'checkout/cart', '/checkout//cart', 'checkouts', 'shop/checkout', '', '/'])
          m.matches(p),
      ], <bool>[true, true, true, true, false, false, false, false]);
      expect(<bool>[
        for (final String p in <String>['checkout/payment', '/checkout/payment/card', 'checkout', 'checkout/paymentx'])
          nested.matches(p),
      ], <bool>[true, true, false, false]);
      expect(m.moduleId, 'checkout');
      expect(m.prefix, 'checkout');
      expect(m.gracePeriod, isNull);
    },
  ),
  (
    name: 'G9 a prefix with no segment is rejected, and the topologies are an unmodifiable copy',
    body: (FlutterBindingHarness h) async {
      for (final String p in <String>['', '/', '//']) {
        expect(() => ModuleRoutes(moduleId: 'm', prefix: p, topologies: <Topology>[_moduleTopology()]),
            throwsArgumentError);
      }
      final List<Topology> given = <Topology>[_moduleTopology()];
      final ModuleRoutes m = ModuleRoutes(
          moduleId: 'm', prefix: 'm', topologies: given, gracePeriod: const Duration(milliseconds: 300));
      given.clear();
      expect(m.topologies, hasLength(1));
      expect(() => m.topologies.add(_moduleTopology()), throwsUnsupportedError);
      expect(m.gracePeriod, const Duration(milliseconds: 300));
    },
  ),
  // ------------------------------------------------------------ G10
  (
    name: 'G10 constructing the observer declares each module on the bus, and a declaration the bus rejects throws ArgumentError',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
        ModuleRoutes(
            moduleId: 'payment',
            prefix: 'pay',
            topologies: <Topology>[_moduleTopology('fb-payment')],
            gracePeriod: Duration.zero),
      ]);
      expect(o.bus, same(bus));
      expect(<String>[for (final ModuleScope s in o.scopes) s.moduleId], <String>['checkout', 'payment']);
      expect(o.scopes[0].gracePeriod, const Duration(milliseconds: 100));
      expect(o.scopes[1].gracePeriod, Duration.zero);
      expect(o.scopes.every((ModuleScope s) => s.references == 0 && !s.isActive), isTrue);
      expect(bus.module('checkout', <Topology>[_moduleTopology()]), same(o.scopes[0]));
      expect(
          () => ModuleScopeObserver(bus, <ModuleRoutes>[
                ModuleRoutes(moduleId: 'bad', prefix: 'bad', topologies: <Topology>[_pageTopology()]),
              ]),
          throwsArgumentError);
    },
  ),
  (
    name: 'G10 each route whose path matches a module holds one reference from its push to its pop, the initial routes included',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.start();
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
      ]);
      final ModuleScope scope = o.scopes.single;
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(_namedApp(key, <String>['/home', '/checkout/cart'], <NavigatorObserver>[o]));
      expect(scope.references, 1);
      expect(scope.isActive, isTrue);
      final NavigatorState nav = key.currentState!;
      unawaited(nav.push(_named('/checkout/pay')));
      expect(scope.references, 2);
      unawaited(nav.push(_named('/profile')));
      expect(scope.references, 2);
      await h.pumpAndSettle();
      nav.pop();
      expect(scope.references, 2);
      nav.pop();
      expect(scope.references, 1);
      nav.pop();
      expect(scope.references, 0);
      expect(scope.isActive, isTrue);
      await h.pump(const Duration(milliseconds: 100));
      expect(scope.isActive, isFalse);
      await h.pumpAndSettle();
    },
  ),
  (
    name: 'G10 leaving the subtree and returning within the grace period keeps the topologies; leaving for longer deactivates them',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final _Activations activations = _Activations();
      bus.addObserver(activations);
      bus.start();
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
      ]);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(_namedApp(key, <String>['/home'], <NavigatorObserver>[o]));
      final NavigatorState nav = key.currentState!;
      unawaited(nav.push(_named('/checkout/cart')));
      await h.pumpAndSettle();
      nav.pop();
      await h.pump(const Duration(milliseconds: 50));
      unawaited(nav.push(_named('/checkout/cart')));
      await h.pump(const Duration(milliseconds: 100));
      expect(o.scopes.single.isActive, isTrue);
      expect(activations.ids, <String>['fb-checkout']);
      await h.pumpAndSettle();
      nav.pop();
      await h.pump(const Duration(milliseconds: 100));
      expect(o.scopes.single.isActive, isFalse);
    },
  ),
  (
    name: 'G10 a replace within the subtree acquires the new route before releasing the old, so even a zero grace period keeps the topologies',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final _Activations activations = _Activations();
      bus.addObserver(activations);
      bus.start();
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(
            moduleId: 'checkout',
            prefix: 'checkout',
            topologies: <Topology>[_moduleTopology()],
            gracePeriod: Duration.zero),
      ]);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(_namedApp(key, <String>['/home', '/checkout/cart'], <NavigatorObserver>[o]));
      unawaited(key.currentState!.pushReplacement<void, void>(_named('/checkout/pay')));
      await h.pumpAndSettle();
      expect(o.scopes.single.references, 1);
      expect(o.scopes.single.isActive, isTrue);
      expect(activations.ids, <String>['fb-checkout']);
      unawaited(key.currentState!.pushReplacement<void, void>(_named('/profile')));
      expect(o.scopes.single.isActive, isFalse);
      await h.pumpAndSettle();
    },
  ),
  (
    name: 'G10 a route matching two modules holds a reference of each, and a route matching none or without a name holds none',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.start();
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
        ModuleRoutes(
            moduleId: 'payment', prefix: 'checkout/payment', topologies: <Topology>[_moduleTopology('fb-payment')]),
      ]);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(_namedApp(key, <String>['/home'], <NavigatorObserver>[o]));
      unawaited(key.currentState!.push(_named('/checkout/payment/card')));
      await h.pumpAndSettle();
      expect(<int>[for (final ModuleScope s in o.scopes) s.references], <int>[1, 1]);
      unawaited(showGeneralDialog<void>(
          context: key.currentContext!,
          pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) => _text('dialog')));
      unawaited(key.currentState!.push(_named('/profile')));
      await h.pumpAndSettle();
      expect(<int>[for (final ModuleScope s in o.scopes) s.references], <int>[1, 1]);
    },
  ),
  (
    name: 'G10 an acquire the bus rejects is reported through FlutterError.reportError, holds no reference, and leaves the Navigator working',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.publisher(_owner, writes: <StateTopic<Object?>>{const StateTopic<int>(name: 'fb.fb-checkout', initial: 0)});
      bus.start();
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
      ]);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(_namedApp(key, <String>['/home'], <NavigatorObserver>[mirror, o]));
      unawaited(key.currentState!.push(_named('/checkout/cart')));
      await h.pumpAndSettle();
      expect(h.takeException(), isA<ActivationRejected>());
      expect(o.scopes.single.references, 0);
      unawaited(key.currentState!.push(_named('/profile')));
      key.currentState!.pop();
      await h.pumpAndSettle();
      expect(mirror.paths, <String?>['/home', '/checkout/cart']);
      expect(h.takeException(), isNull);
    },
  ),
  (
    name: 'G10 a route pushed before start() holds no reference: the acquire\'s StateError is reported, and only a route pushed after start() acquires',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
      ]);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(_namedApp(key, <String>['/home', '/checkout/cart'], <NavigatorObserver>[mirror, o]));
      final Object? error = h.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('checkout'));
      expect(mirror.paths, <String?>['/home', '/checkout/cart']);
      bus.start();
      expect(o.scopes.single.references, 0);
      expect(o.scopes.single.isActive, isFalse);
      unawaited(key.currentState!.push(_named('/checkout/pay')));
      await h.pumpAndSettle();
      expect(h.takeException(), isNull);
      expect(o.scopes.single.references, 1);
      expect(o.scopes.single.isActive, isTrue);
    },
  ),
  (
    name: 'G10 dispose releases every reference and is idempotent; after it, or after shutdown, the observer acquires nothing',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.start();
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(
            moduleId: 'checkout',
            prefix: 'checkout',
            topologies: <Topology>[_moduleTopology()],
            gracePeriod: Duration.zero),
      ]);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(_namedApp(key, <String>['/home', '/checkout/cart'], <NavigatorObserver>[o]));
      expect(o.scopes.single.references, 1);
      o.dispose();
      o.dispose();
      expect(o.isDisposed, isTrue);
      expect(o.scopes.single.references, 0);
      expect(o.scopes.single.isActive, isFalse);
      unawaited(key.currentState!.push(_named('/checkout/pay')));
      await h.pumpAndSettle();
      expect(o.scopes.single.references, 0);
      final Bus second = h.bus(_quiet);
      second.start();
      final ModuleScopeObserver afterShutdown = ModuleScopeObserver(second, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
      ]);
      final GlobalKey<NavigatorState> key2 = GlobalKey<NavigatorState>();
      await h.pumpWidget(_namedApp(key2, <String>['/home'], <NavigatorObserver>[afterShutdown]));
      second.shutdown();
      unawaited(key2.currentState!.push(_named('/checkout/cart')));
      await h.pumpAndSettle();
      expect(h.takeException(), isNull);
      expect(afterShutdown.scopes.single.references, 0);
    },
  ),
  (
    name: 'G10 pathOf is the entry\'s route path for a route a FlutterNavigationRouter built, else the route\'s name, else null',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final FlutterNavigationRouter router =
          FlutterNavigationRouter(_homeState, routeBuilder: _pages());
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(BusProvider.value(bus: bus, child: _host(router, observers: <NavigatorObserver>[mirror])));
      expect(ModuleScopeObserver.pathOf(mirror.routes.single), 'fb/home');
      expect(ModuleScopeObserver.pathOf(_named('/plain/name')), '/plain/name');
      expect(
          ModuleScopeObserver.pathOf(PageRouteBuilder<void>(
              pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) => const SizedBox())),
          isNull);
    },
  ),
  // ------------------------------------------------------------ G11
  (
    name: 'G11 after each perform the Navigator holds the routes of the stack\'s entries in order, and the confirmation comes before perform returns',
    body: (FlutterBindingHarness h) async {
      final FlutterNavigationRouter router =
          FlutterNavigationRouter(_homeState, routeBuilder: _pages());
      expect(router.supportsPopUntil, isTrue);
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(_host(router, observers: <NavigatorObserver>[mirror]));
      final List<RouteConfirmation> got = <RouteConfirmation>[];
      router.confirmations.listen(got.add);
      List<String?> stackPaths() =>
          <String?>[for (final NavigationEntry e in router.stack) e.state.route.path];
      router.perform(<RouterCall>[PushRoute(_entry(_detail, 1)), PushRoute(_entry(_orders))], _orders.go());
      expect(got, hasLength(1));
      expect(mirror.paths, stackPaths());
      router.perform(<RouterCall>[PushRoute(NavigationEntry(RouteState(route: _sheet, args: 's'), modal: true))],
          _sheet.showModal('s'));
      router.perform(<RouterCall>[ReplaceRoute(_entry(_detail, 2))], _detail.replace(2));
      expect(mirror.paths, <String?>['fb/home', 'fb/detail', 'fb/orders', 'fb/detail']);
      router.perform(<RouterCall>[const PopUntilRoute(_detail)], _detail.backTo());
      expect(mirror.paths, <String?>['fb/home', 'fb/detail', 'fb/orders', 'fb/detail']);
      router.perform(<RouterCall>[const PopUntilRoute(_home)], _home.backTo());
      expect(mirror.paths, <String?>['fb/home']);
      expect(mirror.paths, stackPaths());
      expect(got, hasLength(5));
      await h.pumpAndSettle();
    },
  ),
  (
    name: 'G11 a perform the stack does not admit, or whose route builder breaks the settings rule, throws before the Navigator is touched',
    body: (FlutterBindingHarness h) async {
      final FlutterNavigationRouter router =
          FlutterNavigationRouter(_homeState, routeBuilder: (NavigationEntry e, RouteSettings s) =>
              e.state.route == _orders ? _named('/elsewhere') : _pages()(e, s));
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(_host(router, observers: <NavigatorObserver>[mirror]));
      final List<RouteConfirmation> got = <RouteConfirmation>[];
      router.confirmations.listen(got.add);
      expect(
          () => router.perform(
              <RouterCall>[PushRoute(_entry(_detail, 1)), const PopRoute(), const PopRoute()], const Back()),
          throwsStateError);
      expect(() => router.perform(<RouterCall>[PushRoute(_entry(_detail, 1)), PushRoute(_entry(_orders))], _orders.go()),
          throwsArgumentError);
      await h.pumpAndSettle();
      expect(mirror.paths, <String?>['fb/home']);
      expect(router.stack, <NavigationEntry>[NavigationEntry(_homeState)]);
      expect(got, isEmpty);
    },
  ),
  // ------------------------------------------------------------ G12
  (
    name: 'G12 while no Navigator hosts it, a perform changes the stack alone and confirms at once; the Navigator that then hosts it starts with one route per entry',
    body: (FlutterBindingHarness h) async {
      h.setPlatformInitialRoute('/somewhere/else');
      final FlutterNavigationRouter router =
          FlutterNavigationRouter(_homeState, routeBuilder: _pages());
      final List<RouteConfirmation> got = <RouteConfirmation>[];
      router.confirmations.listen(got.add);
      expect(router.isHosted, isFalse);
      router.perform(<RouterCall>[PushRoute(_entry(_detail, 5))], _detail.go(5));
      expect(got, hasLength(1));
      expect(router.stack, hasLength(2));
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(_host(router, observers: <NavigatorObserver>[mirror]));
      expect(router.isHosted, isTrue);
      expect(mirror.paths, <String?>['fb/home', 'fb/detail']);
      expect((mirror.routes.last.settings.arguments! as NavigationEntry).state.args, 5);
    },
  ),
  (
    name: 'G12 when its Navigator unmounts the router keeps its stack, and the next Navigator starts from that stack with new routes',
    body: (FlutterBindingHarness h) async {
      final FlutterNavigationRouter router =
          FlutterNavigationRouter(_homeState, routeBuilder: _pages());
      final _Mirror first = _Mirror();
      await h.pumpWidget(_host(router, observers: <NavigatorObserver>[first]));
      router.perform(<RouterCall>[PushRoute(_entry(_detail, 1))], _detail.go(1));
      await h.pumpAndSettle();
      final List<Route<dynamic>> before = List<Route<dynamic>>.of(first.routes);
      await h.pumpWidget(const SizedBox());
      expect(router.isHosted, isFalse);
      router.perform(<RouterCall>[PushRoute(_entry(_orders))], _orders.go());
      final _Mirror second = _Mirror();
      await h.pumpWidget(_host(router, observers: <NavigatorObserver>[second]));
      expect(second.paths, <String?>['fb/home', 'fb/detail', 'fb/orders']);
      expect(second.routes.any(before.contains), isFalse);
      expect(router.generateRoute(const RouteSettings(name: '/fb/orders')), isNull);
    },
  ),
  // ------------------------------------------------------------ G13
  (
    name: 'G13 the route of an entry is built with settings named after its path that carry the entry',
    body: (FlutterBindingHarness h) async {
      final List<RouteSettings> given = <RouteSettings>[];
      final FlutterNavigationRouter router = FlutterNavigationRouter(_homeState,
          routeBuilder: (NavigationEntry e, RouteSettings s) {
        given.add(s);
        return _pages()(e, s);
      });
      await h.pumpWidget(_host(router));
      final NavigationEntry detail = _entry(_detail, 3);
      router.perform(<RouterCall>[PushRoute(detail)], _detail.go(3));
      expect(<(String?, Object?)>[for (final RouteSettings s in given) (s.name, s.arguments)],
          <(String?, Object?)>[('/fb/home', NavigationEntry(_homeState)), ('/fb/detail', detail)]);
      await h.pumpAndSettle();
    },
  ),
  (
    name: 'G13 a route the router did not build is not an entry: a dialog changes and confirms nothing, its pop neither, and a perform pops it first',
    body: (FlutterBindingHarness h) async {
      final FlutterNavigationRouter router =
          FlutterNavigationRouter(_homeState, routeBuilder: _pages());
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(_host(router, observers: <NavigatorObserver>[mirror]));
      router.perform(<RouterCall>[PushRoute(_entry(_detail, 1))], _detail.go(1));
      await h.pumpAndSettle();
      final List<RouteConfirmation> got = <RouteConfirmation>[];
      router.confirmations.listen(got.add);
      Future<void> dialog() async {
        unawaited(showGeneralDialog<void>(
            context: router.navigatorKey.currentContext!,
            pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) => _text('dialog')));
        await h.pumpAndSettle();
      }

      await dialog();
      expect(router.stack, hasLength(2));
      await h.platformBack();
      expect(got, isEmpty);
      expect(router.stack, hasLength(2));
      await dialog();
      expect(mirror.paths, <String?>['fb/home', 'fb/detail', null]);
      router.perform(<RouterCall>[PushRoute(_entry(_orders))], _orders.go());
      expect(mirror.paths, <String?>['fb/home', 'fb/detail', 'fb/orders']);
      expect(got, hasLength(1));
      await h.pumpAndSettle();
    },
  ),
  (
    name: 'G13 a pop of the top entry\'s route that no perform made, such as a page\'s own Navigator.maybePop, is confirmed as Back',
    body: (FlutterBindingHarness h) async {
      late BuildContext detailPage;
      final FlutterNavigationRouter router = FlutterNavigationRouter(_homeState,
          routeBuilder: _pages((NavigationEntry e) => e.state.route == _detail
              ? _Context((BuildContext c) => detailPage = c)
              : _text(e.state.route.path)));
      await h.pumpWidget(_host(router));
      router.perform(<RouterCall>[PushRoute(_entry(_detail, 1))], _detail.go(1));
      await h.pumpAndSettle();
      final List<RouteConfirmation> got = <RouteConfirmation>[];
      router.confirmations.listen(got.add);
      expect(await Navigator.maybePop(detailPage), isTrue);
      expect(got, <RouteConfirmation>[
        RouteConfirmation(stack: <NavigationEntry>[NavigationEntry(_homeState)], intent: const Back()),
      ]);
      await h.pumpAndSettle();
    },
  ),
  (
    name: 'G13 a platform back that the top entry\'s page refuses with PopScope is not a pop: nothing changes or is confirmed',
    body: (FlutterBindingHarness h) async {
      final FlutterNavigationRouter router = FlutterNavigationRouter(_homeState,
          routeBuilder: _pages((NavigationEntry e) => e.state.route == _detail
              ? PopScope<Object?>(canPop: false, child: _text('guarded'))
              : _text(e.state.route.path)));
      await h.pumpWidget(_host(router));
      router.perform(<RouterCall>[PushRoute(_entry(_detail, 1))], _detail.go(1));
      await h.pumpAndSettle();
      final List<RouteConfirmation> got = <RouteConfirmation>[];
      router.confirmations.listen(got.add);
      await h.platformBack();
      expect(got, isEmpty);
      expect(router.stack, hasLength(2));
    },
  ),
  // ------------------------------------------------------------ G14
  (
    name: 'G14 the executor is a FlutterNavigationRouter with a NavigationExecutor over it, named flutter-navigation by default',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final FlutterNavigationExecutor n =
          FlutterNavigationExecutor(bus, initial: _homeState, routeBuilder: _pages());
      expect(n.bus, same(bus));
      expect(n.executor.router, same(n.router));
      expect(n.executor.source, const ExecutorSource('flutter-navigation'));
      expect(n.router.stack, <NavigationEntry>[NavigationEntry(_homeState)]);
      expect(bus.toGraph().claims, <ShellClaim>[
        ShellClaim(
            source: const ExecutorSource('flutter-navigation'),
            writes: <TopicRef>{NavigationTopics.currentRoute.ref}),
      ]);
      final FlutterNavigationExecutor named = FlutterNavigationExecutor(h.bus(_quiet),
          initial: _homeState, routeBuilder: _pages(), name: 'shell');
      expect(named.executor.source, const ExecutorSource('shell'));
    },
  ),
  (
    name: 'G14 a construction that throws claims nothing and forwards nothing',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final EnvelopeRecorder recorder = EnvelopeRecorder.attach(bus);
      bus.publisher(_owner, writes: <StateTopic<Object?>>{NavigationTopics.currentRoute});
      bus.start();
      h.setPlatformInitialRoute('/fb/detail/9');
      expect(() => FlutterNavigationExecutor(bus, initial: _homeState, routeBuilder: _pages()),
          throwsA(isA<ClaimRejected>()));
      await h.platformPushRoute('/fb/detail/10');
      expect(recorder.payloadsOf(NavigationTopics.intent), isEmpty);
      expect(bus.toGraph().claims, hasLength(1));
    },
  ),
  (
    name: 'G14 dispose is idempotent, disposes the NavigationExecutor and stops forwarding; shutting the bus down disposes it',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final EnvelopeRecorder recorder = EnvelopeRecorder.attach(bus);
      bus.start();
      final FlutterNavigationExecutor n =
          FlutterNavigationExecutor(bus, initial: _homeState, routeBuilder: _pages());
      n.dispose();
      n.dispose();
      expect(n.isDisposed, isTrue);
      expect(n.executor.isDisposed, isTrue);
      expect(bus.toGraph().claims, isEmpty);
      await h.platformPushRoute('/fb/detail/4');
      expect(recorder.payloadsOf(NavigationTopics.intent), isEmpty);
      final Bus other = h.bus(_quiet);
      final FlutterNavigationExecutor m =
          FlutterNavigationExecutor(other, initial: _homeState, routeBuilder: _pages());
      other.shutdown();
      expect(m.isDisposed, isTrue);
    },
  ),
  // ------------------------------------------------------------ G15
  (
    name: 'G15 the platform\'s initial route is published to nav.intent as a deep link at construction, through a publisher of ExecutorSource(name), queued before start()',
    body: (FlutterBindingHarness h) async {
      h.setPlatformInitialRoute('/fb/detail/5?from=os');
      final Bus bus = h.bus(_quiet);
      final EnvelopeRecorder recorder = EnvelopeRecorder.attach(bus);
      FlutterNavigationExecutor(bus, initial: _homeState, routeBuilder: _pages());
      expect(recorder.envelopes, isEmpty);
      bus.start();
      expect(recorder.payloadsOf(NavigationTopics.intent), <NavIntent>[DeepLink(Uri.parse('/fb/detail/5?from=os'))]);
      expect(recorder.envelopesOf(NavigationTopics.intent).single.source,
          const ExecutorSource('flutter-navigation'));
      final Bus atRoot = h.bus(_quiet);
      h.setPlatformInitialRoute('/');
      final EnvelopeRecorder none = EnvelopeRecorder.attach(atRoot);
      FlutterNavigationExecutor(atRoot, initial: _homeState, routeBuilder: _pages());
      atRoot.start();
      expect(none.payloadsOf(NavigationTopics.intent), isEmpty);
    },
  ),
  (
    name: 'G15 a route the platform pushes is published as a deep link, and nothing is pushed on the Navigator',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final EnvelopeRecorder recorder = EnvelopeRecorder.attach(bus);
      final FlutterNavigationExecutor n =
          FlutterNavigationExecutor(bus, initial: _homeState, routeBuilder: _pages());
      bus.start();
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(_host(n.router, observers: <NavigatorObserver>[mirror]));
      await h.platformPushRoute('/fb/detail/6');
      expect(recorder.payloadsOf(NavigationTopics.intent), <NavIntent>[DeepLink(Uri.parse('/fb/detail/6'))]);
      expect(mirror.paths, <String?>['fb/home']);
      expect(h.takeException(), isNull);
    },
  ),
  (
    name: 'G15 with forwarding off, the platform\'s initial route is not published',
    body: (FlutterBindingHarness h) async {
      h.setPlatformInitialRoute('/fb/detail/5');
      final Bus bus = h.bus(_quiet);
      final EnvelopeRecorder recorder = EnvelopeRecorder.attach(bus);
      final FlutterNavigationExecutor n = FlutterNavigationExecutor(bus,
          initial: _homeState, routeBuilder: _pages(), forwardPlatformRoutes: false);
      bus.start();
      expect(recorder.payloadsOf(NavigationTopics.intent), isEmpty);
      expect(bus.toGraph().claims, hasLength(1));
      n.dispose();
    },
  ),
  // ------------------------------------------------------------ G16
  (
    name: 'G16 with the resolver active and the executor constructed before start(), the platform\'s deep link is performed before any Navigator exists, and the first frame shows it above the initial route',
    body: (FlutterBindingHarness h) async {
      h.setPlatformInitialRoute('/fb/detail/5');
      final Bus bus = h.bus(_quiet);
      bus.activate(_resolver());
      final FlutterNavigationExecutor n =
          FlutterNavigationExecutor(bus, initial: _homeState, routeBuilder: _pages());
      final ModuleScopeObserver modules = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'detail', prefix: 'fb/detail', topologies: <Topology>[_moduleTopology()]),
      ]);
      bus.start();
      await h.pump();
      expect(n.router.isHosted, isFalse);
      expect(n.router.stack, <NavigationEntry>[NavigationEntry(_homeState), _entry(_detail, 5)]);
      expect(bus.getCurrentValue(NavigationTopics.currentRoute), RouteState(route: _detail, args: 5));
      final _Mirror mirror = _Mirror();
      await h.pumpWidget(BusProvider.value(
          bus: bus, child: _host(n.router, observers: <NavigatorObserver>[mirror, modules])));
      expect(mirror.paths, <String?>['fb/home', 'fb/detail']);
      expect(modules.scopes.single.isActive, isTrue);
      expect(bus.getBufferedValues(NavigationTopics.history).single.intent, _detail.go(5));
    },
  ),
  // ------------------------------------------------------------ G17
  (
    name: 'G17 a WidgetTestBus runs a production-provider bus built in the current zone, so pump drives its clock and timers',
    body: (FlutterBindingHarness h) async {
      final WidgetTestBus t = WidgetTestBus(_quiet);
      final DateTime t0 = t.bus.clock.now();
      final ModuleScope scope = t.bus.module('fb', <Topology>[_moduleTopology()]);
      t.bus.start();
      scope.acquire().release();
      expect(scope.isActive, isTrue);
      await h.pumpWidget(t.wrap(const SizedBox()));
      await h.pump(const Duration(seconds: 1));
      expect(t.bus.clock.now().difference(t0), const Duration(seconds: 1));
      expect(scope.isActive, isFalse);
      await h.pumpWidget(const SizedBox());
    },
  ),
  (
    name: 'G17 a WidgetTestBus rejects a virtual provider',
    body: (FlutterBindingHarness h) async {
      expect(() => WidgetTestBus(BusConfig(scheduler: VirtualSchedulerProvider(VirtualScheduler()))),
          throwsArgumentError);
    },
  ),
  (
    name: 'G17 the recorder is attached at construction and records every delivery, start()\'s queue included',
    body: (FlutterBindingHarness h) async {
      final WidgetTestBus t = WidgetTestBus(_quiet);
      t.input.publish(_taps, 1);
      t.stub(_count).publish(2);
      t.bus.start();
      expect(t.recorder.payloadsOf(_taps), <int>[1]);
      expect(t.recorder.payloadsOf(_count), <int>[2]);
      await h.pumpWidget(t.wrap(const SizedBox()));
      await h.pumpWidget(const SizedBox());
    },
  ),
  (
    name: 'G17 input and stub publish as ServiceSource(test), each made once, stub claiming its topic alone at application scope',
    body: (FlutterBindingHarness h) async {
      final WidgetTestBus t = WidgetTestBus(_quiet);
      expect(WidgetTestBus.testSource, const ServiceSource('test'));
      expect(t.input, same(t.input));
      expect(t.input.source, const ServiceSource('test'));
      expect(t.input.writes, isEmpty);
      expect(t.stub(_count), same(t.stub(_count)));
      t.stub(_other);
      expect(_claims(t.bus), <ShellClaim>{
        ShellClaim(source: const ServiceSource('test'), writes: <TopicRef>{_count.ref}),
        ShellClaim(source: const ServiceSource('test'), writes: <TopicRef>{_other.ref}),
      });
      await h.pumpWidget(t.wrap(const SizedBox()));
      await h.pumpWidget(const SizedBox());
    },
  ),
  (
    name: 'G17 stub keeps one publisher per topic and returns its writer per type argument, and a claim the bus rejects throws ClaimRejected and claims nothing',
    body: (FlutterBindingHarness h) async {
      final WidgetTestBus t = WidgetTestBus(_quiet);
      final StateTopic<Object?> wide = _count;
      final StateWriter<Object?> loose = t.stub<Object?>(wide);
      final StateWriter<int> typed = t.stub<int>(_count);
      expect(t.stub<Object?>(wide), same(loose));
      expect(t.stub<int>(_count), same(typed));
      t.bus.publisher(_owner, writes: <StateTopic<Object?>>{_other});
      expect(() => t.stub(_other), throwsA(isA<ClaimRejected>()));
      expect(_claims(t.bus), <ShellClaim>{
        ShellClaim(source: const ServiceSource('test'), writes: <TopicRef>{_count.ref}),
        ShellClaim(source: _owner, writes: <TopicRef>{_other.ref}),
      });
      t.bus.start();
      typed.publish(7);
      expect(t.bus.getCurrentValue(_count), 7);
      await h.pumpWidget(t.wrap(const SizedBox()));
      await h.pumpWidget(const SizedBox());
    },
  ),
  (
    name: 'G17 wrap gives an owning provider: unmounting it shuts the bus down and cancels a pending grace timer',
    body: (FlutterBindingHarness h) async {
      final WidgetTestBus t = WidgetTestBus(_quiet);
      t.bus.start();
      final ModuleScopeObserver o = ModuleScopeObserver(t.bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
      ]);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(t.wrap(_namedApp(key, <String>['/home', '/checkout/cart'], <NavigatorObserver>[o])));
      expect(BusProvider.of(key.currentContext!), same(t.bus));
      key.currentState!.pop();
      await h.pump();
      expect(o.scopes.single.isActive, isTrue);
      await h.pumpWidget(const SizedBox());
      expect(t.bus.lifecycle, BusLifecycle.shutDown);
      expect(o.scopes.single.isActive, isFalse);
    },
  ),
  // ------------------------------------------------------------ G20
  (
    name: 'G20 a NidanaModule declares its module on the provided bus at mount and holds one reference until it unmounts; the topologies outlive it by the grace period',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final _Activations activations = _Activations();
      bus.addObserver(activations);
      bus.start();
      final NidanaModule wrapper = NidanaModule(
          moduleId: 'checkout', topologies: <Topology>[_moduleTopology()], child: _text('checkout'));
      await h.pumpWidget(BusProvider.value(bus: bus, child: wrapper));
      final ModuleScope scope = bus.module('checkout', <Topology>[_moduleTopology()]);
      expect(scope.references, 1);
      expect(scope.isActive, isTrue);
      expect(activations.ids, <String>['fb-checkout']);
      await h.pumpWidget(BusProvider.value(bus: bus, child: const SizedBox()));
      expect(scope.references, 0);
      expect(scope.isActive, isTrue);
      await h.pump(const Duration(milliseconds: 100));
      expect(scope.isActive, isFalse);
      expect(wrapper.moduleId, 'checkout');
      expect(wrapper.gracePeriod, isNull);
    },
  ),
  (
    name: 'G20 constructing a NidanaModule rejects an empty id, no topologies, a topology that is not MODULE-scoped and a negative grace period, and keeps an unmodifiable copy of its topologies',
    body: (FlutterBindingHarness h) async {
      NidanaModule wrapper(String id, List<Topology> topologies, [Duration? grace]) =>
          NidanaModule(moduleId: id, topologies: topologies, gracePeriod: grace, child: const SizedBox());
      expect(() => wrapper('', <Topology>[_moduleTopology()]), throwsArgumentError);
      expect(() => wrapper('m', <Topology>[]), throwsArgumentError);
      expect(() => wrapper('m', <Topology>[_pageTopology()]), throwsArgumentError);
      expect(() => wrapper('m', <Topology>[_moduleTopology()], const Duration(milliseconds: -1)),
          throwsArgumentError);
      final List<Topology> given = <Topology>[_moduleTopology()];
      final NidanaModule m = wrapper('m', given, Duration.zero);
      given.clear();
      expect(m.topologies, hasLength(1));
      expect(() => m.topologies.add(_moduleTopology()), throwsUnsupportedError);
      expect(m.gracePeriod, Duration.zero);
    },
  ),
  (
    name: 'G20 a NidanaModule in each page of the subtree holds the module while any of its pages is mounted: a covered page keeps its reference, a replace mounts the new page before the old unmounts, and a popped page releases when its exit transition ends',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      final _Activations activations = _Activations();
      bus.addObserver(activations);
      bus.start();
      Route<dynamic> page(String name, {bool wrapped = true}) => PageRouteBuilder<void>(
            settings: RouteSettings(name: name),
            pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) => wrapped
                ? NidanaModule(
                    moduleId: 'checkout',
                    topologies: <Topology>[_moduleTopology()],
                    gracePeriod: Duration.zero,
                    child: _text(name))
                : _text(name),
          );
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(BusProvider.value(bus: bus, child: _namedApp(key, <String>['/home'], <NavigatorObserver>[])));
      final ModuleScope scope =
          bus.module('checkout', <Topology>[_moduleTopology()], gracePeriod: Duration.zero);
      final NavigatorState nav = key.currentState!;
      unawaited(nav.push(page('/checkout/cart')));
      expect(scope.references, 0);
      await h.pump();
      expect(scope.references, 1);
      await h.pumpAndSettle();
      unawaited(nav.push(page('/checkout/pay')));
      await h.pumpAndSettle();
      unawaited(nav.push(page('/profile', wrapped: false)));
      await h.pumpAndSettle();
      expect(scope.references, 2);
      nav.pop();
      await h.pumpAndSettle();
      unawaited(nav.pushReplacement<void, void>(page('/checkout/review')));
      await h.pump();
      expect(scope.references, 3);
      await h.pumpAndSettle();
      expect(scope.references, 2);
      nav.pop();
      await h.pump(const Duration(milliseconds: 150));
      expect(scope.references, 2);
      await h.pumpAndSettle();
      expect(scope.references, 1);
      expect(activations.ids, <String>['fb-checkout']);
      nav.pop();
      await h.pumpAndSettle();
      expect(scope.references, 0);
      expect(scope.isActive, isFalse);
    },
  ),
  (
    name: 'G20 a NidanaModule around a nested Navigator holds one reference while the routes inside it come and go, whatever their names',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.start();
      Route<dynamic> unnamed(Widget child) => PageRouteBuilder<void>(
          pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) => child);
      final GlobalKey<NavigatorState> root = GlobalKey<NavigatorState>();
      final GlobalKey<NavigatorState> nested = GlobalKey<NavigatorState>();
      await h.pumpWidget(BusProvider.value(bus: bus, child: _namedApp(root, <String>['/home'], <NavigatorObserver>[])));
      unawaited(root.currentState!.push(unnamed(NidanaModule(
        moduleId: 'checkout',
        topologies: <Topology>[_moduleTopology()],
        child: Navigator(
          key: nested,
          onGenerateInitialRoutes: (NavigatorState _, String _) => <Route<dynamic>>[unnamed(_text('cart'))],
          onGenerateRoute: (RouteSettings _) => null,
        ),
      ))));
      await h.pumpAndSettle();
      final ModuleScope scope = bus.module('checkout', <Topology>[_moduleTopology()]);
      expect(scope.references, 1);
      for (final String step in <String>['pay', 'review']) {
        unawaited(nested.currentState!.push(unnamed(_text(step))));
        await h.pumpAndSettle();
      }
      unawaited(nested.currentState!.pushReplacement<void, void>(unnamed(_text('done'))));
      await h.pumpAndSettle();
      nested.currentState!.pop();
      await h.pumpAndSettle();
      expect(scope.references, 1);
      root.currentState!.pop();
      await h.pumpAndSettle();
      expect(scope.references, 0);
    },
  ),
  (
    name: 'G20 NidanaModules and a ModuleScopeObserver that declare one module share its scope and add their references, and a NidanaModule that declares it otherwise fails to mount with ArgumentError',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      bus.start();
      final ModuleScopeObserver o = ModuleScopeObserver(bus, <ModuleRoutes>[
        ModuleRoutes(moduleId: 'checkout', prefix: 'checkout', topologies: <Topology>[_moduleTopology()]),
      ]);
      final Widget twoWrappers = Column(textDirection: TextDirection.ltr, children: <Widget>[
        for (var i = 0; i < 2; i++)
          NidanaModule(
              key: ValueKey<int>(i),
              moduleId: 'checkout',
              topologies: <Topology>[_moduleTopology()],
              child: const SizedBox()),
      ]);
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: WidgetsApp(
          navigatorKey: key,
          navigatorObservers: <NavigatorObserver>[o],
          color: const Color(0xFF000000),
          onGenerateInitialRoutes: (String _) => <Route<dynamic>>[_named('/checkout/cart', twoWrappers)],
          onGenerateRoute: (RouteSettings _) => null,
        ),
      ));
      expect(h.takeException(), isNull);
      expect(o.scopes.single.references, 3);
      o.dispose();
      expect(o.scopes.single.references, 2);
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: NidanaModule(
            moduleId: 'checkout',
            topologies: <Topology>[_moduleTopology()],
            gracePeriod: const Duration(milliseconds: 300),
            child: const SizedBox()),
      ));
      expect(h.takeException(), isA<ArgumentError>());
      expect(o.scopes.single.references, 0);
    },
  ),
  (
    name: 'G20 a NidanaModule mounted before start() fails to mount with the StateError of scope timing, builds no child and holds no reference',
    body: (FlutterBindingHarness h) async {
      final Bus bus = h.bus(_quiet);
      var built = false;
      await h.pumpWidget(BusProvider.value(
        bus: bus,
        child: NidanaModule(
            moduleId: 'checkout',
            topologies: <Topology>[_moduleTopology()],
            child: _Context((BuildContext _) => built = true)),
      ));
      final Object? error = h.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('checkout'));
      expect(built, isFalse);
      final ModuleScope scope = bus.module('checkout', <Topology>[_moduleTopology()]);
      expect(scope.references, 0);
      expect(_active(bus), isEmpty);
      await h.pumpWidget(BusProvider.value(bus: bus, child: const SizedBox()));
      expect(scope.references, 0);
    },
  ),
  (
    name: 'G20 a NidanaModule binds once, at mount: a rebuild with other arguments, or a change of the provided bus, keeps its reference on the bus it mounted under until it unmounts',
    body: (FlutterBindingHarness h) async {
      final Bus a = h.bus(_quiet);
      final Bus b = h.bus(_quiet);
      a.start();
      b.start();
      Widget under(Bus bus, String moduleId) => BusProvider.value(
            bus: bus,
            child: NidanaModule(
                moduleId: moduleId, topologies: <Topology>[_moduleTopology()], child: const SizedBox()),
          );
      await h.pumpWidget(under(a, 'checkout'));
      final ModuleScope onA = a.module('checkout', <Topology>[_moduleTopology()]);
      expect(onA.references, 1);
      await h.pumpWidget(under(a, 'other'));
      expect(onA.references, 1);
      expect(a.module('other', <Topology>[_moduleTopology()]).references, 0);
      await h.pumpWidget(under(b, 'checkout'));
      expect(onA.references, 1);
      expect(b.module('checkout', <Topology>[_moduleTopology()]).references, 0);
      await h.pumpWidget(BusProvider.value(bus: b, child: const SizedBox()));
      expect(onA.references, 0);
    },
  ),
];

Set<ShellClaim> _claims(Bus bus) => bus.toGraph().claims.toSet();
