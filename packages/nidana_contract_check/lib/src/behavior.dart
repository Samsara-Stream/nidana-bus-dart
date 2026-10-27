/// The `behavior` set's plan (ADR-001 items 4 and 9): what the set does with
/// each binding of a slug, decided from the snapshots alone, and the command
/// line of the runner that runs one.
///
/// A binding is a `behavior/{name}_test.dart` directly under a slug's
/// fixture directory. It imports one conformance library by a relative path,
/// possibly another slug's, and that library's slug keys the `--guarantee`
/// restriction. Running a binding is the shell's.
library;

import 'package:path/path.dart' as p;

import 'dart_library.dart';
import 'outcome.dart';
import 'packages.dart';
import 'request.dart';
import 'snapshot.dart';

/// The runners a binding runs under (ADR-001 item 9), each with its command for report text.
enum Runner {
  dart('dart test'),
  flutter('flutter test --no-pub');

  const Runner(this.label);

  /// The runner's command, for report text.
  final String label;
}

/// The rules of the behavior set.
enum BehaviorRule implements Rule {
  /// The binding can be read.
  binding('binding'),

  /// It imports exactly one conformance library that can be read.
  suite('suite'),

  /// It loads under its runner.
  load('load'),

  /// A case runs, and every case it runs passes.
  cases('cases'),

  /// One failing case, by name.
  failedCase('failed-case');

  const BehaviorRule(this.label);

  @override
  final String label;
}

/// What the behavior set does with one binding.
sealed class BindingPlan {
  const BindingPlan();

  /// The binding's path from the workspace root.
  String get path;
}

/// Decided without running: a fixture defect ([Failed]), [Pending], or [Passed] unrun.
final class BindingSettled extends BindingPlan {
  const BindingSettled(this.outcome);

  /// The binding's outcome.
  final FixtureOutcome outcome;

  @override
  String get path => outcome.path;
}

/// Run the binding at [path] under [runner]; [admitted] is null when unrestricted, else the
/// restriction's ids of [suiteSlug], at least one of which begins one of the suite's case names.
final class BindingRun extends BindingPlan {
  const BindingRun({
    required this.path,
    required this.runner,
    required this.suiteSlug,
    required this.admitted,
  });

  @override
  final String path;

  /// The runner the binding's imports choose.
  final Runner runner;

  /// The slug of the conformance library the binding imports.
  final String suiteSlug;

  /// The ids the runner's name filter admits; null when unrestricted.
  final Set<int>? admitted;
}

/// The slugs of the conformance libraries the bindings of [snapshot] import, its own included
/// when they import one of its own; a binding whose source was not read contributes none.
Set<String> suiteSlugs(SlugSnapshot snapshot) =>
    Set<String>.unmodifiable(<String>{
      for (final String relative in _bindingsOf(snapshot))
        if (snapshot.files[relative] case final String source)
          for (final _Suite suite in _suitesOf(
            '${fixtureDirectory(snapshot.slug)}$relative',
            readDartLibrary(source),
          ))
            suite.slug,
    });

/// One plan per binding of [snapshot], ascending by path. [snapshots] holds the snapshots of the
/// other slugs whose suites the bindings import (more may be present); [packages] are the
/// workspace's package names.
///
/// A binding's verdicts come in a fixed order (design decision 5): a binding
/// or a suite that cannot be read fails; then an absent package of either
/// makes the binding [Pending]; then a restriction that admits none of the
/// suite's cases passes it unrun; otherwise it runs.
List<BindingPlan> planBindings(
  SlugSnapshot snapshot, {
  required Map<String, SlugSnapshot> snapshots,
  required Set<String> packages,
  required Set<GuaranteeRef>? restriction,
}) {
  final _Inputs inputs = (
    snapshot: snapshot,
    snapshots: snapshots,
    packages: packages,
    restriction: restriction,
  );
  return List<BindingPlan>.unmodifiable(<BindingPlan>[
    for (final String relative in _bindingsOf(snapshot))
      if (_decodingAt(snapshot, relative) case final SourceDecoding binding)
        _planBinding(
          inputs,
          '${fixtureDirectory(snapshot.slug)}$relative',
          binding,
        ),
  ]);
}

