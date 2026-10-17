import 'package:rxdart/rxdart.dart';

BehaviorSubject<int> seeded() => BehaviorSubject<int>.seeded(0, sync: true);

/// Stand-in for a contract surface: a state topic has a current value, an
/// event topic does not.
final class StateTopicX<T> {
  const StateTopicX(this.name, this.initial);
  final String name;
  final T initial;
  T currentValue() => initial;
}

final class EventTopicX<T> {
  const EventTopicX(this.name);
  final String name;
}
