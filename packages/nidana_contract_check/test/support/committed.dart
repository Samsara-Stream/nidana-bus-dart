/// The committed governance of the workspace that holds the test run, read
/// for the tests that assert a property of it. hsdd-contract amends it, and
/// another node's gate runs this suite, so a test asserts a property of
/// whatever is committed, never its counts or literals.
library;

import 'dart:io';

import 'package:nidana_contract_check/src/contract.dart';
import 'package:nidana_contract_check/src/workspace.dart';
import 'package:path/path.dart' as p;

/// Each committed contract text whose `## Validation` holds a `- file:` bullet, read, by slug.
Map<String, ContractText> committedFileContracts() {
  final Directory contracts = Directory(
    p.join(findWorkspaceRoot(Directory.current)!.path, 'hsdd', 'contract'),
  );
  return <String, ContractText>{
    for (final File file in contracts.listSync().whereType<File>())
      if (p.extension(file.path) == '.md')
        if (file.readAsStringSync() case final String text
            when _holdsFileBullet(text))
          p.basenameWithoutExtension(file.path): readContract(
            p.basenameWithoutExtension(file.path),
            text,
          ),
  };
}

/// Whether a line of [text]'s `## Validation` section begins `- file: `, as [readContract]
/// reads the section.
bool _holdsFileBullet(String text) => text
    .replaceAll('\r\n', '\n')
    .split('\n')
    .map((String line) => line.trimRight())
    .skipWhile((String line) => line != '## Validation')
    .skip(1)
    .takeWhile((String line) => !line.startsWith('## '))
    .any((String line) => line.startsWith('- file: '));
