// packages/nidana_contract_check/test/cli_set_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:nidana_contract_check/src/cli_set.dart';
import 'package:nidana_contract_check/src/command.dart';
import 'package:nidana_contract_check/src/contract.dart';
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/packages.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/shell.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/tree.dart';
import 'package:nidana_contract_check/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/generator.dart';
import 'support/sample.dart';

const String i = 'hsdd/contract/fixture/gen/invocation/';

final SlugSnapshot gen = snapshotOf('gen', genFiles);

/// [plan] as text: an [InvocationSettled] by its report line, an [InvocationRun] as
/// `RUN {path} {command} files: {files} expected: {expected} exit: {exitCode} stdout: {stdout}
/// stderr: {stderr}`, an absent directory or stream as `-` and a stream JSON-encoded.
String describe(InvocationPlan plan) => switch (plan) {
  InvocationSettled(:final FixtureOutcome outcome) => outcomeLine(
    CheckSet.cli,
    outcome,
  ),
  InvocationRun(
    :final String path,
    :final Command command,
    :final String? files,
    :final String? expected,
    :final int exitCode,
    :final String? stdout,
    :final String? stderr,
  ) =>
    'RUN $path ${commandText(command)} files: ${files ?? '-'} '
        'expected: ${expected ?? '-'} exit: $exitCode '
        'stdout: ${stdout == null ? '-' : jsonEncode(stdout)} '
        'stderr: ${stderr == null ? '-' : jsonEncode(stderr)}',
};

/// The plans of [snapshot] under [restriction] with [packages], each as [describe] gives it.
List<String> plans(
  SlugSnapshot snapshot, {
  Set<String> packages = const <String>{'gen'},
  Set<GuaranteeRef>? restriction,
}) => planInvocations(
  snapshot,
  packages: packages,
  restriction: restriction,
).map(describe).toList();

/// The plan of the case [name] of [snapshot], as [describe] gives it.
String planOf(
  String name,
  SlugSnapshot snapshot, {
  Set<String> packages = const <String>{'gen'},
  Set<GuaranteeRef>? restriction,
}) => describe(
  planInvocations(
    snapshot,
    packages: packages,
    restriction: restriction,
  ).singleWhere((InvocationPlan plan) => plan.path == '$i$name/'),
);

/// The `gen` snapshot with [changes] applied to [genFiles] and [bytes] given as raw bytes.
SlugSnapshot genWith(
  Map<String, String?> changes, {
  Map<String, List<int>> bytes = const <String, List<int>>{},
}) => snapshotOf('gen', changed(genFiles, changes), bytes: bytes);

/// [genContract] with [row] appended to its Case table, which ends the text.
String withRow(String row) => '$genContract$row\n';

/// The run of the case [name] of [gen], unrestricted with its package.
InvocationRun runOf(String name) =>
    planInvocations(
          gen,
          packages: const <String>{'gen'},
          restriction: null,
        ).singleWhere((InvocationPlan plan) => plan.path == '$i$name/')
        as InvocationRun;

/// What [plan] does with its case: `run`, `pending`, `not run`, or the report line of any other
/// outcome, a fixture defect.
String verdictOf(InvocationPlan plan) => switch (plan) {
  InvocationRun() => 'run',
  InvocationSettled(outcome: Pending()) => 'pending',
  InvocationSettled(outcome: Passed(:final String detail))
      when detail.startsWith('not run: ') =>
    'not run',
  InvocationSettled(:final FixtureOutcome outcome) => outcomeLine(
    CheckSet.cli,
    outcome,
  ),
};

/// The restriction id G{number} of `gen`.
GuaranteeRef g(int number) => (slug: 'gen', number: number);

const String absentGen =
    'package gen is absent from .dart_tool/package_config.json';

const String usageLine =
    'usage: generate [--echo] [--write-then-fail] <input> <output>\n';

const String notUtf8 = 'not UTF-8: Invalid UTF-8 byte (at offset 0)';

