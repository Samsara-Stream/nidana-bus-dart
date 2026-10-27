// model-gate-reach: for every behavior case that a gate of an unshipped
// nidana.model phase replays, what the case reaches that still throws
// UnimplementedError at HEAD, which phase delivers that, and whether the
// gate's own phase or its dependency closure contains that phase.
//
// Usage, from the workspace root:
//   fvm dart docs/auto-run/experiments/model-gate-reach/scan.dart [spec.md]
// The spec defaults to hsdd/spec/nidana.model.md; run.sh also passes HEAD's.
//
// Method (a static scan; the cases are Dart, and the bodies they need are
// not written yet, so no run can tell "not built yet" from "cannot pass"):
//   1. The stubs: every line under packages/nidana_dart_contracts/lib/ that
//      throws UnimplementedError, named by its enclosing member. With
//      nidana.model.1 to .10 merged, these are the only bodies left, so a
//      case that reaches none of them throws no UnimplementedError.
//   2. Each stub is mapped to the unshipped phase whose Scope delivers it
//      (D4's file layout); the script checks that the Scope names it.
//   3. Each case's code (comments and string contents removed, string
//      interpolations kept) is matched against each stub's call forms, and
//      so is the code of every top-level declaration of the conformance
//      library the case references, transitively, with topologyIrSamples
//      resolved sample by sample.
//   4. The gates: each `nidana_contract_check` command of each phase's Gate
//      line, its slugs, --set and --guarantee; the bindings under each
//      slug's behavior/ and the conformance library each imports; the
//      admitted cases by ADR-001 item 9 (a name beginning with an admitted
//      id of the suite's slug, then a space).
//   5. The closure: the phases a phase's Dependencies line names,
//      transitively (D5: a gate replays what its closure has delivered).
import 'dart:io';

// ------------------------------------------------------------ stubs

/// Stub name (as derived from the code) -> (delivering phase, the text the
/// phase's Scope names it by, the call forms that reach it).
final Map<String, (int, String, List<String>)> stubPhase =
    <String, (int, String, List<String>)>{
  'TopologyPlan.definition': (
    11,
    'TopologyPlan.definition',
    // Topology.buildDefinition() is planOf(this).definition (checked below).
    <String>[r'\bbuildDefinition\s*\(', r'\.definition\b'],
  ),
  'ShellClaim()': (11, 'ShellClaim', <String>[r'\bShellClaim\s*\(']),
  'TopologyGraph()': (11, 'TopologyGraph', <String>[r'\bTopologyGraph\s*\(']),
  'TopologyGraph.render': (11, 'render(r)', <String>[r'\.render\s*\(']),
  'TopologyDefinitionGraph.toGraph': (11, 'toGraph()', <String>[r'\btoGraph\s*\(']),
  'findTopologyCycles': (12, 'findTopologyCycles', <String>[r'\bfindTopologyCycles\b']),
  'findSelfReferences': (12, 'findSelfReferences', <String>[r'\bfindSelfReferences\b']),
  'findWriterConflicts': (12, 'findWriterConflicts', <String>[r'\bfindWriterConflicts\b']),
  'findScopeViolations': (12, 'findScopeViolations', <String>[r'\bfindScopeViolations\b']),
  'analyzeTopologyGraph': (12, 'analyzeTopologyGraph', <String>[r'\banalyzeTopologyGraph\b']),
  'findTopicNameCollisions': (12, 'findTopicNameCollisions', <String>[r'\bfindTopicNameCollisions\b']),
  'encodeTopologyGraph': (13, 'encodeTopologyGraph', <String>[r'\bencodeTopologyGraph\b']),
  'decodeTopologyGraph': (13, 'decodeTopologyGraph', <String>[r'\bdecodeTopologyGraph\b']),
  'encodeTopologyDefinition': (13, 'encodeTopologyDefinition', <String>[r'\bencodeTopologyDefinition\b']),
  'decodeTopologyDefinition': (13, 'decodeTopologyDefinition', <String>[r'\bdecodeTopologyDefinition\b']),
  'JsonRenderer.render': (13, 'JsonRenderer', <String>[r'\bJsonRenderer\b']),
  'MermaidRenderer.render': (14, 'MermaidRenderer', <String>[r'\bMermaidRenderer\b']),
  'GraphvizRenderer.render': (14, 'GraphvizRenderer', <String>[r'\bGraphvizRenderer\b']),
};

