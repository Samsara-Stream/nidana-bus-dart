// S79 (hsdd-phase-plan, nidana.runtime, append mode; H11 of the v0.15.1
// intake). Re-derives nidana.runtime's behavior replay schedule from the
// fixtures as they stand after H3 and H4: for each conformance case of
// bus-api@v2 (109), bus-testing@v2 (50) and topology-dsl@v2's live suite
// (49, bound in bus-api's bus_activation_test.dart), the first phase of the
// re-planned cut after which every mechanism the case touches exists; then,
// for each guarantee, the latest of its cases (ADR-001 item 10: a guarantee
// joins `--guarantee` once every case of it can pass). It descends from
// ../runtime-replay-schedule/schedule.dart (S30, against the v1 fixtures),
// with the mechanism map of the re-plan:
//
//   .6  registry and cells: getCurrentValue, getBufferedValues, removeTopic
//   .7  publish path, start() with its queue, observers, the recorder seam
//   .15 observed streams (appended): observe, its first values, the
//       bootstrap hold and step 2 of start(), the forwarding subscription
//   .8  publishers, writers, claims, the live graph
//   .11 activation checks and handles (cases that need no pipeline running)
//   .12 activation wiring, step 1 of start()
//   .13 test support, telemetry
//   .14 module scopes, lifecycle
//
// Phases run in this order on the bus lane: .5, .6, .7, .15, .8, .11, .12,
// .13, .14. The pipeline lane (.9, .16, .10) and the pure band produce no
// contract and replay no behavior.
//
// With `--check <spec>` it also reads every gate of the plan in <spec> and
// checks that each `--guarantee` id selects at least one case of the suite
// it restricts, and that each restricted gate equals the cumulative list this
// schedule derives for its phase.
//
// Run from this directory:
//   fvm dart schedule.dart > output.txt
//   fvm dart schedule.dart --check ../../../../hsdd/spec/nidana.runtime.md
import 'dart:io';

const String fixtures = '../../../../hsdd/contract/fixture';

/// Execution order of the producing phases whose gates replay behavior.
const List<int> order = <int>[5, 6, 7, 15, 8, 11, 12, 13, 14];

int rank(int phase) => order.indexOf(phase);

/// The phase that lands each mechanism in the re-planned cut.
const List<(String, int)> mechanisms = <(String, int)>[
  (r'getCurrentValue|getBufferedValues|_currentAny|_bufferedAny|removeTopic', 6),
  (r'\.start\(\)|bus\.publish\(|\bbus\.publish\b|_publishAny|addObserver|EnvelopeRecorder\.attach|\.recorder\b', 7),
  (r'\.observe\(|_listen\b|_listen<|_listen\(|_listenAny', 15),
  (r'\.publisher\(|writes:|\.writer\(|_writerAny|_publishThroughAny|toGraph\(', 8),
  (r'\.activate\(|_relayAny|_gate\(', 12),
  (r'TelemetryObserver|\.input\b|\.stub\(|payloadsOf|envelopesOf|OrderingProbe|_recordOne', 13),
  (r'\.module\(|onShutdown\(|StartNotCalled|\.acquire\b', 14),
];