const String analyzeLibRun =
    'RUN ${i}analyze-lib/ dart [analyze, --format=machine, .] '
    'files: ${i}analyze-lib/files expected: - exit: 2 '
    'stdout: "WARNING|STATIC_WARNING|UNUSED_IMPORT|{files}/lib/a.dart|1|8|12|'
    'Unused import: \'dart:async\'.\\n" stderr: -';

void main() {
  group('planInvocations', () {
    test('each case directory gives one plan, ascending, with its recordings', () {
      expect(plans(gen), <String>[
        analyzeLibRun,
        'RUN ${i}generate-from-files/ package gen:generate [word.txt, {output}] '
            'files: ${i}generate-from-files/files '
            'expected: ${i}generate-from-files/expected exit: 0 '
            'stdout: "wrote {output}\\ncwd {files}\\n" stderr: -',
        'RUN ${i}generate-tree/ package gen:generate '
            '[--echo, hsdd/contract/fixture/gen/input/word.txt, {output}] '
            'files: - expected: ${i}generate-tree/expected exit: 0 '
            'stdout: "wrote {output}\\ncwd {root}\\nresolved {output}\\n" '
            'stderr: -',
        'RUN ${i}generate-usage/ package gen:generate [--frob, {output}] '
            'files: - expected: - exit: 2 stdout: - '
            'stderr: "usage: generate [--echo] [--write-then-fail] <input> '
            '<output>\\n"',
      ]);
    });
    test('a package the command runs that the workspace lacks is PENDING; a dart command names none', () {
      expect(plans(gen, packages: const <String>{}), <String>[
        analyzeLibRun,
        'PENDING cli ${i}generate-from-files/: $absentGen',
        'PENDING cli ${i}generate-tree/: $absentGen',
        'PENDING cli ${i}generate-usage/: $absentGen',
      ]);
    });
    test('a plugin files/analysis_options.yaml enables is a package the command runs', () {
      final SlugSnapshot plugin = genWith(<String, String>{
        'hsdd/contract/gen.md': withRow(
          '| `analyze-plugin` | `dart analyze .` | 0 | G5 |',
        ),
        '${i}analyze-plugin/args': 'dart\nanalyze\n.\n',
        '${i}analyze-plugin/exit_code': '0\n',
        '${i}analyze-plugin/files/analysis_options.yaml':
            'plugins:\n  absent_lint:\n    path: ../absent_lint\n',
      });
      expect(
        planOf('analyze-plugin', plugin),
        'PENDING cli ${i}analyze-plugin/: '
        'package absent_lint is absent from .dart_tool/package_config.json',
      );
      expect(
        planOf(
          'analyze-plugin',
          plugin,
          packages: const <String>{'gen', 'absent_lint'},
        ),
        'RUN ${i}analyze-plugin/ dart [analyze, .] '
        'files: ${i}analyze-plugin/files expected: - exit: 0 '
        'stdout: - stderr: -',
      );
    });
    test(
      'a case runs only when every id it covers is restricted, before PENDING',
      () {
        expect(
          plans(
            gen,
            packages: const <String>{},
            restriction: <GuaranteeRef>{g(2)},
          ),
          <String>[
            'PASS cli ${i}analyze-lib/: '
                'not run: the restriction does not admit all of G5',
            'PASS cli ${i}generate-from-files/: '
                'not run: the restriction does not admit all of G4',
            'PASS cli ${i}generate-tree/: '
                'not run: the restriction does not admit all of G1, G3',
            'PENDING cli ${i}generate-usage/: $absentGen',
          ],
        );
        expect(
          plans(
            gen,
            packages: const <String>{},
            restriction: <GuaranteeRef>{g(1)},
          ),
          <String>[
            'PASS cli ${i}analyze-lib/: '
                'not run: the restriction does not admit all of G5',
            'PASS cli ${i}generate-from-files/: '
                'not run: the restriction does not admit all of G4',
            'PASS cli ${i}generate-tree/: '
                'not run: the restriction does not admit all of G1, G3',
            'PASS cli ${i}generate-usage/: '
                'not run: the restriction does not admit all of G2',
          ],
        );
      },
    );
    test('a case with no row runs only unrestricted', () {
      final SlugSnapshot extra = genWith(<String, String>{
        '${i}extra/args': 'dart\n--version\n',
        '${i}extra/exit_code': '0\n',
      });
      expect(
        planOf('extra', extra),
        'RUN ${i}extra/ dart [--version] files: - expected: - exit: 0 '
        'stdout: - stderr: -',
      );
      expect(
        planOf('extra', extra, restriction: <GuaranteeRef>{g(2)}),
        'PASS cli ${i}extra/: not run: it covers no declared guarantee, and '
        'the replay is restricted',
      );
    });
    test('fixture defects fail the case, admitted or not', () {
      String usage(
        Map<String, String?> changes, {
        Map<String, List<int>> bytes = const <String, List<int>>{},
      }) => planOf(
        'generate-usage',
        genWith(changes, bytes: bytes),
        restriction: <GuaranteeRef>{g(5)},
      );
      String exitCodeHolds(String json) =>
          'FAIL cli ${i}generate-usage/: exit-code (exit_code holds $json, '
          'expected a decimal exit code from 0 to 255 and an optional '
          'newline)';

      expect(
        usage(<String, String?>{
          '${i}generate-usage/args': null,
          '${i}generate-usage/exit_code': null,
        }),
        'FAIL cli ${i}generate-usage/: command (no args file); '
        'exit-code (no exit_code file)',
      );
      expect(
        usage(<String, String>{'${i}generate-usage/exit_code': 'x\n'}),
        exitCodeHolds(r'"x\n"'),
      );
      expect(
        usage(<String, String>{'${i}generate-usage/exit_code': '256\n'}),
        exitCodeHolds(r'"256\n"'),
      );
      expect(
        usage(<String, String>{'${i}generate-usage/exit_code': '02\n'}),
        exitCodeHolds(r'"02\n"'),
      );
      expect(
        usage(<String, String>{'${i}generate-usage/exit_code': '-1\n'}),
        exitCodeHolds(r'"-1\n"'),
      );
      expect(
        usage(<String, String>{'${i}generate-usage/exit_code': '2'}),
        'PASS cli ${i}generate-usage/: '
        'not run: the restriction does not admit all of G2',
      );
      expect(
        usage(
          const <String, String>{},
          bytes: <String, List<int>>{
            '${i}generate-usage/args': <int>[0xff],
          },
        ),
        'FAIL cli ${i}generate-usage/: command (args: $notUtf8)',
      );
      expect(
        usage(<String, String>{'${i}generate-usage/args': 'fvm dart\n'}),
        'FAIL cli ${i}generate-usage/: command (args names no command: '
        '"fvm dart"; the command is dart, flutter or {package}:{executable})',
      );
      expect(
        usage(
          const <String, String>{},
          bytes: <String, List<int>>{
            '${i}generate-usage/stderr': <int>[0xff],
          },
        ),
        'FAIL cli ${i}generate-usage/: recording (stderr: $notUtf8)',
      );
    });

    // Beyond the brief: the rules the six steps above leave unpinned.
    test('every defect of a case is in its one FAIL, in the order command, exit-code, stdout, stderr', () {
      expect(
        planOf(
          'generate-usage',
          genWith(
            <String, String>{
              '${i}generate-usage/args': 'fvm dart\n',
              '${i}generate-usage/exit_code': 'x',
            },
            bytes: <String, List<int>>{
              '${i}generate-usage/stdout': <int>[0xff],
              '${i}generate-usage/stderr': <int>[0x41, 0xc3],
            },
          ),
        ),
        'FAIL cli ${i}generate-usage/: command (args names no command: '
        '"fvm dart"; the command is dart, flutter or {package}:{executable}); '
        'exit-code (exit_code holds "x", expected a decimal exit code from 0 '
        'to 255 and an optional newline); recording (stdout: $notUtf8); '
        'recording (stderr: not UTF-8: Unfinished UTF-8 octet sequence '
        '(at offset 2))',
      );
    });
    test('exit_code is 0 to 255 with no leading zero, no sign, no space and at most one final newline', () {
      String usage(String exitCode) => planOf(
        'generate-usage',
        genWith(<String, String>{'${i}generate-usage/exit_code': exitCode}),
      );
      String exitCodeHolds(String json) =>
          'FAIL cli ${i}generate-usage/: exit-code (exit_code holds $json, '
          'expected a decimal exit code from 0 to 255 and an optional '
          'newline)';

      for (final (String text, int code) in <(String, int)>[
        ('0', 0),
        ('0\n', 0),
        ('255\n', 255),
        ('7', 7),
      ]) {
        expect(usage(text), contains(' exit: $code '), reason: text);
      }
      for (final (String text, String json) in <(String, String)>[
        ('', '""'),
        ('\n', r'"\n"'),
        ('2\n\n', r'"2\n\n"'),
        ('2\r\n', r'"2\r\n"'),
        (' 2\n', r'" 2\n"'),
        ('+2\n', r'"+2\n"'),
        ('00\n', r'"00\n"'),
        ('99999999999999999999\n', r'"99999999999999999999\n"'),
      ]) {
        expect(usage(text), exitCodeHolds(json), reason: json);
      }
      expect(
        planOf(
          'generate-usage',
          genWith(
            const <String, String>{},
            bytes: <String, List<int>>{
              '${i}generate-usage/exit_code': <int>[0xff],
            },
          ),
        ),
        'FAIL cli ${i}generate-usage/: exit-code (exit_code: $notUtf8)',
      );
    });
    test('a stdout that is not UTF-8 is a recording defect, and an empty stream is recorded', () {
      expect(
        planOf(
          'generate-from-files',
          genWith(
            const <String, String>{},
            bytes: <String, List<int>>{
              '${i}generate-from-files/stdout': <int>[0xff],
            },
          ),
        ),
        'FAIL cli ${i}generate-from-files/: recording (stdout: $notUtf8)',
      );
      expect(
        planOf(
          'generate-usage',
          genWith(<String, String>{'${i}generate-usage/stdout': ''}),
        ),
        endsWith(
          ' exit: 2 stdout: "" stderr: "usage: generate [--echo] '
          '[--write-then-fail] <input> <output>\\n"',
        ),
      );
    });
    test('the first row that names a case gives its ids; a malformed Covers cell gives none', () {
      final SlugSnapshot twice = genWith(<String, String>{
        'hsdd/contract/gen.md': withRow(
          '| `generate-usage` | `gen:generate --frob {output}` | 2 | G5 |',
        ),
      });
      expect(
        planOf('generate-usage', twice, restriction: <GuaranteeRef>{g(2)}),
        startsWith('RUN ${i}generate-usage/ '),
      );
      expect(
        planOf('generate-usage', twice, restriction: <GuaranteeRef>{g(5)}),
        'PASS cli ${i}generate-usage/: '
        'not run: the restriction does not admit all of G2',
      );
      final SlugSnapshot malformed = genWith(<String, String>{
        'hsdd/contract/gen.md': genContract.replaceFirst(
          '| 2 | G2 |',
          '| 2 | G2 and more |',
        ),
      });
      expect(
        planOf('generate-usage', malformed, restriction: <GuaranteeRef>{g(2)}),
        'PASS cli ${i}generate-usage/: not run: it covers no declared '
        'guarantee, and the replay is restricted',
      );
      expect(
        planOf('generate-usage', malformed),
        startsWith('RUN ${i}generate-usage/ '),
      );
    });
    test('the packages of the command and of its plugins are PENDING together, ascending, the options read leniently', () {
      final SlugSnapshot both = genWith(<String, String>{
        '${i}generate-from-files/files/analysis_options.yaml':
            'plugins:\n  zeta_lint:\n    path: ../z\n'
            '  absent_lint:\n    path: ../a\n',
      });
      expect(
        planOf('generate-from-files', both, packages: const <String>{}),
        'PENDING cli ${i}generate-from-files/: packages absent_lint, gen, '
        'zeta_lint are absent from .dart_tool/package_config.json',
      );
      expect(
        planOf(
          'generate-from-files',
          genWith(
            const <String, String>{},
            bytes: <String, List<int>>{
              '${i}generate-from-files/files/analysis_options.yaml': <int>[
                0xff,
                0x0a,
                ...utf8.encode('plugins:\n  absent_lint:\n'),
              ],
            },
          ),
          packages: const <String>{'gen'},
        ),
        'PENDING cli ${i}generate-from-files/: package absent_lint is absent '
        'from .dart_tool/package_config.json',
      );
    });
    test('the cases are the directories directly under invocation/', () {
      final SlugSnapshot stray = genWith(<String, String>{
        '${i}README': 'not a case\n',
      });
      expect(plans(stray), plans(gen));
      expect(
        plans(
          snapshotOf('gen', <String, String>{
            'hsdd/contract/gen.md': genContract,
          }),
        ),
        isEmpty,
      );
    });
    test('a contract text the set cannot read fails every case, admitted or not', () {
      final SlugSnapshot textless = genWith(<String, String?>{
        'hsdd/contract/gen.md': null,
      });
      for (final Set<GuaranteeRef>? restriction in <Set<GuaranteeRef>?>[
        null,
        <GuaranteeRef>{g(2)},
      ]) {
        expect(plans(textless, restriction: restriction), <String>[
          for (final String name in <String>[
            'analyze-lib',
            'generate-from-files',
            'generate-tree',
            'generate-usage',
          ])
            'FAIL cli $i$name/: '
                'command (no contract text at hsdd/contract/gen.md)',
        ]);
      }
      final SlugSnapshot undecodable = genWith(
        const <String, String>{},
        bytes: <String, List<int>>{
          'hsdd/contract/gen.md': <int>[0x2d, 0xff],
        },
      );
      expect(
        planOf('generate-usage', undecodable),
        'FAIL cli ${i}generate-usage/: command (hsdd/contract/gen.md: '
        'not UTF-8: Invalid UTF-8 byte (at offset 1))',
      );
      expect(
        planOf(
          'generate-usage',
          genWith(
            <String, String?>{'${i}generate-usage/args': null},
            bytes: <String, List<int>>{
              'hsdd/contract/gen.md': <int>[0x2d, 0xff],
            },
          ),
        ),
        'FAIL cli ${i}generate-usage/: command (hsdd/contract/gen.md: '
        'not UTF-8: Invalid UTF-8 byte (at offset 1)); command (no args file)',
      );
    });
    // The committed cases are governance that hsdd-contract amends, and
    // another node's gate runs this suite: a property of whatever is
    // committed, never its counts or packages.
    test('every committed case plans without a fixture defect: as a run, PENDING, or not run', () {
      final Directory root = findWorkspaceRoot(Directory.current)!;
      final Map<String, Set<String>> packageSets = <String, Set<String>>{
        'no package': const <String>{},
        'the workspace packages': packageNamesOf(
          File(workspacePath(root, packageConfigPath)).readAsStringSync(),
        )!,
      };
      final List<SlugSnapshot> snapshots = <SlugSnapshot>[
        for (final FileSystemEntity slug in Directory(
          workspacePath(root, 'hsdd/contract/fixture'),
        ).listSync())
          if (Directory(p.join(slug.path, 'invocation')).existsSync())
            readSnapshot(root, p.basename(slug.path)),
      ];
      final List<(String, String)> verdicts = <(String, String)>[
        for (final SlugSnapshot snapshot in snapshots)
          for (final Set<GuaranteeRef>? restriction in <Set<GuaranteeRef>?>[
            null,
            if (snapshot.contractText case final String text)
              for (final int number in readContract(
                snapshot.slug,
                text,
              ).guarantees)
                <GuaranteeRef>{(slug: snapshot.slug, number: number)},
          ])
            for (final MapEntry<String, Set<String>>(
                  key: String named,
                  value: Set<String> packages,
                )
                in packageSets.entries)
              for (final InvocationPlan plan in planInvocations(
                snapshot,
                packages: packages,
                restriction: restriction,
              ))
                (
                  '${plan.path} with $named, '
                      'restricted to ${restriction ?? 'nothing'}',
                  verdictOf(plan),
                ),
      ];
      expect(verdicts, isNotEmpty);
      for (final (String context, String verdict) in verdicts) {
        expect(
          verdict,
          isIn(const <String>['run', 'pending', 'not run']),
          reason: context,
        );
      }
    });
  });

  group('invocationPath and namesOutput', () {
    test('a recorded invocation is named by its case directory', () {
      expect(invocationPath('gen', 'generate-usage'), '${i}generate-usage/');
      expect(runOf('generate-usage').path, '${i}generate-usage/');
    });
    test(
      'a run names {output} only by an argument that is exactly {output}',
      () {
        expect(runOf('generate-usage').namesOutput, isTrue);
        expect(runOf('analyze-lib').namesOutput, isFalse);
        expect(
          const InvocationRun(
            path: '${i}x/',
            command: DartCommand(<String>['--out={output}', '{output}/a']),
            files: null,
            expected: null,
            exitCode: 0,
            stdout: null,
            stderr: null,
          ).namesOutput,
          isFalse,
        );
      },
    );
  });

  group('withPlaceholders', () {
    test(
      'withPlaceholders replaces the longer form of each path first, in order',
      () {
        expect(
          withPlaceholders(
            'a /private/var/t/output/b /var/t/output /w/x/files/c /w/d',
            const <PathForms>[
              (
                given: '/var/t/output',
                resolved: '/private/var/t/output',
                placeholder: '{output}',
              ),
              (
                given: '/w/x/files',
                resolved: '/w/x/files',
                placeholder: '{files}',
              ),
              (given: '/w', resolved: '/w', placeholder: '{root}'),
            ],
          ),
          'a {output}/b {output} {files}/c {root}/d',
        );
        expect(
          withPlaceholders('/link/ws/a /ws/b', const <PathForms>[
            (given: '/link/ws', resolved: '/ws', placeholder: '{root}'),
          ]),
          '{root}/a {root}/b',
        );
      },
    );

    // Beyond the brief: every occurrence, the forms' order, and no form at all.
    test('every occurrence is replaced, a later form only in what earlier ones left, and no form keeps the text', () {
      expect(
        withPlaceholders('/w/x/files/a /w/x/files/b', const <PathForms>[
          (given: '/w/x/files', resolved: '/w/x/files', placeholder: '{files}'),
          (given: '/w', resolved: '/w', placeholder: '{root}'),
        ]),
        '{files}/a {files}/b',
      );
      expect(
        withPlaceholders('/w/x/files/a', const <PathForms>[
          (given: '/w', resolved: '/w', placeholder: '{root}'),
          (given: '/w/x/files', resolved: '/w/x/files', placeholder: '{files}'),
        ]),
        '{root}/x/files/a',
      );
      expect(withPlaceholders('/w/a', const <PathForms>[]), '/w/a');
    });
  });

  group('invocationOutcome', () {
    final FileTree e = treeOf(<String, List<int>>{
      'notes.txt': utf8.encode(genNotes),
    });
    const ProcessExit ok = (code: 0, stdout: '', stderr: '');
    const ProcessExit usageExit = (code: 2, stdout: '', stderr: usageLine);
    const ProcessExit fromFilesExit = (
      code: 0,
      stdout: 'wrote {output}\ncwd {files}\n',
      stderr: '',
    );
    final FileTree empty = treeOf(const <String, List<int>>{});

    String outcome(
      InvocationRun run,
      ProcessExit exit,
      OutputState output, {
      FileTree? expected,
      List<PathForms> forms = const <PathForms>[],
    }) => outcomeLine(
      CheckSet.cli,
      invocationOutcome(
        run,
        exit: exit,
        output: output,
        expected: expected ?? empty,
        forms: forms,
      ),
    );

    test('a case without expected/ passes on its exit and stream with nothing at {output}', () {
      expect(
        outcome(runOf('generate-usage'), usageExit, const NoOutput()),
        'PASS cli ${i}generate-usage/',
      );
      expect(
        outcome(runOf('generate-usage'), (
          code: 0,
          stdout: '',
          stderr: usageLine,
        ), const NoOutput()),
        'FAIL cli ${i}generate-usage/: exit (exited 0, expected 2)',
      );
    });
    test('an exit, a stream and the tree that differ each fail, the exit with the first stderr line after forms', () {
      expect(
        outcome(
          runOf('generate-tree'),
          (
            code: 255,
            stdout: '',
            stderr: 'Could not find a file named "pubspec.yaml" in "/w".\n',
          ),
          const NoOutput(),
          expected: e,
          forms: const <PathForms>[
            (given: '/w', resolved: '/w', placeholder: '{root}'),
          ],
        ),
        'FAIL cli ${i}generate-tree/: exit (exited 255, expected 0: Could not '
        'find a file named "pubspec.yaml" in "{root}".); stdout (line 1: '
        'expected "wrote {output}", got ""); output (nothing at {output}, '
        'expected the tree of expected/)',
      );
    });
    test('a case with expected/ compares its stdout by line and the tree at {output}', () {
      final InvocationRun run = runOf('generate-from-files');
      expect(
        outcome(run, fromFilesExit, OutputTree(e, ok), expected: e),
        'PASS cli ${i}generate-from-files/',
      );
      expect(
        outcome(
          run,
          (code: 0, stdout: 'wrote {output}\ncwd {root}\n', stderr: ''),
          OutputTree(e, ok),
          expected: e,
        ),
        'FAIL cli ${i}generate-from-files/: '
        'stdout (line 2: expected "cwd {files}", got "cwd {root}")',
      );
      expect(
        outcome(
          run,
          (code: 0, stdout: 'wrote {output}\n', stderr: ''),
          OutputTree(e, ok),
          expected: e,
        ),
        'FAIL cli ${i}generate-from-files/: '
        'stdout (line 2: expected "cwd {files}", got "")',
      );
      expect(
        outcome(
          run,
          fromFilesExit,
          OutputTree(
            treeOf(<String, List<int>>{
              'notes.txt': utf8.encode('from Hello\n'),
            }),
            (code: 65, stdout: '', stderr: 'bad\n'),
          ),
          expected: e,
        ),
        'FAIL cli ${i}generate-from-files/: format (dart format exited 65: '
        'bad); changed-file (notes.txt: first difference at byte 5)',
      );
      expect(
        outcome(run, fromFilesExit, const OutputFile(), expected: e),
        'FAIL cli ${i}generate-from-files/: '
        'output ({output} is not a directory, expected the tree of expected/)',
      );
    });
    test('a case without expected/ fails on anything left at {output}', () {
      final InvocationRun run = runOf('generate-usage');
      expect(
        outcome(
          run,
          usageExit,
          OutputTree(
            treeOf(const <String, List<int>>{
              'notes.txt': <int>[1],
              'out.dart': <int>[2],
            }),
            null,
          ),
        ),
        'FAIL cli ${i}generate-usage/: output ({output} exists after the run, '
        'expected nothing there: notes.txt, out.dart)',
      );
      expect(
        outcome(run, usageExit, OutputTree(empty, null)),
        'FAIL cli ${i}generate-usage/: '
        'output ({output} exists after the run, expected nothing there)',
      );
      expect(
        outcome(run, usageExit, const OutputFile()),
        'FAIL cli ${i}generate-usage/: '
        'output ({output} is not a directory, expected nothing there)',
      );
    });

    // Beyond the brief: the rules the steps above leave unpinned.
    test('a recorded stderr is compared by line, and a stream not recorded is not compared', () {
      expect(
        outcome(runOf('generate-usage'), (
          code: 2,
          stdout: 'anything\n',
          stderr: 'usage: generate\n',
        ), const NoOutput()),
        'FAIL cli ${i}generate-usage/: stderr (line 1: expected "usage: '
        'generate [--echo] [--write-then-fail] <input> <output>", got "usage: '
        'generate")',
      );
      expect(
        outcome(
          runOf('generate-from-files'),
          (
            code: 0,
            stdout: 'wrote {output}\ncwd {files}\n',
            stderr: 'warning\n',
          ),
          OutputTree(e, ok),
          expected: e,
        ),
        'PASS cli ${i}generate-from-files/',
      );
    });
    test('a line one side lacks is end of output, and a carriage return is part of its line', () {
      final InvocationRun run = runOf('generate-from-files');
      String stdout(String text) => outcome(
        run,
        (code: 0, stdout: text, stderr: ''),
        OutputTree(e, ok),
        expected: e,
      );
      expect(
        stdout('wrote {output}\ncwd {files}'),
        'FAIL cli ${i}generate-from-files/: '
        'stdout (line 3: expected "", got end of output)',
      );
      expect(
        stdout('wrote {output}\ncwd {files}\n\n'),
        'FAIL cli ${i}generate-from-files/: '
        'stdout (line 4: expected end of output, got "")',
      );
      expect(
        stdout('wrote {output}\r\ncwd {files}\r\n'),
        'FAIL cli ${i}generate-from-files/: '
        r'stdout (line 1: expected "wrote {output}", got "wrote {output}\r")',
      );
    });
    test(
      'the streams compare after the placeholders, both forms of each path',
      () {
        expect(
          outcome(
            runOf('generate-tree'),
            (
              code: 0,
              stdout:
                  'wrote /var/t/output\ncwd /private/w\n'
                  'resolved /private/var/t/output\n',
              stderr: '',
            ),
            OutputTree(e, ok),
            expected: e,
            forms: const <PathForms>[
              (
                given: '/var/t/output',
                resolved: '/private/var/t/output',
                placeholder: '{output}',
              ),
              (given: '/w', resolved: '/private/w', placeholder: '{root}'),
            ],
          ),
          'PASS cli ${i}generate-tree/',
        );
      },
    );
    test('an exit that differs adds no stderr line when the case records stderr or there is none', () {
      expect(
        outcome(
          runOf('generate-tree'),
          (code: 1, stdout: '', stderr: ' \n\t\n'),
          OutputTree(e, ok),
          expected: e,
        ).split('; ').first,
        'FAIL cli ${i}generate-tree/: exit (exited 1, expected 0)',
      );
      expect(
        outcome(runOf('generate-usage'), (
          code: 1,
          stdout: '',
          stderr: 'boom\n',
        ), const NoOutput()).split('; ').first,
        'FAIL cli ${i}generate-usage/: exit (exited 1, expected 2)',
      );
    });
    test('every problem that applies, in the order exit, stdout, stderr, format, output', () {
      const InvocationRun both = InvocationRun(
        path: '${i}both/',
        command: DartCommand(<String>[]),
        files: null,
        expected: '${i}both/expected',
        exitCode: 0,
        stdout: 'a\n',
        stderr: 'b\n',
      );
      expect(
        outcome(
          both,
          (code: 1, stdout: 'x\n', stderr: 'y\n'),
          OutputTree(
            treeOf(const <String, List<int>>{
              'z': <int>[1],
            }),
            (code: 65, stdout: '', stderr: '\nbad\n'),
          ),
          expected: e,
        ),
        'FAIL cli ${i}both/: exit (exited 1, expected 0); stdout (line 1: '
        'expected "a", got "x"); stderr (line 1: expected "b", got "y"); '
        'format (dart format exited 65: bad); missing-file (notes.txt); '
        'extra-file (z)',
      );
    });
    test('what is left at {output} is listed by ascending path, hidden and nested ones included', () {
      expect(
        outcome(
          runOf('generate-usage'),
          usageExit,
          OutputTree(<String, FileEntry>{
            'b/c.txt': const FileBytes(<int>[]),
            'a.txt': const FileBytes(<int>[]),
            '.hidden': const FileUnreadable('a dangling link'),
          }, null),
        ),
        'FAIL cli ${i}generate-usage/: output ({output} exists after the run, '
        'expected nothing there: .hidden, a.txt, b/c.txt)',
      );
    });
  });
}