final RegExp _ident = RegExp(r'[A-Za-z_$][\w$]*');

bool _isIdentChar(String c) => RegExp(r'[\w$]').hasMatch(c);

/// The stubs under [lib]: each UnimplementedError line named by its
/// enclosing member, with its file and line.
List<(String, String, int)> findStubs(Directory lib, String root) {
  final List<(String, String, int)> out = <(String, String, int)>[];
  final List<File> files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File f in files) {
    final List<String> lines = f.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      if (!lines[i].contains('UnimplementedError')) continue;
      String? owner;
      for (int k = i; k >= 0; k--) {
        final RegExpMatch? c =
            RegExp(r'^(?:\w+\s+)*(?:class|extension)\s+(\w+)').firstMatch(lines[k]);
        if (c != null) {
          owner = c.group(1);
          break;
        }
        if (lines[k].startsWith('}')) break; // top level
      }
      String? member;
      for (int k = i; k >= 0 && k >= i - 8; k--) {
        final String l = lines[k];
        final String t = l.trimLeft();
        if (t.startsWith('throw') || t.startsWith(')') || t.startsWith('}')) continue;
        final RegExpMatch? fac = RegExp(r'factory\s+(\w+)\s*\(').firstMatch(l);
        if (fac != null) {
          member = '${fac.group(1)}()';
          break;
        }
        final RegExpMatch? get = RegExp(r'\bget\s+(\w+)').firstMatch(l);
        if (get != null) {
          member = '$owner.${get.group(1)}';
          break;
        }
        final int p = l.indexOf('(');
        if (p > 0) {
          final List<RegExpMatch> ids = _ident.allMatches(l.substring(0, p)).toList();
          if (ids.isNotEmpty) {
            final String name = ids.last.group(0)!;
            member = owner == null ? name : '$owner.$name';
            break;
          }
        }
      }
      out.add((member ?? '?', f.path.substring(root.length + 1), i + 1));
    }
  }
  return out;
}

// ------------------------------------------------------------ lexing

/// [src] with comments removed and string contents replaced by '', keeping
/// the code of interpolations.
String codeOnly(String src) {
  final StringBuffer out = StringBuffer();
  _code(src, 0, out, untilBrace: false);
  return out.toString();
}

int _code(String s, int i, StringBuffer out, {required bool untilBrace}) {
  int depth = 0;
  while (i < s.length) {
    final String c = s[i];
    if (s.startsWith('//', i)) {
      final int j = s.indexOf('\n', i);
      i = j < 0 ? s.length : j;
      continue;
    }
    if (s.startsWith('/*', i)) {
      final int j = s.indexOf('*/', i + 2);
      i = j < 0 ? s.length : j + 2;
      continue;
    }
    final bool rawStart = c == 'r' &&
        i + 1 < s.length &&
        (s[i + 1] == "'" || s[i + 1] == '"') &&
        (i == 0 || !_isIdentChar(s[i - 1]));
    if (c == "'" || c == '"' || rawStart) {
      i = _string(s, i, out);
      continue;
    }
    if (untilBrace) {
      if (c == '{') depth++;
      if (c == '}') {
        if (depth == 0) return i + 1;
        depth--;
      }
    }
    out.write(c);
    i++;
  }
  return i;
}

int _string(String s, int i, StringBuffer out) {
  bool raw = false;
  if (s[i] == 'r') {
    raw = true;
    i++;
  }
  final String q = s[i];
  final String delim = s.startsWith(q * 3, i) ? q * 3 : q;
  i += delim.length;
  out.write("''");
  while (i < s.length) {
    if (s.startsWith(delim, i)) return i + delim.length;
    final String c = s[i];
    if (!raw && c == r'\') {
      i += 2;
      continue;
    }
    if (!raw && c == r'$') {
      if (i + 1 < s.length && s[i + 1] == '{') {
        out.write(' ');
        i = _code(s, i + 2, out, untilBrace: true);
        out.write(' ');
        continue;
      }
      int j = i + 1;
      while (j < s.length && _isIdentChar(s[j])) {
        j++;
      }
      out.write(' ${s.substring(i + 1, j)} ');
      i = j;
      continue;
    }
    i++;
  }
  return i;
}