/// The test-name filter of [ids], ascending, anchored at the start of the name: `^(G2|G5) `.
String nameFilter(Set<int> ids) =>
    '^(${(ids.toList()..sort()).map((int id) => 'G$id').join('|')}) ';

/// The runner's arguments for [run], from the workspace root: `test`, then `--no-pub` for
/// flutter, `--reporter json`, `--name {nameFilter}` when restricted, and the binding's path.
List<String> testArguments(BindingRun run) =>
    List<String>.unmodifiable(<String>[
      'test',
      if (run.runner == Runner.flutter) '--no-pub',
      '--reporter',
      'json',
      if (run.admitted case final Set<int> admitted) ...<String>[
        '--name',
        nameFilter(admitted),
      ],
      run.path,
    ]);

/// The flutter of the Flutter SDK that holds [dart], when [dart] sits at
/// `{root}/bin/cache/dart-sdk/bin/dart` (or `dart.exe`): `{root}/bin/flutter` (or `flutter.bat`);
/// null for any other path. Whether the file exists is the shell's to check.
String? flutterBeside(String dart) => switch (p.split(dart)) {
  [...final List<String> root, 'bin', 'cache', 'dart-sdk', 'bin', 'dart'] =>
    p.joinAll(<String>[...root, 'bin', 'flutter']),
  [...final List<String> root, 'bin', 'cache', 'dart-sdk', 'bin', 'dart.exe'] =>
    p.joinAll(<String>[...root, 'bin', 'flutter.bat']),
  _ => null,
};

/// What every binding of one slug is planned against: [planBindings]'s arguments.
typedef _Inputs = ({
  SlugSnapshot snapshot,
  Map<String, SlugSnapshot> snapshots,
  Set<String> packages,
  Set<GuaranteeRef>? restriction,
});

/// A conformance library a binding imports: its path from the workspace root, and its slug.
typedef _Suite = ({String path, String slug});

/// A binding, by its path relative to its slug's fixture directory.
final RegExp _bindingLibrary = RegExp(r'^behavior/[^/]+_test\.dart$');

/// A conformance library, by its path from the workspace root; its slug in group 1.
final RegExp _suiteLibrary = RegExp(
  r'^hsdd/contract/fixture/([^/]+)/behavior/[^/]+_conformance\.dart$',
);

/// The relative paths of the bindings of [snapshot], ascending.
List<String> _bindingsOf(SlugSnapshot snapshot) => <String>[
  for (final String relative in snapshot.files.keys)
    if (_bindingLibrary.hasMatch(relative)) relative,
]..sort();

/// The source of the file at [relative] below [snapshot]'s fixture directory, as the shell
/// decoded it; null when the snapshot holds no source for it.
SourceDecoding? _decodingAt(SlugSnapshot snapshot, String relative) =>
    switch ((snapshot.files[relative], snapshot.undecodable[relative])) {
      (final String text, _) => SourceText(text),
      (null, final String reason) => SourceNotUtf8(reason),
      (null, null) => null,
    };

/// The conformance libraries the directives of [binding], the library at [path], import, in
/// directive order: each URI with no scheme that does not start with `/`, resolved against the
/// binding's directory, that names a conformance library. A directive that is no URI names none.
List<_Suite> _suitesOf(String path, DartLibrary binding) => <_Suite>[
  for (final String uri in binding.directives)
    if (Uri.tryParse(uri) case Uri(hasScheme: false) when !uri.startsWith('/'))
      if (_suiteLibrary.firstMatch(
            p.posix.normalize(p.posix.join(p.posix.dirname(path), uri)),
          )
          case final RegExpMatch match)
        (path: match.group(0)!, slug: match.group(1)!),
];

/// The binding at [path] can be read; then [_planImports].
BindingPlan _planBinding(_Inputs inputs, String path, SourceDecoding binding) =>
    switch (binding) {
      SourceNotUtf8(:final String reason) => _failed(
        path,
        BehaviorRule.binding,
        reason,
      ),
      SourceText(:final String text) => _planImports(
        inputs,
        path,
        readDartLibrary(text),
      ),
    };

