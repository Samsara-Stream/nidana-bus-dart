// Stand-in for `fvm dart run nidana_dart_codegen:generate
// [--graph <topology-graph.json>] <topics.yaml> <output>` (topic-codegen@v1).
import 'dart:io';

import 'package:nidana_dart_codegen/src/generate.dart';
import 'package:path/path.dart' as p;

const usage =
    'usage: generate [--graph <topology-graph.json>] <topics.yaml> <output>';

void main(List<String> args) {
  String? graphPath;
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--graph') {
      if (i + 1 >= args.length || graphPath != null) return _usage('--graph takes one file');
      graphPath = args[++i];
    } else if (a.startsWith('-')) {
      return _usage('unknown option $a');
    } else {
      positional.add(a);
    }
  }
  if (positional.length != 2) return _usage('expected <topics.yaml> <output>');
  final topicsFile = File(positional[0]);
  final output = Directory(positional[1]);
  if (!topicsFile.existsSync()) return _usage('${positional[0]} does not exist');
  if (graphPath != null && !File(graphPath).existsSync()) {
    return _usage('$graphPath does not exist');
  }
  if (FileSystemEntity.typeSync(output.path) == FileSystemEntityType.file) {
    return _usage('${output.path} is not a directory');
  }
  final result = generate(
    topicsSource: topicsFile.readAsStringSync(),
    topicsPath: positional[0],
    graphSource: graphPath == null ? null : File(graphPath).readAsStringSync(),
    graphPath: graphPath,
  );
  if (!result.ok) {
    for (final d in result.diagnostics) {
      stderr.writeln(d);
    }
    exitCode = 1;
    return;
  }
  try {
    output.createSync(recursive: true);
    for (final MapEntry(:key, :value) in result.outputs.entries) {
      File(p.join(output.path, key)).writeAsStringSync(value);
    }
  } on FileSystemException catch (e) {
    return _usage('cannot write ${output.path}: ${e.message}');
  }
}

void _usage(String problem) {
  stderr
    ..writeln(problem)
    ..writeln(usage);
  exitCode = 2;
}
