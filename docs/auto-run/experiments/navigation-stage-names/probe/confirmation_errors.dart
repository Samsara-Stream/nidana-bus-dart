// S3: what an error event on a router's confirmations does to a listener
// that, like the stand-in executor, passes onData only. The stream is a
// synchronous broadcast controller, as InMemoryRouter's is. The listener
// subscribes inside a guarded zone standing in for the zone the executor's
// constructor runs in.
import 'dart:async';

void main() {
  final StreamController<int> confirmations =
      StreamController<int>.broadcast(sync: true);
  final List<int> got = <int>[];
  final List<Object> uncaught = <Object>[];
  runZonedGuarded(() {
    confirmations.stream.listen(got.add);
  }, (Object error, StackTrace _) => uncaught.add(error));
  confirmations.add(1);
  confirmations.addError(StateError('router defect'));
  confirmations.add(2);
  print('data received: $got');
  print('errors at the listening zone\'s handler: $uncaught');
  print('subscription kept receiving after the error: ${got.contains(2)}');
}
