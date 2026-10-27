/// What the `behavior` set reads of a binding's run (ADR-001 item 9): the
/// report a runner prints with `--reporter json`, read, and the binding's
/// outcome by it.
///
/// The report is package:test's JSON reporter protocol, version 0.1.1,
/// which `flutter test` also prints: one JSON object per line, each with a
/// string `type`. A suite's load is a test of its own, `loading {path}`,
/// outside every group, hidden when the load succeeds and a visible failure
/// when it does not; every case sits in a group.
///
/// Pure: the shell starts the runner and hands this library its stdout;
/// nothing here reads a file or starts a process.
library;

import 'dart:convert';

import 'behavior.dart';
import 'ids.dart';
import 'outcome.dart';

/// What a runner printed with `--reporter json`, read.
sealed class TestReport {
  const TestReport();
}

/// The output holds no complete report: no `done` event, or one whose `success` is null.
final class NoReport extends TestReport {
  const NoReport();
}

/// A complete report: the cases ran, or the binding did not load.
sealed class Reported extends TestReport {
  const Reported();
}

/// The binding loaded and its visible tests ended: [passed], [failed] and [skipped] count them.
final class CasesRan extends Reported {
  const CasesRan({
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.failing,
  });

  /// The tests that succeeded and were not skipped.
  final int passed;

  /// The tests whose result is `failure` or `error`.
  final int failed;

  /// The tests that were skipped.
  final int skipped;

  /// The names of the failed cases, in the order they started.
  final List<String> failing;
}

/// The binding did not load.
final class LoadFailed extends Reported {
  const LoadFailed(this.error);

  /// The first non-blank text of the load error after `Failed to load "{path}":`.
  final String error;
}

/// The report in [stdout], what a runner printed with `--reporter json`.
///
/// Each line that decodes to a JSON object with a string `type` is an event;
/// every other line, and an event whose fields have other types, is skipped.
/// The last `done` event decides whether the report is complete. A test
/// counts once its `testDone` is visible (`hidden` false). The first visible
/// failed test with no group is the load, and gives [LoadFailed]; otherwise
/// the visible tests give [CasesRan], which may count none.
TestReport readTestReport(String stdout) {
  final List<_Event> events = List<_Event>.unmodifiable(
    LineSplitter.split(stdout).map(_eventOf).nonNulls,
  );
  return switch (events.whereType<_Done>().lastOrNull) {
    _Done(success: bool()) => _reported(events),
    _Done(success: null) || null => const NoReport(),
  };
}

/// `{runner} exited {exitCode} without a JSON report for {path}`, then `: {line}` with the first
/// line of [stderr] that is not blank, trimmed, when there is one.
String runnerFailure(BindingRun run, int exitCode, String stderr) {
  final String reason =
      '${run.runner.label} exited $exitCode without a JSON report for ${run.path}';
  return switch (_firstText(LineSplitter.split(stderr))) {
    final String first => '$reason: $first',
    null => reason,
  };
}

/// The outcome of [run] by [report].
///
/// A load failure is a `load` problem. A run in which no case ran is a
/// `cases` problem, whatever `done` says: a filter that admits no case name
/// ends with a `done` whose `success` is true. A run with no failure passes,
/// its counts the line's detail;
/// otherwise a `cases` problem holds the counts and one `failed-case` problem
/// names each failing case, in order. Every count prints, zero or not, and a
/// restricted run names its restriction after the runner.
FixtureOutcome ranOutcome(BindingRun run, Reported report) {
  final String runner = run.runner.label;
  final String restriction = switch (run.admitted) {
    final Set<int> admitted =>
      ', restricted to ${run.suiteSlug} ${formatIds(admitted)}',
    null => '',
  };
  return switch (report) {
    LoadFailed(:final String error) => _failed(run.path, <Problem>[
      Problem(BehaviorRule.load, 'did not load under $runner: $error'),
    ]),
    CasesRan(passed: 0, failed: 0, skipped: 0) => _failed(run.path, <Problem>[
      Problem(BehaviorRule.cases, 'no case ran under $runner$restriction'),
    ]),
    CasesRan(:final int passed, failed: 0, :final int skipped) => Passed(
      run.path,
      detail:
          '$passed passed, 0 failed, $skipped skipped under $runner$restriction',
    ),
    CasesRan(
      :final int passed,
      :final int failed,
      :final int skipped,
      :final List<String> failing,
    ) =>
      _failed(run.path, <Problem>[
        Problem(
          BehaviorRule.cases,
          '$passed passed, $failed failed, $skipped skipped '
          'under $runner$restriction',
        ),
        for (final String name in failing)
          Problem(BehaviorRule.failedCase, name),
      ]),
  };
}

/// The detail of a load failure that reports no error, or no text after `Failed to load "{path}":`.
const String _noErrorText = 'no error text';

/// The start of a load error, up to the colon after its path's closing quote; `^` anchors it at
/// the start of the error's text, and `.` keeps it on the first line.
final RegExp _failedToLoad = RegExp(r'^Failed to load ".*?":');

