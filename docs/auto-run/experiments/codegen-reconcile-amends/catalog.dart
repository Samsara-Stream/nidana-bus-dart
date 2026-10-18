// Stand-in for `fvm dart run nidana_dart_codegen:catalog <package>... <output>`
// (topic-codegen@v1 as amended by hsdd-reconcile, S40), experiment only. It
// implements the usage rules of the amended exit-code bullet and nothing
// else: past them it writes the graph document of a package set that
// registers no topology and holds no claim, which is enough to show that a
// case expecting exit 2 and nothing at {output} fails when the rules are not
// kept. run.sh copies it to the stand-in package's bin/catalog.dart.
import 'dart:io';

import 'package:nidana_dart_contracts/topology_ir.dart';
import 'package:path/path.dart' as p;

const usage = 'usage: catalog <package>... <output>';

void main(List<String> args) {
  final positional = <String>[];
  for (final a in args) {
    if (a.startsWith('-')) return _usage('unknown option $a');
    positional.add(a);
  }
  if (positional.length < 2) return _usage('expected <package>... <output>');
  final packages = positional.sublist(0, positional.length - 1);
  final output = positional.last;
  for (final pkg in packages) {
    if (!Directory(pkg).existsSync()) return _usage('$pkg does not exist');
    if (!File(p.join(pkg, 'pubspec.yaml')).existsSync()) {
      return _usage('$pkg is not a package root');
    }
  }
  if (FileSystemEntity.typeSync(output) == FileSystemEntityType.file) {
    return _usage('$output is not a directory');
  }
  try {
    Directory(output).createSync(recursive: true);
    File(p.join(output, 'topology-graph.json'))
        .writeAsStringSync(const JsonRenderer().render(TopologyGraph()));
  } on FileSystemException catch (e) {
    return _usage('cannot write $output: ${e.message}');
  }
}

void _usage(String problem) {
  stderr
    ..writeln(problem)
    ..writeln(usage);
  exitCode = 2;
}
