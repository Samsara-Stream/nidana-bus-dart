/// The one way the replay tool starts a process (design decision 18), part
/// of its imperative shell: the analysis, the `behavior` set's runners and
/// the replay's `pub get` each start theirs through [runProcess], which
/// decodes what the process prints by [lenientUtf8] and turns a process that
/// cannot start into a reason. It is one of the libraries under `lib/src/`
/// that import `dart:io`, which `test/purity_test.dart` lists.
library;

import 'dart:convert';
import 'dart:io';

import 'command.dart';

/// UTF-8 that decodes malformed bytes as U+FFFD instead of throwing: how the replay decodes the
/// output of every process it starts, so bytes that are not UTF-8 never stop a replay.
const Utf8Codec lenientUtf8 = Utf8Codec(allowMalformed: true);

/// What starting one process gave: it [Exited], or it [NotStarted].
sealed class ProcessRun {
  const ProcessRun();
}

/// The process ran to its [exit].
final class Exited extends ProcessRun {
  const Exited(this.exit);

  /// Its exit code and its output, decoded by [lenientUtf8].
  final ProcessExit exit;
}

/// The process could not start: [reason] is `could not run {executable}: {message}`.
final class NotStarted extends ProcessRun {
  const NotStarted(this.reason);

  /// Why it could not start, for a report line.
  final String reason;
}

/// Runs [executable] with [arguments] from [workingDirectory] to its exit, its output decoded by
/// [lenientUtf8]; a ProcessException becomes [NotStarted].
///
/// The arguments reach the process as given, through no shell. As
/// [Process.run] starts it, its stdin is at end of input, so a process that
/// waits for input cannot hang the replay (design decision 17).
Future<ProcessRun> runProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final ProcessResult result;
  try {
    result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      stdoutEncoding: lenientUtf8,
      stderrEncoding: lenientUtf8,
    );
  } on ProcessException catch (error) {
    return NotStarted('could not run $executable: ${error.message}');
  }
  return Exited((
    code: result.exitCode,
    stdout: result.stdout as String,
    stderr: result.stderr as String,
  ));
}
