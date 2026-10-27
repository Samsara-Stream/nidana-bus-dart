// packages/nidana_contract_check/test/file_set_test.dart
import 'dart:convert';

import 'package:nidana_contract_check/src/command.dart';
import 'package:nidana_contract_check/src/file_set.dart';
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/tree.dart';
import 'package:test/test.dart';

import 'support/generator.dart';
import 'support/sample.dart';

const String path = 'hsdd/contract/fixture/gen/expected/';

final SlugSnapshot gen = snapshotOf('gen', genFiles);

/// [plan] as text: a [FileSettled] by its report line, a [FileRun] as
/// `RUN {path} [{arguments}] {input} {expected}`, the arguments joined by `, `.
String planText(FilePlan plan) => switch (plan) {
  FileSettled(:final FixtureOutcome outcome) => outcomeLine(
    CheckSet.file,
    outcome,
  ),
  FileRun(
    :final String path,
    :final List<String> arguments,
    :final String input,
    :final String expected,
  ) =>
    'RUN $path [${arguments.join(', ')}] $input $expected',
};

/// The plan of [snapshot] under [restriction] with [packages], as [planText].
String plan(
  SlugSnapshot snapshot, {
  Set<String> packages = const <String>{'gen'},
  Set<GuaranteeRef>? restriction,
}) => planText(
  planFileReplay(snapshot, packages: packages, restriction: restriction),
);

/// The `gen` snapshot with its contract text [contract].
SlugSnapshot genWith(String contract) => snapshotOf(
  'gen',
  changed(genFiles, <String, String>{'hsdd/contract/gen.md': contract}),
);

const String runLine =
    'RUN hsdd/contract/fixture/gen/expected/ '
    '[run, gen:generate, {input}/word.txt, {output}] '
    'hsdd/contract/fixture/gen/input hsdd/contract/fixture/gen/expected';

const String notAdmittedG1 =
    'PASS file hsdd/contract/fixture/gen/expected/: '
    'not run: the restriction does not admit all of G1';

const String coversNothing =
    'PASS file hsdd/contract/fixture/gen/expected/: '
    'not run: it covers no declared guarantee, and the replay is restricted';

