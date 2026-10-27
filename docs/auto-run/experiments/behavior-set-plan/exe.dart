// Prints the dart that runs this script and the flutter its SDK would hold.
import 'dart:io';

void main() {
  final String dart = Platform.resolvedExecutable;
  print('Platform.resolvedExecutable: $dart');
  final List<String> parts = dart.split('/');
  final String bin = parts.sublist(0, parts.length - 4).join('/');
  print('four directories up, then flutter: $bin/flutter');
  print('that file exists: ${File('$bin/flutter').existsSync()}');
}
