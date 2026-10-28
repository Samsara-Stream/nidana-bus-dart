// Prototype of the `structure` set as docs/superpowers/plans/nidana.model.1.md
// specifies it (S99), experiment only. It differs from the two earlier
// prototypes (file-invocations/structure_check.dart,
// topology-ir-fixtures/packages/nidana_contract_check/bin/structure_check.dart)
// in the rules the plan fixes:
//   - behavior case names are read from the exported List<ConformanceCase<H>>
//     by a small Dart scanner (strings, comments, brackets), as the `name`
//     field of each record literal, never by matching `name:` text;
//   - {ids} follow ADR-001 item 3's grammar strictly (G{n} with no leading
//     zero, ranges G{a} to G{b} with a < b, separators ", " and " and ");
//   - every not-executable line, whole ("G{n}, ...") or partial
//     ("G{n}'s ..."), must end its reason with "; checked by {node}'s
//     gates" (ADR-001 item 3 as written; the orchestrator's ruling on S99
//     decision 8); a whole line counts as coverage, a partial one does not
//     (LENIENT=1 in the environment restores the first draft's reading, in
//     which a partial line may omit the clause);
//   - the reject header is the leading comment block; a marker must sit on
//     its own line and be followed by a line that is neither blank nor a
//     comment;
//   - every id a header, case name, covers clause, Covers cell or
//     not-executable line cites must be a declared guarantee;
//   - set directories per kind follow items 4 to 7 literally (shared-model
//     gets no valid/ or invalid/).
// Run from a workspace root: fvm dart run <path>/structure_proto.dart [slug...]
import 'dart:io';

// ---------------------------------------------------------------- ids
final RegExp _idRe = RegExp(r'^G([1-9][0-9]*)$');
final RegExp _rangeRe = RegExp(r'^G([1-9][0-9]*) to G([1-9][0-9]*)$');

Set<int>? parseIds(String text) {
  if (text.isEmpty) return null;
  final Set<int> out = <int>{};
  for (final String part in text.split(RegExp(r', | and '))) {
    final RegExpMatch? one = _idRe.firstMatch(part);
    final RegExpMatch? range = _rangeRe.firstMatch(part);
    if (one != null) {
      out.add(int.parse(one.group(1)!));
    } else if (range != null) {
      final int a = int.parse(range.group(1)!);
      final int b = int.parse(range.group(2)!);
      if (a >= b) return null;
      for (int i = a; i <= b; i++) {
        out.add(i);
      }
    } else {
      return null;
    }
  }
  return out;
}

// ---------------------------------------------------------------- scanner
enum K { ident, string, punct, other }

final class Tok {
  Tok(this.kind, this.text, {this.value, this.line = 0});
  final K kind;
  final String text;
  final String? value; // decoded string value, null when interpolated
  final int line;
  @override
  String toString() => '$kind:$text';
}

final class Scanner {
  Scanner(this.s);
  final String s;
  int i = 0;

  bool _at(String p) => s.startsWith(p, i);
  int get _line => '\n'.allMatches(s.substring(0, i)).length + 1;

  List<Tok> scan({bool untilBrace = false}) {
    final List<Tok> out = <Tok>[];
    int braces = 0;
    while (i < s.length) {
      final String c = s[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        i++;
      } else if (_at('//')) {
        while (i < s.length && s[i] != '\n') {
          i++;
        }
      } else if (_at('/*')) {
        int d = 0;
        while (i < s.length) {
          if (_at('/*')) {
            d++;
            i += 2;
          } else if (_at('*/')) {
            d--;
            i += 2;
            if (d == 0) break;
          } else {
            i++;
          }
        }
      } else if (c == "'" || c == '"') {
        out.add(_string(raw: false));
      } else if (c == 'r' && i + 1 < s.length && (s[i + 1] == "'" || s[i + 1] == '"')) {
        i++;
        out.add(_string(raw: true));
      } else if (RegExp(r'[A-Za-z_$]').hasMatch(c)) {
        final int st = i;
        while (i < s.length && RegExp(r'[A-Za-z0-9_$]').hasMatch(s[i])) {
          i++;
        }
        out.add(Tok(K.ident, s.substring(st, i)));
      } else if (RegExp(r'[0-9]').hasMatch(c)) {
        final int st = i;
        while (i < s.length && RegExp(r'[0-9A-Za-z_.]').hasMatch(s[i])) {
          i++;
        }
        out.add(Tok(K.other, s.substring(st, i)));
      } else {
        if (untilBrace) {
          if (c == '{') braces++;
          if (c == '}') {
            if (braces == 0) {
              i++;
              return out;
            }
            braces--;
          }
        }
        out.add(Tok(K.punct, c, line: _line));
        i++;
      }
    }
    return out;
  }

