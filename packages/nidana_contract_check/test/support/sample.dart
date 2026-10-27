/// The seeded samples the tests share: the clean `sample` slug (kind `api`),
/// the clean `tool` slug (kind `file`) and the clean `doc` slug (kind
/// `schema`), as strings keyed by their paths from the workspace root. A
/// seeded fixture is a string, never a `.dart` file in the package (D2
/// item 5).
library;

import 'dart:convert';

import 'package:nidana_contract_check/src/snapshot.dart';

/// `hsdd/contract/sample.md`.
const String sampleContract = r'''
---
id: sample
version: v1
status: stable
kind: api
---

# sample@v1

## Guarantees / invariants

- **G1** a sample type is closed.
- **G2** a sample value round-trips.
- **G3** a sample value is redacted.
- **G4** a property of the package's pubspec.

## Validation

- surface: `hsdd/contract/fixture/sample/surface/` uses every declaration.
- reject: `hsdd/contract/fixture/sample/reject/`, one library per type-level guarantee.
- behavior: conformance library `hsdd/contract/fixture/sample/behavior/sample_conformance.dart`, cases `sampleConformance`.
- binding: `hsdd/contract/fixture/sample/behavior/sample_impl_test.dart` binds the suite, under `dart test`.
- goldens: `hsdd/contract/fixture/sample/goldens/`, renderings the behavior set compares.
- not executable: G4, a property of the package's pubspec; checked by nidana.model's gates
- not executable: G3's last clause, on a value no case can build; checked by nidana.model's gates
''';

/// `hsdd/contract/fixture/sample/reject/sample_is_closed.dart`.
const String sampleReject = r'''
// Reject fixture for sample@v1 G1: the sample type is closed.
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class Local extends Sample {}
''';

/// `hsdd/contract/fixture/sample/behavior/sample_conformance.dart`: the
/// `name:` on line 12 is the first case; the `G9` topic in its body is no case.
const String _sampleConformance = r'''
import 'package:matcher/expect.dart';
import 'package:nidana_contract_check/fixture.dart';
import 'package:sample/sample.dart';

abstract interface class SampleHarness {
  Future<void> settle();
}

final List<ConformanceCase<SampleHarness>> sampleConformance =
    <ConformanceCase<SampleHarness>>[
  (
    name: 'G2 a sample value round-trips',
    body: (SampleHarness h) async {
      expect(Topic(name: 'G9 a topic, not a case').name, isNotEmpty);
    },
  ),
  (
    name: 'G3 a sample value is redacted',
    body: (SampleHarness h) async {},
  ),
];
''';

/// `hsdd/contract/fixture/sample/behavior/sample_impl_test.dart`.
const String _sampleBinding = r'''
import 'package:test/test.dart';

import 'sample_conformance.dart';

void main() {
  for (final c in sampleConformance) {
    test(c.name, () => c.body(_Harness()));
  }
}
''';

/// `hsdd/contract/fixture/sample/surface/use.dart`.
const String _sampleSurface = r'''
import 'package:sample/sample.dart';

Sample use() => Sample();
''';

/// `hsdd/contract/tool.md`.
const String _toolContract = r'''
---
id: tool
version: v1
status: stable
kind: file
---

# tool@v1

## Guarantees / invariants

- **G1** generate writes the expected tree.
- **G2** generate exits 2 on an unknown option.

## Validation

- file: `hsdd/contract/fixture/tool/input/` holds `in.txt`; the replay runs `fvm dart run tool:generate {input}/in.txt {output}` and compares the tree with `expected/`. The file set covers G1.
- invocations: one directory per case under `hsdd/contract/fixture/tool/invocation/`.

| Case | Command | Exit | Covers |
|------|---------|------|--------|
| `generate-usage` | `tool:generate --frob` | 2 | G2: an unknown option |
''';

