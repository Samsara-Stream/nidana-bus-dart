/// Which sets a slug has and which of them a [Request] runs (ADR-001 item 9).
library;

import 'request.dart';
import 'snapshot.dart';

/// The sets a slug has: structure always; surface, reject, behavior when that
/// directory exists; schema when the schema file or a valid/ or invalid/
/// directory exists; file when input/ or expected/ exists; cli when
/// invocation/ exists.
Set<CheckSet> setsOf(SlugSnapshot snapshot) => Set<CheckSet>.unmodifiable(
  CheckSet.values.where((CheckSet set) => _has(snapshot, set)),
);

/// structure first, then each other set the slug has and the request selects,
/// in [CheckSet] order.
///
/// `--set` selects among the slug's other sets and never adds a set the slug
/// lacks; structure runs whether `--set` names it or not.
List<CheckSet> plannedSets(Request request, SlugSnapshot snapshot) {
  final Set<CheckSet> has = setsOf(snapshot);
  final Set<CheckSet>? selected = request.sets;
  return List<CheckSet>.unmodifiable(<CheckSet>[
    CheckSet.structure,
    ...CheckSet.values.where(
      (CheckSet set) =>
          set != CheckSet.structure &&
          has.contains(set) &&
          (selected?.contains(set) ?? true),
    ),
  ]);
}

/// Whether [snapshot]'s slug has [set], read from the entries directly under
/// its fixture directory and from its schema file.
bool _has(SlugSnapshot snapshot, CheckSet set) {
  bool exists(String directory) => snapshot.directories.contains(directory);
  return switch (set) {
    CheckSet.structure => true,
    CheckSet.surface => exists('surface'),
    CheckSet.reject => exists('reject'),
    CheckSet.behavior => exists('behavior'),
    CheckSet.schema =>
      snapshot.hasSchemaFile || exists('valid') || exists('invalid'),
    CheckSet.file => exists('input') || exists('expected'),
    CheckSet.cli => exists('invocation'),
  };
}