// ------------------------------------------------------------ libraries

final class Decl {
  Decl(this.name, this.line, this.text);
  final String name;
  final int line;
  final String text;
  late final String code = codeOnly(text);
}

final class Case {
  Case(this.name, this.line, this.text);
  final String name;
  final int line; // the line of `name:`
  final String text;
  late final String code = codeOnly(text);
  String get id => name.split(' ').first;
}

final class Library {
  Library(this.path, this.decls, this.cases, this.samples);
  final String path;
  final Map<String, Decl> decls;
  final List<Case> cases;
  final Map<String, Decl> samples; // topologyIrSamples entries, by key
}

String? declName(String line) {
  if (line.isEmpty ||
      line.startsWith(' ') ||
      line.startsWith('//') ||
      line.startsWith('import ') ||
      line.startsWith('export ') ||
      line.startsWith('@') ||
      RegExp(r'^[\]\)\}]').hasMatch(line)) {
    return null;
  }
  final RegExpMatch? cls =
      RegExp(r'\b(?:class|enum|mixin|extension)\s+([A-Za-z_$][\w$]*)').firstMatch(line);
  if (cls != null) return cls.group(1);
  final RegExp assign = RegExp(r'([A-Za-z_$][\w$]*)\s*=(?![=>])');
  if (RegExp(r'^(?:final|const|var|late)\s').hasMatch(line)) {
    return assign.firstMatch(line)?.group(1);
  }
  final int paren = line.indexOf('(');
  final RegExpMatch? a = assign.firstMatch(line);
  if (a != null && (paren < 0 || a.start < paren)) return a.group(1);
  if (paren < 0) return null;
  final List<RegExpMatch> ids = _ident.allMatches(line.substring(0, paren)).toList();
  return ids.isEmpty ? null : ids.last.group(0);
}

Library readLibrary(String path, String root) {
  final List<String> lines = File('$root/$path').readAsLinesSync();
  final List<(String, int)> starts = <(String, int)>[];
  for (int i = 0; i < lines.length; i++) {
    final String? n = declName(lines[i]);
    if (n != null) starts.add((n, i));
  }
  final Map<String, Decl> decls = <String, Decl>{};
  final List<Case> cases = <Case>[];
  final Map<String, Decl> samples = <String, Decl>{};
  for (int s = 0; s < starts.length; s++) {
    final (String name, int from) = starts[s];
    final int to = s + 1 < starts.length ? starts[s + 1].$2 : lines.length;
    final List<String> body = lines.sublist(from, to);
    decls[name] = Decl(name, from + 1, body.join('\n'));
    if (lines[from].contains('List<ConformanceCase<')) {
      for (int i = 0; i < body.length; i++) {
        if (body[i] != '  (') continue;
        int j = i;
        while (body[j] != '  ),') {
          j++;
        }
        final String text = body.sublist(i, j + 1).join('\n');
        final int nameAt = text.indexOf('name:');
        final int bodyAt = text.indexOf('body:');
        final String nameSpan = text.substring(nameAt + 5, bodyAt);
        final String caseName = RegExp(r"'((?:[^'\\]|\\.)*)'|" r'"((?:[^"\\]|\\.)*)"')
            .allMatches(nameSpan)
            .map((RegExpMatch m) => m.group(1) ?? m.group(2)!)
            .join();
        final int nameLine = from + i + body.sublist(i, j + 1).indexWhere((String l) => l.contains('name:'));
        cases.add(Case(caseName, nameLine + 1, text));
        i = j;
      }
    }
    if (name == 'topologyIrSamples') {
      String? key;
      int keyFrom = 0;
      void flush(int end) {
        if (key != null) {
          samples[key] = Decl('sample:$key', from + keyFrom + 1, body.sublist(keyFrom, end).join('\n'));
        }
      }
      for (int i = 0; i < body.length; i++) {
        final RegExpMatch? m = RegExp(r"^  '(\w+)': ").firstMatch(body[i]);
        if (m != null || body[i].startsWith('};')) {
          flush(i);
          key = m?.group(1);
          keyFrom = i;
        }
      }
    }
  }
  return Library(path, decls, cases, samples);
}

