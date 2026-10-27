// packages/nidana_contract_check/test/behavior_test.dart
import 'package:nidana_contract_check/src/behavior.dart';
import 'package:nidana_contract_check/src/ids.dart';
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/structure.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

const String s = 'hsdd/contract/fixture/sample/';
const String h = 'hsdd/contract/fixture/host/';
const Set<String> everyPackage = <String>{
  'flutter_test',
  'matcher',
  'nidana_contract_check',
  'sample',
  'test',
};

/// A settled plan as its report line; a run as `RUN {path} {runner} {suite slug} {ids, or all}`.
String describe(BindingPlan plan) => switch (plan) {
  BindingSettled(:final FixtureOutcome outcome) => outcomeLine(
    CheckSet.behavior,
    outcome,
  ),
  BindingRun(
    :final String path,
    :final Runner runner,
    :final String suiteSlug,
    :final Set<int>? admitted,
  ) =>
    'RUN $path ${runner.label} $suiteSlug ${admitted == null ? 'all' : formatIds(admitted)}',
};

final SlugSnapshot sample = snapshotOf('sample', behaviorFiles);

List<String> plans(
  SlugSnapshot snapshot, {
  Map<String, SlugSnapshot> others = const <String, SlugSnapshot>{},
  Set<String> packages = everyPackage,
  Set<GuaranteeRef>? restriction,
}) => planBindings(
  snapshot,
  snapshots: others,
  packages: packages,
  restriction: restriction,
).map(describe).toList();

/// The suite of [behaviorFiles].
final String conformance =
    behaviorFiles['${s}behavior/sample_conformance.dart']!;

/// The binding of [hostFiles].
const String hostBindingPath = '${h}behavior/host_impl_test.dart';
final String hostBinding = hostFiles[hostBindingPath]!;

/// The relative import of the sample's suite in [hostBinding].
const String hostSuiteImport =
    "import '../../sample/behavior/sample_conformance.dart';";

final SlugSnapshot host = snapshotOf('host', hostFiles);

/// The not-run line of [binding] when the restriction admits no case of the sample's suite.
String notRun(String binding) =>
    'PASS behavior $binding: not run: the restriction admits no case of '
    '${s}behavior/sample_conformance.dart';