/// The clean `sample` slug, keyed by path from the workspace root.
const Map<String, String> sampleFiles = <String, String>{
  'hsdd/contract/sample.md': sampleContract,
  'hsdd/contract/fixture/sample/reject/sample_is_closed.dart': sampleReject,
  'hsdd/contract/fixture/sample/behavior/sample_conformance.dart':
      _sampleConformance,
  'hsdd/contract/fixture/sample/behavior/sample_impl_test.dart': _sampleBinding,
  'hsdd/contract/fixture/sample/surface/use.dart': _sampleSurface,
  'hsdd/contract/fixture/sample/goldens/sample.txt': 'golden\n',
};

/// `hsdd/contract/fixture/sample/surface/dirty.dart`: an unused import, a
/// warning on line 1.
const String _surfaceDirty = r'''
import 'dart:async';

import 'package:sample/sample.dart';

Sample use() => Sample();
''';

/// `hsdd/contract/fixture/sample/surface/pending.dart`: it imports a package
/// no workspace holds.
const String _surfacePending = r'''
import 'package:producer/producer.dart';

Producer use() => Producer();
''';

/// `hsdd/contract/fixture/sample/reject/assigns_final.dart`: the marked code
/// on the marked line.
const String _rejectAssignsFinal = r'''
// covers: G1
import 'package:sample/sample.dart';

void f(Sample s) {
  // expect-diagnostic: assignment_to_final
  s.count = 1;
}
''';

/// `hsdd/contract/fixture/sample/reject/extra_warning.dart`: the marked code,
/// and a warning no marker names on line 8.
const String _rejectExtraWarning = r'''
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class Local extends Sample {}

void f() {
  final int unused = 0;
}
''';

/// `hsdd/contract/fixture/sample/reject/wrong_code.dart`: the marker names a
/// code the analyzer does not report on its line.
const String _rejectWrongCode = r'''
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: undefined_class
final class Local extends Sample {}
''';

/// `hsdd/contract/fixture/sample/reject/wrong_line.dart`: the marked code is
/// reported one line below the line the marker names.
const String _rejectWrongLine = r'''
// covers: G1
import 'package:sample/sample.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
const int before = 0;
final class Local extends Sample {}
''';

/// [sampleFiles] with a surface library that has a warning, one that imports
/// a package no workspace holds, and four more reject libraries; the seeds of
/// the analyzer tests.
const Map<String, String> analysisFiles = <String, String>{
  ...sampleFiles,
  'hsdd/contract/fixture/sample/surface/dirty.dart': _surfaceDirty,
  'hsdd/contract/fixture/sample/surface/pending.dart': _surfacePending,
  'hsdd/contract/fixture/sample/reject/assigns_final.dart': _rejectAssignsFinal,
  'hsdd/contract/fixture/sample/reject/extra_warning.dart': _rejectExtraWarning,
  'hsdd/contract/fixture/sample/reject/wrong_code.dart': _rejectWrongCode,
  'hsdd/contract/fixture/sample/reject/wrong_line.dart': _rejectWrongLine,
};

/// The clean `tool` slug (kind `file`), keyed by path from the workspace root.
const Map<String, String> toolFiles = <String, String>{
  'hsdd/contract/tool.md': _toolContract,
  'hsdd/contract/fixture/tool/input/in.txt': 'in\n',
  'hsdd/contract/fixture/tool/expected/out.txt': 'out\n',
  'hsdd/contract/fixture/tool/invocation/generate-usage/args':
      'tool:generate\n--frob\n',
  'hsdd/contract/fixture/tool/invocation/generate-usage/exit_code': '2\n',
};

/// `hsdd/contract/doc.md`, a contract of kind `schema`.
const String docContract = r'''
---
id: doc
version: v1
status: stable
kind: schema
---

# doc@v1

## Guarantees / invariants

- **G1** a document names itself and counts from zero.

## Validation

- schema: `hsdd/contract/schema/doc.schema.json`, JSON Schema draft 2020-12, replayed by the `schema` set (ADR-001 item 5); covers G1.
- valid: `hsdd/contract/fixture/doc/valid/`, documents that validate.
- invalid: `hsdd/contract/fixture/doc/invalid/`, documents that do not.
''';

