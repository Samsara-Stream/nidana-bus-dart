// Probes for nidana.model.7's plan (S121), experiment only. Run with the
// SDK's dart, from anywhere:
//
//   dart paths.dart exe            the dart running this program
//   dart paths.dart temp           how a temporary directory's path reads
//   dart paths.dart spawn          a child started with a linked working
//                                  directory: what it reads and prints, and
//                                  the two orders of replacing a path pair
//   dart paths.dart stdin-parent   whether Process.run gives a child that
//                                  reads stdin an end of input or a hang
import 'dart:io';

Future<void> main(List<String> args) async {
  switch (args.first) {
    case 'exe':
      stdout.writeln(Platform.resolvedExecutable);
    case 'temp':
      final Directory t = Directory.systemTemp.createTempSync('probe_');
      stdout.writeln('Directory.systemTemp.path: ${Directory.systemTemp.path}');
      stdout.writeln('createTempSync path:       ${t.path}');
      stdout.writeln('resolveSymbolicLinksSync:  ${t.resolveSymbolicLinksSync()}');
      t.deleteSync();
    case 'child':
      // Prints what a child sees: its working directory, the argument as
      // given, a relative path made absolute, and the argument resolved.
      stdout.writeln('cwd: ${Directory.current.path}');
      stdout.writeln('PWD: ${Platform.environment['PWD']}');
      stdout.writeln('arg: ${args[1]}');
      stdout.writeln('relative made absolute: ${File('rel.txt').absolute.path}');
      Directory(args[1]).createSync();
      stdout.writeln('arg resolved: ${Directory(args[1]).resolveSymbolicLinksSync()}');
    case 'spawn':
      final Directory t = Directory.systemTemp.createTempSync('probe_');
      final Directory files = Directory('${t.path}/files')..createSync();
      final String output = '${t.path}/output';
      final ProcessResult r = await Process.run(
        Platform.resolvedExecutable,
        <String>[Platform.script.toFilePath(), 'child', output],
        workingDirectory: files.path,
      );
      final String text = r.stdout as String;
      stdout.writeln('child exit: ${r.exitCode}');
      stdout.write(text);
      final String outputResolved = '${t.resolveSymbolicLinksSync()}/output';
      final String filesResolved = files.resolveSymbolicLinksSync();
      String apply(String s, List<(String, String)> pairs) => pairs.fold(
        s,
        (String acc, (String, String) p) => acc.replaceAll(p.$1, p.$2),
      );
      stdout.writeln('-- given form first, then resolved:');
      stdout.write(apply(text, <(String, String)>[
        (output, '{output}'),
        (outputResolved, '{output}'),
        (files.path, '{files}'),
        (filesResolved, '{files}'),
      ]));
      stdout.writeln('-- the longer form of each pair first:');
      stdout.write(apply(text, <(String, String)>[
        (outputResolved, '{output}'),
        (output, '{output}'),
        (filesResolved, '{files}'),
        (files.path, '{files}'),
      ]));
      t.deleteSync(recursive: true);
    case 'stdin-child':
      final String? line = stdin.readLineSync();
      stdout.writeln('read: ${line == null ? 'end of input' : line}');
    case 'stdin-parent':
      final Stopwatch watch = Stopwatch()..start();
      final ProcessResult r = await Process.run(
        Platform.resolvedExecutable,
        <String>[Platform.script.toFilePath(), 'stdin-child'],
      );
      stdout.writeln(
        'child exit: ${r.exitCode}, stdout: ${(r.stdout as String).trim()}, '
        'seconds: ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)}',
      );
  }
}