  Tok _string({required bool raw}) {
    final int line = _line;
    final String q = _at("'''")
        ? "'''"
        : _at('"""')
            ? '"""'
            : s[i];
    final int st = i;
    i += q.length;
    final StringBuffer v = StringBuffer();
    bool interpolated = false;
    while (i < s.length && !_at(q)) {
      final String c = s[i];
      if (!raw && c == r'\') {
        final String n = i + 1 < s.length ? s[i + 1] : '';
        v.write(switch (n) { 'n' => '\n', 't' => '\t', 'r' => '\r', _ => n });
        i += 2;
      } else if (!raw && c == r'$') {
        interpolated = true;
        if (i + 1 < s.length && s[i + 1] == '{') {
          i += 2;
          scan(untilBrace: true);
        } else {
          i++;
          while (i < s.length && RegExp(r'[A-Za-z0-9_]').hasMatch(s[i])) {
            i++;
          }
        }
      } else {
        v.write(c);
        i++;
      }
    }
    i += q.length;
    return Tok(K.string, s.substring(st, i.clamp(0, s.length)), value: interpolated ? null : v.toString(), line: line);
  }
}

// ---------------------------------------------------------------- case lists
final class CaseList {
  CaseList(this.name);
  final String name;
  final List<String?> names = <String?>[]; // null: not a string literal
  final List<String> problems = <String>[];
}

const Map<String, String> _close = <String, String>{'(': ')', '[': ']', '{': '}'};

int _matchAngle(List<Tok> t, int i) {
  // t[i] is '<'; returns the index after the matching '>'
  int d = 0;
  for (; i < t.length; i++) {
    if (t[i].text == '<') d++;
    if (t[i].text == '>') {
      d--;
      if (d == 0) return i + 1;
    }
  }
  return t.length;
}

int _matchBracket(List<Tok> t, int i) {
  // t[i] is an opening bracket; returns the index of its closing one
  int d = 0;
  for (; i < t.length; i++) {
    if (t[i].kind != K.punct) continue;
    if (_close.containsKey(t[i].text)) d++;
    if (_close.containsValue(t[i].text)) {
      d--;
      if (d == 0) return i;
    }
  }
  return t.length - 1;
}

