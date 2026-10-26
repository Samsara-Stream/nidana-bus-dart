import 'dart:io';

import 'package:nidana_contract_check/src/shell.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(
    arguments,
    workingDirectory: Directory.current,
    out: stdout,
    err: stderr,
  );
}
