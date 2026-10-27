// packages/nidana_contract_check/test/contract_test.dart
import 'dart:io';

import 'package:nidana_contract_check/src/contract.dart';
import 'package:nidana_contract_check/src/workspace.dart';
import 'package:test/test.dart';

/// A `gen` contract whose generator spans sit among spans that name no command.
const String genText = '''
---
id: gen
version: v1
kind: file
---

# gen@v1

## Interface

- file: `dart run gen:interface {output}` outside the Validation section.

## Validation

- file: `hsdd/contract/fixture/gen/input/` holds `word.txt`; the replay runs `fvm dart run gen:generate {input}/word.txt {output}`, formats the Dart in `{output}` and compares `{output}/a` with `expected/`.
- file: then `dart run gen:other {output}`.
- schema: `dart run x {output}`.
''';

const String text = '''
---
id: sample
version: v1
kind: api
---

# sample@v1

## Guarantees / invariants

- **G1** a sample type is closed.
- **G2** a sample value round-trips.
- G3 an entry without its bold id.
- **G4** a property of the package's pubspec.

## Validation

- surface: `hsdd/contract/fixture/sample/surface/` uses every declaration.
- goldens: `hsdd/contract/fixture/sample/goldens/`, renderings the behavior set compares.
- notes: `hsdd/contract/fixture/other/notes/`, another slug's directory.
- binding: `hsdd/contract/fixture/sample/behavior/sample_impl_test.dart` binds the suite, under `dart test`.
- schema: `hsdd/contract/schema/sample.schema.json`, replayed by the `schema` set (ADR-001 item 5).
- file: `hsdd/contract/fixture/sample/input/` holds one file. The file set covers G1 to G2 and G4.
- schema: a second schema bullet that covers the document.
- not executable: G4, a property of the package's pubspec; checked by nidana.model's gates
- not executable: G2's last clause, on a value no case builds; checked by nidana.runtime's gates, which build it
- not executable: G1's last sentence, on an exception no case can raise
- not executable: the rest of it

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `run-clean` | `tool:run` | 0 | G1, G2: a clean tree |
| `run-usage` | `tool:run --frob` | 2 | G4 |
| run-bad | `tool:run` | 1 | two |
''';

void expectSample(ContractText c) {
  expect(c.id, 'sample');
  expect(c.kindLabel, 'api');
  expect(c.kind, ContractKind.api);
  expect(c.guarantees, <int>[1, 2, 4]);
  expect(c.malformedGuarantees, <String>['- G3 an entry without its bold id.']);
  expect(c.bindings, <String>[
    'hsdd/contract/fixture/sample/behavior/sample_impl_test.dart',
  ]);
  expect(c.listedDirectories, <String>{'surface', 'goldens'});
  expect(c.coversClauses.map((CoversClause x) => x.bullet), <String>[
    'file',
    'schema',
  ]);
  expect(c.coversClauses.map((CoversClause x) => x.text), <String>[
    'G1 to G2 and G4',
    'the document',
  ]);
  expect(c.coversClauses.map((CoversClause x) => x.ids), <Set<int>?>[
    <int>{1, 2, 4},
    null,
  ]);
  expect(c.invocationRows.map((InvocationRow x) => x.caseName), <String?>[
    'run-clean',
    'run-usage',
    null,
  ]);
  expect(c.invocationRows.map((InvocationRow x) => x.covers), <String>[
    'G1, G2: a clean tree',
    'G4',
    'two',
  ]);
  expect(c.invocationRows.map((InvocationRow x) => x.ids), <Set<int>?>[
    <int>{1, 2},
    <int>{4},
    null,
  ]);
  expect(c.notExecutable.map((NotExecutableLine x) => x.id), <int?>[
    4,
    2,
    1,
    null,
  ]);
  expect(c.notExecutable.map((NotExecutableLine x) => x.partial), <bool>[
    false,
    true,
    true,
    false,
  ]);
  expect(c.notExecutable.map((NotExecutableLine x) => x.node), <String?>[
    'nidana.model',
    'nidana.runtime',
    null,
    null,
  ]);
}