List<CaseList> readCaseLists(String source) {
  final List<Tok> t = Scanner(source).scan();
  final List<CaseList> lists = <CaseList>[];
  int i = 0;
  while (i < t.length) {
    final Tok k = t[i];
    if (k.kind == K.punct && _close.containsKey(k.text)) {
      i = _matchBracket(t, i) + 1; // skip anything nested: only top level declares
      continue;
    }
    int? afterEq;
    String? name;
    if (k.text == 'List' && i + 2 < t.length && t[i + 1].text == '<' && t[i + 2].text == 'ConformanceCase') {
      final int j = _matchAngle(t, i + 1);
      if (j + 1 < t.length && t[j].kind == K.ident && t[j + 1].text == '=') {
        name = t[j].text;
        afterEq = j + 2;
      }
    } else if (k.kind == K.ident && i + 3 < t.length && t[i + 1].text == '=' && t[i + 2].text == '<' && t[i + 3].text == 'ConformanceCase') {
      name = k.text;
      afterEq = i + 2;
    }
    if (afterEq == null) {
      i++;
      continue;
    }
    int j = afterEq;
    if (j < t.length && t[j].text == '<') j = _matchAngle(t, j);
    final CaseList list = CaseList(name!);
    lists.add(list);
    if (j >= t.length || t[j].text != '[') {
      list.problems.add('$name is not initialized by a list literal');
      i = j;
      continue;
    }
    final int end = _matchBracket(t, j);
    int e = j + 1;
    while (e < end) {
      if (t[e].text == 'const') e++;
      if (t[e].text != '(') {
        list.problems.add('line ${t[e].line}: an element of $name is not a record literal');
        while (e < end && t[e].text != ',') {
          e = t[e].kind == K.punct && _close.containsKey(t[e].text) ? _matchBracket(t, e) + 1 : e + 1;
        }
        e++;
        continue;
      }
      final int rEnd = _matchBracket(t, e);
      bool found = false;
      int f = e + 1;
      while (f < rEnd) {
        if (t[f].kind == K.ident && t[f + 1].text == ':' && t[f].text == 'name') {
          found = true;
          int g = f + 2;
          final List<Tok> expr = <Tok>[];
          while (g < rEnd && t[g].text != ',') {
            if (t[g].kind == K.punct && _close.containsKey(t[g].text)) {
              final int m = _matchBracket(t, g);
              expr.addAll(t.sublist(g, m + 1));
              g = m + 1;
            } else {
              expr.add(t[g++]);
            }
          }
          final bool literal = expr.isNotEmpty && expr.every((Tok x) => x.kind == K.string && x.value != null);
          list.names.add(literal ? expr.map((Tok x) => x.value).join() : null);
          f = g;
        } else if (t[f].kind == K.punct && _close.containsKey(t[f].text)) {
          f = _matchBracket(t, f) + 1;
        } else {
          f++;
        }
      }
      if (!found) list.problems.add('line ${t[e].line}: a record of $name has no name field');
      e = rEnd + 1;
      if (e < end && t[e].text == ',') e++;
    }
    i = end + 1;
  }
  return lists;
}

List<String> readDirectives(String source) {
  final List<Tok> t = Scanner(source).scan();
  final List<String> uris = <String>[];
  for (int i = 0; i + 1 < t.length; i++) {
    if ((t[i].text == 'import' || t[i].text == 'export') && t[i + 1].kind == K.string) {
      uris.add(t[i + 1].value ?? t[i + 1].text);
    }
    if (t[i].kind == K.punct && _close.containsKey(t[i].text)) break; // directives precede declarations
  }
  return uris;
}

// ---------------------------------------------------------------- contract text
String section(String text, String heading) {
  final List<String> lines = text.split('\n');
  final int start = lines.indexOf('## $heading');
  if (start < 0) return '';
  final int end = lines.indexWhere((String l) => l.startsWith('## '), start + 1);
  return lines.sublist(start + 1, end < 0 ? lines.length : end).join('\n');
}

const Map<String, Set<String>> setDirs = <String, Set<String>>{
  'api': <String>{'surface', 'reject', 'behavior', 'valid', 'invalid'},
  'shared-model': <String>{'surface', 'reject', 'behavior'},
  'schema': <String>{'valid', 'invalid'},
  'file': <String>{'input', 'expected', 'valid', 'invalid', 'invocation'},
  'cli': <String>{'invocation'},
};

final bool lenient = Platform.environment['LENIENT'] == '1';

