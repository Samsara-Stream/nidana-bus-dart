/// The `structure` set (ADR-001 item 9): marker and header syntax, item 3's
/// coverage, the bindings listed in `## Validation` against the files
/// present, the fixture directory's layout with its data directories, the
/// ban on `src/` imports, the contract text and every Dart source read as
/// UTF-8, and item 4's ban on a conformance library that imports
/// `package:test` or `package:flutter_test`.
///
/// It needs no implementation of the contract: it reads one [SlugSnapshot].
library;

import 'contract.dart';
import 'dart_library.dart';
import 'ids.dart';
import 'outcome.dart';
import 'snapshot.dart';

/// The rules of the `structure` set.
enum StructureRule implements Rule {
  contractText('contract-text'),
  validationForm('validation-form'),
  layout('layout'),
  coverage('coverage'),
  unknownId('unknown-id'),
  coversHeader('covers-header'),
  marker('marker'),
  caseName('case-name'),
  binding('binding'),
  invocationRow('invocation-row'),
  srcImport('src-import'),
  encoding('encoding'),
  conformanceImport('conformance-import');

  const StructureRule(this.label);

  @override
  final String label;
}

/// The `structure` set's outcomes for [snapshot].
///
/// The contract text, the fixture directory and each Dart library the
/// snapshot holds get a [Passed] or a [Failed]; any other path, a Dart source
/// that is not UTF-8 among them, appears only when it fails. The contract
/// text comes first, the fixture directory second, and every other path
/// after them in ascending order. A [Failed] lists its problems in the order
/// the checks run. Without a contract text, absent or not UTF-8, the
/// contract text's [Failed] is the only outcome.
List<FixtureOutcome> checkStructure(SlugSnapshot snapshot) {
  final String? text = snapshot.contractText;
  if (text == null) {
    final String path = contractPath(snapshot.slug);
    return List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[
      _outcome(path, <Problem>[
        Problem(
          StructureRule.contractText,
          snapshot.contractUndecodable ?? 'no contract text at $path',
        ),
      ]),
    ]);
  }
  final _Slug slug = _Slug.read(snapshot, readContract(snapshot.slug, text));
  final List<_Citation> citations = _citations(slug);
  return _outcomes(slug, <_Found>[
    ..._contractText(slug),
    ..._validationForms(slug),
    ..._listedBindingForms(slug),
    if (slug.contract.kind case final ContractKind kind) ..._layout(slug, kind),
    for (final _Library library in slug.libraries) ..._library(slug, library),
    ..._undecodableSources(slug),
    ..._absentBindings(slug),
    ..._invocationDirectories(slug),
    ..._unknownIds(slug, citations),
    ..._coverage(slug, citations),
  ]);
}

/// One slug as the checks read it.
final class _Slug {
  const _Slug({
    required this.name,
    required this.snapshot,
    required this.contract,
    required this.textPath,
    required this.directory,
    required this.declared,
    required this.listedBindings,
    required this.libraries,
  });

  factory _Slug.read(SlugSnapshot snapshot, ContractText contract) {
    final String directory = fixtureDirectory(snapshot.slug);
    final List<String> sourcePaths = <String>[
      for (final String relative in snapshot.files.keys)
        if (holdsSource(relative)) relative,
    ]..sort();
    return _Slug(
      name: snapshot.slug,
      snapshot: snapshot,
      contract: contract,
      textPath: contractPath(snapshot.slug),
      directory: directory,
      declared: Set<int>.unmodifiable(contract.guarantees),
      listedBindings: Set<String>.unmodifiable(<String>{
        for (final String binding in contract.bindings)
          ?_bindingBelow(directory, binding),
      }),
      libraries: List<_Library>.unmodifiable(<_Library>[
        for (final String relative in sourcePaths)
          if (snapshot.files[relative] case final String source)
            (
              relative: relative,
              path: '$directory$relative',
              content: readDartLibrary(source),
            ),
      ]),
    );
  }

  /// The slug.
  final String name;

  /// What the shell read for the slug.
  final SlugSnapshot snapshot;

  /// The contract text, read.
  final ContractText contract;

  /// The contract text's path from the workspace root.
  final String textPath;

