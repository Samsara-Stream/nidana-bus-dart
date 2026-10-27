# nidana_dart_contracts

The pure, effect-free core of Nidana Bus on Dart, which every other nidana
package builds on: typed topics and their references, the message envelope
and its lineage rules, scopes, the observer interfaces, sensitive-payload
redaction, the topology DSL with its recording builder, and the
`TopologyDefinition` IR with its graphs, renderers and analyses.

Everything here is an immutable value, a pure function, or one of the
observer interfaces an application implements; a function rejects an
argument outside its domain with an `ArgumentError`, as `Lineage.combine`
does for an empty input list. The package depends on the
Dart SDK and `package:meta` alone; it reads no clock, creates no timer or
microtask, generates no id and performs no I/O, so a function that needs a
timestamp or a fresh id takes it as an argument. Delivering messages is the
runtime's work, in `nidana_dart_runtime`.

## Libraries

- `package:nidana_dart_contracts/nidana_dart_contracts.dart`: topics,
  envelopes, lineage, scopes, observers and redaction; the topology DSL; the
  IR values.
- `package:nidana_dart_contracts/topology_plan.dart`: the plan a topology
  declaration records, which live activation interprets.
- `package:nidana_dart_contracts/topology_ir.dart`: topology graphs, their
  renderers and JSON form, and the analyses over them.

## Declaring topics

A registry declares its topics as constant members of an
`abstract final class`:

```dart
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

abstract final class CartTopics {
  static const StateTopic<int> itemCount = StateTopic<int>(
    name: 'cart.item-count',
    initial: 0,
  );

  static const EventTopic<String> checkoutRequested = EventTopic<String>(
    name: 'cart.checkout.requested',
  );
}
```

## License

Apache-2.0; see `LICENSE`.
