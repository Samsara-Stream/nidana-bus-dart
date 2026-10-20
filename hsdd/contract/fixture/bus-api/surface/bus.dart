// Surface of bus-api@v2, configuration, lifecycle, topics and publishers:
// every declaration used with the types the Interface states. Passes when
// `fvm dart analyze --fatal-infos` reports nothing (ADR-001 item 4).
import 'dart:async';

import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const StateTopic<int> count = StateTopic<int>(name: 'surface.count', initial: 0);
const EventTopic<String> taps = EventTopic<String>(name: 'surface.taps');
const ReplayTopic<String> log =
    ReplayTopic<String>(name: 'surface.log', bufferSize: 3);
const EventTopic<num> readings = EventTopic<num>(name: 'surface.readings');

void configure(DiagnosticSink sink, ObserveContext context) {
  const BusConfig defaults = BusConfig();
  final BusConfig config = BusConfig(
    scheduler: const ProductionSchedulerProvider(),
    devMode: true,
    diagnostics: sink,
    observeContext: context,
    maxTopics: 100,
    maxActiveTopologies: 20,
    maxObservers: 4,
    maxReentrancyDepth: 5,
    moduleScopeGracePeriod: const Duration(milliseconds: 250),
    startupWindow: const Duration(seconds: 2),
  );
  final SchedulerProvider? scheduler = config.scheduler;
  final bool? devMode = config.devMode;
  final DiagnosticSink? diagnostics = config.diagnostics;
  final ObserveContext? observeContext = config.observeContext;
  final int maxTopics = config.maxTopics;
  final int maxActiveTopologies = config.maxActiveTopologies;
  final int maxObservers = config.maxObservers;
  final int maxReentrancyDepth = config.maxReentrancyDepth;
  final Duration grace = config.moduleScopeGracePeriod;
  final Duration window = config.startupWindow;
  final Bus bus = Bus(config);
  final Bus plain = Bus();
  print(<Object?>[
    defaults, scheduler, devMode, diagnostics, observeContext, maxTopics,
    maxActiveTopologies, maxObservers, maxReentrancyDepth, grace, window,
    bus, plain,
  ]);
  final String provider = switch (scheduler) {
    null => 'production',
    ProductionSchedulerProvider() => 'production',
    SchedulerProvider() => 'virtual',
  };
  print(provider);
}

void lifecycle(Bus bus) {
  final BusConfig config = bus.config;
  final bool devMode = bus.devMode;
  final DateTime now = bus.clock.now();
  final Stopwatch watch = bus.clock.stopwatch();
  final BusLifecycle lifecycle = bus.lifecycle;
  final String phase = switch (lifecycle) {
    BusLifecycle.bootstrapping => 'bootstrapping',
    BusLifecycle.running => 'running',
    BusLifecycle.shutDown => 'shut down',
  };
  bus.onShutdown(() => print('disposed'));
  bus.start();
  bus.shutdown();
  print(<Object?>[config, devMode, now, watch, phase]);
}

void topics(Bus bus) {
  bus.publish(taps, 'tap');
  bus.publish<String, String>(log, 'entry');
  bus.publish(readings, 1);
  final Stream<int> counts = bus.observe(count);
  final Stream<String> tapStream = bus.observe(taps);
  final StreamSubscription<String> sub = bus.observe(log).listen(print);
  final int current = bus.getCurrentValue(count);
  final List<String> buffered = bus.getBufferedValues(log);
  final bool removed = bus.removeTopic(taps);
  final bool forced = bus.removeTopic(count, force: true);
  unawaited(sub.cancel());
  print(<Object?>[counts, tapStream, current, buffered, removed, forced]);
}

void publishers(Bus bus) {
  final Publisher events = bus.publisher(const PageSource('checkout/cart'));
  final Publisher owner = bus.publisher(
    const ExecutorSource('example'),
    writes: <StateTopic<Object?>>{count},
    scope: Scope.module,
  );
  final MessageSource source = owner.source;
  final Scope scope = owner.scope;
  final Set<StateTopic<Object?>> writes = owner.writes;
  final bool disposed = owner.isDisposed;
  events.publish(taps, 'tap');
  events.publish<String, String>(log, 'entry');
  events.publish(readings, 2.5);
  final StateWriter<int> writer = owner.writer(count);
  final StateTopic<int> topic = writer.topic;
  writer.publish(1);
  owner.dispose();
  events.dispose();
  print(<Object?>[source, scope, writes, disposed, topic]);
}

/// A generic caller that holds a topic and a value of its type publishes
/// without type arguments (G40); `readings` above shows that a value of a
/// subtype of the topic's value type compiles too.
void forward<T>(Bus bus, Publisher publisher, MultiWriterTopic<T> topic, T value) {
  bus.publish(topic, value);
  publisher.publish(topic, value);
}
