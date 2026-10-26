/// The replay tool's imperative shell (nidana.model D2 item 5): it finds the
/// workspace root, reads one [SlugSnapshot] per slug, runs `dart analyze`
/// once for the `surface` and `reject` sets of every slug, runs the planned
/// sets and prints the report. Every decision is the pure core's; this is the
/// only library of the tool that imports `dart:io`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'analysis.dart';
import 'outcome.dart';
import 'packages.dart';
import 'reject.dart';
import 'report.dart';
import 'request.dart';
import 'run.dart';
import 'schema.dart';
import 'snapshot.dart';
import 'structure.dart';
import 'surface.dart';

/// The nearest ancestor of [start], [start] included, that holds hsdd/contract/; null when none does.
Directory? findWorkspaceRoot(Directory start) =>
    _selfAndAncestors(_absolute(start)).where(_holdsContracts).firstOrNull;

/// The names of the directories directly under hsdd/contract/fixture/, hidden ones excluded; empty
/// when it is absent. Throws FileSystemException for a symbolic link directly under it.
///
/// A link where a slug directory belongs is refused rather than skipped or
/// followed: skipped, it would hide a slug from `--all`; followed, it would
/// replay a tree outside the fixtures. A hidden entry, link or not, is not
/// part of the replay.
Set<String> discoverSlugs(Directory root) {
  final Directory fixtures = Directory(
    _workspacePath(root, 'hsdd/contract/fixture/'),
  );
  if (!fixtures.existsSync()) {
    return const <String>{};
  }
  final List<FileSystemEntity> entries = fixtures
      .listSync(followLinks: false)
      .where((FileSystemEntity entity) => !_isHiddenName(_nameOf(entity)))
      .toList();
  if (entries.whereType<Link>().firstOrNull case final Link link) {
    throw FileSystemException(
      "a slug's fixture directory is a symbolic link",
      link.path,
    );
  }
  return Set<String>.unmodifiable(entries.whereType<Directory>().map(_nameOf));
}

/// Reads one slug; entries whose name begins with '.' are not part of it. Throws FileSystemException.
///
/// Every other directory and file below `hsdd/contract/fixture/{slug}/` is
/// recorded by its `/`-separated path relative to that directory, a file with
/// its source only when [holdsSource] says so, and with its bytes as a
/// document only when [holdsDocument] says so. The schema file is read as
/// bytes when it exists. Bytes are never decoded here, so a document that is
/// not UTF-8 is that document's defect for the schema set to report. A
/// symbolic link is never descended into, so no tree outside the fixture
/// directory joins the snapshot: it is recorded as a file, the layout check
/// sees it as one, and when [holdsSource] or [holdsDocument] says so it is
/// read through the link, so a linked library or document is replayed and a
/// dangling one throws.
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
  final File schema = File(_workspacePath(root, schemaPath(slug)));
  return SlugSnapshot(
    slug: slug,
    contractText: contract.existsSync() ? contract.readAsStringSync() : null,
    schemaBytes: schema.existsSync() ? schema.readAsBytesSync() : null,
    directories: Set<String>.unmodifiable(<String>{
      for (final (:String path, :FileSystemEntity entity) in entries)
        if (entity is Directory) path,
    }),
    files: Map<String, String?>.unmodifiable(<String, String?>{
      for (final (:String path, :FileSystemEntity entity) in entries)
        if (_isFile(entity))
          path: holdsSource(path) ? File(entity.path).readAsStringSync() : null,
    }),
    documents: Map<String, List<int>>.unmodifiable(<String, List<int>>{
      for (final (:String path, :FileSystemEntity entity) in entries)
        if (_isFile(entity) && holdsDocument(path))
          path: File(entity.path).readAsBytesSync(),
    }),
  );
}

