import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class CheckoutDraft {
  const CheckoutDraft();
}

final class SessionState {
  const SessionState();
}

abstract final class CheckoutTopics {
  static const StateTopic<CheckoutDraft> draft =
      StateTopic<CheckoutDraft>(name: 'checkout.draft', initial: CheckoutDraft());
}

abstract final class SessionTopics {
  static const StateTopic<SessionState> state = StateTopic<SessionState>(name: 'session.state', initial: SessionState());
}
