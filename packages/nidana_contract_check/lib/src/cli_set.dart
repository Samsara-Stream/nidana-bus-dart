/// The `cli` set's plans and outcomes (ADR-001 item 7; design decisions 7 to
/// 14): what the set does with each recorded invocation, decided from the
/// slug's snapshot alone, the placeholders of a recorded stream, and the
/// outcome of a case that ran. Running a case, formatting `{output}` and
/// reading what is there are the shell's.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'command.dart';
import 'contract.dart';
import 'outcome.dart';
import 'report.dart';
import 'request.dart';
import 'run.dart';
import 'snapshot.dart';
import 'tree.dart';

/// The path the cli set names a recorded invocation by: `hsdd/contract/fixture/{slug}/invocation/{name}/`.
String invocationPath(String slug, String name) =>
    '${fixtureDirectory(slug)}invocation/$name/';

/// What the cli set does with one recorded invocation.
sealed class InvocationPlan {
  const InvocationPlan();

  /// The recorded invocation's path from the workspace root, [invocationPath].
  String get path;
}

/// Decided without running: a fixture defect ([Failed]), [Passed] unrun, or [Pending].
final class InvocationSettled extends InvocationPlan {
  const InvocationSettled(this.outcome);

  /// The recorded invocation's outcome.
  final FixtureOutcome outcome;

  @override
  String get path => outcome.path;
}

