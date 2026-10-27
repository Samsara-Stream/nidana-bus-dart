/// What the `surface` and `reject` sets read (ADR-001 items 4 and 9): the
/// diagnostics of `dart analyze --format=json`, each attributed to the
/// fixture it was reported in, and the libraries each set analyzes; and the
/// replay's one analysis: which sets read it, what it analyzes, and when its
/// report cannot be attributed.
///
/// Pure: the shell runs the analyzer once per replay and hands this library
/// its stdout and the paths it resolved; nothing here reads a file or starts
/// a process.
library;

import 'dart:convert';

import 'package:path/path.dart' as p;

import 'dart_library.dart';
import 'packages.dart';
import 'request.dart';
import 'run.dart';
import 'snapshot.dart';

/// One diagnostic as `dart analyze --format=json` reports it.
final class Diagnostic {
  const Diagnostic({
    required this.file,
    required this.line,
    required this.severity,
    required this.code,
    required this.message,
  });

  /// The file, as dart analyze reports it: absolute, symbolic links
  /// resolved.
  final String file;

  /// The 1-based line the diagnostic starts on.
  final int line;

  /// `ERROR`, `WARNING` or `INFO`.
  final String severity;

  /// The code, lowercase, as reported.
  final String code;

  /// The `problemMessage`.
  final String message;
}

/// The diagnostics of `dart analyze --format=json`'s [stdout]; null when it holds no such report.
///
/// The report is decoded from the first `{` of [stdout]; text before it is
/// ignored. [stdout] holds a report when that text decodes to a map whose
/// `diagnostics` is a list of maps, each with a string `code`, a string
/// `severity`, a string `location.file`, an integer
/// `location.range.start.line` and a string `problemMessage`. Other keys are
/// ignored.
List<Diagnostic>? parseAnalysis(String stdout) {
  final int start = stdout.indexOf('{');
  if (start < 0) {
    return null;
  }
  final Object? document;
  try {
    document = jsonDecode(stdout.substring(start));
  } on FormatException {
    return null;
  }
  if (document case {'diagnostics': final List<Object?> entries}) {
    final List<Diagnostic?> diagnostics = entries.map(_diagnosticOf).toList();
    return diagnostics.contains(null)
        ? null
        : List<Diagnostic>.unmodifiable(diagnostics.nonNulls);
  }
  return null;
}

/// The reason of an analysis that printed no report.
///
/// `dart analyze exited {exitCode} without a JSON report`, then
/// `: {line}` with the first line of [stderr] that is not blank, trimmed,
/// when there is one.
String analysisFailure(int exitCode, String stderr) {
  final String reason = 'dart analyze exited $exitCode without a JSON report';
  final String? first = LineSplitter.split(stderr)
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .firstOrNull;
  return first == null ? reason : '$reason: $first';
}

/// Diagnostics grouped by fixture: [byFixture] maps a fixture's path from the
/// workspace root to the diagnostics reported in it, and [strays] are the
/// reported files that belong to no fixture.
typedef GroupedDiagnostics = ({
  Map<String, List<Diagnostic>> byFixture,
  List<String> strays,
});

/// [reported] by fixture path from the workspace root, through [fixtureOf], which maps an
/// analyzer path to a fixture; [strays] are the reported files [fixtureOf] lacks, once, ascending.
///
/// Each fixture's diagnostics keep their reported order. Several analyzer
/// paths may map to one fixture, as a path given and its symlink-resolved
/// form do.
GroupedDiagnostics groupDiagnostics(
  List<Diagnostic> reported,
  Map<String, String> fixtureOf,
) {
  final Set<String> fixtures = <String>{
    for (final Diagnostic diagnostic in reported) ?fixtureOf[diagnostic.file],
  };
  return (
    byFixture: Map<String, List<Diagnostic>>.unmodifiable(
      <String, List<Diagnostic>>{
        for (final String fixture in fixtures)
          fixture: List<Diagnostic>.unmodifiable(<Diagnostic>[
            for (final Diagnostic diagnostic in reported)
              if (fixtureOf[diagnostic.file] == fixture) diagnostic,
          ]),
      },
    ),
    strays: List<String>.unmodifiable(
      <String>{
        for (final Diagnostic diagnostic in reported)
          if (!fixtureOf.containsKey(diagnostic.file)) diagnostic.file,
      }.toList()..sort(),
    ),
  );
}

