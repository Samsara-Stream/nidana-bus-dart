/// Stand-in for a contract surface declared by a pure producer package.
library;

import 'package:meta/meta.dart';

/// A state topic carries a current value.
final class StateTopic<T> {
  const StateTopic(this.name, this.initial);
  final String name;
  final T initial;
}

/// An event topic carries no current value (stand-in for Spec §2.5).
final class EventTopic<T> {
  const EventTopic(this.name);
  final String name;
}

/// An interface declared here and implemented elsewhere (stand-in for the
/// navigation executor protocol).
abstract interface class Executor {
  String get current;
  Future<void> go(String route);
}

/// The pure implementation this package ships.
final class InMemoryExecutor implements Executor {
  String _current = '/';

  @override
  String get current => _current;

  @override
  Future<void> go(String route) async => _current = route;

  @visibleForTesting
  void reset() => _current = '/';
}

@Deprecated('use Executor.go')
void legacyGo() {}
