// bus-api-v2 probe P2: what a derived topology activated before its input's
// writer sees when start() connects them (bus-api@v2 G34; Spec v0.15.1
// §3.13 step 1). The reader reads x and writes y = 10 * x; the writer reads
// s (initial 1) and writes x = s + 1. The reader is activated first. Run
// against each runtime: fvm dart run probe/barrier_probe.dart
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_dart_runtime/testing.dart';

const StateTopic<int> _s = StateTopic<int>(name: 'p.s', initial: 1);
const StateTopic<int> _x = StateTopic<int>(name: 'p.x', initial: 0);
const StateTopic<int> _y = StateTopic<int>(name: 'p.y', initial: 0);

final List<String> _log = <String>[];

int _times10(int v) {
  _log.add('reader saw x=$v');
  return v * 10;
}

int _plus1(int v) {
  _log.add('writer saw s=$v');
  return v + 1;
}

void main() {
  final TestBus bus = TestBus(const BusConfig(devMode: false));
  bus.activate(topology('reader', Scope.application,
      (TopologyBuilder b) => b.write(_y, b.read(_x).map(_times10))));
  bus.activate(topology('writer', Scope.application,
      (TopologyBuilder b) => b.write(_x, b.read(_s).map(_plus1))));
  final List<int> ys = <int>[];
  bus.observe(_y).listen(ys.add);
  _log.add('-- before start (after triggerActions)');
  bus.scheduler.triggerActions();
  _log.add('-- start()');
  bus.start();
  _log.add('-- start() returned: x=${bus.getCurrentValue(_x)} y=${bus.getCurrentValue(_y)} '
      'subscriber of y got $ys');
  bus.scheduler.triggerActions();
  _log.add('-- after triggerActions: x=${bus.getCurrentValue(_x)} y=${bus.getCurrentValue(_y)} '
      'subscriber of y got $ys');
  _log.add('-- recorder: ${<String>[
    for (final RecordedEnvelope r in bus.recorder.envelopes)
      '${r.topic.name}=${r.envelope.payload}',
  ]}');
  _log.forEach(print);
}