  /// The fixture directory's path from the workspace root, with its slash.
  final String directory;

  /// The guarantee ids the contract text declares.
  final Set<int> declared;

  /// The listed bindings of the form `{directory}behavior/{name}_test.dart`,
  /// each relative to [directory].
  final Set<String> listedBindings;

  /// The files [holdsSource] accepts whose bytes are UTF-8, read as Dart
  /// libraries, by ascending relative path.
  final List<_Library> libraries;
}

/// A Dart library of the fixture directory: its path relative to that
/// directory, its path from the workspace root, and what it reads as.
typedef _Library = ({String relative, String path, DartLibrary content});

/// A problem found at a path from the workspace root.
typedef _Found = ({String path, Problem problem});

/// Guarantee ids cited at a path from the workspace root, and whether the
/// citation covers them (ADR-001 item 3).
typedef _Citation = ({String path, Set<int> ids, bool covers});

final RegExp _srcUri = RegExp(r'^package:[^/]+/src/');
final RegExp _testPackageUri = RegExp(r'^package:(test|flutter_test)/');
final RegExp _invocationCase = RegExp(r'^invocation/([^/]+)$');

/// The directories a file replay reads (ADR-001 item 6), in the order a
/// problem names them.
const List<String> _fileSetDirectories = <String>['input', 'expected'];

/// The frontmatter's `id` and `kind`, and the guarantee entries.
Iterable<_Found> _contractText(_Slug slug) => _at(slug.textPath, <Problem>[
  if (slug.contract.id != slug.name)
    Problem(
      StructureRule.contractText,
      'frontmatter id is ${slug.contract.id ?? 'none'}, expected ${slug.name}',
    ),
  if (slug.contract.kind == null)
    Problem(
      StructureRule.contractText,
      'unknown kind ${slug.contract.kindLabel ?? 'none'}',
    ),
  for (final String entry in slug.contract.malformedGuarantees)
    Problem(
      StructureRule.contractText,
      'guarantee entry does not begin with - **G{n}**: $entry',
    ),
  for (final int id in _repeated(slug.contract.guarantees))
    Problem(StructureRule.contractText, 'G$id repeats'),
]);

/// The forms of ADR-001 item 3 in `## Validation`: covers clauses, the
/// covers bullets without their closing clause, the sets the clauses name,
/// the Case table's rows and the not-executable lines.
Iterable<_Found> _validationForms(_Slug slug) {
  final ContractText contract = slug.contract;
  return _at(slug.textPath, <Problem>[
    for (final CoversClause clause in contract.coversClauses)
      if (clause.ids == null)
        Problem(
          StructureRule.validationForm,
          'malformed covers clause: covers ${clause.text}.',
        ),
    for (final String line in contract.unclosedCovers)
      Problem(
        StructureRule.validationForm,
        'bullet holds covers but does not end with covers {ids}.: $line',
      ),
    for (final CoversClause clause in contract.coversClauses)
      if (_absentFromSet(slug, clause) case final List<String> absent
          when absent.isNotEmpty)
        Problem(
          StructureRule.validationForm,
          'covers clause of the ${clause.bullet} bullet names a set that is '
          'absent: no ${absent.join(' and ')}',
        ),
    for (final InvocationRow row in contract.invocationRows)
      if (row.caseName == null)
        Problem(
          StructureRule.validationForm,
          'malformed Case cell: ${row.caseCell}',
        ),
    for (final InvocationRow row in contract.invocationRows)
      if (row.caseName case final String name when row.ids == null)
        Problem(
          StructureRule.validationForm,
          'malformed Covers cell of $name: ${row.covers}',
        ),
    for (final NotExecutableLine line in contract.notExecutable)
      if (line.id == null)
        Problem(
          StructureRule.validationForm,
          'not-executable line begins with no G{n}: ${line.text}',
        ),
    for (final NotExecutableLine line in contract.notExecutable)
      if (line.id case final int id when line.node == null)
        Problem(
          StructureRule.validationForm,
          "G$id's not-executable line names no node: "
          "; checked by {node}'s gates",
        ),
  ]);
}

