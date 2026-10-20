// navigation-api-v0151 probe P6: where an error the executor leaves
// unhandled goes (nidana.navigation D6; bus-api@v2 G18; Spec §10.2
// principle 5). The TestBus, and so its scheduler, is built in one guarded
// zone ("bus zone"); the executor is constructed in another ("executor
// zone"). Its router throws from perform on the first intent and works
// afterwards, and later emits an error event on its confirmations. Run
// against each runtime: fvm dart run probe/executor_error_probe.dart
import 'dart:async';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_navigation/testing.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const NavRoute<void> _home = NavRoute<void>('p/home');
const NavRoute<int> _detail = NavRoute<int>('p/detail');

final class _FaultyRouter implements NavigationRouter {
  _FaultyRouter(this._inner);

  final InMemoryRouter _inner;
  final StreamController<RouteConfirmation> _faults =
      StreamController<RouteConfirmation>.broadcast(sync: true);
  int _performs = 0;

  @override
  List<NavigationEntry> get stack => _inner.stack;
  @override
  bool get supportsPopUntil => _inner.supportsPopUntil;
  @override
  void perform(List<RouterCall> calls, ResolvedNavIntent intent) {
    if (_performs++ == 0) throw StateError('router defect on the first perform');
    _inner.perform(calls, intent);
  }

  @override
  Stream<RouteConfirmation> get confirmations =>
      StreamGroup.merge(_inner.confirmations, _faults.stream);

  void fault() => _faults.addError(StateError('router defect on its confirmations'));
}

/// A minimal merge of two broadcast streams, so the probe needs no package.
abstract final class StreamGroup {
  static Stream<T> merge<T>(Stream<T> a, Stream<T> b) {
    late final StreamController<T> out;
    final List<StreamSubscription<T>> subs = <StreamSubscription<T>>[];
    out = StreamController<T>.broadcast(
      sync: true,
      onListen: () {
        for (final Stream<T> s in <Stream<T>>[a, b]) {
          subs.add(s.listen(out.add, onError: out.addError));
        }
      },
      onCancel: () {
        for (final StreamSubscription<T> s in subs) {
          s.cancel();
        }
      },
    );
    return out.stream;
  }
}

void main() {
  final List<String> log = <String>[];
  late final TestBus bus;
  late final _FaultyRouter router;
  runZonedGuarded(() {
    bus = TestBus(const BusConfig(devMode: false));
  }, (Object e, StackTrace _) => log.add('bus zone: $e'));
  runZonedGuarded(() {
    router = _FaultyRouter(InMemoryRouter(RouteState(route: _home)));
    NavigationExecutor(bus, router);
  }, (Object e, StackTrace _) => log.add('executor zone: $e'));
  bus.start();
  bus.scheduler.triggerActions();
  final Publisher pages = bus.publisher(const ServiceSource('p-pages'));
  pages.publish(NavigationTopics.resolvedIntent, _detail.go(1));
  bus.scheduler.triggerActions();
  pages.publish(NavigationTopics.resolvedIntent, _detail.go(2));
  bus.scheduler.triggerActions();
  router.fault();
  bus.scheduler.triggerActions();
  print('P6 errors: ${log.join('; ')}');
  print('P6 stack after a throwing perform, a working one and a confirmation error: '
      '[${router.stack.map((NavigationEntry e) => '${e.state.route.path}:${e.state.args}').join(', ')}]; '
      'nav.current-route ${bus.getCurrentValue(NavigationTopics.currentRoute).route.path}:'
      '${bus.getCurrentValue(NavigationTopics.currentRoute).args}');
}
