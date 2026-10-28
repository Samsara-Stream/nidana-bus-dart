/// The byte-for-byte comparison of two file trees (ADR-001 item 6; design
/// decision 7): the tree a generator wrote against the `expected/` tree a
/// fixture holds. Reading a tree is the shell's.
library;

import 'dart:math' as math;

import 'command.dart';
import 'outcome.dart';

/// An entry of a [FileTree]: the [FileBytes] of a file the shell read, or [FileUnreadable].
sealed class FileEntry {
  const FileEntry();
}

/// A file read: its [bytes].
final class FileBytes extends FileEntry {
  const FileBytes(this.bytes);

  /// The file's bytes, as read.
  final List<int> bytes;
}

/// An entry the shell found but could not read, as [reason] tells.
final class FileUnreadable extends FileEntry {
  const FileUnreadable(this.reason);

  /// Why the entry could not be read, for a report line.
  final String reason;
}

/// A tree of files: each file's [FileEntry] by its `/`-separated path relative to the tree's
/// root.
///
/// Every file below the root is a key, hidden ones included. A symbolic link
/// that resolves is read through: a link to a file is that file's
/// [FileBytes], and a link to a directory holds the files below it. A
/// directory is no key: the comparison is of files, as git commits no empty
/// directory. The shell records an entry it cannot read, such as a dangling
/// link, a link cycle or a file it may not read, as a [FileUnreadable]
/// rather than throwing or dropping it, so the comparison reports it.
typedef FileTree = Map<String, FileEntry>;

/// The problems of [actual] against [expected], byte for byte with the file set included
/// (ADR-001 item 6), by ascending path: `missing-file` ({path}) for a file only [expected] has,
/// `extra-file` ({path}) for one only [actual] has, `changed-file` ({path}: first difference at
/// byte {offset}) for one whose bytes differ, the offset where one ends being a difference.
///
/// An unreadable entry is an `unreadable-file` ({path} in expected: {reason}) or
/// ({path} in output: {reason}) problem of its side, before any other problem of its path, the
/// expected side first. Its bytes are unknown, so it is never equal to another entry and never a
/// `changed-file`; an entry one side alone holds is missing or extra whether it can be read or
/// not.
List<Problem> treeProblems(FileTree expected, FileTree actual) =>
    List<Problem>.unmodifiable(<Problem>[
      for (final String path in <String>{
        ...expected.keys,
        ...actual.keys,
      }.toList()..sort())
        ..._fileProblems(path, expected[path], actual[path]),
    ]);

/// The problems of the file at [path], [expected] and [actual] its entries in each tree, null
/// where a tree lacks it: the unreadable-file problem of each side, then [_comparison]'s.
List<Problem> _fileProblems(
  String path,
  FileEntry? expected,
  FileEntry? actual,
) => <Problem>[
  if (expected case FileUnreadable(:final String reason))
    _unreadable(path, 'expected', reason),
  if (actual case FileUnreadable(:final String reason))
    _unreadable(path, 'output', reason),
  ?_comparison(path, expected, actual),
];

/// The `missing-file`, `extra-file` or `changed-file` problem of the file at [path]; null when
/// both trees hold the same bytes there, or when both hold an entry there and either cannot be
/// read. An entry one tree alone holds is `missing-file` or `extra-file`, read or not.
Problem? _comparison(String path, FileEntry? expected, FileEntry? actual) =>
    switch ((expected, actual)) {
      (_, null) => Problem(CommandRule.missingFile, path),
      (null, _) => Problem(CommandRule.extraFile, path),
      (
        FileBytes(bytes: final List<int> inExpected),
        FileBytes(bytes: final List<int> inActual),
      ) =>
        switch (_firstDifference(inExpected, inActual)) {
          null => null,
          final int offset => Problem(
            CommandRule.changedFile,
            '$path: first difference at byte $offset',
          ),
        },
      (FileUnreadable(), _) || (_, FileUnreadable()) => null,
    };

/// The `unreadable-file` problem of the entry at [path] on [side], `expected` or `output`.
Problem _unreadable(String path, String side, String reason) =>
    Problem(CommandRule.unreadableFile, '$path in $side: $reason');

/// The offset of the first byte at which [a] and [b] differ, the length of the shorter when one
/// ends first; null when they are equal.
int? _firstDifference(List<int> a, List<int> b) {
  final int shorter = math.min(a.length, b.length);
  return Iterable<int>.generate(shorter)
          .where((int offset) => a[offset] != b[offset])
          .firstOrNull ??
      (a.length == b.length ? null : shorter);
}