/// The listed bindings that are not in the fixture directory's `behavior/`.
Iterable<_Found> _listedBindingForms(_Slug slug) =>
    _at(slug.textPath, <Problem>[
      for (final String binding in slug.contract.bindings)
        if (_bindingBelow(slug.directory, binding) == null)
          Problem(
            StructureRule.binding,
            'listed binding $binding is not in ${slug.directory}behavior/',
          ),
    ]);

/// The entries directly under the fixture directory against the set
/// directories of [kind] and the data directories `## Validation` lists; then
/// each directory `## Validation` lists, set directory or data directory,
/// that is absent.
Iterable<_Found> _layout(_Slug slug, ContractKind kind) {
  final Set<String> setDirectories = kind.setDirectories;
  final Set<String> dataDirectories = slug.contract.listedDirectories
      .difference(setDirectories);
  Problem neither(String entry) => Problem(
    StructureRule.layout,
    '$entry is neither a set directory of kind ${kind.label} '
    'nor a data directory listed in ## Validation',
  );
  return <_Found>[
    for (final String entry in slug.snapshot.files.keys)
      if (!entry.contains('/'))
        (path: '${slug.directory}$entry', problem: neither(entry)),
    for (final String entry in slug.snapshot.directories)
      if (!entry.contains('/') &&
          !setDirectories.contains(entry) &&
          !dataDirectories.contains(entry))
        (path: '${slug.directory}$entry/', problem: neither(entry)),
    for (final String name in slug.contract.listedDirectories)
      if (!slug.snapshot.directories.contains(name))
        (
          path: '${slug.directory}$name/',
          problem: const Problem(
            StructureRule.layout,
            'listed in ## Validation, absent',
          ),
        ),
  ];
}

/// One Dart library: its imports and exports, the header and markers of a
/// `reject/` library, the case names and the test-package imports of a
/// conformance library, and whether a binding is listed.
Iterable<_Found> _library(_Slug slug, _Library library) =>
    _at(library.path, <Problem>[
      for (final String uri in library.content.directives)
        if (_srcUri.hasMatch(uri)) Problem(StructureRule.srcImport, uri),
      if (library.relative.startsWith('reject/'))
        ..._rejectLibrary(library.content),
      if (isConformancePath(library.relative)) ...<Problem>[
        ..._conformanceLibraryCases(library.content),
        ..._conformanceLibraryImports(library.content),
      ],
      if (isBindingPath(library.relative) &&
          !slug.listedBindings.contains(library.relative))
        const Problem(StructureRule.binding, 'not listed in ## Validation'),
    ]);

/// The `// covers:` header and the `// expect-diagnostic:` markers of a
/// `reject/` library (ADR-001 item 4).
List<Problem> _rejectLibrary(DartLibrary content) => <Problem>[
  ...switch (content.coversHeaders) {
    [] => const <Problem>[
      Problem(StructureRule.coversHeader, 'no // covers: header'),
    ],
    [CoversHeader(ids: null, :final String text)] => <Problem>[
      Problem(StructureRule.coversHeader, 'malformed // covers: $text'),
    ],
    [_] => const <Problem>[],
    _ => const <Problem>[
      Problem(StructureRule.coversHeader, 'more than one // covers: header'),
    ],
  },
  for (final Marker marker in content.markers)
    if (marker.code == null)
      Problem(
        StructureRule.marker,
        'line ${marker.line}: '
        'not a marker of the form // expect-diagnostic: {code}',
      ),
  for (final Marker marker in content.markers)
    if (marker.code != null && !marker.followedByCode)
      Problem(
        StructureRule.marker,
        'line ${marker.line}: not followed by a line of code',
      ),
  if (!content.markers.any((Marker marker) => marker.code != null))
    const Problem(StructureRule.marker, 'no // expect-diagnostic: marker'),
];

/// The case lists and case names of a conformance library (ADR-001 item 4).
List<Problem> _conformanceLibraryCases(DartLibrary content) => <Problem>[
  if (content.caseLists.length != 1)
    Problem(
      StructureRule.caseName,
      '${content.caseLists.length} public List<ConformanceCase> '
      'declarations, expected one',
    ),
  for (final CaseList list in content.caseLists)
    for (final String problem in list.problems)
      Problem(StructureRule.caseName, problem),
  for (final CaseName name in _cases(content))
    if (name.name == null)
      Problem(
        StructureRule.caseName,
        'line ${name.line}: case name is not a string literal',
      ),
  for (final CaseName name in _cases(content))
    if (name.name case final String text when caseIdOf(text) == null)
      Problem(
        StructureRule.caseName,
        'line ${name.line}: case name does not begin with G{n} and a space: '
        '$text',
      ),
];

