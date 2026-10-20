// navigation-executor-during-start (S83, hsdd-phase-plan nidana.navigation):
// can nidana.navigation.6's planned test construct a NavigationExecutor from
// a bootstrap subscription's callback during start(), and is it reported as
// LateExecutorConstruction (bus-api@v2 G34: the bus is running from the
// moment start() begins its steps; navigation-api@v1 G19)? Also: does that
// executor then work, and what does the recorder hold, in which order?
//
// Runs on the stand-in packages of ../navigation-api-v0151/ (the bus-api@v2
// stand-in runtime and the "once" navigation stand-in), through that
// workspace's package configuration, without editing it:
//   fvm dart run --packages=../navigation-api-v0151/.dart_tool/package_config.json probe.dart
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_navigation/nidana_dart_navigation.dart';
import 'package:nidana_dart_navigation/testing.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const NavRoute<void> _home = NavRoute<void>('p/home');
const NavRoute<int> _detail = NavRoute<int>('p/detail');
const StateTopic<int> _trigger = StateTopic<int>(name: 'probe.trigger', initial: 0);

void main() {
  for (final String step in <String>['step 2 (first value)', 'step 3 (queue)']) {
    final List<BusDiagnostic> d = <BusDiagnostic>[];
    final TestBus bus = TestBus(BusConfig(devMode: true, diagnostics: d.add));
    final InMemoryRouter router = InMemoryRouter(RouteState(route: _home));
    NavigationExecutor? executor;
    BusLifecycle? seen;
    final StateWriter<int> trigger = bus.stub(_trigger);
    final bool onQueue = step.startsWith('step 3');
    if (onQueue) trigger.publish(1);
    bus.observe(_trigger).listen((int v) {
      if (executor != null) return;
      if (onQueue && v != 1) return;
      seen = bus.lifecycle;
      executor = NavigationExecutor(bus, router, name: 'during-start');
    });
    print('$step: lifecycle before start(): ${bus.lifecycle}');
    bus.start();
    bus.scheduler.triggerActions();
    print('$step: executor constructed: ${executor != null}; lifecycle seen in the callback: $seen');
    print('$step: diagnostics: $d');
    bus.input.publish(NavigationTopics.resolvedIntent, _detail.go(2));
    bus.scheduler.triggerActions();
    print('$step: router stack after a resolved intent: '
        '${router.stack.map((NavigationEntry e) => '${e.state.route.path}:${e.state.args}').toList()}');
    print('$step: nav.current-route: ${bus.getCurrentValue(NavigationTopics.currentRoute).route.path}');
    print('$step: recorded topics in order: '
        '${bus.recorder.envelopes.map((RecordedEnvelope r) => r.topic.name).toList()}');
    bus.shutdown();
  }
}
