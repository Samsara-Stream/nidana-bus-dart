// packages/nidana_contract_check/test/test_report_test.dart
import 'dart:convert';

import 'package:nidana_contract_check/src/behavior.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/test_report.dart';
import 'package:test/test.dart';

String report(List<Map<String, Object?>> events) =>
    events.map(jsonEncode).join('\n');

const Map<String, Object?> opening = <String, Object?>{
  'type': 'start',
  'protocolVersion': '0.1.1',
  'runnerVersion': '1.33.0',
  'pid': 1,
  'time': 0,
};
Map<String, Object?> started(
  int id,
  String name, {
  List<int> groups = const <int>[2],
}) => <String, Object?>{
  'type': 'testStart',
  'time': 0,
  'test': <String, Object?>{
    'id': id,
    'name': name,
    'suiteID': 0,
    'groupIDs': groups,
  },
};
Map<String, Object?> loading(int id) =>
    started(id, 'loading p_test.dart', groups: const <int>[]);
Map<String, Object?> ended(
  int id,
  String result, {
  bool skipped = false,
  bool hidden = false,
}) => <String, Object?>{
  'type': 'testDone',
  'testID': id,
  'result': result,
  'skipped': skipped,
  'hidden': hidden,
  'time': 0,
};
Map<String, Object?> failedWith(
  int id,
  String error, {
  bool isFailure = false,
}) => <String, Object?>{
  'type': 'error',
  'testID': id,
  'error': error,
  'stackTrace': '',
  'isFailure': isFailure,
  'time': 0,
};
Map<String, Object?> printed(int id, String message) => <String, Object?>{
  'type': 'print',
  'testID': id,
  'messageType': 'print',
  'message': message,
  'time': 0,
};
Map<String, Object?> finished(bool? success) => <String, Object?>{
  'type': 'done',
  'success': success,
  'time': 0,
};

/// D0: a pass, an expectation failure, an error, a skip and a case that prints.
final List<Map<String, Object?>> d0 = <Map<String, Object?>>[
  opening,
  loading(1),
  ended(1, 'success', hidden: true),
  started(3, 'G1 passes'),
  ended(3, 'success'),
  started(4, 'G2 fails'),
  failedWith(4, 'Expected: <2>\n  Actual: <1>\n', isFailure: true),
  ended(4, 'failure'),
  started(5, 'G3 throws'),
  failedWith(5, 'UnimplementedError: x'),
  ended(5, 'error'),
  started(6, 'G4 skipped'),
  ended(6, 'success', skipped: true),
  started(7, 'G5 prints'),
  printed(7, 'hello'),
  ended(7, 'success'),
  finished(false),
];

/// A report as one line: `none`, `load: {error}`, or `{passed}/{failed}/{skipped} {failing joined by |}`.
String text(TestReport r) => switch (r) {
  NoReport() => 'none',
  LoadFailed(:final String error) => 'load: $error',
  CasesRan(
    :final int passed,
    :final int failed,
    :final int skipped,
    :final List<String> failing,
  ) =>
    '$passed/$failed/$skipped ${failing.join('|')}',
};

const BindingRun dartRun = BindingRun(
  path: 'p',
  runner: Runner.dart,
  suiteSlug: 'sample',
  admitted: null,
);

/// The events of a binding that did not load, its load test failing with [error].
List<Map<String, Object?>> notLoaded(String error) => <Map<String, Object?>>[
  opening,
  loading(1),
  failedWith(1, error),
  ended(1, 'error'),
  finished(false),
];

/// [text] of the report of [events].
String read(List<Map<String, Object?>> events) =>
    text(readTestReport(report(events)));

/// The behavior line of [run] by [reported].
String line(BindingRun run, Reported reported) =>
    outcomeLine(CheckSet.behavior, ranOutcome(run, reported));