/// The imports and exports of a test package by a conformance library, in
/// directive order: it imports neither `package:test` nor
/// `package:flutter_test` (ADR-001 item 4), so a binding's own imports alone
/// choose its runner.
List<Problem> _conformanceLibraryImports(DartLibrary content) => <Problem>[
  for (final String uri in content.directives)
    if (_testPackageUri.hasMatch(uri))
      Problem(StructureRule.conformanceImport, uri),
];

/// Each Dart source that is not UTF-8, at its path with the reason. It is no
/// library, so no other rule reads it.
Iterable<_Found> _undecodableSources(_Slug slug) => <_Found>[
  for (final MapEntry<String, String>(
        key: String relative,
        value: String reason,
      )
      in slug.snapshot.undecodable.entries)
    (
      path: '${slug.directory}$relative',
      problem: Problem(StructureRule.encoding, reason),
    ),
];

/// The listed bindings that are not files of the fixture directory.
Iterable<_Found> _absentBindings(_Slug slug) => <_Found>[
  for (final String relative in slug.listedBindings)
    if (!slug.snapshot.files.containsKey(relative))
      (
        path: '${slug.directory}$relative',
        problem: const Problem(
          StructureRule.binding,
          'listed in ## Validation, absent',
        ),
      ),
];

/// The `invocation/{case}` directories against the Case table's rows.
Iterable<_Found> _invocationDirectories(_Slug slug) {
  final Set<String> directories = <String>{
    for (final String directory in slug.snapshot.directories)
      ?_invocationCase.firstMatch(directory)?.group(1),
  };
  final Set<String> rows = <String>{
    for (final InvocationRow row in slug.contract.invocationRows) ?row.caseName,
  };
  return <_Found>[
    for (final String name in directories.difference(rows))
      (
        path: '${slug.directory}invocation/$name/',
        problem: const Problem(
          StructureRule.invocationRow,
          'no row in the Case table',
        ),
      ),
    for (final String name in rows.difference(directories))
      (
        path: '${slug.directory}invocation/$name/',
        problem: const Problem(
          StructureRule.invocationRow,
          'a row of the Case table, absent',
        ),
      ),
  ];
}

/// Every citation of guarantee ids (ADR-001 item 3): the covers clauses, the
/// Case table's rows that name their case and the not-executable lines of the
/// contract text, the one parsed header of each `reject/` library, and the
/// case names of each conformance library. A row whose Case cell is malformed
/// names no recorded invocation, so it cites nothing, and a covers bullet
/// without its closing clause gives no clause, so it cites nothing either. A
/// covers clause covers its ids only when the set it names exists. A
/// not-executable line covers its id only when it is whole and names its
/// node; a partial line stands beside a fixture that covers the rest.
List<_Citation> _citations(_Slug slug) => <_Citation>[
  for (final CoversClause clause in slug.contract.coversClauses)
    if (clause.ids case final Set<int> ids)
      (
        path: slug.textPath,
        ids: ids,
        covers: _absentFromSet(slug, clause).isEmpty,
      ),
  for (final InvocationRow row in slug.contract.invocationRows)
    if (row case InvocationRow(caseName: String(), ids: final Set<int> ids))
      (path: slug.textPath, ids: ids, covers: true),
  for (final NotExecutableLine line in slug.contract.notExecutable)
    if (line.id case final int id)
      (
        path: slug.textPath,
        ids: <int>{id},
        covers: !line.partial && line.node != null,
      ),
  for (final _Library library in slug.libraries)
    if (library.relative.startsWith('reject/'))
      if (library.content.coversHeaders case [
        CoversHeader(ids: final Set<int> ids),
      ])
        (path: library.path, ids: ids, covers: true),
  for (final _Library library in slug.libraries)
    if (isConformancePath(library.relative))
      for (final CaseName name in _cases(library.content))
        if (caseIdOf(name.name) case final int id)
          (path: library.path, ids: <int>{id}, covers: true),
];

