import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class AccessToken {
  const AccessToken();
}

abstract final class AuthTopics {
  static const EventTopic<AccessToken> issued = EventTopic<AccessToken>(name: 'auth.issued');
}

final class RefreshToken {
  const RefreshToken();
}

final class ApiCredential {
  const ApiCredential();
}

/// An alias whose own name is known-sensitive.
typedef SessionToken = Map<String, ApiCredential>;

/// Value types that contain more than one known-sensitive type: '{1}' names the
/// first a depth-first search meets (Placeholders).
abstract final class SessionTopics {
  // Type arguments in order: RefreshToken.
  static const EventTopic<Map<RefreshToken, ApiCredential>> grants =
      EventTopic<Map<RefreshToken, ApiCredential>>(name: 'session.grants');
  // A record's positional fields before its named fields: ApiCredential.
  static const EventTopic<(ApiCredential, {RefreshToken refresh})> pair =
      EventTopic<(ApiCredential, {RefreshToken refresh})>(name: 'session.pair');
  // Named fields by name, not as written: ApiCredential, since api sorts before refresh.
  static const EventTopic<({RefreshToken refresh, ApiCredential api})> named =
      EventTopic<({RefreshToken refresh, ApiCredential api})>(name: 'session.named');
  // The alias before the type it names: SessionToken.
  static const EventTopic<SessionToken> session = EventTopic<SessionToken>(name: 'session.current');
}
