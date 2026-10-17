import 'dart:io';

import 'package:nidana_dart_codegen/src/scan.dart';

Future<void> main(List<String> args) async {
  final int code = await runScan(args, out: stdout, err: stderr);
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