/// For each citing path, the cited ids the contract text does not declare.
Iterable<_Found> _unknownIds(_Slug slug, List<_Citation> citations) {
  final Map<String, Set<int>> unknown = <String, Set<int>>{
    for (final String path in <String>{
      for (final _Citation citation in citations) citation.path,
    })
      path: <int>{
        for (final _Citation citation in citations)
          if (citation.path == path) ...citation.ids,
      }.difference(slug.declared),
  };
  return <_Found>[
    for (final MapEntry<String, Set<int>>(key: String path, value: Set<int> ids)
        in unknown.entries)
      if (ids.isNotEmpty)
        (
          path: path,
          problem: Problem(
            StructureRule.unknownId,
            ids.length == 1
                ? '${formatIds(ids)} is not a guarantee of ${slug.name}'
                : '${formatIds(ids)} are not guarantees of ${slug.name}',
          ),
        ),
  ];
}

/// The declared ids no citation covers, reported at the fixture directory.
Iterable<_Found> _coverage(_Slug slug, List<_Citation> citations) {
  final Set<int> uncovered = slug.declared.difference(<int>{
    for (final _Citation citation in citations)
      if (citation.covers) ...citation.ids,
  });
  return <_Found>[
    if (uncovered.isNotEmpty)
      (
        path: slug.directory,
        problem: Problem(
          StructureRule.coverage,
          '${formatIds(uncovered)} uncovered',
        ),
      ),
  ];
}

/// One outcome per subject and per failing path: the contract text, the
/// fixture directory, then the libraries and the other failing paths by
/// ascending path. Each gets the problems [found] at it, in order.
List<FixtureOutcome> _outcomes(_Slug slug, List<_Found> found) {
  final Set<String> first = <String>{slug.textPath, slug.directory};
  final List<String> others = <String>{
    for (final _Library library in slug.libraries) library.path,
    for (final _Found problem in found) problem.path,
  }.difference(first).toList()..sort();
  return List<FixtureOutcome>.unmodifiable(<FixtureOutcome>[
    for (final String path in <String>[...first, ...others])
      _outcome(path, <Problem>[
        for (final _Found problem in found)
          if (problem.path == path) problem.problem,
      ]),
  ]);
}

/// [Passed] when [problems] is empty, else [Failed] with them.
FixtureOutcome _outcome(String path, List<Problem> problems) => problems.isEmpty
    ? Passed(path)
    : Failed(path, List<Problem>.unmodifiable(problems));

/// [problems], each found at [path].
Iterable<_Found> _at(String path, List<Problem> problems) =>
    problems.map((Problem problem) => (path: path, problem: problem));

/// The ids that occur more than once in [ids], each once, in the order of
/// their first occurrence.
Iterable<int> _repeated(List<int> ids) => ids.toSet().where(
  (int id) => ids.where((int other) => other == id).length > 1,
);

/// The cases of every case list of [content], in order.
Iterable<CaseName> _cases(DartLibrary content) =>
    content.caseLists.expand((CaseList list) => list.cases);

/// What the set that [clause]'s bullet names lacks: the schema file for a
/// `schema` bullet, `input/` and `expected/` for a `file` bullet. Empty when
/// the set exists.
List<String> _absentFromSet(_Slug slug, CoversClause clause) =>
    switch (clause.bullet) {
      'schema' => <String>[
        if (!slug.snapshot.hasSchemaFile) schemaPath(slug.name),
      ],
      'file' => <String>[
        for (final String directory in _fileSetDirectories)
          if (!slug.snapshot.directories.contains(directory)) '$directory/',
      ],
      _ => const <String>[],
    };

/// [binding], a path from the workspace root, relative to [directory] when
/// it has the form `{directory}behavior/{name}_test.dart`; null otherwise.
String? _bindingBelow(String directory, String binding) {
  final String? relative = binding.startsWith(directory)
      ? binding.substring(directory.length)
      : null;
  return relative != null && isBindingPath(relative) ? relative : null;
}
