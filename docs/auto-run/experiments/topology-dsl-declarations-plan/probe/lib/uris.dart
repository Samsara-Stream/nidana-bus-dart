// URI spellings that import dart:io and dart:isolate past the old directive
// reader of purity_test.dart (S112): an escape sequence and adjacent string
// literals. Both resolve; neither import is reported as unused, because the
// names below use them.
import 'dart:\x69o';
import 'dart:' "isolate";

String probe() => '${Platform.version} ${Isolate.current}';
