/// The runs of the sets that run commands (ADR-001 items 6 and 7; design
/// decisions 1, 4 to 9 and 16), part of the replay tool's imperative shell:
/// the `file` set's generator started into a fresh `{output}`, each of the
/// `cli` set's recorded invocations started from its `files/` or the root
/// with a fresh `{output}`, `dart format` over `{output}`, and the trees
/// read, hidden entries included. Every decision is the pure core's
/// (`file_set.dart`, `cli_set.dart`, `command.dart` and `tree.dart`); each
/// process starts through `processes.dart`. It is one of the libraries under
/// `lib/src/` that import `dart:io`, which `test/purity_test.dart` lists.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'cli_set.dart';
import 'command.dart';
import 'file_set.dart';
import 'outcome.dart';
import 'packages.dart';
import 'processes.dart';
import 'report.dart';
import 'request.dart';
import 'tree.dart';
import 'workspace.dart';

/// The files below [directory], hidden ones included, each read as bytes by its `/`-separated
/// path relative to it; a symbolic link is read through. The empty tree when [directory] is no
/// directory. Never throws: an entry it cannot read is a [FileUnreadable] (design decision 7).
///
/// A link to a file is that file's bytes, and a link to a directory holds the
/// files below it; [directory] itself may be a link. An entry that cannot be
/// read keeps its path, its reason one line: a dangling link, a link cycle
/// (links that resolve to each other, or a link to a directory the walk is
/// inside), a file that cannot be opened, a named pipe, a socket or a device,
/// which is never opened, and a directory that cannot be listed, [directory]
/// itself under the path `.`. A directory that can be listed is no entry: the
/// files below it are.
FileTree readTree(Directory directory) =>
    Map<String, FileEntry>.unmodifiable(switch (_typeOf(directory.path)) {
      FileSystemEntityType.directory => switch (_attempt(
        directory.resolveSymbolicLinksSync,
      )) {
        _Done(value: final String resolved) => _below(
          directory.path,
          key: '',
          descent: <String>{resolved},
          resolved: resolved,
        ),
        _Refused(:final String reason) => <String, FileEntry>{
          '.': FileUnreadable(reason),
        },
      },
      _ => const <String, FileEntry>{},
    });

/// The file set over [slug]'s [plan]: [SetChecked] with its one outcome, the run's from the
/// generator started by [dart] from [root] into a fresh `{t}/output`, `{dart} format {output}`
/// and the two trees, `{t}` deleted after; [SetUnavailable] when a process cannot start. A line
/// `running file {path}` goes to [progress] before the generator starts.
///
/// A [FileSettled] plan starts no process. For a [FileRun], `{t}` is a fresh
/// temporary directory and `{output}` its `output` subdirectory, created
/// empty; `{input}` is the slug's `input` directory under [root]. Both
/// processes start from [root], and the generator's output is not printed:
/// [fileOutcome] judges its exit code, the format's, the slug's `expected`
/// tree and the tree at `{output}`, each read by [readTree]. The deletion of
/// `{t}` is as far as it can go: a tree the generator left that cannot be
/// deleted stays in the system temporary directory, a line `could not delete
/// {t}: {reason}` goes to [progress], and the outcome stands.
Future<SetRun> runFileSet(
  String slug,
  FilePlan plan, {
  required Directory root,
  required String dart,
  required StringSink progress,
}) async => switch (plan) {
  FileSettled(:final FixtureOutcome outcome) => _fileChecked(slug, outcome),
  final FileRun run => await _runGenerator(
    slug,
    run,
    root: root,
    dart: dart,
    progress: progress,
  ),
};

