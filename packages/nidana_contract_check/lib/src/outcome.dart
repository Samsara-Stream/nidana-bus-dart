/// What a set concludes about a fixture: it [Passed], it [Failed] with the
/// [Problem]s found, each naming the [Rule] it breaks, or it is [Pending] on
/// packages the workspace lacks. Every set shares these types.
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
  const Passed(super.path, {this.detail});

  /// What the set adds to the fixture's line, after a colon; null for nothing.
  final String? detail;
}

/// The fixture breaks one or more of the set's rules.
final class Failed extends FixtureOutcome {
  const Failed(super.path, this.problems);

  /// What breaks, in the order the set checks it.
  final List<Problem> problems;
}

/// The fixture names a package absent from the workspace's package configuration (ADR-001 item 9).
///
/// A pending fixture fails the replay without being a defect of the fixture:
/// a package it imports is absent from the workspace, so it cannot run.
final class Pending extends FixtureOutcome {
  const Pending(super.path, this.packages);

  /// The absent packages, ascending, at least one.
  final List<String> packages;
}
