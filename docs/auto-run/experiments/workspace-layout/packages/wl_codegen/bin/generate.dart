// Command entry outside build_runner: generate {input} {output}.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:wl_codegen/src/generate.dart';

void main(List<String> args) {
  final input = Directory(args[0]);
  final output = Directory(args[1])..createSync(recursive: true);
  for (final f in input.listSync().whereType<File>().where((f) => f.path.endsWith('.topics.yaml'))) {
    final name = p.basename(f.path).replaceAll('.topics.yaml', '.topics.g.dart');
    File(p.join(output.path, name)).writeAsStringSync(generateTopics(f.readAsStringSync()));
  }
  stdout.writeln('generated into ${output.path}');
}