/// [run] of [slug]'s file replay in a fresh `{t}`, deleted after as far as it can be.
Future<SetRun> _runGenerator(
  String slug,
  FileRun run, {
  required Directory root,
  required String dart,
  required StringSink progress,
}) async {
  final Directory temporary = Directory.systemTemp.createTempSync('ncc_file_');
  try {
    final Directory output = Directory(p.join(temporary.path, 'output'))
      ..createSync();
    progress.writeln('running file ${run.path}');
    return switch (await runProcess(
      dart,
      generatorArguments(
        run,
        input: workspacePath(root, run.input),
        output: output.path,
      ),
      workingDirectory: root.path,
    )) {
      NotStarted(:final String reason) => SetUnavailable(
        CheckSet.file,
        slug,
        reason,
      ),
      Exited(exit: final ProcessExit generator) => switch (await runProcess(
        dart,
        <String>['format', output.path],
        workingDirectory: root.path,
      )) {
        NotStarted(:final String reason) => SetUnavailable(
          CheckSet.file,
          slug,
          reason,
        ),
        Exited(exit: final ProcessExit format) => _fileChecked(
          slug,
          fileOutcome(
            run,
            generator: generator,
            format: format,
            expected: readTree(Directory(workspacePath(root, run.expected))),
            actual: readTree(output),
          ),
        ),
      },
    };
  } finally {
    _deleteTemporary(temporary, progress);
  }
}

/// The file set of [slug], checked with its one [outcome].
SetChecked _fileChecked(String slug, FixtureOutcome outcome) => SetChecked(
  CheckSet.file,
  slug,
  List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[outcome]),
);

/// The cli set over [slug]'s [plans], in order. Each run is resolved to its process first by
/// [processOf] with [dart], [flutter], the package configuration under [root] and [roots]; the
/// first that cannot be makes the set [SetUnavailable] with `no flutter in the Flutter SDK of
/// {dart}; {path} runs flutter`, and no case of the slug starts. Otherwise each run gets a
/// fresh `{t}`, its `{output}` arguments become `{t}/output`, it starts from its `files/` or
/// [root] after a line `running cli {path}` to [progress], `{output}` is read (formatted first
/// when the case has `expected/`), and [invocationOutcome] judges it with the placeholders of
/// `{output}`, its `files/` and [root]; `{t}` is deleted after. A process that cannot start
/// makes the set [SetUnavailable] with its reason, starting no case after it.
///
/// An [InvocationSettled] plan starts no process. A `{package}:{executable}`
/// run whose package [roots] lacks, which the planner makes PENDING before
/// it gets here, has no process either; its reason is `package {package} is
/// absent from .dart_tool/package_config.json; {path} runs
/// {package}:{executable}`.
///
/// `{t}` is a fresh temporary directory, and nothing exists at `{output}`
/// when the run starts. The placeholders are resolved before the run, in
/// ADR-001 item 7's order (design decision 9): `{output}`, given as the
/// argument and resolved as `{t}` resolved and `output`, since nothing may be
/// there after the run; `{files}`, only for a case with `files/`; `{root}`.
/// After the run, a directory at `{output}` is an [OutputTree] read by
/// [readTree], a file or a link an [OutputFile], and nothing a [NoOutput];
/// `{dart} format {output}` runs from [root] only over a directory and only
/// for a case with `expected/`, whose tree [readTree] reads after the run.
/// The process's output is not printed: [invocationOutcome] compares it. A
/// `{t}` that cannot be deleted, as when the command left a directory there
/// that cannot be listed, stays in the system temporary directory, a line
/// `could not delete {t}: {reason}` goes to [progress], and the outcome
/// stands. Throws FileSystemException when the root or a case's `files/`
/// cannot be resolved.
Future<SetRun> runCliSet(
  String slug,
  List<InvocationPlan> plans, {
  required Directory root,
  required String dart,
  required String? flutter,
  required Map<String, Uri> roots,
  required StringSink progress,
}) async {
  CommandProcess? resolve(Command command) => processOf(
    command,
    dart: dart,
    flutter: flutter,
    packageConfig: workspacePath(root, packageConfigPath),
    roots: roots,
  );
  return switch (plans
      .whereType<InvocationRun>()
      .where((InvocationRun run) => resolve(run.command) == null)
      .firstOrNull) {
    final InvocationRun run => SetUnavailable(
      CheckSet.cli,
      slug,
      _unresolvable(run, dart),
    ),
    null => await _runInvocations(
      slug,
      plans,
      root: root,
      dart: dart,
      resolve: resolve,
      progress: progress,
    ),
  };
}

/// The process that runs [command], as [processOf] resolves it; null when there is none.
typedef _Resolve = CommandProcess? Function(Command command);

/// What running one recorded invocation gave: its outcome, or the reason the slug's set cannot
/// run.
sealed class _CaseResult {
  const _CaseResult();
}

