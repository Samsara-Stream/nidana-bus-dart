/// A token scanner for the Dart the fixture reader needs.
///
/// It is not a Dart lexer. It knows identifiers, strings (with their values),
/// numbers and single-character punctuation, and it skips whitespace and
/// comments, so that nothing inside a comment or a string is ever taken for
/// structure. The tool has no analyzer dependency (ADR-002 item 3), so the
/// fixture reader works over these tokens.
///
/// The scanner is total. It never throws: an unterminated string, comment or
/// interpolation runs to the end of the source.
library;

/// What a [Token] is.
enum TokenKind { identifier, string, punctuation, other }

/// One token of a Dart source.
final class Token {
  const Token(this.kind, this.text, this.line, {this.value});

  /// What this token is.
  final TokenKind kind;

  /// The source text.
  final String text;

  /// The 1-based line of its first character.
  final int line;

  /// A string's value, escapes decoded; null when it interpolates, and for
  /// other kinds.
  final String? value;
}

/// The tokens of [source], in order.
///
/// Spaces, tabs, `\r`, `\n`, `//` comments and nesting `/* */` comments give
/// no token. A string is one token from its opening quote (and its `r`) to
/// its closing quote; the tokens of a `${...}` inside it are not part of the
/// result. An identifier is `[A-Za-z_$][A-Za-z0-9_$]*`, a token starting with
/// a digit runs over `[0-9A-Za-z_.]` and is [TokenKind.other], and every
/// other character is one [TokenKind.punctuation] token, so `>>` is two `>`
/// tokens.
List<Token> scanDart(String source) =>
    List<Token>.unmodifiable(_tokens(source));

/// One step of the scan: where it ends, and the token it gives; [kind] is
/// null for whitespace and comments, [value] as [Token.value].
typedef _Lexeme = ({int end, TokenKind? kind, String? value});

/// The tokens of [source], each with the line counted as the scan passes it.
Iterable<Token> _tokens(String source) sync* {
  int line = 1;
  for (final (int start, _Lexeme lexeme) in _lexemes(source, 0)) {
    if (lexeme.kind case final TokenKind kind) {
      yield Token(
        kind,
        source.substring(start, lexeme.end),
        line,
        value: lexeme.value,
      );
    }
    line += _newlines(source, start, lexeme.end);
  }
}

/// The lexemes of [source] from [start] to its end, each with its start.
Iterable<(int, _Lexeme)> _lexemes(String source, int start) sync* {
  for (int at = start; at < source.length;) {
    final _Lexeme lexeme = _lexeme(source, at);
    yield (at, lexeme);
    at = lexeme.end;
  }
}

/// The lexeme that starts at [start], which is inside [source].
_Lexeme _lexeme(String source, int start) {
  final String? next = start + 1 < source.length ? source[start + 1] : null;
  return switch ((source[start], next)) {
    (' ' || '\t' || '\r' || '\n', _) => _skipped(start + 1),
    ('/', '/') => _skipped(_lineEnd(source, start)),
    ('/', '*') => _skipped(_blockCommentEnd(source, start + 2)),
    ('r', "'" || '"') => _string(source, start + 1, raw: true),
    ("'" || '"', _) => _string(source, start, raw: false),
    _ =>
      _matched(_identifier, TokenKind.identifier, source, start) ??
          _matched(_number, TokenKind.other, source, start) ??
          (end: start + 1, kind: TokenKind.punctuation, value: null),
  };
}

final RegExp _identifier = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');
final RegExp _number = RegExp(r'[0-9][0-9A-Za-z_.]*');

/// The first character of the name in a `$name` interpolation.
final RegExp _interpolatedName = RegExp(r'[A-Za-z_]');

/// A lexeme that gives no token and ends at [end].
_Lexeme _skipped(int end) => (end: end, kind: null, value: null);

/// A [kind] token where [pattern] matches at [start]; null when it does not.
_Lexeme? _matched(RegExp pattern, TokenKind kind, String source, int start) =>
    switch (pattern.matchAsPrefix(source, start)) {
      final Match match => (end: match.end, kind: kind, value: null),
      null => null,
    };

/// The offset of the `\n` that ends the line holding [start], or the end of
/// [source].
int _lineEnd(String source, int start) {
  final int newline = source.indexOf('\n', start);
  return newline < 0 ? source.length : newline;
}

/// The offset after the `*/` that closes a block comment whose body starts
/// at [start], counting nested `/*`; the end of [source] when none does.
int _blockCommentEnd(String source, int start) {
  int depth = 1;
  for (int at = start; at < source.length;) {
    if (source.startsWith('*/', at)) {
      depth -= 1;
      at += 2;
      if (depth == 0) {
        return at;
      }
    } else if (source.startsWith('/*', at)) {
      depth += 1;
      at += 2;
    } else {
      at += 1;
    }
  }
  return source.length;
}

/// The string whose opening quote sequence is at [quote]: `'`, `"`, `'''` or
/// `"""`. It ends after the same sequence, or at the end of [source].
///
/// In a non-raw string a backslash takes the next character (`n`, `t` and
/// `r` decode to newline, tab and carriage return; any other character
/// stands for itself), and `$name` or `${...}` makes the string interpolated.
_Lexeme _string(String source, int quote, {required bool raw}) {
  final String mark = source[quote];
  final String delimiter = source.startsWith(mark * 3, quote) ? mark * 3 : mark;
  final StringBuffer value = StringBuffer();
  bool interpolated = false;
  int at = quote + delimiter.length;
  while (at < source.length && !source.startsWith(delimiter, at)) {
    final String character = source[at];
    final String? next = at + 1 < source.length ? source[at + 1] : null;
    if (raw || next == null) {
      value.write(character);
      at += 1;
    } else if (character == r'\') {
      value.write(_escaped(next));
      at += 2;
    } else if (character == r'$' && next == '{') {
      interpolated = true;
      at = _interpolationEnd(source, at + 2);
    } else if (character == r'$' && _interpolatedName.hasMatch(next)) {
      interpolated = true;
      at += 1;
    } else {
      value.write(character);
      at += 1;
    }
  }
  return (
    end: at < source.length ? at + delimiter.length : source.length,
    kind: TokenKind.string,
    value: interpolated ? null : value.toString(),
  );
}

/// The character an escape `\` followed by [character] stands for.
String _escaped(String character) => switch (character) {
  'n' => '\n',
  't' => '\t',
  'r' => '\r',
  _ => character,
};

/// The offset after the `}` that closes a `${` whose expression starts at
/// [start], scanning nested strings and comments as lexemes; the end of
/// [source] when none does.
int _interpolationEnd(String source, int start) {
  int depth = 1;
  for (final (int at, _Lexeme lexeme) in _lexemes(source, start)) {
    if (lexeme.kind == TokenKind.punctuation) {
      depth += switch (source[at]) {
        '{' => 1,
        '}' => -1,
        _ => 0,
      };
      if (depth == 0) {
        return lexeme.end;
      }
    }
  }
  return source.length;
}

/// The number of `\n` characters in [source] from [start] to [end].
int _newlines(String source, int start, int end) => source.codeUnits
    .getRange(start, end)
    .where((int unit) => unit == _newline)
    .length;

/// The code unit of `\n`.
const int _newline = 0x0A;
