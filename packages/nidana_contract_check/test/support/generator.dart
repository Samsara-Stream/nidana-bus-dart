/// The samples the file and cli set tests share.
library;

import 'package:nidana_contract_check/src/command.dart';

/// [command] as text: `dart [{arguments}]`, `flutter [{arguments}]` or
/// `package {package}:{executable} [{arguments}]`, the arguments joined by `, `.
String commandText(Command command) {
  final String arguments = command.arguments.join(', ');
  return switch (command) {
    DartCommand() => 'dart [$arguments]',
    FlutterCommand() => 'flutter [$arguments]',
    PackageCommand(:final String package, :final String executable) =>
      'package $package:$executable [$arguments]',
  };
}