/// The case's [outcome], judged by [invocationOutcome].
final class _CaseConcluded extends _CaseResult {
  const _CaseConcluded(this.outcome);

  final FixtureOutcome outcome;
}

/// A process of the case could not start, as [reason] tells.
final class _CaseUnavailable extends _CaseResult {
  const _CaseUnavailable(this.reason);

  final String reason;
}

/// Why [run] has no process: [processOf] gives none for a `{package}:{executable}` command whose
/// package the package configuration lacks, and for a `flutter` command when the Flutter SDK of
/// [dart] holds no flutter.
String _unresolvable(InvocationRun run, String dart) => switch (run.command) {
  PackageCommand(:final String package, :final String executable) =>
    'package $package is absent from $packageConfigPath; '
        '${run.path} runs $package:$executable',
  _ => 'no flutter in the Flutter SDK of $dart; ${run.path} runs flutter',
};

/// [plans] of [slug]'s recorded invocations taken in order, after the [concluded] outcomes of the
/// plans before them: [SetChecked] with every outcome, or [SetUnavailable] at the first process
/// that cannot start, starting no case after it.
Future<SetRun> _runInvocations(
  String slug,
  List<InvocationPlan> plans, {
  required Directory root,
  required String dart,
  required _Resolve resolve,
  required StringSink progress,
  List<FixtureOutcome> concluded = const <FixtureOutcome>[],
}) async => switch (plans) {
  [] => SetChecked(
    CheckSet.cli,
    slug,
    List<FixtureOutcome>.unmodifiable(concluded),
  ),
  [
    InvocationSettled(:final FixtureOutcome outcome),
    ...final List<InvocationPlan> rest,
  ] =>
    await _runInvocations(
      slug,
      rest,
      root: root,
      dart: dart,
      resolve: resolve,
      progress: progress,
      concluded: <FixtureOutcome>[...concluded, outcome],
    ),
  [final InvocationRun run, ...final List<InvocationPlan> rest] =>
    switch (await _runCase(
      run,
      root: root,
      dart: dart,
      resolve: resolve,
      progress: progress,
    )) {
      _CaseConcluded(:final FixtureOutcome outcome) => await _runInvocations(
        slug,
        rest,
        root: root,
        dart: dart,
        resolve: resolve,
        progress: progress,
        concluded: <FixtureOutcome>[...concluded, outcome],
      ),
      _CaseUnavailable(:final String reason) => SetUnavailable(
        CheckSet.cli,
        slug,
        reason,
      ),
    },
};

/// [run] with a fresh `{t}`, deleted after as far as it can be: after its progress line, its
/// process, `{output}` its `{t}/output`, started from its `files/` or [root], and its outcome
/// judged by [_judged].
Future<_CaseResult> _runCase(
  InvocationRun run, {
  required Directory root,
  required String dart,
  required _Resolve resolve,
  required StringSink progress,
}) async {
  final Directory temporary = Directory.systemTemp.createTempSync('ncc_cli_');
  try {
    final String output = p.join(temporary.path, 'output');
    final List<PathForms> forms = _formsOf(
      run,
      root: root,
      temporary: temporary,
      output: output,
    );
    progress.writeln('running cli ${run.path}');
    return switch (resolve(withOutput(run.command, output))) {
      // Not reached: runCliSet resolved every run before the first started,
      // and substituting `{output}` changes no command's kind or package.
      null => _CaseUnavailable(_unresolvable(run, dart)),
      final CommandProcess process => switch (await runProcess(
        process.executable,
        process.arguments,
        workingDirectory: switch (run.files) {
          final String files => workspacePath(root, files),
          null => root.path,
        },
      )) {
        NotStarted(:final String reason) => _CaseUnavailable(reason),
        Exited(:final ProcessExit exit) => await _judged(
          run,
          exit,
          output: output,
          forms: forms,
          root: root,
          dart: dart,
        ),
      },
    };
  } finally {
    _deleteTemporary(temporary, progress);
  }
}

