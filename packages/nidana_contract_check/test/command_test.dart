// packages/nidana_contract_check/test/command_test.dart
import 'dart:io';

import 'package:nidana_contract_check/src/command.dart';
import 'package:nidana_contract_check/src/contract.dart';
import 'package:nidana_contract_check/src/packages.dart';
import 'package:nidana_contract_check/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/generator.dart';

/// [r] as text: a [CommandRead] by [commandText], a [CommandUnreadable] as
/// `unreadable: {reason}`.
String read(CommandReading r) => switch (r) {
  CommandRead(:final Command command) => commandText(command),
  CommandUnreadable(:final String reason) => 'unreadable: $reason',
};

/// [process] as text: `{executable} [{arguments}]`, or `null`.
String processText(CommandProcess? process) => process == null
    ? 'null'
    : '${process.executable} [${process.arguments.join(', ')}]';

/// The committed `nidana-checks/invocation/analyze-configuration/files/analysis_options.yaml`.
const String analyzeConfiguration = '''
# Enables the plugin under test by a relative path to the workspace member
# (ADR-001 item 7, ADR-002 item 7), and configures it per diagnostic code:
# one rule disabled, one lowered to info, one raised to error (Guide C.1's
# configurable error), one left at its default.
plugins:
  nidana_dart_lint:
    path: ../../../../../../../packages/nidana_dart_lint
    diagnostics:
      raw_string_topic: false
      global_bus_accessor: info
      unflagged_sensitive_topic: error
''';

const String twoPlugins =
    'plugins:\n  # a lint\n  a_lint:\n    path: x\n  b_lint:\n    path: y\n'
    'analyzer:\n  language:\n    strict-casts: true\n';

/// The workspace root that holds the test run.
final String root = findWorkspaceRoot(Directory.current)!.path;

/// The committed files at [name], a `/`-separated path, below each
/// `hsdd/contract/fixture/*/invocation/*/` directory of the workspace, ascending by path.
List<File> committedRecords(String name) {
  final Directory fixtures = Directory(
    p.join(root, 'hsdd', 'contract', 'fixture'),
  );
  return <File>[
    for (final FileSystemEntity slug in fixtures.listSync())
      if (Directory(p.join(slug.path, 'invocation'))
          case final Directory invocations when invocations.existsSync())
        for (final FileSystemEntity invocation in invocations.listSync())
          if (File(p.joinAll(<String>[invocation.path, ...p.posix.split(name)]))
              case final File record when record.existsSync())
            record,
  ]..sort((File a, File b) => a.path.compareTo(b.path));
}

