/// The contract reader: a contract text's frontmatter, its guarantee ids
/// (ADR-001 item 3) and the forms of its `## Validation` section, read as
/// values.
///
/// The reader is total. It never throws, and it keeps a malformed form as a
/// value for the `structure` set to judge rather than rejecting it.
library;

import 'ids.dart';

/// The kinds of ADR-001 item 1, with the set directories items 4 to 7 give each.
enum ContractKind {
  api('api', <String>{'surface', 'reject', 'behavior', 'valid', 'invalid'}),
  sharedModel('shared-model', <String>{'surface', 'reject', 'behavior'}),
  schema('schema', <String>{'valid', 'invalid'}),
  file('file', <String>{'input', 'expected', 'valid', 'invalid', 'invocation'}),
  cli('cli', <String>{'invocation'});

  const ContractKind(this.label, this.setDirectories);

  /// The frontmatter `kind` value that names this kind.
  final String label;

  /// The fixture directories this kind's sets read.
  final Set<String> setDirectories;

  /// The kind that [label] names; null when it names none, or is null.
  static ContractKind? byLabel(String? label) =>
      values.where((ContractKind kind) => kind.label == label).firstOrNull;
}

/// A `- schema:` or `- file:` bullet that ends with `covers {text}.`
final class CoversClause {
  const CoversClause({
    required this.bullet,
    required this.text,
    required this.ids,
  });

  /// `schema` or `file`.
  final String bullet;

  /// The text between `covers ` and the final `.`.
  final String text;

  /// The numbers of [text]; null when [text] is not an `{ids}` list.
  final Set<int>? ids;
}

/// A row of the recorded-invocation table.
final class InvocationRow {
  const InvocationRow({
    required this.caseName,
    required this.covers,
    required this.ids,
  });

  /// The name in the Case cell; null when that cell is not one backticked name.
  final String? caseName;

  /// The Covers cell, trimmed; empty when the table has no Covers column.
  final String covers;

  /// The `{ids}` list [covers] begins with; null when it is malformed.
  final Set<int>? ids;
}

/// A `- not executable:` line (ADR-001 item 3).
final class NotExecutableLine {
  const NotExecutableLine({
    required this.text,
    required this.id,
    required this.partial,
    required this.node,
  });

  /// The whole line.
  final String text;

  /// The number of the `G{n}` the line begins with; null when none.
  final int? id;

  /// Whether the line reads `G{n}'s {part}, ...` rather than `G{n}, ...`.
  final bool partial;

  /// The node of `; checked by {node}'s gates`; null when that clause is absent.
  final String? node;
}

/// What [readContract] reads from one contract text.
final class ContractText {
  const ContractText({
    required this.id,
    required this.kindLabel,
    required this.guarantees,
    required this.malformedGuarantees,
    required this.bindings,
    required this.listedDirectories,
    required this.coversClauses,
    required this.invocationRows,
    required this.notExecutable,
  });

  /// The frontmatter `id`; null when the text has no frontmatter or no `id`.
  final String? id;

  /// The frontmatter `kind`, as written; null when absent.
  final String? kindLabel;

  /// The numbers of the `- **G{n}** ` entries, in order, repeats kept.
  final List<int> guarantees;

  /// The other `- ` lines of `## Guarantees / invariants`, whole.
  final List<String> malformedGuarantees;

  /// The paths of the `- binding:` bullets, in order.
  final List<String> bindings;

  /// The `{dir}` of each `` - {dir}: `hsdd/contract/fixture/{slug}/{dir}/` ``
  /// bullet, set directories included (ADR-001 item 9's data-directory bullet).
  final Set<String> listedDirectories;

  /// The `covers` clauses of the `- schema:` and `- file:` bullets, in order.
  final List<CoversClause> coversClauses;

  /// The rows of the recorded-invocation table, in order.
  final List<InvocationRow> invocationRows;

  /// The `- not executable:` lines, in order.
  final List<NotExecutableLine> notExecutable;

  /// The kind [kindLabel] names; null when it names none.
  ContractKind? get kind => ContractKind.byLabel(kindLabel);
}

/// Reads [text], the contract text of [slug], as a [ContractText].
///
/// `\r\n` reads as `\n`. Only the frontmatter and the lines of the
/// `## Guarantees / invariants` and `## Validation` sections are read.
ContractText readContract(String slug, String text) {
  final List<String> lines = text.replaceAll('\r\n', '\n').split('\n');
  final List<String> frontmatter = _frontmatter(lines);
  final List<(String, int?)> entries = <(String, int?)>[
    for (final String line in _section(lines, '## Guarantees / invariants'))
      if (line.startsWith('- ')) (line, _guaranteeId(line)),
  ];
  final List<String> validation = _section(lines, '## Validation');
  return ContractText(
    id: _field(frontmatter, 'id'),
    kindLabel: _field(frontmatter, 'kind'),
    guarantees: List<int>.unmodifiable(<int>[
      for (final (_, int? id) in entries) ?id,
    ]),
    malformedGuarantees: List<String>.unmodifiable(<String>[
      for (final (String line, int? id) in entries)
        if (id == null) line,
    ]),
    bindings: List<String>.unmodifiable(<String>[
      for (final String line in validation)
        ?_binding.firstMatch(line)?.group(1),
    ]),
    listedDirectories: Set<String>.unmodifiable(
      _listedDirectories(slug, validation),
    ),
    coversClauses: List<CoversClause>.unmodifiable(<CoversClause>[
      for (final String line in validation) ?_coversClause(line),
    ]),
    invocationRows: List<InvocationRow>.unmodifiable(
      _invocationRows(validation),
    ),
    notExecutable: List<NotExecutableLine>.unmodifiable(<NotExecutableLine>[
      for (final String line in validation)
        if (line.startsWith('- not executable: ')) _notExecutable(line),
    ]),
  );
}

