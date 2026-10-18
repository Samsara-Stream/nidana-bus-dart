// Prints the dart executable running this program, as catalog finds the SDK
// that runs it (Platform.resolvedExecutable).
import 'dart:io';

void main() => stdout.write(Platform.resolvedExecutable);
