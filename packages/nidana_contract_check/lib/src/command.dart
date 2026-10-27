/// The commands the `file` and `cli` sets run (ADR-001 items 6 and 7), read
/// as values: the generator command of a `- file:` bullet, the command of a
/// recorded invocation's `args`, the packages a command runs, and the process
/// that runs it. Starting the process is the shell's.
///
/// [readGeneratorCommand] and [readArgs] are total. They never throw, and a
/// text that names no command is a [CommandUnreadable] with the reason, for
/// the set to report.
library;

import 'dart:convert';

import 'outcome.dart';

/// The rules of the sets that run commands, `file` and `cli`.
enum CommandRule implements Rule {
  /// The generator command, or a recorded invocation's `args`, can be read.
  command('command'),

  /// A recorded invocation's `exit_code` can be read.
  exitCode('exit-code'),

  /// A recorded invocation's `stdout` and `stderr` are UTF-8.
  recording('recording'),

  /// The process exits as expected: a generator with 0, a recorded invocation
  /// with its `exit_code`.
  exit('exit'),

  /// The process's stdout is the recorded one.
  stdout('stdout'),

  /// The process's stderr is the recorded one.
  stderr('stderr'),

  /// `dart format` reads the Dart in `{output}`.
  format('format'),

  /// Every file of the expected tree is in the tree written.
  missingFile('missing-file'),

  /// Every file of the tree written is in the expected tree.
  extraFile('extra-file'),

  /// A file in both trees has the same bytes in each.
  changedFile('changed-file'),

  /// Every entry of either tree can be read.
  unreadableFile('unreadable-file'),

  /// What is at `{output}` after the run is what the case expects there.
  output('output');

  const CommandRule(this.label);

  @override
  final String label;
}

/// How a process ended: its exit [code] and its output, decoded.
typedef ProcessExit = ({int code, String stdout, String stderr});

/// A command a file replay or a recorded invocation runs (ADR-001 items 6 and 7).
sealed class Command {
  const Command(this.arguments);

  /// The arguments after the program, each as written.
  final List<String> arguments;
}

/// `dart` [arguments]: the dart that runs the tool runs them.
final class DartCommand extends Command {
  const DartCommand(super.arguments);
}

/// `flutter` [arguments]: the flutter of the Flutter SDK that holds the running dart runs them.
final class FlutterCommand extends Command {
  const FlutterCommand(super.arguments);
}

/// `{package}:{executable}` [arguments].
final class PackageCommand extends Command {
  const PackageCommand(this.package, this.executable, super.arguments);

  /// The package that holds the executable.
  final String package;

  /// The executable, the name of a script under the package's `bin/`.
  final String executable;
}

/// A command read: [CommandRead], or [CommandUnreadable] with the reason.
sealed class CommandReading {
  const CommandReading();
}

/// The text reads as [command].
final class CommandRead extends CommandReading {
  const CommandRead(this.command);

  /// The command the text names.
  final Command command;
}

/// The text names no command, as [reason] tells.
final class CommandUnreadable extends CommandReading {
  const CommandUnreadable(this.reason);

  /// Why the text names no command, for a report line.
  final String reason;
}

/// The one generator command of [commands], [ContractText.generatorCommands]: its words after
/// a leading `fvm dart` or `dart`, as a DartCommand.
///
/// The words are the span split at spaces, empty words dropped (design
/// decision 3). No span, more than one, or one whose words do not begin with
/// `fvm dart` or `dart` is unreadable.
CommandReading readGeneratorCommand(List<String> commands) =>
    switch (commands) {
      [] => const CommandUnreadable(
        'no - file: bullet names a generator command: a backticked span that '
        'holds {output} and a space',
      ),
      [final String command] => _generatorCommand(command),
      _ => CommandUnreadable(
        '${commands.length} backticked spans of - file: bullets hold {output} '
        'and a space, expected one: ${commands.join('; ')}',
      ),
    };

/// The command of a recorded invocation's `args` [text] (decision 10).
///
/// The text is split at `\n` and one final empty line dropped; every other
/// line is one argument as written, an empty line an empty argument. The
/// first line is the command: `dart`, `flutter` or `{package}:{executable}`,
/// `{package}` matching `[a-z_][a-z0-9_]*` and `{executable}` holding no
/// space, `:` or `/`. No line, or any other first line, is unreadable.
CommandReading readArgs(String text) {
  final List<String> split = text.split('\n');
  final List<String> lines = split.last.isEmpty
      ? split.sublist(0, split.length - 1)
      : split;
  return switch (lines) {
    [] => const CommandUnreadable('args holds no command'),
    ['dart', ...final List<String> arguments] => CommandRead(
      DartCommand(List<String>.unmodifiable(arguments)),
    ),
    ['flutter', ...final List<String> arguments] => CommandRead(
      FlutterCommand(List<String>.unmodifiable(arguments)),
    ),
    [final String first, ...final List<String> arguments] =>
      switch (_packageCommand.firstMatch(first)) {
        final RegExpMatch match => CommandRead(
          PackageCommand(
            match.group(1)!,
            match.group(2)!,
            List<String>.unmodifiable(arguments),
          ),
        ),
        null => CommandUnreadable(
          'args names no command: ${jsonEncode(first)}; the command is dart, '
          'flutter or {package}:{executable}',
        ),
      },
  };
}

