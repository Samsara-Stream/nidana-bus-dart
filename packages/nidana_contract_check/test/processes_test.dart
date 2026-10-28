// packages/nidana_contract_check/test/processes_test.dart
import 'dart:io';

import 'package:nidana_contract_check/src/command.dart';
import 'package:nidana_contract_check/src/processes.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/seed.dart';

void main() {
  test('runProcess runs to the exit and decodes the output', () async {
    final ProcessRun run = await runProcess(
      Platform.resolvedExecutable,
      <String>['--version'],
      workingDirectory: Directory.systemTemp.path,
    );
    expect(
      run,
      isA<Exited>()
          .having((Exited e) => e.exit.code, 'code', 0)
          .having(
            (Exited e) => '${e.exit.stdout}${e.exit.stderr}',
            'output',
            contains('Dart SDK version: 3.13.5'),
          ),
    );
  });
  test('runProcess decodes output that is not UTF-8 leniently', () async {
    final String script = p.join(
      seed(const <String, String>{}).path,
      'bytes.dart',
    );
    File(script).writeAsStringSync(
      "import 'dart:io'; void main() { stdout.add(<int>[0xff, 0x0a]); "
      'stderr.add(<int>[0x61, 0xfe]); exitCode = 3; }',
    );
    final ProcessRun run = await runProcess(
      Platform.resolvedExecutable,
      <String>[script],
      workingDirectory: Directory.systemTemp.path,
    );
    expect(
      run,
      isA<Exited>().having((Exited e) => e.exit, 'exit', (
        code: 3,
        stdout: '\uFFFD\n',
        stderr: 'a\uFFFD',
      )),
    );
  });
  test(
    'runProcess of an executable that does not exist is NotStarted',
    () async {
      final ProcessRun run = await runProcess(
        '/nonexistent/dart',
        const <String>[],
        workingDirectory: Directory.systemTemp.path,
      );
      expect(
        run,
        isA<NotStarted>().having(
          (NotStarted n) => n.reason,
          'reason',
          startsWith('could not run /nonexistent/dart: '),
        ),
      );
    },
  );

  // Beyond the brief: the working directory is the child's, and the arguments
  // reach it as given, one each, an empty one included.
  test('runProcess starts the process from its working directory with its arguments as given', () async {
    final Directory directory = seed(const <String, String>{});
    final String script = p.join(directory.path, 'echo.dart');
    File(script).writeAsStringSync(
      "import 'dart:io'; void main(List<String> a) { "
      "stdout.write('\${Directory.current.resolveSymbolicLinksSync()}|\${a.join('|')}'); }",
    );
    final ProcessRun run = await runProcess(
      Platform.resolvedExecutable,
      <String>[script, 'a b', '', '{output}'],
      workingDirectory: directory.path,
    );
    expect(
      run,
      isA<Exited>().having((Exited e) => e.exit, 'exit', (
        code: 0,
        stdout: '${directory.resolveSymbolicLinksSync()}|a b||{output}',
        stderr: '',
      )),
    );
  });
  // Beyond the brief: the codec every process's output is decoded by.
  test(
    'lenientUtf8 decodes malformed bytes as U+FFFD and encodes as UTF-8',
    () {
      expect(lenientUtf8.decode(<int>[0x61, 0xc3]), 'a\uFFFD');
      expect(lenientUtf8.encode('\u00e9'), <int>[0xc3, 0xa9]);
    },
  );
  // Beyond the brief: the record a process's exit is read as.
  test('an Exited holds the ProcessExit it was given', () {
    const ProcessExit exit = (code: 1, stdout: 'o', stderr: 'e');
    expect(const Exited(exit).exit, exit);
  });
}
