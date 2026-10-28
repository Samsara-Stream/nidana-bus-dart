import 'package:nidana_contract_check/src/analysis.dart';
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/reject.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/surface.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String closed =
    "The class 'Sample' can't be extended outside of its library because it's a final class.";
const Set<String> withSample = <String>{'sample'};

/// A diagnostic reported in the fixture at [path].
Diagnostic reportedAt(
  String path,
  int line,
  String severity,
  String code,
  String message,
) => Diagnostic(
  file: '/w/$path',
  line: line,
  severity: severity,
  code: code,
  message: message,
);

/// What dart analyze reported for [analysisFiles] under the stand-in package (experiment A11).
final Map<String, List<Diagnostic>> reported = <String, List<Diagnostic>>{
  '${s}reject/assigns_final.dart': <Diagnostic>[
    reportedAt(
      '${s}reject/assigns_final.dart',
      6,
      'ERROR',
      'assignment_to_final',
      "'count' can't be used as a setter because it's final.",
    ),
  ],
  '${s}reject/extra_warning.dart': <Diagnostic>[
    reportedAt(
      '${s}reject/extra_warning.dart',
      5,
      'ERROR',
      'invalid_use_of_type_outside_library',
      closed,
    ),
    reportedAt(
      '${s}reject/extra_warning.dart',
      8,
      'WARNING',
      'unused_local_variable',
      "The value of the local variable 'unused' isn't used.",
    ),
  ],
  '${s}reject/sample_is_closed.dart': <Diagnostic>[
    reportedAt(
      '${s}reject/sample_is_closed.dart',
      6,
      'ERROR',
      'invalid_use_of_type_outside_library',
      closed,
    ),
  ],
  '${s}reject/wrong_code.dart': <Diagnostic>[
    reportedAt(
      '${s}reject/wrong_code.dart',
      5,
      'ERROR',
      'invalid_use_of_type_outside_library',
      closed,
    ),
  ],
  '${s}reject/wrong_line.dart': <Diagnostic>[
    reportedAt(
      '${s}reject/wrong_line.dart',
      6,
      'ERROR',
      'invalid_use_of_type_outside_library',
      closed,
    ),
  ],
  '${s}surface/dirty.dart': <Diagnostic>[
    reportedAt(
      '${s}surface/dirty.dart',
      1,
      'WARNING',
      'unused_import',
      "Unused import: 'dart:async'.",
    ),
  ],
};

SlugSnapshot snapshotWith(Map<String, String?> changes) =>
    snapshotOf('sample', changed(analysisFiles, changes));

List<String> surfaceLines(
  SlugSnapshot snapshot,
  Map<String, List<Diagnostic>> diagnostics, {
  Set<String> packages = withSample,
}) => checkSurface(
  snapshot,
  packages: packages,
  diagnostics: diagnostics,
).map((FixtureOutcome o) => outcomeLine(CheckSet.surface, o)).toList();

List<String> rejectLines(
  SlugSnapshot snapshot,
  Map<String, List<Diagnostic>> diagnostics, {
  Set<String> packages = withSample,
}) => checkReject(
  snapshot,
  packages: packages,
  diagnostics: diagnostics,
).map((FixtureOutcome o) => outcomeLine(CheckSet.reject, o)).toList();

