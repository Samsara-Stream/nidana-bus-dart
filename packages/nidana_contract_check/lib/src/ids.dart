/// Guarantee ids and `{ids}` lists (ADR-001 item 3).
///
/// An id is `G` and a positive decimal number without a leading zero. A range
/// is `G{a} to G{b}` with `a < b`. A list is ids and ranges separated by `, `
/// or ` and `. Nothing here trims: callers pass exact text.
library;

final RegExp _id = RegExp(r'^G([1-9][0-9]*)$');
final RegExp _range = RegExp(r'^G([1-9][0-9]*) to G([1-9][0-9]*)$');
final RegExp _separator = RegExp(', | and ');

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

/// `G{n}` for each of [ids] in ascending order, joined by `, `.
String formatIds(Iterable<int> ids) =>
    (ids.toList()..sort()).map((int id) => 'G$id').join(', ');

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
  if (first == null || last == null || first >= last) {
    return null;
  }
  return <int>{for (int id = first; id <= last; id++) id};
}