/// `line {line}: {severity} {code}: {message}`.
String diagnosticText(Diagnostic diagnostic) =>
    'line ${diagnostic.line}: ${diagnostic.severity} ${diagnostic.code}: '
    '${diagnostic.message}';

/// One library a set analyzes: its [path] from the workspace root, the
/// [library] read from its source, and the packages it names that the
/// workspace lacks, [absent], ascending.
typedef SetLibrary = ({String path, DartLibrary library, List<String> absent});

/// Every library below `{set}/` for set surface or reject, by path from the workspace root,
/// ascending, with the packages it names that [packages] lacks; empty for every other set.
///
/// A library is a file of [snapshot] that [holdsSource] accepts and whose
/// source was read, nested ones included.
List<SetLibrary> setLibraries(
  SlugSnapshot snapshot,
  CheckSet set,
  Set<String> packages,
) => switch (set) {
  CheckSet.surface ||
  CheckSet.reject => _librariesBelow(snapshot, '${set.name}/', packages),
  CheckSet.structure ||
  CheckSet.behavior ||
  CheckSet.schema ||
  CheckSet.file ||
  CheckSet.cli => const <SetLibrary>[],
};

/// The paths of [setLibraries] whose `absent` is empty: what `dart analyze` must analyze.
List<String> analysisTargets(
  SlugSnapshot snapshot,
  CheckSet set,
  Set<String> packages,
) => List<String>.unmodifiable(<String>[
  for (final SetLibrary library in setLibraries(snapshot, set, packages))
    if (library.absent.isEmpty) library.path,
]);

/// Whether [set] reads the replay's one analysis: surface and reject do.
bool readsAnalysis(CheckSet set) => switch (set) {
  CheckSet.surface || CheckSet.reject => true,
  CheckSet.structure ||
  CheckSet.behavior ||
  CheckSet.schema ||
  CheckSet.file ||
  CheckSet.cli => false,
};

/// What the replay's one `dart analyze` analyzes: [analysisTargets] of every set of every one of
/// [plans], once each, ascending.
///
/// Empty when no planned library can be analyzed; the shell then starts no
/// process, because `dart analyze` without a path analyzes the working
/// directory.
List<String> replayTargets(List<SlugPlan> plans, Set<String> packages) =>
    List<String>.unmodifiable(
      <String>{
        for (final (:SlugSnapshot snapshot, :List<CheckSet> sets) in plans)
          for (final CheckSet set in sets)
            ...analysisTargets(snapshot, set, packages),
      }.toList()..sort(),
    );

/// One library handed to `dart analyze`: its [path] from the workspace root,
/// the absolute path it was [given] as, and that path with symbolic links
/// [resolved].
typedef AnalysisTarget = ({String path, String given, String resolved});

/// The diagnostics of one analysis by target: [Attributed], or
/// [Unattributable] with the reason the `surface` and `reject` sets cannot
/// run.
sealed class Attribution {
  const Attribution();
}

/// The diagnostics reported in each target.
final class Attributed extends Attribution {
  const Attributed(this.byFixture);

  /// The diagnostics reported in each target, by its path from the workspace
  /// root; a target with none has no entry.
  final Map<String, List<Diagnostic>> byFixture;
}

/// An analysis whose report cannot be attributed: an environment error, with
/// its [reason].
final class Unattributable extends Attribution {
  const Unattributable(this.reason);

