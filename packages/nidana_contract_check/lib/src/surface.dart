/// The `surface` set (ADR-001 items 4 and 9): a library below `surface/`
/// passes when the analyzer reports no diagnostic in it, at any severity,
/// under `--fatal-infos`.
///
/// It reads the diagnostics the shell's one analysis reported, attributed to
/// fixtures; nothing here runs the analyzer.
library;

import 'analysis.dart';
import 'outcome.dart';
import 'request.dart';
import 'snapshot.dart';

/// The rules of the `surface` set.
enum SurfaceRule implements Rule {
  /// The analyzer reports no diagnostic in the library, at any severity.
  diagnostic('diagnostic');

  const SurfaceRule(this.label);

  @override
  final String label;
}

/// The `surface` set's outcomes for [snapshot]: one per library below
/// `surface/`, in [setLibraries] order.
///
/// [diagnostics] maps a fixture path from the workspace root to what was
/// reported in it; a library without an entry has no diagnostic. A library
/// that names a package [packages] lacks is [Pending] whatever is reported.
/// Otherwise it [Passed] with no diagnostic, else it [Failed] with one
/// [SurfaceRule.diagnostic] problem per diagnostic, by line, then code, then
/// message.
List<FixtureOutcome> checkSurface(
  SlugSnapshot snapshot, {
  required Set<String> packages,
  required Map<String, List<Diagnostic>> diagnostics,
}) => List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[
  for (final (:String path, library: _, :List<String> absent) in setLibraries(
    snapshot,
    CheckSet.surface,
    packages,
  ))
    absent.isEmpty
        ? _judged(path, diagnostics[path] ?? const <Diagnostic>[])
        : Pending(path, absent),
]);

/// The library at [path], judged by the diagnostics [reported] in it.
FixtureOutcome _judged(String path, List<Diagnostic> reported) =>
    switch (_sorted(reported)) {
      [] => Passed(path),
      final List<Diagnostic> sorted => Failed(
        path,
        List<Problem>.unmodifiable(<Problem>[
          for (final Diagnostic diagnostic in sorted)
            Problem(SurfaceRule.diagnostic, diagnosticText(diagnostic)),
        ]),
      ),
    };

/// [reported] by line, then code, then message.
List<Diagnostic> _sorted(List<Diagnostic> reported) =>
    List<Diagnostic>.unmodifiable(reported.toList()..sort(_byLineCodeMessage));

/// The order of [a] and [b] by line, then code, then message.
int _byLineCodeMessage(Diagnostic a, Diagnostic b) => <int>[
  a.line.compareTo(b.line),
  a.code.compareTo(b.code),
  a.message.compareTo(b.message),
].firstWhere((int order) => order != 0, orElse: () => 0);
