/// The `reject` set (ADR-001 items 4 and 9): a library below `reject/`
/// passes when the (line, code) pairs reported in it, at every severity,
/// equal the pairs its markers name, and it has at least one marker. A
/// marker `// expect-diagnostic: {code}` on its own line names `{code}` on
/// the next line.
///
/// It reads the diagnostics the shell's one analysis reported, attributed to
/// fixtures; nothing here runs the analyzer.
library;

import 'analysis.dart';
import 'dart_library.dart';
import 'outcome.dart';
import 'request.dart';
import 'snapshot.dart';

/// The rules of the `reject` set.
enum RejectRule implements Rule {
  /// The library has a well-formed marker.
  marker('marker'),

  /// Each pair a marker names is reported.
  missingDiagnostic('missing-diagnostic'),

  /// Each reported pair is named by a marker.
  unexpectedDiagnostic('unexpected-diagnostic');

  const RejectRule(this.label);

  @override
  final String label;
}

/// The `reject` set's outcomes for [snapshot]: one per library below
/// `reject/`, in [setLibraries] order.
///
/// [diagnostics] maps a fixture path from the workspace root to what was
/// reported in it; a library without an entry has no diagnostic. A library
/// that names a package [packages] lacks is [Pending] whatever is reported.
/// Otherwise its problems come in this order: [RejectRule.marker] when no
/// marker names a pair; then line by line, ascending, each pair named and
/// not reported ([RejectRule.missingDiagnostic]), then each pair reported and
/// not named ([RejectRule.unexpectedDiagnostic]), codes ascending within
/// each. The reported pairs form a set: the marked code reported twice on
/// its line is one pair. A malformed marker names no pair; the `structure`
/// set reports it.
List<FixtureOutcome> checkReject(
  SlugSnapshot snapshot, {
  required Set<String> packages,
  required Map<String, List<Diagnostic>> diagnostics,
}) => List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[
  for (final (:String path, :DartLibrary library, :List<String> absent)
      in setLibraries(snapshot, CheckSet.reject, packages))
    absent.isEmpty
        ? _judged(
            path,
            library.markers,
            diagnostics[path] ?? const <Diagnostic>[],
          )
        : Pending(path, absent),
]);

/// A diagnostic's line and code: what a marker names and what the set
/// compares.
typedef _Pair = ({int line, String code});

/// The library at [path], judged by its [markers] against the diagnostics
/// [reported] in it.
FixtureOutcome _judged(
  String path,
  List<Marker> markers,
  List<Diagnostic> reported,
) {
  final Set<_Pair> named = <_Pair>{
    for (final Marker marker in markers)
      if (marker.code case final String code)
        (line: marker.line + 1, code: code),
  };
  final Set<_Pair> found = reported.map(_pairOf).toSet();
  final List<_Pair> missing = _ascending(named.difference(found));
  final List<_Pair> unexpected = _ascending(found.difference(named));
  final List<int> lines = <int>{
    for (final _Pair pair in <_Pair>[...missing, ...unexpected]) pair.line,
  }.toList()..sort();
  final List<Problem> problems = List<Problem>.unmodifiable(<Problem>[
    if (named.isEmpty)
      const Problem(RejectRule.marker, 'no // expect-diagnostic: marker'),
    for (final int line in lines) ...<Problem>[
      for (final _Pair pair in missing)
        if (pair.line == line)
          Problem(
            RejectRule.missingDiagnostic,
            'line $line: ${pair.code}, named by the marker on line '
            '${line - 1}, not reported',
          ),
      for (final _Pair pair in unexpected)
        if (pair.line == line)
          Problem(
            RejectRule.unexpectedDiagnostic,
            diagnosticText(
              reported.firstWhere(
                (Diagnostic diagnostic) => _pairOf(diagnostic) == pair,
              ),
            ),
          ),
    ],
  ]);
  return problems.isEmpty ? Passed(path) : Failed(path, problems);
}

/// The pair [diagnostic] gives.
_Pair _pairOf(Diagnostic diagnostic) =>
    (line: diagnostic.line, code: diagnostic.code);

/// [pairs] by line, then code.
List<_Pair> _ascending(Set<_Pair> pairs) => List<_Pair>.unmodifiable(
  pairs.toList()..sort(
    (_Pair a, _Pair b) =>
        a.line == b.line ? a.code.compareTo(b.code) : a.line.compareTo(b.line),
  ),
);
