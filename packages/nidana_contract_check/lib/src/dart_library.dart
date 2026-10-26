/// The fixture reader: the directives, the `// covers:` headers, the
/// `// expect-diagnostic:` markers and the conformance case lists of one Dart
/// fixture library, read as values.
///
/// Directives and case lists are read over [scanDart]'s tokens, so nothing
/// inside a comment or a string is taken for structure. Headers and markers
/// are comment lines, read from the lines of the source. The reader is
/// total: it never throws, and it keeps a malformed form as a value for the
/// `structure` set to judge.
library;

import 'dart_scanner.dart';
import 'ids.dart';

/// A `// covers: ` line of a library's leading comment block.
final class CoversHeader {
  const CoversHeader(this.line, this.text, this.ids);

  /// The 1-based line.
  final int line;

  /// The text after `// covers: `, trailing space trimmed.
  final String text;

  /// The numbers of [text]; null when [text] is not an `{ids}` list.
  final Set<int>? ids;
}

/// A line that mentions `expect-diagnostic`.
final class Marker {
  const Marker({
    required this.line,
    required this.code,
    required this.followedByCode,
  });

  /// The 1-based line.
  final int line;

  /// The diagnostic code; null when the line is not exactly
  /// `// expect-diagnostic: {code}`.
  final String? code;

  /// Whether a next line exists, is not blank and is not a `//` comment.
  final bool followedByCode;
}

/// The `name` field of one case: the line of its `name` token, and the
/// name; [name] null when the field is not a string literal.
typedef CaseName = ({int line, String? name});

/// A public top-level `List<ConformanceCase<...>>` declaration.
final class CaseList {
  const CaseList({
    required this.name,
    required this.cases,
    required this.problems,
  });

  /// The declared name.
  final String name;

  /// The name field of each record element that has one, in order.
  final List<CaseName> cases;

  /// The elements that are not record literals and the records without a
  /// name field, as messages in source order.
  final List<String> problems;
}

/// What [readDartLibrary] reads from one Dart fixture library.
final class DartLibrary {
  const DartLibrary({
    required this.directives,
    required this.coversHeaders,
    required this.markers,
    required this.caseLists,
  });

  /// The URIs of the import and export directives, in order.
  final List<String> directives;

  /// The `// covers:` lines of the leading comment block.
  final List<CoversHeader> coversHeaders;

  /// Every line that mentions `expect-diagnostic`.
  final List<Marker> markers;

  /// The public top-level `List<ConformanceCase<...>>` declarations.
  final List<CaseList> caseLists;
}

/// Reads [source], one Dart fixture library, as a [DartLibrary].
///
/// `\r\n` reads as `\n`.
DartLibrary readDartLibrary(String source) {
  final String text = source.replaceAll('\r\n', '\n');
  final List<String> lines = text.split('\n');
  final List<Token> tokens = scanDart(text);
  return DartLibrary(
    directives: List<String>.unmodifiable(_directives(tokens)),
    coversHeaders: List<CoversHeader>.unmodifiable(_coversHeaders(lines)),
    markers: List<Marker>.unmodifiable(_markers(lines)),
    caseLists: List<CaseList>.unmodifiable(_caseLists(tokens)),
  );
}

final RegExp _blankOrComment = RegExp(r'^\s*(//|$)');
final RegExp _coversHeader = RegExp(r'^// covers: (.*)$');
final RegExp _marker = RegExp(
  r'^\s*// expect-diagnostic: ([a-z][a-z0-9_]*)\s*$',
);

/// The value of each string that directly follows an `import` or `export`
/// identifier at bracket depth 0.
Iterable<String> _directives(List<Token> tokens) => tokens
    .level(0, tokens.length)
    .where(
      (int at) =>
          tokens.identifierAt(at, 'import') ||
          tokens.identifierAt(at, 'export'),
    )
    .map((int at) => tokens.stringValueAt(at + 1))
    .nonNulls;

/// The `// covers: ` lines of the leading block: the lines from the top
/// while each is blank or, after leading spaces, begins with `//`.
Iterable<CoversHeader> _coversHeaders(List<String> lines) sync* {
  for (final (int index, String line) in lines.indexed.takeWhile(
    ((int, String) entry) => _blankOrComment.hasMatch(entry.$2),
  )) {
    if (_coversHeader.firstMatch(line) case final RegExpMatch match) {
      final String text = match.group(1)!.trimRight();
      yield CoversHeader(index + 1, text, _unmodifiable(parseIdList(text)));
    }
  }
}

