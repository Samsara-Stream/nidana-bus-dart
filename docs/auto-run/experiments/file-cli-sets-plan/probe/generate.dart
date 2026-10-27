// A stand-in generator, experiment only: `packages/gen/bin/generate.dart` of
// the temporary workspace run.sh seeds. `generate <input> <output>` writes
// `<output>/out.dart` (unformatted on purpose) and `<output>/notes.txt`, and
// prints the output path and its working directory; any other argument count
// is a usage error, exit 2, writing nothing.
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: generate <input> <output>');
    exitCode = 2;
    return;
  }
  final File input = File(args[0]);
  if (!input.existsSync()) {
    stderr.writeln('${args[0]} does not exist');
    exitCode = 2;
    return;
  }
  final Directory output = Directory(args[1])..createSync(recursive: true);
  final String word = input.readAsStringSync().trim();
  File('${output.path}/out.dart').writeAsStringSync(
    "void   main( ) {print(  '$word' ) ;}\n",
  );
  File('${output.path}/notes.txt').writeAsStringSync('from $word\n');
  stdout.writeln('wrote ${output.path}');
  stdout.writeln('cwd ${Directory.current.path}');
}
