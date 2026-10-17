// Surface of bus-testing@v1, the TestBus and the provider family: every
// declaration used with the types the Interface states. Passes when
// `fvm dart analyze --fatal-infos` reports nothing (ADR-001 item 4). The
// switch over SchedulerProvider names both providers and no catch-all, so a
// third provider fails this file.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const StateTopic<int> count = StateTopic<int>(name: 'surface.count', initial: 0);
const EventTopic<String> taps = EventTopic<String>(name: 'surface.taps');

String describe(SchedulerProvider provider) => switch (provider) {
      ProductionSchedulerProvider() => 'production',
      VirtualSchedulerProvider(:final VirtualScheduler scheduler) =>
        'virtual at ${scheduler.clock.now()}',
    };

void construct() {
  final TestBus plain = TestBus();
  final TestBus configured = TestBus(const BusConfig(devMode: false));
  final VirtualScheduler shared = VirtualScheduler();
  final VirtualSchedulerProvider provider = VirtualSchedulerProvider(shared);
  final VirtualScheduler providerScheduler = provider.scheduler;
  final SchedulerProvider asProvider = provider;
  final TestBus onShared = TestBus(BusConfig(scheduler: provider));
  final Bus asBus = onShared;
  final Bus plainOnVirtual = Bus(BusConfig(scheduler: provider));
  print(<Object?>[
    plain, configured, providerScheduler, describe(asProvider), asBus,
    plainOnVirtual,
  ]);
}

void use(TestBus bus) {
  final VirtualScheduler scheduler = bus.scheduler;
  final EnvelopeRecorder recorder = bus.recorder;
  const ServiceSource source = TestBus.testSource;
  final MessageSource asSource = TestBus.testSource;
  final Publisher input = bus.input;
  input.publish(taps, 'tap');
  final StateWriter<int> stub = bus.stub(count);
  stub.publish(1);
  print(<Object?>[scheduler, recorder, source, asSource]);
}
