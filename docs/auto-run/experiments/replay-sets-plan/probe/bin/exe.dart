// Prints the dart running this executable (question X1).
import 'dart:io';

void main() {
  print('Platform.resolvedExecutable: ${Platform.resolvedExecutable}');
  print('Platform.executable: ${Platform.executable}');
  print('Directory.current: ${Directory.current.path}');
}