void main() {
  group('the surface set', () {
    test('one outcome per library by path: clean passes, a diagnostic fails, an absent package is pending', () {
      expect(surfaceLines(snapshotWith(const <String, String?>{}), reported), <
        String
      >[
        "FAIL surface ${s}surface/dirty.dart: diagnostic (line 1: WARNING unused_import: Unused import: 'dart:async'.)",
        'PENDING surface ${s}surface/pending.dart: package producer is absent from .dart_tool/package_config.json',
        'PASS surface ${s}surface/use.dart',
      ]);
    });
    test('a diagnostic at any severity fails, listed by line', () {
      expect(
        surfaceLines(
          snapshotWith(const <String, String?>{}),
          <String, List<Diagnostic>>{
            '${s}surface/use.dart': <Diagnostic>[
              reportedAt(
                '${s}surface/use.dart',
                3,
                'INFO',
                'deprecated_member_use',
                "'old' is deprecated and shouldn't be used.",
              ),
              reportedAt(
                '${s}surface/use.dart',
                1,
                'ERROR',
                'uri_does_not_exist',
                "Target of URI doesn't exist: 'package:sample/gone.dart'.",
              ),
            ],
          },
        ).last,
        "FAIL surface ${s}surface/use.dart: diagnostic (line 1: ERROR uri_does_not_exist: Target of URI doesn't exist: 'package:sample/gone.dart'.); diagnostic (line 3: INFO deprecated_member_use: 'old' is deprecated and shouldn't be used.)",
      );
    });
    test('a library nested below surface/ is a surface library', () {
      expect(
        surfaceLines(
          snapshotWith(<String, String?>{
            '${s}surface/more/extra.dart': "import 'package:sample/sample.dart';\n\nSample extra() => Sample();\n",
          }),
          const <String, List<Diagnostic>>{},
        ),
        contains('PASS surface ${s}surface/more/extra.dart'),
      );
    });
    test('diagnostics on one line are listed by code, then message', () {
      const String path = '${s}surface/use.dart';
      expect(
        surfaceLines(
          snapshotWith(const <String, String?>{}),
          <String, List<Diagnostic>>{
            path: <Diagnostic>[
              reportedAt(path, 3, 'WARNING', 'b_code', 'x.'),
              reportedAt(path, 3, 'INFO', 'a_code', 'z.'),
              reportedAt(path, 3, 'INFO', 'a_code', 'y.'),
            ],
          },
        ).last,
        'FAIL surface $path: diagnostic (line 3: INFO a_code: y.); diagnostic (line 3: INFO a_code: z.); diagnostic (line 3: WARNING b_code: x.)',
      );
    });
    test('a library that names no package is judged, never pending, though no package is configured', () {
      const String path = '${s}surface/core.dart';
      final SlugSnapshot snapshot = snapshotWith(<String, String?>{
        path: "import 'dart:async';\n\nFuture<void> wait() async {}\n",
      });
      expect(
        surfaceLines(
          snapshot,
          const <String, List<Diagnostic>>{},
          packages: const <String>{},
        ),
        <String>[
          'PASS surface $path',
          'PENDING surface ${s}surface/dirty.dart: package sample is absent from .dart_tool/package_config.json',
          'PENDING surface ${s}surface/pending.dart: package producer is absent from .dart_tool/package_config.json',
          'PENDING surface ${s}surface/use.dart: package sample is absent from .dart_tool/package_config.json',
        ],
      );
      expect(
        surfaceLines(snapshot, <String, List<Diagnostic>>{
          path: <Diagnostic>[
            reportedAt(path, 1, 'WARNING', 'unused_import', 'm.'),
          ],
        }, packages: const <String>{}).first,
        'FAIL surface $path: diagnostic (line 1: WARNING unused_import: m.)',
      );
    });
  });
  group('the reject set', () {
    test('the reported (line, code) pairs against the pairs the markers name', () {
      expect(rejectLines(snapshotWith(const <String, String?>{}), reported), <
        String
      >[
        'PASS reject ${s}reject/assigns_final.dart',
        "FAIL reject ${s}reject/extra_warning.dart: unexpected-diagnostic (line 8: WARNING unused_local_variable: The value of the local variable 'unused' isn't used.)",
        'PASS reject ${s}reject/sample_is_closed.dart',
        'FAIL reject ${s}reject/wrong_code.dart: missing-diagnostic (line 5: undefined_class, named by the marker on line 4, not reported); unexpected-diagnostic (line 5: ERROR invalid_use_of_type_outside_library: $closed)',
        'FAIL reject ${s}reject/wrong_line.dart: missing-diagnostic (line 5: invalid_use_of_type_outside_library, named by the marker on line 4, not reported); unexpected-diagnostic (line 6: ERROR invalid_use_of_type_outside_library: $closed)',
      ]);
    });
    test('the pairs form a set: the marked code twice on its line passes, once more on another line fails', () {
      const String path = '${s}reject/sample_is_closed.dart';
      Diagnostic onLine(int line) => reportedAt(
        path,
        line,
        'ERROR',
        'invalid_use_of_type_outside_library',
        closed,
      );
      expect(
        rejectLines(
          snapshotWith(const <String, String?>{}),
          <String, List<Diagnostic>>{
            path: <Diagnostic>[onLine(6), onLine(6)],
          },
        ),
        contains('PASS reject $path'),
      );
      expect(
        rejectLines(
          snapshotWith(const <String, String?>{}),
          <String, List<Diagnostic>>{
            path: <Diagnostic>[onLine(6), onLine(3)],
          },
        ),
        contains(
          'FAIL reject $path: unexpected-diagnostic (line 3: ERROR invalid_use_of_type_outside_library: $closed)',
        ),
      );
    });
    test('a marked diagnostic that is not reported', () {
      expect(
        rejectLines(
          snapshotWith(const <String, String?>{}),
          const <String, List<Diagnostic>>{},
        ),
        contains(
          'FAIL reject ${s}reject/sample_is_closed.dart: missing-diagnostic (line 6: invalid_use_of_type_outside_library, named by the marker on line 5, not reported)',
        ),
      );
    });
    test('a library without a marker fails, with or without diagnostics; a malformed marker names nothing', () {
      const String path = '${s}reject/no_marker.dart';
      final SlugSnapshot snapshot = snapshotWith(<String, String?>{
        path: "// covers: G1\nimport 'package:sample/sample.dart';\n\n// expect-diagnostic: Bad_Code\nfinal class Local extends Sample {}\n",
      });
      expect(
        rejectLines(snapshot, const <String, List<Diagnostic>>{}),
        contains('FAIL reject $path: marker (no // expect-diagnostic: marker)'),
      );
      expect(
        rejectLines(snapshot, <String, List<Diagnostic>>{
          path: <Diagnostic>[
            reportedAt(
              path,
              5,
              'ERROR',
              'invalid_use_of_type_outside_library',
              closed,
            ),
          ],
        }),
        contains(
          'FAIL reject $path: marker (no // expect-diagnostic: marker); unexpected-diagnostic (line 5: ERROR invalid_use_of_type_outside_library: $closed)',
        ),
      );
    });
    test('a library that imports an absent package is pending, whatever is reported', () {
      final List<String> lines = rejectLines(
        snapshotWith(const <String, String?>{}),
        reported,
        packages: const <String>{},
      );
      expect(lines, hasLength(5));
      expect(lines, everyElement(startsWith('PENDING reject ')));
      expect(
        lines.first,
        'PENDING reject ${s}reject/assigns_final.dart: package sample is absent from .dart_tool/package_config.json',
      );
    });
    test('every severity: an INFO diagnostic is compared as an ERROR is', () {
      const String path = '${s}reject/sample_is_closed.dart';
      Diagnostic info(int line, String code) =>
          reportedAt(path, line, 'INFO', code, 'm.');
      expect(
        rejectLines(
          snapshotWith(<String, String?>{
            path: "// covers: G1\nimport 'package:sample/sample.dart';\n\n// expect-diagnostic: deprecated_member_use\nfinal Object old = Sample();\n",
          }),
          <String, List<Diagnostic>>{
            path: <Diagnostic>[info(5, 'deprecated_member_use')],
          },
        ),
        contains('PASS reject $path'),
      );
      expect(
        rejectLines(
          snapshotWith(const <String, String?>{}),
          <String, List<Diagnostic>>{
            path: <Diagnostic>[
              reportedAt(
                path,
                6,
                'ERROR',
                'invalid_use_of_type_outside_library',
                closed,
              ),
              info(2, 'unnecessary_import'),
            ],
          },
        ),
        contains(
          'FAIL reject $path: unexpected-diagnostic (line 2: INFO unnecessary_import: m.)',
        ),
      );
    });
    test('problems run line by line: on each line the missing pair, then the unexpected ones by code', () {
      const String path = '${s}reject/order.dart';
      final SlugSnapshot snapshot = snapshotWith(<String, String?>{
        path:
            "// covers: G1\nimport 'package:sample/sample.dart';\n\n"
            '// expect-diagnostic: z_code\nfinal int a = 0;\n'
            'final int b = 0;\n'
            '// expect-diagnostic: a_code\nfinal int c = 0;\n',
      });
      Diagnostic at(int line, String code) =>
          reportedAt(path, line, 'ERROR', code, '$code.');
      expect(
        rejectLines(snapshot, <String, List<Diagnostic>>{
          path: <Diagnostic>[
            at(8, 'c_code'),
            at(6, 'y_code'),
            at(5, 'z_code'),
            at(3, 'x_code'),
            at(6, 'b_code'),
          ],
        }),
        contains(
          'FAIL reject $path: '
          'unexpected-diagnostic (line 3: ERROR x_code: x_code.); '
          'unexpected-diagnostic (line 6: ERROR b_code: b_code.); '
          'unexpected-diagnostic (line 6: ERROR y_code: y_code.); '
          'missing-diagnostic (line 8: a_code, named by the marker on line 7, not reported); '
          'unexpected-diagnostic (line 8: ERROR c_code: c_code.)',
        ),
      );
    });
    test('an unexpected pair reported twice is one problem, told by the first diagnostic that gives it', () {
      const String path = '${s}reject/sample_is_closed.dart';
      expect(
        rejectLines(
          snapshotWith(const <String, String?>{}),
          <String, List<Diagnostic>>{
            path: <Diagnostic>[
              reportedAt(path, 3, 'WARNING', 'x_code', 'first.'),
              reportedAt(
                path,
                6,
                'ERROR',
                'invalid_use_of_type_outside_library',
                closed,
              ),
              reportedAt(path, 3, 'ERROR', 'x_code', 'second.'),
            ],
          },
        ),
        contains(
          'FAIL reject $path: unexpected-diagnostic (line 3: WARNING x_code: first.)',
        ),
      );
    });
    test('a library that names no package is judged, never pending, though no package is configured', () {
      const String path = '${s}reject/core.dart';
      final SlugSnapshot snapshot = snapshotWith(<String, String?>{
        path: "// covers: G1\n// expect-diagnostic: unused_import\nimport 'dart:async';\n",
      });
      expect(
        rejectLines(snapshot, <String, List<Diagnostic>>{
          path: <Diagnostic>[
            reportedAt(path, 3, 'WARNING', 'unused_import', 'm.'),
          ],
        }, packages: const <String>{}),
        contains('PASS reject $path'),
      );
      expect(
        rejectLines(
          snapshot,
          const <String, List<Diagnostic>>{},
          packages: const <String>{},
        ),
        contains(
          'FAIL reject $path: missing-diagnostic (line 3: unused_import, named by the marker on line 2, not reported)',
        ),
      );
    });
  });
}
