// P2: which description renderings trip unintended_html_in_doc_comment.
abstract final class D {
  /// Plain: emits List<int> values.
  static final int plain = 1;

  /// Code span: emits `List<int>` values.
  static final int codeSpan = 2;

  /// Escaped: emits List\<int\> values.
  static final int escaped = 3;

  /// Comparison: fires when a < b and b > c.
  static final int comparison = 4;

  /// Link-like: see [Unresolved] and <https://example.com>.
  static final int linkLike = 5;
}