int checkSlug(String slug, List<String> out) {
  final List<String> problems = <String>[];
  void p(String path, String rule, String detail) => problems.add('FAIL structure $path: $rule ($detail)');
  final String cPath = 'hsdd/contract/$slug.md';
  final String dir = 'hsdd/contract/fixture/$slug';
  final File cf = File(cPath);
  if (!cf.existsSync()) {
    p(cPath, 'contract-text', 'no contract text');
    out.addAll(problems);
    return problems.length;
  }
  final String text = cf.readAsStringSync();
  final List<String> fm = text.split('\n');
  final int fmEnd = fm.first == '---' ? fm.indexOf('---', 1) : -1;
  String? field(String k) => fmEnd < 0
      ? null
      : fm.sublist(1, fmEnd).where((String l) => l.startsWith('$k: ')).map((String l) => l.substring(k.length + 2).trim()).firstOrNull;
  final String? id = field('id');
  final String? kind = field('kind');
  if (id != slug) p(cPath, 'contract-text', 'frontmatter id is $id, expected $slug');
  if (!setDirs.containsKey(kind)) p(cPath, 'contract-text', 'unknown kind $kind');
  final List<int> declaredList = <int>[];
  for (final String l in section(text, 'Guarantees / invariants').split('\n').where((String l) => l.startsWith('- '))) {
    final RegExpMatch? m = RegExp(r'^- \*\*G([1-9][0-9]*)\*\* ').firstMatch(l);
    if (m == null) {
      p(cPath, 'contract-text', 'a guarantee entry does not begin with - **G{n}**: ${l.substring(0, l.length.clamp(0, 40))}');
    } else {
      declaredList.add(int.parse(m.group(1)!));
    }
  }
  final Set<int> declared = declaredList.toSet();
  if (declared.length != declaredList.length) p(cPath, 'contract-text', 'a guarantee id repeats');
  final String validation = section(text, 'Validation');
  final List<String> vLines = validation.split('\n');

  final Map<String, Set<int>> covered = <String, Set<int>>{};
  void cite(String path, String by, Set<int> ids) {
    final Set<int> unknown = ids.difference(declared);
    if (unknown.isNotEmpty) p(path, 'unknown-id', '${unknown.map((int g) => 'G$g').join(', ')} cited by $by');
    (covered[by] ??= <int>{}).addAll(ids.intersection(declared));
  }

  // covers clauses of - schema: and - file: bullets
  for (final String l in vLines.where((String l) => l.startsWith('- schema: ') || l.startsWith('- file: '))) {
    final RegExpMatch? m = RegExp(r'\bcovers ([^.]*)\.$').firstMatch(l);
    if (m == null) continue;
    final Set<int>? ids = parseIds(m.group(1)!);
    if (ids == null) {
      p(cPath, 'validation-form', 'malformed covers clause: covers ${m.group(1)}.');
    } else {
      cite(cPath, l.startsWith('- schema') ? 'schema' : 'file', ids);
    }
  }
  // not-executable lines
  int partial = 0;
  int whole = 0;
  for (final String l in vLines.where((String l) => l.startsWith('- not executable: '))) {
    final RegExpMatch? m = RegExp(r"^- not executable: G([1-9][0-9]*)('s |, )").firstMatch(l);
    final RegExpMatch? node = RegExp(r"; checked by (\S+)'s gates").firstMatch(l);
    if (m == null) {
      p(cPath, 'validation-form', 'malformed not-executable line: ${l.substring(0, 40)}');
      continue;
    }
    final int g = int.parse(m.group(1)!);
    final bool isPartial = m.group(2) == "'s ";
    if (node == null && (!isPartial || !lenient)) {
      p(cPath, 'validation-form', 'G$g not-executable line names no node (; checked by {node}\'s gates)');
      continue;
    }
    if (isPartial) {
      partial++;
      cite(cPath, 'not-executable-part', <int>{g});
      covered['not-executable-part']!.remove(g);
    } else {
      whole++;
      cite(cPath, 'not executable', <int>{g});
    }
  }
  // the invocation table
  final int header = vLines.indexWhere((String l) => RegExp(r'^\| *Case *\|').hasMatch(l));
  final Set<String> rows = <String>{};
  if (header >= 0) {
    final List<String> cols = vLines[header].split('|').map((String c) => c.trim()).toList();
    final int cc = cols.indexOf('Covers');
    for (final String row in vLines.skip(header + 2).takeWhile((String l) => l.startsWith('|'))) {
      final List<String> cells = row.split('|').map((String c) => c.trim()).toList();
      final RegExpMatch? nm = RegExp(r'^`([^`]+)`$').firstMatch(cells[1]);
      if (nm == null || cc < 0 || cc >= cells.length) {
        p(cPath, 'validation-form', 'malformed invocation row: ${row.substring(0, 40)}');
        continue;
      }
      rows.add(nm.group(1)!);
      final Set<int>? ids = parseIds(cells[cc].split(': ').first);
      if (ids == null) {
        p(cPath, 'validation-form', 'malformed Covers cell of ${nm.group(1)}: ${cells[cc]}');
      } else {
        cite(cPath, 'cli', ids);
      }
    }
  }
  // data directories and listed bindings
  final Set<String> listed = <String>{};
  for (final String l in vLines) {
    final RegExpMatch? m = RegExp('^- ([a-z0-9_-]+): `${RegExp.escape(dir)}/([a-z0-9_-]+)/`').firstMatch(l);
    if (m != null && m.group(1) == m.group(2)) listed.add(m.group(1)!);
  }
  final Set<String> bindings = <String>{};
  for (final String l in vLines) {
    final RegExpMatch? m = RegExp(r'^- binding: `([^`]+)`').firstMatch(l);
    if (m == null) continue;
    if (!RegExp('^${RegExp.escape(dir)}/behavior/[a-z0-9_]+_test\\.dart\$').hasMatch(m.group(1)!)) {
      p(cPath, 'binding', '${m.group(1)} is not a binding of this slug\'s behavior/');
    } else {
      bindings.add(m.group(1)!);
    }
  }
  final Set<String> kindDirs = setDirs[kind] ?? <String>{};
  final Set<String> dataDirs = listed.difference(kindDirs);
  final List<FileSystemEntity> top = Directory(dir).listSync()..sort((a, b) => a.path.compareTo(b.path));
  for (final FileSystemEntity e in top) {
    final String name = e.path.split('/').last;
    if (e is Directory && (kindDirs.contains(name) || dataDirs.contains(name))) continue;
    p('${e.path}${e is Directory ? '/' : ''}', 'layout', 'neither a set directory of kind $kind nor a data directory listed in ## Validation');
  }
  for (final String d in dataDirs) {
    if (!Directory('$dir/$d').existsSync()) p('$dir/$d/', 'layout', 'listed in ## Validation, absent');
  }
  // invocation directories against rows
  final Set<String> cases = Directory('$dir/invocation').existsSync()
      ? Directory('$dir/invocation').listSync().whereType<Directory>().map((Directory d) => d.path.split('/').last).toSet()
      : <String>{};
  for (final String c in cases.difference(rows)) {
    p('$dir/invocation/$c/', 'invocation-row', 'no row in the Case table');
  }
  for (final String r in rows.difference(cases)) {
    p('$dir/invocation/$r/', 'invocation-row', 'a row of the Case table, absent');
  }
  // Dart libraries
  int libs = 0;
  int caseCount = 0;
  final Set<String> presentBindings = <String>{};
  for (final String set in <String>['surface', 'reject', 'behavior']) {
    final Directory sd = Directory('$dir/$set');
    if (!sd.existsSync()) continue;
    final List<File> files = sd.listSync(recursive: true).whereType<File>().where((File f) => f.path.endsWith('.dart')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final File f in files) {
      libs++;
      final String src = f.readAsStringSync();
      for (final String u in readDirectives(src)) {
        if (RegExp(r'^package:[^/]+/src/').hasMatch(u)) p(f.path, 'src-import', u);
      }
      final List<String> lines = src.split('\n');
      if (set == 'reject') {
        final List<String> head = lines.takeWhile((String l) => l.trim().isEmpty || l.startsWith('//')).toList();
        final List<String> hs = head.where((String l) => l.startsWith('// covers:')).toList();
        if (hs.length != 1) {
          p(f.path, 'covers-header', hs.isEmpty ? 'no // covers: header' : 'more than one // covers: header');
        } else {
          final RegExpMatch? m = RegExp(r'^// covers: (.+)$').firstMatch(hs.single);
          final Set<int>? ids = m == null ? null : parseIds(m.group(1)!.trimRight());
          if (ids == null) {
            p(f.path, 'covers-header', 'malformed: ${hs.single}');
          } else {
            cite(f.path, 'reject', ids);
          }
        }
        int markers = 0;
        for (int i = 0; i < lines.length; i++) {
          if (!lines[i].contains('expect-diagnostic')) continue;
          if (!RegExp(r'^\s*// expect-diagnostic: [a-z][a-z0-9_]*\s*$').hasMatch(lines[i])) {
            p(f.path, 'marker', 'line ${i + 1} malformed');
            continue;
          }
          markers++;
          if (i + 1 >= lines.length || lines[i + 1].trim().isEmpty || lines[i + 1].trim().startsWith('//')) {
            p(f.path, 'marker', 'line ${i + 1} is not followed by a line of code');
          }
        }
        if (markers == 0) p(f.path, 'marker', 'no // expect-diagnostic: marker');
      }
      if (set == 'behavior' && f.path.endsWith('_conformance.dart')) {
        final List<CaseList> ls = readCaseLists(src).where((CaseList l) => !l.name.startsWith('_')).toList();
        if (ls.length != 1) {
          p(f.path, 'case-name', '${ls.length} public List<ConformanceCase> declarations, expected one');
        }
        for (final CaseList l in ls) {
          for (final String q in l.problems) {
            p(f.path, 'case-name', q);
          }
          for (final String? n in l.names) {
            final RegExpMatch? m = n == null ? null : RegExp(r'^G([1-9][0-9]*) ').firstMatch(n);
            if (m == null) {
              p(f.path, 'case-name', n == null ? 'a case name is not a string literal' : 'case name does not begin with G{n}: $n');
            } else {
              caseCount++;
              cite(f.path, 'behavior', <int>{int.parse(m.group(1)!)});
            }
          }
        }
      }
      if (set == 'behavior' && f.path.endsWith('_test.dart') && f.parent.path == sd.path) presentBindings.add(f.path);
    }
  }
  for (final String b in presentBindings.difference(bindings)) {
    p(b, 'binding', 'not listed in ## Validation');
  }
  for (final String b in bindings.difference(presentBindings)) {
    p(b, 'binding', 'listed in ## Validation, absent');
  }
  final Set<int> all = <int>{for (final MapEntry<String, Set<int>> e in covered.entries) if (e.key != 'not-executable-part') ...e.value};
  final Set<int> uncovered = declared.difference(all);
  if (uncovered.isNotEmpty) p('$dir/', 'coverage', '${(uncovered.toList()..sort()).map((int g) => 'G$g').join(', ')} uncovered');
  out.add('$slug ($kind): ${declared.length} guarantees, $caseCount cases, $libs libraries, ${bindings.length} bindings, '
      '${rows.length} invocation rows, not executable $whole whole and $partial in part, data directories ${dataDirs.isEmpty ? 'none' : dataDirs.join(', ')}');
  out.addAll(problems);
  return problems.length;
}

void main(List<String> args) {
  final List<String> slugs = args.isNotEmpty
      ? args
      : (Directory('hsdd/contract/fixture').listSync().whereType<Directory>().map((Directory d) => d.path.split('/').last).toList()..sort());
  int problems = 0;
  final List<String> out = <String>[];
  for (final String s in slugs) {
    problems += checkSlug(s, out);
  }
  out.forEach(stdout.writeln);
  stdout.writeln('${slugs.length} slugs, $problems problem(s)${lenient ? ' (LENIENT)' : ''}');
  exit(problems == 0 ? 0 : 1);
}