/// Parses, replays, prints one line per fixture to [out] and errors to [err]; returns the exit code.
/// [dart] runs `dart analyze`; null means Platform.resolvedExecutable, the dart running the tool.
///
/// Outcome lines and the summary go to [out]; a set that could not run, a
/// usage error and an environment error go to [err]. The exit code is
/// [exitCodeOf] the runs, [exitUsage] on a usage error, and [exitEnvironment]
/// when no workspace root or no slug directory is found or reading fails.
Future<int> runCli(
  List<String> arguments, {
  required Directory workingDirectory,
  required StringSink out,
  required StringSink err,
  String? dart,
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
    return await _replay(
      arguments,
      root,
      out: out,
      err: err,
      dart: dart ?? Platform.resolvedExecutable,
    );
  } on FileSystemException catch (error) {
    err.writeln(switch (error.path) {
      final String path => 'error: ${error.message}: $path',
      null => 'error: ${error.message}',
    });
    return exitEnvironment;
  }
}

/// Parses [arguments] against the slugs under [root], reads every slug of the
/// request, runs the one analysis and every planned set, then prints each run
/// in order and the summary.
///
/// Every run is computed before the first line is printed: the analysis
/// serves every slug, so no slug's runs are known before it completes.
Future<int> _replay(
  List<String> arguments,
  Directory root, {
  required StringSink out,
  required StringSink err,
  required String dart,
}) async {
  final Set<String> slugs = discoverSlugs(root);
  if (slugs.isEmpty) {
    err.writeln('error: no slug directory under hsdd/contract/fixture/');
    return exitEnvironment;
  }
  switch (parseRequest(arguments, slugs: slugs)) {
    case UsageError(:final String message):
      err
        ..writeln('error: $message')
        ..writeln(usage);
      return exitUsage;
    case ParsedRequest(:final Request request):
      final List<SlugPlan> plans = List<SlugPlan>.unmodifiable(<SlugPlan>[
        for (final String slug in request.slugs)
          _planOf(request, readSnapshot(root, slug)),
      ]);
      final _Analysis analysis = await _analyze(root, plans, dart: dart);
      final List<SetRun> runs = List<SetRun>.unmodifiable(<SetRun>[
        for (final (:SlugSnapshot snapshot, :List<CheckSet> sets) in plans)
          for (final CheckSet set in sets) _run(set, snapshot, analysis),
      ]);
      for (final SetRun run in runs) {
        _print(run, out: out, err: err);
      }
      out.writeln(summaryLine(runs));
      return exitCodeOf(runs);
  }
}

/// The [SlugPlan] of [snapshot] under [request]: the sets [plannedSets]
/// runs over it.
SlugPlan _planOf(Request request, SlugSnapshot snapshot) =>
    (snapshot: snapshot, sets: plannedSets(request, snapshot));

/// What the replay's one analysis gives the `surface` and `reject` runs: the
/// diagnostics by fixture, or the reason those runs cannot run.
sealed class _Analysis {
  const _Analysis();
}

/// The workspace's [packages] and the [diagnostics] reported in each analyzed
/// library, by its path from the workspace root.
final class _Analyzed extends _Analysis {
  const _Analyzed(this.packages, this.diagnostics);

  final Set<String> packages;
  final Map<String, List<Diagnostic>> diagnostics;
}

/// The analysis could not run: every `surface` and `reject` run is
/// [SetUnavailable] with [reason].
final class _AnalysisUnavailable extends _Analysis {
  const _AnalysisUnavailable(this.reason);

  final String reason;
}

/// The replay's one analysis, for the `surface` and `reject` runs of every
/// plan.
///
/// The package configuration is read only when some plan holds a set that
/// [readsAnalysis]; otherwise the result is never consulted. With no
/// [replayTargets], no process starts.
Future<_Analysis> _analyze(
  Directory root,
  List<SlugPlan> plans, {
  required String dart,
}) async {
  if (!plans.any((SlugPlan plan) => plan.sets.any(readsAnalysis))) {
    return const _Analyzed(<String>{}, <String, List<Diagnostic>>{});
  }
  final File configuration = File(_workspacePath(root, packageConfigPath));
  if (!configuration.existsSync()) {
    return const _AnalysisUnavailable(
      'no package configuration at $packageConfigPath; run fvm dart pub get',
    );
  }
  final Set<String>? packages = packageNamesOf(
    configuration.readAsStringSync(),
  );
  if (packages == null) {
    return const _AnalysisUnavailable(
      '$packageConfigPath is not a package configuration',
    );
  }
  final List<String> targets = replayTargets(plans, packages);
  return targets.isEmpty
      ? _Analyzed(packages, const <String, List<Diagnostic>>{})
      : _analyzeTargets(root, targets, packages, dart: dart);
}

