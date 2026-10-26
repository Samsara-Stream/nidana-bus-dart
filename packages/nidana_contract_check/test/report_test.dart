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
const SetUnavailable unavailable = SetUnavailable(CheckSet.surface, 'sample');

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
    test('an unavailable set', () {
      expect(
        unavailableLine(unavailable),
        'ERROR surface sample: this version of nidana_contract_check does not implement the surface set',
      );
    });
    test('the summary counts fixtures', () {
      expect(
        summaryLine(const <SetRun>[passing, failing, unavailable]),
        '3 fixtures: 2 passed, 1 failed',
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
    test('the four codes of ADR-001 item 9', () {
      expect(
        <int>[exitPassed, exitFailed, exitEnvironment, exitUsage],
        <int>[0, 1, 2, 64],
      );
    });
  });
}
