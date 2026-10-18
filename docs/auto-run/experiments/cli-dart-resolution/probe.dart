// Under `fvm dart run`, which `dart` does a child process named `dart` get,
// compared with the SDK of the running `dart`?
import 'dart:io';

Future<void> main() async {
  print('Platform.resolvedExecutable: ${Platform.resolvedExecutable}');
  final path = Platform.environment['PATH'] ?? '';
  final first = path.split(':').take(3).join(':');
  print('PATH (first three entries): $first');
  final which = await Process.run('which', ['dart']);
  print('which dart: ${(which.stdout as String).trim()} (exit ${which.exitCode})');
  final byName = await Process.run('dart', ['--version']);
  print('dart --version by name: ${(byName.stdout as String).trim()}${(byName.stderr as String).trim()}');
  final pinned = await Process.run(Platform.resolvedExecutable, ['--version']);
  print('running dart --version: ${(pinned.stdout as String).trim()}${(pinned.stderr as String).trim()}');
}
