// Derives nidana.runtime's behavior replay schedule from the fixtures: for
// each conformance case of bus-api@v1, bus-testing@v1 and topology-dsl@v1's
// live suite, the first phase of the S30 phase plan after which every
// mechanism the case touches exists, then for each guarantee the latest of
// its cases (ADR-001 item 10: a guarantee joins `--guarantee` once every
// case of it can pass). Run from this directory:
//   fvm dart schedule.dart > output.txt
import 'dart:io';

const String fixtures = '../../../../hsdd/contract/fixture';

/// The phase (nidana.runtime.{n}) that lands each mechanism, as the S30 plan
/// cuts the slices. The harness itself (TestBus, VirtualScheduler) is 5.
const List<(String, int, String)> mechanisms = <(String, int, String)>[
  (r'\.observe\(|_listen|getCurrentValue|getBufferedValues|_currentAny|_bufferedAny|removeTopic', 6, 'registry, cells, observed streams'),
  (r'\.start\(\)|bus\.publish\(|_publishAny|addObserver|EnvelopeRecorder\.attach|recorder\.envelopes', 7, 'publish path, start, observers, recorder seam'),
  (r'\.publisher\(|writes:|\.writer\(|_writerAny|toGraph\(', 8, 'publishers, writers, claims, live graph'),
  (r'\.activate\(|_relayAny|_gate\(', 12, 'activation wiring (11 for the cases listed as checks-only)'),
  (r'TelemetryObserver|\.input\b|\.stub\(|payloadsOf|envelopesOf|OrderingProbe|_recordOne', 13, 'test support, telemetry'),
  (r'\.module\(|onShutdown\(|StartNotCalled', 14, 'module scopes, lifecycle'),
];

/// Cases whose activations need the checks, handles and live graph only, not
/// the pipeline wiring: nothing they assert depends on a pipeline running.
const List<String> checksOnly = <String>[
  'G1 two buses',
  'G10 an activation beyond',
  'G20 a claim on a state topic that a live publisher or an active topology owns',
  'G20 a claim bound to a shorter scope',
  'G21 deactivating a topology releases',
  'G22 an APPLICATION topology activated after start',
  'G23 activating a different definition',
  'G23 after deactivation',
  'G23 two declarations with equal definitions',
  'G24 ',
  'G32 ',
  'G37 ',
  'G18 stub rejects a topic another owner holds',
];

typedef Case = ({String name, String body});

List<Case> casesOf(String path) {
  final String src = File(path).readAsStringSync();
  final RegExp start = RegExp(r"\n\s*\(\s*\n\s*name:\s*\n?\s*'([^']*)'");
  final List<RegExpMatch> ms = start.allMatches(src).toList();
  return <Case>[
    for (var i = 0; i < ms.length; i++)
      (
        name: ms[i].group(1)!,
        body: src.substring(ms[i].end, i + 1 < ms.length ? ms[i + 1].start : src.length),
      ),
  ];
}

int phaseOf(Case c, {required bool live}) {
  if (live) return 12;
  var p = 5;
  for (final (String re, int phase, String _) in mechanisms) {
    if (RegExp(re).hasMatch(c.body)) {
      var q = phase;
      if (q == 12 && checksOnly.any(c.name.startsWith)) q = 11;
      if (q > p) p = q;
    }
  }
  return p;
}

void report(String label, String path, {bool live = false}) {
  final List<Case> cases = casesOf(path);
  final Map<String, int> byGuarantee = <String, int>{};
  stdout.writeln('### $label: ${cases.length} cases');
  for (final Case c in cases) {
    final String id = RegExp(r'^G\d+').firstMatch(c.name)!.group(0)!;
    final int p = phaseOf(c, live: live);
    stdout.writeln('  .$p  ${c.name.length > 96 ? '${c.name.substring(0, 96)}...' : c.name}');
    byGuarantee[id] = (byGuarantee[id] ?? 0) > p ? byGuarantee[id]! : p;
  }
  final int starts = cases.where((Case c) => RegExp(r'\.start\(\)').hasMatch(c.body)).length;
  final Set<String> shutdowns = <String>{
    for (final Case c in cases)
      if (RegExp(r'shutdown\(\)').hasMatch(c.body)) RegExp(r'^G\d+').firstMatch(c.name)!.group(0)!,
  };
  stdout.writeln('  cases calling start(): $starts of ${cases.length}');
  stdout.writeln('  guarantees with a case calling shutdown(): ${shutdowns.join(', ')}');
  final List<String> ids = byGuarantee.keys.toList()
    ..sort((a, b) => int.parse(a.substring(1)).compareTo(int.parse(b.substring(1))));
  stdout.writeln('  per guarantee (the phase after which every case passes):');
  for (final int phase in <int>{...byGuarantee.values}.toList()..sort()) {
    final List<String> at = <String>[for (final String g in ids) if (byGuarantee[g] == phase) g];
    stdout.writeln('    .$phase: ${at.join(', ')}');
  }
  stdout.writeln('  cumulative --guarantee lists:');
  for (final int phase in <int>[5, 6, 7, 8, 11, 12, 13, 14]) {
    final List<String> upTo = <String>[for (final String g in ids) if (byGuarantee[g]! <= phase) g];
    stdout.writeln('    after .$phase (${upTo.length} of ${ids.length}): ${upTo.join(',')}');
  }
  stdout.writeln();
}

void main() {
  report('bus-api@v1 suite', '$fixtures/bus-api/behavior/bus_api_conformance.dart');
  report('bus-testing@v1 suite', '$fixtures/bus-testing/behavior/bus_testing_conformance.dart');
  report('topology-dsl@v1 live suite (bound in bus_activation_test.dart)',
      '$fixtures/topology-dsl/behavior/live_conformance.dart', live: true);
}