/// The placeholders of [run]'s streams, in ADR-001 item 7's order (design decision 9):
/// `{output}`, given as [output] and resolved as [temporary] resolved and `output`; `{files}`,
/// for a case with `files/`; and `{root}`, each directory given as found and resolved. Throws
/// FileSystemException when a directory cannot be resolved.
List<PathForms> _formsOf(
  InvocationRun run, {
  required Directory root,
  required Directory temporary,
  required String output,
}) => List<PathForms>.unmodifiable(<PathForms>[
  (
    given: output,
    resolved: p.join(temporary.resolveSymbolicLinksSync(), 'output'),
    placeholder: '{output}',
  ),
  if (run.files case final String files)
    _formsOfDirectory(Directory(workspacePath(root, files)), '{files}'),
  _formsOfDirectory(root, '{root}'),
]);

/// [directory]'s path as given and resolved, for [placeholder]. Throws FileSystemException.
PathForms _formsOfDirectory(Directory directory, String placeholder) => (
  given: directory.path,
  resolved: directory.resolveSymbolicLinksSync(),
  placeholder: placeholder,
);

/// The outcome of [run], which ended as [exit], by [invocationOutcome] with [forms] and with what
/// is at [output], read once the run ended; [_CaseUnavailable] when `dart format` cannot start.
///
/// A directory is an [OutputTree]: for a case with `expected/`, formatted
/// first by [dart] from [root] and compared with the case's `expected/` tree;
/// for one without, read unformatted. Nothing is a [NoOutput]; a file, a
/// link or any other entry is an [OutputFile].
Future<_CaseResult> _judged(
  InvocationRun run,
  ProcessExit exit, {
  required String output,
  required List<PathForms> forms,
  required Directory root,
  required String dart,
}) async {
  _CaseResult judge(OutputState state) => _CaseConcluded(
    invocationOutcome(
      run,
      exit: exit,
      output: state,
      expected: switch (run.expected) {
        final String expected => readTree(
          Directory(workspacePath(root, expected)),
        ),
        null => const <String, FileEntry>{},
      },
      forms: forms,
    ),
  );
  return switch ((_typeOf(output, followLinks: false), run.expected)) {
    (FileSystemEntityType.notFound, _) => judge(const NoOutput()),
    (FileSystemEntityType.directory, null) => judge(
      OutputTree(readTree(Directory(output)), null),
    ),
    (FileSystemEntityType.directory, String()) => switch (await runProcess(
      dart,
      <String>['format', output],
      workingDirectory: root.path,
    )) {
      NotStarted(:final String reason) => _CaseUnavailable(reason),
      Exited(exit: final ProcessExit format) => judge(
        OutputTree(readTree(Directory(output)), format),
      ),
    },
    _ => judge(const OutputFile()),
  };
}

