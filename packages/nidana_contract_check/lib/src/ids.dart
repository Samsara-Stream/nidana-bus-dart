/// Guarantee ids and `{ids}` lists (ADR-001 item 3).
///
/// An id is `G` and a positive decimal number without a leading zero. A range
/// is `G{a} to G{b}` with `a < b`. A list is ids and ranges separated by `, `
/// or ` and `. Nothing here trims: callers pass exact text.
///
/// The replay reads a range only when it holds at most 1000 ids
/// (`b - a < 1000`), and rejects a wider one before expanding anything, so a
/// typo such as `G1 to G100000000` makes a list malformed instead of hanging
/// the replay.
library;

final RegExp _id = RegExp(r'^G([1-9][0-9]*)$');
final RegExp _range = RegExp(r'^G([1-9][0-9]*) to G([1-9][0-9]*)$');
final RegExp _separator = RegExp(', | and ');

/// The most ids one range holds.
const int _rangeIds = 1000;

/// The number of [text] when it is exactly one `G{n}`, else null.
int? parseGuaranteeId(String text) {
  final Match? match = _id.firstMatch(text);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// The numbers of an `{ids}` list, or null when [text] is not one.
Set<int>? parseIdList(String text) {
  final List<Set<int>?> parts = text
      .split(_separator)
      .map(_parsePart)
      .toList(growable: false);
  if (parts.any((Set<int>? part) => part == null)) {
    return null;
  }
  return <int>{for (final Set<int>? part in parts) ...part!};
}

/// Each of [ids] once, in ascending order, joined by `, `: a maximal run of
/// three or more consecutive ids as `G{a} to G{b}`, every other id as `G{n}`.
///
/// A run of more than 1000 ids prints as several ranges, so [parseIdList]
/// reads every result back except the empty text of no ids.
String formatIds(Iterable<int> ids) => <String>[
  for (final (int first, int last) in _runs(ids.toSet().toList()..sort()))
    ..._pieces(first, last),
].join(', ');

/// The numbers of one id or one range, or null when [part] is neither.
Set<int>? _parsePart(String part) {
  final int? single = parseGuaranteeId(part);
  if (single != null) {
    return <int>{single};
  }
  final Match? range = _range.firstMatch(part);
  if (range == null) {
    return null;
  }
  final int? first = int.tryParse(range.group(1)!);
  final int? last = int.tryParse(range.group(2)!);
  if (first == null ||
      last == null ||
      first >= last ||
      last - first >= _rangeIds) {
    return null;
  }
  return <int>{for (int id = first; id <= last; id++) id};
}

/// The maximal runs of consecutive ids in [sorted], which ascends without
/// repeats, each as its first and its last id.
Iterable<(int, int)> _runs(List<int> sorted) sync* {
  int start = 0;
  for (int index = 1; index <= sorted.length; index++) {
    if (index == sorted.length || sorted[index] != sorted[index - 1] + 1) {
      yield (sorted[start], sorted[index - 1]);
      start = index;
    }
  }
}

/// The run from [first] to [last] as list parts: ranges of at most
/// [_rangeIds] ids, and single ids for a piece of fewer than three.
Iterable<String> _pieces(int first, int last) sync* {
  for (int start = first; start <= last; start += _rangeIds) {
    final int end = last - start < _rangeIds ? last : start + _rangeIds - 1;
    if (end - start >= 2) {
      yield 'G$start to G$end';
    } else {
      yield* <String>[for (int id = start; id <= end; id++) 'G$id'];
    }
  }
}