/// `hsdd/contract/schema/doc.schema.json`.
const String docSchema = r'''
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "count": { "type": "integer", "minimum": 0 }
  },
  "required": ["name", "count"],
  "additionalProperties": false
}
''';

/// The clean `doc` slug (kind `schema`), keyed by path from the workspace
/// root: one document that validates and two that do not.
const Map<String, String> docFiles = <String, String>{
  'hsdd/contract/doc.md': docContract,
  'hsdd/contract/schema/doc.schema.json': docSchema,
  'hsdd/contract/fixture/doc/valid/minimal.json': '{"name": "a", "count": 0}\n',
  'hsdd/contract/fixture/doc/invalid/negative-count.json':
      '{"name": "a", "count": -1}\n',
  'hsdd/contract/fixture/doc/invalid/extra-property.json':
      '{"name": "a", "count": 0, "extra": true}\n',
};

/// [base] with each of [changes] applied: a path mapped to a text holds that
/// text, a path mapped to null is removed.
Map<String, String> changed(
  Map<String, String> base,
  Map<String, String?> changes,
) => Map<String, String>.unmodifiable(<String, String>{
  for (final MapEntry<String, String> entry in base.entries)
    if (!changes.containsKey(entry.key)) entry.key: entry.value,
  for (final MapEntry<String, String?> entry in changes.entries)
    entry.key: ?entry.value,
});

/// The snapshot of [slug] that the shell would read from a workspace holding
/// [files], keyed by path from the workspace root.
///
/// [bytes] are files given as raw bytes, keyed by path from the workspace
/// root; a path in both maps takes its bytes. A source [holdsSource] accepts
/// is decoded by [decodeSource], as the shell decodes it: one that is not
/// UTF-8 has a null source and its reason in [SlugSnapshot.undecodable].
SlugSnapshot snapshotOf(
  String slug,
  Map<String, String> files, {
  Map<String, List<int>> bytes = const <String, List<int>>{},
}) {
  List<int>? bytesAt(String path) => switch ((bytes[path], files[path])) {
    (final List<int> raw, _) => raw,
    (null, final String text) => utf8.encode(text),
    (null, null) => null,
  };
  String? textAt(String path) => switch (bytesAt(path)) {
    final List<int> raw => utf8.decode(raw),
    null => null,
  };
  final String fixtures = fixtureDirectory(slug);
  final List<String> below = <String>[
    for (final String path in <String>{...files.keys, ...bytes.keys})
      if (path.startsWith(fixtures)) path.substring(fixtures.length),
  ];
  final Map<String, SourceDecoding> sources =
      Map<String, SourceDecoding>.unmodifiable(<String, SourceDecoding>{
        for (final String path in below)
          if (holdsSource(path)) path: decodeSource(bytesAt('$fixtures$path')!),
      });
  return SlugSnapshot(
    slug: slug,
    contractText: textAt(contractPath(slug)),
    schemaBytes: bytesAt(schemaPath(slug)),
    directories: Set<String>.unmodifiable(<String>{
      for (final String path in below) ..._ancestors(path),
    }),
    files: Map<String, String?>.unmodifiable(<String, String?>{
      for (final String path in below)
        path: switch (sources[path]) {
          SourceText(:final String text) => text,
          SourceNotUtf8() || null => null,
        },
    }),
    documents: Map<String, List<int>>.unmodifiable(<String, List<int>>{
      for (final String path in below)
        if (holdsDocument(path)) path: bytesAt('$fixtures$path')!,
    }),
    undecodable: Map<String, String>.unmodifiable(<String, String>{
      for (final MapEntry<String, SourceDecoding>(
            key: String path,
            value: SourceDecoding decoding,
          )
          in sources.entries)
        if (decoding case SourceNotUtf8(:final String reason)) path: reason,
    }),
  );
}

/// The directories that hold the relative [path]: `a` and `a/b` for
/// `a/b/c.txt`.
Iterable<String> _ancestors(String path) {
  final List<String> segments = path.split('/');
  return <String>[
    for (int count = 1; count < segments.length; count += 1)
      segments.take(count).join('/'),
  ];
}