/// Runs `dart analyze` once over [targets] from [root] and has
/// [attributeDiagnostics] attribute what it reports.
///
/// The shell's part is the file system's and the process's: each target's
/// absolute path and its symlink-resolved form, and the analyzer's output.
Future<_Analysis> _analyzeTargets(
  Directory root,
  List<String> targets,
  Set<String> packages, {
  required String dart,
}) async {
  final List<AnalysisTarget> files = List<AnalysisTarget>.unmodifiable(
    <AnalysisTarget>[for (final String path in targets) _targetOf(root, path)],
  );
  final ProcessResult result;
  try {
    result = await Process.run(dart, <String>[
      'analyze',
      '--fatal-infos',
      '--format=json',
      for (final AnalysisTarget file in files) file.given,
    ], workingDirectory: root.path);
  } on ProcessException catch (error) {
    return _AnalysisUnavailable('could not run $dart: ${error.message}');
  }
  final List<Diagnostic>? reported = parseAnalysis(result.stdout as String);
  if (reported == null) {
    return _AnalysisUnavailable(
      analysisFailure(result.exitCode, result.stderr as String),
    );
  }
  return switch (attributeDiagnostics(files, reported)) {
    Attributed(:final Map<String, List<Diagnostic>> byFixture) => _Analyzed(
      packages,
      byFixture,
    ),
    Unattributable(:final String reason) => _AnalysisUnavailable(reason),
  };
}

/// The [AnalysisTarget] of the library at [path] from [root]: the absolute
/// path handed to `dart analyze`, and that path with symbolic links
/// resolved.
AnalysisTarget _targetOf(Directory root, String path) {
  final String given = _workspacePath(root, path);
  return (
    path: path,
    given: given,
    resolved: File(given).resolveSymbolicLinksSync(),
  );
}

/// [set] run over [snapshot], the `surface` and `reject` sets reading
/// [analysis]. Each set this version does not implement is [SetUnavailable]
/// with the [notImplemented] reason; the phase that lands it replaces its
/// branch.
SetRun _run(CheckSet set, SlugSnapshot snapshot, _Analysis analysis) =>
    switch (set) {
      CheckSet.structure => SetChecked(
        set,
        snapshot.slug,
        checkStructure(snapshot),
      ),
      CheckSet.surface => _analyzedRun(set, snapshot, analysis, checkSurface),
      CheckSet.reject => _analyzedRun(set, snapshot, analysis, checkReject),
      CheckSet.schema => SetChecked(set, snapshot.slug, checkSchema(snapshot)),
      // nidana.model.6 lands this.
      CheckSet.behavior => SetUnavailable(
        set,
        snapshot.slug,
        notImplemented(set),
      ),
      // nidana.model.7 lands these.
      CheckSet.file ||
      CheckSet.cli => SetUnavailable(set, snapshot.slug, notImplemented(set)),
    };

/// A set that judges libraries by the diagnostics reported in them:
/// [checkSurface] or [checkReject].
typedef _AnalyzedCheck = List<FixtureOutcome> Function(
  SlugSnapshot snapshot, {
  required Set<String> packages,
  required Map<String, List<Diagnostic>> diagnostics,
});

/// [set] run by [check] over [snapshot] when [analysis] ran, else
/// [SetUnavailable] with its reason.
SetRun _analyzedRun(
  CheckSet set,
  SlugSnapshot snapshot,
  _Analysis analysis,
  _AnalyzedCheck check,
) => switch (analysis) {
  _Analyzed(
    :final Set<String> packages,
    :final Map<String, List<Diagnostic>> diagnostics,
  ) =>
    SetChecked(
      set,
      snapshot.slug,
      check(snapshot, packages: packages, diagnostics: diagnostics),
    ),
  _AnalysisUnavailable(:final String reason) => SetUnavailable(
    set,
    snapshot.slug,
    reason,
  ),
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

/// Whether the snapshot records [entity] as a file: a file, or a symbolic
/// link, which is never descended into.
bool _isFile(FileSystemEntity entity) => entity is File || entity is Link;

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

/// The last segment of [entity]'s path.
String _nameOf(FileSystemEntity entity) => p.basename(entity.path);
