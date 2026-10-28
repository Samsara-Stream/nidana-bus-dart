/// Which sets a slug has, which of them a [Request] runs (ADR-001 item 9),
/// the [SlugPlan] of each slug of a replay, which sets read the workspace's
/// package configuration and which run commands, the reason of the `pub get`
/// before them that failed, and which file replays and recorded invocations
/// a `--guarantee` restriction admits.
library;

import 'ids.dart';
import 'report.dart';
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

/// One slug of a replay: its [snapshot] and the sets planned over it, in
/// order.
typedef SlugPlan = ({SlugSnapshot snapshot, List<CheckSet> sets});

/// The [SlugPlan] of [snapshot] under [request]: the sets [plannedSets] runs over it.
SlugPlan slugPlan(Request request, SlugSnapshot snapshot) =>
    (snapshot: snapshot, sets: plannedSets(request, snapshot));

/// Whether [set] reads the workspace's package configuration: surface, reject, behavior, file
/// and cli do.
///
/// The shell reads the configuration once per replay, and only when some
/// planned set reads it. file and cli read it for the packages their
/// commands run, absent ones PENDING, and for each package's root (design
/// decisions 1 and 11).
bool readsPackages(CheckSet set) => switch (set) {
  CheckSet.surface ||
  CheckSet.reject ||
  CheckSet.behavior ||
  CheckSet.file ||
  CheckSet.cli => true,
  CheckSet.structure || CheckSet.schema => false,
};

/// Whether [set] runs commands, before which the replay runs `dart pub get --enforce-lockfile`
/// once: file and cli do.
bool runsCommands(CheckSet set) => switch (set) {
  CheckSet.file || CheckSet.cli => true,
  CheckSet.structure ||
  CheckSet.surface ||
  CheckSet.reject ||
  CheckSet.behavior ||
  CheckSet.schema => false,
};

/// `dart pub get --enforce-lockfile exited {exitCode}`, then `: {firstTextLine(stderr)}` when there is one.
///
/// The reason of every `file` and `cli` set of a replay whose `pub get`
/// exited non-zero (design decision 15).
String pubGetFailure(int exitCode, String stderr) {
  final String reason = 'dart pub get --enforce-lockfile exited $exitCode';
  return switch (firstTextLine(stderr)) {
    final String first => '$reason: $first',
    null => reason,
  };
}

/// Whether a file replay or recorded invocation of [slug] that covers [ids] runs under
/// [restriction] (ADR-001 item 9): unrestricted, or [ids] is not empty and each is a restriction
/// id of [slug].
///
/// A replay that covers no id runs only unrestricted: a slug with no id of
/// its own in the restriction runs none of them (design decision 13). The
/// restriction ids of other slugs neither admit nor bar it.
bool admitsAll(Set<GuaranteeRef>? restriction, String slug, Set<int> ids) =>
    switch (restriction) {
      null => true,
      final Set<GuaranteeRef> restricted =>
        ids.isNotEmpty &&
            ids.every(
              (int number) => restricted.contains((slug: slug, number: number)),
            ),
    };

/// The detail of a replay [admitsAll] does not admit.
///
/// `not run: the restriction does not admit all of {ids}` names [ids] as
/// [formatIds] gives them; `not run: it covers no declared guarantee, and the
/// replay is restricted` stands for no id.
String notAdmitted(Set<int> ids) => ids.isEmpty
    ? 'not run: it covers no declared guarantee, and the replay is restricted'
    : 'not run: the restriction does not admit all of ${formatIds(ids)}';

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
