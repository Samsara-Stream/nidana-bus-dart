/// The replay tool's imperative shell (nidana.model D2 item 5): it finds the
/// workspace root, reads the contract texts a restriction names, one
/// [SlugSnapshot] per slug of the request and per slug whose suite a binding
/// imports, and the package configuration, runs `dart analyze` once for the
/// `surface` and `reject` sets of every slug, runs one test runner per
/// binding the `behavior` set runs (through `runners.dart`), runs the planned
/// sets and prints the report. Every decision is the pure core's. With
/// `runners.dart` and `workspace.dart`, it is one of the three libraries
/// under `lib/src/` that import `dart:io`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'analysis.dart';
import 'behavior.dart';
import 'contract.dart';
import 'outcome.dart';
import 'packages.dart';
import 'reject.dart';
import 'report.dart';
import 'request.dart';
import 'run.dart';
import 'runners.dart';
import 'schema.dart';
import 'snapshot.dart';
import 'structure.dart';
import 'surface.dart';
import 'workspace.dart';

/// The names of the directories directly under hsdd/contract/fixture/, hidden ones excluded; empty
/// when it is absent. Throws FileSystemException for a symbolic link directly under it.
///
/// A link where a slug directory belongs is refused rather than skipped or
/// followed: skipped, it would hide a slug from `--all`; followed, it would
/// replay a tree outside the fixtures. A hidden entry, link or not, is not
/// part of the replay.
Set<String> discoverSlugs(Directory root) {
  final Directory fixtures = Directory(
    workspacePath(root, 'hsdd/contract/fixture/'),
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
/// bytes when it exists. A source is read as bytes and decoded by
/// [decodeSource], so a source that is not UTF-8 has a null source and its
/// reason in [SlugSnapshot.undecodable], that source's defect for the
/// structure set to report. A document's bytes are never decoded here, so a
/// document that is not UTF-8 is that document's defect for the schema set
/// to report. A symbolic link is never descended into, so no tree outside
/// the fixture directory joins the snapshot: it is recorded as a file, the
/// layout check sees it as one, and when [holdsSource] or [holdsDocument]
/// says so it is read through the link, so a linked library or document is
/// replayed and a dangling one throws.
SlugSnapshot readSnapshot(Directory root, String slug) {
  final Directory fixtures = Directory(
    workspacePath(root, fixtureDirectory(slug)),
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
  final Map<String, SourceDecoding> sources =
      Map<String, SourceDecoding>.unmodifiable(<String, SourceDecoding>{
        for (final (:String path, :FileSystemEntity entity) in entries)
          if (_isFile(entity) && holdsSource(path))
            path: decodeSource(File(entity.path).readAsBytesSync()),
      });
  final File contract = File(workspacePath(root, contractPath(slug)));
  final File schema = File(workspacePath(root, schemaPath(slug)));
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
          path: switch (sources[path]) {
            SourceText(:final String text) => text,
            SourceNotUtf8() || null => null,
          },
    }),
    documents: Map<String, List<int>>.unmodifiable(<String, List<int>>{
      for (final (:String path, :FileSystemEntity entity) in entries)
        if (_isFile(entity) && holdsDocument(path))
          path: File(entity.path).readAsBytesSync(),
    }),
    undecodable: Map<String, String>.unmodifiable(<String, String>{
      for (final MapEntry<String, SourceDecoding>(
            key: String path,
            value: SourceDecoding decoding,
          )
          in sources.entries)
        if (decoding case SourceNotUtf8(:final String reason)) path: reason,
    }),
  );
}

/// Parses, replays, prints one line per fixture to [out] and errors to [err]; returns the exit code.
/// [dart] runs `dart analyze` and `dart test`, and the flutter of its Flutter SDK runs
/// `flutter test`; null means Platform.resolvedExecutable, the dart running the tool.
///
/// Outcome lines and the summary go to [out]; a set that could not run, a
/// usage error, an environment error and one progress line before each test
/// runner starts go to [err]. The exit code is
/// [exitCodeOf] the runs; [exitUsage] on a usage error, a command line
/// [parseRequest] rejects or a restriction with an id its slug does not
/// declare, even in a workspace with no slug directory; and
/// [exitEnvironment] when no workspace root or no slug directory is found or
/// reading fails.
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

