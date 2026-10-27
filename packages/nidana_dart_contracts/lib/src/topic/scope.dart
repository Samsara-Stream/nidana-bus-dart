/// A topology's lifetime (Spec §7.1). Topics have no scope.
enum Scope {
  application,
  module,
  page;

  /// Whether this scope lives at least as long as [other]: the order
  /// application, module, page, reflexive (Spec §7.2).
  bool isAtLeastAsLongAs(Scope other) => index <= other.index;
}
