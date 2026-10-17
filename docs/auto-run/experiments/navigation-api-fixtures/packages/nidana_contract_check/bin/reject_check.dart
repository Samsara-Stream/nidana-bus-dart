// Prototype of the replay tool's `reject` set (ADR-001 items 4 and 9): every
// `// expect-diagnostic: {code}` comment on its own line names a diagnostic
// reported on the next line, and every diagnostic reported in the file, at
// any severity, is so named. A file with no marker fails.
import 'dart:convert';
import 'dart:io';

typedef Hit = ({int line, String code});

final _marker = RegExp(r'^\s*// expect-diagnostic: ([a-z0-9_]+)\s*$');

Set<Hit> expected(File f) {
  final lines = f.readAsLinesSync();
  return {
    for (var i = 0; i < lines.length; i++)
      if (_marker.firstMatch(lines[i]) case final m?) (line: i + 2, code: m[1]!),
  };
}

void main(List<String> args) {
  final dir = Directory(args.single).absolute;
  final run = Process.runSync(
      Platform.resolvedExecutable, ['analyze', '--format=json', dir.path]);
  final out = run.stdout as String;
  final json = jsonDecode(out.substring(out.indexOf('{'))) as Map<String, Object?>;
  final actual = <String, Set<Hit>>{};
  for (final d in (json['diagnostics'] as List).cast<Map<String, Object?>>()) {
    final loc = d['location'] as Map<String, Object?>;
    final start = (loc['range'] as Map)['start'] as Map;
    (actual[loc['file'] as String] ??= {})
        .add((line: start['line'] as int, code: d['code'] as String));
  }
  var failures = 0;
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final want = expected(f);
    final got = actual[f.path] ?? const <Hit>{};
    final ok = want.isNotEmpty && want.length == got.length && want.containsAll(got);
    if (!ok) failures++;
    final shown = (want.toList()..sort((a, b) => a.line.compareTo(b.line)))
        .map((h) => '${h.line}:${h.code}')
        .join(' ');
    print('${ok ? 'PASS' : 'FAIL'} ${f.uri.pathSegments.last} [$shown]'
        '${ok ? '' : ' reported=$got'}');
  }
  exit(failures == 0 ? 0 : 1);
}
