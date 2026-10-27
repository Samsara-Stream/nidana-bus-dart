/// The `file` set's plan and outcome (ADR-001 item 6; design decisions 3, 4,
/// 6 and 12): what the set does with a slug's file replay, decided from its
/// snapshot alone, the generator's arguments once the shell has its paths,
/// and the outcome of a run. Running the generator, formatting `{output}`
/// and reading the trees are the shell's.
library;

import 'command.dart';
import 'contract.dart';
import 'outcome.dart';
import 'report.dart';
import 'request.dart';
import 'run.dart';
import 'snapshot.dart';
import 'tree.dart';

/// The path the file set names [slug]'s file replay by: `hsdd/contract/fixture/{slug}/expected/`.
String fileReplayPath(String slug) => '${fixtureDirectory(slug)}expected/';

/// What the file set does with a slug's file replay.
sealed class FilePlan {
  const FilePlan();

  /// The file replay's path from the workspace root, [fileReplayPath].
  String get path;
}

/// Decided without running: a fixture defect ([Failed]), [Passed] unrun, or [Pending].
final class FileSettled extends FilePlan {
  const FileSettled(this.outcome);

  /// The file replay's outcome.
  final FixtureOutcome outcome;

  @override
  String get path => outcome.path;
}

/// Run the generator: [arguments] are the running dart's, `{input}` and `{output}` kept;
/// [input] and [expected] are the slug's `input` and `expected` directories from the root.
final class FileRun extends FilePlan {
  const FileRun({
    required this.path,
    required this.arguments,
    required this.input,
    required this.expected,
  });

  @override
  final String path;

  /// The generator command's words after its leading `fvm dart` or `dart`, as written.
  final List<String> arguments;

  /// The slug's `input` directory from the workspace root, with no trailing slash.
  final String input;

  /// The slug's `expected` directory from the workspace root, with no trailing slash.
  final String expected;
}

/// The file replay of [snapshot] (decision 12): a defect of its command fails; a restriction
/// that does not admit the ids of its `- file:` covers clauses passes it unrun; a package the
/// command runs that [packages] lacks makes it [Pending]; otherwise it runs.
///
/// The command is the one [readGeneratorCommand] reads from the contract
/// text. A slug with no contract text, or one that is not UTF-8, has none.
/// The ids are the union of the ids of every `- file:` covers clause; a
/// malformed clause contributes none, and a `- schema:` clause is the schema
/// set's. A defect fails whether the restriction admits the replay or not,
/// so a contract gap is loud at every gate.
FilePlan planFileReplay(
  SlugSnapshot snapshot, {
  required Set<String> packages,
  required Set<GuaranteeRef>? restriction,
}) {
  final String path = fileReplayPath(snapshot.slug);
  final String contract = contractPath(snapshot.slug);
  return switch ((snapshot.contractText, snapshot.contractUndecodable)) {
    (null, final String reason) => _defect(path, '$contract: $reason'),
    (null, null) => _defect(path, 'no contract text at $contract'),
    (final String text, _) => _planCommand(
      snapshot,
      readContract(snapshot.slug, text),
      packages: packages,
      restriction: restriction,
    ),
  };
}

/// [run]'s arguments with every `{input}` and `{output}` in them replaced by [input] and [output].
///
/// The placeholders may occur anywhere in a word, as in `{input}/topics.yaml`
/// (design decision 4). Each argument is scanned once, left to right, so a
/// path given that holds `{input}` or `{output}` is not substituted again.
List<String> generatorArguments(
  FileRun run, {
  required String input,
  required String output,
}) => List<String>.unmodifiable(<String>[
  for (final String argument in run.arguments)
    argument.replaceAllMapped(
      _placeholder,
      (Match match) => match.group(0) == '{input}' ? input : output,
    ),
]);

/// The outcome of [run]: [Passed] when [generator] and [format] exited 0 and the trees are
/// equal; else [Failed] with an `exit` problem, a `format` problem, then [treeProblems], each
/// that applies, in that order.
///
/// The `exit` detail is `the generator exited {code}` and the `format`
/// detail `dart format exited {code}`, each followed by `: {line}` with the
/// [firstTextLine] of the process's stderr when there is one (design
/// decisions 5 and 6).
FixtureOutcome fileOutcome(
  FileRun run, {
  required ProcessExit generator,
  required ProcessExit format,
  required FileTree expected,
  required FileTree actual,
}) {
  final List<Problem> problems = List<Problem>.unmodifiable(<Problem>[
    if (generator.code != 0)
      Problem(
        CommandRule.exit,
        _exited('the generator exited ${generator.code}', generator),
      ),
    if (format.code != 0)
      Problem(
        CommandRule.format,
        _exited('dart format exited ${format.code}', format),
      ),
    ...treeProblems(expected, actual),
  ]);
  return problems.isEmpty ? Passed(run.path) : Failed(run.path, problems);
}

final RegExp _placeholder = RegExp(r'\{input\}|\{output\}');

/// The ids of [contract]'s `- file:` covers clauses, a malformed clause contributing none.
Set<int> _fileIds(ContractText contract) => Set<int>.unmodifiable(<int>{
  for (final CoversClause clause in contract.coversClauses)
    if (clause.bullet == 'file') ...?clause.ids,
});

/// The file replay of [snapshot] by its readable [contract]: a command it cannot read fails;
/// then [_planRun].
FilePlan _planCommand(
  SlugSnapshot snapshot,
  ContractText contract, {
  required Set<String> packages,
  required Set<GuaranteeRef>? restriction,
}) => switch (readGeneratorCommand(contract.generatorCommands)) {
  CommandUnreadable(:final String reason) => _defect(
    fileReplayPath(snapshot.slug),
    reason,
  ),
  CommandRead(:final Command command) => _planRun(
    snapshot.slug,
    command,
    _fileIds(contract),
    packages: packages,
    restriction: restriction,
  ),
};

/// The file replay of [slug]'s readable [command], whose covers clauses give [ids], in decision
/// 12's order: [Passed] unrun when [restriction] does not admit them, then [Pending] on the
/// packages [command] runs that [packages] lacks, else a [FileRun].
FilePlan _planRun(
  String slug,
  Command command,
  Set<int> ids, {
  required Set<String> packages,
  required Set<GuaranteeRef>? restriction,
}) {
  final String path = fileReplayPath(slug);
  final List<String> absent = List<String>.unmodifiable(
    commandPackages(command).difference(packages).toList()..sort(),
  );
  return switch ((admitsAll(restriction, slug, ids), absent)) {
    (false, _) => FileSettled(Passed(path, detail: notAdmitted(ids))),
    (true, [_, ...]) => FileSettled(Pending(path, absent)),
    (true, []) => FileRun(
      path: path,
      arguments: command.arguments,
      input: '${fixtureDirectory(slug)}input',
      expected: '${fixtureDirectory(slug)}expected',
    ),
  };
}

/// The [FileSettled] of a command defect at [path], told by [detail].
FileSettled _defect(String path, String detail) => FileSettled(
  Failed(
    path,
    List<Problem>.unmodifiable(<Problem>[Problem(CommandRule.command, detail)]),
  ),
);

/// [reason], then `: {line}` with the [firstTextLine] of [exit]'s stderr when there is one.
String _exited(String reason, ProcessExit exit) =>
    switch (firstTextLine(exit.stderr)) {
      final String line => '$reason: $line',
      null => reason,
    };