void main() {
  test('the behavior and host samples pass the structure set', () {
    // As report lines, so a failure shows its problems.
    for (final SlugSnapshot snapshot in <SlugSnapshot>[sample, host]) {
      expect(
        checkStructure(snapshot).map(
          (FixtureOutcome outcome) => outcomeLine(CheckSet.structure, outcome),
        ),
        everyElement(startsWith('PASS ')),
      );
    }
  });
  test('unrestricted, each binding runs every case under the runner its imports choose', () {
    expect(plans(sample), <String>[
      'RUN ${s}behavior/sample_impl_test.dart dart test sample all',
      'RUN ${s}behavior/widget_impl_test.dart flutter test --no-pub sample all',
    ]);
  });
  test("a bare id restricts the bindings of the replayed slug's own suite", () {
    expect(
      plans(
        sample,
        restriction: const <GuaranteeRef>{(slug: 'sample', number: 2)},
      ),
      <String>[
        'RUN ${s}behavior/sample_impl_test.dart dart test sample G2',
        'RUN ${s}behavior/widget_impl_test.dart flutter test --no-pub sample G2',
      ],
    );
  });
  test('an id no case begins with: not run, passing', () {
    expect(
      plans(
        sample,
        restriction: const <GuaranteeRef>{(slug: 'sample', number: 4)},
      ),
      <String>[
        notRun('${s}behavior/sample_impl_test.dart'),
        notRun('${s}behavior/widget_impl_test.dart'),
      ],
    );
  });
  test('the id is anchored: G2 admits no G25 case', () {
    final SlugSnapshot g25 = snapshotOf(
      'sample',
      changed(behaviorFiles, <String, String>{
        '${s}behavior/sample_conformance.dart': conformance.replaceAll(
          "name: 'G2 ",
          "name: 'G25 ",
        ),
      }),
    );
    expect(
      plans(
        g25,
        restriction: const <GuaranteeRef>{(slug: 'sample', number: 2)},
      ),
      <String>[
        notRun('${s}behavior/sample_impl_test.dart'),
        notRun('${s}behavior/widget_impl_test.dart'),
      ],
    );
    expect(
      plans(
        g25,
        restriction: const <GuaranteeRef>{(slug: 'sample', number: 25)},
      ),
      <String>[
        'RUN ${s}behavior/sample_impl_test.dart dart test sample G25',
        'RUN ${s}behavior/widget_impl_test.dart flutter test --no-pub sample G25',
      ],
    );
  });
  test(
    "a binding of another slug's suite is restricted by that slug's ids alone",
    () {
      List<String> hostPlans(Set<GuaranteeRef>? restriction) => plans(
        host,
        others: <String, SlugSnapshot>{'sample': sample},
        restriction: restriction,
      );
      // G1 a body not implemented yet begins with G1, but G1 here is host's.
      expect(
        hostPlans(const <GuaranteeRef>{(slug: 'host', number: 1)}),
        <String>[notRun(hostBindingPath)],
      );
      expect(
        hostPlans(const <GuaranteeRef>{(slug: 'sample', number: 3)}),
        <String>['RUN $hostBindingPath dart test sample G3'],
      );
      expect(
        hostPlans(const <GuaranteeRef>{
          (slug: 'host', number: 1),
          (slug: 'sample', number: 2),
          (slug: 'sample', number: 3),
        }),
        <String>['RUN $hostBindingPath dart test sample G2, G3'],
      );
      expect(hostPlans(null), <String>[
        'RUN $hostBindingPath dart test sample all',
      ]);
    },
  );
  test('a suite that is absent or not UTF-8 fails the binding', () {
    expect(plans(host), <String>[
      'FAIL behavior $hostBindingPath: suite (${s}behavior/sample_conformance.dart does not exist)',
    ]);
    expect(
      plans(
        host,
        others: <String, SlugSnapshot>{
          'sample': snapshotOf(
            'sample',
            behaviorFiles,
            bytes: <String, List<int>>{
              '${s}behavior/sample_conformance.dart': <int>[0xff],
            },
          ),
        },
      ),
      <String>[
        'FAIL behavior $hostBindingPath: suite (${s}behavior/sample_conformance.dart: not UTF-8: Invalid UTF-8 byte (at offset 0))',
      ],
    );
  });
  test('a binding that is not UTF-8, or imports no or two conformance libraries, fails', () {
    expect(
      plans(
        snapshotOf(
          'host',
          hostFiles,
          bytes: <String, List<int>>{
            hostBindingPath: <int>[0xff],
          },
        ),
      ),
      <String>[
        'FAIL behavior $hostBindingPath: binding (not UTF-8: Invalid UTF-8 byte (at offset 0))',
      ],
    );
    expect(
      plans(
        snapshotOf(
          'host',
          changed(hostFiles, <String, String>{
            hostBindingPath: hostBinding.replaceFirst('$hostSuiteImport\n', ''),
          }),
        ),
        others: <String, SlugSnapshot>{'sample': sample},
      ),
      <String>[
        'FAIL behavior $hostBindingPath: suite (imports no conformance library)',
      ],
    );
    expect(
      plans(
        snapshotOf(
          'host',
          changed(hostFiles, <String, String>{
            hostBindingPath: hostBinding.replaceFirst(
              hostSuiteImport,
              "$hostSuiteImport\nimport '../../other/behavior/other_conformance.dart';",
            ),
          }),
        ),
        others: <String, SlugSnapshot>{'sample': sample},
      ),
      <String>[
        'FAIL behavior $hostBindingPath: suite (imports 2 conformance libraries: ${s}behavior/sample_conformance.dart, hsdd/contract/fixture/other/behavior/other_conformance.dart)',
      ],
    );
  });
  test('an absent package of the binding or of its suite alone makes the binding PENDING, before the restriction', () {
    const String absentSample =
        'package sample is absent from .dart_tool/package_config.json';
    final Set<String> noSample = everyPackage.difference(<String>{'sample'});
    expect(plans(sample, packages: noSample), <String>[
      'PENDING behavior ${s}behavior/sample_impl_test.dart: $absentSample',
      'PENDING behavior ${s}behavior/widget_impl_test.dart: $absentSample',
    ]);
    expect(
      plans(
        sample,
        packages: noSample,
        restriction: const <GuaranteeRef>{(slug: 'sample', number: 4)},
      ),
      <String>[
        'PENDING behavior ${s}behavior/sample_impl_test.dart: $absentSample',
        'PENDING behavior ${s}behavior/widget_impl_test.dart: $absentSample',
      ],
    );
    expect(
      plans(
        host,
        others: <String, SlugSnapshot>{'sample': sample},
        packages: everyPackage.difference(<String>{'matcher'}),
      ),
      <String>[
        'PENDING behavior $hostBindingPath: package matcher is absent from .dart_tool/package_config.json',
      ],
    );
    expect(
      plans(
        sample,
        packages: everyPackage.difference(<String>{'flutter_test'}),
      ),
      <String>[
        'RUN ${s}behavior/sample_impl_test.dart dart test sample all',
        'PENDING behavior ${s}behavior/widget_impl_test.dart: package flutter_test is absent from .dart_tool/package_config.json',
      ],
    );
  });
  test('only files directly under behavior/ named _test.dart are bindings', () {
    final String nested = behaviorFiles['${s}behavior/sample_impl_test.dart']!
        .replaceFirst(
          "import 'sample_conformance.dart';",
          "import '../sample_conformance.dart';",
        );
    expect(
      plans(
        snapshotOf(
          'sample',
          changed(behaviorFiles, <String, String>{
            '${s}behavior/sub/nested_test.dart': nested,
          }),
        ),
      ),
      <String>[
        'RUN ${s}behavior/sample_impl_test.dart dart test sample all',
        'RUN ${s}behavior/widget_impl_test.dart flutter test --no-pub sample all',
      ],
    );
  });
  test('suiteSlugs names the slugs whose suites the bindings import', () {
    expect(suiteSlugs(host), <String>{'sample'});
    expect(suiteSlugs(sample), <String>{'sample'});
    expect(
      suiteSlugs(
        snapshotOf(
          'host',
          hostFiles,
          bytes: <String, List<int>>{
            hostBindingPath: <int>[0xff],
          },
        ),
      ),
      isEmpty,
    );
  });
  test('nameFilter anchors ascending ids at the start of the name', () {
    expect(nameFilter(<int>{5, 2}), '^(G2|G5) ');
    expect(nameFilter(<int>{18}), '^(G18) ');
  });
  test('testArguments', () {
    expect(
      testArguments(
        const BindingRun(
          path: 'p',
          runner: Runner.dart,
          suiteSlug: 'x',
          admitted: null,
        ),
      ),
      <String>['test', '--reporter', 'json', 'p'],
    );
    expect(
      testArguments(
        const BindingRun(
          path: 'p',
          runner: Runner.flutter,
          suiteSlug: 'x',
          admitted: <int>{5, 2},
        ),
      ),
      <String>[
        'test',
        '--no-pub',
        '--reporter',
        'json',
        '--name',
        '^(G2|G5) ',
        'p',
      ],
    );
  });
  test(
    'flutterBeside finds the flutter of the Flutter SDK that holds the dart',
    () {
      expect(
        flutterBeside('/sdk/bin/cache/dart-sdk/bin/dart'),
        '/sdk/bin/flutter',
      );
      expect(
        flutterBeside('/sdk/bin/cache/dart-sdk/bin/dart.exe'),
        '/sdk/bin/flutter.bat',
      );
      expect(flutterBeside('/usr/lib/dart/bin/dart'), isNull);
      expect(flutterBeside('/sdk/bin/dart'), isNull);
      expect(flutterBeside('/sdk/bin/cache/dart-sdk/bin/dartvm'), isNull);
    },
  );

  // Beyond the brief: the rules of planBindings no test above would catch
  // breaking.
  group('beyond the brief', () {
    test('every id the restriction names for the suite is admitted, a case or not', () {
      expect(
        plans(
          sample,
          restriction: const <GuaranteeRef>{
            (slug: 'sample', number: 2),
            (slug: 'sample', number: 4),
          },
        ),
        <String>[
          'RUN ${s}behavior/sample_impl_test.dart dart test sample G2, G4',
          'RUN ${s}behavior/widget_impl_test.dart flutter test --no-pub sample G2, G4',
        ],
      );
    });
    test('the absent packages of a binding and its suite are joined, once, ascending', () {
      expect(
        plans(
          sample,
          packages: everyPackage.difference(<String>{'sample', 'matcher'}),
        ).first,
        'PENDING behavior ${s}behavior/sample_impl_test.dart: packages matcher, sample are absent from .dart_tool/package_config.json',
      );
    });
    test('a fixture defect comes before an absent package', () {
      expect(plans(host, packages: const <String>{}), <String>[
        'FAIL behavior $hostBindingPath: suite (${s}behavior/sample_conformance.dart does not exist)',
      ]);
    });
    test("another slug's snapshot without the suite's file: it does not exist", () {
      expect(
        plans(
          host,
          others: <String, SlugSnapshot>{
            'sample': snapshotOf(
              'sample',
              changed(behaviorFiles, <String, String?>{
                '${s}behavior/sample_conformance.dart': null,
              }),
            ),
          },
        ),
        <String>[
          'FAIL behavior $hostBindingPath: suite (${s}behavior/sample_conformance.dart does not exist)',
        ],
      );
    });
    test("a suite of the slug's own is read from its own snapshot", () {
      expect(
        plans(
          sample,
          others: <String, SlugSnapshot>{
            'sample': snapshotOf('sample', const <String, String>{}),
          },
        ),
        <String>[
          'RUN ${s}behavior/sample_impl_test.dart dart test sample all',
          'RUN ${s}behavior/widget_impl_test.dart flutter test --no-pub sample all',
        ],
      );
    });
    test('a binding not listed in ## Validation is planned too, in path order', () {
      expect(
        plans(
          snapshotOf(
            'sample',
            changed(behaviorFiles, <String, String>{
              '${s}behavior/a_impl_test.dart':
                  behaviorFiles['${s}behavior/sample_impl_test.dart']!,
            }),
          ),
        ),
        <String>[
          'RUN ${s}behavior/a_impl_test.dart dart test sample all',
          'RUN ${s}behavior/sample_impl_test.dart dart test sample all',
          'RUN ${s}behavior/widget_impl_test.dart flutter test --no-pub sample all',
        ],
      );
    });
    test('a directive with a scheme, or one that is no URI, names no suite', () {
      const String throughScheme =
          "import 'package:sample/../../../../../../${s}behavior/sample_conformance.dart';";
      // Resolved as a relative path, the package: URI would name the suite;
      // `:` is no URI, which Uri.parse rejects.
      expect(
        plans(
          snapshotOf(
            'host',
            changed(hostFiles, <String, String>{
              hostBindingPath: hostBinding.replaceFirst(
                hostSuiteImport,
                "$throughScheme\nimport ':';",
              ),
            }),
          ),
          others: <String, SlugSnapshot>{'sample': sample},
        ),
        <String>[
          'FAIL behavior $hostBindingPath: suite (imports no conformance library)',
        ],
      );
    });
    test('an export of package:flutter_test chooses flutter too', () {
      expect(
        plans(
          snapshotOf(
            'host',
            changed(hostFiles, <String, String>{
              hostBindingPath: hostBinding.replaceFirst(
                "import 'package:test/test.dart';",
                "export 'package:flutter_test/flutter_test.dart';",
              ),
            }),
          ),
          others: <String, SlugSnapshot>{'sample': sample},
        ),
        <String>['RUN $hostBindingPath flutter test --no-pub sample all'],
      );
    });
  });
}
