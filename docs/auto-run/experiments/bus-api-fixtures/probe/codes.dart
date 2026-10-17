// Probe: which diagnostic each candidate type-level misuse reports.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const StateTopic<int> s = StateTopic<int>(name: 'p.s', initial: 0);
const EventTopic<int> e = EventTopic<int>(name: 'p.e');
const ReplayTopic<int> r = ReplayTopic<int>(name: 'p.r', bufferSize: 2);

final class B1 extends Bus {}
final class B2 implements Bus {}
final class P1 implements Publisher {}
final class W1 implements StateWriter<int> {}
final class H1 implements TopologyHandle {}
final class M1 implements ModuleScope {}
final class R1 implements ModuleReference {}
final class C1 extends BusConfig {}
final class SP1 extends SchedulerProvider {}
final class SP2 implements SchedulerProvider {}
final class SP3 extends ProductionSchedulerProvider {}
final class D1 extends BusDiagnostic {}
final class D2 implements ShellDiagnostic {
  @override
  String get origin => 'x';
}
final class D3 extends ShellDiagnostic {
  const D3();
  @override
  String get origin => 'x';
}
final class E1 extends BusError {}
final class E2 extends ActivationRejected {}
final class T1 extends TelemetryObserver {}

void f(Bus bus, Publisher p, BusConfig config) {
  Bus.instance;
  Bus.current;
  Bus.of(bus);
  Publisher();
  TopologyHandle();
  ModuleScope();
  StateWriter<int>();
  bus.publish(s, 1);
  p.publish(s, 1);
  bus.getCurrentValue(e);
  bus.getCurrentValue(r);
  bus.getBufferedValues(s);
  bus.getBufferedValues(e);
  bus.publisher(const ServiceSource('x'), writes: {e});
  bus.publisher(const ServiceSource('x'), writes: <StateTopic<Object?>>{e});
  p.writer(s).publish('x');
  p.writer(e);
  config.maxTopics = 3;
  bus.clock = bus.clock;
  bus.config = config;
  bus.devMode = false;
  p.source = const ServiceSource('y');
}