/// Run the case: [command] as its `args` read it, `{output}` kept; [files] and [expected] are
/// its `files` and `expected` directories from the root, null when absent; [exitCode], [stdout]
/// and [stderr] are recorded, a stream null when not recorded.
final class InvocationRun extends InvocationPlan {
  const InvocationRun({
    required this.path,
    required this.command,
    required this.files,
    required this.expected,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  @override
  final String path;

  /// The command of the case's `args`, every argument as written.
  final Command command;

  /// The case's `files` directory from the workspace root, with no trailing slash; null when
  /// the case has none and runs from the workspace root.
  final String? files;

  /// The case's `expected` directory from the workspace root, with no trailing slash; null when
  /// the case has none and expects nothing at `{output}`.
  final String? expected;

  /// The exit code the case's `exit_code` records, 0 to 255.
  final int exitCode;

  /// The text of the case's `stdout`; null when the case records none.
  final String? stdout;

  /// The text of the case's `stderr`; null when the case records none.
  final String? stderr;

  /// Whether an argument is exactly `{output}`.
  bool get namesOutput => command.arguments.contains('{output}');
}

/// One plan per `invocation/{case}` directory of [snapshot], ascending by case name (decision 12).
///
/// Each case is planned in decision 12's order. Its fixture defects fail
/// it, every one in one [Failed], admitted by [restriction] or not, so a
/// contract gap is loud at every gate: a contract text that is absent or not
/// UTF-8, then `args`, `exit_code`, a `stdout` and a `stderr` that cannot
/// be read. Then a [restriction] that does not admit the ids its row covers
/// passes it unrun; then a package its command runs, or a plugin its
/// `files/analysis_options.yaml` enables, that [packages] lacks makes it
/// [Pending]; otherwise it is an [InvocationRun].
///
/// A case's ids are those of the first Case-table row that names it; none
/// when no row names it or that row's Covers cell is malformed, and a case
/// with none runs only unrestricted (decision 13).
List<InvocationPlan> planInvocations(
  SlugSnapshot snapshot, {
  required Set<String> packages,
  required Set<GuaranteeRef>? restriction,
}) {
  final Problem? contractDefect = _contractDefect(snapshot);
  final List<InvocationRow> rows = _caseRows(snapshot);
  return List<InvocationPlan>.unmodifiable(<InvocationPlan>[
    for (final String name in _caseNames(snapshot))
      _planCase(
        snapshot,
        name,
        contractDefect: contractDefect,
        ids: _idsOf(rows, name),
        packages: packages,
        restriction: restriction,
      ),
  ]);
}

/// A path a recorded stream names by [placeholder], in its [given] and its symlink-[resolved] form.
typedef PathForms = ({String given, String resolved, String placeholder});

/// [text] with each of [forms], in order, replaced by its placeholder, the longer of its two
/// forms first (decision 9).
///
/// Every occurrence of a form is replaced, wherever it occurs. The longer
/// form goes first because one may hold the other, as `/private/var/...`
/// holds `/var/...` on macOS, and the shorter first would leave
/// `/private{output}`. A later form is replaced only in what the earlier
/// ones left, so `{output}`, `{files}`, `{root}` is ADR-001 item 7's order:
/// `files/` lies below the root. Each form is an absolute path, never empty.
String withPlaceholders(String text, List<PathForms> forms) => forms.fold(
  text,
  (String replaced, PathForms form) => _longerFirst(form).fold(
    replaced,
    (String inner, String path) => inner.replaceAll(path, form.placeholder),
  ),
);

/// What is at `{output}` after a case ran.
sealed class OutputState {
  const OutputState();
}

/// Nothing exists at `{output}`.
final class NoOutput extends OutputState {
  const NoOutput();
}

/// An entry that is not a directory is at `{output}`: a file, a named pipe, a socket, or a link,
/// even one to a directory.
final class OutputFile extends OutputState {
  const OutputFile();
}

/// A directory is at `{output}`, read as [tree]; [format] is how `dart format` over it ended,
/// null when the case has no `expected/` and it was not formatted.
final class OutputTree extends OutputState {
  const OutputTree(this.tree, this.format);

  /// The files below `{output}`, as the shell read them.
  final FileTree tree;

  /// How `dart format {output}` ended; null when it did not run.
  final ProcessExit? format;
}

/// The outcome of [run], which ended as [exit], with [output] at `{output}` (NoOutput when it
/// names none) and [expected] its `expected/` tree (empty when it has none), the streams
/// compared after [forms]: [Passed], else [Failed] with `exit`, `stdout`, `stderr`, `format`,
/// then the output's problems, each that applies, in that order.
///
/// The `exit` detail is `exited {code}, expected {recorded}`, followed by
/// `: {line}` with the [firstTextLine] of the stderr after [forms] when the
/// case records no stderr and there is one. A recorded stream is compared
/// exactly with the process's after [forms]; one not recorded is not
/// compared. The streams are split at `\n`, and the detail names the first
/// line that differs, from 1, each side JSON-encoded or `end of output`
/// (decision 8). The `format` detail is `dart format exited {code}` with
/// the first stderr line, as the file set words it. A case without
/// `expected/` expects nothing at `{output}`; one with it expects a tree
/// there, compared by [treeProblems].
FixtureOutcome invocationOutcome(
  InvocationRun run, {
  required ProcessExit exit,
  required OutputState output,
  required FileTree expected,
  required List<PathForms> forms,
}) {
  final String stderr = withPlaceholders(exit.stderr, forms);
  final List<Problem> problems = List<Problem>.unmodifiable(<Problem>[
    if (exit.code != run.exitCode)
      Problem(CommandRule.exit, _exitDetail(run, exit.code, stderr)),
    ?_streamProblem(
      CommandRule.stdout,
      run.stdout,
      withPlaceholders(exit.stdout, forms),
    ),
    ?_streamProblem(CommandRule.stderr, run.stderr, stderr),
    ..._outputProblems(run.expected, output, expected),
  ]);
  return problems.isEmpty ? Passed(run.path) : Failed(run.path, problems);
}

/// A record of a case read: [_Read] with its value, or [_Defective] with the defect.
sealed class _Reading<T> {
  const _Reading();
}

/// The record reads as [value].
final class _Read<T> extends _Reading<T> {
  const _Read(this.value);

  /// What the record holds.
  final T value;
}

/// The record cannot be read, as [problem] tells.
final class _Defective<T> extends _Reading<T> {
  const _Defective(this.problem);

  /// The case's defect.
  final Problem problem;
}

/// A case directory directly under `invocation/`, its name in group 1.
final RegExp _caseDirectory = RegExp(r'^invocation/([^/]+)$');

/// A recorded exit code: a decimal with no leading zero, its digits in group 1, and an optional
/// final newline.
final RegExp _exitCodeText = RegExp(r'^(0|[1-9][0-9]*)\n?$');

/// The names of [snapshot]'s case directories, ascending.
List<String> _caseNames(SlugSnapshot snapshot) => List<String>.unmodifiable(
  <String>[
    for (final String directory in snapshot.directories)
      ?_caseDirectory.firstMatch(directory)?.group(1),
  ]..sort(),
);

/// The `command` problem of [snapshot]'s contract text: absent, or not UTF-8 with the reason
/// [decodeSource] gives, worded as the file set words it; null when it reads.
Problem? _contractDefect(SlugSnapshot snapshot) {
  final String contract = contractPath(snapshot.slug);
  return switch ((snapshot.contractText, snapshot.contractUndecodable)) {
    (String(), _) => null,
    (null, final String reason) => Problem(
      CommandRule.command,
      '$contract: $reason',
    ),
    (null, null) => Problem(
      CommandRule.command,
      'no contract text at $contract',
    ),
  };
}

/// The rows of [snapshot]'s Case table; none when it has no contract text.
List<InvocationRow> _caseRows(SlugSnapshot snapshot) =>
    switch (snapshot.contractText) {
      final String text => readContract(snapshot.slug, text).invocationRows,
      null => const <InvocationRow>[],
    };

/// The ids of the first of [rows] that names the case [name]; none when no row names it or its
/// Covers cell is malformed.
Set<int> _idsOf(List<InvocationRow> rows, String name) =>
    rows.where((InvocationRow row) => row.caseName == name).firstOrNull?.ids ??
    const <int>{};

/// The plan of [snapshot]'s case [name], whose row covers [ids]: its defects, [contractDefect]
/// first, fail it; else [_planRun].
InvocationPlan _planCase(
  SlugSnapshot snapshot,
  String name, {
  required Problem? contractDefect,
  required Set<int> ids,
  required Set<String> packages,
  required Set<GuaranteeRef>? restriction,
}) {
  final String path = invocationPath(snapshot.slug, name);
  List<int>? record(String file) => snapshot.records['invocation/$name/$file'];
  final _Reading<Command> command = _readCommand(record('args'));
  final _Reading<int> exitCode = _readExitCode(record('exit_code'));
  final _Reading<String?> stdout = _readStream('stdout', record('stdout'));
  final _Reading<String?> stderr = _readStream('stderr', record('stderr'));
  return switch ((contractDefect, command, exitCode, stdout, stderr)) {
    (
      null,
      _Read<Command>(value: final Command read),
      _Read<int>(value: final int code),
      _Read<String?>(value: final String? out),
      _Read<String?>(value: final String? err),
    ) =>
      _planRun(
        snapshot.slug,
        InvocationRun(
          path: path,
          command: read,
          files: _directoryOf(snapshot, name, 'files'),
          expected: _directoryOf(snapshot, name, 'expected'),
          exitCode: code,
          stdout: out,
          stderr: err,
        ),
        ids: ids,
        options: record('files/analysis_options.yaml'),
        packages: packages,
        restriction: restriction,
      ),
    _ => InvocationSettled(
      Failed(
        path,
        List<Problem>.unmodifiable(<Problem>[
          ?contractDefect,
          for (final _Reading<Object?> reading in <_Reading<Object?>>[
            command,
            exitCode,
            stdout,
            stderr,
          ])
            if (reading case _Defective<Object?>(:final Problem problem))
              problem,
        ]),
      ),
    ),
  };
}

/// [run], a case of [slug] free of defects whose row covers [ids], in decision 12's order:
/// [Passed] unrun when [restriction] does not admit [ids], then [Pending] on the packages its
/// command runs and its [options] enables that [packages] lacks, else [run] itself.
///
/// [options] are the bytes of the case's `files/analysis_options.yaml`, null
/// when it has none. Only its keys are read, so they decode leniently.
InvocationPlan _planRun(
  String slug,
  InvocationRun run, {
  required Set<int> ids,
  required List<int>? options,
  required Set<String> packages,
  required Set<GuaranteeRef>? restriction,
}) {
  final List<String> absent = List<String>.unmodifiable(
    <String>{
      ...commandPackages(run.command),
      if (options != null)
        ...pluginPackages(utf8.decode(options, allowMalformed: true)),
    }.difference(packages).toList()..sort(),
  );
  return switch ((admitsAll(restriction, slug, ids), absent)) {
    (false, _) => InvocationSettled(Passed(run.path, detail: notAdmitted(ids))),
    (true, [_, ...]) => InvocationSettled(Pending(run.path, absent)),
    (true, []) => run,
  };
}

/// The case [name]'s [directory], `files` or `expected`, from the workspace root with no
/// trailing slash; null when [snapshot] has no such directory.
String? _directoryOf(SlugSnapshot snapshot, String name, String directory) =>
    snapshot.directories.contains('invocation/$name/$directory')
    ? '${invocationPath(snapshot.slug, name)}$directory'
    : null;

/// The command of a case's `args` [bytes]: a `command` defect when they are absent, not UTF-8,
/// or name no command by [readArgs].
_Reading<Command> _readCommand(List<int>? bytes) => switch (bytes) {
  null => const _Defective<Command>(
    Problem(CommandRule.command, 'no args file'),
  ),
  final List<int> raw => switch (decodeSource(raw)) {
    SourceNotUtf8(:final String reason) => _Defective<Command>(
      Problem(CommandRule.command, 'args: $reason'),
    ),
    SourceText(:final String text) => switch (readArgs(text)) {
      CommandRead(:final Command command) => _Read<Command>(command),
      CommandUnreadable(:final String reason) => _Defective<Command>(
        Problem(CommandRule.command, reason),
      ),
    },
  },
};

/// The exit code of a case's `exit_code` [bytes] (decision 10): an `exit-code` defect when they
/// are absent, not UTF-8, or no decimal from 0 to 255 with no leading zero and an optional final
/// newline.
_Reading<int> _readExitCode(List<int>? bytes) => switch (bytes) {
  null => const _Defective<int>(
    Problem(CommandRule.exitCode, 'no exit_code file'),
  ),
  final List<int> raw => switch (decodeSource(raw)) {
    SourceNotUtf8(:final String reason) => _Defective<int>(
      Problem(CommandRule.exitCode, 'exit_code: $reason'),
    ),
    SourceText(:final String text) => switch (_exitCodeValue(text)) {
      final int code => _Read<int>(code),
      null => _Defective<int>(
        Problem(
          CommandRule.exitCode,
          'exit_code holds ${jsonEncode(text)}, expected a decimal exit code '
          'from 0 to 255 and an optional newline',
        ),
      ),
    },
  },
};

/// The exit code [text] records; null when it matches no exit code or its value exceeds 255.
int? _exitCodeValue(String text) =>
    switch (int.tryParse(_exitCodeText.firstMatch(text)?.group(1) ?? '')) {
      final int code when code <= 255 => code,
      _ => null,
    };

/// The text of a case's recorded stream [name], `stdout` or `stderr`, from its [bytes]: null
/// when it is not recorded, a `recording` defect when it is not UTF-8 (decision 8).
_Reading<String?> _readStream(String name, List<int>? bytes) => switch (bytes) {
  null => const _Read<String?>(null),
  final List<int> raw => switch (decodeSource(raw)) {
    SourceText(:final String text) => _Read<String?>(text),
    SourceNotUtf8(:final String reason) => _Defective<String?>(
      Problem(CommandRule.recording, '$name: $reason'),
    ),
  },
};

/// The two forms of [form], the longer first.
List<String> _longerFirst(PathForms form) =>
    form.resolved.length > form.given.length
    ? <String>[form.resolved, form.given]
    : <String>[form.given, form.resolved];

/// `exited {code}, expected {recorded}`, then `: {line}` with the [firstTextLine] of [stderr]
/// when [run] records no stderr and there is one.
String _exitDetail(InvocationRun run, int code, String stderr) {
  final String detail = 'exited $code, expected ${run.exitCode}';
  return switch ((run.stderr, firstTextLine(stderr))) {
    (null, final String line) => '$detail: $line',
    _ => detail,
  };
}

/// The [rule] problem of a process's stream [actual] against its [recorded] text: null when
/// [recorded] is null or they are equal, else the first line that differs.
Problem? _streamProblem(CommandRule rule, String? recorded, String actual) =>
    switch (recorded) {
      null => null,
      final String text => _lineProblem(
        rule,
        text.split('\n'),
        actual.split('\n'),
      ),
    };

/// The [rule] problem of the first line at which [expected] and [actual] differ, from 1; null
/// when they are equal.
Problem? _lineProblem(
  CommandRule rule,
  List<String> expected,
  List<String> actual,
) => switch (Iterable<int>.generate(math.max(expected.length, actual.length))
    .where((int index) => _lineAt(expected, index) != _lineAt(actual, index))
    .firstOrNull) {
  null => null,
  final int index => Problem(
    rule,
    'line ${index + 1}: expected ${_lineText(_lineAt(expected, index))}, '
    'got ${_lineText(_lineAt(actual, index))}',
  ),
};

/// The line of [lines] at [index]; null past the last.
String? _lineAt(List<String> lines, int index) =>
    index < lines.length ? lines[index] : null;

/// [line] JSON-encoded, or `end of output` for none.
String _lineText(String? line) =>
    line == null ? 'end of output' : jsonEncode(line);

/// The problems of what is at `{output}`, [output], for a case whose `expected` directory is
/// [expectedDirectory] and whose expected tree is [expected].
///
/// Without `expected/`, nothing must be there: an entry that is not a
/// directory, or a directory with the files below it ascending, is an
/// `output` problem. With it, a directory must be there: its `format`
/// problem, then [treeProblems].
List<Problem> _outputProblems(
  String? expectedDirectory,
  OutputState output,
  FileTree expected,
) => switch ((expectedDirectory, output)) {
  (null, NoOutput()) => const <Problem>[],
  (null, OutputFile()) => const <Problem>[
    Problem(
      CommandRule.output,
      '{output} is not a directory, expected nothing there',
    ),
  ],
  (null, OutputTree(:final FileTree tree, :final ProcessExit? format)) =>
    <Problem>[?_formatProblem(format), _leftAtOutput(tree)],
  (String(), NoOutput()) => const <Problem>[
    Problem(
      CommandRule.output,
      'nothing at {output}, expected the tree of expected/',
    ),
  ],
  (String(), OutputFile()) => const <Problem>[
    Problem(
      CommandRule.output,
      '{output} is not a directory, expected the tree of expected/',
    ),
  ],
  (String(), OutputTree(:final FileTree tree, :final ProcessExit? format)) =>
    <Problem>[?_formatProblem(format), ...treeProblems(expected, tree)],
};

/// The `output` problem of [tree] left at `{output}` by a case that expects nothing there.
Problem _leftAtOutput(FileTree tree) {
  const String left = '{output} exists after the run, expected nothing there';
  return Problem(
    CommandRule.output,
    tree.isEmpty ? left : '$left: ${(tree.keys.toList()..sort()).join(', ')}',
  );
}

/// The `format` problem of [format]: `dart format exited {code}`, then `: {line}` with the
/// [firstTextLine] of its stderr when there is one; null when it did not run or exited 0.
Problem? _formatProblem(ProcessExit? format) => switch (format) {
  null || (code: 0, stdout: _, stderr: _) => null,
  (:final int code, stdout: _, :final String stderr) => Problem(
    CommandRule.format,
    switch (firstTextLine(stderr)) {
      final String line => 'dart format exited $code: $line',
      null => 'dart format exited $code',
    },
  ),
};
