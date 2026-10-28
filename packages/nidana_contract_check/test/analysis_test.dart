import 'package:nidana_contract_check/src/analysis.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/run.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String s = 'hsdd/contract/fixture/sample/';

/// One diagnostic as `dart analyze --format=json` prints it (experiment A1), every key included.
const String report =
    r'''{"version":1,"diagnostics":[{"code":"unused_import","severity":"WARNING","type":"STATIC_WARNING","location":{"file":"/w/hsdd/contract/fixture/sample/surface/dirty.dart","range":{"start":{"offset":7,"line":1,"column":8},"end":{"offset":19,"line":1,"column":20}}},"problemMessage":"Unused import: 'dart:async'.","correctionMessage":"Try removing the import directive.","documentation":"https://dart.dev/diagnostics/unused_import"}]}''';

String fields(Diagnostic d) =>
    '${d.file}|${d.line}|${d.severity}|${d.code}|${d.message}';

void main() {
  group('parseAnalysis', () {
    test('reads each diagnostic', () {
      expect(parseAnalysis(report)!.map(fields), <String>[
        "/w/hsdd/contract/fixture/sample/surface/dirty.dart|1|WARNING|unused_import|Unused import: 'dart:async'.",
      ]);
      expect(parseAnalysis('{"version":1,"diagnostics":[]}'), isEmpty);
    });
    test('ignores text before the JSON document', () {
      expect(parseAnalysis('A notice.\n$report')!.map(fields), hasLength(1));
    });
    test('is null when stdout holds no report', () {
      for (final String stdout in <String>[
        '',
        'Usage: dart analyze [arguments] [<directory>]',
        '{"version":1}',
        '{"version":1,"diagnostics":[{"code":1}]}',
        report.substring(0, 40),
      ]) {
        expect(parseAnalysis(stdout), isNull, reason: stdout);
      }
    });
    test('needs only the five fields; any entry that lacks one, or holds another type, voids the whole report', () {
      String withEntries(List<String> entries) =>
          '{"version":1,"diagnostics":[${entries.join(',')}]}';
      String entry({
        String code = '"c"',
        String line = '1',
        String message = '"problemMessage":"m"',
      }) =>
          '{"code":$code,"severity":"INFO","location":{"file":"/w/a.dart",'
          '"range":{"start":{"line":$line}}},$message}';
      expect(
        parseAnalysis(withEntries(<String>[entry()]))!.map(fields),
        <String>['/w/a.dart|1|INFO|c|m'],
      );
      for (final String stdout in <String>[
        withEntries(<String>[entry(), entry(line: '"2"')]),
        withEntries(<String>[entry(line: '1.5')]),
        withEntries(<String>[entry(code: 'null')]),
        withEntries(<String>[entry(message: '"correctionMessage":"m"')]),
        withEntries(<String>[entry(), '1']),
        '{"version":1,"diagnostics":{}}',
        '$report\nA notice.',
      ]) {
        expect(parseAnalysis(stdout), isNull, reason: stdout);
      }
    });
  });
  test('analysisFailure names the exit code and the first line of stderr', () {
    expect(
      analysisFailure(
        64,
        "\nDirectory or file doesn't exist: x.dart\n\nUsage: dart analyze [arguments] [<directory>]\n",
      ),
      "dart analyze exited 64 without a JSON report: Directory or file doesn't exist: x.dart",
    );
    expect(
      analysisFailure(1, ''),
      'dart analyze exited 1 without a JSON report',
    );
    expect(
      analysisFailure(255, '  \r\n\t Bad state: x. \r\nmore\r\n'),
      'dart analyze exited 255 without a JSON report: Bad state: x.',
    );
    expect(
      analysisFailure(3, ' \n\n'),
      'dart analyze exited 3 without a JSON report',
    );
  });
  test('diagnosticText', () {
    expect(
      diagnosticText(
        const Diagnostic(
          file: '/w/a.dart',
          line: 3,
          severity: 'INFO',
          code: 'c',
          message: 'm.',
        ),
      ),
      'line 3: INFO c: m.',
    );
  });
  test('groupDiagnostics attributes each diagnostic to its fixture and names the files it cannot', () {
    Diagnostic at(String file, int line) => Diagnostic(
      file: file,
      line: line,
      severity: 'ERROR',
      code: 'x',
      message: 'm',
    );
    final GroupedDiagnostics g = groupDiagnostics(
      <Diagnostic>[
        at('/private/w/a.dart', 1),
        at('/w/a.dart', 2),
        at('/w/b.dart', 3),
        at('/elsewhere/c.dart', 4),
        at('/elsewhere/c.dart', 5),
      ],
      <String, String>{
        '/private/w/a.dart': '${s}surface/a.dart',
        '/w/a.dart': '${s}surface/a.dart',
        '/w/b.dart': '${s}reject/b.dart',
      },
    );
    expect(
      g.byFixture.map(
        (String path, List<Diagnostic> ds) => MapEntry<String, List<int>>(
          path,
          ds.map((Diagnostic d) => d.line).toList(),
        ),
      ),
      <String, List<int>>{
        '${s}surface/a.dart': <int>[1, 2],
        '${s}reject/b.dart': <int>[3],
      },
    );
    expect(g.strays, <String>['/elsewhere/c.dart']);
  });
  test('groupDiagnostics: strays once each, ascending; nothing reported groups nothing', () {
    Diagnostic at(String file) => Diagnostic(
      file: file,
      line: 1,
      severity: 'INFO',
      code: 'x',
      message: 'm',
    );
    final GroupedDiagnostics g = groupDiagnostics(<Diagnostic>[
      at('/z.dart'),
      at('/a.dart'),
      at('/z.dart'),
    ], const <String, String>{});
    expect(g.byFixture, isEmpty);
    expect(g.strays, <String>['/a.dart', '/z.dart']);
    final GroupedDiagnostics none = groupDiagnostics(
      const <Diagnostic>[],
      <String, String>{'/w/a.dart': '${s}surface/a.dart'},
    );
    expect(none.byFixture, isEmpty);
    expect(none.strays, isEmpty);
  });
  group('the libraries a set analyzes', () {
    final SlugSnapshot snapshot = snapshotOf('sample', analysisFiles);
    test('setLibraries: every library below surface/ or reject/, by path, with the absent packages it names', () {
      expect(
        setLibraries(snapshot, CheckSet.surface, const <String>{
          'sample',
        }).map((SetLibrary l) => '${l.path} [${l.absent.join(', ')}]'),
        <String>[
          '${s}surface/dirty.dart []',
          '${s}surface/pending.dart [producer]',
          '${s}surface/use.dart []',
        ],
      );
    });
    test('analysisTargets: those that import no absent package; never behavior/ or another set', () {
      expect(
        analysisTargets(snapshot, CheckSet.surface, const <String>{'sample'}),
        <String>['${s}surface/dirty.dart', '${s}surface/use.dart'],
      );
      expect(
        analysisTargets(snapshot, CheckSet.reject, const <String>{'sample'}),
        <String>[
          '${s}reject/assigns_final.dart',
          '${s}reject/extra_warning.dart',
          '${s}reject/sample_is_closed.dart',
          '${s}reject/wrong_code.dart',
          '${s}reject/wrong_line.dart',
        ],
      );
      expect(
        analysisTargets(snapshot, CheckSet.behavior, const <String>{'sample'}),
        isEmpty,
      );
      expect(
        analysisTargets(snapshot, CheckSet.schema, const <String>{'sample'}),
        isEmpty,
      );
      expect(
        analysisTargets(snapshot, CheckSet.surface, const <String>{}),
        isEmpty,
      );
    });
    test('a nested library is one; a file that is not Dart is none; a library that names no package is never absent', () {
      final SlugSnapshot nested = snapshotOf(
        'sample',
        changed(analysisFiles, <String, String?>{
          '${s}surface/README.md': 'notes\n',
          '${s}surface/more/core.dart':
              "import 'dart:async';\n\nFuture<void> wait() async {}\n",
        }),
      );
      expect(
        setLibraries(
          nested,
          CheckSet.surface,
          const <String>{},
        ).map((SetLibrary l) => '${l.path} [${l.absent.join(', ')}]'),
        <String>[
          '${s}surface/dirty.dart [sample]',
          '${s}surface/more/core.dart []',
          '${s}surface/pending.dart [producer]',
          '${s}surface/use.dart [sample]',
        ],
      );
      expect(
        analysisTargets(nested, CheckSet.surface, const <String>{}),
        <String>['${s}surface/more/core.dart'],
      );
    });
    test('a source that is not UTF-8 is no library of surface/ or reject/', () {
      final SlugSnapshot undecodable = snapshotOf(
        'sample',
        sampleFiles,
        bytes: <String, List<int>>{
          '${s}surface/latin1.dart': <int>[0xff],
          '${s}reject/latin1.dart': <int>[0xff],
        },
      );
      expect(
        setLibraries(undecodable, CheckSet.surface, const <String>{
          'sample',
        }).map((SetLibrary l) => l.path),
        <String>['${s}surface/use.dart'],
      );
      expect(
        analysisTargets(undecodable, CheckSet.reject, const <String>{'sample'}),
        <String>['${s}reject/sample_is_closed.dart'],
      );
    });
  });
  group('the replay\'s one analysis', () {
    test('readsAnalysis: surface and reject, no other set', () {
      expect(CheckSet.values.where(readsAnalysis), <CheckSet>[
        CheckSet.surface,
        CheckSet.reject,
      ]);
    });

    // Beyond the brief: the replay-level reads of run.dart that would
    // otherwise go unpinned. Which sets readsPackages is pinned in
    // report_test.dart, beside runsCommands.
    test('every set that readsAnalysis also readsPackages, so the analysis always has its names', () {
      expect(
        CheckSet.values.where(readsAnalysis),
        everyElement(predicate<CheckSet>(readsPackages, 'reads packages')),
      );
    });
    test('slugPlan: the snapshot and the sets plannedSets runs over it', () {
      final SlugSnapshot sample = snapshotOf('sample', sampleFiles);
      const Request request = Request(
        slugs: <String>['sample'],
        sets: <CheckSet>{CheckSet.reject, CheckSet.schema},
        restriction: null,
      );
      final SlugPlan plan = slugPlan(request, sample);
      expect(plan.snapshot, same(sample));
      expect(plan.sets, <CheckSet>[CheckSet.structure, CheckSet.reject]);
    });
    test('replayTargets: analysisTargets of every planned set of every slug, once each, ascending', () {
      final SlugSnapshot sample = snapshotOf('sample', analysisFiles);
      final SlugSnapshot other = snapshotOf('other', <String, String>{
        for (final MapEntry<String, String> entry in sampleFiles.entries)
          entry.key.replaceFirst('sample', 'other'): entry.value,
      });
      expect(
        replayTargets(
          <SlugPlan>[
            (
              snapshot: sample,
              sets: <CheckSet>[
                CheckSet.structure,
                CheckSet.reject,
                CheckSet.behavior,
              ],
            ),
            (
              snapshot: other,
              sets: <CheckSet>[CheckSet.structure, CheckSet.surface],
            ),
            (snapshot: sample, sets: <CheckSet>[CheckSet.reject]),
          ],
          const <String>{'sample'},
        ),
        <String>[
          'hsdd/contract/fixture/other/surface/use.dart',
          '${s}reject/assigns_final.dart',
          '${s}reject/extra_warning.dart',
          '${s}reject/sample_is_closed.dart',
          '${s}reject/wrong_code.dart',
          '${s}reject/wrong_line.dart',
        ],
      );
      expect(
        replayTargets(<SlugPlan>[
          (
            snapshot: sample,
            sets: <CheckSet>[CheckSet.structure, CheckSet.surface],
          ),
        ], const <String>{}),
        isEmpty,
      );
    });
  });
  group('attributeDiagnostics', () {
    const String fixtures = '/private/w/hsdd/contract/fixture';
    AnalysisTarget target(String name, {String? resolved}) => (
      path: '$s$name',
      given: '/w/$s$name',
      resolved: resolved ?? '/private/w/$s$name',
    );
    Diagnostic at(String file, int line) => Diagnostic(
      file: file,
      line: line,
      severity: 'ERROR',
      code: 'x',
      message: 'm',
    );
    Object linesOf(Attribution attribution) => switch (attribution) {
      Attributed(:final Map<String, List<Diagnostic>> byFixture) =>
        byFixture.map(
          (String path, List<Diagnostic> ds) => MapEntry<String, List<int>>(
            path,
            ds.map((Diagnostic d) => d.line).toList(),
          ),
        ),
      Unattributable(:final String reason) => reason,
    };
    test('a target is found by the path it was given and by its resolved path; one with no diagnostic has no entry', () {
      expect(
        linesOf(
          attributeDiagnostics(
            <AnalysisTarget>[
              target('surface/a.dart'),
              target('surface/clean.dart'),
            ],
            fixtures,
            <Diagnostic>[
              at('/private/w/${s}surface/a.dart', 1),
              at('/w/${s}surface/a.dart', 2),
            ],
          ),
        ),
        <String, List<int>>{
          '${s}surface/a.dart': <int>[1, 2],
        },
      );
    });
    test('targets that resolve to one file each get its diagnostics, as a link to another library does', () {
      expect(
        linesOf(
          attributeDiagnostics(
            <AnalysisTarget>[
              target(
                'reject/b.dart',
                resolved:
                    '/private/w/hsdd/contract/fixture/other/surface/a.dart',
              ),
              target(
                'surface/c.dart',
                resolved:
                    '/private/w/hsdd/contract/fixture/other/surface/a.dart',
              ),
            ],
            fixtures,
            <Diagnostic>[
              at('/private/w/hsdd/contract/fixture/other/surface/a.dart', 3),
            ],
          ),
        ),
        <String, List<int>>{
          '${s}reject/b.dart': <int>[3],
          '${s}surface/c.dart': <int>[3],
        },
      );
    });
    test('a reported file no target claims refuses the attribution, naming the first stray', () {
      expect(
        linesOf(
          attributeDiagnostics(
            <AnalysisTarget>[target('surface/a.dart')],
            fixtures,
            <Diagnostic>[
              at('/private/w/${s}surface/a.dart', 1),
              at('/z/stray.dart', 1),
              at('/elsewhere/stray.dart', 1),
            ],
          ),
        ),
        'dart analyze reported /elsewhere/stray.dart, which the replay did not ask it to analyze',
      );
    });
    test('a target that resolves outside the fixtures refuses the attribution, before any stray and whatever is reported', () {
      String outside(String resolved, List<Diagnostic> reported) => linesOf(
        attributeDiagnostics(
          <AnalysisTarget>[
            target('surface/a.dart'),
            target('surface/linked.dart', resolved: resolved),
          ],
          fixtures,
          reported,
        ),
      ) as String;
      expect(
        outside('/private/w/outside/cast.dart', <Diagnostic>[
          at('/z/stray.dart', 1),
        ]),
        '${s}surface/linked.dart is a symbolic link to /private/w/outside/cast.dart, outside hsdd/contract/fixture/, so dart analyze does not apply the fixture analysis options',
      );
      expect(
        outside(
          '/private/w/hsdd/contract/fixture-copy/cast.dart',
          const <Diagnostic>[],
        ),
        '${s}surface/linked.dart is a symbolic link to /private/w/hsdd/contract/fixture-copy/cast.dart, outside hsdd/contract/fixture/, so dart analyze does not apply the fixture analysis options',
      );
    });
  });
}
