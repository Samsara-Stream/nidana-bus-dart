/// The replay tool's command line (ADR-001 item 9) read as a [Request]: the
/// slugs to replay, the sets `--set` selects and the guarantees `--guarantee`
/// restricts to.
library;

import 'package:args/args.dart';

import 'ids.dart';

/// The replay tool's sets (ADR-001 item 9); `--set` names each by its enum name.
enum CheckSet { structure, surface, reject, behavior, schema, file, cli }

/// One guarantee, `--guarantee`'s bare ids resolved to the replayed slug.
typedef GuaranteeRef = ({String slug, int number});

/// What one run of the replay tool replays.
final class Request {
  const Request({
    required this.slugs,
    required this.sets,
    required this.restriction,
  });

  /// Command order without repeats; every slug in ascending order under --all.
  final List<String> slugs;

  /// The sets --set named; null when it named none (every set a slug has).
  final Set<CheckSet>? sets;

  /// The guarantees --guarantee named; null when unrestricted.
  final Set<GuaranteeRef>? restriction;
}

/// A command line read as a [ParsedRequest] or rejected as a [UsageError].
sealed class ParseResult {
  const ParseResult();
}

/// A command line that names a [Request].
final class ParsedRequest extends ParseResult {
  const ParsedRequest(this.request);

  final Request request;
}

/// A command line the replay tool rejects, which exits 64 (ADR-001 item 9).
final class UsageError extends ParseResult {
  const UsageError(this.message);

  final String message;
}

/// Printed after a usage error.
const String usage = '''
usage: fvm dart run nidana_contract_check {slug}... [--set {set},...] [--guarantee {id},...]
       fvm dart run nidana_contract_check --all [--set {set},...] [--guarantee {id},...]
sets: structure, surface, reject, behavior, schema, file, cli
ids: G{n} for the one slug named, or {slug}/G{n}''';

/// Parses the command line against the slugs that have a fixture directory.
///
/// The checks run in a fixed order and the first that fails gives the
/// [UsageError]: the slug count, the named slugs, the set names, each
/// `--guarantee` value, then the bare ids.
ParseResult parseRequest(List<String> arguments, {required Set<String> slugs}) {
  final ArgResults results;
  try {
    results = _parser.parse(arguments);
  } on FormatException catch (error) {
    return UsageError(error.message);
  }
  final bool all = results.flag('all');
  final List<String> named = results.rest;
  final List<String> setNames = results.multiOption('set');
  final List<String> idTexts = results.multiOption('guarantee');
  final List<String> replayed = all
      ? (<String>[...slugs]..sort())
      : named.toSet().toList();
  // _idError rejects every value that does not read, so by the time the
  // bare-id check and the restriction see `ids`, it holds every value.
  final List<_Id> ids = idTexts.map(_readId).nonNulls.toList(growable: false);
  final String? error =
      _slugCountError(all, named) ??
      _unknownSlugError(named, slugs) ??
      _setError(setNames) ??
      _idError(idTexts, slugs) ??
      _bareIdError(ids, replayed.length);
  if (error != null) {
    return UsageError(error);
  }
  return ParsedRequest(
    Request(
      slugs: List<String>.unmodifiable(replayed),
      sets: setNames.isEmpty
          ? null
          : Set<CheckSet>.unmodifiable(setNames.map(CheckSet.values.byName)),
      restriction: ids.isEmpty
          ? null
          : Set<GuaranteeRef>.unmodifiable(
              ids.map((_Id id) => _resolve(id, replayed)),
            ),
    ),
  );
}

final ArgParser _parser = ArgParser()
  ..addFlag('all', negatable: false)
  ..addMultiOption('set')
  ..addMultiOption('guarantee');

/// The names `--set` accepts, in [CheckSet] order.
final Set<String> _knownSetNames = CheckSet.values
    .map((CheckSet set) => set.name)
    .toSet();

/// A `--guarantee` value that reads as an id.
sealed class _Id {
  const _Id();
}

/// `G{n}`, which belongs to the one slug the command replays.
final class _BareId extends _Id {
  const _BareId(this.text, this.number);

  final String text;
  final int number;
}

/// `{slug}/G{n}`, which may name a slug the command does not replay.
final class _QualifiedId extends _Id {
  const _QualifiedId(this.ref);

  final GuaranteeRef ref;
}

/// [text] as a bare `G{n}`, or as `{slug}/G{n}` split at its first `/` with a
/// non-empty slug; null when it is neither.
_Id? _readId(String text) {
  final int slash = text.indexOf('/');
  if (slash < 0) {
    final int? number = parseGuaranteeId(text);
    return number == null ? null : _BareId(text, number);
  }
  final String slug = text.substring(0, slash);
  final int? number = parseGuaranteeId(text.substring(slash + 1));
  return slug.isEmpty || number == null
      ? null
      : _QualifiedId((slug: slug, number: number));
}

/// The guarantee [id] names, a bare id resolved to the one replayed slug.
GuaranteeRef _resolve(_Id id, List<String> replayed) => switch (id) {
  _BareId(:final int number) => (slug: replayed.single, number: number),
  _QualifiedId(:final GuaranteeRef ref) => ref,
};

/// Check 1: a slug or `--all`, and never both.
String? _slugCountError(bool all, List<String> named) =>
    switch ((all, named.isEmpty)) {
      (false, true) => 'name a slug or --all',
      (true, false) => '--all takes no slug',
      _ => null,
    };

/// Check 2: every named slug has a fixture directory.
String? _unknownSlugError(List<String> named, Set<String> slugs) => named
    .where((String slug) => !slugs.contains(slug))
    .map(
      (String slug) =>
          "unknown slug '$slug': no directory hsdd/contract/fixture/$slug/",
    )
    .firstOrNull;

/// Check 3: every `--set` value names a [CheckSet].
String? _setError(List<String> setNames) => setNames
    .where((String name) => !_knownSetNames.contains(name))
    .map(
      (String name) =>
          "unknown set '$name'; the sets are ${_knownSetNames.join(', ')}",
    )
    .firstOrNull;

/// Check 4: every `--guarantee` value reads as an id, and a qualified id
/// names a slug that has a fixture directory.
String? _idError(List<String> idTexts, Set<String> slugs) => idTexts
    .map(
      (String text) => switch (_readId(text)) {
        null => "malformed guarantee id '$text'; write G{n} or {slug}/G{n}",
        _QualifiedId(:final GuaranteeRef ref) when !slugs.contains(ref.slug) =>
          "unknown slug '${ref.slug}' in '$text'",
        _BareId() || _QualifiedId() => null,
      },
    )
    .nonNulls
    .firstOrNull;

/// Check 5: a bare id only when the command replays exactly one slug.
String? _bareIdError(List<_Id> ids, int replayedCount) => replayedCount == 1
    ? null
    : ids
          .whereType<_BareId>()
          .map(
            (_BareId id) =>
                "bare id '${id.text}' names no single slug: "
                'the command replays $replayedCount slugs; write {slug}/${id.text}',
          )
          .firstOrNull;
