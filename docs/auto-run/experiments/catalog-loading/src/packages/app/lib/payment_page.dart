// A page library: a widget and its page topology in one file, so the
// topology's library imports Flutter.
import 'package:flutter/widgets.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

abstract final class PaymentTopics {
  static const EventTopic<String> submitted = EventTopic<String>(name: 'payment.submitted');
  static const StateTopic<String> status = StateTopic<String>(name: 'payment.status', initial: 'idle');
}

String statusOf(String submitted) => 'pending:$submitted';

final Topology paymentPageTopology = topology(
  'payment-page',
  Scope.page,
  (b) => b.write(PaymentTopics.status, b.read(PaymentTopics.submitted).map(statusOf)),
);

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
