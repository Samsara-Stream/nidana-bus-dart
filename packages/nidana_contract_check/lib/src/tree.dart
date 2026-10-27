/// The byte-for-byte comparison of two file trees (ADR-001 item 6; design
/// decision 7): the tree a generator wrote against the `expected/` tree a
/// fixture holds. Reading a tree is the shell's.
library;

import 'dart:math' as math;

import 'command.dart';
import 'outcome.dart';

/// A tree of files: each file's bytes by its `/`-separated path relative to the tree's root.
///
/// Every file below the root is a key, hidden ones included. A directory is
/// no key: the comparison is of files, as git commits no empty directory.
typedef FileTree = Map<String, List<int>>;

/// The problems of [actual] against [expected], byte for byte with the file set included
/// (ADR-001 item 6), by ascending path: `missing-file` ({path}) for a file only [expected] has,
/// `extra-file` ({path}) for one only [actual] has, `changed-file` ({path}: first difference at
/// byte {offset}) for one whose bytes differ, the offset where one ends being a difference.
List<Problem> treeProblems(FileTree expected, FileTree actual) =>
    List<Problem>.unmodifiable(<Problem>[
      for (final String path in <String>{
        ...expected.keys,
        ...actual.keys,
      }.toList()..sort())
        ?_fileProblem(path, expected[path], actual[path]),
    ]);

/// The problem of the file at [path], [expected] and [actual] its bytes in each tree, null where
/// a tree lacks it; null when the two hold the same bytes.
Problem? _fileProblem(String path, List<int>? expected, List<int>? actual) =>
    switch ((expected, actual)) {
      (_, null) => Problem(CommandRule.missingFile, path),
      (null, _) => Problem(CommandRule.extraFile, path),
      (final List<int> inExpected, final List<int> inActual) =>
        switch (_firstDifference(inExpected, inActual)) {
          null => null,
          final int offset => Problem(
            CommandRule.changedFile,
            '$path: first difference at byte $offset',
          ),
        },
    };

/// The offset of the first byte at which [a] and [b] differ, the length of the shorter when one
/// ends first; null when they are equal.
int? _firstDifference(List<int> a, List<int> b) {
  final int shorter = math.min(a.length, b.length);
  return Iterable<int>.generate(shorter)
          .where((int offset) => a[offset] != b[offset])
          .firstOrNull ??
      (a.length == b.length ? null : shorter);
}
