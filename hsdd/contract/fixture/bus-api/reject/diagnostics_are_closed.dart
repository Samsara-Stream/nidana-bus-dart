// covers: G4
// The diagnostic family is sealed (root D8). Another package adds a
// diagnostic only by extending ShellDiagnostic, which it cannot implement.
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class OwnDiagnostic extends BusDiagnostic {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class FakeShellDiagnostic implements ShellDiagnostic {}

// The one open path: compiles, so it carries no marker.
final class ExecutorWarning extends ShellDiagnostic {
  const ExecutorWarning();
  @override
  String get origin => 'executor:example';
}
