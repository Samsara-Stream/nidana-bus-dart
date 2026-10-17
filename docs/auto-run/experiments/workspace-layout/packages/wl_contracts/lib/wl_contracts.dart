import 'package:meta/meta.dart';

@immutable
final class TopicName {
  const TopicName(this.value);
  final String value;
}

/// A pure analysis, the kind the lint package would want to reuse.
bool isDomainEntity(TopicName name) => name.value.split('.').length == 2;
