// Prototype of the two `structure` checks amended ADR-001 adds or widens,
// experiment only: item 3's coverage (reject headers, behavior case names, the
// `covers {ids}.` ending of a `- schema:` or `- file:` bullet, the invocation
// table's `Covers` cells, not-executable lines) and item 9's layout (set
// directories of the contract's kind, data directories listed by a bullet
// `- {dir}: `hsdd/contract/fixture/{slug}/{dir}/``). Run from the repository
// root over the nine contracts as they stand:
//
//   fvm dart run docs/auto-run/experiments/file-invocations/structure_check.dart
import 'dart:io';

final RegExp _idOrRange = RegExp(r'^G(\d+)(?: to G(\d+))?$');

/// Parses `{ids}`: ids `G{n}` and ranges `G{a} to G{b}`, separated by `, ` or ` and `.
Set<int>? parseIds(String text) {
  final Set<int> out = <int>{};
  for (final String part in text.trim().split(RegExp(r', | and '))) {
    final RegExpMatch? m = _idOrRange.firstMatch(part.trim());
    if (m == null) return null;
    final int a = int.parse(m.group(1)!);
    final int b = m.group(2) == null ? a : int.parse(m.group(2)!);
    for (int i = a; i <= b; i++) {
      out.add(i);
    }
  }
  return out;
}

String section(String text, String heading) {
  final int start = text.indexOf('\n## $heading');
  if (start < 0) return '';
  final int end = text.indexOf('\n## ', start + 4);
  return text.substring(start, end < 0 ? text.length : end);
}

const Map<String, Set<String>> setDirs = <String, Set<String>>{
  'api': <String>{'surface', 'reject', 'behavior', 'valid', 'invalid'},
  'shared-model': <String>{'surface', 'reject', 'behavior', 'valid', 'invalid'},
  'schema': <String>{'valid', 'invalid'},
  'file': <String>{'input', 'expected', 'valid', 'invalid', 'invocation'},
  'cli': <String>{'invocation'},
};

