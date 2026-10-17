import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

import 'model.dart';

abstract final class AuthTopics {
  // Reported: each carries a known-sensitive type and no flag.
  static const StateTopic<RefreshToken> refresh =
      StateTopic<RefreshToken>(name: 'auth.refresh', initial: RefreshToken());
  static const EventTopic<LoginCredentials> login = EventTopic<LoginCredentials>(name: 'auth.login');
  static const ReplayTopic<CardPaymentInfo> cards = ReplayTopic<CardPaymentInfo>(name: 'auth.cards', bufferSize: 2);
  static const StateTopic<UserProfile> profile =
      StateTopic<UserProfile>(name: 'auth.profile', initial: UserProfile(), sensitive: false);
  static const EventTopic<AccountHolder> holder = EventTopic<AccountHolder>(name: 'auth.holder');
  // Reported: a known-sensitive type nested in the value type.
  static const EventTopic<List<ApiCredential>> keys = EventTopic<List<ApiCredential>>(name: 'auth.keys');
  static const EventTopic<(String, RefreshToken?)> pair = EventTopic<(String, RefreshToken?)>(name: 'auth.pair');

  // Accepted: flagged.
  static const StateTopic<RefreshToken> session =
      StateTopic<RefreshToken>(name: 'auth.session', initial: RefreshToken(), sensitive: true);
  // Accepted: no known-sensitive type.
  static const EventTopic<TokenRefreshed> refreshed = EventTopic<TokenRefreshed>(name: 'auth.refreshed');
}
