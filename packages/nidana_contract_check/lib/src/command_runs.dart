/// The runs of the sets that run commands (ADR-001 item 6; design decisions
/// 4 to 7), part of the replay tool's imperative shell: the `file` set's
/// generator started into a fresh `{output}`, `dart format` over it, and the
/// two trees read, hidden entries included. Every decision is the pure
/// core's (`file_set.dart` and `tree.dart`); each process starts through
/// `processes.dart`. It is one of the libraries under `lib/src/` that import
/// `dart:io`, which `test/purity_test.dart` lists.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'command.dart';
import 'file_set.dart';
import 'outcome.dart';
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
/// deleted stays in the system temporary directory, and the outcome stands.
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
    _attempt(() => temporary.deleteSync(recursive: true));
  }
}

/// The file set of [slug], checked with its one [outcome].
SetChecked _fileChecked(String slug, FixtureOutcome outcome) => SetChecked(
  CheckSet.file,
  slug,
  List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[outcome]),
);

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