/// A [Marker] for each line that contains `expect-diagnostic`.
Iterable<Marker> _markers(List<String> lines) sync* {
  for (final (int index, String line) in lines.indexed) {
    if (line.contains('expect-diagnostic')) {
      yield Marker(
        line: index + 1,
        code: _marker.firstMatch(line)?.group(1),
        followedByCode:
            index + 1 < lines.length &&
            !_blankOrComment.hasMatch(lines[index + 1]),
      );
    }
  }
}

/// A case-list declaration: its name, and the index of the first token after
/// its `=`.
typedef _Declaration = ({String name, int initializer});

/// The public case-list declarations at bracket depth 0, in order.
///
/// A declaration with the declared type that is initialized by the typed
/// literal matches both forms, at different tokens; the set keeps it once.
Iterable<CaseList> _caseLists(List<Token> tokens) {
  final Set<_Declaration> declarations = <_Declaration>{
    for (final int at in tokens.level(0, tokens.length))
      ?_declaredTypeAt(tokens, at) ?? _typedLiteralAt(tokens, at),
  };
  return declarations
      .where((_Declaration declaration) => !declaration.name.startsWith('_'))
      .map((_Declaration declaration) => _caseList(tokens, declaration));
}

/// The declaration `List<ConformanceCase ...> NAME =` that starts at [at];
/// the type's angle group ends at its matching `>`.
_Declaration? _declaredTypeAt(List<Token> tokens, int at) {
  if (!tokens.identifierAt(at, 'List') ||
      !tokens.punctuationAt(at + 1, '<') ||
      !tokens.identifierAt(at + 2, 'ConformanceCase')) {
    return null;
  }
  final int name = tokens.angleClosing(at + 1) + 1;
  return tokens.identifierAt(name) && tokens.punctuationAt(name + 1, '=')
      ? (name: tokens[name].text, initializer: name + 2)
      : null;
}

/// The declaration `NAME = <ConformanceCase` that starts at [at].
_Declaration? _typedLiteralAt(List<Token> tokens, int at) =>
    tokens.identifierAt(at) &&
        tokens.punctuationAt(at + 1, '=') &&
        tokens.punctuationAt(at + 2, '<') &&
        tokens.identifierAt(at + 3, 'ConformanceCase')
    ? (name: tokens[at].text, initializer: at + 2)
    : null;

/// The case list of [declaration]: after its `=`, an optional angle group
/// and then a list literal whose elements are records.
CaseList _caseList(List<Token> tokens, _Declaration declaration) {
  final (:String name, :int initializer) = declaration;
  final int open = tokens.punctuationAt(initializer, '<')
      ? tokens.angleClosing(initializer) + 1
      : initializer;
  if (!tokens.punctuationAt(open, '[')) {
    return CaseList(
      name: name,
      cases: const <CaseName>[],
      problems: List<String>.unmodifiable(<String>[
        '$name is not initialized by a list literal',
      ]),
    );
  }
  final List<_Element> elements = tokens
      .items(open + 1, tokens.closing(open))
      .map(((int, int) item) => _element(tokens, name, item.$1, item.$2))
      .toList(growable: false);
  return CaseList(
    name: name,
    cases: List<CaseName>.unmodifiable(
      elements.whereType<_Case>().map((_Case element) => element.value),
    ),
    problems: List<String>.unmodifiable(
      elements.whereType<_Problem>().map((_Problem element) => element.text),
    ),
  );
}

/// What one element of a case list reads as.
sealed class _Element {
  const _Element();
}

/// A record element with a name field.
final class _Case extends _Element {
  const _Case(this.value);

  final CaseName value;
}

/// An element that is not a record literal, or a record without a name field.
final class _Problem extends _Element {
  const _Problem(this.text);

  final String text;
}