/// Parses [arguments] against the slugs under [root], checks the
/// restriction, reads every slug of the request, the slugs whose suites its
/// bindings import and the package configuration, runs the one analysis and
/// every planned set, then prints each run in order and the summary.
///
/// The order is fixed: a usage error comes before the check for a slug
/// directory, so a command line that does not parse exits [exitUsage] even
/// in a workspace with no fixtures; the restriction is checked against the
/// contract texts it names before any snapshot is read; the slugs of the
/// suites are read after the request's, only for a plan that holds the
/// `behavior` set; the package configuration is read once, for every set
/// that [readsPackages], before the analysis that needs its names. The sets
/// run one after another, so the `behavior` set's runners run one at a time,
/// in plan order.
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
  final Set<String> discovered = discoverSlugs(root);
  switch (parseRequest(arguments, slugs: discovered)) {
    case UsageError(:final String message):
      return _usageError(message, err: err);
    case ParsedRequest(:final Request request):
      if (request.slugs.isEmpty) {
        err.writeln('error: no slug directory under hsdd/contract/fixture/');
        return exitEnvironment;
      }
      if (guaranteeError(request, _declaredGuarantees(root, request))
          case final String message) {
        return _usageError(message, err: err);
      }
      final List<SlugPlan> plans = List<SlugPlan>.unmodifiable(<SlugPlan>[
        for (final String slug in request.slugs)
          slugPlan(request, readSnapshot(root, slug)),
      ]);
      final Map<String, SlugSnapshot> snapshots = _snapshotsOf(
        root,
        plans,
        discovered,
      );
      final _Packages packages = _readPackages(root, plans);
      final _Context context = (
        root: root,
        packages: packages,
        analysis: await _analyze(root, plans, packages, dart: dart),
        snapshots: snapshots,
        restriction: request.restriction,
        dart: dart,
        flutter: _flutterOf(dart),
        progress: err,
      );
      final List<SetRun> runs = List<SetRun>.unmodifiable(<SetRun>[
        for (final (:SlugSnapshot snapshot, :List<CheckSet> sets) in plans)
          for (final CheckSet set in sets) await _run(set, snapshot, context),
      ]);
      for (final SetRun run in runs) {
        _print(run, out: out, err: err);
      }
      out.writeln(summaryLine(runs));
      return exitCodeOf(runs);
  }
}

/// Prints the usage error [message] and the [usage] to [err]; returns [exitUsage].
int _usageError(String message, {required StringSink err}) {
  err
    ..writeln('error: $message')
    ..writeln(usage);
  return exitUsage;
}

/// For each slug [request]'s restriction names, the ids its contract text declares, or null when
/// it has none; empty when the request is unrestricted.
Map<String, Set<int>?> _declaredGuarantees(Directory root, Request request) =>
    Map<String, Set<int>?>.unmodifiable(<String, Set<int>?>{
      for (final String slug in <String>{
        for (final GuaranteeRef ref
            in request.restriction ?? const <GuaranteeRef>{})
          ref.slug,
      })
        slug: _declaredBy(root, slug),
    });

/// The ids the contract text of [slug] under [root] declares; null when it is absent, as
/// [readSnapshot] reads it.
Set<int>? _declaredBy(Directory root, String slug) {
  final File contract = File(workspacePath(root, contractPath(slug)));
  return contract.existsSync()
      ? Set<int>.unmodifiable(
          readContract(slug, contract.readAsStringSync()).guarantees,
        )
      : null;
}

/// What a replay reads once for all its runs: the workspace [root], its
/// [_Packages] and the replay's one [_Analysis]; the [snapshots] of every
/// slug read, the request's and the slugs of the suites its bindings import;
/// the request's [restriction]; the [dart] running the tool and the
/// [flutter] beside it, null when its Flutter SDK holds none; and the
/// [progress] sink, `err`, that a line goes to before each runner starts.
typedef _Context = ({
  Directory root,
  _Packages packages,
  _Analysis analysis,
  Map<String, SlugSnapshot> snapshots,
  Set<GuaranteeRef>? restriction,
  String dart,
  String? flutter,
  StringSink progress,
});

/// The snapshot of each slug of [plans], and of each slug that [discovered] holds whose suite a
/// binding of a plan with the `behavior` set imports, read once each, in ascending order.
///
/// A suite's slug that has no fixture directory is not read: the planner
/// fails a binding of it as a suite that does not exist.
Map<String, SlugSnapshot> _snapshotsOf(
  Directory root,
  List<SlugPlan> plans,
  Set<String> discovered,
) {
  final Map<String, SlugSnapshot> requested = <String, SlugSnapshot>{
    for (final SlugPlan plan in plans) plan.snapshot.slug: plan.snapshot,
  };
  final List<String> suites = <String>{
    for (final SlugPlan plan in plans)
      if (plan.sets.contains(CheckSet.behavior)) ...suiteSlugs(plan.snapshot),
  }.toList()..sort();
  return Map<String, SlugSnapshot>.unmodifiable(<String, SlugSnapshot>{
    ...requested,
    for (final String slug in suites)
      if (discovered.contains(slug) && !requested.containsKey(slug))
        slug: readSnapshot(root, slug),
  });
}

