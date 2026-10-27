// packages/nidana_contract_check/test/tree_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/tree.dart';
import 'package:test/test.dart';

/// The problems of [actual] against [expected], each as `{rule} ({detail})`.
List<String> problems(FileTree expected, FileTree actual) => <String>[
  for (final Problem p in treeProblems(expected, actual))
    '${p.rule.label} (${p.detail})',
];

void main() {
  test('equal trees, the empty pair included, give no problem', () {
    expect(
      problems(const <String, List<int>>{}, const <String, List<int>>{}),
      <String>[],
    );
    expect(
      problems(
        const <String, List<int>>{
          'a.txt': <int>[1, 2, 3],
          'sub/b.txt': <int>[],
        },
        const <String, List<int>>{
          'sub/b.txt': <int>[],
          'a.txt': <int>[1, 2, 3],
        },
      ),
      <String>[],
    );
  });
  test(
    'a changed file names its first differing byte, where one ends being one',
    () {
      const FileTree expected = <String, List<int>>{
        'a.txt': <int>[1, 2, 3],
      };
      expect(
        problems(expected, const <String, List<int>>{
          'a.txt': <int>[1, 2, 4],
        }),
        <String>['changed-file (a.txt: first difference at byte 2)'],
      );
      expect(
        problems(expected, const <String, List<int>>{
          'a.txt': <int>[1, 2],
        }),
        <String>['changed-file (a.txt: first difference at byte 2)'],
      );
    },
  );
  test('missing, changed and extra files come by ascending path, hidden ones included', () {
    expect(
      problems(
        const <String, List<int>>{
          '.keep': <int>[0],
          'a': <int>[1],
          'b': <int>[2],
        },
        const <String, List<int>>{
          'b': <int>[3],
          'c': <int>[4],
        },
      ),
      <String>[
        'missing-file (.keep)',
        'missing-file (a)',
        'changed-file (b: first difference at byte 0)',
        'extra-file (c)',
      ],
    );
  });

  // Beyond the brief: the rules the three cases above leave unpinned.
  test('a longer actual file differs where the expected one ends', () {
    expect(
      problems(
        const <String, List<int>>{
          'a.txt': <int>[1, 2],
        },
        const <String, List<int>>{
          'a.txt': <int>[1, 2, 3],
        },
      ),
      <String>['changed-file (a.txt: first difference at byte 2)'],
    );
  });
  test('an empty file against a non-empty one differs at byte 0', () {
    expect(
      problems(
        const <String, List<int>>{'a.txt': <int>[]},
        const <String, List<int>>{
          'a.txt': <int>[7],
        },
      ),
      <String>['changed-file (a.txt: first difference at byte 0)'],
    );
  });
  test('against the empty tree every file is missing, and from it every file is extra', () {
    const FileTree tree = <String, List<int>>{
      'b': <int>[1],
      'a': <int>[2],
    };
    expect(problems(tree, const <String, List<int>>{}), <String>[
      'missing-file (a)',
      'missing-file (b)',
    ]);
    expect(problems(const <String, List<int>>{}, tree), <String>[
      'extra-file (a)',
      'extra-file (b)',
    ]);
  });
  test(
    'nested and hidden paths compare as whole relative paths, ascending',
    () {
      expect(
        problems(
          const <String, List<int>>{
            'lib/.hidden/x.dart': <int>[1],
            'lib/a.dart': <int>[1],
            'lib.txt': <int>[1],
          },
          const <String, List<int>>{
            'lib/a.dart': <int>[1],
            '.dart_tool/x': <int>[1],
            'lib.txt': <int>[2],
          },
        ),
        <String>[
          'extra-file (.dart_tool/x)',
          'changed-file (lib.txt: first difference at byte 0)',
          'missing-file (lib/.hidden/x.dart)',
        ],
      );
    },
  );
}
