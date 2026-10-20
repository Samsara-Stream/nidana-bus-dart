// runtime-topic-storage probe P5: an add to a synchronous broadcast
// controller made while that controller delivers. The bus-owned fan-out of
// nidana.runtime D3 is such a controller; root D9 recorded the same error
// for a sync: true RxDart subject (docs/auto-run/experiments/rxdart-sync-
// subjects/). SDK only: fvm dart run probe/broadcast_reentrant.dart
import 'dart:async';

void main() {
  final StreamController<int> c = StreamController<int>.broadcast(sync: true);
  final List<String> log = <String>[];
  c.stream.listen((int v) {
    log.add('a got $v');
    if (v == 1) {
      try {
        c.add(2);
        log.add('reentrant add(2) returned');
      } catch (e) {
        log.add('reentrant add(2) threw ${e.runtimeType}: $e');
      }
    }
  });
  c.stream.listen((int v) => log.add('b got $v'));
  c.add(1);
  log.add('add(1) returned');
  // Deferred, as bus-api@v2 G14 has the bus defer a reentrant publish.
  scheduleMicrotask(() {
    c.add(3);
    log.add('add(3) from a microtask returned');
    log.forEach(print);
  });
}