void main() {
  test(
    'reads the frontmatter, the guarantee ids and every Validation form',
    () {
      expectSample(readContract('sample', text));
    },
  );
  test('reads CRLF text as it reads LF text', () {
    expectSample(readContract('sample', text.replaceAll('\n', '\r\n')));
  });
  test('a text without frontmatter has no id and no kind', () {
    final ContractText c = readContract(
      'sample',
      '# sample\n\n## Guarantees / invariants\n\n- **G1** one.\n',
    );
    expect(c.id, isNull);
    expect(c.kindLabel, isNull);
    expect(c.kind, isNull);
    expect(c.guarantees, <int>[1]);
  });
  test('Validation lines are right-trimmed; a covers bullet without its closing clause is kept', () {
    final ContractText c = readContract(
      'sample',
      text
          .replaceFirst('covers G1 to G2 and G4.', 'covers G1 to G2 and G4. \t')
          .replaceFirst(
            'a second schema bullet that covers the document.',
            'a bullet that covers G1, then wraps',
          ),
    );
    expect(c.coversClauses.map((CoversClause x) => x.ids), <Set<int>?>[
      <int>{1, 2, 4},
    ]);
    expect(c.unclosedCovers, <String>[
      '- schema: a bullet that covers G1, then wraps',
    ]);
    expect(readContract('sample', text).unclosedCovers, isEmpty);
  });
  test('every line is right-trimmed before any section is read', () {
    expectSample(
      readContract(
        'sample',
        text
            .replaceFirst('---\nid:', '---  \nid:')
            .replaceFirst('---\n\n#', '--- \n\n#')
            .replaceFirst('## Validation\n', '## Validation\t\n'),
      ),
    );
  });
  test('only a schema or file bullet holding the word covers is unclosed', () {
    final ContractText c = readContract(
      'sample',
      text
          .replaceFirst('uses every declaration.', 'covers G1, see below')
          .replaceFirst(
            'a second schema bullet that covers the document.',
            'a bullet the tool recovers from',
          )
          .replaceFirst(
            'holds one file. The file set covers G1 to G2 and G4.',
            'holds one file that covers G1 and is read twice',
          ),
    );
    expect(c.unclosedCovers, <String>[
      '- file: `hsdd/contract/fixture/sample/input/` holds one file that covers G1 and is read twice',
    ]);
    expect(c.coversClauses, isEmpty);
  });
  test('a row keeps its Case cell as written', () {
    expect(
      readContract(
        'sample',
        text,
      ).invocationRows.map((InvocationRow x) => x.caseCell),
      <String>['`run-clean`', '`run-usage`', 'run-bad'],
    );
  });
  test('ContractKind.byLabel reads the five labels and nothing else', () {
    expect(
      ContractKind.values.map(
        (ContractKind k) => ContractKind.byLabel(k.label),
      ),
      ContractKind.values,
    );
    expect(ContractKind.byLabel('widget'), isNull);
    expect(ContractKind.byLabel(null), isNull);
  });
  test('generatorCommands holds the spans of - file: bullets that hold {output} and a space', () {
    expect(readContract('gen', genText).generatorCommands, <String>[
      'fvm dart run gen:generate {input}/word.txt {output}',
      'dart run gen:other {output}',
    ]);
  });
  test('the committed topic-codegen text names one generator command', () {
    final String root = findWorkspaceRoot(Directory.current)!.path;
    expect(
      readContract(
        'topic-codegen',
        File('$root/hsdd/contract/topic-codegen.md').readAsStringSync(),
      ).generatorCommands,
      <String>[
        'fvm dart run nidana_dart_codegen:generate --graph {input}/topology-graph.json {input}/topics.yaml {output}',
      ],
    );
  });

  // Beyond the brief: CRLF text reads alike; a span needs both {output} and
  // a space; only a line that begins `- file: ` counts; a text with no
  // generator span has none.
  test('generatorCommands reads CRLF text alike and needs {output}, a space and a - file: line', () {
    expect(
      readContract('gen', genText.replaceAll('\n', '\r\n')).generatorCommands,
      readContract('gen', genText).generatorCommands,
    );
    expect(
      readContract(
        'gen',
        '## Validation\n\n'
            '- file: `dart run {input}` and `{output}/x` and `dart{output}`.\n'
            '  - file: `dart run gen:nested {output}`.\n'
            'file: `dart run gen:bare {output}`.\n'
            '- files: `dart run gen:plural {output}`.\n'
            '- file:`dart run gen:tight {output}`.\n'
            '- file: `dart run gen:last {output}`\n',
      ).generatorCommands,
      <String>['dart run gen:last {output}'],
    );
    expect(readContract('sample', text).generatorCommands, isEmpty);
  });
}
