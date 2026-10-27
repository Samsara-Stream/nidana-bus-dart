/// Stand-in runners for the tests that run bindings or commands: a Flutter
/// SDK whose `flutter` runs `dart test`, a `dart` that no Flutter SDK holds,
/// and one that records its calls, each a shell script over the real `dart`,
/// [Platform.resolvedExecutable]. No test starts the real flutter: this
/// machine's Flutter SDK has no engine artifacts, and fetching them is a
/// network action the run does not take.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'seed.dart';

/// A stand-in Flutter SDK in a fresh temporary directory deleted after the test:
/// `bin/cache/dart-sdk/bin/dart` runs the real dart with its arguments, and `bin/flutter` appends
/// its arguments, one line per call, to [flutterCalls], expects `test --no-pub` first and runs the
/// real `dart test` with the rest. With [flutterReports] false, `bin/flutter` prints `boom` to
/// stderr and exits 3 instead.
({String dart, File flutterCalls}) standInSdk({bool flutterReports = true}) {
  final String sdk = seed(const <String, String>{}).path;
  final String dart = p.join(sdk, 'bin', 'cache', 'dart-sdk', 'bin', 'dart');
  final String flutter = p.join(sdk, 'bin', 'flutter');
  _writeScripts(<String, String>{
    dart: _dartScript,
    flutter: flutterReports ? _flutterScript : _failingFlutterScript,
  });
  return (dart: dart, flutterCalls: File('$flutter.calls'));
}

/// A script named `dart` in a fresh temporary directory, held by no Flutter SDK, that runs the real dart.
String plainDart() {
  final String dart = p.join(seed(const <String, String>{}).path, 'dart');
  _writeScripts(<String, String>{dart: _dartScript});
  return dart;
}

/// A script named `dart` in a fresh temporary directory, held by no Flutter SDK: it appends its
/// arguments, one line per call, to [calls]; with [pubFails], a call whose first argument is
/// `pub` prints the line "Unable to satisfy `pubspec.yaml` using `pubspec.lock`." to stderr and exits 65;
/// every other call runs the real dart.
({String dart, File calls}) recordingDart({bool pubFails = false}) {
  final String dart = p.join(seed(const <String, String>{}).path, 'dart');
  _writeScripts(<String, String>{
    dart: <String>[
      ..._recordCall,
      if (pubFails) '[ "\$1" = pub ] && { echo $_unsatisfied >&2; exit 65; }',
      'exec $_realDart "\$@"',
      '',
    ].join('\n'),
  });
  return (dart: dart, calls: File('$dart.calls'));
}

/// The first line `dart pub get --enforce-lockfile` writes to stderr when the lockfile lacks a
/// dependency, quoted for `sh`.
final String _unsatisfied = _quoted(
  'Unable to satisfy `pubspec.yaml` using `pubspec.lock`.',
);

/// The real dart, quoted for `sh`.
final String _realDart = _quoted(Platform.resolvedExecutable);

/// A stand-in `dart`: it runs the real dart with its arguments.
final String _dartScript = <String>[
  '#!/bin/sh',
  'exec $_realDart "\$@"',
  '',
].join('\n');

/// The first lines of a stand-in `flutter` or a recording `dart`: it records its arguments.
const List<String> _recordCall = <String>[
  '#!/bin/sh',
  r'''printf '%s\n' "$*" >> "$0.calls"''',
];

/// A stand-in `flutter` that runs `flutter test --no-pub {arguments}` as `dart test {arguments}`.
final String _flutterScript = <String>[
  ..._recordCall,
  '[ "\$1" = test ] && [ "\$2" = --no-pub ] || '
      '{ echo "stand-in flutter: expected test --no-pub" >&2; exit 64; }',
  'shift 2',
  'exec $_realDart test "\$@"',
  '',
].join('\n');

/// A stand-in `flutter` that prints no report: `boom` on stderr, and exit 3.
final String _failingFlutterScript = <String>[
  ..._recordCall,
  'echo boom >&2',
  'exit 3',
  '',
].join('\n');

/// Writes each script of [scripts], keyed by its path, and makes it executable.
void _writeScripts(Map<String, String> scripts) {
  for (final MapEntry<String, String>(key: String path, value: String text)
      in scripts.entries) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  final ProcessResult chmod = Process.runSync('chmod', <String>[
    '+x',
    ...scripts.keys,
  ]);
  expect(chmod.exitCode, 0, reason: '${chmod.stdout}${chmod.stderr}');
}

/// [path] in single quotes for `sh`, each single quote in it closed, escaped and reopened.
String _quoted(String path) => "'${path.replaceAll("'", r"'\''")}'";