/// The stubs [code] reaches directly.
Set<String> directStubs(String code) => <String>{
      for (final MapEntry<String, (int, String, List<String>)> e in stubPhase.entries)
        if (e.value.$3.any((String p) => RegExp(p).hasMatch(code))) e.key,
    };

/// Every stub a case reaches, each with the path it is reached by.
Map<String, String> reach(Library lib, Case c) {
  final Map<String, String> found = <String, String>{};
  final Set<String> seen = <String>{};
  void visit(String raw, String code, String via) {
    for (final String s in directStubs(code)) {
      found.putIfAbsent(s, () => via);
    }
    // Samples by key (a string literal, so read from the raw text); .values,
    // .entries or .forEach run every sample.
    final Set<String> keys = <String>{
      for (final RegExpMatch m in RegExp(r"topologyIrSamples\[\s*'(\w+)'\s*\]").allMatches(raw))
        m.group(1)!,
    };
    if (RegExp(r'topologyIrSamples\s*\.\s*(values|entries|forEach)\b').hasMatch(code)) {
      keys.addAll(lib.samples.keys);
    }
    for (final String k in keys) {
      final Decl d = lib.samples[k]!;
      if (seen.add(d.name)) visit(d.text, d.code, via == 'case' ? d.name : '$via > ${d.name}');
    }
    for (final RegExpMatch m in _ident.allMatches(code)) {
      final String n = m.group(0)!;
      if (n == 'topologyIrSamples') continue;
      final Decl? d = lib.decls[n];
      if (d == null || d.text.contains('List<ConformanceCase<')) continue;
      if (seen.add(n)) visit(d.text, d.code, via == 'case' ? n : '$via > $n');
    }
  }

  visit(c.text, c.code, 'case');
  return found;
}

// ------------------------------------------------------------ the plan

final class Phase {
  Phase(this.n, this.title, this.gate, this.scope, this.deps, this.shipped);
  final int n;
  final String title;
  final String gate;
  final String scope;
  final Set<int> deps;
  final bool shipped;
}

Map<int, Phase> readPlan(String specText, String root) {
  final Map<int, Phase> out = <int, Phase>{};
  final List<String> parts = specText.split(RegExp(r'^### ', multiLine: true));
  for (final String p in parts) {
    final RegExpMatch? h = RegExp(r'^nidana\.model\.(\d+): (.*)$', multiLine: true).firstMatch(p);
    if (h == null || h.start != 0) continue;
    final int n = int.parse(h.group(1)!);
    String field(String f) =>
        RegExp('^- \\*\\*$f:\\*\\* (.*)\$', multiLine: true).firstMatch(p)?.group(1) ?? '';
    final Set<int> deps = <int>{
      for (final RegExpMatch m in RegExp(r'nidana\.model\.(\d+)').allMatches(field('Dependencies')))
        int.parse(m.group(1)!),
    };
    out[n] = Phase(n, h.group(2)!, field('Gate'), field('Scope'), deps,
        File('$root/hsdd/verify/nidana.model.$n.verification.md').existsSync());
  }
  return out;
}

Set<int> closure(Map<int, Phase> plan, int n) {
  final Set<int> out = <int>{};
  final List<int> todo = <int>[...plan[n]!.deps];
  while (todo.isNotEmpty) {
    final int d = todo.removeLast();
    if (out.add(d)) todo.addAll(plan[d]?.deps ?? const <int>{});
  }
  return out;
}

final class Replay {
  Replay(this.command, this.slugs, this.sets, this.ids);
  final String command;
  final List<String> slugs;
  final Set<String>? sets; // null: every set
  final Set<String>? ids; // null: unrestricted
  bool get runsBehavior => sets == null || sets!.contains('behavior');
}