final RegExp _guarantee = RegExp(r'^- \*\*G([1-9][0-9]*)\*\* ');
final RegExp _binding = RegExp(r'^- binding: `([^`]+)`');
final RegExp _coversBullet = RegExp(r'^- (schema|file): ');
final RegExp _covers = RegExp(r'\bcovers ([^.]*)\.$');
final RegExp _tableHeader = RegExp(r'^\|\s*Case\s*\|');
final RegExp _caseName = RegExp(r'^`([^`]+)`$');
final RegExp _notExecutableHead = RegExp(
  r"^- not executable: G([1-9][0-9]*)('s |, )",
);
final RegExp _checkedBy = RegExp(r"; checked by (\S+)'s gates");

/// The lines between a first line `---` and the next `---` line; none when
/// the text does not open with `---` or the block is never closed.
List<String> _frontmatter(List<String> lines) {
  if (lines.first != '---') {
    return const <String>[];
  }
  final int end = lines.indexOf('---', 1);
  return end < 0 ? const <String>[] : lines.sublist(1, end);
}

/// The trimmed value of the first frontmatter line beginning `{key}: `.
String? _field(List<String> frontmatter, String key) => frontmatter
    .where((String line) => line.startsWith('$key: '))
    .map((String line) => line.substring(key.length + 2).trim())
    .firstOrNull;

/// The lines after the first line exactly [heading], up to the next line
/// beginning `## `; none when no line is [heading].
List<String> _section(List<String> lines, String heading) {
  final int start = lines.indexOf(heading);
  return start < 0
      ? const <String>[]
      : lines
            .skip(start + 1)
            .takeWhile((String line) => !line.startsWith('## '))
            .toList(growable: false);
}

/// The number of a `- **G{n}** ` entry; null when [line] is not one, or when
/// its number does not fit an `int`.
int? _guaranteeId(String line) {
  final String? digits = _guarantee.firstMatch(line)?.group(1);
  return digits == null ? null : int.tryParse(digits);
}

/// The `{dir}` names of the data-directory bullets of [slug] in [validation].
Set<String> _listedDirectories(String slug, List<String> validation) {
  final RegExp bullet = RegExp(
    '^- ([a-z0-9_-]+): `hsdd/contract/fixture/${RegExp.escape(slug)}'
    '/([a-z0-9_-]+)/`',
  );
  return <String>{
    for (final String line in validation)
      if (bullet.firstMatch(line) case final RegExpMatch match
          when match.group(1) == match.group(2))
        match.group(1)!,
  };
}

/// The clause of a `- schema:` or `- file:` bullet that ends with
/// `covers {text}.`; null for any other line.
CoversClause? _coversClause(String line) {
  final String? bullet = _coversBullet.firstMatch(line)?.group(1);
  final String? text = _covers.firstMatch(line)?.group(1);
  return bullet == null || text == null
      ? null
      : CoversClause(
          bullet: bullet,
          text: text,
          ids: _unmodifiable(parseIdList(text)),
        );
}

/// The rows of the first table in [validation] whose header's first cell is
/// `Case`: every line beginning `|` after the header and its separator row.
Iterable<InvocationRow> _invocationRows(List<String> validation) {
  final int header = validation.indexWhere(_tableHeader.hasMatch);
  if (header < 0) {
    return const <InvocationRow>[];
  }
  final int coversColumn = _cells(validation[header]).indexOf('Covers');
  return validation
      .skip(header + 2)
      .takeWhile((String line) => line.startsWith('|'))
      .map((String line) => _invocationRow(_cells(line), coversColumn));
}

/// The cells of a table line split on `|`, trimmed. Every line read here
/// begins with `|`, so there are at least two cells: cell 0 is the empty text
/// before that `|`, and the Case cell is cell 1.
List<String> _cells(String line) =>
    line.split('|').map((String cell) => cell.trim()).toList(growable: false);

/// One row from its [cells]; [coversColumn] is -1 when the table has none.
InvocationRow _invocationRow(List<String> cells, int coversColumn) {
  final String covers = coversColumn >= 0 && coversColumn < cells.length
      ? cells[coversColumn]
      : '';
  return InvocationRow(
    caseName: _caseName.firstMatch(cells[1])?.group(1),
    covers: covers,
    ids: _unmodifiable(parseIdList(covers.split(': ').first)),
  );
}

/// A `- not executable: ` line read as a [NotExecutableLine].
NotExecutableLine _notExecutable(String line) {
  final RegExpMatch? head = _notExecutableHead.firstMatch(line);
  final int? id = head == null ? null : int.tryParse(head.group(1)!);
  return NotExecutableLine(
    text: line,
    id: id,
    partial: id != null && head!.group(2) == "'s ",
    node: _checkedBy.firstMatch(line)?.group(1),
  );
}

/// [ids] as a set nothing can change; null stays null.
Set<int>? _unmodifiable(Set<int>? ids) =>
    ids == null ? null : Set<int>.unmodifiable(ids);
