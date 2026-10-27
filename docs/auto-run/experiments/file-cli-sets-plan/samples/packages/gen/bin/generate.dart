// A stand-in generator: `generate [--echo] [--write-then-fail] <input> <output>`
// writes <output>/out.dart (unformatted) and <output>/notes.txt from the first
// line of <input>, and prints where it wrote and its working directory; a
// usage error or a missing input exits 2 and writes nothing.
import 'dart:io';

void main(List<String> arguments) {
  final List<String> options = <String>[
    for (final String argument in arguments)
      if (argument.startsWith('--')) argument,
  ];
  final List<String> positional = <String>[
    for (final String argument in arguments)
      if (!argument.startsWith('--')) argument,
  ];
  const Set<String> known = <String>{'--echo', '--write-then-fail'};
  if (positional.length != 2 || !options.every(known.contains)) {
    stderr.writeln(
      'usage: generate [--echo] [--write-then-fail] <input> <output>',
    );
    exitCode = 2;
    return;
  }
  final File input = File(positional[0]);
  if (!input.existsSync()) {
    stderr.writeln('${positional[0]} does not exist');
    exitCode = 2;
    return;
  }
  final String word = input.readAsLinesSync().first;
  final Directory output = Directory(positional[1])
    ..createSync(recursive: true);
  File('${output.path}/out.dart').writeAsStringSync(
    "void   main( ) {print(  '$word' ) ;}\n",
  );
  File('${output.path}/notes.txt').writeAsStringSync('from $word\n');
  stdout.writeln('wrote ${output.path}');
  stdout.writeln('cwd ${Directory.current.path}');
  if (options.contains('--echo')) {
    stdout.writeln('resolved ${output.resolveSymbolicLinksSync()}');
  }
  if (options.contains('--write-then-fail')) {
    stderr.writeln('failed after writing');
    exitCode = 1;
  }
}
