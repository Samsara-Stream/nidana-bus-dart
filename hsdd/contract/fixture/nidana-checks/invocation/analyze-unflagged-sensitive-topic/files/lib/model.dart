/// Known-sensitive by name: the suffixes Token, Credential, Credentials and
/// PaymentInfo (Spec §9.2).
final class RefreshToken {
  const RefreshToken();
}

final class ApiCredential {
  const ApiCredential();
}

final class LoginCredentials {
  const LoginCredentials();
}

final class CardPaymentInfo {
  const CardPaymentInfo();
}

/// The app's own marker; any class named Sensitive marks a type (Spec §9.2
/// "types annotated @Sensitive").
final class Sensitive {
  const Sensitive();
}

@Sensitive()
final class UserProfile {
  const UserProfile();
}

final class ThirdPartyUser {
  const ThirdPartyUser();
}

/// A type the app cannot annotate, marked through an alias.
@Sensitive()
typedef AccountHolder = ThirdPartyUser;

/// Not sensitive: no suffix matches, no annotation.
final class TokenRefreshed {
  const TokenRefreshed();
}
