// Reject fixture for topic-model@v1 G16: the message source family is closed
// (Spec §2.4 `source`). No type outside the library extends or implements a
// source, and a switch that omits a variant does not compile.
// covers: G16
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
final class BridgeSource implements MessageSource {}

// expect-diagnostic: invalid_use_of_type_outside_library
final class NamedService extends ServiceSource {
  const NamedService() : super('named');
}

// expect-diagnostic: non_exhaustive_switch_expression
String kind(MessageSource source) => switch (source) {
      TopologySource() => 'topology',
      ServiceSource() => 'service',
      PageSource() => 'page',
      ExecutorSource() => 'executor',
    };