/// The packages [command] runs (decision 11): a PackageCommand's package; for a DartCommand
/// whose first argument is `run`, the package of the first later argument that does not start
/// with `-`, when it reads `{package}` or `{package}:{executable}`; none otherwise.
Set<String> commandPackages(Command command) =>
    Set<String>.unmodifiable(switch (command) {
      PackageCommand(:final String package) => <String>{package},
      DartCommand(arguments: ['run', ...final List<String> later]) => <String>{
        if (later
                .where((String argument) => !argument.startsWith('-'))
                .firstOrNull
            case final String target)
          ?_runTarget.firstMatch(target)?.group(1),
      },
      DartCommand() || FlutterCommand() => const <String>{},
    });

/// The plugin packages [analysisOptions] enables: the keys of its top-level `plugins:` section.
///
/// The keys are read by hand, as `package:yaml` is no dependency of the tool
/// (decision 11). `\r\n` reads as `\n`. The section is the lines after the
/// first line that is exactly `plugins:`, up to the next line that is neither
/// blank nor indented nor a comment. Its keys are the lines that match
/// `^\s+([a-z_][a-z0-9_]*)\s*:` at the indentation of the section's first
/// line that is neither blank nor a comment.
Set<String> pluginPackages(String analysisOptions) {
  final List<String> lines = analysisOptions
      .replaceAll('\r\n', '\n')
      .split('\n');
  final int start = lines.indexOf('plugins:');
  final List<String> entries = start < 0
      ? const <String>[]
      : lines
            .skip(start + 1)
            .takeWhile(
              (String line) =>
                  _isBlank(line) || _isIndented(line) || _isComment(line),
            )
            .where((String line) => !_isBlank(line) && !_isComment(line))
            .toList(growable: false);
  final int? indentation = entries.isEmpty ? null : _indentation(entries.first);
  return Set<String>.unmodifiable(<String>{
    for (final String line in entries)
      if (_indentation(line) == indentation)
        ?_pluginKey.firstMatch(line)?.group(1),
  });
}

/// [command] with each argument that is exactly `{output}` replaced by [output], its kind,
/// package and executable kept (ADR-001 item 7).
Command withOutput(Command command, String output) {
  final List<String> arguments = List<String>.unmodifiable(<String>[
    for (final String argument in command.arguments)
      argument == '{output}' ? output : argument,
  ]);
  return switch (command) {
    DartCommand() => DartCommand(arguments),
    FlutterCommand() => FlutterCommand(arguments),
    PackageCommand(:final String package, :final String executable) =>
      PackageCommand(package, executable, arguments),
  };
}

/// The executable and arguments of a process.
typedef CommandProcess = ({String executable, List<String> arguments});

/// The process that runs [command] (decision 1): [dart] with its arguments for a DartCommand;
/// [flutter] with them for a FlutterCommand; for a PackageCommand, [dart] with
/// `--packages={packageConfig}`, the file path of `bin/{executable}.dart` below the package's
/// root in [roots], then its arguments. Null for a FlutterCommand when [flutter] is null and
/// for a PackageCommand whose package [roots] lacks.
///
/// A root is a directory URI ending in `/`, as a package configuration gives
/// it. `bin/{executable}.dart` is resolved against it as two path segments,
/// so a `#`, `?` or `%` the executable holds is part of the file name.
///
/// Every root of [roots] is a `file:` URI with an empty authority whose path
/// segments, decoded, hold no `/`, as `packageRootsOf` gives one; for
/// another, such as an `http:` root, [Uri.toFilePath] throws an
/// UnsupportedError.
CommandProcess? processOf(
  Command command, {
  required String dart,
  required String? flutter,
  required String packageConfig,
  required Map<String, Uri> roots,
}) => switch (command) {
  DartCommand(:final List<String> arguments) => (
    executable: dart,
    arguments: arguments,
  ),
  FlutterCommand(:final List<String> arguments) =>
    flutter == null ? null : (executable: flutter, arguments: arguments),
  PackageCommand(
    :final String package,
    :final String executable,
    :final List<String> arguments,
  ) =>
    switch (roots[package]) {
      null => null,
      final Uri root => (
        executable: dart,
        arguments: List<String>.unmodifiable(<String>[
          '--packages=$packageConfig',
          root
              .resolveUri(
                Uri(pathSegments: <String>['bin', '$executable.dart']),
              )
              .toFilePath(),
          ...arguments,
        ]),
      ),
    },
};

const String _packageName = '[a-z_][a-z0-9_]*';
const String _executable = r'[^\s:/]+';
final RegExp _packageCommand = RegExp('^($_packageName):($_executable)\$');
final RegExp _runTarget = RegExp('^($_packageName)(?::$_executable)?\$');
final RegExp _pluginKey = RegExp(r'^\s+([a-z_][a-z0-9_]*)\s*:');
final RegExp _leadingSpace = RegExp(r'^\s');

/// The span [command] split at spaces, empty words dropped, read as a DartCommand.
CommandReading _generatorCommand(String command) {
  final List<String> words = command
      .split(' ')
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  return switch (words) {
    ['fvm', 'dart', ...final List<String> arguments] ||
    [
      'dart',
      ...final List<String> arguments,
    ] => CommandRead(DartCommand(List<String>.unmodifiable(arguments))),
    _ => CommandUnreadable(
      'the generator command does not begin with fvm dart or dart: $command',
    ),
  };
}

/// Whether [line] holds nothing but whitespace.
bool _isBlank(String line) => line.trim().isEmpty;

/// Whether [line] begins with whitespace.
bool _isIndented(String line) => _leadingSpace.hasMatch(line);

/// Whether [line] is a YAML comment, indented or not.
bool _isComment(String line) => line.trimLeft().startsWith('#');

/// The number of whitespace characters [line] begins with.
int _indentation(String line) => line.length - line.trimLeft().length;