/// The binding at [path] imports exactly one conformance library; then [_planSuite].
BindingPlan _planImports(_Inputs inputs, String path, DartLibrary binding) =>
    switch (_suitesOf(path, binding)) {
      [final _Suite suite] => _planSuite(inputs, path, binding, suite),
      [] => _failed(path, BehaviorRule.suite, 'imports no conformance library'),
      final List<_Suite> suites => _failed(
        path,
        BehaviorRule.suite,
        'imports ${suites.length} conformance libraries: '
        '${suites.map((_Suite suite) => suite.path).join(', ')}',
      ),
    };

/// The [suite] of the binding at [path] can be read; then [_planRun].
BindingPlan _planSuite(
  _Inputs inputs,
  String path,
  DartLibrary binding,
  _Suite suite,
) => switch (_suiteDecoding(inputs, suite)) {
  null => _failed(path, BehaviorRule.suite, '${suite.path} does not exist'),
  SourceNotUtf8(:final String reason) => _failed(
    path,
    BehaviorRule.suite,
    '${suite.path}: $reason',
  ),
  SourceText(:final String text) => _planRun(
    inputs,
    path,
    binding,
    suite,
    readDartLibrary(text),
  ),
};

/// The binding at [path] and its suite read: [Pending] on an absent package of either, else
/// [Passed] unrun when the restriction admits no case of the suite, else a [BindingRun].
BindingPlan _planRun(
  _Inputs inputs,
  String path,
  DartLibrary binding,
  _Suite suite,
  DartLibrary suiteLibrary,
) {
  final List<String> absent = List<String>.unmodifiable(
    <String>{
      ...absentPackages(binding, inputs.packages),
      ...absentPackages(suiteLibrary, inputs.packages),
    }.toList()..sort(),
  );
  if (absent.isNotEmpty) {
    return BindingSettled(Pending(path, absent));
  }
  final Set<int>? admitted = switch (inputs.restriction) {
    final Set<GuaranteeRef> restriction => Set<int>.unmodifiable(<int>{
      for (final GuaranteeRef ref in restriction)
        if (ref.slug == suite.slug) ref.number,
    }),
    null => null,
  };
  return admitted != null && !_admitsACase(suiteLibrary, admitted)
      ? BindingSettled(
          Passed(
            path,
            detail: 'not run: the restriction admits no case of ${suite.path}',
          ),
        )
      : BindingRun(
          path: path,
          runner: binding.directives.any(_namesFlutterTest)
              ? Runner.flutter
              : Runner.dart,
          suiteSlug: suite.slug,
          admitted: admitted,
        );
}

/// The source of [suite], read from the replayed slug's own snapshot for its own slug, else from
/// the snapshot of the suite's slug; null when there is no snapshot or no such file.
SourceDecoding? _suiteDecoding(_Inputs inputs, _Suite suite) {
  final SlugSnapshot? owner = suite.slug == inputs.snapshot.slug
      ? inputs.snapshot
      : inputs.snapshots[suite.slug];
  return owner == null
      ? null
      : _decodingAt(
          owner,
          suite.path.substring(fixtureDirectory(suite.slug).length),
        );
}

/// Whether a case name of [suite]'s case lists begins with one of [admitted].
bool _admitsACase(DartLibrary suite, Set<int> admitted) => suite.caseLists
    .expand((CaseList list) => list.cases)
    .any((CaseName name) => admitted.contains(caseIdOf(name.name)));

/// Whether [uri] names a library of `package:flutter_test`.
bool _namesFlutterTest(String uri) => uri.startsWith('package:flutter_test/');

/// The settled [Failed] of the binding at [path], with one problem breaking [rule].
BindingSettled _failed(String path, BehaviorRule rule, String detail) =>
    BindingSettled(
      Failed(
        path,
        List<Problem>.unmodifiable(<Problem>[Problem(rule, detail)]),
      ),
    );