/// The element of the list [list] from [start] to [end]: an optional `const`
/// and a record literal `( ... )`, whose name field is read at the record's
/// own depth only.
_Element _element(List<Token> tokens, String list, int start, int end) {
  final int open = tokens.identifierAt(start, 'const') ? start + 1 : start;
  if (!tokens.punctuationAt(open, '(') || tokens.closing(open) != end - 1) {
    return _Problem(
      'line ${tokens[start].line}: an element of $list is not a record literal',
    );
  }
  final (int, int)? field = tokens
      .items(open + 1, end - 1)
      .where(
        ((int, int) item) =>
            tokens.identifierAt(item.$1, 'name') &&
            tokens.punctuationAt(item.$1 + 1, ':'),
      )
      .firstOrNull;
  return switch (field) {
    (final int name, final int fieldEnd) => _Case((
      line: tokens[name].line,
      name: _stringLiteral(tokens.sublist(name + 2, fieldEnd)),
    )),
    null => _Problem(
      'line ${tokens[open].line}: a record of $list has no name field',
    ),
  };
}

/// The joined values of [expression] when it is one or more string tokens,
/// none interpolated; null for any other expression.
String? _stringLiteral(List<Token> expression) =>
    expression.isNotEmpty &&
        expression.every(
          (Token token) =>
              token.kind == TokenKind.string && token.value != null,
        )
    ? expression.map((Token token) => token.value!).join()
    : null;

/// [ids] as a set nothing can change; null stays null.
Set<int>? _unmodifiable(Set<int>? ids) =>
    ids == null ? null : Set<int>.unmodifiable(ids);

const Set<String> _openingBrackets = <String>{'(', '[', '{'};
const Set<String> _closingBrackets = <String>{')', ']', '}'};

/// Reading a token list by position. An index past the end reads as no
/// token, and a group that never closes runs to the end of the list.
extension _Tokens on List<Token> {
  /// Whether the token at [at] is the punctuation [text].
  bool punctuationAt(int at, String text) =>
      at < length &&
      this[at].kind == TokenKind.punctuation &&
      this[at].text == text;

  /// Whether the token at [at] is an identifier, [text] when given.
  bool identifierAt(int at, [String? text]) =>
      at < length &&
      this[at].kind == TokenKind.identifier &&
      (text == null || this[at].text == text);

  /// The value of the string token at [at]; null when there is none, or when
  /// it interpolates.
  String? stringValueAt(int at) =>
      at < length && this[at].kind == TokenKind.string ? this[at].value : null;

  /// The index of the bracket that closes the `(`, `[` or `{` at [open],
  /// counting those three brackets only; [length] when none does.
  int closing(int open) {
    int depth = 0;
    for (int at = open; at < length; at += 1) {
      depth += _depthChange(this[at]);
      if (depth == 0) {
        return at;
      }
    }
    return length;
  }

  /// The index of the `>` that closes the `<` at [open], counting `<` and `>`
  /// tokens only; [length] when none does.
  int angleClosing(int open) {
    int depth = 0;
    for (int at = open; at < length; at += 1) {
      depth += punctuationAt(at, '<')
          ? 1
          : punctuationAt(at, '>')
          ? -1
          : 0;
      if (depth == 0) {
        return at;
      }
    }
    return length;
  }

  /// The indices from [start] to [end] at the depth of [start]: a bracket
  /// group is one step, at its opening bracket.
  Iterable<int> level(int start, int end) sync* {
    for (int at = start; at < end;) {
      yield at;
      at = _depthChange(this[at]) > 0 ? closing(at) + 1 : at + 1;
    }
  }

  /// The non-empty items from [start] to [end] separated by `,` at the depth
  /// of [start], each as its start and end index.
  List<(int, int)> items(int start, int end) {
    // The separating commas, with a virtual one just before [start] and one
    // at [end].
    final List<int> bounds = <int>[
      start - 1,
      for (final int at in level(start, end))
        if (punctuationAt(at, ',')) at,
      end,
    ];
    return <(int, int)>[
      for (int i = 1; i < bounds.length; i += 1)
        if (bounds[i] > bounds[i - 1] + 1) (bounds[i - 1] + 1, bounds[i]),
    ];
  }
}

/// How [token] changes the bracket depth.
int _depthChange(Token token) => token.kind != TokenKind.punctuation
    ? 0
    : _openingBrackets.contains(token.text)
    ? 1
    : _closingBrackets.contains(token.text)
    ? -1
    : 0;
