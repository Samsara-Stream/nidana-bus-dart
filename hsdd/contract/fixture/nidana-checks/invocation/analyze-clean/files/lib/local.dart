/// Not nidana's Bus: a class of the same name in this package.
final class Bus {
  static final Bus instance = Bus();
}

/// Not nidana's EventTopic either.
final class EventTopic<T> {
  const EventTopic({required this.name});
  final String name;
}

const EventTopic<String> local = EventTopic<String>(name: 'local.event');