void main() {
  group('commandText', () {
    test(
      'renders each kind with its arguments joined by a comma and a space',
      () {
        expect(commandText(const DartCommand(<String>['', 'x'])), 'dart [, x]');
        expect(
          commandText(const PackageCommand('gen', 'generate', <String>[])),
          'package gen:generate []',
        );
        expect(
          commandText(const FlutterCommand(<String>['test', 'a'])),
          'flutter [test, a]',
        );
      },
    );
  });

  group('readGeneratorCommand', () {
    test(
      'reads the words after a leading fvm dart or dart as a dart command',
      () {
        expect(
          read(
            readGeneratorCommand(const <String>[
              'fvm dart run gen:generate {input}/word.txt {output}',
            ]),
          ),
          'dart [run, gen:generate, {input}/word.txt, {output}]',
        );
        expect(
          read(
            readGeneratorCommand(const <String>[
              'dart  run gen:generate {output}',
            ]),
          ),
          'dart [run, gen:generate, {output}]',
        );
      },
    );
    test('no span is unreadable', () {
      expect(
        read(readGeneratorCommand(const <String>[])),
        'unreadable: no - file: bullet names a generator command: a backticked '
        'span that holds {output} and a space',
      );
    });
    test('two spans are unreadable, each named', () {
      expect(
        read(
          readGeneratorCommand(const <String>[
            'dart a {output}',
            'dart b {output}',
          ]),
        ),
        'unreadable: 2 backticked spans of - file: bullets hold {output} and a '
        'space, expected one: dart a {output}; dart b {output}',
      );
    });
    test('a span that does not begin with fvm dart or dart is unreadable', () {
      expect(
        read(readGeneratorCommand(const <String>['gen:generate {output}'])),
        'unreadable: the generator command does not begin with fvm dart or '
        'dart: gen:generate {output}',
      );
    });

    // Beyond the brief: the words are split at spaces, so empty words go
    // wherever they are; fvm alone, or a word that only begins with dart, is
    // no leading dart.
    test('empty words go anywhere in the span; fvm without dart, or dartx, is unreadable', () {
      expect(
        read(
          readGeneratorCommand(const <String>[' fvm  dart run x  {output} ']),
        ),
        'dart [run, x, {output}]',
      );
      expect(
        read(
          readGeneratorCommand(const <String>['fvm run gen:generate {output}']),
        ),
        'unreadable: the generator command does not begin with fvm dart or '
        'dart: fvm run gen:generate {output}',
      );
      expect(
        read(readGeneratorCommand(const <String>['dartx run x {output}'])),
        'unreadable: the generator command does not begin with fvm dart or '
        'dart: dartx run x {output}',
      );
      expect(
        read(readGeneratorCommand(const <String>['fvm flutter test {output}'])),
        'unreadable: the generator command does not begin with fvm dart or '
        'dart: fvm flutter test {output}',
      );
    });

    // Beyond the brief: the committed topic-codegen@v1 text, read end to end.
    test('the committed topic-codegen generator command reads as dart run of nidana_dart_codegen', () {
      final CommandReading reading = readGeneratorCommand(
        readContract(
          'topic-codegen',
          File(p.join(root, 'hsdd', 'contract', 'topic-codegen.md'))
              .readAsStringSync(),
        ).generatorCommands,
      );
      expect(
        read(reading),
        'dart [run, nidana_dart_codegen:generate, --graph, '
        '{input}/topology-graph.json, {input}/topics.yaml, {output}]',
      );
      expect(commandPackages((reading as CommandRead).command), <String>{
        'nidana_dart_codegen',
      });
    });
  });

  group('readArgs', () {
    test('a {package}:{executable} first line reads as a package command', () {
      expect(
        read(readArgs('gen:generate\n--echo\n{output}\n')),
        'package gen:generate [--echo, {output}]',
      );
      expect(read(readArgs('gen:generate')), 'package gen:generate []');
    });
    test('a dart first line reads as a dart command; an empty line is an empty argument', () {
      expect(
        read(readArgs('dart\nanalyze\n--format=machine\n.\n')),
        'dart [analyze, --format=machine, .]',
      );
      expect(read(readArgs('dart\n\nx\n')), 'dart [, x]');
    });
    test('a flutter first line reads as a flutter command', () {
      expect(read(readArgs('flutter\n--version\n')), 'flutter [--version]');
    });
    test('no line, or a first line that names no command, is unreadable', () {
      expect(read(readArgs('')), 'unreadable: args holds no command');
      for (final (String text, String line) in const <(String, String)>[
        ('fvm dart\nx\n', '"fvm dart"'),
        ('\n', '""'),
        ('Gen:x\n', '"Gen:x"'),
        ('gen:a/b\n', '"gen:a/b"'),
      ]) {
        expect(
          read(readArgs(text)),
          'unreadable: args names no command: $line; the command is dart, '
          'flutter or {package}:{executable}',
          reason: text,
        );
      }
    });

    // Beyond the brief: one final empty element goes, no more; a line is kept
    // as written, so a CRLF line end stays part of it; the package pattern.
    test('only one final empty line is dropped, and a line keeps a carriage return', () {
      expect(read(readArgs('dart\n\n')), 'dart []');
      expect(read(readArgs('dart\nx\n\n')), 'dart [x, ]');
      expect(read(readArgs('dart\nx\r\n')), 'dart [x\r]');
      expect(
        read(readArgs('dart\r\nx\r\n')),
        r'unreadable: args names no command: "dart\r"; the command is dart, '
        'flutter or {package}:{executable}',
      );
    });
    test('{package} matches [a-z_][a-z0-9_]* and {executable} holds no space, : or /', () {
      expect(read(readArgs('_gen9:x-y.z\n')), 'package _gen9:x-y.z []');
      for (final String line in const <String>[
        'gen:',
        ':x',
        '9gen:x',
        'gen-x:y',
        'gen:a:b',
        'gen:a b',
        'gen',
        'Dart',
        ' dart',
      ]) {
        expect(
          read(readArgs('$line\n')),
          startsWith('unreadable: args names no command: '),
          reason: line,
        );
      }
    });

    // Beyond the brief: every committed recording is one the rules read.
    test('every committed invocation args reads as a command', () {
      final List<File> args = committedRecords('args');
      expect(args, isNotEmpty);
      for (final File file in args) {
        expect(
          readArgs(file.readAsStringSync()),
          isA<CommandRead>(),
          reason: file.path,
        );
      }
      expect(
        <String>{
          for (final File file in args)
            ...commandPackages(
              (readArgs(file.readAsStringSync()) as CommandRead).command,
            ),
        },
        <String>{'nidana_dart_codegen'},
      );
    });
  });

  group('commandPackages', () {
    test(
      'a package command runs its package; dart run, its target package',
      () {
        expect(
          commandPackages(const PackageCommand('gen', 'generate', <String>[])),
          <String>{'gen'},
        );
        expect(
          commandPackages(
            const DartCommand(<String>[
              'run',
              'nidana_dart_codegen:generate',
              '--graph',
              'x',
            ]),
          ),
          <String>{'nidana_dart_codegen'},
        );
        expect(
          commandPackages(
            const DartCommand(<String>['run', '--enable-asserts', 'gen']),
          ),
          <String>{'gen'},
        );
      },
    );
    test(
      'dart run of a file, another dart command and a flutter command run none',
      () {
        expect(
          commandPackages(const DartCommand(<String>['run', 'bin/x.dart'])),
          isEmpty,
        );
        expect(
          commandPackages(const DartCommand(<String>['analyze', '.'])),
          isEmpty,
        );
        expect(
          commandPackages(const FlutterCommand(<String>['test'])),
          isEmpty,
        );
      },
    );

    // Beyond the brief: only a first argument run counts, only for dart; the
    // target is the first argument after it that does not start with -.
    test('run must come first, for dart; the first later non-option argument is the target', () {
      expect(commandPackages(const DartCommand(<String>['run'])), isEmpty);
      expect(
        commandPackages(const DartCommand(<String>['run', '-v', '--'])),
        isEmpty,
      );
      expect(
        commandPackages(
          const DartCommand(<String>['run', '--', 'gen:x', 'other']),
        ),
        <String>{'gen'},
      );
      expect(
        commandPackages(const DartCommand(<String>['run', 'x.dart', 'gen'])),
        isEmpty,
      );
      expect(
        commandPackages(const DartCommand(<String>['run', 'Gen:x'])),
        isEmpty,
      );
      expect(
        commandPackages(const DartCommand(<String>['run', 'gen:a/b'])),
        isEmpty,
      );
      expect(
        commandPackages(const DartCommand(<String>['test', 'gen'])),
        isEmpty,
      );
      expect(commandPackages(const DartCommand(<String>[])), isEmpty);
      expect(
        commandPackages(const FlutterCommand(<String>['run', 'gen'])),
        isEmpty,
      );
    });
  });

  group('pluginPackages', () {
    test(
      'the committed analyze-configuration options enable nidana_dart_lint',
      () {
        expect(pluginPackages(analyzeConfiguration), <String>{
          'nidana_dart_lint',
        });
      },
    );
    test('the keys at the first indentation of the top-level plugins: section, LF or CRLF', () {
      expect(pluginPackages(twoPlugins), <String>{'a_lint', 'b_lint'});
      expect(pluginPackages(twoPlugins.replaceAll('\n', '\r\n')), <String>{
        'a_lint',
        'b_lint',
      });
    });
    test(
      'a nested plugins: list, the legacy form, and an empty text enable none',
      () {
        expect(
          pluginPackages('analyzer:\n  plugins:\n    - old_lint\n'),
          isEmpty,
        );
        expect(pluginPackages(''), isEmpty);
      },
    );

    // Beyond the brief: empty, blank and comment lines neither end the section
    // nor set its indentation; a comment at the margin does not end it; the
    // indentation is the first key's, at whatever depth.
    test('blank lines and comments at the margin stay in the section', () {
      expect(
        pluginPackages(
          'plugins:\n\n   \n# a note\n    a_lint:\n      path: x\n\n    b_lint: {}\n',
        ),
        <String>{'a_lint', 'b_lint'},
      );
    });
    test(
      'the section ends at the first line at the margin that is not a comment',
      () {
        expect(
          pluginPackages(
            'include: x.yaml\nplugins:\n  a_lint:\nlinter:\n  rules:\n',
          ),
          <String>{'a_lint'},
        );
        expect(
          pluginPackages('plugins:\n  a_lint:\n---\n  b_lint:\n'),
          <String>{'a_lint'},
        );
      },
    );
    test(
      'a line that is not a key at the first indentation names no plugin',
      () {
        expect(
          pluginPackages(
            'plugins:\n  - a_lint\n  B_lint:\n  "c_lint":\n  d_lint :\n',
          ),
          <String>{'d_lint'},
        );
        expect(pluginPackages('plugins: {}\n  a_lint:\n'), isEmpty);
        expect(pluginPackages('plugins:\n'), isEmpty);
      },
    );

    // Beyond the brief: every committed recording that configures the analyzer
    // enables the one plugin its cases test.
    test(
      'every committed files/analysis_options.yaml enables nidana_dart_lint',
      () {
        final List<File> options = committedRecords(
          'files/analysis_options.yaml',
        );
        expect(options, isNotEmpty);
        for (final File file in options) {
          expect(pluginPackages(file.readAsStringSync()), <String>{
            'nidana_dart_lint',
          }, reason: file.path);
        }
      },
    );
  });

  group('withOutput', () {
    test('replaces each argument that is exactly {output}, keeping package and executable', () {
      final Command c = withOutput(
        const PackageCommand('gen', 'generate', <String>[
          '--out={output}',
          '{output}',
          'x{output}',
        ]),
        '/t/output',
      );
      expect(c, isA<PackageCommand>());
      expect((c as PackageCommand).package, 'gen');
      expect(c.executable, 'generate');
      expect(c.arguments, <String>['--out={output}', '/t/output', 'x{output}']);
    });

    // Beyond the brief: the kind is kept for dart and flutter too.
    test('keeps a dart command dart and a flutter command flutter', () {
      expect(
        commandText(
          withOutput(const DartCommand(<String>['{output}', 'a']), '/o'),
        ),
        'dart [/o, a]',
      );
      expect(
        commandText(
          withOutput(const FlutterCommand(<String>['{output}']), '/o'),
        ),
        'flutter [/o]',
      );
    });
  });

  group('processOf', () {
    final Map<String, Uri> roots = <String, Uri>{
      'gen': Uri.parse('file:///w/packages/gen/'),
    };
    CommandProcess? process(Command command, {String? flutter}) => processOf(
      command,
      dart: '/sdk/dart',
      flutter: flutter,
      packageConfig: '/w/.dart_tool/package_config.json',
      roots: roots,
    );

    test('a dart command runs under dart', () {
      final CommandProcess? run = process(
        const DartCommand(<String>['analyze', '.']),
      );
      expect(run?.executable, '/sdk/dart');
      expect(run?.arguments, <String>['analyze', '.']);
    });
    test(
      'a flutter command runs under flutter, and has no process without one',
      () {
        expect(
          processText(
            process(
              const FlutterCommand(<String>['--version']),
              flutter: '/sdk/flutter',
            ),
          ),
          '/sdk/flutter [--version]',
        );
        expect(process(const FlutterCommand(<String>['--version'])), isNull);
      },
    );
    test('a package command runs its bin script under dart with the package configuration', () {
      expect(
        processText(
          process(const PackageCommand('gen', 'generate', <String>['a'])),
        ),
        '/sdk/dart [--packages=/w/.dart_tool/package_config.json, '
        '/w/packages/gen/bin/generate.dart, a]',
      );
      expect(process(const PackageCommand('nosuch', 'x', <String>[])), isNull);
    });

    // Beyond the brief: a package command and a dart command need no flutter;
    // a root whose path needs percent-decoding gives the file path.
    test('a dart or package command needs no flutter; the script is the root URI resolved as a file path', () {
      expect(
        processText(
          processOf(
            const PackageCommand('gen', 'generate', <String>[]),
            dart: '/sdk/dart',
            flutter: null,
            packageConfig: '/w/c.json',
            roots: <String, Uri>{'gen': Uri.parse('file:///my%20w/gen/')},
          ),
        ),
        '/sdk/dart [--packages=/w/c.json, /my w/gen/bin/generate.dart]',
      );
      expect(
        processText(
          process(const DartCommand(<String>['format', '.']), flutter: '/f'),
        ),
        '/sdk/dart [format, .]',
      );
    });

    // Beyond the brief: readArgs admits an executable holding #, ? or %, and
    // its script is that name, never a URI fragment, query or escape.
    test('an executable holding #, ? or % names its script as written', () {
      final CommandReading reading = readArgs('gen:a#b?c%41\n');
      expect(
        processText(process((reading as CommandRead).command)),
        '/sdk/dart [--packages=/w/.dart_tool/package_config.json, '
        '/w/packages/gen/bin/a#b?c%41.dart]',
      );
    });

    // Routed: the precondition on roots. Every root packageRootsOf gives
    // reads as a file path; a configuration holding one that does not is
    // refused there, so processOf never meets it in a replay.
    test('the roots packageRootsOf gives read as file paths, and a root that is no plain file: URI throws', () {
      final Map<String, Uri> read = packageRootsOf(
        '{"configVersion": 2, "packages": [{"name": "gen", "rootUri": "../packages/gen"}, {"name": "far", "rootUri": "file:///cache/far-1.0.0"}]}',
        Uri.parse('file:///w/.dart_tool/package_config.json'),
      )!;
      expect(
        <String>[
          for (final String package in <String>['gen', 'far'])
            processText(
              processOf(
                PackageCommand(package, 'run', const <String>[]),
                dart: '/sdk/dart',
                flutter: null,
                packageConfig: '/w/c.json',
                roots: read,
              ),
            ),
        ],
        <String>[
          '/sdk/dart [--packages=/w/c.json, /w/packages/gen/bin/run.dart]',
          '/sdk/dart [--packages=/w/c.json, /cache/far-1.0.0/bin/run.dart]',
        ],
      );
      for (final String root in <String>[
        'http://cache.example/gen/',
        'data:,gen/',
        'file://host/gen/',
        'file:///a%2Fb/',
      ]) {
        expect(
          () => processOf(
            const PackageCommand('gen', 'run', <String>[]),
            dart: '/sdk/dart',
            flutter: null,
            packageConfig: '/w/c.json',
            roots: <String, Uri>{'gen': Uri.parse(root)},
          ),
          throwsUnsupportedError,
          reason: root,
        );
      }
    });
  });

  // Beyond the brief: the rule labels a report line carries.
  test('CommandRule labels', () {
    expect(CommandRule.values.map((CommandRule r) => r.label), <String>[
      'command',
      'exit-code',
      'recording',
      'exit',
      'stdout',
      'stderr',
      'format',
      'missing-file',
      'extra-file',
      'changed-file',
      'unreadable-file',
      'output',
    ]);
  });
}