List<Replay> replays(String gate) {
  final List<Replay> out = <Replay>[];
  for (final String raw in gate.replaceAll('`', '').split('&&')) {
    final String cmd = raw.trim();
    if (!cmd.startsWith('fvm dart run nidana_contract_check')) continue;
    final List<String> t = cmd.split(RegExp(r'\s+')).sublist(4);
    final List<String> slugs = <String>[];
    Set<String>? sets;
    Set<String>? ids;
    for (int i = 0; i < t.length; i++) {
      if (t[i] == '--set') {
        sets = t[++i].split(',').toSet();
      } else if (t[i] == '--guarantee') {
        ids = t[++i].split(',').toSet();
      } else if (t[i] == '--all') {
        slugs.add('--all');
      } else {
        slugs.add(t[i]);
      }
    }
    out.add(Replay(cmd, slugs, sets, ids));
  }
  return out;
}

/// The bindings of [slug]: each behavior/*_test.dart and the slug and path
/// of the conformance library it imports by relative path.
List<(String, String, String)> bindings(String root, String slug) {
  final Directory dir = Directory('$root/hsdd/contract/fixture/$slug/behavior');
  if (!dir.existsSync()) return const <(String, String, String)>[];
  final List<(String, String, String)> out = <(String, String, String)>[];
  for (final File f in dir.listSync().whereType<File>().where((File f) => f.path.endsWith('_test.dart'))) {
    for (final RegExpMatch m in RegExp(r"^import '([^:']+)';", multiLine: true).allMatches(f.readAsStringSync())) {
      final Uri lib = dir.uri.resolve(m.group(1)!);
      final String rel = lib.toFilePath().substring(root.length + 1);
      final String suiteSlug = rel.split('/')[3];
      out.add((f.path.substring(root.length + 1), suiteSlug, rel));
    }
  }
  return out;
}

// ------------------------------------------------------------ report

String root() {
  Directory d = Directory.current.absolute;
  while (!Directory('${d.path}/hsdd/contract').existsSync()) {
    if (d.parent.path == d.path) throw StateError('no workspace root');
    d = d.parent;
  }
  return d.path;
}

String ph(Iterable<int> ns) => ns.isEmpty ? '-' : (ns.toList()..sort()).map((int n) => '.$n').join(' ');

