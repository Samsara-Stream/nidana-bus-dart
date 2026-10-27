/// Seeded pub workspaces for the tests that run `dart analyze`: the seeded
/// files beside a stand-in package, resolved offline. Inside a temporary
/// directory `fvm` runs no `dart`, so the workspace resolves with
/// [Platform.resolvedExecutable], the SDK's `dart` running the tests.
library;

import 'dart:io';

import 'package:nidana_contract_check/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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

/// [files] in a fresh temporary pub workspace resolved offline: its root's one member is the
/// stand-in package `sample` unless [standIn] is false, and the fixtures' analysis options are
/// this workspace's hsdd/contract/fixture/analysis_options.yaml.
Future<Directory> seedWorkspace(
  Map<String, String> files, {
  bool standIn = true,
}) async {
  final Directory root = seed(<String, String>{
    ...files,
    'pubspec.yaml': _rootPubspec(standIn: standIn),
    if (standIn) 'packages/sample/pubspec.yaml': _samplePubspec,
    if (standIn) 'packages/sample/lib/sample.dart': standInSample,
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

/// The seeded workspace's root `pubspec.yaml`: a pub workspace whose one
/// member is the stand-in package when [standIn] is true.
String _rootPubspec({required bool standIn}) => <String>[
  'name: stand_in_workspace',
  'publish_to: none',
  'environment:',
  '  sdk: ^3.13.0',
  if (standIn) ...<String>['workspace:', '  - packages/sample'],
  '',
].join('\n');

/// `packages/sample/pubspec.yaml` of the seeded workspace.
const String _samplePubspec = '''
name: sample
publish_to: none
environment:
  sdk: ^3.13.0
resolution: workspace
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