/// Cases that activate but assert nothing a running pipeline produces: they
/// pass once activation checks, claims and handles exist (.11), before the
/// wiring of .12. Each was read case by case (S79).
const List<String> checksOnly = <String>[
  'G1 two buses',
  'G10 an activation beyond',
  'G20 a claim on a state topic that a live publisher or an active topology owns',
  'G20 a claim bound to a shorter scope',
  'G21 deactivating a topology releases',
  'G23 activating a different definition',
  'G23 after deactivation',
  'G23 equal definitions whose plans differ',
  'G24 ',
  'G25 an activation deactivated before start',
  'G32 ',
  'G37 ',
  'G42 a MODULE or PAGE topology activated before start',
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

String idOf(Case c) => RegExp(r'^G\d+').firstMatch(c.name)!.group(0)!;

int phaseOf(Case c, {required bool live}) {
  if (live) return 12;
  var p = 5;
  for (final (String re, int phase) in mechanisms) {
    if (RegExp(re).hasMatch(c.body)) {
      var q = phase;
      if (q == 12 && checksOnly.any(c.name.startsWith)) q = 11;
      if (rank(q) > rank(p)) p = q;
    }
  }
  return p;
}

typedef Suite = ({String label, String slug, List<Case> cases, bool live});

final List<Suite> suites = <Suite>[
  (
    label: 'bus-api@v2 suite (nidana_dart_runtime_test.dart)',
    slug: 'bus-api',
    cases: casesOf('$fixtures/bus-api/behavior/bus_api_conformance.dart'),
    live: false,
  ),
  (
    label: 'bus-testing@v2 suite (nidana_dart_runtime_test.dart)',
    slug: 'bus-testing',
    cases: casesOf('$fixtures/bus-testing/behavior/bus_testing_conformance.dart'),
    live: false,
  ),
  (
    label: 'topology-dsl@v2 live suite (bound in bus-api bus_activation_test.dart)',
    slug: 'topology-dsl',
    cases: casesOf('$fixtures/topology-dsl/behavior/live_conformance.dart'),
    live: true,
  ),
];

/// For each suite, guarantee id -> the phase after which every case passes.
Map<String, Map<String, int>> schedule() => <String, Map<String, int>>{
      for (final Suite s in suites)
        s.slug: () {
          final Map<String, int> by = <String, int>{};
          for (final Case c in s.cases) {
            final int p = phaseOf(c, live: s.live);
            final String id = idOf(c);
            by[id] = by[id] == null || rank(p) > rank(by[id]!) ? p : by[id]!;
          }
          return by;
        }(),
    };

List<String> sortIds(Iterable<String> ids) =>
    ids.toList()..sort((a, b) => int.parse(a.substring(1)).compareTo(int.parse(b.substring(1))));

List<String> upTo(Map<String, int> by, int phase) =>
    sortIds(<String>[for (final e in by.entries) if (rank(e.value) <= rank(phase)) e.key]);

void report() {
  final Map<String, Map<String, int>> sched = schedule();
  for (final Suite s in suites) {
    stdout.writeln('### ${s.label}: ${s.cases.length} cases');
    for (final Case c in s.cases) {
      final int p = phaseOf(c, live: s.live);
      stdout.writeln('  .$p  ${c.name.length > 100 ? '${c.name.substring(0, 100)}...' : c.name}');
    }
    final int starts = s.cases.where((Case c) => RegExp(r'\.start\(\)').hasMatch(c.body)).length;
    final Set<String> shutdowns = <String>{
      for (final Case c in s.cases)
        if (RegExp(r'shutdown\(\)').hasMatch(c.body)) idOf(c),
    };
    stdout.writeln('  cases calling start(): $starts of ${s.cases.length}');
    stdout.writeln('  guarantees with a case calling shutdown(): ${sortIds(shutdowns).join(', ')}');
    final Map<String, int> by = sched[s.slug]!;
    stdout.writeln('  per guarantee (the phase after which every case passes):');
    for (final int phase in order) {
      final List<String> at = sortIds(<String>[for (final e in by.entries) if (e.value == phase) e.key]);
      if (at.isNotEmpty) stdout.writeln('    .$phase: ${at.join(', ')}');
    }
    stdout.writeln('  cumulative --guarantee lists, in execution order:');
    for (final int phase in order) {
      final List<String> l = upTo(by, phase);
      stdout.writeln('    after .$phase (${l.length} of ${by.length}): ${l.join(',')}');
    }
    stdout.writeln();
  }
}

/// Reads the gates of [specPath]'s phase sections and checks each
/// restriction against the fixtures and against the schedule.
int check(String specPath) {
  final String spec = File(specPath).readAsStringSync();
  final Map<String, Map<String, int>> sched = schedule();
  final Map<String, Suite> bySlug = <String, Suite>{for (final Suite s in suites) s.slug: s};
  final RegExp head = RegExp(r'^### nidana\.runtime\.(\d+): ', multiLine: true);
  final List<RegExpMatch> heads = head.allMatches(spec).toList();
  var failures = 0;
  for (var i = 0; i < heads.length; i++) {
    final int phase = int.parse(heads[i].group(1)!);
    final String section =
        spec.substring(heads[i].start, i + 1 < heads.length ? heads[i + 1].start : spec.length);
    final RegExpMatch? gate = RegExp(r'^- \*\*Gate:\*\* (.*)$', multiLine: true).firstMatch(section);
    if (gate == null) {
      stdout.writeln('.$phase: NO GATE LINE');
      failures++;
      continue;
    }
    final String g = gate.group(1)!;
    final List<RegExpMatch> runs = RegExp(r'nidana_contract_check ([a-z -]+?)(?: --guarantee ([A-Za-z0-9,/-]+))?(?= &&|`|$)')
        .allMatches(g)
        .toList();
    if (runs.isEmpty) {
      stdout.writeln('.$phase: ${g.length > 60 ? '${g.substring(0, 60)}...' : g} (no replay command; node default)');
      continue;
    }
    for (final RegExpMatch r in runs) {
      final List<String> slugs = r.group(1)!.trim().split(' ').where((String x) => !x.startsWith('-')).toList();
      final String? list = r.group(2);
      if (list == null) {
        stdout.writeln('.$phase: ${slugs.join(' ')} unrestricted');
        continue;
      }
      if (slugs.length != 1) {
        stdout.writeln('.$phase: FAIL bare ids with ${slugs.length} slugs');
        failures++;
        continue;
      }
      final String slug = slugs.single;
      final List<String> ids = list.split(',');
      final Map<String, List<String>> perSlug = <String, List<String>>{};
      for (final String id in ids) {
        final List<String> parts = id.split('/');
        final String s = parts.length == 2 ? parts[0] : slug;
        final String g2 = parts.last;
        perSlug.putIfAbsent(s, () => <String>[]).add(g2);
        final Suite? suite = bySlug[s];
        if (suite == null) {
          stdout.writeln('.$phase: FAIL $id names a slug with no suite here');
          failures++;
          continue;
        }
        final int n = suite.cases.where((Case c) => c.name.startsWith('$g2 ')).length;
        if (n == 0) {
          stdout.writeln('.$phase: FAIL $id selects no case of ${suite.slug}');
          failures++;
        }
      }
      for (final MapEntry<String, List<String>> e in perSlug.entries) {
        final List<String> want = upTo(sched[e.key]!, phase);
        final List<String> got = sortIds(e.value);
        final bool same = want.join(',') == got.join(',');
        final int selected = bySlug[e.key]!.cases.where((Case c) => got.contains(idOf(c))).length;
        stdout.writeln('.$phase: $slug replay, ${e.key} ids ${got.length}, $selected cases selected; '
            '${same ? 'equals the schedule' : 'DIFFERS from the schedule: want ${want.join(',')}'}');
        if (!same) failures++;
      }
      if (slug == 'bus-api' && !perSlug.containsKey('topology-dsl') && rank(phase) >= rank(12)) {
        stdout.writeln('.$phase: FAIL bus-api replay names no topology-dsl id at or after .12');
        failures++;
      }
    }
  }
  stdout.writeln('check: $failures failure(s)');
  return failures;
}

void main(List<String> args) {
  if (args.length == 2 && args[0] == '--check') {
    exitCode = check(args[1]) == 0 ? 0 : 1;
    return;
  }
  report();
}
