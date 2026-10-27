// Prints how it was started, then writes left.txt into its working
// directory, which the replay tool does not look at afterwards.
import 'dart:io';

void main() {
  stdout.writeln('script ${Platform.script.toFilePath()}');
  stdout.writeln('packages ${Platform.packageConfig}');
  stdout.writeln('cwd ${Directory.current.path}');
  File('left.txt').writeAsStringSync('written by probe_tool:facts\n');
}
