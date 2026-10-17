// Stand-in app types for the topic-codegen@v1 fixture (experiment only).
final class AuthState {
  const AuthState.initializing() : signedIn = false;
  const AuthState.signedIn() : signedIn = true;
  final bool signedIn;
}

final class LoginCredentials {
  const LoginCredentials(this.user, this.secret);
  final String user;
  final String secret;
}

final class TokenRefresh {
  const TokenRefresh();
}
