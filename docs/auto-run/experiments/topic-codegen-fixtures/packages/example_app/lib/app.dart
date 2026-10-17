// Uses the generated registry as app code would (experiment only): every
// member keeps the type topic-codegen@v1 states.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

import 'auth/auth.dart';
import 'topics.g.dart';

final StateTopic<AuthState> authState = AuthTopics.state;
final MultiWriterTopic<LoginCredentials> login = AuthTopics.loginEvent;
final List<Topic<Object?>> someTopics = <Topic<Object?>>[
  AuthTopics.state,
  CheckoutTopics.recentOrders,
  SettingsTopics.flags,
  ProfileTopics.avatar,
];
