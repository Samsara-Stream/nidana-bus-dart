// Prototype of the replay tool's `structure` set (ADR-001 items 3, 9 and 12)
// for one slug: marker and header syntax, guarantee coverage, the bindings
// listed in `## Validation` against the files present, and the ban on `src/`
// imports. Run from the experiment root: structure_check {slug}.
import 'dart:io';

final _guarantee = RegExp(r'^- \*\*(G\d+)\*\* ', multiLine: true);
final _notExecutable = RegExp(r'^- not executable: (G\d+), .+; checked by \S+ gates$', multiLine: true);
final _binding = RegExp(r'^- binding: `?(hsdd/contract/fixture/[^`\s]+_test\.dart)`?', multiLine: true);
final _covers = RegExp(r'^// covers: (G\d+(?:, G\d+)*)\s*$', multiLine: true);
final _marker = RegExp(r'^\s*// expect-diagnostic:');
final _markerOk = RegExp(r'^\s*// expect-diagnostic: [a-z0-9_]+\s*$');
// A case is a record literal in the exported list: a line holding only `(`,
// then its `name:` field. Matching `name:` anywhere would also catch the
// topic constructors the cases call, which take a `name:` argument too.
final _caseName = RegExp(r'''^\s*\(\s*\n\s*name:\s*'([^']*)''', multiLine: true);
final _caseNameOk = RegExp(r'^(G\d+) \S');
final _srcImport = RegExp(r'''^import\s+'package:[a-z0-9_]+/src/''', multiLine: true);

String section(String text, String heading) {
  final start = text.indexOf('\n## $heading');
  if (start < 0) return '';
  final next = text.indexOf('\n## ', start + 1);
  return text.substring(start, next < 0 ? text.length : next);
}

void main(List<String> args) {
  final slug = args.single;
  final contract = File('hsdd/contract/$slug.md').readAsStringSync();
  final dir = Directory('hsdd/contract/fixture/$slug');
  final problems = <String>[];

  final declared = _guarantee.allMatches(section(contract, 'Guarantees / invariants')).map((m) => m[1]!).toList();
  final validation = section(contract, 'Validation');
  final notExecutable = _notExecutable.allMatches(validation).map((m) => m[1]!).toSet();
  final listedBindings = _binding.allMatches(validation).map((m) => m[1]!).toSet();
  if (declared.toSet().length != declared.length) problems.add('duplicate guarantee id');

  final covered = <String, List<String>>{};
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final presentBindings = <String>{};
  var cases = 0;
  for (final f in files) {
    final rel = f.path.substring(f.path.indexOf('hsdd/'));
    final text = f.readAsStringSync();
    if (_srcImport.hasMatch(text)) problems.add('$rel imports a src/ library');
    final lines = text.split('\n');
    if (rel.contains('/reject/')) {
      final header = _covers.firstMatch(text);
      if (header == null) {
        problems.add('$rel has no // covers: header');
      } else {
        for (final id in header[1]!.split(', ')) {
          (covered[id] ??= []).add(rel);
        }
      }
      var markers = 0;
      for (var i = 0; i < lines.length; i++) {
        if (!_marker.hasMatch(lines[i])) continue;
        markers++;
        if (!_markerOk.hasMatch(lines[i])) problems.add('$rel:${i + 1} malformed marker');
        if (i + 1 >= lines.length || lines[i + 1].trim().isEmpty) problems.add('$rel:${i + 1} marker not followed by a line');
      }
      if (markers == 0) problems.add('$rel has no marker');
    }
    if (rel.endsWith('_conformance.dart')) {
      for (final m in _caseName.allMatches(text)) {
        final ok = _caseNameOk.firstMatch(m[1]!);
        if (ok == null) {
          problems.add('$rel case name does not begin with a guarantee id: ${m[1]}');
        } else {
          (covered[ok[1]!] ??= []).add('$rel case');
          cases++;
        }
      }
    }
    if (rel.contains('/behavior/') && rel.endsWith('_test.dart')) presentBindings.add(rel);
  }

  for (final id in declared) {
    final how = <String>[
      if (covered.containsKey(id)) '${covered[id]!.length} fixture(s)',
      if (notExecutable.contains(id)) 'not executable',
    ];
    if (how.isEmpty) problems.add('$id is not covered');
    print('${how.isEmpty ? 'FAIL' : 'PASS'} $id ${how.join(', ')}');
  }
  for (final id in {...covered.keys, ...notExecutable}) {
    if (!declared.contains(id)) problems.add('$id is cited but not declared');
  }
  for (final b in presentBindings.difference(listedBindings)) {
    problems.add('binding $b is not listed in ## Validation');
  }
  for (final b in listedBindings.difference(presentBindings)) {
    problems.add('listed binding $b does not exist');
  }
  print('guarantees: ${declared.length}; cases: $cases; bindings: ${presentBindings.length}; fixture files: ${files.length}');
  for (final p in problems) {
    print('PROBLEM $p');
  }
  exit(problems.isEmpty ? 0 : 1);
}