void main() {
  group('planFileReplay', () {
    test('unrestricted with its package, the replay runs', () {
      expect(plan(gen), runLine);
    });
    test('a package the command runs that the workspace lacks is PENDING', () {
      expect(
        plan(gen, packages: const <String>{}),
        'PENDING file hsdd/contract/fixture/gen/expected/: '
        'package gen is absent from .dart_tool/package_config.json',
      );
    });
    test('the restriction admits it only when every id it covers is restricted, before PENDING', () {
      expect(
        plan(gen, restriction: const <GuaranteeRef>{(slug: 'gen', number: 1)}),
        runLine,
      );
      const Set<GuaranteeRef> g2 = <GuaranteeRef>{(slug: 'gen', number: 2)};
      expect(plan(gen, restriction: g2), notAdmittedG1);
      expect(
        plan(gen, packages: const <String>{}, restriction: g2),
        notAdmittedG1,
      );
      expect(
        plan(
          gen,
          restriction: const <GuaranteeRef>{(slug: 'other', number: 1)},
        ),
        notAdmittedG1,
      );
    });
    test('a file bullet that covers nothing runs only unrestricted', () {
      final SlugSnapshot uncovered = genWith(
        genContract.replaceFirst(' The file set covers G1.', ''),
      );
      expect(
        plan(
          uncovered,
          restriction: const <GuaranteeRef>{(slug: 'gen', number: 1)},
        ),
        coversNothing,
      );
      expect(plan(uncovered), runLine);
    });
    test('a command it cannot read fails, admitted or not', () {
      const Set<GuaranteeRef> g2 = <GuaranteeRef>{(slug: 'gen', number: 2)};
      expect(
        plan(
          genWith(
            genContract.replaceFirst(
              'fvm dart run gen:generate',
              'gen:generate',
            ),
          ),
          restriction: g2,
        ),
        'FAIL file hsdd/contract/fixture/gen/expected/: command (the '
        'generator command does not begin with fvm dart or dart: '
        'gen:generate {input}/word.txt {output})',
      );
      final SlugSnapshot textless = snapshotOf(
        'gen',
        changed(genFiles, <String, String?>{'hsdd/contract/gen.md': null}),
      );
      const String noText =
          'FAIL file hsdd/contract/fixture/gen/expected/: '
          'command (no contract text at hsdd/contract/gen.md)';
      expect(plan(textless, restriction: g2), noText);
      expect(plan(textless), noText);
    });

    // Beyond the brief: the rules the seven steps above leave unpinned.
    test(
      'a contract text that is not UTF-8 fails with its reason, not as absent',
      () {
        final SlugSnapshot undecodable = snapshotOf(
          'gen',
          genFiles,
          bytes: <String, List<int>>{
            'hsdd/contract/gen.md': <int>[0x2d, 0xff],
          },
        );
        expect(
          plan(undecodable),
          'FAIL file hsdd/contract/fixture/gen/expected/: command '
          '(hsdd/contract/gen.md: ${undecodable.contractUndecodable})',
        );
        expect(undecodable.contractUndecodable, startsWith('not UTF-8: '));
      },
    );
    test('the ids are the union of every - file: covers clause, and no - schema: one', () {
      final SlugSnapshot twoClauses = genWith(
        genContract.replaceFirst(
          '- invocations:',
          '- file: `expected/` also holds `notes.txt`. The file set covers G3.\n'
              '- schema: `hsdd/contract/schema/gen.schema.json`, '
              'JSON Schema draft 2020-12; covers G2.\n'
              '- invocations:',
        ),
      );
      expect(
        plan(
          twoClauses,
          restriction: const <GuaranteeRef>{(slug: 'gen', number: 1)},
        ),
        'PASS file hsdd/contract/fixture/gen/expected/: '
        'not run: the restriction does not admit all of G1, G3',
      );
      expect(
        plan(
          twoClauses,
          restriction: const <GuaranteeRef>{
            (slug: 'gen', number: 1),
            (slug: 'gen', number: 3),
          },
        ),
        runLine,
      );
    });
    test('a malformed covers clause contributes no id', () {
      final SlugSnapshot malformed = genWith(
        genContract.replaceFirst(
          'The file set covers G1.',
          'The file set covers G1 and the rest.',
        ),
      );
      expect(
        plan(
          malformed,
          restriction: const <GuaranteeRef>{(slug: 'gen', number: 1)},
        ),
        coversNothing,
      );
      expect(plan(malformed), runLine);
    });
    test('two generator commands fail with the reason readGeneratorCommand gives', () {
      expect(
        plan(
          genWith(
            genContract.replaceFirst(
              '- invocations:',
              '- file: or `fvm dart run gen:other {output}`.\n- invocations:',
            ),
          ),
          packages: const <String>{},
        ),
        'FAIL file hsdd/contract/fixture/gen/expected/: command (2 backticked '
        'spans of - file: bullets hold {output} and a space, expected one: '
        'fvm dart run gen:generate {input}/word.txt {output}; '
        'fvm dart run gen:other {output})',
      );
    });
    test(
      'a command that runs no package runs whatever the workspace holds',
      () {
        expect(
          plan(
            genWith(
              genContract.replaceFirst(
                'fvm dart run gen:generate',
                'dart tool/generate.dart',
              ),
            ),
            packages: const <String>{},
          ),
          'RUN hsdd/contract/fixture/gen/expected/ '
          '[tool/generate.dart, {input}/word.txt, {output}] '
          'hsdd/contract/fixture/gen/input hsdd/contract/fixture/gen/expected',
        );
      },
    );
    test('the file replay is named by the expected tree it compares', () {
      expect(fileReplayPath('gen'), path);
      expect(
        planFileReplay(gen, packages: const <String>{}, restriction: null).path,
        path,
      );
    });
  });

  group('generatorArguments', () {
    final FileRun run = planFileReplay(
      gen,
      packages: const <String>{'gen'},
      restriction: null,
    ) as FileRun;
    test('{input} and {output} become the paths given, wherever they occur in a word', () {
      expect(
        generatorArguments(
          run,
          input: '/w/hsdd/contract/fixture/gen/input',
          output: '/t/output',
        ),
        <String>[
          'run',
          'gen:generate',
          '/w/hsdd/contract/fixture/gen/input/word.txt',
          '/t/output',
        ],
      );
    });

    // Beyond the brief: every occurrence, and no substitution of a substitution.
    test(
      'every occurrence is replaced once, and a path given is not read again',
      () {
        const FileRun several = FileRun(
          path: path,
          arguments: <String>['{input}:{input}', '--out={output}', 'plain', ''],
          input: 'hsdd/contract/fixture/gen/input',
          expected: 'hsdd/contract/fixture/gen/expected',
        );
        expect(
          generatorArguments(
            several,
            input: '/a/{output}',
            output: '/o/{input}',
          ),
          <String>['/a/{output}:/a/{output}', '--out=/o/{input}', 'plain', ''],
        );
      },
    );
  });

  group('fileOutcome', () {
    final FileRun run = planFileReplay(
      gen,
      packages: const <String>{'gen'},
      restriction: null,
    ) as FileRun;
    final FileTree e = treeOf(<String, List<int>>{
      'notes.txt': utf8.encode(genNotes),
    });
    final FileTree changedNotes = treeOf(<String, List<int>>{
      'notes.txt': utf8.encode('from Hello\n'),
    });
    const ProcessExit ok = (code: 0, stdout: '', stderr: '');
    const ProcessExit failedAfterWriting = (
      code: 1,
      stdout: '',
      stderr: '\nfailed after writing\n',
    );
    const ProcessExit unparsed = (
      code: 65,
      stdout: '',
      stderr: 'Could not format because the source could not be parsed:\n\nline 2 ...',
    );

    String outcome({
      ProcessExit generator = ok,
      ProcessExit format = ok,
      FileTree? actual,
    }) => outcomeLine(
      CheckSet.file,
      fileOutcome(
        run,
        generator: generator,
        format: format,
        expected: e,
        actual: actual ?? e,
      ),
    );

    test('both exits 0 and equal trees pass', () {
      expect(outcome(), 'PASS file hsdd/contract/fixture/gen/expected/');
    });
    test('a generator that exits non-zero fails, with its first stderr line when there is one', () {
      expect(
        outcome(generator: failedAfterWriting),
        'FAIL file hsdd/contract/fixture/gen/expected/: '
        'exit (the generator exited 1: failed after writing)',
      );
      expect(
        outcome(generator: (code: 255, stdout: '', stderr: '')),
        'FAIL file hsdd/contract/fixture/gen/expected/: '
        'exit (the generator exited 255)',
      );
    });
    test('a format that exits non-zero fails with its first stderr line', () {
      expect(
        outcome(format: unparsed),
        'FAIL file hsdd/contract/fixture/gen/expected/: format (dart format '
        'exited 65: Could not format because the source could not be parsed:)',
      );
    });
    test('trees that differ fail by treeProblems', () {
      expect(
        outcome(actual: changedNotes),
        'FAIL file hsdd/contract/fixture/gen/expected/: '
        'changed-file (notes.txt: first difference at byte 5)',
      );
    });
    test('every problem that applies, in the order exit, format, tree', () {
      expect(
        outcome(
          generator: failedAfterWriting,
          format: unparsed,
          actual: changedNotes,
        ),
        'FAIL file hsdd/contract/fixture/gen/expected/: '
        'exit (the generator exited 1: failed after writing); '
        'format (dart format exited 65: Could not format because the source '
        'could not be parsed:); '
        'changed-file (notes.txt: first difference at byte 5)',
      );
    });

    // Beyond the brief: stdout never reads as the reason, a blank stderr adds
    // nothing, and every tree problem follows the exits in path order.
    test('stdout is not the reason, and a blank stderr adds nothing', () {
      expect(
        outcome(
          generator: (code: 3, stdout: 'wrote it\n', stderr: ' \n\t\n'),
          format: (code: 65, stdout: 'line 1', stderr: ''),
        ),
        'FAIL file hsdd/contract/fixture/gen/expected/: '
        'exit (the generator exited 3); format (dart format exited 65)',
      );
    });
    test('a non-zero exit comes before the tree problems, a hidden file written among them', () {
      expect(
        outcome(
          generator: (code: 2, stdout: '', stderr: 'usage: generate\n'),
          actual: treeOf(const <String, List<int>>{'.hidden': <int>[]}),
        ),
        'FAIL file hsdd/contract/fixture/gen/expected/: '
        'exit (the generator exited 2: usage: generate); '
        'extra-file (.hidden); missing-file (notes.txt)',
      );
    });

    // The controller's ruling on Task 3: an entry the shell could not read
    // fails the replay as its own problem, after the exits.
    test('an entry the shell could not read is an unreadable-file problem', () {
      expect(
        outcome(
          format: unparsed,
          actual: const <String, FileEntry>{
            'notes.txt': FileUnreadable('a dangling link'),
          },
        ),
        'FAIL file hsdd/contract/fixture/gen/expected/: format (dart format '
        'exited 65: Could not format because the source could not be '
        'parsed:); unreadable-file (notes.txt in output: a dangling link)',
      );
    });
  });
}
