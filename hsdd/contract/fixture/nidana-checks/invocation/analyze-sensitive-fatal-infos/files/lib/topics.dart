import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class AccessToken {
  const AccessToken();
}

abstract final class AuthTopics {
  static const EventTopic<AccessToken> issued = EventTopic<AccessToken>(name: 'auth.issued');
}
