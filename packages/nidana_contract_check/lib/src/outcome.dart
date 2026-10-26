/// What a set concludes about a fixture: it [Passed], or it [Failed] with the
/// [Problem]s found, each naming the [Rule] it breaks. Every set shares these
/// types.
library;

/// A rule a set checks; each set names its rules with an enum implementing this.
abstract interface class Rule {
  /// The rule's name in a report line, such as `layout`.
  String get label;
}

/// One way a fixture breaks a [rule], told by [detail].
final class Problem {
  const Problem(this.rule, this.detail);

  /// The rule the fixture breaks.
  final Rule rule;

  /// What breaks it, for a report line.
  final String detail;
}

/// What one set concluded about one fixture, named by its path from the workspace root.
sealed class FixtureOutcome {
  const FixtureOutcome(this.path);

  /// The fixture's path from the workspace root, `/`-separated; a directory's
  /// path ends in `/`.
  final String path;
}

/// The fixture breaks none of the set's rules.
final class Passed extends FixtureOutcome {
  const Passed(super.path);
}

/// The fixture breaks one or more of the set's rules.
final class Failed extends FixtureOutcome {
  const Failed(super.path, this.problems);

  /// What breaks, in the order the set checks it.
  final List<Problem> problems;
}
