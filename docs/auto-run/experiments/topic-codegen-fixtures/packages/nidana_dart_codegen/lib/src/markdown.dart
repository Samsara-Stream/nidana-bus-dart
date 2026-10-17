// Text transforms the stand-in generator applies to Markdown it writes
// (doc comments and topics.md), as topic-codegen@v1 states them.

/// Backslash-escapes every `<` and `>` that is outside a code span and not
/// already escaped, so author text never reads as HTML.
String escapeAngles(String text) {
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (c == r'\' && i + 1 < text.length) {
      out.write(text.substring(i, i + 2));
      i += 2;
      continue;
    }
    if (c == '`') {
      var n = 0;
      while (i + n < text.length && text[i + n] == '`') {
        n++;
      }
      final fence = '`' * n;
      final close = _closingRun(text, i + n, n);
      if (close >= 0) {
        out.write(text.substring(i, close + n));
        i = close + n;
      } else {
        out.write(fence);
        i += n;
      }
      continue;
    }
    if (c == '<' || c == '>') {
      out.write('\\$c');
    } else {
      out.write(c);
    }
    i++;
  }
  return out.toString();
}

/// The index of the next run of exactly [n] backticks at or after [from].
int _closingRun(String text, int from, int n) {
  var i = from;
  while (i < text.length) {
    if (text[i] != '`') {
      i++;
      continue;
    }
    var m = 0;
    while (i + m < text.length && text[i + m] == '`') {
      m++;
    }
    if (m == n) return i;
    i += m;
  }
  return -1;
}

/// [text] as one code span: line breaks become spaces; the fence is one
/// backtick longer than the longest backtick run in the text; one space pads
/// each side when the text begins or ends with a backtick, or begins and
/// ends with a space.
String codeSpan(String text) {
  final t = text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
  var longest = 0;
  var run = 0;
  for (var i = 0; i < t.length; i++) {
    run = t[i] == '`' ? run + 1 : 0;
    if (run > longest) longest = run;
  }
  final fence = '`' * (longest + 1);
  final pad = t.startsWith('`') ||
          t.endsWith('`') ||
          (t.length > 1 && t.startsWith(' ') && t.endsWith(' '))
      ? ' '
      : '';
  return '$fence$pad$t$pad$fence';
}

/// A table cell: every `|` written `\|`, line breaks as spaces.
String cell(String text) => text
    .replaceAll('\r\n', ' ')
    .replaceAll('\n', ' ')
    .replaceAll('\r', ' ')
    .replaceAll('|', r'\|');

/// The lines of a description: trailing white space removed from the whole
/// text and from every line.
List<String> descriptionLines(String description) => description
    .trimRight()
    .split('\n')
    .map((l) => l.trimRight())
    .toList();
