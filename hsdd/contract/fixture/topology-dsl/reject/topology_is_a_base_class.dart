// Reject fixture for topology-dsl@v2 G8: Topology is an immutable base class.
// A topology extends it and cannot implement it, so its definition always
// comes from its own declaration (Spec §6.5): buildDefinition() is
// non-virtual, and a mutable field is reported.
// covers: G8
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

final class Faked extends Topology {
  @override
  String get topologyId => 'checkout-flow';

  @override
  Scope get scope => Scope.module;

  @override
  void declare(TopologyBuilder b) {}

  @override
  // expect-diagnostic: invalid_override_of_non_virtual_member
  TopologyDefinition buildDefinition() => throw UnimplementedError();
}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class Pretender implements Topology {}

// expect-diagnostic: subtype_of_base_or_final_is_not_base_final_or_sealed
class Open extends Topology {
  @override
  String get topologyId => 'checkout-flow';

  @override
  Scope get scope => Scope.module;

  @override
  void declare(TopologyBuilder b) {}
}

// expect-diagnostic: must_be_immutable
final class Counting extends Topology {
  int declarations = 0;

  @override
  String get topologyId => 'checkout-flow';

  @override
  Scope get scope => Scope.module;

  @override
  void declare(TopologyBuilder b) => declarations++;
}