/// Deletes [temporary] and everything below it, as far as it can: when what a process left there
/// cannot be deleted, it stays, with a line `could not delete {path}: {reason}` to [progress]. A
/// [temporary] that no longer exists needs no deleting.
void _deleteTemporary(Directory temporary, StringSink progress) {
  if (_attempt(() => temporary.deleteSync(recursive: true))
      case _Refused(:final String reason)
      when _typeOf(temporary.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
    progress.writeln('could not delete ${temporary.path}: $reason');
  }
}

/// The entries below the directory at [path], whose symlink-resolved path is [resolved], each
/// keyed by [key], `/` and its path relative to [path]; [descent] holds the resolved path of
/// every directory the walk is inside, [resolved] included.
///
/// A directory that cannot be listed is one [FileUnreadable] at [key], `.`
/// for the tree's own directory.
Map<String, FileEntry> _below(
  String path, {
  required String key,
  required Set<String> descent,
  required String resolved,
}) => switch (_attempt(() => _namesIn(path))) {
  _Done(value: final List<String> names) => <String, FileEntry>{
    for (final String name in names)
      ..._entriesAt(
        p.join(path, name),
        key: key.isEmpty ? name : '$key/$name',
        descent: descent,
        resolvedParent: resolved,
      ),
  },
  _Refused(:final String reason) => <String, FileEntry>{
    key.isEmpty ? '.' : key: FileUnreadable(reason),
  },
};

/// The entries of the file system entry at [path], keyed by [key]: its bytes for a file, or a
/// link that resolves to one; the entries below it for a directory, or a link that resolves to
/// one that [descent] lacks; else one [FileUnreadable].
///
/// [resolvedParent] is the resolved path of the directory that lists it, so
/// a directory that is no link resolves to [resolvedParent] and its name.
Map<String, FileEntry> _entriesAt(
  String path, {
  required String key,
  required Set<String> descent,
  required String resolvedParent,
}) => switch (_typeOf(path)) {
  FileSystemEntityType.file => <String, FileEntry>{
    key: switch (_attempt(File(path).readAsBytesSync)) {
      _Done(value: final List<int> bytes) => FileBytes(bytes),
      _Refused(:final String reason) => FileUnreadable(reason),
    },
  },
  FileSystemEntityType.directory => switch (_resolvedDirectory(
    path,
    resolvedParent,
  )) {
    _Done(value: final String resolved) when descent.contains(resolved) =>
      <String, FileEntry>{
        key: const FileUnreadable(
          'a symbolic link to a directory above it, a cycle',
        ),
      },
    _Done(value: final String resolved) => _below(
      path,
      key: key,
      descent: <String>{...descent, resolved},
      resolved: resolved,
    ),
    _Refused(:final String reason) => <String, FileEntry>{
      key: FileUnreadable(reason),
    },
  },
  FileSystemEntityType.pipe => <String, FileEntry>{
    key: const FileUnreadable('a named pipe, not a file'),
  },
  FileSystemEntityType.unixDomainSock => <String, FileEntry>{
    key: const FileUnreadable('a socket, not a file'),
  },
  _ => <String, FileEntry>{key: _unresolved(path)},
};

/// The resolved path of the directory at [path] that the directory at [resolvedParent] lists:
/// [resolvedParent] and its name when it is no link, else the link resolved.
_Attempt<String> _resolvedDirectory(String path, String resolvedParent) =>
    switch (_typeOf(path, followLinks: false)) {
      FileSystemEntityType.link => _attempt(
        Link(path).resolveSymbolicLinksSync,
      ),
      _ => _Done<String>(p.join(resolvedParent, p.basename(path))),
    };

/// The [FileUnreadable] of an entry that is no file, directory, named pipe or socket: the reason
/// resolving it gives, such as for a link that does not resolve; for one that resolves, such as
/// a device, `neither a file nor a directory`.
FileUnreadable _unresolved(String path) =>
    switch (_attempt(Link(path).resolveSymbolicLinksSync)) {
      _Refused(:final String reason) => FileUnreadable(reason),
      _Done() => const FileUnreadable('neither a file nor a directory'),
    };

/// The names of the entries directly in the directory at [path], ascending. Throws
/// FileSystemException.
List<String> _namesIn(String path) => List<String>.unmodifiable(
  Directory(path)
      .listSync(followLinks: false)
      .map((FileSystemEntity entity) => p.basename(entity.path))
      .toList()
    ..sort(),
);

/// The type of the entry at [path], a link followed unless [followLinks] is false;
/// [FileSystemEntityType.notFound] when it cannot be read.
FileSystemEntityType _typeOf(String path, {bool followLinks = true}) =>
    switch (_attempt(
      () => FileSystemEntity.typeSync(path, followLinks: followLinks),
    )) {
      _Done(value: final FileSystemEntityType type) => type,
      _Refused() => FileSystemEntityType.notFound,
    };

/// What a file system action gave: it is [_Done] with its value, or [_Refused] with the reason.
sealed class _Attempt<T> {
  const _Attempt();
}

/// The action gave [value].
final class _Done<T> extends _Attempt<T> {
  const _Done(this.value);

  final T value;
}

/// The action threw a FileSystemException, told by [reason], one line.
final class _Refused<T> extends _Attempt<T> {
  const _Refused(this.reason);

  final String reason;
}

/// [action]'s value, or the reason of the FileSystemException it throws.
_Attempt<T> _attempt<T>(T Function() action) {
  try {
    return _Done<T>(action());
  } on FileSystemException catch (error) {
    return _Refused<T>(_reasonOf(error));
  }
}

/// [error] as one line: the first line of its message, then `: ` and the first line of its OS
/// error's message when there is one.
String _reasonOf(FileSystemException error) => switch (<String>[
  ?firstTextLine(error.message),
  ?firstTextLine(error.osError?.message ?? ''),
]) {
  [] => 'it cannot be read',
  final List<String> parts => parts.join(': '),
};