void main(List<String> args) {
  final String r = root();
  if (args.length == 2 && args.first == '--check') {
    check(r, args[1]);
    return;
  }
  final String specPath = args.isNotEmpty ? args.first : '$r/hsdd/spec/nidana.model.md';
  final Map<int, Phase> plan = readPlan(File(specPath).readAsStringSync(), r);

  print('# model-gate-reach');
  print('spec: ${specPath.startsWith(r) ? specPath.substring(r.length + 1) : specPath}');

  // 1. stubs
  print('\n## S1 stubs at HEAD: bodies under packages/nidana_dart_contracts/lib/ that throw UnimplementedError');
  final List<(String, String, int)> stubs =
      findStubs(Directory('$r/packages/nidana_dart_contracts/lib'), r);
  final List<String> unmapped = <String>[];
  for (final (String name, String file, int line) in stubs) {
    final (int, String, List<String>)? m = stubPhase[name];
    if (m == null) unmapped.add(name);
    final String named = m == null
        ? '?'
        : (plan[m.$1]!.scope.contains(m.$2) ? 'Scope of .${m.$1} names `${m.$2}`' : 'Scope of .${m.$1} does NOT name `${m.$2}`');
    print('- $name  ($file:$line)  -> ${m == null ? 'UNMAPPED' : '.${m.$1}'}; $named');
  }
  final Set<String> derived = stubs.map(((String, String, int) s) => s.$1).toSet();
  for (final String k in stubPhase.keys) {
    if (!derived.contains(k)) print('- mapped stub not found in the code: $k');
  }
  print('stubs: ${stubs.length}; unmapped: ${unmapped.isEmpty ? 'none' : unmapped.join(', ')}');
  final String topo = File('$r/packages/nidana_dart_contracts/lib/src/topology/topology.dart').readAsStringSync();
  print('Topology.buildDefinition() is planOf(this).definition: '
      '${topo.contains('TopologyDefinition buildDefinition() => planOf(this).definition;')}');

  // 2. the plan
  print('\n## S2 phases, closures and gates (unshipped phases: no hsdd/verify doc)');
  final List<int> unshipped = (plan.keys.where((int n) => !plan[n]!.shipped).toList()..sort());
  for (final int n in unshipped) {
    print('- .$n ${plan[n]!.title}: depends on ${ph(plan[n]!.deps)}; closure ${ph(closure(plan, n))}');
    for (final Replay rp in replays(plan[n]!.gate)) {
      print('  - ${rp.command}${rp.runsBehavior ? '' : '   (no behavior set)'}');
    }
  }

  // 3. the cases
  final Map<String, Library> libs = <String, Library>{};
  final Map<String, Map<Case, Map<String, String>>> reached = <String, Map<Case, Map<String, String>>>{};
  Library lib(String path) => libs.putIfAbsent(path, () => readLibrary(path, r));

  final Set<String> suites = <String>{};
  for (final int n in unshipped) {
    for (final Replay rp in replays(plan[n]!.gate)) {
      if (!rp.runsBehavior) continue;
      for (final String slug in rp.slugs) {
        for (final (String _, String _, String path) in bindings(r, slug)) {
          suites.add(path);
        }
      }
    }
  }
  print('\n## S3 every case of every suite those gates bind: what it reaches that still throws');
  print('(phases: the unshipped phases whose stubs the case reaches; "via" names the helper or sample)');
  for (final String path in suites.toList()..sort()) {
    final Library l = lib(path);
    reached[path] = <Case, Map<String, String>>{};
    print('\n### $path (${l.cases.length} cases${l.samples.isEmpty ? '' : ', samples ${l.samples.keys.join(', ')}'})');
    for (final Case c in l.cases) {
      final Map<String, String> hit = reach(l, c);
      reached[path]![c] = hit;
      final Set<int> phases = <int>{for (final String s in hit.keys) stubPhase[s]!.$1};
      final String detail = hit.isEmpty
          ? ''
          : '  [${(hit.keys.toList()..sort()).map((String s) => hit[s] == 'case' ? s : '$s via ${hit[s]}').join('; ')}]';
      final String nm = c.name.length > 90 ? '${c.name.substring(0, 87)}...' : c.name;
      print('- L${c.line} $nm -> needs ${ph(phases)}$detail');
    }
  }

  // 4. per gate
  print('\n## S4 per gate: the admitted cases, and whether its phase or its closure delivers what each reaches');
  final Map<int, List<String>> failingIds = <int, List<String>>{};
  for (final int n in unshipped) {
    final Set<int> have = <int>{...closure(plan, n), n};
    print('\n### .$n ${plan[n]!.title} (delivered: ${ph(have.where((int p) => p >= 11))} of .11 to .14)');
    for (final Replay rp in replays(plan[n]!.gate)) {
      if (!rp.runsBehavior) continue;
      for (final String slug in rp.slugs) {
        for (final (String binding, String suiteSlug, String path) in bindings(r, slug)) {
          final Set<String>? admittedIds = rp.ids == null
              ? null
              : <String>{
                  for (final String id in rp.ids!)
                    if (id.contains('/') ? id.split('/').first == suiteSlug : suiteSlug == slug)
                      id.split('/').last,
                };
          final List<Case> admitted = <Case>[
            for (final Case c in lib(path).cases)
              if (admittedIds == null || admittedIds.contains(c.id)) c,
          ];
          int ok = 0;
          final List<String> bad = <String>[];
          final List<String> serialOnly = <String>[];
          for (final Case c in admitted) {
            final Set<int> need = <int>{for (final String s in reached[path]![c]!.keys) stubPhase[s]!.$1};
            final Set<int> missing = need.difference(have);
            if (missing.isEmpty) {
              ok++;
            } else {
              final bool laterOnly = missing.every((int m) => m > n);
              bad.add('L${c.line} ${c.id}: needs ${ph(missing)}, outside .$n\'s closure'
                  '${laterOnly ? '' : ' (numbered before .$n, but not a dependency)'}');
              if (!laterOnly) serialOnly.add(c.id);
              failingIds.putIfAbsent(n, () => <String>[]).add('$slug:${c.id}');
            }
          }
          final String restr = rp.ids == null ? 'unrestricted' : 'restricted to ${rp.ids!.join(',')}';
          print('- $slug, $restr; binding $binding (suite of $suiteSlug): '
              '${admitted.length} admitted, $ok reachable, ${bad.length} cannot pass');
          for (final String b in bad) {
            print('  - CANNOT PASS $b');
          }
        }
      }
    }
  }

  // 5. per guarantee of topology-ir: where every case of it is reachable
  print('\n## S5 topology-ir@v1 by guarantee: the unshipped phases its cases need, and the first unshipped phase whose closure has them');
  const String irSuite = 'hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart';
  final Map<String, Set<int>> byId = <String, Set<int>>{};
  final Map<String, int> count = <String, int>{};
  for (final Case c in lib(irSuite).cases) {
    byId.putIfAbsent(c.id, () => <int>{}).addAll(<int>{for (final String s in reached[irSuite]![c]!.keys) stubPhase[s]!.$1});
    count[c.id] = (count[c.id] ?? 0) + 1;
  }
  final List<String> ids = byId.keys.toList()..sort((String a, String b) => int.parse(a.substring(1)).compareTo(int.parse(b.substring(1))));
  for (final String id in ids) {
    final Set<int> need = byId[id]!;
    final int? first = unshipped.cast<int?>().firstWhere(
        (int? n) => need.difference(<int>{...closure(plan, n!), n}).isEmpty,
        orElse: () => null);
    final List<String> inGates = <String>[
      for (final int n in unshipped)
        for (final Replay rp in replays(plan[n]!.gate))
          if (rp.runsBehavior && rp.slugs.contains('topology-ir') && (rp.ids == null || rp.ids!.contains(id))) '.$n',
    ];
    final String at = need.isEmpty
        ? 'reachable from nidana.model.10 on (needs no unshipped phase)'
        : 'first reachable at ${first == null ? 'no unshipped phase' : '.$first'}';
    print('- $id (${count[id]} case${count[id] == 1 ? '' : 's'}): needs ${ph(need)}; $at; replayed by ${inGates.isEmpty ? 'no unshipped gate' : inGates.join(' ')}');
  }

  print('\n## Verdict');
  for (final int n in unshipped) {
    final List<String> f = failingIds[n] ?? const <String>[];
    print('- .$n: ${f.isEmpty ? 'every admitted case is reachable; the gate can pass' : 'CANNOT PASS: ${f.join(', ')}'}');
  }
}

