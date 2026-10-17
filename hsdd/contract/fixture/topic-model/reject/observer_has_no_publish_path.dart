// Reject fixture for topic-model@v1 G22: nothing an observer receives offers
// a way to publish or to reach a bus (Spec §3.7).
// covers: G22
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class Republisher implements BusObserver {
  @override
  Set<ObserverCapability> get capabilities => const <ObserverCapability>{
        ObserverCapability.observeAll,
      };

  @override
  void onPublish(
    TopicRef topic,
    MessageEnvelope<Object?> envelope,
    ObserveContext context,
  ) {
    // expect-diagnostic: undefined_method
    context.publish(topic, envelope.payload);
    // expect-diagnostic: undefined_getter
    context.bus;
    // expect-diagnostic: undefined_method
    topic.publish(envelope.payload);
    // expect-diagnostic: undefined_method
    envelope.publish();
    // expect-diagnostic: undefined_method
    context.span('republish').publish(envelope);
  }
}