/// The flutter of the Flutter SDK that holds [dart], [flutterBeside] it, when that file exists;
/// else null.
String? _flutterOf(String dart) => switch (flutterBeside(dart)) {
  final String flutter when File(flutter).existsSync() => flutter,
  _ => null,
};

/// The workspace's package names, read once per replay from
/// [packageConfigPath], or the reason they cannot be read.
sealed class _Packages {
  const _Packages();
}

/// The [names] of the packages the workspace's package configuration
/// configures.
final class _PackageNames extends _Packages {
  const _PackageNames(this.names);

  final Set<String> names;
}

/// The workspace has no package configuration it can read: every run that
/// needs the names is [SetUnavailable] with [reason].
final class _NoPackages extends _Packages {
  const _NoPackages(this.reason);

  final String reason;
}

/// The package configuration under [root], for the sets of [plans] that [readsPackages].
///
/// When no plan holds such a set, the configuration is not read and the
/// empty names stand in; no run consults them. The configuration is read as
/// bytes and decoded strictly, so bytes that are not UTF-8 are a
/// configuration that is not one, as a text [packageNamesOf] rejects is.
_Packages _readPackages(Directory root, List<SlugPlan> plans) {
  if (!plans.any((SlugPlan plan) => plan.sets.any(readsPackages))) {
    return const _PackageNames(<String>{});
  }
  final File configuration = File(workspacePath(root, packageConfigPath));
  if (!configuration.existsSync()) {
    return const _NoPackages(
      'no package configuration at $packageConfigPath; run fvm dart pub get',
    );
  }
  final Set<String>? names = switch (_strictUtf8(
    configuration.readAsBytesSync(),
  )) {
    final String text => packageNamesOf(text),
    null => null,
  };
  return names == null
      ? const _NoPackages('$packageConfigPath is not a package configuration')
      : _PackageNames(names);
}

