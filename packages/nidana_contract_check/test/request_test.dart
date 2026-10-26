// packages/nidana_contract_check/test/request_test.dart
import 'package:nidana_contract_check/src/request.dart';
import 'package:test/test.dart';

const Set<String> slugs = <String>{
  'topic-model',
  'topology-dsl',
  'topology-ir',
  'bus-api',
};

Request parsed(List<String> arguments) {
  final ParseResult r = parseRequest(arguments, slugs: slugs);
  expect(r, isA<ParsedRequest>(), reason: r is UsageError ? r.message : null);
  return (r as ParsedRequest).request;
}

String usageError(List<String> arguments) {
  final ParseResult r = parseRequest(arguments, slugs: slugs);
  expect(r, isA<UsageError>());
  return (r as UsageError).message;
}

void main() {
  test('one slug, every set, unrestricted', () {
    final Request r = parsed(<String>['topic-model']);
    expect(r.slugs, <String>['topic-model']);
    expect(r.sets, isNull);
    expect(r.restriction, isNull);
  });
  test('--all replays every slug in ascending order', () {
    expect(parsed(<String>['--all', '--set', 'structure']).slugs, <String>[
      'bus-api',
      'topic-model',
      'topology-dsl',
      'topology-ir',
    ]);
  });
  test('named slugs keep command order without repeats', () {
    expect(
      parsed(<String>['topology-ir', 'topic-model', 'topology-ir']).slugs,
      <String>['topology-ir', 'topic-model'],
    );
  });
  test('--set takes comma lists, repeats and the = form', () {
    expect(
      parsed(<String>[
        'topic-model',
        '--set',
        'structure,schema',
        '--set=surface',
      ]).sets,
      <CheckSet>{CheckSet.structure, CheckSet.schema, CheckSet.surface},
    );
  });
  test('a bare id belongs to the one slug named', () {
    expect(
      parsed(<String>['topology-dsl', '--guarantee', 'G10,G11']).restriction,
      <GuaranteeRef>{
        (slug: 'topology-dsl', number: 10),
        (slug: 'topology-dsl', number: 11),
      },
    );
  });
  test('a {slug}/G{n} may name a slug the command does not replay', () {
    expect(
      parsed(<String>['bus-api', '--guarantee', 'G3,topology-dsl/G18'])
          .restriction,
      <GuaranteeRef>{
        (slug: 'bus-api', number: 3),
        (slug: 'topology-dsl', number: 18),
      },
    );
    expect(
      parsed(<String>[
        'topic-model',
        'topology-dsl',
        '--guarantee',
        'topology-ir/G2',
      ]).restriction,
      <GuaranteeRef>{(slug: 'topology-ir', number: 2)},
    );
  });
  group('usage errors', () {
    test(
      'no slug and no --all',
      () => expect(usageError(<String>[]), contains('name a slug or --all')),
    );
    test(
      '--all with a slug',
      () => expect(
        usageError(<String>['--all', 'topic-model']),
        contains('--all takes no slug'),
      ),
    );
    test(
      'an unknown slug',
      () => expect(
        usageError(<String>['nosuch']),
        contains("unknown slug 'nosuch'"),
      ),
    );
    test('an unknown or empty set', () {
      expect(
        usageError(<String>['topic-model', '--set', 'surfaces']),
        contains("unknown set 'surfaces'"),
      );
      expect(
        usageError(<String>['topic-model', '--set', '']),
        contains("unknown set ''"),
      );
    });
    test('a malformed id, a space after a comma included', () {
      for (final String id in <String>[
        'G0',
        'g1',
        'G1a',
        ' G2',
        'topic-model/',
        '/G1',
      ]) {
        expect(
          usageError(<String>['topic-model', '--guarantee', id]),
          contains("malformed guarantee id '$id'"),
        );
      }
      expect(
        usageError(<String>['topic-model', '--guarantee', 'G1, G2']),
        contains("malformed guarantee id ' G2'"),
      );
    });
    test('an unknown slug in an id', () {
      expect(
        usageError(<String>['topic-model', '--guarantee', 'nosuch/G1']),
        contains("unknown slug 'nosuch'"),
      );
    });
    test('a bare id with more than one slug', () {
      expect(
        usageError(<String>[
          'topic-model',
          'topology-dsl',
          '--guarantee',
          'G1',
        ]),
        contains("bare id 'G1'"),
      );
      expect(
        usageError(<String>['--all', '--guarantee', 'G1']),
        contains("bare id 'G1'"),
      );
    });
    test('an unknown option or a missing value', () {
      expect(
        usageError(<String>['--frobnicate', 'topic-model']),
        contains('frobnicate'),
      );
      expect(usageError(<String>['topic-model', '--set']), contains('--set'));
    });
  });
}
