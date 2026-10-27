// packages/nidana_contract_check/test/behavior_cli_test.dart
import 'dart:io';

import 'package:nidana_contract_check/src/shell.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/runners.dart';
import 'support/sample.dart';
import 'support/seed.dart';
import 'support/workspace.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String h = 'hsdd/contract/fixture/host/';
const List<String> hostStructure = <String>[
  'PASS structure hsdd/contract/host.md',
  'PASS structure hsdd/contract/fixture/host/',
  'PASS structure hsdd/contract/fixture/host/behavior/host_impl_test.dart',
];
const String notAdmitted =
    'not run: the restriction admits no case of ${s}behavior/sample_conformance.dart';

typedef Replay = ({int code, List<String> out, List<String> err});

/// [arguments] replayed in process from [from] with [dart] as the running dart.
Future<Replay> replay(
  List<String> arguments, {
  required Directory from,
  required String dart,
}) async {
  final StringBuffer out = StringBuffer();
  final StringBuffer err = StringBuffer();
  final int code = await runCli(
    arguments,
    workingDirectory: from,
    out: out,
    err: err,
    dart: dart,
  );
  List<String> split(StringBuffer b) =>
      b.isEmpty ? const <String>[] : b.toString().trimRight().split('\n');
  return (code: code, out: split(out), err: split(err));
}

List<String> lines(ProcessResult r) =>
    (r.stdout as String).trimRight().split('\n');
String all(ProcessResult r) => '${r.stdout}${r.stderr}';
String told(Replay r) => '${r.out.join('\n')}\n${r.err.join('\n')}';

/// Writes [source] at [path] from [root] for the test, removing it after.
void addBinding(Directory root, String path, String source) {
  final File file = File('${root.path}/$path')..writeAsStringSync(source);
  addTearDown(file.deleteSync);
}