/// [bytes] decoded as UTF-8; null when they are not UTF-8.
String? _strictUtf8(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

/// What the replay's one analysis gives the `surface` and `reject` runs: the
/// diagnostics by fixture, or the reason those runs cannot run.
sealed class _Analysis {
  const _Analysis();
}

/// The [diagnostics] reported in each analyzed library, by its path from the
/// workspace root.
final class _Analyzed extends _Analysis {
  const _Analyzed(this.diagnostics);

  final Map<String, List<Diagnostic>> diagnostics;
}

/// The analysis could not run: every `surface` and `reject` run is
/// [SetUnavailable] with [reason].
final class _AnalysisUnavailable extends _Analysis {
  const _AnalysisUnavailable(this.reason);

  final String reason;
}

/// The replay's one analysis, for the `surface` and `reject` runs of every
/// plan, over the [packages] [_readPackages] read.
///
/// When no plan holds a set that [readsAnalysis], the empty diagnostics stand
/// in and no run consults them. With [_NoPackages], the analysis is
/// unavailable for its reason. With no [replayTargets], no process starts.
Future<_Analysis> _analyze(
  Directory root,
  List<SlugPlan> plans,
  _Packages packages, {
  required String dart,
}) async {
  if (!plans.any((SlugPlan plan) => plan.sets.any(readsAnalysis))) {
    return const _Analyzed(<String, List<Diagnostic>>{});
  }
  switch (packages) {
    case _NoPackages(:final String reason):
      return _AnalysisUnavailable(reason);
    case _PackageNames(:final Set<String> names):
      final List<String> targets = replayTargets(plans, names);
      return targets.isEmpty
          ? const _Analyzed(<String, List<Diagnostic>>{})
          : _analyzeTargets(root, targets, dart: dart);
  }
}

/// Runs `dart analyze` once over [targets] from [root] and has
/// [attributeDiagnostics] attribute what it reports.
///
/// The shell's part is the file system's and the process's: each target's
/// absolute path and its symlink-resolved form, hsdd/contract/fixture/
/// resolved once, and the analyzer's output, decoded by [lenientUtf8] so
/// bytes that are not UTF-8 never stop the replay.
Future<_Analysis> _analyzeTargets(
  Directory root,
  List<String> targets, {
  required String dart,
}) async {
  final List<AnalysisTarget> files = List<AnalysisTarget>.unmodifiable(
    <AnalysisTarget>[for (final String path in targets) _targetOf(root, path)],
  );
  final String fixtures = Directory(
    workspacePath(root, 'hsdd/contract/fixture/'),
  ).resolveSymbolicLinksSync();
  final ProcessResult result;
  try {
    result = await Process.run(
      dart,
      <String>[
        'analyze',
        '--fatal-infos',
        '--format=json',
        for (final AnalysisTarget file in files) file.given,
      ],
      workingDirectory: root.path,
      stdoutEncoding: lenientUtf8,
      stderrEncoding: lenientUtf8,
    );
  } on ProcessException catch (error) {
    return _AnalysisUnavailable('could not run $dart: ${error.message}');
  }
  final List<Diagnostic>? reported = parseAnalysis(result.stdout as String);
  if (reported == null) {
    return _AnalysisUnavailable(
      analysisFailure(result.exitCode, result.stderr as String),
    );
  }
  return switch (attributeDiagnostics(files, fixtures, reported)) {
    Attributed(:final Map<String, List<Diagnostic>> byFixture) => _Analyzed(
      byFixture,
    ),
    Unattributable(:final String reason) => _AnalysisUnavailable(reason),
  };
}

/// The [AnalysisTarget] of the library at [path] from [root]: the absolute
/// path handed to `dart analyze`, and that path with symbolic links
/// resolved.
AnalysisTarget _targetOf(Directory root, String path) {
  final String given = workspacePath(root, path);
  return (
    path: path,
    given: given,
    resolved: File(given).resolveSymbolicLinksSync(),
  );
}

/// [set] run over [snapshot], the `surface`, `reject` and `behavior` sets
/// reading [context]. Each set this version does not implement is
/// [SetUnavailable] with the [notImplemented] reason; the phase that lands it
/// replaces its branch.
Future<SetRun> _run(
  CheckSet set,
  SlugSnapshot snapshot,
  _Context context,
) async => switch (set) {
  CheckSet.structure => SetChecked(
    set,
    snapshot.slug,
    checkStructure(snapshot),
  ),
  CheckSet.surface => _analyzedRun(set, snapshot, context, checkSurface),
  CheckSet.reject => _analyzedRun(set, snapshot, context, checkReject),
  CheckSet.behavior => await _behaviorRun(snapshot, context),
  CheckSet.schema => SetChecked(set, snapshot.slug, checkSchema(snapshot)),
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

/// [set] run by [check] over [snapshot] with the package names and the
/// diagnostics of [context], else [SetUnavailable] with the reason the
/// packages or the analysis gives.
SetRun _analyzedRun(
  CheckSet set,
  SlugSnapshot snapshot,
  _Context context,
  _AnalyzedCheck check,
) => switch ((context.packages, context.analysis)) {
  (_NoPackages(:final String reason), _) ||
  (
    _,
    _AnalysisUnavailable(:final String reason),
  ) => SetUnavailable(set, snapshot.slug, reason),
  (
    _PackageNames(:final Set<String> names),
    _Analyzed(:final Map<String, List<Diagnostic>> diagnostics),
  ) =>
    SetChecked(
      set,
      snapshot.slug,
      check(snapshot, packages: names, diagnostics: diagnostics),
    ),
};

/// The `behavior` set over [snapshot]: [planBindings] plans each binding with the package names
/// and the snapshots of [context], and [runBehavior] runs the plans with the root, the dart, the
/// flutter and the progress sink of [context]; [SetUnavailable] with the packages' reason when
/// the package configuration cannot be read.
Future<SetRun> _behaviorRun(SlugSnapshot snapshot, _Context context) async =>
    switch (context.packages) {
      _NoPackages(:final String reason) => SetUnavailable(
        CheckSet.behavior,
        snapshot.slug,
        reason,
      ),
      _PackageNames(:final Set<String> names) => await runBehavior(
        snapshot.slug,
        planBindings(
          snapshot,
          snapshots: context.snapshots,
          packages: names,
          restriction: context.restriction,
        ),
        root: context.root,
        dart: context.dart,
        flutter: context.flutter,
        progress: context.progress,
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

/// [directory] as an absolute, normalized path, as [findWorkspaceRoot]
/// starts from it.
Directory _absolute(Directory directory) =>
    Directory(p.normalize(directory.absolute.path));

/// [entity]'s path relative to [base], `/`-separated.
String _relative(FileSystemEntity entity, Directory base) =>
    p.posix.joinAll(p.split(p.relative(entity.path, from: base.path)));

/// Whether a segment of the `/`-separated [path] is hidden.
bool _isHiddenPath(String path) => path.split('/').any(_isHiddenName);

/// Whether [name] is hidden: it begins with `.`.
bool _isHiddenName(String name) => name.startsWith('.');

/// The last segment of [entity]'s path.
String _nameOf(FileSystemEntity entity) => p.basename(entity.path);