  /// Why the report cannot be attributed, for the unavailable sets' lines.
  final String reason;
}

/// The diagnostics [reported] by one `dart analyze` over [targets], attributed to each target;
/// [fixtures] is hsdd/contract/fixture/ as an absolute path with symbolic links resolved.
///
/// The rules, in order:
///
/// 1. A target that resolves outside [fixtures] is a symbolic link the
///    analyzer follows: it analyzes the file under the analysis options of
///    where the link lands, not the fixture analysis options (ADR-001
///    item 2), so the verdict would not be the fixture's. The first such
///    target makes the report [Unattributable]. A link to another file
///    within [fixtures] is analyzed under those options and is attributed.
/// 2. A reported file that is no target's given or resolved path is a stray:
///    dropping it could pass a library that has a diagnostic, so the first
///    stray, ascending, makes the report [Unattributable].
/// 3. Otherwise each target gets every diagnostic reported at its given or
///    its resolved path, in reported order. The analyzer reports
///    symlink-resolved paths and reports a file once, so targets that
///    resolve to one file, as a link to another library does, each get that
///    file's diagnostics.
Attribution attributeDiagnostics(
  List<AnalysisTarget> targets,
  String fixtures,
  List<Diagnostic> reported,
) {
  if (targets
          .where(
            (AnalysisTarget target) => !p.isWithin(fixtures, target.resolved),
          )
          .firstOrNull
      case final AnalysisTarget outside) {
    return Unattributable(
      '${outside.path} is a symbolic link to ${outside.resolved}, outside '
      'hsdd/contract/fixture/, so dart analyze does not apply the fixture '
      'analysis options',
    );
  }
  // Grouped by resolved file, not by fixture: several targets may share one.
  final GroupedDiagnostics byFile = groupDiagnostics(reported, <String, String>{
    for (final AnalysisTarget target in targets) ...<String, String>{
      target.given: target.resolved,
      target.resolved: target.resolved,
    },
  });
  if (byFile.strays.firstOrNull case final String stray) {
    return Unattributable(
      'dart analyze reported $stray, which the replay did not ask it to '
      'analyze',
    );
  }
  return Attributed(
    Map<String, List<Diagnostic>>.unmodifiable(<String, List<Diagnostic>>{
      for (final AnalysisTarget target in targets)
        if (byFile.byFixture[target.resolved] case final List<Diagnostic> found)
          target.path: found,
    }),
  );
}

/// The [Diagnostic] that [entry], one element of a report's `diagnostics`,
/// describes; null when it lacks a field or a field has another type.
Diagnostic? _diagnosticOf(Object? entry) => switch (entry) {
  {
    'code': final String code,
    'severity': final String severity,
    'location': {
      'file': final String file,
      'range': {'start': {'line': final int line}},
    },
    'problemMessage': final String message,
  } =>
    Diagnostic(
      file: file,
      line: line,
      severity: severity,
      code: code,
      message: message,
    ),
  _ => null,
};

/// The libraries of [snapshot] whose relative path begins with [prefix],
/// ascending, each with the packages it names that [packages] lacks.
List<SetLibrary> _librariesBelow(
  SlugSnapshot snapshot,
  String prefix,
  Set<String> packages,
) {
  final String directory = fixtureDirectory(snapshot.slug);
  final List<String> relatives = <String>[
    for (final String relative in snapshot.files.keys)
      if (holdsSource(relative) && relative.startsWith(prefix)) relative,
  ]..sort();
  return List<SetLibrary>.unmodifiable(<SetLibrary>[
    for (final String relative in relatives)
      if (snapshot.files[relative] case final String source)
        _setLibrary('$directory$relative', readDartLibrary(source), packages),
  ]);
}

/// The [SetLibrary] at [path], read as [library].
SetLibrary _setLibrary(
  String path,
  DartLibrary library,
  Set<String> packages,
) => (path: path, library: library, absent: absentPackages(library, packages));
