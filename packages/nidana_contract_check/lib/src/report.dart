/// What a replay reports (ADR-001 item 9; nidana.model D2 item 1): one line
/// per fixture, a summary line, and the exit code.
library;

import 'outcome.dart';
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

/// A set this version of the tool does not implement yet: an environment error.
final class SetUnavailable extends SetRun {
  const SetUnavailable(super.set, super.slug);
}

/// The report line of [outcome] under [set]: `PASS {set} {path}`, or
/// `FAIL {set} {path}: {rule} ({detail}); ...` with every problem in order.
String outcomeLine(CheckSet set, FixtureOutcome outcome) => switch (outcome) {
  Passed(:final String path) => 'PASS ${set.name} $path',
  Failed(:final String path, :final List<Problem> problems) =>
    'FAIL ${set.name} $path: ${problems.map(_problemText).join('; ')}',
};

/// The report line of a set this version of the tool does not implement.
String unavailableLine(SetUnavailable run) =>
    'ERROR ${run.set.name} ${run.slug}: this version of nidana_contract_check '
    'does not implement the ${run.set.name} set';

/// The summary over the outcomes of every [SetChecked] in [runs]:
/// `{n} fixtures: {passed} passed, {failed} failed`.
String summaryLine(List<SetRun> runs) {
  final List<FixtureOutcome> outcomes = _outcomesOf(runs);
  final ({int passed, int failed}) tally = _tally(outcomes);
  return '${outcomes.length} fixtures: '
      '${tally.passed} passed, ${tally.failed} failed';
}

/// The exit code of [runs]: [exitEnvironment] when any set is unavailable,
/// else [exitFailed] when any fixture fails, else [exitPassed].
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

/// Whether [outcome] makes the replay exit [exitFailed].
bool _fails(FixtureOutcome outcome) => switch (outcome) {
  Passed() => false,
  Failed() => true,
};

/// How many of [outcomes] passed and how many failed.
({int passed, int failed}) _tally(List<FixtureOutcome> outcomes) =>
    outcomes.fold(
      (passed: 0, failed: 0),
      (({int passed, int failed}) tally, FixtureOutcome outcome) =>
          switch (outcome) {
            Passed() => (passed: tally.passed + 1, failed: tally.failed),
            Failed() => (passed: tally.passed, failed: tally.failed + 1),
          },
    );
