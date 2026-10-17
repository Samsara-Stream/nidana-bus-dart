import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

import 'model.dart';

/// A registry: every topic is the whole initializer of a static field.
abstract final class SearchTopics {
  static const EventTopic<String> query = EventTopic<String>(name: 'search.query');
  static final StateTopic<SearchResults> results =
      StateTopic<SearchResults>(name: 'search.results', initial: SearchResults.empty);
  static final ReplayTopic<String> history = ReplayTopic<String>(name: 'search.history', bufferSize: 5);
  static final StateTopic<int> clock = StateTopic<int>.computed(name: 'search.clock', initial: _zero);

  /// Sensitive by type, and flagged.
  static final StateTopic<AuthToken> token =
      StateTopic<AuthToken>(name: 'search.token', initial: AuthToken.none, sensitive: true);
}

int _zero() => 0;

/// Not a string literal: the name comes from the caller.
EventTopic<int> counterNamed(String name) => EventTopic<int>(name: name);

/// A sensitive type whose flag is not a literal: the author decided.
StateTopic<AuthToken> tokenTopic(bool flagged) =>
    StateTopic<AuthToken>(name: SearchTopics.token.name, initial: AuthToken.none, sensitive: flagged);
