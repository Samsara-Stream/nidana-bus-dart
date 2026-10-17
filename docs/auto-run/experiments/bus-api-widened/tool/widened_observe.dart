// Side finding of S14 (not a flutter-binding@v1 fixture): on the stand-in
// runtime of ../bus-api-amendment/, a topic first reached through a
// Topic<Object?>-typed reference, as generic code holds it, gets a subject
// typed by that static type, and mixing it with typed access fails either way.
// bus-api@v1's fixtures always reach a topic at its declared type. Run from
// the experiment root: fvm dart run tool/widened_observe.dart
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';
import 'package:nidana_dart_runtime/nidana_dart_runtime.dart';

const StateTopic<int> count = StateTopic<int>(name: 'probe.count', initial: 0);

void observeAny(Bus bus, Topic<Object?> topic) => bus.observe(topic).listen((Object? _) {});

void attempt(String label, void Function() body) {
  try {
    body();
    print('$label: ok');
  } on TypeError catch (e) {
    print('$label: TypeError: $e');
  }
}

void main() {
  final Bus typedFirst = Bus();
  attempt('typed read, then widened observe', () {
    typedFirst.getCurrentValue(count);
    observeAny(typedFirst, count);
  });
  final Bus widenedFirst = Bus();
  attempt('widened observe, then typed read', () {
    observeAny(widenedFirst, count);
    widenedFirst.getCurrentValue(count);
  });
  final Bus typedOnly = Bus();
  attempt('typed observe, then typed read', () {
    typedOnly.observe(count).listen((int _) {});
    typedOnly.getCurrentValue(count);
  });
  typedFirst.shutdown();
  widenedFirst.shutdown();
  typedOnly.shutdown();
}
