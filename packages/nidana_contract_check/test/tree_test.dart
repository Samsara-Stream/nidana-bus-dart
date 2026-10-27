// packages/nidana_contract_check/test/tree_test.dart
import 'package:nidana_contract_check/src/outcome.dart';
import 'package:nidana_contract_check/src/tree.dart';
import 'package:test/test.dart';

import 'support/generator.dart';

/// The problems of [actual] against [expected], each as `{rule} ({detail})`.
List<String> problems(FileTree expected, FileTree actual) => <String>[
  for (final Problem p in treeProblems(expected, actual))
    '${p.rule.label} (${p.detail})',
];

/// The empty tree.
final FileTree empty = treeOf(const <String, List<int>>{});

void main() {
  test('equal trees, the empty pair included, give no problem', () {
    expect(problems(empty, empty), <String>[]);
    expect(
      problems(
        treeOf(const <String, List<int>>{
          'a.txt': <int>[1, 2, 3],
          'sub/b.txt': <int>[],
        }),
        treeOf(const <String, List<int>>{
          'sub/b.txt': <int>[],
          'a.txt': <int>[1, 2, 3],
        }),
      ),
      <String>[],
    );
  });
  test(
    'a changed file names its first differing byte, where one ends being one',
    () {
      final FileTree expected = treeOf(const <String, List<int>>{
        'a.txt': <int>[1, 2, 3],
      });
      expect(
        problems(
          expected,
          treeOf(const <String, List<int>>{
            'a.txt': <int>[1, 2, 4],
          }),
        ),
        <String>['changed-file (a.txt: first difference at byte 2)'],
      );
      expect(
        problems(
          expected,
          treeOf(const <String, List<int>>{
            'a.txt': <int>[1, 2],
          }),
        ),
        <String>['changed-file (a.txt: first difference at byte 2)'],
      );
    },
  );
  test('missing, changed and extra files come by ascending path, hidden ones included', () {
    expect(
      problems(
        treeOf(const <String, List<int>>{
          '.keep': <int>[0],
          'a': <int>[1],
          'b': <int>[2],
        }),
        treeOf(const <String, List<int>>{
          'b': <int>[3],
          'c': <int>[4],
        }),
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
        treeOf(const <String, List<int>>{
          'a.txt': <int>[1, 2],
        }),
        treeOf(const <String, List<int>>{
          'a.txt': <int>[1, 2, 3],
        }),
      ),
      <String>['changed-file (a.txt: first difference at byte 2)'],
    );
  });
  test('an empty file against a non-empty one differs at byte 0', () {
    expect(
      problems(
        treeOf(const <String, List<int>>{'a.txt': <int>[]}),
        treeOf(const <String, List<int>>{
          'a.txt': <int>[7],
        }),
      ),
      <String>['changed-file (a.txt: first difference at byte 0)'],
    );
  });
  test('against the empty tree every file is missing, and from it every file is extra', () {
    final FileTree tree = treeOf(const <String, List<int>>{
      'b': <int>[1],
      'a': <int>[2],
    });
    expect(problems(tree, empty), <String>[
      'missing-file (a)',
      'missing-file (b)',
    ]);
    expect(problems(empty, tree), <String>['extra-file (a)', 'extra-file (b)']);
  });
  test(
    'nested and hidden paths compare as whole relative paths, ascending',
    () {
      expect(
        problems(
          treeOf(const <String, List<int>>{
            'lib/.hidden/x.dart': <int>[1],
            'lib/a.dart': <int>[1],
            'lib.txt': <int>[1],
          }),
          treeOf(const <String, List<int>>{
            'lib/a.dart': <int>[1],
            '.dart_tool/x': <int>[1],
            'lib.txt': <int>[2],
          }),
        ),
        <String>[
          'extra-file (.dart_tool/x)',
          'changed-file (lib.txt: first difference at byte 0)',
          'missing-file (lib/.hidden/x.dart)',
        ],
      );
    },
  );

  // The controller's ruling on Task 3: an entry the shell cannot read is a
  // FileUnreadable, and the comparison reports it as its own problem.
  group('an unreadable entry', () {
    test('on the output side is an unreadable-file problem of the output', () {
      expect(
        problems(
          treeOf(const <String, List<int>>{
            'notes.txt': <int>[1],
          }),
          const <String, FileEntry>{
            'notes.txt': FileUnreadable('a dangling link'),
          },
        ),
        <String>['unreadable-file (notes.txt in output: a dangling link)'],
      );
    });
    test('on the expected side is an unreadable-file problem of expected', () {
      expect(
        problems(
          const <String, FileEntry>{
            'notes.txt': FileUnreadable('Permission denied'),
          },
          treeOf(const <String, List<int>>{
            'notes.txt': <int>[1],
          }),
        ),
        <String>['unreadable-file (notes.txt in expected: Permission denied)'],
      );
    });
    test(
      'on both sides is never equal: one problem per side, expected first',
      () {
        const FileTree unreadable = <String, FileEntry>{
          'notes.txt': FileUnreadable('a link cycle'),
        };
        expect(problems(unreadable, unreadable), <String>[
          'unreadable-file (notes.txt in expected: a link cycle)',
          'unreadable-file (notes.txt in output: a link cycle)',
        ]);
      },
    );
    test('beside byte differences comes in path order', () {
      expect(
        problems(
          const <String, FileEntry>{
            'a.txt': FileBytes(<int>[1, 2]),
            'b.txt': FileUnreadable('Permission denied'),
            'c.txt': FileBytes(<int>[1]),
          },
          const <String, FileEntry>{
            'a.txt': FileUnreadable('a dangling link'),
            'b.txt': FileBytes(<int>[1, 2]),
            'c.txt': FileBytes(<int>[2]),
            '.d': FileBytes(<int>[]),
          },
        ),
        <String>[
          'extra-file (.d)',
          'unreadable-file (a.txt in output: a dangling link)',
          'unreadable-file (b.txt in expected: Permission denied)',
          'changed-file (c.txt: first difference at byte 0)',
        ],
      );
    });

    // Beyond the ruling: presence is known even when the bytes are not, so
    // an entry one side alone holds is missing or extra as well.
    test('on one side only is also missing or extra, after its unreadable-file problem', () {
      const FileTree unreadable = <String, FileEntry>{
        'notes.txt': FileUnreadable('a dangling link'),
      };
      expect(problems(unreadable, empty), <String>[
        'unreadable-file (notes.txt in expected: a dangling link)',
        'missing-file (notes.txt)',
      ]);
      expect(problems(empty, unreadable), <String>[
        'unreadable-file (notes.txt in output: a dangling link)',
        'extra-file (notes.txt)',
      ]);
    });
  });
}
