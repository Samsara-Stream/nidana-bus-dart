// Probes what a test of a Flutter workspace member, run from the workspace
// root as `fvm flutter test --no-pub packages/nidana_integration`, can do
// with the toolchain: find the pinned `dart`, run a member's executable,
// analyze and scan a seeded temporary package, and start a nested
// `flutter test`. Every line it prints starts with the probe id.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _workspaceRoot() {
  Directory d = Directory.current.absolute;
  while (true) {
    final File pubspec = File('${d.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('\nworkspace:')) {
      return d;
    }
    final Directory parent = d.parent;
    if (parent.path == d.path) throw StateError('no workspace root');
    d = parent;
  }
}

String _show(String text, Directory root) => text
    .replaceAll(root.path, '{root}')
    .replaceAll(Platform.environment['HOME'] ?? '/nonexistent', '{home}')
    .replaceAll(Directory.systemTemp.resolveSymbolicLinksSync(), '{tmp}')
    .replaceAll(Directory.systemTemp.path, '{tmp}');

Future<ProcessResult> _run(String exe, List<String> args, Directory cwd) =>
    Process.run(exe, args, workingDirectory: cwd.path);

void main() {
  final Directory root = _workspaceRoot();
  void say(String id, String text) =>
      // ignore: avoid_print
      print('$id: ${_show(text, root)}');

  late String dart;

  test('I1 the pinned dart, found from a flutter test of a member', () async {
    say('I1', 'working directory ${Directory.current.path}');
    say('I1', 'Platform.resolvedExecutable ${Platform.resolvedExecutable}');
    final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
    say('I1', 'FLUTTER_ROOT ${flutterRoot ?? '(unset)'}');
    final Map<String, Object?> config = jsonDecode(
            File('${root.path}/.dart_tool/package_config.json')
                .readAsStringSync())
        as Map<String, Object?>;
    say('I1', 'package_config flutterRoot ${config['flutterRoot']}');
    final List<String> candidates = <String>[
      if (flutterRoot != null) '$flutterRoot/bin/cache/dart-sdk/bin/dart',
      if (config['flutterRoot'] is String)
        '${Uri.parse(config['flutterRoot']! as String).toFilePath()}/bin/cache/dart-sdk/bin/dart',
    ];
    for (final String c in candidates) {
      say('I1', 'candidate $c exists=${File(c).existsSync()}');
    }
    dart = candidates.firstWhere((String c) => File(c).existsSync());
    final ProcessResult v = await _run(dart, <String>['--version'], root);
    say('I1', 'dart --version exit ${v.exitCode}: ${(v.stdout as String).trim()}${(v.stderr as String).trim()}');
  });

  test('I2 a member executable run from the workspace root', () async {
    final Stopwatch sw = Stopwatch()..start();
    final ProcessResult r = await _run(dart,
        <String>['run', 'nidana_dart_codegen:scan', 'packages/nidana_integration'], root);
    say('I2', 'scan exit ${r.exitCode} in ${sw.elapsed.inSeconds} s, stdout "${(r.stdout as String).trim()}", stderr "${(r.stderr as String).trim()}"');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('I3 and I4 a seeded temporary package outside the workspace',
      () async {
    final Directory tmp =
        Directory.systemTemp.createTempSync('nidana_seeded_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final Directory pkg = Directory('${tmp.path}/seeded_app')
      ..createSync(recursive: true);
    File('${pkg.path}/pubspec.yaml').writeAsStringSync('''
name: seeded_app
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  nidana_dart_contracts: any
  nidana_dart_runtime: any
  nidana_integration: any
''');
    File('${pkg.path}/analysis_options.yaml').writeAsStringSync('''
plugins:
  nidana_dart_lint:
    path: ${root.path}/packages/nidana_dart_lint
''');
    // The workspace's package configuration with absolute roots, plus the
    // seeded package itself.
    final Map<String, Object?> config = jsonDecode(
            File('${root.path}/.dart_tool/package_config.json')
                .readAsStringSync())
        as Map<String, Object?>;
    final Uri base = Directory('${root.path}/.dart_tool/').uri;
    final List<Object?> packages = <Object?>[
      for (final Object? e in config['packages']! as List<Object?>)
        <String, Object?>{
          ...(e! as Map<String, Object?>),
          'rootUri': base
              .resolve((e as Map<String, Object?>)['rootUri']! as String)
              .toString(),
        },
      <String, Object?>{
        'name': 'seeded_app',
        'rootUri': '../',
        'packageUri': 'lib/',
        'languageVersion': '3.13',
      },
    ];
    Directory('${pkg.path}/.dart_tool').createSync();
    File('${pkg.path}/.dart_tool/package_config.json').writeAsStringSync(
        jsonEncode(<String, Object?>{'configVersion': 2, 'packages': packages}));
    Directory('${pkg.path}/lib').createSync();
    File('${pkg.path}/lib/seeded.dart').writeAsStringSync('''
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';
import 'package:nidana_integration/app.dart';

Bus? globalBus;

final class SessionToken {}

abstract final class SeededTopics {
  static const StateTopic<int> duplicate =
      StateTopic<int>(name: 'payment.result', initial: 0);
  static const EventTopic<SessionToken> tokens =
      EventTopic<SessionToken>(name: 'seeded.tokens');
}

void seed(Bus bus) {
  const EventTopic<int> raw = EventTopic<int>(name: 'seeded.raw');
  bus.publish<int, int>(raw, 1);
  bus.publisher(const ServiceSource('rogue'),
      writes: <StateTopic<Object?>>{PaymentTopics.result});
}
''');
    final Stopwatch sw = Stopwatch()..start();
    final ProcessResult a = await _run(
        dart, <String>['analyze', '--format=machine', '.'], pkg);
    say('I3', 'dart analyze exit ${a.exitCode} in ${sw.elapsed.inSeconds} s');
    for (final String line in LineSplitter.split('${a.stdout}${a.stderr}')) {
      final List<String> f = line.split('|');
      say('I3', f.length > 7 ? '${f[0]}|${f[2]}|${f[4]}:${f[5]}' : line);
    }
    sw.reset();
    final ProcessResult s = await _run(
        dart,
        <String>[
          'run',
          'nidana_dart_codegen:scan',
          'packages/nidana_integration',
          pkg.path,
        ],
        root);
    say('I4', 'scan exit ${s.exitCode} in ${sw.elapsed.inSeconds} s');
    for (final String line in LineSplitter.split('${s.stdout}${s.stderr}')) {
      say('I4', line);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('I5 a nested flutter test started from inside a flutter test',
      () async {
    final String flutter =
        '${File(dart).parent.parent.parent.parent.parent.path}/bin/flutter';
    say('I5', 'flutter $flutter exists=${File(flutter).existsSync()}');
    final Stopwatch sw = Stopwatch()..start();
    final ProcessResult n = await _run(
        flutter,
        <String>['test', '--no-pub', 'nested_probe/nested_test.dart'],
        Directory('${root.path}/packages/nidana_integration'));
    final String out = '${n.stdout}${n.stderr}';
    say('I5', 'nested exit ${n.exitCode} in ${sw.elapsed.inSeconds} s; '
        'nested ran: ${out.contains('NESTED-RAN')}; '
        'startup lock: ${out.contains('startup lock')}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
