// packages/nidana_contract_check/test/report_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/report.dart';
import 'package:nidana_contract_check/src/request.dart';
import 'package:nidana_contract_check/src/run.dart';
import 'package:nidana_contract_check/src/snapshot.dart';
import 'package:nidana_contract_check/src/structure.dart';
import 'package:test/test.dart';

import 'support/sample.dart';

Request request({Set<CheckSet>? sets}) =>
    Request(slugs: const <String>['sample'], sets: sets, restriction: null);

const SetChecked passing = SetChecked(
  CheckSet.structure,
  'sample',
  <FixtureOutcome>[Passed('a'), Passed('b')],
);
const SetChecked failing = SetChecked(
  CheckSet.structure,
  'tool',
  <FixtureOutcome>[
    Failed('c', <Problem>[Problem(StructureRule.layout, 'x')]),
  ],
);
const SetUnavailable unavailable = SetUnavailable(
  CheckSet.surface,
  'sample',
  'dart analyze exited 64 without a JSON report',
);
const SetChecked pending = SetChecked(
  CheckSet.reject,
  'sample',
  <FixtureOutcome>[
    Pending('hsdd/contract/fixture/sample/reject/a.dart', <String>['sample']),
  ],
);

void main() {
  group('setsOf', () {
    test('the sample has structure, surface, reject and behavior', () {
      expect(setsOf(snapshotOf('sample', sampleFiles)), <CheckSet>{
        CheckSet.structure,
        CheckSet.surface,
        CheckSet.reject,
        CheckSet.behavior,
      });
    });
    test('the tool sample has structure, file and cli', () {
      expect(setsOf(snapshotOf('tool', toolFiles)), <CheckSet>{
        CheckSet.structure,
        CheckSet.file,
        CheckSet.cli,
      });
    });
    test('a schema file or a valid/ or invalid/ directory gives schema', () {
      expect(
        setsOf(
          snapshotOf(
            'sample',
            changed(sampleFiles, <String, String?>{
              'hsdd/contract/schema/sample.schema.json': '{}',
            }),
          ),
        ),
        contains(CheckSet.schema),
      );
      expect(
        setsOf(
          snapshotOf(
            'sample',
            changed(sampleFiles, <String, String?>{
              'hsdd/contract/fixture/sample/invalid/a.json': '{}',
            }),
          ),
        ),
        contains(CheckSet.schema),
      );
    });
  });
  group('plannedSets', () {
    final SlugSnapshot sample = snapshotOf('sample', sampleFiles);
    test('every set the slug has, structure first', () {
      expect(plannedSets(request(), sample), <CheckSet>[
        CheckSet.structure,
        CheckSet.surface,
        CheckSet.reject,
        CheckSet.behavior,
      ]);
    });
    test('structure runs whether --set names it or not', () {
      expect(
        plannedSets(request(sets: <CheckSet>{CheckSet.reject}), sample),
        <CheckSet>[CheckSet.structure, CheckSet.reject],
      );
    });
    test('--set never adds a set the slug lacks', () {
      expect(
        plannedSets(
          request(sets: <CheckSet>{CheckSet.schema, CheckSet.cli}),
          sample,
        ),
        <CheckSet>[CheckSet.structure],
      );
    });
  });
  group('lines', () {
    test('a passed fixture', () {
      expect(
        outcomeLine(
          CheckSet.structure,
          const Passed('hsdd/contract/fixture/sample/'),
        ),
        'PASS structure hsdd/contract/fixture/sample/',
      );
    });
    test('a passed outcome with a detail prints it after a colon', () {
      expect(
        outcomeLine(CheckSet.behavior, const Passed('p', detail: 'd')),
        'PASS behavior p: d',
      );
      expect(
        outcomeLine(CheckSet.behavior, const Passed('p')),
        'PASS behavior p',
      );
    });
    test('a failed fixture lists every problem', () {
      expect(
        outcomeLine(
          CheckSet.structure,
          const Failed('hsdd/contract/fixture/sample/x.dart', <Problem>[
            Problem(StructureRule.layout, 'one'),
            Problem(StructureRule.marker, 'two'),
          ]),
        ),
        'FAIL structure hsdd/contract/fixture/sample/x.dart: layout (one); marker (two)',
      );
    });
    test('a pending fixture names the absent packages', () {
      expect(
        outcomeLine(
          CheckSet.surface,
          const Pending(
            'hsdd/contract/fixture/sample/surface/use.dart',
            <String>['sample'],
          ),
        ),
        'PENDING surface hsdd/contract/fixture/sample/surface/use.dart: package sample is absent from .dart_tool/package_config.json',
      );
      expect(
        outcomeLine(
          CheckSet.reject,
          const Pending('hsdd/contract/fixture/sample/reject/a.dart', <String>[
            'alpha',
            'zeta',
          ]),
        ),
        'PENDING reject hsdd/contract/fixture/sample/reject/a.dart: packages alpha, zeta are absent from .dart_tool/package_config.json',
      );
    });
    test('an unavailable set prints its reason', () {
      expect(
        unavailableLine(unavailable),
        'ERROR surface sample: dart analyze exited 64 without a JSON report',
      );
      expect(
        unavailableLine(
          SetUnavailable(
            CheckSet.behavior,
            'sample',
            notImplemented(CheckSet.behavior),
          ),
        ),
        'ERROR behavior sample: this version of nidana_contract_check does not implement the behavior set',
      );
    });
    test('the summary counts passed, failed and pending fixtures', () {
      expect(
        summaryLine(const <SetRun>[passing, failing, pending, unavailable]),
        '4 fixtures: 2 passed, 1 failed, 1 pending',
      );
      expect(
        summaryLine(const <SetRun>[
          SetChecked(CheckSet.structure, 'sample', <FixtureOutcome>[
            Passed('a'),
          ]),
        ]),
        '1 fixture: 1 passed, 0 failed, 0 pending',
      );
      expect(
        summaryLine(const <SetRun>[]),
        '0 fixtures: 0 passed, 0 failed, 0 pending',
      );
    });
  });
  group('exitCodeOf', () {
    test('0 when every fixture passes, and for no run', () {
      expect(exitCodeOf(const <SetRun>[passing]), exitPassed);
      expect(exitCodeOf(const <SetRun>[]), exitPassed);
    });
    test(
      '1 when a fixture fails',
      () => expect(exitCodeOf(const <SetRun>[passing, failing]), exitFailed),
    );
    test('2 when a set is unavailable, failures or not', () {
      expect(
        exitCodeOf(const <SetRun>[passing, failing, unavailable]),
        exitEnvironment,
      );
    });
    test(
      '1 when a fixture is pending, 2 when a set is unavailable as well',
      () {
        expect(exitCodeOf(const <SetRun>[passing, pending]), exitFailed);
        expect(
          exitCodeOf(const <SetRun>[pending, unavailable]),
          exitEnvironment,
        );
      },
    );
    test('the four codes of ADR-001 item 9', () {
      expect(
        <int>[exitPassed, exitFailed, exitEnvironment, exitUsage],
        <int>[0, 1, 2, 64],
      );
    });
  });

  group('admission', () {
    const Set<GuaranteeRef> r = <GuaranteeRef>{
      (slug: 'gen', number: 1),
      (slug: 'gen', number: 3),
      (slug: 'other', number: 2),
    };
    test('an unrestricted replay admits every replay, one that covers nothing included', () {
      expect(admitsAll(null, 'gen', const <int>{}), isTrue);
      expect(admitsAll(null, 'gen', const <int>{1}), isTrue);
    });
    test('a restriction admits a replay only when every id it covers is a restriction id of its slug', () {
      expect(admitsAll(r, 'gen', const <int>{1, 3}), isTrue);
      expect(admitsAll(r, 'gen', const <int>{1}), isTrue);
      expect(admitsAll(r, 'gen', const <int>{1, 2}), isFalse);
      expect(admitsAll(r, 'gen', const <int>{}), isFalse);
      expect(admitsAll(r, 'other', const <int>{1}), isFalse);
    });
    // Beyond the brief: an id of the slug's own admits it under a restriction
    // that also names other slugs, and the empty restriction admits nothing.
    test(
      'the restriction ids of other slugs neither admit nor bar a replay',
      () {
        expect(admitsAll(r, 'other', const <int>{2}), isTrue);
        expect(
          admitsAll(const <GuaranteeRef>{}, 'gen', const <int>{1}),
          isFalse,
        );
      },
    );
    test('the detail of a replay not admitted names its ids, or that it covers none', () {
      expect(
        notAdmitted(const <int>{3, 1}),
        'not run: the restriction does not admit all of G1, G3',
      );
      expect(
        notAdmitted(const <int>{}),
        'not run: it covers no declared guarantee, and the replay is restricted',
      );
    });
    test('file and cli run commands, and no other set does', () {
      expect(
        <CheckSet>[
          for (final CheckSet set in CheckSet.values)
            if (runsCommands(set)) set,
        ],
        <CheckSet>[CheckSet.file, CheckSet.cli],
      );
    });
    test('the reason of a pub get that failed names its exit and the first line of its stderr', () {
      expect(
        pubGetFailure(
          65,
          'Unable to satisfy `pubspec.yaml` using `pubspec.lock`.\n\nTo update ...',
        ),
        'dart pub get --enforce-lockfile exited 65: Unable to satisfy `pubspec.yaml` using `pubspec.lock`.',
      );
      expect(pubGetFailure(1, ''), 'dart pub get --enforce-lockfile exited 1');
      // Beyond the brief: a stderr of blank lines has no first text line.
      expect(
        pubGetFailure(1, ' \r\n\t\n'),
        'dart pub get --enforce-lockfile exited 1',
      );
    });
    test('surface, reject, behavior, file and cli read the package configuration; structure and schema do not', () {
      expect(
        <CheckSet>[
          for (final CheckSet set in CheckSet.values)
            if (readsPackages(set)) set,
        ],
        <CheckSet>[
          CheckSet.surface,
          CheckSet.reject,
          CheckSet.behavior,
          CheckSet.file,
          CheckSet.cli,
        ],
      );
    });
    // Beyond the brief: the configuration a command set reads is the one the
    // pub get before it leaves.
    test('every set that runsCommands also readsPackages', () {
      expect(
        CheckSet.values.where(runsCommands),
        everyElement(predicate<CheckSet>(readsPackages, 'reads packages')),
      );
    });
    test(
      'the first text line is the first line that is not blank, trimmed',
      () {
        expect(firstTextLine('\n  \n  boom  \nnext'), 'boom');
        expect(firstTextLine(' \n'), isNull);
        expect(firstTextLine(''), isNull);
      },
    );
    // Beyond the brief: the line ends a line splitter reads.
    test('a first text line ends at a carriage return, alone or before a line feed', () {
      expect(firstTextLine('\r\n  boom\r\nnext'), 'boom');
      expect(firstTextLine('boom\rnext'), 'boom');
    });
  });
}