void main() {
  late Directory root;
  setUpAll(() async {
    root = await seedWorkspace(<String, String>{
      ...behaviorFiles,
      ...hostFiles,
    }, runners: true);
  });
  test('unrestricted, each binding runs under its runner and its line holds its counts and failing cases', () async {
    final ({String dart, File flutterCalls}) sdk = standInSdk();
    final Replay r = await replay(
      <String>['sample', '--set', 'behavior'],
      from: root,
      dart: sdk.dart,
    );
    expect(r.code, 1, reason: told(r));
    expect(
      r.out,
      containsAll(<String>[
        'FAIL behavior ${s}behavior/sample_impl_test.dart: cases (2 passed, 2 failed, 0 skipped under dart test); failed-case (G3 a sample is redacted); failed-case (G1 a body not implemented yet)',
        'FAIL behavior ${s}behavior/widget_impl_test.dart: cases (2 passed, 2 failed, 0 skipped under flutter test --no-pub); failed-case (G3 a sample is redacted); failed-case (G1 a body not implemented yet)',
      ]),
    );
    expect(r.out.last, '9 fixtures: 7 passed, 2 failed, 0 pending');
    expect(r.err, <String>[
      'running behavior ${s}behavior/sample_impl_test.dart under dart test',
      'running behavior ${s}behavior/widget_impl_test.dart under flutter test --no-pub',
    ]);
    expect(sdk.flutterCalls.readAsLinesSync(), <String>[
      'test --no-pub --reporter json ${s}behavior/widget_impl_test.dart',
    ]);
  });
  test('one id runs exactly the cases whose names begin with it, under dart test and under flutter test --no-pub', () async {
    final ({String dart, File flutterCalls}) sdk = standInSdk();
    final Replay r = await replay(
      <String>['sample', '--set', 'behavior', '--guarantee', 'G2'],
      from: root,
      dart: sdk.dart,
    );
    expect(r.code, 0, reason: told(r));
    expect(
      r.out,
      containsAll(<String>[
        'PASS behavior ${s}behavior/sample_impl_test.dart: 2 passed, 0 failed, 0 skipped under dart test, restricted to sample G2',
        'PASS behavior ${s}behavior/widget_impl_test.dart: 2 passed, 0 failed, 0 skipped under flutter test --no-pub, restricted to sample G2',
      ]),
    );
    expect(sdk.flutterCalls.readAsLinesSync(), <String>[
      'test --no-pub --reporter json --name ^(G2)  ${s}behavior/widget_impl_test.dart',
    ]);
  });
  test("a binding of another slug's suite runs exactly the cases its {slug}/G{n} ids name", () async {
    final Replay r = await replay(
      <String>[
        'host',
        '--set',
        'behavior',
        '--guarantee',
        'sample/G2,sample/G3',
      ],
      from: root,
      dart: standInSdk().dart,
    );
    expect(r.code, 1, reason: told(r));
    expect(r.out, <String>[
      ...hostStructure,
      'FAIL behavior ${h}behavior/host_impl_test.dart: cases (2 passed, 1 failed, 0 skipped under dart test, restricted to sample G2, G3); failed-case (G3 a sample is redacted)',
      '4 fixtures: 3 passed, 1 failed, 0 pending',
    ]);
  });
  test('and none for bare ids alone, even where a bare id equals one of its case ids', () async {
    final Replay r = await replay(
      <String>['host', '--set', 'behavior', '--guarantee', 'G1'],
      from: root,
      dart: standInSdk().dart,
    );
    expect(r.code, 0, reason: told(r));
    expect(r.out, <String>[
      ...hostStructure,
      'PASS behavior ${h}behavior/host_impl_test.dart: $notAdmitted',
      '4 fixtures: 4 passed, 0 failed, 0 pending',
    ]);
    expect(r.err, isEmpty);
  });
  test('a binding the restriction admits no case of passes with no case run, and the replay exits 0', () async {
    final ({String dart, File flutterCalls}) sdk = standInSdk();
    final Replay r = await replay(
      <String>['sample', '--set', 'behavior', '--guarantee', 'G4'],
      from: root,
      dart: sdk.dart,
    );
    expect(r.code, 0, reason: told(r));
    expect(
      r.out,
      containsAll(<String>[
        'PASS behavior ${s}behavior/sample_impl_test.dart: $notAdmitted',
        'PASS behavior ${s}behavior/widget_impl_test.dart: $notAdmitted',
      ]),
    );
    expect(r.err, isEmpty);
    expect(sdk.flutterCalls.existsSync(), isFalse);
  });
  test('a binding of an absent package prints PENDING, never a test failure, and starts no runner', () async {
    final Replay r = await replay(
      <String>['sample', '--set', 'behavior'],
      from: await seedWorkspace(behaviorFiles),
      dart: plainDart(),
    );
    expect(r.code, 1, reason: told(r));
    expect(
      r.out,
      containsAll(<String>[
        'PENDING behavior ${s}behavior/sample_impl_test.dart: packages matcher, nidana_contract_check, test are absent from .dart_tool/package_config.json',
        'PENDING behavior ${s}behavior/widget_impl_test.dart: packages flutter_test, matcher, nidana_contract_check are absent from .dart_tool/package_config.json',
      ]),
    );
    expect(r.out.last, '9 fixtures: 7 passed, 0 failed, 2 pending');
    expect(r.err, isEmpty);
  });
  test('a binding that does not compile fails on load, not on its cases', () async {
    addBinding(root, '${h}behavior/broken_impl_test.dart', r'''
import 'package:test/test.dart';

import '../../sample/behavior/sample_conformance.dart';

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(undefinedHarness));
  }
}
''');
    final Replay r = await replay(
      <String>['host', '--set', 'behavior'],
      from: root,
      dart: standInSdk().dart,
    );
    expect(r.code, 1, reason: told(r));
    expect(
      r.out,
      contains(
        allOf(
          startsWith(
            'FAIL behavior ${h}behavior/broken_impl_test.dart: load (did not load under dart test: ${h}behavior/broken_impl_test.dart:',
          ),
          contains('undefinedHarness'),
        ),
      ),
    );
    expect(
      r.out,
      contains(
        'FAIL behavior ${h}behavior/host_impl_test.dart: cases (2 passed, 2 failed, 0 skipped under dart test); failed-case (G3 a sample is redacted); failed-case (G1 a body not implemented yet)',
      ),
    );
  });
  test('no flutter in the SDK of the running dart is an environment error (2), and no binding of the slug runs', () async {
    final String dart = plainDart();
    final Replay r = await replay(
      <String>['sample', '--set', 'behavior'],
      from: root,
      dart: dart,
    );
    expect(r.code, 2, reason: told(r));
    expect(r.err, <String>[
      'ERROR behavior sample: no flutter in the Flutter SDK of $dart; ${s}behavior/widget_impl_test.dart runs under flutter test --no-pub',
    ]);
    final Replay unrun = await replay(
      <String>['sample', '--set', 'behavior', '--guarantee', 'G4'],
      from: root,
      dart: dart,
    );
    expect(unrun.code, 0, reason: told(unrun));
  });
  test('a runner that prints no report is an environment error (2)', () async {
    final Replay r = await replay(
      <String>['sample', '--set', 'behavior'],
      from: root,
      dart: standInSdk(flutterReports: false).dart,
    );
    expect(r.code, 2, reason: told(r));
    expect(
      r.err,
      contains(
        'ERROR behavior sample: flutter test --no-pub exited 3 without a JSON report for ${s}behavior/widget_impl_test.dart: boom',
      ),
    );
  });
  test('through a symbolic link to the workspace root, outcomes still reach their bindings', () async {
    final Link link = Link('${seed(const <String, String>{}).path}/linked')
      ..createSync(root.path);
    final Replay r = await replay(
      <String>['host', '--set', 'behavior', '--guarantee', 'sample/G2'],
      from: Directory(link.path),
      dart: standInSdk().dart,
    );
    expect(r.code, 0, reason: told(r));
    expect(
      r.out,
      contains(
        'PASS behavior ${h}behavior/host_impl_test.dart: 2 passed, 0 failed, 0 skipped under dart test, restricted to sample G2',
      ),
    );
  });
  test('the bin script replays a dart binding end to end', () async {
    final ProcessResult r = await runTool(<String>[
      'host',
      '--set',
      'behavior',
      '--guarantee',
      'sample/G2',
    ], workingDirectory: root);
    expect(r.exitCode, 0, reason: all(r));
    expect(lines(r), <String>[
      ...hostStructure,
      'PASS behavior ${h}behavior/host_impl_test.dart: 2 passed, 0 failed, 0 skipped under dart test, restricted to sample G2',
      '4 fixtures: 4 passed, 0 failed, 0 pending',
    ]);
    expect(
      r.stderr as String,
      'running behavior ${h}behavior/host_impl_test.dart under dart test\n',
    );
  });

  // Beyond the brief: rules of the shell's behavior runs that would otherwise
  // go unpinned.
  test('a dart at the Flutter SDK layout whose flutter is absent has no flutter (2)', () async {
    final ({String dart, File flutterCalls}) sdk = standInSdk();
    File(p.withoutExtension(sdk.flutterCalls.path)).deleteSync();
    final Replay r = await replay(
      <String>['sample', '--set', 'behavior'],
      from: root,
      dart: sdk.dart,
    );
    expect(r.code, 2, reason: told(r));
    expect(r.err, <String>[
      'ERROR behavior sample: no flutter in the Flutter SDK of ${sdk.dart}; ${s}behavior/widget_impl_test.dart runs under flutter test --no-pub',
    ]);
  });
  test("a runner that cannot start, or prints no report, ends the slug's behavior set at that binding", () async {
    addBinding(
      root,
      '${h}behavior/second_impl_test.dart',
      hostFiles['${h}behavior/host_impl_test.dart']!,
    );
    final String missing = '${root.path}/no-such-dart';
    final Replay unstarted = await replay(
      <String>['host', '--set', 'behavior'],
      from: root,
      dart: missing,
    );
    expect(unstarted.code, 2, reason: told(unstarted));
    expect(unstarted.err, hasLength(2));
    expect(
      unstarted.err.first,
      'running behavior ${h}behavior/host_impl_test.dart under dart test',
    );
    expect(
      unstarted.err.last,
      startsWith('ERROR behavior host: could not run $missing: '),
    );
    final Replay unreported = await replay(
      <String>['host', '--set', 'behavior'],
      from: root,
      dart: '/bin/echo',
    );
    expect(unreported.code, 2, reason: told(unreported));
    expect(unreported.err, <String>[
      'running behavior ${h}behavior/host_impl_test.dart under dart test',
      'ERROR behavior host: dart test exited 0 without a JSON report for ${h}behavior/host_impl_test.dart',
    ]);
    expect(unreported.out, everyElement(isNot(startsWith('PASS behavior'))));
  });
  test("another slug's suite file is read alone, only for a replay that runs the behavior set", () async {
    final Directory seeded = await seedWorkspace(<String, String>{
      ...behaviorFiles,
      ...hostFiles,
    });
    // Defects of the suite's slug outside its suite file: none is read.
    Link('${seeded.path}/${s}reject/gone.dart')
        .createSync('${seeded.path}/gone');
    File('${seeded.path}/hsdd/contract/sample.md')
        .writeAsBytesSync(const <int>[0xff]);
    final File suite = File(
      '${seeded.path}/${s}behavior/sample_conformance.dart',
    )..writeAsBytesSync(const <int>[0x2f, 0x2f, 0xff, 0x0a]);
    final ProcessResult chmod = Process.runSync('chmod', <String>[
      '000',
      suite.path,
    ]);
    expect(chmod.exitCode, 0, reason: all(chmod));
    Future<Replay> host(String set) =>
        replay(<String>['host', '--set', set], from: seeded, dart: plainDart());

    final Replay structure = await host('structure');
    expect(structure.code, 0, reason: told(structure));
    // A suite file that exists and cannot be read stops the replay, as a
    // source of the replayed slug does.
    final Replay unreadable = await host('behavior');
    expect(unreadable.code, 2, reason: told(unreadable));
    expect(
      unreadable.err.single,
      allOf(
        startsWith('error: '),
        contains('${s}behavior/sample_conformance.dart'),
      ),
    );
    expect(unreadable.out, isEmpty);
    final ProcessResult readable = Process.runSync('chmod', <String>[
      '644',
      suite.path,
    ]);
    expect(readable.exitCode, 0, reason: all(readable));
    final Replay undecodable = await host('behavior');
    expect(undecodable.code, 1, reason: told(undecodable));
    expect(
      undecodable.out,
      contains(
        'FAIL behavior ${h}behavior/host_impl_test.dart: suite (${s}behavior/sample_conformance.dart: not UTF-8: Invalid UTF-8 byte (at offset 2))',
      ),
    );
    expect(undecodable.err, isEmpty);
  });
  test("a binding of another slug's suite is PENDING on the suite's absent packages too", () async {
    final Replay r = await replay(
      <String>['host', '--set', 'behavior'],
      from: await seedWorkspace(<String, String>{
        ...behaviorFiles,
        ...hostFiles,
      }),
      dart: plainDart(),
    );
    expect(r.code, 1, reason: told(r));
    expect(
      r.out,
      contains(
        'PENDING behavior ${h}behavior/host_impl_test.dart: packages matcher, nidana_contract_check, test are absent from .dart_tool/package_config.json',
      ),
    );
    expect(r.err, isEmpty);
  });
  test('a suite whose slug has no fixture directory fails its binding, and nothing is read for it', () async {
    final Replay r = await replay(
      <String>['host', '--set', 'behavior'],
      from: await seedWorkspace(hostFiles),
      dart: plainDart(),
    );
    expect(r.code, 1, reason: told(r));
    expect(
      r.out,
      contains(
        'FAIL behavior ${h}behavior/host_impl_test.dart: suite (${s}behavior/sample_conformance.dart does not exist)',
      ),
    );
    expect(r.err, isEmpty);
  });
  test('bytes a case writes to stdout that are not UTF-8 change no count and stop no replay', () async {
    addBinding(root, '${h}behavior/raw_impl_test.dart', r'''
import 'dart:io';

import 'package:test/test.dart';

import '../../sample/behavior/sample_conformance.dart';

final class _Harness implements SampleHarness {
  @override
  Future<void> settle() async {}
}

void main() {
  for (final c in sampleConformance) {
    test(c.name, () {
      stdout.add(const <int>[0xff, 0x0a]);
      return c.body(_Harness());
    });
  }
}
''');
    final Replay r = await replay(
      <String>['host', '--set', 'behavior', '--guarantee', 'sample/G2'],
      from: root,
      dart: standInSdk().dart,
    );
    expect(
      r.out,
      contains(
        'PASS behavior ${h}behavior/raw_impl_test.dart: 2 passed, 0 failed, 0 skipped under dart test, restricted to sample G2',
      ),
    );
  });
}