void main() {
  group('readTestReport', () {
    test(
      'counts come from visible testDone events, failures in start order',
      () {
        expect(read(d0), '2/2/1 G2 fails|G3 throws');
      },
    );
    test('a visible failed test with no group is a load failure, its detail after Failed to load', () {
      expect(
        read(
          notLoaded(
            'Failed to load "p_test.dart":\n'
            "p_test.dart:4:31: Error: Method not found: 'undefinedName'.\n"
            '  test(...);\n'
            '  ^^^',
          ),
        ),
        "load: p_test.dart:4:31: Error: Method not found: 'undefinedName'.",
      );
      expect(
        read(
          notLoaded(
            'Failed to load "p_test.dart": Bad state: a case list that fails to build',
          ),
        ),
        'load: Bad state: a case list that fails to build',
      );
      expect(read(notLoaded('boom')), 'load: boom');
    });
    test('no case ran is counted as none ran, whatever done says', () {
      expect(
        read(<Map<String, Object?>>[
          opening,
          loading(1),
          ended(1, 'success', hidden: true),
          finished(true),
        ]),
        '0/0/0 ',
      );
    });
    test('lines that are not JSON events change nothing', () {
      final List<String> lines = LineSplitter.split(report(d0)).toList();
      expect(
        text(
          readTestReport(
            <String>[
              lines.first,
              'Waiting for another flutter command to release the startup lock...',
              '--experimental-faster-testing was parsed but will be ignored.',
              '[1, 2]',
              '"text"',
              '{"no": "type"}',
              '',
              ...lines.skip(1),
            ].join('\n'),
          ),
        ),
        '2/2/1 G2 fails|G3 throws',
      );
    });
    test('no done event, or a done whose success is null, is no report', () {
      expect(text(readTestReport('')), 'none');
      expect(read(d0.sublist(0, d0.length - 1)), 'none');
      expect(
        read(<Map<String, Object?>>[
          ...d0.sublist(0, d0.length - 1),
          finished(null),
        ]),
        'none',
      );
    });
    test('the last done event decides whether the report is complete', () {
      expect(
        read(<Map<String, Object?>>[...d0, finished(null)]),
        'none',
        reason: 'a done of null after a done of false',
      );
      expect(
        read(<Map<String, Object?>>[
          ...d0.sublist(0, d0.length - 1),
          finished(null),
          finished(false),
        ]),
        '2/2/1 G2 fails|G3 throws',
        reason: 'a done of false after a done of null',
      );
    });
    test('a test with no testDone, or a hidden one, is not counted', () {
      expect(
        read(<Map<String, Object?>>[
          opening,
          loading(1),
          ended(1, 'success', hidden: true),
          started(3, 'G1 starts and never ends'),
          started(4, '(setUpAll)'),
          ended(4, 'success', hidden: true),
          started(5, 'G2 passes'),
          ended(5, 'success'),
          finished(true),
        ]),
        '1/0/0 ',
      );
    });
    test('an event whose fields have other types is skipped', () {
      expect(
        read(<Map<String, Object?>>[
          opening,
          loading(1),
          ended(1, 'success', hidden: true),
          started(3, 'G1 passes'),
          <String, Object?>{...ended(3, 'success'), 'testID': '3'},
          started(4, 'G2 fails'),
          <String, Object?>{...ended(4, 'failure'), 'hidden': 'no'},
          started(5, 'G3 is skipped'),
          <String, Object?>{...ended(5, 'success'), 'skipped': 1},
          <String, Object?>{
            ...started(6, 'G4 fails'),
            'test': <String, Object?>{
              'id': 6,
              'name': 4,
              'groupIDs': <int>[2],
            },
          },
          ended(6, 'failure'),
          started(7, 'G5 passes'),
          ended(7, 'success'),
          finished(true),
        ]),
        '1/0/0 ',
      );
      expect(
        read(<Map<String, Object?>>[
          ...d0.sublist(0, d0.length - 1),
          <String, Object?>{'type': 'done', 'success': 'yes', 'time': 0},
        ]),
        'none',
        reason: 'a done whose success is a string is no done',
      );
      expect(
        read(<Map<String, Object?>>[
          ...d0.sublist(0, d0.length - 1),
          <String, Object?>{'type': 'done', 'time': 0},
        ]),
        'none',
        reason: 'a done without success is no done',
      );
    });
    test(
      'a testDone whose result is not success, failure or error is skipped',
      () {
        expect(
          read(<Map<String, Object?>>[
            opening,
            loading(1),
            ended(1, 'success', hidden: true),
            started(3, 'G1 ends oddly'),
            ended(3, 'skipped'),
            started(4, 'G2 passes'),
            ended(4, 'success'),
            finished(true),
          ]),
          '1/0/0 ',
        );
      },
    );
    test(
      'a failed test in a group is a case failure, whatever its error says',
      () {
        expect(
          read(<Map<String, Object?>>[
            opening,
            loading(1),
            ended(1, 'success', hidden: true),
            started(3, 'G1 fails'),
            failedWith(3, 'Failed to load "p_test.dart": no'),
            ended(3, 'error'),
            finished(false),
          ]),
          '0/1/0 G1 fails',
        );
      },
    );
    test('the load error is the first error event of the first failed test with no group', () {
      expect(
        read(<Map<String, Object?>>[
          opening,
          loading(1),
          failedWith(1, 'Failed to load "p_test.dart": first'),
          failedWith(1, 'Failed to load "p_test.dart": second'),
          ended(1, 'error'),
          started(2, 'loading q_test.dart', groups: const <int>[]),
          failedWith(2, 'Failed to load "q_test.dart": third'),
          ended(2, 'failure'),
          finished(false),
        ]),
        'load: first',
      );
    });
    test(
      'the path in Failed to load ends at its first closing quote and colon',
      () {
        expect(
          read(
            notLoaded(
              'Failed to load "p_test.dart": Bad state: no case "G1": x',
            ),
          ),
          'load: Bad state: no case "G1": x',
        );
      },
    );
    test('a load failure with no error text, or only blank text, says so', () {
      expect(
        read(<Map<String, Object?>>[
          opening,
          loading(1),
          ended(1, 'error'),
          finished(false),
        ]),
        'load: no error text',
      );
      expect(
        read(notLoaded('Failed to load "p_test.dart":\n  \n')),
        'load: no error text',
      );
      expect(read(notLoaded('')), 'load: no error text');
    });
    test('a failing case list is unmodifiable', () {
      expect(
        () => (readTestReport(report(d0)) as CasesRan).failing.add('x'),
        throwsUnsupportedError,
      );
    });
  });

  group('ranOutcome', () {
    test("ranOutcome prints counts, failing names and the restriction on the binding's line", () {
      expect(
        line(
          dartRun,
          const CasesRan(
            passed: 2,
            failed: 2,
            skipped: 1,
            failing: <String>['G2 fails', 'G3 throws'],
          ),
        ),
        'FAIL behavior p: cases (2 passed, 2 failed, 1 skipped under dart test); '
        'failed-case (G2 fails); failed-case (G3 throws)',
      );
      expect(
        line(
          const BindingRun(
            path: 'p',
            runner: Runner.flutter,
            suiteSlug: 'sample',
            admitted: <int>{2},
          ),
          const CasesRan(passed: 2, failed: 0, skipped: 0, failing: <String>[]),
        ),
        'PASS behavior p: 2 passed, 0 failed, 0 skipped under flutter test --no-pub, '
        'restricted to sample G2',
      );
      expect(
        line(
          dartRun,
          const CasesRan(passed: 0, failed: 0, skipped: 2, failing: <String>[]),
        ),
        'PASS behavior p: 0 passed, 0 failed, 2 skipped under dart test',
      );
      expect(
        line(
          const BindingRun(
            path: 'p',
            runner: Runner.dart,
            suiteSlug: 'sample',
            admitted: <int>{9},
          ),
          const CasesRan(passed: 0, failed: 0, skipped: 0, failing: <String>[]),
        ),
        'FAIL behavior p: cases (no case ran under dart test, restricted to sample G9)',
      );
      expect(
        line(dartRun, const LoadFailed('x')),
        'FAIL behavior p: load (did not load under dart test: x)',
      );
    });
    test('a failing restricted run names its ids as an {ids} list; a load failure omits the restriction', () {
      const BindingRun restricted = BindingRun(
        path: 'p',
        runner: Runner.dart,
        suiteSlug: 'sample',
        admitted: <int>{7, 2, 3, 4},
      );
      expect(
        line(
          restricted,
          const CasesRan(
            passed: 1,
            failed: 1,
            skipped: 0,
            failing: <String>['G7 fails'],
          ),
        ),
        'FAIL behavior p: cases (1 passed, 1 failed, 0 skipped under dart test, '
        'restricted to sample G2 to G4, G7); failed-case (G7 fails)',
      );
      expect(
        line(restricted, const LoadFailed('x')),
        'FAIL behavior p: load (did not load under dart test: x)',
      );
    });
    test("the outcome names the binding's path", () {
      expect(
        ranOutcome(
          dartRun,
          const CasesRan(passed: 1, failed: 0, skipped: 0, failing: <String>[]),
        ).path,
        'p',
      );
    });
  });

  group('runnerFailure', () {
    test('runnerFailure names the runner, the exit code, the binding and the first line of stderr', () {
      expect(
        runnerFailure(
          const BindingRun(
            path: 'p',
            runner: Runner.flutter,
            suiteSlug: 'sample',
            admitted: null,
          ),
          3,
          '\n  boom\nmore\n',
        ),
        'flutter test --no-pub exited 3 without a JSON report for p: boom',
      );
      expect(
        runnerFailure(dartRun, 255, ''),
        'dart test exited 255 without a JSON report for p',
      );
    });
    test('a stderr of blank lines adds nothing', () {
      expect(
        runnerFailure(dartRun, 1, '  \n\t\n'),
        'dart test exited 1 without a JSON report for p',
      );
    });
  });
}
