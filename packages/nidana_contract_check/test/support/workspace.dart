/// Seeded pub workspaces for the tests that run `dart analyze`, a binding's
/// test runner or a generator: the seeded files beside stand-in packages,
/// resolved offline.
/// Inside a temporary directory `fvm` runs no `dart`, so the workspace
/// resolves with [Platform.resolvedExecutable], the SDK's `dart` running the
/// tests.
library;

import 'dart:io';

import 'package:nidana_contract_check/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'generator.dart';
import 'seed.dart';

/// `packages/sample/lib/sample.dart` of the seeded workspace.
const String standInSample = r'''
/// The stand-in package the replay tool's tests analyze fixtures against.
library;

/// A class other libraries may construct but never extend.
final class Sample {
  const Sample();

  /// A final field: assigning it reports `assignment_to_final`.
  final int count = 0;
}
''';

/// [files] in a fresh temporary pub workspace resolved offline: its members are the stand-in
/// package `sample` unless [standIn] is false; with [runners], also the stand-in
/// `nidana_contract_check` and `flutter_test`; with [generator], also the stand-in generator
/// package `gen` (no dependency) whose `bin/generate.dart` is [standInGenerator].
///
/// The fixtures' analysis options are this workspace's
/// hsdd/contract/fixture/analysis_options.yaml. With [runners], `sample` also
/// depends on `matcher` and dev-depends on `test`, so bindings run under
/// `dart test`. The root's `workspace:` list names each member the flags
/// give, and the root has no `workspace:` key when they give none.
///
/// Never start the real flutter: the pinned Flutter SDK has no engine
/// artifacts. Replay a seeded Flutter binding that is not PENDING only with
/// `runCli(..., dart: standInSdk().dart)` or `plainDart()` from
/// `runners.dart`, never through `runTool` and never with `dart: null`.
Future<Directory> seedWorkspace(
  Map<String, String> files, {
  bool standIn = true,
  bool runners = false,
  bool generator = false,
}) async {
  if (runners && !standIn) {
    throw ArgumentError.value(
      runners,
      'runners',
      'the runners join the stand-in package sample, so they require standIn',
    );
  }
  final Directory root = seed(<String, String>{
    ...files,
    'pubspec.yaml': _rootPubspec(<String>[
      if (standIn) 'packages/sample',
      if (runners) ...<String>[
        'packages/nidana_contract_check',
        'packages/flutter_test',
      ],
      if (generator) 'packages/gen',
    ]),
    if (standIn)
      'packages/sample/pubspec.yaml': runners
          ? '$_samplePubspec$_sampleRunnerDependencies'
          : _samplePubspec,
    if (standIn) 'packages/sample/lib/sample.dart': standInSample,
    if (runners) ...<String, String>{
      'packages/nidana_contract_check/pubspec.yaml': _toolPubspec,
      'packages/nidana_contract_check/lib/fixture.dart': _toolFixture,
      'packages/flutter_test/pubspec.yaml': _flutterTestPubspec,
      'packages/flutter_test/lib/flutter_test.dart': _flutterTestLibrary,
    },
    if (generator) ...<String, String>{
      'packages/gen/pubspec.yaml': _genPubspec,
      'packages/gen/bin/generate.dart': standInGenerator,
    },
    'hsdd/contract/fixture/analysis_options.yaml': _fixtureOptions,
  });
  final ProcessResult result = await Process.run(
    Platform.resolvedExecutable,
    <String>['pub', 'get', '--offline'],
    workingDirectory: root.path,
  );
  expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  return root;
}

/// The seeded workspace's root `pubspec.yaml`: a pub workspace whose members
/// are [members], each a `/`-separated path from the root, with no
/// `workspace:` key when there is none.
String _rootPubspec(List<String> members) => <String>[
  'name: stand_in_workspace',
  'publish_to: none',
  'environment:',
  '  sdk: ^3.13.0',
  if (members.isNotEmpty) 'workspace:',
  for (final String member in members) '  - $member',
  '',
].join('\n');

/// `packages/gen/pubspec.yaml` of a seeded workspace with a generator.
const String _genPubspec = '''
name: gen
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
''';

/// `packages/sample/pubspec.yaml` of the seeded workspace.
const String _samplePubspec = '''
name: sample
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
''';

/// The lines a seeded workspace with runners appends to [_samplePubspec]: the
/// packages a seeded suite and its `dart test` binding import.
const String _sampleRunnerDependencies = '''
dependencies:
  matcher: any
dev_dependencies:
  test: any
''';

/// `packages/nidana_contract_check/pubspec.yaml` of a seeded workspace with
/// runners.
const String _toolPubspec = '''
name: nidana_contract_check
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
''';

/// `packages/nidana_contract_check/lib/fixture.dart` of a seeded workspace
/// with runners.
const String _toolFixture = r'''
/// Stands in for package:nidana_contract_check/fixture.dart in a seeded workspace.
library;

typedef ConformanceCase<H> = ({
  String name,
  Future<void> Function(H harness) body,
});
''';

/// `packages/flutter_test/pubspec.yaml` of a seeded workspace with runners.
const String _flutterTestPubspec = '''
name: flutter_test
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
dependencies:
  test: any
''';

/// `packages/flutter_test/lib/flutter_test.dart` of a seeded workspace with
/// runners.
const String _flutterTestLibrary = r'''
/// Stands in for package:flutter_test in a seeded workspace: testWidgets over package:test.
library;

import 'package:test/test.dart' show test;

export 'package:test/test.dart';

/// Stands in for flutter_test's WidgetTester.
final class WidgetTester {
  const WidgetTester._();
}

/// Registers [description] as a test whose body is given a [WidgetTester].
void testWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => test(description, () => body(const WidgetTester._()));
''';

/// The text of hsdd/contract/fixture/analysis_options.yaml in the workspace
/// that holds the test run.
final String _fixtureOptions = File(
  p.join(
    (findWorkspaceRoot(Directory.current) ??
            (throw StateError(
              'no ancestor of ${Directory.current.path} holds hsdd/contract/',
            )))
        .path,
    'hsdd',
    'contract',
    'fixture',
    'analysis_options.yaml',
  ),
).readAsStringSync();
