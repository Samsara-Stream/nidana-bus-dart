import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

enum AuthState { signedOut, signedIn }

abstract final class AuthTopics {
  static const StateTopic<AuthState> state = StateTopic<AuthState>(name: 'auth.state', initial: AuthState.signedOut);
}
