/// The replay tool's imperative shell (nidana.model D2 item 5): it finds the
/// workspace root, reads one [SlugSnapshot] per slug, runs the planned sets
/// and prints the report. Every decision is the pure core's; this is the only
/// library of the tool that imports `dart:io`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'outcome.dart';
import 'report.dart';
import 'request.dart';
import 'run.dart';
import 'snapshot.dart';
import 'structure.dart';

/// The nearest ancestor of [start], [start] included, that holds hsdd/contract/; null when none does.
Directory? findWorkspaceRoot(Directory start) =>
    _selfAndAncestors(_absolute(start)).where(_holdsContracts).firstOrNull;

/// The names of the directories directly under hsdd/contract/fixture/, hidden ones excluded; empty when it is absent.
Set<String> discoverSlugs(Directory root) {
  final Directory fixtures = Directory(
    _workspacePath(root, 'hsdd/contract/fixture/'),
  );
  return fixtures.existsSync()
      ? Set<String>.unmodifiable(
          fixtures
              .listSync(followLinks: false)
              .whereType<Directory>()
              .map((Directory directory) => p.basename(directory.path))
              .where((String name) => !_isHiddenName(name)),
        )
      : const <String>{};
}

/// Reads one slug; entries whose name begins with '.' are not part of it. Throws FileSystemException.
///
/// Every other directory and file below `hsdd/contract/fixture/{slug}/` is
/// recorded by its `/`-separated path relative to that directory, a file with
/// its source only when [holdsSource] says so. Links are not followed and are
/// recorded as neither.
SlugSnapshot readSnapshot(Directory root, String slug) {
  final Directory fixtures = Directory(
    _workspacePath(root, fixtureDirectory(slug)),
  );
  final List<_Entry> entries = List<_Entry>.unmodifiable(<_Entry>[
    for (final FileSystemEntity entity in fixtures.listSync(
      recursive: true,
      followLinks: false,
    ))
      if (_relative(entity, fixtures) case final String path
          when !_isHiddenPath(path))
        (path: path, entity: entity),
  ]);
  final File contract = File(_workspacePath(root, contractPath(slug)));
  return SlugSnapshot(
    slug: slug,
    contractText: contract.existsSync() ? contract.readAsStringSync() : null,
    hasSchemaFile: File(
      _workspacePath(root, 'hsdd/contract/schema/$slug.schema.json'),
    ).existsSync(),
    directories: Set<String>.unmodifiable(<String>{
      for (final (:String path, :FileSystemEntity entity) in entries)
        if (entity is Directory) path,
    }),
    files: Map<String, String?>.unmodifiable(<String, String?>{
      for (final (:String path, :FileSystemEntity entity) in entries)
        if (entity case final File file)
          path: holdsSource(path) ? file.readAsStringSync() : null,
    }),
  );
}

/// Parses, replays, prints one line per fixture to [out] and errors to [err]; returns the exit code.
///
/// Outcome lines and the summary go to [out]; a set this version does not
/// implement, a usage error and an environment error go to [err]. The exit
/// code is [exitCodeOf] the runs, [exitUsage] on a usage error, and
/// [exitEnvironment] when no workspace root is found or reading fails.
Future<int> runCli(
  List<String> arguments, {
  required Directory workingDirectory,
  required StringSink out,
  required StringSink err,
}) async {
  final Directory? root = findWorkspaceRoot(workingDirectory);
  if (root == null) {
    err.writeln(
      'error: no ancestor of ${_absolute(workingDirectory).path} '
      'holds hsdd/contract/',
    );
    return exitEnvironment;
  }
  try {
    return _replay(arguments, root, out: out, err: err);
  } on FileSystemException catch (error) {
    err.writeln(switch (error.path) {
      final String path => 'error: ${error.message}: $path',
      null => 'error: ${error.message}',
    });
    return exitEnvironment;
  }
}

/// Parses [arguments] against the slugs under [root], runs every planned set
/// and prints each run as it completes, then the summary.
int _replay(
  List<String> arguments,
  Directory root, {
  required StringSink out,
  required StringSink err,
}) {
  switch (parseRequest(arguments, slugs: discoverSlugs(root))) {
    case UsageError(:final String message):
      err
        ..writeln('error: $message')
        ..writeln(usage);
      return exitUsage;
    case ParsedRequest(:final Request request):
      final List<SetRun> runs = <SetRun>[];
      for (final SetRun run in _runs(request, root)) {
        _print(run, out: out, err: err);
        runs.add(run);
      }
      out.writeln(summaryLine(runs));
      return exitCodeOf(runs);
  }
}

/// The runs [request] asks for, slug by slug in request order and, within a
/// slug, set by set in [plannedSets] order; each slug is read when its first
/// run is asked for.
Iterable<SetRun> _runs(Request request, Directory root) sync* {
  for (final String slug in request.slugs) {
    final SlugSnapshot snapshot = readSnapshot(root, slug);
    yield* plannedSets(
      request,
      snapshot,
    ).map((CheckSet set) => _run(set, snapshot));
  }
}

/// [set] run over [snapshot]. Each set this version does not implement is
/// [SetUnavailable]; the phase that lands it replaces its branch.
SetRun _run(CheckSet set, SlugSnapshot snapshot) => switch (set) {
  CheckSet.structure => SetChecked(
    set,
    snapshot.slug,
    checkStructure(snapshot),
  ),
  // nidana.model.2 lands these.
  CheckSet.surface ||
  CheckSet.reject ||
  CheckSet.schema => SetUnavailable(set, snapshot.slug),
  // nidana.model.6 lands this.
  CheckSet.behavior => SetUnavailable(set, snapshot.slug),
  // nidana.model.7 lands these.
  CheckSet.file || CheckSet.cli => SetUnavailable(set, snapshot.slug),
};

/// Prints [run]: each outcome's line to [out], or the unavailable line to
/// [err].
void _print(SetRun run, {required StringSink out, required StringSink err}) {
  switch (run) {
    case SetChecked(:final CheckSet set, :final List<FixtureOutcome> outcomes):
      outcomes
          .map((FixtureOutcome outcome) => outcomeLine(set, outcome))
          .forEach(out.writeln);
    case SetUnavailable():
      err.writeln(unavailableLine(run));
  }
}

/// An entry below a slug's fixture directory, with its relative
/// `/`-separated [path].
typedef _Entry = ({String path, FileSystemEntity entity});

/// [directory] followed by each of its ancestors up to the file system root.
Iterable<Directory> _selfAndAncestors(Directory directory) sync* {
  yield directory;
  final Directory parent = directory.parent;
  if (parent.path != directory.path) {
    yield* _selfAndAncestors(parent);
  }
}

/// Whether [directory] holds `hsdd/contract/`.
bool _holdsContracts(Directory directory) =>
    Directory(_workspacePath(directory, 'hsdd/contract/')).existsSync();

/// [directory] as an absolute, normalized path.
Directory _absolute(Directory directory) =>
    Directory(p.normalize(directory.absolute.path));

/// The platform path of the `/`-separated [path] from [root].
String _workspacePath(Directory root, String path) =>
    p.joinAll(<String>[root.path, ...p.posix.split(path)]);

/// [entity]'s path relative to [base], `/`-separated.
String _relative(FileSystemEntity entity, Directory base) =>
    p.posix.joinAll(p.split(p.relative(entity.path, from: base.path)));

/// Whether a segment of the `/`-separated [path] is hidden.
bool _isHiddenPath(String path) => path.split('/').any(_isHiddenName);

/// Whether [name] is hidden: it begins with `.`.
bool _isHiddenName(String name) => name.startsWith('.');
