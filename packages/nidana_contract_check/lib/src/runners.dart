/// The `behavior` set's test runners (ADR-001 item 9), part of the replay
/// tool's imperative shell: each binding the planner gives a [BindingRun]
/// runs under `dart test` or under the flutter beside the running dart, one
/// process after another, from the workspace root, and its report becomes
/// the binding's outcome. Every decision is the pure core's (`behavior.dart`
/// and `test_report.dart`); each runner starts through `processes.dart`. It
/// is one of the libraries under `lib/src/` that import `dart:io`, which
/// `test/purity_test.dart` lists.
library;

import 'dart:io';

import 'behavior.dart';
import 'outcome.dart';
import 'processes.dart';
import 'report.dart';
import 'request.dart';
import 'test_report.dart';

/// The `behavior` set over [slug]'s binding [plans], in plan order, each [BindingRun] under its
/// runner from [root]: [dart] for `dart test`, [flutter] for `flutter test --no-pub`, null when
/// the Flutter SDK of [dart] holds none. A line goes to [progress] before each runner starts.
///
/// Each run is resolved to its executable once, before any runner starts:
/// when a run needs a flutter and [flutter] is null, the set is
/// [SetUnavailable] and no binding of the slug starts (design decision 12).
/// Otherwise the bindings run one at a time; the first runner that cannot
/// start or prints no report makes the set [SetUnavailable] with its reason,
/// and no binding after it starts. Else the set is [SetChecked] with every
/// binding's outcome.
Future<SetRun> runBehavior(
  String slug,
  List<BindingPlan> plans, {
  required Directory root,
  required String dart,
  required String? flutter,
  required StringSink progress,
}) async {
  final List<_Step> steps = List<_Step>.unmodifiable(<_Step>[
    for (final BindingPlan plan in plans)
      _stepOf(plan, dart: dart, flutter: flutter),
  ]);
  return switch (steps.whereType<_Unrunnable>().firstOrNull) {
    _Unrunnable(:final BindingRun run) => SetUnavailable(
      CheckSet.behavior,
      slug,
      'no flutter in the Flutter SDK of $dart; '
      '${run.path} runs under ${run.runner.label}',
    ),
    null => await _runSteps(
      slug,
      List<_Ready>.unmodifiable(steps.whereType<_Ready>()),
      root: root,
      progress: progress,
    ),
  };
}

/// A binding's plan with its runner resolved.
sealed class _Step {
  const _Step();
}

/// A step that can be taken: [_Settled], or [_Runnable] under its executable.
sealed class _Ready extends _Step {
  const _Ready();
}

/// The binding's [outcome], settled by the planner without running.
final class _Settled extends _Ready {
  const _Settled(this.outcome);

  final FixtureOutcome outcome;
}

/// [run] under [executable], the dart or the flutter its runner starts.
final class _Runnable extends _Ready {
  const _Runnable(this.run, this.executable);

  final BindingRun run;
  final String executable;
}

/// [run] needs a flutter, and the Flutter SDK of the running dart holds none.
final class _Unrunnable extends _Step {
  const _Unrunnable(this.run);

  final BindingRun run;
}

/// What running one binding gives: its outcome, or the reason the slug's set cannot run.
sealed class _BindingResult {
  const _BindingResult();
}

/// The binding's [outcome], read from its runner's report.
final class _BindingConcluded extends _BindingResult {
  const _BindingConcluded(this.outcome);

  final FixtureOutcome outcome;
}

/// The binding's runner could not start, or printed no report: [reason].
final class _RunnerUnavailable extends _BindingResult {
  const _RunnerUnavailable(this.reason);

  final String reason;
}

/// [plan]'s step: a [BindingSettled] is [_Settled]; a [BindingRun] is [_Runnable] under the
/// executable its runner starts, [dart] or [flutter], else [_Unrunnable].
_Step _stepOf(
  BindingPlan plan, {
  required String dart,
  required String? flutter,
}) => switch (plan) {
  BindingSettled(:final FixtureOutcome outcome) => _Settled(outcome),
  final BindingRun run => switch ((run.runner, flutter)) {
    (Runner.dart, _) => _Runnable(run, dart),
    (Runner.flutter, final String beside) => _Runnable(run, beside),
    (Runner.flutter, null) => _Unrunnable(run),
  },
};

/// [steps] of [slug]'s bindings taken in order, after the [concluded] outcomes of the steps
/// before them: [SetChecked] with every outcome, or [SetUnavailable] at the first runner that
/// cannot start or prints no report, starting none after it.
Future<SetRun> _runSteps(
  String slug,
  List<_Ready> steps, {
  required Directory root,
  required StringSink progress,
  List<FixtureOutcome> concluded = const <FixtureOutcome>[],
}) async => switch (steps) {
  [] => SetChecked(
    CheckSet.behavior,
    slug,
    List<FixtureOutcome>.unmodifiable(concluded),
  ),
  [_Settled(:final FixtureOutcome outcome), ...final List<_Ready> rest] =>
    await _runSteps(
      slug,
      rest,
      root: root,
      progress: progress,
      concluded: <FixtureOutcome>[...concluded, outcome],
    ),
  [
    _Runnable(:final BindingRun run, :final String executable),
    ...final List<_Ready> rest,
  ] =>
    switch (await _started(run, executable, root: root, progress: progress)) {
      _BindingConcluded(:final FixtureOutcome outcome) => await _runSteps(
        slug,
        rest,
        root: root,
        progress: progress,
        concluded: <FixtureOutcome>[...concluded, outcome],
      ),
      _RunnerUnavailable(:final String reason) => SetUnavailable(
        CheckSet.behavior,
        slug,
        reason,
      ),
    },
};

/// [run] under [executable]: its progress line to [progress], then the runner started from
/// [root] by [runProcess] and its report read into the binding's outcome.
///
/// The runner's output is decoded by [lenientUtf8], so bytes a case writes
/// to stdout that are not UTF-8 never stop the replay; a malformed line is no
/// event, and the report reader skips it. A runner that cannot start, or
/// prints no report, makes the binding [_RunnerUnavailable].
Future<_BindingResult> _started(
  BindingRun run,
  String executable, {
  required Directory root,
  required StringSink progress,
}) async {
  progress.writeln('running behavior ${run.path} under ${run.runner.label}');
  return switch (await runProcess(
    executable,
    testArguments(run),
    workingDirectory: root.path,
  )) {
    NotStarted(:final String reason) => _RunnerUnavailable(reason),
    Exited(
      exit: (:final int code, :final String stdout, :final String stderr),
    ) =>
      switch (readTestReport(stdout)) {
        NoReport() => _RunnerUnavailable(runnerFailure(run, code, stderr)),
        final Reported report => _BindingConcluded(ranOutcome(run, report)),
      },
  };
}