void main() {
  int problems = 0;
  void problem(String s) {
    problems++;
    stdout.writeln('  PROBLEM $s');
  }

  final List<File> contracts = Directory('hsdd/contract')
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.md') && !f.path.endsWith('INDEX.md'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File c in contracts) {
    final String text = c.readAsStringSync();
    final String slug = RegExp(r'^id: (\S+)$', multiLine: true).firstMatch(text)!.group(1)!;
    final String kind = RegExp(r'^kind: (\S+)$', multiLine: true).firstMatch(text)!.group(1)!;
    final Set<int> guarantees = RegExp(r'^- \*\*G(\d+)\*\*', multiLine: true)
        .allMatches(section(text, 'Guarantees'))
        .map((RegExpMatch m) => int.parse(m.group(1)!))
        .toSet();
    final String validation = section(text, 'Validation');
    final String dir = 'hsdd/contract/fixture/$slug';
    final Map<String, Set<int>> covered = <String, Set<int>>{};
    void cover(String by, Set<int> ids) => covered.putIfAbsent(by, () => <int>{}).addAll(ids);

    // item 9 layout
    final Set<String> listedData = RegExp('^- ([a-z_-]+): `${RegExp.escape(dir)}/([a-z_-]+)/`', multiLine: true)
        .allMatches(validation)
        .where((RegExpMatch m) => m.group(1) == m.group(2))
        .map((RegExpMatch m) => m.group(1)!)
        .toSet();
    final List<String> entries = Directory(dir).existsSync()
        ? (Directory(dir).listSync().map((FileSystemEntity e) => e.path.split('/').last).toList()..sort())
        : <String>[];
    final List<String> dataDirs = <String>[];
    for (final String e in entries) {
      final bool isDir = FileSystemEntity.isDirectorySync('$dir/$e');
      if (isDir && setDirs[kind]!.contains(e)) continue;
      if (isDir && listedData.contains(e)) {
        dataDirs.add(e);
        continue;
      }
      problem('$slug: $e is neither a set directory of kind $kind nor a data directory listed in Validation');
    }
    for (final String d in listedData.difference(setDirs[kind]!)) {
      if (!entries.contains(d)) problem('$slug: data directory $d is listed but absent');
    }

    // item 3 coverage: reject headers and behavior case names
    for (final FileSystemEntity f in Directory('$dir/reject').existsSync() ? Directory('$dir/reject').listSync() : <FileSystemEntity>[]) {
      final RegExpMatch? m = RegExp(r'^// covers: (.+)$', multiLine: true).firstMatch(File(f.path).readAsStringSync());
      final Set<int>? ids = m == null ? null : parseIds(m.group(1)!);
      if (ids == null) {
        problem('$slug: ${f.path} has no parsable // covers: header');
      } else {
        cover('reject', ids);
      }
    }
    for (final FileSystemEntity f in Directory('$dir/behavior').existsSync() ? Directory('$dir/behavior').listSync() : <FileSystemEntity>[]) {
      if (!f.path.endsWith('_conformance.dart')) continue;
      cover('behavior', RegExp(r"name: 'G(\d+) ").allMatches(File(f.path).readAsStringSync()).map((RegExpMatch m) => int.parse(m.group(1)!)).toSet());
    }
    // `- schema:` and `- file:` bullets ending in `covers {ids}.`
    for (final RegExpMatch m in RegExp(r'^- (schema|file): (.*)$', multiLine: true).allMatches(validation)) {
      final RegExpMatch? end = RegExp(r'covers ([^.;:]+)\.$').firstMatch(m.group(2)!);
      if (end == null) continue;
      final Set<int>? ids = parseIds(end.group(1)!);
      if (ids == null) {
        problem('$slug: ${m.group(1)} bullet ends in an unparsable covers clause: ${end.group(1)}');
      } else {
        cover(m.group(1)!, ids);
      }
    }
    // the invocation table
    final List<String> lines = validation.split('\n');
    final int header = lines.indexWhere((String l) => l.startsWith('| Case |'));
    final Set<String> rows = <String>{};
    if (header >= 0) {
      final List<String> cols = lines[header].split('|').map((String s) => s.trim()).toList();
      final int coversCol = cols.indexOf('Covers');
      for (final String row in lines.skip(header + 2).takeWhile((String l) => l.startsWith('|'))) {
        final List<String> cells = row.split('|').map((String s) => s.trim()).toList();
        final String name = cells[1].replaceAll('`', '');
        rows.add(name);
        final String coverText = cells[coversCol].split(': ').first;
        final Set<int>? ids = parseIds(coverText);
        if (ids == null) {
          problem('$slug: invocation $name has an unparsable Covers cell: ${cells[coversCol]}');
        } else {
          cover('cli', ids);
        }
      }
    }
    final Set<String> caseDirs = Directory('$dir/invocation').existsSync()
        ? Directory('$dir/invocation').listSync().whereType<Directory>().map((Directory d) => d.path.split('/').last).toSet()
        : <String>{};
    for (final String d in caseDirs.difference(rows)) {
      problem('$slug: invocation/$d has no row in the invocation table');
    }
    for (final String r in rows.difference(caseDirs)) {
      problem('$slug: table row $r has no invocation directory');
    }
    // not-executable lines, whole or in part
    final Set<int> notExecutable = <int>{};
    final Set<int> partial = <int>{};
    for (final RegExpMatch m in RegExp(r"^- not executable: G(\d+)('s)?.*checked by (\S+)'s gates", multiLine: true).allMatches(validation)) {
      final int id = int.parse(m.group(1)!);
      (m.group(2) == null ? notExecutable : partial).add(id);
    }
    final Set<int> all = <int>{for (final Set<int> s in covered.values) ...s};
    final Set<int> uncovered = guarantees.difference(all).difference(notExecutable);
    final Set<int> unknown = <int>{...all, ...notExecutable, ...partial}.difference(guarantees);
    for (final int g in partial) {
      if (!all.contains(g)) problem('$slug: G$g is marked executable in part but nothing covers it');
    }
    final String by = covered.entries.map((MapEntry<String, Set<int>> e) => '${e.key} ${e.value.length}').join(', ');
    stdout.writeln('$slug ($kind): ${guarantees.length} guarantees; covered by $by; not executable ${notExecutable.length}; in part ${partial.length}; data directories ${dataDirs.isEmpty ? 'none' : dataDirs.join(', ')}');
    if (uncovered.isNotEmpty) problem('$slug: uncovered ${uncovered.map((int g) => 'G$g').join(', ')}');
    if (unknown.isNotEmpty) problem('$slug: ids with no guarantee ${unknown.map((int g) => 'G$g').join(', ')}');
  }
  stdout.writeln('${contracts.length} contracts, $problems problem(s)');
  exit(problems == 0 ? 0 : 1);
}