/// Validates the static scan against a replay of the three slugs' behavior
/// sets on today's code: a case that reaches no stub must pass today, and a
/// case that reaches one must fail today, except where it throws before the
/// stub is reached (listed, not counted as a miss).
void check(String r, String replayOut) {
  final String out = File(replayOut).readAsStringSync();
  final Set<String> failed = <String>{
    for (final RegExpMatch m in RegExp(r'failed-case \((.*?)\)(?=;|$)', multiLine: true).allMatches(out)) m.group(1)!,
  };
  print('# model-gate-reach --check: the static scan against today\'s replay');
  print('failed cases in the replay: ${failed.length}');
  int misses = 0;
  for (final String path in <String>[
    'hsdd/contract/fixture/topic-model/behavior/topic_model_conformance.dart',
    'hsdd/contract/fixture/topology-dsl/behavior/recording_conformance.dart',
    'hsdd/contract/fixture/topology-ir/behavior/topology_ir_conformance.dart',
  ]) {
    final Library l = readLibrary(path, r);
    int none = 0, some = 0;
    for (final Case c in l.cases) {
      final bool needs = reach(l, c).isNotEmpty;
      final bool fails = failed.contains(c.name);
      if (needs) {
        some++;
      } else {
        none++;
      }
      if (!needs && fails) {
        misses++;
        print('- MISS L${c.line} ${c.id}: reaches no stub but fails today: ${c.name}');
      }
      if (needs && !fails) {
        print('- conservative L${c.line} ${c.id}: reaches a stub, passes today (throws before reaching it): ${c.name}');
      }
    }
    print('$path: ${l.cases.length} cases, $none reach no stub, $some reach one');
  }
  print('misses (a case the scan says needs nothing that fails today): $misses');
}
