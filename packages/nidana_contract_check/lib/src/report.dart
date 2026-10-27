/// What a replay reports (ADR-001 item 9; nidana.model D2 item 1): one line
/// per fixture, a summary line, and the exit code.
library;

import 'outcome.dart';
import 'packages.dart';
import 'request.dart';

/// Every fixture the replay ran passed.
const int exitPassed = 0;

/// A fixture failed or is PENDING.
const int exitFailed = 1;

/// An environment error: the replay is incomplete.
const int exitEnvironment = 2;

/// A usage error: the command line names no [Request].
const int exitUsage = 64;

/// One set run over one slug: the set [SetChecked] its fixtures, or it is
/// [SetUnavailable].
sealed class SetRun {
  const SetRun(this.set, this.slug);

  /// The set that ran.
  final CheckSet set;

  /// The slug it ran over.
  final String slug;
}

/// A set that ran and concluded [outcomes].
final class SetChecked extends SetRun {
  const SetChecked(super.set, super.slug, this.outcomes);

  /// One outcome per fixture, in the order the set reports them.
  final List<FixtureOutcome> outcomes;
}

/// A set that could not run: an environment error, with its [reason].
final class SetUnavailable extends SetRun {
  const SetUnavailable(super.set, super.slug, this.reason);

  /// Why the set could not run, for its report line.
  final String reason;
}

/// The reason of a set this version does not implement.
String notImplemented(CheckSet set) =>
    'this version of nidana_contract_check does not implement the '
    '${set.name} set';

/// The report line of [outcome] under [set]: `PASS {set} {path}`, or
/// `PASS {set} {path}: {detail}` when the outcome has a detail,
/// `FAIL {set} {path}: {rule} ({detail}); ...` with every problem in order,
/// or `PENDING {set} {path}: ...` naming every absent package.
String outcomeLine(CheckSet set, FixtureOutcome outcome) => switch (outcome) {
  Passed(:final String path, detail: null) => 'PASS ${set.name} $path',
  Passed(:final String path, :final String detail) =>
    'PASS ${set.name} $path: $detail',
  Failed(:final String path, :final List<Problem> problems) =>
    'FAIL ${set.name} $path: ${problems.map(_problemText).join('; ')}',
  Pending(:final String path, :final List<String> packages) =>
    'PENDING ${set.name} $path: ${_absenceText(packages)}',
};

/// The report line of a set that could not run: `ERROR {set} {slug}: {reason}`.
String unavailableLine(SetUnavailable run) =>
    'ERROR ${run.set.name} ${run.slug}: ${run.reason}';

/// The summary over the outcomes of every [SetChecked] in [runs]:
/// `{n} fixtures: {passed} passed, {failed} failed, {pending} pending`, with
/// `fixture` for one fixture.
///
/// Every count is printed, zero or not, so the line has one form.
String summaryLine(List<SetRun> runs) {
  final List<FixtureOutcome> outcomes = _outcomesOf(runs);
  final _Tally tally = _tally(outcomes);
  return '${outcomes.length} ${outcomes.length == 1 ? 'fixture' : 'fixtures'}: '
      '${tally.passed} passed, ${tally.failed} failed, '
      '${tally.pending} pending';
}

/// The exit code of [runs]: [exitEnvironment] when any set is unavailable,
/// else [exitFailed] when any fixture fails or is pending, else [exitPassed].
///
/// An environment error outranks a failure: the replay is then incomplete,
/// so a gate must not read its failures as the whole story.
int exitCodeOf(List<SetRun> runs) =>
    switch ((runs.any(_isUnavailable), _outcomesOf(runs).any(_fails))) {
      (true, _) => exitEnvironment,
      (false, true) => exitFailed,
      (false, false) => exitPassed,
    };

/// `{rule} ({detail})`.
String _problemText(Problem problem) =>
    '${problem.rule.label} (${problem.detail})';

/// `package {a} is absent from ...` for one package, or
/// `packages {a}, {b} are absent from ...` for more.
String _absenceText(List<String> packages) => packages.length == 1
    ? 'package ${packages.single} is absent from $packageConfigPath'
    : 'packages ${packages.join(', ')} are absent from $packageConfigPath';

/// The outcomes of every [SetChecked] in [runs], in run order.
List<FixtureOutcome> _outcomesOf(List<SetRun> runs) =>
    List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[
      for (final SetRun run in runs)
        ...switch (run) {
          SetChecked(:final List<FixtureOutcome> outcomes) => outcomes,
          SetUnavailable() => const <FixtureOutcome>[],
        },
    ]);

/// Whether [run] is an environment error.
bool _isUnavailable(SetRun run) => switch (run) {
  SetChecked() => false,
  SetUnavailable() => true,
};

/// Whether [outcome] makes the replay exit [exitFailed]: a pending fixture
/// fails the replay as a failed one does (ADR-001 item 9).
bool _fails(FixtureOutcome outcome) => switch (outcome) {
  Passed() => false,
  Failed() => true,
  Pending() => true,
};

/// How many fixtures passed, failed and are pending.
typedef _Tally = ({int passed, int failed, int pending});

/// The [_Tally] of [outcomes].
_Tally _tally(List<FixtureOutcome> outcomes) => outcomes.fold(
  (passed: 0, failed: 0, pending: 0),
  (_Tally tally, FixtureOutcome outcome) => switch (outcome) {
    Passed() => (
      passed: tally.passed + 1,
      failed: tally.failed,
      pending: tally.pending,
    ),
    Failed() => (
      passed: tally.passed,
      failed: tally.failed + 1,
      pending: tally.pending,
    ),
    Pending() => (
      passed: tally.passed,
      failed: tally.failed,
      pending: tally.pending + 1,
    ),
  },
);