/// How a test ended, by its `testDone`.
enum _Result { passed, failed, skipped }

/// One event of the report that the reader reads.
sealed class _Event {
  const _Event();
}

/// A `testStart`: test [id] named [name] started, [grouped] when it sits in a group.
final class _Started extends _Event {
  const _Started(this.id, this.name, {required this.grouped});

  final int id;
  final String name;
  final bool grouped;
}

/// A `testDone`: test [id] ended with [result], [hidden] when the runner hides it, as it hides
/// a load that succeeds.
final class _Ended extends _Event {
  const _Ended(this.id, this.result, {required this.hidden});

  final int id;
  final _Result result;
  final bool hidden;
}

/// An `error`: test [id] reported [text].
final class _Errored extends _Event {
  const _Errored(this.id, this.text);

  final int id;
  final String text;
}

/// A `done`: the run ended, its [success] null when the runner closed early.
final class _Done extends _Event {
  const _Done(this.success);

  final bool? success;
}

/// A visible test: how it started, and how it ended.
typedef _Visible = ({_Started start, _Result result});

/// The event [line] holds; null when it holds none the reader reads.
_Event? _eventOf(String line) => switch (_decoded(line)) {
  {
    'type': 'testStart',
    'test': {
      'id': final int id,
      'name': final String name,
      'groupIDs': final List<Object?> groups,
    },
  } =>
    _Started(id, name, grouped: groups.isNotEmpty),
  {
    'type': 'testDone',
    'testID': final int id,
    'result': final String result,
    'skipped': final bool skipped,
    'hidden': final bool hidden,
  } =>
    switch (_resultOf(result, skipped: skipped)) {
      final _Result ending => _Ended(id, ending, hidden: hidden),
      null => null,
    },
  {'type': 'error', 'testID': final int id, 'error': final String text} =>
    _Errored(id, text),
  {'type': 'done', 'success': final bool? success} => _Done(success),
  _ => null,
};

/// [line] decoded as JSON; null when it is not JSON.
Object? _decoded(String line) {
  try {
    return jsonDecode(line);
  } on FormatException {
    return null;
  }
}

/// How a test whose `testDone` reports [result] and [skipped] ended; null for another result.
_Result? _resultOf(String result, {required bool skipped}) =>
    switch ((skipped, result)) {
      (true, _) => _Result.skipped,
      (false, 'success') => _Result.passed,
      (false, 'failure' || 'error') => _Result.failed,
      (false, _) => null,
    };

/// The complete report of [events]: the load's failure, else the counts of the visible tests.
Reported _reported(List<_Event> events) {
  final Map<int, _Ended> ends = Map<int, _Ended>.unmodifiable(<int, _Ended>{
    for (final _Ended end in events.whereType<_Ended>()) end.id: end,
  });
  final List<_Visible> visible = List<_Visible>.unmodifiable(<_Visible>[
    for (final _Started start in events.whereType<_Started>())
      if (ends[start.id] case _Ended(hidden: false, :final _Result result))
        (start: start, result: result),
  ]);
  return switch (visible.where(_failedLoad).firstOrNull) {
    final _Visible load => LoadFailed(
      _loadError(_firstError(events, load.start.id)),
    ),
    null => _casesRan(visible),
  };
}

/// Whether [test] is a load that failed: a failed test outside every group.
bool _failedLoad(_Visible test) =>
    !test.start.grouped && test.result == _Result.failed;

/// The text of the first `error` event of test [id] in [events]; empty when there is none.
String _firstError(List<_Event> events, int id) =>
    events
        .whereType<_Errored>()
        .where((_Errored error) => error.id == id)
        .firstOrNull
        ?.text ??
    '';

/// The detail of a load failure by its first error's [text]: the first non-blank text after
/// `Failed to load "{path}":` when [text] begins so, else of the whole [text].
String _loadError(String text) =>
    _firstText(LineSplitter.split(text.replaceFirst(_failedToLoad, ''))) ??
    _noErrorText;

/// The counts of [visible] and the names of its failed tests, in start order.
CasesRan _casesRan(List<_Visible> visible) {
  int count(_Result result) =>
      visible.where((_Visible test) => test.result == result).length;
  return CasesRan(
    passed: count(_Result.passed),
    failed: count(_Result.failed),
    skipped: count(_Result.skipped),
    failing: List<String>.unmodifiable(<String>[
      for (final _Visible test in visible)
        if (test.result == _Result.failed) test.start.name,
    ]),
  );
}

/// The first of [lines] that is not blank, trimmed; null when every one is blank.
String? _firstText(Iterable<String> lines) => lines
    .map((String line) => line.trim())
    .where((String line) => line.isNotEmpty)
    .firstOrNull;

/// The [Failed] of the binding at [path] with [problems].
Failed _failed(String path, List<Problem> problems) =>
    Failed(path, List<Problem>.unmodifiable(problems));
