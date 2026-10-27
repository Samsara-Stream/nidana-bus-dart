/// The samples the file and cli set tests share: [commandText], [treeOf], and
/// the `gen` slug (kind `file`) as strings keyed by their paths from the
/// workspace root, `docs/auto-run/experiments/file-cli-sets-plan/samples/` as
/// strings.
library;

import 'package:nidana_contract_check/src/command.dart';
import 'package:nidana_contract_check/src/tree.dart';

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

/// The tree of [files], each file's bytes by its relative path, every entry a [FileBytes].
FileTree treeOf(Map<String, List<int>> files) =>
    Map<String, FileEntry>.unmodifiable(<String, FileEntry>{
      for (final MapEntry<String, List<int>>(:String key, :List<int> value)
          in files.entries)
        key: FileBytes(value),
    });

/// `hsdd/contract/gen.md`.
const String genContract = r'''
---
id: gen
version: v1
status: stable
kind: file
---

# gen@v1

## Guarantees / invariants

- **G1** generate writes the expected tree.
- **G2** generate exits 2 on a usage error and writes nothing.
- **G3** generate prints where it wrote and the directory it ran from.
- **G4** generate reads its input relative to the directory it runs from.
- **G5** a case's files analyze as recorded.

## Validation

- file: `hsdd/contract/fixture/gen/input/` holds `word.txt`; the replay runs `fvm dart run gen:generate {input}/word.txt {output}`, formats the Dart in `{output}` and compares `{output}` with `expected/`. The file set covers G1.
- invocations: one directory per case under `hsdd/contract/fixture/gen/invocation/`.

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `analyze-lib` | `dart analyze --format=machine .` | 2 | G5 |
| `generate-from-files` | `gen:generate word.txt {output}` | 0 | G4: from files/ |
| `generate-tree` | `gen:generate --echo hsdd/contract/fixture/gen/input/word.txt {output}` | 0 | G1, G3 |
| `generate-usage` | `gen:generate --frob {output}` | 2 | G2 |
''';

/// The `out.dart` of each expected tree of `gen`: what `generate` writes, formatted.
const String genOutDart = "void main() {\n  print('hello');\n}\n";

/// The `notes.txt` of each expected tree of `gen`.
const String genNotes = 'from hello\n';

/// `hsdd/contract/fixture/gen/`.
const String _gen = 'hsdd/contract/fixture/gen/';

/// `hsdd/contract/fixture/gen/invocation/`.
const String _invocations = '${_gen}invocation/';

/// The clean `gen` slug (kind `file`), keyed by path from the workspace root.
const Map<String, String> genFiles = <String, String>{
  'hsdd/contract/gen.md': genContract,
  '${_gen}input/word.txt': 'hello\n',
  '${_gen}expected/out.dart': genOutDart,
  '${_gen}expected/notes.txt': genNotes,
  '${_invocations}analyze-lib/args': 'dart\nanalyze\n--format=machine\n.\n',
  '${_invocations}analyze-lib/exit_code': '2\n',
  '${_invocations}analyze-lib/stdout': "WARNING|STATIC_WARNING|UNUSED_IMPORT|{files}/lib/a.dart|1|8|12|Unused import: 'dart:async'.\n",
  '${_invocations}analyze-lib/files/pubspec.yaml':
      'name: example_app\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\n',
  '${_invocations}analyze-lib/files/lib/a.dart':
      "import 'dart:async';\n\nvoid f() {}\n",
  '${_invocations}generate-from-files/args':
      'gen:generate\nword.txt\n{output}\n',
  '${_invocations}generate-from-files/exit_code': '0\n',
  '${_invocations}generate-from-files/stdout': 'wrote {output}\ncwd {files}\n',
  '${_invocations}generate-from-files/files/word.txt': 'hello\n',
  '${_invocations}generate-from-files/expected/out.dart': genOutDart,
  '${_invocations}generate-from-files/expected/notes.txt': genNotes,
  '${_invocations}generate-tree/args': 'gen:generate\n--echo\nhsdd/contract/fixture/gen/input/word.txt\n{output}\n',
  '${_invocations}generate-tree/exit_code': '0\n',
  '${_invocations}generate-tree/stdout':
      'wrote {output}\ncwd {root}\nresolved {output}\n',
  '${_invocations}generate-tree/expected/out.dart': genOutDart,
  '${_invocations}generate-tree/expected/notes.txt': genNotes,
  '${_invocations}generate-usage/args': 'gen:generate\n--frob\n{output}\n',
  '${_invocations}generate-usage/exit_code': '2\n',
  '${_invocations}generate-usage/stderr':
      'usage: generate [--echo] [--write-then-fail] <input> <output>\n',
};
