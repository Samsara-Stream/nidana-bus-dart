// Seeds one defect into a copy of the stand-in nidana_dart_codegen of
// ../topic-codegen-fixtures/, experiment only. Each defect is one exact text
// replacement that must match exactly once, so a defect that silently fails
// to apply cannot pass for a defect the cases miss.
//
//   fvm dart run seed.dart <package dir> <defect>
//   fvm dart run seed.dart --list
import 'dart:io';

typedef Defect = ({String file, String from, String to, String breaks});

const Map<String, Defect> defects = <String, Defect>{
  // G14: without --graph, generate writes no topology-graph.html.
  'page-without-graph': (
    file: 'lib/src/generate.dart',
    from: r"    if (graph != null) 'topology-graph.html': renderGraphHtml(graph),",
    to: r"    'topology-graph.html': graph == null ? '' : renderGraphHtml(graph),",
    breaks: 'G14: a page is written without a graph',
  ),
  // G14: topics.g.dart is the same bytes with and without a graph.
  'registry-depends-on-graph': (
    file: 'lib/src/generate.dart',
    from: r"    'topics.g.dart': renderRegistry(doc),",
    to: r"    'topics.g.dart': graph == null ? renderRegistry(doc).replaceFirst('(topic-codegen@v1).', '(topic-codegen@v1), without a graph.') : renderRegistry(doc),",
    breaks: 'G14: the registry differs without a graph',
  ),
  // G2 and G19: a rejected document or an undecodable graph writes nothing.
  'writes-before-rejecting': (
    file: 'bin/generate.dart',
    from: r'  final result = generate(',
    to: '  output.createSync(recursive: true);\n  final result = generate(',
    breaks: 'G2, G19: the output directory is created before the inputs are checked',
  ),
  // G19: a usage error exits 2.
  'usage-exits-1': (
    file: 'bin/generate.dart',
    from: r'  exitCode = 2;',
    to: r'  exitCode = 1;',
    breaks: 'G19: usage errors exit 1',
  ),
  // G19: a missing graph file is a usage error (exit 2), not an undecodable graph (exit 1).
  'missing-graph-exits-1': (
    file: 'bin/generate.dart',
    from: r"    return _usage('$graphPath does not exist');",
    to: r"    stderr.writeln('$graphPath: does not exist'); exitCode = 1; return;",
    breaks: 'G19: a missing graph exits 1 like an undecodable one',
  ),
  // G2 (R3): a member name that is a reserved word or an Object member is rejected.
  'reserved-member-accepted': (
    file: 'lib/src/topics_document.dart',
    from: r'        if (reservedMembers.contains(member)) {',
    to: r'        if (member.isEmpty && reservedMembers.contains(member)) {',
    breaks: 'G2: R3 is not enforced',
  ),
};

void main(List<String> args) {
  if (args.length == 1 && args.first == '--list') {
    for (final MapEntry<String, Defect> e in defects.entries) {
      stdout.writeln('${e.key}: ${e.value.breaks}');
    }
    return;
  }
  final String dir = args[0];
  final Defect? d = defects[args[1]];
  if (d == null) {
    stderr.writeln('unknown defect ${args[1]}');
    exit(2);
  }
  final File f = File('$dir/${d.file}');
  final String text = f.readAsStringSync();
  final int count = d.from.allMatches(text).length;
  if (count != 1) {
    stderr.writeln('${args[1]}: expected one match in ${d.file}, found $count');
    exit(1);
  }
  f.writeAsStringSync(text.replaceFirst(d.from, d.to));
  stdout.writeln('seeded ${args[1]} in ${d.file} (${d.breaks})');
}
